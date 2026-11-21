# Security requirements: landing page and sign-in screens (design stage)

| | |
|---|---|
| **Date** | 2026-11-21 |
| **Reviewer** | security-reviewer agent; saved by the orchestrator because the reviewer had read-only tools |
| **Stage** | Design. No auth code exists yet. |
| **Spec read** | `spec/v4.0/docs/SESSION_SECURITY.md`, `EU_PRIVACY_COOKIES.md`, `CORE_EXPERIENCE_AND_CATALOG.md:15`; `docs/adr/0006-six-platform-targets-and-fallbacks.md`; `docs/security/threat-model.md` |

**Every Firebase behaviour below is unverified**, because no page could be fetched during this review. Before M3, the researcher must fetch and quote:

- firebase.google.com/docs/auth/web/password-auth
- cloud.google.com/identity-platform/docs/admin/email-enumeration-protection
- firebase.google.com/docs/auth/web/email-link-auth
- the Firebase password-policy page
- firebase.google.com/docs/auth/web/auth-state-persistence

## A1 Sign-in methods and flows

- **R1** Sign-in is email and password: the Firebase SDK on web, Android, iOS and macOS, and the Auth REST API on Linux and Windows (ADR-0006). Passwords never reach the Worker (SESSION_SECURITY step 7).
  - Confirm: a Worker route test shows no route accepts a `password` field, and a network log review agrees.
- **R2** Turn on email enumeration protection in the Firebase project, and record the setting in the M3 ADR. Expected effects (unverified):
  - a wrong password and an unknown email return the same error (`INVALID_LOGIN_CREDENTIALS`);
  - a reset request for an unknown email does not fail;
  - looking up sign-in methods returns nothing.

  It probably does not cover sign-up, where `email-already-in-use` is still returned.
  - Confirm: a REST call with an unknown email and one with a wrong password give the same error code (V4-SEC-01).
- **R3** Create account always ends on one neutral "check your email" screen. The client sends the verification email, signs Firebase out, and doesn't call `/api/auth/session`. The Worker refuses a session while `email_verified` is false (SESSION_SECURITY step 2).
  - Confirm: a widget test shows the same screen and the same focus order for a new and for an existing email.
  - Confirm: a Worker test with an unverified token returns 403 with a stable code.
- **R4** Social providers: GitHub and Google cost nothing on standard Firebase Auth (research ledger). Leave them out of M3 unless the owner decides otherwise, because:
  - popup and redirect flows need a `frame-src` for the Firebase auth domain, and break under third-party storage partitioning (unverified);
  - the desktop REST client would need a loopback OAuth flow;
  - "account exists with a different credential" errors enumerate accounts;
  - signing in with GitHub doesn't prove ownership of a repository (SEC-002); ownership still goes through the GitHub App's user authorization.
- **R5** Email action links (verify, reset) use an action URL on the canonical host, which is also listed in Authorized Domains (OPS-001, OPS-002). The page that handles them:
  - sends `Referrer-Policy: no-referrer` and `Cache-Control: no-store`;
  - removes `oobCode` from the address bar after reading it;
  - never logs it (SEC-015).
  - Confirm: review the logs after a reset.
- **R6** After a password reset, the interface says "you are signed out everywhere" only if the Worker really revokes the D1 sessions. That depends on the open decision in threat-model row 4.3.

## A2 Sessions on web and native

- **R7** Web keeps the Firebase state in memory only (SESSION_SECURITY step 1; `Persistence.NONE` is web-only per the research ledger).
  - Confirm: an end-to-end test signs in and reloads, and storage holds no `firebase:*` or token keys.
  - Confirm: the browser-storage rule in `tool/check_rules.py`.
- **R8** The Worker sets the cookie `__Host-course_session` (HttpOnly, Secure, SameSite=Lax, Path=/, no Domain, `Max-Age=43200`). JavaScript never reads it (SEC-011, CT-003).
  - Confirm: parse `Set-Cookie`, and check that `document.cookie` doesn't contain it.
- **R9** Login CSRF: `POST /api/auth/session` requires the exact Origin and rotates the session (SEC-012, SEC-013).
  - Confirm: a cross-origin POST returns 403.
- **R10** The app fetches the CSRF token from `/api/auth/csrf` (`no-store`) and keeps it in memory only. Every mutation sends `X-CSRF-Token`, logout included, and logout is a POST (SEC-012).
- **R11** After a reload, the app learns who is signed in from `GET /api/auth/me` (`no-store`). Until that returns, the header shows a neutral placeholder rather than flashing "Log in" (V4-CACHE-02).
- **R12** Session-expired state, after 30 minutes idle or 12 hours absolute: a non-modal notice, "You've been logged out. Log in to continue.", with Log in. It returns to the same route and keeps unsent input (ERR-006).
  - Confirm: a test where the session has expired and a request gets 401, then logging in again restores the route.
- **R13** Logout sits in the account menu in the signed-in header, beside "Log out of all devices" (SESSION_SECURITY step 6).
  - On success it clears providers and caches and goes to the landing page, and replaying the old cookie returns 401 (SEC-013).
  - If revocation fails, the app shows an error with "Try again"; it never reports a success that didn't happen.
