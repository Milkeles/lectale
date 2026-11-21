# Screen: Landing page, with its entry pages

| | |
|---|---|
| **Milestone** | M2 concept round (the site), M3 (sign-in and account screens in the app) |
| **Journeys** | First visit: understand what Lectale is, open a course, install, sign in |
| **Requirements** | V4-CORE-01, V4-CORE-02, V4-CAT-01 to V4-CAT-05, V4-COST-06, A11Y-001; ADR-0014; security review R3, R12, R13, R15 to R22 |
| **Status** | Draft for design review, second round (fixes from the design review and the Codex critique of 2026-11-21). Built as static HTML and CSS in `../concepts/landing/`; screenshots in `../concepts/landing/screens/` |

Copy is `../copy/landing.md`, used as written. Where this spec adds or changes words, section 9 says so. The landing page is static HTML served by the Worker at `/` (ADR-0014). The auth and app-home pages in the same folder are mocks of what the Flutter app draws under `/app/`; they are listed in section 14.

## 1. Purpose

A first-time visitor who has never heard of Lectale wants to know what it is and whether it costs anything; they succeed when they can say "it shows a course's files in one place, free, no account" and open a course, or install the app, without a second page of reading.

## 2. Primary action

**Open a course** (gold, hero). It leads to `/app/#/open`, the app's open-a-course screen, with the repository link field focused. The second gold button, **Open in browser**, is in the Download section and is never in view together with the first at 900 px height. Header "Create account" is outlined (copy file section 3, point 8).

## 3. Entry and exit

| Arrives from | Leaves to |
|---|---|
| Search, a shared link, a README badge | `/app/#/open` (Open a course, Open in browser, "Paste a course link", Open a course by link); `/app/` (card links); `/app/#/login` (Log in, Connect a repository); `/app/#/create-account` (header); `catalog.html`; GitHub Releases `latest/download/<asset>` (downloads, SHA256SUMS); the canonical host's `/download/android` (QR code); privacy, terms, accessibility pages (not built yet) |

## 4. Content, in order of importance

1. What Lectale is: the hook, the deck, Open a course (hero).
2. Proof that it is real: the reader, drawn in HTML, with the ribbon.
3. What opens in it (formats).
4. How to start (3 steps).
5. For instructors, with the repository-to-outline picture.
6. Catalog teaser with example covers.
7. Download and browser use.
8. Privacy (one compact block), then the footer.

## 5. Elements

Every row names the task it serves. No row, no element.

