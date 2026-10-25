# Auracare mobile demo

Supabase email/password account entry is implemented. See [authentication configuration and verification limits](../../docs/FLUTTER_AUTHENTICATION.md). Google sign-in remains disabled. Historical UI-only notes below predate authentication.

The authenticated PCOS questionnaire can submit four disclosed fields after
explicit confirmation. Authenticated AI chat uses `POST /chat` and asks for
per-message AI-processing confirmation; see [network configuration](../../docs/FLUTTER_NETWORKING.md)
and [PCOS mapping and limits](../../docs/FLUTTER_PCOS_INTEGRATION.md).
Journal, symptom, cycle and wellbeing records use the authenticated remote
repository only when the health-persistence deployment gate is enabled. The
gate is off by default; no cloud persistence is claimed. Demo records remain
separate and session-only.

Current game, spotting/discharge and fictional directory: [implementation and verification](../../docs/AURACARE_UNWIND_TRACKING.md). No new dependencies. Game state remains session-only.

Phase 3 features, data handling, sources and verification: [Cycle estimates, Doctor and Learn](../../docs/AURACARE_PHASE3.md). Doctor appointments persist in app-private Android storage.

Current UI refinements, logo assets, changed files and device/test results: [AuraCare refinement](../../docs/AURACARE_REFINEMENT.md).

Flutter/Dart mobile app using the team's existing Supabase project for email/password authentication. Demo records and other demo state are in-memory and session-only. Authenticated health records require the explicit migration gate and a deployed, verified schema; the gate is off by default. Do not enter real health information until deployment, RLS and privacy controls are verified. Android remembers first-run onboarding completion using a native SharedPreferences flag. Demo samples are loaded only through the explicit demo action. The Supabase Flutter client persists authentication sessions locally; the app uses only the public project URL and publishable/anon key.

Implemented: original flat geometric characters, white/pastel UI, welcome screen, three onboarding pages, sample/empty entry, Home/Timeline/Learn/Insights/Profile tabs, symptom/wellbeing/journal/bleeding record CRUD, date/type filters, optional cycle day selection, source-linked descriptive coverage, selected appointment preparation and clipboard summary, question management, synthetic JSON export/reset, experimental PCOS quiz with fixture/failure/unavailable states, and authenticated AI chat. Learn topics are structural previews without invented articles or review credentials.

## Integrated navigation and API flows

The app keeps the five destinations (Home, Timeline, Wellbeing, Doctor and PCOS Quiz),
the drawer, the Insights activity UI and the Sisterhood prototype. The authenticated
controller supplies tokens to both the trained-model PCOS endpoint and the separately
confirmed four-field survey endpoint. The model questionnaire takes priority when its
service is configured; the survey UI remains available when only that service is supplied.
AI Assistant opens the authenticated chat with confirmation for each message. Gemini is
used when GEMINI_API_KEY is configured; otherwise the incoming OpenAI integration is used.
Provider credentials belong only in the backend environment or ignored root .env.local.

For the connected Android phone, keep FastAPI running on port 8000 and use:

```powershell
adb -s ZD2229TJMM reverse tcp:8000 tcp:8000
flutter run -d ZD2229TJMM --dart-define-from-file=build/local-model-defines.json --dart-define=API_BASE_URL=http://127.0.0.1:8000 --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process
```

The existing local defines file contains only public client configuration. No AI key is
compiled into Flutter. The Gemini call has a 20-second transport timeout and a 25-second
total deadline, with no automatic retries.

## Run

Generated and checked with Flutter **3.47.8**, Dart **3.13.7**. The generated SDK constraint is preserved in pubspec.yaml; no packages were downgraded. Runtime dependencies include Flutter, the official Supabase Flutter client and `http` for authenticated API/record requests.

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
# Android emulator backend URL; see FLUTTER_NETWORKING.md for phone targets.
flutter run `
  --dart-define="SUPABASE_URL=$($settings['SUPABASE_URL'])" `
  --dart-define="SUPABASE_ANON_KEY=$($settings['SUPABASE_ANON_KEY'])" `
  --dart-define="AURACARE_API_BASE_URL=http://10.0.2.2:8000"
```

If `.env` is unavailable, obtain the project URL and publishable/anon key from the existing Supabase project and pass them as `--dart-define` values. Never use a service-role/secret key. Without both Dart defines the app intentionally shows the unavailable-provider state instead of attempting authentication.

#### Supabase Auth dashboard setup

