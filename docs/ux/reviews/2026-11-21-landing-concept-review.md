# Design review: landing concept and entry screens

| | |
|---|---|
| **Date** | 2026-11-21 |
| **Reviewer** | design-reviewer agent; Codex second opinion folded in (marked "Codex") |
| **Pages** | `docs/ux/concepts/landing/`: `index.html`, `index-hook-d.html`, `catalog.html` (and `?q=quantum`), `login*.html` (4 states), `create-account.html`, `create-account-sent.html`, `app-home*.html` (3 states) |
| **Judged against** | Brief `../concepts/2026-11-21-landing-brief.md`; copy `../copy/landing.md`; research `../../research/2026-11-21-landing-references.md`; security R16 to R22; spec `../screens/landing.md` (section 12 is the token plan for this milestone); `../token-plan.md` |
| **Evidence** | `landing-concept/*.webp`, all captured by this review (Chrome, `deviceScaleFactor: 1`, `reducedMotion: reduce`, 1440, 768 and 390 px, light and dark; 78 full-page captures, the cited ones saved) |

## Verdict

**Fix required.** The page is accessible, private and clear in five seconds, and the type pairing works. It still doesn't look finished, though. The product preview, which is meant to be the proof, has a CSS bug and cuts text in half. The hero's two columns don't share a top edge or a baseline. Section gaps stack to 214 to 256 px of empty Paper. The download section is a wall of five identical buttons with "-- MB" placeholders. Two security requirements (R21, R22) are not met as written, and the self-converted fonts fall under the OFL's "Modified Version" definition.

**Five-second test:** pass. "Open the course. Close the other tabs." with the deck says what Lectale is, that it is free and that no account is needed, and there is one gold action. **Polish test:** fail, for the reasons in the hard stops and majors below.

## Automated and measured results

| Check | Result |
|---|---|
| axe-core 4.x, tags wcag2a, wcag2aa, wcag21a/aa, wcag22aa, best-practice; 13 pages × 3 widths × 2 schemes = 78 runs | **0 violations.** "Incomplete" colour-contrast items on the catalog selects (CSS-gradient chevrons), the open account menu and Hook D at 390. I measured those by hand and they pass (table below) |
| Playwright HAR of `index.html`, scrolled to the end | **10 requests, all to the preview origin** (html, css, 3 fonts, logo, QR, 3 covers); **0 `Set-Cookie`, 0 cookies, `document.cookie` empty, localStorage and sessionStorage empty, 0 CSP console messages** under the R18 policy. Fonts are 697 kB of the 799 kB transferred |
| Tab walk, `index.html` at 1440, light and dark | 31 stops in exactly the order of spec §8; ring visible on all 31; none obscured (`20-tab-walk-index-1440-light.webp`) |
| Tab walk, `login.html` at 1440 | 8 stops: skip, brand, Email, Password, Show password, Log in, Forgot your password?, Create account; ring on all (`21-tab-walk-login-1440-light.webp`; resting state `16-login-1440-light.webp`) |
| Targets | All ≥ 24 × 24. Smallest: inline "release page" 81 × 18 (inline exception, 2.5.8). Card title links are 29 px tall, but `::after` makes the whole card the target |
| 200% zoom at 1440 (720 CSS px, DPR 2) on index, login, catalog, create-account, app-home | No horizontal scroll (`22-index-200-percent-zoom.webp`). At 320 px: none either |
| Text spacing override (WCAG 1.4.12) at 390 | No clipping, except the `aria-hidden` preview `.app`, which is decorative |
| `prefers-reduced-motion` | `reduce`: `animation: none` on both ribbons. `no-preference`: `unfurl 0.7s` on the two ribbon elements (only one is displayed per width). No other animation or transition. Pass |

### Contrast, every pair found on the pages (computed from rendered colours, WCAG 2 ratio)

