# Implementation instructions for Codex, Claude Code, and other coding agents

**Read first:** `docs/ARCHITECTURE.md`, `docs/SESSION_SECURITY.md`, `docs/RENDERING_REQUIREMENTS.md`, `docs/SEMANTIC_VALIDATION.md`, `docs/SECURITY_TESTS.md`, `schemas/*`, `api/openapi.yaml`, `db/0001_init.sql`. The accompanying technical requirements PDF/DOCX is normative where this bundle delegates to it.

## Implementation contract

- This is a new **v3** spec; no newly generated repository may use v1 YAML. JSON Schemas in `schemas/` are authoritative field grammar. Use `course.yaml` for machine-readable navigation and mandatory root `README.md` for the human-facing full course description. Submission and grade YAML in private repo are only exports; D1 remains authoritative for grades.
- The core goal is student-facing delivery of lecture recordings/PDFs/Jupyter notebooks/other files, plus arbitrary-file assignment submission, manual grading, **opt-in owner-funded GitHub Actions automatic/hybrid grading**, and optionally free or one-time paid courses with a 5% platform commission. No notebook execution in browser and no untrusted grading execution on platform Workers.
- Do not implement user-facing functionality that requires students to visit GitHub to read/view PDFs, notebooks or video. In-app viewers are a release requirement, and unsupported binaries get an in-app download card.
- Stack: Flutter Web/mobile, Cloudflare Pages static assets, same-origin Pages Functions/Workers for API, Cloudflare D1, Firebase Auth, GitHub App, instructor GitHub repos, external video provider; Only owner-hosted GitHub LFS may hold large submissions, after a safe-delegation test.
- Do not silently assume GitHub LFS direct authorization is safe. Gate it behind `LFS_DIRECT_UPLOAD_ENABLED=false` until end-to-end validation. There is no alternate storage route. If safe Git LFS upload delegation cannot be demonstrated, disable large upload functionality and explain the block.
- Require secure web cookies/CSRF per `docs/SESSION_SECURITY.md`; native uses Firebase Bearer tokens. Do not write your own password system or store sensitive credentials in browser storage.
- Provider-neutral persistence and resource rendering modules make future backends possible, but do not add a premature plugin system or unsupported execution/quiz features.

## Proposed monorepo layout

```
apps/
  flutter_client/         # responsive Flutter Web + Android/iOS, viewer abstractions
  edge_api/               # Cloudflare Pages Functions or Worker; D1, GitHub, auth
packages/
  course_contract/        # v3 schemas, YAML parser/validator, generated types
  resource_renderers/     # pdf/video/notebook/markdown/image/audio/text/fallback
  api_client/             # typed HTTP client with cookie/Bearer modes
infrastructure/
  d1/                     # schema migrations
  cloudflare/             # deployment configuration, headers, routes
  github_app/             # manifest, callback/webhook handlers
spec/
  schemas/               # committed copies of normative schemas
  examples/              # sample valid/invalid manifest fixtures
  tests/                 # contract and security test fixtures
.github/workflows/       # CI for schema/security/Flutter/tests
```

## V4 final-decisions precedence (READ FIRST)
Read `docs/IMPLEMENTATION_DECISIONS.md`, `docs/CORE_EXPERIENCE_AND_CATALOG.md`, `docs/CACHING_PERFORMANCE_COST.md`, `docs/COST_MODEL_FINAL.md`, and `docs/RELEASE_TESTS_V4.md` before coding. These V4 clarifications override ambiguities in older narrative sections. **Open-by-GitHub-link is core; catalog is an optional opt-in discovery feature and must never be required to publish, read public course files, enroll or submit.** Do not infer a public paid-content license from a teaser listing. Root README is the full course description. Cached Worker GET still counts as a Worker request, even when CPU avoided. Do not cache private/personal records in shared edge cache. `/api/*` only invokes Functions; static assets must be static. `db/0004_catalog_discovery.sql` is required. `course-v3.schema.json` remains THE manifest grammar; spec v4 does not introduce a YAML v4 dialect.

## Work stages / gates

