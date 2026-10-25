# Authenticated PCOS questionnaire

Account sessions select `AuthenticatedQuizService` through the existing
`DemoSession` scope; demo sessions keep their existing local `DemoQuizService`
and simulated failure/unavailable scenarios. No parallel API client was added.
The account service creates the existing `AuraApiClient` lazily, with the
`AuraAuthController` token provider. Its transport closes when the session ends.
No request occurs on login, questionnaire entry, or loading the fictional example.

## Explicit mapping

| Flutter answer | FastAPI field | Encoding |
| --- | --- | --- |
| `regular_periods` | `irregular_periods` | 1 → false, 0 → true, null → null |
| `acne` | `acne` | 1 → true, 0 → false, null → null |
| `excess_hair` | `excess_hair_growth` | 1 → true, 0 → false, null → null |
| `hair_thinning` | `scalp_hair_thinning` | Same encoding, only after explicit scalp clarification; otherwise null |

`PcosQuestionnaireAdapter` produces typed `PcosSurveyAnswers`. Values outside
0/1/null are rejected, not coerced. All four keys are present with strict JSON
booleans or null. At least one known supported answer is required by the API client.

Inspection of `auracare_pcos/quiz_contract.json` found legacy hair wording
"hair loss/hair thinning/baldness", without an explicit scalp location. It is
not automatically equivalent to scalp thinning. The live review therefore asks
the user to confirm that their hair answer refers to scalp hair. This checkbox
defaults to false and is separate from permission to submit. The original answer
is retained regardless of clarification. No ML contract/model file was changed.

Age, BMI (and its weight/height inputs), weight gain, skin darkening and known
PCOS diagnosis are retained locally and excluded from the request. Review states
that the backend does not consider these fields. Known diagnosis keeps the
existing local tracking route; it is not sent as a diagnostic input. Legacy demo
age/minimum-input gates remain demo rules, not backend scoring rules.

## Confirmation, response and failures

The live review discloses the four transmitted fields and the draft save to
the account. The user must check confirmation and press Submit. Every attempt
consumes that confirmation, including failures. Editing answers requires review
and confirmation again. The service independently requires confirmation, denies
demo/signed-out/recovery/account-mismatched sessions and rejects overlapping calls.
Current user access tokens come from the existing auth provider; near-expiry
refresh and missing-token blocking remain in that provider/API client.

`POST /predict-pcos` returns HTTP 201. The existing parser reads assessment ID,
prediction, risk score, answered/total questions, reported symptoms, method and
limitations. The PCOS result area calls `risk_score` **Reported symptoms**, a
count. It shows known-answer coverage, partial-summary status, reported fields,
method, draft ID and the returned limitations. There is no percentage, diagnosis,
probability or clinical risk band. No trained model is called.

401, 403, 422, 503, timeouts, network failures and malformed responses use fixed
local API messages. Questionnaire state remains intact for review/edit/retry.
There are no automatic POST retries. Timeout is ambiguous: the draft may already
have been saved. The UI warns about this before another explicit submission.
There is no server idempotency key in the current contract, so a deliberate retry
after an ambiguous outcome can create another draft.

## Configuration and verification limits

Use the existing `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`AURACARE_API_BASE_URL` compile-time configuration; see
[authentication](FLUTTER_AUTHENTICATION.md) and [networking](FLUTTER_NETWORKING.md).
Only disposable accounts and fictional answers should be used for live checks.
No real health data was transmitted during implementation/testing. Automated
tests mock HTTP and authentication; live save behavior, device networking and
two-user RLS enforcement remain unverified.

No production backend, migration, policy or experimental model was modified.

Validation on 2026-10-25:

- `flutter analyze`: no issues found (9.8 seconds).
- `flutter test test/pcos_integration_test.dart test/api_client_test.dart test/auth_test.dart --reporter expanded`:
  105 passed, zero failures (6 seconds), including 25 PCOS integration tests.
- `flutter test --concurrency=1 --reporter expanded`: 195 passed, zero failures
  (2 minutes 26 seconds), including existing questionnaire navigation and UI regressions.

The PCOS tests exercise every mapping and null conversion, period inversion,
scalp scope, unsupported-state preservation, confirmation, authenticated requests,
response parsing, missing/invalid/expired tokens, demo/recovery isolation, HTTP
401/403/422/503, timeout/network/malformed responses, duplicate requests, late
results after logout, answer retention and non-diagnostic result wording.
