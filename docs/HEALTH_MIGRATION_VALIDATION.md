# Health-record migration validation — NOT READY

Reviewed 2026-10-25 on `integration/frontend-backend`. Report only: the migration,
deployed migration sources, Flutter/backend code, UI and existing uncommitted
work were not changed. No SQL, database connection, migration application or
health-record access occurred. Read-only queries and deployment commands below
are instructions for a separately authorized operator, not actions performed.

## A. Migration and history

`supabase/migrations/20261025120000_health_observation_persistence.sql`

Version `20261025120000` is a valid, unique 14-digit local migration identifier.
Both older files use `20261025`:

- `20261025_initial_schema.sql`
- `20261025_extended_features.sql`

That legacy collision must be reconciled with applied migration history before
using the normal migration runner. The extended migration depends on objects
created by the initial migration; suffix sorting is not a valid history fix.
Applied versions, including whether the proposed version is already recorded,
are **unknown** because database access is prohibited. Do not infer deployment
state from filenames, rename deployed migrations, run repair/reset, or manually
insert/delete history entries to bypass this blocker.

## B. Additivity and schema coverage

The file wraps its DDL in BEGIN/COMMIT. It creates one new table and adds two
nullable columns plus two checks to `journal_entries`. There is no DROP,
TRUNCATE, record UPDATE/DELETE, INSERT...SELECT, backfill or replacement of any
existing function/table/policy. Existing journal time fields become null, not
invented midnight/audit times. A failure is intended to roll back the whole
transaction. ALTER TABLE acquires a lock and checks may scan journal rows;
deployment still needs a maintenance/timeout plan, even though it is additive.

Added journal columns: `entry_time time(6) without time zone`, `entry_is_utc
boolean`. The nullable pair must be both present or both absent. The time check
rejects PostgreSQL's 24:00:00 representation. Existing journal policies, content,
IDs, versions, audit timestamps and grants are not changed by this file.

New `health_observations` columns:

| Group | Columns |
| --- | --- |
| Identity/type | UUID `id`, server-defaulted UUID `user_id`, `kind`, `title`, `notes` |
| Observation context | `observation_date`, microsecond `observation_time`, `observation_is_utc`, `timezone_label` |
| Symptom/wellbeing | `severity`, nullable `mood_category` |
| Period source markers | Nullable `period_start`, `period_end` |
| Tracking | Nullable `tracking_amount`, `tracking_color`, `tracking_consistency`, `tracking_odor_change`, `tracking_irritation` |
| Server metadata | `created_at`, `updated_at`, positive bigint `version` |

Enums match the actual Dart definitions exactly, excluding journal from the new
table because journals retain their own table. Multiple same-day/same-kind/time
rows remain valid. Two non-unique indexes begin with owner, then date/time/ID,
with kind included in one index. A UUID primary key distinguishes observations.
The owner FK references `auth.users(id)` with account-deletion cascade; sign-out
must never delete database records.

Constraints retain empty non-journal notes, categorical severity and six moods;
tracking amount is required when tracking child fields exist. Notes/color/
consistency limits match the current repository limits. Null, false, unsure and
empty optional strings remain distinct. The proposal deliberately avoids numeric
coercion or per-kind metadata deletion. Dates 1–9999 cover the UI's 2000–2100
picker; values outside the storage domain must fail explicitly, not be truncated.

## C. Security/RLS review

| Area | Source result | Limit of verification |
| --- | --- | --- |
| New private tables | One new private-health table, RLS enabled | Actual deployed RLS flag not inspected |
| SELECT | Authenticated owner USING auth.uid() = user_id | A/B row visibility untested |
| INSERT | Owner WITH CHECK, user_id default auth.uid() | Actual role/default/function execution untested |
| UPDATE | Owner USING and WITH CHECK | Must verify effective inherited grants too |
| DELETE | Owner USING | Delete confirmation/version filtering belongs to the repository |
| PUBLIC/anon | All explicit table grants revoked; no access grant added | Actual role memberships/default privileges/other policies unknown |
| Mutable columns | Only listed content fields are updateable | Direct plus inherited effective privileges need inspection |
| Ownership/ID transfer | user_id excluded from INSERT and UPDATE; id excluded from UPDATE | Prevents normal clients under the intended grants; admin/BYPASSRLS roles are outside that boundary |
| Metadata writes | Audit/version columns excluded from client INSERT/UPDATE grants | Trigger execution and permission behavior need DB tests |
| Privileged code | No new SECURITY DEFINER or dynamic SQL function | Existing live function definition might differ from repository source |

