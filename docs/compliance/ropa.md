# Record of processing activities (Article 30), draft stub

> **DRAFT. The owner must complete it. This is not a statement of compliance.** It lists what the spec says D1 will hold, so the owner and counsel have something to check. It was not reviewed by a lawyer. Nothing here is a legal determination. `spec/v4.0/docs/EU_PRIVACY_COOKIES.md` requires counsel review before public signups or payments.

| | |
|---|---|
| **Owner** | Milkeles (project owner), as the intended controller. Not yet confirmed. |
| **Status** | Draft stub from M0. No personal data is processed yet: D1 migrations do not exist in production. |
| **Last reviewed** | 2026-11-21 |
| **Review cadence** | On each trigger below, and once a year against the real list of data stores and processors. |
| **Review trigger** | A new D1 column holding personal data, a new processor, a new country, a new purpose. |
| **Location** | `docs/compliance/ropa.md` |
| **Sources** | `spec/v4.0/docs/EU_PRIVACY_COOKIES.md` (PRIV-001 to PRIV-006), `spec/v4.0/db/0001_init.sql` to `0004_catalog_discovery.sql`, `spec/v4.0/docs/SESSION_SECURITY.md` |

## 1. Controller details (Article 30(1)(a))

To be completed by the owner. The spec says code generators must not invent legal identity or contact fields.

| Item | Value |
|---|---|
| Controller name and legal form | *To be decided by the owner* |
| Contact address | *To be decided by the owner* |
| Data protection officer | *To be decided by the owner (whether one is needed)* |
| EU representative | *To be decided by the owner* |
| Roles of instructors | *To be decided: the spec says to determine controller and processor arrangements among the platform, instructors, GitHub, Firebase, Cloudflare, video hosts and the payment processor.* |

This record covers the controller role only. A processor record (Article 30(2)) is needed only if the owner decides to act as a processor for instructors.

## 2. Processing activities

Lawful basis is **to be decided by the owner** for every row. The spec asks for a documented basis per purpose and rules out blanket consent. Retention is given only where a spec file states it; otherwise "not stated in the spec".

| # | Activity | Personal data held in D1 | Data subjects | Purpose | Lawful basis | Retention | Processors |
|---|---|---|---|---|---|---|---|
| 1 | Accounts | `users`: `uid`, `first_name`, `middle_name`, `last_name`, `certificate_name`, timestamps | Learners, instructors | Identify the account holder and show a name to staff | To be decided by the owner | Not stated in the spec | Firebase/Google (sign-in), Cloudflare (D1) |
| 2 | Web sessions | `web_sessions`: SHA-256 of the session ID, `uid`, created, last seen, expiry, revoked time | Signed-in users | Keep a user signed in | To be decided by the owner | 12 hours absolute, 30 minutes idle, from `SESSION_SECURITY.md` step 3. Deletion of expired rows is not stated. | Cloudflare |
| 3 | GitHub connection | `github_installations`: installation ID, account ID, account login, connecting `uid`; `courses`: owner `uid`, repo ID and URL | Instructors | Let the Worker read and write course repositories | To be decided by the owner | Not stated in the spec | GitHub, Cloudflare |
| 4 | Course staff and roles | `course_staff`: `uid`, role | Instructors, TAs, graders | Enforce access control | To be decided by the owner | Not stated in the spec | Cloudflare |
| 5 | Enrollment | `enrollments`: `uid`, `student_key`, state, decision time, deciding `uid`; `course_entitlements` | Learners | Decide who may read a course | To be decided by the owner | Not stated in the spec | Cloudflare |
| 6 | Submissions | `submission_attempts`, `upload_reservations` (filename, media type, checksum), `submission_files`. File contents are in the instructor's GitHub repository, not D1. | Learners | Hold coursework for grading | To be decided by the owner | `upload_reservations` carry an `expires_at`; no retention period is stated. PRIV-004 names submissions and upload reservations as needing one. | GitHub, Cloudflare |
| 7 | Grades and feedback | `grades` (including free-text `feedback`), `grade_events` (old and new values, actor) | Learners, graders | Record and justify grades | To be decided by the owner | Not stated in the spec | Cloudflare |
| 8 | Certificates | `certificates`: `recipient_name_snapshot`, course title, grade snapshot, issuer, revocation reason | Learners | Issue a certificate others can verify | To be decided by the owner | Not stated in the spec | Cloudflare |
| 9 | Consent receipts | `consent_events`: `uid` or `anonymous_key_hash`, purpose, provider, granted, policy version, time, source | Users and anonymous visitors | Prove an optional-purpose choice (analytics, marketing, third-party media) | To be decided by the owner | Not stated in the spec | Cloudflare |
| 10 | Legal acceptances | `legal_acceptances`: `uid`, document type and version, time, order ID, `evidence_json` | Users | Prove acceptance of terms | To be decided by the owner | Not stated in the spec | Cloudflare |
| 11 | Privacy requests | `privacy_requests`: `uid` or `contact_email_hash`, type, state, received, due and completed times, decision reason | Requesters | Handle access, erasure and other requests on time | To be decided by the owner | Not stated in the spec | Cloudflare |
| 12 | Content notices | `content_notices`: reporter `uid`, target, category, free-text `description`, reviewer `uid`, decision | Reporters, reviewers, reported instructors | Handle content reports and delisting | To be decided by the owner | Not stated in the spec | Cloudflare |
| 13 | Audit and webhook log | `audit_events`: actor `uid`, course, action, target, result, `detail_json`; `webhook_events` (no personal data beyond repo ID) | Staff, users acting | Security and accountability | To be decided by the owner | Not stated in the spec; the spec says security audit logs need a retention period | Cloudflare |
| 14 | Catalog listing (**optional**, M10) | `courses.catalog_*` columns, `catalog_search_terms`. The spec says they hold public-safe text, not student names. | Instructors (as authors) | Let people find public courses | To be decided by the owner | Not stated in the spec | Cloudflare |
| 15 | Paid courses (**optional**, M9) | `commerce_orders`: `buyer_uid`, Stripe session, payment intent and charge IDs, amount, state; `commerce_adjustments`; `creator_payment_accounts` (connected account ID); `stripe_webhook_events` | Buyers, instructors | Sell and refund courses | To be decided by the owner | Not stated in the spec; PRIV-004 names purchase records | Stripe, Cloudflare |
| 16 | Automatic grading (**optional**, M8) | `grading_jobs`, `grading_job_events`, `grading_config_approvals`: `owner_uid`, `result_json` | Learners, instructors | Run and record instructor-defined grading | To be decided by the owner | Not stated in the spec | GitHub (Actions), Cloudflare |
| 17 | Sign-in identity | Not in D1. Firebase holds email address and credentials; D1 holds only the `uid`. | All signed-in users | Authenticate | To be decided by the owner | Held by Firebase; period not stated in the spec | Firebase/Google |

