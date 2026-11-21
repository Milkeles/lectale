# M2 user journeys

Milestone M2: a learner pastes a public GitHub repository URL and reads the course in the app, with no account. Release cases are from `spec/v4.0/docs/RELEASE_TESTS_V4.md`; acceptance IDs (CAT, README, A11Y, ERR) from the spec documents named in each row. PDF, notebook, video, audio and folder viewers are M2b: in M2 those kinds show the file card (see `screens/reader.md`).

Actor: a learner of any discipline, signed out, on any of the six platforms. Nothing is written to GitHub, nothing is registered, no catalog is queried (V4-CORE-02).

| ID | Journey | Release cases | Start | Success looks like | Screens |
|---|---|---|---|---|---|
| J1 | Open a course by URL | V4-CORE-01, V4-CORE-02, CAT-001, CAT-008 | Learner has a repository address (any common form: with or without `https://`, trailing slash, `.git`) | The course screen shows its title and description within a few seconds, with no sign-in and no catalog step | home, course |
| J2 | Read the description | V4-CORE-01, V4-CORE-05, V4-SEC-03, README-001, README-003, README-005, N5 | Course screen is open | The root README at the pinned commit reads as a page: headings, tables, code, LaTeX, images. No script runs; external images wait for a tap | course |
| J3 | Move through lessons | V4-CORE-01, A11Y-001, A11Y-007 | Learner chooses Start course or a lesson in the contents | Lessons open in outline order; Next and Previous follow the outline across modules; the current place is always marked; the last lesson ends calmly | course, reader |
| J4 | Open a resource | V4-CORE-05 (preview part), V4-SEC-03, README-005, A11Y-007, N5 | A lesson or assignment is open | Markdown, text, code and images show in the app. A file with no viewer in this version shows a file card with name, type, size and a Download action. Nothing is silently hidden | reader |
| J5 | Recover from errors | V4-CORE-01, V4-CORE-02, V4-SEC-03, V4-SEC-09, CAT-002, ERR-010 | Something fails | The learner is told what failed and what to do next, with a support reference where the server gave one | home, course, reader |
| J5a | Invalid URL | CAT-002 | Learner submits text that is not a GitHub repository address | Inline message names the expected form; no request is sent | home |
| J5b | Repository not found or private | V4-CORE-01, V4-SEC-03 | Server answers 404 for a missing, private or unsafe address | One privacy-neutral message, identical for all three causes | home |
| J5c | Invalid or missing course.yaml | CAT-002, V4-CORE-04 | Server answers 422 (or 413) | The exact errors from the validator, each with its path and message, so the author can fix them | home |
| J5d | Rate-limited or offline | V4-CAT-05 (explicit network error, never a blank page), ERR-004 | Server answers 429 or 5xx, GitHub is limiting requests, or the device has no connection | Message says what is happening and when to retry; the same button retries | home, course, reader |
| J5e | A resource or the README fails | README-002, ERR-007, ERR-010 | Single file is missing, too large or unreachable | The failure stays inside that resource; the rest of the course keeps working; Retry is offered | course, reader |

## Notes

- J1 to J4 are one continuous flow. A learner who closes the app starts again at J1; M2 keeps no account state. Remembering the last course on the device is an open question (`screens/home.md`).
- J5 is not a separate screen. Each screen owns the error states of the request it makes (rule: every state is designed, `screen-spec` skill).
