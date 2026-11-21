# Full portable YAML contract v3 (authoritative field reference)

**This specifies the FORMAT, not a particular instructor's course.** Normative structural validators are `schemas/course-v3.schema.json`, `schemas/submission-v3.schema.json` and `schemas/grade-v3.schema.json`. Files in `templates/` show minimal and complete syntactic combinations. The sample in `examples/` is non-normative. JSON Schema Draft 2020-12 plus semantic validation together define validity. New files must use integer `schemaVersion: 3`. All YAML field names are case-sensitive. Unlisted keys are forbidden unless a new schema version explicitly permits them.

## 1. File locations

- `<content repository root>/course.yaml` is the **only mandatory author-created YAML document**. It stores global course metadata, an ordered nested outline and assignment definitions. There are no per-lesson YAML requirements.
- `<private submissions repository>/submissions/<studentKey>/<assignmentId>/attempt-<NNNN>/submission.yaml` is produced by the backend for each finalized GitHub-backed attempt. Do not ask students to write it.
- `<private submissions repository>/grades/<studentKey>/<assignmentId>.yaml` is an OPTIONAL backend-exported mirror of the authoritative D1 grade. Never trust a user commit as proof of a grade.
- Referenced PDF/video/notebook/other files do not have YAML sidecars; existing source file formats are preserved. File folder listing is derived at a pinned git SHA and rendered in manifest order plus deterministic filename order.

## 2. `course.yaml` — top-level

| Field | Required | Type / constraints | Semantics |
|---|---|---|---|
| `schemaVersion` | Yes | integer constant `2` | format dispatch |
| `course` | Yes | object | metadata, never owner permissions |
| `outline` | Yes | ordered array, 0..250 root nodes | modules, lessons and assignment references |
| `assignments` | Yes | array, 0..500 | assignment definitions (each stable ID) |
| `display` | No | object | non-security UI hints |

`outline` is a recursively ordered tree. A module may contain children that are modules (maximum nesting 5), lessons or assignment references. A course may contain top-level lessons/assignments without modules, so the format also works for very short courses.

## 3. `course` object

| Key | Required | Type / constraints | Meaning |
|---|---|---|---|
| `id` | Yes | lowercase slug, 1..80 chars; `^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$` | stable course identifier within manifest, separate from numeric GitHub repo ID |
| `title` | Yes | nonempty string <=160 | human title |
| `summary` | Yes | nonempty string <=2000 | short overview |
| `language` | Yes | lowercase ISO language code with optional uppercase region | `en`, `bg`, `en-US` etc |
| `version` | Yes | SemVer-like `major.minor.patch[-suffix]` | content format version display; does not replace SHA |
| `description` | No | string <=10000 | extended overview |
| `license` | No | string <=100 | applicable content license label |
| `level` | No | `introductory`, `intermediate`, `advanced`, `mixed` | descriptive difficulty |
| `tags` | No | array <=40 unique slug strings | discovery tags |
| `authors` | No | array <=30 of `{name, url?}` | display-only author references; not platform staff roles |
| `homepage` | No | HTTPS URL | optional public homepage |
| `cover` | No | canonical repo-relative path | display image |
| `estimatedMinutes` | No | integer 0..100000 | approximate duration |
| `publishedAt` | No | RFC3339 timestamp or null | author metadata; not verified publishing timestamp |

## 4. `outline` nodes

**Module node** required: `kind: module`, `id`, `title`, `children`. Optional: `description`. `children` can contain module, lesson or assignment reference. Maximum total nodes 2,000 and maximum nesting 5 (semantic rule). Node IDs unique across whole outline.

**Lesson node** required: `kind: lesson`, `id`, `title`, `resources` (an array, possibly empty). Optional: `description`, `recordedAt` (RFC3339 or null). The term "lesson" is generic: it can stand for a lecture, lab session, reading block, week or any learning unit. A lesson need not have a video.

**Assignment-reference node** required: `kind: assignment`, `id`, `assignmentId`. `assignmentId` must resolve to exactly one `assignments[].id`. A reference determines navigation position and does NOT duplicate the actual assignment definition.

## 5. `resource` object — every lesson and assignment material

| Key | Required | Type / constraints | Meaning |
|---|---|---|---|
| `id` | Yes | stable slug, unique within local resources list | stable UI resource key |
| `title` | Yes | string <=160 | student-facing title |
| `type` | Yes | `auto`, `pdf`, `notebook`, `markdown`, `image`, `video`, `audio`, `text`, `code`, `file`, `folder`, `external` | preferred viewer category, not security |
| `path` OR `url` | Yes | exactly ONE | canonical repository-relative file/folder path OR HTTPS URL |
| `description` | No | string <=3000 | optional context |
| `mediaType` | No | MIME hint `type/subtype` | advisory; never trust for security |
| `display` | No | `inline`, `attachment`, `auto` | desired presentation; `auto` default |
| `preview` | No | boolean | UI hint, true by default where safely supported |
| `download` | No | boolean | show download action; **not** DRM or ACL |
| `provider` | For URL-backed videos | `youtube`, `vimeo`, `external` | origin-checked embed adapter, never arbitrary iframe URL |
| `language` | No | language code | language hint for rendering |
| `recursive` | Folder only | boolean | whether to list nested entries; false by default |
| `maxEntries` | Folder only | integer 1..1000 | hard directory enumeration cap (default 100) |

A `folder` MUST use a repository `path`, cannot use `url`. An `external` MUST use an HTTPS `url`. All other types allow either URL or repository path. `provider` is permitted only on URL-backed `video`; it is required for URL-backed `video`. File-backed `video` has no provider. HTTPS is required for URL values, but **an HTTPS URL is not an automatic permission to embed or server-fetch that domain**.

