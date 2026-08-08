"""JWT token issue / verify using PyJWT."""

from __future__ import annotations

import secrets
import time
from pathlib import Path
from typing import Optional

import jwt as pyjwt

from src.auth.models import User, Principal

_DEFAULT_TTL_HOURS = 12


_SECRET_FILE = None  # cached path
_CACHED_SECRET = None  # cached value


def _get_or_create_secret() -> str:
    """Get the JWT secret from env config, or generate+persist one."""
    global _CACHED_SECRET, _SECRET_FILE
    if _CACHED_SECRET:
        return _CACHED_SECRET

    # 1. Try env config.
    try:
        from src.config.accessor import get_env_config
        cfg = get_env_config()
        auth_cfg = getattr(cfg, "auth", None)
        if auth_cfg and getattr(auth_cfg, "jwt_secret", None):
            _CACHED_SECRET = auth_cfg.jwt_secret
            return _CACHED_SECRET
    except Exception:
        pass

    # 2. Try persisted secret file.
    if _SECRET_FILE is None:
        _SECRET_FILE = Path.home() / ".vibe-trading" / "jwt_secret"
    if _SECRET_FILE.exists():
        _CACHED_SECRET = _SECRET_FILE.read_text(encoding="utf-8").strip()
        return _CACHED_SECRET

    # 3. Generate + persist.
    _SECRET_FILE.parent.mkdir(parents=True, exist_ok=True)
    _CACHED_SECRET = secrets.token_hex(32)
    _SECRET_FILE.write_text(_CACHED_SECRET, encoding="utf-8")
    try:
        _SECRET_FILE.chmod(0o600)
    except OSError:
        pass  # Windows
    return _CACHED_SECRET


def _get_ttl_seconds() -> int:
    try:
        from src.config.accessor import get_env_config
        cfg = get_env_config()
        auth_cfg = getattr(cfg, "auth", None)
        if auth_cfg and getattr(auth_cfg, "jwt_ttl_hours", None):
            return auth_cfg.jwt_ttl_hours * 3600
    except Exception:
        pass
    return _DEFAULT_TTL_HOURS * 3600


def issue_token(user: User) -> tuple[str, int]:
    """Issue a JWT for [user]. Returns (token_string, expires_in_seconds)."""
    ttl = _get_ttl_seconds()
    now = int(time.time())
    payload = {
        "sub": user.user_id,
        "username": user.username,
        "role": user.role,
        "iat": now,
        "exp": now + ttl,
    }
    token = pyjwt.encode(payload, _get_or_create_secret(), algorithm="HS256")
    return token, ttl


def verify_token(token: str) -> Optional[dict]:
    """Verify a JWT. Returns claims dict or None if invalid/expired."""
    try:
        return pyjwt.decode(token, _get_or_create_secret(), algorithms=["HS256"])
    except pyjwt.PyJWTError:
        return None


def principal_from_claims(claims: dict) -> Principal:
    return Principal(
        user_id=claims.get("sub", ""),
        username=claims.get("username", ""),
        role=claims.get("role", "user"),
    )
