# Landing hero review: open book with orbiting quotes

| | |
|---|---|
| **Stage** | Built page, before the owner sees it (`visual-review-loop` steps 2 to 4) |
| **Reviewer** | design-reviewer, with a Codex read-only second opinion |
| **Date** | 2026-11-22 |
| **Build** | Worktree `lectale-codex-hero2`, uncommitted diff on `70d08b8`: `apps/site/src/partials/hero.html`, `src/hero-quotes.js`, the hero block of `src/site.css`, `src/art/open-book*` |
| **Checked against** | Approved image (`hero-2026-11-22/approved-1440-light.webp`; copy since changed, as agreed); `spec/tasks/m2-site-hero.md`; `docs/ux/token-plan.md`; `docs/ux/screens/landing.md` §8 and §12; `docs/ux/inventory.md` "Keyboard: every screen"; WCAG 2.2 AA; `screen-spec/references/ai-tells.md` |
| **Method** | `npm run build`, `python3 -m http.server`, Playwright with Chrome at 1x. Widths 1440, 1280, 1024, 768, 390 and 320, light and dark; reduced motion; 200 percent zoom (720 CSS px at 2x). The orbit was frozen with the Web Animations API (`currentTime`) at 0, 18, 36, 54, 72 and 90 s. Every 0.5 s over two laps (144 s), card boxes were measured against the book, each other, the hero text lines, the pause button and the content column. The site CSP from `src/_headers` was injected on the document response. |

## Verdict: fix required

The book, rings, dots, cards and pause button match the approved image, and the accessibility basics pass. Ring, `aria-pressed`, 44 px target, reduced motion, screen-reader list and CSP are all correct. What fails is the orbit geometry. The ellipse is wider than the box it is laid out in, so moving cards cover the lead paragraph, slide under the pause button, leave the content column and make the page scroll sideways at 768 px. There are also three token drifts: a fluid headline size, 12 px credits and a 40 px gap.

## Hard stops

### H1. Cards cover the lead paragraph at 1440 (clipping of primary content)
- **Evidence:** `1440-light-t54.webp` and `1440-dark-t55_5-crop.webp`, left middle: the Tagore card hides "Anyone ca|n". `1440-light-t20_5-crop.webp`: the Thoreau card does the same. The sweep found an overlap with the lead's text lines in 52 of 288 samples, about 18 percent of every lap. The worst case was 536 px² (Tagore at 55.5 s, Thoreau at 21.5 s, Descartes at 93 s). At rest (`1440-light-t0.webp`), the Montessori card's left edge is at x 665 and the lead's line ends at x 662, a 3 px gap.
- **Cause:** `.hero__rings, .hero__quote-track` are `width: 34rem` (544 px) inside `--orbit-width: 40.25rem` (644 px), so a 12 to 14.5 rem card centred on the ellipse's ends overhangs the art column by about 60 px each side. That overhang falls into the 32 px grid gap and the text column.
- **Fix (`site.css`, `.hero__rings, .hero__quote-track` inside `@media (width > 47rem)`):** size the ellipse so that ellipse plus half the widest card fits the column. Try `width: 29rem; height: 13rem` and re-tune the `--quote-anchor` offsets. The approved image has its ellipse about 490 px wide with the cards inside 696 to 1340. Add a Playwright test that steps `document.getAnimations()` through a lap and asserts every visible `.hero__quote` box lies inside `.hero .wrap`'s content box and never intersects the Range rects of `.hero__lead` and `.hero__title`.

### H2. Cards leave the content column, and the page scrolls sideways at 768 px
- **Evidence:** `1440-light-t0.webp`, `1440-light-t18.webp` and `1440-dark-t0.webp`, right edge: the Comenius and Tagore cards end at x 1371 to 1394, past the header's right edge (Create account, x 1340), by up to 54 px. `768-light-t54.webp`, left: the Tagore card starts at x 12, inside the 32 px gutter. At 768 px, `scrollWidth` reaches 804 to 828 px over a lap and `scrollTo(200, 0)` scrolls by 60 px: a horizontal scrollbar on a tablet, or at 200 percent zoom on a 1536 px screen. At 1440, `scrollWidth` swings between 1440 and 1462 as the cards move, so a classic-scrollbar browser shows a scrollbar that flickers in and out.
- **Fix:** the H1 geometry fix. Also add `overflow-x: clip` to `.hero` as a guard, not as the fix, because clipping a card is itself a defect. Extend the H1 test to 768 and 1024.

