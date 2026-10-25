# Navigation, wellbeing and logging update — 25 October 2026

## Current correction: calendar and game requirements

Validation for this correction: 88 Flutter tests passed; Flutter analysis reported no issues; git diff --check passed. Android debug APK built successfully at build/app/outputs/flutter-apk/app-debug.apk. New tests cover failed-save retry, all four flow choices across create/edit paths, optional boundary removal, notes, journal date context, deletion, color identity and narrow/doubled-text popup scrolling. Java native-access warnings were emitted during the successful build. No physical-device vibration or manual runtime verification is claimed.

This supersedes the restoration and mandatory-period-boundary descriptions below. Navigation, sidebar routes, breathing haptics and game physics are unchanged.

- Reused RecordCalendar and EntryEditor for the Period Picker. Selecting a date opens a bounded, scrollable dialog. Spotting/Light/Medium/Heavy are supported; Medium keeps the existing Moderate storage title. Start/end are optional, with Neither available. Successful writes close the popup and update intensity gradients. Failures retain selections. Saved dates reuse existing IDs and versions; new duplicate daily flow records are rejected. Historical records are retained.
- Saved-date Add Notes exposes the existing note field. Continue in Journal reuses the journal editor and an existing journal for that date if present. Unsaved changes require confirmation before journal navigation. Existing delete confirmation remains.
- The game draws solid, unique colors and vector faces without numeric ball labels. Internal values 1/2/4/8 map to Green/Turquoise/Pink/Purple. Original doubling, size cap, scoring, collision handling and controls are untouched. Cosmetic pop respects reduced motion.
- No emoji characters were found in lib source. No new dependencies, backend or database changes.
- BLOCKED: No Dots contact component or personal-contact repository exists in this checkout or the inspected branch refs; the fictional doctor directory was not substituted.
- INCOMPLETE: DemoRecordsRepository is memory-only. Flow, notes and journals remain session-only; refresh/relaunch persistence is not implemented. The appointment store is separate and unchanged. A verified durable health-record integration is needed to complete this requirement.


## Latest revision: restore originals and reapply navigation/vibration

The mini game is restored exactly from local main (74c1661), including the original numbered rendering. The earlier face-rendering description below is historical; ball_face.dart is no longer imported by the game. Physics and scoring remain unchanged.

The five horizontal destinations remain Home, Wellbeing, Doctor, Timeline, PCOS Quiz. The bar now uses equal-width destinations and scrolls when larger text needs more space. Existing drawer destinations and their working routes remain available. Original breathing duration and pacing remain with the optional, cancellable vibration cues reapplied. No unrelated forms, models, storage or backend configuration were changed in this revision.


This is the current UI handoff supplement. Earlier handoffs describe historical states. The previous Timeline PageStorage fix and its regression tests remain intact. No branch was switched, no existing user changes were discarded, and no commit or push was made.

## Recovered implementation and authority

The active checkout is `md_modification` (`d957b4f`). The missing features were located through read-only `git branch`, `git worktree`, `git ls-tree` and `git show` inspection on local `main` and `origin/main`, both at **74c1661**. No additional worktree exists. The neighboring `Auracare---Women-health-companion` folder is a separate HTML/JavaScript application, not the Flutter implementation. Its AGENTS.md was read for inspection context; no files in that repository were changed. No applicable AGENTS.md exists in this Flutter repository or its ancestors.

Recovered the actual breathing timer, Merge & Unwind game, doctor directory, spotting/discharge models/forms, route observer and their tests from `74c1661`. This selectively brings those requested features into the active checkout rather than switching branches or merging all unrelated changes. Early standalone game/timer drafts were removed once the originals were located. `merge_world.dart` is byte-identical to the recovered original (Git object `1d16a9997991794d2bafaab3269f38ee85c9f8ef`). Physics, scoring, random preview values, equal-value addition, cooldown and cap of 10 are unchanged.

The user explicitly approved the existing bundled PNG as the desired logo. `auracare-lockup.png`, `auracare-icon.png` and `auracare-wordmark.png` were reused unchanged, with their existing pubspec registration. No new logo was generated, redrawn, recolored or stretched. Earlier asset provenance remains in `assets/brand/README.md`.

## Navigation and presentation

Exactly five bottom destinations, left to right:

