---
name: contract-first-api
description: Contract-first workflow for Lectale's API and manifest schemas. Use when editing schemas/*.json, the corrected OpenAPI at spec/errata/openapi.yaml, error envelopes, idempotency, pagination, generated TypeScript or Dart clients, swagger_parser, openapi-typescript, semantic-validation fixtures, or the CI drift check.
---

# Contract-first API

The contract is the source of truth. Handlers and clients are generated or checked against it, never the other way round. This keeps the Worker, the Flutter client and the tests from drifting apart, and lets a reviewer judge an API change by reading one diff.

## Which file is the contract

- Manifest grammar: `schemas/*.json` (JSON Schema Draft 2020-12). `course-v3.schema.json` is the only manifest dialect; there is no v4 YAML.
- HTTP API: `spec/errata/openapi.yaml` (created in M1 as a corrected fork).
- Do not edit `spec/v4.0/api/openapi.yaml`. It is the frozen upstream bundle with known defects (missing path parameters, global auth on public routes). Fix problems in the errata fork and record why in an errata ADR.
- If the schema and prose disagree, the schema wins.

## OpenAPI rules

- Public routes (anonymous preview, public offers, legal documents, public catalog) set `security: []` on the operation. A global `security` block would force auth onto them.
- Every `{param}` in a path is declared under `parameters` with `in: path` and `required: true`. Generators fail or emit wrong code otherwise.
- Resource IDs are unique per containing list, so routes use a composite address (`{lessonId}/{resourceId}`), not a bare resource ID.
- Every error response uses one envelope, `ApiError`:
  `code, message, requestId, retryable, retryAfterSeconds?, details?`
  `code` is a stable enum; `message` is safe to show; no secrets or stack traces.
- Mutating operations (`POST`, `PUT`, `PATCH`, `DELETE`) accept an `Idempotency-Key` header (UUID). Replay within 24 hours returns the first result. It is a header, not a body field.
- Use `201` for create, `202` for accepted async work, `200` otherwise. Say which per operation.
- Lists use keyset pagination: `limit` (max 100) and an opaque `cursor`; the response carries `nextCursor`. No offsets, because rows shift under offset paging.
- Status meanings: 400 invalid input, 401 unauthenticated, 403 not allowed, 404 not found or hidden, 409 conflict, 413 too large, 422 malformed manifest, 429 throttled, 502 provider failure.
- Private resources answer 404, not 403, to non-members so existence is not revealed.
- Request bodies are described for every mutation. Add `additionalProperties: false` unless a field is deliberately open.

## Codegen

```bash
# Worker types (openapi-typescript, MIT)
npx openapi-typescript spec/errata/openapi.yaml -o apps/edge_api/src/generated/api.d.ts

# Dart client (swagger_parser, dio)
dart run swagger_parser -f contracts/swagger_parser.yaml
```

- `contracts/swagger_parser.yaml` follows `/home/user/devchat-frontend/contracts/swagger_parser.yaml`: `http_client: dio`, `serializer: plain`, `body_positional: true`, one entry under `inputs:` per API with `schema_path` and `output_directory`.
- Generated files are committed and never hand-edited. To change them, change the contract and regenerate.
- Run `just generate` (or the two commands above) after every contract edit.
- CI drift check: regenerate both outputs, then `git diff --exit-code`. A diff means someone edited generated code or forgot to regenerate.
- Lint the OpenAPI in CI. openapi-typescript validates the schema with Redocly while it generates, so a broken contract fails codegen.
- devchat-frontend's justfile also runs `dart run swagger_parser --check -f contracts/swagger_parser.yaml` in its check recipe; reuse it.

## Fixtures

Every semantic rule in `spec/v4.0/docs/SEMANTIC_VALIDATION.md` gets two fixtures: one that passes and one that fails, named after the rule (`yaml-alias.invalid.yaml`, `yaml-alias.valid.yaml`). A rule with only a passing fixture proves nothing, because a validator that accepts everything also passes.

- Rules that JSON Schema cannot express (unique IDs, path canonicalisation, chronology, `maxAttemptBytes >= maxFileBytes`) are checked by the TypeScript validator, not the schema.
- Failing fixtures assert the exact error `code`, not just "rejected".
- Attack fixtures to include: duplicate keys, aliases, custom tags, input over 1 MiB, `../` and `%2e%2e` paths, backslashes, non-HTTPS URLs, unlisted video hosts.

## Keep the bundled tests green

```bash
for t in spec/v4.0/tools/test_*.py; do python3 -I "$t" || exit 1; done
python3 spec/v4.0/tools/validate_course.py spec/v4.0/examples/complete.course.yaml
```

These pass on the unmodified bundle. If a change to the errata fork needs a test updated, say so in the commit and do not weaken an assertion to make it pass.

## Done when

Contract diff reviewed; codegen regenerated with an empty drift diff; new rules have passing and failing fixtures; Python tests pass; the traceability row for the requirement ID is updated.

Sources: spec/v4.0/docs/API_SEMANTICS.md, SEMANTIC_VALIDATION.md and AGENTS.md; plan section 1.1 (E1, E2, E7); openapi-typescript CLI docs (raw.githubusercontent.com/openapi-ts/openapi-typescript/main/docs/cli.md, fetched 2026-11-21; openapi-ts.dev itself was unreachable); /home/user/devchat-frontend/contracts/swagger_parser.yaml and justfile. The swagger_parser flags (`-f`, `--check`) come from devchat-frontend's justfile, not from a fetched package README.
