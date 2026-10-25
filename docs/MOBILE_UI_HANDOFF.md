# Mobile UI handoff

> Latest mobile extension (25 October 2026): the ball-merging game, spotting/discharge fields and fictional directory are implemented in the existing app. Current files, rules, data lifetimes and 68-test/build results are in [Merge & Unwind / tracking handoff](AURACARE_UNWIND_TRACKING.md). The original audit below is historical and is not the current implementation status.

## Audit and authority (2026-10-25)

Inspected local branch `md_modification`, commit `19ef623`; initial working tree clean. Read all 16 existing project Markdown files completely. No applicable repository/ancestor AGENTS.md found. The only non-document project artifact was the tracked PowerShell cache, left untouched. No archives, images, Flutter/native README, pubspec, lib, tests, assets, lockfile, quiz_contract.json, predict.py, model or backend existed locally. The remote snapshot described in the brief is not this checkout. No reference images were supplied; the visual implementation follows the written brief, not a claimed image match.

Flutter located outside PATH at `C:\Users\Soumya\flutter`: Flutter 3.47.8, Dart 3.13.7. SDK cache access requires execution outside the workspace sandbox. New package location: `Auracare_mobile_app/auracare_mobile_app/`. No existing native/signing configuration is replaced.

## Source-to-screen checklist established before implementation

| Source | Existing readiness | Mobile implementation choice |
| --- | --- | --- |
| PRODUCT_OVERVIEW.md, FEATURES.md, USER_FLOWS.md | Specifications only | Five persistent Home/Timeline/Learn/Insights/Profile destinations, labeled quick actions; session-only synthetic demo |
| FRONTEND.md, ARCHITECTURE.md | Web routes/proposed server, no code | Flutter SDK navigation/ChangeNotifier; no website, cloud or new backend |
| BRAND_IDENTITY.md, DESIGN_SYSTEM.md | Old obsidian/violet palette and editorial web typography | Explicit brief overrides with Plum/Orchid/Mist/Apricot/Blush Cloud; rounded system sans, original painted characters |
| FEATURES.md: Mind & Wellness | Planned optional records/private journal | Journal, mood/energy/stress/sleep record choices; self-care and reminders unavailable pending review/service |
| FEATURES.md: Period Tracker | Planned records/estimates | Optional bleeding-day calendar and CRUD; no estimates without reviewed method; no fertility overlays |
| FEATURES.md: Library | No verified articles/sources/reviewers | All documented topic categories, searchable structural previews, consultation question action; no generated medical advice/review badges |
| AI_AND_CLINICAL_SAFETY.md, DATA_MODEL.md | Descriptive/provenance requirements; no rules | Derived counts/coverage, prototype-count-v1, source links and immediate recomputation; no diagnosis/probability |
| Brief: experimental quiz | No local schema/model/server | Preserve supplied keys/nulls, demo fixture service and live-unavailable seam; no model run or consumer score |
| FEATURES.md: AI Assistant, Sisterhood, clinic integrations | Planned, no services or verified provider data | Discoverable unavailable boundaries only; no chat/uploads/social feed/booking/sharing; appointment preparation works locally |
| BACKEND.md, API_SPECIFICATION.md, SECURITY_AND_PRIVACY.md | Proposed APIs/controls only | Separate records/resources/quiz/account interfaces; no fake endpoints, legal consent or security claims |
| TESTING.md, DEPLOYMENT.md, PIPELINE.md | No executable tests/CI | Focused state/widget tests, format/analyze/test and Android build if toolchain permits; no deployment/push |

Unresolved: missing reference images; model question time windows/wording and minimum inputs unverified; clinical scales/thresholds/reviewers, real content, identity/storage, IANA conversion, reminders, moderation, jurisdiction, retention and provider integration. These do not block the synthetic UI. Prototype severity uses Unspecified/Mild/Moderate/Severe, not a clinical scale. No inference from missing entries.

## Implemented screens and interactions

