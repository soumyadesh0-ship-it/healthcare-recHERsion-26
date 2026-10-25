# AuraCare Phase 3 — implementation and verification

Implemented in the existing Flutter Android app on 25 October 2026. No new Flutter project, packages, Gradle changes, SDK changes, package ID changes or logo replacements.

## Features

### Timeline and cycle history

- Existing recorded flow fills and latest-saved mood borders are preserved.
- Optional basic phase estimates are off by default. Recorded flow always wins the cell fill; mood keeps the border. Estimated phase remains available as a separate outlined marker and in selected-date details.
- Follicular, broad possible fertile interval, estimated ovulation midpoint, luteal, approaching-period and upcoming-period indicators use flat muted fills. Approaching-period colors use three discrete pink steps.
- Menstrual flow continues to represent recorded period observations. Blank days are never silently converted into logged bleeding days.
- The period editor adds optional first-day and last-day markers. Existing entries remain unchanged until explicitly edited. A gap in logging is not interpreted as a new cycle start.
- Cycle Summary replaces the old secondary calendar while retaining the `CyclePage` route for existing callers. It displays explicit starts, start-to-start lengths, durations with an explicit end, shortest/longest intervals when available, recent history, flow counts and editable source entries. Timeline remains the primary calendar-based Log period interface.

### Basic estimate method and limits

No existing tested prediction service was present. The new method is a basic calendar visualization, not a medically validated prediction model or fertility-awareness method.

Eligibility requires four explicitly recorded starts (three intervals), all intervals between 21 and 35 days, a spread of no more than three days, and no future latest start. These are conservative product guardrails, not validated accuracy thresholds. Users can disable estimates or mark cycles unsuitable, including irregular cycles/PCOS, pregnancy/postpartum, perimenopause or hormonal contraception. No diagnosis is inferred from the checkbox or interval lengths.

The next start uses the mean recorded interval, rounded to a calendar day, without a 28-day default. A future duration is shown only when at least two explicitly ended periods have durations within the method's 1–10-day guardrail; otherwise only the estimated start day is marked. No missing cycle is rolled forward repeatedly.

