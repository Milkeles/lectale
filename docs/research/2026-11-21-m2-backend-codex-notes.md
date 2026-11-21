# M2 anonymous preview backend

The Worker implements `POST /api/courses/import` and the pinned README and scoped content routes. Import validates the root `course.yaml` under the 1 MiB limit and returns the generated `CoursePreview` DTO with README presence. Both GET routes require a public repository resolved by ID. Lesson resources and assignment materials resolve through the validated manifest and must be regular Git blobs at the requested SHA. [Task spec](../../spec/tasks/m2-anonymous-preview-api.md) · [OpenAPI contract](../../spec/errata/openapi.yaml)

## Trust boundaries

- At the API boundary, private and missing repositories use the same `course_not_found` response. Validator diagnostics stay in the generated error envelope, and GitHub throttles return `429` with a retry delay (V4-SEC-09).
- At the GitHub boundary, the adapter uses REST for metadata and raw delivery for pinned bytes and byte ranges. The transport allows only the two GitHub HTTPS hosts, bounds time and redirects, and constructs its own outbound headers. The optional server token goes only to REST, and the default provider returns no token (V4-SEC-03). [GitHub access research](2026-11-21-github-public-access.md)
- At the browser boundary, MIME types come from the extension allowlist. Active and unknown formats download as octet-stream. File responses use `nosniff` and a sandbox CSP. A single byte range is forwarded, and an upstream 416 keeps its range information in a no-store error response.
- At the cache boundary, the class D name-to-head entry lasts 60 seconds, and a warm import makes zero GitHub calls. Class B entries use a stable ID and full SHA for validated outlines, plus file path and renderer version for bytes. Each GET reaching the Worker checks live visibility before using those entries. Complete file responses up to 4 MiB with matching size headers are eligible for edge storage. Ranged and larger responses stream directly. The public file TTL is 300 seconds (V4-CACHE-01, V4-CACHE-02, V4-CACHE-05). [Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/)

Truncated Git trees return a bounded failure. The content routes serve regular-file bytes, so directory listing is outside this slice. The sandbox blocked live GitHub access, so production behavior of `GET /repositories/{id}` remains unverified. The anonymous visibility, content handling, and outbound HTTP changes require security review before merge.

## Verification

| Check | Result |
| --- | --- |
| `npm run typecheck` | Passed after seeding matching generated workerd declarations so Wrangler could reuse them without opening a socket. |
| `npx vitest run` | The Worker pool could not start because binding `127.0.0.1` returned `EPERM`. With a temporary Node config and a shim for the health-test entrypoint, 6 files and 220 tests passed. |
| `python3 tool/check_rules.py` with an explicit repository file list | Exit 0, no output. Explicit paths avoid the default Git-based file enumeration. |
| `python3 tool/test_openapi_contract.py` | 8 tests passed. |

## Follow-up to both reviews of 353467a

