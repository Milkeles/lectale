# Spec errata register

Defects in the imported bundle `spec/v4.0/`, which is never edited. Each entry
says what is wrong, where, and what Lectale does instead. The owner signs off
each one. Until then the status is `proposed`.

Paths are relative to `spec/v4.0/`. Line numbers were checked against the files
on 2026-11-21. The PDF (`course_platform_final_v4.pdf`) was not checked; this
register covers the Markdown, YAML, JSON and SQL files only.

Precedence is the bundle's own rule (`FULL_SPECIFICATION.md` §19, line 909;
`AGENTS.md`, "V4 final-decisions precedence"; see also `spec/INDEX.md`). An
erratum that conflicts with a higher-precedence item says so.

Evidence check: `held` means every claim was confirmed in the bundle. `partly`
says which part was not. No entry failed outright.

| ID | Defect | Status | Evidence | ADR |
| --- | --- | --- | --- | --- |
| E1 | OpenAPI unusable for codegen | accepted | held | none |
| E2 | Resource ID scope collides | accepted | held | [0008](../../docs/adr/0008-scoped-resource-addresses-and-public-preview-route.md) |
| E3 | Anonymous preview has no content route | accepted | held, plan wording corrected | [0008](../../docs/adr/0008-scoped-resource-addresses-and-public-preview-route.md) |
| E4 | `schemaVersion` is 2 in prose, 3 in schema | accepted | held | none |
| E5 | Manual grading needs an LFS upload | accepted | held | [0007](../../docs/adr/0007-offline-assessment-records.md) |
| E6 | Auto-grading approval loses release policy and repo | accepted | held | none |
| E7 | Error envelope, idempotency, status codes disagree | accepted | partly | none |
| E8 | Grade integrity | accepted | held | none |
| E9 | Catalog TTL and upload-state vocabularies | accepted | held | none |
| E10 | Pages lacks Cron, Workers Logs, Rate Limiting | accepted | held, external fact | [0002](../../docs/adr/0002-one-worker-with-static-assets.md) |
| E11 | Free D1 limits vs session writes | accepted | partly | none |
| X1 | v2 to v3 migration demanded, v2 undefined | proposed | held | none |
| X2 | Archived baseline contradicts same-origin `/api` | proposed | held | none |
| X3 | Missing routes | proposed | held | none |
| N1 | COM and GRA IDs defined three ways | proposed | held | none |

Entries E1 to E11 and X1 to X3 come from the delivery plan (§1.1). N1 was found
while building `spec/INDEX.md`.

---

## E1 OpenAPI is unusable for codegen

- **Status:** accepted (owner, 2026-11-21)
- **Affected:** `api/openapi.yaml` lines 27-29 (global `security`), 71, 100,
  235, 242, 343 (the only five `security: []`), 154-162 (`/courses/import`),
  187 (stray key), 376 (`/legal/{documentType}`), 488-500 (the only
  `requestBody`).
- **Defect:** 28 of 46 operations have a templated path. 27 of those declare no
  parameters; only `PUT /courses/{courseId}/catalog` declares `courseId`.
  `components` has no `parameters`. The file has one `requestBody`, one
  `content:` and no `$ref`, so no request or response has a schema. Line 187
  holds the key `restricted when course private: null` inside the manifest
  `200` response. The global `security` (WebSession or FirebaseBearer) applies
  to every operation that does not set `security: []`. That includes
  `POST /courses/import`, which the spec calls "public for public URL only"
  (`docs/API_SEMANTICS.md`, line 14), and `GET /legal/{documentType}`, whose
  summary says "without authentication".
- **Resolution:** fork as `spec/errata/openapi.yaml`. Declare path parameters,
  add request and response schemas, remove the stray key, set per-operation
  `security: []` on public routes, and lint in CI. Generate types from the fork
  (openapi-typescript, swagger_parser).
- **ADR:** none yet. Covered by M1.

## E2 Resource ID scope collides

- **Status:** accepted (owner, 2026-11-21)
- **Affected:** `docs/YAML_V3_REFERENCE.md` line 55; `FULL_SPECIFICATION.md`
  line 286; `docs/SEMANTIC_VALIDATION.md` line 5; `api/openapi.yaml` line 188;
  `docs/API_SEMANTICS.md` line 19; `FULL_SPECIFICATION.md` line 584.
