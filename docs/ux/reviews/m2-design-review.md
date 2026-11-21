# M2 design review: journeys, inventory, token plan, Home, Course, Reader

| | |
|---|---|
| **Stage** | Spec review before code (`docs/ux/README.md` step 4). No screenshots exist yet. |
| **Reviewer** | design-reviewer |
| **Date** | 2026-11-21 |
| **Files** | `docs/ux/journeys-m2.md`, `inventory.md`, `token-plan.md`, `screens/home.md`, `screens/course.md`, `screens/reader.md` |
| **Checked against** | `screen-spec` skill (rules, UX laws, anti-patterns), `references/ai-tells.md`, `frontend-design` skill |
| **Cross-checked with** | `spec/errata/openapi.yaml`; the Worker draft in `apps/edge_api/src/preview/` (uncommitted, so its codes may still change); `RENDERING_REQUIREMENTS.md`, `WCAG_ACCESSIBILITY.md`, `ERROR_FAILURE_SEMANTICS.md`; litse-ui sources in `litse-ui-private/lib/src/`; contrast computed from the token seeds; line length measured from a local IBM Plex Serif Regular |

## Verdict: revise

The structure is sound. Each of the three screens has one purpose and one primary action. The specs use known patterns: list-detail, supporting pane, table of contents, previous and next. Errors stay on the screen that owns the request. Home's not-found message is the same for missing, private and unsafe addresses. The token plan avoids the default looks, and the ribbon is a good choice for the one memorable element. All cited litse-ui components and parameters exist (`DcAlert.announce`, `DcInput.invalid`/`autofillHints`, `DcButton.loading`, `DcButton.icon(semanticLabel:)`, `DcTypography.reading`). The spinner, skeleton and tabs honour `disableAnimations`.

Six things block the build:

1. Two journeys have dead ends: a reload or deep link leaves the learner stranded, and some file cards have no working action.
2. The contract gives README images and relative links nothing to load.
3. Reader up-navigation has a breadcrumb item that goes nowhere, and a control name that fails WCAG 2.5.3.
4. The contents list moves sides between screens and does not mark the current place where J3 requires.
5. README headings are smaller than the body text.

The must-fix items below cover these as M1 to M6. M1 and M3 are the two dead ends.

---

## Must-fix

### M1. A reload, shared link or reopened tab is a dead end

- **Where:** `screens/course.md` §6 "Error: opened by link, outline not in memory" and §11 Q1; `screens/reader.md` §6 (same state); `inventory.md` Routes.
- **Problem:**
  - The outline lives only in memory. On Flutter web, a browser refresh, a bookmark, a shared link or a restored tab lands on "Open this course again. The link needs the repository address." So J3 breaks on every refresh.
  - The recovery button is labelled "Open course", but here it only navigates to an empty Home. On Home the same label submits the import, so one name means two different actions.
  - The learner has to remember and retype the address. The copy describes the system ("the link needs the repository address") rather than the next step.
- **Change:**
  - Resolve Q1 before build. The preferred fix is `GET /preview/{repoId}/{sha}/outline`. The Worker already caches the pinned preview under `public-course-outline:v1:{repoId}:{sha}` (`routes.ts`, `pinnedKey`), so the route is a cache read plus the same visibility check. Design its states:
    - loading: skeleton header and contents;
    - not found: the same privacy-neutral copy as Home;
    - the other errors as in S1.
  - If the route is refused, use this interim fix:
    - Keep the last `CoursePreview` in session storage, keyed by `repoId` and `sha`.
    - Carry `owner/repo` in the route as a query parameter, so the fallback can re-import by itself or prefill the Home field. Note that a re-import pins the current head, which may differ from the link's commit.
    - Label the fallback button "Enter the GitHub address" and give it a prefilled field, so "Open course" keeps one meaning.

### M2. README images and relative links have nothing to load

- **Where:** `screens/course.md` §5 (README image rows) and §10 "README image, relative path in the repository"; `screens/reader.md` §5 Markdown viewer and §10 "Images inside Markdown".
- **Problem:**
  - Course §10 says repository images load through a "Preview route `OutlineResource`-style href". No such route exists. The contract has only `/preview/{repoId}/{sha}/readme` and `/preview/{repoId}/{sha}/content/{lessonId}/{resourceId}`. The Worker draft indexes only `README.md` and manifest resources (`indexFiles` in `pinned.ts`). So every relative image in a README or Markdown lesson fails, and J2 ("images") cannot be met.
  - Relative links, such as `[Lesson 2](lessons/02.md)`, are common in course READMEs. `OutlineResource` carries no path, so the client cannot map such a link to a resource, and neither spec says what tapping one does. A link that does nothing is a dead control.
- **Change:**
  - **(a)** Take this to the contract and edge engineers. The options are a scoped route for raster images referenced by README or Markdown at the pinned commit (validated regular files only), or an explicit M2 decision that they don't load.
  - **(b)** Design each case in Course §5/§6 and Reader §5/§6:

    | Case | Behaviour |
    |---|---|
    | Relative image with no route | A box with the alt text and filename and "This image can't be shown in this version". Never a broken-image glyph. |
    | `#anchor` | Scrolls within the page. |
    | Relative link that matches an outline resource | Opens it in the Reader. This needs a `path` on `OutlineResource` or a map resolved on the server. |
    | Any other relative link | Plain text with the target in small text, not a dead link. |
    | `https` link | Opens the browser. The accessible name says "opens in your browser", as for author links. |

### M3. File cards that offer no way to get the file, or a Download that cannot work