| Element | Component (HTML) | User task it serves | Requirement | Law or pattern |
|---|---|---|---|---|
| Skip link "Skip to main content" | `a.skip`, first Tab stop | Bypass the header | A11Y-001, WCAG 2.4.1 | Fitts |
| Brand "Lectale, home" | logo SVG + wordmark link to top | Know where I am; go to the top | NN/g homepage 2.1 | Jakob |
| Nav: Catalog, Download, For instructors | `nav` "Main", visible at every width (no Menu) | Jump to the three places a visitor looks for | NN/g 4.3 | Hick: three links |
| Log in (text link) | `a` to `/app/#/login` | Return to my account | R17 | Jakob |
| Create account (outlined button) | `a.btn--outline` to `/app/#/create-account` | Start teaching or enrolling | R17 | Jakob |
| Hero headline (h1), two lines | `h1`, Source Serif 4, opsz 60 | Understand the promise in a second | NN/g 2.2 | Von Restorff |
| Deck, directly under the headline | `p.t-lead` | Learn what Lectale is: it opens a course from its GitHub repository | Copy hook H, Codex #1 | Cognitive load |
| Open a course (gold) | `a.btn--primary` to `/app/#/open` | Start reading; the link field is focused on arrival | V4-CORE-01 | Fitts, one primary |
| Browse courses | `a.btn--outline` to catalog | Find a course without a link | V4-CAT-01 | Hick |
| "Free to read, no account needed." | `p.hero__free`, own line under the buttons | Learn the price and the account rule before clicking | Brief | Cognitive load |
| Product preview (reader): app bar with the course title and "Lesson 3 of 7", contents, one lesson with module label, title and two paragraphs | `figure`, children `aria-hidden`; caption states what it shows. A phone shows the app bar, the lesson title with the ribbon and one paragraph | See what reading a course looks like, where I am in it, and what the ribbon means | NN/g "show real content" | Zeigarnik, Goal gradient, Von Restorff |
| Section "Everything in the course opens in the app": six run-in terms with one sentence each, closing line | `dl` (term inline, semibold serif) | Know whether my files will open (text, PDF, notebook, video, audio, code) | `RENDERING_REQUIREMENTS.md` | Chunking |
| Section "How to start": three numbered steps; step 1 links to the link field and the catalog | `ol` | Know the first step, and that an account is optional | V4-CORE-01 | Goal gradient |
| Section "Keep your course. Lectale presents it.": body, What you keep, What you get | `h2`, `ul` | Learn what an instructor keeps and gets | Brief | Proximity |
| Repository and outline figure: columns "Your repository" and "What learners see", one row per source line, lesson names as in the preview | `figure`, two `ul` on a subgrid, each labelled by an `h3` | Picture how a folder becomes a course | Brief, Codex #4 | Specifics beat abstractions |
| Connect a repository (outlined, to `/app/#/login`) and Open a course by link (link) in instructors | `a` | Sign in to teach, or try my own repository first | R17 | Hick |
| Section "Browse listed courses": body, Browse the catalog link | `h2`, `a` | Learn the catalog is optional and how to reach it | V4-CAT-01 | Jakob |
| Note "These are examples. They are not real courses.", above the cards | `p.cap` | Not mistake examples for real work | Copy 4.4 | Honesty |
| Three example course cards (two on a phone): cover, title, summary, language, "Example course" tag | `li.card`, one link per card named "{title}, example course" | See what a listed course looks like | V4-CAT-01, V4-CAT-05 | Specifics beat abstractions |
| Download rows: Web, Android app, Windows, macOS, Linux; name, file name (no size until a release exists) and one button each | `ul.plats`, one compact row per platform; one gold button (Open in browser), four outlined "Download" with a hidden platform name | Pick my platform | R21 | Hick: one row each |
| Line "Android and desktop files come from GitHub Releases. Check a file against SHA256SUMS." | `p`, two links | Know where files come from; check what I downloaded | R21 | Trust |
| Line "The Android signing certificate fingerprint is published with each release." | `p` | Know that the Android app can be verified | R21 | Trust |
| iPhone and iPad note | `p.note` | Know why no iOS file exists and what to do | Brief | Dead-end avoidance |
| QR code labelled "Android app" with caption and the printed canonical URL (hidden under 45 rem) | `img` + `p` + `p` | Install on my phone from this screen | R22, NN/g QR | Not on the device that shows it |
| Privacy block: heading, text, link, one compact row | `h2`, `p`, `a` | Know there is no tracking | V4-COST-06 | Peak-end |
| Footer: brand, description, six links, independence line, "© 2026 Lectale" | `footer`, `nav` "Footer" | Find legal pages; learn that Lectale is not GitHub | NN/g top ten 3 | Consistent help (WCAG 3.2.6) |

Not on the page, by decision: no testimonials, counters, logos of other products, newsletter box, cookie banner, chat widget, icons in lists, gradients.

## 6. States

A static page has few states; each is designed.

| State | What the reader sees | What they can do |
|---|---|---|
| Fonts loading | System serif and sans until woff2 swaps in (`font-display: swap`; both preloaded) | Read at once |
| No JavaScript | The landing page uses none | Everything |
| Phone width | Nav moves to a second row, still visible; both hero buttons are full width; the preview drops the contents pane and the second paragraph, and the ribbon moves beside the lesson title; two example courses, with the notice above them; download rows stay one line each; QR block hidden because the Android row is the direct link (NN/g) | Same tasks |
| Reduced motion | The ribbon is drawn at rest | Same |
| Forced colours | Outline ring and a bordered primary button replace shadows and fills | Same |
| Dark | Own palette; the reader window has a hairline boundary and a lighter selected row; the QR tile stays dark on light | Same |
| Download not published yet | Buttons link to `releases/latest/download/<asset>`, which GitHub answers with 404 until the first release; no size is shown | Open GitHub Releases from the line under the list |

## 7. Wireframes

### Phone (390 px)