- **R14** Native apps use `Authorization: Bearer` and no cookies.
  - The SDK keeps tokens in secure storage; desktop uses the OS keychain (ADR-0006), and logout deletes the keychain item.
  - Grading, admin and certificate actions need a fresh login (SESSION_SECURITY, "Native").
- **R15** Forms:
  - Credentials go by POST or the SDK, never in a query string.
  - Fields carry the autofill hints `email`, `current-password` and `new-password`. Paste is allowed, and "Show password" starts hidden.
  - A `next=` after login accepts only same-origin relative paths.
  - Confirm: a unit test rejects `//evil`, `https://evil` and `/\evil`.
- **R16** Every auth screen and the landing page send `frame-ancestors 'none'` (SESSION_SECURITY headers).

## A3 The landing page

- **R17** The landing page is static HTML and CSS from Worker static assets, so it invokes no Worker code (V4-CACHE-04, CACHE-010).
  - It makes no third-party requests at all: fonts are self-hosted woff2, with no analytics, CDN or QR service (V4-COST-06, PRIV-002, CT-001).
  - "Log in" and "Create account" link into the app at `/app`, so Firebase JavaScript never loads on the landing page.
  - Confirm: a Playwright HAR of the page load shows only the canonical origin, and no cookies are set.
- **R18** The landing page's Content Security Policy:
  `default-src 'none'; style-src 'self'; font-src 'self'; img-src 'self'; script-src 'none'` (or `'self'` for a menu script, with no inline JavaScript); `connect-src 'none'; base-uri 'none'; form-action 'self'; object-src 'none'; frame-ancestors 'none'; upgrade-insecure-requests`.
  - Also send `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()`, and HSTS on the custom host.
  - Unverified: that a `_headers` file applies to Workers static assets.
- **R19** The app's CSP: `connect-src 'self'` plus the Firebase Auth hosts (identitytoolkit and securetoken; the exact hosts are to be fetched). Flutter web may need `wasm-unsafe-eval` (spike S3).
  - Unverified risk: Flutter web may load CanvasKit from gstatic and fallback fonts from Google by default. Both must be self-hosted.
  - Confirm: a HAR of the app.
- **R20** Catalog thumbnails come from the same origin, read at the pinned SHA, and are never hotlinked from raw.githubusercontent.com or an author's host (threat 5.6). An SVG cover is used only inside `<img>`, served with `nosniff` and `Content-Security-Policy: sandbox` (SEC-014).
- **R21** Download links are written at build time and point only to this project's github.com Releases asset URLs. The assets come from the CI release workflow, never a manual upload.
  - Show each asset's SHA-256, link to the checksums file, and publish the Android signing certificate's SHA-256 fingerprint.
  - Copy never tells users to turn off operating-system protections globally.
  - Confirm: a test that every download `href` matches `^https://github.com/<owner>/<repo>/releases/`.
- **R22** The QR code is a static SVG made at build time. It encodes the canonical HTTPS URL, which is also printed as text under it.
  - Confirm: CI decodes the SVG and compares it with the canonical host.

## A4 The private-or-missing message

- **R23** One response (404 `course_not_found`) and one text for missing, private and unsafe addresses, for every visitor.
  - A "Log in" action may be offered, as the spec asks for owner connect and login options (CORE_EXPERIENCE:15), provided the text, actions and timing don't change with the cause.
  - The anonymous preview never uses an installation token, which could see private repositories.
  - After login, connecting a repository goes through GitHub App authorization, and the result never says "exists but not yours" (SEC-002, SEC-005).
  - Confirm: snapshot tests show the three causes render the same widget tree, and a route test shows the bodies match apart from the request ID.

## A5 Password rules

- **R24** The client rule is at least 12 characters and at most 128, any characters allowed, with no composition rules.
  - Unverified: Firebase's server-side minimum (probably 6), and whether password-policy enforcement exists on the standard tier.
  - The REST API bypasses client checks, so set Firebase's policy to the same value if the tier allows it; otherwise record the gap.
  - No Firebase breached-password check could be verified. A Have I Been Pwned k-anonymity check would be a third-party request from the client, so it needs an owner decision and a line in the privacy notice. Spec step 7 rules out doing it in the Worker.

## A6 Answers to the copy questions (`docs/ux/copy/landing.md` section 6)

- **Q3, "Log in" on the private-or-missing message:** safe on the conditions in R23. When the visitor is already signed in, the action becomes "Connect a repository".
- **Q4, the create-account confirmation:** not accurate as drafted. For an email that already has an account nothing is sent, and sign-up probably still reveals that the email is taken (unverified). Use: "Check your email. If {email} can be used for a new account, we have sent a link to confirm it. If you already have an account, log in or reset your password."
- **Q5, sign-in methods:** email and password only for M3 (R4).
- **5.3, log-in errors:**
  - The generic text is safe only with R2. Map `user-disabled` to the same generic text unless a fetched source shows Firebase returns it only after a correct password.
  - For too many attempts, "Wait a few minutes" replaces "Wait a minute", because Firebase doesn't publish a lockout time (unverified).
  - Add a state for a correct password on an unverified email: "Confirm your email first", with "Send the link again".
- **5.4, password hint:** "Use at least 12 characters. A password you don't use anywhere else is best."

Not checked, because no code exists: every Worker and widget test named above.
