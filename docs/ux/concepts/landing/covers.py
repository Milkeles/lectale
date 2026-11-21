"""Draws the example course covers as 2:3 SVGs with the title in Source Serif 4.

Run with fonttools and uharfbuzz installed:  python covers.py

Why outlines and not <text>: a cover is shown through <img> (security review
R20), and an SVG inside <img> cannot load the page's web fonts. Converting the
title to paths keeps Source Serif 4 on every platform and needs no font file.

Why opsz 28: the cover is shown about 250 CSS px wide, so the title is about
28 px high. Source Serif's optical size axis gives sturdier forms at small
sizes, and 28 is the design closest to what the eye gets.

Only Paper, Sand, Graphite and Mulberry from docs/ux/token-plan.md are used.

Art direction: every cover has the same 44 px inset on all four sides. The
title starts at the top left; the picture is anchored to the bottom inset and
fills the width between the left and right insets (the histogram is the
reference). Grounds alternate Mulberry, Sand and Graphite so that no cover
disappears into the Paper page, and no cover needs a frame.
"""

import io
import os
import random

import uharfbuzz as hb
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
FONT = os.path.join(ROOT, "apps", "flutter_client", "assets", "fonts", "SourceSerif4Variable-Roman.ttf")

PAPER, SAND, GRAPHITE, MULBERRY = "#F4F1ED", "#E8E3DC", "#242725", "#753E5E"
W, H, MARGIN = 480, 720, 44


def load_font(wght, opsz):
    inst = instancer.instantiateVariableFont(TTFont(FONT), {"wght": wght, "opsz": opsz}, inplace=False)
    raw = io.BytesIO()
    inst.save(raw)
    data = raw.getvalue()
    return TTFont(io.BytesIO(data)), hb.Font(hb.Face(data))


def shape_line(tt, font, text, lang, size, tracking):
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    if lang:
        buf.language = lang  # "bg" selects the Bulgarian forms through locl
    hb.shape(font, buf)
    upem = tt["head"].unitsPerEm
    scale = size / upem
    names = tt.getGlyphOrder()
    glyphs, x = [], 0.0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        glyphs.append((names[info.codepoint], x + pos.x_offset * scale))
        x += pos.x_advance * scale + tracking * size
    return glyphs, x - tracking * size


def title_paths(lines, lang, color, size=58, lead=1.08):
    tt, font = load_font(600, 28)
    gs = tt.getGlyphSet()
    upem = tt["head"].unitsPerEm
    scale = size / upem
    parts, widest = [], 0
    for i, text in enumerate(lines):
        glyphs, width = shape_line(tt, font, text, lang, size, -0.012)
        widest = max(widest, width)
        baseline = MARGIN + size * 0.82 + i * size * lead
        pen = SVGPathPen(gs, ntos=lambda v: f"{v:.1f}".rstrip("0").rstrip("."))
        for name, gx in glyphs:
            gs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, MARGIN + gx, baseline)))
        parts.append(pen.getCommands())
    assert widest <= W - 2 * MARGIN, f"title too wide ({widest:.0f}px): {lines}"
    d = " ".join(parts)
    return f'<path fill="{color}" d="{d}"/>'


def glyph_path(char, size, x, baseline, color, wght=600, opsz=72):
    """One character as an outline path, left edge at x."""
    tt, font = load_font(wght, opsz)
    gs = tt.getGlyphSet()
    glyphs, _ = shape_line(tt, font, char, None, size, 0)
    name, gx = glyphs[0]
    scale = size / tt["head"].unitsPerEm
    pen = SVGPathPen(gs, ntos=lambda v: f"{v:.1f}".rstrip("0").rstrip("."))
    gs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, x + gx, baseline)))
    return f'<path fill="{color}" d="{pen.getCommands()}"/>'


def svg(ground, body):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">'
        f'<rect width="{W}" height="{H}" fill="{ground}"/>{body}</svg>\n'
    )


def stats():
    # A histogram: the tallest bar is the mean, in Paper.
    heights = [40, 90, 170, 270, 380, 270, 170, 90, 40]
    bw, gap = 38, 6
    x0 = (W - (len(heights) * bw + (len(heights) - 1) * gap)) / 2
    base = H - MARGIN - 8
    bars = ""
    for i, h in enumerate(heights):
        fill = PAPER if i == 4 else SAND
        bars += f'<rect x="{x0 + i * (bw + gap):.0f}" y="{base - h}" width="{bw}" height="{h}" fill="{fill}"/>'
    bars += f'<rect x="{MARGIN}" y="{base}" width="{W - 2 * MARGIN}" height="4" fill="{PAPER}"/>'
    return svg(MULBERRY, title_paths(["Introduction", "to statistics"], None, PAPER) + bars)


