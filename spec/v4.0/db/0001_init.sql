PRAGMA foreign_keys = ON;
-- UUIDs are TEXT; GitHub numeric identifiers stored as TEXT to avoid precision problems.
-- All timestamps are ISO-8601 UTC strings; app enforces real time comparisons.
CREATE TABLE users (
 uid TEXT PRIMARY KEY,
 first_name TEXT NOT NULL CHECK(length(first_name) BETWEEN 1 AND 120),
 middle_name TEXT,
 last_name TEXT NOT NULL CHECK(length(last_name) BETWEEN 1 AND 120),
 certificate_name TEXT NOT NULL,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL
);
CREATE TABLE github_installations (
 installation_id TEXT PRIMARY KEY,
 account_id TEXT NOT NULL,
 account_login TEXT NOT NULL,
 connected_by_uid TEXT NOT NULL REFERENCES users(uid),
 state TEXT NOT NULL CHECK(state IN ('active','suspended','removed')),
 updated_at TEXT NOT NULL
);
CREATE TABLE courses (
 id TEXT PRIMARY KEY,
 manifest_slug TEXT NOT NULL,
 owner_uid TEXT NOT NULL REFERENCES users(uid),
 content_repo_id TEXT NOT NULL UNIQUE,
 content_repo_url TEXT NOT NULL,
 content_installation_id TEXT REFERENCES github_installations(installation_id),
 submission_repo_id TEXT UNIQUE,
 submission_installation_id TEXT REFERENCES github_installations(installation_id),
 default_branch TEXT NOT NULL,
 manifest_path TEXT NOT NULL DEFAULT 'course.yaml',
 last_validated_sha TEXT,
 manifest_version INTEGER NOT NULL DEFAULT 3,
 visibility TEXT NOT NULL CHECK(visibility IN ('public','private')),
 enrollment_policy TEXT NOT NULL CHECK(enrollment_policy IN ('open','approval','invite')),
 status TEXT NOT NULL CHECK(status IN ('draft','published','paused','archived')),
 storage_backend TEXT NOT NULL CHECK(storage_backend = 'github-lfs'),
 effective_policy_json TEXT NOT NULL DEFAULT '{}',
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX idx_courses_owner ON courses(owner_uid);
CREATE INDEX idx_courses_listing ON courses(status,visibility,created_at);
CREATE TABLE course_staff (
 course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
 uid TEXT NOT NULL REFERENCES users(uid),
 role TEXT NOT NULL CHECK(role IN ('owner','instructor','ta','grader')),
 created_at TEXT NOT NULL,
 PRIMARY KEY(course_id,uid)
);
CREATE TABLE enrollments (
 course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
 uid TEXT NOT NULL REFERENCES users(uid),
 student_key TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('pending','active','rejected','revoked','completed')),
 requested_at TEXT NOT NULL,
 decided_at TEXT,
 decided_by_uid TEXT,
 PRIMARY KEY(course_id,uid), UNIQUE(course_id,student_key)
);
CREATE INDEX idx_enrollments_course_state ON enrollments(course_id,state);
CREATE TABLE web_sessions (
 session_hash TEXT PRIMARY KEY,
 uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
 created_at TEXT NOT NULL, last_seen_at TEXT NOT NULL,
 expires_at TEXT NOT NULL, idle_expires_at TEXT NOT NULL,
 revoked_at TEXT
);
CREATE INDEX idx_sessions_uid ON web_sessions(uid,revoked_at);
CREATE TABLE submission_attempts (
 id TEXT PRIMARY KEY,
 course_id TEXT NOT NULL REFERENCES courses(id),
 assignment_id TEXT NOT NULL,
 uid TEXT NOT NULL REFERENCES users(uid),
 student_key TEXT NOT NULL,
 attempt_no INTEGER NOT NULL CHECK(attempt_no >= 1),
 status TEXT NOT NULL CHECK(status IN ('reserved','uploading','submitted','failed','cancelled')),
 course_sha TEXT NOT NULL,
 created_at TEXT NOT NULL, finalized_at TEXT,
 UNIQUE(course_id,assignment_id,uid,attempt_no)
);
CREATE INDEX idx_submissions_student ON submission_attempts(course_id,uid,assignment_id);
CREATE TABLE upload_reservations (
 id TEXT PRIMARY KEY,
 attempt_id TEXT NOT NULL REFERENCES submission_attempts(id) ON DELETE CASCADE,
 uid TEXT NOT NULL REFERENCES users(uid),
 storage_backend TEXT NOT NULL CHECK(storage_backend = 'github-lfs'),
 object_ref TEXT NOT NULL UNIQUE,
 filename TEXT NOT NULL, media_type TEXT NOT NULL,
 expected_bytes INTEGER NOT NULL CHECK(expected_bytes > 0),
 expected_sha256 TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('reserved','uploaded','verified','finalized','expired','failed')),
 expires_at TEXT NOT NULL, created_at TEXT NOT NULL, finalized_at TEXT
);
CREATE INDEX idx_uploads_attempt ON upload_reservations(attempt_id,state);
CREATE TABLE submission_files (
 reservation_id TEXT PRIMARY KEY REFERENCES upload_reservations(id),
 attempt_id TEXT NOT NULL REFERENCES submission_attempts(id),
 confirmed_bytes INTEGER NOT NULL, confirmed_sha256 TEXT,
 storage_ref TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE grades (
 course_id TEXT NOT NULL REFERENCES courses(id),
 assignment_id TEXT NOT NULL,
 uid TEXT NOT NULL REFERENCES users(uid),
 submission_id TEXT NOT NULL REFERENCES submission_attempts(id),
 state TEXT NOT NULL CHECK(state IN ('graded','returned','excused')),
 score REAL, max_points REAL NOT NULL CHECK(max_points > 0),
 feedback TEXT NOT NULL DEFAULT '',
 revision INTEGER NOT NULL CHECK(revision >= 1),
 graded_by_uid TEXT NOT NULL REFERENCES users(uid),
 graded_at TEXT NOT NULL,
 PRIMARY KEY(course_id,assignment_id,uid),
 CHECK ((state='graded' AND score IS NOT NULL AND score >= 0 AND score <= max_points)
   OR (state <> 'graded' AND score IS NULL))
);
CREATE TABLE grade_events (
 id TEXT PRIMARY KEY,
 course_id TEXT NOT NULL, assignment_id TEXT NOT NULL,
 uid TEXT NOT NULL, submission_id TEXT NOT NULL,
 revision INTEGER NOT NULL, old_value_json TEXT,
 new_value_json TEXT NOT NULL, actor_uid TEXT NOT NULL,
 created_at TEXT NOT NULL,
 UNIQUE(course_id,assignment_id,uid,revision)
);
CREATE TABLE certificates (
 id TEXT PRIMARY KEY,
 course_id TEXT NOT NULL REFERENCES courses(id),
 uid TEXT NOT NULL REFERENCES users(uid),
 recipient_name_snapshot TEXT NOT NULL,
 course_title_snapshot TEXT NOT NULL,
 course_sha TEXT NOT NULL,
 grade_snapshot_json TEXT NOT NULL,
 issued_by_uid TEXT NOT NULL REFERENCES users(uid),
 issued_at TEXT NOT NULL, revoked_at TEXT, revoke_reason TEXT
);
CREATE INDEX idx_cert_course_uid ON certificates(course_id,uid);
CREATE TABLE webhook_events (
 delivery_id TEXT PRIMARY KEY,
 event_name TEXT NOT NULL,
 installed_repo_id TEXT,
 received_at TEXT NOT NULL,
 processed_at TEXT,
 status TEXT NOT NULL CHECK(status IN ('pending','processed','ignored','failed'))
);
CREATE TABLE audit_events (
 id TEXT PRIMARY KEY,
 actor_uid TEXT, course_id TEXT,
 action TEXT NOT NULL, target_id TEXT,
 result TEXT NOT NULL, created_at TEXT NOT NULL,
 detail_json TEXT NOT NULL DEFAULT '{}'
);
CREATE INDEX idx_audit_course_date ON audit_events(course_id,created_at);
-- D1 application API must use prepared statements and transactions when state is coupled.
-- Implement data retention/batch expiration outside this initial migration.
