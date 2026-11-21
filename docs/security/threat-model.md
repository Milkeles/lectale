# Threat model: Lectale, M0 to M7 plus optional features

| | |
|---|---|
| **Owner** | Milkeles (project owner) |
| **Status** | Stub for M0. Written from the spec and the plan, before most of the code exists. |
| **Scope** | The system as planned through M7 (`docs/plan.md` section 7), plus the optional features M8 to M10 (Actions grading, Stripe Connect, catalog), each marked **optional**. |
| **Last reviewed** | 2026-11-21 |
| **Review cadence** | At the close of each milestone, and whenever a task's Security field changes a trust boundary. |
| **Review trigger** | A new data flow, a new external caller, a new stored personal-data field, or a change to the Worker fetch allowlist. |
| **Participants** | Owner and docs-pm agent. The security-reviewer has not yet reviewed it. |

Mitigation status: **implemented** means the file exists in this repository and I read it. **planned (Mn)** means the milestone in `docs/plan.md` section 7 that delivers it. Nothing under `apps/edge_api` beyond the health route and the error envelope exists yet, so almost every runtime control is planned.

Spec IDs come from `spec/v4.0/docs/SECURITY_TESTS.md` (SEC-, UI-, OPS-, COM-), `SESSION_SECURITY.md` (cited by section) and `RELEASE_TESTS_V4.md` (V4-). `spec/INDEX.md` lists them.

---

## 1. What are we working on

Lectale is a Flutter client (web and native) and one Cloudflare Worker (Hono, with static assets). The Worker reads course content from GitHub, keeps platform state in D1 and verifies Firebase ID tokens. Instructors keep courses in their own GitHub repositories.

```
 Browser / native app --(B1)--> Worker --(B2)--> GitHub API, raw, webhooks in
        |                          |--(B3)--> D1
        |                          '--(B4)--> Firebase public keys
        '--(B6) video iframes      
 Course repo content (B5) flows through the Worker to the client.
 CI (B7) pulls litse-ui-private.  Coding agents (B8) read and write this repo.
```

### Trust boundaries

| ID | Boundary | Direction of concern |
|---|---|---|
| B1 | Browser or native app and Worker | Anyone on the internet calls `/api`. |
| B2 | Worker and GitHub: App JWT, installation tokens, webhooks | Tokens out, webhook payloads in. |
| B3 | Worker and D1 | Worker holds the only credentials; queries carry user input. |
| B4 | Worker and Firebase public keys | Worker trusts the key set to verify identity. |
| B5 | Untrusted course repositories: README, `course.yaml`, notebooks, PDFs | Any GitHub user can author what the Worker and client parse and render. |
| B6 | Third-party video embeds (YouTube, Vimeo) | A third party runs code and sets cookies inside the page. |
| B7 | CI and the `litse-ui-private` deploy key | A read-only key lives in Actions secrets. |
| B8 | Coding agents and the repository | Agents read fetched pages and course content, and can run commands. |

### Assets

| Asset | Where it lives | Why it matters |
|---|---|---|
| GitHub App private key, webhook secret | Workers Secrets (planned M4) | Full repository access for every installation. |
| Installation tokens (at most 1 hour) | Worker memory | Read and write on instructor repositories. |
| Session IDs, as SHA-256 hashes | D1 `web_sessions` | Account takeover if the raw cookie leaks. |
| Real names, certificate names | D1 `users`, `certificates` | Personal data; certificates are public by link. |
| Submissions, grades, feedback | D1 `grades`, `submission_attempts`; GitHub for files | Integrity of academic records; private by default. |
| Stripe IDs and order state (optional) | D1 `commerce_orders` | Money and entitlements. |
| `LITSE_UI_DEPLOY_KEY` | GitHub Actions secret | Read access to the private design-system repository. |
| Cloudflare deploy token | GitHub Actions secret | Can deploy code and change D1. |
| Availability | Free-tier Worker and D1 limits | Quotas are small, so cost abuse is also a denial of service. |

### Assumptions

- Cloudflare, Google (Firebase) and GitHub are trusted to run their platforms correctly. Their breach is out of scope here and belongs in the incident plan.
- Only the owner holds Cloudflare, Firebase and GitHub App admin rights. No other human is modelled.
- Flutter Web needs a CSP exception (`wasm-unsafe-eval` is likely). That is spike S3, not yet decided.
- Anything a course author writes is hostile until validated.