| Destination | Stable route | Existing implementation |
|---|---|---|
| Home | `/app/home` | HomePage |
| Wellbeing | `/app/wellbeing` | MoodCheckInPage, embedded without another app bar |
| Doctor | `/app/doctor` | DoctorPage with recovered DemoDirectory |
| Timeline | `/app/timeline` | TimelinePage with the previous storage fix |
| PCOS Quiz | `/app/quiz` (`/app/pcos` alias) | QuizPage, embedded |

The shell selects enum destinations, not legacy numeric indices. Visited tabs retain state in IndexedStack; hidden tabs disable tickers. Home Wellbeing/quiz cards select these same tab instances. The five labels remain in order in a horizontally scrollable bar when space or large text requires it. System Back walks quiz steps before returning Home; other non-Home tabs return Home. Inactive quiz PopScope cannot block other screens.

The accessible logo button opens the left drawer. Profile, Learn and Insights retain existing screen constructors and named routes. AI Assistant and Sisterhood retain honest unavailable pages. Appointment & Clinic selects the same Doctor tab. The Alex demo-profile footer opens the same `/app/profile` route as the upper item. Drawer items close the drawer before navigating; content scrolls above a SafeArea footer. Home no longer contains More from Auracare or its three duplicate destination cards. Appointment preparation remains a contextual workflow.

Welcome keeps its existing Continue/Get started callbacks and first-run behavior. Six decorative blobs and the old kinder-way tagline are removed. The existing logo is centered on white. Shared accents now use the exact brief values: blush `#F9DFEA`, blue `#A6BCE1`, lavender `#E7DEF1`; white/input/dark plum and semantic calendar colors remain.

## Breathing, game and temporary feedback

The recovered **single inline** BreathingSection keeps 1/3/5-minute choices, a 4-second inhale and 6-second exhale, comfortable-breathing copy, monotonic clock and reduced-motion behavior. There is no hold phase. The Anxious action scrolls to this section without starting it.

Optional Vibration cues defaults off. Flutter SDK HapticFeedback is used, with no new dependency or vibration permission:

- Inhale: one light impact.
- Exhale: two light impacts, 120 ms apart.
- Pause: one selection click.
- Completion or explicit Stop session: one medium impact.
- Resume: current-phase cue.

