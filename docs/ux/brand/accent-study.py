from functools import lru_cache
from math import dist
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
GRAPHITE = "#242725"
WHITE = "#FFFFFF"
MODES = {
    "Light": {
        "paper": "#F4F1ED", "sand": "#E8E3DC", "ink": GRAPHITE,
        "muted": "#5A5F5B", "mulberry": "#783D57", "label": WHITE,
    },
    "Dark": {
        "paper": "#191B1A", "sand": "#262927", "ink": "#E9E5DE",
        "muted": "#A9ADA7", "mulberry": "#E3A7B9", "label": GRAPHITE,
    },
}
CANDIDATES = {
    "Deep teal": {"Light": "#00392B", "Dark": "#B1ECE2"},
    "Golden ochre": {"Light": "#905E0C", "Dark": "#F3DDA4"},
    "Ink blue": {"Light": "#1D2F66", "Dark": "#CCDDFA"},
}

# Machado, Oliveira and Fernandes (2009), full dichromacy (severity 1.0).
CVD = {
    "Deuteranopia": (
        (0.367322, 0.860646, -0.227968),
        (0.280085, 0.672501, 0.047413),
        (-0.011820, 0.042940, 0.968881),
    ),
    "Protanopia": (
        (0.152286, 1.052583, -0.204868),
        (0.114503, 0.786281, 0.099216),
        (-0.003882, -0.048116, 1.051998),
    ),
}
LUMINANCE_WEIGHTS = (0.2126, 0.7152, 0.0722)
LINEAR_TO_LMS = (
    (0.4122214708, 0.5363325363, 0.0514459929),
    (0.2119034982, 0.6806995451, 0.1073969566),
    (0.0883024619, 0.2817188376, 0.6299787005),
)
LMS_TO_OKLAB = (
    (0.2104542553, 0.7936177850, -0.0040720468),
    (1.9779984951, -2.4285922050, 0.4505937099),
    (0.0259040371, 0.7827717662, -0.8086757660),
)


def dot(first, second):
    return sum(a * b for a, b in zip(first, second))


def linear_rgb(color):
    def decode(value):
        channel = value / 255
        if channel <= 0.04045:
            return channel / 12.92
        return ((channel + 0.055) / 1.055) ** 2.4

    return tuple(map(decode, bytes.fromhex(color[1:])))


def srgb_hex(rgb):
    def encode(channel):
        if channel <= 0.0031308:
            return round(255 * 12.92 * channel)
        return round(255 * (1.055 * channel ** (1 / 2.4) - 0.055))

    return "#" + bytes(map(encode, rgb)).hex().upper()


def contrast(first, second):
    low, high = sorted(dot(LUMINANCE_WEIGHTS, rgb) for rgb in (first, second))
    return (high + 0.05) / (low + 0.05)


def ratio(first, second):
    return contrast(linear_rgb(first), linear_rgb(second))


def simulate(rgb, vision):
    if vision == "Standard":
        return rgb
    return tuple(min(1, max(0, dot(row, rgb))) for row in CVD[vision])


def oklab(rgb):
    lms = tuple(dot(row, rgb) ** (1 / 3) for row in LINEAR_TO_LMS)
    return tuple(dot(row, lms) for row in LMS_TO_OKLAB)


def pairing(accent, mulberry, vision):
    first, second = (simulate(linear_rgb(color), vision) for color in (accent, mulberry))
    return contrast(first, second), dist(oklab(first), oklab(second))


def report():
    print("| Candidate | Mode | Accent | Text on Paper | UI on Paper | Label on fill | Ribbon on Sand | Adjacent to Mulberry |")
    print("|---|---|---|---:|---:|---:|---:|---:|")
    for name, shades in CANDIDATES.items():
        for mode, theme in MODES.items():
            accent = shades[mode]
            paper = ratio(accent, theme["paper"])
            label = ratio(accent, theme["label"])
            sand = ratio(accent, theme["sand"])
            mulberry = ratio(accent, theme["mulberry"])
            assert paper >= 4.5 and label >= 4.5 and sand >= 3, (name, mode)
            print(f"| {name} | {mode} | `{accent}` | {paper:.2f}:1 | {paper:.2f}:1 | "
                  f"{label:.2f}:1 | {sand:.2f}:1 | {mulberry:.2f}:1 |")

    print()
    print("| Candidate | Mode | Standard | Deuteranopia | Protanopia |")
    print("|---|---|---:|---:|---:|")
    for name, shades in CANDIDATES.items():
        for mode, theme in MODES.items():
            cells = []
            for vision in ("Standard", *CVD):
                value, delta = pairing(shades[mode], theme["mulberry"], vision)
                assert value >= 1.30 and delta >= 0.09, (name, mode, vision)
                cells.append(f"{value:.2f}:1 / {delta:.3f}")
            print(f"| {name} | {mode} | " + " | ".join(cells) + " |")


# litse-ui bundles the font; pub keeps its git checkout in the pub cache.
FONT_PATHS = (
    ROOT / "IBMPlexSans.ttf",
    *sorted(Path.home().glob(".pub-cache/git/litse-ui-private-*/assets/fonts/IBMPlexSans.ttf")),
)
BOARD = "#FBFAF8"
BOARD_RULE = "#E2DCD4"
MUTED = MODES["Light"]["muted"]
MARGIN = 54
COLUMN = 468
GAP = 24
PANEL_HEIGHT = 502
WIDTH = 2 * MARGIN + 3 * COLUMN + 2 * GAP
HEIGHT = 1576


@lru_cache
def plex(size, weight):
    path = next((path for path in FONT_PATHS if path.is_file()), None)
    if path is None:
        raise FileNotFoundError("Place IBM Plex Sans Variable (IBMPlexSans.ttf) beside this script.")
    face = ImageFont.truetype(str(path), size)
    face.set_variation_by_axes([weight, 100])
    return face


