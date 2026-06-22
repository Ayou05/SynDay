package repository

import (
	"context"
	"fmt"

	"github.com/catclaw-cloud/synday/backend/internal/model"
)

func (p *Postgres) Settings(ctx context.Context, userID string) (model.Settings, error) {
	var settings model.Settings
	err := p.Pool.QueryRow(ctx, `
		select display_name, ai_tone::text, external_checkin_enabled, bedtime::text,
		       notification_review_enabled, notification_bedtime_enabled,
		       notification_partner_enabled, notification_streak_enabled
		from public.profiles where id = $1
	`, userID).Scan(
		&settings.DisplayName, &settings.AITone, &settings.ExternalCheckinEnabled,
		&settings.Bedtime, &settings.NotificationReviewEnabled,
		&settings.NotificationBedtimeEnabled, &settings.NotificationPartnerEnabled,
		&settings.NotificationStreakEnabled,
	)
	if err != nil {
		return model.Settings{}, fmt.Errorf("query settings: %w", err)
	}
	return settings, nil
}

func (p *Postgres) UpdateSettings(ctx context.Context, userID string, settings model.Settings) (model.Settings, error) {
	_, err := p.Pool.Exec(ctx, `
		update public.profiles
		set display_name = trim($2), ai_tone = $3::public.ai_tone,
		    external_checkin_enabled = $4, bedtime = $5::time,
		    notification_review_enabled = $6,
		    notification_bedtime_enabled = $7,
		    notification_partner_enabled = $8,
		    notification_streak_enabled = $9
		where id = $1
	`, userID, settings.DisplayName, settings.AITone, settings.ExternalCheckinEnabled,
		settings.Bedtime, settings.NotificationReviewEnabled,
		settings.NotificationBedtimeEnabled, settings.NotificationPartnerEnabled,
		settings.NotificationStreakEnabled,
	)
	if err != nil {
		return model.Settings{}, fmt.Errorf("update settings: %w", err)
	}
	return p.Settings(ctx, userID)
}

func (p *Postgres) LeaveDays(ctx context.Context, userID string) ([]model.LeaveDay, error) {
	rows, err := p.Pool.Query(ctx, `
		select id::text, kind::text, business_date::text, weekday
		from public.leave_days where user_id = $1
		order by kind, business_date, weekday
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("query leave days: %w", err)
	}
	defer rows.Close()
	var days []model.LeaveDay
	for rows.Next() {
		var day model.LeaveDay
		if err := rows.Scan(&day.ID, &day.Kind, &day.BusinessDate, &day.Weekday); err != nil {
			return nil, err
		}
		days = append(days, day)
	}
	return days, rows.Err()
}

func (p *Postgres) CreateLeaveDay(ctx context.Context, userID string, input model.LeaveInput) (model.LeaveDay, error) {
	var day model.LeaveDay
	query := `
		insert into public.leave_days (user_id, kind, business_date, weekday)
		values ($1, $2::public.leave_kind, $3::date, $4)
		returning id::text, kind::text, business_date::text, weekday
	`
	if input.Kind == "weekly_rest" {
		query = `
			insert into public.leave_days (user_id, kind, business_date, weekday)
			values ($1, 'weekly_rest', null, $4)
			on conflict (user_id) where kind = 'weekly_rest'
			do update set weekday = excluded.weekday
			returning id::text, kind::text, business_date::text, weekday
		`
	}
	err := p.Pool.QueryRow(ctx, query, userID, input.Kind, input.BusinessDate, input.Weekday).Scan(
		&day.ID, &day.Kind, &day.BusinessDate, &day.Weekday,
	)
	if err != nil {
		return model.LeaveDay{}, fmt.Errorf("create leave day: %w", asInvalidState(err))
	}
	return day, nil
}

func (p *Postgres) DeleteLeaveDay(ctx context.Context, userID, leaveID string) error {
	tag, err := p.Pool.Exec(ctx, `delete from public.leave_days where id = $1 and user_id = $2`, leaveID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