Phase transitions are detected outside build, so rebuilding does not repeat cues. Generation checks and a cancellable Timer prevent the delayed pulse after pause, reset, disabling cues, backgrounding, tab changes, route coverage or disposal. Device settings remain in control. MissingPluginException/PlatformException disable haptics safely while visual guidance continues. The SDK does not guarantee precise custom waveforms or perceptually distinct cues on every device. See [Flutter HapticFeedback](https://api.flutter.dev/flutter/services/HapticFeedback-class.html). Platform-channel scheduling is tested; physical vibration feel has not been verified.

The Merge & Unwind entry title and exact original subtitle, `A little space to pause and play.`, remain. Original board tap/drag-release, slider-release, explicit accessible Drop ball button and gesture/cooldown guards remain. Only rendering changes: muted warm red-to-pink balls, separately visible numbers, ten vector expressions from angry to happy, and short birth/merge pop and face interpolation. All ten face states are defined even where random previews/doubling do not directly reach a value. Reduced motion disables cosmetic interpolation/pop while retaining play physics.

Mood order remains Happy/Sad/Tired then Calm/Anxious/Energetic. Selection creates one prominent inline pastel feedback card beneath the grid, with enlarged original character, bold heading and supportive message. Brief fade/scale, gentle bounce and mood-specific particles/ripple stop after 1.8 seconds; reduced motion shows static content. Replacing mood disposes the previous animation. Leaving the tab or covering it clears the feedback. No mood interaction writes records, opens the calendar, creates analytics or talks to a backend. Anxious activities require an explicit button press.

## Logging compatibility

Period tracking opens an inline CalendarDatePicker immediately, with selected date, Light/Moderate/Heavy, Period start/Period end and Save. The redundant introductory heading is omitted on this form to keep the calendar high on small, large-text screens. The form scrolls naturally. At narrow widths/large text, the inline calendar gains horizontal space and scrolling so two-digit days remain readable; a regression checks the second glyph is inside its paragraph bounds. No nested unbounded viewport was introduced.

New period entries require observed flow and an explicit start/end choice. Only that selected day is recorded. End-only records do not fabricate a start; CycleHistory handles them without creating a cycle. Edits of historical unspecified-flow or unknown-marker entries preserve their original values unless explicitly changed. Existing both-marker entries also remain readable. Edit/delete/version/failure-retry still use the same repository.

Mood is removed from Home Log entry choices. Journal remains available. Optional Notes inputs are removed from non-journal health logging forms; their historical note strings are copied exactly on edits, including whitespace. Journal text remains editable and required. Original structured spotting/discharge amount/color/consistency/odor/irritation fields are recovered and preserved. Notes, structured observations, prior mood metadata and null markers remain in exports and selected appointment summaries. Health records are still session-only; there is no persistent health-record JSON importer to migrate. Persistent appointments keep their existing model and storage format.

## Nine-step PCOS quiz and model compatibility

The actual eight-feature experimental contract and inference code were found on `main` at `74c1661`, in `auracare_pcos/quiz_contract.json` and `auracare_pcos/predict.py`. They are reference sources, not a mobile endpoint. A copy of the contract is checked into [PCOS_CONTRACT_REFERENCE.json](PCOS_CONTRACT_REFERENCE.json) to make this UI handoff auditable without changing branches. No model weights, training pipeline, predictors or scores were modified or copied into the mobile runtime.

The nine question steps are followed by a non-question review screen:

| Step | Final wording / fields | Payload semantics |
|---|---|---|
| 1 | Has a clinician previously diagnosed you with PCOS? | `known_pcos_diagnosis`; true routes to tracking without service/scoring |
| 2 | Age (years) | `age`; experimental scope 18–45 |
| 3 | Height and weight (optional) | kg/cm calculate `bmi`; both blank remains null; supplied BMI must be 10–70 per predict.py |
| 4 | Are your periods regular? | `regular_periods`: Yes=1, No=0 |
| 5 | Have you gained weight recently? | `weight_gain`: Yes=1, No=0 |
| 6 | Do you have excessive body or facial hair growth? | `excess_hair`: Yes=1, No=0 |
| 7 | Are you noticing skin darkening recently? | `skin_darkening`: Yes=1, No=0 |
| 8 | Do you have scalp hair loss or thinning? | `hair_thinning`: Yes=1, No=0 |
| 9 | Do you have pimples or acne on your face or jawline? | `acne`: Yes=1, No=0 |

No answer is preselected. Not sure remains null. All six binary answers plus age are required by experimental-1; missing BMI is permitted. The inference contract uses development-trained BMI imputation, but no imputation or inference is performed by this disconnected mobile app.

`QuizAnswers.toJson()` retains an unknown diagnosis as null. `toModelJson()` deliberately omits only that optional routing field when unknown: predict.py accepts omission but rejects an explicit null for this flag. This is not a conversion to a negative diagnosis. All other nulls remain null. Known diagnosis is sent as a real boolean when supplied.

The active branch also has an older **different** service: `service/main.py`, `/predict-pcos`, accepts only nullable StrictBool `irregular_periods`, `acne`, `excess_hair_growth`, `scalp_hair_thinning` (extra keys forbidden) and returns `survey-count-v1`. It requires Supabase authentication. It is not the eight-feature model and is intentionally not used as a substitute endpoint. No silent boolean inversion, unsupported feature dropping or survey-count-as-AI result was introduced. A verified deployment/auth contract is still required before adding transport for the eight-feature model.

The default UI uses LiveUnavailableQuizService. Complete answers reach a retryable unavailable state; unknown inputs and out-of-scope ages get explicit non-scoring states. Thrown service failures preserve input and retry. Demo fixture service remains injectable for tests, but production UI offers no fabricated result or fixture scenario picker. Results show reported answers in plain language, experimental/clinical-assessment limits and the existing Doctor destination, without probability or invented risk bands.

### Wording sources, checked 25 October 2026

- [WHO PCOS fact sheet](https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome): supports menstrual irregularity, excess facial/body hair, acne and scalp-hair topics.
- [FDA PCOS information](https://www.fda.gov/consumers/womens-health-topics/polycystic-ovary-syndrome-pcos): supports symptom topics and explains clinical evaluation; includes skin changes and weight-related information.
- [Monash international guideline](https://www.monash.edu/medicine/mchri/pcos/guideline): guideline context for clinical assessment; not a validated nine-question survey. The current page also uses updated PMOS terminology. The requested PCOS app label and experimental API keys remain unchanged for compatibility.

These sources support topics, not a ranked most-asked list or a validated questionnaire. Final model wording follows the training contract without new thresholds or time windows. BMI/weight and skin-darkening questions serve this experimental model and are not sufficient diagnostic criteria. Clinical editorial review is still needed. Sources are bundled as static links in an expandable section; no medical content is fetched dynamically at runtime.

## Files and configuration

Paths below are relative to `Auracare_mobile_app/auracare_mobile_app/`:

- `lib/app/{app,shell,theme,navigation}.dart`: routes, five tabs, drawer, lifecycle observer and exact shared accents.
- `lib/core/{brand,widgets,calendar}.dart`: existing icon button asset, embedded PageFrame, structured-record rendering and exhaustive spotting/discharge calendar colors; previous Timeline storage keys preserved.
- `lib/data/{records,services,demo_doctors}.dart`: recovered tracking data/directory, note/observation export compatibility, wording and model payload adapter.
- `lib/features/home/home.dart`, `features/onboarding/onboarding.dart`: consolidated navigation and simple logo welcome.
- `lib/features/logging/editor.dart`: recovered structured forms, inline period calendar, hidden historical notes, ephemeral feedback and existing breathing section.
- `lib/features/appointments/{doctor,demo_directory}.dart`: recovered original directory inside existing appointment screen.
- `lib/features/pcos_quiz/quiz.dart`: nine steps, review, local guards, unavailable/error/retry states, Doctor action and source links.
- `lib/features/wellbeing/{breathing,breath_haptics,merge_game,merge_world,ball_face,wellbeing}.dart`: recovered activities, discrete cues, faces and inline mood feedback. `merge_world.dart` is unchanged from its source branch.
- `android/app/src/main/kotlin/org/auracare/auracare_mobile_app/MainActivity.kt`: adds only `www.fda.gov` and `www.monash.edu` to the existing HTTPS source-link allowlist.
- `test/{layout,phase3,redesign,refinement,widget}_test.dart`: update superseded navigation/mood/quiz expectations while retaining unaffected checks; layout captures include period forms.
- `test/{merge_world,unwind_tracking,wellbeing_controls}_test.dart`: recovered original regression coverage.
- `test/update_brief_test.dart`: model/null encoding, ten rendered face states, haptic transitions/cancellation/unsupported/completion, legacy period records, end-only periods, drawer/footer and system Back.
- Existing `test/timeline_test.dart` and calendar storage fix from the prior request remain.

No package, pubspec, Gradle, manifest, permission, signing or asset changes. The only native change is the source-link allowlist.

## Validation

- Flutter analysis: no issues.
- Full Flutter suite: 85 tests passed. A preceding full capture run generated the responsive previews; the added date-glyph regression was included in the final verification. Covers original physics and both drop methods, navigation and Back, drawer/footer, welcome flow, temporary moods/no writes, null/model gates, service errors/retry, period compatibility, spotting/discharge, persistent appointment storage and the original Timeline crash.
- Responsive captures generated at 320/390/430 logical pixels, normal/doubled text, with focused keyboard-inset coverage where a form still has text fields. Preview files are ignored under `build/previews/`. These are Flutter widget-engine images, not device screenshots.
- Inspected Home, welcome, inline mood feedback, all ten ball faces and the 320px/doubled-text period preview. This prompted removing the redundant period introduction, widening the calendar at large text to prevent clipped dates, and separating game numbers from the smiles; final layout captures verify the calendar change.
- Android debug APK built successfully. Installed and launched on connected **A059, Android 16/API 36, arm64**. The emulator is unauthorized and was not used. Final APK-only launch explicitly returned `FLUTTER_RUN_EXIT=0`. No Flutter exception appeared in the launch log; startup/vendor GPU/resource warnings and a skipped-frame notice were emitted, so sustained performance is not verified. No physical haptic-feel, sustained game-performance, TalkBack or device-gesture verification is claimed.
- No health API calls, model inference, retraining, live bookings, calls, emails, community writes or AI integration were performed.
- Git diff whitespace check and final format check are included in the final verification run. No commits or pushes.

Logs in ignored `build/`: `brief-accepted-tests.log`, `brief-complete-device-run.log`, `brief-apk-launch.log`; APK: `build/app/outputs/flutter-apk/app-debug.apk`. Haptic feel/platform differences and a verified authenticated eight-feature model endpoint remain limitations; the visual and unavailable flows remain usable.
