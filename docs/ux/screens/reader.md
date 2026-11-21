# Screen: Reader

| | |
|---|---|
| **Milestone** | M2 (M2b adds PDF, notebook, video, audio and folder viewers) |
| **Journeys** | J3, J4, J5d, J5e (`../journeys-m2.md`) |
| **Requirements** | V4-CORE-01, V4-CORE-05 (preview part), V4-SEC-03, README-005, N5, A11Y-001, A11Y-002, A11Y-007, ERR-007, ERR-010 |
| **Status** | Draft |

Pattern column added to the template per the owner's request; names and sources in `../inventory.md`.

## 1. Purpose

A learner reading one lesson or assignment wants to read its current resource and move on; they succeed when they have read it and open the next one without hunting.

## 2. Primary action

**Next** (the next resource in the lesson, else the first resource of the next lesson; the label names the target). On the last item it becomes **Back to course**.

## 3. Entry and exit

| Arrives from | Leaves to |
|---|---|
| Course (Start course, lesson or assignment row) | Next or previous resource or lesson (same screen); Course (back control, last item); Home (brand link); an external link (new tab); a file download |

## 4. Content, in order of importance

1. The resource itself.
2. Lesson title and, if the lesson has several resources, the list of them.
3. Next and Previous.
4. Where I am in the course (breadcrumb, contents).

## 5. Elements

| Element | litse-ui component | User task it serves | Requirement | UX law applied | Pattern |
|---|---|---|---|---|---|
| Skip link | **missing** (skip link) | Bypass bar and contents | A11Y-001 | Fitts | Skip navigation link |
| Top bar: brand mark link | **missing** (app bar) | Return to Home | V4-CORE-01 | Jakob | App bar |
| Back control with course title (below 840 px) | `DcButton` ghost, leading `LucideIcons.chevronLeft` | Go up to the Course contents (the list) | V4-CORE-01 | Jakob, Fitts | Up navigation; list-detail back on compact and medium |
| Breadcrumb "Course / Module / Lesson" (840 px and wider) | **missing** (breadcrumb); interim `Row` of `DcButton` link | See where I am; jump up a level | A11Y-007 | Jakob | Breadcrumb for hierarchy |
| Contents list pane (840 px and wider) | **missing** (list row, tree); interim rows | Jump to any lesson while reading; see current place | V4-CORE-01 | Zeigarnik, Von Restorff (the one marked row) | List pane of list-detail; table of contents |
| Current-place marker (ribbon) in the contents | `Container` in `primary` role, 3 dp wide | Know where I am | V4-CORE-01 | Von Restorff | The memorable element (see `../token-plan.md`) |
| Lesson or assignment title (h1) and description | `Text` (`heading`, `reading`) | Know what this lesson is | V4-CORE-01 | Cognitive load | Page title |
| Assignment dates (release, open, due, close; only those present) | `Text` rows (`small`) | Know deadlines | V4-CORE-01 | Chunking | Metadata list |
| Assignment note | `Text` (`small`) | Know that submitting is not available here | V4-CORE-01 | Tesler | Inline note |
| In-this-lesson list (only if the lesson has two or more resources): title, kind, size | **missing** (list row); interim rows | Choose a resource (J4) | A11Y-007 | Miller | Item list above detail; selected row marked |
| Resource heading (h2) and meta (kind, size) | `Text` (`title`, `small`) | Know what I am looking at | A11Y-007 | Proximity | Document header |
| Download | `DcButton` outline (hidden when `download` is false and the viewer works) | Keep a copy | V4-CORE-05 | Jakob | Secondary action in the document header |
| Markdown viewer | App renderer (see `course.md` for element rules) | Read text with formulas, tables, code | V4-CORE-05, V4-SEC-03 | Jakob | Reading column, 640 dp |
| Text viewer | `Text` in `code` style, wrapped | Read plain text | V4-CORE-05 | Jakob | Plain-text document |
| Code viewer: line numbers, language label, horizontal scroll, copy | `Text` in `code` style, `DcButton` ghost "Copy" | Read and copy code | V4-CORE-05 | Jakob | Code viewer with gutter |
| Image viewer: image, alt or title, zoom in, zoom out, reset | `Image`, `DcButton.icon` x3 with labels | See detail in a figure | V4-CORE-05, A11Y-005 | Jakob | Zoom controls; pinch and wheel also work |
| External image gate (see `course.md`) | as in `course.md` | Choose to load | N5 | Consent | Click-to-load |
| File card: name, type, size, reason, Download | `DcCard` + `DcButton` outline | Get a file Lectale cannot show (J4) | V4-CORE-05, RENDERING | Postel, no dead end | Metadata card with a download action |
| Link card (`external`, URL-only video): title, host, Open link | `DcCard` + `DcButton` outline | Follow an outside link knowingly | RENDERING | Jakob | Link card |
| Previous | `DcButton` ghost, label with target title | Go back one step | V4-CORE-01 | Jakob | Previous and next (reading convention) |
| Next | `DcButton` primary, large | Go forward one step | V4-CORE-01 | Serial position, Fitts | Previous and next; right-hand position |
| End-of-course note | `Text` (`reading`) | Know I finished | V4-CORE-01 | Peak-End | Calm end state |
| Layout: contents list left, resource right at 840 px and wider | `Row` + `LayoutBuilder` | Move and read in one view | V4-CORE-01 | Jakob | List-detail, expanded width |

