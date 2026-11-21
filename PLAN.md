# Task plan: Lectale

| | |
|---|---|
| **Covers** | Whole repository. The milestones and reasons are in `docs/adr/` and in the approved plan in `docs/plan.md`. |
| **Last reviewed** | 2026-11-21 |

Every task gets a spec in `spec/tasks/` that opens with the intake gate (Why / Simpler / Ready-made / Security / Verify) before work starts. One task is one sentence; if it needs two sentences, split it.

## Waiting on the owner

- [x] **Logo:** the owner chose 01 Ribbon Cut (2026-11-21). SVGs are in `docs/ux/brand/logo-01-ribbon-cut-*.svg`. The colour follows the palette decision below.
- [x] **Palette:** the owner chose mulberry on warm paper (2026-11-21), so the logo is `logo-01-ribbon-cut-mulberry.svg`. The owner asked for one accent that catches the eye; it is golden ochre (`#905E0C` light, `#F3DDA4` dark), used only for the primary button, the ribbon and the focus ring (`docs/ux/token-plan.md`, study in `docs/ux/brand/accent-study.md`). Say if you'd rather have deep teal or ink blue.
- [x] **Mulberry, slightly more purple:** the owner asked for it; the hue moved 8° (now `#753E5E` light, `#E0A7C0` dark) at the same contrast. The logo SVG uses the new value. **Keyboard:** the owner asked that everything works by keyboard; the rule and its tests are in `docs/ux/inventory.md` (Keyboard).
- [x] **Reading font:** the owner chose Source Serif 4 (2026-11-21), which has Bulgarian letterforms in roman and italic (ADR-0012).
- [ ] **Create the GitHub App sooner rather than later.** Anonymous GitHub API calls allow only 60 per hour per IP, so a deployed preview would run dry quickly. The App's installation token allows at least 5,000 per hour. Whether that token can read public repositories the App isn't installed on is still unverified; it's the first thing to test once the App exists.
- [ ] **Decide where the missing components live** (app bar, skip link, breadcrumb, list row, tree, scrollable tabs, progress). Until you say otherwise, they're built inside Lectale on litse-ui's foundations, without Material, so they can move into litse-ui later.

- [ ] After M2 deploys and production CPU is measured: decide how to handle validation CPU on the Free plan (errata N7: cap course size, $5/month Paid plan, or a faster YAML parser).

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

## M2 tooling for visual and accessibility checks

The owner can't test with screen readers or on real devices, so accessibility is checked by tools, and the accessibility statement says so.

- [ ] Widgetbook catalog of Lectale screens and states (as in devchat-frontend). The design reviewer screenshots every use case in light and dark, at three widths and at large text.
- [ ] `accessibility_tools` overlay in debug builds and the catalog. First check whether its 48×48 tap-area default can be set to WCAG 2.2's 24×24, as litse-ui uses.
- [ ] Widget tests use Flutter's contrast, tap-target and label guideline matchers.
- [ ] axe-core and a browser accessibility-tree snapshot run on the web build in CI.

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