The [NHS menstrual-cycle reference](https://www.nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle/) describes variable ovulation timing, often 10–16 days before a following period, and sperm survival up to seven days. The UI therefore shows a broad possible fertile interval rather than a precise fertile window. Its ovulation midpoint is a labeled visual anchor, not evidence that ovulation occurred. Historical intervals use their recorded next start where available. The complete user-requested contraception warning is displayed whenever estimates are enabled.

Clinical validation and clinical editorial review are still required before treating these features as medical decision support. PCOS and irregular-cycle accuracy is not claimed.

### Doctor appointments

The bottom bar is now Home | Timeline | Learn | Insights | Doctor | Profile. On narrow screens or enlarged text it uses wrapped labeled controls, preserving access to all six tabs. The duplicate Home profile-header button is removed.

The Doctor tab provides future appointments, history, create/edit/delete with confirmation, doctor name, optional specialty/location, local date/time and notes/questions. It opens the original `AppointmentPage` for record selection and consultation preparation; there is no duplicate preparation workflow or external booking system.

Appointments persist through an Android MethodChannel using an atomic JSON file in `noBackupFilesDir`. This is app-private device storage, excluded from Android backup; no clinic or cloud receives the data. It is not described as encrypted or compliant with a particular regulation. Uninstalling or clearing app data deletes it. Invalid/unreadable stored data blocks overwriting and shows a retry state. Writes update in-memory state only after storage succeeds. Failed saves preserve form input. Appointments survive repository/app recreation; their times are stored as device-local wall-clock values, without named-timezone conversion or notifications.

The original health-record repository remains session-only. This task does not silently migrate, reseed or clear health records. The existing demo reset affects its session records/preferences, not the separate persistent appointment organizer; delete appointments individually in Doctor.

### Learn

All twelve existing categories now open structured articles, with an introduction, what happens, physical/emotional experiences, general care, when to seek help, FAQ and source references. The twelve existing icons, category names, filters and navigation are preserved. Search also checks article text without duplicating topics. References can open in an external Android browser or be copied.

Sources were checked on 25 October 2026. This is a source-check date, not a clinical review date. Each page states that it is general education and that clinical editorial review is pending. No clinical endorsement, diagnostic model, medication prescription or invented medical statistic is included.

Source families include:

- [NHS: puberty](https://www.nhs.uk/conditions/early-or-delayed-puberty/) and [starting periods](https://www.nhs.uk/conditions/periods/starting-periods/).
- [NHS: period problems](https://www.nhs.uk/conditions/periods/period-problems/), [menstrual cycle](https://www.nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle/) and [discharge](https://www.nhs.uk/symptoms/vaginal-discharge/).
- [NHS: preparing for pregnancy](https://www.nhs.uk/pregnancy/trying-for-a-baby/trying-to-get-pregnant/) and [CDC: fertility](https://www.cdc.gov/reproductive-health/infertility-faq/).
- [NHS: pregnancy symptoms](https://www.nhs.uk/pregnancy/trying-for-a-baby/signs-and-symptoms-that-might-mean-youre-pregnant/) and [warning signs](https://www.nhs.uk/pregnancy/common-symptoms/pregnancy-symptoms-you-need-to-get-help-for/).
- [NHS: recovery after birth](https://www.nhs.uk/pregnancy/labour-and-birth/your-body/), [early days](https://www.nhs.uk/pregnancy/labour-and-birth/early-days/) and [CDC: maternal warning signs](https://www.cdc.gov/hearher/maternal-warning-signs/index.html).
- [NHS: menopause symptoms](https://www.nhs.uk/conditions/menopause-and-perimenopause/symptoms/) and [general care](https://www.nhs.uk/conditions/menopause-and-perimenopause/things-you-can-do/).
- [NHS: bone health](https://www.nhs.uk/conditions/osteoporosis/), [pelvic support](https://www.nhs.uk/conditions/pelvic-organ-prolapse/) and [postmenopausal bleeding](https://www.nhs.uk/symptoms/post-menopausal-bleeding/).
- [WHO: PCOS](https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome).
- [NHS: appointment preparation](https://www.nhs.uk/nhs-services/gps/what-to-ask-your-doctor/) and [NIH: preparing for appointments](https://health.nih.gov/health-topics-a-z/prepare-for-appointment).

### Splash and onboarding

The original logo splash appears on returning launches as well as first setup. Continue leads returning users to the existing shell; first-time setup retains the three illustrated pages and original sample/empty entry choices. There is no authentication integration to alter. Completing onboarding no longer resets a supplied existing health session.

Debug-only routes `/debug/onboarding` and `/debug/splash` preview the existing screens without resetting records or the completion flag. Alternatively:

```powershell
flutter run -d 00160359B000398 --dart-define=PREVIEW_ONBOARDING=true
```

That define is honored only in debug mode. Preview completion returns to normal startup and does not load sample records or change the persistent completion flag.

## Files changed

Paths below are relative to `Auracare_mobile_app/auracare_mobile_app/`.

| Files | Purpose |
|---|---|
| `lib/data/cycles.dart` (new) | Explicit history/statistics and guarded phase estimates. |
| `lib/data/appointments.dart` (new) | Appointment model, native store interface, atomic repository behavior. |
| `lib/data/articles.dart` (new) | Twelve structured source-linked educational drafts. |
| `lib/data/records.dart` | Optional start/end metadata preserved on save/export; no migration. |
| `lib/data/services.dart` | Existing resources link to article data. |
| `lib/app/app.dart` | Returning-user splash, safe onboarding completion and debug previews. |
| `lib/app/session.dart` | Appointment repository lifecycle and optional estimate state. |
| `lib/app/shell.dart` | Six responsive destinations; no duplicate header profile action. |
| `lib/app/theme.dart` | Phase-only color tokens; existing brand palette retained. |
| `lib/core/calendar.dart` | Optional estimate fills/markers, legends and selected-date details. |
| `lib/features/timeline/timeline.dart` | Estimate controls and Cycle Summary navigation. |
| `lib/features/cycle/cycle.dart` | Historical summary replacing the secondary calendar. |
| `lib/features/logging/editor.dart` | Optional explicit period boundary markers. |
| `lib/features/appointments/doctor.dart` (new) | Organizer and appointment editor, linked to existing preparation. |
| `lib/features/learn/learn.dart` | Article detail pages, content search and source actions. |
| `lib/features/onboarding/onboarding.dart` | Configurable existing splash button label. |
| `android/app/src/main/kotlin/org/auracare/auracare_mobile_app/MainActivity.kt` | App-private atomic appointment storage and allowlisted external source links. |
| `test/phase3_test.dart` (new) | Estimates, summaries, persistent-store contract, failure protection, articles, onboarding, six tabs and editor workflows. |
| `test/layout_test.dart` | Doctor form, article and phase overlays added to phone/large-text/keyboard coverage. |
| `test/widget_test.dart`, `test/redesign_test.dart`, `test/refinement_test.dart` | Intentional splash, six-tab and Cycle Summary expectation changes. |
| `README.md`, `docs/AURACARE_PHASE3.md` | Current implementation and handoff. |

Journal, Insights, Profile, PCOS quiz and original appointment-preparation implementations were not edited. Existing record CRUD, flow intensities and mood borders remain operational.

## Verification

- Formatting clean for `lib` and `test`.
- `flutter analyze --no-pub`: no issues.
- Full suite: **47 tests passed**.
- Expanded layout suite: **six phone/scale cases passed**, covering 320/390/430 logical pixels, normal/200% text and keyboard insets, including Doctor, appointment editor, educational article and phase estimates.
- Rendered widget previews are in ignored `build/previews/`; Doctor, Postpartum article and phase calendar were inspected. An illustration aspect-ratio issue found during inspection was fixed and layout checks rerun.
- Android ARM64 debug build succeeded. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Update installed with `adb install -r`, without clearing storage. The phone was in another app, so its foreground screen was not driven. There was no active Flutter run process to hot reload. Native storage changes require this full rebuild.
- Native on-phone create/edit/delete across process restarts and external-browser launching were not end-to-end exercised. Repository persistence/reload, failure cases and form workflows were verified in tests with an injected durable test store. The real Android implementation compiled successfully.

## Viewing and follow-up

Open AuraCare on the updated phone, or run `flutter run -d 00160359B000398` from the Flutter project folder. Press `r` for future Dart hot reloads, `R` for hot restart. Native bridge changes require a full rebuild/relaunch. Hot restart still resets the original in-memory health session; saved Doctor appointments use the new independent persistent store.

To try estimates without inventing data, edit actual historical period entries to mark starts/ends, then enable the Timeline estimate switch. Sparse/variable history correctly shows the withheld state. The algorithm and educational drafts need clinical editorial validation before a clinical release. No real clinic booking, notifications, cloud sync or authenticated account behavior was added.