- **Defect:** resource `id` is "unique within local resources list" and
  validation requires "resource IDs per containing list". The route is
  `/courses/{courseId}/content/{resourceId}`. Lessons and assignments both hold
  resources (`docs/YAML_V3_REFERENCE.md`, section 5), so one `resourceId` can
  name several files.
- **Resolution:** address a resource by its parent and ID (`{lessonId}/{resourceId}`)
  or by an opaque address the validator derives. Keep the schema unchanged.
- **ADR:** [0008](../../docs/adr/0008-scoped-resource-addresses-and-public-preview-route.md) (proposed).

## E3 The anonymous preview has no content route or identity

- **Status:** accepted (owner, 2026-11-21)
- **Affected:** `docs/API_SEMANTICS.md` lines 14 and 19; `api/openapi.yaml` lines
  154 and 188; `db/0001_init.sql` line 22 (`courses.id`);
  `docs/CACHING_PERFORMANCE_COST.md` lines 11-13 (classes B and D).
- **Defect:** `POST /courses/import` returns a read-only preview, but the only
  content route needs a D1 `courseId`. An unclaimed public repository has no
  course row. V4-CORE-01 and V4-CORE-02 require the preview with no
  registration.
- **Resolution:** add `GET /api/preview/{repoId}/{sha}/...`, public, keyed like
  the `public-course:v1:` cache key.
- **Correction to the plan:** the plan says "public cache class A". In
  `docs/CACHING_PERFORMANCE_COST.md` class A is the hashed static app. SHA-keyed
  public content is class B, and the repository-to-SHA lookup is class D. Use B
  and D.
- **ADR:** [0008](../../docs/adr/0008-scoped-resource-addresses-and-public-preview-route.md) (proposed).

## E4 `schemaVersion` is 2 in prose, `const: 3` in the schema

- **Status:** accepted (owner, 2026-11-21)
- **Affected:** `FULL_SPECIFICATION.md` line 247; `docs/YAML_V3_REFERENCE.md`
  line 16; `schemas/course-v3.schema.json` line 8.
- **Defect:** both prose tables say `schemaVersion` is "integer constant `2`".
  The schema says `"const": 3`, and every example and template uses 3.
- **Resolution:** the schema wins. The precedence rule ranks "authoritative v3
  JSON Schemas" above the specification text (`FULL_SPECIFICATION.md` §19).
  Implement 3 and note the typo here.
- **ADR:** none needed.

## E5 Manual grading is promised with uploads disabled, but no record allows it

- **Status:** accepted (owner decided 2026-11-21)
- **Affected:** `FULL_SPECIFICATION.md` lines 785 and 787;
  `db/0001_init.sql` line 105; `docs/API_SEMANTICS.md` (grades route);
  `schemas/submission-v3.schema.json` (`files`, `minItems: 1`; `storage` const
  `github-lfs`); `schemas/grade-v3.schema.json` (`submissionId` required).
- **Defect:** gate 8 says "manual grade entry may still work" when LFS delegation
  fails. But `grades.submission_id` is `NOT NULL` with a foreign key to
  `submission_attempts`, and a submission needs at least one LFS file.
- **Resolution:** add an offline assessment record (graded work done outside
  the platform). Grading no longer depends on the LFS proof of concept.
- **ADR:** [0007](../../docs/adr/0007-offline-assessment-records.md).

## E6 Auto-grading approval cannot store the release policy or grading repo

- **Status:** accepted (owner, 2026-11-21) (optional feature, deferred to M8)
- **Affected:** `docs/AUTOMATIC_GRADING.md` lines 7 and 17;
  `db/0002_commerce_autograding.sql` lines 76-86.
- **Defect:** the document says the D1 approval includes "the workflow path,
  exact approved commit SHA, timeout, rate limits and allowed release policy"
  and that the owner "connects a private, owner-controlled grading repository".
  `grading_config_approvals` has no release-policy column and no grading
  repository column. Its primary key is `(course_id, assignment_id)`, so a
  re-approval overwrites the previous one.
- **Resolution:** add an approvals-history table with the missing columns.
- **ADR:** none yet.

## E7 Error envelope, idempotency and status codes are defined two or three ways

