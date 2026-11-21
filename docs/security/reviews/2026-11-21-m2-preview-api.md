# Security review: M2 anonymous preview API (commit 353467a)

Reviewer: security-reviewer agent, 2026-11-21. Method: read-only (Read, Grep, Glob, `git show`), using the `lectale-threat-checklist` skill. Tests were not run. Scope: `apps/edge_api/src/{net,github,preview}`, `src/index.ts`, and `test/preview/*`.

Verdict: **do not merge until H1 is fixed.** I found no critical issues.

## Findings

### [HIGH] H1. The client-chosen SHA is not bound to the repository, so another repository's commit can be served under this repository's ID   spec ID: V4-SEC-03, SEC-020 (threat model 5.2), ADR-0008, CACHE-005

Where: `apps/edge_api/src/preview/routes.ts:118-133`, `apps/edge_api/src/preview/pinned.ts:67,93`, `apps/edge_api/src/github/rest-reader.ts:110,131`

The route checks the SHA's format and the repository's live visibility. It then reads `git/trees/{sha}` and `raw…/{owner}/{name}/{sha}/…` for whatever SHA the client sends. GitHub resolves any object in a fork network through the upstream path (the public "impostor commit" / cross-fork object reference behaviour). It also resolves commits that were force-pushed away.

Exploit sketch:
1. The attacker forks `uni/course` (repoId V) and pushes commit C to the fork, with their own `course.yaml`, `README.md` and a phishing PDF. They can delete the fork afterwards.
2. The attacker shares `/api/preview/V/C/readme` or `/api/preview/V/C/content/…`.
3. The Worker sees that V is public, validates the attacker's manifest, and caches `public-course-outline:v1:V:C` and `public-course:v1:V:C:…`. It then serves the attacker's bytes as repository V with `public, max-age=300`.

Fix: on an outline-cache miss, accept only a SHA that is reachable from the default branch. One way is `GET /repos/{o}/{r}/compare/{sha}...{defaultBranch}` with a bounded read, accepting only `identical` or `ahead`. Another is a durable record of the SHAs that import pinned. Cache the verdict together with the outline.

Test to add: give the fake reader two repositories in one network. Requesting the upstream ID with the fork-only SHA must return 404 and must not write to the cache. The current fake ignores owner and name (`test/preview/fake-github-reader.ts:43-60`), so it cannot model this attack.

### [MEDIUM] M1. Every file request and every Range request makes an uncached GitHub call, and the default reader is unauthenticated   spec ID: V4-CACHE-05, CACHE-007, OPS-003, CACHING class D ("rate-limited")

Where: `routes.ts:125`, `index.ts:13`, `rest-reader.ts:77`

Exploit sketch: about 60 anonymous GETs to any preview file use up the unauthenticated limit of 60 requests per hour for the shared Cloudflare egress IP. After that, every visitor gets 429 for up to an hour. Normal use does the same thing: a PDF viewer that sends 30 Range requests uses half the hour's budget. No rate limit exists. The Cloudflare docs say Cache API calls do nothing on `workers.dev` (not tested here), so the free-subdomain deployment (OPS-001) gets no caching at all.

Fix: cache the visibility verdict per repoId for at most 60 s (class D). Use the App or OAuth credentials that the research note recommends. Add a Workers rate-limit binding on `/api/courses/import` and `/api/preview/*`.

Test to add: N requests within the TTL must call `resolveRepositoryById` exactly once.

### [MEDIUM] M2. Upstream reads are unbounded, failures are not negatively cached, and the CPU cost on the 10 ms budget was not measured   spec ID: V4-CACHE-05, OPS-003, threat model 5.3, CACHING class D (negative lookup ≤ 30 s)

Where:
- `rest-reader.ts:84` calls `response.json()` with no byte cap. This applies to the recursive tree (up to 7 MB and 100,000 entries, parsed before `truncated` is checked) and to `commits/HEAD` at line 102 (the full commit, including file patches).
- `routes.ts:129` parses the whole cached outline on every file GET.
- `pinned.ts:106` validates YAML on every miss.