The migration first revokes table privileges and then grants only SELECT/DELETE
plus column-scoped INSERT/UPDATE. This avoids retaining a broad table UPDATE grant
that would override column restrictions. PUBLIC is a pseudo-grantee, not a role
name to pass blindly to `has_table_privilege`. Inspect its ACL entries separately.
Effective privilege helpers below include role inheritance; RLS checks are an
additional boundary, not included in those helpers' boolean privilege results.

The existing `public.set_record_metadata()` is a trigger function, not SECURITY
DEFINER, with an empty search_path and no dynamic SQL or cross-table access. Its
body changes only NEW.created_at/version/updated_at; it cannot alter NEW.user_id,
grant privileges or expose other rows. The new table grants no TRIGGER/REFERENCES
privilege to application roles. No source-level privilege escalation path was
identified. Deployment requires a trusted role able to create the trigger and
execute that function. This is a source review, not proof of the live definition.

Existing journal/period/wellness RLS is declared in the initial migration but is
not strengthened or rewritten here. This report does not certify live grants on
those old tables or arbitrary inherited roles/default privileges.

## D. Dependencies, mapping and integrations

Repository prerequisites exist: `public.journal_entries`, `auth.users` references,
the Supabase authenticated/anon role convention, and
`public.set_record_metadata()` defined in the initial migration. `auth.uid()` and
`gen_random_uuid()` are existing Supabase/PostgreSQL prerequisites, not new helper
functions introduced by this migration. Actual catalog presence/signatures,
permissions, PostgreSQL version and definition drift remain unverified.

`HealthEntry.when` is nominal wall-clock date/time with a declared label. The new
date + time(6) + representation flag preserves those components and microseconds
without assuming an IANA zone. `Device local` does not establish a historical
offset; `entry_is_utc` alone cannot recover an actual historical observation
instant. `created_at`/`updated_at` remain timestamptz save/audit instants. New cloud
records may explicitly use returned updated_at as confirmed server savedAt;
there is no automatic import of old local timestamps, IDs or version history.

Raw bleeding records preserve nullable start/end flags and titles, so existing
CycleHistory can derive intervals without treating spotting as a period. Symptoms
retain title/severity; spotting/discharge retain every TrackingDetails field.
Wellness retains six nominal moods and exact category titles/prose. Energy,
stress and sleep currently have no structured numeric answer; the migration does
not invent one or misuse wellness_logs daily numeric columns.

Journal compatibility is only preparatory: no journal persistence adapter exists,
and both account/demo sessions currently use DemoRecordsRepository. Legacy
date-only journal rows cannot be represented honestly by the non-null Flutter
when field until an unknown-time representation/display decision is made.
Arbitrary non-default generic HealthEntry metadata on a journal still requires
explicit rejection or separately approved support; the current journal UI does
not collect it. No claim of complete cloud journal support is justified.

PCOS tables, endpoint, client parsing and auth token provider are untouched.
The new table does not introduce model inference, automatically include journals
in PCOS or change existing PCOS save behavior.

Version metadata is not mandatory optimistic locking. The future repository must
filter UPDATE/DELETE by owner + ID + expected old version, verify returned rows,
and handle zero rows as stale/deleted/access failure. The trigger alone allows
an authorized owner to make an unconditional last-write-wins update. UUID reuse
supports retry reconciliation but does not itself prevent an intentional duplicate
with a new UUID. After timeout, inspect only the same owner's fixed UUID before
retrying; never unconditional-upsert or assume a duplicate-key error proves the
requested content was saved. These are unimplemented repository obligations.

## E. Findings requiring resolution before deployment

1. **Blocker: migration history.** Reconcile the two legacy version identifiers
   against authorized applied history and verify the new version is not already
   applied with conflicting content. No safe history-repair command can be chosen
   without that evidence.
2. **Blocker: database validation.** No PostgreSQL parser/engine, psql, Docker,
   Supabase CLI or `supabase/config.toml` was available here. No isolated local
   environment was identified; syntax/permissions/trigger/RLS behavior is untested.
3. **Deployment preflight:** verify dependency signatures/definitions, effective
   grants, role inheritance and existing column/object drift. Missing required
   schema USAGE or deployment function privileges should be corrected through a
   reviewed, scoped change, not blanket grants.
