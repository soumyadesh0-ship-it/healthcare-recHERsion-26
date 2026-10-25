# PCOS flashcards and trained model integration

The Flutter quiz has two explicit modes. Demo mode retains its labeled synthetic
fixture/failure/unavailable flow and never calls FastAPI. Signed-in mode submits
the reviewed questionnaire to `POST /pcos/model-assessment` using the current
Supabase user's access token. It never substitutes a demo result for a failed
live request. Unknown answers remain null; missing BMI is supported.

## Backend

The existing `POST /predict-pcos` remains the authenticated four-question count
summary with its original response and persistence behavior. The new endpoint is
independent: it performs real inference and does not persist submitted answers.

`service/pcos_model.py` loads only the supplied `random_forest.joblib`, once at
startup, after checking SHA-256
`102296849d064dab86c97bdc260f99a11af1bf503e7be6acab7cd93f2efab1b1`
against the delivered package identity. It verifies feature order, calibrated
Random Forest type, and target class order. Requests cannot supply a model path.
The fitted pipeline includes its original imputation and calibration. No model
was retrained and no artifact or raw dataset was modified.

The exact serialization-compatible model library versions are in
`service/requirements.txt`. An unavailable/incompatible artifact leaves existing
endpoints usable and produces a generic 503 for requests requiring inference.
Unknown answers, age limits, and known-diagnosis routing abstain without scoring.
The API rejects unknown fields, invalid types, non-finite values, non-binary
answers, and supplied BMI outside 10–70. Age outside the experimental 18–45
scope produces an explicit abstention. Supabase verifies every model request;
authentication failures and validation errors do not echo private values.

From the repository root on this Windows machine:

```powershell
python -m venv .venv-pcos
.\.venv-pcos\Scripts\python.exe -m pip install -r service/requirements.txt httpx
.\.venv-pcos\Scripts\python.exe -m uvicorn service.main:app --host 127.0.0.1 --port 8000 --no-access-log
```

The root `.env` must contain the team's existing `SUPABASE_URL` and public
`SUPABASE_ANON_KEY`. Never put a service-role key in Flutter. Open
<http://127.0.0.1:8000/docs> to inspect the separate endpoint schemas.

Example **fictional** request (requires a real signed-in user's Bearer token):

```json
{
  "age": 28,
  "bmi": null,
  "regular_periods": 0,
  "weight_gain": 1,
  "excess_hair": 1,
  "skin_darkening": 0,
  "hair_thinning": 0,
  "acne": 1,
  "known_pcos_diagnosis": false
}
```

`regular_periods: 1` means regular, and `0` means not regular. This endpoint
does not use the old summary endpoint's `irregular_periods` field. Unknown
symptoms return `insufficient_inputs`; BMI may remain null. The optional routing
flag is a boolean and is not a predictor. Flutter maps an unspecified routing
flag to false while keeping symptom unknowns null.

An inference response has `status: experimental_result`, `model: random_forest`,
`method_version: trained-random-forest-v1`, and a numeric research output
`experimental_model_score`. Flutter validates the response contract and now
shows `experimental_model_score × 100`, rounded to one decimal, as an
**Experimental model score** out of 100. This is a display rescaling of the
existing research output, not a new risk formula, clinical risk percentage, or
personal probability. Higher output means a stronger model association with the
self-reported prior diagnosis label in the training data; it does not establish
higher clinical risk for an individual. No diagnostic labels or clinical risk
bands are assigned. The result also lists the actual reported changes, preserves
regular-period encoding, and explains whether BMI was supplied or imputed.
Detailed limitations are under “About this score”; the main card clearly states
that this is not a PCOS risk percentage or diagnosis. Errors, missing inputs,
out-of-scope and tracking statuses never show a generated score.

## USB-connected Android development

`127.0.0.1` on Android normally refers to the phone. Forward the USB port first:

```powershell
C:\Users\Admin\AppData\Local\Android\sdk\platform-tools\adb.exe -s ZD2229TJMM reverse tcp:8000 tcp:8000
```

From `Auracare_mobile_app/auracare_mobile_app`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/run_model_quiz.ps1 -ApiBaseUrl http://127.0.0.1:8000 -AllowLocalApi
```

The process-only script execution override is needed on this machine because
its PowerShell script policy is restricted. It does not change machine policy.
The helper reads only the two public Supabase client values from the root `.env`
and writes public Dart defines into ignored `build/local-model-defines.json`.
Use `-BuildOnly` to build the APK without launching it.

If this machine's Kotlin incremental cache fails across the C: SDK/pub cache and
D: workspace, add `-DisableKotlinIncremental` to the helper invocation. It passes
`kotlin.incremental=false` and `kotlin.compiler.execution.strategy=in-process`
as Gradle project arguments for that invocation only.

Sign in with an existing account, then open Home → PCOS quiz → Begin
questionnaire. Review the intro's upload explanation, enter fictional context
and answers for testing, review them, and press Submit questionnaire. Do not
choose demo mode when verifying live inference; demo mode intentionally remains
offline. A missing/expired token prompts reauthentication; a failed request keeps
answers editable and retryable. Changing accounts clears the questionnaire and
discards pending responses. Tokens are fetched/refreshed at submission time,
never hardcoded or logged. Redirects are not followed with the Bearer token.

The local URL is **not** the production default. Future deployment must pass
`AURACARE_API_BASE_URL=https://your-shared-backend` (an optional base path is
supported), with the same public Supabase client settings. Release builds reject
HTTP URLs even when the local flag is supplied. Android's debug-only network
configuration permits cleartext only for localhost/127.0.0.1/10.0.2.2; the main
manifest includes internet permission for HTTPS release requests. ADB forwarding
may need to be repeated after reconnecting the phone.