Kinds without a viewer in M2 (`pdf`, `notebook`, `video` file, `audio`, `folder`, `svg`, text over 512 KB, any unknown extension) use the file card. `auto` is resolved from `fileExtension` and `mediaType`. When `download` is false the card says so and offers no Download.

## 6. States

| State | What the reader sees | What they can do |
|---|---|---|
| Loading | Header and controls at once; viewer area shows `DcSkeleton` lines (image: a block at the image's ratio if known) | Next, Previous, Contents stay usable |
| Empty: lesson has no resources | "This lesson has no files yet." | Next |
| Error: resource unavailable (404 masked) | In the viewer area: "This file can't be opened. It may have been moved or removed from the course." plus Try again | Try again, Next, Contents |
| Error: rate-limited | "Too many requests. Try again in {n} seconds." | Try again when enabled |
| Error: offline or server | "Lectale can't be reached. Check your internet connection." plus reference | Try again |
| Error: image fails to decode | Alt text and filename in the image's box, plus Download | Download, Next |
| Error: opened by link, outline not in memory | As in `course.md` | Go to Home |
| Success: viewer shown | Resource | Read, zoom, copy, download |
| End | On the last item Next reads "Back to course" and the note "You've reached the end of this course." appears above it | Back to course |

A failure stays inside the viewer. Controls and navigation never disappear. On a layout switch (one pane to two) the current resource and scroll position are kept.

## 7. Wireframes

### Phone (360 px)

```
+--------------------------------+
| [mark]                         |
| < Introduction to Statistics   |  up navigation
+--------------------------------+
| Reading data                   |  h1
| How to load a CSV file.        |
| In this lesson                 |
| |data.md        Markdown       |  marked row
|  survey.csv     Text, 12 KB    |
| ------------------------------ |
| data.md           [Download]   |
| Text text text, 17 px...       |
| ...                            |
| [Previous]       [ Next: ... ] |
+--------------------------------+
```

### Tablet (768 px)

```
+----------------------------------------------------+
| [mark]                                             |
| < Introduction to Statistics                       |
+----------------------------------------------------+
|   Reading data                                     |
|   In this lesson: data.md | survey.csv             |
|   +--------------------------------+               |
|   | resource, 640 dp column        |               |
|   +--------------------------------+               |
|   [Previous]                  [ Next: Summaries ]  |
+----------------------------------------------------+
  medium window: detail only; back returns to Contents
```

### Desktop (1440 px)

```
+------------------------------------------------------------------------------+
| [mark]   Course / Module 1: Data / Reading data                              |
+------------------------------------------------------------------------------+
| Contents (list pane, 320 dp)  | Reading data                                 |
|  Module 1: Data               | In this lesson: data.md | survey.csv         |
| |Reading data      (ribbon)   | data.md                       [Download]     |
|   Summaries                   | +----------------------------------------+   |
|  Assignment 1  Due 3 Dec      | | resource, 640 dp column                |   |
|                               | +----------------------------------------+   |
|                               | [Previous]                    [ Next: ... ]  |
+------------------------------------------------------------------------------+
```

## 8. Interaction and accessibility

- **Keyboard order:** skip link, brand link, back control or breadcrumb, Contents rows (840 px and wider), In-this-lesson rows, Download, viewer content (code scroll region, zoom controls, image gate buttons), Previous, Next. On opening a lesson, focus goes to its h1. Selecting a resource moves focus to its h2.
- **Shortcuts:** none beyond defaults (Tab, Enter, Space, arrows in lists, +, - and 0 on the image viewer). Next and Previous are not bound to arrow keys, to avoid clashing with scrolling.
- **Landmarks and headings:** banner; `nav` "Course contents"; main with h1 (lesson), h2 (resource); `nav` "Lesson steps" holds Previous and Next. The marked row has `selected` semantics and "current" in its name.
- **Labels for icon-only controls:** zoom in, zoom out, reset zoom, and the chevron on Back all carry labels ("Zoom in", "Zoom out", "Reset zoom", "Back to course contents").
- **Touch targets:** at least 44 dp; zoom controls 44 dp.
- **Motion:** the ribbon moves to the new row in 170 ms; none otherwise. Reduce-motion makes it instant. Scroll resets to top on a new resource.
- **Text:** body 18 dp, 64 to 70 characters per line, left aligned, scales with the system setting.

## 9. Copy

| Where | Text |
|---|---|
| Back control | {course title} (name: Back to course contents) |
| Breadcrumb nav name | You are here |
| List section | In this lesson |
| Meta | {kind}, {size} |
| Next | Next: {title} |
| Previous | Previous: {title} |
| Last item | Back to course |
| End note | You've reached the end of this course. |
| Download / Copy | Download, Copy |
| Copy done (live region) | Copied |
| Zoom | Zoom in, Zoom out, Reset zoom |
| No resources | This lesson has no files yet. |
| Assignment note | You can read this assignment here. Submitting is not available in a preview. |
| Assignment dates | Opens {date}, Due {date}, Closes {date} |
| Unavailable | This file can't be opened. It may have been moved or removed from the course. |
| Retry | Try again |
| File card reason, no viewer | Lectale can't show {PDF files} in this version. Download the file to read it. |
| File card reason, unknown | Lectale can't show this type of file. Download it to open it in another app. |
| File card, too large | This file is too large to show here. Download it to read it. |
| File card, downloads off | The course author turned off downloads for this file. |
| Link card | Opens {host} in your browser. Open link |
| External image | Load image from {host} |

## 10. Images

| Image | Source | Rule |
|---|---|---|
| Resource `image` (PNG, JPEG, GIF, WebP) | Scoped preview href, same origin | Loads normally; decode at displayed size x device pixel ratio with `cacheWidth` (native); web: browser decodes; shown at most 100% of the column and at most 1600 dp tall; zoom up to 400% re-decodes the visible size only; alt from `title`/`description` |
| Resource `image` SVG | Repository | Not rendered (can carry script). File card with Download |
| Images inside Markdown | Repository or other host | Same rules as `course.md` (repository: loads; other host: click-to-load; `data:`: never) |
| Resource kind icons in lists | Lucide, vector | One family; text label always beside the icon |
| Brand mark | App asset SVG | Vector, decorative |

## 11. Open questions

1. Text size limit for inline viewing: I propose 512 KB for text and code, larger shows the file card. Confirm against Worker response limits.
2. Syntax highlighting: highlight is a nicety; plain text first. Which highlighter package (needs the Material check, ADR-0006)?
3. litse-ui lacks: app bar, skip link, breadcrumb, list row (ListTile), tree or accordion, sidebar or split-pane helper, scrollable tabs, determinate progress.
4. Should Next skip assignment rows with no resources? I assume it does not skip them.
5. Add an arrow-key shortcut for Next and Previous later? Left out in M2.
