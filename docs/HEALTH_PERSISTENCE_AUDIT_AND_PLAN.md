# Health persistence audit and staged implementation plan

Audit date: 2026-10-25. Branch: `integration/frontend-backend`.
This document is the only new task artifact. Existing staged merge resolutions
and the untracked journal schema review are preserved. No Flutter/backend code,
SQL file, RLS policy, branch or data was changed by this audit. No live Supabase
requests were made. Schema findings describe repository migrations, not a live
database inspection.

## 1. Journal verification: incomplete

The current checkout does **not** contain completed journal cloud persistence.
Searching all application code found no `journal_entries` access or journal
persistence adapter. The only health record implementation is
`DemoRecordsRepository` in `lib/data/records.dart`.

| Requested check | Finding and evidence |
| --- | --- |
| Authenticated journal CRUD | Not implemented. `lib/app/auth_root.dart` constructs `DemoRecordsRepository(sample: false)` for both account and demo boundaries. SDK access in the auth services is authentication, not journal CRUD. |
| Demo remains local | Yes in the inspected production root. Demo uses a separate records instance; no journal network path exists. |
| Journal/Timeline/Home/Insights consistency | Local records share `SessionScope.records`: Journal wraps `TimelinePage(onlyType: journal)`; Timeline groups by `when`; Home reads recent records; Insights computes `Coverage` from the same list. Cloud consistency cannot be verified because there is no cloud repository. |
| Account switching | `AuthenticationRoot` keys boundaries by `account:<userId>` or demo, creates a fresh session, and disposes the previous session after widgets detach. This prevents ordinary reuse of the displayed list across boundaries. It is not verification of cloud owner filtering or real two-user RLS. |
| Sensitive cache clearing / pending work | There is no authenticated cloud cache. The demo repository inherits notifier disposal without explicitly clearing its list or invalidating delayed writes. Cloud persistence must add both, rather than treating existing disposal as sufficient. |
| Existing features | Analyzer/tests assess current local features and auth/PCOS integration. Passing local tests does not establish remote journal durability. |

The earlier schema blocker remains: journals have editable wall-clock date/time,
but the table has only `entry_date`. `created_at`/`updated_at` are server audit
instants, not observation times. See `JOURNAL_PERSISTENCE_SCHEMA_REVIEW.md` for
the prior mapping review. Journal completion and its verification are a hard
gate before implementing the other persistence stages below.

## 2. Current Flutter contracts

Paths below are relative to `Auracare_mobile_app/auracare_mobile_app/` unless a
repository-root path is shown.

- `lib/data/records.dart`: `HealthEntry` holds `id`, `type`, `title`, `note`,
  `when`, `zone`, `severity`, `version`, `mood`, `savedAt`, nullable `periodStart`
  and `periodEnd`, and optional `TrackingDetails`. Tracking details hold required
  amount plus optional color, consistency, odor-change and irritation answers.
- Types are symptom, journal, bleeding, wellness, spotting and discharge. The
  repository retains multiple entries per day and per type. Calendar display
  selecting one representative does not authorize deleting the other records.
- Severity is categorical: unspecified/mild/moderate/severe. Recorded moods are
  happy/calm/sad/anxious/tired/energetic, with null meaning unrecorded.
  `RecordedMood.fromLabel` and the explicit legacy `Feeling: <mood>.` prefix
  provide a limited compatibility reader; arbitrary prose is never classified.
- `when` stores nominal wall-clock components with an opaque zone label. Device
  local is not a historical IANA zone/offset. Existing exports format only
  minutes, but the in-memory model may contain seconds/microseconds; new storage
  must not use the export string as a full-fidelity timestamp codec.
  A true historical observation instant cannot generally be recovered from that
  label. Preserve nominal components; do not claim the representation flag alone
  supplies an actual historical timezone offset. Capturing IANA/offset context
  prospectively would require a separate explicit model/UX decision.
- `savedAt` is the successful-save instant, separate from the observation time.
  Records sort by `when`; `RecordedDay` uses save time and ID for selection ties.
- New local IDs are `demo-N`. Save requires the prior version plus one for edits;
  successful writes set UTC `savedAt` and notify listeners. Local delete has no
  expected-version argument. `RecordsRepository` exposes only entries/save/delete;
  the session and editor additionally depend on demo-only newId/reset/failure controls.
