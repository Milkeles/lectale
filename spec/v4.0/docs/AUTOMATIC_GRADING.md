# Optional GitHub Actions grading — normative v3

## Grading modes and platform scope

Every assignment declares `grading.mode` as `manual`, `automatic`, or `hybrid`. Default is `manual`. Manual grading remains available for all supported file formats, including essays, image portfolios, PDF reports, notebook submissions, source files, archives and other instructor-permitted work. Automatic grading is NOT restricted to code file extensions but **requires an instructor-provided, explicitly authorized compatible grading workflow**. The platform never claims it can assess arbitrary essays, PDFs, videos or notebooks automatically. No user-submitted code runs in Cloudflare Workers, Pages, D1, or the Flutter app.

For `automatic` and `hybrid`, the course manifest provides an advisory workflow configuration. Server trust comes from a verified instructor approval pinned in D1 (`grading_config_approvals`), including the workflow path, exact approved commit SHA, timeout, rate limits and allowed release policy. A student's YAML edit, a manifest change, or a pull request cannot enable a new privileged workflow.

**Manual mode:** student submits, status `submitted/ungraded`; authorized instructor records grade and optional feedback, creating immutable grade audit events.

**Automatic mode:** after a verified final submission, the Worker queues an instructor-funded GitHub Actions run. Result is a PROPOSAL; default `releasePolicy=review-required` (instructor verifies/releases). The owner may explicitly enable auto-release after passing security and output-correctness tests; the Worker, not the workflow, authorizes and stores released scores.

**Hybrid mode:** an automatic result is only advisory; instructor MUST review and approve/modify final score. Workflow cannot auto-release in this mode. Learner can see permitted progress and feedback, not other students' submissions or raw runtime logs.

## Trust boundaries and runtime isolation

1. Owner explicitly enables GitHub Actions grading, connects a **private, owner-controlled grading repository**, and approves a specific workflow path and commit SHA. Public workflow runs are not acceptable when student files/results are private. Creator pays and caps Actions usage. On a private GitHub Free account, usage draws from included compute; extra charges may require billing and can stop when unavailable. GitHub's current docs express Free included compute as $12 per billing month; the 2-core Linux runner example is $0.006/minute. Never price the platform as if those runner minutes were free for all.
2. When an attempt is finalized, Worker enforces course enrollment, assignment policy, `maxRunsPerAttempt`, concurrency, cooldown and active workflow approval. It inserts `grading_jobs` with unique job ID and submission pointer, not a script body or arbitrary shell commands.
3. A trusted dispatch step calls GitHub's workflow dispatch endpoint using a short-lived installation token restricted to the OWNER'S approved repo. All `workflow_dispatch` inputs are opaque IDs or strict allowlisted flags; reject arbitrary repository, branch, command and URL fields.
4. A trusted fetch phase obtains the verified submission as data, never by executing student-controlled archive entrypoints or using unsafe extraction paths. Keep access tokens out of any process running untrusted student content.
5. An isolated job runs tests with `permissions: {}` for `GITHUB_TOKEN`, `actions/checkout` credential persistence disabled, no workflow secrets, no cloud credentials, no admin tokens, and no access to other students' private files. Use ephemeral GitHub-hosted runners; never run untrusted user code on persistent teacher-owned servers. Timeouts, output limits, disk/memory quotas, concurrency limits, dependency allowlists and non-privileged containers are mandatory. Network access may not be fully disabled on ordinary Actions runners; disclose that limit and avoid grading workflows that handle sensitive services or secrets.
6. Do not execute untrusted PR code under `pull_request_target`, `workflow_run` with privileged checkout, or any workflow that mixes student-controlled code and repository secrets. Pin third-party Actions to reviewed commit SHAs; default to read-only permissions when possible. Treat all notebook outputs and grader messages as untrusted content.
7. Run outputs only a bounded `course-grading-result/v1` JSON file as workflow artifact, never a trusted grade record. A separate trusted Worker consumes GitHub-signed webhook/run status (and may independently query the GitHub Actions API), checks run ID, repository ID, pinned workflow SHA, linked submission ID, provenance, completion and output bounds, then validates the result against the JSON Schema.
8. The Worker records the resulting PROPOSAL and creates a final D1 grade only under approved release policy. Preserve score revision/history, related job, test summary and instructor overrides. GitHub's run being `success` by itself never means the student earned full marks.

### Run state machine

`queued -> dispatched -> running -> completed | failed | timed_out | cancelled`.

A completed run with valid grading JSON may yield `proposed_score`; a failed or timed-out job may yield `no score`. Infrastructure failure does not automatically mean the student earned zero. Workers and GitHub webhooks can retry: state transitions and artifact processing MUST be idempotent. Subsequent regrading creates a new job and a new grade revision rather than silently rewriting prior history.

## YAML v3 grading contract

`grading.mode` is required. `grading.maxPoints` >0 is required. `grading.allowRevisionAfterGrade` optional. For automatic or hybrid, `grading.automatic` is REQUIRED with exact fields:

```
automatic:
  provider: github-actions
  workflowPath: .github/workflows/grade-submission.yml
  trigger: on-submit              # or manual
  resultFormat: course-grading-result/v1
  timeoutMinutes: 10              # 1..60
  maxRunsPerAttempt: 2            # 1..10
  releasePolicy: review-required  # or auto-release (automatic only)
```

`grading.automatic` is forbidden for manual mode. `hybrid` MUST use `review-required`. The schema captures structure; semantic and D1 verification must confirm workflow owner approval, repo/path equivalence, disabled execution on unauthorized courses, quotas and compatibility with a given file type. This is a format definition, not a recommendation that every course contain a grader.

## Limits, billing, and results

- Course owner explicitly sees estimated Actions compute and is required to set a maximum total monthly runs or cap in their GitHub settings. If the owner disables Actions/billing, grading falls back to manual and does not consume platform compute.
- Default automated runs on submission only if enabled; extra submissions may cause extra billed runs, so cap attempts, repeats, per-hour concurrency and per-user rate.
- `maxPoints` must match effective assignment grading policy; tests can award points but result must not exceed cap. On grading failure prefer `status=error`, not numeric zero.
- `grades` table is authoritative. `grading_jobs` logs provenance; `grade_events` retains overrides; optional GitHub YAML exports remain non-authoritative.
- Send no account credentials, billing keys, Stripe tokens, Firebase ID tokens, GitHub App tokens, instructor PII or private grades to an untrusted grading job.

## Acceptance cases

GRA-001: A PDF assignment with manual mode works and never attempts code execution.
GRA-002: A valid automatic assignment launches only the owner-approved workflow and only for a finalized student attempt.
GRA-003: Student edits manifest workflow path, approval token or grading request -> cannot execute a new workflow.
GRA-004: Malicious student file attempts secret exfiltration or path traversal -> no credentials available and no other private file access.
GRA-005: Failed infrastructure, timeouts, malformed JSON and duplicate GitHub events do not create false grades.
GRA-006: Hybrid score is never published without an instructor decision.
GRA-007: Owner can disable automatic grading and continue manual grading without breaking enrollments.
GRA-008: Instructor's GitHub Actions bill, not platform Workers, covers grading jobs; spending caps enforced.

References: https://docs.github.com/en/actions/concepts/billing-and-usage ; https://docs.github.com/en/actions/reference/security/secure-use ; https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target ; https://docs.github.com/en/rest/actions/workflows
