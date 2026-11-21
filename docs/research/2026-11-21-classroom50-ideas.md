# classroom50 ideas for Lectale M4-M8 (2026-11-21)

Need: learn how foundation50/classroom50 solves enrolment, submissions, grading and Actions autograding, and take ideas for M4-M8.
Requirement IDs: V4-CORE-03/04/06/07, V4-SEC-04/05/06/07/08/09 (`spec/v4.0/docs/RELEASE_TESTS_V4.md`).
Constraints checked: Workers / six platforms / litse-ui / MIT / cost.

**Source:** https://github.com/foundation50/classroom50, shallow clone at `/home/user/research/classroom50`, commit `7c1a541e6b85253709e6eaa45c742da8e0ee1746`, fetched 2026-11-21. Paths below are relative to that checkout.

**Licence rule.** classroom50 is GPL-3.0 (`LICENSE`, `CONTRIBUTING.md` line 205); Lectale is MIT. This note holds ideas, flows and data shapes in my own words, with no code copied. Nobody should read its source while writing the same Lectale module. Repository content was treated as data, not instructions.

**How to read it (owner guidance).** Lectale has one course repository, the spec's private submissions repository, D1 as the grade authority and no per-student repositories. `spec/v4.0` wins every conflict. Anything that depends on classroom50's per-student repository model is marked "avoid (architecture differs)". The useful parts are assignment validation and automatic grading, so M7 and M8 get most of the space.

## 1. What classroom50 is

- **No backend.** "Classroom 50 has no server or database of its own" (`wiki/Home.md`). State lives in a private `classroom50` config repo in the teacher's org, plus org teams, one repo per student, Releases and GitHub Pages (`wiki/How-Classroom-50-Works.md`).
- **Stack.** React 19, Vite, TanStack, zod (`web/package.json`); Go `gh` CLI extensions (`cli/`); Python runner and reusable Actions workflows (`cli/gh-teacher/skeleton/dotgithub/`). The only server piece is a stateless Cloudflare Worker proxy for the OAuth token exchange and zip downloads (`wiki/GitHub-Integration.md`, "The GitHub proxy").
- **Hosting and cost.** Web app on GitHub Pages (`.github/workflows/web-deploy.yaml`). The teacher's org needs GitHub Team or Enterprise, free for verified teachers (`wiki/Prerequisites-and-GitHub-Education.md`). Grading minutes bill to the org: Team includes 3,000 a month and every run bills at least 2 minutes (`wiki/Managing-Actions-Cost.md`).
- **Auth.** A classic OAuth App with broad scopes, one set for all roles, not a GitHub App (`wiki/GitHub-Integration.md`, "Permissions and access").
- **Self-documented limits** (`wiki/Known-Limitations.md`): no webhooks, state refreshes only on page load, no LMS passback, no in-app scores for students, no self-service join link, public repos cannot be autograded, and autograded scores come from repos students can write to.

## 2. M4-M6 in brief

| Area | classroom50 | Verdict |
|---|---|---|
| M4 identity and roles | Teacher = org owner; roles are org teams, no role database (`wiki/How-Classroom-50-Works.md`, "Roles are GitHub organization roles and teams"). | **Avoid (architecture differs).** Lectale roles live in D1 behind ACL middleware. |
| M4 tokens | User token held in the browser, scopes are all-or-nothing (`wiki/GitHub-Integration.md`). | **Avoid.** V4-SEC-04: tokens never reach clients; the Worker mints installation tokens. |
| M4 proxy reasoning | The proxy exists because GitHub's token endpoint has no CORS and needs a client secret; it accepts only the app's own origins. | **Adopt** as confirmation that secrets stay in the Worker and same-origin `/api` is right. |
| M4 install health check | A read-only "probe token" workflow and a **Test token** button name the exact missing permission (`skeleton/dotgithub/workflows/probe-token.yaml`, `wiki/GitHub-Integration.md` section 7). | **Adopt.** A post-install check listing missing App permissions. |
| M4 webhooks | None; staleness is accepted. | **Avoid.** V4-SEC-04 requires HMAC-verified webhooks. Also detect a suspended install: a lapsed plan silently disabled classroom50's Pages site (`wiki/Prerequisites-and-GitHub-Education.md`). |
| M5 enrolment record | Enrolled = member of an org team; `roster.csv` holds extras. | **Avoid (architecture differs).** Enrolment rows live in D1 (V4-SEC-06). |
| M5 email invites | A single-member secret team holds the address; whoever joins it is the invitee (`schemas/invite-v1.schema.json`, `wiki/How-Classroom-50-Works.md`, "Invitations by email"). | **Avoid the mechanism (architecture differs).** **Adopt the guarantee:** a single-use hashed invite token redeemed by the authenticated user, unique per course (their invite id hashes classroom plus lowercased email). |
| M5 sync safety | If a read is degraded, a sync removes nothing, because it cannot prove a row is dead (same page, "What triggers a sync"). | **Adopt** for webhook and roster reconciliation. |
| M5 identity key | Imports prefer the immutable numeric GitHub id over the username (`wiki/Web-Teacher-Guide.md`, "Roster CSV fields"). | **Adopt** stable ids; shared contact emails allowed, so no unique-email constraint. |
| M6 per-student repos, org lockdown, ruleset on student branches, feedback PR base branch, group teams, repo-name tracking | Core of the model (`wiki/How-Classroom-50-Works.md`, "The permission model"). | **Avoid (architecture differs).** Lectale uses one submissions repo with delegated upload (V4-SEC-05/06). |
| M6 private-fork leak | A private fork inherits the template's team permissions (`wiki/Known-Limitations.md`). | **Adopt as a pitfall:** never fork or template private repos into a space students can read. |
| M6 submission event | A submission is an explicit `submit/<UTC time>-<short sha>` tag; due date only marks late, "Close submission" is the hard cutoff (`wiki/Course-Lifecycle-and-End-of-Term.md`). | **Adapt.** Keep the soft-late and hard-close split, but stamp the Worker's receive time. Their time is the client-set committer date and forgeable. |
| M6 allowed paths | `allowed_files` globs restrict what counts as a submission (`wiki/Advanced-Autograding.md`). | **Adopt** as a server-side path allowlist with size caps. |
| M6 locked assignments | Create locked, unlock when a timed session starts. | **Adopt** as an "available from" state enforced in the Worker. |

