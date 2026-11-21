# V3 upgrade summary

This v3 adds opt-in paid courses (creator payout and 5% fee) and optional owner-funded GitHub Actions grading. All of v2's viewer, repo-by-link, Firebase/Auth cookies, D1, GitHub authorization, secure Git LFS upload release gate, certificates, domain/no-domain and cost constraints remain in scope.

**Normative precedence:** Security invariants and signed provider events > JSON Schema v3 and `COMMERCE_AND_ACCESS.md` / `AUTOMATIC_GRADING.md` > D1 migrations and API > documentation and templates > historical v2 folder.

A course authored as `schemaVersion:2` is only imported read-only and migrated through validation; never auto-publish a newly generated v2 course. Paid price never comes from YAML. Every automatic grader workflow is instructor-approved/pinned in D1. Feature flags default disabled until all payment/tax/video/app store and execution-security gates pass.

**v3.1 authoritative:** root README description, EU privacy/cookies/WCAG/commercial compliance, the sole Git LFS file backend, and error semantics are mandatory and override legacy examples.
