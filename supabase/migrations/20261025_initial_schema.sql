begin;

-- Private account data only. Community identities must be stored separately.
create table public.profiles (
    id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
    display_name text check (char_length(display_name) between 1 and 100),
    timezone text not null default 'UTC' check (char_length(timezone) between 1 and 100),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0)
);

create table public.period_logs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    start_date date not null,
    end_date date,
    timezone text not null default 'UTC' check (char_length(timezone) between 1 and 100),
    flow text check (flow in ('spotting', 'light', 'medium', 'heavy')),
    pain_level smallint check (pain_level between 0 and 10),
    notes text check (char_length(notes) <= 10000),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0),
    constraint period_logs_date_order check (end_date is null or end_date >= start_date),
    unique (user_id, start_date)
);

-- A user may have only one ongoing period.
create unique index period_logs_one_open_per_user
    on public.period_logs (user_id) where end_date is null;

create table public.wellness_logs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    log_date date not null,
    timezone text not null default 'UTC' check (char_length(timezone) between 1 and 100),
    mood smallint check (mood between 1 and 5),
    energy smallint check (energy between 1 and 5),
    stress smallint check (stress between 1 and 5),
    sleep_hours numeric(4, 2) check (sleep_hours between 0 and 24),
    notes text check (char_length(notes) <= 10000),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0),
    unique (user_id, log_date)
);

create table public.journal_entries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    entry_date date not null,
    timezone text not null default 'UTC' check (char_length(timezone) between 1 and 100),
    title text check (char_length(title) <= 200),
    body text not null check (char_length(body) between 1 and 50000),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0)
);

create index journal_entries_user_date_idx on public.journal_entries (user_id, entry_date desc);

-- Descriptive, user-reported observations; no diagnostic score or probability.
-- Cross-module source selection and consent must be verified by the service
-- before producing a summary. No journals are included automatically.
create table public.pcos_assessments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    assessment_date date not null,
    range_start date,
    range_end date,
    status text not null default 'draft' check (status in ('draft', 'reviewed', 'outdated')),
    observations text check (char_length(observations) <= 20000),
    limitations text check (char_length(limitations) <= 10000),
    user_edits text check (char_length(user_edits) <= 20000),
    method_version text check (char_length(method_version) between 1 and 100),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0),
    constraint pcos_assessments_range check (
        (range_start is null and range_end is null)
        or (range_start is not null and range_end is not null and range_end >= range_start)
    )
);

create index pcos_assessments_user_date_idx on public.pcos_assessments (user_id, assessment_date desc);

-- Maintain server-controlled modification metadata for every mutable record.
create function public.set_record_metadata()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if TG_OP = 'INSERT' then
        new.created_at := now();
        new.version := 1;
    else
        new.created_at := old.created_at;
        new.version := old.version + 1;
    end if;
    new.updated_at := now();
    return new;
end;
$$;

-- All five tables have the same private CRUD contract. UPDATE checks both
-- the existing owner and the resulting owner to prevent ownership transfers.
do $$
declare
    table_name text;
    owner_column text;
begin
    foreach table_name in array array[
        'profiles', 'period_logs', 'wellness_logs', 'journal_entries', 'pcos_assessments'
    ] loop
        owner_column := case when table_name = 'profiles' then 'id' else 'user_id' end;

        execute format('alter table public.%I enable row level security', table_name);
        execute format('revoke all on table public.%I from anon, authenticated', table_name);
        execute format('grant select, insert, update, delete on table public.%I to authenticated', table_name);

        execute format(
            'create policy %I on public.%I for select to authenticated using ((select auth.uid()) = %I)',
            table_name || '_select_own', table_name, owner_column
        );
        execute format(
            'create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = %I)',
            table_name || '_insert_own', table_name, owner_column
        );
        execute format(
            'create policy %I on public.%I for update to authenticated using ((select auth.uid()) = %I) with check ((select auth.uid()) = %I)',
            table_name || '_update_own', table_name, owner_column, owner_column
        );
        execute format(
            'create policy %I on public.%I for delete to authenticated using ((select auth.uid()) = %I)',
            table_name || '_delete_own', table_name, owner_column
        );
        execute format(
            'create trigger set_record_metadata before insert or update on public.%I for each row execute function public.set_record_metadata()',
            table_name
        );
    end loop;
end;
$$;

revoke all on function public.set_record_metadata() from public;

commit;
