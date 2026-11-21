# GitHub public-repo access for the M2 preview, build vs buy (2026-11-21)

Need: read any public GitHub repo (ID, default branch, pinned SHA, files, PDF streaming) from one Cloudflare Worker with no author install.
Requirement IDs: not supplied in the task. Constraints: Workers runtime, zero recurring cost, no PATs in D1.
All facts fetched 2026-11-21 from docs.github.com. "Not verified" = not found in a fetched page.

## 1. Rate limits
Source: https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
- Unauthenticated: "The primary rate limit for unauthenticated requests is 60 requests per hour." Also: "associated with the originating IP address". Shared Cloudflare egress IPs make this unusable.
- Installation token: "use the installation's minimum rate limit of 5,000 requests per hour." Non-Enterprise Cloud installations "receive another 50 requests per hour for each repository" over 20 repos and "for each user" over 20 users; "cannot increase beyond 12,500 requests per hour". Enterprise Cloud org installation: 15,000.
- App JWT: the page and https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/rate-limits-for-github-apps state no JWT limit. Not verified. (The JWT is only needed to mint installation tokens.)
- Conditional requests: "Making a conditional request does not count against your primary rate limit if a 304 response is returned and the request was made while correctly authorized with an Authorization header." (https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api). So 304s are free only when authenticated.
- Secondary limits (rate-limits page): "No more than 100 concurrent requests"; "No more than 900 points per minute ... for REST API endpoints"; "No more than 90 seconds of CPU time per 60 seconds of real time"; most REST GET = 1 point; "Some REST API endpoints have a different point cost that is not shared publicly." Also "subject to change without notice". Best practice: "make requests serially instead of concurrently".
- Errors: 403 or 429; honour retry-after / x-ratelimit-reset.

## 2. Can an installation token read public repos where the App is not installed?
Not documented as such. Fetched pages say only:
- Get repository content, Get a repository, Get a commit, Git trees, Git blobs (each at docs.github.com/en/rest/...): "This endpoint works with ... GitHub App installation access tokens ... must have ... 'Contents' repository permissions (read)" (Get a repository: "Metadata"), then "This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested."
- https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation: "The installation access token cannot be granted access to repositories that the installation was not granted access to."
- Inference, not documented: the "public resources" line says permissions are not needed for public data, so a valid token should authenticate and bill to the installation. No fetched page says this explicitly. Needs a live test with the real App (not run here: no App credentials).
- Documented fallback for arbitrary public repos: unauthenticated (60/h per IP) is the only mode the docs name. OAuth app client id and secret: "can also use their client ID and client secret to fetch public data ... 5,000 requests per hour per OAuth app" (rate-limits page). This is a documented route for public data at 5,000/h with no user token, but it needs an OAuth app, not the GitHub App. Verify before relying on it.

