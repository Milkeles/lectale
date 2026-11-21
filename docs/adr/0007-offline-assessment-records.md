---
status: accepted
date: 2026-11-21
---

# Offline assessment records for manual grading

## Context and problem statement

The spec promises manual grading even when uploads are blocked.
`spec/v4.0/FULL_SPECIFICATION.md` §13, gate 8 (line 787) says that if the LFS
delegation test fails, "Publishing/free course viewing/manual grade entry may
still work". Gate 6 (line 785) requires manual grading and grade history.

No record shape allows that. `grades.submission_id` is `NOT NULL` and
references `submission_attempts(id)` (`spec/v4.0/db/0001_init.sql`, line 105).
The grade route takes `submissionId` in its body
(`spec/v4.0/docs/API_SEMANTICS.md`). The submission schema requires a
non-empty `files` list of `github-lfs` objects
(`spec/v4.0/schemas/submission-v3.schema.json`, `files` with `minItems: 1`).
So every grade needs an LFS upload, and uploads stay off until the S1 spike
proves a safe delegated upload. The plan expects that spike to fail, because
GitHub documents no browser-scoped LFS upload credential (docs.github.com,
fetched 2026-11-21). This is erratum E5. The owner decided the resolution.

## Decision drivers

- Manual grading must work with `LFS_DIRECT_UPLOAD_ENABLED=false`.
- Do not weaken the submission schema or fake uploads.
- Grades stay append-only and audited (`grade_events`).

## Considered options

- A separate "offline assessment" record: work done outside the platform
  (exam, oral, in-person, emailed file) that a grader scores.
- Make `grades.submission_id` nullable.
- Create a synthetic submission with a placeholder file.
- Wait for the LFS proof of concept.

## Decision outcome

Chosen option: "an offline assessment record". It ties a grade to a course,
assignment and learner without any submission or file. Grading then does not
depend on the LFS proof of concept. The exact table and DTO are designed in
M7 as an additive D1 migration and an erratum to the OpenAPI document.

A nullable `submission_id` would let a grade point at nothing and weaken the
integrity checks in erratum E8. A synthetic file would break the schema rule
that a submission holds real LFS objects. Waiting leaves the spec's own gate
8 unmet.

### Consequences

- Good, because instructors can grade from M7 whether or not uploads
  ever ship.
- Good, because the submission and grade-integrity rules stay strict.
- Bad, because there are two ways to produce a grade (submission and offline
  record). Reports, certificates and the learner's "my grades" view must read
  both.
- Bad, because the grade YAML export (`schemas/grade-v3.schema.json`,
  `submissionId` required) needs an erratum too.

### Confirmation

- An integration test grants a grade through an offline record with
  `LFS_DIRECT_UPLOAD_ENABLED=false` and no rows in `submission_attempts`.
- A test shows a student reads only their own offline grades (V4-SEC-06).
- Traceability: V4-CORE-06 (certificates read grades) in `docs/traceability.md`.

## More information

Owner decision, 2026-11-21. Related: erratum E8 (grade integrity), M6 and M7
in the plan.
