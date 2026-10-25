begin;

-- Keep the account-to-community mapping outside the exposed public schema.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table private.community_identities (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references auth.users (id) on delete cascade
);
alter table private.community_identities enable row level security;
revoke all on private.community_identities from public, anon, authenticated;

-- Provision identities through a narrowly scoped function, never expose user_id.
create function public.get_my_community_identity()
returns uuid language plpgsql security definer set search_path = ''
as $$
declare identity_id uuid;
begin
    if auth.uid() is null then
        raise exception 'Authentication required' using errcode = '42501';
    end if;
    insert into private.community_identities (user_id) values (auth.uid())
        on conflict (user_id) do nothing;
    select id into identity_id from private.community_identities where user_id = auth.uid();
    return identity_id;
end;
$$;
revoke all on function public.get_my_community_identity() from public;
grant execute on function public.get_my_community_identity() to authenticated;

create function private.owns_community_identity(identity_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (select 1 from private.community_identities
        where id = identity_id and user_id = (select auth.uid()));
$$;
revoke all on function private.owns_community_identity(uuid) from public;
grant execute on function private.owns_community_identity(uuid) to authenticated;

create table public.forum_posts (
    id uuid primary key default gen_random_uuid(),
    author_id uuid not null default public.get_my_community_identity()
        references private.community_identities (id) on delete cascade,
    anonymous_name text not null check (char_length(trim(anonymous_name)) between 1 and 80),
    title text not null check (char_length(trim(title)) between 1 and 200),
    body text not null check (char_length(trim(body)) between 1 and 20000),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0)
);

create table public.forum_comments (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references public.forum_posts (id) on delete cascade,
    author_id uuid not null default public.get_my_community_identity()
        references private.community_identities (id) on delete cascade,
    anonymous_name text not null check (char_length(trim(anonymous_name)) between 1 and 80),
    body text not null check (char_length(trim(body)) between 1 and 10000),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0)
);
create index forum_posts_created_idx on public.forum_posts (created_at desc);
create index forum_posts_author_idx on public.forum_posts (author_id);
create index forum_comments_post_created_idx on public.forum_comments (post_id, created_at);
create index forum_comments_author_idx on public.forum_comments (author_id);

-- The account link is server-managed and excluded from directory SELECT grants.
create table public.doctors (
    id uuid primary key default gen_random_uuid(),
    user_id uuid unique references auth.users (id) on delete set null,
    display_name text not null check (char_length(trim(display_name)) between 1 and 200),
    specialty text not null check (char_length(trim(specialty)) between 1 and 200),
    biography text check (char_length(biography) <= 10000),
    is_verified boolean not null default false,
    verification_source text,
    verified_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0),
    check (not is_verified or (verified_at is not null and char_length(trim(verification_source)) > 0 and verification_source is not null))
);

create table public.appointments (
    id uuid primary key default gen_random_uuid(),
    patient_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    doctor_id uuid not null references public.doctors (id) on delete restrict,
    scheduled_at timestamptz not null,
    status text not null default 'requested'
        check (status in ('requested', 'confirmed', 'cancelled', 'completed')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0)
);
create index appointments_patient_date_idx on public.appointments (patient_id, scheduled_at);
create index appointments_doctor_date_idx on public.appointments (doctor_id, scheduled_at);

