# Spec index

Find what to read before you read it. All paths are relative to
`spec/v4.0/` unless they start with `spec/` or `docs/adr/`. `FULL_SPECIFICATION.md`
is cited as `FULL` with its section number (`FULL §6`). Never edit `spec/v4.0/`.
Defects in it are in [`spec/errata/ERRATA.md`](errata/ERRATA.md); read the
matching erratum before you implement a section it names.

How to use this page:

1. Find the topic in the topic table and read only those files.
2. Look up an ID in the ID table to jump to its file and line.
3. If two sources disagree, apply the precedence rule below, then check the
   errata.

## Precedence

The bundle states its own rule. Read it before you resolve any conflict.

`FULL_SPECIFICATION.md` line 909 (§19):

> **Normative precedence**: (1) verified authorization/security invariants and
> provider signatures, (2) authoritative v3 JSON Schemas and semantic
> validation, (3) v4.0 link-first, catalog, cache and solo-operator policy,
> (4) API contract and D1 migrations, (5) this document, (6) non-normative
> examples and archived material. Do not implement weaker legacy wording.

`AGENTS.md` line 36, "V4 final-decisions precedence (READ FIRST)":

> These V4 clarifications override ambiguities in older narrative sections.
> **Open-by-GitHub-link is core; catalog is an optional opt-in discovery
> feature and must never be required to publish, read public course files,
> enroll or submit.**

Two older rules still apply where they do not conflict:

- `docs/V3_UPGRADE_AND_RELEASE_GATES.md` line 5: "Security invariants and
  signed provider events > JSON Schema v3 and `COMMERCE_AND_ACCESS.md` /
  `AUTOMATIC_GRADING.md` > D1 migrations and API > documentation and templates
  > historical v2 folder."
- `AGENTS.md` line 69, "Solo-maintenance precedence (v3.2)":
  `docs/SOLO_OPERATOR_GITHUB_POLICY.md` overrides any legacy "mandatory human
  legal reviewer" wording.

Consequences for Lectale: the JSON Schemas and semantic validation outrank the
prose (see erratum E4); the SQL and OpenAPI outrank the narrative documents
(but OpenAPI itself is defective, see E1). Archived material,
`docs/ARCHIVED_INFRASTRUCTURE_BASELINE_V3.md`, ranks last and is ignored (X2).

## Topics

| Topic | Read |
| --- | --- |
| Product scope, what is core vs optional | `docs/IMPLEMENTATION_DECISIONS.md` (DEC-01..16); `docs/CORE_EXPERIENCE_AND_CATALOG.md`; `docs/README.md`; FULL §1 |
| Open a public repository by URL (import, preview) | `docs/ARCHITECTURE.md` "Repository onboarding by URL"; `docs/CORE_EXPERIENCE_AND_CATALOG.md` "API / state transitions"; `docs/API_SEMANTICS.md`; FULL §2, §20; V4-CORE-01/02; erratum E3 |
| Course manifest format (`course.yaml`) | `docs/YAML_V3_REFERENCE.md`; `schemas/course-v3.schema.json`; FULL §4; `templates/`; `examples/`; erratum E4 |
| Manifest validation and attack fixtures | `docs/SEMANTIC_VALIDATION.md`; FULL §4 item 10; `tools/validate_course.py`; `tools/test_*.py`; SEC-014, SEC-020 |
| Root README as course description | `docs/README_COURSE_DESCRIPTION.md`; FULL §14; README-001..005 |
| Scaffold and canonical repository layout | FULL §3 (line 197); `docs/ARCHITECTURE.md` onboarding steps 4-6; `diagrams/repository_onboarding.dot` |
| In-app viewers (PDF, notebook, video, audio, images, folders) | `docs/RENDERING_REQUIREMENTS.md`; FULL §5 (FE-001), §5.2; UI-001..008; V4-CORE-05; A11Y-005, A11Y-006 |
| Sessions, cookies and CSRF | `docs/SESSION_SECURITY.md`; FULL §6; SEC-011..013; V4-SEC-02; `diagrams/web_session.dot`; erratum E11 |
| Firebase sign-in and native Bearer tokens | `docs/SESSION_SECURITY.md` "Native application authentication"; `docs/ARCHITECTURE.md` "Browser/native specifics"; FULL §6; SEC-010; V4-SEC-01 |
| GitHub App, owner verification, webhooks | `docs/ARCHITECTURE.md` onboarding steps 3-4, 7; `docs/SESSION_SECURITY.md` "Instructor GitHub authorization"; FULL §6; `db/0001_init.sql` (`github_installations`, `webhook_events`); V4-SEC-04; erratum X3 |
| Roles and access control | `docs/ARCHITECTURE.md` "Access-control model"; FULL §2; `db/0001_init.sql` (`course_staff`, `enrollments`); SEC-001..006 |
| Enrollment (open, approval, invite) | `docs/ARCHITECTURE.md` "Access-control model"; `docs/API_SEMANTICS.md` (enroll, enrollments); erratum X3 (invites) |
| API routes and responses | `api/openapi.yaml`; `docs/API_SEMANTICS.md`; `docs/API_V3_DTO.md`; `docs/COMPLIANCE_API.md`; FULL §7.2; errata E1, E7 |
| D1 schema and migrations | `db/0001_init.sql`..`db/0004_catalog_discovery.sql`; FULL §7.1, §12.2; errata E5, E6, E8 |
| Submissions and Git LFS uploads | FULL §8; `docs/ERROR_FAILURE_SEMANTICS.md` "Upload lifecycle"; `docs/INSTRUCTOR_LFS_GUIDE.md`; `schemas/submission-v3.schema.json`; SEC-021..026; V4-SEC-05; `README.md` "Unverified dependency"; erratum E9 |
| Manual grading and grade records | FULL §8, §9; `db/0001_init.sql` (`grades`, `grade_events`); `docs/API_SEMANTICS.md` (grades route); `schemas/grade-v3.schema.json`; errata E5, E8; ADR-0007 |
| Automatic (GitHub Actions) grading | `docs/AUTOMATIC_GRADING.md`; FULL §11; `db/0002_commerce_autograding.sql`; `schemas/grading-result-v1.schema.json`; V4-SEC-08; errata E6, N1 |
| Certificates | FULL §7; `db/0001_init.sql` (`certificates`); `docs/API_SEMANTICS.md`; V4-CORE-06 |
| Paid courses and Stripe | `docs/COMMERCE_AND_ACCESS.md`; `docs/COMMERCE_COSTS.md`; `docs/API_V3_DTO.md`; `db/0002_commerce_autograding.sql`; FULL §10, §12.1; V4-SEC-07; COM-001..006 |
| Optional catalog and search | `docs/CORE_EXPERIENCE_AND_CATALOG.md`; `db/0004_catalog_discovery.sql`; FULL §20; V4-CAT-01..05; CAT-001..009 |
| Caching and cache keys | `docs/CACHING_PERFORMANCE_COST.md`; FULL §21; V4-CACHE-01..05; CACHE-001..010; `diagrams/cache_security.dot`; errata E3, E9 |
| Costs and free-tier limits | `docs/COST_MODEL_FINAL.md`; `docs/COMMERCE_COSTS.md`; FULL §12.1, §22; V4-COST-01..06; erratum E11 |
| Errors, retries and idempotency | `docs/ERROR_FAILURE_SEMANTICS.md`; `docs/API_SEMANTICS.md`; FULL §18; V4-SEC-09; ERR-001..010; erratum E7 |
| Privacy, cookies, DSAR, retention | `docs/EU_PRIVACY_COOKIES.md`; `db/0003_compliance.sql`; FULL §15, §17.4; PRIV, COOKIE, CT; erratum E10 (scheduler) |
| Third-party video consent | `docs/EU_PRIVACY_COOKIES.md` COOKIE-003; `docs/RENDERING_REQUIREMENTS.md`; FULL §15.2; `diagrams/video_cookie_gate.dot` |
| Accessibility (WCAG 2.2 AA) | `docs/WCAG_ACCESSIBILITY.md`; FULL §16; A11Y-001..008, A11Y-T01..05; DEC-12 |
| Legal, EU marketplace, solo operator | `docs/EU_MARKETPLACE_COMPLIANCE.md`; `docs/SOLO_OPERATOR_GITHUB_POLICY.md`; FULL §17; EU-001..007; LEGAL-GATE-01..07; SOLO-001..010 |
| Security headers and threat controls | `docs/SESSION_SECURITY.md` "Threat controls", "Default security headers"; `docs/SECURITY_TESTS.md`; FULL §6, §9 |
| Hosting, domains and deployment | `docs/ARCHITECTURE.md` "Deployment placements", "Domain variants"; FULL §2, §23; OPS-001/002; V4-COST-03; ADR-0002; erratum E10 |
| Agent instructions and build order | `AGENTS.md`; FULL §13, §19, §24; `docs/BUNDLE_INDEX.md` |
| Acceptance cases and traceability | `docs/RELEASE_TESTS_V4.md`; FULL §24; `docs/traceability.md`; `docs/SECURITY_TESTS.md` |
| Bundle contract tests | `tools/test_v4_contract.py`; `tools/test_v31_static_contract.py`; `tools/test_v3_extensions.py`; `tools/test_contract.py` |
| Archived v3 baseline (do not implement) | `docs/ARCHIVED_INFRASTRUCTURE_BASELINE_V3.md`; erratum X2 |