- `lib/data/cycles.dart`: periods are derived from bleeding observations with
  explicit start/end flags. Starts are grouped by calendar date; missing ends
  remain unknown; start-to-start intervals form cycle lengths. Spotting does not
  start a period. Estimates are derived, not confirmed observations or persisted
  diagnoses. Multiple unfinished/inconsistent markers can exist in raw input.
- `lib/features/logging/editor.dart`: wellness choices Mood/Energy/Stress/Sleep
  are titles. Only Mood has a structured category field. Energy, Stress and Sleep
  currently have free-text notes, not numeric ratings/hours. The wellbeing
  check-in's selected mood/feedback is widget-local and is not itself an automatic
  record write. Breathing/game activity is not a health-log submission.
- `lib/data/services.dart`: appointment summaries read exact selected source
  entries and their versions; the PCOS service has its own explicit authenticated
  submission path. Neither is a journal or generic-health persistence service.

## 3. Field-by-field compatibility matrix

P = `public.period_logs`, W = `public.wellness_logs`, J =
`public.journal_entries`, as defined in the supplied migrations.

| Flutter field/capability | P | W | J | Loss or safe mapping decision |
| --- | --- | --- | --- | --- |
| Multiple observations/day | Unique `(user_id,start_date)`; one open interval/user | Unique `(user_id,log_date)` | Multiple rows/date allowed | P/W cannot be the authoritative event store; same-day upsert would overwrite observations. |
| `type` discriminator | Implicit period interval | Implicit daily wellness | Implicit journal | No generic symptom/spotting/discharge identity. Never force all types into notes. |
| `title` | No title | No title | Nullable text, max 200 | UI journal title max 80 fits J; generic repository permits longer titles. Reject incompatible data, never truncate. Preserve symptom names and wellness subtype explicitly. |
| `note` | `notes`, max 10,000 | `notes`, max 10,000 | Required `body`, 1–50,000 | UI notes max 2,000 fit all lengths; generic health notes may be empty, so J is not a generic notes bucket. No hidden JSON envelope in body. |
| Symptom type | None | None | None | Headache/Cramps/Fatigue/Bloating/Other symptom and original title need an event representation. |
| `severity` enum | `pain_level` 0–10 | None | None | Severity is not a validated pain score. No numeric conversion is justified. Unspecified is not zero pain. |
| Bleeding intensity | `flow`: spotting/light/medium/heavy | None | None | Flutter has unspecified/light/moderate/heavy encoded by exact bleeding titles. Moderate→medium is only a vocabulary mapping on a deliberately defined interval summary, not an event round-trip; unspecified must not become light. |
| `periodStart`, `periodEnd` | Start/end date of interval | None | None | Nullable event flags cannot round-trip through one interval row, especially after edits, missing boundaries or repeated observations. Null and false must remain distinct. |
| Spotting type/amount | A spotting flow value only | None | None | A separate spotting event with light/moderate/heavy amount is not equivalent to a period interval or period start. |
| Discharge amount | None | None | None | Requires enum storage, separate from bleeding intensity. |
| Tracking `color` | None | None | None | Exact optional text, UI max 80; cannot be discarded. |
| Tracking `consistency` | None | None | None | Exact optional text, UI max 80; cannot be discarded. |
| `odorChange` | None | None | None | yes/no/unsure plus null-unrecorded requires four distinct states. |
| `irritation` | None | None | None | Same four states; unsure must not become false/null. |
| Tracking object presence | None | None | None | Absent tracking object differs from a present object with its required amount and optional unanswered fields. |
| Six mood categories | None | Integer 1–5 | None | Six nominal categories cannot be mapped losslessly to five ordered numbers. Never invent a clinical ordering. |
| Energy/Stress | None | Integers 1–5 | None | Current Flutter supplies category title plus prose; there is no numeric answer to send. Retain prose and subtype. |
| Sleep | None | `sleep_hours numeric(4,2)` | None | Do not extract hours from arbitrary text or round notes into a number. Structured numeric sleep capture would be a separate approved feature. |
| Exact observation `when` | Dates only | Date only | Date only | All three lose time. Audit timestamps cannot replace it. Need microsecond wall-clock time and explicit UTC/local representation. |
| `zone` | Text max 100 | Text max 100 | Text max 100 | Existing UI labels fit; retain exact label, reject oversize input rather than truncate. No invented historical offset. |
| `id` | UUID | UUID | UUID | Generate stable UUIDs only for new authenticated writes. Do not rewrite `demo-N` IDs or silently import local records. |
| Account ownership | `user_id`, default `auth.uid()` | Same | Same | Owner RLS is declared; only real two-user checks can verify deployment. No caller-supplied arbitrary owner. |
| `version` | Server bigint | Server bigint | Server bigint | Insert trigger forces 1; update increments. Use expected-version conditional writes and confirmed returned versions. Never import arbitrary local versions as if preserved. |
| `savedAt` | `updated_at` is server instant | Same | Same | For new cloud records, define savedAt as confirmed server modification time. Do not silently reinterpret an existing local historical save instant or observation time. |
| Editing/deleting | CRUD declared by RLS | Same | Same | Atomic version filters are still required. Existing Flutter `delete(id)` lacks a version and must be narrowly extended. |
| Concurrent changes | Trigger increments version | Same | Same | Trigger alone does not prevent last-write-wins. Require conditional ID+owner+expected-version update/delete and a nonempty returned result. |

