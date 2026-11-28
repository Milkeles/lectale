"""Draws fixture/histogram.png: a histogram of exam scores with labelled axes.

The fixture course's lesson text describes a histogram, so the figure is one.
It has its own mid-tone ground, so it reads on the light and the dark page
alike, with labels at 4.5 to 1 or better. Course authors' own figures keep
their colors; only this owned asset is toned for both schemes.

Run once, from this folder: python3 make_histogram.py
"""

from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 900, 520
# One asset has to read on the light and the dark page, so it carries its own
# mid-tone ground. Labels are off-white on it: 5.5 to 1, above the 4.5 to 1
# that text needs. Bars are a light mulberry, 3.1 to 1 against the ground.
GROUND = (95, 100, 95, 255)
INK = (244, 241, 237, 255)
BAR = (224, 167, 192, 255)
GRID = (130, 135, 130, 255)

font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 28)
small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 26)

img = Image.new("RGBA", (WIDTH, HEIGHT), GROUND)
d = ImageDraw.Draw(img)

left, right, top, bottom = 100, 870, 24, 400
counts = [2, 4, 9, 15, 23, 30, 26, 19, 11, 6, 3, 1]
labels = [f"{40 + 10 * k}" for k in range(7)]
step = (right - left) / len(counts)
scale = (bottom - top) / 35

for value in range(0, 36, 10):
    y = bottom - value * scale
    d.line([left, y, right, y], fill=GRID, width=1)
    d.text((left - 12, y), str(value), font=small, fill=INK, anchor="rm")

for i, count in enumerate(counts):
    x0 = left + i * step + 3
    d.rectangle([x0, bottom - count * scale, x0 + step - 6, bottom], fill=BAR)

d.line([left, top, left, bottom], fill=INK, width=3)
d.line([left, bottom, right, bottom], fill=INK, width=3)

for i, label in enumerate(labels):
    d.text((left + i * 2 * step, bottom + 10), label, font=small, fill=INK, anchor="mt")

d.text(((left + right) / 2, bottom + 56), "Exam score (points)", font=font, fill=INK, anchor="mt")

y_label = Image.new("RGBA", (360, 40), (0, 0, 0, 0))
ImageDraw.Draw(y_label).text((180, 20), "Students", font=font, fill=INK, anchor="mm")
y_label = y_label.rotate(90, expand=True)
img.alpha_composite(y_label, (6, int((top + bottom) / 2 - 180)))

img.convert("RGB").save("fixture/histogram.png", optimize=True)