## Requirement IDs

Extracted with a script from every Markdown file in the bundle except
`docs/ARCHIVED_INFRASTRUCTURE_BASELINE_V3.md`, whose `REQ-01`.. headings are
historical. The table lists each place that defines an ID, not places that
refer to it. 241 definitions; identical text in two files shares a row.

Cautions:

- `COM-` and `GRA-` IDs mean different things in `FULL_SPECIFICATION.md`,
  `docs/SECURITY_TESTS.md` and `docs/AUTOMATIC_GRADING.md` (erratum N1). Cite
  them with the file.
- `CAT-` (nine cases in `docs/CORE_EXPERIENCE_AND_CATALOG.md`) is separate from
  `V4-CAT-` (five release cases).
- Summaries are trimmed. Read the line before you rely on one.

### Release acceptance: product core (V4-CORE)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| V4-CORE-01 | `docs/RELEASE_TESTS_V4.md:4` | Product core | public repository URL preview opens valid course.yaml + root README with no login, does not mutate GitHub |
| V4-CORE-02 | `docs/RELEASE_TESTS_V4.md:5` | Product core | no catalog registration is ever required for a public source-link preview; no Github org required for managed course |
| V4-CORE-03 | `docs/RELEASE_TESTS_V4.md:6` | Product core | verified author uses selected-repo GitHub App to register, safe scaffold, repin and update an existing course |
| V4-CORE-04 | `docs/RELEASE_TESTS_V4.md:7` | Product core | missing/invalid YAML reports exact error, old published course remains pinned |
| V4-CORE-05 | `docs/RELEASE_TESTS_V4.md:8` | Product core | web & native display in-app PDF, embedded video, Markdown/LaTeX, static notebook, audio, images, code/text, folders; unsupported binary... |
| V4-CORE-06 | `docs/RELEASE_TESTS_V4.md:9` | Product core | real-name certificate snapshots and independent verification link; enrollment/profile edits cannot silently change issued certificates |
| V4-CORE-07 | `docs/RELEASE_TESTS_V4.md:10` | Product core | paid/priv access denied without valid enrollment/entitlement, including media URLs, API, READMEs, download ranges and previews |

### Release acceptance: catalog (V4-CAT)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| V4-CAT-01 | `docs/RELEASE_TESTS_V4.md:13` | Catalog | catalog discovery optional; managed course starts unlisted |
| V4-CAT-02 | `docs/RELEASE_TESTS_V4.md:14` | Catalog | owner lists/unlists, chooses public teaser; private README/grades and student names never leak |
| V4-CAT-03 | `docs/RELEASE_TESTS_V4.md:15` | Catalog | indexed bounded query with q/language/category/price and keyset pagination, max 50 |
| V4-CAT-04 | `docs/RELEASE_TESTS_V4.md:16` | Catalog | no external search paid service, crawler, cron indexing or required per-card GitHub API calls |
| V4-CAT-05 | `docs/RELEASE_TESTS_V4.md:17` | Catalog | catalog outage doesn't block source link to GitHub; when core Worker unavailable, explicit network error rather than blank page |