- **Where:** `screens/reader.md`, the note under the §5 table, the §5 File card and Link card rows, and §9 "File card, downloads off"; `journeys-m2.md` J4.
- **Problem:** there are three cases.
  1. **A kind with no viewer and `download: false`.** The card says "The course author turned off downloads for this file." and offers nothing. That is a dead end. It also contradicts `RENDERING_REQUIREMENTS.md`, which says a resource that can't be previewed "must show an in-app metadata card with a Download action and clear reason", and that "`download: false` is a UI preference, not access control".
  2. **`folder`.** The card offers Download, but a folder is not a regular file. The Worker draft never indexes it, so the request returns 404.
  3. **YouTube and Vimeo.** The outline mapper (`toResource` in `outline.ts`) sets `embedUrl` and leaves `href` null and `url` empty. As specified, neither the file card (its Download needs `href`) nor the link card (it needs `url`) has a working action.

  The sample fixture `spec/v4.0/examples/complete.course.yaml` opens with a lesson holding a PDF, a YouTube video and a folder, so Start course on it reaches all three cards.
- **Change:** add a card table to Reader §5, mapping kind × `href`/`url`/`embedUrl` × `download` to the card's text and action. Rules:
  - A kind with no viewer always offers Download. `download: false` only hides the header Download when a viewer works.
  - A `folder` in M2 gets a card saying "Folders open in a later version." with no Download. If the edge can return the folder path, add an "Open on GitHub" link card.
  - A video from an embed provider in M2 gets a link card that opens the provider's watch page, built from `embedUrl`, with the text "Opens youtube.com in your browser."
  - Never draw a button whose request is known to fail.

### M4. Reader up-navigation: a breadcrumb item with no destination, and a name that fails WCAG 2.5.3

- **Where:** `screens/reader.md` §5 Breadcrumb and Back control rows, §7 Desktop, §8 Labels and §9 Back control; `inventory.md` Patterns, Breadcrumb row; `token-plan.md`, the "Dense header chrome" row.
- **Problem:**
  - **(1)** The breadcrumb "Course / Module / Lesson" is built from `DcButton` links. There is no module screen, so the Module item has nowhere to go. The Lesson item is the current page. The wireframe shows the literal word "Course" where the course title belongs.
  - **(2)** The back control shows the course title, but its accessible name is "Back to course contents", which does not contain the visible text. This fails WCAG 2.2 2.5.3 Label in Name (level A). A speech user who says "click Introduction to Statistics" gets nothing.
  - **(3)** At 1440 the breadcrumb sits in the top bar, which breaks the token plan's rule "Top bar has the brand link and nothing else".
- **Change:**
  - Make the breadcrumb `{course title}` (a link to Course), then `{module title}` (plain text), then `{lesson title}` (plain text with `current` semantics).
  - Place it in main, above the h1, not in the top bar.
  - Give the back control the accessible name "Back to {course title} contents".
  - Name the breadcrumb `nav` "Breadcrumb", the usual landmark name, instead of "You are here".

### M5. The contents list moves sides, and the current place is not marked where J3 needs it

- **Where:** `screens/course.md` §5 Contents rows and §7 Desktop; `screens/reader.md` §7 Phone and Desktop; `token-plan.md` "The memorable element"; `journeys-m2.md` J3 ("the current place is always marked").
- **Problem:**
  - At 840 px and wider, Contents sits right of the README on Course (supporting pane) but left of the resource on Reader (list-detail). The list the learner just clicked jumps across the window when the lesson opens.
  - Course gives its contents no current-row marker. After the learner comes back from the Reader, by the back control or "Back to course", their place is gone.
  - Below 840 the Reader shows no position in the course at all.
  - So the ribbon, the one memorable element, appears only on the Reader at 840 px and wider, although the audience is "often on a phone".
- **Change:**
  - Put Contents on the start side (left) on both screens at 840 px and wider, so Course reads Contents | README, like the Reader.
  - On Course, mark this session's last-opened lesson with the ribbon and scroll it into view. Below 840, select the Contents tab when the learner arrives from the Reader.
  - Once a lesson has been opened this session, Start course reads "Continue: {lesson title}". It is still the one primary action.
  - Below 840 on the Reader, show the module title under the back control in small plain text.

### M6. README headings are smaller than the text under them

- **Where:** `token-plan.md` Type table, plus the "Reading-oriented DcStyle" section.
- **Problem:**
  - README h1 maps to `heading` (21.5), but h3 and h4 map to `title` (17) and `subtitle` (15). Both sit under 18 px reading text, so the hierarchy inverts in every README and Markdown lesson.
  - h2 (after the shift), h5 and h6 have no mapping.
  - The Reader has a lesson h1 and a resource h2 above the content, but no shift is defined for Markdown headings there.
  - At visual review this would be type-scale drift, which is a hard stop.
- **Change:** write one map from rendered heading level to size, used by both screens, with these rules:
  1. No heading inside reading content is smaller than the 18 px reading size. h4 to h6 are 18 semibold Sans, told apart by weight and the space above them.
  2. No heading inside content is larger than the page h1.
  3. Course shifts README headings by one level. Reader shifts Markdown headings by two (h1 becomes h3).

  For example: h2 21.5 (`heading`), h3 19.5 semibold, h4 to h6 18 semibold. Keep `title` and `subtitle` for UI text only (module headings, card titles).

---

## Should-fix (in priority order)

### S1. Retry, reference and cause differ across the three screens

- **Where:** `screens/home.md` §6 and §9; `screens/course.md` §6; `screens/reader.md` §6 and §9; `journeys-m2.md` J5d and J5e.
- **Problem:**
  - **Try again on failures that can't clear.** Course shows it for a README 404 and Reader for a resource 404. For `course_not_found`, `ApiError.retryable` is false.
  - **Wrong advice for server failures.** Home separates offline from server failure correctly. Course puts 5xx under the 404 copy. Reader puts both offline and 5xx under "Check your internet connection", which is wrong advice when the server did answer.
  - **Missing support references.** ERR-010 asks for a reference "for every failure". It is missing from every rate-limit state and from Course's offline state. Offline has no `requestId` because no response arrived. Everything the server answered has one.
  - **Reader 404 copy.** "It may have been moved or removed from the course." cannot be true at a pinned commit. The same 404 also covers a repository made private.
