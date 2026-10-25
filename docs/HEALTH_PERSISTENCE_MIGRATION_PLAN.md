# Proposed health persistence migration and verification plan

Prepared on 2026-10-25 for `integration/frontend-backend`. **Not applied.**
No Supabase connection, SQL execution, Flutter/backend modification, existing
migration edit, commit, push, merge or branch switch occurred in this task.
Existing staged merge work and both earlier audit documents are preserved.

## A. Journal status and prerequisite

Journal cloud persistence remains incomplete in the checked-out source:
`lib/app/auth_root.dart` constructs `DemoRecordsRepository(sample: false)` for
both account and demo sessions, and no production code accesses
`journal_entries`. Journal is a filtered Timeline; Home and Insights consume
the same local records. Separate session instances are not evidence of durable
cloud CRUD or real two-user RLS isolation.

The latest completed Flutter validation in this workspace reports analyzer clean
(15.3 seconds) and 219 tests passed, 0 failed (2 minutes 25 seconds). There are no
known outstanding failures from that run, but those tests do not verify journal
cloud persistence. Flutter was not rerun for this SQL/documentation-only task.
The new schema-contract test run is recorded below.

Journal schema support and a verified journal adapter remain the implementation
gate. See `JOURNAL_PERSISTENCE_SCHEMA_REVIEW.md` and
`HEALTH_PERSISTENCE_AUDIT_AND_PLAN.md` for the source inspection and stages A–G.

## B/C. Minimum additive schema and migration identity

New proposal:

`supabase/migrations/20261025120000_health_observation_persistence.sql`

This single transactional file covers the two related schema additions:

1. Add nullable `entry_time time(6) without time zone` and `entry_is_utc boolean`
   to existing `public.journal_entries`. Require both values to be null together
   or populated together; reject PostgreSQL's `24:00:00` time representation,
   which the Flutter clock model cannot round-trip. Existing rows receive null,
   without a default, timestamp inference or data backfill. Existing journal RLS,
   table grants, audit trigger, content and versions are not changed.
2. Create `public.health_observations`: one row for each symptom, bleeding,
   spotting, discharge or wellness observation. No uniqueness by date, type,
   title or observation time. Existing `period_logs` and `wellness_logs` remain
   unchanged and keep their distinct interval/daily-summary semantics.

The new version is a valid, distinct 14-digit timestamp and sorts after the
repository's existing prefixes. **Both existing migrations use the same version
prefix `20261025`**, despite different suffixes. The new file does not introduce
another collision or repair the old one. This is a deployment preflight blocker:
an authorized administrator must compare actual migration history with both files
and decide how to reconcile legacy history. Do not rename deployed files, invent
new applied-history entries, run reset/push/repair commands, or infer deployment
order in this task. The earlier audit's two proposed filenames were design
placeholders; the single filename above is the actual new proposal.

Prerequisites are the existing `journal_entries` table, `auth.users`, `auth.uid()`,
Supabase roles and `public.set_record_metadata()`. It intentionally has no
`IF NOT EXISTS` clauses to hide unexpected drift: an inconsistent target should
fail the transaction and be reviewed, rather than silently skip incompatible
objects. The live schema/history were not inspected.

## D. Ownership, grants, metadata and indexes

The new table enables RLS with four authenticated owner policies:

| Operation | Required ownership expression |
| --- | --- |
| SELECT | USING `(select auth.uid()) = user_id` |
| INSERT | WITH CHECK `(select auth.uid()) = user_id` |
| UPDATE | Both USING and WITH CHECK the same owner expression |
| DELETE | USING the same owner expression |

All table privileges are first revoked from PUBLIC, anon and authenticated to
remove default broad grants. Authenticated users receive SELECT/DELETE and
column-scoped INSERT/UPDATE. `user_id` is excluded from both write grants and
comes only from `auth.uid()`; INSERT may supply a stable UUID `id`, UPDATE may
not change it. Clients cannot write created_at, updated_at or version. No
anonymous-role access, service-role credential, public read policy or SECURITY
DEFINER function is introduced. These claims describe SQL intent, not executed
permission tests. Table owners/admin roles can bypass normal RLS; verify using
the actual authenticated role rather than an administrator session.