| Screen | Implemented prototype behavior |
| --- | --- |
| Welcome/onboarding | Three swipeable illustrated pages, progress, Back/Next/Skip; fictional sample or empty demo entry; timezone/cycle preferences and unavailable account notice |
| Shared shell | Persistent Home/Timeline/Learn/Insights/Profile destinations; IndexedStack retains tab state; one demo badge per visible route; large text switches navigation to two columns; badge height is measured rather than clipped |
| Home | Date/zone, original blossom greeting, derived record/day totals, direct source-history link, Log entry, recent records and labeled Cycle/Journal/Wellbeing/PCOS quiz/Appointment actions |
| Logging/details | Symptom/date/time/zone/severity and bounded notes; journal title/body; wellbeing metric notes; recorded bleeding intensity; save/edit/delete confirmation/cancel; visible loading, validation, failure/retry, atomic writes and duplicate-submit prevention |
| Timeline | Chronological date groups, record-type and date-range filters, empty/filtered-empty states and detail links; journals and bleeding records use the same repository |
| Cycle | Opt-in, month/day selection, selected/recorded/unrecorded distinction and bleeding CRUD; disabling retains records and removes the active calendar card in favor of optional setup; no fertility/ovulation overlays or estimates |
| Journal | Separate journal view, plain-text editor, shared timeline, failed-save preservation and unsaved-change confirmation; no automatic AI/community/clinician disclosure |
| Learn | Search/filter across all 12 documented life-stage/topic categories, structural detail previews and question-to-appointment action; no invented sources, reviewer/date or medical advice |
| Insights | Select date range; derived counts, recorded/unknown-day coverage, symptom-day descriptions and source versions/links; prototype-count-v1, no clinical-review claim; edit/delete recomputes immediately |
| Appointment preparation | Explicit record selection (including journals only by deliberate selection), range, optional notes/observations, add/remove questions, current preview and working clipboard copy; no PDF/native share/provider delivery claims |
| Profile/privacy | Fictional Alex profile, local/UTC preference, optional cycle controls, reduced motion, off-by-default simulated purpose preferences, correction/deletion entry, synthetic JSON clipboard export, confirmed session reset and controlled failure/sample scenarios |
| PCOS quiz | Intro, context/age/optional kg+cm-derived BMI, six binary questions with no preselection, Not sure/null, Back/Next/review/edit, visible submitting, insufficient/outside-scope/known-diagnosis states, fixture/failure/retry/live-unavailable boundaries and copyable descriptive result; no scores or model-run claims |
| Other documented modules | Discoverable unavailable AI Assistant/report, Sisterhood and clinic-directory/booking surfaces; no records sent, no uploads, social feed or invented provider data |

Original artwork uses Flutter CustomPainter and the five exact mobile tokens. The same original character was rendered into new Android/iOS launcher images; native launch backgrounds use Mist. This is prototype artwork, not an official logo. No font/image runtime dependency or remote asset URL was added. Native files were newly generated locally; signing/provisioning was not customized.

## Synthetic-data policy and state lifetime

The default entry offers visibly fictional fixtures or an empty session. One typed DemoRecordsRepository notifies all record consumers. There is no persistent health-text storage, telemetry, credentials, upload or network API integration. Restart returns to onboarding. Reset clears records/questions/optional preferences but cannot recall clipboard copies. Explicit export includes journal records; the UI explains this before copying. No real server deletion, encryption, backups, legal consent, authentication or compliance is asserted.

Records preserve wall-clock components and their declared Device local/UTC label. New UTC entries use the UTC clock; preference changes do not reinterpret historical timestamps. Mixed-zone coverage groups declared calendar dates and says so; full IANA conversion is deferred. Missing entries are unknown, not symptom-free. The prototype severity enum and bleeding vocabulary are not clinical scales.

There are no supplied medical articles, actual references/reviewers or approved descriptive-rule thresholds. Learn therefore shows structural previews. Insights counts only; it does not calculate PCOS probability, diagnosis, improvement or causation. Period intervals/start-end history, reviewed estimates, structured sleep/stress scales, reminders, clinically reviewed self-care and real persistence remain future product work. Bleeding-day records and optional wellbeing notes implement the narrower mobile prototype brief.

## Integration seams and unresolved work

- RecordsRepository: replace in-memory writes only after real authentication, owner isolation, persistence, lifecycle and consent tests.
- ResourcesRepository: add real sourced/reviewed editorial content and review/revision metadata. No fabricated placeholder citations exist.
- QuizService: DemoQuizService returns labeled fixture/state outcomes without a model; LiveUnavailableQuizService is explicitly unconnected. No quiz_contract.json, predict.py, model/server or verified endpoint exists locally. Supplied keys are preserved, unknown binaries remain null and known diagnosis is routing-only. Model question wording/time windows and actual minimum inputs still need verification. The conservative all-known demo gate is not a model specification.
- AccountPrivacyService: only synthetic JSON export is active; real account/export/deletion, encryption, retention, backups and jurisdiction require reviewed backend work.
- Provider/PDF/share, AI/report processing and community/moderation remain unavailable. No private health references are exposed to community code.
- Reference images were not attached. The implementation follows the written composition/palette brief and is not claimed to reproduce unseen images or the inaccessible prior Figma screen.

