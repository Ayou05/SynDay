begin;

create extension if not exists pgcrypto;

create type public.task_category as enum ('course', 'self_study', 'temporary');
create type public.task_status as enum ('pending', 'completed', 'expired');
create type public.recurrence_kind as enum ('once', 'daily', 'weekly');
create type public.focus_mode as enum ('solo_countup', 'solo_countdown', 'shared_countup', 'shared_countdown');
create type public.focus_status as enum ('active', 'completed', 'cancelled');
create type public.leave_kind as enum ('weekly_rest', 'temporary_leave');
create type public.binding_status as enum ('pending', 'active', 'ended');
create type public.notification_kind as enum (
  'review_reminder',
  'bedtime_reminder',
  'partner_task_completed',
  'partner_joined_focus',
  'streak_milestone'
);
create type public.device_platform as enum ('ios', 'android');
create type public.push_provider as enum ('apns', 'oppo', 'fcm');
create type public.ai_tone as enum ('restrained', 'companion', 'concise');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  timezone text not null default 'Asia/Shanghai'
    check (timezone = 'Asia/Shanghai'),
  ai_tone public.ai_tone not null default 'restrained',
  external_checkin_enabled boolean not null default false,
  bedtime time,
  notification_review_enabled boolean not null default true,
  notification_bedtime_enabled boolean not null default true,
  notification_partner_enabled boolean not null default true,
  notification_streak_enabled boolean not null default true,
  account_deletion_requested_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.app_policy (
  id boolean primary key default true check (id),
  temporary_leave_days_per_month smallint not null default 4 check (temporary_leave_days_per_month between 0 and 31),
  temporary_leave_max_consecutive smallint not null default 2 check (temporary_leave_max_consecutive between 1 and 7),
  minimum_focus_seconds integer not null default 60 check (minimum_focus_seconds >= 0),
  pairing_token_ttl_seconds integer not null default 300 check (pairing_token_ttl_seconds between 60 and 3600),
  updated_at timestamptz not null default now()
);
insert into public.app_policy (id) values (true);

create table public.task_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 200),
  category public.task_category not null,
  recurrence public.recurrence_kind not null,
  starts_on date not null,
  ends_on date,
  weekdays smallint[] not null default '{}',
  planned_time time,
  is_pinned boolean not null default false,
  is_active boolean not null default true,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on),
  check (
    recurrence <> 'weekly'
    or (
      cardinality(weekdays) between 1 and 7
      and weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
    )
  )
);
create index task_templates_user_active_idx on public.task_templates(user_id, is_active);

create table public.daily_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  template_id uuid references public.task_templates(id) on delete set null,
  business_date date not null,
  title text not null check (char_length(trim(title)) between 1 and 200),
  category public.task_category not null,
  status public.task_status not null default 'pending',
  planned_time time,
  is_pinned boolean not null default false,
  sort_order integer not null default 0,
  completed_at timestamptz,
  expired_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (template_id, business_date),
  check ((status = 'completed') = (completed_at is not null)),
  check ((status = 'expired') = (expired_at is not null))
);
create index daily_tasks_user_date_idx on public.daily_tasks(user_id, business_date, is_pinned desc, sort_order, created_at);

create table public.ai_copy_cache (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_id uuid not null references public.daily_tasks(id) on delete cascade,
  tone public.ai_tone not null,
  content text not null check (char_length(content) between 1 and 120),
  model text,
  generated_at timestamptz not null default now(),
  unique (task_id, tone)
);

create table public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_date date not null,
  mode public.focus_mode not null,
  status public.focus_status not null default 'active',
  started_at timestamptz not null,
  planned_seconds integer check (planned_seconds is null or planned_seconds >= 60),
  ended_at timestamptz,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  is_valid boolean not null default false,
  share_with_partner boolean not null default true,
  shared_room_id uuid,
  client_operation_id uuid not null,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, client_operation_id),
  check (ended_at is null or ended_at >= started_at)
);
create index focus_sessions_user_date_idx on public.focus_sessions(user_id, business_date, started_at);
create unique index one_active_focus_per_user_idx on public.focus_sessions(user_id) where status = 'active';

