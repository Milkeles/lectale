# Appendix A. Previous infrastructure and cost requirements (preserved baseline)

> THIS APPENDIX IS HISTORICAL ONLY AND MUST NOT BE IMPLEMENTED WHERE IT CONFLICTS WITH v3.1. This appendix preserves the earlier approved requirements and cost notes. For implementation, the v3 definitions, security model, YAML schemas, API contracts and rendering requirements above take precedence where language differs. A historical sample YAML snippet is not normative. Recheck external provider rates before billing decisions.

## A.1 Executive decision

Recommended default: Cloudflare Pages (static Flutter Web) + Cloudflare Workers (trusted API) + Cloudflare D1 (relational metadata) + existing Firebase Authentication + instructor-owned GitHub repositories/GitHub App. Host videos through instructor-selected video providers. Preserve direct student-to-storage uploads as a requirement; do not relay large files through Workers.

Cost target: $0/month at small scale with no custom domain, assuming free-plan quotas and a secure GitHub LFS direct-upload integration. At larger scale, Workers Paid starts at $5/month. A custom domain adds registration/renewal fees. Git LFS delegation is PROVISIONAL until proven, so upload is unavailable if the gate fails.

# 1. Scope and assumptions

-   Public and optionally private courses can be imported by GitHub repository URL, with a versioned course.yaml manifest defining ordered lectures, materials and assignments.

-   Each lecture may contain an externally hosted recording, one or more PDF notes, supporting video/PDF links, and Jupyter notebooks for static viewing/download. No notebook execution, interactive lesson engine or prerequisites are required.

-   Students submit arbitrary authorized file types, including potentially hundreds-of-megabytes PDFs. Instructors grade manually. Certificates may be issued in students' real names.

-   Instructor repositories own source content. Platform metadata must remain small; no duplicate storage of large course files in D1.

-   The web client is statically deployed. Firebase is used only for authentication, not Firestore/Cloud Functions/Hosting.

# 2. Placement requirements

  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Component / data**                                  **Required service**                                **Cost / security rule**
  ----------------------------------------------------- --------------------------------------------------- ---------------------------------------------------------------------------------------------------------
  Web UI / Flutter Web                                  Cloudflare Pages                                    Static assets only; never run large media through Pages Functions.

  Flutter Android/iOS                                   App stores / direct distribution                    Call the same Workers API; no web hosting meter for native installs.

  Accounts, passwords, account recovery                 Standard Firebase Authentication                    Never store passwords/refresh tokens in D1; do not enable paid Identity Platform tier without need.

  API, permissions, GitHub integration                  Cloudflare Workers                                  Verify Firebase ID tokens; perform privileged GitHub operations; keep secrets server side.

  Profiles, enrollment, roles, metadata, certificates   Cloudflare D1                                       Indexed SQLite relational schema; minimal personal data; no PDFs/blobs.

  Course YAML, public notes, notebooks                  Instructor-owned GitHub repository                  Read public materials directly from GitHub; render PDFs/notebooks/videos inside Flutter.

  Private course materials                              Private GitHub repo + authenticated Worker          Never expose long-lived repo credentials; consider short-lived provider download URLs only when secure.

  Lecture recordings / supplemental videos              Instructor's video provider                         Embed YouTube/Vimeo/etc. no platform video transfer.

  Submissions, preferred                                Separate instructor-owned private GitHub LFS repo   Only if secure delegated direct-upload handshake passes acceptance tests; instructor pays GitHub.

  

  Canonical grades and certificate records              D1                                                  Only instructors / trusted API can modify; optional versioned GitHub exports.

  Secrets                                               Cloudflare Worker Secrets                           Prefer GitHub App installation credentials over professor PATs.
  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 3. Domain and deployment variants

## 3.1 No custom domain --- minimum cash cost

-   Publish static Flutter Web at https://\<project\>.pages.dev. Deploy the API at https://\<worker\>.\<account\>.workers.dev, or configure a Pages /api/\* function route if desired; dynamic requests still count toward Workers quotas.