```
[mark Lectale]        Log in [Create account]
Catalog  Download  For instructors
Open the course.
Close the other tabs.
deck (4 lines)
[ Open a course ]
[ Browse courses ]
Free to read, no account needed.
+---------------------------+  Sand mat
| mark Introduction...  3 of 7 |
| Describing data           |
| |ribbon Averages and spread |
| one paragraph             |
A lesson from an example course ...
Everything in the course opens ... (run-in terms, one column)
How to start (1 2 3 stacked) ... Instructors ... Browse listed courses
notice, then 2 example covers
Use Lectale on your device: Web, Android app, Windows, macOS, Linux (one line each, no QR)
No tracking / footer
```

### Desktop (1440 px)

```
[mark Lectale] Catalog Download For instructors                 Log in [Create account]

Open the course.
Close the other tabs.
deck, 2 lines
[Open a course] [Browse courses]
Free to read, no account needed.

+------------------------- Sand mat ---------------------------------------------+
|  +-- reader window (hairline) -------------------------------------------+      |
|  | mark Introduction to statistics                        Lesson 3 of 7  |      |
|  | Overview            | Describing data                                 |      |
|  | Describing data     | Averages and spread (mulberry, 36)              |      |
|  | |Averages and spread| paragraph, 18/30, 36 em                         |      |
+------------------------------------------------------------------------------+
Everything in the course     | Text. ...
opens in the app             | PDFs. ... (run-in terms)
How to start     1 Find a course   2 Read it   3 Save a course or enrol
Keep your course.            | Your repository | What learners see (rows aligned)
Lectale presents it.         | [Connect a repository] Open a course by link
Browse listed courses        | notice, then [cover] [cover] [cover]
Use Lectale on your device   Web [Open in browser]            [QR]
                             Android app ... Windows ... macOS ... Linux ...
No tracking                  | text, link
-------------------------------- footer ----------------------------------------
```

## 8. Interaction and accessibility

- **Tab order:** skip link, Lectale home, Catalog, Download, For instructors, Log in, Create account, Open a course, Browse courses, [reader preview: none], Paste a course link, catalog (How to start), Connect a repository, Open a course by link, Browse the catalog (teaser), card 1, card 2, card 3, Open in browser, Download (Android app, Windows, macOS, Linux), GitHub Releases, SHA256SUMS, Read the privacy notice, footer links. Measured in the built page at 1440: 32 stops, in this order, ring visible on all.
- **Landmarks:** banner, `nav` "Main", main, one `section` per h2 with `aria-labelledby`, `nav` "Footer", contentinfo. One h1; h2 per section; h3 for list terms and card titles. The preview is `aria-hidden`; its figcaption says what it shows.
- **Focus ring:** gold, 2 px, outside a 2 px Paper gap (box-shadow plus a transparent outline for forced colours). Card focus draws the ring around the whole card.
- **Targets:** every header, account, footer and standalone link and every button is at least 44 px high (measured). Inline links inside a sentence (Paste a course link, catalog, GitHub Releases, SHA256SUMS) are 22 px high and fall under the WCAG 2.5.8 inline exception. Header and footer links carry 12 px of side padding so the ring never touches the letters. "Show password" is a 40 px button reserved inside the field, so typed text ends where it begins.
- **Labels:** the logo link is "Lectale, home"; cards are "{title}, example course"; download buttons read "Download" with a hidden platform name ("Download for Windows"), so the visible text is part of the name; the QR image has a text alternative and the same URL is printed under it as text. "Show password" is a button with `aria-pressed`; in Flutter it exposes a toggled state. The catalog result count is `aria-live="polite"` and stays in the page at zero.
- **Contrast:** measured by axe on every page in both schemes; the token plan's ratios apply (graphite 13.4:1, muted text 6.9:1 on Paper and 6.1:1 on Sand in light, 9.1 and 7.7 in dark, mulberry 7.15:1, gold button label 5.54:1, gold ring 4.92:1 on Paper).
- **Motion:** one moment, the ribbon in the preview unfurls once in 0.7 s after 0.5 s. No other animation. Reduced motion removes it. No scroll effects, no hover transitions.
- **No third-party request, cookie, inline script or inline style.** Verified with a Playwright HAR of `index.html`: 12 requests, all to the page's own origin, 0 cookies, empty storage, 0 CSP messages under the R18 policy (`script-src 'none'` on every page except the catalog).

## 9. Copy

