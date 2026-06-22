package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/jackc/pgx/v5"
)

func (p *Postgres) Plans(ctx context.Context, userID string) ([]model.Plan, error) {
	rows, err := p.Pool.Query(ctx, `
		select id::text, title, category::text, recurrence::text,
		       starts_on::text, ends_on::text, weekdays, planned_time::text,
		       is_pinned, is_active, version, created_at
		from public.task_templates
		where user_id = $1
		order by is_active desc, is_pinned desc, planned_time nulls last, created_at
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("query plans: %w", err)
	}
	defer rows.Close()
	var plans []model.Plan
	for rows.Next() {
		var plan model.Plan
		if err := rows.Scan(
			&plan.ID, &plan.Title, &plan.Category, &plan.Recurrence,
			&plan.StartsOn, &plan.EndsOn, &plan.Weekdays, &plan.PlannedTime,
			&plan.IsPinned, &plan.IsActive, &plan.Version, &plan.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan plan: %w", err)
		}
		plans = append(plans, plan)
	}
	return plans, rows.Err()
}

func (p *Postgres) CreatePlan(ctx context.Context, userID string, input model.PlanInput) (model.Plan, error) {
	var plan model.Plan
	err := p.Pool.QueryRow(ctx, `
		insert into public.task_templates (
		  user_id, title, category, recurrence, starts_on, ends_on,
		  weekdays, planned_time, is_pinned
		)
		values ($1, trim($2), $3::public.task_category, $4::public.recurrence_kind,
		        $5::date, $6::date, $7, $8::time, $9)
		returning id::text, title, category::text, recurrence::text,
		          starts_on::text, ends_on::text, weekdays, planned_time::text,
		          is_pinned, is_active, version, created_at
	`, userID, input.Title, input.Category, input.Recurrence, input.StartsOn,
		input.EndsOn, input.Weekdays, input.PlannedTime, input.IsPinned,
	).Scan(
		&plan.ID, &plan.Title, &plan.Category, &plan.Recurrence,
		&plan.StartsOn, &plan.EndsOn, &plan.Weekdays, &plan.PlannedTime,
		&plan.IsPinned, &plan.IsActive, &plan.Version, &plan.CreatedAt,
	)
	if err != nil {
		return model.Plan{}, fmt.Errorf("create plan: %w", err)
	}
	return plan, nil
}

func (p *Postgres) UpdatePlan(ctx context.Context, userID, planID string, input model.PlanInput) (model.Plan, error) {
	var plan model.Plan
	err := p.Pool.QueryRow(ctx, `
		update public.task_templates
		set title = trim($4), category = $5::public.task_category,
		    recurrence = $6::public.recurrence_kind, starts_on = $7::date,
		    ends_on = $8::date, weekdays = $9, planned_time = $10::time,
		    is_pinned = $11
		where id = $1 and user_id = $2 and version = $3
		returning id::text, title, category::text, recurrence::text,
		          starts_on::text, ends_on::text, weekdays, planned_time::text,
		          is_pinned, is_active, version, created_at
	`, planID, userID, input.Version, input.Title, input.Category, input.Recurrence,
		input.StartsOn, input.EndsOn, input.Weekdays, input.PlannedTime, input.IsPinned,
	).Scan(
		&plan.ID, &plan.Title, &plan.Category, &plan.Recurrence,
		&plan.StartsOn, &plan.EndsOn, &plan.Weekdays, &plan.PlannedTime,
		&plan.IsPinned, &plan.IsActive, &plan.Version, &plan.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.Plan{}, ErrVersionConflict
	}
	if err != nil {
		return model.Plan{}, fmt.Errorf("update plan: %w", err)
	}
	return plan, nil
}

func (p *Postgres) DisablePlan(ctx context.Context, userID, planID string) error {
	tag, err := p.Pool.Exec(ctx, `
		update public.task_templates set is_active = false
		where id = $1 and user_id = $2 and is_active
	`, planID, userID)
	if err != nil {
		return fmt.Errorf("disable plan: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
