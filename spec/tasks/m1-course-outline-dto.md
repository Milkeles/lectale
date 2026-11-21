# M1 CourseOutline client DTO

| Intake | Decision |
| --- | --- |
| Why | Generate the Dart client for V4-CORE-01 and give readers a typed course outline. |
| Simpler | Project the validated manifest into plain OpenAPI types and put each scoped href on its resource. |
| Ready-made | Reuse the Worker validator, swagger_parser, Dio and the existing Flutter SDK test dependency. |
| Security | Allowlist display fields, omit credential-bearing links and policy, and reuse ADR-0008's pinned resource addresses. |
| Verify | Check both response schemas, map a validated manifest in Vitest, decode a CoursePreview in Flutter, and verify generation, root analysis and project rules. |

Generate a Dart reader client from the normalized CourseOutline contract.
