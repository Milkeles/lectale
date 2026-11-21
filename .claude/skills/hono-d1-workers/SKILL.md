---
name: hono-d1-workers
description: Conventions for Lectale's edge API on one Cloudflare Worker with Hono and D1. Use when writing or reviewing Worker code, wrangler.jsonc, run_worker_first, static assets, scheduled() cron handlers, Hono middleware order, D1 migrations, prepared statements, batch(), D1 Free-plan limits, secrets, outbound fetch, Cache API, or Vitest tests with applyD1Migrations.
---

# Hono and D1 on Workers

One Worker serves the Flutter static build and the `/api/*` routes, so there is one deploy, one hostname and one set of `__Host-` cookies. The rules below keep it inside the free plan and inside the security baseline.

## Layout

```
apps/edge_api/
  wrangler.jsonc        # assets, d1_databases, triggers.crons, compatibility_date
  migrations/           # NNNN_name.sql, created by wrangler
  src/index.ts          # export default { fetch: app.fetch, scheduled }
  src/routes/ src/middleware/ src/db/ src/github/
  test/
```

```jsonc
"assets": { "directory": "../flutter_client/build/web", "binding": "ASSETS",
            "run_worker_first": ["/api/*"] }
```

- `run_worker_first` as an array runs the Worker only for those patterns; every other request is served from assets without invoking the Worker (at most 100 entries). This keeps static traffic free and satisfies V4-CACHE-04. Never use `true` or a `/*` pattern.
- Export both handlers from one module, as Hono documents:
  `export default { fetch: app.fetch, scheduled: async (controller, env, ctx) => {...} }`.
  The cron handler runs retention, expiry and DSAR jobs. Test it locally with `GET /cdn-cgi/local/scheduled?format=json` on the dev server.
- Type bindings with `wrangler types --env-interface CloudflareBindings` and `new Hono<{ Bindings: CloudflareBindings }>()`.

## Middleware order

Hono runs middleware in registration order; code after `await next()` runs in reverse. Register in this order, and say why in a comment if you change it:

1. request ID (`hono/request-id`): every later log line and error body carries it.
2. secure headers (`hono/secure-headers`): applies to all responses, including errors. It sets no CSP by default; configure `contentSecurityPolicy` explicitly.
3. rate limit (Rate Limiting binding for general limits, D1 counter for auth): reject cheaply before doing work.
4. session/auth: read `__Host-course_session`, hash it, look up the D1 session; or verify the bearer token (native).
5. CSRF on `POST/PUT/PATCH/DELETE`: exact `Origin` match plus session-bound `X-CSRF-Token`. Hono's built-in `csrf()` only checks form content types, so it does not cover JSON; write our own.
6. ACL, default deny: a route with no declared policy answers 404/403. Allow only what a route lists.

An uncaught error is caught by Hono and passed to `app.onError`, so `next()` never throws. Map errors to the canonical `ApiError` envelope in `onError`.

## D1

- Create and apply with Wrangler, using the database name (the binding name can change):
  `npx wrangler d1 migrations create <DATABASE> <message>` then
  `npx wrangler d1 migrations apply <DATABASE> --local`.
  Production uses `--remote` and needs the owner's explicit go-ahead.
- Never edit a migration that has been applied anywhere. Applied files are tracked by name in `d1_migrations`; an edit silently diverges environments. Add a new migration instead.
- Use prepared statements with `.bind()`. Never build SQL by string concatenation (SQL injection).
- D1 has no interactive transactions. `db.batch([...])` runs its statements as one transaction and rolls back all if one fails. Use it for any multi-statement write (grade plus audit row, purchase plus entitlement, session rotation).
- Free-plan limits (check the page again before relying on them): 50 queries per Worker invocation (a whole `batch()` counts as one), 100,000 rows written per day (indexes add a written row; resets 00:00 UTC), 500 MB per database, 100 bound parameters per query, 2 MB per row.
- So: do not write `last_seen` on every request (touch at most once per 15 minutes), batch reads, and record `meta.rows_read/rows_written` in tests for hot paths.
- Each database is single-threaded; keep queries short and indexed.

## Workers rules

- No `eval()` or `new Function`; Workers block them. Avoid libraries that generate code at runtime (Ajv).
- Node APIs: compatibility dates from 2026-08-04 enable `nodejs_compat` by default, so check that a dependency is not quietly pulling Node polyfills in. Prefer Web APIs (`fetch`, WebCrypto, `crypto.subtle`). If Node APIs are needed, record why in an ADR.
- Secrets: `npx wrangler secret put <NAME>`. Local development uses `.dev.vars` (git-ignored). Never put secrets in `vars`, D1, YAML or the Flutter bundle.
- Outbound `fetch` goes only to an allowlist (`api.github.com`, `raw.githubusercontent.com`, Firebase JWKS host, Stripe API when enabled). Build URLs from IDs, never from manifest strings (SSRF).
- Cache API: only for public immutable data (cache classes A to D), keyed by repo ID plus commit SHA. A response with `Set-Cookie` is never stored by the Cache API. Personal data answers `Cache-Control: private, no-store`.
- Free plan allows 50 subrequests per invocation; coalesce GitHub calls.

## Testing

Use `@cloudflare/vitest-plugin` (the `cloudflareTest()` Vite plugin). The older package `@cloudflare/vitest-pool-workers` is deprecated and renamed to it on npm. Tests run in workerd.

- In `vitest.config.ts`, read migrations with `readD1Migrations("migrations")` and pass them as a test-only binding.
- In a setup file call `applyD1Migrations(env.DB, env.TEST_MIGRATIONS)`.
- Call `reset()` from `cloudflare:test` in `afterEach` to delete data from all bindings. Storage is isolated per test file, not per test.
- Call the app with `exports.default.fetch(request)` (from `cloudflare:workers`). It does not serve assets.
- Every route gets: allowed role, denied role, anonymous, and cross-user (IDOR) cases.

Sources (fetched 2026-11-21): developers.cloudflare.com/d1/platform/limits, /d1/platform/pricing, /d1/reference/migrations, /d1/worker-api/d1-database, /workers/wrangler/commands/d1, /workers/static-assets/binding, /workers/runtime-apis/web-standards, /workers/runtime-apis/nodejs, /workers/runtime-apis/cache, /workers/runtime-apis/handlers/scheduled, /workers/configuration/secrets, /workers/testing/vitest-integration/{configuration,test-apis} (all with index.md appended); hono.dev/docs/guides/middleware, /docs/getting-started/cloudflare-workers, /docs/middleware/builtin/{csrf,secure-headers,request-id}; registry.npmjs.org (deprecation notice). Not verified by fetch: Rate Limiting binding semantics, exact Workers Free CPU limits.
