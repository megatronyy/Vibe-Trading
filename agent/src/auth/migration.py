"""One-shot migration: create admin user + backfill owner_id on existing data.

Idempotent: a ``migration_state.json`` records completion; re-runs are no-ops.
"""

from __future__ import annotations

import json
import logging
import secrets
from pathlib import Path

from src.auth.user_store import UserStore

logger = logging.getLogger(__name__)
_STATE_FILE = Path.home() / ".vibe-trading" / "auth_migration_state.json"


def run_if_needed() -> None:
    """Run the migration if it hasn't been done yet. Idempotent."""
    if _STATE_FILE.exists():
        logger.info("auth migration already completed, skipping")
        return

    store = UserStore.get_instance()
    if store.count() > 0:
        # Users already exist (maybe created manually) — just mark done.
        _mark_done()
        return

    # Check if there's existing single-tenant data to migrate.
    vibe_dir = Path.home() / ".vibe-trading"
    has_data = any(vibe_dir.glob("sessions.db")) or any(vibe_dir.glob("agent.json"))
    if not has_data:
        # Fresh install — no migration needed.
        _mark_done()
        logger.info("auth migration: fresh install, no data to migrate")
        return

    # Create admin user with a random password.
    admin_password = secrets.token_urlsafe(16)
    try:
        admin = store.create_user("admin", admin_password, role="admin")
    except ValueError:
        logger.warning("admin user already exists, skipping creation")
        _mark_done()
        return

    # Print the password once (server log + file).
    pw_file = vibe_dir / ".initial_admin_password"
    pw_file.write_text(admin_password, encoding="utf-8")
    try:
        pw_file.chmod(0o600)
    except OSError:
        pass  # Windows

    logger.warning("=" * 60)
    logger.warning("AUTH MIGRATION COMPLETE")
    logger.warning("Admin user 'admin' created with password: %s", admin_password)
    logger.warning("Password also written to: %s", pw_file)
    logger.warning("CHANGE THIS PASSWORD IMMEDIATELY via /auth/register")
    logger.warning("=" * 60)

    # --- Backfill owner_id on existing data ---
    # 1. sessions.db: goals table
    _backfill_goals(admin.user_id)

    # 2. session.json files
    _backfill_session_files(admin.user_id)

    _mark_done()
    logger.info("auth migration: backfill complete, owner_id=%s", admin.user_id)


def _backfill_goals(owner_id: str) -> None:
    """Add owner_id column to goals table if not present."""
    import sqlite3
    db_path = Path.home() / ".vibe-trading" / "sessions.db"
    if not db_path.exists():
        return
    try:
        conn = sqlite3.connect(str(db_path), isolation_level=None)
        # Check if column exists
        cols = [r[1] for r in conn.execute("PRAGMA table_info(goals)").fetchall()]
        if "owner_id" not in cols:
            conn.execute(
                "ALTER TABLE goals ADD COLUMN owner_id TEXT NOT NULL DEFAULT ?", (owner_id,)
            )
            conn.execute("CREATE INDEX IF NOT EXISTS idx_goals_owner ON goals(owner_id)")
            logger.info("goals table: added owner_id column, backfilled '%s'", owner_id)
        conn.close()
    except Exception as e:
        logger.warning("goals backfill failed: %s", e)


def _backfill_session_files(owner_id: str) -> None:
    """Add owner_id to every session.json in the sessions directory."""
    sessions_dirs = [
        Path(__file__).resolve().parents[2] / "sessions",  # agent/sessions
        Path.home() / ".vibe-trading" / "sessions",
    ]
    for base in sessions_dirs:
        if not base.is_dir():
            continue
        for session_dir in base.iterdir():
            if not session_dir.is_dir():
                continue
            meta_path = session_dir / "session.json"
            if not meta_path.exists():
                continue
            try:
                data = json.loads(meta_path.read_text(encoding="utf-8"))
                if "owner_id" not in data:
                    data["owner_id"] = owner_id
                    meta_path.write_text(
                        json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8"
                    )
            except Exception as e:
                logger.warning("session backfill failed for %s: %s", session_dir.name, e)


def _mark_done() -> None:
    _STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    _STATE_FILE.write_text(
        json.dumps({"completed": True}, indent=2), encoding="utf-8"
    )
