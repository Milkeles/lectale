# M2 anonymous preview API

| Intake | Decision |
| --- | --- |
| Why | Open a public course by GitHub URL and read its pinned files anonymously (V4-CORE-01, V4-CORE-02). |
| Simpler | Use the existing Hono Worker and Cache API with a read-only GitHub port. |
| Ready-made | Reuse generated OpenAPI types, the course validator, the outline mapper, and GitHub REST and raw file endpoints. |
| Security | Check public visibility, pin reads to SHA, allow only validated regular files, confine outbound requests, and return safe media types and errors (V4-SEC-03, V4-SEC-09). |
| Verify | Type-check and run Worker tests for import, scoped streaming, cache keys, visibility, and outbound fetch policy. Run the project-rule and OpenAPI checks (V4-CACHE-01, V4-CACHE-02, V4-CACHE-05). |

Implement the three anonymous preview operations defined in the corrected OpenAPI contract.
