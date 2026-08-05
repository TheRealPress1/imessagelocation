"""Generates assets/extension-icon.png — a map pin inside a speech bubble.

Supersampled 4x and downscaled with LANCZOS so the curves stay clean at the
small sizes Raycast actually renders. Run: python3 assets/make-icon.py
"""
import math
import os
from PIL import Image, ImageDraw

S, SS = 512, 4          # final size, supersample factor
W = S * SS
OUT = os.path.join(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets"), "extension-icon.png")

TOP, BOTTOM = (74, 144, 255), (26, 76, 176)   # map-blue gradient
PIN_BLUE = (37, 99, 214, 255)


def tangent_points(cx, cy, r, tip_y):
    """Where the teardrop's straight flanks meet the circular head.

    For an external point P below centre C, the angle at C between C->P and
    each tangency point is arccos(r / |CP|) — so a triangle drawn through
    those two points and the tip unions with the circle seamlessly.
    """
    d = tip_y - cy
    phi = math.acos(r / d)
    dx, dy = r * math.sin(phi), r * math.cos(phi)
    return (cx - dx, cy + dy), (cx + dx, cy + dy)


def draw_pin(draw, cx, cy, r, tip_y, fill, hole=None):
    left, right = tangent_points(cx, cy, r, tip_y)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)
    draw.polygon([left, (cx, tip_y), right], fill=fill)
    if hole:
        hr = r * 0.40
        draw.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=hole)


img = Image.new("RGBA", (W, W), (0, 0, 0, 0))

# Vertical gradient, clipped to a squircle-ish rounded square.
column = Image.new("RGB", (1, W))
for y in range(W):
    t = y / (W - 1)
    column.putpixel((0, y), tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, W - 1], radius=int(W * 0.223), fill=255)
img.paste(column.resize((W, W)), (0, 0), mask)

d = ImageDraw.Draw(img)

# Speech bubble: the "this is a message" half of the idea.
d.rounded_rectangle([W * 0.155, W * 0.165, W * 0.845, W * 0.675], radius=W * 0.135, fill=(255, 255, 255, 255))
d.polygon([(W * 0.275, W * 0.640), (W * 0.455, W * 0.640), (W * 0.255, W * 0.855)], fill=(255, 255, 255, 255))

# Pin: the "this is a place" half.
draw_pin(d, W * 0.50, W * 0.378, W * 0.108, W * 0.590, PIN_BLUE, hole=(255, 255, 255, 255))

img.resize((S, S), Image.LANCZOS).save(OUT)
print(f"wrote {OUT}")
