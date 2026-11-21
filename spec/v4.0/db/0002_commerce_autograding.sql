-- 0002: One-time paid courses and optional instructor-billed automated grading.
-- D1 schema: append only; do not embed payment credentials or card details in D1.
PRAGMA foreign_keys = ON;
ALTER TABLE courses ADD COLUMN commerce_mode TEXT NOT NULL DEFAULT 'free' CHECK(commerce_mode IN ('free','paid'));
ALTER TABLE courses ADD COLUMN sales_status TEXT NOT NULL DEFAULT 'not_enabled' CHECK(sales_status IN ('not_enabled','pending_review','active','suspended'));
CREATE TABLE creator_payment_accounts (
 id TEXT PRIMARY KEY,
 owner_uid TEXT NOT NULL REFERENCES users(uid),
 processor TEXT NOT NULL CHECK(processor='stripe_connect'),
 connected_account_id TEXT NOT NULL UNIQUE,
 onboarding_state TEXT NOT NULL CHECK(onboarding_state IN ('pending','restricted','ready','disabled')),
 charges_enabled INTEGER NOT NULL DEFAULT 0 CHECK(charges_enabled IN (0,1)),
 payouts_enabled INTEGER NOT NULL DEFAULT 0 CHECK(payouts_enabled IN (0,1)),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX idx_creator_accounts_owner ON creator_payment_accounts(owner_uid);
CREATE TABLE course_offers (
 id TEXT PRIMARY KEY,
 course_id TEXT NOT NULL REFERENCES courses(id),
 creator_payment_account_id TEXT NOT NULL REFERENCES creator_payment_accounts(id),
 status TEXT NOT NULL CHECK(status IN ('draft','active','paused','retired')),
 currency TEXT NOT NULL CHECK(length(currency)=3),
 price_minor INTEGER NOT NULL CHECK(price_minor > 0),
 fee_basis_points INTEGER NOT NULL DEFAULT 500 CHECK(fee_basis_points=500),
 version INTEGER NOT NULL CHECK(version>=1),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 UNIQUE(course_id,version)
);
CREATE INDEX idx_offers_course_status ON course_offers(course_id,status);
CREATE TABLE commerce_orders (
 id TEXT PRIMARY KEY,
 buyer_uid TEXT NOT NULL REFERENCES users(uid),
 course_id TEXT NOT NULL REFERENCES courses(id),
 offer_id TEXT NOT NULL REFERENCES course_offers(id),
 stripe_checkout_session_id TEXT UNIQUE,
 stripe_payment_intent_id TEXT UNIQUE,
 stripe_charge_id TEXT UNIQUE,
 amount_subtotal_minor INTEGER NOT NULL CHECK(amount_subtotal_minor>=0),
 tax_minor INTEGER NOT NULL DEFAULT 0 CHECK(tax_minor>=0),
 total_minor INTEGER NOT NULL CHECK(total_minor>=0),
 currency TEXT NOT NULL CHECK(length(currency)=3),
 platform_fee_minor INTEGER NOT NULL CHECK(platform_fee_minor>=0),
 state TEXT NOT NULL CHECK(state IN ('created','checkout_pending','paid','failed','refunded','partially_refunded','disputed','cancelled')),
 created_at TEXT NOT NULL, paid_at TEXT, updated_at TEXT NOT NULL,
 UNIQUE(buyer_uid,course_id,id)
);
CREATE INDEX idx_orders_buyer ON commerce_orders(buyer_uid,created_at);
CREATE INDEX idx_orders_course_state ON commerce_orders(course_id,state);
CREATE TABLE course_entitlements (
 course_id TEXT NOT NULL REFERENCES courses(id),
 uid TEXT NOT NULL REFERENCES users(uid),
 source TEXT NOT NULL CHECK(source IN ('free_enrollment','purchase','staff_grant')),
 order_id TEXT REFERENCES commerce_orders(id),
 state TEXT NOT NULL CHECK(state IN ('active','revoked','pending')),
 granted_at TEXT NOT NULL, revoked_at TEXT,
 PRIMARY KEY(course_id,uid)
);
CREATE TABLE stripe_webhook_events (
 event_id TEXT PRIMARY KEY,
 event_type TEXT NOT NULL,
 received_at TEXT NOT NULL,
 processed_at TEXT,
 state TEXT NOT NULL CHECK(state IN ('received','processed','ignored','failed')),
 failure_reason TEXT
);
CREATE TABLE commerce_adjustments (
 id TEXT PRIMARY KEY,
 order_id TEXT NOT NULL REFERENCES commerce_orders(id),
 stripe_object_id TEXT UNIQUE,
 kind TEXT NOT NULL CHECK(kind IN ('refund','partial_refund','chargeback','chargeback_reversed','manual_adjustment')),
 amount_minor INTEGER NOT NULL CHECK(amount_minor>=0),
 currency TEXT NOT NULL CHECK(length(currency)=3),
 processed_at TEXT NOT NULL,
 detail_json TEXT NOT NULL DEFAULT '{}'
);
CREATE TABLE grading_config_approvals (
 course_id TEXT NOT NULL REFERENCES courses(id),
 assignment_id TEXT NOT NULL,
 workflow_path TEXT NOT NULL,
 workflow_commit_sha TEXT NOT NULL,
 approved_by_uid TEXT NOT NULL REFERENCES users(uid),
 approved_at TEXT NOT NULL,
 max_runs_per_attempt INTEGER NOT NULL CHECK(max_runs_per_attempt BETWEEN 1 AND 10),
 max_timeout_minutes INTEGER NOT NULL CHECK(max_timeout_minutes BETWEEN 1 AND 60),
 state TEXT NOT NULL CHECK(state IN ('approved','paused','revoked')),
 PRIMARY KEY(course_id,assignment_id)
);
CREATE TABLE grading_jobs (
 id TEXT PRIMARY KEY,
 submission_id TEXT NOT NULL REFERENCES submission_attempts(id),
 course_id TEXT NOT NULL REFERENCES courses(id),
 assignment_id TEXT NOT NULL,
 owner_uid TEXT NOT NULL REFERENCES users(uid),
 github_run_id TEXT UNIQUE,
 workflow_commit_sha TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('queued','dispatched','running','completed','failed','timed_out','cancelled')),
 proposed_score REAL,
 proposed_max_points REAL,
 result_json TEXT,
 attempt_number INTEGER NOT NULL CHECK(attempt_number>=1),
 created_at TEXT NOT NULL, completed_at TEXT,
 UNIQUE(submission_id,attempt_number)
);
CREATE INDEX idx_grading_jobs_submission ON grading_jobs(submission_id,created_at);
CREATE TABLE grading_job_events (
 id TEXT PRIMARY KEY, job_id TEXT NOT NULL REFERENCES grading_jobs(id),
 state TEXT NOT NULL, source TEXT NOT NULL, detail_json TEXT NOT NULL DEFAULT '{}',
 occurred_at TEXT NOT NULL
);
-- Grade history stays in grades/grade_events; auto results are PROPOSALS until approved
-- or explicitly auto-released under a verified course-owner policy.
