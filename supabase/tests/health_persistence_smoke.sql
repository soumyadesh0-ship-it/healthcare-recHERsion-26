-- ISOLATED, DISPOSABLE SUPABASE TEST PROJECT ONLY. Never run against live data.
-- Run as the test project's postgres operator AFTER separately applying the
-- reviewed baseline and proposed migration. Everything here rolls back.
begin;
insert into auth.users (id, email) values
 ('11111111-1111-4111-8111-111111111111', 'synthetic-a@example.invalid'),
 ('22222222-2222-4222-8222-222222222222', 'synthetic-b@example.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

do $$
declare
  journal_id uuid;
  observation_id uuid;
  returned_version bigint;
  changed bigint;
begin
  insert into public.journal_entries
    (client_request_id, title, body, entry_date, entry_time, entry_is_utc, timezone)
  values ('33333333-3333-4333-8333-333333333333', 'Synthetic journal', '',
    date '2026-10-25', time '09:15:12.345678', true, 'UTC')
  returning id, version into journal_id, returned_version;
  if journal_id is null or returned_version <> 1 then
    raise exception 'Journal UUID/version must be server generated';
  end if;
  if not exists (select 1 from public.journal_entries where id = journal_id
      and entry_time = time '09:15:12.345678' and entry_is_utc is true
      and user_id = auth.uid()) then
    raise exception 'Journal precision/ownership failed';
  end if;

  insert into public.journal_entries
    (client_request_id, title, body, entry_date, entry_time, entry_is_utc, timezone)
  values ('33333333-3333-4333-8333-333333333333', 'Synthetic journal', '',
    date '2026-10-25', time '09:15:12.345678', true, 'UTC')
  on conflict (user_id, client_request_id) do nothing;
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'Create retry was duplicated'; end if;

  update public.journal_entries set title = 'Edited synthetic journal'
    where id = journal_id and user_id = auth.uid() and version = 1
    returning version into returned_version;
  if returned_version <> 2 then raise exception 'Server version did not advance'; end if;
  delete from public.journal_entries where id = journal_id and version = 1;
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'Stale delete succeeded'; end if;

  begin
    update public.journal_entries set version = 100 where id = journal_id;
    raise exception 'Client metadata write unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;

  insert into public.health_observations
    (kind, title, notes, observation_date, observation_time, observation_is_utc,
     timezone_label, severity, mood_category, period_start, period_end,
     tracking_amount, tracking_color, tracking_consistency, tracking_odor_change,
     tracking_irritation)
  values ('discharge', 'Synthetic discharge', 'Fictional note', date '2026-10-25',
    time '09:15:12.345678', false, 'Original label', 'mild', 'calm', false, null,
    'light', 'pink', 'thin', 'unsure', 'no') returning id into observation_id;
  if not exists (select 1 from public.health_observations where id = observation_id
      and observation_time = time '09:15:12.345678'
      and observation_is_utc is false and period_start is false and period_end is null
      and tracking_odor_change = 'unsure') then
    raise exception 'Observation round trip failed';
  end if;
end $$;

-- A different user's SELECT/UPDATE/DELETE must all see zero rows.
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
do $$
declare changed bigint;
begin
  if exists (select 1 from public.journal_entries) or
     exists (select 1 from public.health_observations) then
    raise exception 'Cross-user read exposed records';
  end if;
  update public.journal_entries set title = 'Forbidden';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'Cross-user journal update allowed'; end if;
  delete from public.health_observations;
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'Cross-user observation delete allowed'; end if;
end $$;

reset role;
rollback;
