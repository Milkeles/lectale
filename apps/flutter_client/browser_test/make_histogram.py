"""Draws fixture/histogram.png: a histogram of exam scores with labelled axes.

The fixture course's lesson text describes a histogram, so the figure is one.
It is drawn the way a course author would commit it: white ground, dark
labels, rounded corners.

Run once, from this folder: python3 make_histogram.py
"""

from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 900, 520
# The way a course author would commit it: a white ground with dark labels
# and rounded corners. On the dark page it is a light plate, which is the
# realistic case the reader has to handle. Ink is 10 to 1 on white.
GROUND = (255, 255, 255, 255)
INK = (58, 62, 59, 255)
BAR = (117, 62, 94, 255)
GRID = (214, 214, 214, 255)
RADIUS = 28

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

mask = Image.new("L", (WIDTH, HEIGHT), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, WIDTH - 1, HEIGHT - 1], RADIUS, fill=255)
img.putalpha(mask)
img.save("fixture/histogram.png", optimize=True)
