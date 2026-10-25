# Database baseline reconciliation — analysis only

Prepared 2026-10-25 on `integration/frontend-backend`. No database connection,
SQL execution, migration application/history repair, source migration rename/edit,
Flutter/backend change, commit, push, merge or branch switch occurred. All prior
staged/uncommitted work is preserved. This plan is the only new artifact.

## A. Current state, likely cause and candidate schema sources

User-reported database evidence: all 12 expected application tables exist, RLS is
enabled, expected policy names exist, and
`to_regclass('supabase_migrations.schema_migrations')` returned NULL. This means
the named relation was not resolved in that inspected database/session. It is
consistent with manual SQL Editor/table creation, absent/deleted CLI history, or
inspection of a different project/branch. It is not proof of which files ran.
Confirm the intended project/database/branch and verification role before adopting
that finding. Do not query a nonexistent history table as though it were empty.

Repository candidates for the deployed schema:

| File | Objects described |
| --- | --- |
| `20261025_initial_schema.sql` | Public profiles, period_logs, wellness_logs, journal_entries, pcos_assessments; metadata trigger function; owner policies/grants and indexes |
| `20261025_extended_features.sql` | Private community_identities; public forum_posts, forum_comments, doctors, appointments, consultation_messages, articles; community/provider helper functions; grants, policies, indexes and optional publication membership |
| `20261025120000_health_observation_persistence.sql` | Undeployed proposal: health_observations and two journal observation-time columns; exclude from the existing baseline |

The first two files together describe **11 public tables and one private table**,
not 12 public tables. If the reported count is 12 public tables, identify the
extra/missing/private objects rather than assume equivalence. Matching counts,
RLS flags and policy names are insufficient: column types, checks, policy
expressions/roles, grants, helper definitions and triggers may still differ.

### Dependencies and version conflict

Supabase-managed prerequisites are auth.users, auth.uid(), authenticated/anon/
service_role roles, supported UUID generation and schema privileges. Do not
baseline Supabase-managed internals as application-owned objects.

Order of application objects in a clean reconstruction:

1. Initial five tables and indexes; public.set_record_metadata(); metadata
   triggers, grants and owner policies.
2. Private schema and community_identities; public.get_my_community_identity()
   and private.owns_community_identity(uuid); forum objects/policies.
3. Doctors before appointments; private.is_appointment_doctor(uuid) before its
   dependent policies; appointments before consultation_messages. Articles and
   remaining indexes/grants follow. Extended metadata triggers require step 1.
4. Optional consultation_messages membership only if supabase_realtime exists,
   matching the conditional source behavior.
5. Health-record additive proposal only after an approved baseline is established.
   It depends on journal_entries and set_record_metadata(), not on replaying all
   extended CREATE TABLE statements.

Both historical filenames have version **20261025**. A unique-version history
row cannot independently describe both files. Lexical suffix order also puts
extended before initial, contrary to dependencies. Do not repair 20261025 once
and pretend both files have been independently tracked. Do not replay CREATE
TABLE over deployed objects or add IF NOT EXISTS to hide unknown differences.

Normalized UTF-8/LF source fingerprints recorded offline for provenance:

| File | SHA-256 |
| --- | --- |
| initial | `bb6f44ca89a01bfa32d32448d66889d22ba9ab329a9dba6522a373be761446b7` |
| extended | `2de06dde1247274d5ac302b86c21767d0950272c9e994f0384560774fa4c1dcd` |
| unapplied health proposal | `658f97d0aabd725d1e1a3fe01332688d39dff8b0d8133d013f37338593cea47d` |

These identify repository content; they are not hashes of deployed schema or
evidence of historical execution.

## B. Recommended baseline strategy

**Adopt a verified current-state baseline instead of fabricating historical
execution records for the colliding files.** A baseline records an agreed schema
state; it need not assert that every original file historically executed.

1. Pause application DDL/SQL Editor edits and competing migration jobs during the
   eventual capture/marking window. Establish the verified target, accountable
   owner, approval, tool versions, backup and restoration evidence first.
2. An authorized operator gathers metadata using section C, without selecting
   application rows. Compare against both repository files and record each
   difference as exact match, intentional deployed difference, missing required
   object or unexpected object. Do not silently normalize security differences.
3. Prepare a **separate reconciliation workspace** with a dedicated Supabase
   configuration/active migration directory. Keep the original repository files
   byte-for-byte unchanged as provenance; do not rename, move or delete them in
   this task. The future workspace is a planned operational change, not created
   here. Point all eventual deployment jobs at the reviewed workspace, not at
   the current duplicate-version directory.
