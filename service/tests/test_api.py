"""Contracts for current behavior; external services are always mocked."""
import json
import socket
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from threading import Barrier
from types import SimpleNamespace
from unittest.mock import Mock

import httpx
import pytest
from fastapi.testclient import TestClient
from postgrest.exceptions import APIError
from supabase_auth.errors import AuthApiError, AuthRetryableError


AUTH = {"Authorization": "Bearer synthetic-token-a"}
FIELDS = ("irregular_periods", "acne", "excess_hair_growth", "scalp_hair_thinning")
FULL = dict(zip(FIELDS, (True, False, True, False)))


def test_network_guard_blocks_direct_sockets_and_httpx():
    with socket.socket() as sock:
        with pytest.raises(AssertionError, match="network access is forbidden"):
            sock.connect(("127.0.0.1", 8000))
    with pytest.raises(AssertionError, match="network access is forbidden"):
        socket.getaddrinfo("synthetic-project.invalid", 443)
    with httpx.Client(trust_env=False) as external:
        with pytest.raises(AssertionError, match="network access is forbidden"):
            external.get("https://synthetic-project.invalid")


@pytest.mark.parametrize("missing", ["SUPABASE_URL", "SUPABASE_ANON_KEY"])
@pytest.mark.parametrize("value", [None, "", "   "])
def test_startup_requires_config(backend, missing, value):
    if value is None:
        backend.config.pop(missing)
    else:
        backend.config[missing] = value
    with pytest.raises(RuntimeError, match="must be configured"):
        with TestClient(backend.api.app):
            pass
    backend.api.create_client.assert_not_called()


def test_startup_trims_config_without_initializing_services(backend):
    backend.config["SUPABASE_URL"] = "  https://synthetic-project.invalid  "
    with TestClient(backend.api.app):
        assert backend.api.app.state.supabase_url == "https://synthetic-project.invalid"
    backend.api.create_client.assert_not_called()
    backend.api.OpenAI.assert_not_called()


@pytest.mark.parametrize("body", [None, [], {}, {"prompt": ""}, {"prompt": "   "},
    {"prompt": 123}, {"prompt": True}, {"prompt": None}, {"prompt": "x" * 10001},
    {"prompt": "synthetic-private-marker", "extra": "synthetic-private-marker"}])
def test_chat_validation(client, backend, supabase, body):
    if isinstance(body, dict):
        body = {**body, "ai_processing_confirmed": True}
    response = client.post("/chat", json=body, headers=AUTH)
    assert response.status_code == 422
    assert response.json() == {"detail": "Invalid request. Check the documented field types and limits."}
    assert "synthetic-private-marker" not in response.text
    assert response.headers["cache-control"] == "no-store"
    backend.api.OpenAI.assert_not_called()


@pytest.mark.parametrize("prompt", ["  synthetic question  ", "x" * 10000])
def test_chat_authenticated_success(client, backend, supabase, openai_client, prompt):
    response = client.post("/chat", json={"prompt": prompt, "ai_processing_confirmed": True}, headers=AUTH)
    assert response.status_code == 200
    assert response.json() == {"response": "Synthetic wellness information."}
    assert response.headers["cache-control"] == "no-store"
    options = backend.api.OpenAI.call_args.kwargs
    assert options["api_key"] == "FAKE_OPENAI_KEY"
    assert options["timeout"] == 30
    assert options["max_retries"] == 0
    supabase.auth.get_user.assert_called_once_with("synthetic-token-a")
    supabase.table.assert_not_called()
    kwargs = openai_client.chat.completions.create.call_args.kwargs
    assert kwargs["messages"][1] == {"role": "user", "content": prompt.strip()}
    assert kwargs["model"] == "gpt-4o-mini"
    assert kwargs["messages"][0] == {"role": "system", "content": backend.api.CHAT_SYSTEM_INSTRUCTION}
    assert kwargs["max_completion_tokens"] == 2048
    openai_client.__exit__.assert_called_once()


@pytest.mark.parametrize("text", [None, "", "  \n"])
def test_chat_empty_upstream_response(client, supabase, openai_client, text):
    openai_client.chat.completions.create.return_value.choices[0].message.content = text
    response = client.post("/chat", json={"prompt": "synthetic question", "ai_processing_confirmed": True}, headers=AUTH)
    assert response.status_code == 502
    assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("stage", ["construct", "generate"])
