# Screen: Landing page, with its entry pages

| | |
|---|---|
| **Milestone** | M2 concept round (the site), M3 (sign-in and account screens in the app) |
| **Journeys** | First visit: understand what Lectale is, open a course, install, sign in |
| **Requirements** | V4-CORE-01, V4-CORE-02, V4-CAT-01 to V4-CAT-05, V4-COST-06, A11Y-001; ADR-0014; security review R3, R12, R13, R15 to R22 |
| **Status** | Draft for design review. Built as static HTML and CSS in `../concepts/landing/`; screenshots in `../concepts/landing/screens/` |

Copy is `../copy/landing.md`, used as written. Where this spec adds or changes words, section 9 says so. The landing page is static HTML served by the Worker at `/` (ADR-0014). The auth and app-home pages in the same folder are mocks of what the Flutter app draws under `/app/`; they are listed in section 14.

## 1. Purpose

A first-time visitor who has never heard of Lectale wants to know what it is and whether it costs anything; they succeed when they can say "it shows a course's files in one place, free, no account" and open a course, or install the app, without a second page of reading.

## 2. Primary action

**Open a course** (gold, hero). It leads to the app, where the link field lives. The second gold button, **Open in browser**, is in the Download section and is never in view together with the first at 900 px height. Header "Create account" is outlined (copy file section 3, point 8).

## 3. Entry and exit

| Arrives from | Leaves to |
|---|---|
| Search, a shared link, a README badge | `/app/` (Open a course, Open in browser, card links, Open a course by link); `/app/#/login`, `/app/#/create-account` (header, instructors); `catalog.html`; GitHub Releases (downloads, QR); privacy, terms, accessibility pages (not built yet) |

## 4. Content, in order of importance

1. What Lectale is: the hook, the deck, Open a course (hero).
2. Proof that it is real: the reader, drawn in HTML, with the ribbon.
3. What opens in it (formats).
4. How to start (3 steps).
5. For instructors, with the repository-to-outline picture.
6. Catalog teaser with example covers.
7. Download and browser use.
8. Privacy, then the footer.

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
| Deck (subheading) | `p.t-lead` | Learn what Lectale is, that it is free, that no account is needed | Copy hook H | Cognitive load |
| Open a course (gold) | `a.btn--primary` | Start reading | V4-CORE-01 | Fitts, one primary |
| Browse courses | `a.btn--outline` to catalog | Find a course without a link | V4-CAT-01 | Hick |
| Product preview (reader) | `figure`, children `aria-hidden`; caption states what it shows | See what reading a course looks like, and what the ribbon means | NN/g "show real content" | Zeigarnik, Von Restorff |
| Section "Everything in the course opens in the app": six terms with one sentence each, closing line | `dl` | Know whether my files will open (text, PDF, notebook, video, audio, code) | `RENDERING_REQUIREMENTS.md` | Chunking |
| Section "How to start": three numbered steps, link Open a course | `ol` | Know the first step, and that an account is optional | V4-CORE-01 | Goal gradient |
| Section "Keep your course. Lectale presents it.": body, What you keep, What you get | `h2`, `ul` | Learn what an instructor keeps and gets | Brief | Proximity |
| Repository and outline figure | `figure`, `pre` and `ul` | Picture how a folder becomes a course | Brief | Specifics beat abstractions |
| Create account (outlined) and Open a course by link (link) in instructors | `a` | Sign up, or try my own repository first | R17 | Hick |
| Section "Browse listed courses": body, Browse the catalog link | `h2`, `a` | Learn the catalog is optional and how to reach it | V4-CAT-01 | Jakob |
| Three example course cards: cover, title, "Example instructor", summary, language, "Example course" tag | `li.card`, one link per card named "{title}, example course" | See what a listed course looks like | V4-CAT-01, V4-CAT-05 | Specifics beat abstractions |
| Note "These are examples. They are not real courses." | `p.cap` | Not mistake examples for real work | Copy 4.4 | Honesty |
| Download rows: Web, Android, Windows, macOS, Linux with file name and size | `ul` of rows; one gold button (Open in browser), four outlined | Pick my platform | R21 | Hick: one row each |
| QR code with caption and printed URL (hidden under 45 rem) | `img` + `p` + link | Install on my phone from this screen | R22, NN/g QR | Not on the device that shows it |
| iPhone and iPad note | `p.note` | Know why no iOS file exists and what to do | Brief | Dead-end avoidance |
| SHA-256 line with link to the release page | `p` | Check what I downloaded | R21 | Trust |
| Privacy section: heading, text, link | `h2`, `p`, `a` | Know there is no tracking | V4-COST-06 | Peak-end |
| Footer: brand, description, six links, independence line, legal line | `footer`, `nav` "Footer" | Find legal pages; learn that Lectale is not GitHub | NN/g top ten 3 | Consistent help (WCAG 3.2.6) |

