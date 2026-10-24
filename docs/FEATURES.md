# Seven-module feature contracts

## Common status and behavior

**Every feature below is planned; none is implemented, partial or prototyped.** Each module contract applies to every listed capability. Shared dependencies: verified identity for private operations, owner authorization, validation, persistence, purpose-specific consent and [safety](AI_AND_CLINICAL_SAFETY.md). Shared errors: expired session, denied/revoked access, validation, conflict, rate limit and service outage. Preserve safe input and never claim unsaved actions succeeded. Empty views invite optional input without pressure. Acceptance criteria are future tests.

## Mind & Wellness

- Purpose/story: as a user, I want a private place to reflect and understand wellbeing patterns.
- Features/interactions: optional mood/energy check-ins; private journaling; stress/sleep logging; history/charts; gentle non-diagnostic self-care; opt-in reminders and privacy controls. Create, inspect, edit and delete entries.
- Inputs: date/timezone, optional mood/energy/stress values, sleep duration/quality, private journal text, selected range and reminder preferences.
- Outputs: versioned entries, history, coverage-aware chart/table and reviewed self-care information.
- Dependencies/privacy: agreed scales, canonical owner records, safe rendering and neutral notification service. Journals are private by default; no AI, clinician or community sharing without explicit selection/consent.
- States: empty journal is valid, missing days unknown; failed saves visibly unsaved; unavailable reminders never marked delivered.
- Acceptance: save/reload/edit/delete works; optional fields stay optional; charts expose gaps and text equivalents; opt-out stops reminders; denied cross-module access cannot retrieve journals.

## AI Assistant

- Purpose/story: as a user, I want understandable health information and questions for a professional.
- Features/interactions: conversational information; terminology explanations; genuine sources where appropriate; selected record summaries; uploaded report explanations; consultation questions; uncertainty and context/history controls.
- Inputs: question, explicitly selected record IDs/versions, user-reviewed report findings, processing grant and conversation retention preference.
- Outputs: explanation, actual references, limitations, provenance-linked draft summary/questions; never diagnosis or prescription.
- Dependencies/privacy: evaluated AI/retrieval service, secure extraction and user review, scoped context, vendor retention review. No blanket record access or journal context by default.
- States: no context permits general information; unsupported questions/source outages disclose limits; extraction ambiguity stays draft; vendor failure is not completion.
- Acceptance: excluded records never enter context; revoked grants block processing; citations/findings are not fabricated; uploaded instructions cannot override policy; user correction precedes downstream reliance; deletion controls work.

## Appointments & Clinic

- Purpose/story: as a user, I want to find suitable providers and prepare accurate requests.
- Features/interactions: clinic/clinician directory, search/filter, verification metadata, requests and booking management, history, opt-in reminders and approved clinician summaries.
- Inputs: filters, sourced provider/slot selection, minimum contact details, reviewed summary version, specific recipient and separate sharing grant.
- Outputs: provenance/verification date/status, request/booking state, history and dispatch/receipt status.
- Dependencies/privacy: sourced directory, actual provider adapter and verified callbacks for real booking; minimum approved payload only. Summary approval is separate from delivery permission.
- States: no results offers filter reset; stale credentials/availability labeled; demo is synthetic and sends nothing; pending/unknown/declined/cancelled remain distinct from confirmed.
- Acceptance: never invent clinics, credentials, slots or integrations; confirmation needs provider evidence; retries/callbacks deduplicated; changed summary requires renewed approval; revocation before dispatch blocks sharing.

## Period Tracker

- Purpose/story: as a user, I want editable menstrual history without assumptions about regularity or fertility goals.
- Features/interactions: start/end dates; optional flow, pain, symptoms, mood/energy; calendar/history; transparent estimates; optional reminders; correction/deletion and selected export.
- Inputs: local dates/timezone, optional daily logs, selected range and reminder/export selection.
- Outputs: canonical versioned records, keyboard-accessible calendar and chart/table, labeled estimate with method/coverage/limitations, previewed export.
- Dependencies/privacy: owner records, validated vocabularies, reviewed minimum-data rules and scoped export. PCOS/AI access requires explicit selected scope.
- States: open periods allowed, end-before-start rejected, overlaps resolved visibly; sparse/irregular data explained; missing entries never mean symptoms absent.
- Acceptance: editing/deletion refreshes dependent views; estimate remains labeled; no ovulation/fertility accuracy or contraceptive promise; export excludes unselected data; opt-out cancels reminders.

## Sisterhood

- Purpose/story: as a user, I want supportive discussion under a display name without exposing private records.
- Features/interactions: pseudonymous profile, topic communities, posts/comments, reactions/bookmarks/search, reporting/blocking, guidelines, moderation/appeals and anti-spam.
- Inputs: deliberately typed community text, topic/query, reaction/bookmark, report reason/block target and moderator decision.
- Outputs: community feed/thread, own bookmarks/blocks, protected report receipt and moderation status.
- Dependencies/privacy: separate CommunityProfile and community-only index/service, restricted account mapping, trained moderators and abuse limits. Pseudonymity is not complete anonymity: account/network metadata, volunteered details and screenshots may identify users.
- States: no results/removed content/blocked action/queued report explained; retry avoids duplicate posts; moderation outages alert owners.
- Acceptance: reporter identity hidden from reported users; unauthorized moderators denied; no private-record joins, auto-attachments, composer prefill or private search results. Period history, PCOS information, reports, journals, appointment summaries and AI conversations are inaccessible to community services. Protect against harassment, doxxing, misinformation and personal-health disclosure; blocking cannot recall external copies.

## Women's Health Library

- Purpose/story: as a user, I want accessible sourced education relevant to my questions/life stage.
- Features/interactions: category/topic navigation, search, accessible articles/media, source management and editorial review/revisions.
- Categories: puberty/adolescence; first periods/menstrual health; hormonal/reproductive health; fertility/preconception; pregnancy; postpartum; perimenopause; menopause; later-life wellbeing; PCOS; common symptoms/terminology; appointment preparation.
- Inputs: topic/query and editorial content/references/review metadata.
- Outputs: educational results/articles with reputable references, review status, reviewer role, review date and revision history where applicable.
- Dependencies/privacy: content taxonomy, source verification, editorial owner and accessible publishing; no private records needed to browse.
- States: empty search offers broader topics; stale/broken sources flagged; missing review metadata blocks a reviewed publication label.
- Acceptance: unreviewed content never labeled medically reviewed; keyboard/search/topic navigation works; sources support claims; articles expose accurate review/revision metadata.

## PCOS Insights

- Purpose/story: as a user, I want descriptive history to prepare for a clinical assessment.
- Features/interactions: optional symptoms, cycle/user-reported history, lifestyle/wellbeing observations, historical visuals, user-reviewed summaries, PCOS education/questions and selected export.
- Inputs: selected canonical records/versions, reported history, date range, optional observations and user edits.
- Outputs: counts, coverage, provenance, descriptive observations, chart/table, draft/reviewed/outdated summary and consultation questions.
- Dependencies/privacy: explicit cross-module scope, versioned descriptive rules, reviewed education and scoped export/sharing; journals excluded by default.
- States: missing/contradictory data is disclosed; insufficient history cannot support reassurance; source changes invalidate affected summaries.
- Acceptance: no unvalidated numerical PCOS probability/percentage, diagnosis or exclusion based on absent symptoms. Distinguish reported history from confirmed clinical diagnoses; user review of report transcription is not diagnosis. Show available data/limitations, encourage professional assessment and require renewed approval of changed share payloads.

Integration: [User flows](USER_FLOWS.md). Verification: [Testing](TESTING.md).
