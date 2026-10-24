# API specification

## Status and common contract

**All endpoints below are proposed; none is implemented.** Draft prefix `/api/v1`. JSON except protected file transfers. Session technology is undecided. Private requests require verified server identity, owner/role authorization, input validation and any required purpose/recipient grant. Derive owner from session; reject client owner IDs. Public reads expose only published data.

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
