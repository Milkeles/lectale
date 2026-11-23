# Screen: Reader

| | |
|---|---|
| **Milestone** | M2 (M2b adds PDF, notebook and audio viewers and the in-app video player) |
| **Journeys** | J3, J3a, J4, J5b, J5d, J5e (`../journeys-m2.md`) |
| **Requirements** | V4-CORE-01, V4-CORE-05 (preview part), V4-SEC-03, README-005, N5, A11Y-001, A11Y-002, A11Y-007, ERR-007, ERR-010, `RENDERING_REQUIREMENTS.md` |
| **Status** | Draft 2, revised after `../reviews/m2-design-review.md` and `../reviews/m2-codex-design-opinion.md` |

Pattern column added per the owner's request. Top bar, Contents bar, Contents pane and breakpoints are shared with Course and defined in `../inventory.md`. Error copy is in `../journeys-m2.md`, J5 error table.

## 1. Purpose

A learner reading one lesson or assignment wants to read its current resource and move on; they succeed when they have read it and open the next one without hunting.

## 2. Primary action

**Next.** Its label names the step: "Next file: {title}" within the lesson, "Next lesson: {title}" or "Next assignment: {title}" when it crosses to the next outline entry (S8, Codex §2). On the last item it becomes **Back to course**, which opens Overview with the ribbon on this lesson.

## 3. Entry and exit

| Arrives from | Leaves to |
|---|---|
| Course (Start course, Continue, a Contents row); a reload, bookmark or shared link; Next or Previous | Another resource or lesson (same screen); Course (Overview row, Back to course); Home (Lectale home, Enter the GitHub address); the browser (link and video cards); a download |

## 4. Content, in order of importance

1. The resource itself.
2. Lesson title, and the list of its files when there are two or more.
3. Next and Previous.
4. Where I am in the course (module line, Contents and the ribbon).

## 5. Elements