## 3. Raw file delivery
- Contents API (https://docs.github.com/en/rest/repos/contents): "1 MB or smaller: All features". "Between 1-100 MB: Only the raw or object custom media types are supported ... content field will be an empty string". "Greater than 100 MB: This endpoint is not supported." "upper limit of 1,000 files for a directory". Media types: "application/vnd.github.raw+json: Returns the raw file contents for files and symlinks"; "application/vnd.github.object+json".
- Git Blobs (https://docs.github.com/en/rest/git/blobs): "This endpoint supports blobs up to 100 megabytes in size." Raw: "application/vnd.github.raw+json: Returns the raw blob data."
- Trees (https://docs.github.com/en/rest/git/trees): "The limit for the tree array is 100,000 entries with a maximum size of 7 MB when using the recursive parameter." "If truncated is true ... use the non-recursive method of fetching trees, and fetch one sub-tree at a time." tree_sha accepts "The SHA1 value or ref (branch or tag) name".
- raw.githubusercontent.com and codeload: no rate limit or terms found in any fetched page. Not verified. The only mention is a download_url field in sample JSON. Contents docs: "Download URLs expire and are meant to be used just once".
- Archives (https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives): "An archive of a commit ID will always have the same file contents"; archives are "generated on request, cached for a while, and then deleted".
- Range: no fetched page documents Range support for contents, blobs or raw. The only hit is an `accept-ranges: bytes` header in a sample response from an issues endpoint (getting-started page), which proves nothing for these endpoints. Not verified; test live.

## 4. URL to stable ID, default branch, head SHA
- GET /repos/{owner}/{repo} (https://docs.github.com/en/rest/repos/repos, "Get a repository") returns `id` and `default_branch` in its schema/example (e.g. "id": 1296269, "default_branch": "master"). Status list includes 301 "Moved permanently".
- IDs surviving rename/transfer: not verified. Docs only say redirects exist: rename: "all existing information ... is automatically redirected to the new name"; transfer: "All links to the previous repository location are automatically redirected". Redirects die if the name is reused ("If you create a new repository ... redirects ... will no longer work", transfers: "permanently deleted"). That is a reason to key on the numeric ID, but no page states the ID is unchanged. A sample link uses `https://api.github.com/repositories/1300192/issues`, suggesting an ID route; the docs section for it was not fetched.
- Head SHA: GET /repos/{o}/{r}/commits/{ref} (https://docs.github.com/en/rest/commits/commits) takes "a commit SHA, branch name (heads/BRANCH_NAME), or tag name". With `application/vnd.github.sha` it "Returns the commit's SHA-1 hash", and supplying a SHA as ETag allows a check. Whether `HEAD` works as ref: not verified. One call for ID plus head SHA: not verified (needs repo call, then commit call; GraphQL not fetched).
- Skip the commit call by passing the branch name as tree_sha, but then the SHA is not pinned. Use the commit JSON (has the tree SHA) once.

## 5. Terms
- ToS section H (https://docs.github.com/en/site-policy/github-terms/github-terms-of-service): "Abuse or excessively frequent requests to GitHub via the API may result in the temporary or permanent suspension of your Account's access to the API." "You may not share API tokens to exceed GitHub's rate limitations." Also: "subscription-based access ... for those Users who require high-throughput access or access that would result in resale of GitHub's Service."
- AUP 9 (https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies): "If we determine your bandwidth usage to be significantly excessive in relation to other users of similar features, we reserve the right to suspend your Account, throttle your file hosting, or otherwise limit your activity".
- ToS: "By setting your repositories to be viewed publicly, you agree to allow others to view and 'fork' your repositories". Nothing fetched on caching. Whether a preview proxy counts as "resale" or needs a licence for author content: not verified; owner decision.

## Recommendation: needs owner decision, then build ~150 lines
Use the platform GitHub App, minted per-Worker via JWT (private key as a Worker secret, not a PAT in D1), installation token cached in KV or a Durable Object for under 1 hour. Gate: run a live test that the token works on a public repo where the App is not installed. If it fails, fall back to the OAuth-app client credentials route, then unauthenticated.

Flow per first preview (serial, not concurrent):
1. GET /repos/{o}/{r} -> id, default_branch (1 call, store id keyed by name).
2. GET /repos/{id-or-o/r}/commits/{default_branch} -> sha and tree sha (1 call).
3. GET git/trees/{tree_sha}?recursive=1 (1 call; fall back to per-subtree if truncated).
4. GET contents of course.yaml and README.md with raw media type at ref=sha (2 calls); or blobs by SHA from the tree (immutable, cacheable forever).
Total: 5 calls first preview. Files and PDFs then go through blobs/contents raw with Cache API.

Repeat preview within TTL: 0 calls (Cache API on the SHA-keyed tree and files, class B). After TTL: 1 conditional GET of /commits/{branch} with If-None-Match, a 304, which is free when authenticated, so 0 budget if unchanged; 4 calls if the head moved (commit, tree, 2 files).

Caching rules: key everything by repo ID + SHA (immutable); only the branch-head lookup is mutable (TTL 60 s, ETag revalidate). Blob SHAs make identical files shared across commits. Budget: 5,000/h at 5 calls is about 1,000 distinct first previews per hour, ignoring the 100 MB/Range questions.

Open: Range on PDFs. Without verified Range support, fetch the blob once, store it in R2 or Cache and serve Range from the Worker. Check Worker memory (blob up to 100 MB) before choosing; stream rather than buffer.

## Live tests (2026-11-21, against Milkeles/lectale, public)

Run with curl from the agent sandbox. That sandbox's GitHub traffic passes a proxy that adds credentials (`X-Ratelimit-Remaining: 14993` on a REST call), so none of this says anything about unauthenticated limits.

| Test | Result |
|---|---|
| `raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>` with `Range: bytes=0-99` on a 1,238,567-byte PDF | **206**, `accept-ranges: bytes`, `content-range: bytes 0-99/1238567`, `cache-control: max-age=300`, strong `etag` |
| Contents API with `Accept: application/vnd.github.raw+json` and the same `Range` | **200**, full `Content-Length: 1238567`: Range is ignored |
| `GET /repos/{owner}/{repo}/commits/HEAD` | Works; returns the default branch head SHA |
| `GET /repos/{owner}/{repo}` | Returns numeric `id`, `default_branch`, `private` |
| `GET /repositories/{id}` | 403 from this sandbox; possibly the session proxy's scope, not GitHub. Unverified. |

Consequence for M2: stream file bytes (and Range requests) from `raw.githubusercontent.com` at the pinned SHA, and use the REST API only for metadata (repository, commit, tree). Whether raw responses count against an authenticated limit or have their own terms is still unverified.
