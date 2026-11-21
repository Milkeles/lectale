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
