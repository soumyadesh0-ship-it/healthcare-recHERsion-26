# AuraCare authentication and cloud-record repair

Repair date: 2026-10-25. The requested `D:\healthcare-recHERsion-26` did not
exist; the user confirmed the available `D:\Projects\auracare-fresh` checkout.
No database records, schema, policies, migration files or migration history were
changed. No Git reset, branch switch, merge, commit or push was performed.

## A. Root causes

The account-unavailable message means the active authentication facade has no
initialized gateway. Flutter does not load backend `.env` files automatically;
`SUPABASE_URL` and `SUPABASE_ANON_KEY` must be supplied as Dart defines when
launching or building. Previously, initialization also caught every SDK failure
and returned the same unconfigured state, hiding the distinction between missing
configuration and an initialization failure.

The merge removed the tracked root `.env`. The original run script still required
that file, so its preparation step failed even though the ignored public
`build/local-model-defines.json` remained. The repaired script accepts that
existing public configuration or an explicit `-PublicConfigFile`, validates it,
and copies only the two public Supabase values into the generated Flutter config.
Neither AI keys nor service-role keys are copied. It sets both API URL aliases,
the callback, and an explicit `HEALTH_PERSISTENCE_ENABLED=false`.

The cloud-record message is a separate, intentional deployment gate. The
authenticated repository is remote; it never silently substitutes a local or
demo repository when the gate is closed. Twelve previously reported application
tables and enabled RLS do not prove the later raw-observation schema is present.

## B. Git and merge findings

Starting HEAD was `162e026` on `main` (matching `origin/main`). The working tree
was clean apart from an unreadable ignored pytest cache. No unresolved index
entries or conflict markers were present. HEAD's tree matched the local
`integration/teammate-ui-pcos` branch. Compared with integration merge `6d1fb40`,
the `lib/` differences were limited to the shell: the intended sidebar Profile
cleanup and a reversal from authenticated `ChatPage` to the older `AssistantPage`.
That reversal reintroduced anonymous prompt-only requests to a backend requiring
authentication and per-message confirmation.

Merge `6d1fb40` introduced the new auth controller and remote-record gate.
`main.dart` uses the new controller; `app/supabase_auth_service.dart` remains a
compatibility implementation exercised by legacy tests, not a second startup
provider. The existing guard that prevents `AuracareApp` from resetting the
authentication root's account state is retained.

Other issues repaired: the controller facade collapsed meaningful auth failures
into a generic rejection; active registration ignored the configured callback;
PCOS read only the older API URL define while chat supported `API_BASE_URL`;
remote errors conflated a disabled gate, missing configuration and missing
schema. Legacy tests still looked for a Profile sidebar item removed by a later
UI commit; they now use the existing account footer without changing the UI.
The current sidebar assistant layout is preserved and now uses the existing
authenticated chat service. Both chat screens share the original confirmation
dialog. Demo mode makes no anonymous requests; failed prompts remain available
for retry. Home still opens its existing authenticated chat screen.

Changed source files (under `Auracare_mobile_app/auracare_mobile_app`):

| File | Repair |
| --- | --- |
| `lib/data/auth_service.dart` | Configuration normalization, configured callback, distinct startup failures and testable single-gateway bootstrap |
| `lib/app/controller_auth_service.dart` | Preserve auth failure categories at the existing UI boundary |
| `lib/app/auth_root.dart` | Accurate connected/unavailable cloud status |
| `lib/features/auth/auth.dart` | Avoid presenting SDK failures as missing configuration |
| `lib/app/quiz_integration.dart` | Honor the same API URL aliases as chat |
| `lib/data/remote_records.dart`, `lib/data/records.dart` | Distinguish gating, configuration, schema and permission failures without losing drafts |
| `lib/features/assistant/assistant.dart`, `lib/features/chat/chat.dart` | Retain both UIs and share the authenticated, confirmed message flow |
| `tool/run_model_quiz.ps1` | Public-only config fallback, validation, both API aliases, prepare-only mode and explicit false storage gate |

Tests cover the active SDK gateway, bootstrap/compiled configuration, remote
failures and authenticated sidebar chat. Existing navigation tests now use the
retained Profile footer. The README links this report. No shell layout, theme,
game implementation, PCOS model, migration or policy was edited.

## C. Active initialization and configuration

`main.dart` -> `initializeAuthentication()` -> `Supabase.initialize()` ->
`SupabaseAuthGateway` -> `AuraAuthController` -> `AuthenticationRoot` ->
`ControllerAuthService` -> the existing branded `LoginPage`.

The controller owns restoration, registration, local sign-out, refresh and
demo/recovery isolation. Each account boundary disposes its previous records;
token refresh does not replace the account's record session. Missing/invalid
public defines remain safely unconfigured; SDK initialization failures now have
a separate sanitized startup failure. Neither path fabricates login success.

The prepared local public configuration passed URL/public-key validation. A
read-only `/auth/v1/settings` request returned HTTP 200 with the email provider
and public signup enabled. This confirms endpoint/key connectivity, not a real user's password
login. All test accounts, tokens and health observations are synthetic/mocked.