`period_logs` is suitable for explicitly represented period intervals, and
`wellness_logs` for explicitly represented daily numeric summaries. Neither is
equivalent to the current event model. Existing rows in those tables must not be
automatically expanded into fabricated source observations or deleted. Journals
should remain in J after the observation-time compatibility gate is resolved.

## 4. Proposed additive database changes — design only

No SQL file is created or edited in this audit. Suggested future migration names
below are proposals, not authorization to apply them. Existing deployed migrations
must remain untouched.

### Journal prerequisite

Proposed `supabase/migrations/20261025000100_journal_observation_time.sql`:
add nullable `entry_time time(6) without time zone` and `entry_is_utc boolean` to
J. New cloud writes supply both. Existing date-only rows remain explicitly
date-only/unknown-time until a confirmed source is available. Do not backfill
midnight, infer time from audit timestamps, or impose NOT NULL before a legacy
row display/model strategy is approved. Keep current owner policies unchanged.

### Raw non-journal observation store

Proposed `supabase/migrations/20261025000200_health_observations.sql` creates
`public.health_observations`, with one row per observation and no unique-per-day
constraint. Proposed fields:

| Column | Proposed type / purpose |
| --- | --- |
| `id` | UUID primary key; stable client-generated ID for new authenticated operations |
| `user_id` | UUID NOT NULL, default auth.uid(), FK auth.users; verified owner |
| `kind` | Text checked against symptom/bleeding/spotting/discharge/wellness |
| `title`, `notes` | Text, exact saved model values; nonblank title, notes up to current repository limit 2,000; no arbitrary new title truncation |
| `observation_date` | Date NOT NULL, nominal calendar components |
| `observation_time` | Time(6) without time zone, supplied for new observations |
| `observation_is_utc` | Boolean, preserves Dart UTC/local representation |
| `timezone_label` | Text, exact declared label; unknown offset remains unknown |
| `severity` | Text enum unspecified/mild/moderate/severe, preserved without numeric coercion |
| `mood_category` | Nullable text enum happy/calm/sad/anxious/tired/energetic |
| `period_start`, `period_end` | Nullable booleans, preserve unrecorded/false/true |
| `tracking_amount` | Nullable light/moderate/heavy; null means no TrackingDetails object |
| `tracking_color`, `tracking_consistency` | Nullable text, up to current limit 80; preserve null separately from an explicitly empty model string |
| `tracking_odor_change`, `tracking_irritation` | Nullable yes/no/unsure text enums |
| `created_at`, `updated_at`, `version` | Server metadata with the existing metadata trigger semantics |

Validate supported enum values and tracking-object coherence without silently
dropping non-default model metadata. Preserve exact titles: bleeding flow and
wellness subtype are currently title-based. A future stable subtype column may
be added, but must not replace the original title or invent a new mapping.
No global uniqueness on timestamp, title or `(owner,date,kind)`: repeated entries
are valid. Add owner/date/time/ID indexes for scoped pagination. Keep UUID and
timestamp codecs independent of the lossy current export format.