- **Status:** accepted (owner, 2026-11-21)
- **Evidence:** partly. The envelope and idempotency conflicts hold. The status
  code conflict holds for errors. For success codes, the prose states none
  except 204 for `auth/session`; only `api/openapi.yaml` varies (`200`, `201` at
  lines 167, 210, 260, 273, `202` at 244, `204`). That is a missing rule, not
  two rules.
- **Affected:** `docs/ERROR_FAILURE_SEMANTICS.md` line 3;
  `docs/API_SEMANTICS.md` line 5; `FULL_SPECIFICATION.md` line 570;
  `api/openapi.yaml` lines 41-53; `docs/API_V3_DTO.md` lines 27, 49, 62;
  `docs/ERROR_FAILURE_SEMANTICS.md` line 8; `db/` (no idempotency table).
- **Defect:**
  - Envelope: `ERROR_FAILURE_SEMANTICS.md` gives `{code, message, requestId,
    retryable, retryAfterSeconds?, details?}`. `API_SEMANTICS.md` and OpenAPI
    `ApiError` omit `retryable`.
  - Idempotency: "`Idempotency-Key` (UUID)" header in `API_SEMANTICS.md`, but
    `"idempotencyKey"` in the body in `API_V3_DTO.md`. No SQL table stores keys.
  - Status codes: `API_SEMANTICS.md` uses 400 for invalid input and 422 for a
    malformed manifest. `API_V3_DTO.md` uses 422 for "invalid inputs" and adds
    503 and 500. `ERROR_FAILURE_SEMANTICS.md` adds 413, 415, 507 and 503.
- **Resolution:** one envelope (`code, message, requestId, retryable,
  retryAfterSeconds?, details?`), the `Idempotency-Key` header with an
  `idempotency_keys` table, one status table, and success codes 200, 201, 202
  and 204 by operation type.
- **ADR:** none yet. Covered by M1 and M3.

## E8 Grade integrity

- **Status:** accepted (owner, 2026-11-21)
- **Affected:** `db/0001_init.sql` lines 69-80 and 101-124.
- **Defect:** `grades.submission_id` references `submission_attempts(id)` alone.
  Nothing ties that submission to the grade's own `course_id`, `assignment_id`
  and `uid`. `submission_attempts` has no unique key on `(id, course_id,
  assignment_id, uid)` to reference. `grade_events` has no foreign keys.
- **Resolution:** add that unique key and a composite foreign key. Write the
  grade and its audit row in one atomic D1 `batch()`.
- **ADR:** none yet. Interacts with E5 (offline records have no submission).

## E9 Catalog TTL conflict and three upload-state vocabularies

- **Status:** accepted (owner, 2026-11-21)
- **Affected:** `docs/CACHING_PERFORMANCE_COST.md` lines 12 and 52;
  `api/openapi.yaml` line 481; `docs/CORE_EXPERIENCE_AND_CATALOG.md` lines 50
  and 53; `FULL_SPECIFICATION.md` lines 621 and 995;
  `docs/ERROR_FAILURE_SEMANTICS.md` line 7; `db/0001_init.sql` lines 76 and 91.
- **Defect:**
  - TTL: class C allows `max-age=60` plus `stale-while-revalidate=120`, a serve
    age of up to 180 s. OpenAPI says "TTL<=60s" and CACHE-004 says "within 60s".
  - Upload states: `new, reserved, uploading, uploaded, verified, submitted`
    (`FULL_SPECIFICATION.md` 621); `reserved, transferring, verifying,
    submitted` (`ERROR_FAILURE_SEMANTICS.md` 7); SQL attempt status `reserved,
    uploading, submitted, failed, cancelled` and reservation state `reserved,
    uploaded, verified, finalized, expired, failed`.
- **Resolution:** cap the catalog's total serve age at 60 s. Use the SQL
  vocabulary for upload states.
- **ADR:** none yet.

## E10 Pages has no Cron Triggers, Workers Logs or Rate Limiting binding

- **Status:** accepted (decision D2)
- **Evidence:** the provider fact comes from the Cloudflare migrate-from-pages
  matrix, fetched 2026-11-21. It is not in the bundle and will be recorded in
  `docs/research/`. The bundle side holds: it needs a scheduler and names Pages
  throughout.