**Special categories.** The spec lists none. Free-text fields (`feedback`, `content_notices.description`, `privacy_requests.decision_reason`, `evidence_json`, `detail_json`) can collect data nobody planned for, including health data a learner volunteers. The owner should decide how to warn users and how to find such data.

**Data not held.** The spec keeps no analytics, advertising or tracking data by default (PRIV-002, COOKIE-005). No IP address column appears in any migration. Cloudflare and GitHub may still log IP addresses at their own layer.

## 3. Recipients and processors

| Recipient | Role (to be confirmed) | What it receives | Transfer outside the EU/EEA |
|---|---|---|---|
| Cloudflare | Processor: hosts the Worker and D1 | All rows in section 2; request logs | To be decided by the owner; no mechanism chosen |
| Firebase / Google | Processor: sign-in | Email address, credentials, `uid`, ID-token requests | To be decided by the owner; no mechanism chosen |
| GitHub | Processor or independent controller, to be decided | Course repository content, installation IDs, submission files (LFS, if enabled), Actions runs | To be decided by the owner; no mechanism chosen |
| Stripe (**optional**) | To be decided | Buyer and order data, connected account data | To be decided by the owner; no mechanism chosen |
| YouTube, Vimeo | Third parties, loaded only after the user asks (COOKIE-003) | The viewer's IP address and cookies, when a video loads | To be decided by the owner |
| Instructors | To be decided | Their students' names, grades and submissions | Not applicable |

The spec requires data processing agreements and a subprocessor inventory (PRIV-005). Neither exists yet.

## 4. Security measures (Article 30(1)(g), summary)

Planned in `docs/security/threat-model.md`: encryption in transit, hashed session IDs, default-deny access control, secrets only in Workers Secrets and Actions. Implemented today: CI scanning and agent guard hooks, which protect the code, not user data, since none is held yet.

## 5. Gaps in the spec found while writing this stub

1. `PRIV-001` lists "Firebase UID/email" as inventory, but `users` has no email column. The email is held in Firebase. `contact_email_hash` in `privacy_requests` is the only email-derived value in D1. The owner should confirm that D1 never stores an email address.
2. No spec file gives a number for retention of any D1 table. `EU_PRIVACY_COOKIES.md` PRIV-004 asks for defaults, and `0001_init.sql` line 154 says to implement retention outside that migration. `db/0003_compliance.sql` states no retention. The only periods in the spec are the session lifetimes. A data retention policy (`docs/compliance/`) must set the rest.
3. `SESSION_SECURITY.md` lists an "auth state version" for sessions, which `web_sessions` lacks.
4. The spec says to inventory "security logs", but only `audit_events` exists. Cloudflare Workers logs are not described.

## 6. Next steps for the owner

- Name the controller, contact address and any DPO.
- Choose a lawful basis for each row.
- Set retention periods and write the retention policy.
- Settle roles for instructors, GitHub and Stripe, and the transfer mechanism for each non-EU processor.
- Have counsel review this record before public signups (`EU_PRIVACY_COOKIES.md`, legal gate).
- Decide whether a DPIA is needed for certificates and the catalog.
