# Code Review: Auth Middleware Refactor

**PR #142** by @sarah — `feature/session-refresh`

## Summary

Replaces the legacy cookie-based session middleware with JWT + refresh token rotation. Adds automatic token refresh on 401 responses and moves session storage from Redis to encrypted HTTP-only cookies.

## Issues Found

### [CRITICAL] Refresh token not invalidated on use

```go
func (m *AuthMiddleware) RefreshToken(w http.ResponseWriter, r *http.Request) {
    claims, err := m.verifyRefreshToken(r)
    if err != nil {
        http.Error(w, "unauthorized", 401)
        return
    }
    // BUG: old refresh token is still valid after issuing new one
    newAccess, newRefresh := m.issueTokenPair(claims.UserID)
    m.setTokenCookies(w, newAccess, newRefresh)
}
```

The old refresh token remains valid until expiry. An attacker who intercepts one refresh token gets permanent access. **Must** invalidate the previous token on rotation:

```go
if err := m.tokenStore.Revoke(claims.TokenID); err != nil {
    log.Error("failed to revoke refresh token", "err", err)
    http.Error(w, "internal error", 500)
    return
}
```

### [HIGH] Missing rate limit on refresh endpoint

The `/auth/refresh` endpoint has no rate limiting. An attacker could brute-force refresh tokens or use it for token spray attacks. Add the same `RateLimit(10, time.Minute)` middleware used on `/auth/login`.

### [MEDIUM] Access token lifetime too long

Currently set to 30 minutes. Industry standard for sensitive operations is 5-15 minutes. Recommend reducing to **10 minutes** — the refresh flow is seamless, so users won't notice.

## What's Good

- Clean separation of `TokenIssuer` and `TokenVerifier` interfaces — makes testing straightforward
- Cookie flags are correct: `HttpOnly`, `Secure`, `SameSite=Strict`
- Good error messages in logs without leaking details to the client
- The `WithAuth()` middleware pattern composes well with existing routes

## Suggestions

1. Add a `token_family` field to detect refresh token reuse (indicates theft)
2. Consider a `/auth/revoke-all` endpoint for "sign out everywhere"
3. The `claims.Exp` check on line 47 is redundant — `jwt.Parse` already validates expiry
4. Add integration test for the full refresh rotation flow

## Verdict

**Request changes.** The refresh token reuse vulnerability is a blocker. Once that's fixed and rate limiting is added, this is a solid improvement over the cookie-session approach.