| Pair | Light | Dark | Target |
|---|---|---|---|
| Graphite on Paper (body, nav, QR caption) | 13.40 | 13.79 | 4.5 |
| Graphite on Sand (band, footer, note, skip link) | 11.82 | 11.71 | 4.5 |
| Muted on Paper (captions, meta, pane module rows) | 5.79 | 7.60 | 4.5 |
| Muted on Sand (outline module rows, footer description) | **5.11** (lowest on the site) | 6.45 | 4.5 |
| Mulberry on Paper (links, QR URL, preview title) | 7.15 | 8.62 | 4.5 |
| Mulberry on Sand (step link, footer links) | 6.31 | 7.32 | 4.5 |
| Button label on Gold | 5.54 (white) | 11.27 (graphite) | 4.5 |
| Signal red on Sand (error title) | 5.65 | 6.62 | 4.5 |
| Outline-button, field and badge borders on Paper | 5.79 | 7.60 | 3 |
| Gold on Sand: the ribbon on the current row, and the focus ring on the Sand band and footer | 4.34 (from the token plan; not used for text anywhere) | 10.98 | 3 (non-text): pass |
| QR modules `#242725` on tile `#F4F1ED` | 13.40 | same (the tile does not invert) | pass |

## Ledger against the token plan (spec §12)

| Point | Plan says | Image shows (file, region) | Verdict and fix |
|---|---|---|---|
| Type scale | Printers' scale 12 14 16 18 21 24 36 48 60 72; preview lesson title is the app's 30 px display | `01-hero-1440-light-annotated.webp`, preview, "Averages and spread" is the same size as the body text | **Drift (hard stop H1).** Measured: 18/30 px. See H1 |
| Type faces | Plex Mono for file names and the repository tree | `04-instructors-1440-light.webp`, the left half of the Sand panel is set in a wide DejaVu-like mono | **Drift (H1).** `code` inherits the UA `monospace` (computed `font-family: monospace`) |
| Spacing rhythm | 8 px grid; "128 around reading sections, 96 around catalog and privacy" | `05-teaser`, `07-download`, `08-privacy-footer`: 214 to 256 px of empty Paper between sections; platform rows 109 px apart | **Inconsistent (H3).** Paddings of neighbouring sections add up, and `.plat__name` keeps the UA `h3` margins of 24 px |
| Radii and elevation | 5 covers and badges, 8 buttons, 12 mat and panels; no shadows; one separation method | All screenshots: radii as planned, no shadows | Pass. The exception is the "Python for lab data" cover, which carries a 3 px graphite frame that no other surface has (`05-teaser`, right card; `14-catalog`) |
| Palette and 80% rule | Paper, Sand, graphite, mulberry; gold only on the primary button, ribbon and ring | `01`, `02`, `07`, `19`: gold appears once per view: hero button, Open in browser, Continue, the ribbon | Pass; no stray hex in `site.css` |
| Memorable element | The swallowtail ribbon, once per view | `01` pane row; `11` phone bar; `19` beside the last lesson | Pass, but the ribbon is the only crafted detail in the preview; the preview around it reads as a wireframe (M2) |
| Density at 390 | Same tasks; QR hidden; nav in a second row | `11-13-phone-390-*.webp`; entry screens `23-entry-screens-390.webp` hold up (single column, full-width fields, primary visible without scrolling): nav row good; downloads take about 1,300 px for five platforms, three of them desktop | **Too long (M3)** |
| Dark parity | Own palette, −50 weight, QR tile stays light | `02-hero-1440-dark`, `06-teaser-1440-dark`: parity is good; two light covers glare on the dark ground | Pass, with a minor point (m9) |

## Hard stops (block merging)

**H1. Type-scale drift, three causes.**
- *Evidence:* `01-hero-1440-light-annotated.webp`, preview: the lesson title renders at 18/30 px instead of 30/36. `04-instructors-1440-light.webp`: the tree is not in Plex Mono. Off-scale sizes in use: 20 (`.brand`), 17 (`.app__top`), 13 (`.badge`, `.qr .url`), 19 (`.mine a`), 22 (`.sidebox .t-h3`), 28 (`.t-h4`, `.cont__title`), 44 (`.auth .t-h2`).
- *Rule:* visual-review-loop hard stop "type-scale drift"; spec §12 scale.
- *Fix* (`site.css`):
  - `.read p:not(.read__mod)` (specificity 0,2,1) overrides `.read__title`. Change it to `.read p:not(.read__mod, .read__title)`, or make the title an element other than `p`.
  - Add `.t-mono code, pre code { font: inherit; }`.
  - Snap the off-scale sizes: brand 21, badge and QR URL 12 or 14, `.mine a` 18, `.sidebox .t-h3` 21 or 24, `.t-h4` and `.cont__title` 24, `.auth .t-h2` 36 or 48. Alternatively, add each one to the §12 table with a reason.