The explicit mobile brief overrides web routing/landing/3D and old palette/typography in FRONTEND.md, ARCHITECTURE.md, BRAND_IDENTITY.md and DESIGN_SYSTEM.md. Scope notices link here; unrelated product and clinical/privacy requirements are retained.

## Validation and local limitations

Commands were executed from the actual new package unless stated otherwise:

| Command/check | Actual outcome |
| --- | --- |
| Flutter/Dart version | Flutter 3.47.8 and Dart 3.13.7 verified via installed SDK; outside PATH |
| flutter create --platforms=android,ios --empty --no-pub | Generated the previously absent package and native projects; generated Flutter/native READMEs read before customization |
| flutter pub get --offline | Initially failed because flutter_lints was not cached |
| flutter pub get | Passed; standard generated SDK/test/lint dependencies resolved; constraints preserved, no downgrade |
| dart format lib test tool/render_native_artwork.dart | Passed; changed Dart source formatted |
| flutter analyze | Executed but analysis server crashed with FormatException before diagnostics on the Unicode workspace path; ASCII short-path attempt also failed |
| python tool/analyze_fallback.py C:/Users/Soumya/flutter | Uses the installed Dart analysis server's supported analyzer line protocol on the actual package, no SDK changes; zero issues after fixes |
| flutter test --concurrency=1 | 26 domain/widget/layout tests passed after defects were corrected; exact final capture run result recorded below |
| flutter test test/layout_test.dart with capture defines | Rendered real Flutter widget PNGs in ignored build/previews at 320/390/430 logical pixels and 100%/200% text with simulated 280px keyboard insets; not emulator screenshots |
| flutter test tool/render_native_artwork.dart | Successfully rendered original palette-matched native launcher PNGs; this is an explicit development utility, not a clinical test |
| flutter doctor -v | Android SDK 36 present, command-line tools missing and licenses unknown; no Android emulator connected; Windows lacks Visual Studio; iOS unavailable on Windows |
| flutter build apk --debug | Attempted; Gradle daemon/JVM failed with insufficient memory and disappeared; no APK/build success claimed |

Initial tests also encountered full disk space. Only verified temporary Flutter directories created by these runs and the redundant ZIP downloaded by this task's Gradle run were removed; the extracted Gradle installation was retained. No unrelated user data or caches were reset. Validation then resumed sequentially. No SDK constraint/version was changed to hide failures.

Tests cover onboarding/entry/tabs and tab-state retention; CRUD/source propagation and version conflicts; empty/filtered-empty/failure-retry; cycle retention and unsaved journal changes; selection/exclusion/current appointment preview and clipboard; quiz back/edit/null/age/known-diagnosis/failure/unavailable/retry behavior; narrow/scaled layouts and focused forms with keyboard insets. This does not prove native screen-reader behavior, full WCAG compliance, clinical validity or real device performance.

Final executed suite: `flutter test --concurrency=1 --reporter expanded --dart-define=CAPTURE_PREVIEWS=true --dart-define=FLUTTER_SDK=C:/Users/Soumya/flutter` — **26/26 passed**, including refreshed captures. Final analyzer fallback: **zero issues**. Format verification: **23 Dart files, zero changes required**. Documentation validation: **19 Markdown files, 54 local links, none broken**. Verified exactly the five requested opaque Flutter base-color constants, no unexpectedly large new files, valid 1024×1024 iOS launcher output, and clean `git diff --check` (Git emitted only its normal line-ending notices).

Rendered PNGs were actually viewed: Home at 390/430 normal text and 320/200%, cycle at 390, focused journal at 320/200%, focused symptom form at 390, and quiz intro at 430/200%. The large-text navigation keeps full labels in an adaptive two-column layout. Focused form captures use simulated keyboard insets with no fake keyboard artwork. Secondary-screen previews use a test MaterialApp and may show Flutter's debug banner; the real AuracareApp disables it. These are widget-engine captures, not native device verification.

Actual native keyboard, Android/iOS device rendering, screen-reader testing, native clipboard integration and successful native builds still require a configured device/toolchain and sufficient disk/RAM. Clipboard behavior was exercised via the platform channel in widget tests. No emulator/device run or deployment was performed. No commits or pushes were made.

## Reproduce / next work

See the [package README](../Auracare_mobile_app/auracare_mobile_app/README.md) for run/test/capture commands. Free sufficient disk/RAM and install Android command-line tools/resolve licenses before retrying `flutter build apk --debug` and `flutter run`. Use macOS/Xcode for iOS. The standard analyzer startup problem is separate from source diagnostics; use the provided fallback while investigating that SDK/path issue.

Integrate reviewed content, real identity/storage and contract-verified backend services in later phases rather than treating the demo as production-ready.
