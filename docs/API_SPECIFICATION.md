# API specification

## Implemented FastAPI API

`service/main.py` implements the following routes without an `/api/v1` prefix.
Interactive schemas are available at `/docs` and `/openapi.json`. Flutter is not
connected. The experimental PCOS ML model is not used.

Both POST routes require `Authorization: Bearer <Supabase access token>`. A shared
dependency verifies the token with Supabase Auth, derives the user ID from that
response, and creates a fresh user-authorized Supabase client per request. Clients
do not persist sessions or refresh tokens; their HTTP transport is closed after
the request. There is no client-supplied owner field.

| Route | Request | Success |
| --- | --- | --- |
| `POST /chat` | `prompt`: strict string, whitespace-trimmed, 1–10,000 characters; required `ai_processing_confirmed`: strict boolean, must be `true` | `200 {"response":"..."}` |
| `POST /predict-pcos` | Optional nullable strict booleans: `irregular_periods`, `acne`, `excess_hair_growth`, `scalp_hair_thinning`; at least one known answer | `201` survey summary, saved as a draft assessment |

Both bodies reject extra fields. Chat's confirmation applies only to sending the
exact prompt in that request to Gemini. Clients must explain that external AI
processing and obtain an affirmative user action before setting it; it is not a
complete consent system, legal consent record, standing grant, or permission to
include journals/records automatically. Omission or a non-boolean yields `422`;
`false` yields `403`. No Gemini request occurs without confirmation and valid auth.

Synthetic chat request (with a valid test-account Bearer token):

```json
{"prompt":"What general questions could I ask a clinician?","ai_processing_confirmed":true}
```

Chat sends only the supplied prompt, plus the unchanged medical-safety system
instruction, to `gemini-2.5-flash`, with at most 2,048 output tokens. It must identify
itself as AI, avoid diagnosis/prescribing/clinical-validation claims, acknowledge
uncertainty and encourage qualified medical care. These instructions do not prove
clinical safety or guarantee model compliance. No conversation storage exists.

Survey response fields: `assessment_id` (UUID), `prediction` (`survey_summary` for
four known answers, otherwise `insufficient_data`), `risk_score` (count of true
answers, 0–4), `answered_questions`, `total_questions` (4), `reported_symptoms`,
`method_version` (`survey-count-v1`), and `limitations`. Partial submissions are
saved; null stays unknown. The count is not a PCOS probability or clinical risk
classification. A draft in `pcos_assessments` stores the authenticated owner,
UTC assessment date and JSON-serialized survey/summary in its observations text.

### Implemented errors, limits and configuration

Errors use `{"detail":"safe message"}`, not the proposed envelope below. All
responses, including errors, use `Cache-Control: no-store`; validation errors omit
submitted values. Raw SDK/internal exception messages are not returned.

| Status | Meaning |
| --- | --- |
| `401` | Missing/wrong Bearer scheme, invalid/expired token or missing authenticated user; `WWW-Authenticate: Bearer` |
| `403` | AI processing confirmation is explicitly false |
| `422` | Invalid body/types/limits, missing confirmation or no known survey answers |
| `429` | Chat user budget exhausted; `Retry-After` seconds |
| `502` | Gemini non-retryable/upstream failure, malformed or empty text response |
| `503` | Auth/network/timeout failure, upstream auth rate limit/server failure, assessment save failure, missing Gemini configuration, Gemini network/timeout/rate-limit/server failure, or limiter capacity exhausted |
| `500` | Unexpected internal failure with a generic message |

Supabase Auth and PostgREST use an explicit 10-second HTTP timeout per network
phase (connect/read/write/pool), not a total request deadline. Gemini uses a
30,000-ms SDK request timeout and one attempt (automatic retries disabled).

Chat has a thread-safe fixed-window budget of 10 attempted AI calls per verified
user ID per 60 seconds, beginning with that user's first admitted attempt. Failed
AI calls consume budget; invalid/unconfirmed requests and missing AI configuration
do not. Token rotation does not reset the user budget. At most 1,024 active user
windows are retained; expired windows are pruned on access. At capacity, new users
receive `503` and `Retry-After` without evicting current budgets. State contains
only user IDs, window expiry times and counts; no prompts or tokens.

This is a **single-process local-development limiter**. Restarts reset it and
workers/replicas have separate budgets. Production needs a shared atomic limiter,
global/provider cost budgets and ingress protections; authentication itself is not
rate-limited by this chat limiter.

