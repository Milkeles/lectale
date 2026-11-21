# M1 course manifest validator

| Intake | Decision |
| --- | --- |
| Why | Report the exact location and reason for invalid course manifests in support of V4-CORE-04, SEC-014 and SEC-020. |
| Simpler | Validate manifest text once on the Worker with a pure function, as required by ADR-0003. |
| Ready-made | Use the installed `yaml` parser, `@cfworker/json-schema` and the bundled Draft 2020-12 schema. Port the manifest-only checks from the Python reference. |
| Security | Bound UTF-8 input before parsing, reject YAML features that can change the data model, enforce repository path and HTTPS provider rules, and bound input excerpts in diagnostics. |
| Verify | Run `npm run typecheck && npm test` in `apps/edge_api`, the project rule check, and all four bundled Python test scripts. Cover each manifest rule with a valid fixture and an invalid fixture that asserts its code. |

Implement the manifest-only validation pipeline from FULL §4 item 10 and
`SEMANTIC_VALIDATION.md`, with workerd fixtures for phase precedence and rule
boundaries. Publication, pinned Git tree inspection and owner-approved policy
checks belong to their respective integrations.