The preview routes now include reload, repository-relative files, and direct folder listings. Import writes a class B pin for each successfully validated repository and SHA. Preview GETs accept that pin or compare the supplied SHA against a fresh snapshot of the default-branch tip, with the tip as the comparison base. Positive comparisons and import pins last 300 seconds in the Cache API. An unpinned SHA needs a new comparison after its cached verdict expires. A fresh name-scoped read is checked against the same repository ID and canonical name before its result can be used or cached. [GitHub compare documentation](https://docs.github.com/en/rest/commits/commits#compare-two-commits)

**Visibility revocation window.** The class D public verdict lasts 60 seconds for both ID and name lookups. A successful file response adds at most 60 seconds of downstream freshness and requires revalidation after expiry. A repository made private immediately after a visibility lookup can therefore remain available for up to about 120 seconds through a conforming downstream cache. Import responses are `no-store`, so their window is 60 seconds. The Worker keeps complete, verified file bytes internally for 300 seconds and checks visibility before accessing them. [Cloudflare Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/)

Imports use 20 requests per minute per client IP. Preview reads use a separate limit of 180 per minute. The shared GitHub cooldown uses the Cache API within a Cloudflare data center, with an in-isolate fallback if cache storage fails. Deployments can supply the optional `GITHUB_PUBLIC_READ_TOKEN` Worker secret for REST. The default is anonymous and raw requests carry no credentials. [Workers Rate Limiting](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/), [GitHub REST rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)

The pinned root contents listing checks README and manifest presence in one lookup. Raw file misses avoid a directory lookup. Successful raw reads use bounded pinned parent metadata to verify regular file type and size. GitHub Contents documents a 1,000-entry limit per directory. An entry omitted by that cap cannot be verified for byte delivery. Folder resources return direct entries up to `maxEntries` and preserve the repo-relative path in each href. [GitHub repository contents documentation](https://docs.github.com/en/rest/repos/contents#get-repository-content)

### Finding to fix and verification

| Review finding | Fix | Test or verification |
| --- | --- | --- |
| Claude H1, caller-selected fork or orphan SHA | Require a matching import pin or a comparison with a fresh default tip. Accept only `behind` and `identical`. Cache a negative verdict for 30 seconds. | Bound-link tests exercise fork-network raw lookup, unpinned force-pushed commits, imported pins, ancestors, and comparison expiry. REST tests check direction and all four statuses. |
| Codex High, namespace swap poisons repo ID cache | Reconfirm the name, ID and public visibility after each fresh name-scoped operation. Discard mismatched reads and serve retryable `503`. | Route tests replace the old name with a second repo during head and raw reads, assert absence of poisoned cache entries, and retry against the new name. |
| Claude M1 and Codex Medium, shared GitHub rate budget | Use raw for bytes. Cache visibility, directory metadata, branch heads and comparisons. Coalesce cold metadata and complete file fills. Add per-IP admission and a shared cooldown. | Parallel cold imports, parallel cold and warm README requests, client-IP admission, cooldown across app instances, and adapter 403/429 translation tests. |
| Claude M2 and Codex Medium, unbounded metadata and validation work | Cap REST response bytes before decoding JSON, request a SHA-only head and paginated compare summary, and remove recursive trees. Cache failures for at most 30 seconds and use small resource index shards. Keep N7's validator limits. | Oversized metadata cancellation, streamed manifest cap, repeated invalid manifest and raw 404 tests. The existing local benchmark measured 13 ms median CPU at 200 resources, 131 ms at 2,000 and 598 ms at 10,000. Production CPU remains a deployment measurement under N7. |
| Claude M3, missing security regression tests | Reuse the manifest path grammar, reject raw redirects and malformed ranges, constrain media by policy, and normalize denials. | Route and adapter tests cover encoded traversal, hidden paths, backslashes, empty segments, links and submodules, raw redirects, malformed ranges, active file extensions, MIME mismatches, 404 headers and exclusion of provider credentials. |
| Codex Medium, Range bypasses cache and trusts upstream interval | Serve ranges from complete cached files, verify the interval and total against the pinned size, and enforce transfer length. | Tests cover native and fallback cache slicing, multipart, overlong, reversed, out-of-bounds and unsafe-integer ranges, mismatched `206`, ignored Range and oversized streamed bodies. |
| Claude L1 and Codex Medium, warm import and downstream visibility | Recheck the class D name mapping and by-ID visibility after 60 seconds. Import answers `no-store` and public file freshness is 60 seconds. | Clock-driven tests verify cached visibility, name replacement, denial at expiry and the combined downstream freshness bound. Live browser-cache behavior was unavailable in this sandbox. |
| Claude L2, same-host raw redirect | Refuse all raw redirects and allow only REST name-lookup redirects to the repository-by-ID operation. | Transport tests reject raw-to-raw repository redirects, unexpected REST path changes, and redirect chains. |
| Claude L3 and Codex Low, sandbox-only CSP and extension-based media | File responses carry `default-src 'none'; sandbox; frame-ancestors 'none'` and `nosniff`. Verify raster signatures before inline delivery and download mismatches. | File and range route tests check headers and binary responses. MIME tests cover valid PNG, mislabeled PNG, SVG, HTML variants, JS and notebooks. Browser PDF sandbox behavior remains unverified. |
| Claude L4, `.well-known` exception | Share the existing manifest grammar at both boundaries. The v3 semantic rules allow explicitly allowlisted hidden paths. | Adapter and route traversal tests exercise denied hidden paths. [Semantic validation rules](../../spec/v4.0/docs/SEMANTIC_VALIDATION.md) |
| Claude L4, unspecified import caching | Send `Cache-Control: no-store` on import success and document it in OpenAPI. | Import response and OpenAPI contract checks. |
| Claude L4, timeout covers streamed bodies | Keep the 30-second fetch deadline for bounded upstream work. | Transport tests check the abort signal. Live slow-stream behavior remains unverified. |
| Claude L4, empty repository yields retryable 502 | Map GitHub's empty-repository `409` to the neutral unavailable response. | Adapter test covers the empty repository status. |
| Codex Low, 404 timing equivalence is unproven | Use one bounded body-read path for provider `403` and `404`, then return the same envelope. | Adapter and route tests compare status, body excluding request ID, headers and call counts. Live GitHub latency equivalence remains unverified. |

Worker regression tests are in [routes.test.ts](../../apps/edge_api/test/preview/routes.test.ts), [rest-reader.test.ts](../../apps/edge_api/test/preview/rest-reader.test.ts), and [fetch.test.ts](../../apps/edge_api/test/preview/fetch.test.ts). The Dart client includes `Dio.openPreviewFile` for nested paths and streaming ranges, since the generated method encodes path segments and selects a single success response. [Dart client tests](../../packages/api_client/test/preview_files_test.dart)

### Follow-up verification

| Check | Result |
| --- | --- |
| TypeScript generation and Worker typecheck | Passed. |
| Worker test suite | 287 passed in Node. The workerd pool could not bind to `127.0.0.1` in the sandbox and returned `EPERM`. |
| OpenAPI contract | 8 passed. |
| Project rule check | Exit 0 with no output using explicit repository paths to avoid Git-based enumeration. |
| Dart regeneration and formatting | Passed with the pinned generator in a temporary offline Dart project, using the repository's generator configuration. |
| Dart client analysis and tests | Analysis passed. Four tests passed in the pure-Dart runner with the same fixtures and assertions. |
