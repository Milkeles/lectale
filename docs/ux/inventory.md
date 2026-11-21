# Screen inventory, M2

Three screens cover J1 to J5. Each has one purpose. Specs are in `screens/`. Revised 2026-11-21 after the design review (`reviews/m2-design-review.md`) and Codex's opinion (`reviews/m2-codex-design-opinion.md`); how each finding was handled is at the end.

| Screen | Spec | Single purpose | Primary action | Journeys |
|---|---|---|---|---|
| Home | `screens/home.md` | Turn a pasted GitHub address into an open course, or say exactly why it cannot open. | Open course | J1, J5a to J5d |
| Course | `screens/course.md` | Understand a course (its overview and facts) and choose where to start. | Start course (after a lesson is opened this visit: Continue: {lesson title}) | J2, J3, J3a, J5b, J5d, J5e |
| Reader | `screens/reader.md` | Read one resource of one lesson or assignment and move to the next. | Next | J3, J3a, J4, J5b, J5d, J5e |

## Merges and exclusions

- **Resource viewer merged into Reader.** Opening a resource and reading a lesson are one purpose; the viewer kind (Markdown, text, code, image, folder list, file card, link card) is a state of the same screen.
- **Contents is one shared pane, not a screen and not a tab.** Course and Reader show the same Contents pane on the same side, with Overview as its first entry (below).
- **Error screens merged into their owners.** Import errors show on Home, where the address is. A course that can't be reloaded from a link shows on Course or Reader with a way to Home. Resource errors stay inside the Reader's viewer.
- **README page (`/about`) merged into Course.** The README is the course overview.
- **Not in M2:** catalog, My courses, sign-in, owner connect, enrolment, submission, certificates, settings, Continue reading (D11), PDF, notebook and audio viewers and the in-app video player (M2b).

## Shared layout: top bar, Contents bar, Contents pane

Defined once here; `course.md` and `reader.md` list the same rows and point here.

**Top bar** (all three screens): the mark and the wordmark "Lectale". On Course and Reader it is one link named "Lectale home". On Home it is plain text, not a link (design review S14). It scrolls away with the page at every width (C13).

**Contents bar** (Course and Reader): a row under the top bar, at least 44 dp tall and growing with its text, that stays put when the page scrolls. At large text sizes the place title wraps to at most two lines, then ends with an ellipsis whose full text is the control's tooltip and accessible description. Scrolling keeps the focused element clear of the bar (`Scrollable.ensureVisible` with the bar's height as padding), so focus is never hidden behind it (WCAG 2.2 2.4.11). It holds the **Contents control**, a `DcButton` ghost whose visible text and accessible name are both "Contents".

- Wide layout: it opens and closes the pane, with `expanded` semantics.
- Single-column layout: it opens the Contents panel.
- Whenever the pane is not on screen, the ribbon sits at the control's start edge, and the title of the learner's place (the open lesson on Reader, the last-opened lesson on Course) shows beside it in `small` text, wrapping, never truncated. Then the learner's place stays visible on a phone (design review M5, Codex §3).

**Contents pane** (`nav` named "Course contents"):

| Row | Shows | Opens |
|---|---|---|
| Overview | "Overview" | Course |
| Module heading | module title, `subtitle` style, not a target; children indented 18 dp per level, visually capped at three levels | nothing |
| Lesson | lesson title only (no file counts, C5) | Reader at its first resource |
| Assignment | title, then "Assignment" and, if `dueAt`, "Due {local date and time}" on their own `small` lines | Reader |

- **Two marks, two meanings.** The *selected* row is the view on screen (Overview on Course, the open lesson on Reader): Sand fill plus a semibold title plus `selected` semantics, because a fill alone is under 3:1 (S7). The *ribbon* marks the learner's place: the open lesson on Reader; on Course this visit's last-opened lesson, or Overview before any. Its row's accessible name ends with ", current" (Reader) or ", last opened" (Course). Only one ribbon is ever on screen.
- **Keyboard** (S9): the pane is one tab stop with roving focus. Up and Down move, Home and End jump, Enter or Space opens. Tab into the pane lands on the selected row.
- **Scroll:** at wide widths the pane scrolls on its own. On a lesson change the ribbon row is scrolled into view instantly (no animated scroll). The pane keeps its scroll position across Course and Reader.
- **Contents panel** (single-column layout): the same list fills the window below the Contents bar. It is part of the route (`?contents`), so system Back closes it. It has the heading "Contents" (h2) and a "Close" button (name "Close contents"). Choosing a row navigates and closes the panel. Reopening restores its scroll position and focuses the selected row (Codex §2).
- **Pane open or closed** is remembered in memory for the visit only.

