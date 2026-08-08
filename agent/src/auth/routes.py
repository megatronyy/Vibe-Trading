"""Auth API routes: register, login, me, refresh."""

from __future__ import annotations

import time
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field

from src.auth.dependency import get_current_principal, require_authenticated_principal
from src.auth.models import Principal
from src.auth.tokens import issue_token, verify_token
from src.auth.user_store import UserStore


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=2, max_length=64)
    password: str = Field(..., min_length=4, max_length=128)


class RegisterRequest(LoginRequest):
    pass


def register_auth_routes(app: FastAPI) -> None:
    """Mount /auth/* routes onto [app]."""

    @app.post("/auth/login")
    async def login(payload: LoginRequest) -> dict[str, Any]:
        store = UserStore.get_instance()
        user = store.verify_password(payload.username, payload.password)
        if user is None:
            raise HTTPException(status_code=401, detail="Invalid username or password")
        token, ttl = issue_token(user)
        return {
            "jwt": token,
            "expires_at": time.strftime(
                "%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + ttl)
            ),
            "user": user.to_dict(),
        }

    @app.post("/auth/register")
    async def register(payload: RegisterRequest) -> dict[str, Any]:
        store = UserStore.get_instance()

        # First user becomes admin; subsequent registrations get role "user".
        # This endpoint is intentionally PUBLIC — it is the credential entry
        # point. If admin wants to lock it down, set allow_registration=False
        # in config (TODO).
        is_first_user = store.count() == 0
        role = "admin" if is_first_user else "user"

        try:
            user = store.create_user(payload.username, payload.password, role=role)
        except ValueError as e:
            raise HTTPException(status_code=409, detail=str(e))

        token, ttl = issue_token(user)
        return {
            "jwt": token,
            "expires_at": time.strftime(
                "%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + ttl)
            ),
            "user": user.to_dict(),
        }

    @app.get("/auth/me")
    async def me(request: Request) -> dict[str, Any]:
        principal = require_authenticated_principal(request)
        return {
            "user_id": principal.user_id,
            "username": principal.username,
            "role": principal.role,
            "is_anonymous": principal.is_anonymous,
        }

    @app.post("/auth/refresh")
    async def refresh(request: Request) -> dict[str, Any]:
        principal = require_authenticated_principal(request)
        if principal.is_anonymous:
            raise HTTPException(status_code=401, detail="Cannot refresh anonymous session")
        store = UserStore.get_instance()
        user = store.get_by_id(principal.user_id)
        if user is None or not user.is_active:
            raise HTTPException(status_code=401, detail="User not found or inactive")
        token, ttl = issue_token(user)
        return {
            "jwt": token,
            "expires_at": time.strftime(
                "%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + ttl)
            ),
            "user": user.to_dict(),
        }

    @app.get("/users")
    async def list_users(request: Request) -> list[dict[str, Any]]:
        principal = require_authenticated_principal(request)
        if principal.role != "admin":
            raise HTTPException(status_code=403, detail="Admin only")
        store = UserStore.get_instance()
        return [u.to_dict() for u in store.list_users()]

    @app.delete("/users/{user_id}")
    async def deactivate_user(user_id: str, request: Request) -> dict[str, str]:
        principal = require_authenticated_principal(request)
        if principal.role != "admin":
            raise HTTPException(status_code=403, detail="Admin only")
        store = UserStore.get_instance()
        store.deactivate(user_id)
        return {"status": "deactivated"}
