# Traceability matrix

Links each V4 release acceptance case to the milestone that closes it, the
tests that prove it, and its status. The cases come from
`spec/v4.0/docs/RELEASE_TESTS_V4.md` (33 cases). The spec's definition of done
requires "a trace matrix linking requirements to tests and source commits"
(`spec/v4.0/docs/RELEASE_TESTS_V4.md`, "Deliverability").

Milestones are from the delivery plan (§7). A milestone marked "inferred" is
not named in the plan and needs the owner's confirmation. The other test
families (SEC, UI, A11Y, CACHE, ERR and so on) are indexed in
[`spec/INDEX.md`](../spec/INDEX.md). Add their rows here when a milestone
claims them.

Statuses: `not started`, `in progress`, `passing`, `blocked`, `dropped`. When a
case passes, fill the test column with the test file and add the commit SHA.

| ID | Requirement (short) | Milestone | Test(s) | Status |
| --- | --- | --- | --- | --- |
| V4-CORE-01 | Public repo URL preview shows course.yaml and README, no login, no GitHub writes | M2 | - | not started |
| V4-CORE-02 | Preview needs no catalog registration or GitHub org | M2 | - | not started |
| V4-CORE-03 | Verified author registers, scaffolds, repins and updates via selected-repo App | M4 | - | not started |
| V4-CORE-04 | Invalid or missing YAML gives exact error; old course stays pinned | M4 | - | not started |
| V4-CORE-05 | Web and native show PDF, video, Markdown/LaTeX, notebook, audio, images, code, folders; binary falls back to download | M2b | - | not started |
| V4-CORE-06 | Certificate snapshots and verification link; edits cannot change issued certificates | M7 | - | not started |
| V4-CORE-07 | Paid or private content denied without enrollment or entitlement, media and ranges included | M4 | - | not started |
| V4-CAT-01 | Catalog optional; managed course starts unlisted | M10 | - | not started |
| V4-CAT-02 | Owner lists or unlists; private README, grades, student names never leak | M10 | - | not started |
| V4-CAT-03 | Indexed catalog query, keyset pagination, max 50; 1M-row benchmark | M10 | - | not started |
| V4-CAT-04 | No paid search, crawler, cron indexing or per-card GitHub calls | M10 | - | not started |
| V4-CAT-05 | Catalog outage does not block source link; core outage shows network error | M10 | - | not started |
| V4-CACHE-01 | Immutable public commits and catalog hit cache; measure requests, CPU, D1 rows | M2 | - | not started |
| V4-CACHE-02 | Personal, private, Stripe, session and LFS responses are no-store, never edge cached | M2 | - | not started |
| V4-CACHE-03 | Revoked paid entitlement denies private access at once, even with stale catalog | M9 (inferred) | - | not started |
| V4-CACHE-04 | No catch-all function bills static traffic as dynamic | M2 | - | not started |
| V4-CACHE-05 | SHA cache keys and webhook invalidation work; miss and 304 never loop on GitHub | M4 (inferred) | - | not started |
| V4-SEC-01 | Firebase token claims verified; client roles never trusted | M3 | - | not started |
| V4-SEC-02 | `__Host-` session cookie, rotation, revocation, CSRF; native Bearer | M3 | - | not started |
| V4-SEC-03 | XSS, traversal, SSRF, trackers and script injection blocked (preview part in M2) | M2 | - | not started |
| V4-SEC-04 | GitHub App tokens restricted, never sent to clients or logged; webhooks HMAC-verified | M4 | - | not started |
| V4-SEC-05 | LFS direct upload stays disabled until proven with a real test repository | M6 | - | not started |
| V4-SEC-06 | One student cannot read or overwrite another's files or grade | M5 | - | not started |
| V4-SEC-07 | Checkout uses signed Stripe webhook; idempotent purchases and refunds | M9 | - | not started |
| V4-SEC-08 | Auto-grader runs untrusted code only on instructor runner with no platform secrets | M8 | - | not started |
| V4-SEC-09 | Errors carry code, retryable, requestId; retries and duplicates are idempotent | M6 | - | not started |
| V4-SEC-10 | Terms, privacy, cookie settings, notices, reporting, WCAG 2.2 AA checks pass | M7 | - | not started |
| V4-COST-01 | Cost modeled at 1k, 10k, 50k MAU free and 100k, 1M paid | M11 | - | not started |
| V4-COST-02 | Index-backed catalog, `rows_read` metrics, over-limit handling, budget alerts | M11 | - | not started |
| V4-COST-03 | Works without a custom domain and with one (same-origin `/api`, Firebase, callbacks, cookies) | M11 | - | not started |
| V4-COST-04 | Public PDF loads from GitHub; private streaming with Range avoids Worker memory | M11 | - | not started |
| V4-COST-05 | Readers and instructors see LFS quota and cost responsibility | M11 | - | not started |
| V4-COST-06 | No tracking or provider-paid service auto-enabled at first release | M11 | - | not started |

## Notes

- M1 (contract) and the spikes S1 to S3 carry no V4 case alone. M1 delivers the
  validator and fixtures that M2 and later cases depend on. S1 decides whether
  M6 runs at all.
- V4-COST-06 holds from the first release (M2 onward), not only at M11. The
  plan lists V4-COST-* under M11 for the final check.
- V4-SEC-09 constrains every error response from M1 on. The plan closes it at
  M6; erratum E7 fixes the envelope earlier.
- If M6 is dropped because the S1 spike fails, V4-SEC-05 passes by keeping the
  upload feature off, and V4-SEC-09 is closed in M7.
