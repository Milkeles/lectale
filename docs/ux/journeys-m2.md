# M2 user journeys

Milestone M2: a learner pastes a public GitHub repository URL and reads the course in the app, with no account. Release cases are from `spec/v4.0/docs/RELEASE_TESTS_V4.md`; acceptance IDs (CAT, README, A11Y, ERR) from the spec documents named in each row. PDF, notebook and audio viewers and the in-app video player are M2b: in M2 those kinds show a file card or a link card (`screens/reader.md`). Folders list their entries in M2.

Actor: a learner of any discipline, signed out, on any of the six platforms. Nothing is written to GitHub, nothing is registered, no catalog is queried (V4-CORE-02).

## Routes the screens call

From `spec/errata/openapi.yaml` at d766458. All are under `/api`.

| Route | Returns | Used for |
|---|---|---|
| `POST /courses/import` | `CoursePreview` (`repoId`, `sha`, `outline`, `readmePresent`) | Home: open a course from its address |
| `GET /preview/{repoId}/{sha}` | the same `CoursePreview` | Course and Reader after a reload, a bookmark, a shared link or a restored tab (J3a) |
| `GET /preview/{repoId}/{sha}/readme` | root README as Markdown | Course overview |
| `GET` `OutlineResource.href` (`.../content/{lessonId}/{resourceId}`) | the resource's bytes | Reader viewers and Download |
| `GET` `OutlineResource.href` for a `folder` (`.../folders/{lessonId}/{resourceId}`) | `PreviewFolder.entries[]`: `name`, `type` (`file` or `directory`), `size`, `href`; direct entries only, at most `maxEntries` (default 100) | Reader folder list |
| `GET /preview/{repoId}/{sha}/files/{path}` | any regular file at the pinned commit, same safe-MIME and download rules as content | README images and relative links, the course cover, folder entries |

The client uses `href` values as returned (ADR-0008, ADR-0011). It builds a files-route address in one case only: a path from the README or `course.cover`, resolved against the repository root, with `./` and `../` collapsed; a path that would leave the root, or that fails the route's path pattern, is not requested.

## Journeys

| ID | Journey | Release cases | Start | Success looks like | Screens |
|---|---|---|---|---|---|
| J1 | Open a course by URL | V4-CORE-01, V4-CORE-02, CAT-001, CAT-008 | Learner has a repository address in any common form: with or without `https://` or `http://`, `www.`, trailing slash, `.git`, a `/tree/...` path, or the clone form `git@github.com:owner/repo.git` | The course screen shows its title and summary within a few seconds, with no sign-in and no catalog step | home, course |
| J2 | Read the overview | V4-CORE-01, V4-CORE-05, V4-SEC-03, README-001, README-003, README-005, N5 | Course screen is open | The root README at the pinned commit reads as a page: headings, tables, code, LaTeX and the repository's own images. No script runs. Images from other hosts wait for a tap. Anything left out says so | course |
| J3 | Move through lessons | V4-CORE-01, A11Y-001, A11Y-007 | Learner chooses Start course or a lesson in Contents | Lessons open in outline order. Next and Previous follow the outline across modules and say whether they go to a file or a lesson. The current place is marked in Contents, on phone too. The last lesson ends calmly | course, reader |
| J3a | Reload or reopen a link | V4-CORE-01 | A refresh, a bookmark, a link from another learner, a restored tab | The same course, lesson and file open again at the pinned commit from the link alone; no address is retyped | course, reader |
| J4 | Open a resource | V4-CORE-05 (preview part), V4-SEC-03, README-005, A11Y-007, N5 | A lesson or assignment is open | Markdown, text, code and images show in the app. A folder lists its entries, each downloadable. A kind with no viewer yet shows a file card with a working Download. A YouTube or Vimeo video opens on the provider's page after a tap. Nothing is silently hidden | reader |
| J5 | Recover from errors | V4-CORE-01, V4-CORE-02, V4-SEC-03, V4-SEC-09, CAT-002, ERR-010 | Something fails | The learner is told what failed and what to do next, with a support reference whenever the server answered | home, course, reader |
| J5a | Invalid URL | CAT-002 | Text that is not a GitHub repository address, or a server 400 `invalid_url` | Inline message names the expected form | home |
| J5b | Repository not found or private | V4-CORE-01, V4-SEC-03 | Server answers 404 for a missing, private or unsafe address | One privacy-neutral message, identical for all three causes | home, course, reader |
| J5c | Invalid or missing course.yaml | CAT-002, V4-CORE-04 | Server answers 422 or 413 | The exact errors from the validator, each with its location and message | home |
| J5d | Rate-limited, offline or server failure | V4-CAT-05 (explicit network error, never a blank page), ERR-004 | 429, 5xx, a timeout, or no connection | Message says what is happening and what to do. Try again appears only when trying again can help | home, course, reader |
| J5e | A resource or the README fails | README-002, ERR-007, ERR-010 | One file is missing, too large or unreachable | The failure stays inside that resource; the rest of the course keeps working; Try again is offered when retrying can help | course, reader |

