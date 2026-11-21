---
name: screen-spec
description: "Writes and reviews Lectale screen specs (AI-readable wireframes) before any UI code: one primary action, every element tied to a user task, UX laws, states, images, and a check against generic AI-generated design. Use when planning a new screen, reviewing a screen spec in docs/ux/screens/, or judging whether an element belongs on a screen."
---

# Screen specs

A screen spec is the wireframe agents work from. It lives in `docs/ux/screens/<screen>.md`, uses `docs/ux/screen-spec-template.md`, and is reviewed before any widget is written (`docs/ux/README.md`). Changing a spec is cheap; deleting shipped UI is not.

## Rules every spec meets

1. **One purpose, one primary action.** If you can't state the purpose in a sentence, the screen is doing two jobs: split it.
2. **Every element earns its place.** Each row in the element table names the user task it serves and the requirement behind it. No task, no element. This rule exists because generated screens tend to sprout buttons that do nothing useful.
3. **Content order is importance order.** The wireframe follows the numbered content list; the most important thing is first in reading order and keyboard order.
4. **Every state is designed:** loading, empty, each error, success. An empty state names the next action; an error says what failed and how to fix it.
5. **Structure follows established patterns.** Navigation and layout use well-studied patterns: canonical adaptive layouts (list-detail, supporting pane), a navigation rail on wide screens and a drawer or sheet on phones, breadcrumbs or a table of contents for hierarchy, and reading-app conventions. Each structural element in the element table names its pattern. Learners feel at home in familiar structures (Jakob's Law), so novelty is spent only on the one memorable element. Ground pattern choices in Flutter's adaptive design guidance (docs.flutter.dev/ui/adaptive-responsive).
6. **Readers come first.** Lectale is a calm reading app for learners of any subject. Reading text is left-aligned, about 60-70 characters per line, in sentence case.

## UX laws to check

Definitions are from the Laws of UX as quoted in `docs/research/2026-11-21-images-codex-ux.md` §5. The application to Lectale is ours.

| Law | Check on every Lectale screen |
|---|---|
| Hick's Law, Choice Overload | Few choices at once; secondary actions in a menu, not a row of buttons. |
| Jakob's Law, Mental Model | Back, search and file actions behave as in other reading apps; don't invent new gestures. |
| Fitts's Law | Primary action large and near where the hand or pointer already is; targets at least 24×24 px. |
| Law of Proximity, Common Region | Related controls sit together; a container only when it groups. |
| Miller's Law, Chunking | Long outlines are grouped into modules; show progress through a chunk, not a wall of items. |
| Cognitive Load, Tesler's Law | The app absorbs complexity (pinning commits, validation) so the reader never sees it. |
| Doherty Threshold | Feedback within 400 ms: a skeleton or progress, never a frozen screen. |
| Von Restorff Effect | Exactly one element stands out: the primary action or the reader's current place. |
| Serial Position, Peak-End | Put the next lesson first; end flows (submission, completion) with a clear, calm confirmation. |
| Goal-Gradient, Zeigarnik | Show where the learner left off and how much of a module remains. |
| Postel's Law | Accept any reasonable GitHub URL form; tell the user exactly what was wrong otherwise. |
| Aesthetic-Usability Effect | Polish matters, but never at the cost of the rules above. |

## Anti-patterns to reject in review

- A button, link or icon whose spec row has no user task, or two controls that do the same thing.
- More than one visually primary action.
- Icon-only controls without a label, or a meaning carried by colour alone.
- Dead ends: a state with no way forward or back.
- Dashboard filler: stat tiles, fake metrics, decorative charts.
- Anything on the AI-tell list in `references/ai-tells.md`. A trait is fine when chosen for this brief; it's a tell when it is a default.

## Images

From `docs/research/2026-11-21-images-codex-ux.md` §1-4:

- **Logos and icons** are vectors: SVG compiled with `vector_graphics_compiler`, drawn with `flutter_svg` / `vector_graphics`. One icon family, one stroke weight.
- **App raster images** are WebP. Flutter documents JPEG, PNG, GIF, WebP, BMP and WBMP; AVIF isn't documented, so it isn't used.
- **Decode at display size.** Set `cacheWidth` or `cacheHeight` (or wrap in `ResizeImage`) to the displayed size times the device pixel ratio, so a large image is never decoded into a small box. Flutter ignores these for `Image.network` on the web, so course images on the web are sized by choosing the right variant on the server side.
- **Resolution variants** (`2.0x/`, `3.0x/`) for bundled raster assets.
- **Course images** are whatever the instructor committed. Repository images load normally; images from other hosts are click-to-load (errata N5).
- **Generated art.** Codex's image tool makes raster concepts. A logo is redrawn as SVG before it ships.

## Long text

For very long documents, measure once and reuse: prepare `TextPainter` layouts per paragraph and rerun only line-breaking when the width changes. This is the idea behind chenglou/pretext, applied with Flutter's own text engine. Use it only if profiling shows long readings stutter.

## Review output

A verdict (approve or revise). Then the element rows to remove or change, each law or anti-pattern violated (with the spec section), missing states, and the five pre-ship checks from `references/ai-tells.md`.

Sources: `docs/research/2026-11-21-images-codex-ux.md` (Laws of UX via a third-party copy, Flutter image docs, Codex image_gen, AI-tell sources); `docs/research/2026-11-21-platform-and-provider-facts.md`.