**H2. Clipped primary content in the preview.**
- *Evidence:* `01` and `02`, bottom of the mat: "The mean is the same. The classes are not. How far the values wander" is sliced through the x-height. `03-hero-768-light.webp`, pane: "Weekly problems" is cut in half. `11-phone-390-light-top.webp`: "though. Two classes can both" is cut.
- *Rule:* hard stop "clipping of primary content"; the preview is item 2 in spec §4.
- *Fix:* `.shot__mat { height: auto; }`. Let `.read` end on a whole paragraph (two paragraphs at ≤ 45 rem) and the pane on a whole row. To keep the frame cropped, crop at a row boundary: `height` equals the top bar plus a whole number of 30 px lines.

**H3. Two spacings for the same relationship.**
- *Evidence:* the gap between one section's last line and the next h2 measures 128, 256, 256, 214, 214 and 214 px at 1440 (`05`, `07`, `08`). `07-download-1440-light.webp`: rows are 109 px tall because `.plat__name` keeps 24 px UA margins above and below. Fluid paddings produce 57.6 and 86.4 px, which are not on the 8 px grid.
- *Rule:* hard stop "inconsistent spacing"; spec §12, "8 px rhythm".
- *Fix:*
  - `.section + .section { padding-top: 0; }`, or give sections `padding-block-end` only, so each boundary is one token: `--s10` (128) between reading sections and `--s9` (96) around catalog and privacy.
  - `.plat__name { margin: 0; }`.
  - Replace `clamp(var(--s7), 6vw, var(--s9))` and `clamp(var(--s6), 4vw, var(--s8))` with a stepped token per breakpoint.

**H4. Placeholder copy visible.**
- *Evidence:* `07-download-1440-light.webp`: "lectale-android.apk, -- MB" and three more like it. `08-privacy-footer-1440-light.webp`: "© 2026 {operator name}".
- *Rule:* hard stop "invented copy, placeholder boxes".
- *Fix* (`build.mjs`):
  - Print the file name only until a release exists (`lectale-android.apk`), and add the size at build time from the release API.
  - Leave out the © line until the owner gives the name, and list it under "Waiting on the owner".

**H5. R22 not met: the QR code doesn't encode the canonical host.**
- *Evidence:* `make-qr.mjs` encodes `https://github.com/Milkeles/lectale/releases/latest` (`07`, right column). R22: "It encodes the canonical HTTPS URL". The research note's staleness rule says the same.
- *Fix:*
  - Encode `https://<canonical host>/get/android`, a Worker static redirect to `releases/latest/download/lectale-android.apk`, and print that URL under the code.
  - The caption "Scan with your phone to get the Android app." becomes true: today the code lands on a GitHub page listing every asset.
  - CI decodes the SVG, as R22 asks.

**H6. Fonts: the self-converted WOFF2 files are Modified Versions under reserved names.**
- *Evidence:* both licence files in `fonts/` define "Modified Version" as a derivative made "by changing formats or by porting the Font Software to a new environment". Condition 3 says no Modified Version may use the Reserved Font Name ("Source"; "Plex"). The README calls the files "converted unmodified", but under that definition a TTF-to-WOFF2 conversion is a modification. (The SIL OFL FAQ is reported to have a WOFF-specific answer; its hosts returned 403 through the proxy, so that is **not verified**.) Table comparison with fontTools:

