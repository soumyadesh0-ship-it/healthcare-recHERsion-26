# Auracare mobile demo

The local UI integration combines `md_modification`'s navigation drawer,
five destinations and wellbeing controls with the authenticated PCOS flashcards
and trained-model service on `main`. Profile, Learn and Insights are available
from the drawer; PCOS Quiz and Wellbeing are bottom destinations. See
[integration notes](../../docs/TEAM_UI_INTEGRATION.md).

PCOS flashcards and real Random Forest serving through the shared FastAPI:
[integration, local USB setup and validation](../../docs/PCOS_MODEL_INTEGRATION.md).
Signed-in quiz submission uses the configurable API URL and current Supabase
token; demo mode remains an explicitly offline fixture flow.

Current game, spotting/discharge and fictional directory: [implementation and verification](../../docs/AURACARE_UNWIND_TRACKING.md). No new dependencies. Health/game state remains session-only.

Phase 3 features, data handling, sources and verification: [Cycle estimates, Doctor and Learn](../../docs/AURACARE_PHASE3.md). Doctor appointments now persist in app-private Android storage; the original health records remain session-only.

Current UI refinements, logo assets, changed files and device/test results: [AuraCare refinement](../../docs/AURACARE_REFINEMENT.md).

Flutter/Dart mobile app using the team's existing Supabase project for email/password authentication. Health records and other app data still use a shared in-memory synthetic session: they are not stored in the account or uploaded. Do not enter real health information. Android remembers first-run onboarding completion using a native SharedPreferences flag. Restarting starts with empty records. Samples are loaded only through the explicit demo action. The Supabase Flutter client persists authentication sessions locally; the app uses only the public project URL and publishable/anon key.

Implemented: original flat geometric characters, white/pastel UI, welcome screen, three onboarding pages, sample/empty entry, Home/Timeline/Learn/Insights/Profile tabs, symptom/wellbeing/journal/bleeding record CRUD, date/type filters, optional cycle day selection, source-linked descriptive coverage, selected appointment preparation and clipboard summary, question management, synthetic JSON export/reset, and experimental PCOS quiz with fixture/failure/unavailable states. Learn topics are structural previews without invented articles or review credentials.

## Run

Generated and checked with Flutter **3.47.8**, Dart **3.13.7**. The generated SDK constraint is preserved in pubspec.yaml; no packages were downgraded. Runtime dependencies include Flutter, the official Supabase Flutter client, and `http` for authenticated PCOS model requests.

From this folder, with the Flutter SDK on PATH and an Android/iOS development device ready:

```powershell
flutter pub get
```

Configure the app with the same `SUPABASE_URL` and public `SUPABASE_ANON_KEY` used by `service/main.py`. From this folder, this PowerShell snippet reads only those two values from the repository-root `.env` without printing them:

```powershell
$settings = @{}
Get-Content (Join-Path (Resolve-Path ..\..) '.env') | ForEach-Object {
  if ($_ -match '^\s*(SUPABASE_URL|SUPABASE_ANON_KEY)\s*=\s*(.*?)\s*$') {
    $settings[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
  }
}
if (-not $settings['SUPABASE_URL'] -or -not $settings['SUPABASE_ANON_KEY']) {
  throw 'Both public Supabase client settings must be configured.'
}
flutter run `
  --dart-define="SUPABASE_URL=$($settings['SUPABASE_URL'])" `
  --dart-define="SUPABASE_ANON_KEY=$($settings['SUPABASE_ANON_KEY'])" `
  --dart-define="AURACARE_AUTH_REDIRECT_URL=auracare://auth-callback"