Exploit sketch:
- The attacker repeatedly imports a public repository with a huge tree or head commit. Each request fetches and parses megabytes, then fails with 502 or 422 and caches nothing.
- The attacker iterates `/preview/{id}/{sha_i}/readme` over the many commits of a repository with a 1 MiB manifest. That forces one YAML and AJV validation per SHA.

The CPU cost was not measured, so the effect on the 10 ms budget is unverified.

Fix: use `readBoundedBody` on all REST JSON. For the head commit, use `Accept: application/vnd.github.sha`. Negatively cache failures for at most 30 s. Store one small index entry per address so that a file GET does not parse the whole outline.

Test to add: an oversized tree body is cancelled, and a repeated invalid manifest causes only one upstream fetch per 30 s.

### [MEDIUM] M3. Several security properties have no test that exercises the attack   spec ID: SEC-014, SEC-020, V4-SEC-03, V4-SEC-04, ADR-0008 Confirmation

Where: `test/preview/*`

Missing tests:
- A foreign-SHA test (see H1).
- Tests for the `openFile` path guard (`rest-reader.ts:127-129`) with `..`, `%2e%2e`, `.git/config`, `a//b` and backslash. ADR-0008 asks for a traversal path. Only `part%2Fname` in the resource ID is tested.
- Tests for multiple ranges, over-long ranges and malformed `Range` (`file.ts:23,56`). The route tests mock the port instead.
- MIME tests for SVG, JS, `.htm`, `.xhtml` and `.ipynb`. Only `.html` and an unknown extension are tested.
- A comparison of headers between the private and missing cases, and a case for the warm-import window.
- A raw-to-raw redirect to another repository path.
- A check that no response contains `ghs_` or `Bearer`.

### [LOW] L1. A repository that goes private stays visible for a bounded time   spec ID: V4-CACHE-02, CACHING classes B and D

Where: `routes.ts:94-97`, `file.ts:84`

A warm import returns the outline with no GitHub call for up to 60 s. File bytes carry `public, max-age=300, immutable`, so browsers and shared proxies can keep them for 300 s. The Worker's own file route checks visibility live before reading its cache.

This is within the spec, but no test proves the bound. Fix: document the window and add a test.

### [LOW] L2. Same-host redirects are followed to any path   spec ID: SESSION_SECURITY "SSRF", V4-SEC-03

Where: `net/fetch.ts:42-47`

A raw redirect can switch the owner, repository or SHA in the path, and the bytes are still served under the original repoId. Only GitHub controls the `Location` header.

Fix: refuse redirects on raw, or require the path prefix `/{owner}/{name}/{sha}/`.

### [LOW] L3. Untrusted bytes are rendered inline on the app origin   spec ID: SEC-014, threat model 5.1 and 5.4

Where: `file.ts:25-30`, `wrangler.jsonc:1-3`

PDFs, images, Markdown and text render inline on the same host as the Flutter app and the future `__Host-` session cookie. Only CSP `sandbox` protects them. How browsers' PDF viewers behave under `sandbox` is unverified. The threat model plans "risky previews on a separate origin".

Fix: use `sandbox; default-src 'none'; frame-ancestors 'none'`. Before M3 sessions ship, use a cookieless content origin or send `Content-Disposition: attachment` when `Sec-Fetch-Dest: document`.

### [LOW] L4. Hygiene

- The `.well-known` exception (`rest-reader.ts:128`, `course-manifest-semantics.ts:95`) departs from the SEC-020 rule against dotfiles. The owner should approve it.
- The import 200 response has no explicit `Cache-Control` (`routes.ts:97,113`).
- The 30-second timeout also aborts streamed bodies (`fetch.ts:33`). This is functional, unverified, and affects SEC-027.
- An empty repository (409) is reported as a retryable 502 (`rest-reader.ts:64`).

## Checked and sound