---

## 2. What can go wrong

Existing control: the control named in the spec or plan. Residual risk assumes the control is built as described, and is High while it is only planned.

### B1. Browser or native app and Worker

| # | Threat scenario | STRIDE | Spec | Residual |
|---|---|---|---|---|
| 1.1 | A user pastes a Firebase token with `alg:none`, a wrong audience or an expired `exp` and is accepted. | S | SEC-010, V4-SEC-01, SESSION_SECURITY "Default web session design" step 2 | High until M3 |
| 1.2 | A stolen or replayed session cookie keeps working after logout. | S | SEC-013, SEC-011, V4-SEC-02 | High until M3 |
| 1.3 | A malicious page posts to a mutation route using the victim's cookie (CSRF). | T | SEC-012, SESSION_SECURITY "Threat controls" CSRF | High until M3 |
| 1.4 | A student changes a UID or path to read another student's submission or grade (IDOR). | I, E | SEC-003, SEC-004, V4-SEC-06 | High until M5 |
| 1.5 | A grader opens a course outside their staff membership, or a student issues a certificate. | E | SEC-004 | High until M7 |
| 1.6 | An unenrolled user reads private content, file metadata or source URLs. | I | SEC-005, UI-008, V4-CORE-07 | High until M4 |
| 1.7 | Personalized or private responses are served from the edge cache to the next user. | I | V4-CACHE-02, SESSION_SECURITY acceptance tests | Medium |
| 1.8 | A client floods import or auth routes, exhausting Worker and D1 free quotas. | D | OPS-003, V4-COST-01, SESSION_SECURITY "Quotas/abuse" | High until M11 guards |
| 1.9 | A privileged action (grade change, certificate revocation) is later denied by its actor. | R | SESSION_SECURITY "Forgery" (append-only `grade_events`), V4-CORE-06 | Medium |
| 1.10 | An error response leaks a stack trace, SQL or token. | I | SEC-015, V4-SEC-09, ERR-001..010 | Low |
| 1.11 | A native client stores the Bearer token in readable storage. | I | SESSION_SECURITY "Native application authentication" | Medium |

### B2. Worker and GitHub

| # | Threat scenario | STRIDE | Spec | Residual |
|---|---|---|---|---|
| 2.1 | A user pastes someone else's repo URL, forges an owner UID or spoofs an installation ID to claim a course. | S | SEC-002, SEC-001, V4-CORE-03 | High until M4 |
| 2.2 | A forged webhook (bad or missing HMAC) republishes a course or flips state. | S, T | OPS-004, V4-SEC-04 | High until M4 |
| 2.3 | A captured webhook delivery is replayed. | T | OPS-004 (idempotent events, `webhook_events.delivery_id` key) | High until M4 |
| 2.4 | An installation token or the App private key reaches the client, a log or an error. | I | V4-SEC-04, SEC-015, SESSION_SECURITY "Instructor GitHub authorization" | High until M4 |
| 2.5 | A removed or transferred repository keeps privileges; a grade vanishes with the repo. | E, T | SEC-006, OPS-005 | Medium |
| 2.6 | A manifest URL or media link makes the Worker fetch an internal or arbitrary host (SSRF). | I | SESSION_SECURITY "SSRF", V4-SEC-03 | Medium; the fetch allowlist is implemented |
| 2.7 | A cache miss or 304 loops on the GitHub API until the rate limit is hit. | D | V4-CACHE-05, OPS-003 | Medium |
| 2.8 | A delegated LFS upload URL carries a reusable token or writes arbitrary repo files. | E, I | SEC-024, SEC-025, SEC-026, V4-SEC-05 | Low while the flag stays off |

### B3. Worker and D1

| # | Threat scenario | STRIDE | Spec | Residual |
|---|---|---|---|---|
| 3.1 | User input reaches SQL through string building. | T | SEC-003 (query-param tampering) | Medium |
| 3.2 | Two concurrent finalize calls create two attempts, or a reservation bypasses the limit. | T | SEC-023, SESSION_SECURITY "Replay / race" | Medium until M6 |
| 3.3 | A grade is changed without an audit row, or a certificate name is rewritten after issue. | T, R | V4-CORE-06, errata E8 | Medium until M7 |
| 3.4 | A D1 export or backup exposes names and grades beyond their retention. | I | PRIV-004 (`EU_PRIVACY_COOKIES.md`) | Medium; no retention values are set (see ROPA) |
| 3.5 | Stale rows and sessions pile up and exhaust the free write budget. | D | V4-COST-02, errata E11 | Medium |

