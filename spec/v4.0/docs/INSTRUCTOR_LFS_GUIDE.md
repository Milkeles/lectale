# Instructor onboarding, Git LFS budgets, and upload limits — required UI copy and workflow

This guide must be accessible from repository connection, assignment configuration, course overview, and every `OWNER_STORAGE_QUOTA_EXCEEDED` error. Course owners are responsible for their GitHub account's usage/billing. **GitHub Free currently includes 10 GiB of LFS storage and 10 GiB/month of download bandwidth**, not unlimited storage and not a separate 10 GiB grant for each repository. Plans differ. Verify allowances on GitHub's current billing page; do not hardcode these as forever-current limits. Source: https://docs.github.com/en/billing/concepts/product-billing/git-lfs

## Guided setup (in instructor UI)

1. Explain that the public/private content repo is theirs and large submitted binaries are written to a separate **private submissions repository they own**. Do not require an organization. Connect only selected repositories through GitHub App; show access and billing account.
2. On initial course registration, show allowance, how LFS pointer files work, the difference between storage and downloaded-bandwidth quota, and how each version/attempt consumes more storage. Ask them to confirm understanding.
3. Before enabling submissions, configure `maxFileBytes`, `maxAttemptBytes`, `maxFiles`, `maxAttempts`, `maxTotalBytesPerStudent`, `allowedExtensions`, open/due/close dates. Warn on dangerously permissive defaults; server-side effective limits may only become stricter.
4. Display worst-case storage estimate: `number of eligible students × maxAttempts × maxAttemptBytes` (plus version updates and existing LFS data); display expected storage and possible downloads separately. Example: 60 learners × 3 attempts × 50 MiB = 9,000 MiB ≈ 8.79 GiB of new files. Show that a few large PDFs could exhaust a Free account's included 10 GiB storage. Do not promise quota availability based solely on estimates; real usage is shared across owner repos.
5. Offer presets: documents 25 MiB/file and 2 attempts; small lab datasets 100 MiB/file and 2 attempts; instructor-defined custom. Defaults are product choices, not GitHub or legal limits. Require explicit confirmation before allowing >100 MiB single file or huge course-wide potential.
6. In GitHub billing dashboard, creator can review quotas, budgets and overage behavior; link to official docs and instruct them to set account budgets/alerts. The platform does not charge those amounts or guarantee GitHub will accept uploads.
7. Show failed/paused states: missing permissions, private repo transferred, LFS unavailable, account quota exhausted, CORS proof unavailable, browser interrupted, digest mismatch. Preserve submissions' latest successful version and show precise retry steps.
8. Communicate that Git history may retain old pointers and LFS objects; deleting a file or accepting a resubmission may not reclaim all storage automatically. Owner has independent GitHub billing and retention duties. No student data is automatically published.

## UX and errors

- Private repo is mandatory for grade or student submission files. Enforce per-course student key anonymization and per-user file ownership through Worker authorization, never by handing a repository token to the browser.
- Default upload safety flag is **off**. The GitHub LFS delegated-object authorization must pass an end-to-end test before student upload UI is enabled. If not, show `LFS_DELEGATION_UNAVAILABLE` with a plain-language description and instructor help; do not imply that uploading worked or transfer files through the API by surprise.
- Owners can lower limits for future attempts. Changing limits must never retroactively destroy already accepted submissions or alter grades. Cost predictions exclude the course owner's other repos, video service and fees.
- Acceptance: LFS-G01 onboarding explains storage and bandwidth separately, with official URL; LFS-G02 worst-case calculator math and quota warnings validated; LFS-G03 policy enforced in API; LFS-G04 no unsafe token leakage; LFS-G05 exceeded quota/other failures actionable; LFS-G06 owner deauthorization removes future access without deleting grade audit.
