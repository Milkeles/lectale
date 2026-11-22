# Task: a safe Jupyter notebook model (`packages/ipynb`)

| Intake | |
|---|---|
| **Why** | V4-CORE-05 lists notebooks among the in-app viewers. No Dart package renders `.ipynb`; the plan records an exception to the 200-line rule for our own renderer. Splitting the parsing and sanitising from the widget lets this part be built and tested on its own. |
| **Simpler** | Pure Dart, with no Flutter dependency: parse nbformat 4 JSON into an immutable model, drop or neutralise everything unsafe, and enforce size limits. The Flutter widget that draws the model is a separate task. |
| **Ready-made** | `dart:convert` for JSON. No new dependency. |
| **Security** | Notebooks are untrusted course content (V4-SEC-03). Never keep `text/html`, `application/javascript`, `image/svg+xml`, widget-state or any other active output: replace each with an `UnsupportedOutput` that records only its MIME type. Strip ANSI escapes from stream and error text. Decode `image/png` and `image/jpeg` base64 lazily, with a byte limit. Reject oversize input before parsing (a byte limit passed in). Cap cells, output count and text length per output. Any limit exceeded leaves a truncation marker, never an exception the reader can't handle. |
| **Verify** | `cd packages/ipynb && dart analyze --fatal-infos && dart test` passes with fixtures: a normal notebook; nbformat 3 (rejected with a clear error); malformed JSON; HTML and JavaScript outputs (dropped); SVG (dropped); ANSI in tracebacks (stripped); a 50 MB embedded image (truncated); 10,000 cells (capped); markdown cells with HTML (kept as text: the Markdown renderer shows raw HTML as text); attachments in markdown cells (`attachment:` references resolved to decoded images, within limits). |

### Security review follow-up

| Intake | |
|---|---|
| **Why** | Close findings 1–8 in `docs/security/reviews/2026-11-22-ipynb.md`. |
| **Simpler** | Bound the existing parser and sanitiser and retain the static preview model. |
| **Ready-made** | Use the Dart standard library and the PNG and JPEG header layouts also used by the Worker cover checks. |
| **Security** | Reject excessive JSON nesting and malformed structures, limit retained text and raster dimensions, and strip display controls from plain output (V4-SEC-03). |
| **Verify** | Run the package's analyzer and tests with regression cases for all eight findings. |

## Model

- `Notebook` holds `language` (from metadata), `cells` and `truncated`.
- `Cell` is a sealed class: `MarkdownCell(source, attachments)`, `CodeCell(source, executionCount, outputs)` and `RawCell(source)`. Raw cells are shown as plain text.
- `Output` is a sealed class:
  - `StreamOutput(name, text)`;
  - `TextOutput(mime: 'text/plain' | 'text/markdown' | 'text/latex', text)`;
  - `ImageOutput(mime, width, height, bytes)`;
  - `ErrorOutput(ename, evalue, traceback)`;
  - `UnsupportedOutput(mime)`.
  Where an output offers several MIME types, choose the safest richest one in this order: markdown, LaTeX, PNG, JPEG, plain text.
- `NotebookLimits` sets the defaults: input 20 MiB, 2,000 cells, 100 outputs per cell, 1 MiB of source per cell, 200 KiB of text per output, 10 MiB and 16,777,216 pixels per image. A caller can lower them.
- `parseNotebook(Uint8List bytes, {NotebookLimits limits})` returns a `Notebook`, or throws `NotebookFormatException` for malformed input, JSON nested deeper than 64 containers, or an unsupported notebook version. Document every public API with `///` per AGENTS.md.

Add the package to the Dart workspace (root `pubspec.yaml`). Commit nothing.
