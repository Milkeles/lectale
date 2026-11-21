# Screen: Course

| | |
|---|---|
| **Milestone** | M2 |
| **Journeys** | J2, J3, J3a, J5b, J5d, J5e (`../journeys-m2.md`) |
| **Requirements** | V4-CORE-01, V4-CORE-05 (Markdown, LaTeX), V4-SEC-03, README-001..005, N5, A11Y-001, A11Y-002, A11Y-007 |
| **Status** | Draft 2, revised after `../reviews/m2-design-review.md` and `../reviews/m2-codex-design-opinion.md` |

Pattern column added per the owner's request. The top bar, Contents bar, Contents pane and breakpoints are shared with the Reader and defined once in `../inventory.md` (Shared layout, Breakpoints). Error copy is in `../journeys-m2.md`, J5 error table.

## 1. Purpose

A learner who opened a course wants to know what it is and where to begin; they succeed when they have read enough of the overview and pressed Start course, or picked a lesson in Contents.

## 2. Primary action

**Start course** (opens the first lesson in outline order). After a lesson has been opened in this visit it reads **Continue: {lesson title}** and reopens that lesson (memory only, `../inventory.md` D11). It is removed when the course has no lessons. Contents rows are navigation, not equal actions.

## 3. Entry and exit

| Arrives from | Leaves to |
|---|---|
| Home after import; a reload, bookmark or shared link; Overview in Contents; "Back to course" at the end of the Reader | Reader (Start course, a Contents row); Home ("Lectale home", "Enter the GitHub address", "Open another course"); an author link, a repository file or an `https` link (browser) |

## 4. Content, in order of importance

1. Title, summary and Start course.
2. The overview (the root README).
3. Contents: Overview, modules, lessons, assignments.
4. Facts: authors, level, time, language, license.

## 5. Elements

| Element | litse-ui component | User task it serves | Requirement | UX law applied | Pattern |
|---|---|---|---|---|---|
| Skip link "Skip to main content" | **missing** (skip link) | Bypass the bar and Contents | A11Y-001 | Fitts | Skip navigation link |
| Top bar "Lectale home" (mark and wordmark) | **missing** (app bar) | Go to Home to open another course | V4-CORE-01 | Jakob | App bar, logo as home link |
| Contents control (shared) | `DcButton` ghost "Contents"; ribbon and place title when the pane is hidden | Open or close the outline; see my place on a phone | V4-CORE-01, A11Y-007 | Zeigarnik, Fitts | Collapsible outline toggle |
| Contents pane or panel (shared): Overview row selected here | **missing** (list row, tree); interim `Column` of `DcPressable` rows | Find a lesson and jump to it (J3) | V4-CORE-01, A11Y-007 | Miller (module groups), Hick | Table of contents; list of list-detail |
| Ribbon on this visit's last-opened lesson, else on Overview | `Container` in `primary`, swallowtail shape | Find where I left off | V4-CORE-01 | Von Restorff, Goal-gradient | The memorable element (`../token-plan.md`) |
| Cover (600 dp and wider) | `Image` via the files route | Recognise the course the author presented | V4-CORE-01 | Aesthetic-usability | Book cover thumbnail |
| Title (h1) `course.title` | `Text` (`display`) | Know which course this is | V4-CORE-01 | Cognitive load | Page title |
| Summary `course.summary` | `Text` (`reading`) | Decide whether this course fits | V4-CORE-01 | Cognitive load | Lead paragraph |
| Start course / Continue: {lesson title} | `DcButton` primary, large, start-aligned with the title | Begin, or resume this visit's lesson | V4-CORE-01 | Serial position, Fitts | Single primary action under the lead |
| Facts as labelled pairs: Authors (links if `url`), Level, Time (only if `display.showEstimatedDuration` is not false), Language, License | `Column` of label and value `Text` rows | Judge fit, who made it, whether I may reuse it | V4-CORE-01 | Chunking | Definition list |
| Overview body | App renderer (`resource_renderers`: flutter_markdown_plus, flutter_math_fork), not litse-ui | Read the course overview (J2) | README-001, V4-CORE-05, V4-SEC-03 | Aesthetic-usability | Reading column, 32 em |
| Overview: headings, lists, tables | renderer; table in its own horizontal scroll region | Read structured content | README-005, A11Y-002 | Jakob | Document semantics; heading map in `../token-plan.md` |
| Overview: code block | renderer, `code` on `muted` | Read and copy code | V4-CORE-05 | Jakob | Preformatted block, horizontal scroll |
| Overview: LaTeX | flutter_math_fork, plain-text alternative as label | Read formulas | V4-CORE-05 | Jakob | Rendered math with text fallback |
| Overview: link (cases below) | renderer link with 24 dp hit area | Follow a reference | README-005 | Jakob | Underlined inline link |
| Overview: repository image | renderer `Image` via the files route | See figures | README-005, V4-SEC-03 | Recognition | Inline figure with alt text |
| Overview: images from another host | outline `DcButton` "Load {n} images from {host}" in a placeholder, one per host per block | Choose whether to contact another server (J2) | N5, V4-SEC-03 | Postel, consent | Click-to-load placeholder |
| Overview: "Part of this overview can't be shown here." | `Text` (`small`) | Know something was left out | README-003 | Nothing silently hidden | Inline omission note |
| Overview error, with Try again when J5 allows | `DcAlert` + `DcButton` outline "Try again" | Recover without losing Contents (J5e) | README-002, ERR-010 | Error recovery | Inline error in the failed region |
| No-overview notice | `DcAlert` standard | Know there is no overview and where to start | README-002 | Cognitive load | Empty state naming the next action |
| No-lessons notice with link "Open another course" | `DcAlert` standard + `DcButton` link | Leave a course with nothing to read | V4-CORE-01 | No dead end | Empty state naming the next action |
| Not-available message with link "Enter the GitHub address" | `DcAlert` destructive + `DcButton` link | Recover when a link no longer opens (J3a, J5b) | V4-CORE-01, V4-SEC-03 | Error recovery | Full-region error with a way out |

