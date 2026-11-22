# Task: resource paths in the outline, and cover image guidance

| Intake | |
|---|---|
| **Why** | (1) Markdown lessons must resolve their own relative images and links, so the reader needs each repository resource's path; the owner approved adding `path` to `OutlineResource` (2026-11-22). (2) The owner asked for course thumbnail guidance: `course.cover` in course.yaml with a stated shape and minimum resolution. V4-CORE-01, V4-CORE-05, errata O2 below. |
| **Simpler** | One optional response field filled from the validated manifest; cover checks read only the image header bytes Lectale already fetches, never the whole image. |
| **Ready-made** | No new dependency. Image size comes from the format headers (PNG IHDR, JPEG SOFn, WebP VP8/VP8L/VP8X, AVIF ispe); about 120 lines with tests. |
| **Security** | `path` is the already-validated repository-relative path (SEC-012, SEC-020); no new route. Header parsing must be bounded (read at most the first 64 KiB, never trust declared sizes beyond 16384 px per side). |
| **Verify** | `npm --prefix apps/edge_api test` passes with new tests; `python3 tool/test_openapi_contract.py` passes; `just generate` then `git diff --exit-code` on generated clients after committing them (the CI drift check). |

## 1. `path` on `OutlineResource`

- In `spec/errata/openapi.yaml`, add optional `path` to `OutlineResource`: string, the resource's repository-relative path as validated (only for repository-backed resources; absent for URL-only ones). Describe it as "Repository-relative path at the pinned commit; used to resolve relative links and images in Markdown."
- Fill it in the Worker's projection (`apps/edge_api/src/preview/outline.ts`, the `present()` helper).
- Regenerate the TypeScript types (tool/codegen) and the Dart client (`just generate`), and update the OpenAPI contract test if it lists fields.
- Tests: a Markdown and a PDF resource carry `path`; a URL-only video does not.

## 2. Cover guidance (errata O2)

Add to `spec/errata/ERRATA.md`:

> **O2 Course cover guidance (owner request, 2026-11-22).** `course.cover` is the course thumbnail. Recommended: portrait 2:3, 1200 x 1800 px; minimum 600 x 900 px; AVIF, WebP, PNG or JPEG; at most 2 MB. Lectale shows covers at 2:3 and crops centrally when the ratio differs by more than 5 percent. A cover below the minimum, of another format or over 2 MB is reported as a warning at import (`cover_too_small`, `cover_format`, `cover_too_large`), never an error, and the course still opens with the placeholder cover.

Implement:
- A bounded header reader in the Worker (`apps/edge_api/src/preview/image-size.ts`) returning `{format, width, height}` or null, with unit tests per format, truncated input and absurd sizes.
- At import, when `course.cover` is set, read the cover's header through the existing pinned raw fetch (respect the existing fetch allowlist and size limits) and add the warnings above to the import response's warnings list (check the contract for the existing warnings field; if none exists, add an optional `warnings` array to the import response in `spec/errata/openapi.yaml` with `{code, message, path}` items).
- Document the guidance for instructors in `spec/errata/` only (the instructor guide comes later).

## Boundaries

Work only in this worktree. Don't commit or deploy. Report: files changed, Verify results with exact commands, anything you could not verify.