create table public.shared_focus_rooms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  binding_id uuid,
  mode public.focus_mode not null,
  status public.focus_status not null default 'active',
  owner_session_id uuid references public.focus_sessions(id) on delete set null,
  planned_seconds integer,
  started_at timestamptz not null,
  ended_at timestamptz,
  joinable boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.focus_sessions
  add constraint focus_sessions_shared_room_fk
  foreign key (shared_room_id) references public.shared_focus_rooms(id) on delete set null;

create table public.shared_focus_participants (
  room_id uuid not null references public.shared_focus_rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid not null references public.focus_sessions(id) on delete cascade,
  joined_at timestamptz not null,
  left_at timestamptz,
  overlap_seconds integer not null default 0 check (overlap_seconds >= 0),
  primary key (room_id, user_id)
);

create table public.leave_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind public.leave_kind not null,
  business_date date,
  weekday smallint,
  created_at timestamptz not null default now(),
  check (
    (kind = 'weekly_rest' and weekday between 1 and 7 and business_date is null)
    or
    (kind = 'temporary_leave' and business_date is not null and weekday is null)
  )
);
create unique index one_weekly_rest_per_user_idx on public.leave_days(user_id) where kind = 'weekly_rest';
create unique index one_leave_per_date_idx on public.leave_days(user_id, business_date) where business_date is not null;

create table public.personal_streaks (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  current_days integer not null default 0 check (current_days >= 0),
  best_days integer not null default 0 check (best_days >= 0),
  last_qualified_date date,
  milestone_30_seen boolean not null default false,
  milestone_100_seen boolean not null default false,
  milestone_365_seen boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.daily_checkins (
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_date date not null,
  qualified boolean not null,
  exempt boolean not null default false,
  task_completed_count integer not null default 0 check (task_completed_count >= 0),
  focus_seconds integer not null default 0 check (focus_seconds >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, business_date)
);

create table public.pairing_tokens (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  token_hash text not null unique,
  six_digit_code text not null,
  expires_at timestamptz not null,
  claimed_by uuid references public.profiles(id) on delete cascade,
  creator_confirmed_at timestamptz,
  claimant_confirmed_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (six_digit_code ~ '^[0-9]{6}$')
);
create index pairing_tokens_code_idx on public.pairing_tokens(six_digit_code, expires_at);

create table public.couple_bindings (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  status public.binding_status not null default 'active',
  bound_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  check (user_a <> user_b)
);
create unique index active_binding_user_a_idx on public.couple_bindings(user_a) where status = 'active';
create unique index active_binding_user_b_idx on public.couple_bindings(user_b) where status = 'active';

alter table public.shared_focus_rooms
  add constraint shared_focus_rooms_binding_fk
  foreign key (binding_id) references public.couple_bindings(id) on delete set null;

create table public.couple_streaks (
  binding_id uuid primary key references public.couple_bindings(id) on delete cascade,
  current_days integer not null default 0 check (current_days >= 0),
  best_days integer not null default 0 check (best_days >= 0),
  last_qualified_date date,
  updated_at timestamptz not null default now()
);

create table public.daily_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_date date not null,
  title text not null,
  full_text text not null default '',
  compact_text text not null default '',
  structured_data jsonb not null default '{}'::jsonb,
  ai_status text not null default 'pending' check (ai_status in ('pending', 'ready', 'fallback', 'failed')),
  model text,
  generated_at timestamptz,
  finalized_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, business_date)
);
create index daily_reviews_user_date_idx on public.daily_reviews(user_id, business_date desc);

create table public.couple_monthly_reports (
  id uuid primary key default gen_random_uuid(),
  binding_id uuid not null references public.couple_bindings(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  metrics jsonb not null,
  generated_at timestamptz not null default now(),
  unique (binding_id, month)
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform public.device_platform not null,
  provider public.push_provider not null,
  token text not null,
  device_id text not null,
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, token),
  unique (user_id, device_id, provider)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  kind public.notification_kind not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);