4. Build a uniquely versioned baseline representing the verified deployed state,
   including the private schema, grants, column grants, checks, helper function
   definitions/owners/search_paths, triggers, policy roles/expressions and relevant
   publication configuration. Capture approved drift honestly; the baseline is
   not an unreviewed copy of the desired schema. Any security correction must be
   separately reviewed as an explicit additive delta.
5. **Do not place the consolidated baseline next to both legacy files in the
   same active migration lineage.** The runner would still see the old files as
   pending, recreate objects or hit the duplicated version. Simply adding another
   file or marking one legacy identifier does not resolve this problem.
6. Reconstruct the baseline in a disposable Supabase test environment with only
   synthetic data. Compare its full metadata to the captured target state and
   rehearse baseline tracking with the installed CLI. Test function execution,
   effective role privileges and policy behavior, not just object names.
7. After approval and a fresh drift check, establish the baseline's applied-history
   record on the existing database through the supported CLI workflow. This is
   an administrative database write, **not allowed by this task**. The baseline's
   CREATE statements run only on fresh test databases; they must not run on the
   already-populated existing project. Do not create a guessed history schema
   or hand-insert records to mimic a particular CLI release.
8. Validate that the baseline is tracked, the active local/remote lineage agrees,
   and the next dry-run proposes only the intended future additive delta. A CLI
   dry-run still connects; no dry-run is performed in this analysis. Stop if any
   historical CREATE, unexpected DROP or unreviewed migration is pending.

When bootstrapping from an existing project, official Supabase tooling can pull a
baseline and offer to record it as applied. That is not a harmless read-only
operation: the offer changes history, and non-interactive behavior may accept it.
Do not run db pull in the current conflicted directory or through unattended
automation while collecting evidence. Prefer an offline candidate assembled from
approved metadata first; any future pull/link/repair needs separate authorization
and an isolated rehearsal. Explicitly include/verify the private application
schema rather than relying on the default public-schema capture.

### Future timestamp strategy

Use unique 14-digit UTC-style timestamp versions, ordered by dependency, with
one canonical migration directory per deployment lineage. Check uniqueness in
both that directory and authorized applied history before release. After baseline
version B, every future additive version must be greater than B and the latest
applied migration. Serialize team migration naming and check CI for collisions.

The new health proposal is locally unique and remains **unapplied**. If its
20261025120000 version precedes the eventual baseline version, it must receive a
later unique version in a future explicitly approved preparation step, with its
filename-pinned tests/docs updated. That is permissible only because it is
unapplied; no already-applied migration may be renamed or edited. Do not use
--include-all to force an earlier delta past a later baseline. No renaming occurs
in this task. The baseline must exclude the unapplied new health table/columns
unless independently verified as already present; such unexpected presence is a
stop-and-investigate condition.

## C. Read-only SQL comparison queries — provided, NOT executed

Run only after separately authorized target/role verification. Results describe
schema/security metadata; no application/auth user rows are selected. Retain
outputs privately. Function definitions can contain sensitive literals if they
have drifted: review locally and redact before sharing. Do not invoke application
helpers to test their existence—get_my_community_identity() can INSERT data.

### C1. Target, history existence and expected objects

```sql
BEGIN READ ONLY;
SET LOCAL statement_timeout = '15s';
SET LOCAL lock_timeout = '3s';
SELECT current_database() AS database_name, current_user AS inspection_role,
       current_setting('server_version') AS postgres_version;
SELECT to_regnamespace('supabase_migrations') AS history_schema,
       to_regclass('supabase_migrations.schema_migrations') AS history_relation;

WITH expected(schema_name, table_name) AS (VALUES
  ('public','profiles'), ('public','period_logs'), ('public','wellness_logs'),
  ('public','journal_entries'), ('public','pcos_assessments'),
  ('private','community_identities'), ('public','forum_posts'),
  ('public','forum_comments'), ('public','doctors'), ('public','appointments'),
  ('public','consultation_messages'), ('public','articles')
)
SELECT e.*, c.oid::regclass AS resolved_object, c.relkind,
       c.relrowsecurity, c.relforcerowsecurity,
       pg_get_userbyid(c.relowner) AS owner
FROM expected e
LEFT JOIN pg_namespace n ON n.nspname = e.schema_name
LEFT JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = e.table_name
ORDER BY e.schema_name, e.table_name;

-- Candidate new objects should remain absent until the separate delta is applied.
SELECT to_regclass('public.health_observations') AS proposed_table;
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'journal_entries'
  AND column_name IN ('entry_time','entry_is_utc');
ROLLBACK;
```

Only if history_relation is non-null, inspect its column definitions first:

```sql
BEGIN READ ONLY;
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = 'supabase_migrations' AND table_name = 'schema_migrations'
ORDER BY ordinal_position;
-- Run only if the standard relation/version column has been confirmed:
SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;
ROLLBACK;
```

If it remains NULL, skip this second block; do not assume any standard history
rows/columns are available. The following application-catalog queries do not
depend on migration history.

### C2. Full application table/column/default/constraint/index definitions

```sql
BEGIN READ ONLY;
SELECT n.nspname AS schema_name, c.relname AS relation_name, c.relkind,
       pg_get_userbyid(c.relowner) AS owner
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public','private')
  AND c.relkind IN ('r','p','v','m')
ORDER BY 1,2;

SELECT n.nspname AS schema_name, c.relname AS table_name, a.attnum,
       a.attname AS column_name, format_type(a.atttypid,a.atttypmod) AS type,
       a.attnotnull, a.attidentity, a.attgenerated,
       pg_get_expr(d.adbin,d.adrelid) AS default_or_generated_expression,
       co.collname AS collation
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
LEFT JOIN pg_collation co ON co.oid = a.attcollation
WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p')
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY 1,2,a.attnum;

SELECT n.nspname AS schema_name, c.relname AS table_name,
       k.conname, k.contype, k.convalidated, k.condeferrable, k.condeferred,
       pg_get_constraintdef(k.oid,true) AS definition
FROM pg_constraint k
JOIN pg_class c ON c.oid = k.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public','private') ORDER BY 1,2,k.conname;

SELECT n.nspname AS schema_name, c.relname AS table_name,
       i.relname AS index_name, x.indisunique, x.indisvalid, x.indisready,
       pg_get_indexdef(x.indexrelid) AS definition,
       pg_get_expr(x.indpred,x.indrelid) AS partial_predicate
FROM pg_index x JOIN pg_class c ON c.oid = x.indrelid
JOIN pg_class i ON i.oid = x.indexrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public','private') ORDER BY 1,2,i.relname;
ROLLBACK;
```

Compare primary/foreign/unique/check constraints, cascade/restrict behavior,
partial one-open-period index, array/text/numeric bounds and server defaults.
All valid expected indexes must be present; a similarly named invalid index is
not equivalent. Include unexpected objects in the difference register rather
than filtering them out of the baseline decision.

### C3. Functions, triggers and optional publication membership

```sql
BEGIN READ ONLY;
SELECT to_regclass('auth.users') AS auth_users,
       to_regprocedure('auth.uid()') AS auth_uid,
       to_regprocedure('gen_random_uuid()') AS uuid_generator;

SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS arguments,
       pg_get_function_result(p.oid) AS result_type,
       pg_get_userbyid(p.proowner) AS owner, p.prosecdef AS security_definer,
       p.provolatile, p.proconfig, p.proacl
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','private') AND p.prokind = 'f'
ORDER BY 1,2,3;

-- Only the four known application functions; inspect definitions privately.
SELECT p.oid::regprocedure AS function_name, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
WHERE p.oid IN (
  to_regprocedure('public.set_record_metadata()'),
  to_regprocedure('public.get_my_community_identity()'),
  to_regprocedure('private.owns_community_identity(uuid)'),
  to_regprocedure('private.is_appointment_doctor(uuid)')
);

SELECT n.nspname, c.relname, t.tgname, t.tgenabled,
       pg_get_triggerdef(t.oid,true) AS definition,
       t.tgfoid::regprocedure AS function_name
FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public','private') AND NOT t.tgisinternal
ORDER BY 1,2,3;

SELECT pubname, schemaname, tablename FROM pg_publication_tables
WHERE schemaname IN ('public','private') ORDER BY 1,2,3;
ROLLBACK;
```

Expected metadata trigger: initial five tables and extended forum_posts,
forum_comments, doctors, appointments and articles. The source excludes
consultation_messages (immutable to clients) and private.community_identities.
Confirm the non-SECURITY-DEFINER metadata function; inspect helper SECURITY
DEFINER owners, empty search_path and revoked PUBLIC EXECUTE carefully.
Publication inclusion is conditional on supabase_realtime existing; record that
optional platform difference without inventing additional application tables.

### C4. Schema/table/column/function ACLs, role inheritance and effective access

