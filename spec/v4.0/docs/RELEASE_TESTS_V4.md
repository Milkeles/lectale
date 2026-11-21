# Release acceptance cases — V4

## Product core
V4-CORE-01 public repository URL preview opens valid course.yaml + root README with no login, does not mutate GitHub.
V4-CORE-02 no catalog registration is ever required for a public source-link preview; no Github org required for managed course.
V4-CORE-03 verified author uses selected-repo GitHub App to register, safe scaffold, repin and update an existing course.
V4-CORE-04 missing/invalid YAML reports exact error, old published course remains pinned.
V4-CORE-05 web & native display in-app PDF, embedded video, Markdown/LaTeX, static notebook, audio, images, code/text, folders; unsupported binary receives download fallback.
V4-CORE-06 real-name certificate snapshots and independent verification link; enrollment/profile edits cannot silently change issued certificates.
V4-CORE-07 paid/priv access denied without valid enrollment/entitlement, including media URLs, API, READMEs, download ranges and previews.

## Catalog
V4-CAT-01 catalog discovery optional; managed course starts unlisted.
V4-CAT-02 owner lists/unlists, chooses public teaser; private README/grades and student names never leak.
V4-CAT-03 indexed bounded query with q/language/category/price and keyset pagination, max 50. 1M records query must be benchmarked for scanned rows and latency.
V4-CAT-04 no external search paid service, crawler, cron indexing or required per-card GitHub API calls.
V4-CAT-05 catalog outage doesn't block source link to GitHub; when core Worker unavailable, explicit network error rather than blank page.

## Cache
V4-CACHE-01 immutable public commits and public catalog cache hit; no auth dependence. Document actual Worker requests, CPU savings and D1 rows.
V4-CACHE-02 personalized, enrollment, grades, private files, Stripe, session and LFS authorizations `no-store` and never in edge cache.
V4-CACHE-03 revoke paid entitlement -> immediate private access denial even if catalog is stale.
V4-CACHE-04 no catchall Pages Function makes static asset traffic dynamically billed.
V4-CACHE-05 public cache SHA keys and webhook invalidation tested; miss and 304 never trigger an unbounded GitHub loop.

## Security and resilience
V4-SEC-01 Firebase token claims, issuer, audience, expiry verified; no special trust granted by client supplied roles/course policy.
V4-SEC-02 web `__Host-` HttpOnly Secure SameSite=Lax opaque session; session rotated and revoked; CSRF origin and token checks for mutations; native bearer.
V4-SEC-03 XSS in README/Markdown/notebook HTML cannot run; URL path traversal, external fetch SSRF, embedded trackers and script injections blocked.
V4-SEC-04 GitHub App tokens restricted, never delivered to clients, never logged; GitHub webhooks HMAC verified.
V4-SEC-05 LFS direct-to-GitHub file transfer disabled until scope+CORS+verification+token safety proved with real test repo. False result must leave upload feature disabled.
V4-SEC-06 one student cannot read or overwrite another student's files/grade even when same private repository holds all attempts.
V4-SEC-07 paid checkout uses genuine signed Stripe webhook, idempotent purchases/refunds, no redirect-as-payment-proof.
V4-SEC-08 automatic grader runs untrusted code only on instructor Github Actions runner with no platform/payment secret; results verified and bounded before grade changes.
V4-SEC-09 error responses include stable code, retryable flag, requestId and safe explanation; idempotency under retries and upload/checkout duplicate events.
V4-SEC-10 Terms, privacy, cookie settings, self-review notices, content reporting/delisting and WCAG 2.2 AA checks pass.

## Performance & costs
V4-COST-01 free 1000/10000/50000 MAU modeled with explicit 40 vs 50 req and daily peak; 100k/1M paid model includes cached Worker request billing.
V4-COST-02 D1 index-backed public catalog and `rows_read` metrics; over-limit handling and budget alerts.
V4-COST-03 no custom domain works; custom domain works with same-origin `/api`, Firebase Authorized Domain, GitHub OAuth callback, cookie/logout and CORS test.
V4-COST-04 public PDF loads from GitHub where possible; private streaming and Range works without saving entire file to Worker memory; current provider limitations surfaced to user.
V4-COST-05 reader and instructor shown GitHub LFS plan-dependent quotas/cost responsibility and expected worst-case upload storage.
V4-COST-06 no tracking or provider-paid service auto-enabled during initial production release.

## Deliverability
A feature is DONE only when it has unit + integration tests, accessible UX including error/empty/loading states, documented security proof for protected operations, and no unverified claims. Agents should produce a trace matrix linking requirements to tests and source commits.
