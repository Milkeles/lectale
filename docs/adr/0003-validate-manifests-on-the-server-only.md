---
status: accepted
date: 2026-11-21
---

# Validate course manifests on the server only

## Context and problem statement

The spec requires safe parsing, JSON Schema validation and a long list of
semantic rules for `course.yaml`
(`spec/v4.0/FULL_SPECIFICATION.md` §4 "Validation precedence and errors";
`spec/v4.0/docs/SEMANTIC_VALIDATION.md`). A reference implementation exists
in Python (`spec/v4.0/tools/validate_course.py`). Lectale needs the rules in
TypeScript on Workers. The Flutter client could validate too, but that means
a second validator in Dart.

Workers block `eval` and `new Function`. Ajv generates validators at runtime
with them, so it does not run on Workers. `@cfworker/json-schema` states
support for Draft 2020-12, which the schemas use. The `yaml` package
(eemeli, ISC) parses YAML 1.2 and can reject aliases, merge keys and custom
tags. All facts were fetched on 2026-11-21.

## Decision drivers

- SEC-014 and V4-SEC-03: untrusted manifests and READMEs must not run code.
- One implementation of each rule, so the two sides cannot disagree.
- Low code to maintain.

## Considered options

- Server-only validation in TypeScript; the client consumes validated DTOs.
- Validate on both sides, with a Dart validator in `course_contract`.
- Validate on the client only.

## Decision outcome

Chosen option: "server-only validation". The Worker uses `yaml` plus
`@cfworker/json-schema` for structure and its own code for the semantic rules
(about 600 lines, ported from `validate_course.py`). The client never parses
`course.yaml`. It reads typed DTOs generated from the OpenAPI document. This
saves about 1.5k lines of Dart and keeps one source of truth.

The server's result is the only trusted one: the spec says the manifest is
content, never authorization (`SEMANTIC_VALIDATION.md`, "Course YAML is
content, not authentication"). Client checks would add nothing the server
does not repeat.

### Consequences

- Good, because there is one validator to test and one place to fix bugs.
- Good, because the client carries no YAML parser or schema engine.
- Bad, because the client cannot preview a manifest offline or before upload.
- Bad, because the port from Python can drift. Every rule needs a passing
  and a failing fixture, and the Python tests
  (`spec/v4.0/tools/test_v4_contract.py`) stay in CI as a cross-check.

### Confirmation

- M1 exit: every rule in `SEMANTIC_VALIDATION.md` has a passing and a failing
  fixture, including attack fixtures (traversal, aliases, oversize, provider
  mismatch, duplicate IDs).
- CI runs the bundled Python contract tests next to the TypeScript tests.
- `tool/check_rules` fails on `eval` and `new Function` in the Worker.

## More information

Revisit if an offline authoring tool is added. Related: erratum E1 (OpenAPI
is the contract the DTOs come from) and E4 (the schema is the authority on
`schemaVersion`).
