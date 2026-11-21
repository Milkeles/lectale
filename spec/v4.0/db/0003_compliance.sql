-- v3.1: compliance/audit records. Consent is optional-purpose only; necessary session cookies do not require consent.
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS consent_events (
 id TEXT PRIMARY KEY,
 uid TEXT REFERENCES users(uid),
 anonymous_key_hash TEXT,
 purpose TEXT NOT NULL CHECK(purpose IN ('analytics','marketing','third_party_media')),
 provider TEXT,
 granted INTEGER NOT NULL CHECK(granted IN (0,1)),
 policy_version TEXT NOT NULL,
 recorded_at TEXT NOT NULL,
 source TEXT NOT NULL CHECK(source IN ('web','android','ios','admin')),
 CHECK(uid IS NOT NULL OR anonymous_key_hash IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS idx_consent_events_uid ON consent_events(uid,recorded_at);
CREATE TABLE IF NOT EXISTS legal_acceptances (
 id TEXT PRIMARY KEY,
 uid TEXT NOT NULL REFERENCES users(uid),
 document_type TEXT NOT NULL CHECK(document_type IN ('terms','instructor_terms','purchase_terms','digital_delivery_consent')),
 document_version TEXT NOT NULL,
 accepted_at TEXT NOT NULL,
 order_id TEXT,
 evidence_json TEXT NOT NULL DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_legal_acceptances_user ON legal_acceptances(uid,document_type);
CREATE TABLE IF NOT EXISTS privacy_requests (
 id TEXT PRIMARY KEY,
 uid TEXT REFERENCES users(uid),
 contact_email_hash TEXT,
 request_type TEXT NOT NULL CHECK(request_type IN ('access','erase','rectify','restrict','object','portability','other')),
 state TEXT NOT NULL CHECK(state IN ('received','identity_check','in_review','completed','partially_completed','rejected')),
 received_at TEXT NOT NULL,
 due_at TEXT NOT NULL,
 completed_at TEXT,
 decision_reason TEXT,
 CHECK(uid IS NOT NULL OR contact_email_hash IS NOT NULL)
);
CREATE TABLE IF NOT EXISTS content_notices (
 id TEXT PRIMARY KEY,
 reporter_uid TEXT REFERENCES users(uid),
 target_type TEXT NOT NULL CHECK(target_type IN ('course','resource','instructor','other')),
 target_id TEXT NOT NULL,
 category TEXT NOT NULL,
 description TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('received','triage','resolved','rejected','appealed')),
 created_at TEXT NOT NULL,
 reviewed_at TEXT,
 decision_reason TEXT,
 reviewer_uid TEXT REFERENCES users(uid)
);
CREATE INDEX IF NOT EXISTS idx_content_notices_target ON content_notices(target_type,target_id,state);
CREATE TABLE IF NOT EXISTS accessibility_issues (
 id TEXT PRIMARY KEY,
 route_or_resource TEXT NOT NULL,
 severity TEXT NOT NULL CHECK(severity IN ('critical','high','medium','low')),
 issue_status TEXT NOT NULL CHECK(issue_status IN ('open','workaround','fixed','accepted_risk')),
 finding TEXT NOT NULL,
 found_at TEXT NOT NULL,
 fixed_at TEXT,
 reviewer TEXT
);
