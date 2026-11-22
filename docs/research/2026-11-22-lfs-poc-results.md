# Spike S1, phase 1: Git LFS delegated upload, results (2026-11-22)

Test plan: `spec/tasks/s1-lfs-delegated-upload-poc.md`. Earlier research: `docs/research/2026-11-21-lfs-delegated-upload.md`.

## Setup

- **Repository:** the throwaway private repository `Milkeles/lectale-lfs-test`, created by the owner. The orchestrator added a one-line README so it has a `main` branch.
- **Credential:** the cloud session's git proxy signed the requests to `github.com` with the session's own GitHub App credential (phase 1 design). No Lectale credential existed or was used.
- **Test data:** two 1 MiB random files, `a.bin` and `b.bin`.
- **Logs:** request and response excerpts below are redacted: signatures, keys and tokens are cut to a prefix and a length.

## What GitHub returned

`POST https://github.com/Milkeles/lectale-lfs-test.git/info/lfs/objects/batch`, `operation: upload`, one object (oid of `a.bin`, size 1048576): HTTP 200.

| Action | Host and path | Headers | Expiry |
|---|---|---|---|
| `upload` | `https://github-cloud.s3.amazonaws.com/alambic/media/<repo id>/<oid[0:2]>/<oid[2:4]>/<oid>`, with query keys `actor_id`, `key_id`, `repo_id` | `Authorization: AWS4-HMAC-SHA256 …` (209 chars; `SignedHeaders=host;x-amz-content-sha256;x-amz-date`; credential scope `<key>/20261122/us-east-1/s3/aws4_request`), `x-amz-content-sha256: <oid>`, `x-amz-date` | `expires_in: 900` (15 minutes) |
| `verify` | `https://lfs.github.com/Milkeles/lectale-lfs-test/objects/<oid>/verify` (path prefix shown) | `Authorization: RemoteAuth …` (134 chars), `Accept` | none given |

## Results

| # | Test | Expected | Result |
|---|---|---|---|
| CORS | Browser preflight (`OPTIONS`, `Access-Control-Request-Method: PUT`, headers `authorization, content-type, x-amz-content-sha256, x-amz-date`) to the real upload link, from `http://localhost:8001`, `https://lectale.fervorgames.workers.dev` and `https://github.com` | `Access-Control-Allow-Origin` for a foreign origin | **Fail.** HTTP 403 for all three origins, with no `Access-Control-*` headers: `<Code>AccessForbidden</Code> CORSResponse: This CORS request is not allowed.` |
| 1 | `PUT a.bin` with only the action's headers | 200 | **Pass.** 200 |
| 2 | `PUT b.bin` (different bytes) to `a.bin`'s link | refused | **Pass.** 400 `XAmzContentSHA256Mismatch` |
| 3 | `PUT a.bin` to another object path with the same headers | refused | **Pass.** 403 `SignatureDoesNotMatch` |
| 4 | `GET` the object with the upload headers | refused | **Pass.** 403 `SignatureDoesNotMatch` |
| 5 | `verify` with the right size | 200 | **Pass.** 200 |
| 5b | `verify` claiming a wrong size (999) | refused | **Fail.** 200: verify does not check the size |
| 6 | Download via the batch API and compare SHA-256 | equal | **Pass.** Equal. Before verify, the download batch answered `404 Object does not exist on the server`. |
| 7 | GitHub token (`gh?_…`) anywhere in the upload action | none | **Pass.** None. The only GitHub credential is the `RemoteAuth` token in the `verify` action. |
| 8 | `PUT` again after `expires_at` | refused | Pending; see below |

## What this means

1. **Direct upload from the web app is impossible.** The storage host refuses the CORS preflight for every origin, including `github.com`. The upload must send `Authorization`, so the browser can't skip the preflight. A domain or any other change on Lectale's side can't fix this: the bucket's CORS policy decides. Under SEC-025 the web clause fails, and the spec says `LFS_DIRECT_UPLOAD_ENABLED` stays `false`.
2. **For native apps the upload action itself is well scoped:**
   - it is limited to one object, by path and content hash (tests 2 and 3);
   - it can't read (test 4);
   - it carries no GitHub token (test 7);
   - it is short-lived (15 minutes; reuse after expiry is still pending, test 8);
   - the content is bound to the declared hash, because S3 checks `x-amz-content-sha256`.

   The `verify` action carries a GitHub `RemoteAuth` token, so it must stay on the server.
3. **Size is not enforced before the bytes land.** The signature doesn't cover `Content-Length`, and `verify` accepted a wrong size (test 5b). A client can ask for a small slot and upload a file of any size up to GitHub's per-file limit, as long as its hash matches the oid it declared. Lectale can only see the real size afterwards (from the download action's `Content-Length`). By then the bytes already count against the instructor's LFS storage, and GitHub doesn't let a single LFS object be deleted.

   SEC-021 (reject a size mismatch) can be enforced before the pointer commit. SEC-022 (byte caps and storage cap enforced on the server) can't be enforced for direct uploads. This is a quota-abuse risk for instructors.

## Options for the owner

| Option | Web | Native | Size and quota enforced before storage | Cost and limits | Spec change |
|---|---|---|---|---|---|
| A. Keep LFS uploads off | none | none | n/a | none | none (the spec's fail-closed default) |
| B. Native apps upload directly; web has no uploads | no | yes | **no** (risk in point 3) | none | erratum: SEC-025's web clause, and the abuse risk accepted |
| C. Uploads pass through the Worker, which counts bytes and streams the body to the upload action | yes | yes | **yes**: the Worker stops at the cap, and S3 still checks the hash | Cloudflare request body limit 100 MB on Free and Pro (ledger); CPU on Workers Free not yet measured | erratum: the spec's "uploads don't traverse the Worker" |

Phase 2 would prove option C with a deployed test Worker: stream a body to the upload action with a byte cap, and measure CPU time.
