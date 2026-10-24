# User flows

## Status

No journeys/forms/navigation are implemented. All flows below are planned and use synthetic data until real-data gates pass.

## Connected journey

1. Record optional dates/symptoms in Period Tracker; confirm only after persistence. Missing days remain unknown.
2. Open related Women's Health Library topics without transmitting private history.
3. Ask AI Assistant about terminology; explicitly select any records/reviewed report findings and authorize processing. General information needs no health context.
4. Select cycle/symptom history in PCOS Insights. Show descriptive coverage/provenance/limitations and reported versus clinical facts; no diagnostic percentage.
5. Review/edit/include/exclude summary sections and approve an exact version. Source edits/deletions invalidate affected outputs or mark them outdated.
6. In Appointments & Clinic, choose a sourced provider and separately approve summary/recipient delivery. Requests stay pending until provider confirmation; synthetic demo sends nothing.
7. Maintain a separate private journal/check-in in Mind & Wellness, with no automatic AI/clinician access.
8. Enter Sisterhood using a separate display name. No period/PCOS/report/journal/appointment/AI data attaches or prefills posts. Explain pseudonymity limitations before public disclosure.

## Supporting and failure paths

- Discover: landing → labeled synthetic demo → scope/privacy → account entry when available.
- Onboard: minimal identity → purposes → separate optional grants → timezone/preferences → empty home. Tracking is skippable.
- Correct: log → validate/save → reload/history → version-checked edit or confirmed delete → dependent views refreshed/outdated. Resolve conflicts visibly; failed saves preserve safe in-memory input.
- Report: private upload → validation/quarantine → extraction draft → correction of text/units → user review → selected explanation. Transcription review is not diagnosis.
- Share: selected records → preview/edit → recipient approval → dispatch → receipt if supported. Changed payload needs approval again; revocation before dispatch blocks sharing.
- Community: guidelines/topic → deliberate writing → post/comment/react/bookmark → report/block if needed. Moderator sees community evidence only; removal/appeal status is visible.
- Learn: life stage/topic → article → references/review metadata → optional consultation question. Reading implies no diagnosis.
- Privacy: inspect grants → withdraw/export/delete → impact/timing preview → status → truthful completion/limitations. Delivered/downloaded copies cannot be recalled automatically.
- Recovery: reauthenticate expired sessions; never imply unsaved persistence. Offline, failed extraction, inaccessible records, stale summaries, provider outages and empty histories have distinct recovery states. Retry cannot duplicate posts/bookings/shares.

Open: sign-in methods, unsaved recovery, provider delivery capabilities, moderation policy, deletion wording and usability research. See [Features](FEATURES.md) and [Testing](TESTING.md).
