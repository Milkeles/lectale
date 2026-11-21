# Token plan, M2

Visual direction for Lectale: a calm reading app for learners of any discipline, who read for hours on six platforms. Structure follows known patterns (`inventory.md`); boldness is spent in one place, the ribbon. All values map to `devchat_ui` roles. No hex appears in widgets; hex values are seeds for the app's `DcColorScheme`s (see Colour).

> **Owner decisions, 2026-11-21.** Warm paper with mulberry (formerly "direction A"), plus one golden ochre accent that catches the eye. Paper, graphite and mulberry make up about 80 percent of what the learner sees; ochre marks the few places that need attention. The cobalt direction is dropped. The reading face is still open (see Type).

## Subject and job

Subject: a course that lives in a Git repository and is read like a book. Audience: students and self-learners, any subject, often on a phone, sometimes for an hour at a time. Job: make long text and course structure easy to read and to find your place in. The visual vocabulary comes from reading: a page, a margin, a bookmark ribbon. The palette follows a bound book: mulberry cloth, warm paper, and a gilt ribbon.

## Colour

Three hues don't fit `DcColorTheme.fromPalettes`, which takes one base and one accent palette and has no link role. The app builds its four `DcColorScheme`s (light, dark and both high-contrast variants) directly from the seeds below, and adds the two roles litse-ui lacks (`link`, `brand`) in a small app-level theme extension. Contrast is the WCAG 2 ratio, computed from the seeds on 2026-11-21 (Codex's study, re-measured); the built theme must be re-measured in tests.

| Name | Light seed | Dark seed | Role | Used for |
|---|---|---|---|---|
| Paper | `#F4F1ED` (OKLCH L 0.96, C 0.006, h 75: a warm grey) | `#191B1A` | `canvas`, `background` | Page and reading surface |
| Sand | `#E8E3DC` | `#262927` | `muted`, `secondary`, `accent` (hover, pressed), `card` | Code blocks, cards, selected rows |
| Graphite | `#242725` (h 157) | `#E9E5DE` | `foreground`, `cardForeground`; `mutedForeground` at about `#5A5F5B` / `#A9ADA7` | Text |
| Mulberry | `#783D57` (L 0.44, C 0.088, h 353) | `#E3A7B9` | `brand`, `link` (app extension) | The logo mark, underlined links, page titles (course and lesson h1) |
| Ochre | `#905E0C` | `#F3DDA4` | `primary`, `ring` | Three jobs: the one primary button per screen (Open course, Start course), the ribbon, the focus ring |
| Ochre, high contrast | `#6E4708` | `#F3DDA4` | `primary`, `ring` in the high-contrast schemes | As above, when the platform asks for more contrast |
| Signal red | `#A3292E` (h 24) | `#F2958E` | `destructive` | Errors only, always with an icon and a title |

| Pair | Light | Dark |
|---|---|---|
| Graphite on Paper | 13.40:1 | 13.79:1 |
| Graphite on Sand | 11.82:1 | 11.71:1 |
| Muted text on Paper / on Sand | 5.79 / 5.11:1 | 7.60:1 on Paper |
| Mulberry on Paper (links, titles) | 7.16:1 | 8.65:1 |
| Mulberry on Sand | 6.32:1 | 7.34:1 |
| Button label on Ochre | white 5.54:1 (8.18:1 on high-contrast `#6E4708`) | light Graphite `#242725` 11.27:1 |
| Ochre on Paper (focus ring) | 4.92:1 | 12.93:1 |
| Ochre on Sand (ribbon on a selected row) | 4.34:1 | 10.98:1 |
| Ochre next to Mulberry | 1.46:1, ΔE 0.149; under simulated deuteranopia and protanopia at least 1.44:1, ΔE 0.137 | 1.50:1 |
| Signal red on Paper / on Sand | 6.40 / 5.65:1 | 7.80:1 on Paper |
| Sand on Paper (selected fill) | 1.13:1: never the only cue (S7) | |

