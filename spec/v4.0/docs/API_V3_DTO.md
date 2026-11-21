# V3 API request/response semantics — normative implementation detail

This document supplements `api/openapi.yaml`. `POST`/`PATCH` operations require the existing web cookie session and exact same-origin `X-CSRF-Token` and Origin checks, or verified Firebase Bearer ID token for native clients. Use stable internal IDs, never client-supplied Firebase UID, course owner, Stripe account, price, platform fee, repo path or grade authority. All private responses `Cache-Control: no-store`. Pagination enforced for lists; rate-limit all mutations. The API prefix is `/api` on the same web origin.

## Creator account and offers

`POST /creators/payments/onboard`:

- Body `{ "returnPath": "/instructor/payment-settings" }`, where `returnPath` must be an allowed relative path (or ignore it and use a fixed route). Backend identifies creator from session, creates/links their Stripe connected account only if verified and permitted. Response `200 {"onboardingUrl":"https://connect.stripe.com/...","accountState":"pending"}`. Never expose Stripe API secret or account data not meant for the creator.

`GET /creators/payments/status`:

- `200 {"status":"pending|restricted|ready|disabled","chargesEnabled":true,"payoutsEnabled":true}` derived from recent provider data; do not let the client self-certify it.

`POST /courses/{courseId}/offers/configure`:

- Owner-only body `{ "priceMinor": 2000, "currency": "EUR", "publish": true }`. Server sets `feeBasisPoints=500` unconditionally; no currency amount with floating point. Needs account ready, merchant/tax gates approved, protected content readiness and course owner verification. Response `200 {"offerId":"off_...","version":1,"priceMinor":2000,"currency":"EUR","feeBasisPoints":500,"status":"active"}`. Price change produces version+1, not edit of active offer; paused and retired offers cannot be resurrected with the same version.

`GET /courses/{courseId}/offers`:

- Public result `200 {"courseId":"...","mode":"free|paid","offer":null}` for free or `{ "courseId":"...","mode":"paid","offer": {"offerId":"off_...","currency":"EUR","priceMinor":2000,"version":1,"status":"active"} }`. No private repository path, private material URLs or buyer details.

## Checkout and entitlements

`POST /courses/{courseId}/checkout`:

- Authenticated learner body `{ "offerId":"off_...","idempotencyKey":"random-client-request-key" }`. The idempotency key is transport deduplication, not trusted order identity. Server loads D1 offer, session UID, seller account and course state; computes 5% of eligible subtotal in minor units; creates internal order, then a Stripe-hosted Checkout Session using a server-generated Idempotency-Key tied to internal order ID. Return `201 {"orderId":"ord_...","checkoutUrl":"https://checkout.stripe.com/..."}`. If entitled already return `409 {"code":"ALREADY_ENTITLED"}` or offer an explicit continue route. A network retry with same checkout intent must not duplicate charges.

`GET /orders/{orderId}`:

- Buyer only, `200 {"orderId":"...","courseId":"...","state":"created|checkout_pending|paid|failed|refunded|partially_refunded|disputed|cancelled","entitlementState":"pending|active|revoked"}`. No card numbers, no other buyer's invoice.

`GET /courses/{courseId}/entitlement`:

- Authenticated requester, `200 {"courseId":"...","access":"granted|pending|denied","source":"free_enrollment|purchase|staff_grant|null"}`. This is a convenient check but content routes must independently verify access; never trust client-cached state.

`POST /stripe/webhook`:

- No Firebase cookie/bearer required. Verify `Stripe-Signature` against RAW request bytes and the server-side endpoint secret; reject invalid signatures. Accept provider event types necessary to handle successful payments and asynchronous events, refund, chargebacks, creator account status. Record `event_id` as idempotency key; verify amount, currency, connected account, and checkout session belong to internal order. Apply updates transactionally; on signature failure respond `400` without side effects. Keep a repair path for out-of-order webhooks. Never allow arbitrary client to call a “mark paid” endpoint.

## Owner-approved autograding

`POST /courses/{courseId}/grading/config`:

- Instructor/owner only, body `{ "assignmentId":"assignment-id","workflowPath":".github/workflows/grade-submission.yml","workflowCommitSha":"0123456789abcdef0123456789abcdef01234567","maxRunsPerAttempt":2,"maxTimeoutMinutes":10,"state":"approved" }`. Must validate repo ownership, GitHub installation and exact private grading workflow; do not trust path alone. Create/update explicit D1 approval. Subsequent workflow changes require new approval.

`POST /courses/{courseId}/submissions/{submissionId}/grading-jobs`:

- Body `{ "idempotencyKey":"opaque-request-key" }`; server locates verified finalized attempt and approved assignment, checks rate/cost caps and selects approved workflow SHA. Response `202 {"jobId":"job_...","status":"queued"}`. Automatic on-submit can invoke this through a trusted internal task; student cannot pick workflow or run arbitrary commands.

`GET /courses/{courseId}/submissions/{submissionId}/grading-jobs`:

- Student gets own redacted statuses, staff get authorized course statuses. Example `200 {"jobs":[{"jobId":"job_...","state":"completed","scoreProposed":70,"maxPoints":100,"requiresReview":true}]}`. Do not expose raw logs containing secrets or other students' submissions.

`POST /courses/{courseId}/grading-jobs/{jobId}/review`:

- Instructor/grader with staff permission only, body `{ "decision":"approve|override|reject","score":70,"feedback":"..." }`; on approve/override validate score `0<=score<=effectiveMaxPoints`, atomically publish grade, update `grades` and append `grade_events`, preserve autograding job and original proposal. On reject keep submission ungraded and permit manual grade. Requests must be revision-checked/idempotent to avoid lost updates.

## Storage, errors and tests

- Standard error `{ "code":"UPPER_SNAKE_CASE", "message":"Safe public explanation", "requestId":"opaque" }`; never echo Stripe/GitHub tokens or internal repository data.
- Use `401` for unauthenticated, `403` for forbidden (or masked `404` for confidential resource existence), `409` for conflicts, `422` for invalid inputs, `429` with retry information for rate limits, `503` for upstream outages, `500` only for sanitized unexpected failures.
- Payment callback requires webhook event signature; the separate authenticated web checkout user redirect may never directly mutate order to paid.
- Do not let rejected or incomplete payments create active enrollment or content authorization. Chargeback/refund adjustments may change entitlements by documented policy without destroying historical academic records.
- Auto grading work must not be run in the API request or behind long-running Workers; dispatch GitHub Actions and return 202. Job completion is eventual; frontend polls with bounded exponential backoff or uses periodic refresh.
