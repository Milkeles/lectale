# Screen: Home

| | |
|---|---|
| **Milestone** | M2 |
| **Journeys** | J1, J5a, J5b, J5c, J5d (`../journeys-m2.md`) |
| **Requirements** | V4-CORE-01, V4-CORE-02, V4-SEC-03, V4-SEC-09, CAT-001, CAT-002, CAT-008, A11Y-001, A11Y-003, ERR-010 |
| **Status** | Draft 2, revised after `../reviews/m2-design-review.md` and `../reviews/m2-codex-design-opinion.md` |

The element table adds a Pattern column to the template, as the owner asked (known structures first, Jakob's Law). Sources are in `../inventory.md`. Error copy shared with the other screens is in `../journeys-m2.md`, J5 error table.

## 1. Purpose

A signed-out learner with a GitHub repository address wants to open that course; they succeed when the Course screen appears, or when they know exactly why it cannot open and what to change.

## 2. Primary action

**Open course.** Everything else (the field, the help, the messages) supports it.

## 3. Entry and exit

| Arrives from | Leaves to |
|---|---|
| App start; "Lectale home" on Course and Reader; "Enter the GitHub address" or "Open another course" on Course and Reader | Course (`/preview/{repoId}/{sha}`) after a successful import |

## 4. Content, in order of importance

1. Heading and the address field with its Open course button (the whole task).
2. The result of the last attempt: progress, or the error and how to fix it.
3. One line on which repositories work and that no account is needed.

## 5. Elements

| Element | litse-ui component | User task it serves | Requirement | UX law applied | Pattern |
|---|---|---|---|---|---|
| Skip link "Skip to main content" | **missing** (skip link) | Keyboard and screen-reader users bypass the bar | A11Y-001 | Fitts | Skip navigation link |
| Top bar: mark and wordmark "Lectale", plain text (not a link on this screen) | **missing** (app bar); `Row` | Recognise the app | V4-CORE-01 | Jakob | App bar with logo; no link to the current page |
| Heading "Open a course from GitHub" (h1) | `Text` (`display`) | Know what this screen does | V4-CORE-01 | Cognitive load | Page title |
| Help line under the heading | `Text` (`body`) | Know which repositories work and that no account is needed | V4-CORE-01, V4-CORE-02 | Postel, Proximity | Helper text under a title |
| Label "GitHub repository address" | `DcLabel` | Name the field for everyone | A11Y-003 | Jakob | Persistent visible label |
| Address field | `DcInput` (`autofillHints: url`, `invalid`) | Paste or type the address | V4-CORE-01, CAT-001 | Postel (forms in §8) | Single text field with inline validation |
| Example hint under the field "For example, https://github.com/owner/repository" | `Text` (`small`), linked to the field as its description | See the expected form after pasting, when a placeholder would be gone | CAT-001, A11Y-003 | Recognition over recall | Persistent hint text (no placeholder) |
| Inline field error | `Text` (`small`, destructive role), linked to the field | Fix an invalid address (J5a) | CAT-002, A11Y-003 | Error prevention | Inline form error under the field |
| Open course | `DcButton` primary, large, `loading` | Start the import; resubmit after a failure | V4-CORE-01 | Fitts, Von Restorff | Single primary form submit; Enter submits |
| Progress text | `Text` (`small`) in a polite live region; `DcSpinner` in the button | Know the request is running | V4-CORE-01 | Doherty (feedback within 400 ms) | Inline progress for a short request |
| Error alert (kinds in §6) | `DcAlert` destructive, `announce: false`; a separate polite live region speaks its summary | Learn what failed and what to do (J5b to J5d) | V4-SEC-09, ERR-010, CAT-002 | Error recovery | Inline alert inside the form column, not a dialog |
| Problems list (invalid course.yaml) | `Column` of `Text` rows | Give the author each error with its location (J5c) | V4-CORE-01, CAT-002 | Recognition over recall | Validation summary listing each issue |
| Support reference "Reference {requestId}" | `Text` (`small`, selectable) | Quote the failure to support | V4-SEC-09, ERR-010 | Tesler | Error reference code |

The content column is 560 dp, left-aligned on the start line (36 dp gutter, 18 dp under 600 dp), the same line as the brand mark. Alerts stay inside it (C8).

## 6. States

| State | What the reader sees | What they can do |
|---|---|---|
| Empty (first visit) | Heading, help line, empty field, hint, Open course enabled. The field is focused only when the window is at the wide threshold (`../inventory.md`), so a phone keyboard doesn't cover the help (C7) | Type or paste an address |
| Loading | Button spinner and "Reading the repository". The field stays editable. After 8 s the text becomes "Still reading. Large courses take longer." | Edit the field (cancels the request) or press Open course again (cancels and restarts with the current text); Escape cancels |
| Timed out (30 s) | J5 "Lectale is taking too long" alert; Open course enabled | Press Open course to retry |
| Error: empty | Field invalid: "Enter the address of a GitHub repository." | Type an address |
| Error: invalid address (client check, no request; or server `invalid_url` 400) | Field invalid: "That doesn't look like a GitHub repository address. Use the form https://github.com/owner/repository." Another host: "Lectale opens repositories on github.com. Use the form https://github.com/owner/repository." | Edit, press Open course |
| Error: not found or private (`course_not_found` 404) | Alert, same text for missing, private and unsafe addresses; reference | Edit the address |
| Error: no course.yaml (`manifest_missing` 422) | Alert, missing-file body; reference | Tell the author, or edit the address |
| Error: invalid course.yaml (`invalid_manifest` 422) | Alert plus the problems list from `details.errors[]`; "Showing the first 50 problems." when `details.truncated`; reference | Tell the author, or edit the address |
| Error: course.yaml too large (`manifest_too_large` 413) | Alert, too-large body; reference | Tell the author |
| Error: rate-limited (`rate_limited` 429) | Alert with the wait from `retryAfterSeconds` (J5 rules); Open course disabled until it ends | Wait; edit the address |
| Error: GitHub not answering (`github_unavailable` 502, `repository_changed` 503) | J5 alert; reference; Open course enabled | Press Open course to retry |
| Error: offline (no response) | J5 alert, no reference; Open course enabled | Press Open course to retry |
| Error: anything else | J5 "Lectale ran into a problem"; Open course enabled only if `retryable` | Retry if offered, or quote the reference |
| Success | Navigates to Course; focus moves to the course title | Read |

One focus rule: after any error, focus goes to the field (S2). The live region speaks the alert title and, for the problems list, the count ("course.yaml can't be used. 3 problems."); the list stays in reading order for those who move into it (S2). A rate-limit wait is spoken at its start and end only.

## 7. Wireframes

No border is drawn around the column; the boxes below are alerts only (C9).

### Phone (360 px)

```
+--------------------------------+
| [mark] Lectale                 |  top bar, scrolls away
+--------------------------------+
| Open a course from             |  h1
| GitHub                         |
| Any public GitHub repository   |
| with a course.yaml file. No    |
| account needed; Lectale only   |
| reads it.                      |
|                                |
| GitHub repository address      |
| [ github.com/ada/stats-101   ] |
| For example, https://github.   |
| com/owner/repository           |
| (inline error here)            |
| [        Open course         ] |  full-width primary
| +----------------------------+ |
| | ! Repository not available | |
| | Lectale can't open this    | |
| | repository. Check the ...  | |
| | Reference 4f2a9c           | |
| +----------------------------+ |
+--------------------------------+
```

### Tablet (768 px)

```
+----------------------------------------------------+
| [mark] Lectale                                     |
+----------------------------------------------------+
| Open a course from GitHub                          |
| Any public GitHub repository with a course.yaml    |
| file. No account needed; Lectale only reads it.    |
|                                                    |
| GitHub repository address                          |
| [ https://github.com/...       ] [ Open course ]   |
| For example, https://github.com/owner/repository   |
| +------------------------------------------------+ |
| | ! Too many requests. Try again in 40 seconds.  | |
| +------------------------------------------------+ |
+----------------------------------------------------+
 column 560 dp on the 36 dp start line
```

### Desktop (1440 px)

```
+------------------------------------------------------------------------------+
| [mark] Lectale                                                               |
+------------------------------------------------------------------------------+
|                                                                              |
| Open a course from GitHub                                                    |
| Any public GitHub repository with a course.yaml file. No account needed;    |
| Lectale only reads it.                                                       |
|                                                                              |
| GitHub repository address                                                    |
| [ https://github.com/...                  ] [ Open course ]                  |
| For example, https://github.com/owner/repository                             |
| +-------------------------------------------------------+                    |
| | ! course.yaml can't be used                           |                    |
| |   Use a repository-relative path.                     |                    |
| |   Outline item 3, resource 1, path                    |                    |
| |   /outline/2/resources/0/path   invalid_path          |                    |
| |   Reference 4f2a9c                                    |                    |
| +-------------------------------------------------------+                    |
+------------------------------------------------------------------------------+
 column 560 dp on the start line, 72 dp below the bar; the rest stays empty
```

## 8. Interaction and accessibility

- **Keyboard order:** skip link, address field, Open course. The top bar is not focusable here (plain text). The alert is not focusable; its summary is announced.
- **Landmarks and headings:** banner (top bar), main (everything else). One h1. Alert titles are not headings.
- **Labels for icon-only controls:** none. The mark is decorative (empty label) beside the wordmark text.
- **Touch targets:** field and button at least 44 dp high; all targets at least 24×24 (WCAG 2.2 2.5.8).
- **Motion:** none beyond the spinner and the alert appearing; both instant under reduce-motion.
- **Text scale:** reflows at 200 and 400 percent; the button is full width below 600 dp.
- **Address forms accepted** (Postel, S2): surrounding spaces; with or without `https://` or `http://`; `www.`; trailing slash; `.git`; query and fragment; `/tree/...` and `/blob/...` paths (cut to the repository, because the preview pins the default branch); `git@github.com:owner/repo.git` and `ssh://git@github.com/owner/repo`. The client sends only `https://github.com/owner/repository`, the form the server accepts.

## 9. Copy

| Where | Text |
|---|---|
| Title | Open a course from GitHub |
| Help | Any public GitHub repository with a course.yaml file. No account needed; Lectale only reads it. |
| Label | GitHub repository address |
| Hint | For example, https://github.com/owner/repository |
| Button | Open course |
| Progress | Reading the repository |
| Slow progress | Still reading. Large courses take longer. |
| Empty, invalid, other host | see §6 |
| Not found, title | Repository not available |
| Not found, body | Lectale can't open this repository. Check the address. A private repository can't be opened here. |
| course.yaml title | course.yaml can't be used |
| Body, problems | This repository's course.yaml has {n} problem(s). The course author needs to fix them before it can open. |
| Body, missing | This repository has no course.yaml at its top level. The course author needs to add one. |
| Body, too large | course.yaml is larger than Lectale can read. The course author needs to shorten it. |
| Problem row | {message}; then the location in words (each number in the pointer plus 1 after its parent's name, for example "Outline item 3, resource 1, path"; the root reads "Whole file"); then the exact pointer in `code` and {code} in small text (C10) |
| Truncated | Showing the first 50 problems. |
| Live summary | {title}. {n} problems. |
| Rate limit, GitHub, offline, timeout, other | `../journeys-m2.md`, J5 error table |
| Reference | Reference {requestId} |

## 10. Images

- Brand mark: app asset, SVG compiled with `vector_graphics_compiler`, drawn with `flutter_svg`; 28 dp tall; decorative next to the wordmark.
- Alert icon: Lucide, vector. No illustration, photo or raster image on this screen.

## 11. Open questions

1. Where do the accessibility statement and privacy links sit (A11Y-T05, V4-SEC-10)? A footer on Home is the known place; which milestone owns the pages?
2. The spec asks for owner connect and sign-in options on the not-found error. Both need M3; omitted here.
3. litse-ui lacks: app bar, skip link.

Resolved since draft 1: the error codes (Q1, Q2) are the Worker's at d766458; `/tree/` paths are cut to the repository (Q3); remembering the last course on the device is out of M2 (Q4, `../inventory.md` D11).
