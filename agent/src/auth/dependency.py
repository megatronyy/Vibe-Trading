"""FastAPI dependency that resolves the current request's Principal.

Drop-in replacement for ``require_auth`` — when the user table is empty
(single-tenant / fresh install), returns ``Principal.anonymous()`` so the
system behaves exactly as before.
"""

from __future__ import annotations

from typing import Optional

from fastapi import Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from src.auth.models import Principal, User
from src.auth.tokens import verify_token, principal_from_claims
from src.auth.user_store import UserStore

_security = HTTPBearer(auto_error=False)


def _extract_bearer(request: Request) -> Optional[str]:
    """Extract the Bearer token from the Authorization header or legacy API key."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        return auth_header[7:]
    return None


def _is_loopback(request: Request) -> bool:
    client = request.client
    if not client:
        return False
    host = client.host
    if host in ("127.0.0.1", "::1", "localhost", "testclient"):
        return True
    try:
        import ipaddress
        return ipaddress.ip_address(host).is_loopback
    except (ValueError, TypeError):
        return False


def get_current_principal(request: Request) -> Principal:
    """Resolve the current user from the request.

    Resolution order:
    1. If user table is empty → ``Principal.anonymous()`` (backward compat).
    2. If a valid JWT Bearer token is present → verify + resolve user.
    3. If loopback client + no token → ``Principal.anonymous()`` (dev trust).
    4. Otherwise → anonymous (the route's own auth gate will 401/403).
    """
    store = UserStore.get_instance()

    # 1. No users registered → single-tenant mode.
    if store.count() == 0:
        return Principal.anonymous()

    # 2. Try JWT Bearer token.
    token = _extract_bearer(request)
    if token:
        claims = verify_token(token)
        if claims:
            return principal_from_claims(claims)
        # Token present but invalid — fall through (route handler will 401).

    # 3. Loopback trust (dev mode, CLI).
    if _is_loopback(request):
        return Principal.anonymous()

    # 4. Anonymous (no valid identity).
    return Principal.anonymous()


def require_authenticated_principal(request: Request) -> Principal:
    """Like [get_current_principal] but raises 401 if not a real user
    (i.e., anonymous is not allowed)."""
    from fastapi import HTTPException

    principal = get_current_principal(request)
    if principal.is_anonymous:
        store = UserStore.get_instance()
        if store.count() > 0:
            raise HTTPException(status_code=401, detail="Authentication required")
    return principal
