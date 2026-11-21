# M1 course manifest validator

| Intake | Decision |
| --- | --- |
| Why | Report the exact location and reason for invalid course manifests (V4-CORE-04, SEC-014, SEC-020) while reducing CPU against the Workers Free 10 ms budget. |
| Simpler | Validate manifest bytes or text once on the Worker with a pure function, as required by ADR-0003. |
| Ready-made | Use the installed `yaml` parser and build-time Ajv standalone generation from the bundled Draft 2020-12 schema. Keep the manifest-only checks ported from the Python reference. |
| Security | Reject invalid UTF-8 and bound YAML composition, schema work and diagnostics. Keep dynamic code generation out of the Worker and retain canonical path and video provider checks. |
| Verify | Run `npm run typecheck && npx vitest run` in `apps/edge_api`, the project rule check and Python tool tests. Record before and after CPU measurements over 20 runs per fixture and check diagnostic pointers across schema branches. |

Implement the manifest-only validation pipeline from FULL §4 item 10 and
`SEMANTIC_VALIDATION.md`, with workerd fixtures for phase precedence and rule
boundaries. Publication, pinned Git tree inspection and owner-approved policy
checks belong to their respective integrations.
