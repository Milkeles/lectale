# V3.1 API contract extensions (same-origin, signed sessions / native bearer)

The endpoint list below extends `api/openapi.yaml`. Use stable errors and actor checks from `ERROR_FAILURE_SEMANTICS.md`. All public routes have rate limits and input bounds. Use signed CSRF for web mutations.

- `GET /api/legal/terms`, `GET /api/legal/privacy`, `GET /api/legal/cookies`, `GET /api/legal/accessibility` — public, versioned operator-reviewed documents; publication must be blocked if missing controller/operator identity or support contact.
- `GET /api/legal/cookie-settings` — current optional-purpose settings; no stateful tracking before consent.
- `PUT /api/legal/cookie-settings` — body `{purpose, provider?, granted, policyVersion}`; record versioned decision for non-essential processing, no blanket consent to necessary session cookies. Optional anonymous receipt uses a pseudonymous short-lived key rather than sensitive PII.
- `POST /api/legal/acceptances` — record scoped versioned acceptance of ToS/instructor terms/purchase terms; do not conflate acceptance with cookies. Require exact document version.
- `POST /api/privacy/requests` — user or verified contact submits request; responds with opaque case ID and due-date status. `GET /api/privacy/requests` lists own cases; admins see separately authorized queue.
- `POST /api/notices` — report allegedly illegal course/material, limited safe report fields. `GET /api/notices/{id}` returns only permitted report/status; staff moderation in trusted admin API with audit and reason.
- `GET /api/courses/{courseId}/description` — return sanitized root README at pinned SHA, public only if course is public and metadata permitted; for private/paid content require entitlement or staff role. Do not leak raw GitHub token/URL for private repo.
- `GET /api/instructors/lfs-guidance` — returned copy is sourced from current GitHub official policy; specifically explain included Free allowances (10 GiB storage and 10 GiB monthly download), owner billing and quotas, upload restrictions, throttling and source retention. Include provider link.
- `GET /api/admin/accessibility-issues`, `POST /api/admin/accessibility-issues` — staff only; report findings and remediation. No student grade access.

Never treat status messages or legal-policy text as a substitute for provider/legal verification.