- **Affected:** scheduler need: `docs/EU_PRIVACY_COOKIES.md` line 10 (PRIV-004
  "scheduled cleanup"), `db/0001_init.sql` line 154 ("retention ... outside this
  initial migration"). Pages wording: `docs/ARCHITECTURE.md` lines 13, 14, 24,
  26, 62; `FULL_SPECIFICATION.md` lines 143, 144, 154, 156, 192, 786, 1021;
  `docs/CACHING_PERFORMANCE_COST.md` lines 10, 38, 58; `AGENTS.md` lines 10, 20;
  `docs/COST_MODEL_FINAL.md` line 4.
- **Defect:** retention, expiry and DSAR jobs need a scheduler, and public
  routes need rate limiting. Pages Functions provide neither.
- **Resolution:** one Worker with static assets and a `scheduled()` handler.
  Read `pages.dev` as `workers.dev`. `docs/ARCHITECTURE.md` line 14 already
  allows "Worker bound to `/api/*` under the same hostname".
- **ADR:** [0002](../../docs/adr/0002-one-worker-with-static-assets.md).

## E11 Free D1 limits against per-request session writes

- **Status:** accepted (owner, 2026-11-21)
- **Evidence:** partly. The D1 limits (100k writes a day, 50 queries per
  invocation, 500 MB per database) come from D1 pricing and limits pages
  fetched 2026-11-21, not from the bundle. The bundle never says "write
  `last_seen` on every request". It stores `last_seen_at` and an idle expiry of
  30 minutes, which implies a write on use.
- **Affected:** `docs/SESSION_SECURITY.md` line 7; `FULL_SPECIFICATION.md`
  line 512; `db/0001_init.sql` lines 61-67 (`web_sessions`).
- **Defect:** a naive implementation updates `last_seen_at` on every
  authenticated request. At the free write limit that caps daily traffic.
- **Resolution:** throttle session touch writes to at most one per 15 minutes
  (within the 30-minute idle window). Batch queries. Track database size.
- **ADR:** none yet. Covered by M3.

## X1 v2 to v3 migration is demanded but impossible

- **Status:** proposed
- **Affected:** `FULL_SPECIFICATION.md` lines 346 and 770;
  `docs/V3_UPGRADE_AND_RELEASE_GATES.md` line 7; `docs/SEMANTIC_VALIDATION.md`
  line 4; `schemas/` (v3 files only).
- **Defect:** line 770 asks for "an explicit validated v2-to-v3 migration" and
  the upgrade note says a v2 course is "migrated through validation". The bundle
  contains no v2 schema, template or example. The only trace of v2 is the typo
  in E4. Line 346 says an unknown future version stays read-only "until a
  migration tool exists".
- **Resolution:** drop the migration. Reject any `schemaVersion` other than 3.
- **ADR:** none needed.

## X2 The archived baseline contradicts same-origin `/api`

- **Status:** proposed
- **Affected:** `docs/ARCHIVED_INFRASTRUCTURE_BASELINE_V3.md` lines 57, 59, 66,
  68 (separate `workers.dev` or `api.<domain>` API with CORS), against
  `docs/ARCHITECTURE.md` line 14 and `FULL_SPECIFICATION.md` line 1021.
- **Defect:** the appendix describes a cross-origin API. Its first line says it
  is "HISTORICAL ONLY AND MUST NOT BE IMPLEMENTED WHERE IT CONFLICTS WITH v3.1".
- **Resolution:** ignore the file. Precedence item 6 ranks archived material
  last. `spec/INDEX.md` omits its `REQ-*` headings.
- **ADR:** none needed.

## X3 Missing routes

- **Status:** proposed
- **Affected:** `api/openapi.yaml` (46 operations; none of the below);
  `docs/ARCHITECTURE.md` lines 32 and 43; `docs/RELEASE_TESTS_V4.md` (V4-CORE-03);
  `docs/CORE_EXPERIENCE_AND_CATALOG.md` line 36; `docs/COMPLIANCE_API.md`
  line 13.
- **Defect:** the text needs routes that OpenAPI lacks:
  - invites: invite-only enrollment "reject[s] without invite"
    (`API_SEMANTICS.md` line 20), but nothing creates or redeems one;
  - profile: only `GET /auth/me` (line 79); `users` holds names
    (`db/0001_init.sql` lines 4-12) with no write route;
  - staff file retrieval: `GET .../submissions` lists attempts; no route returns
    a file;
  - refresh and repin: V4-CORE-03 and `CACHING_PERFORMANCE_COST.md` line 30
    ("staff `Refresh`") have no route;
  - GitHub callbacks: user-to-server authorization and App installation
    (`ARCHITECTURE.md` line 32) have no callback; only `POST /github/webhook`;
  - `GET /api/courses/{id}` (`CORE_EXPERIENCE_AND_CATALOG.md` line 36);
  - `GET` and `POST /api/admin/accessibility-issues` (`COMPLIANCE_API.md`).
- **Resolution:** add each route in the errata OpenAPI fork in the milestone
  that needs it.
- **ADR:** none yet.

## N1 COM and GRA test IDs are defined three ways

- **Status:** proposed
- **Affected:** `FULL_SPECIFICATION.md` lines 756-766; `docs/SECURITY_TESTS.md`
  line 53; `docs/AUTOMATIC_GRADING.md` lines 59-66.
- **Defect:** the same IDs mean different tests. GRA-002 is "untrusted student
  manifest or file cannot enable/inject a workflow" in the specification,
  "workflow only after signed owner approval" in `SECURITY_TESTS.md`, and
  "launches only the owner-approved workflow ... for a finalized student
  attempt" in `AUTOMATIC_GRADING.md`. The specification has GRA-001 to 005,
  `SECURITY_TESTS.md` 001 to 006, `AUTOMATIC_GRADING.md` 001 to 008. COM-006 is
  "no web checkout/external checkout CTA ... without policy review" in the
  specification and "free courses never require processor" in `SECURITY_TESTS.md`.
  SEC, UI and OPS IDs are identical in both files.
- **Resolution:** cite these IDs with the file, for example
  `AUTOMATIC_GRADING:GRA-002`. Treat `AUTOMATIC_GRADING.md` (eight cases) as the
  working set for GRA. For COM, trace both lists.
- **ADR:** none needed.

## Gaps found while writing the threat model and ROPA (2026-11-21)

All `proposed`; the owner decides each before the milestone named.

| ID | Gap | Evidence | Needed by |
|---|---|---|---|
| N2 | PRIV-001 lists email as personal data, but `users` in `db/0001_init.sql` has no email column. Decide whether D1 stores email at all; Firebase already holds it. | `spec/v4.0/docs/SECURITY_TESTS.md` PRIV-001; `spec/v4.0/db/0001_init.sql` `users` | M3 |
| N3 | No retention period is given for any D1 table; only session lifetimes (12 h absolute, 30 min idle) are stated. | `spec/v4.0/docs/EU_PRIVACY_COOKIES.md`, `SESSION_SECURITY.md`, `db/0003_compliance.sql` | M7 |
| N4 | `SESSION_SECURITY.md` names an "auth state version" that `web_sessions` has no column for. | `spec/v4.0/docs/SESSION_SECURITY.md`; `spec/v4.0/db/0001_init.sql` `web_sessions` | M3 |
| N5 | **Accepted 2026-11-21:** images stored in the course repository load normally; images from other hosts show a placeholder the reader taps to load, like the video consent gate. Originally: no rule covers a course README that loads images from author-hosted servers, which exposes readers' IP addresses to third parties without consent. Options: proxy images through the pinned repo only, or click-to-load like video. | `spec/v4.0/docs/EU_PRIVACY_COOKIES.md` §15.2 covers video only | M2 |
| N6 | No decision on revoking Lectale sessions when a Firebase account is disabled or deleted. | `spec/v4.0/docs/SESSION_SECURITY.md` | M3 |

## Validator interpretations (accepted by the owner, 2026-11-21)

Where the spec is ambiguous, the course.yaml validator (`apps/edge_api/src/contract/`) applies these rules. Details are in `docs/research/2026-11-21-m1-validator-codex-notes.md`.

| ID | Rule | Why |
|---|---|---|
| V1 | Outline IDs are unique across the whole course, not only within their list. | Unique IDs make resource addresses unambiguous (E2) and catch copy-paste mistakes. |
| V2 | `releaseAt` takes part in the date-ordering check. | A resource released after its own deadline is an authoring error. |
| V3 | An assignment that no lesson references is an error. | Unreachable assignments would never be shown to students. |
