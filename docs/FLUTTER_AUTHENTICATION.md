# Flutter authentication

The entry boundary uses official `supabase_flutter` 2.18.3 (compatible 2.x
constraint). Email/password, signup confirmation, resend confirmation, password
recovery, local sign-out, SDK persisted session restoration and automatic refresh
are implemented. Missing/invalid configuration leaves account actions disabled;
the explicitly labelled synthetic demo remains available.

After reconciling the shared login work from `main`, production startup still
uses `AuthenticationRoot` and `AuraAuthController`. `ControllerAuthService`
adapts that controller to the shared `LoginPage`, registration and recovery
widgets. This retains current-token injection, recovery sign-out, demo isolation
and authenticated PCOS service selection without initializing another SDK client.
Registration forwards display-name metadata. The shell displays account identity
and supports profile sign-out. `AuracareApp(authService: ...)` remains available
for the existing standalone entry flow; the production root passes externally
managed account state and sign-out instead of running a second login flow.
Both controller tests and upstream widget tests are retained in separate files.

Merge reconciliation validation on 2026-10-25: `flutter pub get` succeeded;
`flutter analyze` reported no issues (7.6 seconds); the focused auth/Supabase/PCOS/API
run passed 129 tests; the complete Flutter suite passed 219 tests with zero
failures (3 minutes). This includes the shared login screen driving the API
controller and entering a PCOS-enabled account session. These are mocked tests,
not verification of live Supabase, email delivery, device links or RLS.

## Run and dashboard configuration

From `Auracare_mobile_app/auracare_mobile_app`:

```powershell
flutter pub get
flutter run --debug --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY --dart-define=AURACARE_API_BASE_URL=http://127.0.0.1:8000
```

Use only the project's public anon JWT or publishable key. Never use a service-role
or secret key, user token, or backend credentials in defines. Defines are embedded
in the application, not secret storage. The configuration rejects privileged key
types. No credentials are checked into the app.

In Supabase Authentication, enable email/password signup, enable Confirm email,
configure the password policy and email delivery/SMTP, and add this exact allowed
redirect URL under URL Configuration:

`org.auracare.auracare_mobile_app://auth/callback`

The merged Android/iOS manifests and production SDK handler also accept the
upstream `auracare://auth-callback` URL for existing links. Allow that URL in the
dashboard too if links were issued using the upstream flow. New production
requests continue using the first URL. These routes still require device testing.

Keep email templates compatible with Supabase's verification redirect flow. The
Android manifest registers this callback; Flutter's built-in deep-link navigation
is disabled so the SDK handles PKCE links. Request verification/reset and open the
email link on the same device/app installation (PKCE verifier is stored locally).
Recovery opens a new-password form and never yields an API token; saving the new
password signs out and requires ordinary sign-in. Cross-device links, stale links,
SMTP delivery and cold-start callbacks require physical-device testing. Neither
password reset nor email delivery has been verified end-to-end here.

For USB backend networking, run `adb reverse tcp:8000 tcp:8000` first. For LAN use
the computer's reachable private IP; for the standard emulator use `10.0.2.2`.
Supabase itself requires device internet access over HTTPS. The existing debug
cleartext exception is unchanged; release backend URLs must use HTTPS. See
[networking instructions](FLUTTER_NETWORKING.md).

## Access and local data boundaries

`AuraAuthController` implements the existing `AccessTokenProvider`. Construct
`AuraApiClient(config: ApiConfig.fromEnvironment(), tokenProvider: auth)` only
when explicitly needed, and close it when finished. Each protected call requests
the current verified user token; near-expiry tokens refresh through one shared
refresh operation. Failed refresh denies access. No protected POST is retried.
The FastAPI contract validates the bearer token through Supabase Auth and forwards
it to PostgREST for RLS. An anon key is never used as the user bearer token.

