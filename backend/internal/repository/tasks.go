package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/jackc/pgx/v5"
)

var (
	ErrNotFound        = errors.New("not found")
	ErrVersionConflict = errors.New("version conflict")
	ErrInvalidState    = errors.New("invalid state")
)

func (p *Postgres) Today(ctx context.Context, userID string, businessDate time.Time) ([]model.Task, model.TodaySummary, error) {
	rows, err := p.Pool.Query(ctx, `
		select dt.id::text, dt.business_date::text, dt.title, dt.category::text, dt.status::text,
		       dt.planned_time::text, dt.is_pinned, dt.sort_order, dt.completed_at,
		       cache.content, dt.version, dt.created_at
		from public.daily_tasks dt
		join public.profiles pr on pr.id = dt.user_id
		left join public.ai_copy_cache cache on cache.task_id = dt.id and cache.tone = pr.ai_tone
		where dt.user_id = $1 and dt.business_date = $2
		order by dt.is_pinned desc, dt.planned_time nulls last, dt.sort_order, dt.created_at
	`, userID, businessDate)
	if err != nil {
		return nil, model.TodaySummary{}, fmt.Errorf("query today tasks: %w", err)
	}
	defer rows.Close()

	tasks := make([]model.Task, 0)
	for rows.Next() {
		var task model.Task
		if err := rows.Scan(
			&task.ID,
			&task.BusinessDate,
			&task.Title,
			&task.Category,
			&task.Status,
			&task.PlannedTime,
			&task.IsPinned,
			&task.SortOrder,
			&task.CompletedAt,
			&task.Encouragement,
			&task.Version,
			&task.CreatedAt,
		); err != nil {
			return nil, model.TodaySummary{}, fmt.Errorf("scan today task: %w", err)
		}
		tasks = append(tasks, task)
	}
	if err := rows.Err(); err != nil {
		return nil, model.TodaySummary{}, fmt.Errorf("iterate today tasks: %w", err)
	}

	var summary model.TodaySummary
	summary.BusinessDate = businessDate.Format("2006-01-02")
	err = p.Pool.QueryRow(ctx, `
		select
		  count(*)::int,
		  count(*) filter (where status = 'completed')::int,
		  coalesce((select sum(duration_seconds)::int from public.focus_sessions
		            where user_id = $1 and business_date = $2 and is_valid), 0),
		  coalesce((select current_days from public.personal_streaks where user_id = $1), 0),
		  coalesce((
		    select case
		      when current_days >= 365 and not milestone_365_seen then 365
		      when current_days >= 100 and not milestone_100_seen then 100
		      when current_days >= 30 and not milestone_30_seen then 30
		      else 0
		    end
		    from public.personal_streaks where user_id = $1
		  ), 0)
		from public.daily_tasks
		where user_id = $1 and business_date = $2
	`, userID, businessDate).Scan(
		&summary.TotalTasks,
		&summary.CompletedTasks,
		&summary.FocusSeconds,
		&summary.CurrentStreak,
		&summary.PendingMilestone,
	)
	if err != nil {
		return nil, model.TodaySummary{}, fmt.Errorf("query today summary: %w", err)
	}
	if summary.TotalTasks > 0 {
		summary.CompletionPercent = summary.CompletedTasks * 100 / summary.TotalTasks
	}
	return tasks, summary, nil
}

