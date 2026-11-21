# Token plan, M2

Visual direction for Lectale: a calm reading app for learners of any discipline, who read for hours on six platforms. Structure follows known patterns (see `inventory.md`); boldness is spent in one place, the ribbon. All values map to `devchat_ui` roles. No hex appears in widgets; hex values below are seeds for the palettes passed to `DcColorTheme.fromPalettes`.

## Subject and job

Subject: a course that lives in a Git repository and is read like a book. Audience: students and self-learners, any subject, often on a phone, sometimes for an hour at a time. Job: make long text and course structure easy to read and to find your place in. The visual vocabulary comes from reading: a page, a margin, a bookmark ribbon.

## Colour

`DcColorTheme.fromPalettes(name: 'Lectale', base: <Birch scale>, accent: <Cobalt scale>)`. Each is an 11-step scale (50 to 950) generated in OKLCH from the seed; the theme picks shades by measured contrast (4.5:1 text, 3:1 borders and focus ring; it throws if a scale cannot reach them). Dark and high-contrast schemes come from the same call; the dark scheme is judged on its own, not by inversion.

| Name | Seed (light) | Role in `DcColorScheme` | Used for |
|---|---|---|---|
| Birch | `#F1F4F1` (hue about 150, chroma 0.01: a barely green grey, not cream) | `canvas`, `background`, base scale | Page and reading surface |
| Mist | `#E3E9E5` | `muted`, `secondary`, `accent` (hover and pressed fills), `card` | Code blocks, file cards, selected rows, quiet fills |
| Ink | `#1B2330` (blue-black; base shade 900) | `foreground`, `cardForeground`, `mutedForeground` at 700 | Text. Named and chosen, not `#111` |
| Cobalt | `#2B4BA0` (hue about 262) | `primary`, `primaryForeground`, `ring`, links | Exactly three jobs: the primary button, links, the ribbon |
| Brick | from `DcPalettes.red` | `destructive`, `destructiveForeground` | Errors only, always with text and an icon |

Dark scheme: Birch becomes a deep blue-green grey (about `#141A1A`, not black), Ink becomes a soft off-white, Cobalt lifts to about `#8FA8EE`. Chart roles are unused in M2.

Rules: one accent. No gradients, glows or overlays on images. Borders are the theme's translucent border; no shadows (`DcShadows.none`); separation is by Mist fill or whitespace, one method at a time. Meaning is never colour alone: errors carry an icon and title, the current place carries the ribbon and the word "current" for assistive tech. The manifest's `themeAccent` is ignored.

## Type

Bundled in litse-ui: IBM Plex Sans and IBM Plex Mono. Proposal: add IBM Plex Serif (SIL OFL, same family proportions, has Cyrillic including Bulgarian forms) as the reading face for README, text and lesson prose only. UI stays Plex Sans, code stays Plex Mono. This is one superfamily, two voices, chosen for long reading and because the app's owner works in Cyrillic. Bundling cost: one family, regular, italic, semibold; confirm size and register the licence with `registerDcLicenses`.

| Role | `DcTypography` slot | Size (line height) | Weight | Where |
|---|---|---|---|---|
| Course title | `display` | 30 (36) | semibold, Sans | one per screen |
| Page heading | `heading` | 21.5 (30) | semibold, Sans | lesson title, README h1 shifted to h2 |
| Section title | `title`, `subtitle` | 17 (26), 15 (21) | semibold, Sans | README h3 to h4, module headings |
| **Reading** | `reading` (override) | **18 (30)**, 1.65 | regular, **Serif** | README, text, summary, lesson description |
| UI body | `body`, `label` | 14 (21.5) | regular, medium | rows, buttons, alerts |
| Small | `small`, `caption` | 12.9 (17), 11.8 (17) | regular | meta, hints, references |
| Code | `code` | 14 (22) | regular, Mono | code and text viewers, paths |