4. **Application release blockers:** journal unknown-time handling, journal CRUD,
   session-bound cache invalidation, safe error mapping, coherent refreshes and
   conditional update/delete are not implemented by the SQL.

No mandatory SQL-source correction was identified for the current supported
non-journal UI fields. The limitations above prevent a deployment approval; 22
source tests alone are not a database security certification.

## F1. Read-only verification SQL — not executed

Run only in a separately authorized verification session. These inspect metadata,
not user health rows. Do not combine them with DDL in a read-only transaction.

```sql
BEGIN READ ONLY;
SELECT current_database(), current_user, current_setting('server_version');
SELECT to_regclass('supabase_migrations.schema_migrations') AS migration_history,
       to_regclass('public.journal_entries') AS journal_table,
       to_regclass('public.health_observations') AS proposed_table,
       to_regclass('auth.users') AS auth_users;
SELECT to_regprocedure('auth.uid()') AS auth_uid,
       to_regprocedure('gen_random_uuid()') AS uuid_generator,
       to_regprocedure('public.set_record_metadata()') AS metadata_function;

SELECT p.oid::regprocedure AS function_name,
       pg_get_function_result(p.oid) AS result_type,
       p.prosecdef AS security_definer, p.proconfig,
       pg_get_userbyid(p.proowner) AS owner,
       has_function_privilege(current_user, p.oid, 'EXECUTE') AS deployer_can_execute
FROM pg_proc p
WHERE p.oid = to_regprocedure('public.set_record_metadata()');

SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity,
       pg_get_userbyid(c.relowner) AS owner
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('health_observations','journal_entries','period_logs','wellness_logs');

SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('health_observations','journal_entries','period_logs','wellness_logs')
ORDER BY tablename, policyname;

SELECT r.rolname, r.rolsuper, r.rolbypassrls, r.rolinherit,
       has_schema_privilege(r.rolname, 'public', 'USAGE') AS public_schema_usage
FROM pg_roles r WHERE r.rolname IN ('anon','authenticated');
SELECT member_role.rolname AS member, parent_role.rolname AS granted_role
FROM pg_auth_members m
JOIN pg_roles member_role ON member_role.oid = m.member
JOIN pg_roles parent_role ON parent_role.oid = m.roleid
ORDER BY member, granted_role;

-- PUBLIC is grantee OID 0. Includes default ACL if relacl is NULL.
SELECT c.relname,
       CASE WHEN a.grantee = 0 THEN 'PUBLIC'
            ELSE pg_get_userbyid(a.grantee) END AS grantee,
       a.privilege_type, a.is_grantable
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner))) a
WHERE n.nspname = 'public'
  AND c.relname IN ('health_observations','journal_entries')
ORDER BY c.relname, grantee, a.privilege_type;

-- Effective direct/inherited column privileges, including table-level grants.
SELECT r.rolname, c.relname, a.attname,
       has_column_privilege(r.rolname, c.oid, a.attnum, 'SELECT') AS can_select,
       has_column_privilege(r.rolname, c.oid, a.attnum, 'INSERT') AS can_insert,
       has_column_privilege(r.rolname, c.oid, a.attnum, 'UPDATE') AS can_update
FROM pg_roles r
CROSS JOIN pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
WHERE r.rolname IN ('anon','authenticated') AND n.nspname = 'public'
  AND c.relname IN ('health_observations','journal_entries')
ORDER BY c.relname, r.rolname, a.attnum;

SELECT r.rolname, c.relname,
       has_table_privilege(r.rolname, c.oid, 'DELETE') AS can_delete,
       has_table_privilege(r.rolname, c.oid, 'TRIGGER') AS can_create_trigger
FROM pg_roles r CROSS JOIN pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE r.rolname IN ('anon','authenticated') AND n.nspname = 'public'
  AND c.relname IN ('health_observations','journal_entries');

SELECT table_name, column_name, data_type, datetime_precision, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('health_observations','journal_entries')
ORDER BY table_name, ordinal_position;
SELECT conname, conrelid::regclass AS relation, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN (to_regclass('public.health_observations'), to_regclass('public.journal_entries'));
SELECT tablename, indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'health_observations';
SELECT tgname, pg_get_triggerdef(oid) AS definition FROM pg_trigger
WHERE tgrelid = to_regclass('public.health_observations') AND NOT tgisinternal;
COMMIT;
```

