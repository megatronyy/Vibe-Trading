"""Shared fixtures and sys.path setup for all tests."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Ensure agent/ is on sys.path so imports like `backtest.*` and `src.*` work.
AGENT_DIR = Path(__file__).resolve().parent.parent
if str(AGENT_DIR) not in sys.path:
    sys.path.insert(0, str(AGENT_DIR))


@pytest.fixture(autouse=True)
def _reset_env_config():
    """Isolate each test from the process environment and the config cache.

    Two things leak between tests otherwise, and the second one bit us:

    1. The cached ``EnvConfig`` singleton, so ``monkeypatch.setenv`` would have
       no effect on anything already holding the cached instance.
    2. ``os.environ`` itself. The settings write path deliberately applies a
       written ``.env`` to the running process, which is correct in production
       (settings take effect without a restart) but means a settings TEST
       writing ``TUSHARE_TOKEN=ts-secret-token`` into a temp file leaks that
       value into the process for every test that follows. That is exactly how
       four live-data tests came to fail with "token is wrong" while passing in
       isolation -- and monkeypatch cannot undo it, because the test never went
       through monkeypatch to set it.

    Snapshotting and restoring the whole environment closes the class of bug
    rather than the one instance of it.
    """
    import os

    from src.config.accessor import reset_env_config

    saved_environ = dict(os.environ)
    reset_env_config()
    yield
    os.environ.clear()
    os.environ.update(saved_environ)
    reset_env_config()


@pytest.fixture
def make_jwt():
    """Return a callable that mints a verifiable JWT for the auth tests.

    API auth is JWT-only, so tests that previously sent ``Authorization: Bearer
    <API_AUTH_KEY>`` now need a real signed token. ``src.auth.tokens`` caches the
    HMAC secret module-globally (``_CACHED_SECRET``); pinning it to a fixed value
    here makes ``issue_token`` and ``verify_token`` agree within the test, and
    the prior cache is restored afterward so other tests are unaffected.
    """
    from src.auth import tokens as _tokens

    saved = _tokens._CACHED_SECRET
    _tokens._CACHED_SECRET = "test-jwt-secret-fixed-0123456789abcdef"
    try:

        def _make(username: str = "alice", role: str = "admin", user_id: str = "u1") -> str:
            from src.auth.models import User

            user = User(
                user_id=user_id,
                username=username,
                role=role,
                password_hash="x",
                created_at="2026-01-01T00:00:00+00:00",
            )
            token, _ = _tokens.issue_token(user)
            return token

        yield _make
    finally:
        _tokens._CACHED_SECRET = saved
