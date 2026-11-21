# Cache/security/performance contract — V4 normative

## Goals and measurements
Minimize provider API calls, D1 rows read, Worker CPU, GitHub rate-limit load, repeated content downloads, frontend bundle bytes, and learner latency without ever using a shared cache for secrets or personalized educational records. Caching is an optimization, not a source of authority. Instrument request counts, response bytes, cache hit rates, D1 `meta.rows_read/rows_written`, GitHub rate headers, Worker CPU, 4xx/5xx and owner-sourced LFS bandwidth where available. Do not log full course files, credentials or student submissions.

## Shared-cache policy by data classification

| Class | Examples | Shared edge caching | Browser caching | TTL/invalidation |
|---|---|---|---|---|
| A — Static app | hashed Flutter JS/WASM/assets | Yes (Pages) | `public, max-age=31536000, immutable` on fingerprinted files | filename-hash changes on build; keep entrypoint short TTL |
| B — Public immutable course | validated public README, YAML, PDFs, notebook static cells keyed by repo numeric ID + SHA + safe path | Yes, only if unambiguously public and no auth-dependent response | `public`, bounded max-age; prefer immutable URL | SHA changes -> new cache key; do not overwrite old published SHA |
| C — Public mutable catalog | opted-in teaser metadata, non-sensitive filters/search | Yes | `public` short TTL + ETag | `max-age=60`, optionally `stale-while-revalidate=120`; purge/listing revision when changing |
| D — Open repository preview | public schema summary / immutable validated manifest for unclaimed repo | Yes after validation, rate-limited | short | 5 min for repo metadata lookup, SHA-key content longer; negative lookup <= 30 s |
| E — Authenticated shared course state | enrollment check, session-specific private document, private README, paid content | **Never** in shared edge cache | `private, no-store` by default | permissions checked on every request |
| F — Academic records | grades, submissions, certificates with restricted fields, billing & purchase records | **Never** | `private, no-store` | no cache; D1 authoritative |
| G — Capability secrets | GitHub app tokens, delegated upload actions, session IDs, Stripe secrets | **Never** | no-store, redact logs | keep transient, expiry enforced |

The shared-cache eligibility rule is DENY by default. A response must be explicitly classified A-D and must have no `Set-Cookie`, `Authorization`-dependent body, enrollment/entitlement dependence, or sensitive data. Cache keys cannot contain an access token, session, email, Firebase UID, or untrusted raw URL. For anonymous catalog reads, explicit listing data is safe; sessions/credentials arriving on a catalog request MUST NOT cause user-specific content in the response.

## Exact cache keys
- `catalog:v1:<normalized_q>:<language>:<category>:<price>:<cursor>:<revision>` for SAFE public-only data; bound normalized values and max key length. Prefer digest when large; never hash raw Authorization.
- `public-course:v1:<github_repo_id>:<40-character_commit_sha>:<normalized_resource_path>:<renderer_version>`; URL input resolved via GitHub API, safe canonical repo id and path, no arbitrary upstream URL proxy.
- `repo-preview:v1:<owner_lower>:<repo_lower>` only for public ref lookup with max 300 s; content cache always SHA-keyed.
- `list-meta:v1:<course_id>:<catalog_revision>` for public teaser.
No cross-tenant cache collisions; multi-host cache keys must include an explicit canonical deployment scope if same Worker serves multiple origins. Never key by mutable branch name only.

## Request path and limits
1. On public course open: resolve once to stable repo ID + last known valid SHA, fetch validated manifest/README for that SHA, and render referenced resources; do not call GitHub separately to determine each file path if manifest already maps them.
2. On public catalog load: one D1-backed paginated query on miss; zero GitHub calls per card; batch author metadata from safe snapshots; `ETag` and 304 for client refresh, short cache TTL. D1 row scan must be index-backed and measured, not assumed.
3. On webhook: authenticate GitHub HMAC signature; enqueue/idempotently validate changed commit; publish new SHA only after validation; update safe listing metadata only when listed and owner-approved public fields haven't been changed without consent. Invalidate catalog cache by version or purge. If webhook missed, allow staff `Refresh` with bounded conditional requests and Github `ETag/If-None-Match`; don't poll all repositories.
4. On public resource fetch: prefer direct source CDN URL with verified owner/repo/commit/path and CORS compatibility. If not feasible, Worker may fetch/stream, never Buffer whole multi-GB file; caching only under public immutable key. Track GitHub source bandwidth/rate limits.
5. On private resource read: authenticate THEN authorize enrollment/entitlement THEN stream with `Cache-Control: private, no-store`; allow `Range` where supported and enforce source-file path. Never send a long-lived private GitHub token or response with public cache headers.
6. On LFS upload: never cache upload actions, reservations, commit responses or digests as authorizations. Upload gating remains disabled until proven safe; failed upload must not create grade or paid entitlement.

## Workers Caching vs Cache API and pricing
Use **Workers Caching** (new front-of-Worker cache, when supported in the chosen deployment route) for public GETs if observed CPU/D1 benefit; use Cache API only when explicit control is needed and verify its per-datacenter behavior. Workers Caching hits can bypass Worker execution, but **Cloudflare still charges the Worker request** at the published request rate; hits reduce CPU and backend origin calls. Source: https://developers.cloudflare.com/workers/cache/ and https://developers.cloudflare.com/workers/platform/pricing/ .

Static assets that are served as native Cloudflare Pages static requests (not invoking Worker) remain free/unlimited under the applicable static Pages terms. Avoid putting the entire app behind a catch-all Worker or a `/*` Pages Function: doing so would convert static visits into billable dynamic requests. Functions must match `/api/*` and explicitly selected routes ONLY.

## Additional frontend savings
- Fingerprint assets, lazy-load PDF/notebook/player packages on demand where Flutter build layout allows; test initial JS/WASM network budget and browser caching.
- For video, embed only after user interaction/required consent; no platform video bandwidth; never cache or rehost paid video yourself.
- PDF range/chunked loading and viewport-driven rendering; no full-size document held in memory; download pause/resume handled by client if provider supports it.
- Course outline normalized once; client in-memory state prevents duplicate API calls during a navigation session; avoid persistent caching of sensitive content, particularly on shared devices.
- Bounded pagination, request coalescing, debounce search at 250-400ms, avoid endless retries and polling; use GitHub webhooks and conditional reads.
- No analytics vendor, custom crawler, KV subscription, or image transformation service by default. Only enable an additional product if measured demand justifies its cost and privacy implications.

## Security & failure tests
CACHE-001: Anonymous public catalog can be shared without leaking any session/personally identifiable or private repository data.
CACHE-002: Requesting same private PDF as two users never returns the other's content, even after first response and across two hostnames.
CACHE-003: Revoked enrollment or refunded payment denies private content on the very next check; cache cannot revive access.
CACHE-004: Unlisted course vanishes from catalog within 60s target (purge if available), while direct link remains functional.
CACHE-005: Different GitHub commits produce different cache keys, old valid commit remains available for older grading context.
CACHE-006: Every authenticated grade/checkout, session, GitHub token or LFS URL returns `Cache-Control: no-store`; service workers do not persist them.
CACHE-007: Under 1000 repeated visits to same public course, GitHub manifest/README fetches do not scale one-for-one once warmed.
CACHE-008: Measured cache hit %, Worker request count, Worker CPU and D1 scanned rows validate that caching saves upstream work. Cached worker requests remain in request billing model.
CACHE-009: Stale catalog price never overrides server offer and checkout amount.
CACHE-010: Static Flutter request does NOT execute Pages Function in production; integration test verifies route matching.