-   Add the actual pages.dev origin to Firebase authorized domains and to API CORS allowlists; secure native app origins separately. Test Firebase sign-in flow under deployed hostname.


-   Monthly domain cost \$0. Platform cost remains subject to Workers and D1 quotas.

## 3.2 Custom domain --- same deployment, only registrar fee changes

-   Acquire a domain at a registrar; annual price varies by TLD. Configure app.example.com for Cloudflare Pages and api.example.com or app.example.com/api for Workers. No special Pages plan is needed to connect a domain.

-   Update Firebase authorized domains and API CORS to the custom origin. Enforce HTTPS, set response security headers, and configure cookie scopes if applicable.

-   Keep the free pages.dev subdomain available for test/rollback or redirect it to the canonical domain. Domain cost = registration/renewal fee / 12 when reporting a monthly equivalent.


# 4. Core functional requirements

## REQ-01 Account and identity

Use standard Firebase Auth for email/social login. Worker MUST validate token signature, issuer, audience, expiry and appropriate authorization state on protected requests; identify the user by Firebase UID.

## REQ-02 Real-name profiles

D1 MUST store display/certificate legal-name fields separately from authentication. Names are self-reported until an explicit verification process exists. Snapshot certificate recipient name on issue.

## REQ-03 Course import

Client MAY parse public course.yaml for preview. Registration/ownership claims MUST require verified GitHub repository admin/installation access. Store stable GitHub repository ID and manifest path in D1.

## REQ-04 Course content

Course manifest MUST use schemaVersion and immutable logical IDs for lessons and assignments. Paths MUST be repository-relative, canonicalized and validated against traversal and unexpected URLs.

## REQ-05 Materials UI

Flutter MUST render PDF, video embeds/players, Markdown and read-only .ipynb previews in-app where feasible; provide explicit download/open-external fallbacks. Video bytes MUST come from provider, not Workers.

## REQ-06 Enrollment

D1 MUST support public/open, public/restricted, private/restricted and invite-only policies. Enrollment states pending/active/rejected/revoked; enforce at every protected endpoint.

## REQ-07 Submissions

A trusted Worker MUST reserve an upload for authenticated UID+course+assignment, enforce size/attempt/type limits, mint a unique destination and log an expiry. Never accept arbitrary destination paths or return privileged GitHub tokens.

## REQ-08 Finalization

Worker MUST confirm an upload exists with the expected size/object hash, validate attempt ownership and atomically change metadata status. For Git LFS, create pointer/metadata commits only after confirmation; handle retries idempotently.

## REQ-09 Grade security

Instructors and designated graders only can create/update official grades. Students can read only their own grading data. Record score, max score, rubric/feedback, grader UID and audit timestamp.

## REQ-10 Certificates

Only trusted instructor-authorization flow may issue/revoke a certificate. D1 record MUST include opaque certificate ID, recipient-name snapshot, course/version, issuer, issue date and revoked status.

## REQ-11 Media privacy

Public course files SHOULD load directly from GitHub and video hosts. Private files MUST be served only after authorization and without leaking repository access tokens; test cache-control and range requests for large PDFs.

## REQ-12 Cost guardrails

Do not proxy user-uploaded binaries through Workers in the default design. Maintain course-level file-size, attempt and retention caps; rate-limit requests and configure account spending limits/alerts.

## REQ-13 Operational resilience

Handle deleted/renamed/private repositories, revoked GitHub installations, API rate limits, upload expiry and failed commits. Never treat Git commit author text as an authentication source.

## REQ-14 Data management

Offer account export/deletion, retention policies and deletion of submissions where contractually and technically possible. Keep D1 audit/certification records independent of mutable course repository paths.

# 5. Direct upload security: release gate

