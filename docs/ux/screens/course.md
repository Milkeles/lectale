# Screen: Course

| | |
|---|---|
| **Milestone** | M2 |
| **Journeys** | J2, J3, J5d, J5e (`../journeys-m2.md`) |
| **Requirements** | V4-CORE-01, V4-CORE-05 (Markdown, LaTeX), V4-SEC-03, README-001..005, N5, A11Y-001, A11Y-002, A11Y-007 |
| **Status** | Draft |

Pattern column added to the template per the owner's request; names and sources in `../inventory.md`.

## 1. Purpose

A learner who opened a course wants to know what it is and where to begin; they succeed when they have read enough of the description and pressed Start course, or picked a lesson from the contents.

## 2. Primary action

**Start course** (opens the first lesson in outline order). Contents rows are navigation, not actions of equal weight: they are plain rows.

## 3. Entry and exit

| Arrives from | Leaves to |
|---|---|
| Home after import; Reader's back control (below 840 px, lands on the Contents tab) | Reader (Start course, a lesson, or an assignment row); Home (brand link); an author link (external, new tab) |

## 4. Content, in order of importance

1. Title, summary and Start course.
2. The README (the course description).
3. Contents: modules, lessons, assignments.
4. Facts: authors, level, minutes, language, license, tags.

## 5. Elements

| Element | litse-ui component | User task it serves | Requirement | UX law applied | Pattern |
|---|---|---|---|---|---|
| Skip link "Skip to main content" | **missing** (skip link) | Bypass the bar | A11Y-001 | Fitts | Skip navigation link |
| Top bar: brand mark link | **missing** (app bar) | Return to Home to open another course | V4-CORE-01 | Jakob | App bar, logo as home link |
| Title (h1) `course.title` | `Text` (`display`) | Know which course this is | V4-CORE-01 | Von Restorff is spent elsewhere; plain | Page title |
| Summary `course.summary` | `Text` (`reading`) | Decide if this is the right course | V4-CORE-01 | Cognitive load | Lead paragraph |
| Facts list: authors (links to `url` if given), level, estimated minutes (only if `display.showEstimatedDuration` is not false), language, license, version | `Column` of `Text` pairs, `DcBadge` for level | Judge fit and who made it | V4-CORE-01 | Chunking | Definition list |
| Tags (at most 5, then "+n") | `DcBadge` outline | See the topics | V4-CORE-01 | Proximity | Tag list |
| Start course | `DcButton` primary, large | Begin at the first lesson | V4-CORE-01 | Serial position, Fitts | Single primary action under the title |
| Tabs "About" and "Contents" (below 840 px only) | `DcTabs` | Switch between description and contents without scrolling past either | V4-CORE-01 | Hick | Tabs for sibling views on compact and medium windows |
| README body | App renderer (`resource_renderers`, flutter_markdown_plus, flutter_math_fork): not litse-ui | Read the course description (J2) | README-001, V4-CORE-05, V4-SEC-03 | Aesthetic-usability | Reading column, 640 dp max (content width cap) |
| README: headings, tables, lists, links | renderer; table in a horizontal scroll region | Read structured content | README-005, A11Y-002 | Jakob | Standard document semantics |
| README: code block | renderer, `code` style on `muted` fill | Read and copy code | V4-CORE-05 | Jakob | Preformatted block, horizontal scroll, no execution |
| README: LaTeX inline and block | renderer (flutter_math_fork) with plain-text alternative as semantics label | Read formulas | V4-CORE-05 | Jakob | Rendered math with text fallback |
| README: repository image | renderer, `Image` at displayed size | See figures | README-005, V4-SEC-03 | Recognition | Inline figure with alt text |
| README: external image gate | renderer: `DcCard`-style region with `DcButton` outline "Load image from {host}" | Choose whether to contact another server (J2) | N5, V4-SEC-03 | Postel, consent | Click-to-load placeholder, as for video consent |
| README: raw HTML, scripts, iframes, `data:` URLs | not rendered | (none: never shown) | V4-SEC-03, README-003 | n/a | Sanitised Markdown |
| Contents: the outline | **missing** (list row; accordion or tree). Interim: `Column` of `DcPressable` rows | Find a lesson and jump to it (J3) | V4-CORE-01, A11Y-007 | Miller (module groups), Zeigarnik | Table of contents; list pane of list-detail |
| Module heading (children indented, up to 5 levels) | `Text` (`subtitle`) | See how lessons are grouped | V4-CORE-01 | Chunking | TOC section heading |
| Lesson row: title, resource count | `DcPressable` row | Open that lesson | V4-CORE-01 | Fitts (row is the target) | TOC entry |
| Assignment row: title, "Due {date}" if `dueAt` | `DcPressable` row, `DcBadge` "Assignment" | Read the assignment and see its deadline | V4-CORE-01 | Proximity | TOC entry with metadata |
| Layout: README primary, Contents beside it at 840 px and wider | `Row` with `LayoutBuilder` | See both at once on a big window | V4-CORE-01 | Jakob | Supporting pane (about two thirds and one third) |
| Error alert for README failure (with Retry) | `DcAlert` + `DcButton` outline "Try again" | Recover without losing the outline (J5e) | README-002, ERR-010 | Error recovery | Inline error in the failed region |
| Missing README notice | `DcAlert` standard | Understand there is no description | README-002 | Cognitive load | Empty state naming the next action |