### B4. Worker and Firebase public keys

| # | Threat scenario | STRIDE | Spec | Residual |
|---|---|---|---|---|
| 4.1 | A token signed by another Firebase project is accepted. | S | SEC-010 (wrong project ID), V4-SEC-01 | High until M3 |
| 4.2 | The key fetch fails or is poisoned, so verification fails open or the API is down. | S, D | SESSION_SECURITY step 2 (rotated keys); ERR-001..010 | Medium |
| 4.3 | A disabled or deleted Firebase account keeps a live session for up to 12 hours. | E | SESSION_SECURITY step 2 (optional revocation check) | Medium; owner decision pending |

### B5. Untrusted course repositories

| # | Threat scenario | STRIDE | Spec | Residual |
|---|---|---|---|---|
| 5.1 | Script in README, YAML description, filename, SVG or notebook HTML runs in a viewer's session. | T, E | SEC-014, UI-003, V4-SEC-03 | High until M2 |
| 5.2 | `../`, encoded traversal or a symlink path escapes the pinned repository. | I | SEC-020, V4-SEC-03 | High until M1 |
| 5.3 | A YAML bomb (aliases, tags, oversize) exhausts Worker CPU. | D | `docs/plan.md` section 5 (YAML size cap, no aliases or tags); attack fixtures in M1 | High until M1 |
| 5.4 | A malicious PDF or notebook output exploits the viewer or an embedded tracker phones home. | E, I | SESSION_SECURITY "Browser XSS"; UI-001, UI-003; V4-COST-06 | Medium |
| 5.5 | An author's invalid `course.yaml` replaces the valid published version. | T | OPS-004, V4-CORE-04 | Medium until M4 |
| 5.6 | A course README embeds an image or link that leaks the reader's IP to an author server. | I | PRIV-002, V4-SEC-03 (embedded trackers) | Medium |
| 5.7 | Submitted code is run on the platform (optional Actions grading). | E | V4-SEC-08 | **Optional**, M8; runs only on the instructor's runner |

### B6. Third-party video embeds

| # | Threat scenario | STRIDE | Spec | Residual |
|---|---|---|---|---|
| 6.1 | A page load starts a YouTube or Vimeo iframe, setting cookies before consent. | I | COOKIE-003, CT-001, UI-002 | High until M2b |
| 6.2 | A manifest names an embed host outside the allowlist. | T, I | SESSION_SECURITY "SSRF" (embed provider allowlist) | Medium until M1 |
| 6.3 | The embedded frame navigates the parent page or reads app state. | E | SESSION_SECURITY "Browser XSS" (separate sandbox origins) | Medium until M2b |

### B7. CI and the `litse-ui-private` deploy key

| # | Threat scenario | STRIDE | Spec | Residual |
|---|---|---|---|---|
| 7.1 | A pull request from a fork reads `LITSE_UI_DEPLOY_KEY` or the Cloudflare token. | I | `docs/plan.md` section 5; zizmor audit | Medium |
| 7.2 | A workflow pins `@v4`, so a moved tag runs attacker code. | T | `docs/plan.md` section 5 (pin by SHA) | Low; implemented |
| 7.3 | A leaked or vulnerable dependency reaches a release. | T, I | `docs/plan.md` section 5 (gitleaks, osv-scanner) | Low; implemented |
| 7.4 | The deploy key is used to write to `litse-ui-private`. | T | `docs/runbooks/litse-ui-deploy-key.md`; ADR-0004 (key is read-only) | Low |
| 7.5 | A workflow injects untrusted input (branch name, PR title) into a shell step. | E | zizmor audit | Low; implemented |

### B8. Coding agents and the repository