| Element | litse-ui component | User task it serves | Requirement | UX law applied | Pattern |
|---|---|---|---|---|---|
| Skip link "Skip to main content" | **missing** (skip link) | Bypass the bar and Contents | A11Y-001 | Fitts | Skip navigation link |
| Top bar "Lectale home" | **missing** (app bar) | Go to Home | V4-CORE-01 | Jakob | App bar, logo as home link |
| Contents control (shared) | `DcButton` ghost "Contents"; ribbon and lesson title beside it when the pane is hidden | Open the outline; see my place on a phone | V4-CORE-01, A11Y-007 | Zeigarnik, Fitts | Collapsible outline toggle |
| Contents pane or panel (shared): open lesson selected | **missing** (list row, tree); interim rows | Jump to any lesson or back to Overview | V4-CORE-01, A11Y-007 | Hick, Jakob | Table of contents; list of list-detail |
| Ribbon on the open lesson | `Container` in `primary`, swallowtail | Know where I am | V4-CORE-01 | Von Restorff | The memorable element |
| Module line (module title, plain text) | `Text` (`small`) | Know which module this lesson is in | A11Y-007 | Proximity | Section label in place of a breadcrumb (`../inventory.md` D2) |
| Lesson or assignment title (h1) and description | `Text` (`display`, `reading`) | Know what this lesson is | V4-CORE-01 | Cognitive load | Page title |
| Assignment dates (opens, due, closes; only those present) | `Text` rows (`small`) | Know deadlines in my time zone | V4-CORE-01 | Chunking | Metadata list |
| Assignment note | `Text` (`small`) | Know submitting isn't available | V4-CORE-01 | Tesler | Inline note |
| In this lesson (two or more resources): rows of title, kind, size if known | **missing** (list row); interim rows; selected row Sand + semibold + `selected` | Choose a file (J4) | A11Y-007 | Miller | Item list above the detail |
| Resource heading (h2), only with two or more resources | `Text` (h2 override, 24/32) | Know which file I'm reading | A11Y-007 | Proximity | Document header |
| Download bar: Download, filename, "{kind}, {size}" | `DcButton` outline + `Text` (`small`, filename in `code`) | Keep a copy; see what the file is | V4-CORE-05, A11Y-007 | Proximity, Jakob | Secondary action in the document header |
| Markdown viewer | App renderer; rules as Course §5, differences below | Read text with formulas, tables, code | V4-CORE-05, V4-SEC-03 | Jakob | Reading column, 32 em |
| Text viewer, prose (`.txt`) | `Text` (`reading`), wrapped | Read plain prose | V4-CORE-05 | Jakob | Plain-text document |
| Text viewer, data (CSV, TSV, JSON, YAML, logs) | `Text` (`code`), unwrapped, horizontal scroll | Read rows without broken lines | V4-CORE-05 | Jakob | Preformatted data |
| Code viewer: line numbers, language label, horizontal scroll, Copy | `Text` (`code`), `DcButton` ghost "Copy" | Read and copy code | V4-CORE-05 | Jakob | Code viewer with gutter |
| Image viewer: image, alt, Zoom in, Zoom out, Reset zoom | `Image`; `DcButton.icon` ×3, each with `DcTooltip` matching its label | See detail in a figure | `RENDERING_REQUIREMENTS.md` (Images: zoom, alternative text), A11Y-002 | Jakob | Zoom controls; pinch and wheel also work |
| Folder list: rows of name, kind or "Folder", size; Download on file rows | interim rows + `DcButton` outline per file | Get the files of a folder resource (J4) | V4-CORE-05, A11Y-007 | Miller, no dead end | File list with per-item download |
| File card: name, type, size if known, reason, Download | `DcCard` + `DcButton` outline | Get a file Lectale can't show yet (J4) | V4-CORE-05, `RENDERING_REQUIREMENTS.md` | Postel, no dead end | Metadata card with a download action |
| Link card: title, host, action | `DcCard` + `DcButton` outline | Leave the app knowingly for a link or video | `RENDERING_REQUIREMENTS.md`, N5 | Jakob, consent | Link card |
| Viewer error with Try again when J5 allows; link "Enter the GitHub address" on a 404 | `DcAlert` + `DcButton` outline, `DcButton` link | Recover, or move on (J5e) | ERR-007, ERR-010 | Error recovery | Inline error in the failed region |
| Previous | `DcButton` ghost, label names the target | Go back one step | V4-CORE-01 | Jakob | Previous and next |
| Next / Back to course | `DcButton` primary, large | Go forward one step | V4-CORE-01 | Serial position, Fitts | Previous and next |
| End note | `Text` (`reading`) | Know I finished | V4-CORE-01 | Peak-End | Calm end state |

**What each resource shows** (M3). `auto` is first resolved from `fileExtension` and `mediaType`. Never draw a button whose request is known to fail.

| Resource | Shows | Action |
|---|---|---|
| `markdown`, `text`, `code`, `image` (PNG, JPEG, GIF, WebP) with `href`; text and code up to 512 KB by `Content-Length` | Its viewer | Bar Download, hidden when `download` is false or `display.showFileDownloads` is false |
| `folder` (its `href` is the folders route) | Folder list of `entries[]` in the order returned; `name` is the path inside the folder, so a recursive listing indents by its `/` segments. Directories say "Folder" and have no action. Empty: "This folder is empty." When the count equals `maxEntries` (default 100): "Lectale shows up to {n} items from this folder." | Download on each row that has an `href`; no bar Download |
| `pdf`, `notebook`, `audio`, `video` with `href`, `file`, SVG, unknown types, text over 512 KB | File card with its reason | Download (`href`) always: `download: false` is a UI preference, not access control, and a kind with no viewer must offer it (`RENDERING_REQUIREMENTS.md`). No bar Download |
| Image that fails to decode | Box with alt text, filename, "This image can't be shown." | Download in the box; no bar Download |
| `video` with `provider` youtube or vimeo and `embedUrl` (`href` null) | Link card "Opens {host} in your browser." | "Watch on YouTube" / "Watch on Vimeo" opens `embedUrl` as given; nothing loads before the tap. M2b plays it in the app behind the consent gate |
| `external`, or `video` with `provider` external (`url`) | Link card with title and host | "Open link" opens `url` |
| Neither `href`, `url` nor `embedUrl` | "This item has no file to open." | None; Next stays |