The proposed Git LFS solution is not approved merely because the Git LFS standard describes an upload action. Before production, test GitHub itself with personal-account and organization-owned private repositories, native Flutter and Flutter Web; inspect every returned header and URL for the absence of broadly reusable repository credentials.

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Test**               **Passing criterion**
  ---------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------
  Token scope            Browser receives only narrowly scoped object-upload authorization, NEVER GitHub App/PAT/installation repository credentials.

  Object isolation       Client cannot upload to another object, tamper with another student's files, or reuse authorization beyond its intended object/expiry.

  Web compatibility      Browser CORS succeeds for the actual GitHub LFS upload destination; mobile also succeeds.

  Size enforcement       Oversized and modified-content attempts are blocked/flagged; server validates object size and digest, and provides cleanup and rate limits.

  Durability             Uploaded LFS bytes plus committed pointer are accessible by instructor with the expected private permissions; recoverable after interrupted upload.

  No Worker data relay   Network trace confirms full file bytes travel device-to-storage, not through the Worker.
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------


# 6. Required D1 data model (minimal)

  ---------------------------------------------------------------------------------------
  users(uid PK, first_name, middle_name?, last_name, certificate_name, created_at)\
  courses(id PK, owner_uid FK, github_repo_id, repo_url, manifest_path,\
  repo_visibility, enrollment_policy, github_installation_id, created_at)\
  course_staff(course_id, uid, role, PRIMARY KEY(course_id, uid))\
  enrollments(course_id, uid, status, requested_at, approved_at?, PK)\
  submission_attempts(id PK, course_id, assignment_id, uid, attempt_no,\
  storage_provider, object_ref, content_sha256, size_bytes, status,\
  reserved_at, expires_at, finalized_at?)\
  grades(id PK, submission_id, score, max_score, feedback_ref?, grader_uid, graded_at)\
  certificates(id PK, course_id, uid, recipient_name, course_commit,\
  issued_at, revoked_at?)\
  audit_events(id PK, actor_uid, action, resource_id, created_at)
  ---------------------------------------------------------------------------------------

  ---------------------------------------------------------------------------------------

-   Index all foreign keys and common filters: enrollments(uid, status), enrollments(course_id, status), submissions(course_id, assignment_id, uid), courses(owner_uid).

-   Write explicit migration files. Set uniqueness constraints on GitHub course ownership mapping and (course, user, assignment, attempt_no). Use randomized/opaque public IDs rather than predictable paths.

-   Tiny course-level metadata fits D1. Avoid writing a log row for every static content view; avoid full-table scans billed as rows read.

# 7. Portable course manifest — superseded by v3 authoritative grammar

The complete general-format definition is in the main section "Full portable YAML contract v3". For machine verification use `schemas/course-v3.schema.json` plus `docs/SEMANTIC_VALIDATION.md`. New repositories MUST NOT generate legacy v1 manifests.

# 8. Operating limits and monitoring

-   Workers Free: 100,000 dynamic requests/day and 10 ms CPU per invocation. Workers Paid: \$5 account minimum, including 10M requests and 30M CPU-ms per month; beyond that \$0.30/M requests and \$0.02/M CPU-ms. Monitor both request and CPU metrics. \[CF-WORKERS\] \[CF-W-LIMITS\]

-   D1 Free: 5M rows read/day, 100K rows written/day and 5 GB total storage. On free tier, hitting daily limits can cause queries to fail. Paid includes 25B read rows/month, 50M written rows/month and 5 GB. \[CF-D1\]

-   Pages static traffic is free/unlimited but Pages Free limits include 500 builds/month, 20,000 site files and 25 MiB per static asset. Keep course PDFs off Pages. \[CF-PAGES\] \[CF-P-LIMITS\]

-   Cloudflare spending limits and alerts are mandatory before enabling any paid plan. Set aggressive Worker CPU limits and rate limits, test quota exhaustion, and retain an observability budget.

-   Public GitHub requests are subject to GitHub availability/rate limits; cache only public course manifests/metadata when beneficial; do not cache private grades or PDFs publicly.