| # | Threat scenario | STRIDE | Spec | Residual |
|---|---|---|---|---|
| 8.1 | A fetched web page or course repo tells the agent to run a command or exfiltrate a secret (prompt injection). | E, I | `docs/plan.md` section 5 "Agent safety" | Medium |
| 8.2 | An agent force-pushes, pushes to main, deploys, or sets a remote secret. | T, E | `docs/plan.md` section 5 hooks | Low; implemented |
| 8.3 | An agent edits the normative spec bundle to make a failing test pass. | T | `spec/INDEX.md`; hook blocks `spec/v4.0/` writes | Low; implemented |
| 8.4 | An agent reads `.dev.vars` or `.env` and puts the value in a prompt or commit. | I | `docs/plan.md` section 5 | Low; implemented for shell and edit tools only |
| 8.5 | An agent adds an unreviewed dependency or a fetch to a new host. | T, I | `tool/check_rules.py` fetch allowlist; osv-scanner | Medium |

---

## 3. What are we going to do about it

One decision per boundary group. Owner is Milkeles for all rows; tickets are the milestone checklists in `PLAN.md`. Every row is Mitigate unless marked.

| Threats | Mitigation | Milestone | Status |
|---|---|---|---|
| 1.1, 4.1 | Verify Firebase JWT with `jose` `createRemoteJWKSet`: signature, `iss`, `aud`, `exp`, `sub`; reject `alg:none` | M3 | planned |
| 1.2, 1.3 | `__Host-course_session` (opaque, hashed in D1, 12 h absolute, 30 min idle), Origin and CSRF token on every mutation, revoke on logout | M3 | planned |
| 1.4, 1.5, 1.6 | Default-deny ACL middleware, 404 masking, a role test per route | M3 (middleware), M4 to M7 (per-route) | planned |
| 1.7 | `Cache-Control: no-store` on auth and private responses; the error envelope already sets it | M2 (cache classes), M3 | partly implemented: `errorResponse` sets `no-store` |
| 1.8, 2.7, 3.5 | Per-user, per-course and per-IP rate limits, cost guards, budget alerts | M11 (limits earlier where a route needs one) | planned |
| 1.9, 3.3 | Append-only `grade_events`, certificate snapshots, audit rows | M7 | planned |
| 1.10 | Error envelope: stable code, `requestId`, fixed message; `onError` logs only `requestId` and the error name, never the message | M0 | **implemented** (`apps/edge_api/src/errors.ts`, `index.ts`) |
| 1.11 | Firebase SDK secure storage on native; no Bearer token in app code | M3 | planned |
| 2.1, 2.2, 2.3 | GitHub owner verification, App install check, HMAC verify, `delivery_id` idempotency | M4 | planned |
| 2.4 | Tokens stay server-side and out of logs and errors; secrets only in Workers Secrets | M4 | planned. The log redaction half is partly implemented: `onError` omits the message. |
| 2.5, 5.5 | Suspend privileges on repo loss; keep the last valid pinned SHA | M4 | planned |
| 2.6, 6.2 | Worker may fetch only the hosts in `WORKER_FETCH_HOSTS`; embeds only from an allowlist | M0 (fetch rule), M1 (embed rule) | fetch allowlist **implemented** in `tool/check_rules.py` (checks `fetch("https://...")` literals only); embed allowlist planned |
| 2.8 | LFS upload flag stays off until spike S1 passes; the rule blocks setting it true | M0 rule, S1 spike | **implemented** rule (`lfs-upload-stays-off`); S1 planned |
| 3.1 | Parameterised D1 queries only; typed helpers | M3 | planned |
| 3.2 | D1 unique constraints, idempotency keys | M3, M6 | planned |
| 3.4 | Retention cron, DSAR export and deletion | M7 | planned |
| 4.2 | Cache the key set; fail closed with `retryable` error | M3 | planned |
| 4.3 | Decide whether to check revocation on session creation. **Owner decision pending.** | M3 | proposed |
| 5.1, 5.4 | No HTML, scripts or iframes from course content; sanitised Markdown; notebooks never executed; CSP; risky previews on a separate origin | M2, M2b | rule `no-html-rendering-of-course-content` **implemented** for Dart; the rest planned |
| 5.2 | Canonical-path checks, within the pinned repo only | M1, M2 | planned |
| 5.3 | Size cap, YAML 1.2 without aliases or tags, attack fixtures | M1 | planned |
| 5.6 | No external images by default; local placeholders | M2 | planned. **Gap:** the spec has no rule for author-hosted images (see section 4). |
| 5.7 | Grader runs on the instructor's Actions runner with no platform secret | M8 **optional** | planned |
| 6.1, 6.3 | Local placeholder and a "Load external video" action; sandboxed frame; consent record in `consent_events` | M2b, M7 | planned |
| 7.1, 7.5 | Workflows run with `permissions: {}` and per-job least privilege; zizmor on every change and weekly | M0 | **implemented** (`.github/workflows/security.yml`) |
| 7.2 | Every `uses:` pinned by full commit SHA | M0 | **implemented** for third-party actions; the two local `./.github/actions/litse-ui-access` uses are in-repo |
| 7.3 | gitleaks over full history, osv-scanner on both lockfiles, CodeQL (JavaScript/TypeScript and Actions) | M0 | **implemented** (`security.yml`). Dependabot is planned. |
| 7.4 | Read-only deploy key, written down in a runbook | M0 | the runbook exists; the key is created by the owner (`docs/plan.md` section 9) |
| 8.1 | Agent prompts treat fetched content as data; the researcher is fetch-only | M0 | instruction-based, not enforced by a hook. Only `researcher.md` and `security-reviewer.md` mention untrusted content. **Mismatch:** `docs/plan.md` section 5 says the researcher has no write tools, but `.claude/agents/researcher.md` grants `Bash` and `Write`. Open until the owner fixes the tool list or the plan. |
| 8.2, 8.3, 8.4 | `.claude/hooks/guard.py` as a PreToolUse hook on Bash, Edit and Write | M0 | **implemented**, wired in `.claude/settings.json` |
| 8.5 | `tool/check_rules.py` as a PostToolUse hook; osv-scanner in CI | M0 | **implemented** |