func (p *Postgres) MarkMilestoneSeen(ctx context.Context, userID string, milestone int) error {
	var column string
	switch milestone {
	case 30:
		column = "milestone_30_seen"
	case 100:
		column = "milestone_100_seen"
	case 365:
		column = "milestone_365_seen"
	default:
		return ErrInvalidState
	}
	tag, err := p.Pool.Exec(ctx, `
		update public.personal_streaks
		set `+column+` = true
		where user_id = $1 and current_days >= $2
	`, userID, milestone)
	if err != nil {
		return fmt.Errorf("mark milestone seen: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrInvalidState
	}
	return nil
}

func (p *Postgres) CreateTask(ctx context.Context, userID string, businessDate time.Time, input model.CreateTaskInput) (model.Task, error) {
	tx, err := p.Pool.Begin(ctx)
	if err != nil {
		return model.Task{}, fmt.Errorf("begin create task: %w", err)
	}
	defer tx.Rollback(ctx)

	if input.OperationID != "" {
		if task, ok, err := storedTaskOperation(ctx, tx, userID, input.OperationID); err != nil {
			return model.Task{}, err
		} else if ok {
			return task, nil
		}
	}

	var task model.Task
	err = tx.QueryRow(ctx, `
		insert into public.daily_tasks (
		  user_id, business_date, title, category, planned_time, is_pinned,
		  sort_order, client_operation_id
		)
		values (
		  $1, $2, trim($3), $4::public.task_category, $5::time, $6,
		  coalesce((select max(sort_order) + 1 from public.daily_tasks where user_id = $1 and business_date = $2), 0),
		  nullif($7, '')::uuid
		)
		on conflict (user_id, client_operation_id) where client_operation_id is not null
		do update set client_operation_id = excluded.client_operation_id
		returning id::text, business_date::text, title, category::text, status::text,
		          planned_time::text, is_pinned, sort_order, completed_at, null::text, version, created_at
	`, userID, businessDate, input.Title, input.Category, input.PlannedTime, input.IsPinned, input.OperationID).Scan(
		&task.ID,
		&task.BusinessDate,
		&task.Title,
		&task.Category,
		&task.Status,
		&task.PlannedTime,
		&task.IsPinned,
		&task.SortOrder,
		&task.CompletedAt,
		&task.Encouragement,
		&task.Version,
		&task.CreatedAt,
	)
	if err != nil {
		return model.Task{}, fmt.Errorf("insert task: %w", err)
	}
	if err := saveTaskOperation(ctx, tx, userID, input.OperationID, "task-create", task); err != nil {
		return model.Task{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return model.Task{}, fmt.Errorf("commit create task: %w", err)
	}
	return task, nil
}

func (p *Postgres) UpdateTask(ctx context.Context, userID, taskID string, input model.UpdateTaskInput, now time.Time) (model.Task, error) {
	tx, err := p.Pool.Begin(ctx)
	if err != nil {
		return model.Task{}, fmt.Errorf("begin update task: %w", err)
	}
	defer tx.Rollback(ctx)

	if input.OperationID != "" {
		if task, ok, err := storedTaskOperation(ctx, tx, userID, input.OperationID); err != nil {
			return model.Task{}, err
		} else if ok {
			return task, nil
		}
	}

	var status string
	var completedAt any
	var pinExpression string
	switch input.Action {
	case "complete":
		status = "completed"
		completedAt = now
	case "uncomplete":
		status = "pending"
		completedAt = nil
	case "pin", "unpin":
		pinExpression = input.Action
	default:
		return model.Task{}, ErrInvalidState
	}

	query := `
		update public.daily_tasks
		set status = $4::public.task_status, completed_at = $5
		where id = $1 and user_id = $2 and version = $3 and status <> 'expired'
		returning id::text, business_date::text, title, category::text, status::text,
		          planned_time::text, is_pinned, sort_order, completed_at, null::text, version, created_at
	`
	args := []any{taskID, userID, input.Version, status, completedAt}
	if pinExpression != "" {
		query = `
			update public.daily_tasks
			set is_pinned = $4
			where id = $1 and user_id = $2 and version = $3 and status <> 'expired'
			returning id::text, business_date::text, title, category::text, status::text,
			          planned_time::text, is_pinned, sort_order, completed_at, null::text, version, created_at
		`
		args = []any{taskID, userID, input.Version, pinExpression == "pin"}
	}

	var task model.Task
	err = tx.QueryRow(ctx, query, args...).Scan(
		&task.ID,
		&task.BusinessDate,
		&task.Title,
		&task.Category,
		&task.Status,
		&task.PlannedTime,
		&task.IsPinned,
		&task.SortOrder,
		&task.CompletedAt,
		&task.Encouragement,
		&task.Version,
		&task.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		var exists bool
		_ = tx.QueryRow(ctx, `select exists(select 1 from public.daily_tasks where id = $1 and user_id = $2)`, taskID, userID).Scan(&exists)
		if exists {
			return model.Task{}, ErrVersionConflict
		}
		return model.Task{}, ErrNotFound
	}
	if err != nil {
		return model.Task{}, fmt.Errorf("update task: %w", err)
	}
	if err := saveTaskOperation(ctx, tx, userID, input.OperationID, "task-"+input.Action, task); err != nil {
		return model.Task{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return model.Task{}, fmt.Errorf("commit update task: %w", err)
	}
	return task, nil
}

func storedTaskOperation(ctx context.Context, tx pgx.Tx, userID, operationID string) (model.Task, bool, error) {
	var raw []byte
	err := tx.QueryRow(ctx, `
		select result->'task'
		from public.sync_operations
		where user_id = $1 and operation_id = $2::uuid
	`, userID, operationID).Scan(&raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.Task{}, false, nil
	}
	if err != nil {
		return model.Task{}, false, fmt.Errorf("read stored task operation: %w", err)
	}
	var task model.Task
	if err := json.Unmarshal(raw, &task); err != nil {
		return model.Task{}, false, fmt.Errorf("decode stored task operation: %w", err)
	}
	return task, true, nil
}

func saveTaskOperation(
	ctx context.Context,
	tx pgx.Tx,
	userID, operationID, operationType string,
	task model.Task,
) error {
	if operationID == "" {
		return nil
	}
	raw, err := json.Marshal(map[string]any{"task": task})
	if err != nil {
		return fmt.Errorf("encode task operation: %w", err)
	}
	if _, err := tx.Exec(ctx, `
		insert into public.sync_operations (user_id, operation_id, operation_type, result)
		values ($1, $2::uuid, $3, $4::jsonb)
		on conflict (user_id, operation_id) do nothing
	`, userID, operationID, operationType, raw); err != nil {
		return fmt.Errorf("save task operation: %w", err)
	}
	return nil
}

func (p *Postgres) DeleteTask(ctx context.Context, userID, taskID string) error {
	tag, err := p.Pool.Exec(ctx, `
		delete from public.daily_tasks
		where id = $1 and user_id = $2 and status = 'pending'
	`, taskID, userID)
	if err != nil {
		return fmt.Errorf("delete task: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
