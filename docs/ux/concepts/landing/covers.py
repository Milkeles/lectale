"""Draws the example course covers as 2:3 SVGs with the title in Source Serif 4.

Run with fonttools and uharfbuzz installed:  python covers.py

Why outlines and not <text>: a cover is shown through <img> (security review
R20), and an SVG inside <img> cannot load the page's web fonts. Converting the
title to paths keeps Source Serif 4 on every platform and needs no font file.

Why opsz 28: the cover is shown about 250 CSS px wide, so the title is about
28 px high. Source Serif's optical size axis gives sturdier forms at small
sizes, and 28 is the design closest to what the eye gets.

Only Paper, Sand, Graphite and Mulberry from docs/ux/token-plan.md are used.
"""

import io
import os

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
    # A manuscript page: a decorated initial, then ruled lines of writing.
    page = f'<rect x="{MARGIN}" y="290" width="{W - 2 * MARGIN}" height="{H - MARGIN - 290}" rx="4" fill="{PAPER}"/>'
    initial = f'<rect x="{MARGIN + 28}" y="320" width="76" height="76" fill="{MULBERRY}"/>'
    ends = [372, 392, 380, 396, 360, 392, 384, 396, 342, 388, 396, 300]
    lines = ""
    for i, end in enumerate(ends):
        y = 326 + i * 28
        x = MARGIN + 28 + (96 if i < 3 else 0)
        lines += f'<rect x="{x}" y="{y}" width="{max(end - x + MARGIN, 40)}" height="7" rx="3.5" fill="{GRAPHITE}"/>'
    return svg(SAND, title_paths(["Reading", "medieval", "manuscripts"], None, MULBERRY) + page + initial + lines)


def python_lab():
    # A scatter plot with its fitted line; a ruled frame like a lab notebook.
    frame = f'<rect x="2" y="2" width="{W - 4}" height="{H - 4}" fill="none" stroke="{GRAPHITE}" stroke-width="4"/>'
    ax, ay0, ay1, ax1 = 64, 400, 650, 424
    axes = f'<path d="M{ax} {ay0}V{ay1}H{ax1}" fill="none" stroke="{GRAPHITE}" stroke-width="3"/>'
    noise = [-20, 16, -10, 28, -26, 12, -6, 24, -16, 8, -4]
    dots = ""
    for i, n in enumerate(noise):
        x = 96 + i * 30
        y = 628 - 0.62 * (x - 96) + n
        dots += f'<circle cx="{x}" cy="{y:.0f}" r="9" fill="{MULBERRY}"/>'
    trend = f'<path d="M84 640L412 436" stroke="{GRAPHITE}" stroke-width="3" fill="none"/>'
    return svg(PAPER, frame + title_paths(["Python for", "lab data"], None, MULBERRY, size=56) + axes + trend + dots)


def logic_bg():
    # Two overlapping sets; the overlap is cut out to the ground (A and B).
    cy, r = 520, 118
    sets = (
        f'<defs><clipPath id="a"><circle cx="190" cy="{cy}" r="{r}"/></clipPath></defs>'
        f'<circle cx="190" cy="{cy}" r="{r}" fill="{SAND}"/>'
        f'<circle cx="290" cy="{cy}" r="{r}" fill="{PAPER}"/>'
        f'<circle cx="290" cy="{cy}" r="{r}" fill="{MULBERRY}" clip-path="url(#a)"/>'
    )
    return svg(MULBERRY, title_paths(["Основи", "на логиката"], "bg", PAPER) + sets)


def cells():
    # Packed cells, each with an off-centre nucleus.
    spec = [(130, 430, 72), (290, 400, 54), (370, 522, 70), (170, 592, 58), (300, 640, 34)]
    out = ""
    for cx, cy, r in spec:
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
