package repository

import (
	"context"
	"fmt"
	"time"
)

func (p *Postgres) RequestAccountDeletion(ctx context.Context, userID string) (time.Time, error) {
	var requestedAt time.Time
	if err := p.Pool.QueryRow(ctx, `select public.synday_request_account_deletion($1)`, userID).Scan(&requestedAt); err != nil {
		return time.Time{}, fmt.Errorf("request account deletion: %w", err)
	}
	return requestedAt, nil
}

func (p *Postgres) CancelAccountDeletion(ctx context.Context, userID string) error {
	_, err := p.Pool.Exec(ctx, `select public.synday_cancel_account_deletion($1)`, userID)
	return err
}

func (p *Postgres) PurgeDeletedAccounts(ctx context.Context) (int, error) {
	var count int
	if err := p.Pool.QueryRow(ctx, `select public.synday_purge_deleted_accounts()`).Scan(&count); err != nil {
		return 0, fmt.Errorf("purge deleted accounts: %w", err)
	}
	return count, nil
}

func (p *Postgres) UnbindCouple(ctx context.Context, userID string) error {
	tag, err := p.Pool.Exec(ctx, `
		update public.couple_bindings
		set status = 'ended', ended_at = now()
		where status = 'active' and $1 in (user_a, user_b)
	`, userID)
	if err != nil {
		return fmt.Errorf("unbind couple: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