def test_chat_sanitizes_raw_exception(client, backend, supabase, openai_client, stage):
    error = RuntimeError("SYNTHETIC_PRIVATE_UPSTREAM_DETAIL")
    if stage == "construct":
        backend.api.OpenAI.side_effect = error
    else:
        openai_client.chat.completions.create.side_effect = error
    response = client.post("/chat", json={"prompt": "synthetic question", "ai_processing_confirmed": True}, headers=AUTH)
    assert response.status_code == 502
    assert "SYNTHETIC_PRIVATE_UPSTREAM_DETAIL" not in response.text
    assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("header", [None, "Basic synthetic", "Bearer", ""])
def test_survey_missing_or_wrong_auth_scheme(client, backend, header):
    headers = {} if header is None else {"Authorization": header}
    response = client.post("/predict-pcos", json=FULL, headers=headers)
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.headers["cache-control"] == "no-store"
    backend.api.create_client.assert_not_called()


@pytest.mark.parametrize("body", [None, [], {"unknown": True}, {"user_id": "synthetic-other-user"},
    {"acne": 1}, {"acne": 0}, {"acne": "true"}, {"acne": "false"}, {"acne": []}])
def test_survey_invalid_body(client, backend, supabase, body):
    response = client.post("/predict-pcos", json=body, headers=AUTH)
    assert response.status_code == 422
    assert response.headers["cache-control"] == "no-store"
    assert "synthetic-other-user" not in response.text
    supabase.table.assert_not_called()


def test_malformed_json_is_sanitized(client, backend):
    response = client.post("/predict-pcos", content='{"synthetic-private-marker":',
        headers={**AUTH, "Content-Type": "application/json"})
    assert response.status_code == 422
    assert "synthetic-private-marker" not in response.text
    backend.api.create_client.assert_not_called()


@pytest.mark.parametrize("body", [{}, dict.fromkeys(FIELDS)])
def test_survey_all_unknown_does_not_insert(client, supabase, body):
    response = client.post("/predict-pcos", json=body, headers=AUTH)
    assert response.status_code == 422
    assert response.json() == {"detail": "Answer at least one survey question."}
    supabase.table.assert_not_called()


@pytest.mark.parametrize("body", [FULL, dict.fromkeys(FIELDS, False), dict.fromkeys(FIELDS, True),
    {"acne": True}, {"acne": False}, {"acne": None, "irregular_periods": True}])
def test_survey_success_and_persisted_contract(client, backend, supabase, body):
    before = datetime.now(timezone.utc).date().isoformat()
    response = client.post("/predict-pcos", json=body, headers=AUTH)
    after = datetime.now(timezone.utc).date().isoformat()
    assert response.status_code == 201
    answers = {field: body.get(field) for field in FIELDS}
    symptoms = [field for field, value in answers.items() if value is True]
    answered = sum(value is not None for value in answers.values())
    result = response.json()
    assert result == {
        "assessment_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "prediction": "survey_summary" if answered == 4 else "insufficient_data",
        "risk_score": len(symptoms), "answered_questions": answered,
        "total_questions": 4, "reported_symptoms": symptoms,
        "method_version": "survey-count-v1", "limitations": backend.api.LIMITATIONS,
    }
    assert response.headers["cache-control"] == "no-store"
    supabase.auth.get_user.assert_called_once_with("synthetic-token-a")
    supabase.postgrest.auth.assert_called_once_with("synthetic-token-a")
    supabase.table.assert_called_once_with("pcos_assessments")
    row = supabase.table.return_value.insert.call_args.args[0]
    assert row["user_id"] == "11111111-1111-4111-8111-111111111111"
    assert row["assessment_date"] in (before, after)
    assert row["status"] == "draft"
    assert row["method_version"] == "survey-count-v1"
    assert row["limitations"] == backend.api.LIMITATIONS
    assert json.loads(row["observations"]) == {
        "survey": answers, "summary": {k: v for k, v in result.items() if k != "assessment_id"}}
    options = backend.api.create_client.call_args.kwargs["options"]
    assert options.persist_session is False
    assert options.auto_refresh_token is False
    assert options.httpx_client.timeout.connect == 10
    assert options.httpx_client.timeout.read == 10
    assert options.httpx_client.is_closed
    assert options.postgrest_client_timeout == 10


