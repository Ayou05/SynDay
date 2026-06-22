package repository

import (
	"context"
	"encoding/json"
	"fmt"
)

type AITask struct {
	ID     string
	UserID string
	Title  string
	Tone   string
}

func (p *Postgres) MissingEncouragements(ctx context.Context, businessDate string, limit int) ([]AITask, error) {
	rows, err := p.Pool.Query(ctx, `
		select dt.id::text, dt.user_id::text, dt.title, pr.ai_tone::text
		from public.daily_tasks dt
		join public.profiles pr on pr.id = dt.user_id
		left join public.ai_copy_cache cache
		  on cache.task_id = dt.id and cache.tone = pr.ai_tone
		where dt.business_date = $1
		  and cache.id is null
		order by dt.created_at
		limit $2
	`, businessDate, limit)
	if err != nil {
		return nil, fmt.Errorf("query missing encouragements: %w", err)
	}
	defer rows.Close()
	var tasks []AITask
	for rows.Next() {
		var task AITask
		if err := rows.Scan(&task.ID, &task.UserID, &task.Title, &task.Tone); err != nil {
			return nil, fmt.Errorf("scan missing encouragement: %w", err)
		}
		tasks = append(tasks, task)
	}
	return tasks, rows.Err()
}

func (p *Postgres) SaveEncouragement(ctx context.Context, task AITask, content, model string) error {
	_, err := p.Pool.Exec(ctx, `
		insert into public.ai_copy_cache (user_id, task_id, tone, content, model)
		values ($1, $2, $3::public.ai_tone, $4, $5)
		on conflict (task_id, tone)
		do update set content = excluded.content, model = excluded.model, generated_at = now()
	`, task.UserID, task.ID, task.Tone, content, model)
	if err != nil {
		return fmt.Errorf("save encouragement: %w", err)
	}
	return nil
}

type PendingReview struct {
	ID             string
	StructuredData json.RawMessage
}

func (p *Postgres) PendingReviews(ctx context.Context, businessDate string, limit int) ([]PendingReview, error) {
	rows, err := p.Pool.Query(ctx, `
		select id::text, structured_data
		from public.daily_reviews
		where business_date = $1 and ai_status in ('pending', 'fallback', 'failed')
		order by updated_at
		limit $2
	`, businessDate, limit)
	if err != nil {
		return nil, fmt.Errorf("query pending reviews: %w", err)
	}
	defer rows.Close()
	var reviews []PendingReview
	for rows.Next() {
		var review PendingReview
		if err := rows.Scan(&review.ID, &review.StructuredData); err != nil {
			return nil, fmt.Errorf("scan pending review: %w", err)
		}
		reviews = append(reviews, review)
	}
	return reviews, rows.Err()
}

func (p *Postgres) SaveAIReview(ctx context.Context, reviewID, full, compact, model string) error {
	_, err := p.Pool.Exec(ctx, `
		update public.daily_reviews
		set full_text = $2,
		    compact_text = $3,
		    ai_status = 'ready',
		    model = $4,
		    generated_at = now()
		where id = $1
	`, reviewID, full, compact, model)
	if err != nil {
		return fmt.Errorf("save AI review: %w", err)
	}
	return nil
}

func (p *Postgres) MarkReviewAIFailed(ctx context.Context, reviewID string) error {
	_, err := p.Pool.Exec(ctx, `
		update public.daily_reviews set ai_status = 'failed' where id = $1
	`, reviewID)
	return err
}