The new table uses the existing server metadata trigger: insert version 1,
preserved creation timestamp, incremented update version and current modification
timestamp. Two ordinary, non-unique B-tree indexes support owner-scoped ordered
pagination: `(user_id, observation_date DESC, observation_time DESC, id DESC)`
and the same key with `kind` after owner. They permit multiple identical-time
observations. The UUID primary key distinguishes records and supports create
retry recovery. No realtime publication or existing-table grants change.

FK account deletion cascades to the account's observations, consistently with
existing private tables. **Signing out must never issue DELETE**; clearing the
local session is not account deletion.

## E. Compatibility mapping

| Flutter field | Proposed database mapping | Preservation rule |
| --- | --- | --- |
| `HealthEntry.id` | Observation/J UUID ID | New authenticated drafts allocate one UUID before the first write; retries reuse it. Existing `demo-N` IDs remain local and are not relabeled/imported. |
| Verified session user | Observation `user_id` default auth.uid(); existing J owner contract | New observation clients omit owner entirely. Read/update/delete also filter the fixed verified owner in addition to RLS. |
| `type` | `kind`, five non-journal enum values | Journal stays exclusively in J. Preserve source-table provenance in the facade; detect duplicate IDs across sources rather than overwriting one entry with another. |
| `title` | `title text` | Preserve exact text. Bleeding intensity and wellness subtype are currently title-based; do not reconstruct arbitrary titles or map unspecified bleeding to light. |
| `note` | Observation `notes`; J `body` | Exact saved text, including empty non-journal notes; observation length limit 2,000 matches current repository. Existing J body constraints are unchanged. No JSON wrapper hidden in note/body. |
| `when` year/month/day | Observation `observation_date`; J `entry_date` | Nominal date without conversion through UTC. Observation schema supports years 1–9999, encompassing the UI's 2000–2100 picker; reject invalid/out-of-range input explicitly. |
| `when` clock components | Observation `observation_time`; J `entry_time` | Full seconds/microseconds, not the minute-only export string. J null remains explicitly unknown, not midnight. |
| `when.isUtc` | `observation_is_utc`; J `entry_is_utc` | Preserves representation metadata; does not establish a historical offset or IANA zone. |
| `zone` | Observation `timezone_label`; J `timezone` | Exact declared label. `Device local` cannot determine an actual historical observation instant. New event title/zone text has no arbitrary smaller maximum than the Flutter model. J's existing max 100 timezone/200 title limits still apply. |
| `severity` | `severity` enum | unspecified/mild/moderate/severe; never coerce to period_logs pain_level 0–10. |
| `mood` | `mood_category` nullable enum | Six nominal values, not wellness_logs 1–5. Null remains unrecorded. Preserve explicit legacy prefix text as well as any typed mood; do not infer mood from free text. |
| `periodStart`, `periodEnd` | Nullable `period_start`, `period_end` | Preserve null/false/true. Derive cycles with current CycleHistory; spotting is never converted to a period start. |
| `tracking == null` | All tracking columns null | Absent object is not a default amount. |
| `tracking.amount` | `tracking_amount` | light/moderate/heavy. A present object requires an amount, enforced by the coherence constraint. |
| `tracking.color` | `tracking_color` | Optional exact text, up to 80; empty string and null remain distinct. |
| `tracking.consistency` | `tracking_consistency` | Same rule. |
| `tracking.odorChange` | `tracking_odor_change` | yes/no/unsure/null are four states. |
| `tracking.irritation` | `tracking_irritation` | Same four-state rule. |
| `savedAt` on new cloud saves | Confirmed returned `updated_at` | Define cloud successful-save time explicitly as the server modification instant. Do not import/reinterpret an old local save instant or use audit time as observation time. |
| `version` | Trigger-managed bigint | Compare old version in UPDATE/DELETE filters; adopt returned version only after confirmed write. Initial insert is version 1. |