- Use the existing project referenced by the backend configuration; do not create another project.
- Add `org.auracare.auracare_mobile_app://auth/callback` to **Authentication → URL Configuration → Redirect URLs**. Android registers this URI in `android/app/src/main/AndroidManifest.xml`. The app accepts the older `auracare://auth-callback` URI for previously issued links.
- Enable email/password signup. If email confirmation is enabled, configure delivery (SMTP/email templates) and verify that the confirmation link redirects to `org.auracare.auracare_mobile_app://auth/callback`. The app keeps the user at login until Supabase confirms a session.
- Configure the password-recovery email template to return to the same allowed redirect URI. Supabase Flutter handles the PKCE callback and the app then presents its new-password form.
- Google OAuth is intentionally disabled: the repository contains no Google provider setup, OAuth client IDs, signing fingerprints, or official Google logo asset. To enable it, configure Google OAuth in Google Cloud and Supabase Auth, register the Android package `org.auracare.auracare_mobile_app` and its signing SHA fingerprints, add the required redirect URI to Supabase, and provide an official Google logo asset. Do not put OAuth client secrets in the app.

The existing `public.profiles` table has `id` tied to `auth.users` and an optional `display_name` limited to 100 characters; its RLS permits users to access only their own row. There is no profile-creation trigger. Registration sends the validated full name as Supabase Auth user metadata under `display_name` and the app reads it for the signed-in profile; this implementation does not add a migration or write a profile row. The backend's existing token verification remains unchanged.

Authentication is separate from demo data. On entry to a real account, previous local demo/session records are cleared. The `/chat` prompt is sent only after the user confirms AI processing; records and chat history are not attached. Health records remain blocked for authenticated sessions until the deployment gate is explicitly enabled after migration and RLS validation.

On the audited Windows machine the SDK is outside PATH:

```powershell
$env:Path = "C:\Users\Soumya\flutter\bin;$env:Path"
flutter devices
```

Then run the Supabase-configured command above so the public client configuration is included in the build.

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

Authenticated health records now use `RemoteRecordsRepository` through
`AuthenticationRoot`; demo mode retains its separate in-memory repository.
Cloud access is **disabled by default** with no local fallback. Enable
`--dart-define=HEALTH_PERSISTENCE_ENABLED=true` only after applying and validating
the proposed `20261025120000_health_observation_persistence.sql` in an isolated
Supabase test project with synthetic users. Supply the existing `SUPABASE_URL`
and publishable `SUPABASE_ANON_KEY` definitions for that test project. Never put
service-role keys in Flutter. No SQL was deployed or live persistence verified.

The unapplied proposal now adds journal metadata, nullable legacy observation
times, empty-body support and per-owner create retry keys; it narrows journal
write grants and reserves record UUIDs/audit/version metadata for the server.
Do not replay historical migrations or repair migration history. An operator
must first confirm the known table/constraint/trigger definitions and grants,
then apply only the reviewed proposal to an isolated baseline. Run
`supabase/tests/health_persistence_smoke.sql` there as the test operator; it uses
synthetic users and rolls back. It has not been executed here. Verify RLS with
two test accounts and anonymous access before enabling the gate. Refresh the
PostgREST schema cache after the migration (operator SQL:
`NOTIFY pgrst, 'reload schema';`) so the new columns and conflict constraints are
recognized. Live SQL
requires separate explicit approval. Existing audit documents describe the
earlier proposal and are not a deployment attestation for this revision.

Mocked checks: `flutter test test/remote_records_test.dart`; offline schema
checks: `python -m pytest supabase/tests -q -p no:cacheprovider` from repo root.
Authenticated screens provide load/error/retry/refresh status. All supported
entry types share this repository; no demo records are imported. A timed-out
write may already have committed remotely: create retries reuse the same
request key; update/delete conflicts require refresh and reopening the record.

- `lib/app`: root, immutable theme tokens, shared session and state-preserving shell.
- `lib/core`: reusable cards, typography, status/confirmation/clipboard helpers and original character painter.
- `lib/data`: typed records and interfaces for records, resources, quiz and account/privacy; demo implementations and descriptive summaries.
- `lib/features`: onboarding, home, logging, timeline, cycle, journal, chat, learn, insights, appointments, profile and pcos_quiz.
- `test`: focused domain, workflow and layout verification; `tool`: explicit development utilities.

Timezones: device-local wall clock or explicit UTC for new entries. Existing dates retain their original label/components; no IANA conversion is claimed. Mild/Moderate/Severe/Unspecified is a prototype scale. Journals start excluded from appointment selection. Clipboard copies leave the session and are not erased by reset.

Quiz keys follow the supplied brief, not a verified local model contract. Unknown answers stay null; known diagnosis routes to tracking. Demo fixtures run no model and show no risk band/percentage. Replace the service only after contract/privacy/safety validation; no speculative endpoint is configured.

See [Mobile UI handoff](../../docs/MOBILE_UI_HANDOFF.md) for the audit, scope checklist, command results, overrides and remaining integration work.
