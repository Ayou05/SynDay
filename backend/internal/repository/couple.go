package repository

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"sort"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/jackc/pgx/v5"
)

func (p *Postgres) CoupleMonthlyReport(
	ctx context.Context,
	userID string,
	month time.Time,
) (model.CoupleMonthlyReport, error) {
	bindingID, _, err := p.ActiveBinding(ctx, userID)
	if err != nil {
		return model.CoupleMonthlyReport{}, err
	}
	var report model.CoupleMonthlyReport
	err = p.Pool.QueryRow(ctx, `
		select month::text, metrics, generated_at
		from public.couple_monthly_reports
		where binding_id = $1 and month = $2
	`, bindingID, month).Scan(&report.Month, &report.Metrics, &report.GeneratedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.CoupleMonthlyReport{}, ErrNotFound
	}
	if err != nil {
		return model.CoupleMonthlyReport{}, fmt.Errorf("load couple monthly report: %w", err)
	}
	return report, nil
}

func (p *Postgres) CreatePairingToken(ctx context.Context, userID string, ttl time.Duration) (model.PairingToken, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return model.PairingToken{}, fmt.Errorf("generate pairing token: %w", err)
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	hash := sha256.Sum256([]byte(token))
	codeNumber, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return model.PairingToken{}, fmt.Errorf("generate pairing code: %w", err)
	}
	code := fmt.Sprintf("%06d", codeNumber.Int64())
	expiresAt := time.Now().Add(ttl)

	var result model.PairingToken
	err = p.Pool.QueryRow(ctx, `
		insert into public.pairing_tokens (
		  creator_id, token_hash, six_digit_code, expires_at
		)
		values ($1, $2, $3, $4)
		returning id::text, six_digit_code, expires_at
	`, userID, hex.EncodeToString(hash[:]), code, expiresAt).Scan(
		&result.ID,
		&result.Code,
		&result.ExpiresAt,
	)
	if err != nil {
		return model.PairingToken{}, fmt.Errorf("insert pairing token: %w", err)
	}
	result.Token = token
	return result, nil
}

func (p *Postgres) ClaimPairingToken(ctx context.Context, userID string, input model.PairingClaimInput) (model.PairingToken, error) {
	var tokenHash string
	if input.Token != "" {
		hash := sha256.Sum256([]byte(input.Token))
		tokenHash = hex.EncodeToString(hash[:])
	}
	var result model.PairingToken
	err := p.Pool.QueryRow(ctx, `
		update public.pairing_tokens
		set claimed_by = $1
		where consumed_at is null
		  and expires_at > now()
		  and creator_id <> $1
		  and claimed_by is null
		  and (
		    ($2 <> '' and token_hash = $2)
		    or ($3 <> '' and six_digit_code = $3)
		  )
		returning id::text, six_digit_code, expires_at, claimed_by::text,
		          creator_confirmed_at is not null,
		          claimant_confirmed_at is not null
	`, userID, tokenHash, input.Code).Scan(
		&result.ID,
		&result.Code,
		&result.ExpiresAt,
		&result.ClaimedBy,
		&result.CreatorReady,
		&result.ClaimantReady,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.PairingToken{}, ErrNotFound
	}
	if err != nil {
		return model.PairingToken{}, fmt.Errorf("claim pairing token: %w", err)
	}
	return result, nil
}