def write(draw, x, y, value, size, color, weight=400, anchor="lt"):
    return draw.text((x, y), value, font=plex(size, weight), fill=color, anchor=anchor)


def ribbon_cut(draw, x, y, paper, mulberry):
    # Redrawn from the supplied mark: 66 × 78 reference, quarter-round and an open notch.
    draw.rectangle((x, y, x + 11, y + 26), fill=mulberry)
    draw.rectangle((x + 11, y + 10, x + 22, y + 26), fill=mulberry)
    draw.pieslice((x + 2, y, x + 22, y + 20), 270, 360, fill=mulberry)
    draw.polygon(
        [(x + 5, y), (x + 12, y), (x + 12, y + 14), (x + 9, y + 11), (x + 5, y + 14)],
        fill=paper,
    )


def draw_panel(draw, x, y, mode, accent):
    theme = MODES[mode]
    paper, sand, ink = (theme[role] for role in ("paper", "sand", "ink"))
    muted, mulberry = (theme[role] for role in ("muted", "mulberry"))
    weight_offset = 0 if mode == "Light" else -50
    draw.rounded_rectangle((x, y, x + COLUMN - 1, y + PANEL_HEIGHT - 1), 12, fill=paper)
    left, right = x + 25, x + COLUMN - 25
    ribbon_cut(draw, left, y + 24, paper, mulberry)
    write(draw, left + 34, y + 25, "lectale", 26, ink, 500 + weight_offset)
    write(draw, left, y + 70, "Open a course from GitHub", 30, ink, 600 + weight_offset)
    write(draw, left, y + 110, "Use any public repository with a course.yaml file.", 16, muted)
    write(draw, left, y + 149, "GitHub repository address", 15, ink, 500 + weight_offset)

    # A two-pixel external ring with paper between ring and field border.
    draw.rounded_rectangle((left - 5, y + 168, right + 4, y + 221), 11, outline=accent, width=2)
    draw.rounded_rectangle((left, y + 173, right - 1, y + 216), 7, outline=muted)
    write(draw, left + 13, y + 195, "github.com/ada/stats-101", 16, ink, anchor="lm")

    draw.rounded_rectangle((left, y + 232, right - 1, y + 275), 7, fill=accent)
    write(draw, (left + right) // 2, y + 254, "Open course", 17, theme["label"],
          600 + weight_offset, anchor="mm")
    link = "View an example course"
    write(draw, left, y + 291, link, 16, accent, 500 + weight_offset)
    link_end = left + round(draw.textlength(link, font=plex(16, 500 + weight_offset))) - 1
    draw.line((left, y + 307, link_end, y + 307), fill=accent)

    write(draw, left, y + 344, "Contents", 22, ink, 600 + weight_offset)
    row_top = y + 367
    for title, current in (("Overview", False), ("Reading data", True), ("Working with samples", False)):
        if current:
            draw.rectangle((left, row_top, right - 1, row_top + 35), fill=sand)
            draw.polygon(
                [(left, row_top), (left + 7, row_top), (left + 7, row_top + 35),
                 (left + 4, row_top + 31), (left, row_top + 35)],
                fill=accent,
            )
            write(draw, right - 12, row_top + 18, "Current", 13, muted, anchor="rm")
        weight = (600 if current else 400) + weight_offset
        write(draw, left + 20, row_top + 18, title, 16, ink, weight, anchor="lm")
        row_top += 37


def draw_pairing(draw, x, y, shades):
    write(draw, x + 156, y, "Light", 15, MUTED, 500)
    write(draw, x + 317, y, "Dark", 15, MUTED, 500)
    for row, vision in enumerate(("Standard", *CVD)):
        top = y + 24 + 30 * row
        write(draw, x, top + 10, vision, 15, GRAPHITE, anchor="lm")
        for mode, swatch_x in (("Light", x + 156), ("Dark", x + 317)):
            for index, color in enumerate((MODES[mode]["mulberry"], shades[mode])):
                fill = srgb_hex(simulate(linear_rgb(color), vision))
                start = swatch_x + 64 * index
                draw.rectangle((start, top, start + 63, top + 19), fill=fill)


def render():
    image = Image.new("RGB", (WIDTH, HEIGHT), BOARD)
    draw = ImageDraw.Draw(image)
    write(draw, MARGIN, 47, "Lectale accent study", 52, GRAPHITE, 600)
    write(draw, MARGIN, 112, "One accent for action, reading position, focus and links.", 20, MUTED)
    draw.line((MARGIN, 159, WIDTH - MARGIN - 1, 159), fill=BOARD_RULE)
    draw.line((MARGIN, 1345, WIDTH - MARGIN - 1, 1345), fill=BOARD_RULE)
    write(draw, MARGIN, 1370, "Next to mulberry", 24, GRAPHITE, 600)
    write(draw, MARGIN, 1404, "Mulberry is on the left of each pair.", 16, MUTED)

    for index, (name, shades) in enumerate(CANDIDATES.items()):
        x = MARGIN + index * (COLUMN + GAP)
        write(draw, x, 186, name, 30, GRAPHITE, 600)
        for mode, top in (("Light", 263), ("Dark", 821)):
            accent = shades[mode]
            write(draw, x, top - 24, mode, 16, MUTED, 500)
            write(draw, x + COLUMN - 1, top - 24, accent, 16, MUTED, 500, anchor="rt")
            draw_panel(draw, x, top, mode, accent)
        draw_pairing(draw, x, 1440, shades)

    profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB"))
    image.save(ROOT / "accent-study.webp", icc_profile=profile.tobytes(), lossless=True, method=6)


if __name__ == "__main__":
    report()
    render()