## 3. M7: manual grading, feedback, export

- **Grade modes.** Per assignment: not graded, manual (with max points), autograded (`wiki/Web-Teacher-Guide.md`, "Scores and overrides").
  - **Adopt.** Mirrors spec grade sources; D1 stays the authority.
- **Override beside the machine score.** A teacher score overrides an autograded one, shows a "Manual" badge, keeps the autograded value and can be cleared. Autograding never replaces an active override.
  - **Adopt.** Store override and machine result as separate fields; the override wins in display, not in storage.
- **Provenance on every score.** A result not published by the trusted workflow identity is kept but marked "Unverified", with the reason carried into exports (`wiki/Autograding-Basics.md`, "How much to trust a collected score"; `skeleton/dotgithub/scripts/collect_scores.py`, provenance check).
  - **Adopt.** Each grade row records its source (manual, runner-reported, imported) and who or what wrote it.
- **Score history.** Full submission history newest first, plus a per-assignment "collected at" stamp (`schemas/scores-v1.schema.json`).
  - **Adopt** in D1 rows, with audit entries. **Avoid (architecture differs)** keeping it as a JSON file in a Git repo.
- **Export.** One CSV row per student with name, score, max, submitted-at, late flag, links and a provenance column; a second per-attempt export carries an override flag (`wiki/Autograding-Basics.md`, "Score exports"). Per-test details stay out of the CSV.
  - **Adopt** the stable column set and provenance column.
  - Neutralising formula-leading cells (`=`, `+`, `-`, `@`) is not documented by classroom50 (not verified); add it ourselves.
- **Feedback.** A single long-lived pull request per student repo, diffed from a frozen baseline, merged only by staff (`wiki/Autograding-Basics.md`, "Feedback pull requests").
  - **Avoid (architecture differs).** It needs per-student repos. Keep feedback in D1.
- **Students seeing scores.** Not possible in classroom50 because Release assets are cross-origin (`wiki/Known-Limitations.md`).
  - **Avoid.** That is an artefact of having no server; Lectale serves grades from its own API.
- **LMS passback.** Declared out of reach without a server.
  - **Adapt later.** Lectale could add it; CSV is the M7 exit.

## 4. M8: assignment checks and automatic grading

### 4.1 Check definitions and validation

- **Declarative checks.** A versioned `tests.json` (`schemas/tests-v1.schema.json`) with three check kinds:
  - `io`: stdout of a command compared to expected text (substring, exact-trimmed, or regex) with optional stdin.
  - `run`: pass on a chosen exit code.
  - `python`: pytest, with points split across cases.
  - Each check has a name, optional setup command, timeout and points.
  - **Adopt** the shape: small closed set of kinds, points per check, an assignment-level default block.
- **Hard limits in the schema.** At most 100 checks, name 1-100 bytes with no control characters, timeout 1-600 s with a 10 s default, points 0-1000, exit code 0-255, additional properties rejected, slug pattern restricted before it becomes a path (`schemas/tests-v1.schema.json`, `skeleton/dotgithub/scripts/materialize_tests.py`).
  - **Adopt** all of these as the starting limits for Lectale's check schema (V4-SEC-08 "bounded").