func (p *Postgres) ConfirmPairing(ctx context.Context, userID, pairingID string) (model.PairingConfirmation, error) {
	tx, err := p.Pool.Begin(ctx)
	if err != nil {
		return model.PairingConfirmation{}, fmt.Errorf("begin pairing confirmation: %w", err)
	}
	defer tx.Rollback(ctx)

	var creatorID string
	var claimantID *string
	var creatorReady bool
	var claimantReady bool
	err = tx.QueryRow(ctx, `
		select creator_id::text, claimed_by::text,
		       creator_confirmed_at is not null,
		       claimant_confirmed_at is not null
		from public.pairing_tokens
		where id = $1 and consumed_at is null and expires_at > now()
		for update
	`, pairingID).Scan(&creatorID, &claimantID, &creatorReady, &claimantReady)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.PairingConfirmation{}, ErrNotFound
	}
	if err != nil {
		return model.PairingConfirmation{}, fmt.Errorf("load pairing token: %w", err)
	}
	if claimantID == nil || (userID != creatorID && userID != *claimantID) {
		return model.PairingConfirmation{}, ErrInvalidState
	}

	if userID == creatorID {
		_, err = tx.Exec(ctx, `update public.pairing_tokens set creator_confirmed_at = now() where id = $1`, pairingID)
		creatorReady = true
	} else {
		_, err = tx.Exec(ctx, `update public.pairing_tokens set claimant_confirmed_at = now() where id = $1`, pairingID)
		claimantReady = true
	}
	if err != nil {
		return model.PairingConfirmation{}, fmt.Errorf("confirm pairing side: %w", err)
	}

	result := model.PairingConfirmation{PairingID: pairingID, Status: "waiting"}
	if creatorReady && claimantReady {
		users := []string{creatorID, *claimantID}
		sort.Strings(users)
		err = tx.QueryRow(ctx, `
			insert into public.couple_bindings (user_a, user_b)
			values ($1, $2)
			returning id::text
		`, users[0], users[1]).Scan(&result.BindingID)
		if err != nil {
			return model.PairingConfirmation{}, fmt.Errorf("create couple binding: %w", asInvalidState(err))
		}
		if _, err := tx.Exec(ctx, `
			insert into public.couple_streaks (binding_id) values ($1)
		`, result.BindingID); err != nil {
			return model.PairingConfirmation{}, fmt.Errorf("create couple streak: %w", err)
		}
		if _, err := tx.Exec(ctx, `update public.pairing_tokens set consumed_at = now() where id = $1`, pairingID); err != nil {
			return model.PairingConfirmation{}, fmt.Errorf("consume pairing token: %w", err)
		}
		result.Status = "bound"
	}

	if err := tx.Commit(ctx); err != nil {
		return model.PairingConfirmation{}, fmt.Errorf("commit pairing confirmation: %w", err)
	}
	return result, nil
}

func (p *Postgres) ActiveBinding(ctx context.Context, userID string) (bindingID, partnerID string, err error) {
	err = p.Pool.QueryRow(ctx, `
		select id::text,
		       case when user_a = $1 then user_b::text else user_a::text end
		from public.couple_bindings
		where status = 'active' and $1 in (user_a, user_b)
	`, userID).Scan(&bindingID, &partnerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", ErrNotFound
	}
	if err != nil {
		return "", "", fmt.Errorf("load active binding: %w", err)
	}
	return bindingID, partnerID, nil
}

func (p *Postgres) PartnerOverview(ctx context.Context, userID string, businessDate time.Time) (model.PartnerOverview, error) {
	_, partnerID, err := p.ActiveBinding(ctx, userID)
	if err != nil {
		return model.PartnerOverview{}, err
	}
	tasks, summary, err := p.Today(ctx, partnerID, businessDate)
	if err != nil {
		return model.PartnerOverview{}, err
	}

	result := model.PartnerOverview{
		UserID:            partnerID,
		CompletionPercent: summary.CompletionPercent,
		CurrentStreak:     summary.CurrentStreak,
		Tasks:             tasks,
	}
	if err := p.Pool.QueryRow(ctx, `select display_name from public.profiles where id = $1`, partnerID).Scan(&result.DisplayName); err != nil {
		return model.PartnerOverview{}, fmt.Errorf("load partner profile: %w", err)
	}
	var focusStarted *time.Time
	var focusMode *string
	var focusRoomID *string
	err = p.Pool.QueryRow(ctx, `
		select started_at, mode::text, shared_room_id::text
		from public.focus_sessions
		where user_id = $1 and status = 'active' and share_with_partner
		order by started_at desc
		limit 1
	`, partnerID).Scan(&focusStarted, &focusMode, &focusRoomID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return model.PartnerOverview{}, fmt.Errorf("load partner focus: %w", err)
	}
	if focusStarted != nil {
		result.IsFocusing = true
		result.FocusStartedAt = focusStarted
		result.FocusMode = focusMode
		result.FocusRoomID = focusRoomID
	}
	return result, nil
}
