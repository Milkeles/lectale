# M1 corrected OpenAPI contract

| Intake | Decision |
| --- | --- |
| Why | Apply E1, E2, E3 and E7 to support V4-CORE-01 and V4-SEC-09. |
| Simpler | Fork the frozen OpenAPI inventory and fully type health and the public preview slice. |
| Ready-made | Reuse the bundled manifest schema and the Python test suite's PyYAML and jsonschema dependencies. |
| Security | Declare route authorization, verify provider webhook signatures, restrict preview to public pinned content, and share one safe error envelope. |
| Verify | Run the OpenAPI test script, unittest discovery under `tool/`, and all bundled spec test scripts. |

Define and lint the corrected OpenAPI 3.1 contract in `spec/errata/openapi.yaml`.