Metadata columns remain available across non-journal kinds rather than being
discarded or prohibited based solely on kind. The coherence constraint rejects
tracking child fields without a tracking amount; such an object cannot be
represented by current `TrackingDetails`. Generic journal entries with non-default
severity/tracking/period/mood metadata still lack a journal-table representation;
future adapters must explicitly reject those unsupported combinations or obtain
additional approved schema support, never silently drop them. The current journal
editor does not collect those fields.

Current Energy/Stress/Sleep entries have a subtype title and prose, not a numeric
answer. Preserve those fields; never extract numbers or synthesize wellness_logs
ratings/hours. The transient check-in selection, breathing timer and merge game
must not trigger automatic health writes. Exact period intervals/daily numeric
summaries remain in existing tables only when a future explicit feature actually
collects those entities. Do not dual-write them from raw events in this scope.

PostgreSQL text cannot represent embedded NUL/invalid text encodings. Future
adapters must surface a safe validation error and preserve the draft rather than
silently stripping characters. Server and Dart string-length checks differ for
some Unicode sequences; retain current Flutter validation as well as DB checks.

## Safe implementation sequence (not implemented)

1. Resolve migration-history/deployment drift and approve nullable legacy journal
   rendering. Review/apply the proposal only through a separately authorized
   deployment workflow. Complete journal mapping/CRUD and its tests first.
2. Generalize the narrow records interface and concrete `DemoSession.records`
   type; add load/refresh/failure state, UUID allocation and expected-version
   delete. Keep demo reset/failure controls in the demo implementation. Preserve
   the journal adapter if one is subsequently supplied rather than replacing it.
3. Add a typed observation adapter and a shared authenticated facade combining J
   and observation rows. Use the initialized official SDK with the current user
   session, no second auth store or invented backend endpoint. Stage coherent
   refresh results before notification; a refresh must not resurrect a confirmed
   deletion or overwrite a newer save.
4. Enable bleeding/cycle, then symptoms/spotting/discharge, then wellbeing. Keep
   raw markers and current cycle derivation. All consumers remain on the same
   repository, so Journal/Timeline/Home/Insights do not fetch separate caches.
5. Keep demo sessions fully local. Login loads only that account's data; there is
   no local/demo import. Owner or auth-mode changes invalidate operation/load
   generations, unsubscribe and clear sensitive caches; late results are ignored.
   Token refresh failure denies access and never falls back to unscoped reads.
6. Gate creates on explicit save and prevent overlaps. After timeout, reconcile
   the fixed UUID under the same owner before any retry; duplicate-key errors
   alone do not establish successful saving. No unconditional upsert.
7. Update/delete with owner + UUID + expected old version and verify exactly one
   returned row. No version increment in client payloads. Zero rows yields a safe
   stale/deleted/access failure and retains unsaved text. Keep delete confirmation.

The metadata trigger **does not force clients to provide a version predicate**.
Conditional-write correctness must be enforced by the repository and its tests.
If server-enforced mandatory compare-and-swap is later required for every client,
design a separately reviewed RPC/privilege boundary; do not claim this migration
alone prevents an owner from issuing an unconditional update. SQL uniqueness
also does not prevent an intentional duplicate with a newly allocated UUID.

Exact proposed source/test files and per-stage acceptance criteria remain in
`HEALTH_PERSISTENCE_AUDIT_AND_PLAN.md`, sections Gate 0 and A–G. This task does
not change those production files or enable persistence.

## F. Offline verification performed

New test file:
`supabase/tests/test_health_observation_schema_contract.py`

Command:

```powershell
python -m pytest supabase/tests/test_health_observation_schema_contract.py -q -p no:cacheprovider
```

Result: **22 passed, 0 failed (latest run: 0.08 seconds)**. An initial test-regex issue with
the parenthesized time precision was corrected before this final passing run.
Caching is disabled for a read-only test run; tests do not import database or
network clients. The checks compare SQL enum sets to actual Dart enums, ensure
every model column is present, protect existing migration text with normalized
SHA-256 fingerprints, check timestamp/version naming, nullable journal fields,
transaction/additive targets, privileges, owner predicates, metadata hooks,
tracking coherence and non-unique pagination indexes.