## Keyboard: every screen

Everything a pointer can do, a keyboard can do, on all six platforms: web and desktop, and phones and tablets with a hardware keyboard (WCAG 2.1.1, 2.1.2, 2.1.4, 2.4.3, 2.4.7, 2.4.11).

- Tab and Shift+Tab visit every control in reading order: the skip link first, then the order listed under "Keyboard order" in the screen spec.
- Enter activates links and buttons; Space activates buttons. Escape closes the Contents panel, menus and tooltips, and focus goes back to the control that opened them.
- A list that works as one control (Contents, In this lesson) is one tab stop with roving focus: Up and Down move, Home and End jump.
- A scroll region without controls of its own (code, wide tables, a PDF page) takes focus so the arrow keys scroll it, and Tab leaves it. Nothing traps focus.
- After moving to another screen, focus starts at the top of it, so the first Tab reaches the skip link. A screen spec may name an exception (Home focuses the address field at wide widths). Back returns focus to the control that left the screen.
- The gold focus ring shows on every control focused by keyboard, outside a 2 dp Paper gap, and is never covered by the top bar: a focused control scrolls into view.
- No single-key shortcuts. Platform shortcuts, such as browser Back and Ctrl or Cmd+F in the PDF viewer, keep working.
- Actions use litse-ui controls, which carry focus, semantics and key handling; never a bare `GestureDetector`.

Verified by:

1. A keyboard-only widget test for each screen. It presses Tab through the screen and checks that focus follows the spec's keyboard order. Then it completes the screen's main task with keys alone: on Home, type an address and press Enter to open Course; on Course, press Enter on Start course; on Reader, move through Contents with the arrow keys and open a lesson.
2. The visual review on the web build captures the focus ring at each Tab stop (`visual-review-loop`).
3. A shared test helper (`expectTabOrder`) keeps these tests short and identical across screens.

## Breakpoints: set by the text