## Validation

Verified on 2026-10-25: Flutter analysis clean; full Flutter suite 129 tests
passed; all 11 existing model tests and 8 API integration tests passed; Python
dependency check clean; local-configured Android debug APK built successfully.
After the final result/back-navigation correction, all 18 focused Flutter
transport/authentication/model UI tests passed again. The trained artifact hash
remains unchanged.

The local FastAPI server was started at `127.0.0.1:8000`; `/docs` returned 200,
OpenAPI included the model route, and unauthenticated model requests returned
401. USB forwarding was enabled and a local-configured app installed; the phone
restored an existing signed-in session. The final integrated build was installed
on the Motorola Edge 30 and its authenticated phone-to-server round trip
completed successfully with explicitly fictional inputs (age 28, BMI omitted,
regular periods yes, other binary answers no). The app displayed “Experimental
model summary” and confirmed development-trained BMI imputation, without showing
a numerical probability or diagnostic label. The result was left open on the
phone. Screenshot: Flutter app `build/previews/pcos-model-phone.png` (ignored
build artifact). Backend unit tests use isolated mock authentication; this
separate device check used the phone's actual restored Supabase session without
extracting or logging its token. No source data or model artifacts were changed.

```powershell
# Repository root; full dataset suite also needs auracare_pcos/requirements.txt
.\.venv-pcos\Scripts\python.exe -m unittest service.test_pcos_api -v
.\.venv-pcos\Scripts\python.exe -m unittest discover -s auracare_pcos -p test_pipeline.py -v

# Flutter directory
flutter analyze
flutter test
```

Backend tests use actual artifact inference, with Supabase authentication mocked
for isolated synthetic requests. They cover authentication rejection, inputs,
missing BMI/answers, age limits, checksum/feature failures, startup with a missing
model, feature order, output parity with local inference, and legacy endpoint
compatibility. These are software checks, not clinical validation.

Flutter tests cover exact JSON contract mapping, token refresh/session
restoration, live result presentation, errors/retries without fixtures, pending
response isolation on account changes, reduced motion, keyboard scrolling, and
320/360/390/430dp flashcard layouts at 200% text scaling.

Windows Git had converted LF to CRLF in the supplied CSVs, including quoted
column headings. Source checks now compare canonical LF bytes with the original
hashes, and preprocessing normalizes heading newlines only. Source values and
artifacts remain unchanged. `PACKAGE_CHECKSUMS.json` remains the original
delivery manifest; inference/import and portability source edits in this
integration intentionally differ from that historical source manifest.
