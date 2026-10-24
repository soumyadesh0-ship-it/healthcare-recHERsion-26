# Backend

## Verified status

No server, runtime, package manifest, database, migrations, API handlers, authentication, environment configuration or jobs exist. No backend technology is selected. All services below are proposed.

| Domain | Responsibilities |
| --- | --- |
| Identity and consent | Session verification, minimal profile, scoped purpose/recipient grants, withdrawal and account lifecycle |
| Mind & Wellness | Optional check-ins/stress/sleep, private journals, history and reminders |
| Period Tracker | Period intervals/canonical symptoms, correction/deletion, transparent estimates and selected exports |
| PCOS Insights | Selected source references, descriptive rules, coverage, user edits/review and stale-summary handling |
| AI Assistant and reports | Scoped context, genuine sources, private quarantine/extraction, user correction/review, conversations and vendor failures |
| Appointments & Clinic | Sourced directory/verification, request state machine, provider callbacks, approved summary delivery and reminders |
| Women's Health Library | Life-stage taxonomy/search, sources, truthful editorial review/publication and revisions |
| Sisterhood | Separate community profiles/topics/content/index, reactions/bookmarks, reports/blocks, moderation/appeals and anti-spam |
| Privacy and audit | Scoped export/deletion, protected job status, minimal audit events and artifact expiry |

## Request and processing contract

Authenticate → validate input/purpose → authorize ownership/role and required grant → fetch selected fields only → transact → minimal response. Derive owner from session, never client userId. Recheck authorization/consent when queued work executes. Use optimistic versions for edits and idempotency for uploads, bookings, posts and sharing.

Validate bounded text/enums, local dates/timezones, period ordering/overlap, upload type/size and pagination. Use parameterized storage access, safe rendering and stable error codes/request IDs without health text or SQL. Rate-limit sensitive operations; numerical limits require load/abuse testing.

Use canonical records rather than per-module copies. Source edits/deletion invalidate derived outputs. Jobs need bounded retries, deduplication, cancellation, safe failures and retention/deletion propagation. Reminder opt-in is separate and message text is neutral.

Select actual identity/storage/extraction/AI/provider/notification adapters only after privacy/safety review. Missing adapters return unavailable/pending, never fake success. Community workers/moderators have no private-health storage access. No fake provider credentials or booking confirmation.

Resolve runtime, persistence/schema/migrations, job mechanism, session design, backups, retention, secret management and operational ownership before implementation. See [API](API_SPECIFICATION.md) and [Data model](DATA_MODEL.md).