```sql
BEGIN READ ONLY;
SELECT rolname, rolsuper, rolbypassrls, rolinherit
FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role');
SELECT member_role.rolname AS member, parent_role.rolname AS granted_role
FROM pg_auth_members m
JOIN pg_roles member_role ON member_role.oid = m.member
JOIN pg_roles parent_role ON parent_role.oid = m.roleid ORDER BY 1,2;

SELECT n.nspname,
       CASE WHEN g.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(g.grantee) END AS grantee,
       g.privilege_type, g.is_grantable
FROM pg_namespace n
CROSS JOIN LATERAL aclexplode(COALESCE(n.nspacl,acldefault('n',n.nspowner))) g
WHERE n.nspname IN ('public','private') ORDER BY 1,2,3;

SELECT n.nspname, c.relname,
       CASE WHEN g.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(g.grantee) END AS grantee,
       g.privilege_type, g.is_grantable
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) g
WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p')
ORDER BY 1,2,3,4;

SELECT n.nspname, c.relname, a.attname,
       CASE WHEN g.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(g.grantee) END AS grantee,
       g.privilege_type, g.is_grantable
FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(a.attacl) g
WHERE n.nspname IN ('public','private') AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY 1,2,3,4,5;

SELECT n.nspname, p.oid::regprocedure AS function_name,
       CASE WHEN g.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(g.grantee) END AS grantee,
       g.privilege_type, g.is_grantable
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) g
WHERE n.nspname IN ('public','private') AND p.prokind = 'f'
ORDER BY 1,2,3;

SELECT pg_get_userbyid(d.defaclrole) AS creator_role,
       n.nspname AS schema_name, d.defaclobjtype, d.defaclacl
FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
ORDER BY 1,2,3;

SELECT r.rolname, n.nspname, c.relname, a.attname,
       has_schema_privilege(r.rolname,n.oid,'USAGE') AS schema_usage,
       has_column_privilege(r.rolname,c.oid,a.attnum,'SELECT') AS can_select,
       has_column_privilege(r.rolname,c.oid,a.attnum,'INSERT') AS can_insert,
       has_column_privilege(r.rolname,c.oid,a.attnum,'UPDATE') AS can_update
FROM pg_roles r CROSS JOIN pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
WHERE r.rolname IN ('anon','authenticated')
  AND n.nspname IN ('public','private') AND c.relkind IN ('r','p')
ORDER BY 2,3,1,a.attnum;

SELECT r.rolname, n.nspname, c.relname,
       has_table_privilege(r.rolname,c.oid,'DELETE') AS can_delete,
       has_table_privilege(r.rolname,c.oid,'TRIGGER') AS can_create_trigger
FROM pg_roles r CROSS JOIN pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE r.rolname IN ('anon','authenticated')
  AND n.nspname IN ('public','private') AND c.relkind IN ('r','p')
ORDER BY 2,3,1;

SELECT r.rolname, p.oid::regprocedure AS function_name,
       has_function_privilege(r.rolname,p.oid,'EXECUTE') AS can_execute
FROM pg_roles r CROSS JOIN pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE r.rolname IN ('anon','authenticated')
  AND n.nspname IN ('public','private') AND p.prokind = 'f'
ORDER BY 2,1;
ROLLBACK;
```

PUBLIC is ACL grantee OID zero, not a role to pass as a normal role argument.
Column ACL absence does not mean denial if a table-level or inherited grant
permits access. Effective privilege results are not a test of row visibility:
evaluate RLS separately. Keep intended directory/article anonymous reads and
community participant permissions distinct from private-health owner access.

### C5. Full RLS definitions, including unexpected policies

```sql
BEGIN READ ONLY;
SELECT n.nspname, c.relname, c.relrowsecurity, c.relforcerowsecurity,
       pg_get_userbyid(c.relowner) AS owner
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p')
ORDER BY 1,2;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies WHERE schemaname IN ('public','private')
ORDER BY schemaname,tablename,policyname;
ROLLBACK;
```

Compare expressions/roles/commands and permissive/restrictive mode, not names.
Private identity storage has RLS but no direct authenticated table access/policies;
approved helpers mediate it. Private-health tables use owner policies; forum
reads, appointment participants, verified doctors and reviewed articles have
intentionally different predicates. Extra permissive policies can widen access
even when the expected named policies exist. Administrator/table-owner/BYPASSRLS
visibility is not evidence of ordinary-user isolation.

## D. CLI repair and SQL Editor distinctions

SQL Editor or direct SQL can create correct application objects without recording
a CLI migration version. BEGIN/COMMIT in the SQL files only controls application
DDL transaction boundaries; it does not implicitly create schema_migrations rows.
Conversely, recording an applied version does not execute or validate its DDL.

`migration repair --status applied` is appropriate only when a **unique identified
baseline/migration** describes effects already present in the verified database,
with complete comparison, tested reconstruction, backup and explicit history-write
approval. It establishes tracking; it does not repair missing schema or data.
`--status reverted` removes tracking and does not undo objects; using it to fix
CREATE TABLE collisions can cause destructive or failing future replays.

