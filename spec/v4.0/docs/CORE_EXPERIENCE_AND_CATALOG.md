# Core experience, repository links, and opt-in catalog — V4 normative

## One-sentence product definition
A public GitHub course repository with a valid root `course.yaml` and `README.md` can be opened by URL, rendered safely inside Flutter, and optionally claimed and managed by its verified owner. Discovery is a convenience, NOT the storage, publication, or access-control mechanism.

## Never conflate these concepts
- **Repository preview**: anonymous, read-only preview of a valid PUBLIC GitHub repository by URL, without its author having an account on this platform. It has no platform-provided student enrollment, grading, paid access, or private-file permissions.
- **Managed course**: instructor proves administrative rights, installs GitHub App on chosen repositories, accepts terms, and registers course in D1. Required for course enrollments, private content, submissions, grades and certificates. Does not require catalog listing.
- **Catalog listing**: optional, reversible, explicitly opted-in public-safe metadata record for a managed course. Paid private courses may list SAFE teaser metadata and price, never private README or private files. Unlisted courses remain reachable via their platform course link, subject to access restrictions; unclaimed public repositories remain accessible through `Open repository URL`.
- **Saved course**: optional learner bookmark, not an enrollment or payment entitlement.
- **Enrollment**: academic participation permission, subject to open/approval/invite.
- **Entitlement**: permission to read paid material, created by a verified payment event or properly authorized grant, not by YAML or catalog listing.

## Frontend navigation / required screens
Home: prominent `Open a course from GitHub` input, `My courses` for logged-in learners, and optional Browse courses tab. Source-link workflow MUST NOT require a catalog query. On paste of `https://github.com/{owner}/{repo}` (allow trailing slash / .git only after normalization), frontend asks a public preview endpoint; renders root README.md, course outline, and supported files in the in-app viewers. The preview MUST be safe and sanitized. If repo is private/not found, show privacy-neutral error, plus owner connect/login options; do not leak whether inaccessible private repo exists via user-specific error differences.

Instructor registration: `Claim/manage this repository` requires Firebase session, GitHub user authorization/admin verification for stable GitHub repo ID, selected-repository GitHub App installation, explicit safe scaffold confirmation, Terms acceptance, then D1 course mapping. `Publish without listing` is always available after validation; `Show in catalog` is a separate opt-in toggle (default OFF). If user pastes a GitHub URL for an already claimed course, display existing platform course when appropriate instead of trying to reassign ownership.

Student: opening public linked course requires no account. Enrolling, submitting, saving bookmarks, purchasing or seeing private materials requires login and platform policy checks. Lesson and assignment material render inside the app. For unknown binary formats, show file metadata plus safe download. Assignments accept arbitrary files subject to validated policy; notebooks are previewed only, not executed.

## Catalog search: scope and no new paid search services
Use existing D1, Workers and cache. Do NOT deploy Algolia, Elasticsearch, a crawler, search vector database, cron-based indexing jobs, or a second public course store. Every listing is a D1 snapshot of an already verified MANAGED course. Only publicly releasable metadata is included. Anonymous guests browse public catalog records; no fetch from GitHub per catalog card. Catalog includes free or paid published courses if explicitly opted-in. PRIVATE course repo can still be listed with approved, safe teaser metadata. Hide `unlisted`, draft, suspended, delisted or deleted courses. Delisting removes search result, not the GitHub repository.

- List schema fields: `catalog_listing` (unlisted|listed), `catalog_title`, `catalog_summary`, `catalog_language`, `catalog_category`, `catalog_tags_json`, `catalog_cover_url`, `catalog_sort_at`; price summary comes from the platform's active offer, not from course.yaml.
- Source of safe title/summary/language defaults: validated public-safe `course` metadata in course.yaml, then instructor confirmation. Never automatically copy README body to a listing; for private repo content this is forbidden.
- When listing a private or paid course, demand explicit public preview consent; URLs/thumbnail must not reveal signed download credentials.
- Query `GET /api/courses?q=&language=&category=&price=free|paid&limit=20&cursor=...` with stable keyset pagination, default 20 and max 50, bounded filter options, strict URL-length cap and typed values. Cursor is opaque, bounded, integrity-protected or strictly validated, and scoped to filter fingerprint. Return `nextCursor`, `items`, and `generatedAt`.
- Search uses indexed, normalized safe catalog terms (`catalog_search_terms`), at most 30 unique tokens per listing, 1-5 query tokens, no unbounded leading-wildcard scan; case folding/Unicode normalization and tokenization must have tests. Exact-token matching is required; prefix matching is an optional later enhancement. Index and limit results by (catalog_sort_at, course_id) for determinism. Disable `q` search with clear fallback rather than executing a full table scan if indexes unavailable.
- Catalog cache may be reused across all anonymous users for public SAFE metadata. Private/personalized views and price/payment entitlements must be rechecked at request time; caching a public price snapshot is not checkout price authority.
- Currency displayed is offer's currency; checkout must re-read current active offer and verify amounts server-side. Catalog can be stale briefly; not evidence of access or price acceptance.

## API / state transitions
`POST /api/courses/import` -> read-only normalized preview; no account required for PUBLIC repositories; anti-abuse budget.
`POST /api/courses/register` -> verified admin managed-course state; no listing by default.
`PUT /api/courses/{courseId}/catalog` -> owner toggles list/unlist and confirms public-safe preview fields, expected revision for concurrency, effective immediately in D1; purge public catalog cache or use short TTL.
`GET /api/courses` -> safe public catalog listing and search, no per-item GitHub requests.
`GET /api/courses/{id}` -> do NOT infer content entitlement from catalog item; consult visibility + session + enrollment/purchase and verified content commit.
`POST /api/courses/{id}/publish` -> publish managed course, separately from catalog listing.

## Cost and operational invariants
- `Open by GitHub URL` and direct course links continue to work if the catalog feature is temporarily disabled, empty, or D1 catalog search is unavailable (public URL preview may still depend on repository access and its shared platform API).
- No mandatory paid service is added for catalog. It uses existing Workers/D1 and public cache only. Catalog requests still count against Workers request quota even on cache hits if Workers Caching handles them; hits save CPU/D1/GitHub, not necessarily request charges.
- No scheduled GitHub scan for newly created courses. Only owner-selected managed courses enter the catalog, via explicit opt-in; no crawling of private repository content.
- Never reveal nonlisted private course existence, membership rosters, student identities, grades, or private file URLs through search.

## Acceptance
CAT-001: Anonymous visitor pastes valid public GitHub repo URL, sees README and outline without account or catalog registration.
CAT-002: Invalid repo/manifest returns precise actionable error, does not claim ownership; request URL is sanitized and request count bounded.
CAT-003: Newly created managed course is UNLISTED; direct link works while catalog shows nothing.
CAT-004: Owner explicitly lists course -> listing appears with safe title/summary; owner unlists -> disappears after cache invalidation/TTL; direct course URL still works.
CAT-005: Private paid course can show ONLY confirmed public teaser; unrelated user cannot fetch protected README/content.
CAT-006: Search supports normalized 1-5 terms and filters; pagination has stable results, max 50, no full scans.
CAT-007: Delisted/suspended course never remains for more than catalog maximum TTL; checkout and private reads deny immediately even if teaser cache is stale.
CAT-008: Empty/failed catalog never blocks source URL import or public lesson rendering.
CAT-009: No catalog index includes email, grade, learner UID, private repo readme, file path to private assets, billing identifiers, or installation token.
