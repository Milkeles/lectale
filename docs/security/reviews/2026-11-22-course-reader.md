# Security review: Course and Reader screens (2026-11-22)

Reviewer: the security-reviewer agent (read-only). Commit 2405a59. Verdict: **fix first**. No critical or high findings; Codex rated the image decode issue high ([its review](../../ux/reviews/2026-11-22-course-reader-codex.md)).

## Medium

1. **Image bombs and no byte limit on images** (`sized_image.dart:94-110`, `content_image.dart:44`, `image_viewer.dart:82`, `course_cover.dart:47-60`). A small PNG whose header declares 20000×20000 is decoded at full size; `cacheWidth` doesn't help, and a 1×N image bypasses it. Fix: refuse sizes above a cap from the header before decoding, and pass `maxBytes` on every read. Test with a header-only bomb.
2. **The app-side trust boundary has no tests** (`preview_host.dart:34-66`, `router.dart:22-29`). Test the real `PreviewResourceHost`: a foreign repoId or sha, `..`, `//`, and a non-files href are refused, and a bad deep link redirects to `/open`. Add Markdown cases for `&#106;avascript:`, `javascript%3A`, `<javascript:alert(1)>`, `%2e%2e/x.png`, `intent:` and `file:`.

## Low

3. **`http:` links are allowed** (`repository_path.dart:147`). `SEMANTIC_VALIDATION.md:7` says "Only HTTPS URLs", and it takes precedence. **Decision (orchestrator, 2026-11-22): HTTPS only.** An `http:` link renders as text, with its host shown.
4. **The shown host can mislead** (`inline_composer.dart:153`, `file_card.dart:111`). Show the punycode (ASCII) form and reject hosts outside `[a-z0-9.-]`.
5. **A provider label is shown without a host check** (`registry.dart:127-141`). Show "Watch on YouTube" or "Vimeo" only when the host belongs to that provider; otherwise show a generic link card.

## Checked and clean

- Raw HTML (inline and block) stays text.
- The link allowlist is https with a host, with case, whitespace, control-character and percent-encoding tricks refused.
- `../` can't leave the repository.
- External links launch with `noopener` and `noreferrer`.
- Remote, `data:`, `blob:` and SVG images are refused before any request.
- There are no webviews, iframes or `Image.network`.
- The files route sends a sandbox CSP and `nosniff`, and refuses symlinks.
- Deep-link IDs are used only for lookups.
- No Material imports.