Not on the page, by decision: no testimonials, counters, logos of other products, newsletter box, cookie banner, chat widget, icons in lists, gradients.

## 6. States

A static page has few states; each is designed.

| State | What the reader sees | What they can do |
|---|---|---|
| Fonts loading | System serif and sans until woff2 swaps in (`font-display: swap`; both preloaded) | Read at once |
| No JavaScript | The landing page uses none | Everything |
| Phone width | Nav moves to a second row, still visible; preview shows the Contents bar with the ribbon and title instead of the pane; QR block hidden because the Android row is the direct link (NN/g) | Same tasks |
| Reduced motion | The ribbon is drawn at rest | Same |
| Forced colours | Outline ring and a bordered primary button replace shadows and fills | Same |
| Dark | Own palette; the QR tile stays dark on light | Same |
| Download not published yet | The button still links to `releases/latest`; GitHub shows the release list | Open the release page |

## 7. Wireframes

### Phone (390 px)

```
[mark Lectale]        Log in [Create account]
Catalog  Download  For instructors
Open the course.
Close the other tabs.
deck (3 lines)
[ Open a course ]
[ Browse courses ]
+---------------------------+  Sand mat
| Lectale                   |
| Contents  |ribbon Averages|
| lesson text ...           |
A lesson from an example course ...
Everything in the course opens ... (list, one column)
How to start (1 2 3 stacked) ... Instructors ... 2 example covers
Use Lectale on your device: Web, Android, ... (no QR)
No tracking / footer
```

### Desktop (1440 px)

```
[mark Lectale] Catalog Download For instructors                 Log in [Create account]

Open the course.                                   deck, 3 lines
Close the other tabs.                              [Open a course] [Browse courses]

+------------------------- Sand mat ---------------------------------------------+
|  +-- Lectale reader ----------------------------------------------------+      |
|  | Contents                                                              |      |
|  | Overview            |        Describing data                          |      |
|  | Describing data     |        Averages and spread (mulberry)           |      |
|  | |Averages and spread|        text, 18/30, 30 em ...                   |      |
+------------------------------------------------------------------------------+
Everything in the course     | Text      PDFs
opens in the app             | Notebooks Video
intro                        | Audio     Code
-------------------------------- Sand band ------------------------------------
How to start      1 Find a course   2 Read it   3 Add an account ...
Keep your course.            | repo tree | outline
Lectale presents it.         | [Create account] Open a course by link
Browse listed courses        | [cover] [cover] [cover]
Use Lectale on your device   Web [Open in browser]            [QR]
                             Android ... Windows ... macOS ... Linux ...
No tracking                  | text, link
-------------------------------- footer ----------------------------------------
```

## 8. Interaction and accessibility