```

If `.env` is unavailable, obtain the project URL and publishable/anon key from the existing Supabase project and pass them as `--dart-define` values. Never use a service-role/secret key. Without both Dart defines the app intentionally shows the unavailable-provider state instead of attempting authentication.

#### Supabase Auth dashboard setup

- Use the existing project referenced by the backend configuration; do not create another project.
- Add `auracare://auth-callback` to **Authentication → URL Configuration → Redirect URLs**. Android registers this URI in `android/app/src/main/AndroidManifest.xml`.
- Enable email/password signup. If email confirmation is enabled, configure delivery (SMTP/email templates) and verify that the confirmation link redirects to `auracare://auth-callback`. The app keeps the user at login until Supabase confirms a session.
- Configure the password-recovery email template to return to the same allowed redirect URI. Supabase Flutter handles the PKCE callback and the app then presents its new-password form.
- Google OAuth is intentionally disabled: the repository contains no Google provider setup, OAuth client IDs, signing fingerprints, or official Google logo asset. To enable it, configure Google OAuth in Google Cloud and Supabase Auth, register the Android package `org.auracare.auracare_mobile_app` and its signing SHA fingerprints, add the required redirect URI to Supabase, and provide an official Google logo asset. Do not put OAuth client secrets in the app.

The existing `public.profiles` table has `id` tied to `auth.users` and an optional `display_name` limited to 100 characters; its RLS permits users to access only their own row. There is no profile-creation trigger. Registration sends the validated full name as Supabase Auth user metadata under `display_name` and the app reads it for the signed-in profile; this implementation does not add a migration or write a profile row. The backend's existing token verification remains unchanged.

Authentication is separate from demo data. On entry to a real account, previous local demo/session records are cleared. The Home and feature UI continues to use session-only records; login does not upload or attach them to an account.

On the audited Windows machine the SDK is outside PATH:

```powershell
$env:Path = "C:\Users\Soumya\flutter\bin;$env:Path"
flutter devices
```

Then run the Supabase-configured command above so the public client configuration is included in the build.

See [redesign verification](../../docs/AURACARE_REDESIGN.md) for the current UI changes and verification. The following notes describe the original implementation audit: Android Doctor reported missing command-line tools and unknown license status. The debug build attempt failed when Gradle's JVM exhausted memory; test runs also initially encountered full disk space. Free adequate disk/RAM and complete the Android toolchain before building. iOS requires macOS/Xcode; no iOS build was attempted on Windows. Signing/provisioning has not been customized.

## Minimal AI chat on a USB-connected Android phone

Home and the navigation drawer open **AI Assistant** at `/app/assistant`.
The Flutter client sends only `{"prompt":"your message"}` to `POST /chat`
and displays the returned `response`. No conversation history or health records
are included. Configure `GEMINI_API_KEY` only in the FastAPI backend environment
or repository-root `.env.local` (ignored by Git), then restart the backend.
The root `.env` is tracked in this repository; do not put the Gemini key there.

With FastAPI running on port 8000, forward the phone's loopback port and add
the chatbot URL to your existing configured Flutter run command:

```powershell
adb -s ZD2229TJMM reverse tcp:8000 tcp:8000
flutter run -d ZD2229TJMM --dart-define-from-file=build/local-model-defines.json --dart-define=API_BASE_URL=http://127.0.0.1:8000 --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process
```

The defines file above is the existing local public client configuration, generated
by `tool/run_model_quiz.ps1`; it must never contain the Gemini key. `API_BASE_URL`
is separate from the existing quiz configuration. Rebuild when changing it.
Loopback HTTP is permitted by the existing Android debug network configuration.
Use HTTPS for a hosted backend.

Chat provider calls have a 20-second HTTP timeout and a 25-second total deadline.
Provider timeouts return HTTP 504; overload returns 503 and rate limits return 429.
Flutter shows a retry message and keeps the prompt when a request fails.

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

Quiz keys match `auracare_pcos/quiz_contract.json`. Unknown answers stay null;
known diagnosis routes to tracking. Signed-in submissions use the separate
`/pcos/model-assessment` endpoint with configurable `AURACARE_API_BASE_URL`.
Demo fixtures run no model. Neither mode displays clinical risk bands or personal
PCOS probabilities. See the integration guide above for exact local and HTTPS setup.

See [Mobile UI handoff](../../docs/MOBILE_UI_HANDOFF.md) for the audit, scope checklist, command results, overrides and remaining integration work.