`display.themeAccent` from the manifest is ignored: an author colour can break contrast (A11Y-002). `course.cover` is not shown in M2 (no fetchable href; see open questions).

## 6. States

| State | What the reader sees | What they can do |
|---|---|---|
| Loading README | Title, summary, facts and Contents show at once (they come from the import response); README area shows 6 `DcSkeleton` text lines | Start course, use Contents |
| Empty: no README (`readmePresent` false) | Notice "This course has no description yet. Use the contents to start." | Start course |
| Empty: outline has no lessons | Contents shows "This course has no lessons yet." Start course is disabled with that text as its reason | Open another course |
| Error: README unavailable (404 masked, 5xx) | Alert in the README area: "The description can't be loaded." with Try again and the reference | Try again, or use Contents |
| Error: rate-limited | Same area: "Too many requests. Try again in {n} seconds." | Try again when enabled |
| Error: offline | "Lectale can't be reached. Check your internet connection." | Try again |
| Error: opened by link, outline not in memory | Whole screen replaced: "Open this course again. The link needs the repository address." with button Open course (to Home) | Go to Home |
| Success | Full page | Read, start |

Window resizes keep the scroll position and selected tab. At 840 px and wider the Contents tab is gone and its list sits in the pane.

## 7. Wireframes

### Phone (360 px)

```
+--------------------------------+
| [mark]                         |
+--------------------------------+
| Introduction to Statistics     |  h1
| Probability and inference...   |
| Ada Lovelace, Intermediate,    |
| 40 min, English, CC BY 4.0     |
| [stats] [probability] +2       |
| [        Start course        ] |
| [ About ]|  Contents           |  tabs
| ------------------------------ |
| README text ...                |
| formulas, tables, code ...     |
|  [Load image from example.org] |
+--------------------------------+
 Contents tab:
| Module 1: Data                 |
|   Reading data        2 files  |
|   Summaries           1 file   |
| Assignment 1  Due 3 Dec 2026   |
```

### Tablet (768 px)

```
+----------------------------------------------------+
| [mark]                                             |
+----------------------------------------------------+
|   Introduction to Statistics                       |
|   summary ..................................       |
|   facts, tags                                      |
|   [ Start course ]                                 |
|   [ About ]|  Contents                             |
|   +----------------------------------+             |
|   | README, 640 dp reading column    |             |
|   +----------------------------------+             |
+----------------------------------------------------+
  medium window: tabs, no side pane
```

### Desktop (1440 px)

