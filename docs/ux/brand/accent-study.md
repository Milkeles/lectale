# Lectale accent study

> **Adopted on 2026-11-21, with one change.** Links stay mulberry rather than ochre, because ochre on Sand is 4.34:1, under the 4.5:1 that text needs. Ochre keeps three jobs: the primary button, the ribbon and the focus ring. The roles are in `../token-plan.md`. Afterwards the owner asked for a slightly more purple mulberry: the hue moved 8° (353° to 345° in OKLCH) at the same lightness and chroma, from `#783D57` / `#E3A7B9` to `#753E5E` / `#E0A7C0`. The image and both tables below were regenerated with it; the prose is Codex's study as written.

Choose **Golden ochre**. Use **`#905E0C` in light mode** and **`#F3DDA4` in dark mode**. Ochre brings out the warmth of the paper and gives the mulberry mark room to keep its identity. It has the strongest worst-case separation from mulberry across the two colour-vision simulations. In light mode it delivers 4.92:1 for links and focus on Paper, and 5.54:1 for the white button label.

Keep Paper as the reading field, Graphite as the text and interface structure, and Mulberry in the Ribbon Cut mark. Use ochre for **Open course** and **Start course**, the current lesson ribbon, keyboard focus and underlined key links. The current row also has a semibold title, a visible “Current” label and a programmatic current state in the app. The focus ring has a Paper gap around the field so the outline reads against Paper.

## The three candidates

| Candidate | Light | Dark | Character and trade-off |
|---|---|---|---|
| **Deep teal** | `#00392B` | `#B1ECE2` | Green-leaning ink feels quiet and gives the pink side of mulberry a cool counterpart. The light teal becomes dark olive-gray in the protanopia simulation, and the dark mint becomes pale gray-blue in the deuteranopia simulation. The pairs remain separated mainly by lightness in those views. The mint button is the brightest of the dark fills by relative luminance. |
| **Golden ochre** | `#905E0C` | `#F3DDA4` | Burnished gold evokes a reading tab and carries the warmth of the paper into dark mode. It reads as olive-gold to straw in both simulations, with a visible tonal step against simulated mulberry. The light version has the smallest text contrast margin, so keep the link on Paper at this shade. Gold can suggest a warning in an interface. The button label, underlined link and swallowtail ribbon identify the actions and reading state. |
| **Ink blue** | `#1D2F66` | `#CCDDFA` | Navy feels precise and reads naturally as a link. The pale blue in dark mode shifts the feel toward a reference or documentation app, a risk already identified for the cobalt direction. Light navy and mulberry both lean blue in the protanopia simulation, where this candidate has its weakest tonal separation. |

## Contrast

The study uses the token plan’s Paper (`#F4F1ED` / `#191B1A`), Sand (`#E8E3DC` / `#262927`), Graphite foreground (`#242725` / `#E9E5DE`) and Mulberry (`#753E5E` / `#E0A7C0`). Button labels use white (`#FFFFFF`) in light mode and reuse the light-mode Graphite (`#242725`) in dark mode.

The two Paper columns measure the same solid pair against different thresholds. The mockups and calculations use the exact seed colours. Thresholds were applied before rounding. [WCAG 2.2 contrast and relative luminance](https://www.w3.org/TR/WCAG22/#contrast-ratio), [W3C non-text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast).

| Candidate | Mode | Accent | Text on Paper ≥ 4.5 | UI on Paper ≥ 3 | Label on fill ≥ 4.5 | Ribbon on Sand ≥ 3 | Adjacent to Mulberry |
|---|---|---|---:|---:|---:|---:|---:|
| Deep teal | Light | `#00392B` | 11.51:1 | 11.51:1 | 12.96:1 | 10.15:1 | 1.61:1 |
| Deep teal | Dark | `#B1ECE2` | 13.16:1 | 13.16:1 | 11.47:1 | 11.17:1 | 1.53:1 |
| Golden ochre | Light | `#905E0C` | 4.92:1 | 4.92:1 | 5.54:1 | 4.34:1 | 1.45:1 |
| Golden ochre | Dark | `#F3DDA4` | 12.93:1 | 12.93:1 | 11.27:1 | 10.98:1 | 1.50:1 |
| Ink blue | Light | `#1D2F66` | 11.30:1 | 11.30:1 | 12.72:1 | 9.97:1 | 1.58:1 |
| Ink blue | Dark | `#CCDDFA` | 12.61:1 | 12.61:1 | 10.99:1 | 10.70:1 | 1.46:1 |

## Mulberry adjacency and colour vision

Each cell gives **accent-to-mulberry luminance ratio / Oklab distance (ΔE)**. The script applies the Machado, Oliveira and Fernandes deuteranopia and protanopia matrices at severity 1.0 to linear sRGB, clips to the display gamut and measures both colours after the transform. The comparison image includes the resulting pairs. [Machado et al. (2009)](https://lume.ufrgs.br/bitstream/handle/10183/27630/000751721.pdf), [Oklab definition and equations](https://bottosson.github.io/posts/oklab/).

| Candidate | Mode | Standard | Deuteranopia | Protanopia |
|---|---|---:|---:|---:|
| Deep teal | Light | 1.61:1 / 0.201 | 1.75:1 / 0.140 | 1.41:1 / 0.102 |
| Deep teal | Dark | 1.53:1 / 0.175 | 1.42:1 / 0.107 | 1.70:1 / 0.163 |
| Golden ochre | Light | 1.45:1 / 0.157 | 1.47:1 / 0.149 | 1.42:1 / 0.159 |
| Golden ochre | Dark | 1.50:1 / 0.161 | 1.47:1 / 0.144 | 1.54:1 / 0.162 |
| Ink blue | Light | 1.58:1 / 0.168 | 1.72:1 / 0.160 | 1.37:1 / 0.098 |
| Ink blue | Dark | 1.46:1 / 0.136 | 1.38:1 / 0.107 | 1.59:1 / 0.142 |

All six shades clear the study’s side-by-side review floors of **1.30:1 and ΔE 0.09** in all three views. These are design heuristics for comparing swatches. With the updated mulberry, golden ochre's minimum is **1.42:1 and ΔE 0.144** (it was 1.44:1 and ΔE 0.137 against the first mulberry). With the fixed Paper and Mulberry values, the highest possible mulberry adjacency for an accent that meets 4.5:1 on Paper is 2.60:1 in light mode and 2.00:1 in dark mode. Keep Paper or Sand behind the accent when it carries meaning. Check the same pairs again on the shades generated by `DcColorTheme.fromPalettes` when applying the palette.

## Files

[Comparison image](accent-study.webp) · [Pillow rendering and measurement script](accent-study.py)

Run `python3 accent-study.py` to print both tables and regenerate the image. The script uses Pillow and Lectale’s bundled IBM Plex Sans Variable. It finds the font in litse-ui's pub-cache checkout, or in a copy of `IBMPlexSans.ttf` beside the script.
