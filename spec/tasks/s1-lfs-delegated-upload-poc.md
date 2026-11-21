# S1 LFS delegated-upload proof of concept

| Intake | Decision |
| --- | --- |
| Why | Decide whether students can upload large files straight to GitHub LFS from every client, as spec section 8 requires: V4-SEC-05, SEC-021, SEC-024, SEC-025, SEC-026, DEC-08, DEC-16. The owner buys a domain only if this passes. |
| Simpler | One throwaway script (under 200 lines, not shipped) and one static HTML page for the browser check. Not building: any Worker route, D1 table, Flutter screen or pointer-commit code. The flag `LFS_DIRECT_UPLOAD_ENABLED` stays false. |
| Ready-made | Difficulty S, about 150 LOC of throwaway script. Uses plain `fetch`, `git-lfs` CLI for cross-checks and Playwright (CLI and `google-chrome` are present in the sandbox; not run yet). No new dependency in the repo. Research: `docs/research/2026-11-21-lfs-delegated-upload.md`. |
| Security | Touches the GitHub installation token and a student browser (trust boundary: the token must never leave the Worker). Uses a throwaway private repo and a 1-hour token; every request and result is logged with tokens redacted. Security review required before any result is turned into code. |
| Verify | Section "Pass and fail" below: one recorded outcome per SEC item, saved to `docs/research/<date>-lfs-poc-results.md`. Closes V4-SEC-05 only when all rows pass. |

## Early finding that shapes the order of work

Without credentials, the storage host seen in real LFS traces (`github-cloud.s3.amazonaws.com`) refuses cross-origin preflight for PUT, GET and POST from two origins (note, section 3.2). Step 3 therefore comes first and is free: if the real upload href gives no `Access-Control-Allow-Origin`, SEC-025 fails for web and the later steps only matter for the native-only or Worker-streaming options.

## Phase 1: the web question, with one repository (orchestrator's addition)

The cloud session's git proxy adds the session's own GitHub credential to requests for repositories attached to the session. That credential belongs to a GitHub App, so a batch upload through the proxy returns a real upload action without the owner creating an App or tokens. Phase 1 uses it to run, in order:

1. Step 0, inverted. With no credential of our own, a batch upload on the attached repository should succeed, because the proxy signs it. Record that the action came from the session's App credential, not Lectale's.
2. Steps 2, 3 and 7: the real action, the preflight on its real href, and a Chromium PUT from a foreign origin. This decides SEC-025's web clause.
3. The parts of step 5 that only need the action: the credential-content search, expiry, swapped-oid and other-path PUTs, and the body-size mismatch.

Owner prerequisite for phase 1: one empty private repository, `lectale-lfs-poc`, created on GitHub with a README so it has a `main` branch, which the orchestrator then attaches to the session. The test objects are a few MiB, inside the free LFS allowance.

Phase 2 runs only if phase 1 passes: Lectale's own GitHub App, the read-only token test (403), the cross-repository read test and the quota check, using the prerequisites below. Tokens for phase 2 are not passed as plain environment variables, because those are readable by everyone using the environment. The orchestrator settles how to hand them over (a network secret, or the owner running the script) before phase 2 starts.

## Owner prerequisites

The owner does these; the agent never creates repositories, tokens or accounts.

1. A throwaway private repository on the owner's GitHub account, for example `lectale-lfs-poc`, with one commit and a `.gitattributes` line `*.bin filter=lfs diff=lfs merge=lfs -text`. A second throwaway private repo `lectale-lfs-poc-other` with one small LFS object already pushed (for the cross-repo and read-other-object tests).
2. A GitHub App (free) with only: Repository permissions, Contents: read and write; Metadata: read. Installed on the two throwaway repositories only. Nothing else.
3. Two installation tokens, each minted for 1 hour using the `repositories` and `permissions` body parameters (documented in the research note, section 2):
   - T-RW: repository `lectale-lfs-poc` only, `contents: write`.
   - T-RO: same repository, `contents: read`.
   Hand-over is decided before phase 2 (see Phase 1): never in a file, chat message, commit or log. Mint them just before the run; they expire after 1 hour.
4. Network, decided by the owner. Option A, run in this sandbox: attach both repos to the session (the proxy refused all github.com LFS paths for unattached repositories) and allow the hosts `github.com`, `api.github.com`, `github-cloud.s3.amazonaws.com`, `github-cloud.githubusercontent.com`, `media.githubusercontent.com`. Risk: the proxy "inject[s] a credential" for attached repos, which can hide which credential is really in use. Step 0 below checks for this. Option B (cleaner): the owner runs the script on their own machine, or in GitHub Actions in the throwaway repo, and pastes the redacted results back. Choose one.
5. Permission to run a local web server on two ports (two origins) and launch Chromium for step 7.
6. Fine-grained personal access token variant (optional): single repo, Contents read and write, 1-day expiry, to learn whether it also works. Skip if not wanted.
7. Confirmation that no money is spent: the test objects total under 10 MiB, well inside the Free 10 GiB LFS allowance. Delete the repos afterwards (owner action).

## Steps

