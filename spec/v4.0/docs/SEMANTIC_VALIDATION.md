# Normative v3 semantic validation (beyond JSON Schema)

- Parse one UTF-8 YAML document with safe loader, reject duplicate keys, custom tags and aliases or merge keys, and input > 1 MiB. YAML 1.2 typing only, never code execution.
- Reject unknown fields and unsupported `schemaVersion`. v1 is legacy, read-only, and never used for new publishing.
- Globally unique outline node IDs, resource IDs per containing list and assignment IDs; every assignmentRef must resolve to exactly one assignment. No unreferenced assignments at publication unless explicitly allowed by product settings. Max nesting 5 levels; max 2,000 total outline nodes and 10,000 resources.
- Canonicalize repo paths, reject traversal, backslashes, symlinks, submodules, .git paths, dotfiles unless allowlisted; validate paths exist at pinned SHA and typed file extension matches declared resource. A folder can contain at most maxEntries, default 100, never silently traverse beyond the configured limit.
- Only HTTPS URLs. Embed video only through explicit provider allowlist and safe ID-to-embed construction; external links are rendered as links, not arbitrary iframes. No server-side arbitrary URL fetch.
- Treat README, Markdown and notebook outputs as untrusted. HTML sanitization and restrictive CSP are mandatory; disable arbitrary scripts and iframe sandbox escape.
- Release/open/due/close timestamps must be chronological if present. `maxAttemptBytes >= maxFileBytes`; server-imposed absolute caps and owner-approved D1 snapshot win over YAML values.
- Course YAML is content, not authentication or authorization: no admin, role, private token, or certificate issuer can be established by YAML.
- Finalization checks actual provider-reported object size, reserved object key, ownership and upload validity; a claimed SHA-256 alone is not proof of received content unless provider verifies matching checksum.
- `score <= maxPoints`, submission attempt belongs to course and student, only staff can grade, grade revision monotonic, histories immutable.
- Private export never includes legal name or email. Course IDs + studentKey mapping exist only in D1.

- Every declared resource (including `type: auto` and `type: file`) must be listed in the UI. In-app preview required for PDF, video, notebook, Markdown, image, audio, code and text when safely decodable; unknown types have an in-app fallback card/download.
- For `video` URL, `provider` must be consistent with host; file-backed video has no provider. Unknown external domains cannot be embedded automatically.
- `preview` / `download` and `display` are presentation hints only; they do not grant or revoke permissions.

## v3 additional semantic requirements

For automatic/hybrid grading, require approved grading_config_approvals in D1 with exact workflow path and SHA, security limits and enabled state. Paid price and entitlement MUST NOT come from this file. For paid content, validate that protected materials are held in a private repository or approved signed-access provider, not public URL/unlisted video. Apply `docs/COMMERCE_AND_ACCESS.md` and `docs/AUTOMATIC_GRADING.md` even if manifest validates.

## Required root README

A published course MUST contain a non-empty `README.md` at root at the same pinned git commit as `course.yaml`. It supplies the full human-readable course description. `course.summary` is only a safe catalog teaser. Validate safe markdown and asset URL policy; restrict private README by enrollment/paid entitlement. See `README_COURSE_DESCRIPTION.md`.
