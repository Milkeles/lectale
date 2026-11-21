# Task plan: Lectale

| | |
|---|---|
| **Covers** | Whole repository. The milestones and reasons are in `docs/adr/` and in the approved plan in `docs/plan.md`. |
| **Last reviewed** | 2026-11-21 |

Every task gets a spec in `spec/tasks/` that opens with the intake gate (Why / Simpler / Ready-made / Security / Verify) before work starts. One task is one sentence; if it needs two sentences, split it.

## Waiting on the owner

- [ ] Protect `main` in GitHub settings against force-pushes and deletion (not "require pull requests": agents merge directly by the owner's choice), and move `LITSE_UI_DEPLOY_KEY` into an Actions environment that only `main` can use. Hooks can't stop a pushed workflow from reading a repository secret; only these server-side settings can.

- [ ] litse-ui stays a dependency, and Lectale work is pushed only to `Milkeles/lectale`. When a screen needs a component litse-ui lacks, decide where it is built: in litse-ui by the owner, or by an agent with the owner's go-ahead.

- [ ] Review `spec/errata/ERRATA.md` and mark each entry accepted or changed.
- [x] Create the read-only deploy key `LITSE_UI_DEPLOY_KEY` so CI can fetch litse-ui (steps in `docs/runbooks/litse-ui-deploy-key.md`).
- [ ] M2: Cloudflare account and an API token (template "Edit Cloudflare Workers" plus D1 Edit).
- [ ] M2: Create the GitHub App from the manifest the edge engineer prepares.
- [ ] M3: Firebase project on the Spark plan, Web app, Authorized Domains.

## M0 Foundations

- [x] Import spec bundle v4.0 into `spec/v4.0/`; the bundled Python tests pass.
- [x] AGENTS.md, CLAUDE.md, the agent team in `.claude/agents/`.
- [x] Skills in `.claude/skills/` (vendored with licences, plus local ones).
- [x] ADRs 0001–0010, errata register, `spec/INDEX.md`, traceability skeleton.
- [x] Research ledger of the facts the plan relies on.
- [x] Toolchain pins (`.config/mise.toml`), `justfile`, prek hooks, `tool/check_rules.py`.
- [x] Claude Code hooks in `.claude/settings.json` that run the rule check and block risky commands.
- [x] Dart workspace with `apps/flutter_client` (six platforms). Packages are added when a milestone needs them, not before.
- [x] Worker: `apps/edge_api` (Hono, static assets, health route, Vitest in workerd).
- [ ] CI: spec tests, Worker tests, Flutter analyze/test, builds; actions pinned by SHA.
- [x] Threat model and ROPA stubs.
- [x] Codex review of M0; high findings fixed (guard bypasses, rule-check gaps, key lifetime in CI) plus headers, release network permissions, reviewer tools.
- [ ] Follow-ups from the Codex review: route and test bare `/api` and asset routing through Wrangler; per-operation limits (catalog max 50, session 204) in the contract-first-api skill; correct ERRATA E1 (catalog PUT has a body) and INDEX precedence and traceability paths; build matrix only for platform changes.

## M1 Contract

- [x] Corrected OpenAPI in `spec/errata/openapi.yaml`, linted in CI (E1, E7).
- [ ] TypeScript manifest validator: size cap, YAML 1.2 without aliases or tags, schema v3, semantic rules.
- [ ] Fixtures: one pass and one fail for every SEMANTIC_VALIDATION rule, plus attack fixtures.
- [ ] Generated TypeScript types and the Dart client, drift-checked in CI.

## Spikes (in parallel with M1)

- [ ] S1: Git LFS delegated upload proof of concept. The flag stays off if it fails.
- [ ] S2: GitHub App authentication on Workers (`@octokit/auth-app` versus jose).
- [ ] S3: Content Security Policy that Flutter Web needs.

## Dependencies

| Task | Blocked by |
|---|---|
| M1 OpenAPI | Owner review of errata E1, E7 |
| M2 deploy | Cloudflare token, GitHub App |
| M3 | Firebase project |

## Completion

| | |
|---|---|
| **Convention** | Check a task off when its Verify command passes, and keep it until its milestone closes. Then move the milestone to `docs/milestones.md`. |
