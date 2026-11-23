# Security review: GitHub App authentication for public previews (2026-11-23)

| | |
|---|---|
| **Change** | The Worker mints a GitHub App installation token and sends it on `api.github.com` preview reads (`spec/tasks/m2-github-app-auth.md`) |
| **Reviewers** | Claude `security-reviewer`; Codex (mode 1, read-only) |
| **Verdict** | Fix first. No path returns fresh content from a repository that is still private, but the token's scope breaks V4-SEC-04 |

## Findings

| # | Severity | Finding | Source | Resolution |
|---|---|---|---|---|
| 1 | High | The installation token isn't limited by `repository_ids`, so it can read every repository in the owner's installation, private ones included. Privacy depends on every path re-checking `private`. `spec/v4.0/docs/ARCHITECTURE.md` requires "installation tokens minted server-side with restricted `repository_ids` and `contents` permissions". | Claude, Codex | Scope the token to one public repository by ID, and check the exchange response's `repository_selection`, `repositories` and `permissions` |
| 2 | Medium | Timing oracle for the owner's private repositories (SEC-005). A private repository in the installation answers `course_not_found` after one authenticated 200; a missing one takes a token 404 plus an anonymous retry. | Claude, Codex | Closed by finding 1: with a scoped token, private and missing repositories both answer token 404, then anonymous 404. Add a route-level test that both cost the same calls |
| 3 | Medium | The anonymous retry lets anyone stall every preview (V4-CACHE-05). About 60 imports of missing names exhaust the shared anonymous budget, and the rate-limit 403 on the retry sets the global cooldown, which also blocks token reads. | Claude | The fallback gets its own cooldown; while it is throttled, the token's answer stands |
| 4 | Medium | Stale authorization: after a repository turns private, a cached public decision can still trigger authenticated reads, whose status (502, 503) differs from the expected 404. | Codex | Closed by finding 1, because a scoped token can't read the private repository |
| 5 | Medium | Missing tests: private and missing repositories answer alike with a token; the name fallback refuses a private repository with a token; the token never reaches the Cache API. | Claude | Add the three tests |
| 6 | Low | A 401 never clears the cached token, so a revoked token is reused for up to 55 minutes, doubling every call. | Claude | Drop the cached token on a 401 |
| 7 | Low | The workflow's key check accepts PKCS#1 keys, which the Worker refuses, so the check can pass while the Worker stays anonymous. It also reads a hard-coded account and stops before the token exchange. | Claude, Codex | Apply the Worker's PKCS#8 rule in the check, and run the same scoped exchange, then revoke the test token |
| 8 | Low | `expires_at` has no upper bound. | Claude | Cap `refreshAt` at now + 55 minutes |
| 9 | Low | On a cold isolate, N concurrent requests mint N tokens. | Claude | Accepted: Workers refuse to resolve I/O started by another request, so a shared promise isn't possible. The cost is a few extra exchanges per isolate start |
| 10 | Note | Previously public content stays served for up to about 120 s after the repository turns private (60 s visibility cache plus 60 s downstream `max-age`). | Codex (rated high), Claude (same as before) | Unchanged by this diff; accepted for cache class A, recorded here |

## Checked and fine

- README, outline, file, folder, head and compare reads made with the token re-check `private` by ID. The name fallback confirms the name before and after.
- Raw reads stay anonymous.
- Cache keys hold no token, and the token stays in isolate memory only.
- Neither the token nor the key is logged or returned: errors are swallowed, and `onError` logs only `error.name`.
- The host allowlist holds. The POST is locked to the `access_tokens` path, the exchange never follows a redirect, and repository redirects stay on the same origin.
- PEM parsing is strict, and `importKey` validates the DER. The token pattern blocks header injection.
- The anonymous retry fires only on 401, 403 and 404, never on rate limits.
- Workflow: manual trigger only, `permissions: {}`, secrets scoped to the `preview` environment, no `${{ }}` inside scripts, and `env -u` strips the secrets before wrangler runs.
- `/api/health` returns a constant `{status: "ok"}` and calls nothing upstream.

## Open

Whether an installation token reads public repositories outside its installation. Check this after the first deploy. If it does, remove the anonymous retry on 403 and 404 and keep it only for 401.

## Round 2 (same day)

Both reviewers re-checked the fix round. They agree findings 1, 2, 5, 6, 7 and 8 are closed and that no new critical or high issue appeared. The orchestrator then closed what remained:

| Item | Source | Resolution |
|---|---|---|
| While the anonymous retry was paused, other public courses answered a non-retryable `course_not_found`, cached for 30 s, or `repo_changed` with lost cache entries (finding 3, medium) | Claude, Codex | A paused retry now answers a retryable 429 whose budget is `fallback`. `PreviewSource` passes it through without opening the shared cooldown, and nothing caches it. A private and a missing repository still answer alike |
| A 401 during the pause answered a cached 502 (low) | Claude | Same 429 |
| After the scoped repository turned private, an authenticated read could still run before the visibility check, so an oversized listing answered 502 (finding 4, medium) | Codex | The scoped repository's visibility is confirmed before each token read, not after |
| The workflow reported the test token as revoked even when the revocation failed (low) | Codex | It reports revocation only on HTTP 204 |
| The token cache kept a second copy of the PEM in its key (low) | Codex | It keys on a SHA-256 digest of the PEM |
| The research note still described the health probe (low) | Claude | Updated |
| Open question: can a scoped token read public repositories outside its scope? | Claude | The deploy check prints the status of reading `octocat/Hello-World` with the scoped token. If it is 200, a follow-up removes the anonymous retry on 403 and 404 and keeps it for 401 |

## Round 3 (same day)

Claude's security-reviewer confirmed that findings 3 and 4 and both lows are closed. The 429 path can't tell a private repository from a missing one: both make the same calls and get the same status, code and `Retry-After`. Nothing caches it. One new low: `checkCover` turned a throttled read into a `cover_format` warning, which the pinned cache then kept for 300 s. Fixed: `checkCover` rethrows `rate_limited`. A route test fails without the fix and passes with it.

## Follow-up: the open question is settled

The first deploy's key check read `octocat/Hello-World` with the scoped token and got HTTP 200. A 403 or 404 on a token read is therefore final, and the anonymous retry for them is gone. Only a 401 falls back to an anonymous read, under the fallback cooldown and its retryable 429. A private and a missing repository now cost one identical call each. This also removes the anonymous-budget drain in finding 3 at its source.
