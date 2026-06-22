package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

type StreakMilestone struct {
	UserID string
	Days   int
}

func (p *Postgres) GenerateDay(ctx context.Context, date time.Time) (int, error) {
	var count int
	if err := p.Pool.QueryRow(ctx, `select public.synday_generate_day($1)`, date).Scan(&count); err != nil {
		return 0, fmt.Errorf("generate day: %w", err)
	}
	return count, nil
}

func (p *Postgres) SettleDay(ctx context.Context, date time.Time) (json.RawMessage, error) {
	var result json.RawMessage
	if err := p.Pool.QueryRow(ctx, `select public.synday_settle_day($1)`, date).Scan(&result); err != nil {
		return nil, fmt.Errorf("settle day: %w", err)
	}
	return result, nil
}

func (p *Postgres) GenerateReviewDrafts(ctx context.Context, date time.Time) (int, error) {
	var count int
	if err := p.Pool.QueryRow(ctx, `select public.synday_generate_review_drafts($1)`, date).Scan(&count); err != nil {
		return 0, fmt.Errorf("generate review drafts: %w", err)
	}
	return count, nil
}

func (p *Postgres) RefreshReviewData(ctx context.Context, date time.Time) (int, error) {
	var count int
	if err := p.Pool.QueryRow(ctx, `select public.synday_refresh_review_data($1)`, date).Scan(&count); err != nil {
		return 0, fmt.Errorf("refresh review data: %w", err)
	}
	return count, nil
}

func (p *Postgres) GenerateMonthlyReports(ctx context.Context, month time.Time) (int, error) {
	var count int
	if err := p.Pool.QueryRow(ctx, `select public.synday_generate_monthly_reports($1)`, month).Scan(&count); err != nil {
		return 0, fmt.Errorf("generate monthly reports: %w", err)
	}
	return count, nil
}

func (p *Postgres) CompleteDueFocusSessions(ctx context.Context) (int, error) {
	var count int
	if err := p.Pool.QueryRow(ctx, `select public.synday_complete_due_focus_sessions()`).Scan(&count); err != nil {
		return 0, fmt.Errorf("complete due focus sessions: %w", err)
	}
	return count, nil
}

func (p *Postgres) StreakMilestonesForDate(ctx context.Context, date time.Time) ([]StreakMilestone, error) {
	rows, err := p.Pool.Query(ctx, `
		select user_id::text, current_days
		from public.personal_streaks
		where last_qualified_date = $1
		  and current_days in (30, 100, 365)
	`, date)
	if err != nil {
		return nil, fmt.Errorf("query streak milestones: %w", err)
	}
	defer rows.Close()
	var milestones []StreakMilestone
	for rows.Next() {
		var milestone StreakMilestone
		if err := rows.Scan(&milestone.UserID, &milestone.Days); err != nil {
			return nil, fmt.Errorf("scan streak milestone: %w", err)
		}
		milestones = append(milestones, milestone)
	}
	return milestones, rows.Err()
}