-- Only this boolean is exposed; the doctor account mapping stays private.
create function private.is_appointment_doctor(target_doctor_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (select 1 from public.doctors
        where id = target_doctor_id and user_id = (select auth.uid()) and is_verified);
$$;
revoke all on function private.is_appointment_doctor(uuid) from public;
grant execute on function private.is_appointment_doctor(uuid) to authenticated;

create table public.consultation_messages (
    id uuid primary key default gen_random_uuid(),
    appointment_id uuid not null references public.appointments (id) on delete cascade,
    sender_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    body text not null check (char_length(trim(body)) between 1 and 10000),
    created_at timestamptz not null default now()
);
create index consultation_messages_appointment_date_idx
    on public.consultation_messages (appointment_id, created_at);
create index consultation_messages_sender_idx on public.consultation_messages (sender_id);

create table public.articles (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    title text not null check (char_length(trim(title)) between 1 and 300),
    category text not null check (char_length(trim(category)) between 1 and 100),
    body text not null check (char_length(trim(body)) between 1 and 100000),
    sources text[] not null default '{}',
    review_status text not null default 'unreviewed'
        check (review_status in ('unreviewed', 'in_review', 'reviewed')),
    reviewer_role text,
    reviewed_at timestamptz,
    published_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version bigint not null default 1 check (version > 0),
    check (review_status <> 'reviewed' or (reviewed_at is not null and reviewer_role is not null))
);
create index articles_category_published_idx on public.articles (category, published_at);

do $$
declare table_name text;
begin
    foreach table_name in array array['forum_posts', 'forum_comments', 'doctors', 'appointments', 'consultation_messages', 'articles'] loop
        execute format('alter table public.%I enable row level security', table_name);
        execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
        execute format('grant all on table public.%I to service_role', table_name);
        if table_name <> 'consultation_messages' then
            execute format('create trigger set_record_metadata before insert or update on public.%I for each row execute function public.set_record_metadata()', table_name);
        end if;
    end loop;
    foreach table_name in array array['forum_posts', 'forum_comments'] loop
        execute format('grant select, insert, delete on public.%I to authenticated', table_name);
        execute format('create policy community_read on public.%I for select to authenticated using (true)', table_name);
        execute format('create policy author_insert on public.%I for insert to authenticated with check (private.owns_community_identity(author_id))', table_name);
        execute format('create policy author_update on public.%I for update to authenticated using (private.owns_community_identity(author_id)) with check (private.owns_community_identity(author_id))', table_name);
        execute format('create policy author_delete on public.%I for delete to authenticated using (private.owns_community_identity(author_id))', table_name);
    end loop;
end;
$$;
grant update (anonymous_name, title, body) on public.forum_posts to authenticated;
grant update (anonymous_name, body) on public.forum_comments to authenticated;

grant select (id, display_name, specialty, biography, is_verified, verification_source, verified_at, created_at, updated_at, version)
    on public.doctors to anon, authenticated;
create policy verified_directory_read on public.doctors for select to anon, authenticated using (is_verified);
-- Directory provisioning and verification are restricted to trusted server code.

grant select on public.appointments to authenticated;
grant insert (patient_id, doctor_id, scheduled_at) on public.appointments to authenticated;
grant update (status) on public.appointments to authenticated;
create policy participant_read on public.appointments for select to authenticated
    using (patient_id = (select auth.uid()) or private.is_appointment_doctor(doctor_id));
create policy patient_request on public.appointments for insert to authenticated
    with check (patient_id = (select auth.uid()) and status = 'requested'
        and scheduled_at > now()
        and exists (select 1 from public.doctors where id = doctor_id and is_verified));
create policy patient_cancel on public.appointments for update to authenticated
    using (patient_id = (select auth.uid()) and status in ('requested', 'confirmed'))
    with check (patient_id = (select auth.uid()) and status = 'cancelled');
-- Only trusted provider integration code may confirm or complete appointments.

grant select on public.consultation_messages to authenticated;
grant insert (appointment_id, sender_id, body) on public.consultation_messages to authenticated;
create policy participant_read on public.consultation_messages for select to authenticated
    using (exists (select 1 from public.appointments a where a.id = appointment_id
        and (a.patient_id = (select auth.uid()) or private.is_appointment_doctor(a.doctor_id))));
create policy participant_send on public.consultation_messages for insert to authenticated
    with check (sender_id = (select auth.uid()) and exists (
        select 1 from public.appointments a where a.id = appointment_id and a.status = 'confirmed'
        and (a.patient_id = (select auth.uid()) or private.is_appointment_doctor(a.doctor_id))));
-- Messages are immutable to clients. RLS also filters Postgres Changes subscribers.

grant select on public.articles to anon, authenticated;
create policy published_articles_read on public.articles for select to anon, authenticated
    using (published_at is not null and published_at <= now() and review_status = 'reviewed');
-- Editorial writes require a trusted server; users cannot publish or self-verify.

-- Supabase normally provides this publication; support installations without it.
do $$
begin
    if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
       and not exists (select 1 from pg_publication_tables
           where pubname = 'supabase_realtime' and schemaname = 'public'
             and tablename = 'consultation_messages') then
        alter publication supabase_realtime add table public.consultation_messages;
    end if;
end;
$$;

commit;
