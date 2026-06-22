package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/jackc/pgx/v5"
)

func (p *Postgres) ActiveFocus(ctx context.Context, userID string) (model.FocusSession, error) {
	var session model.FocusSession
	err := p.Pool.QueryRow(ctx, `
		select id::text, business_date::text, mode::text, status::text,
		       started_at, planned_seconds, ended_at, duration_seconds,
		       is_valid, share_with_partner, shared_room_id::text, version
		from public.focus_sessions
		where user_id = $1 and status = 'active'
		order by started_at desc
		limit 1
	`, userID).Scan(
		&session.ID,
		&session.BusinessDate,
		&session.Mode,
		&session.Status,
		&session.StartedAt,
		&session.PlannedSeconds,
		&session.EndedAt,
		&session.DurationSeconds,
		&session.IsValid,
		&session.ShareWithPartner,
		&session.SharedRoomID,
		&session.Version,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.FocusSession{}, ErrNotFound
	}
	if err != nil {
		return model.FocusSession{}, fmt.Errorf("load active focus: %w", err)
	}
	return session, nil
}

func (p *Postgres) StartFocus(
	ctx context.Context,
	userID string,
	businessDate time.Time,
	now time.Time,
	input model.StartFocusInput,
) (model.FocusSession, error) {
	tx, err := p.Pool.Begin(ctx)
	if err != nil {
		return model.FocusSession{}, fmt.Errorf("begin focus: %w", err)
	}
	defer tx.Rollback(ctx)

	session, err := insertFocusSession(ctx, tx, userID, businessDate, now, input)
	if err != nil {
		return model.FocusSession{}, err
	}
	if session.SharedRoomID != nil {
		if err := tx.Commit(ctx); err != nil {
			return model.FocusSession{}, fmt.Errorf("commit repeated focus start: %w", err)
		}
		return session, nil
	}

	if input.ShareWithPartner {
		var bindingID string
		err = tx.QueryRow(ctx, `
			select id::text
			from public.couple_bindings
			where status = 'active' and $1 in (user_a, user_b)
		`, userID).Scan(&bindingID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return model.FocusSession{}, fmt.Errorf("load binding for focus: %w", err)
		}
		if err == nil {
			var roomID string
			err = tx.QueryRow(ctx, `
				insert into public.shared_focus_rooms (
				  owner_id, binding_id, mode, owner_session_id,
				  planned_seconds, started_at
				)
				values ($1, $2, $3::public.focus_mode, $4, $5, $6)
				returning id::text
			`, userID, bindingID, input.Mode, session.ID, input.PlannedSeconds, now).Scan(&roomID)
			if err != nil {
				return model.FocusSession{}, fmt.Errorf("create shared focus room: %w", err)
			}
			if _, err := tx.Exec(ctx, `
				update public.focus_sessions set shared_room_id = $2 where id = $1
			`, session.ID, roomID); err != nil {
				return model.FocusSession{}, fmt.Errorf("attach shared room: %w", err)
			}
			if _, err := tx.Exec(ctx, `
				insert into public.shared_focus_participants (
				  room_id, user_id, session_id, joined_at
				)
				values ($1, $2, $3, $4)
			`, roomID, userID, session.ID, now); err != nil {
				return model.FocusSession{}, fmt.Errorf("add room owner: %w", err)
			}
			session.SharedRoomID = &roomID
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return model.FocusSession{}, fmt.Errorf("commit focus start: %w", err)
	}
	return session, nil
}

func insertFocusSession(
	ctx context.Context,
	tx pgx.Tx,
	userID string,
	businessDate time.Time,
	now time.Time,
	input model.StartFocusInput,
) (model.FocusSession, error) {
	var session model.FocusSession
	err := tx.QueryRow(ctx, `
		insert into public.focus_sessions (
		  user_id, business_date, mode, started_at, planned_seconds,
		  share_with_partner, client_operation_id
		)
		values ($1, $2, $3::public.focus_mode, $4, $5, $6, $7)
		on conflict (user_id, client_operation_id)
		do update set client_operation_id = excluded.client_operation_id
		returning id::text, business_date::text, mode::text, status::text,
		          started_at, planned_seconds, ended_at, duration_seconds,
		          is_valid, share_with_partner, shared_room_id::text, version
	`, userID, businessDate, input.Mode, now, input.PlannedSeconds, input.ShareWithPartner, input.OperationID).Scan(
		&session.ID,
		&session.BusinessDate,
		&session.Mode,
		&session.Status,
		&session.StartedAt,
		&session.PlannedSeconds,
		&session.EndedAt,
		&session.DurationSeconds,
		&session.IsValid,
		&session.ShareWithPartner,
		&session.SharedRoomID,
		&session.Version,
	)
	if err != nil {
		return model.FocusSession{}, fmt.Errorf("start focus: %w", err)
	}
	return session, nil
}

func (p *Postgres) JoinSharedFocus(
	ctx context.Context,
	userID string,
	businessDate time.Time,
	now time.Time,
	input model.JoinFocusInput,
) (model.FocusSession, error) {
	tx, err := p.Pool.Begin(ctx)
	if err != nil {
		return model.FocusSession{}, fmt.Errorf("begin join focus: %w", err)
	}
	defer tx.Rollback(ctx)

	var bindingID string
	var ownerID string
	err = tx.QueryRow(ctx, `
		select sfr.binding_id::text, sfr.owner_id::text
		from public.shared_focus_rooms sfr
		join public.couple_bindings cb on cb.id = sfr.binding_id
		where sfr.id = $1
		  and sfr.status = 'active'
		  and sfr.joinable
		  and $2 in (cb.user_a, cb.user_b)
		  and sfr.owner_id <> $2
		for update
	`, input.RoomID, userID).Scan(&bindingID, &ownerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.FocusSession{}, ErrNotFound
	}
	if err != nil {
		return model.FocusSession{}, fmt.Errorf("load shared focus room: %w", err)
	}

	focusInput := model.StartFocusInput{
		Mode:             "shared_countup",
		ShareWithPartner: true,
		OperationID:      input.OperationID,
	}
	session, err := insertFocusSession(ctx, tx, userID, businessDate, now, focusInput)
	if err != nil {
		return model.FocusSession{}, err
	}
	if _, err := tx.Exec(ctx, `
		update public.focus_sessions set shared_room_id = $2 where id = $1
	`, session.ID, input.RoomID); err != nil {
		return model.FocusSession{}, fmt.Errorf("attach joined focus room: %w", err)
	}
	if _, err := tx.Exec(ctx, `
		insert into public.shared_focus_participants (
		  room_id, user_id, session_id, joined_at
		)
		values ($1, $2, $3, $4)
		on conflict (room_id, user_id) do nothing
	`, input.RoomID, userID, session.ID, now); err != nil {
		return model.FocusSession{}, fmt.Errorf("join room participant: %w", err)
	}
	session.SharedRoomID = &input.RoomID

	if err := tx.Commit(ctx); err != nil {
		return model.FocusSession{}, fmt.Errorf("commit join focus: %w", err)
	}
	return session, nil
}

func (p *Postgres) StopFocus(
	ctx context.Context,
	userID string,
	now time.Time,
	minimumSeconds int,
	operationID string,
) (model.FocusSession, error) {
	tx, err := p.Pool.Begin(ctx)
	if err != nil {
		return model.FocusSession{}, fmt.Errorf("begin stop focus: %w", err)
	}
	defer tx.Rollback(ctx)

	var session model.FocusSession
	if operationID != "" {
		err = tx.QueryRow(ctx, `
			select id::text, business_date::text, mode::text, status::text,
			       started_at, planned_seconds, ended_at, duration_seconds,
			       is_valid, share_with_partner, shared_room_id::text, version
			from public.focus_sessions
			where user_id = $1 and stop_operation_id = $2::uuid
		`, userID, operationID).Scan(
			&session.ID,
			&session.BusinessDate,
			&session.Mode,
			&session.Status,
			&session.StartedAt,
			&session.PlannedSeconds,
			&session.EndedAt,
			&session.DurationSeconds,
			&session.IsValid,
			&session.ShareWithPartner,
			&session.SharedRoomID,
			&session.Version,
		)
		if err == nil {
			return session, nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return model.FocusSession{}, fmt.Errorf("read repeated focus stop: %w", err)
		}
	}

	err = tx.QueryRow(ctx, `
		update public.focus_sessions
		set status = 'completed',
		    ended_at = $2,
		    duration_seconds = greatest(0, floor(extract(epoch from ($2 - started_at)))::int),
		    is_valid = floor(extract(epoch from ($2 - started_at)))::int >= $3,
		    stop_operation_id = nullif($4, '')::uuid
		where user_id = $1 and status = 'active'
		returning id::text, business_date::text, mode::text, status::text,
		          started_at, planned_seconds, ended_at, duration_seconds,
		          is_valid, share_with_partner, shared_room_id::text, version
	`, userID, now, minimumSeconds, operationID).Scan(
		&session.ID,
		&session.BusinessDate,
		&session.Mode,
		&session.Status,
		&session.StartedAt,
		&session.PlannedSeconds,
		&session.EndedAt,
		&session.DurationSeconds,
		&session.IsValid,
		&session.ShareWithPartner,
		&session.SharedRoomID,
		&session.Version,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.FocusSession{}, ErrNotFound
	}
	if err != nil {
		return model.FocusSession{}, fmt.Errorf("stop focus: %w", err)
	}

	if session.SharedRoomID != nil {
		if _, err := tx.Exec(ctx, `
			update public.shared_focus_participants
			set left_at = $3
			where room_id = $1 and user_id = $2
		`, *session.SharedRoomID, userID, now); err != nil {
			return model.FocusSession{}, fmt.Errorf("leave shared focus room: %w", err)
		}
		if _, err := tx.Exec(ctx, `
			with intervals as (
			  select
			    count(*) participant_count,
			    max(joined_at) overlap_start,
			    min(coalesce(left_at, $2)) overlap_end
			  from public.shared_focus_participants
			  where room_id = $1
			),
			value as (
			  select case
			    when participant_count < 2 then 0
			    else greatest(0, floor(extract(epoch from (overlap_end - overlap_start)))::int)
			  end seconds
			  from intervals
			)
			update public.shared_focus_participants
			set overlap_seconds = value.seconds
			from value
			where room_id = $1
		`, *session.SharedRoomID, now); err != nil {
			return model.FocusSession{}, fmt.Errorf("calculate shared overlap: %w", err)
		}
		if _, err := tx.Exec(ctx, `
			update public.shared_focus_rooms
			set status = 'completed', ended_at = $2, joinable = false
			where id = $1
			  and not exists (
			    select 1
			    from public.shared_focus_participants sfp
			    join public.focus_sessions fs on fs.id = sfp.session_id
			    where sfp.room_id = $1 and fs.status = 'active'
			  )
		`, *session.SharedRoomID, now); err != nil {
			return model.FocusSession{}, fmt.Errorf("complete shared focus room: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return model.FocusSession{}, fmt.Errorf("commit stop focus: %w", err)
	}
	return session, nil
}
