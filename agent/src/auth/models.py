"""User and Principal data models."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional
from uuid import uuid4


@dataclass(frozen=True)
class User:
    """A registered user."""

    user_id: str
    username: str
    password_hash: str
    role: str  # "admin" | "user"
    created_at: str
    is_active: bool = True

    def to_dict(self) -> dict:
        return {
            "user_id": self.user_id,
            "username": self.username,
            "role": self.role,
            "created_at": self.created_at,
            "is_active": self.is_active,
        }

    @classmethod
    def from_row(cls, row: dict) -> User:
        return cls(
            user_id=row["user_id"],
            username=row["username"],
            password_hash=row["password_hash"],
            role=row["role"],
            created_at=row["created_at"],
            is_active=bool(row.get("is_active", 1)),
        )


@dataclass(frozen=True)
class Principal:
    """The request-scoped identity, resolved from the JWT bearer token.

    When no users are registered (single-tenant deployment), all requests
    get ``Principal.anonymous()`` and the system behaves as before.
    """

    user_id: str
    username: str
    role: str  # "admin" | "user" | "anonymous"
    is_anonymous: bool = False

    @classmethod
    def anonymous(cls) -> Principal:
        return cls(user_id="_anonymous", username="anonymous", role="anonymous", is_anonymous=True)

    @classmethod
    def from_user(cls, user: User) -> Principal:
        return cls(user_id=user.user_id, username=user.username, role=user.role)

    @property
    def effective_owner_id(self) -> str:
        """The owner_id to use for data scoping. Anonymous → "_legacy"."""
        return "_legacy" if self.is_anonymous else self.user_id


def new_user_id() -> str:
    return uuid4().hex[:12]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")
