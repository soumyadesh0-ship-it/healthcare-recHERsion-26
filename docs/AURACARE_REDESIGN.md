# AuraCare Flutter UI redesign

Implemented directly in `Auracare_mobile_app/auracare_mobile_app`, the existing Android Studio Flutter application. No new app, dependencies, Gradle changes, SDK path changes, or package ID changes.

## Design and screens

The detailed HabitZ-style brief supplied the design direction. Reference screenshots were not attached to this session, so pixel-level matching to those images could not be verified.

- `lib/app/theme.dart`: centralized requested palette, white surfaces, black headings, Roboto sans-serif, purple actions, rounded inputs and flat cards.
- `lib/core/characters.dart`: six reusable, original CustomPainter characters, expressive moods and welcome cluster. Local vector-style drawing; no network assets.
- `lib/core/widgets.dart`: shared flat cards, empty-state character and compatibility Blossom wrapper.
- `lib/features/onboarding/onboarding.dart`: welcome composition and three illustrated onboarding pages, indicators and circular Next action; original sample/empty and setup choices retained.
- `lib/app/app.dart`, `lib/app/setup_preference.dart`, Android `MainActivity.kt`: native preference channel remembers only setup completion. Returning launches open Home with empty session records. Unsupported platforms fall back to first-run onboarding. Sample loading remains explicit.
- `lib/app/shell.dart`: existing five destinations and state retention, white bottom bar, selected pastel indicator and Home profile shortcut.
- `lib/features/home/home.dart`: compact pink greeting, visible Log entry action, pastel feature cards and original secondary destinations.
- `lib/features/logging/editor.dart`: Period/Symptoms/Mood/Notes chooser and six-mood selection. Continue opens the original wellbeing editor, with Mood selected and the chosen feeling in an editable note. The original save, retry, validation, cancellation and deletion logic is retained.
- `lib/core/calendar.dart`, `lib/features/timeline/timeline.dart`, `lib/features/cycle/cycle.dart`: Monday-first month calendar, previous/next controls, pink period highlights and record-type markers. Selecting a Timeline date uses its existing date filter; Clear date filter restores the full list. Cycle opt-in and selected-day recording remain. Calendar scrolls horizontally when necessary to retain touch targets at small widths/large text. No predictions were added.
- `lib/features/learn/learn.dart`: all existing categories, search and filter retained, pastel topic cards, unavailable articles still labeled as previews.
- `lib/features/insights/insights.dart`: Overview/Source records tabs, actual coverage counts and source-linked records. No chart is shown for an empty range; a lavender empty state is used.
- `lib/features/profile/profile.dart`: illustrated avatar and expandable settings rows. Existing tracking, timezone, motion, privacy preferences, corrections, export, reset and sample/failure controls remain accessible.

Journal, appointment preparation and PCOS questionnaire inherit the shared UI styling. Their data models, services, questions, exports and underlying logic were preserved. `lib/data/records.dart`, `lib/data/services.dart` and `lib/app/session.dart` were not changed. The project remains an in-memory synthetic demo; the redesign does not add authentication, medical content, AI services or persistent health storage.

## Verification

- Dart formatting completed for `lib` and `test`.
- `flutter analyze`: no issues found.
- Full Flutter suite: **29 tests passed**. Includes existing record CRUD/failure/versioning, journal cancellation, quiz boundaries, appointment selection/export, tab/search state and record propagation; added setup flag, mood saving and calendar navigation tests.
- Layout tests cover 320, 390 and 430 logical pixel widths, normal and 200% text, keyboard insets, splash, onboarding, log chooser, mood picker, cycle, forms and quiz.
- Rendered widget previews were generated in ignored `build/previews/`. These are test-rendered previews, not emulator screenshots. Home, mood and large-text onboarding previews were visually inspected.
- `flutter build apk --debug` succeeded. The final x64 emulator-target rebuild after the last typography adjustments also succeeded (49 Gradle tasks; exit code 0). Its APK is `build/app/outputs/flutter-apk/app-debug.apk`; this final artifact targets x64 emulators.
- Android emulator verification: the first emulator boot remained offline. A lower-memory cold boot after tests also remained offline. Runtime UI and native preference persistence could not be verified in an emulator; no physical phone installation was performed.

First-run completion is checked with a mocked Android method channel in widget tests; native end-to-end verification depends on a working Android emulator/device. The preference flag contains no health records. Clearing Android application storage resets first-run completion.