For the new table only, propose authenticated owner SELECT/INSERT/UPDATE/DELETE
policies with both USING and WITH CHECK ownership, no anonymous access, appropriate
grants and a metadata trigger. Owner transfer must be impossible: forbid updates
to owner/ID through column grants or a targeted immutable-owner trigger. Do not
change existing table policies as part of this work. Validate all constraints,
permissions and policy behavior in isolated database tests before deployment.

Retain P/W unchanged. Do not dual-write raw events and daily/interval summaries.
The existing UI derives cycle history from raw bleeding markers. If a later
feature intentionally writes P/W summaries, define deterministic provenance and
transactional ownership-safe reconciliation first; it is outside this roadmap's
initial event-persistence scope. No confirmed cycle or predicted fertility window
should be inferred as a persisted user observation.

## 5. Recommended repository architecture

Use direct official authenticated Supabase SDK access, consistently for journal
and non-journal events. No journal/event FastAPI routes exist; do not invent them.
Keep PCOS/FastAPI unchanged. Wrap the already initialized SDK; no service-role
key, second auth store, manual token caching or per-screen SDK calls.

Keep `HealthEntry`, shared session scope, screen consumers and demo implementation.
Generalize the narrow `RecordsRepository` contract to include ID allocation,
load/refresh state, safe failures and expected-version deletion, with explicit
demo-only controls outside the cloud interface. Add typed table adapters and an
authenticated records facade that combines journal and health observations into
one canonical, source-aware snapshot. Route each operation by type; never write
one logical entry to two tables. Preserve an existing working journal adapter if
one is subsequently supplied; do not replace it to implement the other adapters.

The authenticated facade owns a fixed verified user ID and monotonically changing
session/load generations. Refuse operations in demo/recovery/signed-out states;
capture generation before await and recheck it before publishing results. On
logout/owner change, clear lists, errors containing private context and pending
write references; unsubscribe and invalidate operations. Cancellation alone is
not enough: a database operation may already have completed. Never delete remote
rows on logout. Do not fall back to demo data or an unscoped read on auth failure.

Use owner-scoped pagination and deterministic ordering. Load both sources into a
staged snapshot; keep the prior confirmed snapshot or show an explicit partial
state if one source fails. A slow refresh must not overwrite a newer local
confirmed write; serialize refresh/write publication or reconcile versions and
deletion acknowledgments under a repository generation. Notify the session only
after coherent confirmed changes. All views derive from that same snapshot.

For create, allocate an ID once per editor draft, reject overlapping submissions,
and use plain insert. After an ambiguous timeout, read that ID under the same
owner before retrying; never use unconditional upsert. A duplicate-ID error is
not proof that the requested content was saved—reconcile the row and surface
conflicts. Update/delete must use owner+ID+expected-version predicates and verify
affected rows. A zero-row outcome may be stale/deleted/unauthorized; expose a
safe conflict message without leaking another owner's record existence. Deletes
require the existing confirmation dialog. No automatic destructive retries.

Keep unsaved editor controllers separate from confirmed caches. Map SDK errors
to fixed local errors before rendering; the editor currently displays
`e.toString()`, which must not receive raw SDK exceptions. Loading, empty, partial,
offline and failed states must remain distinct. Reuse current components and
layout; adjust only necessary status and save-label wording. Cloud writes must
be disclosed, with no automatic upload of pre-existing local or demo data.

## 6. Staged implementation roadmap

All paths are exact proposed targets, not files changed by this audit. Tests are
mocked unless explicitly labeled as a future isolated/live database check.

### Gate 0 — finish and verify journal first

- Files: the proposed journal migration above (approval required), new
  `lib/data/journal_persistence.dart`, `lib/data/journal_mapper.dart`,
  `lib/data/authenticated_records_repository.dart`, and narrow changes to
  `lib/data/records.dart`, `lib/app/session.dart`, `lib/app/auth_root.dart`,
  `lib/features/logging/editor.dart`, `lib/features/journal/journal.dart`.
- Mapping: retain title/body/date/zone/UUID/version, observation time and server
  audit distinction; resolve legacy unknown-time rows without fabricating values.
- Security: verified SDK owner, RLS, scoped CRUD, CAS edits/deletes and logout
  invalidation. No demo upload or new backend endpoint.
