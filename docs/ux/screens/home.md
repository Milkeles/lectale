# Screen: Home

| | |
|---|---|
| **Milestone** | M2 |
| **Journeys** | J1, J5a, J5b, J5c, J5d (`../journeys-m2.md`) |
| **Requirements** | V4-CORE-01, V4-CORE-02, V4-SEC-03, V4-SEC-09, CAT-001, CAT-002, CAT-008, A11Y-001, A11Y-003, ERR-010 |
| **Status** | Draft |

The element table adds a Pattern column to the template, as the owner asked (known structures first, Jakob's Law). Sources are in `../inventory.md`.

## 1. Purpose

A signed-out learner with a GitHub repository address wants to open that course; they succeed when the course screen appears, or when they know exactly why it cannot open and what to change.

## 2. Primary action

**Open course.** Everything else (the field, the help line, the error messages) supports it.

## 3. Entry and exit

| Arrives from | Leaves to |
|---|---|
| App start; the brand link on Course and Reader; a failed import that returns the learner to the field | Course (`/preview/{repoId}/{sha}`) after a successful import |

## 4. Content, in order of importance

1. Heading and the address field with its Open course button (the whole task).
2. The result of the last attempt: progress, or the error with how to fix it.
3. One line on what repositories work and that no account is needed.

## 5. Elements

| Element | litse-ui component | User task it serves | Requirement | UX law applied | Pattern |
|---|---|---|---|---|---|
| Skip link "Skip to main content" | **missing** (skip link) | Keyboard and screen-reader users bypass the bar | A11Y-001 | Fitts | Skip navigation link |
| Top bar with brand mark and wordmark (link to this screen) | **missing** (app bar); compose `Row` + `DcPressable` | Recognise the app | V4-CORE-01 | Jakob | App bar with logo as home link |
| Heading "Open a course from GitHub" (h1) | `Text` (`display`) | Know what this screen does | V4-CORE-01 | Cognitive load | Page title |
| Help line (what repositories work) | `Text` (`body`) | Know the address must be a public repository with course.yaml and README.md | V4-CORE-01 | Postel | Helper text under a title |
| Label "GitHub repository address" | `DcLabel` | Name the field for everyone, including screen readers | A11Y-003 | Jakob | Persistent visible label |
| Address field | `DcInput` (`autofillHints: url`, `invalid`) | Paste or type the address | V4-CORE-01, CAT-001 | Postel: accepts `github.com/o/r`, `www.`, trailing slash, `.git`, query and fragment | Single text field with inline validation |
| Inline field error | `Text` (`small`, destructive role) linked to the field | Fix an invalid address (J5a) | CAT-002, A11Y-003 | Error prevention | Inline form error under the field |
| Open course | `DcButton` primary, large, `loading` | Start the import | V4-CORE-01 | Fitts, Von Restorff | Single primary form submit; Enter submits |
| Progress text "Reading the repository" | `Text` (`small`) in a polite live region, with `DcSpinner` inside the button | Know the request is running | V4-CORE-01 | Doherty (feedback within 400 ms) | Inline progress for a short request |
| Error alert (kinds below) | `DcAlert` destructive, `announce: true` | Learn what failed and what to do (J5b, J5c, J5d) | V4-SEC-09, ERR-010, CAT-002 | Error recovery | Inline alert above the form's fold, not a dialog |
| Problems list (invalid course.yaml) | `Column` of `Text` rows (path in `code` style, message) | Give the author the exact errors (J5c) | V4-CORE-01, CAT-002 | Recognition over recall | Validation summary listing each issue with its location |
| Support reference "Reference {requestId}" | `Text` (`small`, selectable) | Quote the failure to support | V4-SEC-09, ERR-010 | Tesler | Error reference code |
| Privacy line | `Text` (`small`, muted) | Trust that no account is needed and nothing is written to GitHub | V4-CORE-01, V4-CORE-02 | Cognitive load | Short reassurance beside the task |

Content column is capped at 560 dp and left-aligned at every width (content width cap).

## 6. States

| State | What the reader sees | What they can do |
|---|---|---|
| Empty (first visit) | Heading, help line, empty field focused, Open course enabled | Type or paste an address |
| Loading | Field read-only, button shows spinner, text "Reading the repository", no layout shift. After 8 s the text becomes "Still reading. Large courses take longer." | Wait; Escape or navigating away cancels |
| Error: empty | Field invalid, message "Enter the address of a GitHub repository." | Type an address |
| Error: invalid URL (client check, no request sent) | Field invalid, message "That doesn't look like a GitHub repository address. Use the form https://github.com/owner/repository." If the host is not github.com: "Lectale opens repositories on github.com. Use the form https://github.com/owner/repository." | Edit the text, press Open course |
| Error: repository not found or private (404) | Alert, same text for missing, private and unsafe addresses | Edit the address, press Open course |
| Error: invalid or missing course.yaml (422), too large (413) | Alert plus the problems list; "Showing the first 50 problems." when `truncated` | Tell the author, or edit the address |
| Error: rate-limited (429) or GitHub limiting requests | Alert naming the wait; Open course disabled until the wait ends | Wait; the button re-enables and focus stays put |
| Error: offline or server failure (5xx) | Alert; Open course enabled | Press Open course to retry |
| Success | Navigates to Course. Focus moves to the Course title | Read |

Focus after any error returns to the field. The alert is announced once; the countdown text is not announced every second (announced at start and when it ends).

## 7. Wireframes

### Phone (360 px)

```
+--------------------------------+
| [mark] Lectale                 |  top bar
+--------------------------------+
|                                |
| Open a course from             |
| GitHub                         |
|                                |
| Any public repository with a   |
| course.yaml and README.md.     |
|                                |
| GitHub repository address      |
| [ https://github.com/...     ] |
| (inline error here)            |
| [        Open course         ] |  full-width primary
|                                |
| [! Repository not available  ] |
| [  Lectale can't open ...    ] |
| [  Reference 4f2a9c          ] |
|                                |
| No account needed. Lectale     |
| only reads the repository.     |
+--------------------------------+
```

### Tablet (768 px)

```
+----------------------------------------------------+
| [mark] Lectale                                     |
+----------------------------------------------------+
|     Open a course from GitHub                      |
|     Any public repository with a course.yaml       |
|     and README.md.                                 |
|                                                    |
|     GitHub repository address                      |
|     [ https://github.com/...  ] [ Open course ]    |
|     [! Repository not available ................ ] |
|     No account needed. Lectale only reads it.      |
+----------------------------------------------------+
   column 560 dp, left edge aligned to the heading
```

### Desktop (1440 px)

```
+------------------------------------------------------------------------------+
| [mark] Lectale                                                               |
+------------------------------------------------------------------------------+
|                                                                              |
|        Open a course from GitHub               (empty right side stays empty)|
|        Any public repository with a course.yaml and README.md.               |
|                                                                              |
|        GitHub repository address                                             |
|        [ https://github.com/...                    ] [ Open course ]        |
|        [! course.yaml can't be used ........................................ ]|
|        [  /outline/2/resources/0/path   Use a repository-relative path ...  ]|
|                                                                              |
+------------------------------------------------------------------------------+
   column 560 dp, starts about a third down; no hero, no illustration
```

## 8. Interaction and accessibility

- **Keyboard order:** skip link, brand link, address field, Open course. Alert content is not focusable; it is announced.
- **Landmarks and headings:** banner (top bar), main (everything else). One h1. Alert title is not a heading level.
- **Labels for icon-only controls:** none. The brand mark link is named "Lectale home".
- **Touch targets:** field and button at least 44 dp high (comfortable style); all at least 24x24.
- **Motion:** none beyond the spinner and the alert appearing; both are instant when the platform asks to reduce motion.
- **Text scale:** layout reflows at 200 and 400 percent; the button stays full width on phone.
- **Rules:** URL normalisation happens in the client (trim, add `https://`, strip `www.`, `.git`, trailing slash, query, fragment). Only `owner/repository` is sent. A `/tree/...` or `/blob/...` path is cut to the repository (see open questions).

## 9. Copy

| Where | Text |
|---|---|
| Title | Open a course from GitHub |
| Help | Any public repository with a course.yaml and README.md. |
| Label | GitHub repository address |
| Placeholder | https://github.com/owner/repository |
| Button | Open course |
| Progress | Reading the repository |
| Slow progress | Still reading. Large courses take longer. |
| Privacy | No account needed. Lectale only reads the repository. |
| Invalid URL, empty, host | see States |
| Not found or private, title | Repository not available |
| Not found or private, body | Lectale can't open this repository. Check the address. A private repository can't be opened here. |
| course.yaml title | course.yaml can't be used |
| course.yaml body, with problems | This repository has a course.yaml with {n} problem(s). The course author needs to fix them before it can open. |
| course.yaml body, missing file | This repository has no course.yaml at its top level. The course author needs to add one. |
| course.yaml body, 413 | course.yaml is larger than Lectale can read. The course author needs to shorten it. |
| Problem row | {message} then `{path}` (the root shows "whole file") then {code} in small text |
| Truncated | Showing the first 50 problems. |
| Rate-limited, title | Too many requests |
| Rate-limited, body | Try again in {n} seconds. |
| GitHub limiting | GitHub is limiting requests right now. Try again in {n} minutes. |
| Offline | Lectale can't be reached. Check your internet connection, then press Open course. |
| Server failure | Lectale ran into a problem. Press Open course to try again. |
| Reference | Reference {requestId} |

## 10. Images

- Brand mark: app asset, SVG compiled with `vector_graphics_compiler`, drawn with `flutter_svg`; 28 dp tall; decorative next to the wordmark (empty semantic label), the link carries the name.
- Alert icon: Lucide, vector. No illustration, photo or raster image on this screen.

## 11. Open questions

1. Which codes does the server send for 422 problems and for "GitHub is limiting requests" versus Lectale's own 429? `ApiError.details` is free-form; I assume `details.errors[]` of `{code, path, message}` and `details.truncated`. The edge engineer should confirm.
2. A missing course.yaml and a broken one share 422; I need a stable code to choose between the two bodies.
3. Pasting a `/tree/branch/path` address: the preview pins the default branch. Is cutting to the repository acceptable, or should the field refuse it?
4. Remember the last course on this device (Zeigarnik, "continue where you left off")? It adds a recent-courses row and storage; left out of M2.
5. Spec asks for owner connect and sign-in options on the not-found error. Both need M3; omitted here.
6. Where do the accessibility statement and privacy links sit (A11Y-T05, V4-SEC-10)? A footer on Home is the known place; which milestone owns the pages?
7. litse-ui lacks: app bar, skip link.
