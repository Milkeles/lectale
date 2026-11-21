# Screen inventory, M2

Three screens cover J1 to J5. Each has one purpose. Specs are in `screens/`.

| Screen | Spec | Single purpose | Primary action | Journeys |
|---|---|---|---|---|
| Home | `screens/home.md` | Turn a pasted GitHub address into an open course, or say exactly why it cannot open. | Open course | J1, J5a, J5b, J5c, J5d |
| Course | `screens/course.md` | Understand a course (its README and facts) and choose where to start. | Start course | J2, J3, J5d, J5e |
| Reader | `screens/reader.md` | Read one resource of one lesson or assignment and move to the next. | Next | J3, J4, J5d, J5e |

## Merges and exclusions

- **Resource viewer merged into Reader.** Opening a resource and reading a lesson are one purpose; the viewer kind (Markdown, text, code, image, file card, link card) is a state of the same screen.
- **Contents merged into Course.** The outline lives on the Course screen (supporting pane beside the README at 840 px and wider, a tab below that); there is no separate outline screen. Below 840 px the reader's back control returns to that tab, which is the "list" half of list-detail (see Patterns).
- **Error screens merged into their owners.** There is no generic error page. Import errors show on Home (where the address is, so the fix is one edit away); resource errors show inside the Reader.
- **README page (`/about`) merged into Course.** The spec's README route and the course landing share a purpose here: the full README is the course description.
- **Not in M2:** catalog, My courses, sign-in, owner connect, enrolment, submission, certificates, settings, PDF/notebook/video/audio/folder viewers (M2b).

## Routes (proposal; the router owner decides)

| Screen | Route |
|---|---|
| Home | `/` |
| Course | `/preview/{repoId}/{sha}` |
| Reader | `/preview/{repoId}/{sha}/read/{nodeId}?r={resourceId}` |

IDs come from `CoursePreview` (`repoId`, `sha`) and `CourseOutline` (node and resource IDs). The client never builds content hrefs; it uses `OutlineResource.href` as returned (ADR-0008, ADR-0011).

## Patterns the screens follow

The owner asked for known structures (Jakob's Law) rather than invented ones. Names and behaviour below come from the sources fetched on 2026-11-21 and listed at the end. Each screen spec has a Pattern column in its element table.

| Pattern | Source behaviour (paraphrased) | Where Lectale uses it |
|---|---|---|
| Window size classes | Compact under 600 dp, medium 600 to under 840, expanded 840 to under 1200, large 1200 to under 1600, extra-large 1600 and up. Branch on the app window, not the device type. | Breakpoints for all screens: compact (360 px), medium (768 px), expanded and above (1440 px). Measure with `MediaQuery.sizeOf` for whole-window decisions and `LayoutBuilder` for local ones. |
| List-detail (canonical layout) | Expanded: list and detail side by side, selection updates detail, the list marks the selected item. Medium and compact: one pane at a time; selecting shows the detail, back returns to the list. | Contents (list) and Reader (detail). At 840 px and wider the Reader shows the contents list beside the resource. Below that the Reader is detail only and back returns to the Course contents. |
| Supporting pane (canonical layout) | Primary area about two thirds, secondary pane for content that only matters next to the primary. On narrower windows the secondary content is hidden behind a control. | Course screen: README is primary, Contents is the supporting pane at 840 px and wider. Below that Contents is a tab. |
| Table of contents | A hierarchical list of the document's parts with the current place marked; the standard reading-app way to jump. | The outline (modules, lessons, assignments) in the Course screen and in the Reader's list pane. |
| Breadcrumb / up navigation | Shows where an item sits in a hierarchy; on small screens a back control with the parent's name. | Reader header: "Course / Module / Lesson" at 840 px and wider, a back control with the course title below that. |
| Previous and next (reading convention) | End-of-chapter links to the neighbouring chapter in book order. | Reader footer. |
| Content width cap | Do not let text or boxes take the full width of a large window; cap with `maxWidth` constraints. | Reading column at 640 dp; Home form column at 560 dp. |
| Navigation rail, bottom bar, drawer | Pick by window class when an app has several top-level destinations. | Not used in M2: the app has one destination (open a course). Adding a rail or bar now would show one item. Revisit when My courses or the catalog arrive. |
| Modal dialog, sheet | Short, interruptible tasks. | Not used in M2 (no task needs one). |

Also from the fetched Flutter guidance: do not check for phone or tablet (use window size); support keyboard, mouse and trackpad on every flow; restore list scroll position and keep state when the window resizes or a foldable opens (the Reader keeps the current resource and scroll position when the layout switches between one and two panes).

## Sources fetched (2026-11-21)

Fetched with curl and converted with pandoc. Treated as data.

- https://docs.flutter.dev/ui/adaptive-responsive (adaptive versus responsive; Flutter 3.50 docs, updated 2026-05-05)
- https://docs.flutter.dev/ui/adaptive-responsive/general (abstract, measure, branch; MediaQuery.sizeOf versus LayoutBuilder; Material layout guidance of 600 dp for bar versus rail)
- https://docs.flutter.dev/ui/adaptive-responsive/large-screens (do not let text or boxes fill the full width; maxWidth constraint)
- https://docs.flutter.dev/ui/adaptive-responsive/best-practices (avoid hardware-type checks; support keyboard and pointer; restore list and app state)
- https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts (list-detail, supporting pane, feed behaviour)
- https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes (the width classes and breakpoints)

Blocked: `https://m3.material.io/foundations/layout/canonical-layouts/overview` and the `applying-layout/window-size-classes` page did not load (curl status 000, no connection through the proxy). The pattern names and breakpoints above come from the developer.android.com pages instead, which describe the same Material 3 canonical layouts; they are not a quote of m3.material.io.