create index notifications_unread_idx on public.notifications(user_id, created_at desc) where read_at is null;

create table public.sync_operations (
  user_id uuid not null references public.profiles(id) on delete cascade,
  operation_id uuid not null,
  operation_type text not null,
  result jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now(),
  primary key (user_id, operation_id)
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.bump_version()
returns trigger
language plpgsql
as $$
begin
  new.version = old.version + 1;
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
for each row execute function public.touch_updated_at();
create trigger task_templates_bump before update on public.task_templates
for each row execute function public.bump_version();
create trigger daily_tasks_bump before update on public.daily_tasks
for each row execute function public.bump_version();
create trigger focus_sessions_bump before update on public.focus_sessions
for each row execute function public.bump_version();
create trigger shared_focus_rooms_touch before update on public.shared_focus_rooms
for each row execute function public.touch_updated_at();
create trigger personal_streaks_touch before update on public.personal_streaks
for each row execute function public.touch_updated_at();
create trigger daily_checkins_touch before update on public.daily_checkins
for each row execute function public.touch_updated_at();
create trigger couple_streaks_touch before update on public.couple_streaks
for each row execute function public.touch_updated_at();
create trigger daily_reviews_bump before update on public.daily_reviews
for each row execute function public.bump_version();
create trigger device_tokens_touch before update on public.device_tokens
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', ''));
  insert into public.personal_streaks (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.task_templates enable row level security;
alter table public.daily_tasks enable row level security;
alter table public.ai_copy_cache enable row level security;
alter table public.focus_sessions enable row level security;
alter table public.shared_focus_rooms enable row level security;
alter table public.shared_focus_participants enable row level security;
alter table public.leave_days enable row level security;
alter table public.personal_streaks enable row level security;
alter table public.daily_checkins enable row level security;
alter table public.pairing_tokens enable row level security;
alter table public.couple_bindings enable row level security;
alter table public.couple_streaks enable row level security;
alter table public.daily_reviews enable row level security;
alter table public.couple_monthly_reports enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;
alter table public.sync_operations enable row level security;

create policy profiles_self_select on public.profiles
for select using (auth.uid() = id);
create policy profiles_self_update on public.profiles
for update using (auth.uid() = id) with check (auth.uid() = id);

create policy task_templates_owner_all on public.task_templates
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy daily_tasks_owner_all on public.daily_tasks
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ai_copy_owner_select on public.ai_copy_cache
for select using (auth.uid() = user_id);
create policy focus_sessions_owner_all on public.focus_sessions
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy leave_days_owner_all on public.leave_days
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy personal_streak_owner_select on public.personal_streaks
for select using (auth.uid() = user_id);
create policy daily_checkin_owner_select on public.daily_checkins
for select using (auth.uid() = user_id);
create policy daily_reviews_owner_all on public.daily_reviews
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy device_tokens_owner_all on public.device_tokens
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy notifications_owner_select on public.notifications
for select using (auth.uid() = user_id);
create policy notifications_owner_update on public.notifications
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy sync_operations_owner_select on public.sync_operations
for select using (auth.uid() = user_id);

create policy couple_binding_member_select on public.couple_bindings
for select using (auth.uid() in (user_a, user_b));
create policy couple_streak_member_select on public.couple_streaks
for select using (
  exists (
    select 1 from public.couple_bindings cb
    where cb.id = binding_id and auth.uid() in (cb.user_a, cb.user_b)
  )
);
create policy couple_report_member_select on public.couple_monthly_reports
for select using (
  exists (
    select 1 from public.couple_bindings cb
    where cb.id = binding_id and auth.uid() in (cb.user_a, cb.user_b)
  )
);

-- Partner read-only access to today's task/check-in/focus presence is granted
-- through security-definer RPCs or the Go API. Direct broad table policies are
-- intentionally avoided so historical/private rows cannot leak accidentally.

commit;