- Tests: new `test/journal_persistence_test.dart`,
  `test/journal_mapper_test.dart`, `test/journal_cloud_widget_test.dart` covering
  CRUD, exact timestamps, UUID parsing, ambiguous saves, stale edits/deletes,
  A/B switches, delayed reads/writes, errors and retained text; shared-view tests.
- Acceptance: durable journal code exists and passes mocked tests; live behavior
  remains labeled unverified until separately authorized disposable-account tests.
  No non-journal cloud writes before this gate passes.

### A — approve and add the event schema

- Files: proposed `20261025000200_health_observations.sql` above; proposed
  `supabase/tests/health_observations_isolation.sql` and
  `supabase/tests/journal_timestamp_compatibility.sql` for later isolated execution.
- Mapping: all raw fields in the column table; no per-day uniqueness, no numeric
  mood/severity guessing; old P/W/J rows remain intact.
- Security: owner policies/grants on the new table, immutable owner/ID, correct
  metadata trigger, FK and permitted-column tests. Existing RLS unchanged.
- Tests: enum/null/length/timestamp/uniqueness/metadata constraints; A cannot read,
  create for, update, delete, transfer or reference B's rows; anonymous/recovery
  access assumptions tested separately against actual auth behavior.
- Acceptance: reviewed additive migration and isolated tests demonstrate lossless
  representation and owner-only access. Application of SQL requires separate approval.

### B — authenticated mapping and repository

- Files: new `lib/data/health_observation_mapper.dart`,
  `lib/data/health_observation_persistence.dart`; extend the Gate 0
  `lib/data/authenticated_records_repository.dart`; adjust
  `lib/data/records.dart`, `lib/app/session.dart`, `lib/app/auth_root.dart` only
  where necessary. Keep the journal adapter and auth token controller intact.
- Mapping: exact `HealthEntry` round-trip, UUIDs and microsecond wall clocks,
  optional tracking object and null/false/unsure distinctions; maintain journal
  routing and local stores for not-yet-enabled types during staged rollout.
- Security: fixed verified owner; scoped paginated reads; auth/session generations;
  safe exceptions and compare-and-swap updates/deletes.
- Tests: new `test/health_observation_mapper_test.dart`,
  `test/authenticated_records_repository_test.dart`,
  `test/health_observation_persistence_test.dart` for all fields, paging, CAS,
  create reconciliation, failed refreshes, out-of-order results, auth expiry and
  A→logout→B with pending A operations.
- Acceptance: one consistent list, no SDK exceptions in UI, no optimistic claims
  of remote success, journal behavior unchanged and demo never calls adapters.

### C — cycle/bleeding records

- Files: event mapper/repository above, `lib/features/logging/editor.dart`,
  `lib/data/cycles.dart`, `lib/features/cycle/cycle.dart`; review
  `lib/core/calendar.dart` and `lib/features/timeline/timeline.dart` consumers.
  Domain/consumer files need modification only if repository integration requires it.
- Mapping: raw bleeding title, severity, note, timestamp/zone and nullable
  start/end markers. Retain `CycleHistory` derivation. Do not collapse multiple
  daily entries, coerce spotting into bleeding or persist estimates as facts.
- Security: standard owner/CAS operations; disabling cycle tracking never deletes
  or hides unrelated records as a persistence side effect.
- Tests: extend `test/phase3_test.dart`, `test/wellbeing_controls_test.dart`;
  add `test/cycle_cloud_test.dart`: unknown/multiple ends, repeated starts,
  unfinished intervals, marker edits/deletes, exact day boundaries and reloads.
- Acceptance: cycle history/coverage after reload matches the same local input;
  record counts/IDs and estimate guardrails are unchanged. P is not auto-written.

### D — symptoms, spotting and discharge

- Files: mapper/repository and `lib/features/logging/editor.dart`; audit
  `lib/features/timeline/timeline.dart` and `lib/core/calendar.dart` display paths.
- Mapping: symptom title and severity; separate spotting/discharge kinds; all
  amount/color/consistency/odor/irritation values, including missing and unsure.
  Do not encode severity as pain or hide structured fields in notes.
- Security: owner-scoped create/read/update/delete; retain existing delete
  confirmation and failure-text preservation; duplicate drafts retain stable IDs.
- Tests: extend `test/unwind_tracking_test.dart`, `test/records_test.dart` and
  mapper tests; new `test/observations_cloud_widget_test.dart` for multiple same-day
  entries, edits/deletes, every enum/null case, offline saves and timestamp zones.
