# Lectale — delivery plan and multi-agent workflow

## Context

Lectale implements the *Portable Course Platform — Technical Requirements Specification v4.0* (PDF plus bundle with schemas, SQL, OpenAPI and AGENTS.md). Students open a public GitHub course repository by URL and read the README, outline, PDFs, notebooks, video, audio and code inside a Flutter app. Instructors can claim and manage courses, and students enrol, submit and get graded. Paid courses and Actions-based grading are optional.

One person builds and runs it, so the goals are low recurring cost, low operating burden and verified security and accessibility. The target repo is `Milkeles/lectale` (MIT, empty). The client builds on the owner's component library `devchat_ui` (litse-ui, Apache-2.0, currently private) and follows the conventions of `Milkeles/devchat-frontend`:
- pub workspace, Riverpod, go_router
- swagger_parser with dio
- mise, just and prek
- release-please
- MADR-style ADRs

What the owner asked for:
- **Specialised agents with skills.** A specialised agent team, each with skills suited to its job, working alongside Codex (GPT).
- **Cost and prompting.** Model routing, RTK and skill discovery, with prompts written to Anthropic's guidance.
- **Build vs buy.** Before writing anything over about 200 LOC, rate its difficulty and look for an existing solution.
- **Fetched sources only.** Internet facts come from fetched pages, never memory.
- **Platforms and UI.** A modern, attractive, accessible UI on web, Android, iOS, Linux, Windows and macOS.
- **Docs.** Documentation guided by `Milkeles/software-doc-templates`.

---

## 1. Findings that change the plan

### 1.1 Spec defects

E1–E9 were found independently by both reviewers (a Claude agent and Codex), so confidence is high. E10–E11 come from fact-checking the provider docs. Each one becomes an errata ADR in M0 for the owner to sign off.

| # | Defect | Evidence | Proposed resolution |
|---|---|---|---|
| E1 | OpenAPI is unusable for codegen | Only one operation declares path params (27 missing). There are no request bodies, and `manifest` has a stray key. Global `security` makes anonymous preview, public offers and legal docs require auth. | Fork as `spec/errata/openapi.yaml`. Fix the params, bodies and per-operation `security: []`, and lint in CI. |
| E2 | Resource ID scope collides | IDs are unique only per containing list, but the route is `/content/{resourceId}`. | Use a composite address `{lessonId}/{resourceId}`, or a path-scoped ID derived by the validator. |
| E3 | The anonymous preview has no content route or identity | Import returns a preview, but content routes need a D1 `courseId`. | Add `GET /api/preview/{repoId}/{sha}/…`: SHA-keyed content is public cache class B, the repo-to-SHA lookup class D (`CACHING_PERFORMANCE_COST.md`). |
| E4 | `schemaVersion` is "2" in prose, `const: 3` in the schema | Spec L247 and YAML_V3_REFERENCE versus the schema. | The schema wins, per the precedence rule. |
| E5 | Manual grading is promised with uploads disabled, but no record shape allows it | `grades` has a FK to a submission, and the submission schema requires LFS files. | **Owner decided:** add an "offline assessment" record (graded work done outside the platform), so grading doesn't depend on the LFS proof of concept (POC). |
| E6 | Auto-grading approval can't store the release policy or grading repo | Compare `0002` with AUTOMATIC_GRADING. | Add an approvals-history table (deferred; optional feature). |
| E7 | Error envelope, idempotency and status codes are each defined two or three ways | `retryable` is missing from ApiError. Idempotency is a header in one place and a body field in another. Success codes are 200 vs 201/202. | One canonical envelope (`code, message, requestId, retryable, retryAfterSeconds?, details?`), an `Idempotency-Key` header plus an `idempotency_keys` table, and 201/202. |
| E8 | Grade integrity | `grades` references a submission without tying it to its course, assignment and learner. | Composite FK and an atomic `batch()` with the audit row. |
| E9 | Catalog TTL conflict (SWR 120 vs ≤60s) and three upload-state vocabularies | Compare CACHING with openapi, and spec L621 with ERROR with SQL. | Cap the catalog's total serve age at 60s. Use the SQL vocabulary for upload states. |
| E10 | Pages has no Cron Triggers, Workers Logs or Rate Limiting binding, but retention, expiry and DSAR jobs need a scheduler | The Cloudflare migrate-from-pages matrix (fetched) | See decision D2. |
| E11 | Free D1 allows only 100k writes/day, 50 queries per invocation and 500 MB per database, yet the session design writes `last_seen` on every request | D1 pricing/limits pages (fetched) | Throttle session touch writes (at most one per 15 min). Batch queries. Track DB size. |

