# Normative v3.1 implementation bundle

Read `AGENTS.md`, `FULL_SPECIFICATION.md`, `docs/ARCHITECTURE.md`, `docs/YAML_V3_REFERENCE.md`, `schemas/`, `db/0001_init.sql`, `db/0002_commerce_autograding.sql`, `db/0003_compliance.sql`, `api/openapi.yaml`, and `docs/COMPLIANCE_API.md`.

Security requires `docs/SESSION_SECURITY.md`, `docs/SECURITY_TESTS.md`, `docs/ERROR_FAILURE_SEMANTICS.md`, `docs/INSTRUCTOR_LFS_GUIDE.md`; client acceptance requires `docs/RENDERING_REQUIREMENTS.md`, `docs/README_COURSE_DESCRIPTION.md`, `docs/WCAG_ACCESSIBILITY.md`, `docs/EU_PRIVACY_COOKIES.md`; paid course launch requires `docs/COMMERCE_AND_ACCESS.md`, `docs/COMMERCE_COSTS.md`, and `docs/EU_MARKETPLACE_COMPLIANCE.md`. Optional grading uses `docs/AUTOMATIC_GRADING.md`.

There is only one submission storage provider: instructor-owned GitHub LFS, pending safe delegated direct upload POC. Large uploads are blocked unless POC passes. Do not generate any alternative provider implementations. All new courses use schemaVersion 3.

- v3.2 policy source: `docs/SOLO_OPERATOR_GITHUB_POLICY.md` (solo maintainer, ToS, GitHub commercial terms and accessibility exceptions).

### V4 authoritative clarifications
- `docs/IMPLEMENTATION_DECISIONS.md`
- `docs/CORE_EXPERIENCE_AND_CATALOG.md`
- `docs/CACHING_PERFORMANCE_COST.md`
- `docs/COST_MODEL_FINAL.md`
- `docs/RELEASE_TESTS_V4.md`
- `db/0004_catalog_discovery.sql`
