# Data model

## Status

Conceptual entities only: no database, schema, tables, migrations or stored product data exist. Storage technology is undecided. Private entities use server IDs, owner references, timestamps and optimistic versions where mutable; enforce ownership across relationships.

| Proposed entity | Fields / relationships / access |
| --- | --- |
| User | Identity subject, timezone, minimal preferences, lifecycle state; private account |
| ConsentRecord | Owner, purpose, selected IDs/versions, recipient, policy version, grant/withdrawal events; current scope checked per use |
| WellnessEntry | Owner/date/timezone, optional mood/energy/stress/sleep; private unless explicitly selected |
| JournalEntry | Owner/date/body/version; private by default, no automatic AI/clinician/community access |
| PeriodRecord | Owner/startDate/optional endDate/timezone/version; validate open intervals and ordering |
| SymptomEntry | Owner/date/timezone, symptom code and optional flow/pain/severity/mood/energy; canonical references rather than duplicate PCOS copies |
| UserReportedHistory | Owner, reported observation/history, date, evidence status; separate reported diagnosis from clinically confirmed evidence |
| PCOSInsightSummary | Owner, selected source IDs/versions, range/coverage, method version, user edits, draft/reviewed/outdated state; no diagnostic probability field |
| HealthDocument | Owner, private object key, type/size, quarantine/extraction state, retention date; selected processing only |
| ExtractedReportFinding | Document/owner, page/span, original text, draft value/unit, uncertainty, correction/review state; user verification is not clinical diagnosis |
| AIConversation | Owner, selected context versions, messages/sources and retention choice; private and deletable |
| Clinic / Clinician | Public contact/specialty, directory/credential sources, verification status/date; never fabricated |
| Appointment | Owner, provider/slot/external reference, request state and demo/integration mode; provider evidence required for confirmation |
| SummaryShare | Owner, reviewed artifact/version, recipient, consent reference, dispatch/receipt states; recipient-specific approval |
| LibraryArticle / Revision | Slug/categories/body/references, review status, reviewer role/date, revision history; editorial writes restricted |
| CommunityProfile / Topic | Public community ID/display name, restricted account mapping; topic rules; no public private-health linkage |
| CommunityPost / CommunityComment | Community author/topic/thread/body/moderation state; no private-record foreign keys or automatic attachments |
| Reaction / Bookmark / Block | Community actor, target/action; own bookmarks/blocks private; deduplicate reactions |
| CommunityReport / ModerationAction | Reporter, community target/reason, decision/appeal trail; protected reporter, authorized moderators only |
| Reminder | Owner, purpose/schedule/timezone/channel, opt-in; neutral content |
| ExportJob / PrivacyRequest | Owner, selected IDs/versions, state, artifact expiry, request/completion times; protected status/download |
| AuditEvent | Actor/action/object type/request ID/time/outcome; restricted minimal metadata, no health text |

## Relationships and lifecycle

Users own private records. Period/symptom/wellbeing records feed selected summaries by versioned reference. Documents own extraction drafts. Appointments reference sourced providers; shares reference exact reviewed versions and consent. Community content references separate community identities and never private records. Articles maintain independent editorial revisions.

Use foreign keys/owner-date indexes, UTC instants and local dates/IANA timezones where appropriate. Define vocabularies, text/upload limits and duplicate/overlap rules before implementation. Missing entries never mean symptom absence.

Correction/deletion invalidates affected summaries and changed-payload approvals; recompute or mark outdated. Remove eligible documents, findings, indices, AI context, pending jobs and expired exports. Delivered/downloaded copies are outside direct recall. Account deletion must explicitly address community authorship, account linkage, moderation evidence and processor copies rather than assuming a universal cascade.

Retention periods/exceptions, consent/audit minimization, backup expiry and provider deletion capability remain open. Define per-entity schedules before collection. Restores must reapply deletion tombstones before serving records; show truthful pending/completed deletion states. No private health data in community, analytics or development fixtures.
