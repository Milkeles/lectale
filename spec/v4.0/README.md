# Portable Course Platform — Final Implementation Package v4.0

**Start:** `AGENTS.md` → `docs/IMPLEMENTATION_DECISIONS.md` → `FULL_SPECIFICATION.md` → `docs/CORE_EXPERIENCE_AND_CATALOG.md` → `docs/CACHING_PERFORMANCE_COST.md` → `docs/RELEASE_TESTS_V4.md`.

The primary workflow is opening public GitHub repositories by URL and rendering `README.md` and `course.yaml` within Flutter. The catalog is an optional discovery feature, opt-in and powered by D1 (no search vendor). The platform does not store source course files. Academic state/grades/entitlements are in D1. Instructor owns GitHub repositories and LFS charges. Manual grading is standard, GitHub Actions auto/hybrid grading and Stripe Connect one-time paid courses are opt-in; fee 5%. Retain WCAG 2.2 AA, cookies/GDPR/consumer compliance and solo-operator controls.

The manifest schema remains version 3 (`schemas/course-v3.schema.json`). The specification version is 4.0, which is not a new YAML dialect. Source SQL migrations: `db/0001_init.sql` through `db/0004_catalog_discovery.sql`. API: `api/openapi.yaml`. The definitive acceptance cases: `docs/RELEASE_TESTS_V4.md` and legacy relevant `docs/SECURITY_TESTS.md`.

**Unverified dependency:** delegated client-side GitHub LFS object uploads. `LFS_DIRECT_UPLOAD_ENABLED=false` until a real secure GitHub integration test demonstrates narrow scope, no owner-token exposure and complete storage verification. No substitute storage provider is part of this specification.

**Run tests** (requires PyYAML, jsonschema and SQLite):
```
python tools/test_contract.py
python tools/test_v3_extensions.py
python tools/test_v31_static_contract.py
python tools/test_v4_contract.py
```

The supplied PDF/DOCX are reading copies with 14-point body text. `FULL_SPECIFICATION.md` and supporting docs are implementation sources. Architecture diagrams are included as `.dot`, `.png`, and `.svg` in `diagrams/`.