### Release acceptance: cache (V4-CACHE)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| V4-CACHE-01 | `docs/RELEASE_TESTS_V4.md:20` | Cache | immutable public commits and public catalog cache hit; no auth dependence |
| V4-CACHE-02 | `docs/RELEASE_TESTS_V4.md:21` | Cache | personalized, enrollment, grades, private files, Stripe, session and LFS authorizations no-store and never in edge cache |
| V4-CACHE-03 | `docs/RELEASE_TESTS_V4.md:22` | Cache | revoke paid entitlement -> immediate private access denial even if catalog is stale |
| V4-CACHE-04 | `docs/RELEASE_TESTS_V4.md:23` | Cache | no catchall Pages Function makes static asset traffic dynamically billed |
| V4-CACHE-05 | `docs/RELEASE_TESTS_V4.md:24` | Cache | public cache SHA keys and webhook invalidation tested; miss and 304 never trigger an unbounded GitHub loop |

### Release acceptance: security and resilience (V4-SEC)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| V4-SEC-01 | `docs/RELEASE_TESTS_V4.md:27` | Security and resilience | Firebase token claims, issuer, audience, expiry verified; no special trust granted by client supplied roles/course policy |
| V4-SEC-02 | `docs/RELEASE_TESTS_V4.md:28` | Security and resilience | web __Host- HttpOnly Secure SameSite=Lax opaque session; session rotated and revoked; CSRF origin and token checks for mutations;... |
| V4-SEC-03 | `docs/RELEASE_TESTS_V4.md:29` | Security and resilience | XSS in README/Markdown/notebook HTML cannot run; URL path traversal, external fetch SSRF, embedded trackers and script injections blocked |
| V4-SEC-04 | `docs/RELEASE_TESTS_V4.md:30` | Security and resilience | GitHub App tokens restricted, never delivered to clients, never logged; GitHub webhooks HMAC verified |
| V4-SEC-05 | `docs/RELEASE_TESTS_V4.md:31` | Security and resilience | LFS direct-to-GitHub file transfer disabled until scope+CORS+verification+token safety proved with real test repo |
| V4-SEC-06 | `docs/RELEASE_TESTS_V4.md:32` | Security and resilience | one student cannot read or overwrite another student's files/grade even when same private repository holds all attempts |
| V4-SEC-07 | `docs/RELEASE_TESTS_V4.md:33` | Security and resilience | paid checkout uses genuine signed Stripe webhook, idempotent purchases/refunds, no redirect-as-payment-proof |
| V4-SEC-08 | `docs/RELEASE_TESTS_V4.md:34` | Security and resilience | automatic grader runs untrusted code only on instructor Github Actions runner with no platform/payment secret; results verified and... |
| V4-SEC-09 | `docs/RELEASE_TESTS_V4.md:35` | Security and resilience | error responses include stable code, retryable flag, requestId and safe explanation; idempotency under retries and upload/checkout... |
| V4-SEC-10 | `docs/RELEASE_TESTS_V4.md:36` | Security and resilience | Terms, privacy, cookie settings, self-review notices, content reporting/delisting and WCAG 2.2 AA checks pass |

### Release acceptance: performance and costs (V4-COST)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| V4-COST-01 | `docs/RELEASE_TESTS_V4.md:39` | Performance & costs | free 1000/10000/50000 MAU modeled with explicit 40 vs 50 req and daily peak; 100k/1M paid model includes cached Worker request billing |
| V4-COST-02 | `docs/RELEASE_TESTS_V4.md:40` | Performance & costs | D1 index-backed public catalog and rows_read metrics; over-limit handling and budget alerts |
| V4-COST-03 | `docs/RELEASE_TESTS_V4.md:41` | Performance & costs | no custom domain works; custom domain works with same-origin /api, Firebase Authorized Domain, GitHub OAuth callback, cookie/logout... |
| V4-COST-04 | `docs/RELEASE_TESTS_V4.md:42` | Performance & costs | public PDF loads from GitHub where possible; private streaming and Range works without saving entire file to Worker memory; current... |
| V4-COST-05 | `docs/RELEASE_TESTS_V4.md:43` | Performance & costs | reader and instructor shown GitHub LFS plan-dependent quotas/cost responsibility and expected worst-case upload storage |
| V4-COST-06 | `docs/RELEASE_TESTS_V4.md:44` | Performance & costs | no tracking or provider-paid service auto-enabled during initial production release |

