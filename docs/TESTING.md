# Testing

## Verified status

No application, suite, runner, scripts, compiler configuration or CI exists. No runtime/API/build/accessibility/security/performance test has run. Documentation checks do not prove functioning software. Choose tooling after architecture approval; do not install dependencies for this task.

## Proposed acceptance coverage

| Area | Scenarios and required outcome |
| --- | --- |
| Mind & Wellness | Optional mood/energy/stress/sleep, journal save/reload/edit/delete, coverage visuals and reminders; journal private by default |
| AI Assistant | Genuine sources, unsupported questions, scoped context, revoked grants, vendor outage, malicious report instructions and deletion; no fabricated citations/findings, diagnosis or prescribing |
| Appointments & Clinic | Directory provenance/verification, filters/no results, demo labels, requests/history/cancel/reminders, duplicate callbacks/outage; only provider evidence confirms booking |
| Period Tracker | Open/start/end/overlapping dates, timezone, optional fields, calendar keyboard use, selected export and edit/delete; labeled estimates and no fertility/contraceptive promise |
| Sisterhood | Pseudonyms/topics/posts/comments/reactions/bookmarks/search, reporting/blocking/spam/moderation/appeals; no private joins, fields, attachments, prefill or search leakage |
| Women's Health Library | All life-stage categories, search/navigation, references/reviewer role/status/date/revisions, broken/stale sources and accessible media; no unreviewed medical-review label |
| PCOS Insights | Selected history, reported versus confirmed facts, missing/sparse/irregular data, coverage/provenance/review/export; no unvalidated PCOS percentage/probability, diagnosis or exclusion from absent symptoms |
| Cross-module | Period Tracker → library → scoped AI → PCOS summary → review/edit → recipient-specific clinic sharing; separate journal/community retain boundaries |
| Authentication/authorization | Unauthenticated/expired sessions, cross-user list/read/edit/delete/download/export/jobs, role access, revocation and CSRF where applicable; denial without existence leaks |
| Consent | Refusal/withdrawal, selected IDs/versions, distinct purposes/recipients, changed payload and queued dispatch; revoke before execution and require approval again for changed content |
| Reports | Invalid type/size/malware, object ownership, OCR/unit/contradiction errors, correction/review/deletion; draft findings cannot become confirmed without user review, which is not diagnosis |
| Lifecycle | Missing versus zero, duplicate/concurrent edits, canonical references, stale summary after edit/delete, export expiry, processor deletion and backup tombstones; truthful status |
| API/errors | Schemas/enums/lengths/ranges, ownership, pagination, rate limits, idempotency, conflicts and integration failures; safe stable errors, no false success |
| Accessibility/responsive | Automated plus keyboard/screen reader/contrast/focus/dialogs/zoom/reflow, chart-table equivalence, calendars, touch/mobile/reduced motion; evaluate WCAG 2.2 AA goals |
| Operations/performance | Slow mobile networks, proposed frontend budgets, compatible migration, restore/rollback, alerts, safe logging, secret/dependency review and incident exercise |

Use synthetic fixtures: two owners, a moderator without health access, sparse cycles, draft/corrected reports, stale summaries, withdrawn grants and unconfirmed bookings. Verify service/storage denial as well as UI; hiding controls is not authorization. Establish clinical/accessibility reviewers and measurable thresholds before real-user launch.

## Documentation validation

Check local Markdown links, seven canonical module names, exact five palette values, evidence-backed stack/status wording, consistent equivalent files, privacy/consent, no PCOS diagnostic score, no automatic community disclosure and user review before extracted findings are relied on. Check Git whitespace/diff and Markdown-only changes. This does not establish clinical efficacy, compliance or runtime behavior.

Open: tooling, browser/CI matrix, reviewers, quantitative thresholds and incident evaluation. See [Roadmap](PIPELINE.md).
