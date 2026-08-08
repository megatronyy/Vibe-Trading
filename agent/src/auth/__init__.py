"""User authentication and authorization package.

Provides per-user identity (registration, login, JWT tokens) and a FastAPI
dependency that resolves the current request's principal. Designed to be
backward-compatible: when no users exist, all requests get
``Principal.anonymous()`` and the system behaves exactly as before.
"""
