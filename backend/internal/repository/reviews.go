package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/jackc/pgx/v5"
)

func (p *Postgres) Review(ctx context.Context, userID string, date time.Time) (model.Review, error) {
	var review model.Review
	err := p.Pool.QueryRow(ctx, `
		select id::text, business_date::text, title, full_text, compact_text,
		       structured_data, ai_status, generated_at, finalized_at, version
		from public.daily_reviews
		where user_id = $1 and business_date = $2
	`, userID, date).Scan(
		&review.ID, &review.BusinessDate, &review.Title, &review.FullText,
		&review.CompactText, &review.StructuredData, &review.AIStatus,
		&review.GeneratedAt, &review.FinalizedAt, &review.Version,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.Review{}, ErrNotFound
	}
	if err != nil {
		return model.Review{}, fmt.Errorf("query review: %w", err)
	}
	return review, nil
}

func (p *Postgres) UpdateReview(ctx context.Context, userID, reviewID string, input model.UpdateReviewInput) (model.Review, error) {
	var review model.Review
	err := p.Pool.QueryRow(ctx, `
		update public.daily_reviews
		set full_text = $4
		where id = $1 and user_id = $2 and version = $3
		returning id::text, business_date::text, title, full_text, compact_text,
		          structured_data, ai_status, generated_at, finalized_at, version
	`, reviewID, userID, input.Version, input.FullText).Scan(
		&review.ID, &review.BusinessDate, &review.Title, &review.FullText,
		&review.CompactText, &review.StructuredData, &review.AIStatus,
		&review.GeneratedAt, &review.FinalizedAt, &review.Version,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.Review{}, ErrVersionConflict
	}
	if err != nil {
		return model.Review{}, fmt.Errorf("update review: %w", err)
	}
	return review, nil
}

func (p *Postgres) Calendar(ctx context.Context, userID string, start, end time.Time) ([]model.CalendarDay, error) {
	rows, err := p.Pool.Query(ctx, `
		select business_date::text, qualified, exempt, task_completed_count, focus_seconds
		from public.daily_checkins
		where user_id = $1 and business_date >= $2 and business_date < $3
		order by business_date
	`, userID, start, end)
	if err != nil {
		return nil, fmt.Errorf("query calendar: %w", err)
	}
	defer rows.Close()
	var days []model.CalendarDay
	for rows.Next() {
		var day model.CalendarDay
		if err := rows.Scan(&day.BusinessDate, &day.Qualified, &day.Exempt, &day.TaskCount, &day.FocusSeconds); err != nil {
			return nil, fmt.Errorf("scan calendar day: %w", err)
		}
		days = append(days, day)
	}
	return days, rows.Err()
}