Breakpoints come from the reading measure, not from device names (Codex §4; Flutter's guidance to branch on window size, not device type). `em` is the reading size: 18 dp at 100 percent text.

| Layout | When | Contents | Text column |
|---|---|---|---|
| Single column, compact gutter | window under 600 dp | panel from the Contents control | window minus 2 × 18 dp, at most 32 em |
| Single column, wide gutter | 600 dp up to the wide threshold | panel from the Contents control | window minus 2 × 36 dp, at most 32 em |
| Wide | window ≥ 36 + 272 + 36 + 32 em + 36 dp (956 dp at 100 percent text, 1532 dp at 200 percent) | 272 dp pane on the start side, open by default, collapsible | 32 em (576 dp at 100 percent), centred in the space beside the pane; headers share its start edge |

- The 32 em cap gives about 73 characters per line in Source Serif 4 (0.438 em per character on English prose, measured; `token-plan.md`). The skill asks for 60 to 70.
- Tables, code blocks and figures may be wider than the text: up to the main area minus gutters, at most 960 dp, centred on the same axis. Beyond that, tables and code scroll sideways in their own region.
- Opening, closing or resizing the pane keeps the paragraph at the top of the viewport where it is (scroll anchoring), and keeps Previous and Next at the end of the text.
- At 360 dp the text column is 324 dp, about 39 characters: acceptable on a phone.
- Home has no pane: its 560 dp column starts on the 36 dp gutter (18 dp under 600), the same start line as the brand mark (C8).

## Routes (proposal; the router owner decides)

| Screen | Route | Data on a cold open |
|---|---|---|
| Home | `/` | none |
| Course | `/preview/{repoId}/{sha}`, `?contents` for the panel | `GET /api/preview/{repoId}/{sha}` unless the import result is already in memory |
| Reader | `/preview/{repoId}/{sha}/read/{nodeId}?r={resourceId}` | the same, then the resource's `href` |

IDs come from `CoursePreview` and `CourseOutline`. A changed lesson pushes a history entry; a changed resource within a lesson replaces it (S8). The API routes and the one case where the client builds a files-route address are listed in `journeys-m2.md`.

## Patterns the screens follow

The owner asked for known structures (Jakob's Law). Pattern names and behaviour come from the sources fetched on 2026-11-21 and listed at the end, except where marked as Codex's proposal.

| Pattern | Source behaviour (paraphrased) | Where Lectale uses it |
|---|---|---|
| Window size classes | Compact under 600 dp, medium 600 to under 840, expanded 840 and up. Branch on the app window, not the device type. | Gutters switch at 600. The pane threshold is computed from the text (above), which Codex proposed; it is not a Material class. |
| List-detail (canonical layout) | Wide: list and detail side by side, selection updates the detail, the list marks the selected item. Narrow: one pane at a time. | Contents (list) beside Overview or a resource (detail). Overview is the first list item, so Course and Reader are two details of one list. |
| Table of contents | A hierarchical list of the document's parts with the current place marked. | The Contents pane and panel. |
| Collapsible outline | Codex's proposal (Codex §4): an outline that can be hidden so the text gets the room. | The Contents control at wide widths. |
| Previous and next (reading convention) | End-of-chapter links to the neighbouring chapter in book order. | Reader footer. |
| Content width cap | Do not let text or boxes fill a large window; cap with `maxWidth`. | 32 em reading column; Home column 560 dp. |
| Navigation rail, bottom bar | Pick by window class when an app has several top-level destinations. | Not used: M2 has one destination. Revisit with My courses. |
| Modal dialog, sheet | Short, interruptible tasks. | Not used in M2. |

Also from the fetched Flutter guidance: no phone or tablet checks; keyboard, mouse and trackpad on every flow; keep state and scroll position when the window resizes or a foldable opens. The Reader keeps the current resource and the top paragraph when the layout switches between one column and two.

## Sources fetched (2026-11-21)

Fetched with curl and converted with pandoc. Treated as data.

- https://docs.flutter.dev/ui/adaptive-responsive (adaptive versus responsive; Flutter 3.50 docs, updated 2026-05-05)
- https://docs.flutter.dev/ui/adaptive-responsive/general (abstract, measure, branch; `MediaQuery.sizeOf` versus `LayoutBuilder`)
- https://docs.flutter.dev/ui/adaptive-responsive/large-screens (do not let text or boxes fill the full width; `maxWidth`)
- https://docs.flutter.dev/ui/adaptive-responsive/best-practices (no hardware-type checks; keyboard and pointer; restore state)
- <https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts> (list-detail, supporting pane)
- <https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes> (width classes)
- Reading-face sources are in `../research/2026-11-21-reading-fonts-bulgarian.md`.

Blocked: the m3.material.io canonical-layout and window-size-class pages (curl status 000). The names above come from developer.android.com, which describes the same layouts.

## How each review finding was handled

Must-fix, all resolved:

| ID | Finding | Resolution | Where |
|---|---|---|---|
| M1 | Reload or shared link is a dead end | Course and Reader load `GET /api/preview/{repoId}/{sha}` on a cold open, with skeleton, not-found (privacy-neutral, link to Home labelled "Enter the GitHub address", so "Open course" keeps one meaning) and the J5 error states. No storage fallback is needed. | `course.md` §6, `reader.md` §6, `journeys-m2.md` J3a |
| M2 | README images and relative links have nothing to load | README images, relative links and the cover use the files route. A table of link and image cases (anchor, repository file, `https`, path outside the root, missing file, Markdown lesson images without a known path) is in Course §5 and reused by Reader. | `course.md` §5, §10; `reader.md` §5, §10 |
| M3 | File cards with no working action | Reader §5 has a card table by kind, `href`, `url`, `embedUrl` and `download`. A kind with no viewer always offers Download; `download: false` only hides the bar's Download when a viewer works. Folders list their entries through the folders route. YouTube and Vimeo open `embedUrl` in the browser after a tap. No button is drawn whose request is known to fail. | `reader.md` §5, §9 |
| M4 | Breadcrumb item with no destination; back control fails 2.5.3 | The breadcrumb and the back control are removed (D2, D3). Up navigation is Overview in Contents; the module title is a plain line above the h1. The Contents control's name equals its visible text. The top bar holds the brand only. | `reader.md` §5, §8; this file, Shared layout |
| M5 | Contents changes sides; current place not marked | One pane on the start side on both screens; the ribbon marks the open lesson on Reader and the last-opened lesson on Course, and moves to the Contents control when the pane is hidden, so phones show it too. Start course becomes "Continue: {lesson title}". | this file, Shared layout; `course.md` §2, §5 |
| M6 | README headings smaller than body text | One heading map in `token-plan.md`: no content heading under 18 dp or over the page h1; Course shifts README headings by one level, Reader shifts Markdown headings by two. | `token-plan.md` Type |

Should-fix, all applied:

| ID | Resolution |
|---|---|
| S1 | One error table in `journeys-m2.md` J5, keyed by `code` and `retryable`; Try again only when it can help; references on every server answer; offline copy only without a response; new Reader 404 copy; J5e reworded. |
| S2 | Home: server 400 maps to the field; one rate-limit message from `retryAfterSeconds` with a fallback; field stays editable while loading and editing cancels; 30 s timeout state; SSH and `http://` normalised; the 422 alert announces title and count only; one focus rule. The truncated-tree state is not added because the code no longer exists (D16). Q1 and Q2 answered with the Worker's codes. |
| S3 | One help line under the heading; the privacy line is removed; README.md is no longer called required. |
| S4 | Header order title, summary, Start course, facts at every width; Start course before author links; tags and version removed; facts as labelled pairs. |
| S5 | No lessons: Start course removed, copy names the next action and links to Home. No README: on single-column layouts the Contents list shows inline under the header. |
| S6 | One name per thing: "Overview" (D5), "Back to course" for the end control, "Enter the GitHub address" for the way to Home, "your IP address" in the image note. |
| S7 | The bar's Download hides when a card or decode box offers Download; In this lesson is rows at every width; selected rows use Sand plus semibold plus `selected`; the ribbon stays in Contents. |
| S8 | Next and Previous stack below 600 dp, Next first; no Previous on the first item; labels name file, lesson or assignment; focus and history rules written. |
| S9 | Roving focus in Contents and In this lesson; ribbon row scrolled into view on a lesson change. |
| S10 | 32 em reading cap; text files split into prose (Reading style, wrapped) and data (Code style, unwrapped); 18 dp on every wireframe; line height stated once; variable reading face so weights and semibold italic exist (Literata) or the bundle adds semibold italic (Plex Serif); Greek checked for both. |
| S11 | Sanitise rather than drop: safe HTML subset, a visible line for anything removed, grouped image placeholders per host, formula source on parse failure, raw HTML moved to a Rules note. |
| S12 | Sizes show only when known (`sizeBytes` is still absent at d766458; folder entries carry `size`); the 512 KB rule reads `Content-Length`. Asked again in Reader Q1. |
| S13 | Kind and row icons removed from lists; this is the pre-ship removal in `token-plan.md`. |
| S14 | One top bar with mark and wordmark; plain text on Home. |
| S15 | Image viewer cites `RENDERING_REQUIREMENTS.md` (Images) and A11Y-002; zoom buttons get `DcTooltip`. |

Consider items applied: C2 (focus changes are instant; four accent jobs named), C3 (edges snap to device pixels), C5 (counts removed), C6 (local date and time), C7 (autofocus only at the wide threshold), C8, C9 (wireframes say "no border"), C10 (1-based location beside the pointer), C11, C13. C12 is moot: Contents now precedes main and the skip link jumps past it. C1 feeds D12. C4 is not applied (D10).

## Review decisions

Where the two reviews agreed, the shared change is applied above. Where they differed, or where the new API changed the answer, the choice and the reason:

| # | Question | Design review | Codex | Chosen, and why |
|---|---|---|---|---|
| D1 | Contents form | Start side on both screens; tab below 840 | One shared pane with Overview on top | Codex, which also meets the review's M5. Tabs are gone, so S5 and S6's tab fixes are covered by the Overview naming and the inline list. |
| D2 | Breadcrumb | Repair it (title link, module and lesson as text) | Not addressed; shared pane with Overview | Remove it. With the pane on the same side and Overview first, it duplicated Contents (the review counted five ways to move at 1440, Hick). Removing it also removes all three M4 problems. The module title stays as one plain line above the h1. |
| D3 | Up control on narrow windows | Rename to "Back to {course title} contents" | A visible Contents control | Codex. One control on every width, name equals its text (2.5.3), and it carries the ribbon on a phone. |
| D4 | Breakpoint for the pane | 840 dp | Set by the text | Codex. At 840, 320 + 640 dp didn't fit; the text-led rule keeps 32 em at any text size. |
| D5 | Name of the README view | "Description" | "Overview" | "Overview", used in the pane and in every message about it ("The overview can't be shown"), so the review's one-name rule holds. |
| D6 | Version and license | Remove version | Keep both in quiet source details | Version removed, license kept as a fact. License tells a learner whether they may reuse the material; version has no learner task and the pinned commit is already hidden (Tesler). |
| D7 | Heading of a single resource | h2 with name and meta | Lesson title is the heading; meta goes to the Download area | Codex for one-resource lessons; h2 appears only with two or more files. Removes a filename heading that repeats the lesson. |
| D8 | Next label | "Next lesson: {title}" when crossing | Distinguish Next file from Next lesson | Both: "Next file", "Next lesson", "Next assignment". |
| D9 | Ribbon | 3 dp, Contents only, one on screen | 8 to 10 dp swallowtail; on the Contents control when the outline is closed | Both: 8 dp swallowtail; one on screen, in the pane when visible, else on the control. |
| D10 | Resources of the open lesson | Rows at every width (S7); consider nesting in the pane (C4) | Keep choices visible when there are several | S7 rows in the reading pane at every width. Nesting would make the pane differ between Course and Reader and would vanish on phones. |
| D11 | Continue reading | Not raised | Add one local entry on Home | Dropped. COOKIE-002 requires granular prior permission for any non-essential device storage and CT-001 gives a new visitor none; a reading position is not strictly necessary and M2 has no consent control. It would store no credentials (course ID, commit, lesson and resource IDs, a scroll offset), but that does not make it necessary. In-memory "Continue: {lesson}" (review M5) is kept. Revisit with a consent setting in a later milestone. |
| D12 | Colour and type | Cobalt passes; C1 notes it is close to IBM Carbon | Warm paper, graphite, mulberry, Literata | Owner chose warm paper and mulberry, with gold as the one accent and Source Serif 4 as the reading face (2026-11-21). |
| D13 | Folder in M2 | Card: "Folders open in a later version" | Not addressed | The new folders route makes a list possible with rows and Download buttons only, so M2 lists entries. The sample course's first lesson has a folder; a card would be a dead end. |
| D14 | YouTube and Vimeo | Link card to the watch page built from `embedUrl` | Not addressed | Link card that opens `embedUrl` as given, so the client never rewrites provider URLs; nothing loads before the tap. The in-app player with consent is M2b. |
| D15 | Course cover | Not shown (no route) | Not addressed | Shown at 600 dp and wider, above the title, through the files route. Not on phones, where it would push Start course down. |
| D16 | Truncated-tree state on Home (S2) | Add it | Not addressed | Not added: `repository_tree_truncated` does not exist at d766458, which reads no recursive tree. A file past GitHub's 1,000-entry directory cap answers 404 and shows "This file isn't available". |
| D17 | Images in Markdown lessons | Design the case | Not addressed | `OutlineResource` has no `path`, so a lesson's relative image can't be resolved: it shows the "can't be shown in this version" box. README images work. Asked of the backend in Reader Q2. |