Workload model: 40 Worker requests, 80 indexed D1 rows read and 4 rows written per monthly active student; 5 ms Worker CPU/request; 30-day month with even traffic; D1 total under 5 GB; ordinary Firebase Auth only; large files bypass the API. The result is a planning estimate, not a guaranteed quote.

  ----------------------------------------------------------------------------------------------
  **Active students/mo**   **API requests/mo**   **No domain**   **Domain @ \$12/y**
  ------------------------ --------------------- --------------- -------------------------------
  100                      4,000                 \$0.00          \$1.00 (example)

  1,000                    40,000                \$0.00          \$1.00 (example)

  10,000                   400,000               \$0.00          \$1.00 (example)

  50,000                   2,000,000             \$0.00          \$1.00 (example)

  100,000                  4,000,000             \$5.00          \$6.00 (example)

  250,000                  10,000,000            \$5.40          \$6.40 (example)

  1,000,000                40,000,000            \$17.40         \$18.40 (example)
  ----------------------------------------------------------------------------------------------

Domain column uses a purely illustrative \$12/year example (\$1/month equivalent): for any real domain price D USD/year, replace that term with D/12. A free pages.dev + workers.dev deployment has \$0 domain cost. GitHub storage, email/SMS add-ons and app-store fees are excluded. \[CF-REG\]

# 10. Acceptance and decision checklist

-   P0: Public course import/render works without Worker calls on each PDF/video view.

-   P0: Authentication token verification and role enforcement pass cross-user access tests.

-   P0: GitHub repository ownership proof and private file access are secure.

-   P0: Direct Git LFS upload security/compatibility test passes before upload feature launch; never expose professor token.

-   P0: Per-course upload quotas, attempts, file validation, and cleanup are enforced.

-   P1: Manual grading, audit history and immutable issued certificate records work.

-   P1: Test web deployment with free subdomains AND with custom domain, including Firebase authorized-domain and CORS settings.

-   P1: Run cost/load tests with 1K, 10K and 100K-equivalent request patterns; adjust CPU assumptions after measurement.

# Sources and verification links

\[CF-WORKERS\] Cloudflare Workers pricing. <https://developers.cloudflare.com/workers/platform/pricing/>

\[CF-W-LIMITS\] Cloudflare Workers limits. <https://developers.cloudflare.com/workers/platform/limits/>

\[CF-D1\] Cloudflare D1 pricing. <https://developers.cloudflare.com/d1/platform/pricing/>

\[CF-PAGES\] Cloudflare Pages Functions pricing and static request rules. <https://developers.cloudflare.com/pages/functions/pricing/>

\[CF-P-LIMITS\] Cloudflare Pages platform limits. <https://developers.cloudflare.com/pages/platform/limits/>

\[CF-DOMAINS\] Cloudflare Pages custom domains. <https://developers.cloudflare.com/pages/configuration/custom-domains/>

\[CF-REG\] Cloudflare Registrar pricing. <https://pricing.registrar.cloudflare.com/>

\[FB-AUTH\] Firebase Authentication overview and upgraded-tier distinction. <https://firebase.google.com/docs/auth>

\[FB-TOKENS\] Firebase ID token verification. <https://firebase.google.com/docs/auth/admin/verify-id-tokens>

\[GH-APP\] GitHub App installation and account types. <https://docs.github.com/en/apps/using-github-apps/installing-a-github-app-from-a-third-party>

\[GH-LFS\] GitHub LFS billing. <https://docs.github.com/en/billing/concepts/product-billing/git-lfs>

\[GH-LIMITS\] GitHub repository limits. <https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits>

\[LFS-BATCH\] Git LFS batch API specification. <https://github.com/git-lfs/git-lfs/blob/main/docs/api/batch.md>

\[LFS-BASIC\] Git LFS basic transfers specification. <https://github.com/git-lfs/git-lfs/blob/main/docs/api/basic-transfers.md>


Provider prices, quotas and product limits can change. Recheck all primary-source links before launch and at each major pricing review.
