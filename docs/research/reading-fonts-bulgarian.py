"""Renders the reading-face specimen for docs/research/2026-11-21-reading-fonts-bulgarian.md.

Usage:
    python3 reading-fonts-bulgarian.py FONT_DIR OUT.webp
    python3 reading-fonts-bulgarian.py FONT_DIR --widths

FONT_DIR holds one folder per face with roman.ttf and italic.ttf (names
below). The note lists the download URLs. Needs Pillow built with raqm:
`language='bg'` reaches HarfBuzz, which applies the BGR `locl` lookup.

Scale is 2x: 18 dp text, 30 dp line height, 32 em measure (token-plan.md).
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PAPER = '#F4F1ED'
GRAPHITE = '#242725'
MULBERRY = '#753E5E'
NOTE_GREY = '#5A5F5C'

SCALE = 2
READ_PX = 18 * SCALE
LEAD_PX = 30 * SCALE
MEASURE_PX = int(32 * 18 * SCALE)
PAD = 36 * SCALE

# (folder, label, axes for reading text, axes for titles)
FACES = [
    ('sourceserif4', 'Source Serif 4 (variable, opsz 18 / 30)',
     {'wght': 400, 'opsz': 18}, {'wght': 600, 'opsz': 30}),
    ('piazzolla', 'Piazzolla (variable, opsz 18 / 30)',
     {'wght': 400, 'opsz': 18}, {'wght': 600, 'opsz': 30}),
    ('vollkorn', 'Vollkorn (variable)',
     {'wght': 400}, {'wght': 600}),
    ('literata', 'Literata upstream, control: no BGR lookup (opsz 18 / 30)',
     {'wght': 400, 'opsz': 18}, {'wght': 600, 'opsz': 30}),
]

EN = ('A good lesson is quiet. It lets the reader settle in, follow one idea '
      'from the first line to the last, and look up only when the idea is '
      'finished. Long reading asks for calm letters: clear shapes, an even '
      'rhythm and enough air between the lines that the eyes do not tire. '
      'Numbers such as 1,204 and 3.5 should sit comfortably in the text.')
BG = ('Всяка добра лекция е тиха. Тя оставя на читателя време да се '
      'настани, да проследи една мисъл от първия до последния ред и да '
      'вдигне поглед чак когато мисълта е завършила. Дългото четене '
      'изисква спокойни букви: ясни форми, равномерен ритъм и достатъчно '
      'въздух между редовете. Ако текстът е труден, добрият шрифт ѝ '
      'помага, а не ѝ пречи.')
BG_ITALIC = 'Курсивът също има български форми: дълъг, жълт, ключ, птица, вълк, юг.'
GREEK = 'μ σ π Ω Δ θ λ    Δθ = λ · σ / π,  Ω = 2πμ'
TITLE_EN = 'Introduction to statistics'
TITLE_BG = 'Увод в статистиката'


def load(path, size, axes):
    """Opens [path] at [size] px and sets the named variation axes, if any."""
    font = ImageFont.truetype(str(path), size, layout_engine=ImageFont.Layout.RAQM)
    try:
        info = font.get_variation_axes()
    except OSError:
        return font
    values = []
    for axis in info:
        name = axis['name']
        name = name.decode() if isinstance(name, bytes) else name
        tag = {'Weight': 'wght', 'Optical Size': 'opsz', 'Optical size': 'opsz'}.get(name, name)
        values.append(axes.get(tag, axis['default']))
    font.set_variation_by_axes(values)
    return font


def wrap(text, font, width, lang):
    lines, line = [], ''
    for word in text.split(' '):
        trial = f'{line} {word}'.strip()
        if font.getlength(trial, language=lang) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def panel(fonts_dir, folder, label, read_axes, title_axes):
    root = Path(fonts_dir) / folder
    roman = load(root / 'roman.ttf', READ_PX, read_axes)
    italic = load(root / 'italic.ttf', READ_PX, read_axes)
    title = load(root / 'roman.ttf', 30 * SCALE, title_axes)
    cap = ImageFont.truetype(str(Path(fonts_dir) / 'caption.ttf'), 13 * SCALE) \
        if (Path(fonts_dir) / 'caption.ttf').exists() else ImageFont.load_default()

    en = wrap(EN, roman, MEASURE_PX, 'en')
    bg = wrap(BG, roman, MEASURE_PX, 'bg')
    it = wrap(BG_ITALIC, italic, MEASURE_PX, 'bg')
    height = (PAD + LEAD_PX + 2 * 36 * SCALE + (len(en) + len(bg) + len(it) + 2) * LEAD_PX
              + 3 * 18 * SCALE + 2 * PAD)
    im = Image.new('RGB', (MEASURE_PX + 2 * PAD, height), PAPER)
    d = ImageDraw.Draw(im)
    y = PAD
    d.text((PAD, y), label, font=cap, fill=NOTE_GREY)
    y += LEAD_PX + 6 * SCALE
    d.text((PAD, y), TITLE_EN, font=title, fill=MULBERRY, language='en')
    y += 36 * SCALE
    d.text((PAD, y), TITLE_BG, font=title, fill=MULBERRY, language='bg')
    y += 36 * SCALE + 12 * SCALE
    for line in en:
        d.text((PAD, y), line, font=roman, fill=GRAPHITE, language='en')
        y += LEAD_PX
    y += 18 * SCALE
    for line in bg:
        d.text((PAD, y), line, font=roman, fill=GRAPHITE, language='bg')
        y += LEAD_PX
    y += 6 * SCALE
    for line in it:
        d.text((PAD, y), line, font=italic, fill=GRAPHITE, language='bg')
        y += LEAD_PX
    y += 12 * SCALE
    d.text((PAD, y), GREEK, font=roman, fill=GRAPHITE, language='el')
    return im


def widths(fonts_dir):
    """Prints average advance per character of [EN] in em, wght 400, opsz 18."""
    for roman in sorted(Path(fonts_dir).glob('*/roman.ttf')):
        font = load(roman, 1000, {'wght': 400, 'opsz': 18})
        print(f'{roman.parent.name:14} {font.getlength(EN, language="en") / 1000 / len(EN):.3f} em/char')


def main():
    fonts_dir = sys.argv[1]
    if sys.argv[2] == '--widths':
        widths(fonts_dir)
        return
    panels = [panel(fonts_dir, *face) for face in FACES]
    w, h = panels[0].size
    h = max(p.size[1] for p in panels)
    sheet = Image.new('RGB', (2 * w, 2 * h), PAPER)
    for i, p in enumerate(panels):
        sheet.paste(p, ((i % 2) * w, (i // 2) * h))
    sheet.save(sys.argv[2], 'WEBP', quality=90, method=6)


if __name__ == '__main__':
    main()