**Markdown in a lesson differs from the overview in two ways.** Its headings shift by two levels when the lesson has a resource h2, by one otherwise (`../token-plan.md`). `OutlineResource` carries no `path`, so a relative image shows "This image can't be shown in this version." with its alt text, and a relative link is plain text with its target in small `code` (Q2). Anchors, `https` links, external-image consent and SVG rules are as in Course §5.

## 6. States

| State | What the reader sees | What they can do |
|---|---|---|
| Opening from a link (no preview in memory) | Top bar, Contents bar, skeleton h1 and eight lines; then the resource loads | Wait; Lectale home |
| Link fails to open (`GET /api/preview/{repoId}/{sha}`) | As Course §6 | Go to Home, or Try again |
| Lesson or file not in this course (IDs absent from the outline) | "This lesson isn't in this course." with a link to Overview | Open Overview, use Contents |
| Loading a resource | Header, list, Download bar and Next at once; viewer shows `DcSkeleton` lines (image: a block at its ratio if known) | Next, Previous, Contents |
| Empty lesson | "This lesson has no files yet." | Next, Contents |
| File missing (404) | J5 "This file isn't available", reference, link Enter the GitHub address; no Try again | Next, Contents, Home |
| Rate-limited, GitHub, offline, timeout, other | The J5 row inside the viewer; Try again when J5 allows | Try again, Next, Contents |
| Success | The viewer, card or list from §5 | Read, zoom, copy, download |
| End | On the last item, the note "You've reached the end of this course." above Back to course | Back to course |

A failure stays inside the viewer; navigation never disappears. When the layout switches between one column and two, the current resource and the paragraph at the top of the viewport stay put.

## 7. Wireframes

Names are illustrative. Regions are unbordered (C9); `|` is the ribbon, `*` the selected row.

### Phone (360 px)

```
+--------------------------------+
| [|Contents] Reading data       |  sticks (top bar scrolled away)
+--------------------------------+
| Module 1: Data                 |  module line
| Reading data                   |  h1
| How to load a CSV file.        |
| In this lesson                 |
| * data.md      Markdown        |
|   survey.csv   Text, 12 KB     |
| Data and its shape             |  h2
| [Download] data.md             |
|            Markdown, 4 KB      |
| Text text text, 18/30 ...      |
| [ Next file: survey.csv      ] |  full width, first
| [ Previous lesson: Welcome   ] |  ghost, below (wraps)
+--------------------------------+
```

### Tablet (768 px)

```
+----------------------------------------------------+
| [mark] Lectale                                     |
+----------------------------------------------------+
| [|Contents] Reading data                           |
+----------------------------------------------------+
|    Module 1: Data, then Reading data (h1)          |
|    [Download] data.md   Markdown, 4 KB             |
|    resource, 32 em column (single file: no h2)     |
|    [Previous lesson: Welcome]  [Next lesson: Sum…] |
+----------------------------------------------------+
 below the wide threshold: single column, panel
```

### Desktop (1440 px)

```
+------------------------------------------------------------------------------+
| [mark] Lectale                                                               |
+------------------------------------------------------------------------------+
| [Contents]                                                                   |
+---------------------------+--------------------------------------------------+
|   Overview                |       Module 1: Data                             |
| Module 1: Data            |       Reading data                               |
| |*Reading data            |       In this lesson                             |
|   Summaries               |       * data.md      Markdown                    |
| Homework 1                |         survey.csv   Text, 12 KB                 |
|   Assignment              |       Data and its shape (h2)                    |
|   Due 4 Dec 2026, 00:59   |       [Download] data.md  Markdown, 4 KB         |
|                           |       resource, 32 em, centred in this space     |
|                           |       [Previous lesson: …]   [Next file: …]      |
+---------------------------+--------------------------------------------------+
```

## 8. Interaction and accessibility

