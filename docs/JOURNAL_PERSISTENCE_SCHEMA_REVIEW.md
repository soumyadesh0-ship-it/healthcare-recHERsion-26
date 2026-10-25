# Journal persistence: blocked before implementation

Reviewed on 2026-10-25 on `integration/frontend-backend`. The pending, staged
merge-resolution work was preserved. No persistence code, migration, RLS policy
or backend code was changed, and no live database request was made.

The request explicitly requires stopping before persistence if the database cannot
represent current journals losslessly. That condition applies: `HealthEntry.when`
contains a user-selected date **and time**, while `journal_entries.entry_date`
contains a date only. Substituting midnight or a server audit timestamp would
discard information or change its meaning.

## Inspected architecture

- `lib/data/records.dart`: journals are `HealthEntry` values in the shared
  `DemoRecordsRepository`. IDs are `demo-N`; `when` is a wall-clock value paired
  with an opaque timezone label. `savedAt` is a separate successful-save instant.
  Successful edits require the previous version plus one; successful writes
  notify listeners. Entries sort by `when`; calendar selection also uses `savedAt`.
- `lib/features/logging/editor.dart`: journal title/body, date and time are
  editable. Title input is limited to 80 characters, body to 2,000. Blank titles
  become `Journal entry`. The existing editor trims title/body before saving.
  Failed writes retain input, duplicate saves are guarded by `busy`, and deletion
  requires confirmation. The current repository also accepts arbitrary string
  IDs and titles outside the editor's UI limits.
- `lib/app/session.dart`: the concrete demo repository is shared through
  `SessionScope`; it forwards record notifications to all dependent screens.
- `lib/features/journal/journal.dart`: wraps a journal-filtered Timeline.
  Timeline groups by observation date; Home uses the same repository for recent
  records. Insights derives coverage from that same collection, without clinical
  inference. Independent screen caches would break this consistency.
- `lib/data/auth_service.dart` and `lib/app/auth_root.dart`: verified account,
  demo and recovery modes are separated; account/mode changes create fresh local
  sessions and dispose previous sessions. Authenticated journals are still local.
- `lib/data/api_client.dart` and `service/main.py`: existing business endpoints
  are chat and PCOS survey submission. There is no journal CRUD endpoint.
- Both SQL migrations were checked. The initial journal table has date,
  timezone, title/body, server audit timestamps and version, but no observation
  time. The metadata trigger forces insert version 1 and increments on updates.
- Existing record/widget tests cover CRUD notification, stale edits, journal
  validation, failed-save text preservation, unsaved text and shared views.

## Proposed field mapping, before implementation

| Flutter value | Database representation | Rule |
| --- | --- | --- |
| New authenticated journal ID | `id uuid` | Generate a stable UUID before the first request; retain it on retries/edits. Do not relabel or upload existing `demo-N` records. |
| Current verified account | `user_id uuid` | Derive from verified SDK user state; use the existing `auth.uid()` default/RLS and explicit owner filters. Never accept ownership from journal input. |
| `when` date components | `entry_date date` | Preserve the nominal year/month/day, without UTC conversion. |
| `when` time components | **Missing** | Requires a dedicated observation-time column; preserve seconds and microseconds too. |
| `when.isUtc` | **Missing representation flag** | Preserve separately if round-tripping the exact Dart UTC/local representation. The opaque zone label cannot reliably determine it. |
| `zone` | `timezone text` | Preserve the exact label. `Device local` is not an IANA timezone or a known historical UTC offset. Never infer one. |
| `title` | `title text` | Preserve saved text; UI limit 80 fits database limit 200. Reject incompatible oversized values rather than truncating them. |
| `note` | `body text` | Preserve saved text; UI limit 2,000 fits database limit 50,000. No JSON envelope hidden in body or timezone. |
| `version` | `version bigint` | Use the server-returned version. Update/delete with ID, owner and expected-version predicates; zero affected rows is a conflict/access failure, not success. |
| `savedAt` for new cloud writes | Returned `updated_at` | Use the confirmed server save instant for cloud records; never substitute it for observation time. Existing local save instants are not migrated. |
| Server audit metadata | `created_at`, `updated_at` | Keep server-controlled and separate from editable observation date/time. |
| `type` | Journal adapter invariant | Only journal records enter this adapter. Other health entry types remain in their existing stores. |

Generic `HealthEntry` severity/mood/period/tracking metadata is not collected by
the journal editor. Non-default values on a journal supplied through other means
must be rejected explicitly or given approved schema support, never discarded.
Existing arbitrary IDs, oversized titles and local version history cannot simply
be imported into this table: UUID constraints, length checks and the insert
trigger would change or reject them. No import is authorized or planned.

## Schema change requiring approval

Proposed additive columns on `public.journal_entries`:

1. `entry_time time(6) without time zone`: observation wall-clock time, paired
   with the existing `entry_date` and `timezone`. Six fractional digits preserve
   Dart microseconds. Do not use `timestamptz` for an observation whose historical
   offset is unknown.
2. `entry_is_utc boolean`: original Dart UTC/local representation, separate from
   the user-declared timezone label. For new entries, save `when.isUtc` explicitly.

Neither column should receive an invented default for existing rows. Existing
date-only rows have unknown time; they must remain explicitly date-only or be
completed using a confirmed source before enforcing `NOT NULL`. A future adapter
must distinguish unknown time from midnight, with an explicit UI/model decision
for those legacy rows. `created_at` cannot supply a missing observation time.

This is a proposal only. No SQL migration was created or applied. The live schema
was not queried; findings refer to the repository's supplied migrations. If the
live database already has additional observation-time fields, their verified
definition would need review before proceeding.

## Planned access and lifecycle after schema approval

Direct authenticated `supabase_flutter` CRUD is the smallest consistent choice:
it uses the existing SDK session and journal RLS without inventing FastAPI routes
or modifying production backend code. Use only user-level SDK access. RLS still
needs actual two-user verification; client owner filters are additional scoping,
not proof of isolation.

A separate adapter should feed the shared records facade, with journal operations
routed to cloud storage and other record types left local. The concrete session
repository typing will need a narrow generalization; a second journal-only UI
store must not bypass Home/Timeline/Insights notifications.

Load only the current user's records, validate field mappings, publish only
confirmed writes, and keep pending text separate from saved data. Serialize
duplicate operations, use expected-version predicates for edits/deletes, and
handle ambiguous network outcomes without blind write retries. On logout/account
change, invalidate in-flight generations and clear authenticated caches without
remote deletion. Demo records must never enter the authenticated adapter.

## Verification and remaining work

No new automated tests were run: implementation stopped at the required schema
gate, and only this review document was added. The last completed merge check
reported a clean analyzer and 219 passing Flutter tests; those are prior results,
not validation of journal cloud persistence.

After schema approval, implement mocked CRUD/mapping/concurrency/session/UI tests,
run analysis and the full Flutter suite, and separately verify actual two-user
RLS and physical-device behavior with disposable accounts and fictional entries.
No claim of remote journal saving or live isolation is made.