A future approved invocation might have this shape, but is not selected or run
here and must first be rehearsed with the installed CLI's missing-history workflow:

```text
supabase migration repair --linked --status applied <verified_unique_baseline_version>
```

Do not substitute 20261025 or 20261025120000 into that placeholder now. The first
is ambiguous; the second is the unapplied health delta. Never mark that delta
applied to skip its execution, or mark baseline tables applied based only on
counts/policy names. If history is absent, use the supported CLI initialization/
baseline-capture workflow after rehearsal; do not guess the internal table DDL.
Commands named pull, list or dry-run can connect, initialize tooling metadata or
offer history changes depending on command/version; none is authorized here.

Supabase's documented existing-project workflow pulls a baseline and can record
it as already applied. Its db push tracks successful versions separately. Review
prompts and non-interactive behavior; a schema capture is not automatic approval
to mutate history. Verify that private schema/functions/grants/publications were
captured; tool/engine defaults and generated diffs are not a complete equivalence
certificate. Do not include Supabase-managed auth/storage internals as if owned
by these application migrations.

## E. Minimum evidence and release conditions

Before any baseline marking, require all of the following:

1. Verified project/branch/database identity, inspection role and observation time;
   confirmation of history absence/presence with appropriate metadata access.
2. Immutable original migration fingerprints and a uniquely versioned candidate
   baseline with clear scope/provenance. Do not claim the old files executed if
   only their resultant schema can be demonstrated.
3. Complete columns/types/nullability/defaults/checks/PK/FK/unique/index comparison,
   including private objects, helper bodies/security/ownership/search_paths,
   triggers, grants/column grants/default ACLs, effective access, exact RLS and
   optional publication semantics. All differences reviewed and dispositioned.
4. Evidence the baseline reproduces that agreed schema in a fresh disposable
   Supabase environment, including helper/trigger execution and synthetic A/B/anon
   security tests. No production patient data needs to be copied for this.
5. Tested CLI history-bootstrap/marking procedure for the actual installed version,
   with no ambiguous identifiers, no pending historical replay and one controlled
   active migration workspace. A second developer reviews the intended history change.
6. Encrypted backup/snapshot with an isolated restoration check, recorded pre-change
   schema/history evidence, coordinated DDL freeze, accountable approver and a
   reviewed recovery procedure. Schema-only evidence is not a data backup.
7. Fresh comparison at marking time to catch concurrent DDL drift. After marking,
   verify history and the intended pending list before authorizing any new delta.

Data security tests do not prove historical file execution; schema equivalence
does not by itself prove RLS enforcement. Both evidence types are necessary for
the intended operational baseline. No current database result beyond the user's
stated findings is claimed in this analysis.

### Backup and recovery

An authorized operator should obtain appropriate platform backups/PITR coverage
and a schema/permission/history snapshot before future writes. No backup or
patient-record export is performed by this agent. Protect data-bearing backups;
keep them out of source control and chat. Rehearse restores with authorized,
protected infrastructure, using synthetic schema tests where real data is not needed.

Because baseline marking should change tracking only, its first recovery option
is a controlled correction of that tracking after comparing exact before/after
evidence—not restoring an old database over newer patient writes. Pause migration
jobs, check for intervening DDL/migrations, preserve all new records, and choose
the narrowest reviewed correction. Do not DROP the history schema or mass-mark
versions reverted just because it was absent at an earlier checkpoint. If actual
schema/data changed unexpectedly, prefer a reviewed roll-forward; restoring a
snapshot requires separate approval and a plan to retain post-snapshot writes.

## F. Safest next actions / current disposition

1. Have an authorized owner collect the metadata-only outputs in C and target
   confirmation. This agent must not connect under the present restrictions.
2. Compare those outputs and record drift before choosing any history repair.
3. Agree on the separate canonical baseline workspace/lineage, preserving legacy
   sources; construct and test the baseline offline/in isolation under new approval.
4. Only then approve history initialization/marking and later health-delta testing.

**Remain blocked for deployment now.** Do not run db push/reset/repair or replay
either legacy file over existing objects. No tests or SQL were executed in this
analysis-only task. Prior source-contract tests and Flutter tests are not proof
of deployed schema equivalence or two-user RLS.

Primary references checked:
- [Existing-project baseline workflow](https://supabase.com/docs/guides/local-development/cli-workflows)
- [Migration repair semantics](https://supabase.com/docs/reference/cli/supabase-migration-repair)
- [Migration tracking and db push](https://supabase.com/docs/reference/cli/supabase-db-push)
