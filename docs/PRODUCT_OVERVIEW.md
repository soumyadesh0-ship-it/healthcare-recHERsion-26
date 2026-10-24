# Product requirements and overview

## Status and vision

All requirements are planned; no application exists. See [audit](../README.md). This existing file serves as PRODUCT_REQUIREMENTS.md to avoid duplication. Connect personal records, understandable education and consultation preparation in a calm, premium companion with optional disclosure and inclusive life-stage support.

Users need simple logging, correction/deletion, reliable sources, understandable uncertainty, privacy controls and supportive discussion without exposing private history.

## Functional requirements

[Features](FEATURES.md) specifies the contracts for seven primary modules:

1. Mind & Wellness: optional mood/energy, journal, stress/sleep, visual history, gentle self-care, reminders and privacy controls.
2. AI Assistant: information/terminology explanations, genuine sources, selected record/report summaries and consultation questions with limitations.
3. Appointments & Clinic: sourced directory/filtering/verification, requests, booking management/history, reminders and approved summaries.
4. Period Tracker: start/end dates, optional flow/pain/symptoms/mood/energy, calendar/history, labeled estimates, correction/deletion and selected export.
5. Sisterhood: pseudonyms, topic communities, posts/comments, reactions/bookmarks/search, reporting/blocking, guidelines, moderation and anti-spam.
6. Women's Health Library: accessible life-stage education, search/topic navigation, references and truthful review/revision metadata.
7. PCOS Insights: optional symptoms, cycle/user-reported history and lifestyle observations, descriptive visuals, reviewed summaries, education/questions and selected export.

Shared identity does not grant universal access. Require explicit scope/purpose authorization for sensitive cross-module use and separate recipient approval for clinician sharing. Journals are private by default. Sisterhood has no automatic private-record access. Reuse canonical records rather than copies; correction/deletion invalidates affected summaries or marks them outdated.

## Non-functional requirements

Target WCAG 2.2 AA, responsive layouts, keyboard/screen-reader access and reduced motion; verify before claiming compliance. Require owner authorization, minimization, encryption, secure files, private caching, safe logging, deletion/export and tested restore before real health collection. Proposed performance goals live in [Frontend](FRONTEND.md); availability/recovery budgets await architecture selection.

## Journeys and acceptance criteria

- Record symptoms → library education → explicitly scoped AI explanation → selected PCOS history → user review/edit → recipient-specific clinic share. Accept only if excluded records never enter context/payloads and sharing requires separate approval.
- Private wellness journaling alongside Sisterhood participation. Accept only if no journal, cycle, PCOS, report, appointment or AI context is attached, prefilled or searchable in community.
- Correct/delete source records. Accept only if derived views update or become outdated and changed share payloads require renewed review.
- Upload report → draft extraction → correction/review → selected downstream use. Accept only if unreviewed findings cannot be treated as confirmed; transcription review is not clinical diagnosis.

See [User flows](USER_FLOWS.md) for failures and [Testing](TESTING.md) for verification.

## Out of scope and decisions

No diagnosis, prescribing, emergency monitoring, unvalidated PCOS probability, symptom-based exclusion of PCOS, fertility/ovulation accuracy or contraceptive guarantees. No fabricated sources, clinics, credentials or bookings. No automatic clinician/community disclosure.

Measure correction/deletion task success, summary fidelity, comprehension of limitations and accessible task completion; do not optimize disclosure volume. Research cohort, age, jurisdiction/languages, business model, reviewers and quantitative success thresholds remain open. Developer timezone does not establish jurisdiction.