### H3. Type-scale drift: the headline is fluid, and the card text has no role in the plan
- **Evidence:** the computed `.hero__title` size is 70.56 px at 1440 (about 67 px at 1366), from `font-size: min(var(--display), max(var(--t48), 4.9vw))`. `landing.md` §12 says display is 72 above 70 rem and "nothing is fluid between steps". The approved image is 72 px. Credits are 12 px IBM Plex Sans (`.hero__quote span`), but the plan's Small role is 14/21 and 12 px is only for the Mono QR URL. Quotes are 16/20 (`.hero__quote blockquote`, line height 1.25), but Short description is 16/26.
- **Fix:** in `.hero__title`, delete the `font-size` line so `.t-display` gives 72. At 72 px the headline needs about 500 px, and the column is 564 px. For the cards, either set `.hero__quote span { font-size: var(--t14); line-height: 1.5 }` and `.hero__quote blockquote { line-height: 1.5 }`, or have the owner add a "Quote card" role (16/21 serif italic, 12/16 sans credit) to `landing.md` §12, because the approved image uses small credits. Don't ship sizes that are in neither.

### H4. Spacing off the scale
- **Evidence:** the gap from hero to preview is 40 px at 1440 (`.hero__intro` bottom 528, `.shot` top 568), from `.hero .shot { margin-top: calc(var(--s6) + var(--s2)) }`. 40 is not a step (4 8 12 16 24 32 48 64 96 128), and §12 says the hero and the preview are 64 px apart. The hero's top padding changed from `--s8` to `--s6` (32 px). §12 says 64 on desktop.
- **Fix:** `.hero .shot { margin-top: var(--s8) }` and `.hero { padding-top: var(--s8) }`, 32 px on phones, as before. If the approved composition needs less, change §12 first.

## Majors

### J1. Cards pass under the pause button
- **Evidence:** `1440-light-t12_5-crop.webp`: the pause glyph sits on "without" in the Tagore card. Measured in 76 of 288 samples (about 38 s of every 144 s) at every width with the orbit. The button stays on top (`z-index: 3`), so focus is never obscured, but the control and the quote both become hard to read. The approved image keeps the top-right corner clear.
- **Fix:** H1's smaller ellipse should clear the corner, and the H1 test should assert no intersection with `.hero__pause`. Also give `.hero__pause` a `background: var(--paper)`, so the glyph stays legible if a card ever touches it.

### J2. The quote card uses three separation methods (AI-tell: "shadow plus border plus tint")
- **Evidence:** `.hero__quote` has a hairline border, `box-shadow: 0 1px var(--hair)` and `background: color-mix(in srgb, var(--paper) 94%, white)`. The token plan says "No shadows… one separation method", and every colour must be a role. The tint is 1/255 off Paper in light, so it is invisible. In dark it equals Sand. The rings use `color-mix` too.
- **Fix:** `.hero__quote { background: var(--paper); box-shadow: none }` and keep the hairline border. For `.hero__rings::before/::after`, use `--hair` or add a named `--orbit-line` token to `landing.md` §12.

### J3. At 1024 to 1312 px the composition stacks
- **Evidence:** `1280-light-t0.webp`: below 82 rem (1312 px) `.hero__intro` becomes one column. The orbit sits centred under the buttons, and the preview drops from y 568 to y 904. A 1280 laptop never sees the approved side-by-side layout. Cards stay inside the column at 1024 and 1280.
- **Fix:** with the narrower ellipse from H1, lower the breakpoint in `@media (max-width: 82rem) .hero__intro` to the width where 72/60 px headline, 32 px gap and orbit still fit, about 64 rem. Or have the owner accept the stack for tablets and small laptops and record it in `landing.md` §7.

### J4. Credits wrap in the middle of a name
- **Evidence:** `1440-light-t0.webp`, the Montessori card shows "trans. Anne / E. George". The Comenius card breaks well, after the comma.
- **Fix (`hero.html`):** mark up each credit as `<span>Maria Montessori</span> <span>trans. Anne E. George</span>` and give `.hero__quote span span { white-space: nowrap }`, or put the translator on its own line. Add `text-wrap: pretty` to `.hero__quote blockquote` to avoid "wise." alone on a line (Comenius).

## Minors

- **Screen-reader credits regressed:** the `.vh` list changed "translated by" to "trans.", which screen readers read as "trans". Restore "translated by" in the `.vh` list only.
- **Book proportion:** the artwork is about 15 px shorter than the approved book at the same width (256×121, against about 137 px tall in `approved-1440-light.webp`). It is the right classic book; check the crop of `open-book.webp` and whether the pages were flattened.
- **Two motions on one screen:** the orbit and the ribbon's unfurl both play. `landing.md` §8 ("No other animation") and §12 Motion still describe the ribbon only. The orbit is owner-approved, so record it in §8 and §12, and in the token plan's memorable-element section, so later reviews don't flag it.
- **Magic offsets:** `--quote-anchor` values (0.6875rem, 2.375rem, 2.625rem, 4.125rem) and `--orbit-width: 40.25rem` are off the scale. They are tolerable as positions, but they show the geometry was tuned by hand. Re-derive them after H1.
- **Outside the hero:** at 320 px the header's "For instructors" wraps onto two lines (`320-dark-t0.webp`, top).

