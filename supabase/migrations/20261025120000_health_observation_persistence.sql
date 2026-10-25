-- PROPOSED ONLY: prepared offline; do not apply without schema/history review.
-- Prerequisites: initial_schema, authenticated/anon roles, auth.uid(), auth.users,
-- and public.set_record_metadata(). Existing policies and rows are unchanged.
begin;

-- Date-only legacy journals remain date-only. Never invent midnight or use audit
-- timestamps as observation times. New clients must handle this nullable pair.
alter table public.journal_entries
    add column entry_time time(6) without time zone,
    add column entry_is_utc boolean,
    add column client_request_id uuid,
    add column severity text not null default 'unspecified'
        check (severity in ('unspecified', 'mild', 'moderate', 'severe')),
    add column mood_category text check (mood_category in (
        'happy', 'calm', 'sad', 'anxious', 'tired', 'energetic'
    )),
    add column period_start boolean,
    add column period_end boolean,
    add column tracking_amount text check (tracking_amount in ('light', 'moderate', 'heavy')),
    add column tracking_color text check (char_length(tracking_color) <= 80),
    add column tracking_consistency text check (char_length(tracking_consistency) <= 80),
    add column tracking_odor_change text check (tracking_odor_change in ('yes', 'no', 'unsure')),
    add column tracking_irritation text check (tracking_irritation in ('yes', 'no', 'unsure')),
    add constraint journal_entries_observation_time_pair
        check ((entry_time is null) = (entry_is_utc is null)),
    add constraint journal_entries_observation_time_range
        check (entry_time is null or entry_time < time '24:00:00');

-- Empty journal bodies are supported by the existing optional-note editor.
-- This is the only replaced constraint; no rows or historical files are changed.
alter table public.journal_entries
    drop constraint journal_entries_body_check,
    add constraint journal_entries_body_check check (char_length(body) between 0 and 50000),
    add constraint journal_entries_request_unique unique (user_id, client_request_id),
    add constraint journal_entries_tracking_object check (
        tracking_amount is not null or (
            tracking_color is null and tracking_consistency is null
            and tracking_odor_change is null and tracking_irritation is null
        )
    );

-- Narrow the original broad writes. UUID and ownership remain server generated.
revoke insert, update on table public.journal_entries from authenticated;
grant insert (client_request_id, title, body, entry_date, entry_time, entry_is_utc,
    timezone, severity, mood_category, period_start, period_end, tracking_amount,
    tracking_color, tracking_consistency, tracking_odor_change, tracking_irritation)
    on table public.journal_entries to authenticated;
grant update (title, body, entry_date, entry_time, entry_is_utc,
    timezone, severity, mood_category, period_start, period_end, tracking_amount,
    tracking_color, tracking_consistency, tracking_odor_change, tracking_irritation)
    on table public.journal_entries to authenticated;

comment on column public.journal_entries.entry_time is
    'Observation wall-clock time; NULL for legacy unknown time, never inferred from created_at/updated_at.';
comment on column public.journal_entries.entry_is_utc is
    'Dart UTC/local representation flag, not a historical timezone offset or inferred IANA zone.';

-- One row per raw non-journal observation, not one row per date or period.
-- Keep exact titles: current bleeding intensity and wellness subtype use them.
create table public.health_observations (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid()
        references auth.users (id) on delete cascade,
    client_request_id uuid,
    constraint health_observations_request_unique unique (user_id, client_request_id),
    kind text not null check (kind in (
        'symptom', 'bleeding', 'spotting', 'discharge', 'wellness'
    )),
    title text not null check (char_length(trim(title)) > 0),
    notes text not null default '' check (char_length(notes) <= 2000),
    observation_date date not null
        check (observation_date between date '0001-01-01' and date '9999-12-31'),
    observation_time time(6) without time zone not null
        check (observation_time < time '24:00:00'),
    observation_is_utc boolean not null,
    timezone_label text not null check (char_length(trim(timezone_label)) > 0),
    severity text not null default 'unspecified'
        check (severity in ('unspecified', 'mild', 'moderate', 'severe')),
    mood_category text check (mood_category in (
        'happy', 'calm', 'sad', 'anxious', 'tired', 'energetic'
    )),
    period_start boolean,
    period_end boolean,
    tracking_amount text check (tracking_amount in ('light', 'moderate', 'heavy')),
    tracking_color text check (char_length(tracking_color) <= 80),
    tracking_consistency text check (char_length(tracking_consistency) <= 80),
    tracking_odor_change text check (tracking_odor_change in ('yes', 'no', 'unsure')),
    tracking_irritation text check (tracking_irritation in ('yes', 'no', 'unsure')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0),
    -- TrackingDetails has a required amount. NULL amount means absent object.
    -- Do not constrain metadata to a kind: preserve any supported HealthEntry
    -- metadata rather than silently discarding non-default legacy field values.
    constraint health_observations_tracking_object check (
        tracking_amount is not null or (
            tracking_color is null and tracking_consistency is null
            and tracking_odor_change is null and tracking_irritation is null
        )
    )
);

comment on table public.health_observations is
    'Private raw observations; no automatic demo import, clinical scoring, or daily/period summary dual-write.';
comment on column public.health_observations.observation_is_utc is
    'Original Dart representation only; preserve nominal date/time and timezone_label without inventing an offset.';
comment on column public.health_observations.mood_category is
    'Nominal mood category, not the wellness_logs numeric scale. NULL remains unrecorded.';
comment on column public.health_observations.version is
    'Server increments on update. Clients must condition updates AND deletes on owner, id and expected version.';

-- No per-day uniqueness: repeated entries, including same-kind/same-time entries,
-- are valid. UUID distinguishes individual records and supports retry recovery.
create index health_observations_owner_time_idx on public.health_observations
    (user_id, observation_date desc, observation_time desc, id desc);
create index health_observations_owner_kind_time_idx on public.health_observations
    (user_id, kind, observation_date desc, observation_time desc, id desc);

create trigger set_record_metadata
    before insert or update on public.health_observations
    for each row execute function public.set_record_metadata();

alter table public.health_observations enable row level security;

-- Remove any inherited/default table-level grants before granting the precise
-- user operations. No client may supply ownership or modification metadata.
revoke all on table public.health_observations from public, anon, authenticated;
grant select, delete on table public.health_observations to authenticated;
grant insert (
    client_request_id, kind, title, notes, observation_date, observation_time, observation_is_utc,
    timezone_label, severity, mood_category, period_start, period_end,
    tracking_amount, tracking_color, tracking_consistency,
    tracking_odor_change, tracking_irritation
) on table public.health_observations to authenticated;
grant update (
    kind, title, notes, observation_date, observation_time, observation_is_utc,
    timezone_label, severity, mood_category, period_start, period_end,
    tracking_amount, tracking_color, tracking_consistency,
    tracking_odor_change, tracking_irritation
) on table public.health_observations to authenticated;

create policy health_observations_select_own on public.health_observations
    for select to authenticated using ((select auth.uid()) = user_id);
create policy health_observations_insert_own on public.health_observations
    for insert to authenticated with check ((select auth.uid()) = user_id);
create policy health_observations_update_own on public.health_observations
    for update to authenticated using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
create policy health_observations_delete_own on public.health_observations
    for delete to authenticated using ((select auth.uid()) = user_id);

-- Deliberately no INSERT ... SELECT, backfill, summary update, publication change,
-- journal RLS change, custom SECURITY DEFINER function, or automatic import.
commit;