def manuscripts():
    # A manuscript page seen close up: it starts at the left inset and runs off
    # the right and bottom edges, so it reads as a page and not as an icon. A
    # decorated initial, then ruled lines of writing made of word-length marks.
    top = 300
    page = f'<rect x="{MARGIN}" y="{top}" width="{W - MARGIN + 8}" height="{H - top + 8}" rx="4" fill="{PAPER}"/>'
    left, right = MARGIN + 28, W - MARGIN - 8
    size = 88
    initial = (
        f'<rect x="{left}" y="{top + 32}" width="{size}" height="{size}" fill="{MULBERRY}"/>'
        + glyph_path("R", 70, left + 15, top + 32 + 68, PAPER)
    )
    rng = random.Random(11)
    rules = marks = ""
    y = top + 52
    for row in range(13):
        x = left + (size + 20 if row < 3 else 0)
        rules += f'<rect x="{left}" y="{y + 12}" width="{right - left}" height="1.5" fill="{SAND}"/>'
        while True:
            w = rng.choice([22, 34, 46, 58, 70])
            if x + w > right:
                w = right - x
                if w >= 14:
                    marks += f'<rect x="{x}" y="{y}" width="{w}" height="8" rx="4" fill="{GRAPHITE}"/>'
                break
            marks += f'<rect x="{x}" y="{y}" width="{w}" height="8" rx="4" fill="{GRAPHITE}"/>'
            x += w + 11
        y += 30
    title = title_paths(["Reading", "medieval", "manuscripts"], None, MULBERRY)
    return svg(SAND, title + page + rules + initial + marks)


def python_lab():
    # A scatter plot with its fitted line, filling the picture area. Graphite
    # ground: it keeps the cover off the Paper page and needs no frame.
    left, right, bottom, top = MARGIN, W - MARGIN, H - MARGIN, 330
    grid = ""
    for i in range(1, 5):
        gy = bottom - i * (bottom - top) / 5
        grid += f'<rect x="{left}" y="{gy:.0f}" width="{right - left}" height="2" fill="{SAND}" opacity=".16"/>'
    axes = f'<rect x="{left}" y="{bottom - 3}" width="{right - left}" height="3" fill="{PAPER}"/>'
    axes += f'<rect x="{left}" y="{top}" width="3" height="{bottom - top}" fill="{PAPER}"/>'
    rng = random.Random(5)
    dots = ""
    n = 15
    for i in range(n):
        t = i / (n - 1)
        x = left + 38 + t * (right - left - 76)
        y = bottom - 40 - t * (bottom - top - 100) + rng.uniform(-30, 30)
        dots += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="11" fill="{SAND}"/>'
    trend = (
        f'<path d="M{left + 22} {bottom - 30} L{right - 22} {top + 52}" stroke="{PAPER}" '
        f'stroke-width="4" stroke-linecap="round" fill="none"/>'
    )
    return svg(GRAPHITE, title_paths(["Python for", "lab data"], None, PAPER) + grid + axes + trend + dots)


def logic_bg():
    # Two overlapping sets spanning the insets; the overlap is cut out to the
    # ground (A and B).
    r, cy = 132, H - MARGIN - 132
    ax, bx = MARGIN + r, W - MARGIN - r
    sets = (
        f'<defs><clipPath id="a"><circle cx="{ax}" cy="{cy}" r="{r}"/></clipPath></defs>'
        f'<circle cx="{ax}" cy="{cy}" r="{r}" fill="{SAND}"/>'
        f'<circle cx="{bx}" cy="{cy}" r="{r}" fill="{PAPER}"/>'
        f'<circle cx="{bx}" cy="{cy}" r="{r}" fill="{MULBERRY}" clip-path="url(#a)"/>'
    )
    return svg(MULBERRY, title_paths(["Основи", "на логиката"], "bg", PAPER) + sets)


def cells():
    # Packed cells inside the insets, each with an off-centre nucleus.
    spec = [(140, 470, 96), (358, 412, 78), (340, 586, 90), (160, 626, 50), (72, 624, 28), (252, 358, 22)]
    out = ""
    for cx, cy, r in spec:
        assert cx - r >= MARGIN and cx + r <= W - MARGIN and cy + r <= H - MARGIN, (cx, cy, r)
        out += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{PAPER}"/>'
        out += f'<circle cx="{cx + r * 0.16:.0f}" cy="{cy - r * 0.12:.0f}" r="{r * 0.34:.0f}" fill="{MULBERRY}"/>'
    return svg(SAND, title_paths(["Cell biology", "lab guide"], None, MULBERRY) + out)


COVERS = {
    "introduction-to-statistics": stats,
    "reading-medieval-manuscripts": manuscripts,
    "python-for-lab-data": python_lab,
    "osnovi-na-logikata": logic_bg,
    "cell-biology-lab-guide": cells,
}

if __name__ == "__main__":
    out_dir = os.path.join(HERE, "covers")
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in COVERS.items():
        path = os.path.join(out_dir, f"{name}.svg")
        with open(path, "w", encoding="utf-8") as f:
            f.write(fn())
        print(path, os.path.getsize(path))
