# Failure, retry and cost containment contract — v3.1

Error objects are stable `{code, message, requestId, retryable, retryAfterSeconds?, details?}`, with a human-readable accessible message and no secrets. Cloudflare API, payment, GitHub LFS and client failures MUST be explicit and recoverable; never show "success" merely because a client received a signed URL or a checkout redirect.

## Upload lifecycle

- Use `reserved -> transferring -> verifying -> submitted` or `reserved/transferring/verifying -> expired/failed` with idempotency key scoped to UID, course, assignment and attempt. Reserve size, SHA-256, MIME and deterministic destination server-side. Do not create a second attempt on retry. No name/email/UID in GitHub paths.
- Large upload preflight checks: enrollment, course/assignment status, allowed media types, max single file/total attempt bytes, per-user attempt cap, course owner LFS quota warning/limits, GitHub App installation and secure delegation gate. If git-lfs direct-upload proof is missing or fails, return `LFS_DELEGATION_UNAVAILABLE`, HTTP 503 and do not grant a repository token. If exceeding instructor limits, `FILE_TOO_LARGE` 413; unsupported type 415; assignment closed 409; capacity/owner billing blocked 507 or provider-specific typed status.
- Owner quota exceeded or GitHub returns billing/403/429: leave attempt retryable where appropriate, show `OWNER_STORAGE_QUOTA_EXCEEDED`, provide instructor-facing quota help and request ID; honor Retry-After, do not retry aggressively. Max attempts/bandwidth enforced before authorizing work, but owner GitHub billing is ultimately controlled by owner.
- Verify actual upload completion (size, digest, object availability). Pointer commit and D1 finalize must be idempotent and carry a commit SHA; after a partial GitHub success, reconcile via object hash/path rather than duplicate. Orphaned LFS objects are possible: warn instructor that abandoned uploads may count toward their GitHub storage and that garbage collection may not free billed objects immediately.
- Timeout and client reload: resumability support only if protocol supports it; otherwise surface a clear re-upload. Frontend must provide progress, cancel and retry, but cancel never falsely claims object deletion.

## Grades and payments

- Grade revision uses optimistic concurrency, append-only audit and role authorization; manual overwrite conflict -> 409 with latest revision. Automatic grading job timeout/failure -> ungraded pending review, not zero points.
- Stripe webhook signature errors -> 400, internal transient errors -> retriable 5xx with idempotent event store, permanent bad event -> audited. Checkout redirect does not prove purchase; refund, chargeback and payout errors shown to appropriate parties with human escalation. Do not duplicate application fee on retries.
- Course repo rename/transfer/404/app revoked: pause writes and show actionable instructor reconnect; preserve grade/entitlement records. GitHub 429 and secondary rate limits -> back off; do not hammer.
- Inaccessible private README/file/video, removed externally hosted lecture, expired cookie, offline native app, stale branch, schema validation error, invalid PDF/notebook: show descriptive accessible fallback and retry/help; do not leak the private original URL in errors.
- Prevent denial of wallet: GitHub per-student/file attempt limits; Workers daily budget/CPU caps and logging limits; payment webhook replay protection; no unbounded fanout/retry; alerts before paid thresholds.

### Test matrix

ERR-001 oversized PDF rejected before upload authorization. ERR-002 replay reservation/finalize cannot overwrite another student's files. ERR-003 LFS unverified returns blocked error with zero credential leakage. ERR-004 GitHub 429 respects retry. ERR-005 partial commit reconciles without duplicating attempts. ERR-006 expired Firebase/session causes safe reauth, no loss of local unsent file. ERR-007 external video 404 accessible fallback. ERR-008 automatic grading fails safe; no zero score. ERR-009 Stripe webhook repeated/out-of-order no duplicate entitlement. ERR-010 user sees meaningful error and support reference for every failure.