- **Change:**
  - Write one error table for all three screens, keyed by `code` and `retryable`, as a section in `journeys-m2.md` J5 that each spec references.
  - Show Try again only when `retryable` is true or no response arrived.
  - Show the reference on every error the server answered.
  - Use the offline copy only when no response arrived.
  - Reader 404: "This file isn't available. Go on to the next item, or open the course again from its GitHub address."
  - In J5e, change "Retry is offered" to "Retry is offered when retrying can help".

### S2. Home: missing states, no visible way out of loading, a narrow Postel's Law, and a long announcement

- **Where:** `screens/home.md` §6, §8 (Rules) and §9.
- **Problem:**
  - **(1) Server 400.** The server can return 400 `invalid_url` (client and server rules can drift). There is no state for it.
  - **(2) Truncated tree.** For very large repositories the server returns 502 `repository_tree_truncated`, which is not retryable. Home would show "Press Open course to try again", which can never succeed.
  - **(3) Rate limit.** The Worker draft sends one code, `rate_limited`, for both of Home's cases, with `retryAfterSeconds` defaulting to 60. So the spec cannot choose between its two copies (seconds, or "GitHub … minutes"). There is no copy for when no delay is given.
  - **(4) Loading.** There is no timeout after "Still reading". The field is read-only during loading, and the only cancel is Escape, so touch users have no way out.
  - **(5) Address forms.** Postel's Law: the clone form `git@github.com:owner/repo.git` and `http://` addresses are not accepted.
  - **(6) Long announcement.** The 422 alert uses `announce: true`. With up to 50 problems, a screen reader reads the whole list.
  - **(7) Focus.** The rate-limit row says focus "stays put", but the rule under the table says it returns to the field.
- **Change:**
  - Map the server's 400 to the inline field error.
  - For `repository_tree_truncated`, add "This repository has too many files for Lectale to read. The course author needs to make it smaller.", with no retry.
  - Write one rate-limit message from `retryAfterSeconds`, formatted as "Try again in 40 seconds" or "Try again in 2 minutes". Use "Try again in a minute." when no delay is given.
  - Answer Q2 with the draft's codes: `manifest_missing` and `invalid_manifest` (422), `manifest_too_large` (413).
  - Keep the field editable during loading. Editing it, or pressing Open course again, cancels the request. At 30 s, show the server-failure state.
  - Normalise SSH and `http://` addresses.
  - Announce only the alert title and the count, for example "course.yaml can't be used. 3 problems." Leave the list in reading order.
  - One focus rule: focus goes to the field.

### S3. Home's help line says README.md is required, and two lines do the job of one

- **Where:** `screens/home.md` §4 item 3, the §5 Help line and Privacy line rows, and §9.
- **Problem:**
  - The help line says "Any public repository with a course.yaml and README.md." But Course designs a state for `readmePresent: false`, so a repository without a README does open.
  - §4 asks for "one line". The help line under the title and the privacy line at the bottom split that one job across two elements.
- **Change:** use one line under the heading: "Any public GitHub repository with a course.yaml file. No account needed; Lectale only reads it." Remove the separate privacy element.

### S4. Course header: order, placement and cuts

- **Where:** `screens/course.md` §4, the §5 Facts and Tags rows, §7 Phone and Desktop, §8 Keyboard order, and §9.
- **Problem:**
  - **Reading order.** §4 ranks title, summary and Start course first and facts fourth. But the phone wireframe puts facts and tags between the summary and Start course.
  - **Keyboard order.** Author links come before Start course.
  - **Placement at 1440.** Start course sits at the far right of the header row, away from the line the eye reads along.
  - **Tags.** They serve no task in M2: there is no catalog to filter by, and they link nowhere. The overflow reads "+n" in §5 and §7 but "+{n} more" in §9.
  - **Version.** It serves no learner task.
  - **Facts layout.** §5 says the facts are a definition list, but §7 draws them as one line joined by commas. That is the middle-dot meta string with a different separator (`ai-tells.md`, Copy).
- **Change:**
  - At every width, order the header as title, summary, Start course, then facts. Put the facts below the button.
  - At 1440, left-align Start course with the title.
  - In keyboard order, put Start course before author links.
  - Remove tags and version from M2.
  - Show facts as labelled pairs, as §5 says, with label words from the copywriter.

### S5. Course empty states leave a primary action that can never act

- **Where:** `screens/course.md` §6, the "Empty: outline has no lessons" and "Empty: no README" rows.
- **Problem:**
  - With no lessons, Start course stays on screen, disabled for good.
  - "This course has no lessons yet." does not name a next action, which the skill's rule 4 requires.
  - With no README, the About tab holds only a notice, so the learner has to switch tabs to reach the one real piece of content.
- **Change:**
  - **No lessons:** remove Start course. Use the copy "This course has no lessons yet. Open another course.", with "Open another course" as a link to Home.
  - **No README:** below 840, drop the tabs. Show Contents under the header, with the notice as one line above it.

### S6. The same thing goes by different names

- **Where:** `screens/course.md` §5 Tabs, §6 and §9 (including "External image note"); `screens/reader.md` §2 and §9.
- **Problem:**
  - The tab is called "About", but every message about its content says "description".
  - "Back to course" (end of course) and "Back to course contents" (the back control) go to the same screen under two names. Neither spec says which tab "Back to course" lands on.
  - "Open course" has two meanings (see M1).
  - "Loading contacts {host}, which can see your address." On Home, "address" means the repository address.
