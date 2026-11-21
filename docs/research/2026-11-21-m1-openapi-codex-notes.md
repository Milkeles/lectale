# M1 corrected OpenAPI contract

The [OpenAPI 3.1 fork](../../spec/errata/openapi.yaml) retains all 46 upstream
operations, including the managed content operation with its new scoped path.
Health and the two preview reads bring the total to 49. The contract declares
path parameters, unique operation IDs, per-operation security, and milestone
tags on deferred operations. It uses one `ApiError` envelope and one UUID
`Idempotency-Key` header definition. Checkout returns 201 and grading dispatch
returns 202. These changes cover the contract checks for V4-CORE-01 and V4-SEC-09.

Import accepts a canonical HTTPS GitHub repository URL and returns a numeric
`repoId`, pinned `sha`, the validated manifest by schema reference, README
presence, and resource addresses. ADR-0008 leaves the preview suffix and
assignment scope open. The fork uses separate `/readme` and
`/content/{lessonId}/{resourceId}` paths under the pinned preview prefix.
Assignment scopes use `assignment~<assignmentId>` to avoid collisions with
lesson IDs. URL-only resources have a null `href` and retain their links in the
manifest. Pinned reads use Class B caching and the repository lookup uses
Class D.

Import is read-only. GitHub and Stripe deliveries use verified provider
signatures and delivery or event IDs for deduplication. The authenticated
course offer and managed manifest routes follow the task's public route list.
The bundle describes public reads for these routes, a difference for M9 and
M4 respectively. Error codes stay strings to match the Worker, whose error
producer currently uses the required fields and supports optional retry timing.
The accepted E7 envelope also allows structured `details`.

## Verification

- `python3 tool/test_openapi_contract.py` passed all 7 tests.
- `python3 -m unittest discover -s tool -p 'test_*.py'` passed all 18 tests.
- All four bundled `spec/v4.0/tools/test_*.py` scripts passed.
- The project rule check passed for the changed files.
- The CI contract job and `just test-spec` both invoke the new test. The local
  environment lacks `just`, so both recipe commands ran directly.
