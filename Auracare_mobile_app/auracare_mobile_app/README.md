# Auracare mobile demo

Phase 3 features, data handling, sources and verification: [Cycle estimates, Doctor and Learn](../../docs/AURACARE_PHASE3.md). Doctor appointments now persist in app-private Android storage; the original health records remain session-only.

Current UI refinements, logo assets, changed files and device/test results: [AuraCare refinement](../../docs/AURACARE_REFINEMENT.md).

Flutter/Dart mobile UI with a shared in-memory synthetic session. No real account, secure persistence, health uploads, model, AI service, community or provider integration is connected. Do not enter real health information. Android remembers first-run onboarding completion using a native SharedPreferences flag. Health records and other session preferences remain in memory; restarting starts with empty records. Samples are loaded only through an explicit demo action. No sensitive-text storage package is used.

Implemented: original flat geometric characters, white/pastel UI, welcome screen, three onboarding pages, sample/empty entry, Home/Timeline/Learn/Insights/Profile tabs, symptom/wellbeing/journal/bleeding record CRUD, date/type filters, optional cycle day selection, source-linked descriptive coverage, selected appointment preparation and clipboard summary, question management, synthetic JSON export/reset, and experimental PCOS quiz with fixture/failure/unavailable states. Learn topics are structural previews without invented articles or review credentials.

## Run

Generated and checked with Flutter **3.47.8**, Dart **3.13.7**. The generated SDK constraint is preserved in pubspec.yaml; no packages were downgraded. Only Flutter SDK and standard Flutter test/lint tooling are dependencies.

From this folder, with the Flutter SDK on PATH and an Android/iOS development device ready:

```powershell
flutter pub get
flutter run
```

On the audited Windows machine the SDK is outside PATH:

```powershell
$env:Path = "C:\Users\Soumya\flutter\bin;$env:Path"
flutter devices
flutter run
```

See [redesign verification](../../docs/AURACARE_REDESIGN.md) for the current UI changes and verification. The following notes describe the original implementation audit: Android Doctor reported missing command-line tools and unknown license status. The debug build attempt failed when Gradle's JVM exhausted memory; test runs also initially encountered full disk space. Free adequate disk/RAM and complete the Android toolchain before building. iOS requires macOS/Xcode; no iOS build was attempted on Windows. Signing/provisioning has not been customized.

## Validate

```powershell
dart format --output=none --set-exit-if-changed lib test tool/render_native_artwork.dart
flutter analyze
flutter test --concurrency=1
flutter build apk --debug
```

`flutter analyze` failed at analysis-server startup on the workspace's Unicode path. A line-protocol fallback checks the actual package without modifying the SDK:

```powershell
python tool/analyze_fallback.py C:/Users/Soumya/flutter
```

Optional rendered widget captures (not emulator screenshots), using fonts already bundled with Flutter:

```powershell
flutter test test/layout_test.dart --concurrency=1 --dart-define=CAPTURE_PREVIEWS=true --dart-define=FLUTTER_SDK=C:/Users/Soumya/flutter
```

Output: ignored `build/previews/` PNGs at 320/390/430 logical pixels, normal/200% text, including simulated keyboard insets. Native launcher images were rendered from the original Flutter-painted blossom; regenerate explicitly with `flutter test tool/render_native_artwork.dart`. No official logo is claimed.

## Structure and integration

- `lib/app`: root, immutable theme tokens, shared session and state-preserving shell.
- `lib/core`: reusable cards, typography, status/confirmation/clipboard helpers and original character painter.
- `lib/data`: typed records and interfaces for records, resources, quiz and account/privacy; demo implementations and descriptive summaries.
- `lib/features`: onboarding, home, logging, timeline, cycle, journal, learn, insights, appointments, profile and pcos_quiz.
- `test`: focused domain, workflow and layout verification; `tool`: explicit development utilities.

Timezones: device-local wall clock or explicit UTC for new entries. Existing dates retain their original label/components; no IANA conversion is claimed. Mild/Moderate/Severe/Unspecified is a prototype scale. Journals start excluded from appointment selection. Clipboard copies leave the session and are not erased by reset.

Quiz keys follow the supplied brief, not a verified local model contract. Unknown answers stay null; known diagnosis routes to tracking. Demo fixtures run no model and show no risk band/percentage. Replace the service only after contract/privacy/safety validation; no speculative endpoint is configured.

See [Mobile UI handoff](../../docs/MOBILE_UI_HANDOFF.md) for the audit, scope checklist, command results, overrides and remaining integration work.