- **Change:**
  - Name the tab "Description".
  - Use "Back to course" for both controls. Both land on the Contents tab below 840, with the last-opened row marked (M5).
  - Change the external image note to "Loading it contacts {host}, which will see your IP address."

### S7. Reader: Download appears twice, and the lesson's file list takes two forms

- **Where:** `screens/reader.md` §5 (Download, In-this-lesson and File card rows), §6 (image fails to decode) and §7 (all widths); `token-plan.md`, the Mist row and the ribbon section.
- **Problem:**
  - When a file card shows, or an image fails to decode, the header Download and the card's Download are two controls for one action.
  - "In this lesson" takes two forms:
    - On phone it is a vertical list marked with the ribbon.
    - At 768 and 1440 it is one inline row joined by pipes ("data.md | survey.csv"). That pipe-joined string is a meta-string tell.
  - Using the ribbon here puts two ribbons on screen at 1440 and breaks the rule that it appears "only in the contents list".
  - The token plan marks selected rows with Mist. Mist on Birch is 1.11:1, below the 3:1 that WCAG 1.4.11 and A11Y-002 ask of an essential indicator.
- **Change:**
  - Hide the header Download whenever a card or the decode-error box offers Download.
  - Show "In this lesson" as a list of rows at every width.
  - Mark the selected row with Mist fill plus a cue that is not colour (a semibold title), and give it `selected` semantics.
  - Keep the ribbon in the contents list only.

### S8. Reader: Previous and Next at 360 px and with large text

- **Where:** `screens/reader.md` §5 Previous and Next rows, §7 Phone, §8 and §9.
- **Problem:**
  - Two buttons side by side, each carrying a title ("Previous: {title}", "Next: {title}"), do not fit at 360 px or at 200 to 400 percent text. The phone wireframe already drops the title from Previous.
  - The spec leaves these open:
    - Previous on the first item.
    - What Next names when it crosses into a new lesson. As specified, it names the next resource, not the lesson.
    - Where focus goes after Next or Previous.
    - Whether Next and Previous add history entries. Under Jakob's Law, system back should leave the Reader, not replay 30 resources.
- **Change:**
  - Below 600 px, stack the buttons: Next full width first, Previous below it as a ghost button. Titles wrap and never truncate.
  - Show no Previous on the first item.
  - When Next crosses into a new lesson, label it "Next lesson: {lesson title}".
  - After Next or Previous, move focus to the new h2 (the h1 if the lesson changed) and reset the scroll.
  - A lesson change pushes a history entry. A resource change within a lesson replaces it.

### S9. Keyboard and scroll behaviour of the contents list

- **Where:** `screens/course.md` §8 Keyboard order; `screens/reader.md` §8 Keyboard order.
- **Problem:**
  - Every contents row is its own tab stop. With a 60-row outline at 840 px and wider, that is 60 Tab presses before the Reader's main content. The skip link only helps from the top.
  - The Reader pane does not keep the current row in view when Next moves to a lesson further down.
- **Change:**
  - Make the outline one tab stop on both screens, with arrow keys to move, Home and End, and Enter to open (roving focus).
  - On a lesson change, scroll the ribbon row into view. The scroll is instant under reduce-motion.

### S10. Type and line length in the token plan

