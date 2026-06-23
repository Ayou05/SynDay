begin;

alter table public.profiles
  add column if not exists realtime_channel_key uuid not null default gen_random_uuid();

create unique index if not exists profiles_realtime_channel_key_idx
  on public.profiles(realtime_channel_key);

-- These functions accept system-level dates or user IDs and run with the
-- function owner's privileges. They are called only by the private Go API or
-- database triggers, never through Supabase client RPC.
revoke execute on function public.synday_generate_day(date)
  from public, anon, authenticated;
revoke execute on function public.synday_settle_personal_day(date)
  from public, anon, authenticated;
revoke execute on function public.synday_settle_couple_day(date)
  from public, anon, authenticated;
revoke execute on function public.synday_settle_day(date)
  from public, anon, authenticated;
revoke execute on function public.synday_generate_review_drafts(date)
  from public, anon, authenticated;
revoke execute on function public.synday_refresh_review_data(date)
  from public, anon, authenticated;
revoke execute on function public.synday_generate_monthly_reports(date)
  from public, anon, authenticated;
revoke execute on function public.synday_complete_due_focus_sessions()
  from public, anon, authenticated;
revoke execute on function public.synday_request_account_deletion(uuid)
  from public, anon, authenticated;
revoke execute on function public.synday_cancel_account_deletion(uuid)
  from public, anon, authenticated;
revoke execute on function public.synday_purge_deleted_accounts()
  from public, anon, authenticated;
revoke execute on function public.handle_new_user()
  from public, anon, authenticated;

commit;