## Fidelity ledger

| Point | Plan or approved image says | Image shows (file, region) | Verdict and fix |
|---|---|---|---|
| Book | Classic open book, front and slightly above, cream engraved pages, mulberry cover, gold ribbon | `1440-light-t0.webp`, centre right | Pass. About 15 px flatter (minor) |
| Rings and dots | Two thin tilted concentric ellipses, small mulberry dots | `1440-light-t0.webp`, `1440-dark-t0.webp` | Pass. Ring colours are derived (J2) |
| Cards | Thin border, upright, clear of the book and each other | `1440-light-t18.webp`, `1440-light-t72.webp` | Book never covered (min 4 px to its box), cards never overlap (min 9 px). They cover text (H1) and leave the column (H2) |
| Thoreau and Descartes swap | Trade places each lap | `1440-light-t0.webp` and `1440-light-t72.webp`, bottom card | Pass |
| Pause button | Round, top right, 44 px, gold ring with Paper gap | `1440-light-focus-pause.webp`, `1440-dark-paused.webp` | Pass: 44×44, ring `0 0 0 2px paper, 0 0 0 4px gold`, play glyph when pressed. Cards pass under it (J1) |
| Composition at 1440 | Text left, orbit in 696 to 1340, right card flush with the header edge | `1440-light-t0.webp` against `approved-1440-light.webp` | Fail: orbit spans 665 to 1371 (H1, H2) |
| Type | Display 72, Small 14/21, Short description 16/26 | computed styles | Fail: 70.56, 12, 16/20 (H3) |
| Spacing | Hero 64 below the header, 64 to the preview | measured 32 and 40 | Fail (H4) |
| Gold | Primary button, ribbon, focus ring only | all captures | Pass: only Open a course, the preview ribbon, the ring and the book's painted ribbon |
| Dark parity | Same composition; the book needs no recolouring | `1440-dark-t0.webp`, `1440-dark-reduced.webp` | Pass, with the same H1 and H2 |
| Reduced motion | Still cards, pause hidden | `1440-dark-reduced.webp` | Pass: 0 animations, pause `display: none`; five cards, but Comenius ends at x 1370 (H2) |
| Phone 390 | Text, buttons, smaller book, one quote line, no motion | `390-light-t0.webp` | Pass |
| Reflow 320 and 200 percent | No horizontal scroll | `320-dark-t0.webp`, `zoom200-light.webp` | Pass (`scrollWidth` 320 and 720). 768 fails (H2) |

## Accessibility and security checks

| Check | Result |
|---|---|
| Contrast (computed from rendered colours) | Quote text on card 13.52:1 light, 11.66:1 dark. Mulberry credit on card 7.22:1 light, 7.29:1 dark. Pause glyph 7.15 and 8.62. Gold ring on Paper 4.92 and 12.93. All pass |
| 2.2.2 Pause, Stop, Hide | Button named "Pause quotes", `aria-pressed` toggles with Space and Enter, all seven orbit animations pause and resume. It is shown only once the script runs, so no motion without a control. Pass |
| 2.4.7 and 2.4.11 Focus | Tab order: skip link, brand, nav, Log in, Create account, Open a course, Make a course, Pause quotes, preview section. Matches reading order. Ring visible and not obscured. Pass |
| 2.5.8 Target size | 44×44. Pass |
| Screen readers | Moving track `aria-hidden`; static `.vh` list of five `blockquote` and `cite`; book `alt=""`. Pass, with the "trans." minor |
| Images | AVIF and WebP, 512w for 256 px and 416w for 208 px (2x), RGBA, with `width` and `height`. Pass |
| Security | 12 requests, all same-origin; 0 CSP console messages under the R18 policy; one external `<script src>`, no inline script or `style=`. Pass |

## Codex second opinion (folded in)

Codex, read-only, was given the approved image and five captures. It confirmed H1 (Tagore over the lead), H2 (right-edge overshoot of 31 to 45 px; 20 and 16 px past the gutters at 768), and the 3 px gap at rest. It also reported the orbit sitting 10 to 14 px lower and the upper card 17 to 34 px lower than approved, which the H1 re-tune should settle. Rejected: "phone drops the rings and cards". The task spec asks for exactly that.

## Fix order

1. H1 and H2 together: a smaller ellipse, re-tuned anchors and the lap-sweep test.
2. H3: delete the fluid headline size, and decide the card type roles.
3. H4: spacing back to `--s8`.
4. J1 and J2: Paper behind the pause glyph, one separation method on the cards.
5. J3, J4, then the minors.

Re-capture at 1440, 1280, 1024 and 768 in both schemes at 0, 18, 36 and 54 s after the fixes.