| File | Local vs app TTF | Local vs official WOFF2 | Official source |
|---|---|---|---|
| `SourceSerif4Variable-Roman.woff2` / `-Italic` | only `head` differs, `DSIG` dropped | **only `head` differs**; same version 4.005, axes, 1464 / 1093 glyphs | `raw.githubusercontent.com/adobe-fonts/source-serif/release/WOFF2/VAR/SourceSerif4Variable-{Roman,Italic}.ttf.woff2` (429,100 and 346,688 bytes; fetched, HTTP 200) |
| `IBMPlexSans.woff2` | only `head` differs (from litse-ui's `IBMPlexSans.ttf`, Version 3.201, `wdth` 75–100) | **different font**: `@ibm/plex-sans-variable` 1.0.0 is Version 3.000, family "IBM Plex Sans Var", `wdth` 85–100, 1082 glyphs. `@ibm/plex-sans` 2.0.0 ships static WOFF2 only | npm `@ibm/plex-sans-variable` or `@ibm/plex-sans` |
| `IBMPlexMono-Regular.woff2` | `glyf`/`loca` reconstruction and `DSIG` only | different build: npm 2.5.0 has 1207 glyphs, local has 1033 | npm `@ibm/plex-mono` 2.5.0, `fonts/complete/woff2/IBMPlexMono-Regular.woff2` |

- *Fix:*
  - Replace both Source Serif files with Adobe's WOFF2. The content is identical, so nothing changes visually.
  - Replace Plex Mono with IBM's WOFF2.
  - For Plex Sans, the owner chooses between two options. (a) IBM's variable WOFF2: `font-stretch: 85% 100%`, family name in CSS unchanged. The app should then move to the same file so web and app match. (b) The static Regular, Medium and SemiBold WOFF2 from `@ibm/plex-sans` 2.0.0.
- **Warning:** every `@ibm/plex-*` npm package runs `postinstall: ibmtelemetry` (telemetry endpoint `www-api.ibm.com`). Take the files from the tarball (`npm pack`, or `npm install --ignore-scripts`), and never run the install script.
- Update the README line and spec §11 open question 3.

## Majors

**M1. Hero columns share no edge (the design lead's flag).**
- *Evidence:* `01-hero-1440-light-annotated.webp`. The deck's cap top is at y 147, the headline's at y 185: the deck starts 38 px higher. The buttons end at y 314, 6 px below the headline baseline (~308). `.hero__grid { align-items: end }` aligns the boxes, not the type. Hook D is worse: its 4-line deck starts 68 px above the headline.
- *Rule:* alignment and baselines; Codex's #2 agrees.
- *Fix (pick one):*
  - (a) `.hero__grid { align-items: start }` plus `.hero__title, .hero__aside .t-lead { text-box: trim-both cap alphabetic; }` (Chrome 133+, Safari 18.2+; harmless elsewhere), so both cap tops sit on one line. Then let the buttons end where they end.
  - (b) Recommended for calm: put the deck and buttons **under** the headline in columns 1–7, which is the pattern on all six comparables. Use column 9–12 for nothing, or start the preview higher.

**M2. The product preview reads as a wireframe, not proof.**
- *Evidence:* `01`, `02`, `03`.
  - The app bar holds the logo and an empty 1,100 px strip: no course title and no controls.
  - "Contents" floats as a bare label.
  - The pane has three left edges (164, 168 and 176 px).
  - The reading column is centred in a wide empty pane.
  - A 40 px Sand mat dominates in dark mode (Codex #1, #10).
- *Rule:* NN/g "show real content"; Aesthetic-Usability.
- *Fix* (`build.mjs` preview, `site.css` `.app*`):
  - Put the course title "Introduction to statistics" in the app bar (Plex 15/500) and a muted "3 of 9" place indicator, which is real Goal-Gradient data.
  - Align module rows, lesson rows and "Contents" to one 12 px inset.
  - Left-align `.read` at 48 px from the pane, the way the reader really sits.
  - Reduce the mat padding to `--s5` (24).
  - After H1, the 30 px mulberry title gives the reading view its hierarchy back.

**M3. The download section is a wall, and too long on phones.**
- *Evidence:* `07-download-1440-light.webp`: five 240 px buttons, four of them identical outlines, and "From GitHub Releases." three times. `13-phone-390-light-bottom.webp`: Windows, macOS and Linux each take a full 239 px block on a phone. A wrapped mono URL sits beside the QR code.
- *Rule:* Hick; spec §5 "one row each"; Codex #6, #7.
- *Fix:*
  - Rows become name, file name and button on one 64 px line. Say "Desktop builds come from GitHub Releases." once under the list, beside the checksum line.
  - At ≤ 45 rem, show Web and Android as full rows, and Windows, macOS and Linux as three `a.more` links in one wrapping flex row under a single "Desktop" heading.
  - Shorten the printed QR URL with H5 so it fits on one line.

**M4. R21 is only partly met.**
- *Evidence:* `07`, under the iPhone note: "Each download lists its SHA-256 checksum on the release page." R21 also asks for a link to the checksums file and the Android signing-certificate SHA-256.
- *Fix:* link `releases/latest/download/SHA256SUMS`, and add the fingerprint line, generated at build time. Until a release exists, leave the line out rather than show a placeholder (H4).

**M5. Every section uses the same split, so the page has one rhythm.**
- *Evidence:* `09`, `04`, `05`, `08`. Formats, instructors, the teaser and privacy all use "h2 left, content right"; the 2 × 3 format grid has six equal-weight headings, and the 72 px light numerals read as a template (Codex #8).
- *Rule:* the ai-tells "same component repeated"; NN/g "lead users down the page".
- *Fix:*
  - Formats: make the list one reading column under the h2 (columns 1–7, terms inline in semibold serif, `dl` kept).
  - Steps: numerals 36 px, `--ink-2`, baseline-aligned with the h3 (m3).
  - Privacy: fold it into the footer's top row as one sentence plus a link, which shortens the page by about 400 px.
  - That leaves the preview, instructors and downloads as the three visual moments.

**M6. Catalog density and the no-cover state.**
- *Evidence:* `14-catalog-1440-light-top.webp`: three 392 × 588 px covers mean one row per screen at 1440. `15-catalog-1440-light-placeholder.webp`: "Field methods in ecology" shows a pale logo on Sand at 1.13:1, which looks like a broken image.
- *Fix:*
  - `.catalog .cards { grid-template-columns: repeat(4, minmax(0, 1fr)); }` from 70 rem, and `repeat(auto-fill, minmax(13rem, 1fr))` below.
  - Draw the placeholder like the other covers: the course title in Source Serif 600 mulberry on Sand, generated at runtime as text in the same 2:3 box, with no logo.

**M7. The repository figure doesn't show the mapping.**
- *Evidence:* `04-instructors-1440-light.webp`: the tree lines and outline rows don't line up (`describing-data/` at y 660, "Describing data" at y 644). `12-phone-390-light-middle.webp`: the caption says "on the left … on the right" while the panels are stacked.
- *Fix:*
  - Build it as one grid with a row per source line: `README.md` → Overview, `describing-data/` → Describing data, `averages-and-spread.md` → Averages and spread, `histograms.pdf` → Histograms, `course.yaml` → empty (it is the outline).
  - Change the caption to "A repository folder and the outline Lectale builds from it."

## Minors

| # | Evidence | Fix |
|---|---|---|
| m1 | `11-phone-390-light-top.webp`: hero buttons stack at 172 and 184 px wide | `@media (max-width: 30rem) { .hero .actions .btn { flex: 1 1 100%; } }`, or follow Codex #3: Browse courses as `a.more` beside the button |
| m2 | `05-teaser-1440-light.webp`: "Browse listed / courses" leaves one word on line 2; 80 px holes above the meta in cards 1 and 3 | `.teaser__head` span 5 and `.teaser__cards` span 7; `.card__meta { margin-top: var(--s3); }` instead of `auto` |
| m3 | `10-formats-steps-768-light.webp`: step numerals sit about 17 px below the h3 baseline | `.steps li { align-items: first baseline; }` in the ≤ 50 rem grid |
| m4 | `07`: `.plat__text` is Plex 15 while the matching `.formats dd` is Serif 16 | Give `.plat__text` the `.t-card` role, so all descriptive sentences use one voice (spec §12 "every sentence a person reads") |
| m5 | `09`, How to start band: the lone "Open a course" link has 48 px above and 128 px of empty band below | Put it on the step 1 line ("Paste a course link" links to `/app/`), or remove it (the hero carries it) |
| m6 | `17-login-expired-1440-light.webp`: the notice sits above the h1, while `login-error` puts its alert below the h1 | Move the notice under "Log in" in `build.mjs`, so the h1 is always first and alerts have one place |
| m7 | `18-create-account-1440-light.webp`: the consent line comes after the button | Put it above `Create account` (people accept before they act) |
| m8 | `19-app-home-1440-light.webp`: "Continue: Averages and spread" repeats the line above it; titles under Your courses are graphite and underlined, while the Continue title is mulberry | Label the button `Continue reading` with `aria-describedby` on the lesson line (Codex #9); make course titles mulberry, as the plan says |
| m9 | `06-teaser-1440-dark.webp`: two light covers glare on the dark ground; the Python cover's 3 px frame | `covers.py`: drop the frame and use the Sand ground; accept the light art as instructor content |
| m10 | `20-tab-walk-index-1440-light.webp`, stops 3–6: the ring touches the glyphs at the sides | `.nav a, .account a:not(.btn) { padding-inline: var(--s2); margin-inline: calc(-1 * var(--s2)); }` |
| m11 | `create-account.html`, `login.html`: "Show password" has `aria-controls` but no pressed state | Flutter spec: expose a toggled state (`aria-pressed` on the web mock) |
| m12 | `serve.mjs` CSP has `script-src 'self'` for every page and leaves out `upgrade-insecure-requests` and the R18 companion headers | Production `/` sends `script-src 'none'` plus the R18 headers; `catalog.html` alone needs `'self'` |
| m13 | HAR: 697 kB of fonts, with 658 kB preloaded on first paint | Record it as an owner decision (spec §11 q3); preload only the roman serif, and let Plex swap in |

## Codex second opinion (read-only, 7 images)

Accepted:
- #1: preview crop and realism, folded into H2 and M2.
- #2: hero alignment, folded into M1.
- #4: section gaps, folded into H3.
- #6 and #7: download rows and placeholders, folded into M3 and H4.
- #8: numerals, folded into M5.
- #9: Continue label, folded into m8.
- #10: mat inset, folded into M2.
- #3: partly accepted as m1.

Rejected:
- #5 (remove titles from covers, use 4:5): `course.cover` is whatever the instructor commits, and titled 2:3 covers are the realistic case. Spec §10 fixes 2:3.

## Pre-ship checks (`ai-tells.md`)

1. **Decoration to remove:** the 72 px step numerals, the oversized Sand mat, the lone step link, and the separate privacy section (M5).
2. **Lectale's own element:** the ribbon. It is right, but the preview around it must be raised to the same craft (M2).
3. **Every size and colour traced to §12:** colour yes; type no (H1); spacing no (H3).
4. **States and reduced motion:** present and verified.
5. **No invented numbers or filler copy:** fails on "-- MB" and "{operator name}" (H4).

## Images cited

All in `docs/ux/reviews/landing-concept/`: `01-hero-1440-light-annotated`, `02-hero-1440-dark`, `03-hero-768-light`, `04-instructors-1440-light`, `05-teaser-1440-light`, `06-teaser-1440-dark`, `07-download-1440-light`, `08-privacy-footer-1440-light`, `09-formats-steps-1440-light`, `10-formats-steps-768-light`, `11`/`12`/`13-phone-390-light-*`, `14-catalog-1440-light-top`, `15-catalog-1440-light-placeholder`, `16-login-1440-light`, `17-login-expired-1440-light`, `18-create-account-1440-light`, `19-app-home-1440-light`, `20-tab-walk-index-1440-light`, `21-tab-walk-login-1440-light`, `22-index-200-percent-zoom`, `23-entry-screens-390` (all `.webp`).