Backend startup requires `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
`GEMINI_API_KEY` is server-only and required when using chat. See `.env.example`;
never substitute a service-role key. Tests mock all external services:

```powershell
python -m pip install -r service/requirements-test.txt
python -B -m pytest service/tests -v -p no:cacheprovider
```

No database migration or deployed RLS verification is implied by these tests.

## Proposed broader API: status and common contract

**All endpoints below are proposed; none of these broader routes is implemented.** Draft prefix `/api/v1`. JSON except protected file transfers. Broader session and consent workflows remain undecided. Private requests require verified server identity, owner/role authorization, input validation and any required purpose/recipient grant. Derive owner from session; reject client owner IDs. Public reads expose only published data.

Lists use bounded date ranges/limits and opaque cursors: `{items,nextCursor}`. Private entries return `{id,version,createdAt,updatedAt,...validatedFields}`. Updates require expectedVersion; side effects require idempotency keys. Health responses use private/no-store. Define CSRF/origin handling for cookie sessions. Rate limits are required per account/IP/operation, stricter for AI/uploads/bookings/posts/reports; numerical budgets remain undecided. 429 includes Retry-After.

## Draft endpoints

Paths omit prefix. GET lists, POST creates, PATCH edits, DELETE follows lifecycle policy. Every row has status **proposed**.

| Module / methods and paths | Request → response | Authorization / validation |
| --- | --- | --- |
| Identity: GET/PATCH /me; GET/POST /consents; POST /consents/{id}/withdraw | Minimal preferences or purpose/scope/recipient grant → profile/grant state | Session owner; cannot grant another owner's records |
| Mind & Wellness: GET/POST /wellness-entries; GET/PATCH/DELETE /wellness-entries/{id}; same for /journal-entries | Date/optional check-in fields or journal body → versioned entry/list | Owner, bounded fields; journals private by default |
| Period Tracker: GET/POST /periods; GET/PATCH/DELETE /periods/{id}; same for /symptoms; GET /cycle-estimates | Dates/optional logs/range → records or estimate/method/coverage | Owner; validate date order/open intervals; insufficient-data state explicit |
| PCOS Insights: POST /pcos-summaries/preview; GET/PATCH/DELETE /pcos-summaries/{id}; POST /pcos-summaries/{id}/review | Selected source versions/range/user edits → draft/reviewed/outdated description | Owner plus selected cross-module scope; no diagnostic probability |
| AI Assistant: POST /ai-conversations; POST /ai-conversations/{id}/messages; GET/DELETE /ai-conversations/{id} | Question, selected context/grant → message/sources/limitations or processing state | Owner and scoped processing consent; no automatic journal context |
| Reports: POST /health-documents; GET/DELETE /health-documents/{id}; GET /health-documents/{id}/findings; PATCH /health-documents/{id}/findings/{findingId}; POST /health-documents/{id}/review | Declared type/size → protected upload instruction; correction/review → finding state | Owner, type/size/quarantine validation and processing scope; draft until user review |
| Women's Health Library: GET /library/topics; GET /library/articles; GET /library/articles/{slug}; POST /editorial/articles; PATCH /editorial/articles/{id} | Query/topic or editorial revision → article/source/review metadata | Published reads public; editorial role for writes; truthful review status |
| Appointments & Clinic: GET /clinics; GET /clinics/{id}; GET/POST /appointments; GET/PATCH /appointments/{id} | Filters or sourced provider/slot request → directory metadata or booking state/mode | Public directory; owner booking; confirmation from actual provider only |
| Sharing: POST /summary-shares/preview; POST /summary-shares; GET /summary-shares/{id} | Reviewed version/recipient/grant → preview/dispatch/receipt status | Owner, separate recipient-specific approval, recheck before dispatch |
| Provider: POST /integrations/providers/{provider}/events | Signed event/external ID → reconciliation acknowledgement | Provider authentication/signature, replay/idempotency checks |
| Sisterhood: GET /community/topics; GET/POST /community/posts; GET/PATCH/DELETE /community/posts/{id}; GET/POST /community/posts/{id}/comments; PATCH/DELETE /community/comments/{id} | Community topic/query/text → community feed/thread | Public reads per policy; own community identity writes; reject private-record fields/attachments |
| Community actions: POST/DELETE /community/posts/{id}/reaction; GET/POST /community/bookmarks; DELETE /community/bookmarks/{id}; POST/DELETE /community/blocks/{communityUserId}; POST /community/reports | Target/action/reason → own state or protected receipt | Actor scope, block enforcement, abuse limits; reporter hidden from target |
| Moderation: GET /moderation/reports; POST /moderation/actions; POST /community/appeals | Community evidence/action/appeal → restricted decision state | Moderator role for queue/actions, own appeals; no private-health access |
| Shared: GET/POST /reminders; PATCH/DELETE /reminders/{id}; POST /exports; GET /exports/{id}; POST /privacy-requests; GET /privacy-requests/{id} | Opt-in schedule/selected versions/deletion request → status/expiry | Owner; scoped export, neutral reminders and protected downloads |

## Synthetic structures

POST /periods:

```json
{"startDate":"2026-09-01","endDate":"2026-09-05","timezone":"Asia/Kolkata"}
```

201 response:

```json
{"id":"synthetic-period-1","startDate":"2026-09-01","endDate":"2026-09-05","version":1}
```

PCOS preview request: `{sources:[{type,id,version}],range:{from,to},consentId}`. Response: `{id,state,sourceVersions,coverage,descriptiveObservations,limitations,userEdits,methodVersion}`. No PCOS probability field. Missing days unknown.

AI message request: `{question,selectedContextVersions,consentId}`. Response: `{message,sources,limitations,selectedContextVersions}` or safe processing/unavailable state. Retrieved citations must exist and support the answer.

Share request: `{summaryId,summaryVersion,recipientId,consentId,idempotencyKey}`. 202 response: `{id,status,recipientId,approvedVersion}`. Approval/dispatch/receipt is distinct from booking confirmation. File/job response: `{id,state,requestId}` with owner-protected polling. User review of extraction confirms transcription, not diagnosis.

## Errors and open schema work

Error: `{error:{code,message,fieldErrors?,requestId}}`, with no health text, SQL, storage keys or another user's existence. Codes: 400 malformed, 401 session required, 403 role/purpose denied, 404 missing/inaccessible private object, 409 edit conflict/outdated approval, 413 oversized, 415 unsupported media, 422 semantic validation, 429 rate limit, 502/503 integration failure, 500 generic failure. Sparse history returns insufficient-data, not reassurance.

Reject invalid dates/enums/lengths/ranges, unowned selections, stale versions, revoked grants, unreviewed findings treated as confirmed and any private-record import in community writes. Recheck queued job permissions at execution. Final OpenAPI schemas, enums/limits, auth callbacks, numeric rate budgets, export expiry and idempotency retention await platform selection; these draft shapes are not executable contracts.