- **Tab order:** skip link, Lectale home, Catalog, Download, For instructors, Log in, Create account, Open a course, Browse courses, [reader preview: none], Open a course (How to start), Create account (instructors), Open a course by link, Browse the catalog (teaser), card 1, card 2, card 3, Open in browser, Download for Android, Windows, macOS, Linux, release page, QR URL link, Read the privacy notice, footer links. Measured in the built page: 31 stops, in this order.
- **Landmarks:** banner, `nav` "Main", main, one `section` per h2 with `aria-labelledby`, `nav` "Footer", contentinfo. One h1; h2 per section; h3 for list terms and card titles. The preview is `aria-hidden`; its figcaption says what it shows.
- **Focus ring:** gold, 2 px, outside a 2 px Paper gap (box-shadow plus a transparent outline for forced colours). Card focus draws the ring around the whole card.
- **Targets:** every control at least 40 px high, most 44 px or more. The one under 24 px is the inline "release page" link inside a sentence (WCAG 2.5.8 inline exception).
- **Labels:** the logo link is "Lectale, home"; cards are "{title}, example course"; the QR image has a text alternative and the same URL is printed as a link.
- **Contrast:** measured by axe on every page in both schemes; the token plan's ratios apply (graphite 13.4:1, mulberry 7.15:1, gold button label 5.54:1, gold ring 4.92:1 on Paper).
- **Motion:** one moment, the ribbon in the preview unfurls once in 0.7 s after 0.5 s. No other animation. Reduced motion removes it. No scroll effects, no hover transitions.
- **No third-party request, cookie, inline script or inline style.** Verified with Playwright: 0 requests to other hosts, 0 cookies, 0 CSP messages under the R18 policy.

## 9. Copy

All text is from `../copy/landing.md`, with these additions for review by the copywriter:

| Where | Text | Why |
|---|---|---|
| Preview caption | "A lesson from an example course, open in Lectale. The gold ribbon marks the lesson you are reading." | A figure needs a caption; says what the ribbon means |
| Repository figure caption | "A repository folder on the left and the outline Lectale builds from it on the right." | Same |
| File lines | `lectale-android.apk, -- MB` and the three desktop equivalents | The task asks for a file name and size placeholder; real names and sizes come from the release |
| SHA-256 line | "Each download lists its SHA-256 checksum on the release page." | Security review R21 |
| QR caption | "Scan with your phone to get the Android app." | The code points at the releases page (copy question 1: the Android reading) |
| QR text alternative | "QR code that opens the Lectale downloads page on GitHub. The same link is printed below it." | Replaces the copy file's browser-version alternative |
| Auth error title | "The email or password is not correct." is the title and "Check both and try again, or reset your password." the text | Errors carry a title (token plan); this splits the copy file's sentence, adds no words |

Deviations from the copy file, with reasons:

- **No "Menu" button on small screens.** The three nav links stay visible in a second row. NN/g's homepage rules fault navigation hidden behind a menu link, and the row needs no script. Log in and Create account stay visible, as the copy file asks.
- **Catalog cards** show the language and the "Example course" tag as two separate items, not "English · Example course", so no middle-dot string is built.
- **Hook D** is built as `index-hook-d.html` for comparison; `HOOK=D node build.mjs` makes it the default.

## 10. Images

| Image | Source | Format | Decoded at |
|---|---|---|---|
| Logo | `docs/ux/brand` Ribbon Cut | Inline SVG, `currentColor` | Vector |
| Example covers (5) | `covers.py`: title as outlines in Source Serif 4 (opsz 28, weight 600) on Paper, Sand or mulberry, with one geometric motif | SVG in `<img>` (R20), 2:3, 480 by 720, 11 to 20 kB each | Vector; shown 250 to 310 px wide; `loading="lazy"`, empty `alt` because the title follows |
| No-cover placeholder | CSS box in Sand with the logo in Paper | Inline SVG | Vector; same 2:3 box so the grid does not move |
| QR code | `make-qr.mjs` with the `qr` package (MIT OR Apache-2.0, zero dependencies), 4-module quiet zone, dark on light in both schemes | SVG in `<img>`, 7 kB | Vector; decoded back to the URL with the package's decoder |
| Product preview | HTML and CSS | Live text | Not an image |

Covers outline their titles because an SVG in `<img>` cannot load web fonts. Bulgarian forms come from the font's `locl` feature, applied with the language set to `bg`.

## 11. Open questions

