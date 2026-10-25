"""Offline backend fixtures: no dotenv loading, real credentials or network."""
import importlib
import socket
import threading
from types import SimpleNamespace
from unittest.mock import Mock

import dotenv
import httpx
import pytest
from fastapi.testclient import TestClient


@pytest.fixture(autouse=True)
def offline(monkeypatch):
    def deny(*args, **kwargs):
        raise AssertionError("External network access is forbidden in backend tests")

    # Windows implements socketpair with loopback TCP for asyncio's wakeup pipe.
    # Permit only that implementation's connect on the current thread.
    original_pair = socket.socketpair
    original_connect = socket.socket.connect
    local = threading.local()

    def socketpair(*args, **kwargs):
        local.in_socketpair = True
        try:
            return original_pair(*args, **kwargs)
        finally:
            local.in_socketpair = False

    def connect(sock, address):
        if getattr(local, "in_socketpair", False) and address[0] in ("127.0.0.1", "::1"):
            return original_connect(sock, address)
        return deny()

    monkeypatch.setattr(socket, "socketpair", socketpair)
    monkeypatch.setattr(socket.socket, "connect", connect)
    monkeypatch.setattr(socket.socket, "connect_ex", deny)
    monkeypatch.setattr(socket, "getaddrinfo", deny)
    monkeypatch.setattr(httpx.HTTPTransport, "handle_request", deny)
    monkeypatch.setattr(httpx.AsyncHTTPTransport, "handle_async_request", deny)


@pytest.fixture
def backend(monkeypatch, offline):
    # Patch before importing main: its module-level load_dotenv must never read .env.
    monkeypatch.setattr(dotenv, "load_dotenv", Mock(return_value=False))
    module = importlib.import_module("service.main")
    config = {
        "SUPABASE_URL": "https://synthetic-project.invalid",
        "SUPABASE_ANON_KEY": "FAKE_ANON_KEY",
        "OPENAI_API_KEY": "FAKE_OPENAI_KEY",
    }
    # Replace main's os reference, not the real process environment or os.getenv.
    monkeypatch.setattr(module, "os", SimpleNamespace(getenv=config.get))
    monkeypatch.setattr(module, "create_client", Mock(side_effect=AssertionError("Unexpected Supabase call")))
    monkeypatch.setattr(module, "OpenAI", Mock(side_effect=AssertionError("Unexpected OpenAI call")))
    return SimpleNamespace(api=module, config=config)


@pytest.fixture
def client(backend):
    with TestClient(backend.api.app, raise_server_exceptions=False) as test_client:
        yield test_client


@pytest.fixture
def supabase(backend):
    fake = Mock()
    fake.auth.get_user.return_value = SimpleNamespace(
        user=SimpleNamespace(id="11111111-1111-4111-8111-111111111111")
    )
    fake.table.return_value.insert.return_value.execute.return_value = SimpleNamespace(
        data=[{"id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}]
    )
    backend.api.create_client.side_effect = None
    backend.api.create_client.return_value = fake
    return fake


@pytest.fixture
def openai_client(backend):
    fake = Mock()
    fake.__enter__ = Mock(return_value=fake)
    fake.__exit__ = Mock(return_value=False)
    fake.chat.completions.create.return_value = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content="  Synthetic wellness information.  "))])
    backend.api.OpenAI.side_effect = None
    backend.api.OpenAI.return_value = fake
    return fake