1. Parser and schema validation + URI/path attack tests; SDK data models from v3.
2. Public repository-by-URL preview, safe manifest rendering, complete in-app viewer suite including fallback.
3. Firebase Auth, same-origin session cookie + CSRF, native Bearer, D1 migration and authorization tests.
4. GitHub owner verification, selected-repo App install, initialization idempotency, private content authorization.
5. Enrollment approval/invite/open and scoped student/staff views.
6. Validate Git LFS safe delegated uploads in a real private test repository, then implement reservation and finalization; keep upload feature disabled if the POC fails.
7. Manual grading, audit, certificates, webhook/pinning, deletion/retention.
8. Optional owner-approved private GitHub Actions grading, with isolated no-secret execution and verified output import.
9. Optional paid-course Stripe Connect one-time Checkout, signed webhook entitlement, refunds/chargebacks, and store-policy gates.
10. Optional D1 opt-in catalog and indexed search; public caching and cost-metrics tests; never block URL flow.
11. Build deploys to `pages.dev`, custom domain, cost guards, mobile integration and penetration tests.

At each stage run automated tests, report which acceptance cases pass, and do not claim security properties not actually tested. Never silently substitute another upload/storage service or require a GitHub organization.

## V3 payment and grading release gates

Read `docs/COMMERCE_AND_ACCESS.md`, `docs/AUTOMATIC_GRADING.md`, `docs/COMMERCE_COSTS.md`, `docs/API_V3_DTO.md`, `docs/YAML_V3_REFERENCE.md`, `db/0002_commerce_autograding.sql`, `schemas/grading-result-v1.schema.json`. No free-course payment API calls. Stripe Checkout success URL is never payment proof. Paid content remains inaccessible until verified webhook, and all private video providers must support enforceable access restrictions.

Do NOT invent automatically approved graders. Student code is hostile. No Firebase/GitHub/Stripe secrets in job environment. Github Actions jobs are instructor-owned and instructor-billed; return validated bounded results to D1 as proposed grades before final release policy. Paid courses can launch web-first, but do not add external checkout links/buttons to native apps without app store compliance review.

**Authoritative schema is course-v3.schema.json; never generate v2.** Only the v3 schemas in `schemas/` are implementation sources. No course pricing or entitlement in YAML. The root README is rendered inside the frontend for authorized readers; catalog teaser metadata comes only from validated public-safe metadata.

## Compliance and release gates (mandatory)

Before implementation read `docs/EU_PRIVACY_COOKIES.md`, `docs/WCAG_ACCESSIBILITY.md`, `docs/EU_MARKETPLACE_COMPLIANCE.md`, `docs/README_COURSE_DESCRIPTION.md`, and `docs/ERROR_FAILURE_SEMANTICS.md`, `docs/INSTRUCTOR_LFS_GUIDE.md`. Follow `db/0003_compliance.sql`. Build the privacy/terms/cookie settings, gated third-party video, DSAR lifecycle, accessible viewer suite, illegal-content reporting, and seller compliance workflows. No non-essential tracking or third-party player loads without appropriate permission. Default to no analytics/cookie banner when only strictly necessary cookies are used. Never claim legal sign-off merely because tests pass. Paid-course activation is legally gated.

Only instructor-owned Git LFS storage is supported. Instructors must receive a readable in-product warning that GitHub Free includes **10 GiB LFS storage and 10 GiB monthly download allowance**, that limits and pricing may change and that the GitHub repository owner pays any overages. A safe Git LFS delegated-upload security proof is required before student direct uploads. If absent, upload is disabled; do not substitute a different storage service or expose repository tokens.

**Solo-maintenance precedence (v3.2):** `docs/SOLO_OPERATOR_GITHUB_POLICY.md` overrides any legacy "mandatory human legal reviewer" wording. The owner self-reviews and signs release criteria; external lawyer/compliance officer is not required by CI. No claim that Terms alone eliminates GDPR, consumer law or DSA duties. GitHub private repo commercial content is generally possible; never use GitHub Pages for an e-commerce storefront.