1. Hook H or D (both built)?
2. Does the QR code point at the releases page (as built) or at a stable Lectale URL that can redirect later (NN/g staleness rule)?
3. The Source Serif 4 woff2 is 428 kB roman plus 346 kB italic, because the licence reserves the name "Source" and the files ship unmodified. Subsetting needs a renamed family (owner decision). Italic is declared but unused on these pages, so it is not fetched.
4. The privacy, terms and accessibility pages and the operator name do not exist yet; the links and `{operator name}` stay placeholders.
5. Sizes show `-- MB` until a release exists.

## 12. Tokens and type scale (the token plan for this milestone)

Colour roles from `../token-plan.md`, written as CSS custom properties; no other value is used.

| Role | Light | Dark | Used for |
|---|---|---|---|
| Paper (`--paper`) | `#F4F1ED` | `#191B1A` | Page, reading surface, field fill |
| Sand (`--sand`) | `#E8E3DC` | `#262927` | Product mat, How to start band, footer, panels, hover, selected row |
| Graphite (`--ink`, `--ink-2`) | `#242725`, `#5A5F5B` | `#E9E5DE`, `#A9ADA7` | Text; field and outline-button borders (5.8:1 on Paper, above 3:1) |
| Mulberry | `#753E5E` | `#E0A7C0` | Logo mark, underlined links, the lesson title in the preview and the course title on app home |
| Gold | `#905E0C` (label white) | `#F3DDA4` (label graphite) | Primary button (Hero, Open in browser; app home Continue), ribbon, focus ring. Never text |
| Signal red | `#A3292E` | `#F2958E` | Wrong-credentials alert only, with an icon and a title |

Paper, Sand, graphite and mulberry are about 80 percent of the pixels. Hover is a Sand fill on outlined controls and an underline on the primary button, so no colour is derived.

**Typeface roles.** Source Serif 4 (variable, `wght` and `opsz`) for display, headings and every sentence a person reads; IBM Plex Sans for interface text (nav, buttons, labels, captions); IBM Plex Mono for file names and the repository tree. Self-hosted woff2, converted unmodified from the app's files (SIL OFL, licence files in `fonts/`).

**Scale.** Sizes follow the traditional printers' scale (Bringhurst, *The Elements of Typographic Style*, 2.1.2: 12 14 16 18 21 24 36 48 60 72), the same family of steps as the app's reading size of 18 over 30.

| Role | Size over line height | Face, weight, optical size | Tracking | Notes |
|---|---|---|---|---|
| Display (h1) | 72 over 74, fluid to 38 on phones | Serif 440, opsz 60 (40 on phones) | -0.03em | Two lines, one size and weight; `text-wrap: balance`. The opsz 60 design is drawn for loose fit, so it is tracked tight |
| Section heading (h2) | 48 over 53, fluid to 30 | Serif 480, opsz 48 | -0.02em | |
| Term, step, platform (h3) | 24 over 31 | Serif 560, opsz 24 | -0.008em | |
| Deck | 21 over 34 | Serif 400, opsz 21 | -0.003em | About 40 characters wide in the hero, set by the column |
| Reading | 18 over 30 | Serif 400, opsz 18 | 0 | Measure 30 em, about 68 characters |
| Short description | 16 over 26 | Serif 400, opsz 16 | 0 | Lists and card summaries |
| Interface | 15 over 24 (nav, labels), 16 (buttons, fields) | Sans 400 and 500 | +0.005em | Fields at 16 so iOS does not zoom |
| Small | 14 over 21 | Sans 400 | +0.008em | Captions, hints, meta |
| Mono | 14 over 22 | Plex Mono 400 | 0 | |

Dark mode subtracts 50 from every weight (`--wo`), as the token plan says, because light text on a dark ground looks heavier. Body weight is 400; weight marks hierarchy only. Line height is larger for serif (1.667) than for sans (1.6). Text is left aligned and ragged right; headings balance, paragraphs `text-wrap: pretty`; no all caps, no eyebrows, no justified text.

