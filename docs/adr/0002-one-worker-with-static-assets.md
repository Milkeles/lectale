---
status: accepted
date: 2026-11-21
---

# One Worker with static assets instead of Pages plus Functions

## Context and problem statement

The spec hosts Flutter Web on Cloudflare Pages and the API in Pages
Functions (`spec/v4.0/docs/ARCHITECTURE.md`, "Deployment placements"). The
same section allows an equivalent: a "Worker bound to `/api/*` under the same
hostname". The spec requires same-origin `/api`, `__Host-` cookies
(`spec/v4.0/docs/SESSION_SECURITY.md`, point 4) and a $0 deployment with no
custom domain (V4-COST-03).

Three facts, fetched on 2026-11-21 from developers.cloudflare.com, change the
choice:

- The Pages index says "Start new projects with Workers".
- Worker static assets are "free and unlimited". `run_worker_first:
  ["/api/*"]` runs the Worker only for `/api` requests.
- The Cloudflare migrate-from-pages matrix shows Pages has no Cron Triggers,
  no Workers Logs and no Rate Limiting binding. Workers Logs is on the Free
  plan at 200k events a day.

Lectale needs a scheduler for retention, upload expiry and DSAR jobs
(`spec/v4.0/docs/EU_PRIVACY_COOKIES.md`, PRIV-004 "scheduled cleanup";
`spec/v4.0/db/0001_init.sql`, last comment). It also needs rate limits on
public routes. This is erratum E10.

## Decision drivers

- V4-CACHE-04: no catch-all function may bill static traffic as dynamic.
- A scheduler is required (retention, expiry, DSAR).
- Same-origin `/api` and a $0 Free plan stay as they are.
- One deployable for a solo operator.

## Considered options

- Pages with Functions, as the spec words it.
- One Worker with static assets, `run_worker_first: ["/api/*"]`, and a
  `scheduled()` handler.
- Pages for the web app and a separate Worker for the API and cron.

## Decision outcome

Chosen option: "one Worker with static assets", because it is the only
option that gives Cron Triggers, Workers Logs and the Rate Limiting binding
on the Free plan with one deployable. Only `/api/*` runs Worker code. Static
requests are served as assets.

The spec's `pages.dev` wording becomes `workers.dev`. This is a wording
change, not a conflict: ARCHITECTURE.md already allows the Worker variant.
The affected lines are listed in erratum E10 in
[`spec/errata/ERRATA.md`](../../spec/errata/ERRATA.md).

### Consequences

- Good, because retention, expiry and DSAR jobs run from the same Worker.
- Good, because static assets cost nothing and are not billed as Worker
  requests.
- Good, because the Hono router and the API share one deploy.
- Bad, because the spec text and the OpenAPI examples say Pages in many
  places. Agents must read them as the Worker variant.
- Bad, because the Rate Limiting binding is approximate by design. Auth
  routes also need a D1 counter.

### Confirmation

- An integration test requests a hashed static file in a deployed or
  workerd-emulated build and shows the Worker did not run (V4-CACHE-04,
  CACHE-010).
- `wrangler.jsonc` is reviewed for `run_worker_first: ["/api/*"]`.
- CI deploys with Wrangler from GitHub Actions.

## More information

Hono is the router; `scheduled()` is in the same Worker. Revisit if the Free
plan limits (Workers requests, D1 writes) block the cost targets in
`spec/v4.0/docs/COST_MODEL_FINAL.md`. Related: ADR-0004 (why deploys run in
GitHub Actions).