0. Credential honesty check (Option A only). Call batch upload on `lectale-lfs-poc` with a deliberately invalid token. Expected: 401. If it succeeds, the proxy substituted its own credential: stop and use Option B.
1. Object preparation: create a 1 MiB random file `a.bin`, compute sha256 and size; prepare `b.bin` (different content, 1 MiB) and `big.bin` of 2 MiB.
2. Batch with T-RW: `POST https://github.com/<owner>/lectale-lfs-poc.git/info/lfs/objects/batch`, Basic auth `x-access-token:<T-RW>`, headers `Accept` and `Content-Type: application/vnd.git-lfs+json`, body `{"operation":"upload","transfers":["basic"],"ref":{"name":"refs/heads/main"},"objects":[{"oid":"<a.bin sha256>","size":1048576}],"hash_algo":"sha256"}`. Record status, `transfer`, `expires_in` / `expires_at`, the `upload` and `verify` actions (href host and path, every header NAME, and for each value: class only, such as "AWS4 signature" or "Basic ...", never the value). Also run with T-RO (expect 403 per spec) and with no Authorization header (expect 401) and with Bearer T-RW.
3. CORS on the real action (decides the web question): send `OPTIONS <upload href>` with `Origin: http://localhost:8001`, `Access-Control-Request-Method: PUT`, `Access-Control-Request-Headers` set to the lower-cased header names from the action plus `content-type`. Repeat for the `verify` href and for the batch URL. Record all `Access-Control-*` headers.
4. Upload `a.bin` with `curl -X PUT` using exactly the action's href and headers (no installation token anywhere). Expect 200. Then POST the verify action if present. Then batch `download` for the oid and GET the download action; compare size and sha256.
5. Scope negative tests, using the `a.bin` upload action:
   - SEC-024: PUT `b.bin` bytes to the href after swapping in the oid of `b.bin` in the path; PUT `a.bin` to another path in the same bucket; GET the object key of the pre-existing object in `lectale-lfs-poc-other`; GET `a.bin`'s key with the upload headers. Each must fail.
   - Reuse and body mismatch (SEC-021): PUT 2 MiB bytes where the action declared 1 MiB; PUT 1 MiB of different bytes to a.bin's href. Record whether storage rejects, or only `verify` does.
   - Expiry (SEC-026): wait past `expires_in` (or `expires_at`), PUT again; must fail. If the lifetime is over 1 hour, record it and mark "not short-lived".
   - Credential content (SEC-025, SEC-026): search the full action JSON for the installation token string, `x-access-token`, `ghs_`, and for any header that also works on `api.github.com` (call `GET https://api.github.com/user` or `/repos/<owner>/lectale-lfs-poc` with each header value; expect 401).
6. Pointer path and completeness (SEC-026): with T-RW over `api.github.com`, create the pointer file through the contents API only after `verify` and batch download confirm size and oid; record whether a pointer for an object that was never uploaded is accepted by GitHub (expected: yes, which is why the Worker must verify first).
7. Real browser: serve a static page on `http://localhost:8001` and the control script on `http://localhost:8002`; the page receives only the action JSON from the script (never the token), runs `fetch(href, {method:"PUT", headers, body})` and logs the result. Run in Chromium with Playwright, headless and headed if possible. Expect: either success or a CORS failure (`TypeError: Failed to fetch` plus a console message naming CORS). Save the console log and the network log. Repeat with the action's headers split into "simple" and "non-simple" cases if the preflight in step 3 passed.
8. Quota check: owner reads the LFS storage figure in GitHub billing before and after steps 4 and 5 to see whether unverified or rejected uploads count (spec says orphans may be billed). Owner action.
9. Write results to `docs/research/<date>-lfs-poc-results.md` with redacted raw excerpts; update `PLAN.md`. Owner deletes tokens and repos.

## Pass and fail

| ID | Pass | Fail |
| --- | --- | --- |
| V4-SEC-05 | Every row below passes with real GitHub responses | Any row fails or is not run: flag stays off |
| SEC-025 object-limited | Step 5 swap, other-path and cross-repo tests all rejected | Any other object writable or readable with the action |
| SEC-025 no installation token | Step 5 string search finds no token; no action header works on `api.github.com` | Token, or any reusable credential, appears in href or headers |
| SEC-025 CORS from web | Step 3 returns an allowing `Access-Control-Allow-Origin` and methods/headers for a foreign origin and step 7 PUT succeeds in Chromium | Step 3 has no `Access-Control-*` or step 7 fails with a CORS error (early evidence points here) |
| SEC-024 | Action cannot read any existing private object, other repo or other file, and cannot change anything else | Any read or write outside the one object |
| SEC-026 object-scoped | As SEC-025 object-limited | As above |
| SEC-026 short-lived | Expiry at most 1 hour (compare the 1-hour installation token) and PUT after expiry is refused | Lifetime over 1 hour, missing expiry, or accepted after expiry |
| SEC-026 verify size/hash before pointer | Storage or `verify` rejects wrong size or digest, or Worker-side batch download plus hash comparison proves it | Wrong-size or wrong-digest bytes end up accepted and not detectable |
| SEC-021 | Mismatched size, oid or expired action is rejected | Accepted silently |

If CORS fails but all other rows pass, report "native only possible, web not": per spec that is a fail of SEC-025 and the flag stays off. Alternatives then belong to the owner (research note, section 6).

## Not verified before this task

Everything that needs a real batch response from GitHub: authentication scheme accepted, App permission needed, action headers, expiry, verify action, real-href CORS. See the research note, section 5.
