> **V3 extension:** This document MUST be read with `COMMERCE_AND_ACCESS.md`, `AUTOMATIC_GRADING.md` and `COMMERCE_COSTS.md`; any older non-goal excluding payments or automatic grading is superseded. Course YAML version 3 is authoritative.

# API behavior, exact security expectations and responses (v3)

HTTP API under same-origin `/api` on Pages Functions/Workers. All JSON requests/responses use UTF-8. Cursor pagination for lists with maximum `limit=100`. Common error JSON: `{ "code":"FORBIDDEN", "message":"...", "requestId":"opaque" }`. Response codes: 400 invalid input, 401 unauthenticated, 403 not authorized, 404 not found/not reveal private existence, 409 state conflict, 413 size exceeded, 422 malformed manifest, 429 throttled, 502 GitHub/provider failure. No secrets in error bodies. All mutating calls carry `Idempotency-Key` (UUID) and are replay-safe within 24 hours.

| Method + route | Auth/access | Semantics |
|---|---|---|
| `POST /api/auth/session` | Firebase ID token plus trusted Origin | Verify signature/claims; create opaque web session and HttpOnly host-only cookie; respond 204 |
| `GET /api/auth/me` | web cookie or native Bearer | Identity and visible profile, no secrets |
| `GET /api/auth/csrf` | cookie web session | Return per-session anti-CSRF token, `no-store`; not needed for native Bearer |
| `POST /api/auth/logout` | signed-in | Revoke D1 session(s), clear cookie |
| `GET /api/courses` | public | Paginated public published course catalog from D1; indexed only, no per-item GitHub fetch |
| `POST /api/courses/import` | public for public URL only | Strict `https://github.com/<owner>/<repo>` URL; resolve and preview read-only manifest; ownership NOT asserted |
| `POST /api/courses/register` | signed-in + verified GitHub admin | Register draft after admin rights and installation verification; stable numeric repo ID |
| `POST /api/courses/{id}/initialize` | verified owner | Explicit idempotent scaffold commit with user confirmation |
| `POST /api/courses/{id}/publish` | verified owner | Validate pinned SHA/manifest, snapshot enrollment/upload policy and activate |
| `GET /api/courses/{id}/manifest` | public or authorized private | Return validated manifest with pinned SHA/ETag; do not leak private repo URLs |
| `GET /api/courses/{id}/content/{resourceId}` | policy-aware | Resolve resource by validated manifest ID; stream private bytes with Range, safe headers, no secret token URLs |
| `POST /api/courses/{id}/enroll` | signed-in | Open: active; approval: pending; invite-only: reject without invite |
| `PATCH /api/courses/{id}/enrollments/{uid}` | owner or instructor | approve, reject, revoke (allowed transitions only, audit) |
| `POST /api/courses/{id}/submissions/reserve` | active enrolled student | file list `(name,size,sha256,mime)` + assignment ID; validate limits and reserve upload paths, signed direct actions only |
| `POST /api/courses/{id}/submissions/{submissionId}/finalize` | same student | check provider object metadata/size/checksum as available, close reservation idempotently, commit pointer when GitHub LFS |
| `GET /api/courses/{id}/submissions` | student self / staff | student sees own attempts; staff sees course-scoped list; no arbitrary UID query escalation |
| `PUT /api/courses/{id}/grades/{assignmentId}/{uid}` | authorized grader | body `(submissionId,status,score,maxPoints,feedback,expectedRevision)`; update + append grade event transaction, prevent concurrent edits |
| `GET /api/courses/{id}/grades/my` | active enrolled student | own graded/returned records only |
| `POST /api/courses/{id}/certificates` | verified owner/instructor | issue based on policy and valid D1 records; snapshot name/course/version, stable opaque ID |
| `GET /api/certificates/{id}` | public verification | reveal only bounded public certificate fields and status; never transcripts by default |
| `POST /api/github/webhook` | HMAC verified webhook secret | Verify signature before parsing; dedupe GitHub delivery, revalidate pinned course SHA on relevant change |

**Session contracts:** `Authorization: Bearer <Firebase ID Token>` supported for native. Web uses same-origin `__Host-course_session` cookie plus `X-CSRF-Token` for mutation and strict Origin check. Do not trust a request `uid` when identity is available; resolve from cookie/Bearer.

**Reservations:** API returns an opaque `reservationId` plus provider-scoped URL and required headers ONLY when they cannot grant broader repo/object access. Do not leak GitHub installation tokens. The Git LFS adapter has a hard release gate; there is no alternative storage provider. Large file bytes never pass through `/api` on standard path.

**Records:** consistent UTC timestamp strings, unique IDs, optimistic concurrency (revision) and D1 transactions; no destructive edits of submitted attempts. One user cannot infer another student exists through 403-vs-404 details.