The ignored backend `.env.local` was missing the two public Supabase settings.
Only those settings were restored from the validated existing public config;
other local settings were preserved. Flutter configuration remains compile-time.

## D. Database deployment status and exact schema requirements

**Unverified; gate remains false.** No live SQL or database-health-record request
was made. The proposal is
`supabase/migrations/20261025120000_health_observation_persistence.sql`.
The old `HEALTH_MIGRATION_VALIDATION.md` describes an earlier proposal with only
two journal columns; it is not approval for the current expanded migration.

Required `public.health_observations` fields:

- `id`, `user_id`, `client_request_id`, `kind`, `title`, `notes`;
- `observation_date`, `observation_time`, `observation_is_utc`, `timezone_label`;
- `severity`, `mood_category`, `period_start`, `period_end`;
- `tracking_amount`, `tracking_color`, `tracking_consistency`,
  `tracking_odor_change`, `tracking_irritation`;
- `created_at`, `updated_at`, `version`.

Required existing `public.journal_entries` fields include `id`, `user_id`,
`title`, `body`, `entry_date`, `timezone`, `created_at`, `updated_at`, `version`.
The proposal adds **12 fields**: `entry_time`, `entry_is_utc`,
`client_request_id`, `severity`, `mood_category`, `period_start`, `period_end`,
`tracking_amount`, `tracking_color`, `tracking_consistency`,
`tracking_odor_change`, `tracking_irritation`.

Required behavior includes server-owned IDs/owner/audit/version metadata,
`public.set_record_metadata()` triggers, owner/date/kind indexes, per-owner
`client_request_id` uniqueness, owner-only CRUD RLS, correct column grants,
timestamp-pair/type/enum/length checks and version-conditional updates/deletes.
The journal body check must support the current optional empty body and the
50,000-character storage limit. Existing records must remain intact.

The two historical migrations share version `20261025`, and applied migration
history was not verified. Do not replay the initial/extended CREATE TABLE files,
rename deployed migrations, or repair history to bypass that uncertainty.

Approval is required for a qualified operator to verify the intended database
catalog/history, reconcile the baseline, review the **current** proposal, test
it on an isolated staging copy with synthetic users and RLS/privilege tests,
then authorize deployment. Only after that evidence should an authenticated
test build enable health persistence. Enabling a Dart define alone is not a
database deployment.

## E. Validation

| Check | Final result |
| --- | --- |
| `flutter analyze` | Passed; no issues |
| Focused auth suite | 70 passed |
| Focused `remote_records_test.dart` | 52 passed |
| Actual local Dart-defines bootstrap test | 1 passed; fake gateway, no network |
| Focused chat/navigation regression suite | 18 passed |
| Full `flutter test --concurrency=1` | **357 passed**, 0 failed, 1m38s |
| Offline backend and schema-contract tests | 140 passed, 13 subtests passed; one existing Starlette/httpx deprecation warning |
| `flutter build apk --debug` with public defines and false health gate | Passed; exit code 0, final Gradle build 17.6s |
| `git diff --check` | Passed |
| Conflict-marker scan / unmerged index | No markers / 0 unmerged files |

APK: `Auracare_mobile_app/auracare_mobile_app/build/app/outputs/flutter-apk/app-debug.apk`.
The APK was built for validation and was not installed during this repair.

Ignored logs in the app's `build/` folder: `repair-flutter-analyze.log`,
`repair-auth-tests.log`, `repair-remote-tests.log`, `repair-configured-test.log`,
`repair-chat-navigation-tests.log`, `repair-full-tests.log`,
`repair-android-build.log`. The first full run exposed the stale Profile helper;
the reported final run includes its fix and the authenticated-sidebar tests.

## F. Exact local launch commands

From PowerShell, with the phone attached and FastAPI running on port 8000:

```powershell
cd D:\Projects\auracare-fresh\Auracare_mobile_app\auracare_mobile_app
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\run_model_quiz.ps1 -ApiBaseUrl http://127.0.0.1:8000 -AllowLocalApi -PrepareOnly
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s ZD2229TJMM reverse tcp:8000 tcp:8000
flutter run --debug -d ZD2229TJMM --dart-define-from-file=build/local-model-defines.json --dart-define=HEALTH_PERSISTENCE_ENABLED=false --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process
```

The JSON supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE_URL`,
`AURACARE_API_BASE_URL`, `AURACARE_ALLOW_LOCAL_API`, `AURACARE_AUTH_REDIRECT_URL`
and the false health flag. No key values appear in these commands. On another
machine provide the existing project's public values in an ignored root `.env`
or pass `-PublicConfigFile` pointing to a local public JSON file. If neither
exists, preparation stops safely rather than creating fake configuration.

Changing Dart defines requires stopping and relaunching Flutter; hot reload does
not change them. Register the callback used by the build in the existing
Supabase project's redirect allowlist. Android already supports both retained
callback formats. No new project is needed.
