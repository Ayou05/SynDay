package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/jackc/pgx/v5"
)

func (p *Postgres) RegisterDevice(ctx context.Context, userID string, input model.DeviceTokenInput) error {
	_, err := p.Pool.Exec(ctx, `
		insert into public.device_tokens (
		  user_id, platform, provider, token, device_id
		)
		values ($1, $2::public.device_platform, $3::public.push_provider, $4, $5)
		on conflict (user_id, device_id, provider)
		do update set token = excluded.token, enabled = true, last_seen_at = now(), updated_at = now()
	`, userID, input.Platform, input.Provider, input.Token, input.DeviceID)
	if err != nil {
		return fmt.Errorf("register device token: %w", err)
	}
	return nil
}

func (p *Postgres) UserDeviceTokens(ctx context.Context, userID string) ([]model.DeviceToken, error) {
	rows, err := p.Pool.Query(ctx, `
		select provider::text, token
		from public.device_tokens
		where user_id = $1 and enabled
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("query device tokens: %w", err)
	}
	defer rows.Close()
	var tokens []model.DeviceToken
	for rows.Next() {
		var token model.DeviceToken
		if err := rows.Scan(&token.Provider, &token.Token); err != nil {
			return nil, err
		}
		tokens = append(tokens, token)
	}
	return tokens, rows.Err()
}

func (p *Postgres) DisableDeviceToken(ctx context.Context, provider, token string) error {
	_, err := p.Pool.Exec(ctx, `
		update public.device_tokens set enabled = false
		where provider = $1::public.push_provider and token = $2
	`, provider, token)
	return err
}

func (p *Postgres) CreateNotification(
	ctx context.Context,
	userID string,
	actorID *string,
	kind, title, body, dedupeKey string,
	payload map[string]any,
) (model.Notification, error) {
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return model.Notification{}, err
	}
	var notification model.Notification
	var storedPayload []byte
	err = p.Pool.QueryRow(ctx, `
		insert into public.notifications (
		  user_id, actor_id, kind, title, body, payload, dedupe_key
		)
		values ($1, $2, $3::public.notification_kind, $4, $5, $6, $7)
		on conflict (user_id, dedupe_key)
		do update set dedupe_key = excluded.dedupe_key
		returning id::text, kind::text, title, body, payload
	`, userID, actorID, kind, title, body, payloadJSON, dedupeKey).Scan(
		&notification.ID, &notification.Kind, &notification.Title,
		&notification.Body, &storedPayload,
	)
	if err != nil {
		return model.Notification{}, fmt.Errorf("create notification: %w", err)
	}
	_ = json.Unmarshal(storedPayload, &notification.Payload)
	return notification, nil
}

func (p *Postgres) PartnerForNotification(ctx context.Context, userID string) (string, error) {
	var partnerID string
	err := p.Pool.QueryRow(ctx, `
		select case when cb.user_a = $1 then cb.user_b::text else cb.user_a::text end
		from public.couple_bindings cb
		join public.profiles partner
		  on partner.id = case when cb.user_a = $1 then cb.user_b else cb.user_a end
		where cb.status = 'active'
		  and $1 in (cb.user_a, cb.user_b)
		  and partner.notification_partner_enabled
	`, userID).Scan(&partnerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("load notification partner: %w", err)
	}
	return partnerID, nil
}

func (p *Postgres) UnreadNotifications(ctx context.Context, userID string, limit int) ([]model.Notification, error) {
	rows, err := p.Pool.Query(ctx, `
		select id::text, kind::text, title, body, payload
		from public.notifications
		where user_id = $1 and read_at is null
		order by created_at desc
		limit $2
	`, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("query notifications: %w", err)
	}
	defer rows.Close()
	var notifications []model.Notification
	for rows.Next() {
		var item model.Notification
		var payload []byte
		if err := rows.Scan(&item.ID, &item.Kind, &item.Title, &item.Body, &payload); err != nil {
			return nil, err
		}
		_ = json.Unmarshal(payload, &item.Payload)
		notifications = append(notifications, item)
	}
	return notifications, rows.Err()
}

func (p *Postgres) MarkNotificationRead(ctx context.Context, userID, notificationID string) error {
	tag, err := p.Pool.Exec(ctx, `
		update public.notifications set read_at = now()
		where id = $1 and user_id = $2 and read_at is null
	`, notificationID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		var exists bool
		err := p.Pool.QueryRow(ctx, `select exists(select 1 from public.notifications where id = $1 and user_id = $2)`, notificationID, userID).Scan(&exists)
		if err != nil {
			return err
		}
		if !exists {
			return ErrNotFound
		}
	}
	return nil
}

func isNoRows(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}