- **Outbound allowlist:** HTTPS only, exact hostnames, no userinfo or port. Every redirect is re-checked, cross-host redirects are refused, and at most 3 are followed. Headers are constructed by the Worker, and client Cookie and Authorization are never forwarded. All of this is tested.
- **Import URL parsing:** the regex is anchored and allows no query, fragment, port or percent-encoding. `.git` is stripped, `.` and `..` are rejected, the body is capped at 4 KiB, and the JSON must have exactly one key. This is tested.
- **Served paths:** a served path always comes from the validated manifest and must be a regular blob (mode 100644 or 100755) in the pinned tree. The schema path pattern blocks `..`, `%` and backslash, and the adapter checks again. Symlinks and submodules are excluded. Client IDs are used only for lookups.
- **SHA and repoId formats:** the SHA must be 40 lowercase hex characters, at both the route and the adapter. The repoId must be a safe integer with no leading zeros.
- **Cache keys:** each key is repoId + SHA + safe path + renderer version, with no token, session or UID. The key families cannot collide.
- **Visibility on file routes:** checked live by ID before any cache read, and this is tested. Visibility `internal` counts as private. Raw reads are unauthenticated, so private bytes cannot be fetched.
- **Errors:** private, missing and unsafe targets all get the same `course_not_found` 404 with the same headers and one upstream call each. Upstream text is never echoed, and logs record only the error name.
- **Content types:** text/html is never served inline. HTML, SVG, CSS and unknown types are sent as octet-stream attachments with a safe filename. JS, JSON and ipynb are sent as text/plain. Every file response has `nosniff` and `sandbox`, and upstream `Set-Cookie` is dropped.
- **Range:** a single range of at most 128 characters is allowed, the upstream `Content-Range` is validated, 416 responses are `no-store`, and ranged responses are never cached.
- **Caching:** errors are `no-store`. Only data verified as public is stored. A file is cached only when complete, at most 4 MiB, with no `Content-Encoding`, and matching its tree size.
- **Manifest size:** the 1 MiB cap is enforced while streaming, and this is tested.
- **Prompt injection:** I found none in the files I reviewed.

**Not built yet:** rate limiting, negative caching, an authenticated GitHub token, and a separate content origin.

**Could not verify:**
- How GitHub resolves fork-network SHAs through `git/trees` and raw. This review relies on public research, not a live test.
- `GET /repositories/{id}` against live GitHub.
- CPU timings.
- How browsers' PDF viewers behave under CSP `sandbox`.
- Whether the Cache API really does nothing on `workers.dev`.

## Fix verification (d766458)

Reviewer: security-reviewer agent, 2026-11-21. Method: read-only (`git show`, Read, Grep). Tests were not run. Paths are relative to `apps/edge_api/`.

### Verdicts on earlier findings

