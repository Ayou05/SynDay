begin;

alter table public.daily_tasks
  add column client_operation_id uuid;

create unique index daily_tasks_operation_idx
  on public.daily_tasks(user_id, client_operation_id)
  where client_operation_id is not null;

alter table public.focus_sessions
  add column stop_operation_id uuid;

create unique index focus_sessions_stop_operation_idx
  on public.focus_sessions(user_id, stop_operation_id)
  where stop_operation_id is not null;

commit;