**Rules for the overview** (S11): Markdown is sanitised, not dropped. Raw HTML renders as a safe subset: `img` exactly like a Markdown image; `details` and `summary`; `br`, `sub`, `sup`, `kbd`. Any other element shows its text content, and a block that lost an element gets the omission note once. Scripts, iframes, styles and event attributes never render (V4-SEC-03, README-003). A formula that fails to parse shows its source in `code` with the label "Formula, as written". `display.themeAccent` is ignored (A11Y-002).

**Links and images** (M2). Relative paths resolve from the repository root; `./` and `../` collapse; the files-route address is built as in `../journeys-m2.md`.

| Case | Behaviour |
|---|---|
| `#anchor` | Scrolls to the heading, instantly; focus moves to it |
| Relative link to a repository file | Opens the files-route address in the browser; the server shows or downloads it by its safe-MIME rules. Name: "{text}, opens the file in your browser" |
| Relative path outside the root or not a valid repository path | Plain text, the target after it in small `code`; not a link |
| `https` link | Opens the browser. Name: "{text}, opens in your browser" |
| `http:`, `mailto:` and other schemes | Plain text with the target in small text |
| Relative image | Loads through the files route. On 404 or decode failure: a box with the alt text, the filename and "This image can't be shown." Never a broken-image glyph |
| Image from another host (`https`) | Not loaded until the learner taps; consecutive images from one host in one block share one placeholder and one button; each loads only that group |
| SVG (any host) or `data:` URL | Never rendered; consecutive ones share one line: "{n} SVG images aren't shown, for safety." |

## 6. States

| State | What the reader sees | What they can do |
|---|---|---|
| Opening from a link (no preview in memory) | Top bar; Contents bar with the control disabled; skeleton title, two summary lines, button block, six Contents rows (`DcSkeleton`) | Wait; Lectale home |
| Link fails to open (`GET /api/preview/{repoId}/{sha}`) | Main region: the J5 row with its reference, no Contents. On 404, "Course not available" with the link "Enter the GitHub address" (Home); otherwise Try again when J5 allows | Go to Home, or Try again |
| Loading the overview | Header, facts and Contents at once (from the preview); six skeleton lines in the overview | Start course, use Contents |
| Overview fails | The J5 row inside the overview area with its reference; a 404 shows "This file isn't available" with the README body and no Try again; others offer Try again when J5 allows | Try again if offered, Start course, Contents |
| No overview (`readmePresent` false) | Notice "This course has no overview yet. Use Contents to start." In a single-column layout the Contents list shows inline below it and the Contents control is hidden (S5) | Start course, pick a lesson |
| No lessons | Start course removed. Notice "This course has no lessons yet." with link "Open another course". Contents shows Overview only | Read the overview, go to Home |
| Success | Full page | Read, start, jump |

A resize keeps the scroll position and the paragraph at the top of the viewport. Arriving back from the Reader, the ribbon row is scrolled into view in Contents.

## 7. Wireframes

Names are illustrative. The overview and pane are unbordered regions (C9); `|` before a row is the ribbon, `*` marks the selected row.

### Phone (360 px)

```
+--------------------------------+
| [mark] Lectale                 |  top bar, scrolls away
+--------------------------------+
| [|Contents] Reading data       |  sticks; ribbon + last opened
+--------------------------------+
| Introduction to Statistics     |  h1 (no cover on phone)
| Probability and inference for  |
| beginners, with worked data.   |
| [ Continue: Reading data     ] |
| Authors   Ada Lovelace         |
| Level     Intermediate         |
| Time      About 40 min  ...    |
| Overview text, 18/30 ...       |
| [Load 3 images from img.exa…] |
+--------------------------------+
 Contents panel (?contents):
| Contents              [Close]  |
| * Overview                     |
| Module 1: Data                 |
| | Reading data                 |
|   Summaries                    |
| Homework 1                     |
|   Assignment                   |
|   Due 4 Dec 2026, 00:59 CET    |
```