Also: v2→v3 migration is demanded but impossible (drop it), and the archived baseline contradicts same-origin `/api` (ignore it). Missing routes include invites, profile, staff file retrieval, refresh/repin and the GitHub callbacks; these get added in errata per milestone.

### 1.2 Verified build-vs-buy decisions (sources fetched; URLs in the research ledger)

| Capability | Use | Own glue | Why |
|---|---|---|---|
| API routing, Workers | **Hono** in one Worker with static assets (`run_worker_first: ["/api/*"]`) plus a `scheduled()` handler | ~200 | Hono's official Workers guide; Cloudflare's static-assets docs. |
| OpenAPI types | **openapi-typescript** (server), **swagger_parser** (Dart, the owner's ADR-0007) | — | Contract-first, generated from the fixed spec. |
| YAML + JSON Schema 2020-12 on Workers | **yaml** (eemeli, ISC) plus **@cfworker/json-schema** | ~40 + semantic rules ~600 | Ajv's runtime codegen needs `eval`/`new Function`, which Workers block; @cfworker states 2020-12 support. |
| D1 | **wrangler d1 migrations** plus thin typed helpers; FTS5 is available | ~150 | An ORM doesn't model FTS5, so the SQL is hand-written anyway. |
| Firebase ID-token verification | **jose** (`createRemoteJWKSet`) | ~80 | jose is multi-runtime and lists Workers. The Workers-specific library is single-maintainer and its revocation TODO is unchecked. |
| CSRF/headers | Hono `secureHeaders`, plus our own session-bound CSRF token | ~100 | Hono's `csrf` only covers form content types, not JSON. |
| Rate limiting | Workers Rate Limiting binding (soft), plus a D1 counter for auth | ~60 | The binding is approximate by design. |
| GitHub webhooks | **@octokit/webhooks** `verify()` | ~30 | The only Octokit package that states Workers support. |
| GitHub App JWT and installation tokens | Spike S2: `@octokit/auth-app` with fetch, else jose RS256 | ~150 | Workers support isn't documented. The key must be PKCS#8 (convert once, as a runbook step). |
| Actions grading provenance | GitHub OIDC tokens verified with jose | ~60 | Pin to `repository_id` and `job_workflow_ref`. |
| Certificates | JWS (ES256) via jose/WebCrypto | ~60 | — |
| Stripe | **stripe-node** (FetchHttpClient plus SubtleCrypto provider) with Checkout and Connect | ~150 + ledger | Hosted Checkout; no in-house payment or VAT handling. |
| Worker tests | `@cloudflare/vitest-pool-workers` with `applyD1Migrations` | ~50 | Runs in the real workerd runtime. |
| Markdown/README | **flutter_markdown_plus** (`flutter_markdown` is discontinued), **flutter_math_fork** (LaTeX) | ~300 | Raw HTML is not rendered. Relative links are resolved only within the pinned repo. |
| PDF | **pdfrx** (MIT, all six platforms, text selection and search) | ~200 | Needs Flutter 3.50 and pulls `material_ui`. Accessibility not documented, so a manual screen-reader test is required. |
| Notebook (.ipynb) | **Own renderer** (no Dart package exists; notebookjs is web-only and an XSS route) | ~500 | Recorded as an ADR exception to the 200-LOC rule. |
| Video | **youtube_player_iframe** (nocookie by default) behind our own consent gate. Vimeo and others start as a link card. | ~150 | No maintained Vimeo package. |
| Audio / image | **just_audio** / `InteractiveViewer` | ~150 | — |
| Auth UI | firebase_auth with `Persistence.NONE` on web; our own form from Dc components | ~250 | firebase_ui_auth pulls in shared_preferences, which breaks the no-browser-storage rule. |
| HTTP | dio (`withCredentials`) | ~80 | Matches the owner's stack. |
| Uploads | file_picker; chunking is our own, after the LFS POC | ~250 | No resumable-upload package verified. |
| a11y testing | flutter_test guideline matchers, devchat_ui theme audits, axe-core via Playwright on the Flutter Web semantics tree, and manual NVDA/VoiceOver/TalkBack passes | — | Automated checks cover roughly 57% of WCAG issues at most. |

**Fact-checked from docs fetched on 2026-11-21. These go into `docs/research/` in M0.**

| Fact | Source | Consequence |
|---|---|---|
| Flutter stable is 3.50.1 (2026-11-20). In-SDK Material/Cupertino are formally deprecated in 3.50, and `MaterialUiCompatibilityBridge` covers third-party packages. | docs.flutter.dev breaking-changes page; Flutter release feed | Pin Flutter 3.50.1. litse-ui's CI moves from 3.47.7 to 3.50.x first. |
| Cloudflare: "Start new projects with Workers". Worker static assets are "free and unlimited". `run_worker_first: ["/api/*"]` exists. Workers Logs is on Free (200k events/day). | developers.cloudflare.com (Pages index, static-assets billing, Workers Logs) | Decision D2. |
| Standard Firebase Auth has no MAU cap. The Identity Platform upgrade brings the 50k cap and billing. | firebase.google.com/pricing | Never upgrade to Identity Platform. No SMS sign-in. |
| `firebase_auth` has **no Linux** support, and Windows is "not intended for production". The Firebase Auth REST API is documented. | firebase.google.com/docs/flutter/setup, /docs/reference/rest/auth | Desktop sign-in (Linux/Windows) uses a small REST client (M3). Release 1 needs no auth, so it runs on all six platforms. |
| `youtube_player_iframe` has no Linux/Windows support. `just_audio` needs `just_audio_media_kit` on Linux/Windows. `pdfrx`, `file_picker`, `go_router`, `flutter_markdown_plus`, `flutter_math_fork` and `dio` cover all six platforms. | pub.dev API | On Linux/Windows, video shows a consent-gated "Open in browser" card. Audio adds the media_kit companion. |
| GitHub Free: 10 GiB LFS storage and 10 GiB bandwidth. There is **no documented** browser-scoped LFS upload credential. | docs.github.com | Expect the S1 LFS spike to fail. Uploads stay off. The offline-assessment record (E5) keeps grading working. |
| Stripe Managed Payments (Stripe as merchant of record) does **not** support Connect. With Connect, the platform or the connected account handles VAT; Stripe Tax only calculates. | docs.stripe.com (managed-payments, connect/charges, tax EU) | A legal and tax decision for M9, deferred and flagged. |
| skills.sh search API works via curl. The `npx skills` CLI hides network errors as "No skills found" (Node fetch ignores the proxy). | vercel-labs/skills source | The researcher searches `https://skills.sh/api/search?q=` with curl. Candidates found this way include `dart-lang/skills`. |

---

## 2. Decisions

- **D1 litse-ui (owner decided: stays private).** Lectale uses its components, and new ones are built there.
  - **Dependency:** Lectale pins devchat_ui as a git dependency by tag, released by release-please.
  - **CI access:** CI fetches it with a read-only deploy key held as a GitHub Actions secret.
  - **Deploys:** builds and deploys run in GitHub Actions (wrangler), so Cloudflare never needs the key.
  - **Fork PRs:** pull requests from forks get no secrets, so they run only the TS/contract jobs. That's acceptable for a solo project, and the README says so.
  - **First litse-ui work, driven by Lectale's screens:** a reading-oriented `DcStyle` (larger type, relaxed density, comfortable line length). Then the missing components in order of need: progress, toast, menu/popover, select, sidebar, breadcrumb, accordion, tree, skip link, sheet, slider, table, drop zone.
  - **References:** forui and shadcn_ui as API references only.
  - **Material:** it arrives transitively through go_router, pdfrx and youtube_player_iframe (via `material_ui`). It is confined to `resource_renderers` adapters and bridged to `DcTheme`.
- **D2 Hosting: one Worker with static assets** instead of Pages + Functions.
  - **Why:** Cloudflare's own docs say to start new projects on Workers. Static assets stay free and unlimited. `run_worker_first: ["/api/*"]` keeps only `/api` dynamic, which satisfies V4-CACHE-04. It also gains Cron (retention/expiry), Workers Logs and the Rate Limiting binding, none of which Pages has.
  - **Spec fit:** the spec's ARCHITECTURE.md already allows "Worker bound to `/api/*` under the same hostname". The `pages.dev` wording becomes `workers.dev` via an errata ADR.
  - **Unchanged:** same-origin `/api`, `__Host-` cookies and a $0 Free plan.
- **D3 Backend language.** TypeScript on Workers. Dart can't target the Workers runtime cleanly, and every verified library is JS.
- **D4 Validation is server-side only.** The client consumes validated DTOs. That removes a second (Dart) validator, saving about 1.5k LOC.
- **D5 First release (owner decided).** "Public course reader" = M0–M2b. Auth, managed courses and so on follow in order. Paid courses, auto-grading and the catalog stay off until the owner decides.
- **D6 Platforms: all six.**
  - **Release 1 targets:** web, Android, iOS, Linux, Windows and macOS. Release 1 has no auth, which removes the Firebase-on-Linux gap.
  - **CI runners:** ubuntu (web, Android, Linux), windows and macos (iOS, macOS). These are free for public repos.
  - **Fallbacks:** video on Linux/Windows uses an "Open in browser" card. Audio uses the media_kit companion.
  - **Desktop sign-in (M3):** the Firebase Auth REST API.
- **D7 Toolchain.** Flutter 3.50.1 (satisfies pdfrx and forui's ≥3.50), Node LTS and wrangler, all pinned in `.config/mise.toml`, as devchat-frontend does.

---

## 3. How work flows: feature intake gate (runs before every task)

The orchestrator writes each task as an *agent task specification* (from `software-doc-templates/ai-assisted-development`). The spec opens with a gate block. A task that can't fill in "Why" is dropped.

```
Why:        requirement IDs (V4-*, SEC-*, A11Y-*, spec §) it satisfies. None → drop it.
Simpler:    the smallest version that meets them; what we are NOT building (out of scope).
Ready-made: difficulty S/M/L/XL + estimated LOC. If >200 LOC or a well-known problem →
            link a researcher note (fetched sources, licence, maintenance, runtime fit) or an ADR exception.
Security:   trust boundaries touched, SEC/V4-SEC IDs, review required (security-reviewer + Codex)?
Verify:     exact command(s) + expected result; the acceptance IDs this closes.
```

State lives in the repo, not in chat, so any agent (Claude or Codex) can resume after a usage limit:
- `PLAN.md`: the task queue, with explicit blockers.
- `spec/tasks/*.md`: the active task specs.
- `docs/adr/`: MADR, as in devchat-frontend.
- `docs/research/`: fetched facts with URL and date, reused instead of re-researched.
- `docs/traceability.md`: requirement → test → commit, which the spec requires.
- `spec/INDEX.md`: requirement ID → bundle file/section, so agents read only what a task needs.

## 4. Agent team

The team lives in `.claude/agents/*.md`, with skills in `.claude/skills/`.

**Model routing.** There is no built-in router. The docs (code.claude.com sub-agents and model-config) offer only:
- the per-agent `model` / `effort` frontmatter,
- `CLAUDE_CODE_SUBAGENT_MODEL`,
- `opusplan`.

So the routing is this table plus `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` as the cheap default. Each agent prompt is short and written to Anthropic's prompting guidance (fetched from platform.claude.com):
- explicit role, scope, inputs, outputs and definition of done
- motivation given for each rule
- XML-tagged sections
- calm wording, without "CRITICAL"
- "investigate before editing"
- no over-engineering

Preloaded skills stay under about 600 lines per agent.

| Agent | Model | Writes code? | Preloaded skills (source) | Job |
|---|---|---|---|---|
| **orchestrator** (main session) | Opus | integrates | — | PM/integrator. Writes task specs with the gate, dispatches agents, merges, does final review, keeps PLAN.md. |
| **researcher** | Sonnet | no (read-only + curl) | local `build-vs-buy-lookup` | Fetch-only facts. Candidates with licence, maintenance and runtime evidence. Drafts ADRs. Never recalls from memory. |
| **contract-engineer** | Sonnet | yes (worktree) | local `contract-first-api` | Spec errata, OpenAPI fixes and lint, the TS validator, codegen (openapi-typescript, swagger_parser), attack fixtures. |
| **edge-backend-engineer** | Sonnet | yes (worktree) | cloudflare `workers-best-practices`, `wrangler`, `workers-development`; local `hono-d1-workers` | Workers/Hono/D1, sessions, GitHub App, caching. |
| **frontend-engineer** | Sonnet (high effort) | yes (worktree) | Anthropic `frontend-design`; flutter `flutter-build-responsive-layout`, `flutter-fix-layout-issues`; local `devchat-ui-usage`, `flutter-a11y-wcag22` | Screens, viewers, litse-ui components. Writes a token plan before any UI code. |
| **design-reviewer** | Opus (vision) | no | local `visual-review-loop`, `flutter-a11y-wcag22` | See the vision loop below. Separating the maker from the judge is what lifts quality. |
| **security-reviewer** | Opus | no | local `lectale-threat-checklist`; built-in `/security-review` | Required on every diff touching auth, ACL, sessions, tokens, untrusted rendering, uploads, cache headers or payments. Always paired with a Codex review. |
| **qa-engineer** | Sonnet | tests only | flutter `flutter-add-widget-test`, `flutter-add-integration-test`; local `devchat-ui-usage` (test harness) | Vitest on workerd plus D1, Flutter widget, golden and a11y tests, keeping the traceability matrix current. |
| **docs-pm** | Sonnet | docs only | local `lectale-docs` (which template when, the owner's writing principles, code-comment style) | ADRs, threat model, runbooks, ROPA, retention, incident plan, a11y statement. |
| **copywriter** | Sonnet, on demand | copy only | local `ui-copy` | Home and onboarding copy, empty states, errors, notices. |
| **commerce-engineer** | Sonnet, M9 only | yes | stripe `stripe-best-practices`, `connect-recommend` | Deferred until the owner enables paid courses. |
| **Explore** (override) | Haiku | no | — | Cheap codebase search. |

**Skills deliberately not preloaded:**
- VGV Bloc and Testing: BLoC/Material assumptions, but the owner uses Riverpod.
- flutter `setup-declarative-routing`: `MaterialApp.router`.
- flutter `use-http-package` and `implement-json-serialization`: the owner uses dio and swagger_parser.
- OpenAI `frontend-app-builder` in full: 4.5k words, React/Image Gen. Its rules are mined into `visual-review-loop` instead.

VGV Accessibility (WCAG 2.2, about 300 lines) is Material-centric. Its criteria and severity workflow are distilled into `flutter-a11y-wcag22`, with devchat_ui equivalents.

**Local skills.** Each is under about 150 lines and written with `skill-creator`'s guidance:
- third-person descriptions,
- progressive disclosure,
- three evals each.

**Design quality (the vision loop).**
1. frontend-engineer writes a token plan: a palette mapped to `DcColorTheme`, type roles, spacing scale, radii, motion, and the single memorable element. It then checks the plan against the anti-generic list from `frontend-design`.
2. It builds the UI.
3. design-reviewer captures the Flutter Web build with Playwright at 360, 768 and 1,440 px, light and dark, plus golden images for native layouts.
4. design-reviewer views the images and writes a fidelity ledger of at least five comparison points, with hard stops: clipping, type-scale drift, contrast, focus visibility, overflow, touch targets.
5. design-reviewer returns fixes.
6. Codex gets the same screenshots (`codex exec -i`) as a second opinion on screens that matter, such as home, course and viewer.

**Codex (GPT) has three roles.** It is dispatched through a small local `codex-dispatch` skill. M0 first evaluates the community "Codex Dispatch" and "codex-review" plugins, adopting one if it beats about 40 lines.
1. **Adversarial reviewer:** `codex exec --sandbox read-only` on security-sensitive diffs and on each milestone plan. The spec review showed the two models catch different things.
2. **Implementer:** well-specified, isolated tasks in a separate git worktree (`--sandbox workspace-write`), for example the notebook renderer, the LFS POC and fixtures. Claude reviews its output.
3. **Takeover:** when Claude usage runs out, Codex continues from `PLAN.md`, the task specs and `AGENTS.md`.
   - Standing instructions live in `AGENTS.md`, which Codex reads.
   - `CLAUDE.md` imports it via `@AGENTS.md` and adds only the Claude-specific routing, so the two never drift.
   - Note: Codex's ChatGPT login lives only in its container, so each new session needs a device-code login.

**RTK** (verified).
- **Install:** the official `install.sh`, or `cargo install --git https://github.com/rtk-ai/rtk`. Never plain `cargo install rtk`, which installs a different crate.
- **Hook into both agents:** `rtk init -g` for Claude Code and `rtk init -g --codex` for Codex. Both run as PreToolUse hooks.
- **Verify:** `rtk gain`.
- **Scope:** it compresses Bash output only. Agents use `rtk recall <hash>` or `rtk bypass <cmd>` to see the full output of a failure.
- **Licence:** the CLI is Apache-2.0, and the engine is BUSL but free for production use.
- **Setup:** added to the environment setup script.

**Skill sourcing.**
- **Vendor, don't preload plugins.** Docs don't confirm that `skills:` accepts `plugin:skill` names, and the VGV plugin's hooks block `flutter` shell commands. So third-party skills are **vendored** into `.claude/skills/`: copied with licence attribution, pinned to a commit and trimmed of Material/BLoC guidance.
- **Plugins for their MCP servers:** the official Dart and Flutter plugin (analyzer, pub, tests) and the Cloudflare plugin (docs search) are worth installing.
- **Searching for new skills:** the researcher queries `skills.sh/api/search` with curl for each new need. That is the "skill that finds skills", working around the CLI's proxy bug. The first check is `dart-lang/skills`.

## 5. Security baseline (enforced, not advisory)

Instruction files are followed "roughly 70%" of the time (software-doc-templates, citing Anthropic). So rules that must hold every time are enforced by hooks and CI.

**Hooks** (`.claude/settings.json`, via the `update-config` skill):
- **PostToolUse on Edit/Write:** format, plus `tool/check_rules`. It fails on:
  - `material.dart` imports outside `packages/resource_renderers/lib/src/adapters/`
  - `LFS_DIRECT_UPLOAD_ENABLED` set to true
  - `shared_preferences`, `localStorage` or IndexedDB used for credentials
  - `eval`/`new Function` in the Worker
  - raw HTML rendering of untrusted content
  - `fetch` to non-allowlisted hosts in the Worker
- **PreToolUse on Bash:** blocks force-push, production `wrangler deploy` / `d1 migrations apply --remote` without an explicit owner flag, and writes to `.dev.vars` or other secret files.

**pre-commit (prek, as in devchat-frontend):** gitleaks, typos, markdownlint, `dart analyze --fatal-infos`, `tsc --noEmit`, eslint.

**CI:**
- Bundled Python contract tests
- OpenAPI lint
- Vitest on workerd
- Flutter tests, goldens and a11y
- osv-scanner (both lockfiles)
- zizmor
- Actions pinned by SHA (the owner's ADR-0011)
- CodeQL (free for public repos)
- Dependabot

**Design rules:**
- **Untrusted-content rendering:** no HTML, scripts or iframes from course content. URLs are resolved only within the pinned repo or allowlisted video hosts.
- **Worker fetch:** GitHub API host allowlist only, which prevents server-side request forgery (SSRF).
- **YAML:** size cap, no aliases or tags.
- **Paths:** canonical-path checks.
- **Access control:** default-deny middleware, 404 masking, role tests per route.
- **Secrets:** only in Wrangler secrets and GitHub Actions; nothing secret in the Flutter bundle (`--dart-define` is public).

**Threat model** (STRIDE, from SECURITY_TESTS + SESSION_SECURITY): written in M0, and every task's "Security" field updates it. An M0 spike checks CSP for Flutter Web, which likely needs `wasm-unsafe-eval`.

**Agent safety:**
- Fetched pages and course repos are untrusted data, never instructions; agents are told this in their prompts.
- The researcher may write only to `docs/research/` (a prompt rule; it has Bash and Write for curl and notes), and its notes are reviewed before use.
- Agents never hold production secrets.
- Codex always runs sandboxed.

## 6. Code documentation and copy

The local `lectale-docs` skill holds the owner's writing principles (software-doc-templates CONTRIBUTING):
- plain language, important things first, short sentences, active voice, specific
- cut every word that doesn't change meaning

It adds Effective Dart doc rules and TSDoc, both fetched in M0.

**Code comments:**
- Dartdoc/TSDoc on every public API: purpose, contract, edge cases, and the spec ID where relevant (`/// Enforces SEC-021: …`).
- Inline comments explain *why*, never *what*.
- Comments follow the house style of devchat_ui's code.
- A banned-phrase list catches AI tells ("This function…", "robust", "seamlessly", "leverage", "comprehensive", decorative headers, emoji).
- Reviewers check this, and the `typos` and markdownlint config enforce part of it.

**Copywriter (`ui-copy` skill):** the owner's writing principles plus the UI-copy rules from `frontend-design`:
- sentence case
- verbs on buttons
- errors that say how to fix the problem

On *Making Websites Win*: it's a copyrighted book, so I won't pull a copy. The skill uses only what the authors publish openly, fetched and cited, plus notes the owner adds from their own copy. That book's conversion methods lean on analytics and A/B tests, which conflict with the spec's no-tracking default (COOKIE/V4-COST-06). Only the research and copy principles are used: customer language, a clear value proposition, answering objections.

## 7. Milestones

Each milestone ends with tests green, the acceptance IDs reported, a security and Codex review for sensitive work, and owner sign-off.

| M | Content | Exit criteria |
|---|---|---|
| **M0 Foundations** | Repo scaffold per the bundle's AGENTS.md layout (`apps/flutter_client`, `apps/edge_api`, `packages/{course_contract,resource_renderers,api_client}`, `infrastructure/{d1,cloudflare,github_app}`, `spec/`). Import the bundle verbatim into `spec/v4.0/`, plus errata E1–E11 as ADRs. Also: `spec/INDEX.md`, toolchain pins (mise: Flutter 3.50.1, Node, wrangler), just recipes, prek, CI. Agent team, vendored and local skills, hooks and RTK. PLAN.md, traceability skeleton, threat model, ROPA stub. litse-ui: move its CI to Flutter 3.50.x and tag a release. The deploy-key dependency is wired up. | CI green on an empty app on all six platforms; the bundled Python tests pass in CI; the owner has approved the errata. |
| **M1 Contract** (stage 1) | TS validator (`yaml` + `@cfworker/json-schema` + semantic rules ported from `validate_course.py`); attack fixtures (traversal, aliases, oversize, provider mismatch, duplicate IDs); corrected OpenAPI 3.1 + lint; generated TS and Dart types. | Every SEMANTIC_VALIDATION rule has a passing and a failing fixture; codegen is drift-checked in CI. |
| **S1 spike, in parallel** | LFS delegated-upload proof of concept on a real private test repo (Codex implements, security-reviewer judges). S2: GitHub App auth on Workers (octokit vs jose). S3: CSP for Flutter Web. | Written results. LFS stays OFF if the POC fails. |
| **M2 Public preview slice** (stage 2 core) | `POST /api/courses/import` + preview content route (E3), pinned SHA, cache classes B and D; Flutter home "Open a course from GitHub", README (Markdown + LaTeX), outline, text/code, images, download card; Lectale reading `DcStyle` + theme; deployed to `workers.dev` by GitHub Actions. | V4-CORE-01/02, the preview part of V4-SEC-03, and V4-CACHE-01/02/04 pass; design-reviewer ledger signed off. |
| **M2b Viewer suite + platforms** | PDF (pdfrx), notebook (own renderer), video consent gate, audio, folders; per-platform fallbacks; CI builds for web, Android, Linux and Windows, then iOS and macOS. | V4-CORE-05 on web plus one native platform; manual screen-reader pass. **Release 1: the public course reader.** |
| M3 | Firebase Auth, `__Host-` session plus CSRF, native Bearer, D1 migrations (with errata), ACL middleware (stage 3) | V4-SEC-01/02 |
| M4 | GitHub owner verification, App install, scaffold, publish/pin, webhooks, private content (stage 4) | V4-CORE-03/04/07, V4-SEC-04 |
| M5 | Enrollment: open, approval and invite; staff views (stage 5) | V4-SEC-06 |
| M6 | Submissions, only if S1 passed (stage 6) | V4-SEC-05/09 |
| M7 | Manual grading, certificates, retention cron, DSAR/notices (stage 7) | V4-CORE-06, V4-SEC-10 |
| M8–M10 | Optional (owner decides each): Actions grading, Stripe Connect, catalog | V4-SEC-07/08, V4-CAT-* |
| M11 | Custom domain, cost guards, penetration test, store submission | V4-COST-* |

## 8. Verification (how each step is checked)

- **Per task:** the "Verify" command in its spec, for example `just test-edge`, `just test-flutter`, `python spec/v4.0/tools/test_v4_contract.py`, or `npx vitest run apps/edge_api/test/import.test.ts`.
- **Per milestone:**
  - CI green, plus the acceptance IDs listed in `docs/traceability.md`.
  - Security-reviewer and Codex review reports attached to the PR.
  - Design-reviewer screenshot ledger.
  - Manual NVDA/VoiceOver/TalkBack passes recorded for the viewer screens.
- **Release 1 smoke:**
  - Paste a public fixture repo URL on the deployed `workers.dev` site.
  - README, outline and every viewer render; an unknown binary shows a download card.
  - Malformed YAML, a private repo, a traversal path and GitHub throttling each give a safe, privacy-neutral error.
  - The branch advancing does not change a pinned preview.
- **Cost check:** record Worker requests, CPU ms and D1 rows per preview against COST_MODEL_FINAL's assumptions before M3.

## 9. Accounts and access (owner actions, each just in time, least privilege)

**How access works.**
- **Secrets never go into chat.** Production secrets live in GitHub Actions secrets and Wrangler secrets, and deploys run from CI. That way agents (Claude and Codex) never hold production credentials.
- **For hands-on work in a cloud session,** a key is saved as a **network secret** via the secure form (`request_credential`): the proxy injects it into requests to that one host, and the agent never sees its value. Saving one also allows that host.

| When | What | Owner does | Agent receives |
|---|---|---|---|
| M0 | litse-ui access for Lectale CI | Create a **read-only deploy key** on `litse-ui-private`, and add its private half as the `LITSE_UI_DEPLOY_KEY` Actions secret in `lectale`. | Nothing: this session already has both repos attached. |
| M0 | Codex | Device-code login at the start of each session (as today), or an OpenAI API key saved as a network secret for `api.openai.com` for unattended runs. | A login link and code. |
| M2 | Cloudflare | Create a free account. Create an **API token** from the "Edit Cloudflare Workers" template, plus D1 Edit, scoped to that one account. Add it with the account ID as Actions secrets. | Optionally the same token as a network secret for `api.cloudflare.com`, for previews from the session. Wrangler gets a dummy value and the proxy substitutes it. |
| M2 | GitHub API for public previews | Create a **GitHub App** (manifest flow, generated in M2): read-only Contents and Metadata. Store the App ID, private key (PKCS#8) and webhook secret as Wrangler secrets via CI. | Nothing secret. Unauthenticated GitHub API limits are too low for a shared Worker IP. |
| M3 | Firebase | Create a project on the free **Spark** plan, without upgrading to Identity Platform. Add a Web app, enable Email/Password plus the chosen social providers, and add the `workers.dev` host to Authorized Domains. | Only the **public** web config (project ID, API key, auth domain). The Worker verifies tokens against Google's public keys, so the backend needs no Firebase secret. |
| M4 | GitHub App write access | Extend the App: Contents write for scaffolding, webhooks, and a user-to-server OAuth callback for owner verification. | Nothing secret. |
| M9 (optional) | Stripe | A Stripe account in **test mode**, with Connect enabled; the restricted key and webhook secret go to Wrangler secrets. Requires the M9 legal and tax decision first. | Nothing secret. |
| Later | Domain | Optional custom domain on Cloudflare. | — |

The environment setup script is extended in M0, after each step has been run in a session, with: Flutter 3.50.1 (mise), Node, wrangler, RTK and Codex.
