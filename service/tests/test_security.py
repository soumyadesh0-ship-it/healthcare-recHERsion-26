"""Authentication, confirmation, failure privacy and bounded local abuse controls."""
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest.mock import Mock

import httpx
import pytest
from fastapi import HTTPException
from openai import APIConnectionError, APIStatusError, APITimeoutError
from supabase_auth.errors import AuthApiError

AUTH = {"Authorization": "Bearer synthetic-token-a"}
CHAT = {"prompt": "synthetic health question", "ai_processing_confirmed": True}


@pytest.mark.parametrize("header", [None, "Basic fake", "Bearer", ""])
def test_chat_requires_bearer(client, backend, header):
    response = client.post("/chat", json=CHAT, headers={} if header is None else {"Authorization": header})
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.headers["cache-control"] == "no-store"
    backend.api.create_client.assert_not_called()
    backend.api.OpenAI.assert_not_called()


@pytest.mark.parametrize("confirmation", [None, "true", 1, 0, [], {}])
def test_confirmation_must_be_strict_boolean(client, backend, supabase, confirmation):
    response = client.post("/chat", json={**CHAT, "ai_processing_confirmed": confirmation}, headers=AUTH)
    assert response.status_code == 422
    backend.api.OpenAI.assert_not_called()


def test_confirmation_required_and_false_denied_without_quota_use(client, backend, supabase):
    missing = client.post("/chat", json={"prompt": "synthetic"}, headers=AUTH)
    refused = client.post("/chat", json={**CHAT, "ai_processing_confirmed": False}, headers=AUTH)
    assert missing.status_code == 422
    assert refused.status_code == 403
    assert refused.headers["cache-control"] == "no-store"
    backend.api.OpenAI.assert_not_called()
    assert backend.api.app.state.chat_limiter._users == {}


@pytest.mark.parametrize("path,body", [("/chat", CHAT), ("/predict-pcos", {"acne": True})])
@pytest.mark.parametrize("stage", ["construct", "verify", "authorize", "missing_identity"])
def test_unexpected_auth_errors_do_not_leak(client, backend, supabase, path, body, stage):
    private = RuntimeError("SYNTHETIC_PRIVATE_AUTH_DETAIL")
    if stage == "construct":
        backend.api.create_client.side_effect = private
    elif stage == "verify":
        supabase.auth.get_user.side_effect = private
    elif stage == "authorize":
        supabase.postgrest.auth.side_effect = private
    else:
        supabase.auth.get_user.return_value = SimpleNamespace(user=SimpleNamespace(id=None))
    response = client.post(path, json=body, headers=AUTH)
    assert response.status_code == 503
    assert "SYNTHETIC_PRIVATE" not in response.text
    assert response.headers["cache-control"] == "no-store"
    supabase.table.assert_not_called()
    backend.api.OpenAI.assert_not_called()


@pytest.mark.parametrize("status,expected", [(401, 401), (403, 401), (429, 503), (500, 503), (503, 503)])
def test_chat_auth_error_statuses(client, backend, supabase, status, expected):
    supabase.auth.get_user.side_effect = AuthApiError("SYNTHETIC_PRIVATE", status, None)
    response = client.post("/chat", json=CHAT, headers=AUTH)
    assert response.status_code == expected
    assert "SYNTHETIC_PRIVATE" not in response.text
    backend.api.OpenAI.assert_not_called()


@pytest.mark.parametrize("mode", ["none", "no_user", "timeout"])
def test_chat_auth_missing_user_or_timeout(client, backend, supabase, mode):
    if mode == "timeout":
        supabase.auth.get_user.side_effect = httpx.ReadTimeout("SYNTHETIC_PRIVATE")
    else:
        supabase.auth.get_user.return_value = None if mode == "none" else SimpleNamespace(user=None)
    response = client.post("/chat", json=CHAT, headers=AUTH)
    assert response.status_code == (503 if mode == "timeout" else 401)
    assert "SYNTHETIC_PRIVATE" not in response.text
    backend.api.OpenAI.assert_not_called()


@pytest.mark.parametrize("error,expected", [
    (APITimeoutError(request=httpx.Request("POST", "https://synthetic.invalid")), 503),
    (APIConnectionError(message="SYNTHETIC_PRIVATE", request=httpx.Request("POST", "https://synthetic.invalid")), 503),
    (httpx.ReadTimeout("SYNTHETIC_PRIVATE"), 503),
    (httpx.ConnectError("SYNTHETIC_PRIVATE"), 503),
    (APIStatusError("SYNTHETIC_PRIVATE", response=httpx.Response(429, request=httpx.Request("POST", "https://synthetic.invalid")), body=None), 503),
    (APIStatusError("SYNTHETIC_PRIVATE", response=httpx.Response(503, request=httpx.Request("POST", "https://synthetic.invalid")), body=None), 503),
    (APIStatusError("SYNTHETIC_PRIVATE", response=httpx.Response(400, request=httpx.Request("POST", "https://synthetic.invalid")), body=None), 502),
    (RuntimeError("SYNTHETIC_PRIVATE"), 502),
])
def test_openai_safe_errors(client, supabase, openai_client, error, expected):
    openai_client.chat.completions.create.side_effect = error
    response = client.post("/chat", json=CHAT, headers=AUTH)
    assert response.status_code == expected
    assert "SYNTHETIC_PRIVATE" not in response.text
    assert response.headers["cache-control"] == "no-store"