Why ochre (Codex's study, `brand/accent-study.md`): of the three candidates (deep teal, golden ochre, ink blue) it is the only one that reads as a colour rather than a dark neutral in light mode, so it catches the eye where it is used. It also keeps the clearest separation from mulberry under both colour-vision simulations. Teal and navy were within 0.1 of mulberry in protanopia; navy in dark mode read as a documentation theme.

Why links stay mulberry: ochre is 4.34:1 on Sand, under the 4.5:1 that text needs, and if every link were ochre the accent would stop meaning "look here". Mulberry passes on both surfaces, keeps the brand colour present on every page, and leaves ochre to three jobs.

Tell check: warm paper with a serif sits next to the "cream, serif, terracotta" default (`ai-tells.md`, Colour). It stays clear of it because the paper has a quarter of the chroma of a cream (C 0.006 against about 0.014 at h 85), the brand colour is a cool mulberry (h 353, far from terracotta `#D97757` at h 39, C 0.131), the accent is a deep ochre used on three elements only, and the serif is for reading, not display chrome. Signal red is darker and redder than terracotta (h 24, L 0.48 against L 0.67) and appears only in errors.

### Rules

- **Ochre has three jobs and no others:** the primary button (at most one per screen), the ribbon, the focus ring. It is never text and never a background behind text other than the button label.
- **Mulberry has three jobs:** the logo mark, underlined links, the course and lesson titles. Prose links are underlined, so colour is never the only cue.
- Large fills are for the primary button only. No gradients, glows or overlays on images. No shadows (`DcShadows.none`); separation is a Sand fill or whitespace, one method at a time.
- The focus ring sits outside a 2 dp Paper gap, so it reads on Sand, on the ochre button and next to mulberry text.
- Gold can read as a warning. Lectale has no warning colour: a caution message uses graphite text with an icon and a title, never ochre.
- Meaning is never colour alone: errors carry an icon and a title, the ribbon carries ", current" or ", last opened" for assistive tech, selected rows carry semibold plus `selected`.
- The manifest's `themeAccent` is ignored (A11Y-002). Chart roles are unused.

## Type

Bundled in litse-ui: IBM Plex Sans (variable, has Greek) and IBM Plex Mono. UI stays Plex Sans; code, paths and data files stay Plex Mono. The reading face is still open: Literata was proposed, IBM Plex Serif is the fallback, and the researcher is comparing faces with Bulgarian letterforms.

| | Literata (proposed) | IBM Plex Serif (fallback) |
|---|---|---|
| Licence | SIL OFL (Literata README) | SIL OFL |
| Files | two variable files, roman and italic (README); weight axis, so the dark-mode offset works and semibold italic exists | static regular, italic, semibold, plus semibold italic for Markdown bold italic (S10); the dark offset does not apply to the serif slot |
| Greek (μ, σ, π, Ω, Δ, θ, λ) | present (checked below) | missing: U+03BC and U+03C3 absent (design review, `fc-query`); falls back to Plex Sans, so a μ/σ sentence must be checked visually |
| Cyrillic, Bulgarian set | present (checked below) | `bg` charset present |
| Bulgarian localised forms | not in the Google Fonts static instance (no `BGR` language system); check the upstream variable files before relying on it | unverified |
| Average width, English prose | 0.461 em per character (measured) | 0.474 em (design review) |
| Also used for | course title, lesson title and content headings, so the reading area has one voice from the first line (Codex §3) | reading text only; headings in Plex Sans |
| Bundle cost | not measured: the Google static 400 instance is 170,668 bytes; the variable files were not fetched | not measured |

**Literata check, 2026-11-21** (fetched with curl; README converted with pandoc; treated as data):

- https://raw.githubusercontent.com/googlefonts/literata/main/README.md: "This wide-ranging family of two variable fonts supports Greek, Cyrillic, PinYin, and Vietnamese", OFL, roman and italic variable files.
- <https://fonts.googleapis.com/css2?family=Literata:wght@400> serves `cyrillic-ext`, `cyrillic`, `greek-ext`, `greek`, `vietnamese` and Latin subsets.
- The static instance it links (`fonts.gstatic.com/s/literata/v40/...ttf`): `fc-query` lists the `cyrl` and `grek` scripts and the ranges U+0384–03CE and U+0401–045F; every Bulgarian letter а–я and ѝ/Ѝ and all seven Greek test letters are present. Its GSUB has `locl` for Latin languages only.
- Blocked: fonts.google.com/specimen/Literata and the TypeTogether PDF specimen (proxy 403).

### Sizes and the heading map (M6)

| Role | `DcTypography` slot | Size (line height) | Weight, face |
|---|---|---|---|
| Rendered h1: course title, lesson title | `display` | 30 (36) | semibold, reading face, Mulberry |
| Rendered h2 | override (litse-ui's `heading` slot is 21.5) | 24 (32) | semibold, as h1 |
| Rendered h3 | `heading` | 21.5 (30) | semibold, as h1 |
| Rendered h4 | override | 19.5 (28) | semibold, as h1 |
| Rendered h5, h6 | override | 18 (28) | semibold, as h1; told apart by space above, not size |
| **Reading** | `reading` (override) | **18 (30)** | regular, reading face |
| UI titles: module headings, card and alert titles | `title`, `subtitle` | 17 (26), 15 (21) | semibold, Sans; never inside content |
| UI body | `body`, `label` | 14 (21.5) | regular, medium, Sans |
| Small | `small`, `caption` | 12.9 (17), 11.8 (17) | regular, Sans |
| Code and data | `code` | 14 (22) | regular, Mono |

Heading rules, both screens:

1. No content heading is smaller than the 18 dp reading size, and none is larger than the page h1.
2. Content headings shift so their top level sits one below the last page heading: Course shifts the README by one (README h1 renders as h2). Reader shifts Markdown by two when the lesson has a resource h2, by one when it has a single resource and so no h2 (`reader.md` §5). Deeper levels clamp at h6.
3. `title` and `subtitle` are UI sizes only.

Text rules:

- **Measure:** the reading column is capped at 32 em (576 dp at 18 dp; about 69 characters in Literata, 68 in Plex Serif), so it holds when text scales. Left aligned, ragged right, no justification, sentence case, no all-caps, no eyebrows. Breakpoints follow from it (`inventory.md`).
- **Text files** (S10): prose `.txt` and `.md` use Reading, wrapped. CSV, TSV, JSON, YAML, logs and code use `code`, unwrapped, with horizontal scroll.
- Body weight 400; weight only marks hierarchy. Dark mode applies the style's -50 weight offset where the face is variable (Plex Sans, and Literata if chosen).
- Text scales with the platform setting; layouts reflow at 200 and 400 percent.

## Spacing, radii, motion

- **Spacing** (`DcStyle.space(n)`, unit 4.5): 1 = 4.5, 2 = 9, 3 = 13.5, 4 = 18 (gutter), 6 = 27, 8 = 36, 12 = 54, 16 = 72. Edges and borders snap to whole device pixels (C3). Paragraph gap 0.9 em; a heading sits closer to its text than to the block above (proximity). Gutters 18 dp under 600 dp, 36 dp from 600. Max widths: reading 32 em, wide blocks 960 dp, Home column 560, Contents pane 272.
- **Radii** (comfortable radius 10): small 5 (inline code), medium 7.5 (buttons, fields, code blocks, images), large 12.5 (alerts, file and link cards). Contents rows and list rows have none.
- **Motion** (litse-ui tokens): `fast` 110 ms for hover and press feedback; `medium` 170 ms for the ribbon moving to a new row. Focus rings appear instantly (C2). No entrance animations, scroll-linked effects, animated scrolling or page transitions. Every duration is zero when the platform asks to reduce motion.

## Reading-oriented DcStyle (proposal)

Name: `DcStyle.reading` (owner decides if it lives in litse-ui or `apps/flutter_client`).

```text
comfortable base: radius 10, spacing 4.5, controls 36/44/52, scale 14/13,
onDarkWeightOffset -50, shadows none, depth flat, standard motion
reading slot: the chosen reading face, 18/30, scale does not apply
heading overrides: the map above
fontFamilyFallback: none for Literata; Plex Sans for Greek with Plex Serif
```

`DcTypography` has one `fontFamily` and fixed slot sizes, so the reading face and heading overrides need either a litse-ui change (per-slot family and size) or app-level `TextStyle`s built from `typography.reading.copyWith(...)` inside `resource_renderers`. The second needs no litse-ui change; it is the interim.

## The memorable element: the ribbon

A bookmark ribbon in the accent colour: 8 dp wide, one row tall, with the logo's swallowtail cut at its lower end (Codex §3), at the start edge of the learner's place in Contents. It marks the open lesson on the Reader and this visit's last-opened lesson on Course. When the pane is not on screen (phones, or a closed pane), it moves to the start edge of the Contents control, beside the title of that lesson, so the learner's place is visible at every width. Only one ribbon is ever on screen. It slides to a new row in 170 ms, instantly under reduce-motion. It is never decoration, and never used to mark a selected file (S7).

## Check against frontend-design's anti-generic list and `ai-tells.md`

| Tell | How Lectale avoids it |
|---|---|
| Cream, serif display, terracotta | Warm grey paper at low chroma, mulberry brand colour, ochre on three elements only, serif only in the reading area (see Tell check). |
| Near-black with an acid accent | Light default; dark schemes are deep greys with a soft accent. |
| Broadsheet hairlines, zero radius, dense columns | Radius by role, one reading column, no rules. |
| SaaS card kit, one radius, same shadow | Cards only for file and link cards and alerts; no shadows. Contents, lessons and files are rows. |
| Eyebrows, middle-dot or pipe meta strings, trailing arrows | None. Facts are labelled pairs; files are rows; no arrows except the real Close and chevron controls. |
| Gradient, glow, gradient text | Flat colour only. |
| Inter or Plus Jakarta display; stock scale | Plex Sans UI, Literata or Plex Serif reading; headings from one map. |
| Documentation-theme look (C1) | Why the cobalt direction was dropped: cool grey, cobalt and a thin bar read as a docs theme. Mulberry, ochre and the swallowtail ribbon are Lectale's own. |
| Centred hero, feature cards | Home is a form on the start line; no hero or illustration. |
| Dashboard filler, fake stats | None; no counts in Contents. |
| Icon tile above headings, decorative icons | No icons in lists or rows (S13). Icons only in alerts and on controls, with text; the three image zoom buttons are icon-only with a tooltip and label (S15). |
| Entrance animations, hover effects everywhere | One user-triggered motion: the ribbon. |
| Emoji or mixed icon styles | One family (Lucide), one stroke weight. |
| Placeholder names, filler verbs | Plain verbs; wireframe names are illustrative and replaced by real fixtures in tests. |
| Dense header chrome | The top bar holds the brand and nothing else. |

Pre-ship checks (`ai-tells.md`): (1) decoration removed: the kind icons in file lists and the tag badges (S4, S13); (2) the Lectale element is the swallowtail ribbon; (3) every colour, font and effect names a token and a reason, and the owner chose the palette and accent, and picks the reading face; (4) states and reduce-motion are in each screen spec; (5) copy has no filler verbs, no invented numbers.

## Logo brief (for Codex image concepts)

**What Lectale is.** A free reading app that opens any public GitHub repository as a course: README, lessons, files. Learners of any subject, no account. Name: Lectale (from "lecture" and "tale"; lowercase wordmark).

**Mood.** Quiet, patient, trustworthy, a little bookish, not nostalgic. A good library at 10 a.m., not a startup.

**The mark.** One flat shape: a tall rounded-corner page with a bookmark ribbon hanging from the top edge, the ribbon's swallowtail cut making the lower end of an "L". Single colour (the accent on paper, or ink), a second tone allowed for the page. The same ribbon becomes the in-app ribbon.

**SVG constraints.** Flat fills, no strokes, no gradients, no blur, no transparency effects, under 10 anchor points per shape, one or two colours, on a 64 by 64 grid, readable at 16 px, with a one-colour version and a version reversed out of the accent. The wordmark is set in IBM Plex Sans Medium by the app, not drawn: give the symbol alone.

**Avoid.** An open book, a graduation cap, an owl, a lightbulb, sparkles or AI stars, code brackets, the GitHub octocat or anything like GitHub's mark, 3D or isometric, glow, purple, cream with terracotta, a speech bubble, a robot.

**Deliverable from Codex.** Three raster concepts (monochrome, 1024 px, white background) for the owner to choose from. A designer redraws the chosen one as SVG; the raster is never shipped (`screen-spec` skill, Images).

## Illustration brief

M2 screens use no illustration; empty and error states use text and one Lucide icon. The only illustration wanted now is one share and store image.

- **Subject.** A repository folder turning into a book page: a folder outline on the left, a page with three text lines and the ribbon on the right, joined by a plain line. Meaning: "a folder of files becomes a course you can read".
- **Style.** Flat, two colours plus the paper tone, 2 dp line weight matching the Lucide icons, no characters or faces, no gradients, no isometric depth, generous empty space. 1200 by 630 for sharing; 240 by 160 variant for an optional spot use.
- **Avoid.** People with laptops, floating cards, abstract blobs, stock-style gradients, rounded-card collages, emoji.
- **Delivery.** Raster concepts from Codex as reference only; the final is SVG. Raster app assets, if any, are WebP at 1x, 2x and 3x.
