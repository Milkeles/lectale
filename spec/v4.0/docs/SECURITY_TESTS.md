# Security and quality acceptance cases (v3)

## Identity and authorization

SEC-001: Anonymous can import/preview a public course but cannot claim instructor ownership or enroll in restricted course.
SEC-002: Attackers paste someone else's public repository URL, forge owner UID, spoof GitHub installation ID, or replay a GitHub callback: denied.
SEC-003: Student attempts another student's submission/grade by changing UID, file path or SQL query params: 403.
SEC-004: Grader attempts course outside their staff membership: 403; student attempts grade/certificate issuance: 403.
SEC-005: Deny private content and file metadata to unauthenticated/non-enrolled students; don't leak source URLs or MIME metadata to them.
SEC-006: Instructor repository removed/transferred: privileged actions suspended, no implicit reassignment.

## Session / browser

SEC-010: Verify signed Firebase JWT claims; reject invalid issuer/audience/signature, expiry, `alg:none`, wrong project ID.
SEC-011: `__Host-course_session` is Secure HttpOnly Path=/ SameSite=Lax, no Domain. D1 stores only hash.
SEC-012: CSRF test with valid browser cookie but absent/wrong CSRF/Origin rejected on every mutation.
SEC-013: Logout/revocation clears server session; copied former cookie no longer works; old user cached data absent.
SEC-014: XSS payload in YAML description, filename, Markdown, notebook HTML, SVG never executes JS, leaks credentials or navigates parents.
SEC-015: No auth tokens, signed upload URLs or instructor PII logged, cached or placed in query strings unnecessarily.

## Files and uploads

SEC-020: Reject `../`, absolute path, `%2e%2e`, URL encoded traversal, backslash and symlink path.
SEC-021: Invalidate upload if declared size != uploaded object size, wrong key, owner, upload attempt, MIME/signature, checksum or expiration.
SEC-022: Enforce maxFiles, maxFileBytes, maxAttemptBytes, maxAttempts and storage cap on server, not just Flutter.
SEC-023: Concurrent finalize requests produce exactly one attempt; duplicate reservations don't bypass limit.
SEC-024: Student cannot use delegated upload credential to read existing private object, alter grade or write arbitrary repository files.
SEC-025: GitHub LFS delegated-upload POC: prove action is object-limited, does not include installation token and works from Flutter Web under CORS; if ANY fails, release flag MUST disable LFS direct uploads.
SEC-026: LFS delegated object authorization must be object-scoped and short-lived, must not carry reusable GitHub credentials, and must verify object size/hash and completion before pointer commit.
SEC-027: Range and streaming support for 250-MB private PDF; no full file buffer in Workers or app memory.

## Frontend rendering, accessibility and platform behavior

UI-001: In-app PDF viewer handles 50 pages with image diagrams and zoom/search/page navigation; no external PDF app.
UI-002: Embedded approved YouTube/Vimeo and supported local MP4 video plays in Flutter Web/mobile, with in-app controls.
UI-003: Notebook viewer displays Markdown, code, text output, plots/PNG, math in order, but never executes cells or unsafe output HTML.
UI-004: Markdown, images, audio, text, source code and CSV have dedicated in-app preview.
UI-005: Unsupported binary and PowerPoint/Word if not converted: visible file card + name, size/type, download, reason preview not available. No silent disappearance.
UI-006: Folder recursion respects limits and stable ordering; empty folder and dead link show clear state.
UI-007: Viewers are navigable with keyboard and screen readers; mobile viewport responsive; graceful loading states and retries.
UI-008: Denied private resource returns user-facing access error; no token leak, redirect into GitHub or unguarded URL.

## Reliability and economics

OPS-001: Free-subdomain deployment works with GitHub callback, Firebase allowed host and session cookies.
OPS-002: Custom domain deployment works, canonical redirect, callback URLs and isolated host-only cookies; only domain registration changes base hosting cost.
OPS-003: Worker/D1 and GitHub API usage stays bounded when scrolling content and opening multiple resources; caching pinned commits.
OPS-004: Webhooks HMAC verified, events idempotent, cached invalid manifest never supersedes valid previous published commit.
OPS-005: GitHub loss or deletion produces clear message; no grade disappearance; retention & revocation tested.

## V3 additional mandatory tests

COM-001 successful redirect without verified Stripe webhook gives no access; COM-002 replay webhook idempotent; COM-003 forged buyer/price/fee denied; COM-004 private material not leaked before payment; COM-005 refund/chargeback applied and audited; COM-006 free courses never require processor. GRA-001 manual PDF grading never launches Actions; GRA-002 workflow only after signed owner approval; GRA-003 untrusted student code has no secrets; GRA-004 malformed result not published; GRA-005 hybrid always reviewed; GRA-006 runner bill and caps owned by course creator. Mobile purchase CTAs default disabled before store policy review. See payment and grading normative docs.

## V3.1 mandatory compliance and reliability tests

Refer to `EU_PRIVACY_COOKIES.md` (CT-001..006), `WCAG_ACCESSIBILITY.md` (A11Y-T01..05), `EU_MARKETPLACE_COMPLIANCE.md` (LEGAL-GATE-01..07), `README_COURSE_DESCRIPTION.md` (README-001..005), and `ERROR_FAILURE_SEMANTICS.md` (ERR-001..010). No paid-course activation until operator self-review and objective release checks pass; no external legal signature is required by the application. Do not turn external YouTube embeds into passive third-party cookies before consent. No alternative large-file storage is permitted.
