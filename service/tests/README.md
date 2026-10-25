# Offline backend tests

From the repository root:

```powershell
python -m pip install -r service/requirements-test.txt
python -B -m pytest service/tests -v -p no:cacheprovider
```

Run this directory explicitly; the separate ML suite has other dependencies.
Tests disable dotenv loading before importing the application, replace the
application's environment reader with fake configuration without changing the
process environment, and mock both SDK factories. Socket/DNS and HTTPX network
transports are blocked. The only socket-connect exception is the thread-local
loopback connection inside Windows' socketpair implementation, used by asyncio's
internal wakeup pipe. TestClient uses its in-process ASGI transport.

No database is contacted and these tests do not verify deployed RLS, migration
application, clinical safety, or Gemini output quality. The concurrency tests
verify per-request client/token isolation against synthetic Supabase clients.

## Security coverage and remaining limits

Both POST endpoints require verified Supabase auth. Tests exercise strict
per-request chat confirmation, safe SDK/internal errors, explicit timeout options,
missing configuration, per-user budgets (including token rotation), failed-call
accounting, window expiry, bounded capacity and thread safety. Existing survey
response and sequential/concurrent user-isolation checks are retained.

Tests assert that raw synthetic private exception markers never reach clients.
They also check no-store errors and the OpenAPI auth/confirmation contract.
Timeouts are configured and timeout failures are mocked; tests do not measure live
upstream latency. Clock-controlled limiter checks do not sleep.

The limiter is local in-memory state, unsuitable for multi-worker production.
Confirmation is not durable consent management. Mocked ownership checks are not
proof of database RLS. Before real-user access, run separately approved two-user
RLS tests in an isolated database and resolve the duplicate migration version/order
issue. Model instruction tests do not establish clinical safety.
