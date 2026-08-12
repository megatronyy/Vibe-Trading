import { safeGet, safeRemove, safeSet } from "@/lib/storage";

const STORAGE_KEY = "vibe_trading_api_auth_key";
const JWT_STORAGE_KEY = "vibe_trading_jwt";

export function getApiAuthKey(): string {
  return safeGet(STORAGE_KEY) || "";
}

export function setApiAuthKey(value: string): void {
  const trimmed = value.trim();
  if (trimmed) {
    safeSet(STORAGE_KEY, trimmed);
  } else {
    safeRemove(STORAGE_KEY);
  }
}

// --- JWT auth (username/password login) -------------------------------------
// Sits alongside the long-lived API-key path. getAuthHeaders() prefers a valid
// JWT and falls back to the API key, so both auth modes work from one surface.

export function getJwt(): string {
  return safeGet(JWT_STORAGE_KEY) || "";
}

export function setJwt(token: string): void {
  const trimmed = token.trim();
  if (trimmed) {
    safeSet(JWT_STORAGE_KEY, trimmed);
  } else {
    safeRemove(JWT_STORAGE_KEY);
  }
}

export function clearJwt(): void {
  safeRemove(JWT_STORAGE_KEY);
}

/**
 * Prefer a JWT; return an empty object when none is stored (loopback dev mode
 * bypasses auth on the backend). API_AUTH_KEY is no longer an accepted server
 * credential, so it is never sent as a bearer token here.
 */
export function getAuthHeaders(): Record<string, string> {
  const jwt = getJwt();
  return jwt ? { Authorization: `Bearer ${jwt}` } : {};
}

/** Backwards-compatible alias; new code should call {@link getAuthHeaders}. */
export function authHeaders(): Record<string, string> {
  return getAuthHeaders();
}

// Decode the `exp` claim (Unix seconds) from a JWT payload without verifying
// the signature — client-side expiry is only a UX hint; the server is the
// source of truth and will reject a tampered/expired token.
function jwtExpiry(token: string): number | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")),
    ) as { exp?: unknown };
    return typeof payload.exp === "number" ? payload.exp : null;
  } catch {
    return null;
  }
}

/** A JWT is present and has not passed its `exp` claim. */
export function isLoggedIn(): boolean {
  const token = getJwt();
  if (!token) return false;
  const exp = jwtExpiry(token);
  if (exp === null) return true; // no exp claim → trust until the server rejects it
  return Date.now() < exp * 1000;
}

/**
 * Append a short-lived, single-use SSE ticket to an EventSource URL.
 *
 * A browser `EventSource` cannot set an `Authorization` header, so we exchange
 * the stored credential (JWT preferred, else API key — sent in a header on this
 * POST) for a one-shot ticket via `POST /auth/sse-ticket`, then open the stream
 * with `?ticket=`. This keeps the long-lived secret out of URLs, browser
 * history, and proxy/access logs.
 *
 * When no credential is stored the backend is in loopback dev mode (auth
 * bypassed), so the URL is returned unchanged and no ticket round-trip is made.
 * Tickets are single-use: every connect/reconnect must mint a fresh one, so
 * callers invoke this per connection attempt rather than caching the result.
 */
export async function withAuthTicket(url: string): Promise<string> {
  if (!getJwt() && !getApiAuthKey()) return url;
  const res = await fetch("/auth/sse-ticket", {
    method: "POST",
    headers: getAuthHeaders(),
  });
  if (!res.ok) {
    throw new Error(`Failed to obtain SSE ticket (HTTP ${res.status})`);
  }
  const data: unknown = await res.json();
  const ticket = (data as { ticket?: unknown } | null)?.ticket;
  if (typeof ticket !== "string" || !ticket) {
    throw new Error("SSE ticket response missing ticket");
  }
  const sep = url.includes("?") ? "&" : "?";
  return `${url}${sep}ticket=${encodeURIComponent(ticket)}`;
}