### Implementation decisions (DEC)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| DEC-01 | `docs/IMPLEMENTATION_DECISIONS.md:5` | One-page implementation decisions — V4 authoritative | Source URL is the core entry: Valid PUBLIC repository can be opened by link without catalog/registration |
| DEC-02 | `docs/IMPLEMENTATION_DECISIONS.md:6` | One-page implementation decisions — V4 authoritative | Catalog is optional: Built-in catalog for listed managed courses only; listing default OFF; no external search service |
| DEC-03 | `docs/IMPLEMENTATION_DECISIONS.md:7` | One-page implementation decisions — V4 authoritative | Course author owns course repository: Public or private; stable numeric repo ID; no GitHub organization requirement |
| DEC-04 | `docs/IMPLEMENTATION_DECISIONS.md:8` | One-page implementation decisions — V4 authoritative | Full course description: Root README.md rendered IN the app; YAML v3 is course outline, not prose description |
| DEC-05 | `docs/IMPLEMENTATION_DECISIONS.md:9` | One-page implementation decisions — V4 authoritative | Any discipline: PDF/video/notebook/markdown/audio/images/text/file/folder viewers; unknown binary fallback; no notebook execution |
| DEC-06 | `docs/IMPLEMENTATION_DECISIONS.md:10` | One-page implementation decisions — V4 authoritative | User identity: Firebase Auth standard; same-origin opaque web cookies + CSRF; native bearer tokens |
| DEC-07 | `docs/IMPLEMENTATION_DECISIONS.md:11` | One-page implementation decisions — V4 authoritative | API/database: Cloudflare Pages /api/* Worker/Functions + D1; all sensitive ACL decisions server-side |
| DEC-08 | `docs/IMPLEMENTATION_DECISIONS.md:12` | One-page implementation decisions — V4 authoritative | Files and finance: Instructor-owned GitHub repos + LFS with mandatory secure upload proof; no alternative binary storage; instructor... |
| DEC-09 | `docs/IMPLEMENTATION_DECISIONS.md:13` | One-page implementation decisions — V4 authoritative | Personal data: D1 authoritative enrollments, grades, purchase entitlements, certificate snapshots; no shared-cache PII |
| DEC-10 | `docs/IMPLEMENTATION_DECISIONS.md:14` | One-page implementation decisions — V4 authoritative | Paid courses: Optional one-time Stripe Connect checkout; 5% eligible subtotal ex VAT; signed webhooks unlock content; no checkout for... |
| DEC-11 | `docs/IMPLEMENTATION_DECISIONS.md:15` | One-page implementation decisions — V4 authoritative | Grading: Manual required; GitHub Actions auto/hybrid optional and owner-funded; never execute submitted code in Workers |
| DEC-12 | `docs/IMPLEMENTATION_DECISIONS.md:16` | One-page implementation decisions — V4 authoritative | Accessibility: WCAG 2.2 AA quality requirement irrespective of statutory microenterprise exemption; uploader guidance for accessible... |
| DEC-13 | `docs/IMPLEMENTATION_DECISIONS.md:17` | One-page implementation decisions — V4 authoritative | Legal/maintenance: Solo owner; self-checks and notices; ToS allocates instructor responsibility but never waives mandatory operator duties |
| DEC-14 | `docs/IMPLEMENTATION_DECISIONS.md:18` | One-page implementation decisions — V4 authoritative | Hosting: Cloudflare Pages static no cost tier; optional custom domain; /api on same origin |
| DEC-15 | `docs/IMPLEMENTATION_DECISIONS.md:19` | One-page implementation decisions — V4 authoritative | Cache: Public immutable SHA-linked objects and catalog only; never cache private, personalized, grade, session or payment data in shared... |
| DEC-16 | `docs/IMPLEMENTATION_DECISIONS.md:20` | One-page implementation decisions — V4 authoritative | No speculative implementation: GitHub LFS delegated upload is unverified; keep feature OFF unless end-to-end proof passes; don't invent... |

### Security cases (SEC)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| SEC-001 | `FULL_SPECIFICATION.md:629`; `docs/SECURITY_TESTS.md:5` | §9 › Identity and authorization | Anonymous can import/preview a public course but cannot claim instructor ownership or enroll in restricted course |
| SEC-002 | `FULL_SPECIFICATION.md:630`; `docs/SECURITY_TESTS.md:6` | §9 › Identity and authorization | Attackers paste someone else's public repository URL, forge owner UID, spoof GitHub installation ID, or replay a GitHub callback: denied |
| SEC-003 | `FULL_SPECIFICATION.md:631`; `docs/SECURITY_TESTS.md:7` | §9 › Identity and authorization | Student attempts another student's submission/grade by changing UID, file path or SQL query params: 403 |
| SEC-004 | `FULL_SPECIFICATION.md:632`; `docs/SECURITY_TESTS.md:8` | §9 › Identity and authorization | Grader attempts course outside their staff membership: 403; student attempts grade/certificate issuance: 403 |
| SEC-005 | `FULL_SPECIFICATION.md:633`; `docs/SECURITY_TESTS.md:9` | §9 › Identity and authorization | Deny private content and file metadata to unauthenticated/non-enrolled students; don't leak source URLs or MIME metadata to them |
| SEC-006 | `FULL_SPECIFICATION.md:634`; `docs/SECURITY_TESTS.md:10` | §9 › Identity and authorization | Instructor repository removed/transferred: privileged actions suspended, no implicit reassignment |
| SEC-010 | `FULL_SPECIFICATION.md:638`; `docs/SECURITY_TESTS.md:14` | §9 › Session / browser | Verify signed Firebase JWT claims; reject invalid issuer/audience/signature, expiry, alg:none, wrong project ID |
| SEC-011 | `FULL_SPECIFICATION.md:639`; `docs/SECURITY_TESTS.md:15` | §9 › Session / browser | __Host-course_session is Secure HttpOnly Path=/ SameSite=Lax, no Domain |
| SEC-012 | `FULL_SPECIFICATION.md:640`; `docs/SECURITY_TESTS.md:16` | §9 › Session / browser | CSRF test with valid browser cookie but absent/wrong CSRF/Origin rejected on every mutation |
| SEC-013 | `FULL_SPECIFICATION.md:641`; `docs/SECURITY_TESTS.md:17` | §9 › Session / browser | Logout/revocation clears server session; copied former cookie no longer works; old user cached data absent |
| SEC-014 | `FULL_SPECIFICATION.md:642`; `docs/SECURITY_TESTS.md:18` | §9 › Session / browser | XSS payload in YAML description, filename, Markdown, notebook HTML, SVG never executes JS, leaks credentials or navigates parents |
| SEC-015 | `FULL_SPECIFICATION.md:643`; `docs/SECURITY_TESTS.md:19` | §9 › Session / browser | No auth tokens, signed upload URLs or instructor PII logged, cached or placed in query strings unnecessarily |
| SEC-020 | `FULL_SPECIFICATION.md:647`; `docs/SECURITY_TESTS.md:23` | §9 › Files and uploads | Reject ../, absolute path, %2e%2e, URL encoded traversal, backslash and symlink path |
| SEC-021 | `FULL_SPECIFICATION.md:648`; `docs/SECURITY_TESTS.md:24` | §9 › Files and uploads | Invalidate upload if declared size != uploaded object size, wrong key, owner, upload attempt, MIME/signature, checksum or expiration |
| SEC-022 | `FULL_SPECIFICATION.md:649`; `docs/SECURITY_TESTS.md:25` | §9 › Files and uploads | Enforce maxFiles, maxFileBytes, maxAttemptBytes, maxAttempts and storage cap on server, not just Flutter |
| SEC-023 | `FULL_SPECIFICATION.md:650`; `docs/SECURITY_TESTS.md:26` | §9 › Files and uploads | Concurrent finalize requests produce exactly one attempt; duplicate reservations don't bypass limit |
| SEC-024 | `FULL_SPECIFICATION.md:651`; `docs/SECURITY_TESTS.md:27` | §9 › Files and uploads | Student cannot use delegated upload credential to read existing private object, alter grade or write arbitrary repository files |
| SEC-025 | `FULL_SPECIFICATION.md:652`; `docs/SECURITY_TESTS.md:28` | §9 › Files and uploads | GitHub LFS delegated-upload POC: prove action is object-limited, does not include installation token and works from Flutter Web under... |
| SEC-026 | `FULL_SPECIFICATION.md:653`; `docs/SECURITY_TESTS.md:29` | §9 › Files and uploads | LFS delegated object authorization must be object-scoped and short-lived, must not carry reusable GitHub credentials, and must verify... |
| SEC-027 | `FULL_SPECIFICATION.md:654`; `docs/SECURITY_TESTS.md:30` | §9 › Files and uploads | Range and streaming support for 250-MB private PDF; no full file buffer in Workers or app memory |

### Frontend rendering cases (UI)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| UI-001 | `FULL_SPECIFICATION.md:658`; `docs/SECURITY_TESTS.md:34` | §9 › Frontend rendering, accessibility and platform behavior | In-app PDF viewer handles 50 pages with image diagrams and zoom/search/page navigation; no external PDF app |
| UI-002 | `FULL_SPECIFICATION.md:659`; `docs/SECURITY_TESTS.md:35` | §9 › Frontend rendering, accessibility and platform behavior | Embedded approved YouTube/Vimeo and supported local MP4 video plays in Flutter Web/mobile, with in-app controls |
| UI-003 | `FULL_SPECIFICATION.md:660`; `docs/SECURITY_TESTS.md:36` | §9 › Frontend rendering, accessibility and platform behavior | Notebook viewer displays Markdown, code, text output, plots/PNG, math in order, but never executes cells or unsafe output HTML |
| UI-004 | `FULL_SPECIFICATION.md:661`; `docs/SECURITY_TESTS.md:37` | §9 › Frontend rendering, accessibility and platform behavior | Markdown, images, audio, text, source code and CSV have dedicated in-app preview |
| UI-005 | `FULL_SPECIFICATION.md:662`; `docs/SECURITY_TESTS.md:38` | §9 › Frontend rendering, accessibility and platform behavior | Unsupported binary and PowerPoint/Word if not converted: visible file card + name, size/type, download, reason preview not available |
| UI-006 | `FULL_SPECIFICATION.md:663`; `docs/SECURITY_TESTS.md:39` | §9 › Frontend rendering, accessibility and platform behavior | Folder recursion respects limits and stable ordering; empty folder and dead link show clear state |
| UI-007 | `FULL_SPECIFICATION.md:664`; `docs/SECURITY_TESTS.md:40` | §9 › Frontend rendering, accessibility and platform behavior | Viewers are navigable with keyboard and screen readers; mobile viewport responsive; graceful loading states and retries |
| UI-008 | `FULL_SPECIFICATION.md:665`; `docs/SECURITY_TESTS.md:41` | §9 › Frontend rendering, accessibility and platform behavior | Denied private resource returns user-facing access error; no token leak, redirect into GitHub or unguarded URL |

### Reliability and economics cases (OPS)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| OPS-001 | `FULL_SPECIFICATION.md:669`; `docs/SECURITY_TESTS.md:45` | §9 › Reliability and economics | Free-subdomain deployment works with GitHub callback, Firebase allowed host and session cookies |
| OPS-002 | `FULL_SPECIFICATION.md:670`; `docs/SECURITY_TESTS.md:46` | §9 › Reliability and economics | Custom domain deployment works, canonical redirect, callback URLs and isolated host-only cookies; only domain registration changes base... |
| OPS-003 | `FULL_SPECIFICATION.md:671`; `docs/SECURITY_TESTS.md:47` | §9 › Reliability and economics | Worker/D1 and GitHub API usage stays bounded when scrolling content and opening multiple resources; caching pinned commits |
| OPS-004 | `FULL_SPECIFICATION.md:672`; `docs/SECURITY_TESTS.md:48` | §9 › Reliability and economics | Webhooks HMAC verified, events idempotent, cached invalid manifest never supersedes valid previous published commit |
| OPS-005 | `FULL_SPECIFICATION.md:673`; `docs/SECURITY_TESTS.md:49` | §9 › Reliability and economics | GitHub loss or deletion produces clear message; no grade disappearance; retention & revocation tested |

### Commerce cases (COM)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| COM-001 | `FULL_SPECIFICATION.md:756` | §12 › 12.3 Security/regression acceptance additions | valid Checkout redirect without a signed Stripe webhook grants no entitlement |
| COM-001 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | successful redirect without verified Stripe webhook gives no access |
| COM-002 | `FULL_SPECIFICATION.md:757` | §12 › 12.3 Security/regression acceptance additions | replaying same Stripe event creates one order transition and one entitlement; no double-payment on retries |
| COM-002 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | replay webhook idempotent |
| COM-003 | `FULL_SPECIFICATION.md:758` | §12 › 12.3 Security/regression acceptance additions | client/YAML tampering with price, fee, seller, buyer or access cannot change server-stored facts |
| COM-003 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | forged buyer/price/fee denied |
| COM-004 | `FULL_SPECIFICATION.md:759` | §12 › 12.3 Security/regression acceptance additions | paid PDF/notebook/video access is denied to nonbuyers even if the course catalog displays preview metadata |
| COM-004 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | private material not leaked before payment |
| COM-005 | `FULL_SPECIFICATION.md:760` | §12 › 12.3 Security/regression acceptance additions | refund/dispute updates are audited; free enrollment never requires Stripe or a payout account |
| COM-005 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | refund/chargeback applied and audited |
| COM-006 | `FULL_SPECIFICATION.md:761` | §12 › 12.3 Security/regression acceptance additions | no web checkout/external checkout CTA is added to iOS/Google Play native app without policy review |
| COM-006 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | free courses never require processor |

### Grading cases (GRA)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| GRA-001 | `FULL_SPECIFICATION.md:762` | §12 › 12.3 Security/regression acceptance additions | manual PDF assignment works without a GitHub Actions workflow |
| GRA-001 | `docs/AUTOMATIC_GRADING.md:59` | Acceptance cases | A PDF assignment with manual mode works and never attempts code execution |
| GRA-001 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | manual PDF grading never launches Actions |
| GRA-002 | `FULL_SPECIFICATION.md:763` | §12 › 12.3 Security/regression acceptance additions | untrusted student manifest or file cannot enable/inject a workflow or access tokens |
| GRA-002 | `docs/AUTOMATIC_GRADING.md:60` | Acceptance cases | A valid automatic assignment launches only the owner-approved workflow and only for a finalized student attempt |
| GRA-002 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | workflow only after signed owner approval |
| GRA-003 | `FULL_SPECIFICATION.md:764` | §12 › 12.3 Security/regression acceptance additions | run ID, artifact identity and score boundaries are independently verified; malformed grader output is not published |
| GRA-003 | `docs/AUTOMATIC_GRADING.md:61` | Acceptance cases | Student edits manifest workflow path, approval token or grading request -> cannot execute a new workflow |
| GRA-003 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | untrusted student code has no secrets |
| GRA-004 | `FULL_SPECIFICATION.md:765` | §12 › 12.3 Security/regression acceptance additions | hybrid result cannot publish without human review, failures preserve an ungraded state |
| GRA-004 | `docs/AUTOMATIC_GRADING.md:62` | Acceptance cases | Malicious student file attempts secret exfiltration or path traversal -> no credentials available and no other private file access |
| GRA-004 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | malformed result not published |
| GRA-005 | `FULL_SPECIFICATION.md:766` | §12 › 12.3 Security/regression acceptance additions | instructor disabling Actions suspends automatic runs while keeping manual grading functional |
| GRA-005 | `docs/AUTOMATIC_GRADING.md:63` | Acceptance cases | Failed infrastructure, timeouts, malformed JSON and duplicate GitHub events do not create false grades |
| GRA-005 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | hybrid always reviewed |
| GRA-006 | `docs/AUTOMATIC_GRADING.md:64` | Acceptance cases | Hybrid score is never published without an instructor decision |
| GRA-006 | `docs/SECURITY_TESTS.md:53` | V3 additional mandatory tests | runner bill and caps owned by course creator |
| GRA-007 | `docs/AUTOMATIC_GRADING.md:65` | Acceptance cases | Owner can disable automatic grading and continue manual grading without breaking enrollments |
| GRA-008 | `docs/AUTOMATIC_GRADING.md:66` | Acceptance cases | Instructor's GitHub Actions bill, not platform Workers, covers grading jobs; spending caps enforced |

### Cache cases (CACHE)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| CACHE-001 | `docs/CACHING_PERFORMANCE_COST.md:49` | Security & failure tests | Anonymous public catalog can be shared without leaking any session/personally identifiable or private repository data |
| CACHE-002 | `docs/CACHING_PERFORMANCE_COST.md:50` | Security & failure tests | Requesting same private PDF as two users never returns the other's content, even after first response and across two hostnames |
| CACHE-003 | `docs/CACHING_PERFORMANCE_COST.md:51` | Security & failure tests | Revoked enrollment or refunded payment denies private content on the very next check; cache cannot revive access |
| CACHE-004 | `docs/CACHING_PERFORMANCE_COST.md:52` | Security & failure tests | Unlisted course vanishes from catalog within 60s target (purge if available), while direct link remains functional |
| CACHE-005 | `docs/CACHING_PERFORMANCE_COST.md:53` | Security & failure tests | Different GitHub commits produce different cache keys, old valid commit remains available for older grading context |
| CACHE-006 | `docs/CACHING_PERFORMANCE_COST.md:54` | Security & failure tests | Every authenticated grade/checkout, session, GitHub token or LFS URL returns Cache-Control: no-store; service workers do not persist them |
| CACHE-007 | `docs/CACHING_PERFORMANCE_COST.md:55` | Security & failure tests | Under 1000 repeated visits to same public course, GitHub manifest/README fetches do not scale one-for-one once warmed |
| CACHE-008 | `docs/CACHING_PERFORMANCE_COST.md:56` | Security & failure tests | Measured cache hit %, Worker request count, Worker CPU and D1 scanned rows validate that caching saves upstream work |
| CACHE-009 | `docs/CACHING_PERFORMANCE_COST.md:57` | Security & failure tests | Stale catalog price never overrides server offer and checkout amount |
| CACHE-010 | `docs/CACHING_PERFORMANCE_COST.md:58` | Security & failure tests | Static Flutter request does NOT execute Pages Function in production; integration test verifies route matching |

### Catalog cases (CAT)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| CAT-001 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:47` | Acceptance | Anonymous visitor pastes valid public GitHub repo URL, sees README and outline without account or catalog registration |
| CAT-002 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:48` | Acceptance | Invalid repo/manifest returns precise actionable error, does not claim ownership; request URL is sanitized and request count bounded |
| CAT-003 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:49` | Acceptance | Newly created managed course is UNLISTED; direct link works while catalog shows nothing |
| CAT-004 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:50` | Acceptance | Owner explicitly lists course -> listing appears with safe title/summary; owner unlists -> disappears after cache invalidation/TTL;... |
| CAT-005 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:51` | Acceptance | Private paid course can show ONLY confirmed public teaser; unrelated user cannot fetch protected README/content |
| CAT-006 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:52` | Acceptance | Search supports normalized 1-5 terms and filters; pagination has stable results, max 50, no full scans |
| CAT-007 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:53` | Acceptance | Delisted/suspended course never remains for more than catalog maximum TTL; checkout and private reads deny immediately even if teaser... |
| CAT-008 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:54` | Acceptance | Empty/failed catalog never blocks source URL import or public lesson rendering |
| CAT-009 | `docs/CORE_EXPERIENCE_AND_CATALOG.md:55` | Acceptance | No catalog index includes email, grade, learner UID, private repo readme, file path to private assets, billing identifiers, or... |

### Error and failure cases (ERR)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| ERR-001 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | oversized PDF rejected before upload authorization |
| ERR-002 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | replay reservation/finalize cannot overwrite another student's files |
| ERR-003 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | LFS unverified returns blocked error with zero credential leakage |
| ERR-004 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | GitHub 429 respects retry |
| ERR-005 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | partial commit reconciles without duplicating attempts |
| ERR-006 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | expired Firebase/session causes safe reauth, no loss of local unsent file |
| ERR-007 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | external video 404 accessible fallback |
| ERR-008 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | automatic grading fails safe; no zero score |
| ERR-009 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | Stripe webhook repeated/out-of-order no duplicate entitlement |
| ERR-010 | `docs/ERROR_FAILURE_SEMANTICS.md:23` | Test matrix | user sees meaningful error and support reference for every failure |

### Instructor LFS guide cases (LFS-G)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| LFS-G01 | `docs/INSTRUCTOR_LFS_GUIDE.md:21` | UX and errors | onboarding explains storage and bandwidth separately, with official URL |
| LFS-G02 | `docs/INSTRUCTOR_LFS_GUIDE.md:21` | UX and errors | worst-case calculator math and quota warnings validated |
| LFS-G03 | `docs/INSTRUCTOR_LFS_GUIDE.md:21` | UX and errors | policy enforced in API |
| LFS-G04 | `docs/INSTRUCTOR_LFS_GUIDE.md:21` | UX and errors | no unsafe token leakage |
| LFS-G05 | `docs/INSTRUCTOR_LFS_GUIDE.md:21` | UX and errors | exceeded quota/other failures actionable |
| LFS-G06 | `docs/INSTRUCTOR_LFS_GUIDE.md:21` | UX and errors | owner deauthorization removes future access without deleting grade audit |

### Root README cases (README)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| README-001 | `docs/README_COURSE_DESCRIPTION.md:11` | Root README.md as the canonical long-form course description | course description equals sanitized root README at pinned SHA |
| README-002 | `docs/README_COURSE_DESCRIPTION.md:11` | Root README.md as the canonical long-form course description | course without README cannot be published until created |
| README-003 | `docs/README_COURSE_DESCRIPTION.md:11` | Root README.md as the canonical long-form course description | malicious image/data/HTML cannot execute |
| README-004 | `docs/README_COURSE_DESCRIPTION.md:11` | Root README.md as the canonical long-form course description | paid/private README cannot be requested without entitlement |
| README-005 | `docs/README_COURSE_DESCRIPTION.md:11` | Root README.md as the canonical long-form course description | all links and images have keyboard/screen-reader fallbacks |

### Frontend product requirement (FE)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| FE-001 | `FULL_SPECIFICATION.md:463` | §5 Frontend responsibilities and in-app content rendering | Students must view all renderable course resources from **inside the Flutter application** |

### Accessibility requirements and gates (A11Y)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| A11Y-001 | `docs/WCAG_ACCESSIBILITY.md:7` | UI contract | Keyboard-only end-to-end: logical tab order, visible focus, no traps, keyboard escape from modal, skip link and labeled landmark/nav/main |
| A11Y-002 | `docs/WCAG_ACCESSIBILITY.md:8` | UI contract | Text: at least 4.5:1 contrast for regular text, 3:1 for large text and essential UI indicators; 200% zoom and up to 400%/reflow without... |
| A11Y-003 | `docs/WCAG_ACCESSIBILITY.md:9` | UI contract | Forms: explicit labels, hints and errors connected semantically; confirmation for financial submissions, destructive repository edits... |
| A11Y-004 | `docs/WCAG_ACCESSIBILITY.md:10` | UI contract | Media: captions/subtitles and transcripts for prerecorded lecture audio/video where required for target accessibility; keyboard operable... |
| A11Y-005 | `docs/WCAG_ACCESSIBILITY.md:11` | UI contract | PDF: integrated viewer with accessible controls, zoom and search; prefer tagged/accessible PDFs and provide download and reasonable... |
| A11Y-006 | `docs/WCAG_ACCESSIBILITY.md:12` | UI contract | Notebook static reader: cell headings, text/code/out accessibility, no script execution, accessible tables and diagrams with fallback... |
| A11Y-007 | `docs/WCAG_ACCESSIBILITY.md:13` | UI contract | Resource lists: descriptive link text, accessible file type/size, breadcrumbs, no focus loss on navigation; documents that cannot... |
| A11Y-008 | `docs/WCAG_ACCESSIBILITY.md:14` | UI contract | Test the real Flutter Web semantics tree and the mobile apps; automatic audit alone is insufficient |
| A11Y-T01 | `docs/WCAG_ACCESSIBILITY.md:18` | Release gates and issue severity | Every critical task (sign-in, find course, watch with captions, read PDF, open notebook, submit PDF, check grade, purchase, revoke... |
| A11Y-T02 | `docs/WCAG_ACCESSIBILITY.md:18` | Release gates and issue severity | 200% and 400% viewport tests show no clipping or horizontal scroll that prevents use except inherently 2-D content |
| A11Y-T03 | `docs/WCAG_ACCESSIBILITY.md:18` | Release gates and issue severity | PDF/video/notebook modules have passing functional tests |
| A11Y-T04 | `docs/WCAG_ACCESSIBILITY.md:18` | Release gates and issue severity | All known critical/high blockers fixed or documented alternative verified before release |
| A11Y-T05 | `docs/WCAG_ACCESSIBILITY.md:18` | Release gates and issue severity | Publish an accessibility statement, support contacts, and issue-response workflow; review content-owner vs platform responsibilities |

### Cookie requirements (COOKIE)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| COOKIE-001 | `docs/EU_PRIVACY_COOKIES.md:16` | COOKIE requirements | Strictly necessary cookies (e.g |
| COOKIE-002 | `docs/EU_PRIVACY_COOKIES.md:17` | COOKIE requirements | If **any** non-essential cookie, local storage tracker, analytics, advertising SDK or device storage access is introduced, block it... |
| COOKIE-003 | `docs/EU_PRIVACY_COOKIES.md:18` | COOKIE requirements | Third-party media. Display local thumbnail/placeholders for YouTube/Vimeo/external players by default, with a clear "Load external... |
| COOKIE-004 | `docs/EU_PRIVACY_COOKIES.md:19` | COOKIE requirements | Publish operator-verified Cookie Policy with each storage mechanism, host, purpose, category, approximate lifetime, recipients,... |
| COOKIE-005 | `docs/EU_PRIVACY_COOKIES.md:20` | COOKIE requirements | Analytics-free baseline must work with **no cookie banner** (only necessary cookies) |

### Privacy requirements (PRIV)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| PRIV-001 | `docs/EU_PRIVACY_COOKIES.md:7` | PRIV requirements | Data mapping and lawful basis |
| PRIV-002 | `docs/EU_PRIVACY_COOKIES.md:8` | PRIV requirements | Privacy by default. No analytics, adtech, third-party trackers, marketing emails, profiling or external player initialization by default |
| PRIV-003 | `docs/EU_PRIVACY_COOKIES.md:9` | PRIV requirements | Rights portal. Provide authenticated privacy dashboard for access/download, correction, deletion requests, objection/restriction where... |
| PRIV-004 | `docs/EU_PRIVACY_COOKIES.md:10` | PRIV requirements | Retention. Define clear defaults with controller review, scheduled cleanup and export for sessions, upload reservations, grades,... |
| PRIV-005 | `docs/EU_PRIVACY_COOKIES.md:11` | PRIV requirements | Security. Least privilege, encryption in transit, secrets isolation, DPIA screening for higher-risk processing, incident runbook,... |
| PRIV-006 | `docs/EU_PRIVACY_COOKIES.md:12` | PRIV requirements | Age handling. Until age-specific legal review, use clear age eligibility; do not build behavioral ads, and require additional... |

### Contractual and operational tests (CT)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| CT-001 | `docs/EU_PRIVACY_COOKIES.md:24` | Contractual and operational tests | New visitor receives no optional tracker/cookie or video iframe; strictly necessary session only after authentication |
| CT-002 | `docs/EU_PRIVACY_COOKIES.md:24` | Contractual and operational tests | Reject vs Accept produces different network/storage behavior, accepts/withdraws persistent categories and stores minimal receipt |
| CT-003 | `docs/EU_PRIVACY_COOKIES.md:24` | Contractual and operational tests | Session cookie never readable in JS and origin/CSRF attack blocked |
| CT-004 | `docs/EU_PRIVACY_COOKIES.md:24` | Contractual and operational tests | DSAR export and deletion/restriction pathways tested with internal D1 and owner GitHub records |
| CT-005 | `docs/EU_PRIVACY_COOKIES.md:24` | Contractual and operational tests | Privacy/Terms/Cookie Policy links accessible without login and on mobile |
| CT-006 | `docs/EU_PRIVACY_COOKIES.md:24` | Contractual and operational tests | Processor incident and retention runbooks exist and are linked in admin |

### EU marketplace requirements (EU)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| EU-001 | `docs/EU_MARKETPLACE_COMPLIANCE.md:5` | EU marketplace, consumer, tax, and moderation readiness — v3.2 | Terms of Service, instructor terms and paid-course terms: published before registration/onboarding; accurate seller identity,... |
| EU-002 | `docs/EU_MARKETPLACE_COMPLIANCE.md:6` | EU marketplace, consumer, tax, and moderation readiness — v3.2 | Consumer checkout: show total price incl |
| EU-003 | `docs/EU_MARKETPLACE_COMPLIANCE.md:7` | EU marketplace, consumer, tax, and moderation readiness — v3.2 | EU VAT/OSS: determine seller/merchant of record, place of supply and B2C VAT; invoice and reporting responsibilities |
| EU-004 | `docs/EU_MARKETPLACE_COMPLIANCE.md:8` | EU marketplace, consumer, tax, and moderation readiness — v3.2 | DSA applicability assessment (not a blanket assumption of all marketplace obligations): hosted course indexes and marketplace may be... |
| EU-005 | `docs/EU_MARKETPLACE_COMPLIANCE.md:9` | EU marketplace, consumer, tax, and moderation readiness — v3.2 | Intellectual property and privacy: instructor warrants license to upload/share recorded lectures, PDFs, music, student images/audio and... |
| EU-006 | `docs/EU_MARKETPLACE_COMPLIANCE.md:10` | EU marketplace, consumer, tax, and moderation readiness — v3.2 | Seller tax reporting (e.g |
| EU-007 | `docs/EU_MARKETPLACE_COMPLIANCE.md:11` | EU marketplace, consumer, tax, and moderation readiness — v3.2 | Payment and mobile store rules: Stripe Connect connected-account verification and reconciliation; only webhook-confirmed entitlement |

### Paid-course release gates (LEGAL-GATE)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| LEGAL-GATE-01 | `docs/EU_MARKETPLACE_COMPLIANCE.md:15` | Paid course release gates | Real legal operator, contact, processor contracts, cross-border data obligations reviewed |
| LEGAL-GATE-02 | `docs/EU_MARKETPLACE_COMPLIANCE.md:15` | Paid course release gates | Consumer law and withdrawal policy reviewed, preview/paid scope clear |
| LEGAL-GATE-03 | `docs/EU_MARKETPLACE_COMPLIANCE.md:15` | Paid course release gates | Tax merchant of record and net creator payouts calculated |
| LEGAL-GATE-04 | `docs/EU_MARKETPLACE_COMPLIANCE.md:15` | Paid course release gates | DSA notice-and-action, contact/complaints and seller verification decisions documented |
| LEGAL-GATE-05 | `docs/EU_MARKETPLACE_COMPLIANCE.md:15` | Paid course release gates | applicable EAA exceptions and WCAG/cookie/privacy readiness documented by owner |
| LEGAL-GATE-06 | `docs/EU_MARKETPLACE_COMPLIANCE.md:15` | Paid course release gates | Native purchase policy vetted or native checkout explicitly disabled |
| LEGAL-GATE-07 | `docs/EU_MARKETPLACE_COMPLIANCE.md:15` | Paid course release gates | Prices, terms, invoices/refunds/webhook identities tested |

### Solo-operator checks (SOLO)

| ID | File:line | Section | Summary |
| --- | --- | --- | --- |
| SOLO-001 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:32` | Product-owner self-review release checks | instructor Terms contain content licenses and rights/recorded-person responsibilities |
| SOLO-002 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:33` | Product-owner self-review release checks | paid materials never become public through a GitHub source URL, shared token, README or previews |
| SOLO-003 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:34` | Product-owner self-review release checks | all public-facing app/checkout hosting uses Cloudflare Pages, not GitHub Pages |
| SOLO-004 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:35` | Product-owner self-review release checks | note explains GitHub usage limits and provides policy links |
| SOLO-005 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:36` | Product-owner self-review release checks | document operator's microenterprise status and applicability of third-party-content exception; do not treat unrelated rights as waived |
| SOLO-006 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:37` | Product-owner self-review release checks | reports can be submitted and course display/paid access can be disabled without deleting GitHub repositories |
| SOLO-007 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:38` | Product-owner self-review release checks | accurate operator identity, support contact, terms/privacy/cookie policy and applicable payment/consumer disclosures published; no... |
| SOLO-008 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:39` | Product-owner self-review release checks | permissions, student data and grades remain private; external media tracking consent (where necessary) is enforced |
| SOLO-009 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:40` | Product-owner self-review release checks | checkout completed by verified webhook; refund/dispute tests and seller payout responsibilities documented |
| SOLO-010 | `docs/SOLO_OPERATOR_GITHUB_POLICY.md:41` | Product-owner self-review release checks | creator self-check recorded with date, markets enabled, legal/policy versions, unresolved issues and links to provider sources |