### Tablet (768 px)

```
+----------------------------------------------------+
| [mark] Lectale                                     |
+----------------------------------------------------+
| [|Contents] Reading data                           |
+----------------------------------------------------+
|    [cover 240x160]                                 |
|    Introduction to Statistics, summary ...         |
|    [ Continue: Reading data ]                      |
|    Authors  Ada Lovelace  (labelled pairs, then    |
|    the overview in a 32 em column, centred)        |
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
| * Overview                |        [cover 240x160]                           |
| Module 1: Data            |        Introduction to Statistics                |
| | Reading data            |        summary ...                               |
|   Summaries               |        [ Continue: Reading data ]                |
| Homework 1                |        Authors  Ada Lovelace                     |
|   Assignment              |        Level    Intermediate                     |
|   Due 4 Dec 2026, 00:59   |        Overview, 32 em, centred in this space    |
| (272 dp, own scroll)      |        wide tables up to 960 dp                  |
+---------------------------+--------------------------------------------------+
```

## 8. Interaction and accessibility

- **Keyboard order:** skip link, Lectale home, Contents control, Contents (one tab stop, roving focus), then main: Start course, author links, the overview in document order (links, Load buttons, scroll regions). Visual order matches.
- **Landmarks and headings:** banner; `nav` "Course contents"; main holds the h1 and the overview, whose headings shift by one level (README h1 renders as h2).
- **Labels for icon-only controls:** none. Close in the panel is named "Close contents".
- **Button labels never truncate.** Labels wrap, and button groups stack full width when their full labels don't fit at the current text size (Load images buttons included).
- **Touch targets:** Contents rows and buttons at least 44 dp; inline links have a 24 dp hit area (WCAG 2.2 2.5.8).
- **Motion:** only the ribbon (170 ms, instant under reduce-motion). No scroll animation.
- **Row names:** "{title}, lesson", "{title}, assignment, due {date and time}" (`dueAt` in the learner's time zone and locale, C6), with ", last opened" on the ribbon row and `selected` on Overview.

## 9. Copy

| Where | Text |
|---|---|
| Primary | Start course / Continue: {lesson title} |
| Contents | Contents, Overview, Close (name: Close contents), Course contents (nav name) |
| Assignment row | Assignment; Due {date and time} |
| Fact labels | Authors, Level, Time, Language, License |
| Level values | Introductory, Intermediate, Advanced, Mixed levels |
| Time | About {n} min |
| No overview | This course has no overview yet. Use Contents to start. |
| No lessons | This course has no lessons yet. Open another course. |
| Not available, overview errors | `../journeys-m2.md`, J5 error table; link: Enter the GitHub address |
| Retry, omission | Try again; Part of this overview can't be shown here. |
| External images | Load {n} images from {host} / Load image from {host} |
| External image note | Loading it contacts {host}, which will see your IP address. |
| Image failed, no alt | This image can't be shown. ({alt text}, {filename}); Image without description: {filename} |
| SVG line | {n} SVG images aren't shown, for safety. |
| Formula label | Formula, as written |
| Link names | {text}, opens in your browser / {text}, opens the file in your browser |

## 10. Images

| Image | Source | Rule |
|---|---|---|
| Brand mark | App asset, SVG | Vector; 28 dp; decorative |
| Cover | `course.cover` through the files route | 600 dp and wider only, start-aligned above the title, at most 240 × 160 dp, aspect kept; decoded at displayed size × device pixel ratio (`cacheWidth`; on the web the browser decodes); decorative (the title follows); if it fails or the path is invalid, the slot collapses |
| Overview image, relative path | Files route, same origin | WebP, PNG, JPEG, GIF; decode at displayed width × device pixel ratio; at most the column width (wide figures up to 960 dp); alt from Markdown, empty alt is decorative; no zoom here |
| Overview image from another host | Author's server | Click-to-load (N5), grouped as in §5 |
| SVG, `data:` | Embedded or any host | Never rendered |
| Alert icons | Lucide, vector | One family, one stroke weight. No icons in Contents rows (S13) |

## 11. Open questions

1. `OutlineResource` has no `path`, so a README link to a lesson file opens the raw file in the browser instead of that lesson in the Reader. Adding `path` (or a server map from path to resource) would fix it. Backend.
2. litse-ui lacks: app bar, skip link, list row, tree or accordion (collapsing modules in long outlines), scroll region helper, collapsible side pane.
3. Level and language values: I assume names via the platform locale, not raw codes.
4. Is the spec's `/about` README route kept as an alias of this screen? Router owner.