These are **static source-contract checks**, not PostgreSQL parsing, migration
execution, privilege behavior, constraint enforcement or proven RLS isolation.
PostgreSQL/psql/Docker and a PostgreSQL parser were not available in this session.
No DB test was executed. No production backend code changed, so backend tests
were not needed. No new Flutter test result is claimed for this task.

### Required verification before any approved deployment

1. **History/preflight:** administrator verifies both legacy migration contents,
   actual applied history/order, SDK schema exposure and defaults, existing journal
   constraints/rows, metadata trigger, roles and grants. Resolve the duplicate
   legacy version identifiers without editing deployed migration source. Confirm
   the new filename has not been applied under different content elsewhere.
2. **Disposable PostgreSQL/Supabase environment:** separately authorize a local or
   staging environment, not production. Reproduce verified prerequisites and
   existing date-only journals, then apply this proposal once. Confirm syntax,
   atomic failure rollback and no old-row/title/body/version/audit-time changes.
3. **Privileges/RLS:** under two actual authenticated identities A/B and anonymous
   role, test SELECT, INSERT, UPDATE, DELETE, attempted foreign owner injection,
   ID/owner mutation, audit/version spoofing, missing auth and anonymous denial.
   Test through normal user roles, not postgres/service_role. Record grants and
   row visibility without logging tokens or health bodies. New table INSERT must
   omit user_id and derive it from auth.uid(). Old journal policies are tested as
   deployed, not assumed from new-table results.
4. **Data constraints:** test all kinds/enums, null/false/unsure, tracking absent
   versus populated, empty notes/text, Unicode, limits, microseconds, 24:00:00 and
   invalid dates, unknown legacy journal time, paired time/flag, multiple identical
   timestamp rows and metadata increment rules. Rejected writes must be atomic.
5. **Concurrency:** two clients edit the same version; exactly one conditional
   update succeeds. Stale delete affects zero rows. Reconcile timeout/create by
   UUID; ensure a changed payload is not treated as a confirmed duplicate. Test
   refresh/write races and logout-A/login-B while A requests are pending.
6. **Flutter integration gate:** mocked SDK CRUD/mapper tests, failed-save text
   retention, auth refresh failures, demo zero-network assertions, shared-view
   consistency, then analyzer and full regression suite. Physical-device/restart
   tests use disposable accounts and fictional data only after authorization.

## Rollback plan without data loss

- **This preparation:** nothing was applied. The proposal and tests are new local
  artifacts only. Preserve all prior staged/uncommitted work.
- **Migration transaction failure:** PostgreSQL should roll back this transaction
  completely; confirm that behavior in the disposable environment before approval.
  Do not run repair/reset/reapply blindly after an ambiguous deployment outcome.
- **Successful migration, application rollback:** disable new cloud writes via
  rollout configuration or revert only the newly deployed repository wiring.
  Retain the additive table, journal columns, owner policies and records. Existing
  applications can still use old columns; old clients may leave time unknown for
  new rows. Treat that as date-only instead of fabricating a time.
- **After any writes:** prefer a reviewed roll-forward fix. Do not DROP/TRUNCATE
  the observation table, drop populated journal columns, reverse-backfill old
  timestamps or merge remote data into local demo stores. A destructive down
  migration would lose user data and is not provided.
- **Before deployment:** obtain an authorized encrypted backup/snapshot and
  verify restoration in isolation. If restoration is ever needed, pause writers,
  preserve post-snapshot writes and reconcile in a separate environment first;
  restoring an old snapshot over new records is not a lossless rollback.

## G. Remaining blockers

Journal CRUD is absent; historical journal time is unknown; existing migration
versions collide; live schema/history and actual owner isolation are unverified;
PostgreSQL execution/permission tests remain pending. Repository lifecycle,
versioned deletion, safe SDK-error mapping and coherent cross-source refreshes
are planned, not implemented. No schema approval/application or Flutter change
is implied by the presence of the migration in the migrations directory.
