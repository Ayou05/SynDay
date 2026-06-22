begin;

create or replace function public.synday_business_today()
returns date
language sql
stable
as $$
  select ((now() at time zone 'Asia/Shanghai') - interval '4 hours')::date;
$$;

create or replace function public.validate_temporary_leave()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  policy public.app_policy%rowtype;
  month_start date;
  month_end date;
  current_count integer;
  run_count integer;
  has_learning boolean;
begin
  if new.kind <> 'temporary_leave' then
    return new;
  end if;

  if new.business_date < public.synday_business_today() then
    raise exception 'past dates cannot be marked as temporary leave';
  end if;

  select * into policy from public.app_policy where id = true;
  month_start := date_trunc('month', new.business_date)::date;
  month_end := (month_start + interval '1 month')::date;

  select count(*) into current_count
  from public.leave_days
  where user_id = new.user_id
    and kind = 'temporary_leave'
    and business_date >= month_start
    and business_date < month_end
    and id <> new.id;

  if current_count >= policy.temporary_leave_days_per_month then
    raise exception 'monthly temporary leave quota exceeded';
  end if;

  select exists (
    select 1
    from public.daily_tasks
    where user_id = new.user_id
      and business_date = new.business_date
      and status = 'completed'
  ) or exists (
    select 1
    from public.focus_sessions
    where user_id = new.user_id
      and business_date = new.business_date
      and is_valid
  ) into has_learning;

  if has_learning then
    raise exception 'a day with valid learning activity cannot become a leave day';
  end if;

  with recursive nearby_dates(day) as (
    select new.business_date - policy.temporary_leave_max_consecutive
    union all
    select day + 1
    from nearby_dates
    where day < new.business_date + policy.temporary_leave_max_consecutive
  ),
  marked as (
    select day,
      case
        when day = new.business_date then true
        else exists (
          select 1 from public.leave_days ld
          where ld.user_id = new.user_id
            and (
              (ld.kind = 'temporary_leave' and ld.business_date = day)
              or
              (ld.kind = 'weekly_rest' and ld.weekday = extract(isodow from day)::smallint)
            )
        )
      end is_leave
    from nearby_dates
  ),
  groups as (
    select day, is_leave,
      day - (row_number() over (order by day))::integer as grp
    from marked
    where is_leave
  )
  select coalesce(max(count), 0) into run_count
  from (
    select count(*)::integer as count from groups group by grp
  ) runs;

  if run_count > policy.temporary_leave_max_consecutive then
    raise exception 'maximum consecutive leave days exceeded';
  end if;
  return new;
end;
$$;

create trigger temporary_leave_policy
before insert or update on public.leave_days
for each row execute function public.validate_temporary_leave();

create or replace function public.synday_request_account_deletion(p_user_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_at timestamptz := now();
begin
  update public.profiles
  set account_deletion_requested_at = requested_at
  where id = p_user_id;

  update public.couple_bindings
  set status = 'ended', ended_at = requested_at
  where status = 'active' and p_user_id in (user_a, user_b);

  update public.device_tokens
  set enabled = false
  where user_id = p_user_id;

  return requested_at;
end;
$$;

create or replace function public.synday_cancel_account_deletion(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set account_deletion_requested_at = null
  where id = p_user_id;
end;
$$;

create or replace function public.synday_purge_deleted_accounts()
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  affected integer;
begin
  delete from auth.users au
  using public.profiles p
  where p.id = au.id
    and p.account_deletion_requested_at <= now() - interval '7 days';
  get diagnostics affected = row_count;
  return affected;
end;
$$;

commit;