- **Where:** `token-plan.md` Type (table and the Measure bullet) and "Reading-oriented DcStyle"; `screens/reader.md` §5 Text viewer, §7 Phone and §8 Text.
- **Problem:**
  - **Line length.** On English prose, Plex Serif averages 0.474 em per character (measured from the font's advance widths). At 18 px a 640 dp column holds about 75 characters, not 64 to 70. The skill asks for 60 to 70.
  - **Text files.** The Type table lists "text" under Reading (Serif) and "text viewers" under Code (Mono), and Reader §5 uses `code`. The Worker serves CSV and JSON as text, and wrapping them breaks their rows.
  - **Reading size.** The Reader phone wireframe says 17 px. The token plan and Reader §8 say 18.
  - **Line height.** "18 (30), 1.65" does not add up: 30/18 is 1.67.
  - **Dark-mode weight.** The style subtracts 50 from weights in dark mode. litse-ui's Plex Sans is a variable font, so that works for UI text. Plex Serif is proposed as static regular, italic and semibold files, so 350 and 550 snap to the nearest file and the offset does nothing for reading text. Markdown bold italic needs a semibold italic file, which is not in the proposed set.
  - **Scripts.**
    - `fc-query` on a local Plex Serif Regular lists Cyrillic, including the `bg` set, but no Greek: U+03BC and U+03C3 are missing.
    - litse-ui's Plex Sans has Greek.
    - Statistics and physics prose uses μ and σ.
    - The plan asks for "fontFamilyFallback for Cyrillic and Greek" but names no fallback.
- **Change:**
  - Cap the reading line at about 580 dp at 18 px (about 68 characters), or at 32 em so the line length holds when text scales.
  - Text viewer: prose `.txt` in the Reading style, wrapped. CSV, TSV, JSON and logs in the Code style, unwrapped, with horizontal scroll.
  - Fix the phone wireframe to 18 px.
  - State the line height one way.
  - Add semibold italic to the bundle. Either drop the dark offset for the Serif slot or bundle a 450 weight.
  - Name the Greek fallback: Plex Sans is already bundled; check how it mixes with Serif in a μ/σ sentence. Drop Cyrillic from the fallback list.
  - The `bg` charset check does not cover Bulgarian localised letterforms. Check those separately.

### S11. README content that disappears without a trace, and noisy image placeholders

- **Where:** `screens/course.md` §5 ("raw HTML, scripts, iframes" and "External image gate" rows) and §10 (SVG and `data:` rows); `journeys-m2.md` J2 and J4 ("Nothing is silently hidden").
- **Problem:**
  - GitHub READMEs often use raw HTML for figures (`<img src="images/fig.png" width=…>`), `<details>`, `<br>` and `<sub>`. Dropping all raw HTML silently removes figures and text.
  - A badge row at the top of a README, for example five shields.io SVGs, would open the description with five placeholder boxes, either "Not shown for safety" or "Load image from img.shields.io".
  - A formula that fails to parse has no designed state.
  - The raw HTML row is not a visible element.
- **Change:**
  - Sanitise rather than drop. Render a safe subset:
    - `img` handled exactly like a Markdown image;
    - `details` and `summary`;
    - `br`, `sub`, `sup` and `kbd`.

    For anything else, show its text content. Where an element is removed, show one line: "Part of this description can't be shown here."
  - Group consecutive gated images into one placeholder per host per block, for example "3 images from img.shields.io" with one Load button. Group blocked SVGs into one line: "2 SVG images aren't shown, for safety."
  - When a formula fails to parse, show its source in the `code` style, with the plain-text label.
  - Move the raw HTML row out of the element table into a Rules note.

### S12. The outline carries no file sizes

- **Where:** `screens/reader.md` §5 (In-this-lesson, Resource heading meta and File card rows), the note on text over 512 KB, and §11 Q1; `screens/course.md` §5 Lesson row.
- **Problem:** the Worker draft's mapper (`toResource`) never sets `sizeBytes`, although the pinned tree it reads holds sizes (`PinnedFile.size`). So these can't work from the outline:
  - sizes in lists;
  - the file card's size;
  - the 512 KB switch to a file card.

  A11Y-007 requires an accessible file size in resource lists.
- **Change:**
  - Ask the edge engineer to fill `sizeBytes` from the tree.
  - Until then, the specs say size is shown only when known. The 512 KB rule reads `Content-Length` before reading the body.

### S13. Icons that no element row asks for

- **Where:** `screens/reader.md` §10 "Resource kind icons in lists"; `screens/course.md` §10 "Alert and row icons"; `token-plan.md`, pre-ship check 1.
- **Problem:**
  - The Images tables add kind icons to list rows. No element row lists them, and the text kind label next to them already says the same thing. They are decoration with no task.
  - The token plan's "remove one decoration" check removes facts icons, which the Course spec never had.
- **Change:** remove row and kind icons from lists. Keep icons in alerts and on controls only. Record this as the pre-ship removal.

### S14. The top bar differs between screens

- **Where:** `screens/home.md` §7 and §10; `screens/course.md` §7 and §8 Labels; `screens/reader.md` §7.
- **Problem:**
  - Home shows the mark and the wordmark. The Course and Reader wireframes show the mark alone, which makes it an icon-only link, while Course §8 says there are none.
  - On Home, the brand link points to the page it is on.
- **Change:**
  - Use the same bar on all three screens: mark plus the wordmark "Lectale", as a link named "Lectale home".
  - On Home, render it either as plain text or with `current` semantics.

### S15. Image viewer cites the wrong requirement, and its zoom buttons show no text

- **Where:** `screens/reader.md` §5 Image viewer row and §8 Labels.
- **Problem:**
  - The row cites A11Y-005, which is the PDF requirement.
  - The three zoom buttons are icon-only, but the token plan says icons always come with text.
- **Change:**
  - Cite `RENDERING_REQUIREMENTS.md` (Images: zoom, alternative text) and A11Y-002.
  - Give each zoom button a `DcTooltip` (litse-ui has one) with the same text as its semantic label.

---

## Consider

- **C1. Identity** (`token-plan.md` Colour, Type)
  - Plex Sans with a cobalt primary on a cool grey sits close to IBM Carbon's default look. The ribbon and the serif reading face are what make the app Lectale, so keep both visible on phone (M5).
  - Brick is the stock `DcPalettes.red`. Tune it to sit with Birch and Cobalt, then check it on dark Birch.
- **C2. Cobalt roles** (`token-plan.md` Colour, Motion)
  - Cobalt also colours the focus ring (`ring`), so it has four jobs, not "exactly three".
  - Focus changes animate over 170 ms. Make them instant.
- **C3. Half pixels** (`token-plan.md` Spacing). The 4.5 unit gives 4.5 and 13.5 dp steps, which put borders on half pixels on 1x web screens. Snap edges to whole device pixels.
- **C4. Merge the two lists** (`screens/reader.md` §5). At 840 px and wider, show the current lesson's resources nested under its row in the contents pane, as e-readers do, and drop the separate "In this lesson" list there. The resource then becomes the first thing in the reading pane. Keep the list below 840.
- **C5. Lesson row count** (`screens/course.md` §5). "{n} files" is wrong when a lesson holds links or videos. Count "items", or drop the count.
- **C6. Assignment dates** (`screens/course.md` §7, `screens/reader.md` §9). "Due 3 Dec 2026" drops the time and time zone of a `date-time`. A deadline at 23:59 UTC falls on a different local day for many learners. Show the local date and time.
- **C7. Autofocus** (`screens/home.md` §6 Empty). Focusing the field on first visit opens the phone keyboard over the help line, and screen-reader users skip past the skip link and the heading. Autofocus only at expanded width.
- **C8. Home at 1440** (`screens/home.md` §7 Desktop)
  - The alert in the wireframe runs past the 560 dp column. Keep alerts inside it.
  - State the column's horizontal position. Aligning it with the Course title's left edge gives all three screens one start line.
- **C9. Boxes in wireframes** (`screens/course.md` §7, `screens/reader.md` §7). The README and resource areas are drawn as bordered boxes. Label them as unbordered regions, so the build doesn't turn them into cards.
- **C10. Problem paths** (`screens/home.md` §9 Problem row). Paths are 0-based JSON Pointers: `/outline/2/resources/0/path` is the third outline item. Show a 1-based form for authors next to the exact pointer.
- **C11. Assignment note** (`screens/reader.md` §9). "Submitting is not available in a preview" uses an internal word. Use "Submitting work isn't available in Lectale yet."
- **C12. Second skip link** (`screens/course.md` §8). At 840 px and wider, Contents comes after the whole README in focus order. Add a second skip link, "Skip to course contents".
- **C13. Top bar on phone** (`screens/reader.md` §7 Phone). On 360 px the Reader's top bar is two rows. Say it scrolls away rather than sticking, so reading space isn't lost.

---

## Journey coverage

| Journey | Served | Gaps |
|---|---|---|
| J1 Open by URL | Yes, mostly | Reload or deep link (M1); timeout and cancel (S2); SSH form (S2) |
| J2 Read the description | Partly | Relative images (M2); raw HTML (S11); heading scale (M6) |
| J3 Move through lessons | Partly | Reload dead end (M1); current place not marked on Course or on the compact Reader; pane moves sides (M5); Previous and Next layout and focus (S8) |
| J4 Open a resource | Partly | File cards with no working action (M3); sizes unknown (S12) |
| J5a Invalid URL | Yes (client check) | Server 400 not designed (S2) |
| J5b Not found or private | Yes | Reader's 404 copy guesses a cause (S1) |
| J5c Invalid course.yaml | Yes | Missing versus invalid is answered by the Worker codes (S2); full list announced (S2) |
| J5d Rate-limited or offline | Partly | Offline and 5xx copy mixed up (S1); one rate-limit code, no fallback copy (S2); references missing (S1) |
| J5e Resource or README fails | Partly | Retry offered on failures that can't clear (S1) |

**Privacy-neutral errors:** pass.

- **Home:** one title and body for missing, private and unsafe addresses, with no wording that depends on the status.
- **Course:** "The description can't be loaded." is neutral.
- **Reader:** neutral but inaccurate (S1).
- **The outline route proposed in M1:** its not-found state must reuse the same copy.

## UX laws

| Law | Holds | Fails or at risk |
|---|---|---|
| Hick, Choice Overload | Home: one field and one button | Reader at 1440 has five ways to move: brand, breadcrumb, contents, In this lesson, Previous and Next (C4) |
| Jakob, Mental Model | Previous and next, table of contents, list-detail | Behaviour of system back not defined (S8); breadcrumb item with no destination (M4) |
| Fitts | 44 dp controls; Next at the end of the text | Start course far right at 1440 (S4) |
| Proximity, Common Region | Download in the resource header | Help and privacy lines split (S3) |
| Miller, Chunking | Modules group lessons | Long outlines without collapse stay an open question (litse-ui lacks an accordion) |
| Cognitive Load, Tesler | Commit pinning hidden from the learner | "preview" in the copy (C11) |
| Doherty | Spinner, skeletons, slow-progress text | No timeout state (S2) |
| Von Restorff | One primary per screen | On phone the ribbon is never visible (M5); two ribbons at 1440 (S7) |
| Serial Position, Peak-End | Calm end-of-course note | Start course doesn't become Continue (M5) |
| Goal-Gradient, Zeigarnik | Ribbon on the Reader pane | Not on Course or on the compact Reader (M5) |
| Postel | Many URL forms accepted | SSH form and `http://` missing (S2) |
| Aesthetic-Usability | Calm, restrained plan | Heading inversion (M6) |

## AI-tell checklist (token plan and screens)

| Area | Result |
|---|---|
| Colour | Pass. Flat surfaces, one accent, Birch is not cream, dark scheme designed separately. Ink on Birch 14.25:1, Cobalt on Birch 7.24:1, white on Cobalt 8.03:1, Cobalt on Mist 6.52:1, dark Cobalt on dark Birch 7.55:1. Make sure `fromPalettes` gives the dark primary button dark text: white on `#8FA8EE` is 2.33:1. Mist as the only selection cue fails at 1.11:1 (S7). Brick is a stock red (C1). |
| Type | Typefaces chosen deliberately. Heading inversion (M6), line length and fallback (S10). No eyebrows and no all-caps. |
| Layout | Pass. No hero, no card kit, no dashboard. Pane moves sides (M5). Wireframe boxes could be read as cards (C9). |
| Components | One separation method, radii by role, no trailing arrows. Download duplicated (S7). Primary disabled with no way forward (S5). |
| Motion | Pass. One motion, triggered by the user (the ribbon). Reduce-motion is specified on all screens, and litse-ui's spinner, skeleton and tabs honour it (checked in source). Focus should not animate (C2). |
| Icons | One family. Kind and row icons are decoration (S13). Zoom buttons are icon-only (S15). |
| Copy | No filler verbs and no invented numbers. Comma- and pipe-joined meta strings (S4, S7). "address" means two things (S6). "preview" is an internal word (C11). |

## Accessibility

- **Keyboard order:**
  - Course puts author links before Start course (S4).
  - Every outline row is a separate tab stop (S9).
  - Focus after Next and Previous is not defined (S8).
- **Landmarks:** banner, main and `nav` are present on all three screens. The breadcrumb `nav` needs its usual name (M4). The footer for the accessibility statement is still an open question (Home Q6).
- **Labels:**
  - The back control fails 2.5.3 Label in Name (M4).
  - The top-bar mark is icon-only on Course and Reader (S14).
  - Zoom buttons need tooltips (S15).
- **Targets:** pass. Controls and rows are 44 dp, and inline links get a 24 dp hit area. State the 24 dp minimum for breadcrumb links too.
- **Line length:** about 75 characters at 640 dp (S10). On phone, about 38 characters at 18 px, which is acceptable.
- **Reduce-motion:** pass.

## Five pre-ship checks (`ai-tells.md`)

1. **Remove one decoration.** The token plan removes facts icons, which the spec never had. Remove the list kind icons and the tags instead (S13, S4).
2. **Name the Lectale-specific element.** The ribbon. As specified it shows only on the Reader at 840 px and wider; extend it to Course contents (M5).
3. **Every colour, font and effect traced to a token.** Yes, except Brick (stock), the Greek fallback (not named) and the selected-row cue (C1, S10, S7).
4. **All states and reduce-motion checked.** Reduce-motion yes. Missing states: M1 to M3, S1, S2, S5 and S11.
5. **Copy.** No filler verbs and no invented numbers. Sample names in the wireframes are marked as illustrative.

## Element rows to remove or change

| Screen | Row | Action | Finding |
|---|---|---|---|
| Home | Privacy line | Merge into the help line | S3 |
| Home | Help line | Drop the claim that README.md is required | S3 |
| Home | Top bar brand link | Plain text or `current` on Home | S14 |
| Course | Tags | Remove | S4 |
| Course | Facts: version | Remove; show facts as labelled pairs below Start course | S4 |
| Course | Start course | Becomes "Continue: {lesson}" after a lesson is opened; removed when there are no lessons | M5, S5 |
| Course | Tabs | "About" becomes "Description"; no tabs when there is no README | S5, S6 |
| Course | Raw HTML row | Becomes a Rules note with a visible placeholder | S11 |
| Course | Contents | Start side at 840 px and wider; ribbon on the last-opened lesson | M5 |
| Reader | Breadcrumb | Course title link, module and lesson as text; moved out of the top bar | M4 |
| Reader | Back control | Name contains the visible title | M4 |
| Reader | Download (header) | Hidden when a card offers Download | S7 |
| Reader | In this lesson | Rows at every width; Mist plus a cue that is not colour | S7 |
| Reader | File card, Link card | Table of kind and action | M3 |
| Reader | Image viewer | Correct requirement; tooltips | S15 |
| Reader | Kind icons (§10) | Remove | S13 |

## Not done in this pass

- **Codex second opinion** (`docs/ux/README.md` step 4): not run. The role runs Codex on screenshots, so for the specs it is left to the caller.
- **Visual review:** after build, against these specs, with screenshots at 360, 768 and 1440 px in light and dark.

---

## Re-review (2026-11-21, revision 5995b25)

| | |
|---|---|
| **Stage** | Spec re-review; still no screenshots |
| **Files** | `journeys-m2.md`, `inventory.md`, `token-plan.md`, `screens/home.md`, `course.md`, `reader.md` |
| **Checked against** | the spec text itself, not the resolution table; `spec/errata/openapi.yaml` (`getPreview`, files and folders routes, `PreviewFolder`, `OutlineResource`); `apps/edge_api/src/preview/` (`routes.ts`, `errors.ts`, `outline.ts`); `litse-ui-private/lib/src/theme/typography.dart`; direction A contrast recomputed from the seeds (all figures in `token-plan.md` match) |

### Verdict: revise (three small edits)

Home can go to build as it stands. Course and Reader need the three edits R1 to R3 below before build. Each would show up as a hard stop at visual review. All six must-fix items are resolved in the spec text. Fourteen of the fifteen should-fix items are resolved; S8 is only partly resolved (R2). The direction A or B owner decision (D12) does not block build, as long as the palette goes through `fromPalettes` and the reading face is one style slot.

### Must-fix from the first review

| ID | Status | Evidence in the specs |
|---|---|---|
| M1 | Resolved | `getPreview` exists in the contract and in `routes.ts`. Course §6 and Reader §6 design the cold open: a skeleton, then "Course not available" with "Enter the GitHub address", or Try again when J5 allows. "Open course" now has one meaning. A not-found never re-imports by itself (J5 rules). |
| M2 | Resolved | The files route exists. Course §5 gives a case table for links and images, Reader §5 states its two differences, and D17 makes it an explicit M2 decision that relative images in lessons don't load. See S-b for the one gap. |
| M3 | Resolved | Reader §5 has a table mapping each resource to what it shows and its action. A kind with no viewer always offers Download. Folders list their entries through the folders route (the `PreviewFolder` shape matches). `embedUrl` is `resource.url` in `outline.ts`, so "Watch on YouTube" opens a real page. |
| M4 | Resolved | The breadcrumb and the back control are gone (D2, D3). The module line is plain text. The Contents control's name is its visible text. The top bar holds only the brand. |
| M5 | Resolved | One pane on the start side. The ribbon marks the learner's place on both screens and moves to the Contents control when the pane is hidden. Start course becomes "Continue: {lesson title}". |
| M6 | **Partly** | The rules are right (nothing under 18, nothing over h1, shift by one or two levels). The slot mapping is wrong: see R1. |

### Should-fix from the first review

S1 to S7 and S9 to S15 are resolved in the spec text. S2's truncated-tree state is correctly dropped: no `repository_tree_truncated` appears in `apps/edge_api/src`. S8 is resolved except for truncation and the stacking rule (R2).

### Remaining must-fix

**R1. The heading map names a slot at the wrong size (type-scale drift).** `token-plan.md` "Sizes and the heading map" maps rendered h2 to `heading` at 24/32. In litse-ui, `heading` is 20/28, which comes to 21.5/30 at the comfortable scale of 14/13. That is the size the plan gives the h3 override. Built as written, h2 and h3 render at the same size. On the Reader, the resource h2 (`Text (heading)`, Reader §5) also matches a Markdown h3. Fix:
- Mark h2 as an override at 24/32 in the token plan.
- Change the Reader §5 resource heading row from `heading` to "h2 override, 24/32".
- Note that `display` comes from 28 × 14/13 (30.15/36.6), so the 30 (36) in the plan is rounded.

**R2. Primary labels truncate, and stacking ignores text size.**
- The Reader 768 wireframe shows "[Next lesson: Sum…]" and the Course 360 wireframe shows "[Load 3 images from img.exa…]".
- No spec text forbids truncation. The only mention is "(wraps)" beside Previous on the phone wireframe.
- Reader §5 stacks Previous and Next below 600 dp only. In a 576 dp column, two "Next lesson: {title}" buttons already overflow at 100 percent text, and certainly at 200 percent.

Fix:
- Add a rule to Reader §5 and §8: button labels wrap and never ellipsize.
- Stack Previous and Next whenever the two don't fit side by side at the current text size. That means measuring, not a fixed 600 dp, which also matches "breakpoints set by the text".
- Keep focus order the same as visual order.
- Redraw the two wireframes.

**R3. The sticky Contents bar is a fixed 44 dp row with a title that wraps.** The inventory's Shared layout section says both "one 44 dp row … stays put" and "the title … wrapping, never truncated". These conflict. On a phone at 200 to 400 percent text, a long lesson title makes the sticky bar two to four lines tall, and it covers focused content. That fails 2.4.11 Focus Not Obscured (Minimum) and is a MAJOR finding. Fix:
- Make 44 dp the minimum height, not a fixed height.
- Stop the bar sticking when its height passes 20 percent of the window, or at 200 percent text or more.
- Scroll focused elements clear of the bar (`Scrollable.ensureVisible` with the bar's height as the offset).

### Should-fix (new in the revision; not blocking)

- **S-a. Title or filename.** Reader §5 and §9 name rows and Next by `{title}`. The wireframes use filenames ("data.md", "Next file: survey.csv") next to a title h2 ("Data and its shape"). Use the resource title in rows, the h2 and Next and Previous. Show the filename only in the Download bar.
- **S-b. Relative README links to a missing file or a directory.** The files route serves regular files only, so these open the Worker's JSON 404 in a browser tab, which is a dead end outside the app. The inventory's M2 row claims a "missing file" case, but Course §5 has a row for missing images only. Fix: add the row, and ask the edge engineer for a plain HTML 404 page when the request prefers `text/html`.
- **S-c. Contents with nothing to show.** In three Course states the pane or bar stays on screen with no task:
  - No lessons: at wide widths, a 272 dp pane holds only "Overview".
  - No overview, single column: the control is hidden but the sticky bar row is not.
  - Link fails to open: the control's state is unspecified.

  Remove the Contents bar and the pane in all three.
- **S-d. A ribbon before any lesson has been opened.** On Course the ribbon then sits on Overview. The Overview row then carries both marks and the name "Overview, last opened", and the bar reads "Contents Overview" while the overview is on screen. Show no ribbon until a lesson has been opened.
- **S-e. Closing the Contents panel.** Neither Escape nor focus return is specified. Escape should close the panel and return focus to the Contents control (2.1.2 No Keyboard Trap, 2.4.3 Focus Order).
- **S-f. Phone density on the Reader.** For a lesson with two files at 360 by 640, the module line, h1, description, In this lesson, the h2 and the two-line Download bar take about 460 dp before the first line of the resource, which §4 ranks first. On a single column, put the Download bar on one line. Check this in the first screenshots.
- **S-g. Plurals.** "{n} problem(s)" (Home §9), "{title}. {n} problems.", "Load {n} images" and "{n} SVG images" need ICU plural forms. "(s)" is a tell, and Bulgarian has its own plural rules.
- **S-h. Unmapped fields.** `OutlineResource.preview: false` has no row in the M3 table. It should get a file card with Download. Assignment `releaseAt` is also missing from the Reader's date rows.
- **S-i. The logo brief contradicts direction A.** The brief says "Avoid … purple" and makes the mark the accent colour, and A's accent is mulberry. State in the brief that mulberry is a wine red (hue 353) before Codex draws concepts.
- **S-j. The safe HTML subset (S11) needs a security ruling.** Before the README renderer is built, the security-reviewer should confirm that mapping `img`, `details`, `summary`, `br`, `sub`, `sup` and `kbd` to native widgets is within AGENTS.md's "Never render HTML … from course content".
- **S-k. "In this lesson" has no style or role.** Make it a `subtitle` label that names the list, not a heading, so the resource h2 stays the next heading.

### New-problem check

| Check | Result |
|---|---|
| One primary action per screen | Pass: Open course; Start course or Continue; Next or Back to course |
| Elements without a task | Pane and bar in empty states (S-c); ribbon on Overview (S-d) |
| Dead ends | None in the app. One outside it: the JSON 404 in a browser tab (S-b) |
| AI tells | "(s)" plurals (S-g). Otherwise pass: no meta strings, icons, eyebrows or card kit |
| Naming | Title or filename (S-a). Otherwise one name per thing ("Overview", "Back to course", "Enter the GitHub address") |
| 360, 768, 1440 | Breaks: truncation and stacking (R2); sticky bar at large text (R3); phone density (S-f). Pane and column arithmetic holds at 1440: the 576 dp column is centred in 1060 dp |

### Not done

- Codex was not re-run. The second opinion on the home, course and viewer screens belongs to the screenshot stage.
- Visual review happens after build, at 360, 768 and 1440 px in light and dark, against these specs.

## Re-review blockers resolved (orchestrator, 2026-11-21)

- **R1:** `token-plan.md` now marks h2 as an explicit 24/32 override, because litse-ui's `heading` slot is 21.5; h3 uses the slot. The Reader's resource h2 row names the override.
- **R2:** Course and Reader state that button labels never truncate: labels wrap, and groups (Previous and Next, Load buttons) stack full width whenever the full labels don't fit at the current text size, not at a fixed width.
- **R3:** `inventory.md` defines the Contents bar as at least 44 dp and growing with its text, with the place title wrapping to two lines and the full text available as tooltip and description; scrolling keeps the focused element clear of the bar (WCAG 2.2 2.4.11).

With these, Home, Course and Reader are cleared for implementation. S-a to S-k are handled during the build.
