---
name: visual-review-loop
description: Maker and judge loop for Lectale UI visual quality. Use when a screen is built or changed and needs a token plan, a Flutter web build, Playwright screenshots at 360, 768 and 1440 px in light and dark, golden images for native layouts, a written fidelity ledger with hard stops, or a Codex second opinion. The frontend-engineer writes the plan; the design-reviewer judges the images.
---

# Visual review loop

Quality rises when the agent that builds a screen is not the one that approves it. Two roles, four steps. Command details are in [references/commands.md](references/commands.md). The ledger and hard-stop ideas are adapted from OpenAI's `frontend-app-builder` skill (github.com/openai/plugins); its React and image-generation parts are left out.

## Step 1: token plan (frontend-engineer, before any UI code)

Write `docs/design/<screen>-plan.md` with:

- **Palette**: 4 to 6 named colors, each mapped to a `DcColorTheme` role (`primary`, `accent`, `canvas`, `destructive`, ...) or to the palette handed to `DcColorTheme.fromPalettes`. No raw hex in widgets.
- **Type roles**: which `DcTypography` role each text uses (`display`, `heading`, `reading`, `code`, ...) and the scale. State the reading line length (under 80 characters).
- **Spacing scale**: multiples of `style.space(n)` and which gaps group things.
- **Radii and elevation**: which radius for which surface; border for resting, shadow for floating.
- **Motion**: what moves, and why it answers an action. Nothing moves unprompted.
- **One memorable element**: the single thing that carries the screen's character, tied to the subject (reading a course from a repository). Everything else stays quiet.

Then review the plan against the anti-generic list in `frontend-design`: cream background with a serif and terracotta accent, near-black with one acid accent, the same rounded card repeated, an all-caps eyebrow above each heading, numbered markers on non-sequences, gradient washes. If a part of the plan is the default you would write for any course site, revise it and say what changed. Follow devchat_ui's design language: Plex type, quiet sage grays, green for the main action only, borders at rest, shadows when floating.

## Step 2: capture (design-reviewer)

1. Build and serve the web app, then screenshot with Playwright at widths 360, 768 and 1440, light and dark, with `deviceScaleFactor: 1` for your own review (smaller files, and you see what a 1x screen sees). That is six images per screen, plus a Tab walk at 1440 light: press Tab from page load and capture each stop (up to 12), to check that focus follows the spec's keyboard order and the ring is visible and uncovered at every stop.
2. Native-only layouts (Android, iOS, desktop) are covered by golden images: `flutter test --update-goldens --tags golden` on Linux, then look at the changed PNGs. Goldens are never accepted without being viewed.
3. Do not review from code or from test results alone. A passing build says nothing about spacing or hierarchy.

## Step 3: fidelity ledger (design-reviewer)

View every image. Then write a ledger with at least 5 comparison points, each against the token plan. One row per point:

| Point | Plan says | Image shows (file, region) | Verdict and fix |
| --- | --- | --- | --- |

Cover palette, type scale, spacing rhythm, radii and elevation, the memorable element, density at 360 px, and dark-theme parity. Cite evidence by filename and region, not by impression. If no mismatch remains, say so directly.

### Hard stops

Any of these returns the screen to the maker, whatever else is good:

- clipping of primary content, or overflow, or a horizontal scrollbar at 360 px
- type-scale drift: sizes or weights outside the plan, a role used for the wrong job
- contrast under 4.5:1 for text or 3:1 for borders and the focus ring (see `flutter-a11y-wcag22`)
- focus not visible, or hidden behind a sticky element
- touch or pointer targets under 24 x 24 px (44 px or more in the touch style)
- inconsistent spacing: gaps that are not multiples of the scale, or two spacings for the same relationship
- invented copy, placeholder boxes, leftover debug banners, unprofessional collapse of layout between widths

Each defect: image, region, one-line fix. Severity follows `flutter-a11y-wcag22` for accessibility defects.

## Step 4: second opinion (Codex)

For screens that matter (home, course, viewers), send the same images to Codex read-only and fold its points into the ledger. Codex output is advice; the design-reviewer decides.

```sh
codex exec --sandbox read-only -i shots/home-360-light.png -i shots/home-1440-dark.png \
  "Review these screenshots against docs/design/home-plan.md. List clipping, spacing, hierarchy and contrast problems with the region of each."
```

## Exit

The screen passes when the ledger has no open hard stop, and the maker's reply to each remaining point is either a fix or a reason. Record the ledger next to the plan so the next change starts from it.