- **Validation in layers, one source of truth.** Strict check at write time, a second lower-bar re-check at grade time so a hand-edited file cannot crash the grader, and a generated file that is never hand-written (`materialize_tests.py` docstring; `runner.py` `_validate_test_spec`).
  - **Adopt.** Matches ADR 0003 (validate on the server). Add parity tests so both validators agree. classroom50 ships fixture files for this (`cli/shared/testdata`).
- **Control characters are an injection vector.** Test names are echoed into log lines that can carry workflow commands, so control characters are rejected (`runner.py`, `_validate_test_spec` comment).
  - **Adopt.** Reject control characters in anything echoed into logs, PR text or CSV.
- **Fail-soft publishing.** A malformed manifest warns and skips instead of breaking a whole deploy.
  - **Adapt.** Lectale should reject the single assignment with a stable error code (V4-SEC-09), not skip it silently.
- **Check files kept out of the student checkout.** Grading files live in the teacher's repo, are bundled per assignment and are fetched fresh on every run; commands receive the bundle path through an environment variable, and nothing from the bundle is copied into the student tree (`wiki/Autograding-Basics.md`, "Teacher-only test files").
  - **Adopt** the separation. **Avoid** their bundle hosting: the Pages bundle is public, so "tamper-proof, not secret" (`wiki/Known-Limitations.md`).
- **Report options.** Per check: `full`, `actual-only` or `none` failure detail, optional passing output, optional command echo (`wiki/Autograding-Basics.md`, "Report options"). `actual-only` hides expected output and the hidden input.
  - **Adopt.** Hidden-test leakage control is cheap. Caps: first 2,000 characters in the summary, 100,000 in the job log.
- **Runtime block.** Per assignment: runner label, language versions, apt packages or a public container image; values are teacher-authored, never student input (`wiki/Advanced-Autograding.md`, "The `runtime` block").
  - **Adapt.** Offer a short allow-list of runtime images. Their "no allow-list, you own the label" is acceptable only because the teacher owns the org.
- **check50.** Example grader runs check50 in a public container and converts its output to the result contract (`examples/autograders/cs50/README.md`). See section 6.

### 4.2 How results are produced, reported and trusted

- **One result contract.** Whatever the tool is, the runner reads a versioned result file (`schemas/result-v1.schema.json`): schema id, classroom and assignment, repo owner, submission id, submission instant, score, max, per-check entries and who pushed. The result file is "the only contract every autograder must satisfy" (`wiki/Advanced-Autograding.md`).
  - **Adopt.** Define `lectale/result/v1` the same way so any checker can feed it.
- **Validation of the result.** Identity must match the repo; score and per-test scores are non-negative integers, booleans are rejected as numbers, score cannot exceed max, `tests` is a list of objects, submission id must have the expected prefix (`runner.py` `validate_result`, mirrored in `collect_scores.py` so both sides agree).
  - **Adopt** every rule, plus size and count caps. Run the same validator in the Worker as the final gate before any grade row is written.
- **Reporting.** The runner posts a commit status and publishes a Release; a separate collect job pulls results into `scores.json` on demand (`wiki/Autograding-Basics.md`, "How grading works").
  - **Avoid (architecture differs)** Release-per-student publishing and pull-based collection.
  - **Adapt** the status model: three outcomes (success, failure, error), where an infrastructure error never moves the score (`wiki/Advanced-Autograding.md`, "Failure paths"). Lectale needs a signed callback or `workflow_run` webhook from its submissions repo to the Worker.
- **Trust model, as documented.** Grading and publishing share one job, so student code can forge a score under the workflow identity; this is "detectable, not prevented". Hand-made Releases are only marked. A student can also delete the newest honest Release so an older score becomes latest. Submission time is client-set (`wiki/Autograding-Basics.md`, "How much to trust a collected score").
  - **Adopt the candour and the remedy:** after the deadline, close submissions, re-run checks in a context the student never wrote to.
  - **Adopt a stronger design for V4-SEC-08:** untrusted code runs in a job with a read-only token and no secrets and uploads only an artifact. A separate trusted step or the Worker validates and records it as "runner-reported". Final grade needs instructor action or a re-run.
- **Runner-side hardening worth copying** (`runner.py`):
  - Opens files without following symlinks, to stop a swapped link escaping the workspace.
  - Refuses to attach any file that looks like a result document, so a student file cannot become a forged score.
  - Caps fetched content at 10 MB and attached files at 50 files and 100 MB.
  - Ignores the host's git config when matching allowed paths, and removes disallowed files before grading.
  - **Adopt** all four as test ideas for the Worker and the runner template.

### 4.3 Isolating student code and secrets

- **No secrets for students.** Students configure nothing. The grade job uses only the job-scoped token; the single personal token lives in teacher-side collect, regrade and probe workflows (`wiki/Advanced-Autograding.md`, "No credentials required").
  - **Adopt.** V4-SEC-08: runner holds no platform or payment secret. Lectale's grade job gets no secret at all.