**Space and grid.** 8 px rhythm with a 4 px half step. 12 columns, 32 px gap (20 px on phones), page 1240 px with a 64 px gutter that falls to 20 px. Sections breathe unevenly on purpose: 128 px around reading sections, 96 around the catalog and privacy blocks, a full-bleed Sand band for the steps. Asymmetric splits (5 and 7 columns, 4 and 8, 8 and 3) replace centred stacks.

**Radii by role.** 5 px (badges, covers, focus ring of inline links), 8 px (buttons, fields, QR tile), 12 px (mat, panels, alerts). No shadows; one separation method per surface (Sand fill, or a 1.5 px graphite outline on fields and the menu panel).

**Motion.** The ribbon unfurls once (0.7 s). Everything else is still. Reduced motion removes it.

**The memorable element: the ribbon.** In the logo, in the reader preview on the lesson being read, and on app home beside the last-opened lesson. It appears at most once per view, always gold, always with the swallowtail cut (clip-path, 8 px wide).

## 13. Check against the anti-generic list

| Tell (`frontend-design`, `ai-tells.md`) | Answer |
|---|---|
| Cream, high-contrast serif, terracotta | Warm grey Paper at low chroma, mulberry, gold on three jobs; the serif carries text and display, in a reading face chosen by the owner |
| Near-black with acid accent | Dark scheme is a separate deep-grey palette with a pale gold accent |
| Broadsheet hairlines | No rules at all; Sand surfaces and whitespace |
| SaaS card kit | One kind of card (course covers, unboxed); no shadows; no icon tiles; no three equal feature cards: the formats are a definition list, the steps a numbered sequence |
| One accented word in the headline | The headline is two plain sentences, same size and weight |
| Eyebrows, caps labels, middle-dot strings, trailing arrows | None |
| Numbers 01 02 03 | Only on the steps, which are a real sequence, and plain 1 2 3 |
| Fade-and-slide on every section | One ribbon unfurl, none elsewhere |
| Generic hero with a gradient or stock photo | The hero shows the product: a real reading view in HTML, with the lesson text set in the reading face |
| Fake stats and testimonials | None; example courses are labelled as examples three times |

Pre-ship checks: (1) removed: Menu button, icons on the format list, hero second visual; (2) Lectale's own element is the swallowtail ribbon; (3) every colour and size traces to section 12; (4) states and reduced motion are in section 6; (5) copy has no filler verbs or invented numbers (the lesson text uses sample scores inside an example lesson).

## 14. Sibling pages in the concept folder

Mocks of app screens, for the owner to judge. They become Flutter screens after review, each with its own spec.

| Page | Purpose and primary action | Elements and the task each serves | States built |
|---|---|---|---|
| `catalog.html` | Find a course. Primary: the search field, then a card | Search field and Language and Subject selects (narrow the list); result count in a live region; cards with covers (recognise a course); "These are examples" note; empty state with Clear search; one card has no `cover` and shows the placeholder | Default; no results (`?q=quantum`); filter by script, plain GET without |
| `login.html` | Log in. Primary: Log in (gold) | Email and Password with Show password (enter credentials, paste allowed, `autocomplete` hints); Forgot your password?; Create account link | Default; wrong credentials (same text for unknown email); unconfirmed email with Send the link again; session expired notice (R12) |
| `create-account.html` | Create an account. Primary: Create account | Email; Password with the 12-character hint; consent line with Terms and Privacy notice; Log in link | Default; "Check your email" (R3: identical for new and existing addresses, with Log in and Reset your password links) |
| `app-home.html` | Continue reading, or open a course. Primary: Continue (gold) | Greeting; Continue reading with cover, ribbon and lesson (resume, Zeigarnik); Your courses (instructor rows with Listed or Unlisted); Connect a repository; open-by-link field with Open course (outlined, because Continue is primary); Catalog link and account menu in the top bar | Default; account menu open with Log out and Log out of all devices (R13); new account (`app-home-empty.html`: field and Open course become primary, Browse the catalog beside it) |

Catalog entry points are deliberately single: the top bar link on signed-in pages. The empty state adds the button the copy asks for because the screen has nothing else to offer.