## J5 error table

All three screens use this one table, so their copy cannot drift (design review S1). Codes are the Worker's at d766458 (`preview/errors.ts`, `pinned.ts`, `routes.ts`). A row is chosen by `code`, then by status. "Reference" shows `requestId` as "Reference {requestId}".

| Situation | Code, status | Try again? | Title | Body | Reference |
|---|---|---|---|---|---|
| No response (offline, DNS, connection lost) | none | Yes | Lectale can't be reached | Check your internet connection, then try again. | No: none exists |
| No answer within 30 s | none (client timeout) | Yes | Lectale is taking too long | The request didn't finish. Try again in a moment. | No |
| Address rejected | `invalid_url`, 400 | n/a | field message (Home) | see `screens/home.md` | No |
| Course missing, private or unsafe | `course_not_found`, 404, `retryable` false | No | Home: Repository not available. Course, Reader: Course not available | Home: see `screens/home.md`. Course, Reader: Lectale can't open this course from this link. Enter its GitHub address to open the latest version. | Yes |
| One file missing (README, resource, folder, image) | `course_not_found`, 404 on a file route | No | This file isn't available | Reader: Go on to the next item, or open the course again from its GitHub address. README: The overview can't be shown. Use Contents to start. | Yes |
| course.yaml missing, invalid, too large | `manifest_missing` 422, `invalid_manifest` 422, `manifest_too_large` 413 | No | course.yaml can't be used | see `screens/home.md` | Yes |
| Rate-limited | `rate_limited`, 429, `retryAfterSeconds` | Yes, when the wait ends | Too many requests | Try again in {n} seconds. / Try again in {n} minutes. / Try again in a minute. | Yes |
| GitHub not answering or repository not confirmed | `github_unavailable` 502, `repository_changed` 503 | Yes | GitHub isn't answering | Lectale couldn't get this course from GitHub. Try again in a moment. | Yes |
| Any other answer | other 4xx or 5xx | Only if `retryable` | Lectale ran into a problem | Try again in a moment. If it keeps happening, quote the reference. | Yes |

Rules:

- Try again is shown only when `retryable` is true or no response arrived. On Home the retry is the Open course button itself; on Course and Reader it is a "Try again" button inside the failed region.
- The offline copy is used only when no response arrived. Every server answer shows its reference.
- Waits under 60 s read in seconds; longer waits round up to whole minutes; no `retryAfterSeconds` reads "Try again in a minute." The button stays disabled until the wait ends. The wait is announced when it starts and when it ends, not every second.
- A not-found on Course or Reader never re-imports by itself: a re-import pins the current commit, which may differ from the link. The learner chooses it with "Enter the GitHub address", which opens Home.

## Notes

- J1 to J4 are one continuous flow. The route carries `repoId`, `sha`, the lesson and the file, so a reload or a shared link reopens the same place (J3a), and a browser bookmark works as a bookmark.
- "Continue reading" (one entry on Home that restores the last file and scroll position) is not in M2. It needs the device to store a reading position. `spec/v4.0/docs/EU_PRIVACY_COOKIES.md` COOKIE-002 blocks any non-essential local storage until the learner gives granular prior permission, with withdrawal from persistent cookie settings; CT-001 says a new visitor receives no optional storage. A reading position is a convenience, not strictly necessary for the service the learner asked for, and M2 has no consent control. `SESSION_SECURITY.md` only forbids tokens and private URLs in storage, so it neither allows nor blocks this. Full reasoning: `inventory.md`, Review decisions D11.
- Within one visit the last-opened lesson is kept in memory only (not in local or session storage). It drives the ribbon on Course and the "Continue: {lesson title}" label on Start course.
- J5 is not a separate screen. Each screen owns the error states of the request it makes (rule: every state is designed, `screen-spec` skill).