- Acceptance: full round-trip of every current field; distinct icons/filters and
  consultation summaries remain correct; existing sample fixtures never upload.

### E — wellbeing records

- Files: mapper/repository, `lib/features/logging/editor.dart`,
  `lib/features/home/home.dart` only if existing recording hooks require it.
- Mapping: exact Mood/Energy/Stress/Sleep title, note and optional six-category
  mood. Preserve explicit legacy mood prefixes without inferring from prose.
  Check-in-only selections remain transient until an existing explicit save.
  Numeric stress/energy/sleep values are not synthesized; W remains unchanged.
- Security: same owner/session/CAS rules; game/breathing and transient check-ins
  never create remote records automatically.
- Tests: extend `test/wellbeing_controls_test.dart`; new
  `test/wellbeing_cloud_test.dart` covering six moods, null mood, legacy prefixes,
  repeated daily entries, notes-only numeric categories and failed-save retention.
- Acceptance: all wellness entries round-trip; no ordinal mood conversion, no
  dropped repeated records and no new numeric-input UI required.

### F — coherent Home/Timeline/Insights synchronization

- Files: `lib/data/authenticated_records_repository.dart`, `lib/app/session.dart`,
  `lib/features/home/home.dart`, `lib/features/timeline/timeline.dart`,
  `lib/features/insights/insights.dart`, `lib/features/journal/journal.dart`,
  `lib/features/profile/profile.dart` and existing status components in
  `lib/core/widgets.dart` as needed. No redesign or navigation replacement.
- Mapping: all screens read one repository snapshot; keep raw record count,
  covered days, unknown days and symptom-day counts distinct. Do not include
  interval/daily summary rows as duplicate raw events or infer missing-day negatives.
- Security: status messages never contain record bodies/SDK errors; no prior-owner
  snapshot while B loads. Realtime is optional and deferred unless needed; any
  future subscriptions must be owner-scoped and disposed at session boundaries.
- Tests: extend `test/widget_test.dart`, `test/responsive_test.dart`,
  `test/layout_test.dart`, `test/phase3_test.dart`; verify create/edit/delete,
  refresh/write races, partial failures and account changes across all views.
- Acceptance: confirmed write visible everywhere without independent fetching;
  one-source failure is explicitly shown, not treated as healthy empty data.

### G — regression and data-isolation release gate

- Files: all new focused tests above; extend `test/auth_test.dart`,
  `test/upstream_auth_test.dart`, `test/pcos_integration_test.dart` only where
  session changes affect existing contracts; document results in this plan and
  `docs/FLUTTER_AUTHENTICATION.md` / `docs/FLUTTER_NETWORKING.md`.
- Mapping/security: table-driven round-trip for each supported field, valid
  nulls, same-day multiplicity, fixed-owner CRUD, stable IDs, stale updates AND
  deletes, delayed results after logout and timeout reconciliation.
- Tests: `flutter analyze`; all focused persistence/auth tests; full
  `flutter test --concurrency=1 --reporter expanded`; backend tests only if backend
  code changes under a separately approved scope. No network in unit tests.
- Acceptance: clean analyzer, all old/new tests pass, demo has zero cloud calls,
  no credentials/bodies in logs. Separately authorized disposable A/B live checks
  must verify RLS and device restart/recovery before claiming live isolation or
  cross-device persistence. Mocked tests are insufficient proof of those properties.

## 7. Audit validation and blockers

`flutter analyze` completed with **No issues found** (15.3 seconds).
`flutter test --concurrency=1 --reporter expanded` completed with **219 passed,
0 failed** (2 minutes 25 seconds), including existing records, journal editor,
shared views, cycle estimates, spotting/discharge, wellbeing, authentication and
PCOS tests. Tests use mocks/local data; none proves cloud journal CRUD or live RLS.
No backend tests were run because no backend code changed.

Blocking implementation: journal adapter absent; journal observation-time schema
gap; additive event schema and its owner policies require review/approval; current
concrete demo repository contract lacks cloud lifecycle/CAS-delete facilities.
Actual deployed schema and two-user enforcement are unverified and intentionally
not queried in this audit. Preserve the pending local merge rather than trying
to fetch, finish, commit or push it as part of persistence planning.
