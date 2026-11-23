"""Draws fixture/histogram.png: a histogram of exam scores with labelled axes.

The fixture course's lesson text describes a histogram, so the figure is one.
The background is transparent and the colors are mid-tones, so the figure
reads on the light and the dark page alike. Course authors' own figures keep
their colors; only this owned asset is toned for both schemes.

Run once, from this folder: python3 make_histogram.py
"""

from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 1200, 640
BAR = (155, 91, 128, 255)
INK = (136, 136, 136, 255)

font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 26)
small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 22)

img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

left, right, top, bottom = 130, 1140, 40, 520
counts = [2, 4, 9, 15, 23, 30, 26, 19, 11, 6, 3, 1]
labels = [f"{40 + 5 * i}" for i in range(len(counts) + 1)]
step = (right - left) / len(counts)
scale = (bottom - top) / 35

# Gridlines and the y axis ticks.
for value in range(0, 36, 5):
    y = bottom - value * scale
    d.line([left, y, right, y], fill=(136, 136, 136, 70), width=1)
    d.text((left - 14, y), str(value), font=small, fill=INK, anchor="rm")

for i, count in enumerate(counts):
    x0 = left + i * step + 4
    d.rectangle([x0, bottom - count * scale, x0 + step - 8, bottom], fill=BAR)

d.line([left, top, left, bottom], fill=INK, width=3)
d.line([left, bottom, right, bottom], fill=INK, width=3)

for i, label in enumerate(labels):
    d.text((left + i * step, bottom + 12), label, font=small, fill=INK, anchor="mt")

d.text(((left + right) / 2, bottom + 64), "Exam score (points)", font=font, fill=INK, anchor="mt")

y_label = Image.new("RGBA", (360, 40), (0, 0, 0, 0))
ImageDraw.Draw(y_label).text((180, 20), "Number of students", font=font, fill=INK, anchor="mm")
y_label = y_label.rotate(90, expand=True)
img.alpha_composite(y_label, (6, int((top + bottom) / 2 - 180)))

img.save("fixture/histogram.png", optimize=True)
