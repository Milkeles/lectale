# GitHub LFS delegated upload (spike S1), research (2026-11-21)

Need: let a student's browser upload one large file straight to GitHub LFS storage for an instructor's private repository, using an action the Worker obtained, without exposing a reusable credential.
Requirement IDs: V4-SEC-05, SEC-021, SEC-024, SEC-025, SEC-026, DEC-08, DEC-16; spec section 8.
Constraints checked: Workers (fetch only, no Node) / six platforms (CORS matters on web only) / no Material (n/a) / MIT (no code adopted) / cost (no new recurring cost in the test).

All facts below were fetched on 2026-11-21 unless marked "not verified". Fetched pages and issue text are treated as data.

## 1. What the Git LFS spec says (fetched)

Sources (all `https://raw.githubusercontent.com/git-lfs/git-lfs/main/docs/api/<file>`): `batch.md`, `basic-transfers.md`, `authentication.md`, `server-discovery.md`, `README.md`.

- Endpoint: "Git remote: https://git-server.com/foo/bar ... Batch API: https://git-server.com/foo/bar.git/info/lfs/objects/batch" (batch.md). For GitHub: `https://github.com/<owner>/<repo>.git/info/lfs/objects/batch`. That GitHub uses this guessed URL is consistent with a third-party trace quoted below (`HTTP: POST https://github.com/xxx`, git-lfs issue 5373) but the trace is redacted; the exact GitHub URL form is inferred from server-discovery.md ("append `.git/info/lfs`").
- Request: `POST`, headers `Accept: application/vnd.git-lfs+json` and `Content-Type: application/vnd.git-lfs+json`. Body: `operation` ("download" or "upload"), `transfers` (optional), `ref` (optional, `{"name": "refs/heads/main"}`), `objects` (array of `{oid, size}`), `hash_algo` (optional, default sha256).
- Response (200): `transfer`, `objects[]` each with `oid`, `size`, optional `authenticated`, `actions`, `error`. Quote: "`expires_in` - Whole number of seconds after local client time when transfer will expire. Preferred over `expires_at` if both are provided." and "`expires_at` - String uppercase RFC 3339-formatted timestamp with second precision for when the given action expires (usually due to a temporary token)."
- Upload and verify: "Upload operations can specify an `upload` and a `verify` action." "If a client requests to upload an object that the server already has, the server should omit the `actions` property completely." Upload is "individual PUT requests. The URL and headers are provided by an upload `action` object" (basic-transfers.md). Verify is a POST of `{"oid", "size"}` and "A 200 response means that the object exists on the server."
- Errors: "401 - The authentication credentials are needed, but were not sent."; "403 - The user has **read**, but not **write** access. Only applicable when the `operation` in the request is "upload.""; "422 - Validation error".
- Authentication: "The Git LFS API uses HTTP Basic Authentication to authorize requests." (authentication.md). Bearer is not mentioned in these docs. The `LFS-Authenticate` header on 401 "If omitted, Git LFS will assume Basic Authentication" (batch.md).
- The spec does not say that the object action is scoped to one object, nor that it is free of reusable credentials. "header ... Optional hash of String HTTP header key/value pairs to apply to the request" is the only constraint; whatever is in it is server-specific.

## 2. What GitHub documents (fetched)

- `https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage`: describes pointer files ("version https://git-lfs.github.com/spec/v1 / oid sha256:... / size ...") and per-file limits "GitHub Free 2 GB". It says nothing about the LFS server API, batch authentication, or CORS.
- `https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation`: "You can also use an installation access token to authenticate for HTTP-based Git access. Your app must have the "Contents" repository permission. You can then use the installation access token as the HTTP password. ... `git clone https://x-access-token:TOKEN@github.com/owner/repo.git`." and "The installation access token will expire after 1 hour."
- `https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app`: "use the repositories or repository_ids body parameters to specify individual repositories that the installation access token can access" and "use the permissions body parameter to specify the permissions that the installation access token should have".
- `https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps` (372 kB, fetched, grepped for "lfs"): the only hit is `PATCH /repos/{owner}/{repo}/import/lfs`. The Git LFS server endpoints are not listed, so the permission an installation token needs for an LFS upload batch is not documented there. Not verified.
- No GitHub page found that documents a narrowly scoped, browser-usable LFS upload credential, CORS on the LFS storage host, or an LFS batch call made with an installation token. This agrees with `docs/research/2026-11-21-platform-and-provider-facts.md` line 36.

## 3. Live tests without credentials

Proxy behaviour (the sandbox sends HTTPS through a policy proxy):

