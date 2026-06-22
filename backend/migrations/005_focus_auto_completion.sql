begin;

create or replace function public.synday_complete_due_focus_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer;
begin
  update public.focus_sessions
  set status = 'completed',
      ended_at = started_at + make_interval(secs => planned_seconds),
      duration_seconds = planned_seconds,
      is_valid = planned_seconds >= (
        select minimum_focus_seconds from public.app_policy where id = true
      )
  where status = 'active'
    and planned_seconds is not null
    and started_at + make_interval(secs => planned_seconds) <= now();

  get diagnostics affected = row_count;

  update public.shared_focus_participants sfp
  set left_at = fs.ended_at
  from public.focus_sessions fs
  where sfp.session_id = fs.id
    and fs.status = 'completed'
    and sfp.left_at is null;

  with room_values as (
    select
      sfr.id room_id,
      case
        when count(sfp.user_id) < 2 then 0
        else greatest(
          0,
          floor(extract(epoch from (
            min(coalesce(sfp.left_at, now())) - max(sfp.joined_at)
          )))::integer
        )
      end overlap_seconds
    from public.shared_focus_rooms sfr
    join public.shared_focus_participants sfp on sfp.room_id = sfr.id
    where sfr.status = 'active'
    group by sfr.id
  )
  update public.shared_focus_participants sfp
  set overlap_seconds = rv.overlap_seconds
  from room_values rv
  where sfp.room_id = rv.room_id;

  update public.shared_focus_rooms sfr
  set status = 'completed',
      ended_at = coalesce(
        (
          select max(fs.ended_at)
          from public.shared_focus_participants sfp
          join public.focus_sessions fs on fs.id = sfp.session_id
          where sfp.room_id = sfr.id
        ),
        now()
      ),
      joinable = false
  where sfr.status = 'active'
    and not exists (
      select 1
      from public.shared_focus_participants sfp
      join public.focus_sessions fs on fs.id = sfp.session_id
      where sfp.room_id = sfr.id and fs.status = 'active'
    );

  return affected;
end;
$$;

commit;