**Accepted risk.** Row 8.1: the owner has not yet accepted it in writing. Until they do, treat it as open.

### What the implemented controls do and do not cover

I read each file before listing it as implemented.

- **`.claude/hooks/guard.py`** blocks force-push, push to main, `wrangler deploy` (without `--dry-run`), remote D1 changes, `wrangler secret` commands, `rm -rf` of root, home or `.git`, writes into `spec/v4.0/`, and any Bash command or edit that names `.dev.vars` or `.env`. It is regex matching on the command text, so a determined agent can evade it (for example by building a path in a script). It is a guardrail against mistakes, not a sandbox.
- **`tool/check_rules.py`** checks six rules (Material imports, LFS flag, browser credential storage, `eval` in the Worker, HTML rendering of course content, `fetch` host allowlist). The fetch rule matches only a literal `https://host` inside `fetch(`. A URL built from a variable is not checked, so the SSRF control still needs a runtime allowlist in M2.
- **`.github/workflows/security.yml`** runs gitleaks, osv-scanner, zizmor and CodeQL on pull requests, pushes to main and weekly. I did not check that branch protection requires these jobs.
- **Worker error envelope.** `onError` logs `requestId` and the exception name only. `notFound` and `onError` both return the standard body with `no-store`. Routes that do not exist yet are not covered.

---

## 4. Did we do a good enough job

**Not covered.** Cloudflare, Google and GitHub platform failures; a hostile owner; physical access; the Stripe Connect and catalog flows in detail (M9 and M10 get their own model when the owner decides to build them); privacy harms beyond what STRIDE finds (a LINDDUN pass would suit the DSAR and certificate flows).

**Least confident about.** CSP for Flutter Web (spike S3); whether LFS delegated upload can be made safe (spike S1); notebook and PDF viewers, which are third-party parsers of hostile input.

**Spec gaps found.**
- No rule covers images or links in a course README that point to an author-controlled host and so disclose the reader's IP (threat 5.6). `PRIV-002` and `V4-SEC-03` mention trackers only.
- `SESSION_SECURITY.md` step 3 lists an "auth state version" on the session, but `web_sessions` in `spec/v4.0/db/0001_init.sql` has no such column, and no table limits concurrent sessions.
- No stated decision on revoking sessions when a Firebase account is disabled (threat 4.3).

**What would change the answers.** A second human with admin access, public signup before M5, any feature that executes submitted code on the platform, or a decision to render author HTML.

**Next review.** At M1 close, then each milestone.
