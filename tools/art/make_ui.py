"""Draws the UI icons that were still Kenney stock, in the same language as the existing
art/v3/ui glyphs (pause, sound): chunky white rounded shapes on alpha, tinted by the button.

    python tools/art/make_ui.py        ->  art/v3/ui/home.png   (80x80, 2x of 40)
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art", "v3", "ui")
SS = 8  # supersample
WHITE = (255, 255, 255, 255)
CLEAR = (255, 255, 255, 0)


def home(size=80):
    n = size * SS
    im = Image.new("RGBA", (n, n), CLEAR)
    d = ImageDraw.Draw(im)
    u = n / 80.0

    def P(pts):
        return [(x * u, y * u) for x, y in pts]

    # roof: a fat rounded chevron
    d.line(P([(11, 41), (40, 14), (69, 41)]), fill=WHITE, width=int(13 * u), joint="curve")
    for x, y in ((11, 41), (69, 41), (40, 14)):
        d.ellipse([(x - 6.5) * u, (y - 6.5) * u, (x + 6.5) * u, (y + 6.5) * u], fill=WHITE)
    d.polygon(P([(40, 20), (62, 41), (18, 41)]), fill=WHITE)
    # body with a door cut out
    d.rounded_rectangle([19 * u, 36 * u, 61 * u, 70 * u], radius=6 * u, fill=WHITE)
    d.rounded_rectangle([33.5 * u, 49 * u, 46.5 * u, 74 * u], radius=3 * u, fill=CLEAR)
    im = im.resize((size, size), Image.LANCZOS)
    path = os.path.normpath(os.path.join(OUT, "home.png"))
    im.save(path, optimize=True)
    print("%s  %d bytes" % (path, os.path.getsize(path)))


if __name__ == "__main__":
    home()