- **Keyboard order:** skip link, Lectale home, Contents control, Contents (one tab stop), then main: In this lesson (one tab stop, roving focus), Download, viewer content (scroll regions, zoom controls, Load buttons, Copy), then Next and Previous in their visual order (Next first when stacked, Previous first when side by side).
- **Button labels never truncate.** Labels wrap. Previous and Next sit side by side only when both full labels fit at the current text size; otherwise they stack full width, Next first. The same rule applies to Load buttons and every other button on Course and Reader.
- **Focus:** opening the screen puts focus on the h1. After Next or Previous, focus goes to the new h1 if the lesson changed, else to the new h2, and the page scrolls to the top (S8). Choosing a row in In this lesson moves focus to the h2.
- **History:** a lesson change pushes a history entry; a file change within a lesson replaces it, so system Back leaves the lesson rather than replaying its files (S8).
- **Shortcuts:** none beyond defaults (+, - and 0 on the image viewer); Next and Previous are not bound to arrow keys.
- **Landmarks and headings:** banner; `nav` "Course contents"; main with h1 (lesson) and h2 (resource, when present); `nav` "Lesson steps" holds Previous and Next. The ribbon row's name ends ", current".
- **Labels for icon-only controls:** Zoom in, Zoom out, Reset zoom, each with a tooltip of the same text (S15).
- **Touch targets:** at least 44 dp, zoom controls included (WCAG 2.2 2.5.8).
- **Motion:** the ribbon moves in 170 ms; instant under reduce-motion. No scroll animation.
- **Text:** reading 18 dp on 30, at most 32 em per line, left aligned, scales with the system setting.

## 9. Copy

| Where | Text |
|---|---|
| Next | Next file: {title} / Next lesson: {title} / Next assignment: {title} |
| Previous | Previous file: {title} / Previous lesson: {title} / Previous assignment: {title}; none on the first item |
| Last item, end note | Back to course; You've reached the end of this course. |
| List, meta | In this lesson; {kind}, {size} (size only when known) |
| Controls | Download, Copy, Copied (live region), Zoom in, Zoom out, Reset zoom |
| Empty lesson | This lesson has no files yet. |
| Not in course | This lesson isn't in this course. Open Overview |
| Assignment dates | Opens {date and time}, Due {date and time}, Closes {date and time} (learner's time zone) |
| Assignment note | You can read this assignment here. Submitting work isn't available in Lectale yet. |
| Errors, retry | `../journeys-m2.md`, J5 error table; link: Enter the GitHub address; Try again |
| File card, no viewer | Lectale can't show {PDF files} in this version. The button reads "Download PDF" for a PDF and "Download" otherwise. *Shortened 2026-11-23: the button already says what to do.* |
| File card, unknown | Lectale can't show this type of file. Download it to open it in another app. |
| File card, too large | This file is too large to show here. Download it to read it. |
| Folder | Folder; This folder is empty.; Lectale shows up to {n} items from this folder. |
| Video and link cards | Watch on YouTube / Watch on Vimeo / Open link; Opens {host} in your browser. |
| No file | This item has no file to open. |
| Image box | This image can't be shown. / This image can't be shown in this version. |

## 10. Images

| Image | Source | Rule |
|---|---|---|
| Resource `image` (PNG, JPEG, GIF, WebP) | Its `href`, same origin | Decode at displayed size × device pixel ratio (`cacheWidth`; on the web the browser decodes); at most the column (wide figures up to 960 dp) and 1600 dp tall; zoom to 400 percent re-decodes the visible size only; alt from `title` and `description` |
| Resource SVG | Repository | Not rendered (can carry script); file card |
| Images inside Markdown | Repository or other host | §5: relative ones can't be resolved in M2; other hosts click-to-load; `data:` never |
| Brand mark | App asset SVG | Vector, decorative. No kind icons in lists (S13) |

## 11. Open questions

1. `sizeBytes` is still absent at d766458 (`toCourseOutline` comment), so list sizes appear only after a file loads (`Content-Length`) or from folder entries. Fill it from tree metadata (A11Y-007). Backend.
2. Add `path` to `OutlineResource`, so Markdown lessons can resolve relative images and links through the files route. Backend.
3. Confirm 512 KB as the inline limit for text and code.
4. Syntax highlighting: plain text first; which package passes the Material check (ADR-0006)?
5. Should Next skip an assignment with no resources? I assume not.
6. litse-ui lacks: app bar, skip link, list row, tree or accordion, collapsible side pane.
