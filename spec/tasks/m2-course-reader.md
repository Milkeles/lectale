# Task: the Course and Reader screens, with the first viewers

| Intake | |
|---|---|
| **Why** | Release 1 is the public course reader: open a course by link, read its README and outline, open lessons and their files. V4-CORE-01, V4-CORE-02, V4-CORE-05; rendering rules V4-SEC-03 (no HTML, scripts or iframes from course content); A11Y rows in `docs/ux/inventory.md`. |
| **Simpler** | M2 viewers only: Markdown with LaTeX, plain text and code, images, folders, and the download card for everything else. PDF, notebooks, video and audio follow in M2b. A notebook model is being built separately, see below. No sign-in, no catalog data. |
| **Ready-made** | Markdown: `flutter_markdown_plus`. LaTeX: `flutter_math_fork`. Both are in the plan's research table, run on all six platforms, and have been checked against pub.dev. Everything else comes from devchat_ui (litse-ui) and the app's existing foundation. |
| **Security** | Course content is untrusted. Markdown renders without HTML, so raw HTML shows as text. Links resolve only inside the pinned repository (through the files route), or to http(s) URLs that open externally with a visible host. Images load only through the same-origin files route, never hotlinked (threat 5.6). No `HtmlElementView`, webview or iframe. A security review is required before merge. |
| **Verify** | `cd apps/flutter_client && dart analyze --fatal-infos && flutter test` and `cd packages/resource_renderers && flutter test` pass. They include widget tests for each viewer, keyboard tests for Course and Reader (Tab order from the specs, Contents with arrow keys and Home and End), golden images at 360, 768 and 1440, and Markdown security tests (HTML shown as text, a `javascript:` link not followed, a `../` path outside the repository refused). `flutter build web --release --base-href /app/` succeeds. |

## Read first

- `docs/ux/screens/course.md` and `docs/ux/screens/reader.md`: the screen specs (elements, states, keyboard order, copy).
- `docs/ux/inventory.md`: the shared layout, the Contents pane, the ribbon, breakpoints, and "Keyboard: every screen".
- `docs/ux/token-plan.md` and the type scale in `docs/ux/screens/landing.md` §12: the reading text is Source Serif 4 at 18/30.
- ADR-0012: set `TextStyle.locale` from the course language, using `ReadingStyles` in `lib/src/app/reading_text.dart`.
- ADR-0014: the app lives under `/app/` with hash URLs.
- The landing concept's product preview, `docs/ux/concepts/landing/`: it shows the reader look the owner approved (contents with the gold ribbon, lesson title, reading column).
- The API contract `spec/errata/openapi.yaml`: `CoursePreview`, `CourseOutline` and `OutlineResource` (now with `path`), and the preview routes `/api/preview/{repoId}/{sha}/readme`, `/content/{lessonId}/{resourceId}`, `/files/{path}` and `/folders/...`. Use the generated client in `packages/api_client`.

## Build

1. **`packages/resource_renderers/`**, a new package in the workspace. A registry maps each `OutlineResource.kind` to a renderer, so adding a kind means adding a renderer and nothing else (AGENTS.md patterns). Renderers in this task:
   - Markdown, with LaTeX and resolution of relative links and images via `path`;
   - text and code (Plex Mono, no wrapping, horizontal scroll);
   - images (decoded at display size);
   - folders (a list of entries);
   - the download card (name, kind, size).
   Material is allowed only under `lib/src/adapters/` if a third-party package forces it.
2. **Course screen**, `/app/#/preview/{repoId}/{sha}`: the cover (2:3, with the placeholder when there is none), title, authors and summary, the README rendered with headings shifted by one, and the outline. "Start course" opens the first lesson.
3. **Reader screen**, `/app/#/preview/{repoId}/{sha}/{lessonId}/{resourceId}`: the Contents pane, with the gold ribbon on the open lesson, collapsible on phones; the lesson title; the resource rendered through the registry; previous and next.
4. **Routing:** `/app/#/open` is the open-by-link screen, which is the current Home. `/app/` redirects there until the new app home exists. Import success goes to the Course screen.
5. **The interrupted accessibility fixes:** check the work-in-progress commit `dbf9d9f` on branch `worktree-agent-a5425f27399d93c22` (the ring around the field, web semantics, pixel snapping, the skip link). Reuse what still applies to the open-by-link screen, and verify it with tests.

## Not in this task

PDF, notebook, video and audio viewers (M2b); the new app home with the catalog; sign-in.

Commit nothing. The orchestrator merges after the design review, the security review and the Verify commands.