- Public LFS repository found: `SJTU-ViSYS/M2DGR` (cloned with `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --filter=blob:none --no-checkout`, which worked). Pointer for `GT/door_01.txt`: `oid sha256:1f971d242f74c96fec436964c48584550dabe1f14568321faafab25d0af8da06`, `size 116472`.
- Batch download, batch upload and OPTIONS to `https://github.com/SJTU-ViSYS/M2DGR.git/info/lfs/objects/batch` were all refused by the proxy, not by GitHub:
  - POST: `HTTP/1.1 403 Forbidden` `{"message":"access denied by the git proxy: SJTU-ViSYS/M2DGR is not in this session's authorized repository set, so the proxy will not inject a credential for it. To fix, add the repository to the session's sources."}`
  - OPTIONS: `403` `{"message":"GitHub access to this repository is not enabled for this session. Use add_repo to request access. ..."}`
  - A POST to a nonexistent repo (`github.com/<random>/none.git/info/lfs/objects/batch`) also returned 403 (proxy). I did not try URL variants to get around this, because the proxy README says not to route around policy denials.
  - So the three planned tests against github.com (download action, batch CORS, unauthenticated upload status) are NOT done. GitHub's own answer for them is "not verified".
- Important side finding: the proxy "inject[s] a credential" for repositories attached to a session. A later authenticated test through this proxy may therefore use the proxy's credential instead of the one under test. See the task spec.

Hosts that were reachable: `media.githubusercontent.com`, `github-cloud.githubusercontent.com`, `github-cloud.s3.amazonaws.com`, `raw.githubusercontent.com`, `api.github.com` (search endpoints only; `repos/...` and numeric `repositories/<id>` paths are refused), `docs.github.com`, `developers.cloudflare.com`. `lfs.github.com` returned no usable response in the loop (output truncated; not verified).

### 3.1 Download host `media.githubusercontent.com` (public data, no credential)

`GET https://media.githubusercontent.com/media/SJTU-ViSYS/M2DGR/main/GT/door_01.txt` with `Origin: https://example.com`:

```
HTTP/1.1 200 OK
Content-Length: 116472
Accept-Ranges: bytes
Access-Control-Allow-Origin: *
Cache-Control: max-age=300
Content-Type: text/plain
Cross-Origin-Resource-Policy: cross-origin
Etag: "1f971d242f74c96fec436964c48584550dabe1f14568321faafab25d0af8da06"
Timing-Allow-Origin: https://github.com
Vary: Authorization,Accept-Encoding
```