All text is from `../copy/landing.md`, with these additions and changes for review by the copywriter:

| Where | Text | Why |
|---|---|---|
| Deck | "Lectale opens a course from its GitHub repository and shows its lessons, PDFs, notebooks, video and audio in one place." | Says the GitHub-to-course idea next to the headline (Codex #1). Replaces "Lectale shows a course's lessons, PDFs, notebooks, video and audio in one app." |
| Free line | "Free to read, no account needed." | Own short line under the buttons; was the deck's last sentence |
| Preview caption | "A lesson from an example course, open in Lectale. The gold ribbon marks the lesson you are reading." | A figure needs a caption; says what the ribbon means |
| Preview app bar | "Introduction to statistics", "Lesson 3 of 7" | Shows the course and the place in it; 7 is the number of lessons in the contents |
| Formats | Terms run in: "Text. Lessons and ..." | One reading column instead of six headings |
| Step 1 | "Paste a course link, or choose a course from the catalog." with both phrases linked | The link is part of the sentence, so the lone link under the steps is gone |
| Step 3 | Title "Save a course or enrol"; text "An account lets you enrol in a course or save it for later. Reading never needs one." | Shorter title (Codex #3); the account rule stays in the text |
| Instructors button | "Connect a repository" (to `/app/#/login`) | The instructor's real next step (Codex #4); the same words as on app home |
| Repository figure | Column labels "Your repository" and "What learners see"; caption "Lectale builds this outline from your course files."; cell "Sets the order and the titles" beside `course.yaml` | Labelled columns; the caption no longer says left and right because the columns stack on a phone |
| Download rows | Names "Web", "Android app", "Windows", "macOS", "Linux"; buttons "Open in browser" and "Download" (hidden suffix names the platform) | One compact row per platform |
| Download lines | "Android and desktop files come from GitHub Releases. Check a file against SHA256SUMS." and "The Android signing certificate fingerprint is published with each release." | R21; "From GitHub Releases" is said once |
| QR label and caption | "Android app", "Scan with your phone to download it." | Same label as the Android row |
| QR text alternative | "QR code for the Android app. The same address is printed below it." | R22 |
| Footer | "© 2026 Lectale" | No placeholder; the operator's identity goes on the Privacy notice page |
| Auth error title | "The email or password is not correct." is the title and "Check both and try again, or reset your password." the text | Errors carry a title (token plan); this splits the copy file's sentence, adds no words |
| App home | Button "Continue", described by the lesson line ("Averages and spread, Describing data, last opened lesson") | The heading above already says "Continue reading" |

Deviations from the copy file, with reasons:

- **No "Menu" button on small screens.** The three nav links stay visible in a second row. NN/g's homepage rules fault navigation hidden behind a menu link, and the row needs no script. Log in and Create account stay visible, as the copy file asks.
- **Catalog cards** show the language and the "Example course" tag as two separate items, not "English · Example course", so no middle-dot string is built. The "Example instructor" line is gone: it was invented data, and the note above the cards and the tag already say these are examples.
- **Hook D is withdrawn.** The owner kept "Open the course. Close the other tabs." (Hook H); `index-hook-d.html` and its screenshots are deleted.

## 10. Images

| Image | Source | Format | Decoded at |
|---|---|---|---|
| Logo | `docs/ux/brand` Ribbon Cut | Inline SVG, `currentColor` | Vector |
| Example covers (5) | `covers.py`: title as outlines in Source Serif 4 (opsz 28, weight 600) on Mulberry, Sand or Graphite, with one picture each. Every cover has a 44 px inset on all sides: the title starts at the top left, the picture is anchored to the bottom inset and fills the width between the side insets (the histogram is the reference). The manuscript is a page that runs off the right and bottom edges, with an illuminated initial and rows of word marks; the scatter plot fills the picture area on Graphite and needs no frame | SVG in `<img>` (R20), 2:3, 480 by 720, 12 to 27 kB each | Vector; shown 120 to 250 px wide; `loading="lazy"`, empty `alt` because the title follows |
| No-cover placeholder | The course title as text (Source Serif 600, Mulberry on Sand, the same 44/480 inset, sized in container units) in the same 2:3 box, no logo. In the app, drawn at run time | HTML text | Same 2:3 box so the grid does not move |
| QR code | `make-qr.mjs` with the `qr` package (MIT OR Apache-2.0, zero dependencies), encodes `https://lectale.fervorgames.workers.dev/download/android`, 4-module quiet zone, dark on light in both schemes | SVG in `<img>`, 7 kB | Vector, 164 px (4 px per module); decoded back to the URL with the package's decoder |
| Product preview | HTML and CSS | Live text | Not an image |

Covers outline their titles because an SVG in `<img>` cannot load web fonts. Bulgarian forms come from the font's `locl` feature, applied with the language set to `bg`. The catalog shows covers at about 120 by 180 px (96 by 144 on a phone) beside the details; the landing page shows them at about 250 px.

**The QR route.** `/download/android` does not exist yet. When the site is built, the Worker answers it with a redirect to the `lectale-android.apk` asset under `releases/latest/download/` of this project's GitHub repository, so the printed code never changes when a release does. Until then the preview does not link it; the URL is printed as text. The asset names are fixed by the release workflow: `lectale-android.apk`, `lectale-windows-x64.zip`, `lectale-macos.zip`, `lectale-linux-x64.tar.gz`, plus `SHA256SUMS` on the same release.

## 11. Open questions and to-do

1. Resolved: Hook H. Hook D is withdrawn.
2. Resolved: the QR code encodes the canonical host (R22). To do when the site is built: the `/download/android` redirect, and a CI step that decodes the SVG and compares it with the printed text.
3. Fonts are the publishers' own, unmodified files: Source Serif 4 variable (419 kB roman; the 339 kB italic is declared but not fetched), Plex Sans Regular, Medium and SemiBold (about 65 kB each) and Plex Mono Regular (48 kB). Only the roman serif is preloaded. The app's `IBMPlexSans.ttf` is a different build (3.201, variable) from the website's static 3.006 files, so the web page and the app render Plex Sans slightly differently; the owner can move the app to the same files later.
4. **To do:** the Privacy notice page, and the Terms and Accessibility pages. The Privacy notice names the operator's legal identity, which is why the footer says only "© 2026 Lectale".
5. **To do:** the open-a-course screen at `/app/#/open` (link field focused) needs its own screen spec; the concept uses `app-home-empty.html` as its stand-in.
6. Sizes are left out of the download rows until a release exists. When it does, the build adds the real size from the release API.
7. The Android signing-certificate SHA-256 is "published with each release"; the CI release workflow has to publish it (R21).
8. `docs/ux/token-plan.md` still lists muted text at `#5A5F5B` / `#A9ADA7`; this round moved it to `#4F544F` / `#B9BDB7` (section 12). Update the token plan when the owner accepts it.

## 12. Tokens and type scale (the token plan for this milestone)

Colour roles from `../token-plan.md`, written as CSS custom properties; no other value is used.

| Role | Light | Dark | Used for |
|---|---|---|---|
| Paper (`--paper`) | `#F4F1ED` | `#191B1A` | Page, reading surface, field fill |
| Sand (`--sand`) | `#E8E3DC` | `#262927` | Product mat, How to start band, footer, panels, hover, selected row |
| Graphite (`--ink`, `--ink-2`) | `#242725`, `#4F544F` | `#E9E5DE`, `#B9BDB7` | Text; field and outline-button borders. Muted text is 6.1:1 on Sand and 6.9:1 on Paper in light (was 5.1 and 5.8), 7.7 and 9.1 in dark |
| Hairline (`--hair`) | `#D3CCC2` | `#454A46` | The reader window's boundary and its inner dividers. Decorative, so it needs no contrast ratio; the only line on the page |
| Selected row (`--sel`) | `#E8E3DC` (Sand) | `#353A36` | The lesson being read in the preview's contents; lighter than Sand in dark so the row is visible (text on it 9.2:1) |
| Mulberry | `#753E5E` | `#E0A7C0` | Logo mark, underlined links, the lesson title in the preview and the course title on app home |
| Gold | `#905E0C` (label white) | `#F3DDA4` (label graphite) | Primary button (Hero, Open in browser; app home Continue), ribbon, focus ring. Never text |
| Signal red | `#A3292E` | `#F2958E` | Wrong-credentials alert only, with an icon and a title |

Paper, Sand, graphite and mulberry are about 80 percent of the pixels. Hover is a Sand fill on outlined controls and an underline on the primary button, so no colour is derived.

**Typeface roles.** Source Serif 4 (variable, `wght` and `opsz`) for display, headings and every sentence a person reads; IBM Plex Sans for interface text (nav, buttons, labels, captions); IBM Plex Mono for file names and the repository tree. Self-hosted WOFF2 files from the publishers: Adobe's `release/WOFF2/VAR` files for Source Serif 4, and IBM's `fonts/complete/woff2` files from the `@ibm/plex-sans` and `@ibm/plex-mono` packages for the static weights 400, 500 and 600 (Sans) and 400 (Mono). Nothing is converted or subset, so none is a Modified Version under the OFL. Licence files sit in `fonts/`. Plex Sans has no dark-mode weight offset because three static weights cannot be stepped by 50; the offset applies to the variable serif only.

**Scale.** Sizes follow the traditional printers' scale (Bringhurst, *The Elements of Typographic Style*, 2.1.2: 12 14 16 18 21 24 36 48 60 72), the same family of steps as the app's reading size of 18 over 30. Every font size in `site.css` is one of these ten, set through the `--t12` to `--t72` tokens; nothing is fluid between steps.

| Role | Size over line height | Face, weight, optical size | Tracking | Notes |
|---|---|---|---|---|
| Display (h1) | 72 over 74 above 70 rem; 60 to 45 rem; 48 to 30 rem; 36 below | Serif 440, opsz 60 (40 on phones) | -0.03em | Two lines, one size and weight; `text-wrap: balance`. The opsz 60 design is drawn for loose fit, so it is tracked tight. Catalog h1: 60 |
| Section heading (h2) | 48 over 53; 36 on phones | Serif 480, opsz 48 | -0.02em | |
| Term, step, platform, compact heading (h3) | 24 over 31 | Serif 560, opsz 24 | -0.008em | The platform name is 21 on phones; "No tracking" is an h2 set at this size |
| Step numeral | 36 over 36 | Serif 400, opsz 36, muted | 0 | Baseline-aligned with the step's h3 |
| Deck | 21 over 34 | Serif 400, opsz 21 | -0.003em | 31 em wide; two lines in the hero at 1440 |
| Preview lesson title | 36 over 41; 24 on phones | Serif 600, opsz 36, Mulberry | -0.012em | The reader's title; the app's own scale decides the final size |
| Reading | 18 over 30 | Serif 400, opsz 18 | 0 | Measure 30 em in the page, 36 em in the preview, about 65 to 68 characters; the formats list and the lesson text use it |
| Short description | 16 over 26 | Serif 400, opsz 16 | 0 | Lists, card summaries, download lines |
| Interface | 16 over 25 (nav, buttons, labels, fields, preview rows) | Sans 400, 500 and 600 | +0.005em | Fields at 16 so iOS does not zoom |
| Brand | 21 | Sans 500 | -0.005em | |
| Small | 14 over 21 | Sans 400 | +0.008em | Captions, hints, meta, badges, the "Free to read" line |
| Mono | 14 over 21 (file names, tree); 12 over 18 (the QR URL) | Plex Mono 400 | 0 | `code` inherits it, so the repository tree is Plex Mono |

Line height is larger for serif (1.667) than for sans (1.6). Text is left aligned and ragged right; headings balance, paragraphs `text-wrap: pretty`; no all caps, no eyebrows, no justified text. Dark mode subtracts 50 from every serif weight (`--wo`), as the token plan says. Body weight is 400; weight marks hierarchy only.

**Space and grid.** 8 px rhythm with a 4 px half step: 4 8 12 16 24 32 48 64 96 128 (`--s1` to `--s10`). Every boundary between sections is one token, `--sec`: 96 px on desktop and tablet, 64 px on a phone. Sections have padding on top only; the footer carries the same token as its top margin; the hero starts 64 px (32 on a phone) under the header; the hero and the preview are 64 px apart (48 on a phone). No stacked paddings, no fluid gaps. 12 columns; the gap is 32 px (20 on phones); page 1240 px; the side gutter is 64 px above 70 rem, 32 px to 45 rem, 20 px below. Asymmetric splits (5 and 7 columns, 4 and 8, 8 and 4) alternate with full-width stacks (the preview, How to start, the download head), so no two neighbouring sections share a shape. The Sand band behind How to start is gone: it added a second edge to the section boundary.

**Radii by role.** 5 px (badges, covers, focus ring of inline links), 8 px (buttons, fields, QR tile, the reader window), 12 px (mat, panels, alerts). No shadows; one separation method per surface (Sand fill, a 1.5 px graphite outline on fields and the menu panel, or the hairline on the reader window).

**Motion.** The ribbon unfurls once (0.7 s). Everything else is still. Reduced motion removes it.

**The memorable element: the ribbon.** In the logo, in the reader preview on the lesson being read, and on app home beside the last-opened lesson. It appears at most once per view, always gold, always with the swallowtail cut (clip-path, 8 px wide).

## 13. Check against the anti-generic list

| Tell (`frontend-design`, `ai-tells.md`) | Answer |
|---|---|
| Cream, high-contrast serif, terracotta | Warm grey Paper at low chroma, mulberry, gold on three jobs; the serif carries text and display, in a reading face chosen by the owner |
| Near-black with acid accent | Dark scheme is a separate deep-grey palette with a pale gold accent |
| Broadsheet hairlines | No rules at all; Sand surfaces and whitespace |
| SaaS card kit | One kind of card (course covers, unboxed); no shadows; no icon tiles; no three equal feature cards: the formats are a run-in definition list, the steps a numbered sequence |
| One accented word in the headline | The headline is two plain sentences, same size and weight |
| Eyebrows, caps labels, middle-dot strings, trailing arrows | None |
| Numbers 01 02 03 | Only on the steps, which are a real sequence: plain 1 2 3 at 36, baseline-aligned with the step title |
| Fade-and-slide on every section | One ribbon unfurl, none elsewhere |
| Generic hero with a gradient or stock photo | The hero shows the product: a real reading view in HTML, with the lesson text set in the reading face |
| Fake stats and testimonials | None; example courses are labelled as examples by a note above the cards, a tag on each card and each card's link name |

Pre-ship checks: (1) removed: Menu button, icons on the format list, hero second visual, the Sand band, the separate privacy section, "Example instructor"; (2) Lectale's own element is the swallowtail ribbon; (3) every colour and size traces to section 12; (4) states and reduced motion are in section 6; (5) copy has no filler verbs or invented numbers (the lesson text uses sample scores inside an example lesson).

## 14. Sibling pages in the concept folder

Mocks of app screens, for the owner to judge. They become Flutter screens after review, each with its own spec.

| Page | Purpose and primary action | Elements and the task each serves | States built |
|---|---|---|---|
| `catalog.html` | Find a course. Primary: the search field, then a card | Search field and Language and Subject selects (narrow the list); result count in a polite live region that stays in the page at zero; covers about 120 by 180 px beside the details, two columns at desktop and one on a phone; cards with covers (recognise a course); "These are examples" note; empty state with Clear search; one card has no `cover` and shows the placeholder | Default; no results (`?q=quantum`); filter by script, plain GET without |
| `login.html` | Log in. Primary: Log in (gold) | Email and Password with Show password, a reserved button inside the field with a pressed state (enter credentials, paste allowed, `autocomplete` hints); Forgot your password?; Create account link | Default; wrong credentials (same text for unknown email); unconfirmed email with Send the link again; session expired notice (R12); notices and errors sit directly under the h1 |
| `create-account.html` | Create an account. Primary: Create account | Email; Password with the 12-character hint; consent line with Terms and Privacy notice, above the button; Log in link | Default; "Check your email" (R3: identical for new and existing addresses, with Log in and Reset your password links) |
| `app-home.html` | Continue reading, or open a course. Primary: Continue (gold) | Greeting; Continue reading with cover, ribbon and lesson, and a Continue button described by the lesson (resume, Zeigarnik); Your courses (instructor rows with Listed or Unlisted); Connect a repository; open-by-link field with Open course (outlined, because Continue is primary); Catalog link and account menu in the top bar | Default; account menu open with Log out and Log out of all devices (R13); new account (`app-home-empty.html`: field focused, Open course primary, Browse the catalog beside it; also the concept's stand-in for `/app/#/open`) |

Catalog entry points are deliberately single: the top bar link on signed-in pages. The empty state adds the button the copy asks for because the screen has nothing else to offer.