- **Fixed job limits.** The grade job stops after 15 minutes; per-command timeouts cannot extend it; each check has its own timeout (`wiki/Advanced-Autograding.md`, "Operational notes").
  - **Adopt** both layers.
- **Fresh trusted code each run.** The runner script is fetched from the teacher's site on each run, so edits propagate and students cannot alter it. If the fetch fails, acceptance detection fails open (grades anyway).
  - **Adopt** fetch-fresh. **Avoid** fail-open for anything security relevant; fail closed.
- **Gaps they admit.** Pausing autograding is housekeeping only, since students with write access can re-enable workflows. Student code and extra workflow files run in the same job as publishing (`wiki/Known-Limitations.md`).
  - **Adopt as rules:** never treat a pause flag as enforcement; separate the untrusted and trusted steps.
- **Cost controls.** Tag-only submissions, 15-minute cap, spending cap, 2-minute minimum per run (`wiki/Managing-Actions-Cost.md`).
  - **Adopt** explicit submission trigger and cap; document the cost per grading run for the owner (M8 is optional).
- **Private repos only.** A public repo cannot call workflows in a private repo, so public repos are not autograded.
  - **Adopt:** keep the submissions repo private; also fits the spec.

## 5. Where classroom50 does not help

Org lockdown, group teams, feedback base branches, rename tracking, Pages-served manifests and the service-token rotation flow all assume per-student repositories or a serverless design. All are **avoid (architecture differs)**.

## 6. Packages and services to evaluate

Fetched 2026-11-21. Fields I could not fetch are marked "not verified".

### Candidate: check50 (CS50)
- Source URLs: https://github.com/cs50/check50 (GitHub search API), https://raw.githubusercontent.com/cs50/check50/main/README.md, https://raw.githubusercontent.com/cs50/check50/main/LICENSE
- Licence: **GPL-3.0** (search API `spdx_id`; LICENSE text). Last push 2026-10-13, archived: no, stars 467.
- Runtime evidence: README: "check50 is a testing tool for checking student code". It is a Python tool, not a Workers library.
- Recommendation: **Avoid bundling, linking or redistributing.** An instructor may run it in their own Actions workflow, which Lectale neither ships nor links. Document it as an optional recipe only.

### Candidate: csv (pub.dev)
- Source URLs: https://pub.dev/api/packages/csv, https://pub.dev/api/packages/csv/score
- Version 8.0.0, published 2026-03-19. Licence MIT (`license:mit`). Platform tags: android, ios, windows, linux, macos, web. Downloads (30 days) 1,055,988.
- Recommendation: **Use** for client-side grade CSV export in Flutter (about 20 lines of glue).

### Candidate: papaparse (npm)
- Source URLs: https://registry.npmjs.org/papaparse/latest, https://raw.githubusercontent.com/mholt/PapaParse/master/README.md
- Version 5.7.1, modified 2026-11-11. Licence MIT. README calls it an "in-browser CSV parser" with Node stream support.
- Workers evidence: none, **not verified**. classroom50 uses it in the browser only.
- Recommendation: **Needs a Workers spike** before any server-side use.

### Candidate: libsodium-wrappers (npm)
- Source URL: https://registry.npmjs.org/libsodium-wrappers/latest. Version 0.8.4, modified 2026-04-19. Licence ISC.
- classroom50 uses it to encrypt the service token before uploading it as a repo secret. Workers evidence: no `workerd` condition in the fetched page, **not verified**.
- Recommendation: **Not needed.** Lectale's grader holds no secret, so no secret upload is required.

### Services
GitHub Pages, Releases and org teams are GitHub features that Lectale replaces with the GitHub App and D1. Pages from a private repo needs a paid plan, a cost to avoid. Cloudflare Workers is already Lectale's platform.

## 7. Recommendation

Adopt the ideas below; two items need an owner decision.

**Top ideas to adopt**
1. A versioned check schema with hard limits and two-layer validation (write time and grade time), with shared parity fixtures.
2. A single versioned result contract, validated in the Worker before any grade row is written, with identity, bounds and provenance.
3. A two-stage grader: untrusted code with no secrets and a read-only token, then a trusted publish step. Re-run after close for any final grade.
4. Grade provenance, with the teacher override stored beside the machine score and carried into the CSV.
5. A post-install health check that names missing permissions, and reconciliation that never deletes on a partial read.

**Owner decisions:** whether grader bundles must be private, and whether check50 may be documented as an optional instructor recipe.

**Gaps:** open issue counts and Workers evidence for papaparse and libsodium are not verified. I read classroom50's wiki, schemas and the validation and trust sections of `runner.py` and `collect_scores.py`, not the full 7,400 lines.
