# Flutter networking infrastructure

The Flutter API client is used by the authenticated PCOS questionnaire and
authenticated AI chat in
`Auracare_mobile_app/auracare_mobile_app/lib/data/api_client.dart`. The quiz
requires explicit review and confirmation; every chat message separately
requires explicit AI-processing confirmation. Health records use a separate
authenticated repository behind a deployment gate that is off by default; see
[PCOS integration](FLUTTER_PCOS_INTEGRATION.md) and the mobile README's
migration warning. Demo repositories remain local and session-only.
Account entry, Supabase initialization and session persistence are now implemented; see [authentication setup](FLUTTER_AUTHENTICATION.md).

## Configuration and ownership

Construct `ApiConfig.fromEnvironment()` to read
`--dart-define=AURACARE_API_BASE_URL=...`. There is no fallback URL: missing or
invalid configuration fails closed when the client is explicitly constructed.
The app can still launch without a define, but authenticated API requests will
show a safe configuration error. URLs may include a reverse-proxy path prefix.

Inject an `AccessTokenProvider` whose `accessToken()` returns the current Supabase
**user access token** or null. The client asks afresh for every authenticated
request, with request-local headers. Never supply an anon key, service-role key,
Gemini key, or tokens through `--dart-define`. Build defines are not secret storage.
Use AuraAuthController as this provider; see authentication setup for SDK storage and refresh behavior.

`AuraApiClient` accepts an optional `http.Client` for tests. Call `close()` when
finished: owned transports are closed and pending requests are aborted. Injected
transports remain owned by their caller. There are no automatic network calls,
retries, caches, logging, analytics, token refreshes or sign-out side effects.
Do not add request/body logging in future adapters or interceptors.

## Contracts

- `chat(prompt: ..., aiProcessingConfirmed: ...)` uses `POST /chat`. Confirmation
  must reflect an explicit user action for sending that prompt to Gemini. False
  is rejected locally without acquiring a token. It is not durable legal consent.
- `predictPcos(PcosSurveyAnswers(...))` uses `POST /predict-pcos`, preserving
  booleans and unknown/null answers. `PcosAssessment` exposes the server response;
  `riskScore` is a symptom count, never a clinical risk/probability. This contract
  is deliberately separate from the existing six-question demo model: no implicit
  conversion or screen integration has been added.
- `checkConnection()` requests only public `GET /openapi.json`, without consulting
  the token provider or sending Authorization. True means both expected POST
  paths appear in the public schema; false means a different contract. Failure
  throws a safe `ApiException`. This does not test Supabase, Gemini, auth or RLS.
  No new backend endpoint was needed.

The Home screen's AI Assistant opens chat for signed-in users. Demo mode labels
chat unavailable and sends no prompt. Each authenticated message is submitted
alone; neither records nor prior chat messages are sent as context. Responses
are general information, not diagnosis or treatment.

Default timeout is 45 seconds for the entire operation, including token lookup,
connection and response reading; it is injectable for tests. Timeout triggers
HTTP request abortion and prevents a late token from causing a later send. A
server may already have processed a timed-out write: do not retry blindly.

Failures contain fixed local messages and status metadata, never raw server
bodies or SDK exception text. `401` maps to unauthenticated, `403` forbidden,
`400/422` validation, `429` rateLimited and `5xx` unavailable. Integer Retry-After
seconds are exposed when supplied. No automatic token refresh or POST retry is
performed. Redirects are disabled to avoid forwarding tokens or resubmitting
health text to another destination. Successful response shapes are validated.

## Android development configurations

From the repository root, start the backend manually when a later diagnostics
check is wanted:

```powershell
python -m uvicorn service.main:app --host 0.0.0.0 --port 8000
```

Backend startup still requires its local server-side Supabase configuration.
These instructions do not apply migrations or establish RLS safety.

From `Auracare_mobile_app/auracare_mobile_app`, select the appropriate debug URL:

| Target | Backend URL | Notes |
| --- | --- | --- |
| Standard Android emulator | `http://10.0.2.2:8000` | Host-machine loopback alias |
| Physical Android phone on LAN | `http://192.168.1.20:8000` | Example only; replace with computer's actual LAN IPv4 address |
| Physical Android phone over USB | `http://127.0.0.1:8000` | First configure ADB reverse |

```powershell
# Emulator
flutter run --debug --dart-define=AURACARE_API_BASE_URL=http://10.0.2.2:8000

# Physical phone on the same reachable LAN; substitute the computer's IP.
flutter run --debug --dart-define=AURACARE_API_BASE_URL=http://192.168.1.20:8000

# USB: authorize debugging on the phone, then select its device if needed.
adb devices
adb reverse tcp:8000 tcp:8000
flutter run --debug --dart-define=AURACARE_API_BASE_URL=http://127.0.0.1:8000
# Remove the mapping when finished:
adb reverse --remove tcp:8000
```

For multiple devices, use `adb -s DEVICE_SERIAL ...` and
`flutter run -d DEVICE_ID ...`. LAN access needs a reachable backend listener and
a suitably scoped firewall rule; guest Wi-Fi/AP isolation can prevent access.
Phone localhost means the phone unless ADB reverse is active. These run commands
configure the dormant infrastructure; they do not connect the existing UI.

The main Android manifest adds INTERNET permission for HTTPS networking in all
builds. Cleartext is allowed **only in the debug manifest**. In Dart, HTTP is also
restricted to debug builds, explicit opt-in, and localhost/private IPv4 addresses.
`ApiConfig.fromEnvironment()` supplies that opt-in only in debug mode. Profile and
release require HTTPS regardless of any supplied opt-in. No certificate-validation
bypass or release cleartext exception was added. Use synthetic data and disposable
test tokens for HTTP development; it is not a secure transport for real health
information. Production must supply a configured HTTPS URL.

Flutter Web would additionally need a backend CORS policy; native Android does
not use browser CORS. Web deployment is not configured in this task.

## Verification

```powershell
flutter pub get
flutter analyze
flutter test test/api_client_test.dart --reporter expanded
flutter test --concurrency=1 --reporter expanded
```

Tests use `http/testing.dart` MockClient, synthetic JSON and fake token providers;
they never instantiate a real API connection. Physical-device connectivity,
release APK behavior and two-user database enforcement need separate verification.

References: [Flutter HTTP networking](https://docs.flutter.dev/cookbook/networking/fetch-data),
[HTTP package and abortable requests](https://pub.dev/packages/http),
[Android emulator addresses](https://developer.android.com/studio/run/emulator-networking-address),
[Android network security configuration](https://developer.android.com/privacy-and-security/security-config).
