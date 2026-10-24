# Pipeline and roadmap

## Baseline

Documentation only; no product, prototype, build/CI or deployment exists. This existing file is the canonical roadmap rather than duplicating ROADMAP.md. Audit/documentation is complete for the inspected baseline; all implementation phases below are planned.

| Phase | Deliverable | Exit criteria |
| --- | --- | --- |
| 1. Repository audit and documentation | Inventory, seven-module requirements and boundaries | Consistent links/status/privacy/safety; no invented capabilities |
| 2. Brand identity and shared frontend foundation | Stack decision, tokens, shell and landing foundation | Contrast/keyboard/reduced-motion review; truthful availability |
| 3. Seven-module UI prototypes | Mind & Wellness, AI Assistant, Appointments & Clinic, Period Tracker, Sisterhood, Women's Health Library, PCOS Insights | Clearly synthetic; empty/loading/error states; no real uploads/bookings or health collection |
| 4. Authentication and secure data architecture | Identity, scoped consent, persistence, storage, deletion/export and audit | Ownership/consent denial, community isolation, encryption/key review and restore/lifecycle tests |
| 5. Period Tracker and Mind & Wellness | Optional editable logs, calendars/history, private journal and reminders | Reload/edit/delete, timezone/missingness, default privacy and opt-in tested |
| 6. Women's Health Library | Life-stage taxonomy/search/editorial workflow | Genuine sources, truthful review metadata/revisions, stale-source handling |
| 7. PCOS Insights and descriptive summaries | Selected history, coverage/provenance, review/edits/export | No probability/diagnosis; missing-data/stale-summary tests and clinical wording review |
| 8. AI Assistant and report processing | Scoped AI, quarantine/extraction/correction/questions | Vendor/privacy review, source grounding, injection/leakage/OCR tests and user-review gate |
| 9. Appointments & Clinic | Sourced directory, real adapter or labeled demo, requests/reminders/sharing | Provider verification, truthful states, callback/retry tests and recipient-specific approval |
| 10. Sisterhood community and moderation | Pseudonyms/topics/content/actions/search, reporting/blocking/appeals | Moderation staffing/guidelines, anti-spam/abuse tests and zero private-health access |
| 11. Testing, security review and deployment | Integrated release and operations | Accessibility/mobile/performance, clinical/security review, deletion/restore, monitoring and rollback |

Testing/privacy/safety apply throughout. No real health collection before phase 4 protections; no real AI/provider processing before relevant vendor/consent/safety gates. Public claims match deployed scope. No dates/provider commitments are implied.

Future CI: formatting, applicable lint/types, meaningful domain/API tests, ownership/cross-module/safety fixtures, production build, secret/dependency scanning and migration review. Choose commands only when tooling exists; previews use isolated credentials and synthetic data.

Open: providers/region, age/geography, owners/staffing/budget/schedule, retention, performance/recovery targets and launch thresholds. See [Deployment](DEPLOYMENT.md).