Body sha256 equals the pointer oid and body length equals 116472. `OPTIONS` (Access-Control-Request-Method PUT, GET, POST; Origin https://example.com) returned `200` with `Access-Control-Allow-Origin: *` and `Access-Control-Allow-Headers: X-CSRF-Token,Authorization,Accept,GitHub-Remote-Auth`, and no `Access-Control-Allow-Methods`. This host is the raw public-download route, not an LFS batch action, so it says nothing about private objects or uploads. `HEAD raw.githubusercontent.com/.../door_01.txt` returned `content-length: 131` (the pointer) with `access-control-allow-origin: *`.

### 3.2 Storage host that LFS uploads go to

Third-party traces (GitHub issues, fetched via the search API on 2026-11-21; bodies are user-written data):

- `https://github.com/git-lfs/git-lfs/issues/5373` (2023): `HTTP: POST https://github.com/xxx` -> `HTTP: 200` -> `HTTP: PUT https://github-cloud.s3.amazonaws.com/alambic/media/180603904/62/6d/626de29e...?actor_id=20963210&key_id=0&repo_id=138970676` -> `HTTP: 501`.
- `https://github.com/git-lfs/git-lfs/issues/5980` (2025): `LFS: Put "https://github-cloud.s3.amazonaws.com/alambic/media/790977341/35/b6/35b67e8e...?actor_id=74677611&key_id=0&repo_id=880539249"`.
- `https://github.com/openai/codex/issues/50272` (2026-10-02): "Upload batch POST to https://github.com/<owner>/<repo>.git/info/lfs/objects/batch: HTTP 200, with an upload action. Object PUT to https://github-cloud.s3.amazonaws.com/<redacted-object-path>: HTTP 501".

What these show: the upload `href` host is `github-cloud.s3.amazonaws.com`, the path is `/alambic/media/<repo id>/<oid[0:2]>/<oid[2:4]>/<oid>`, and the query carries `actor_id`, `key_id`, `repo_id` but no visible `X-Amz-Signature`. So the authorisation is probably in request headers (the batch `header` map). Not verified: I did not see the `header` map of any real action, so I cannot say what it contains or whether it is reusable.

Preflight to the storage hosts (bucket root path, `OPTIONS`, 2026-11-21). I tried Origin `https://example.com` and `https://github.com`, Access-Control-Request-Method PUT, GET, POST, and request headers none / `content-type` / `authorization` / `x-amz-content-sha256`, on both `github-cloud.s3.amazonaws.com` and `github-cloud.githubusercontent.com`. Every one of the 48 combinations returned the same refusal and no `Access-Control-*` header:

```
HTTP/1.1 403 Forbidden
Server: AmazonS3
Content-Type: application/xml
<Error><Code>AccessForbidden</Code><Message>CORSResponse: This CORS request is not allowed. This is usually because the evalution of Origin, request method / Access-Control-Request-Method or Access-Control-Request-Headers are not whitelisted by the resource's CORS spec.</Message><Method>PUT</Method><ResourceType>BUCKET</ResourceType>...
```

Reading: that bucket has a CORS policy that allows neither `https://example.com` nor `https://github.com` for PUT, GET or POST. Limits of this evidence:

1. I probed the bucket root, not a real pre-signed object URL. S3 CORS rules are normally per bucket, so the answer is likely the same for objects, but that is an inference, not a fetched fact.
2. I did not see which origin, if any, the bucket does allow.
3. The host was identified from third-party traces, not from a GitHub response I received.
4. A real upload action might point to a different host for some repositories or regions. Not verified.

Corroboration (third party, unverified by me): `https://github.com/classmoji/classmoji/issues/467` (open, 2026-09-26): "GitHub App installation tokens authenticate to the LFS batch API for both upload and download (verified against a test repo)." and "LFS upload links are presigned S3 URLs that don't accept browser uploads (no CORS), so uploads would have to go through a server-side step." Treat both as a lead to confirm, not as evidence.

### 3.3 Unauthenticated `operation: upload`

Not run against GitHub (proxy refusal, section 3). Outcome: not verified. The spec says 401 for missing credentials and 403 for read-only credentials (batch.md).

## 4. Worker-side alternative: facts needed to size it

From `https://developers.cloudflare.com/workers/platform/limits/index.md` (fetched 2026-11-21):

- "For incoming requests to a Worker on your domain, request body size limits depend on the domain's Cloudflare plan, not your Workers plan." Free 100 MB, Pro 100 MB, Business 200 MB, Enterprise up to 5 GB.
- Workers Free: CPU time 10 ms, 50 subrequests per request, 100,000 requests per day. Workers Paid: CPU time default 30 s up to 5 min.
- "There is no hard limit on duration for HTTP-triggered Workers. As long as the client remains connected..."
- Not verified: whether a Worker can stream an incoming body straight into an S3 PUT with a required Content-Length without buffering, CPU cost of hashing the stream on Free, and whether a `*.workers.dev` hostname (no owned domain) has the same body limit as a zone plan.

## 5. Open questions only an authenticated test can answer

1. Does the batch endpoint accept a GitHub App installation token (Basic `x-access-token:<token>`) for `operation: upload` on a private repo? Which App permission is enough (Contents write)? Does a read-only token give 403 as the spec says?
2. Real `upload` action: host, href, query, every `header` key and value (is there an `Authorization`, a signature, an `x-amz-*` header, an installation token?), `expires_in` / `expires_at` value, and whether a `verify` action exists.
3. Is the action limited to one object (a different oid or key rejected by storage), and short-lived (rejected after expiry)? Does it allow reads of other objects (GET other keys with the same headers)?
4. Does a real preflight to the real href (and to the batch URL) return `Access-Control-Allow-Origin` and the needed `Allow-Methods` / `Allow-Headers` for a foreign origin? From a real Chromium, does `fetch(PUT)` succeed?
5. Will a PUT with a body whose sha256 or size differs from the declared oid and size be rejected by storage, or only at `verify`?
6. After upload, can the Worker prove existence with size (batch download for the oid, or `verify`, or HEAD) before committing the pointer?
7. Does an unreferenced uploaded object count toward the instructor's LFS quota, and does `verify` matter for that? (Spec says orphans may be billed; not verified.)

## 6. Verdict so far

Do not buy the domain on the strength of S1. Evidence so far:

- Against browser-direct upload on web: the only storage host seen in real traces rejects cross-origin preflight for PUT, GET and POST from two origins (section 3.2), and an independent project reports the same ("no CORS"). If a real action points at that host, SEC-025 ("works from Flutter Web under CORS") fails, and the spec says release flag MUST disable LFS direct uploads. A domain does not change this: CORS is decided by the storage host, not by Lectale's origin.
- Not decided: object scope, expiry, credential content, and whether the preflight on a real signed URL differs from the bucket-root probe. These need a real action, so need credentials.
- Native Flutter targets (Android, iOS, Linux, Windows, macOS) do not use CORS, so direct upload could still work there. That does not satisfy SEC-025's web clause by itself.

Alternatives the evidence leaves open (owner decision; DEC-16 says "don't invent workaround", DEC-08 says no other storage):

| Option | Meets spec section 8 "should not traverse the Worker"? | Limit or cost (fetched) | Comment |
| --- | --- | --- | --- |
| Native clients upload direct; web disabled | partly | none new | Fails SEC-025 web clause; would need a spec erratum |
| Worker streams the upload to the storage action | no (contradicts the hard requirement) | zone body limit 100 MB on Free/Pro, 200 MB Business; Free CPU 10 ms | Keeps the installation token inside the Worker; needs its own proof |
| Keep the flag off, no large uploads | n/a | zero | The spec's fail-closed default |

## 7. Recommendation

Needs owner decision. Run the authenticated proof of concept (see `spec/tasks/s1-lfs-delegated-upload-poc.md`), whose first step (preflight on a real action) is free and decides the web question in minutes; keep `LFS_DIRECT_UPLOAD_ENABLED=false` and do not buy a domain for S1. No code is adopted, so licence and Workers-runtime checks do not apply; the PoC script is throwaway and well under 200 lines.