```
+------------------------------------------------------------------------------+
| [mark]                                                                       |
+------------------------------------------------------------------------------+
|  Introduction to Statistics                                                  |
|  summary ................  facts, tags      [ Start course ]                 |
|                                                                              |
|  +------------------------------------+   +--------------------------------+ |
|  | README (640 dp column)             |   | Contents (supporting pane,     | |
|  |  headings, text, tables, code      |   |  sticky, own scroll)           | |
|  |  figures                           |   |  Module 1: Data                | |
|  |                                    |   |    Reading data                | |
|  |                                    |   |  Assignment 1  Due 3 Dec 2026  | |
|  +------------------------------------+   +--------------------------------+ |
+------------------------------------------------------------------------------+
```

## 8. Interaction and accessibility

- **Keyboard order:** skip link, brand link, author links, Start course, tabs (below 840 px; arrow keys move between tabs), then the README in document order (links, "Load image" buttons, scroll regions), then Contents rows in outline order. At 840 px and wider Contents follows the README.
- **Landmarks and headings:** banner; main holds h1 and the README; `nav` labelled "Course contents" holds Contents. README headings keep their levels, shifted so the README's h1 becomes h2 (one h1 per screen).
- **Labels for icon-only controls:** none; every control has a visible label.
- **Touch targets:** Contents rows at least 44 dp high; inline README links at least 24 dp by padding of the hit area.
- **Motion:** none. No scroll animation. Tab change is instant.
- **Rows:** each row's accessible name reads "{title}, lesson, {n} files" or "{title}, assignment, due {date}".

## 9. Copy

| Where | Text |
|---|---|
| Primary | Start course |
| Tabs | About, Contents |
| Contents label | Course contents |
| Lesson meta | {n} file / {n} files |
| Assignment badge and date | Assignment, Due {date} |
| Level values | Introductory, Intermediate, Advanced, Mixed levels |
| Minutes | {n} min |
| Tags overflow | +{n} more |
| No README | This course has no description yet. Use the contents to start. |
| No lessons | This course has no lessons yet. |
| README error | The description can't be loaded. |
| Retry | Try again |
| Link opened without data | Open this course again. The link needs the repository address. |
| External image | Load image from {host} |
| External image note | Loading contacts {host}, which can see your address. |
| Image without alt | Image without description: {filename} |
| Author link name | {name}, opens in your browser |

## 10. Images

| Image | Source | Rule |
|---|---|---|
| Brand mark | App asset, SVG compiled to vector graphics | Vector; 28 dp; decorative |
| README image, relative path in the repository | Preview route `OutlineResource`-style href, same origin | Loads normally; WebP, PNG, JPEG, GIF accepted; decode at displayed width x device pixel ratio (`cacheWidth`; on web the browser decodes, so no variant control); alt text read from Markdown; empty alt means decorative; max display width 640 dp; zoom not offered here |
| README image from another host (https) | Author's server | Not loaded. Placeholder with host and "Load image from {host}"; loads after activation, for that image only; failure shows alt text and filename (N5) |
| README image, `data:` URL or SVG | Embedded | Never rendered; shows "Image without description" style placeholder naming the reason "Not shown for safety" |
| Course cover | `course.cover` repository path | Not shown in M2 |
| Alert and row icons | Lucide, vector | One family, one stroke weight |

## 11. Open questions

1. The outline has no endpoint reachable from a bare `/preview/{repoId}/{sha}` link (import needs the URL). Add `GET /preview/{repoId}/{sha}/outline`, or keep outline in memory and accept the fallback state above?
2. `course.cover` has no href in `OutlineCourse`. Add one if a cover is wanted.
3. litse-ui lacks: app bar, skip link, list row, accordion or tree (long outlines would collapse modules), scrollable region helper for tables.
4. Is the `/about` README route kept separate (spec) or is this screen the description (my merge)?
5. Level and language values: show raw codes (`en`) or names? I assume names via the platform locale.
