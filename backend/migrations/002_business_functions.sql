begin;

create or replace function public.synday_is_exempt(p_user_id uuid, p_date date)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.leave_days ld
    where ld.user_id = p_user_id
      and (
        (ld.kind = 'temporary_leave' and ld.business_date = p_date)
        or
        (
          ld.kind = 'weekly_rest'
          and ld.weekday = extract(isodow from p_date)::smallint
        )
      )
  );
$$;

create or replace function public.synday_generate_day(p_date date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer;
begin
  insert into public.daily_tasks (
    user_id,
    template_id,
    business_date,
    title,
    category,
    planned_time,
    is_pinned,
    sort_order
  )
  select
    tt.user_id,
    tt.id,
    p_date,
    tt.title,
    tt.category,
    tt.planned_time,
    tt.is_pinned,
    row_number() over (
      partition by tt.user_id
      order by tt.is_pinned desc, tt.planned_time nulls last, tt.created_at
    )::integer
  from public.task_templates tt
  where tt.is_active
    and p_date >= tt.starts_on
    and (tt.ends_on is null or p_date <= tt.ends_on)
    and (
      (tt.recurrence = 'once' and p_date = tt.starts_on)
      or tt.recurrence = 'daily'
      or (
        tt.recurrence = 'weekly'
        and extract(isodow from p_date)::smallint = any(tt.weekdays)
      )
    )
  on conflict (template_id, business_date) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create or replace function public.synday_settle_personal_day(p_date date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer := 0;
begin
  update public.daily_tasks
  set status = 'expired', expired_at = now()
  where business_date = p_date and status = 'pending';

  insert into public.daily_checkins (
    user_id,
    business_date,
    qualified,
    exempt,
    task_completed_count,
    focus_seconds
  )
  select
    p.id,
    p_date,
    coalesce(t.completed_count, 0) > 0 or coalesce(f.focus_seconds, 0) > 0,
    public.synday_is_exempt(p.id, p_date),
    coalesce(t.completed_count, 0),
    coalesce(f.focus_seconds, 0)
  from public.profiles p
  left join (
    select user_id, count(*)::integer as completed_count
    from public.daily_tasks
    where business_date = p_date and status = 'completed'
    group by user_id
  ) t on t.user_id = p.id
  left join (
    select user_id, sum(duration_seconds)::integer as focus_seconds
    from public.focus_sessions
    where business_date = p_date and is_valid
    group by user_id
  ) f on f.user_id = p.id
  on conflict (user_id, business_date)
  do update set
    qualified = excluded.qualified,
    exempt = excluded.exempt,
    task_completed_count = excluded.task_completed_count,
    focus_seconds = excluded.focus_seconds,
    updated_at = now();

  insert into public.personal_streaks (
    user_id,
    current_days,
    best_days,
    last_qualified_date
  )
  select
    dc.user_id,
    case
      when dc.qualified then
        case
          when ps.last_qualified_date = p_date - 1 then ps.current_days + 1
          when ps.last_qualified_date = p_date then ps.current_days
          else 1
        end
      when dc.exempt then ps.current_days
      else 0
    end,
    greatest(
      ps.best_days,
      case
        when dc.qualified then
          case
            when ps.last_qualified_date = p_date - 1 then ps.current_days + 1
            when ps.last_qualified_date = p_date then ps.current_days
            else 1
          end
        else ps.current_days
      end
    ),
    case when dc.qualified or dc.exempt then p_date else ps.last_qualified_date end
  from public.daily_checkins dc
  join public.personal_streaks ps on ps.user_id = dc.user_id
  where dc.business_date = p_date
  on conflict (user_id)
  do update set
    current_days = excluded.current_days,
    best_days = excluded.best_days,
    last_qualified_date = excluded.last_qualified_date,
    updated_at = now();

  get diagnostics affected = row_count;
  return affected;
end;
$$;

create or replace function public.synday_settle_couple_day(p_date date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer := 0;
begin
  insert into public.couple_streaks (
    binding_id,
    current_days,
    best_days,
    last_qualified_date
  )
  select
    cb.id,
    case
      when a.qualified or b.qualified then
        case
          when cs.last_qualified_date = p_date - 1 then coalesce(cs.current_days, 0) + 1
          when cs.last_qualified_date = p_date then coalesce(cs.current_days, 1)
          else 1
        end
      when a.exempt or b.exempt then coalesce(cs.current_days, 0)
      else 0
    end,
    greatest(
      coalesce(cs.best_days, 0),
      case
        when a.qualified or b.qualified then
          case
            when cs.last_qualified_date = p_date - 1 then coalesce(cs.current_days, 0) + 1
            when cs.last_qualified_date = p_date then coalesce(cs.current_days, 1)
            else 1
          end
        else coalesce(cs.current_days, 0)
      end
    ),
    case
      when a.qualified or b.qualified or a.exempt or b.exempt then p_date
      else cs.last_qualified_date
    end
  from public.couple_bindings cb
  join public.daily_checkins a on a.user_id = cb.user_a and a.business_date = p_date
  join public.daily_checkins b on b.user_id = cb.user_b and b.business_date = p_date
  left join public.couple_streaks cs on cs.binding_id = cb.id
  where cb.status = 'active'
  on conflict (binding_id)
  do update set
    current_days = excluded.current_days,
    best_days = excluded.best_days,
    last_qualified_date = excluded.last_qualified_date,
    updated_at = now();

  get diagnostics affected = row_count;
  return affected;
end;
$$;

create or replace function public.synday_settle_day(p_date date)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  personal_count integer;
  couple_count integer;
begin
  personal_count := public.synday_settle_personal_day(p_date);
  couple_count := public.synday_settle_couple_day(p_date);
  return jsonb_build_object(
    'business_date', p_date,
    'personal_streaks', personal_count,
    'couple_streaks', couple_count
  );
end;
$$;

create or replace function public.synday_review_data(p_user_id uuid, p_date date)
returns jsonb
language sql
stable
as $$
  with task_stats as (
    select
      count(*)::integer as total,
      count(*) filter (where status = 'completed')::integer as completed,
      count(*) filter (where status = 'expired')::integer as expired
    from public.daily_tasks
    where user_id = p_user_id and business_date = p_date
  ),
  categories as (
    select coalesce(
      jsonb_object_agg(category, details),
      '{}'::jsonb
    ) as value
    from (
      select
        category::text as category,
        jsonb_build_object(
          'total', count(*)::integer,
          'completed', count(*) filter (where status = 'completed')::integer,
          'tasks', jsonb_agg(
            jsonb_build_object(
              'title', title,
              'status', status::text
            )
            order by sort_order, created_at
          )
        ) as details
      from public.daily_tasks
      where user_id = p_user_id and business_date = p_date
      group by category
    ) grouped
  ),
  focus as (
    select coalesce(sum(duration_seconds), 0)::integer as seconds
    from public.focus_sessions
    where user_id = p_user_id and business_date = p_date and is_valid
  )
  select jsonb_build_object(
    'business_date', p_date,
    'total_tasks', task_stats.total,
    'completed_tasks', task_stats.completed,
    'expired_tasks', task_stats.expired,
    'completion_percent',
      case when task_stats.total = 0 then 0 else floor(task_stats.completed * 100.0 / task_stats.total)::integer end,
    'focus_seconds', focus.seconds,
    'categories', categories.value
  )
  from task_stats, categories, focus;
$$;

create or replace function public.synday_generate_review_drafts(p_date date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer;
begin
  insert into public.daily_reviews (
    user_id,
    business_date,
    title,
    full_text,
    compact_text,
    structured_data,
    ai_status,
    generated_at
  )
  select
    p.id,
    p_date,
    to_char(p_date, 'YYYY"年"MM"月"DD"日 每日学习复盘'),
    format(
      E'当日总览\n共 %s 项任务，完成 %s 项，作废 %s 项，完成率 %s%%。\n\n分类明细\n详细任务记录已按课程、自主学习与临时任务归档。\n\n未完成客观分析\n尚未完成的任务可能受到时间安排、精力状态或临时事项影响。\n\n次日优化建议\n明天优先完成一项最重要的任务，并为它预留清晰的开始时间。',
      review_data.data->>'total_tasks',
      review_data.data->>'completed_tasks',
      review_data.data->>'expired_tasks',
      review_data.data->>'completion_percent'
    ),
    format(
      '%s：完成 %s/%s 项，专注 %s 分钟。明天先完成最重要的一项。',
      to_char(p_date, 'YYYY-MM-DD'),
      review_data.data->>'completed_tasks',
      review_data.data->>'total_tasks',
      floor(coalesce((review_data.data->>'focus_seconds')::numeric, 0) / 60)
    ),
    review_data.data,
    'fallback',
    now()
  from public.profiles p
  cross join lateral (
    select public.synday_review_data(p.id, p_date) as data
  ) review_data
  on conflict (user_id, business_date)
  do update set
    structured_data = excluded.structured_data,
    title = excluded.title,
    full_text = case
      when public.daily_reviews.ai_status in ('pending', 'fallback', 'failed') then excluded.full_text
      else public.daily_reviews.full_text
    end,
    compact_text = case
      when public.daily_reviews.ai_status in ('pending', 'fallback', 'failed') then excluded.compact_text
      else public.daily_reviews.compact_text
    end,
    generated_at = now(),
    updated_at = now();

  get diagnostics affected = row_count;
  return affected;
end;
$$;

create or replace function public.synday_refresh_review_data(p_date date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer;
begin
  update public.daily_reviews dr
  set structured_data = public.synday_review_data(dr.user_id, p_date),
      finalized_at = now(),
      updated_at = now()
  where dr.business_date = p_date;
  get diagnostics affected = row_count;
  return affected;
end;
$$;

create or replace function public.synday_generate_monthly_reports(p_month date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer;
  month_end date := (p_month + interval '1 month')::date;
begin
  if extract(day from p_month) <> 1 then
    raise exception 'p_month must be the first day of a month';
  end if;

  insert into public.couple_monthly_reports (binding_id, month, metrics)
  select
    cb.id,
    p_month,
    jsonb_build_object(
      'user_a_average_completion', coalesce(a.avg_completion, 0),
      'user_b_average_completion', coalesce(b.avg_completion, 0),
      'user_a_checkin_days', coalesce(a.checkin_days, 0),
      'user_b_checkin_days', coalesce(b.checkin_days, 0),
      'user_a_focus_seconds', coalesce(a.focus_seconds, 0),
      'user_b_focus_seconds', coalesce(b.focus_seconds, 0),
      'shared_overlap_seconds', coalesce(shared.overlap_seconds, 0),
      'couple_current_streak', coalesce(cs.current_days, 0),
      'couple_best_streak', coalesce(cs.best_days, 0)
    )
  from public.couple_bindings cb
  left join lateral (
    select
      avg(case when totals.total = 0 then 0 else totals.completed * 100.0 / totals.total end)::numeric(5,2) as avg_completion,
      count(*) filter (where dc.qualified or dc.exempt)::integer as checkin_days,
      coalesce(sum(dc.focus_seconds), 0)::bigint as focus_seconds
    from public.daily_checkins dc
    left join lateral (
      select
        count(*)::integer as total,
        count(*) filter (where status = 'completed')::integer as completed
      from public.daily_tasks dt
      where dt.user_id = dc.user_id and dt.business_date = dc.business_date
    ) totals on true
    where dc.user_id = cb.user_a
      and dc.business_date >= p_month
      and dc.business_date < month_end
  ) a on true
  left join lateral (
    select
      avg(case when totals.total = 0 then 0 else totals.completed * 100.0 / totals.total end)::numeric(5,2) as avg_completion,
      count(*) filter (where dc.qualified or dc.exempt)::integer as checkin_days,
      coalesce(sum(dc.focus_seconds), 0)::bigint as focus_seconds
    from public.daily_checkins dc
    left join lateral (
      select
        count(*)::integer as total,
        count(*) filter (where status = 'completed')::integer as completed
      from public.daily_tasks dt
      where dt.user_id = dc.user_id and dt.business_date = dc.business_date
    ) totals on true
    where dc.user_id = cb.user_b
      and dc.business_date >= p_month
      and dc.business_date < month_end
  ) b on true
  left join lateral (
    select coalesce(sum(room_overlap), 0)::bigint as overlap_seconds
    from (
      select max(sfp.overlap_seconds)::bigint as room_overlap
      from public.shared_focus_participants sfp
      join public.shared_focus_rooms sfr on sfr.id = sfp.room_id
      where sfr.binding_id = cb.id
        and sfr.started_at >= (p_month::timestamp at time zone 'Asia/Shanghai')
        and sfr.started_at < (month_end::timestamp at time zone 'Asia/Shanghai')
      group by sfp.room_id
    ) room_overlaps
  ) shared on true
  left join public.couple_streaks cs on cs.binding_id = cb.id
  where cb.status = 'active'
  on conflict (binding_id, month)
  do update set metrics = excluded.metrics, generated_at = now();

  get diagnostics affected = row_count;
  return affected;
end;
$$;

create or replace function public.prevent_multiple_active_bindings()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'active' and exists (
    select 1
    from public.couple_bindings cb
    where cb.id <> new.id
      and cb.status = 'active'
      and (
        new.user_a in (cb.user_a, cb.user_b)
        or new.user_b in (cb.user_a, cb.user_b)
      )
  ) then
    raise exception 'one or both users already have an active binding';
  end if;
  return new;
end;
$$;

create trigger couple_bindings_one_active
before insert or update on public.couple_bindings
for each row execute function public.prevent_multiple_active_bindings();

commit;