@pytest.mark.parametrize("mode", ["invalid", "no_result", "no_user", "http", "retryable"])
def test_auth_failures_are_safe_and_do_not_insert(client, supabase, mode):
    if mode == "invalid":
        supabase.auth.get_user.side_effect = AuthApiError("SYNTHETIC_PRIVATE", 401, None)
    elif mode == "http":
        supabase.auth.get_user.side_effect = httpx.ConnectError("SYNTHETIC_PRIVATE")
    elif mode == "retryable":
        supabase.auth.get_user.side_effect = AuthRetryableError("SYNTHETIC_PRIVATE", 503)
    else:
        supabase.auth.get_user.return_value = None if mode == "no_result" else SimpleNamespace(user=None)
    response = client.post("/predict-pcos", json=FULL, headers=AUTH)
    assert response.status_code == (503 if mode in ("http", "retryable") else 401)
    assert "SYNTHETIC_PRIVATE" not in response.text
    assert response.headers["cache-control"] == "no-store"
    supabase.postgrest.auth.assert_not_called()
    supabase.table.assert_not_called()


@pytest.mark.parametrize("mode", ["api", "http", "empty", "none"])
def test_database_failures_are_sanitized(client, supabase, mode):
    execute = supabase.table.return_value.insert.return_value.execute
    if mode == "api":
        execute.side_effect = APIError({"message": "SYNTHETIC_PRIVATE_SQL", "code": "42501", "details": "private", "hint": "private"})
    elif mode == "http":
        execute.side_effect = httpx.ConnectError("SYNTHETIC_PRIVATE_SQL")
    else:
        execute.return_value = SimpleNamespace(data=[] if mode == "empty" else None)
    response = client.post("/predict-pcos", json=FULL, headers=AUTH)
    assert response.status_code == 503
    assert "SYNTHETIC_PRIVATE_SQL" not in response.text
    assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("concurrent", [False, True])
def test_user_authentication_context_is_isolated(client, backend, concurrent):
    barrier = Barrier(2) if concurrent else None
    clients = []

    def factory(*args, **kwargs):
        fake = Mock()
        state = {}

        def authenticate(token):
            state["token"] = token
            return SimpleNamespace(user=SimpleNamespace(id={"token-a": "user-a", "token-b": "user-b"}[token]))

        def authorize(token):
            state["rest_token"] = token
            if barrier:
                barrier.wait(timeout=10)

        def execute():
            row = fake.table.return_value.insert.call_args.args[0]
            assert state["token"] == state["rest_token"]
            assert row["user_id"] == {"token-a": "user-a", "token-b": "user-b"}[state["token"]]
            return SimpleNamespace(data=[{"id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}])

        fake.auth.get_user.side_effect = authenticate
        fake.postgrest.auth.side_effect = authorize
        fake.table.return_value.insert.return_value.execute.side_effect = execute
        clients.append(fake)
        return fake

    backend.api.create_client.side_effect = factory

    def submit(token):
        return client.post("/predict-pcos", json={"acne": True}, headers={"Authorization": f"Bearer {token}"})

    if concurrent:
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(submit, ["token-a", "token-b"]))
    else:
        responses = [submit(token) for token in ("token-a", "token-b")]
    assert [response.status_code for response in responses] == [201, 201]
    assert len(clients) == 2 and clients[0] is not clients[1]
    assert {fake.table.return_value.insert.call_args.args[0]["user_id"] for fake in clients} == {"user-a", "user-b"}
    # A later unauthenticated request must not inherit either successful session.
    assert client.post("/predict-pcos", json=FULL).status_code == 401
    assert backend.api.create_client.call_count == 2


def test_chat_missing_choices(client, supabase, openai_client):
    openai_client.chat.completions.create.return_value.choices = []
    response = client.post("/chat", json={"prompt": "synthetic question", "ai_processing_confirmed": True}, headers=AUTH)
    assert response.status_code == 502
    assert response.headers["cache-control"] == "no-store"