`auto` is the general-purpose choice for unknown files. It instructs the frontend to inspect safe MIME and extension hints and choose the best supported viewer; when impossible it renders a useful in-app file card with download. `file` behaves as a generic attachment and may still be previewed if supported. `.docx`, `.pptx` or unusual proprietary binaries are not guaranteed to render faithfully; they remain discoverable/downloadable and can optionally be converted by an instructor offline. File-backed raw videos are permitted if provider/CDN can stream them; direct Git repo raw video hosting is not recommended.

## 6. `assignment` object

| Key | Required | Type / constraints | Meaning |
|---|---|---|---|
| `id` | Yes | unique slug | stable assignment key (do not reuse for different assignment) |
| `title` | Yes | string <=160 | student-facing title |
| `materials` | Yes | array of resource objects, may be empty | instructions PDF, starter notebook, attached files, videos, etc. |
| `submission` | Yes | submission policy object | allowed file submissions |
| `grading` | Yes | grading policy object | manual, automatic, or hybrid grading |
| `description` | No | string <=5000 | assignment instructions summary |
| `releaseAt` | No | timestamp or null | author-desired display time, enforced by Worker if course policy requires |

**`submission` required keys:** `allowedExtensions` (1..30 unique lowercase extensions, e.g. `.pdf`), `maxFileBytes` (integer >0), `maxAttemptBytes` (>0), `maxFiles` (1..100), `maxAttempts` (1..100).

**`submission` optional keys:** `maxTotalBytesPerStudent` (>0), `openAt`, `dueAt`, `closeAt` (RFC3339 or null), `allowLate` (boolean). Check logical chronological order and `maxAttemptBytes >= maxFileBytes`. A server-side owner-approved effective policy snapshot may only be **stricter** than manifest values and is authoritative for limiting storage and abuse. A changed file limit must not retroactively invalidate already-submitted work.

**`grading` required keys:** `mode: manual | automatic | hybrid`, `maxPoints` (>0..1e6). Optional: `allowRevisionAfterGrade` boolean. For `automatic` or `hybrid`, a `grading.automatic` object is required, as specified in `AUTOMATIC_GRADING.md` and `schemas/course-v3.schema.json`; it is forbidden for `manual`. In `hybrid`, release policy must be `review-required`. Scores are `null` until graded, and `0` is a valid score. Course YAML cannot designate graders, set trusted workflow approvals or confer execution permission. The grading workflow file and pinned SHA must be explicitly approved in D1 by a verified course instructor.

## 7. `display` object

All optional: `showEstimatedDuration` (boolean), `showFileDownloads` (boolean; UI hint), `themeAccent` (`#RRGGBB`). Defaults are application-defined, but absent display hints must not affect required resource discoverability or file access authorization.

## 8. Finalized `submission.yaml` (backend generated)

Required keys: `schemaVersion: 3`; `submissionId` unique `sub_<opaque>`; `courseId`, `assignmentId`, `studentKey` (`stu_<opaque>`); `attempt` positive integer; `status: submitted`; `submittedAt` timestamp UTC; `courseCommit` 40 lowercase hex git SHA; `files` nonempty list (up to 100).

Each `files[]` record requires `id`, `name`, `mediaType`, `sizeBytes`, `sha256` and `storage` (`github-lfs` only). `storage` MUST be `github-lfs`; `pointerPath` is required. The platform does not define any alternative large-file storage. `studentKey` is an opaque random per-course identifier: no email, name or Firebase UID appears in exported paths. Submission records are immutable once finalized; new attempts are new records.

## 9. Private `grade.yaml` (optional backend export)

Required: `schemaVersion: 3`, `gradeId`, `submissionId`, `courseId`, `assignmentId`, `studentKey`, `status` (`graded`, `returned`, `excused`), `score`, `maxPoints`, `graderKey` (`staff_<opaque>`), `gradedAt` timestamp UTC, `courseCommit`, and `revision` positive integer. Optional `feedback` (<=10000). Status `graded` requires numeric score between `0` and `maxPoints` inclusive; other statuses require `score: null`. Only D1-verified staff can cause such an export; the export is not source of authority.

## 10. Validation precedence and errors

1. Parse UTF-8 YAML with safe YAML 1.2 loader; reject duplicate keys, aliases/merges/tags, multiple documents, >1 MiB manifest.
2. Validate against correct Draft 2020-12 schema; reject unknown keys.
3. Apply semantic constraints in `SEMANTIC_VALIDATION.md`: IDs, reference integrity, path safety/existence at selected Git commit, folder enumeration, provider URLs, server limits, time ordering and content type consistency.
4. If invalid, show readable exact error (`JSON pointer`, reason, expected format), block publishing and retain last good published snapshot.
5. Never allow `course.yaml` to grant ownership, platform roles, GitHub permissions or private file access.

## 11. Schema evolution

`schemaVersion` controls parsing and is distinct from `course.version`. v3 is the only write format. Unknown future major schema version is read-only unsupported until a migration tool exists. Stable course/assignment/lesson IDs must not be reused; historical submissions pin `courseCommit` regardless of later edits.

## Commercial status never comes from YAML

A course may be free or paid regardless of the instructional-file syntax. The 5% commission, currency, immutable offer version, price, seller onboarding and buyer entitlements live only in D1/Stripe. Any price-like text in README or Markdown is ordinary untrusted prose; it grants no purchase right. Paid content must be private or held by a protected streaming provider.