The authenticated PCOS questionnaire now invokes the client only after explicit
review and confirmation; see [PCOS integration](FLUTTER_PCOS_INTEGRATION.md).
Signing in never uploads or migrates data. Each demo/account boundary creates a fresh in-memory health session;
authenticated appointments use a separate memory store and never read the legacy
demo appointment file. Demo SDK events cannot grant account access, including
password-recovery events; exit demo before opening account email links. Demo and
recovery modes never supply tokens. Demo appointments retain their existing local
Android persistence, separate from account sessions.

Signup uses the session returned by that signup response, never an unrelated
session left in the SDK. An empty initial-session event leaves account entry
available and continues listening for subsequent email-confirmation events.

The SDK owns persisted auth session storage and refresh scheduling. Its default
Flutter storage uses platform preferences; Android backup is disabled. This is
not a claim of hardware-backed credential storage. UI errors are fixed local
messages; SDK exceptions, tokens, request bodies and secrets are never displayed
or explicitly logged. SDK debug logging is disabled.

## Google sign-in remains disabled

Repository inspection found no Google sign-in dependency, Google client IDs,
`google-services.json`, or native OAuth setup. Dashboard/provider configuration
was not accessible or verified. There is deliberately no Google button.

Before implementing/enabling Google sign-in:

1. Configure Google Auth Platform branding, consent screen, audience/test users
   and required scopes (`openid`, email and profile).
2. Create a web OAuth client. Register the Supabase project's callback
   `https://YOUR_PROJECT.supabase.co/auth/v1/callback` as an authorized redirect.
   Enable Google in Supabase Authentication Providers and enter the web client ID
   and secret there only. Allow the app callback above in Supabase redirects.
3. For native Android Google sign-in, create Android OAuth clients for application
   ID `org.auracare.auracare_mobile_app` with each actual signing certificate's
   SHA-1 (debug, release and Play App Signing as applicable). Configure the web
   client ID as the native SDK server client ID and register the required client
   IDs with Supabase. Never bundle a client secret. The current release Gradle
   configuration uses debug signing; production signing still needs setup.
4. Choose browser OAuth or a supported native Google SDK implementation, then
   test consent, cancellation, callback, nonce/ID-token exchange if native,
   restoration and sign-out on a physical device before exposing the button.

References: [official package](https://pub.dev/packages/supabase_flutter/versions/2.18.3),
[password recovery](https://supabase.com/docs/reference/dart/auth-resetpasswordforemail),
[Google provider setup](https://supabase.com/docs/guides/auth/social-sign-in/auth-google?platform=flutter).

## Verification limits

Validation commands (from the Flutter app directory):

```powershell
flutter analyze
flutter test test/auth_test.dart test/api_client_test.dart --reporter expanded
flutter test --concurrency=1 --reporter expanded
```

Validation on 2026-10-25: `flutter analyze` reported "No issues found" (6.5 seconds).
The focused authentication/API client run passed all 80 tests (19 authentication
and 61 API client tests, 3 seconds). The full Flutter suite passed all 170 tests
in 1 minute 42 seconds, with no failures. Coverage includes sign-in failure/success,
sign-out, expired token refresh and failure, concurrent refresh, restoration,
unauthenticated transport blocking, demo event/data isolation, recovery, signup
confirmation, late login completion and login loading/validation/failure states.
It also verifies signup response isolation, signup failures and refreshed-token
injection through the real controller into mocked API requests, with no sends
after logout. Existing widget tests exercise onboarding and tab navigation.
An additional `flutter build apk --debug --no-pub` check was cancelled after
Gradle remained in configuration without further output or updated build
artifacts. Android compilation is therefore unverified; the existing APK is not
evidence for this implementation. Physical-device networking was not exercised.

Automated tests use fake auth sessions and mocked HTTP, with synthetic values only.
They do not verify email delivery, device links, Google OAuth, real backend token
validation, or two-user RLS enforcement. No backend code, migrations or policies
are changed by this authentication task. Use disposable accounts and synthetic
data for a separate two-user enforcement check before relying on database isolation.
