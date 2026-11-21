# Authentication, cookies and session security contract (v3)

## Default web session design (same-origin)

1. Flutter Web uses Firebase Auth SDK to log in. Set `inMemoryPersistence` for the *login-to-session exchange* by default. Obtain a Firebase ID token; send it via TLS once to `POST /api/auth/session` on the **same website hostname**. Do not save ID tokens, refresh tokens, GitHub tokens or private file URLs in `localStorage`, `sessionStorage`, URLs, logs or analytics. The SDK may temporarily hold a token in memory for this exchange. Clean up client Firebase state after session establishment as designed.
2. Worker verifies Firebase JWT cryptographic signature with Google's rotated public keys, checks `aud`, `iss`, `sub`, `exp`, `iat`, and rejects invalid/expired tokens; verify `email_verified` if required for enrollment/certificates. If sensitive account revocation is a requirement, implement an explicit revocation check or accept the documented short-session revocation window. Pure local JWT verification alone does not establish token revocation.
3. Worker creates CSPRNG 256-bit random opaque session ID. Store **SHA-256(session ID)** in D1, not the raw ID; associate UID, creation, absolute expiry (12 hours), idle expiry (30 minutes, configurable), last seen, revoked flag, and auth state version. Limit concurrent sessions and rate-limit creation.
4. Send `Set-Cookie: __Host-course_session=<opaque>; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=43200`. Never set `Domain` for a `__Host-` cookie. Same-site redirects with an external login provider must be tested. Use separate sessions for `pages.dev` and custom domain; select canonical hostname.
5. Protected `GET`s validate cookie hash and server-side role. Mutating calls (`POST`, `PUT`, `PATCH`, `DELETE`) require `Origin` matching exact canonical origin, `Content-Type: application/json` where applicable, `X-CSRF-Token` bound to server-side session, and no caching. CSRF token returned by `/api/auth/csrf` with `Cache-Control: no-store` to authenticated clients; keep it in memory, not persistent storage.
6. Server controls authorization on every operation; cookie possession is necessary but not sufficient. Regenerate session after login/step-up. Logout deletes/revokes D1 hash and expires cookie with exact attributes. `logout all devices` revokes all hashes.
7. Do not send password details to Workers. Firebase manages password verification, email confirmation, social login, credential recovery and MFA if enabled. Sessions and user roles are your platform's responsibility.

## Native application authentication

Native Flutter authenticates through Firebase SDK and sends `Authorization: Bearer <Firebase ID token>` on each protected request; Worker validates signature+claims and uses D1 for roles/enrollment. Do not issue browser cookies to native clients. Token persistence should use Firebase SDK backed by platform secure storage; do not copy tokens to logs or normal shared preferences. Require a fresh token/re-authentication for grading/admin/certificate issuance as policy demands.

## Instructor GitHub authorization

Use GitHub App installation tokens generated server-side. Keep app private key and webhook secret in Workers Secrets, not D1 or GitHub `course.yaml`. Installation token lives at most 1 hour, is scoped to repository IDs and minimum permissions; never return it to Flutter. Use a GitHub user authorization flow to bind the GitHub identity and verify admin permission before initial course registration. Validate installation callback state/nonce and compare stable GitHub IDs. A pasted repository URL is not proof of ownership.

## Threat controls

- Browser XSS: Content Security Policy, proper output escaping, sanitize Markdown/notebook HTML, no arbitrary HTML execution; separate sandbox origins for risky previews. Treat uploaded PDFs as potentially malicious; render with maintained viewer; do not run notebook cells.
- CSRF: Origin + session-bound CSRF token, same-site cookie, state-changing routes require POST/PUT/PATCH/DELETE; never use GET mutations.
- SSRF / URL exfiltration: Do not fetch arbitrary manifest URLs from server. Require GitHub host for repos, HTTPS for media links, embed provider allowlist; validate redirect hosts where network requests occur.
- IDOR: Lookup student UID from authenticated identity, not user-supplied UID or path. Student may read own submissions/grades; staff must be scoped to course. Deny by default.
- Replay / race: use reservation token/nonce and idempotency key, D1 unique constraints, attempt-number locking, server-generated paths and expiry, finalization exactly-once semantics.
- Forgery: grades/certificates only created by verified staff, D1 authoritative, append-only grade_events with actor/time, certificate revocation audited.
- Token leakage: redact Authorization headers, secrets, signed URLs, PII and student file contents from logs. Do not include secrets in errors or external analytics.
- Quotas/abuse: per-user, per-course, per-IP rate limits; finite manifest size; upload limits; retry backoff, concurrency caps, spending alerts and manual owner limits.
- Privacy: data retention policy, user export and deletion workflow, certificate/public disclosure notices, private GitHub repo where needed, no public student grade exports. “Real name required” is not the same as identity verified; certificate must clearly indicate if unverified.

## Default security headers

- App HTML: `Content-Security-Policy` tailored to Firebase identity endpoints, approved video providers and asset hosts (avoid unsafe-inline/unsafe-eval unless platform build forces a documented exception), `Referrer-Policy: strict-origin-when-cross-origin`, `X-Content-Type-Options: nosniff`, `Permissions-Policy` restrictive, `Strict-Transport-Security` on custom HTTPS host, `frame-ancestors 'none'` for app except sandbox preview rules.
- API JSON: `Cache-Control: no-store` on auth/private data, `Content-Type: application/json; charset=utf-8`, `X-Content-Type-Options: nosniff`; CORS disabled by default for same-origin browser and only allowlisted if using other origins/native.
- Downloads: `Content-Disposition` safe filename; correct MIME after validation; do not reflect untrusted filename into headers unsanitized. Use `Range` for large PDFs and video when proxying private content.

## Acceptance tests

- Attempt write as student to another student's grade/submission -> 403; no GitHub operation.
- Missing/forged/expired ID JWT -> 401; revoked D1 web session -> 401.
- Cross-site POST without valid CSRF and Origin -> 403.
- A `__Host-` cookie has Secure, HttpOnly, SameSite and Path and lacks Domain; localhost dev uses secure same-host environment or explicit nonproduction-only variant.
- Cached public content cannot serve private file or student grades after switching accounts.
- GitHub App token, PAT, Firebase token and payment-provider credentials never appear in Flutter source, browser dev tools responses, logs, YAML or analytics.