| Finding | Verdict | Evidence or what remains |
|---|---|---|
| Claude H1, fork or force-pushed SHA | **closed** (live GitHub unverified) | The import pin or a compare against a fresh default tip is checked before any read (`src/preview/routes.ts:115-125`, `src/preview/source.ts:111-124`). Only `behind` and `identical` are accepted (`src/github/rest-reader.ts:129-139`). The fake now shares objects across a fork network (`test/preview/fake-github-reader.ts:85-90`). Tests: `test/preview/routes.test.ts:436-450` (fork SHA, all five routes, nothing cached), `:452-474` (force push, verdict expiry, fresh tip), `test/preview/rest-reader.test.ts:57-67` (compare direction). Residual: a pin or a positive verdict outlives a force push by up to 300 s, which is accepted. The fake's `isReachable` ignores `defaultHead`. |
| Codex High, rename race | **closed** | `namedRead` checks every name-scoped head, compare, listing and raw read against the cached by-ID record, then re-resolves the name and discards a mismatch (`src/preview/source.ts:45-83`). `repo_changed` is never negatively cached (`src/preview/cache.ts:126`). Tests: `test/preview/routes.test.ts:279-311` and `:476-488`. Gap: no swap test during compare or listing, which use the same helper. |
| Claude M1 and Codex Medium, GitHub rate budget | **partly closed** | Visibility is cached for 60 s and lookups are coalesced. There is a shared cooldown and limiters of 20/min for import and 180/min for preview (`wrangler.jsonc`). Remains: `confirmName` makes an **uncached** REST call after every raw read and directory listing (`src/preview/source.ts:47,77`). A raw miss costs one more call per path every 30 s. Ranges on files over 4 MiB cost one call each. One IP at 180/min therefore spends the anonymous 60/h budget in under a minute, or a 5,000/h token in about 30 minutes. The cooldown (`:34-39`) then answers 429 to every user. The preview limiter has no test. Cache API on `workers.dev` is still unverified. |
| Claude M2, unbounded reads | **closed** (CPU part below) | REST bodies are capped at 128 KiB and listings at 2 MiB. Head uses `vnd.github.sha`, there is no recursive tree, failures are negatively cached for 30 s, and the resource index is sharded. Tests: `test/preview/rest-reader.test.ts:80-92`, `test/preview/routes.test.ts:179-219` and `:511-522`. |
| Codex Medium, cold-preview CPU | **partly closed** | Bounds and caching are added, but validation still takes 131 ms at 2,000 resources and 598 ms at 10,000, against a 10 ms Free budget. An attacker can walk the commits of their own repository and pay one validation per SHA. This waits on the owner's N7 decision. |
| Claude M3, missing attack tests | **closed** | There are now tests for traversal, encoded and hidden paths (`test/preview/routes.test.ts:502-509`, `test/preview/rest-reader.test.ts:69-78`), multipart and malformed ranges (`test/preview/routes.test.ts:573-597`), hostile MIME (`:551-567`), identical 404 headers (`:330-350`), raw redirects (`test/preview/fetch.test.ts:56-64`) and `ghs_`/`Bearer` (`test/preview/rest-reader.test.ts:113`). |
| Codex Medium, warm import visibility | **closed** (bounded) | Import is cached for 60 s and returns `no-store`. Files carry `max-age=60, must-revalidate` (`src/preview/cache.ts:34`). Tests: `test/preview/routes.test.ts:270-289` and `:330-350`. A real browser cache is unverified. |
| Codex Medium, Range | **closed** | The interval and total are checked against the size from the pinned listing, and ranges are served from the cache (`src/preview/file.ts:119-202`, `src/preview/range.ts`). Tests: `test/preview/routes.test.ts:570-656`. |

### `/files/{path}` confinement

The route takes the raw suffix of the URL, refuses `%2f` and `%5c`, decodes once, and checks `isSafeRepoPath` (`src/preview/routes.ts:62-75`). That check allows only `[A-Za-z0-9_.-]` segments, with no empty, dot-terminated or hidden segment other than `.well-known` (`src/contract/repo-path.ts:1-7`). The adapter checks again (`src/github/rest-reader.ts:165`), raw redirects are refused (`src/net/fetch.ts:38-40`), and the file must appear as `type: file` in the pinned parent listing (`src/preview/file.ts:157-172`). I found no way to reach anything outside the repository at that SHA.

### New issues

**[MEDIUM] N1. `/files/*` serves any blob of any public repository, with or without a valid course**   spec ID: V4-SEC-03 (task gate: "allow only validated regular files")
- Where: `src/preview/routes.ts:143-147`. `authorize` never loads the outline, and `test/preview/routes.test.ts:492` asserts "serves files outside the manifest".
- Exploit: take any public repository ID and a default-branch SHA, then link `/api/preview/{id}/{sha}/files/payload.exe`. The Lectale origin becomes a free proxy for arbitrary GitHub content. Malware served from it can get the app domain listed by Safe Browsing, and the route amplifies the M1 budget drain.
- Fix: call the cached `coursePreview(source, repository, sha)` before serving, or limit the route to README-referenced and cover paths.
- Test: a repository with no `course.yaml` returns 404 and never calls `openFile`.

**[LOW] N2. The optional REST token can see private repositories**
- Where: `src/preview/routes.ts:94`.
- Reads are discarded after the post-read check, but timing can reveal whether a private repository exists. This is unverified.
- Fix: use a fine-grained token limited to public repositories, and record that in the runbook.

L3 (no separate content origin) is still open and must be fixed before M3 sessions ship.

**Merge:** nothing at high or critical is open. Merging is acceptable; fix N1 and the per-read `confirmName` cost before any public deployment.