def test_missing_openai_configuration(client, backend, supabase):
    backend.config.pop("OPENAI_API_KEY")
    response = client.post("/chat", json=CHAT, headers=AUTH)
    assert response.status_code == 503
    backend.api.OpenAI.assert_not_called()


def test_unexpected_internal_error_is_generic(client, backend, supabase, monkeypatch):
    monkeypatch.setattr(backend.api.app.state.chat_limiter, "check", Mock(side_effect=RuntimeError("SYNTHETIC_PRIVATE")))
    response = client.post("/chat", json=CHAT, headers=AUTH)
    assert response.status_code == 500
    assert response.json() == {"detail": "Internal server error."}
    assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("stage", ["table", "execute", "malformed"])
def test_unexpected_database_failure_is_safe(client, supabase, stage):
    if stage == "table":
        supabase.table.side_effect = RuntimeError("SYNTHETIC_PRIVATE")
    elif stage == "execute":
        supabase.table.return_value.insert.return_value.execute.side_effect = httpx.ReadTimeout("SYNTHETIC_PRIVATE")
    else:
        supabase.table.return_value.insert.return_value.execute.return_value = SimpleNamespace(data=[{"id": "SYNTHETIC_PRIVATE"}])
    response = client.post("/predict-pcos", json={"acne": True}, headers=AUTH)
    assert response.status_code == 503
    assert "SYNTHETIC_PRIVATE" not in response.text


def test_rate_limit_is_per_verified_user_and_recovers(client, backend, supabase, openai_client):
    now = [100.0]
    backend.api.app.state.chat_limiter = backend.api.ChatRateLimiter(limit=2, clock=lambda: now[0])
    def identity(token):
        return SimpleNamespace(user=SimpleNamespace(id=token))
    supabase.auth.get_user.side_effect = identity
    assert client.post("/chat", json=CHAT, headers=AUTH).status_code == 200
    assert client.post("/chat", json=CHAT, headers=AUTH).status_code == 200
    limited = client.post("/chat", json=CHAT, headers=AUTH)
    assert limited.status_code == 429
    assert limited.headers["retry-after"] == "60"
    assert limited.headers["cache-control"] == "no-store"
    assert openai_client.chat.completions.create.call_count == 2
    other = {"Authorization": "Bearer synthetic-token-b"}
    assert client.post("/chat", json=CHAT, headers=other).status_code == 200
    now[0] += 60
    assert client.post("/chat", json=CHAT, headers=AUTH).status_code == 200


def test_rotated_tokens_share_user_budget(client, backend, supabase, openai_client):
    backend.api.app.state.chat_limiter = backend.api.ChatRateLimiter(limit=1)
    assert client.post("/chat", json=CHAT, headers=AUTH).status_code == 200
    assert client.post("/chat", json=CHAT, headers={"Authorization": "Bearer rotated-token"}).status_code == 429
    assert openai_client.chat.completions.create.call_count == 1


def test_failed_ai_attempts_count_against_budget(client, backend, supabase, openai_client):
    backend.api.app.state.chat_limiter = backend.api.ChatRateLimiter(limit=1)
    openai_client.chat.completions.create.side_effect = httpx.ReadTimeout("synthetic")
    assert client.post("/chat", json=CHAT, headers=AUTH).status_code == 503
    assert client.post("/chat", json=CHAT, headers=AUTH).status_code == 429
    assert openai_client.chat.completions.create.call_count == 1


def test_limiter_capacity_is_bounded_and_expired_users_are_removed(backend):
    now = [0.0]
    limiter = backend.api.ChatRateLimiter(max_users=2, clock=lambda: now[0])
    limiter.check("a")
    limiter.check("b")
    with pytest.raises(HTTPException) as failure:
        limiter.check("c")
    assert failure.value.status_code == 503
    assert failure.value.headers["Retry-After"] == "60"
    assert len(limiter._users) == 2
    # Existing user budgets survive capacity pressure; they are never evicted.
    limiter.check("a")
    now[0] = 60
    limiter.check("c")
    assert set(limiter._users) == {"c"}


def test_limiter_is_thread_safe(backend):
    limiter = backend.api.ChatRateLimiter(limit=10)
    def attempt(_):
        try:
            limiter.check("same-user")
            return 200
        except HTTPException as failure:
            return failure.status_code
    with ThreadPoolExecutor(max_workers=8) as pool:
        statuses = list(pool.map(attempt, range(40)))
    assert statuses.count(200) == 10
    assert statuses.count(429) == 30


def test_default_chat_budget(client, backend, supabase, openai_client):
    assert backend.api.app.state.chat_limiter.limit == 10
    assert backend.api.app.state.chat_limiter.window_seconds == 60
    assert backend.api.app.state.chat_limiter.max_users == 1024
    for _ in range(10):
        assert client.post("/chat", json=CHAT, headers=AUTH).status_code == 200
    assert client.post("/chat", json=CHAT, headers=AUTH).status_code == 429
    assert openai_client.chat.completions.create.call_count == 10


def test_openapi_advertises_chat_auth_and_confirmation(client):
    schema = client.get("/openapi.json").json()
    assert schema["paths"]["/chat"]["post"]["security"] == [{"HTTPBearer": []}]
    assert "ai_processing_confirmed" in schema["components"]["schemas"]["ChatRequest"]["required"]
