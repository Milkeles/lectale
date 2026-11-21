> **V3 extension:** This document MUST be read with `COMMERCE_AND_ACCESS.md`, `AUTOMATIC_GRADING.md` and `COMMERCE_COSTS.md`; any older non-goal excluding payments or automatic grading is superseded. Course YAML version 3 is authoritative.

# Architecture and operational contract (v3, normative with extensions)

## Platform vision and non-goals

A portable, repository-centric course publisher and learner interface. A creator owns a GitHub repository containing the versioned course manifest (`course.yaml`) and materials. The application resolves course links, safely renders the ordered manifest on Flutter Web and native Flutter, and supports enrollment, file submissions, manual grading and optional certificate issuance. A valid public repository can be previewed by URL without registration or GitHub permission. Managed publishing, private content, grading and certificates require verified repository administration and platform authorization.

A course can cover any subject, not just programming. The frontend MUST render PDFs, videos, `.ipynb` notebooks (static viewer), Markdown, images, common text/code formats and audio in-app. Other arbitrary files must still appear as resource cards with metadata/download; a promise of rendering all proprietary binaries is impossible. The platform SHALL NOT run notebooks or student code in Workers/Flutter. Optional owner-funded GitHub Actions grading is enabled only under the approval and isolation rules in `AUTOMATIC_GRADING.md`; no quizzes/prerequisite engine.

## Deployment placements

- Flutter Web compiled assets -> Cloudflare Pages static hosting. Native Flutter apps use the same API.
- Dynamic routes -> same-origin Cloudflare Pages Functions with D1 bindings, or equivalently Worker bound to `/api/*` under **the same hostname**. A Pages Function consumes Workers quota. Avoid separate API subdomains for web unless essential.
- Firebase Auth -> identity provider only. Standard auth; avoid SMS/optional Identity Platform upgrade unless independently justified.
- D1 -> users/profile name, course/repo registry, instructor roles, enrollment, session hashes, upload reservations, immutable submissions/grades, certificate snapshots, audits.
- GitHub App -> selected GitHub repositories; installation signing key in Worker Secrets; installation tokens minted server-side with restricted `repository_ids` and `contents` permissions and never returned to users.
- Content Git repository -> course.yaml and teaching material files. Separate private submissions Git repository -> LFS pointer file/optional YAML exports if Git LFS backend chosen.
- Video recordings -> course-creator's video host (YouTube/Vimeo/etc); iframe only for approved providers.
- Large uploads -> direct to instructor-owned Git LFS only after a verified object-scoped delegation test. No insecure client repository tokens. If unsupported, block oversized uploads with an actionable error. Never relay large files through Workers.

## Domain variants

No custom domain: use `https://<project>.pages.dev/` and same-host `/api/` functions. Firebase Authorized Domains and GitHub App callback URLs must include the exact published host; test redirects and logout. Domain fee $0. Static hosting within Pages free static limits; API within Workers/D1 pricing.

With custom domain: configure e.g. `https://courses.example.com/` in Cloudflare Pages and DNS. Use `/api/*` on same host, update Auth authorized domains and all GitHub OAuth/app callback URLs. Host-only `__Host-` cookies are not shared between the custom domain and `pages.dev`: pick a canonical host, redirect the other, expire old sessions as needed. Pricing difference is registrar annual renewal, not a mandatory Pages subscription.

## Repository onboarding by URL

1. User pastes canonical GitHub HTTPS repository URL; read-only public repo preview does not register them as owner. Normalize to stable numeric repository ID; avoid URL/path SSRF and path traversal.
2. Verify `course.yaml` at a chosen commit via safe parsing and v3 schema/semantic validation. Render preview without allowing edit; show actionable errors.
3. To claim/publish the course, require platform login plus **GitHub user-to-server authorization** and verify admin rights to that exact repo. A guessed repo URL, an app installation ID query parameter, or a public `course.yaml` must never assign ownership.
4. Instructor explicitly installs GitHub App on selected repositories. Grant contents read for content; contents write only for approved scaffolding/metadata, and necessary permissions on private submissions. Confirm selected repo IDs server-side.
5. If manifest missing, instructor clicks `Initialize`; create only missing `course.yaml`, `README.md`, allowed scaffold, with idempotency/concurrency checks. Never overwrite files or alter unrelated repositories.
6. If a separate private submission repo is needed, prompt to select one; attempt automatic creation **only through an authenticated GitHub token/endpoint proven to support it**, with explicit consent. A GitHub App installation alone is not guaranteed to create a personal account repo. If unsupported, instruct owner to create one and install App.
7. Validate user-controlled policies, take a D1 snapshot of effective server restrictions, pin last-valid SHA, then publish. Revalidate on webhook; invalid subsequent commit does not replace known-good published manifest.
8. Repo transfer/removal or revoked installation pauses privileged operations and prompts owner to reconnect; preserve course ID and academic records.

## Access-control model

- Public content: anyone, even unauthenticated, can preview. Public course can still restrict *enrollment*.
- Private content: only active enrollment or authorized course staff, including source/URL resources; no browser GitHub repository token.
- Open enrollment: immediate active enrollment. Approval: creates pending request; authorized instructor decides. Invite: invite code or instructor action; no uncontrolled self-enroll.
- Owner: course policy, staff, grading, certificate authority and repo registration. Instructor: assigned course management and grading as granted; TA/grader: explicitly scoped abilities. Student: own submissions only and own grades only.
- YAML is never an ACL or source of staff authority; D1 and verified GitHub rights govern.
- Avoid sensitive legal names or emails in GitHub exports. Public certificate verification reveals only permitted name/title/date/status and never grades by default.

## Storage, authorship and billing

Use D1 for authoritative private student records and optional private YAML export for portability. Do not put private grades in a public content repo. Course creator owns storage/streaming bills for their GitHub content and third-party videos. The instructor is the repository owner and pays for their Git LFS storage and download usage. No large file service is operated by the platform.

## Performance and caching

- Statically host Flutter bundle on Cloudflare Pages with fingerprinted caching; deploy immutable assets with long-lived caching and HTML entry with shorter TTL.
- Cache validated public manifest keyed by repository ID+commit SHA at edge or D1 only if cost-effective; avoid repeated GitHub API calls per component. Cache private resources only in appropriately private scopes; `Cache-Control: private, no-store` for sensitive responses.
- Pin references to commit SHA; respect GitHub API rate/abuse limits and backoff. Avoid per-resource polling and use signed webhooks to refresh.
- Large PDFs should use byte-range requests if supported. Do not download whole multi-hundred-MB files into app memory. Use streaming and cap concurrent previews.
- Never proxy huge files through Firebase, Workers or D1; use direct provider transfers when securely possible.

## Browser/native specifics

Web: `pages.dev` or custom domain serves static and `/api` on same origin; use secure HttpOnly opaque cookie sessions and CSRF checks. Native: Firebase ID Bearer tokens on all protected API calls, stored only via the platform's secure Firebase Auth SDK/OS keychain, not homegrown plaintext local preferences.

See `docs/SESSION_SECURITY.md`, `docs/RENDERING_REQUIREMENTS.md`, `docs/SEMANTIC_VALIDATION.md`, `api/openapi.yaml`, and `db/0001_init.sql`.
