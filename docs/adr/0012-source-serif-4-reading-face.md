---
status: accepted
date: 2026-11-21
---

# Source Serif 4 as the reading face

## Context and problem statement

Course text, and the course and lesson titles, use a serif reading face at
18 dp with a 30 dp line height (`docs/ux/token-plan.md`, Type). Literata was
proposed, but it has no Bulgarian localised forms, not even in its upstream
files. Courses can be written in any language, and the owner reads Bulgarian.

## Decision drivers

- Latin, Greek (for formulas such as μ, σ, Δ) and the full Bulgarian
  Cyrillic alphabet, including ѝ.
- Bulgarian forms in roman and italic.
- SIL OFL or another licence that allows bundling.
- A variable weight axis, so the dark-mode weight offset and semibold
  italic work.
- Calm at long reading lengths, next to IBM Plex Sans in the interface.

## Considered options

- Literata: the original proposal. Has no Bulgarian forms.
- Source Serif 4: has Bulgarian forms, weight and optical-size axes, and is the largest file.
- Piazzolla: has Bulgarian forms. Its default weight is 100, so every style must set the weight.
- Vollkorn: has Bulgarian forms. Smallest file, no optical sizes, the heaviest look.

The evidence for each is in
[the research note](../research/2026-11-21-reading-fonts-bulgarian.md), with
a specimen image.

## Decision outcome

The owner chose Source Serif 4 from the specimen. Ship the upstream variable
roman and italic files (adobe-fonts/source-serif, release 4.005) unmodified.

- **Locale:** reading text and titles set `TextStyle.locale` from
  `course.language`, or from the resource's own language when it has one.
  Flutter passes the locale to HarfBuzz, which applies the font's `locl`
  lookup, so Bulgarian courses get Bulgarian forms and other Cyrillic
  courses keep the standard ones.
- **Optical size:** set `FontVariation('opsz', ...)` to the rendered size.
  Nothing showed that Flutter sets it automatically.
- **No subsetting:** the licence reserves the font name "Source", and a
  subset is a modified version, which must carry a different name.

### Consequences

- The two files add about 2.05 MB to the app (0.89 MB brotli on the web).
  That is the largest of the three candidates.
- Flutter web loads every declared font at start-up. If the web build's
  first load is too slow, there are two fixes: load the reading face with
  `FontLoader` when the first reading screen opens, or ship a renamed
  subset (Latin, Greek, Cyrillic) as the licence allows.
- Literata's measured line length no longer applies. Source Serif 4 averages
  0.438 em per character, so the 32 em column holds about 73 characters.

### Confirmation

- A widget test renders a Bulgarian sentence with `locale: Locale('bg')` and
  with `Locale('ru')`, and checks that the two differ.
- A web smoke test records the font transfer size on first load.

## More information

- [Reading-face research and specimen](../research/2026-11-21-reading-fonts-bulgarian.md)
- [Token plan, Type](../ux/token-plan.md)
- [Source Serif licence](https://github.com/adobe-fonts/source-serif/blob/main/LICENSE.md): "No Modified Version of the Font Software may use the Reserved Font Name(s)" (fetched 2026-11-21)
