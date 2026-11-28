# Task: in-app PDF and notebook viewers

| Intake | |
|---|---|
| **Why** | V4-CORE-05 and `RENDERING_REQUIREMENTS.md`: PDFs and notebooks must open inside the app, not as a download. UI-001 (PDF: pages, zoom, search, page navigation), UI-003 (notebook: Markdown, code, text output, PNG plots and math in order, never executed), UI-007 (keyboard, screen readers, loading and retry), A11Y-005 and A11Y-006. Today both kinds show the file card from `m2-course-reader.md`. |
| **Simpler** | Two renderers in `packages/resource_renderers`, registered for the `pdf` and `notebook` kinds, so nothing else in the app changes. The file card stays as the fallback for anything these viewers can't open. **Not building:** running notebook code, interactive widget outputs, PDF forms, annotations or printing, password-protected PDFs (they get the file card with the reason "This PDF is password-protected."), local MP4 video and audio (separate task). |
| **Ready-made** | PDF: `pdfrx` (ADR-0006, research note `2026-11-21-platform-and-provider-facts.md`; MIT, all six platforms, text search). Notebook: our own `packages/ipynb` model (merged, security-reviewed), drawn with the Markdown, math, code and image pieces that already exist in `resource_renderers`. No other new dependency. |
| **Security** | Course files are untrusted (V4-SEC-03).<br>- **Sources:** PDF and notebook bytes come only through `ResourceHost` from the same-origin preview route, never from another host. `pdfrx` must not fetch anything from a CDN or third party at runtime on any platform, including its web engine. Check how it loads on the web and bundle its assets if needed.<br>- **Links:** links inside a PDF go through the existing HTTPS-only link policy (host shown, punycode, refusal of anything else), or are not followable.<br>- **Notebook model:** notebooks go through `packages/ipynb` with its limits. `UnsupportedOutput` shows a one-line note with its MIME type, never content. Images use the existing header-checked, size-capped image path.<br>- **Size caps:** bytes are capped: PDFs over 50 MB, or over the server's file limit if lower, get the file card. Use byte ranges if `pdfrx` accepts a custom range loader; otherwise cap the full read.<br>- **Material:** stays inside `lib/src/adapters/` (`check_rules.py`).<br>- **Reviews:** a security review (Claude) and a Codex review are needed before merge. |
| **Verify** | `dart analyze --fatal-infos` and `flutter test` pass in `packages/resource_renderers` and `apps/flutter_client`. `python3 tool/check_rules.py` passes. `flutter build web --release --base-href /app/` succeeds. `browser_test/security.test.mjs` passes with a fixture PDF and a fixture notebook added: zero requests to any host other than the app's own origin and the font host already listed, and no script runs from notebook HTML or JavaScript outputs. |

## Build

1. **PDF viewer** (`pdf` kind, and `file` or `auto` when the trusted type is PDF):
   - Shows all pages with page navigation: a "Page n of m" indicator, previous and next page, and go to page.
   - Has zoom in, zoom out and fit width.
   - Has a text search with next and previous matches (UI-001).
   - Keeps the file bar's Download action.
   - **Keyboard:** Page Up and Page Down move between pages, `+` and `-` zoom, Ctrl/Cmd+F focuses search, and every control is reachable by Tab.
   - **Screen readers:** each page is announced as "Page n of m". If `pdfrx` exposes a page's text, offer it to screen readers. If it doesn't, say so in the report; don't fake it.
   - Shows a loading state while bytes arrive. On a read failure, show an error with Retry.
2. **Notebook viewer** (`notebook` kind and `.ipynb`):
   - Draws the cells in order:
     - Markdown cells use the existing Markdown renderer with math.
     - Code cells use the existing code view with the notebook's language (no execution, no run buttons), marked "In [n]" as Jupyter does.
     - Stream and plain-text outputs are monospace.
     - PNG and JPEG outputs go through the image path.
     - Error outputs show the traceback with ANSI codes stripped (the model already strips them).
     - Unsupported outputs get a short note.
   - Shows the model's truncation markers as a visible note.
   - Is keyboard-scrollable; code and outputs keep the scroll cues from the design round.
3. **Fixtures:**
   - `browser_test/fixture/` gets a multi-page PDF with a raster diagram, and a notebook with Markdown, math, code, a PNG plot, an HTML output with a script, and an SVG output.
   - Add both to the fixture course outline so the browser test and the screenshots reach them.
4. **Screen spec:** update `docs/ux/screens/reader.md` with the two viewers' layouts, controls, states, Tab order and copy, before the code. Then write the code to match it.
5. **Screenshots:** for the design review, PDF and notebook at 1440 and 390, light and dark, into `docs/ux/reviews/course-reader-build/`.

## Boundaries

Work in your worktree only. Don't commit, deploy or add dependencies other than `pdfrx`. Report what changed, the Verify results, and what `pdfrx` does on the web (assets, workers, any network use).