- Scale: the comfortable style's 14/13 factor on the DevChat steps gives the UI sizes above (about a 1.2 ratio). Reading is set separately at 18.
- Measure: reading column 640 dp, about 64 to 70 characters at 18 dp in Plex Serif. On a 360 px phone the column is the window minus 18 dp gutters (about 36 characters; acceptable on a phone). Left aligned, ragged right, no justification, sentence case, no all-caps labels, no eyebrows.
- Body weight is 400; weight only marks hierarchy. Dark mode applies the style's weight offset (-50).
- Text scales with the platform setting; layouts reflow at 200 and 400 percent.

## Spacing, radii, motion

- **Spacing** (`DcStyle.space(n)`, unit 4.5): 1 = 4.5, 2 = 9, 3 = 13.5, 4 = 18 (gutter), 6 = 27, 8 = 36, 12 = 54, 16 = 72. Paragraph gap 0.9 em; gap between a heading and its text is smaller than the gap above it (proximity). Screen gutter 18 dp on phone, 36 dp from 600 dp, content centred or pane-bound by max widths: reading 640, Home form 560, contents pane 320.
- **Radii** (comfortable radius 10): small 5 (checkbox, inline code), medium 7.5 (buttons, fields, tabs, code blocks, images), large 12.5 (alerts, file cards), extra large 17.5 (dialogs, unused in M2), pill (badges). Images use the medium radius; contents rows have none (rows are separated by whitespace).
- **Motion** (litse-ui tokens): `fast` 110 ms for hover and release, `medium` 170 ms for the ribbon moving to a new row and for focus, `slow` 240 ms unused. Curves `curve` and `enter`. No entrance animations, no scroll-linked effects, no page transitions. All durations are zero when the platform asks to reduce motion.

## Reading-oriented DcStyle (proposal)

Name: `DcStyle.reading` (owner decides if it lives in litse-ui or in `apps/flutter_client`).

```
comfortable base: radius 10, spacing 4.5, controls 36/44/52, scale 14/13,
onDarkWeightOffset -50, shadows none, depth flat, standard motion
differences from comfortable: radius stays 10; DcShadows.none;
  typography: reading slot overridden to Plex Serif 18/30 (scale does not apply),
  fontFamilyFallback for Cyrillic and Greek
```

Larger than DevChat's tool style (13 px body, 32 px controls, 8 px radius): UI text 14, reading 18, controls 44 high, which meets touch targets without a separate mode. `DcTypography` has one `fontFamily` and fixed per-slot sizes, so the serif reading slot needs either a litse-ui change (per-slot family and size overrides) or an app-level `TextStyle` built from `typography.reading.copyWith(fontFamily:, fontSize:, height:)` inside `resource_renderers`. The second needs no litse-ui change; it is the interim.

## The memorable element: the ribbon

A 3 dp wide Cobalt bar, one row tall, at the left edge of the current row in the contents list (and its dark-scheme lift). It is the only place Cobalt appears outside the primary button and links. It slides to the new row in 170 ms when the lesson changes. It is also the shape of the logo. Meaning: this is where you are, like the ribbon in a book. Von Restorff: it is the single standing-out thing besides the primary button. It must not be used as decoration.

## Check against frontend-design's anti-generic list and `ai-tells.md`

