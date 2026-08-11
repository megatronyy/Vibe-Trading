"""API auth contract: JWT is the only bearer credential; loopback dev-trust is preserved.

The API server no longer accepts ``API_AUTH_KEY`` as a bearer credential --
JWT is the only accepted token. A request with no token is admitted only from a
loopback peer (dev mode); a non-loopback peer without a valid JWT is rejected.
This file pins that contract on both ``require_auth`` and the event-stream
dependency.

A default FastAPI ``TestClient`` reports its peer host as ``testclient``, which
``_is_local_client`` treats as loopback. ``TestClient(..., client=("203.0.113.10", ...))``
simulates a non-loopback caller.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

import api_server


def _loopback_client() -> TestClient:
    """TestClient whose peer host ('testclient') is treated as loopback."""
    return TestClient(api_server.app)


def _remote_client() -> TestClient:
    """TestClient that simulates a non-loopback caller."""
    return TestClient(api_server.app, client=("203.0.113.10", 50000))


@pytest.fixture(autouse=True)
def clear_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    """Start every test from dev-mode auth (no configured key)."""
    monkeypatch.delenv("API_AUTH_KEY", raising=False)
    monkeypatch.delenv("VIBE_TRADING_TRUST_DOCKER_LOOPBACK", raising=False)
    monkeypatch.delenv("VIBE_TRADING_ENABLE_SHELL_TOOLS", raising=False)
    monkeypatch.setattr(api_server, "_API_KEY", "")


# (a) Loopback + no credential -> allowed (dev mode unchanged).
def test_loopback_allowed_in_dev_mode_without_token() -> None:
    response = _loopback_client().get("/runs")

    assert response.status_code == 200


# (b) Loopback + valid JWT -> allowed.
def test_loopback_with_valid_jwt_allowed(make_jwt) -> None:
    response = _loopback_client().get(
        "/runs", headers={"Authorization": f"Bearer {make_jwt()}"}
    )

    assert response.status_code == 200


# (b') Loopback + invalid bearer -> rejected (token present but not a valid JWT).
def test_loopback_with_invalid_bearer_rejected() -> None:
    response = _loopback_client().get(
        "/runs", headers={"Authorization": "Bearer not-a-jwt"}
    )

    assert response.status_code == 401


# (c) A configured API_AUTH_KEY is no longer consulted: loopback stays trusted.
def test_configured_api_key_does_not_gate_loopback(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("API_AUTH_KEY", "secret")
    monkeypatch.setattr(api_server, "_API_KEY", "secret")

    response = _loopback_client().get("/runs")

    # Loopback dev-trust applies regardless of API_AUTH_KEY now.
    assert response.status_code == 200


# (d) Remote + no credential -> rejected (403).
def test_remote_without_token_rejected() -> None:
    response = _remote_client().get("/runs")

    assert response.status_code == 403


# (e) Remote + valid JWT -> allowed.
def test_remote_with_valid_jwt_allowed(make_jwt) -> None:
    response = _remote_client().get(
        "/runs", headers={"Authorization": f"Bearer {make_jwt()}"}
    )

    assert response.status_code == 200


# (e') Remote + invalid bearer -> rejected (401).
def test_remote_with_invalid_bearer_rejected() -> None:
    response = _remote_client().get(
        "/runs", headers={"Authorization": "Bearer not-a-jwt"}
    )

    assert response.status_code == 401


# --- Event stream ---------------------------------------------------------

# (d) Event-stream: valid single-use ticket still authenticates (any peer).
def test_event_stream_accepts_valid_ticket(make_jwt) -> None:
    ticket = api_server._mint_sse_ticket()
    response = _remote_client().get(f"/sessions/missing/events?ticket={ticket}")

    # Auth passed; the 404/501 comes from the missing session / disabled runtime,
    # not from the auth layer (a 401/403 would mean auth rejected the ticket).
    assert response.status_code in {404, 501}


# (d) Event-stream: valid JWT bearer still authenticates.
def test_event_stream_accepts_valid_jwt(make_jwt) -> None:
    response = _remote_client().get(
        "/sessions/missing/events",
        headers={"Authorization": f"Bearer {make_jwt()}"},
    )

    assert response.status_code in {404, 501}


# (d) Event-stream: loopback allowed without any credential (dev mode).
def test_event_stream_allowed_in_dev_mode_without_token() -> None:
    response = _loopback_client().get("/sessions/missing/events")

    assert response.status_code in {404, 501}


# (d) Event-stream: an invalid bearer is rejected.
def test_event_stream_rejects_invalid_bearer() -> None:
    response = _remote_client().get(
        "/sessions/missing/events", headers={"Authorization": "Bearer not-a-jwt"}
    )

    assert response.status_code == 401


# (d) Event-stream: an expired/invalid ticket is not accepted.
def test_event_stream_rejects_invalid_ticket() -> None:
    response = _remote_client().get("/sessions/missing/events?ticket=not-a-real-ticket")

    assert response.status_code == 401