Only if the first query confirms that the migration history relation exists:

```sql
BEGIN READ ONLY;
SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;
SELECT version FROM supabase_migrations.schema_migrations
WHERE version IN ('20261025','20261025120000');
COMMIT;
```

Before deployment the proposed table/columns/version should be absent. If present,
stop and compare definitions/history; do not rerun blind. Afterwards expect one
new table with four owner policies; anon must have no effective read/write access;
authenticated may insert id but cannot update it or write owner/audit/version.
Inspect the trusted metadata function body privately for drift as well; the
signature/metadata queries do not prove body equivalence to repository source.

## F2. Exact write SQL / controlled deployment commands — NOT RUN

The complete write SQL is the reviewed migration file itself, beginning with
BEGIN and ending with COMMIT. Do not copy fragments into a second migration,
wrap it in another BEGIN/COMMIT, or manually mark an unexecuted migration applied.

For a separately approved **disposable isolated database only**, after verifying
its prerequisites and absence of the new objects, psql can execute precisely
that file (PSQL meta-commands, from the repository root):

```text
\set ON_ERROR_STOP on
SET lock_timeout = '5s';
SET statement_timeout = '60s';
\i 'supabase/migrations/20261025120000_health_observation_persistence.sql'
RESET statement_timeout;
RESET lock_timeout;
```

This block writes schema and commits; it is not a read-only verification query.
Use it only in an already verified isolated session. A timeout/error is a stop
condition, not permission to increase limits and retry blindly. Raw psql execution
does not maintain Supabase migration history: use it only for disposable engine
tests, not as a parallel deployment path for a managed project.

Once history has been reconciled, local tooling installed/configured, and a
separate disposable local stack intentionally prepared, the managed CLI workflow
is (examples only, not executed):

```powershell
supabase migration list --local
supabase db push --local --dry-run
# Proceed only if the reviewed pending list is exactly the intended proposal.
supabase db push --local
```

The dry-run does not apply migrations, but it is still a database connection.
Do not run `supabase start`, `db reset` or any push against the current unresolved
history as a way to validate it. A fresh stack can replay repository migrations;
the existing duplicate versions must be handled first in an isolated setup.

After isolated syntax/constraint/A-B/CAS tests pass and a separately authorized
staging target/link and backup are verified, the corresponding managed workflow
would be:

```powershell
supabase migration list --linked
supabase db push --linked --dry-run
# Stop unless only the approved proposal is pending and the target is verified.
supabase db push --linked
```

No command here authorizes production deployment. No credentials/connection URI
are embedded. No `--include-all`, destructive reset or history-repair command is
provided because the evidence to choose one safely is unavailable.

Required isolated tests: actual A/B/anon CRUD; owner/ID/audit/version spoofing;
expected-version concurrent update/delete; UUID retry reconciliation; same-day
multiplicity; all enum/null/length/time constraints; legacy journal unknown time;
transaction failure rollback and unchanged old record metadata. Use fictional
fixtures only. Do not mistake administrator-role success for application access.

Rollback after any approved application should retain additive schema/data and
disable the new client writes, then prefer roll-forward fixes. Do not drop tables
or populated journal columns to undo this migration. The existing migration plan
contains the backup/recovery requirements.

## G. Final recommendation and test result

**NOT READY** for managed test deployment from the current repository state:
legacy history collision unresolved, applied-version/dependency/grant state
unknown, and no isolated PostgreSQL execution/security tests performed. The
proposal is ready for further source review and for a deliberately prepared,
separately authorized isolated test environment once its prerequisites/history
are resolved. It is not a deployment approval.

Offline command performed:
`python -m pytest supabase/tests/test_health_observation_schema_contract.py -q -p no:cacheprovider`
— **22 passed, 0 failed (0.13 seconds)**. These checks protect source contracts
and existing migration fingerprints; they are not SQL parsing or live security
verification. No new Flutter/backend run was necessary for a report-only review.

References checked: [PostgreSQL GRANT](https://www.postgresql.org/docs/16/sql-grant.html),
[CREATE TRIGGER](https://www.postgresql.org/docs/16/sql-createtrigger.html),
[Supabase migration history](https://supabase.com/docs/guides/deployment/database-migrations),
[Supabase CLI deployment flags](https://supabase.com/docs/reference/cli/supabase-db-push).