| Tell | How Lectale avoids it |
|---|---|
| Cream background with serif display and terracotta accent | Background is a grey-green Birch; the serif is reading text only, not display; the accent is Cobalt, far from `#D97757`. |
| Near-black with an acid accent | Light default; dark scheme is a deep blue-green grey with a soft Cobalt; no acid colours. |
| Broadsheet layout, hairlines, zero radius, dense columns | Radius 10, wide reading column, no rule lines or columns beyond list-detail. |
| SaaS card kit: identical rounded cards, one radius, same shadow, gradient washes | Cards only for file and link cards and alerts; no shadows; radii by role; no gradients. Contents and lessons are rows, not cards. |
| Tracked all-caps eyebrow, middle-dot meta strings, `WORD - fragment` labels, tinted near-black, mono data labels, trailing arrows | None. Meta uses commas and separate lines; Ink is a named blue-black; Mono only for code and file paths in error lists; no arrows on buttons (chevron only on the real Back control). |
| Purple-blue gradient, glow, gradient text | Flat Cobalt only. |
| Inter or Plus Jakarta display; stock scale | Plex Sans for UI (bundled), Plex Serif for reading; scale built from the 14/13 factor plus an 18 reading size. |
| One accented word in a headline | Headings are plain. |
| 01/02/03 numbering | Numbers only where order is real: none are shown; the outline's order is the order. |
| Centred hero, three feature cards, CTA band | Home is a form on the left of the column; no hero, illustration or features. |
| Dashboard filler, fake stats | None. No progress numbers (M2 has no progress). |
| Icon tile above headings, gradient borders | No icon tiles; icons only inside alerts and controls, always with text. |
| Fade and slide-up entrances, hover transitions everywhere | None. One user-triggered motion: the ribbon. |
| Emoji or mixed icon styles | One family (Lucide), one stroke weight. |
| Placeholder names and brands, invented stats, filler verbs | Copy in the screen specs uses plain verbs; sample names in wireframes are illustrative only and must be replaced by real fixtures in tests. |
| Dense header chrome | Top bar has the brand link and nothing else. |

Pre-ship checks (`ai-tells.md`): (1) remove one decoration: the facts list loses its icons; (2) the Lectale element is the ribbon; (3) every colour, font and effect above names a token and a reason; (4) states and reduce-motion are in each screen spec; (5) copy has no filler verbs, no invented numbers.

## Logo brief (for Codex image concepts)

**What Lectale is.** A free reading app that opens any public GitHub repository as a course: README, lessons, files. Learners of any subject, no account. Name: Lectale (from "lecture" and "tale"; lowercase wordmark).

**Mood.** Quiet, patient, trustworthy, a little bookish, not nostalgic. A good library at 10 a.m., not a startup.

**The mark.** One flat shape: a tall rounded-corner page with a bookmark ribbon hanging from the top edge, the ribbon's notch (the swallowtail cut) making the lower end of an "L". Single colour (Cobalt on Birch, or Ink), a second tone allowed for the page. The same bar becomes the in-app ribbon.

**SVG constraints.** Flat fills, no strokes, no gradients, no blur, no transparency effects, under 10 anchor points per shape, one or two colours, on a 64 by 64 grid, readable at 16 px, with a one-colour version and a white-on-Cobalt version. Wordmark is set in IBM Plex Sans Medium by the app, not drawn: give the symbol alone.

**Avoid.** An open book, a graduation cap, an owl, a lightbulb, sparkles or AI stars, code brackets, the GitHub octocat or anything that looks like GitHub's mark, 3D or isometric, glow, purple, cream with terracotta, a speech bubble, a robot.

**Deliverable from Codex.** Three raster concepts (monochrome, 1024 px, white background) for the owner to choose from. A designer redraws the chosen one as SVG; the raster is never shipped (`screen-spec` skill, Images).

## Illustration brief

M2 screens use no illustration (Home, Course and Reader specs list none), and empty or error states use text and one Lucide icon. The only illustration wanted now is one share and store image.

- **Subject.** A repository folder turning into a book page: a folder outline on the left, a page with three text lines and the ribbon on the right, joined by a plain line. Meaning: "a folder of files becomes a course you can read".
- **Style.** Flat, two colours plus Birch, 2 dp line weight matching the Lucide icons, no characters or faces, no gradients, no isometric depth, generous empty space. 1200 by 630 for sharing; 240 by 160 variant for an optional spot use.
- **Avoid.** People with laptops, floating cards, abstract blobs, stock-style gradients, rounded-card collages, emoji.
- **Delivery.** Raster concepts from Codex as reference only; the final is SVG. Raster app assets, if any, are WebP at 1x, 2x and 3x.
