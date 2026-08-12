"""Tests for `vibe-trading login` / `logout` and the stored CLI JWT."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace

import pytest

from cli import _legacy


def _token_path(tmp_path: Path) -> Path:
    return tmp_path / "cli_token.json"


@pytest.fixture
def isolated_token(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> Path:
    """Point the CLI token store at a temp path for the duration of the test."""
    path = _token_path(tmp_path)
    monkeypatch.setattr(_legacy, "_cli_token_path", lambda: path)
    return path


class _FakeResponse:
    def __init__(self, status_code: int, payload: dict | None = None) -> None:
        self.status_code = status_code
        self._payload = payload or {}

    def json(self) -> dict:
        return self._payload


def test_cmd_login_stores_jwt_and_headers_carry_it(
    monkeypatch: pytest.MonkeyPatch, isolated_token: Path
) -> None:
    expires = (datetime.now(timezone.utc) + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    captured: dict = {}

    def fake_post(url, *, json, timeout):  # noqa: A002
        captured["url"] = url
        captured["json"] = json
        return _FakeResponse(
            200,
            {"jwt": "jwt-abc", "expires_at": expires, "user": {"username": "alice"}},
        )

    monkeypatch.setattr("httpx.post", fake_post)
    monkeypatch.setattr(_legacy, "get_env_config", lambda: SimpleNamespace(api=SimpleNamespace(vibe_trading_api_url="http://api.example/")))

    rc = _legacy.cmd_login(SimpleNamespace(username="alice", password="pw"))
    assert rc == _legacy.EXIT_SUCCESS
    assert captured["url"] == "http://api.example/auth/login"
    assert captured["json"] == {"username": "alice", "password": "pw"}

    stored = json.loads(isolated_token.read_text(encoding="utf-8"))
    assert stored["jwt"] == "jwt-abc"
    assert stored["username"] == "alice"
    # _api_auth_headers now sends the stored JWT as a bearer.
    assert _legacy._api_auth_headers() == {"Authorization": "Bearer jwt-abc"}


def test_cmd_login_rejects_bad_credentials(
    monkeypatch: pytest.MonkeyPatch, isolated_token: Path
) -> None:
    monkeypatch.setattr("httpx.post", lambda *a, **k: _FakeResponse(401))
    monkeypatch.setattr(_legacy, "get_env_config", lambda: SimpleNamespace(api=SimpleNamespace(vibe_trading_api_url="http://api.example/")))

    rc = _legacy.cmd_login(SimpleNamespace(username="alice", password="wrong"))
    assert rc == _legacy.EXIT_USAGE_ERROR
    assert not isolated_token.exists()
    assert _legacy._api_auth_headers() == {}


def test_cmd_logout_clears_token(isolated_token: Path) -> None:
    isolated_token.write_text(json.dumps({"jwt": "x", "expires_at": ""}), encoding="utf-8")
    assert _legacy._api_auth_headers() == {"Authorization": "Bearer x"}

    assert _legacy.cmd_logout() == _legacy.EXIT_SUCCESS
    assert not isolated_token.exists()
    assert _legacy._api_auth_headers() == {}


def test_expired_token_is_not_sent(monkeypatch: pytest.MonkeyPatch, isolated_token: Path) -> None:
    past = (datetime.now(timezone.utc) - timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    isolated_token.write_text(
        json.dumps({"jwt": "stale", "expires_at": past}), encoding="utf-8"
    )
    assert _legacy._api_auth_headers() == {}


def test_unexpired_token_is_sent(isolated_token: Path) -> None:
    future = (datetime.now(timezone.utc) + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    isolated_token.write_text(
        json.dumps({"jwt": "live", "expires_at": future, "username": "alice"}),
        encoding="utf-8",
    )
    assert _legacy._api_auth_headers() == {"Authorization": "Bearer live"}
