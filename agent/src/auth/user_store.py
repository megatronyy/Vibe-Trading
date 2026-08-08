"""SQLite-backed user store with bcrypt password hashing."""

from __future__ import annotations

import sqlite3
import threading
from pathlib import Path
from typing import Optional

import bcrypt

from src.auth.models import User, new_user_id, now_iso

_DEFAULT_DB_PATH = Path.home() / ".vibe-trading" / "users.db"


class UserStore:
    """Thread-safe SQLite user store. One shared instance per process."""

    _instance: Optional[UserStore] = None
    _lock = threading.Lock()

    def __init__(self, db_path: Path | None = None) -> None:
        path = db_path or _DEFAULT_DB_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        self._path = path
        self._rl = threading.RLock()
        self._conn = sqlite3.connect(
            str(path), check_same_thread=False, isolation_level=None
        )
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute("PRAGMA foreign_keys=ON")
        self._conn.execute("PRAGMA busy_timeout=5000")
        self._create_schema()

    @classmethod
    def get_instance(cls) -> UserStore:
        with cls._lock:
            if cls._instance is None:
                cls._instance = UserStore()
            return cls._instance

    def _create_schema(self) -> None:
        with self._rl:
            self._conn.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    user_id       TEXT PRIMARY KEY,
                    username      TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    role          TEXT NOT NULL DEFAULT 'user',
                    created_at    TEXT NOT NULL,
                    is_active     INTEGER NOT NULL DEFAULT 1
                )
                """
            )

    # --- CRUD ---

    def create_user(self, username: str, password: str, role: str = "user") -> User:
        pw_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
        user = User(
            user_id=new_user_id(),
            username=username,
            password_hash=pw_hash,
            role=role,
            created_at=now_iso(),
        )
        with self._rl:
            try:
                self._conn.execute(
                    "INSERT INTO users (user_id, username, password_hash, role, created_at, is_active) "
                    "VALUES (?, ?, ?, ?, ?, 1)",
                    (user.user_id, user.username, user.password_hash, user.role, user.created_at),
                )
            except sqlite3.IntegrityError:
                raise ValueError(f"username '{username}' already exists")
        return user

    def get_by_username(self, username: str) -> Optional[User]:
        with self._rl:
            row = self._conn.execute(
                "SELECT * FROM users WHERE username = ?", (username,)
            ).fetchone()
        return User.from_row(dict(row)) if row else None

    def get_by_id(self, user_id: str) -> Optional[User]:
        with self._rl:
            row = self._conn.execute(
                "SELECT * FROM users WHERE user_id = ?", (user_id,)
            ).fetchone()
        return User.from_row(dict(row)) if row else None

    def verify_password(self, username: str, password: str) -> Optional[User]:
        user = self.get_by_username(username)
        if user is None or not user.is_active:
            return None
        if not bcrypt.checkpw(password.encode(), user.password_hash.encode()):
            return None
        return user

    def list_users(self) -> list[User]:
        with self._rl:
            rows = self._conn.execute(
                "SELECT * FROM users ORDER BY created_at"
            ).fetchall()
        return [User.from_row(dict(r)) for r in rows]

    def count(self) -> int:
        with self._rl:
            return self._conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]

    def deactivate(self, user_id: str) -> None:
        with self._rl:
            self._conn.execute(
                "UPDATE users SET is_active = 0 WHERE user_id = ?", (user_id,)
            )

    def close(self) -> None:
        with self._rl:
            self._conn.close()
