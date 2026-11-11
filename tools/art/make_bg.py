"""Draws the four world backgrounds that were still code-drawn (backdrops.gd):
Harbor, Snow, Construction, Sky Port -> art/v3/bg/bg_<world>.png

Style guide "Morning Hybrid", layer stack (back to front):
  1 sky gradient (blue top -> warm horizon)   2 flat sun disc + 2 rings (no glow, no rays)
  (clouds are a separate scrolling layer in the game: art/v3/bg/clouds.png)
  3 far silhouettes: no outline, close to the sky in value
  4 near props: pastel, 3 px tinted ink #4A5875   5 ground strip, then road + curb (y >= 609,
  which the game draws over).
Drawn at 3x and downscaled (Lanczos), saved as a 256-colour dithered PNG (<= 32 KB).

    python tools/art/make_bg.py            # all four
    python tools/art/make_bg.py harbor     # one
"""
import os
import sys
from PIL import Image, ImageDraw

W, H, S = 1280, 720, 3
INK = "#4A5875"
CURB_Y, ROAD_Y = 609, 625
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art", "v3", "bg")


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Canvas:
    def __init__(self, stops):
        self.im = Image.new("RGB", (W * S, H * S))
        px = self.im.load()
        # vertical gradient through the (y, colour) stops
        for y in range(H * S):
            yy = y / S
            c = rgb(stops[-1][1])
            for (y0, c0), (y1, c1) in zip(stops, stops[1:]):
                if y0 <= yy <= y1:
                    t = (yy - y0) / max(1e-6, (y1 - y0))
                    a, b = rgb(c0), rgb(c1)
                    c = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
                    break
            for x in range(0, W * S):
                px[x, y] = c
        self.d = ImageDraw.Draw(self.im)

    # ---- primitives, all in 720p design px -------------------------------
    def _p(self, pts):
        return [(x * S, y * S) for x, y in pts]

    def poly(self, pts, fill, ink=False, w=3):
        self.d.polygon(self._p(pts), fill=fill)
        if ink:
            p = self._p(pts)
            self.d.line(p + [p[0], p[1]], fill=INK, width=w * S, joint="curve")

    def rect(self, x, y, w, h, fill, ink=False, lw=3):
        box = [x * S, y * S, (x + w) * S - 1, (y + h) * S - 1]
        if ink:
            self.d.rectangle(box, fill=fill, outline=INK, width=lw * S)
        else:
            self.d.rectangle(box, fill=fill)

    def circle(self, cx, cy, r, fill, ink=False, lw=3):
        box = [(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S]
        if ink:
            self.d.ellipse(box, fill=fill, outline=INK, width=lw * S)
        else:
            self.d.ellipse(box, fill=fill)

    def line(self, a, b, fill=INK, w=3):
        self.d.line(self._p([a, b]), fill=fill, width=w * S)

    def blend_circle(self, cx, cy, r, colour, alpha):
        layer = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S],
                                      fill=rgb(colour) + (int(255 * alpha),))
        self.im = Image.alpha_composite(self.im.convert("RGBA"), layer).convert("RGB")
        self.d = ImageDraw.Draw(self.im)

    # ---- shared pieces -----------------------------------------------------
    def sun(self, cx, cy):
        self.blend_circle(cx, cy, 112, "#FFE6A6", 0.38)
        self.blend_circle(cx, cy, 80, "#FFEFC2", 0.62)
        self.circle(cx, cy, 56, "#FFF6D8")

    def cloud(self, x, y, k=1.0):
        """Flat union of circles on a flat base: white with a peach underside, no outline."""
        for dy, col in ((7, "#FFDDBE"), (0, "#FFFFFF")):
            for ox, oy, r in ((0, 0, 22), (26, -12, 28), (58, -4, 24), (84, 4, 18)):
                self.circle(x + ox * k, y + (oy + dy) * k, r * k, col)
            self.rect(x - 20 * k, y + (2 + dy) * k, 122 * k, 20 * k, col)
        self.rect(x - 22 * k, y + 22 * k, 126 * k, 8 * k, "#FFDDBE")

    def road(self):
        self.rect(0, CURB_Y, W, 16, "#C9D3E0")
        self.rect(0, CURB_Y, W, 5, "#E9EEF4")
        self.rect(0, ROAD_Y, W, H - ROAD_Y, "#5A5F70")
        self.rect(0, ROAD_Y, W, 5, "#4A4F5C")
        x = -20
        while x < W + 20:
            self.rect(x, ROAD_Y + 46, 56, 8, "#F2F2EC")
            x += 112

    def pine(self, x, base, h, green="#8CCB7A", snow=False):
        hw = h * 0.32
        self.rect(x - 4, base - 12, 8, 14, "#A07457", ink=True, lw=2)
        for i in range(3):
            ty = base - 8 - i * h * 0.26
            w = hw * (1.0 - i * 0.22)
            tri = [(x - w, ty), (x, ty - h * 0.44), (x + w, ty)]
            self.poly(tri, green, ink=True)
            if snow:
                self.poly([(x - w * 0.42, ty - h * 0.25), (x, ty - h * 0.44 + 3), (x + w * 0.42, ty - h * 0.25),
                           (x + w * 0.2, ty - h * 0.2), (x, ty - h * 0.27), (x - w * 0.2, ty - h * 0.2)], "#FFFFFF")

    def save(self, name):
        self.road()
        im = self.im.resize((W, H), Image.LANCZOS)
        im = im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
        path = os.path.normpath(os.path.join(OUT, "bg_%s.png" % name))
        im.save(path, optimize=True)
        print("%s  %d bytes" % (path, os.path.getsize(path)))


# ============================================================================ worlds
def harbor():
    c = Canvas([(0, "#5AAEEA"), (170, "#96CDF0"), (330, "#D6EEF6"), (400, "#FFEFD2"), (430, "#FFE9C4"), (720, "#FFE9C4")])
    c.sun(1060, 110)
    sea = 430
    # far shore: low hills on the horizon, no outline
    c.poly([(140, sea), (300, sea - 26), (470, sea - 12), (640, sea - 30), (860, sea - 10), (1060, sea - 28), (1280, sea - 14), (1280, sea), ], "#CFE2F2")
    # the sea: pale, quieter than gameplay water
    c.rect(0, sea, W, CURB_Y - sea, "#A9D8F3")
    c.rect(0, sea, W, 5, "#D3ECFA")
    for row, y in enumerate((sea + 34, sea + 78, sea + 126)):
        x = 190 + row * 46
        while x < W:
            c.rect(x, y, 30, 4, "#D3ECFA")
            x += 150
    # container ship (near prop, tinted ink)
    sx, sy = 560, sea + 6
    c.poly([(sx, sy - 34), (sx + 470, sy - 34), (sx + 440, sy), (sx + 26, sy)], "#7F96BC", ink=True)
    cols = ["#F4D3C6", "#CFE2F2", "#F5E2B5", "#DCEBD3", "#E3D7EE"]
    for row in range(2):
        for i in range(9):
            if row == 1 and i in (0, 8):
                continue
            c.rect(sx + 40 + i * 42, sy - 34 - 27 * (row + 1), 42, 28, cols[(i * 2 + row * 3) % len(cols)], ink=True, lw=2)
    c.rect(sx + 420, sy - 100, 36, 68, "#E9EEF4", ink=True)
    c.rect(sx + 428, sy - 90, 20, 10, "#B9DDF2")
    # quay cranes (pastel, behind the action)
    for x, h, face in ((380, 300, 1), (1220, 250, -1)):
        col = "#F2CFA4"
        c.rect(x - 8, sea - h, 16, h, col, ink=True)
        c.rect(x - 60 if face > 0 else x - 150, sea - h - 14, 210, 16, col, ink=True)
        c.rect(x - 22, sea - h - 46, 44, 34, col, ink=True)
        hx = x + 120 * face
        c.line((hx, sea - h + 2), (hx, sea - h + 70), INK, 2)
        c.rect(hx - 9, sea - h + 70, 18, 7, "#D39A6A", ink=True, lw=2)
    # gulls
    for gx, gy in ((250, 250), (290, 280), (980, 300)):
        c.line((gx - 11, gy - 4), (gx, gy), INK, 2)
        c.line((gx, gy), (gx + 11, gy - 4), INK, 2)
    c.save("harbor")


def snow():
    c = Canvas([(0, "#6FB0E6"), (170, "#A5CFEF"), (330, "#DDEBF5"), (430, "#FFE9D2"), (540, "#FFF3E4"), (720, "#FFF3E4")])
    c.sun(980, 130)
    base = 520
    # far range: no outline, close to the sky
    for x, top, w in ((120, 300, 420), (480, 250, 480), (900, 290, 460)):
        c.poly([(x, base), (x + w * 0.5, top), (x + w, base)], "#C5D8EC")
        c.poly([(x + w * 0.5 - 46, top + 62), (x + w * 0.5, top), (x + w * 0.5 + 46, top + 62),
                (x + w * 0.5 + 18, top + 48), (x + w * 0.5 - 6, top + 66), (x + w * 0.5 - 24, top + 50)], "#F6FAFF")
    # nearer snow hills
    c.poly([(0, base + 30), (330, base - 40), (560, base + 6), (800, base - 46), (1050, base), (1280, base - 30),
            (1280, CURB_Y), (0, CURB_Y)], "#E9F1F9")
    c.rect(0, base + 50, W, CURB_Y - base - 50, "#F6F9FD")
    c.poly([(0, base + 54), (420, base + 30), (760, base + 52), (1040, base + 34), (1280, base + 50), (1280, base + 70),
            (0, base + 70)], "#F6F9FD")
    # chalet with a snow roof
    hx, hy = 300, base + 50
    c.rect(hx, hy - 44, 84, 46, "#E6BBA3", ink=True)
    c.poly([(hx - 14, hy - 42), (hx + 42, hy - 80), (hx + 98, hy - 42)], "#FFFFFF", ink=True)
    c.rect(hx + 12, hy - 30, 18, 16, "#B9DDF2", ink=True, lw=2)
    c.rect(hx + 50, hy - 28, 18, 30, "#A07457", ink=True, lw=2)
    # snowy pines (kept out from behind the truck bed on the right half)
    for x, h in ((190, 96), (250, 70), (430, 110), (500, 78), (590, 92), (1180, 104), (1240, 76)):
        c.pine(x, base + 54, h, "#8CCB7A", snow=True)
    for x, h in ((680, 60), (760, 50), (900, 56), (1010, 48)):  # small far ones, no outline
        c.poly([(x - h * 0.3, base + 20), (x, base + 20 - h), (x + h * 0.3, base + 20)], "#BFD9C9")
    c.save("snow")


def construction():
    c = Canvas([(0, "#6AAEE6"), (170, "#A6CFEE"), (330, "#FFE3BC"), (430, "#FFD49C"), (560, "#FFEFD6"), (720, "#FFEFD6")])
    c.sun(1050, 120)
    ground = 548
    # far: half-built steel frame, no outline, close to the sky
    frame = "#F0D2A8"
    for i in range(4):
        c.rect(760 + i * 120, 190, 14, ground - 190, frame)
    for j in range(5):
        c.rect(760, 190 + j * 74, 374, 12, frame)
    for i in range(3):
        c.line((774 + i * 120, 276), (880 + i * 120, 338), "#EBC99B", 6)
    # far skyline hint on the left
    for x, top, w in ((170, 380, 70), (250, 340, 60), (560, 400, 90), (650, 360, 60)):
        c.rect(x, top, w, ground - top, "#F7DDB8")
    # ground: packed sand
    c.rect(0, ground, W, CURB_Y - ground, "#F1DDB8")
    c.rect(0, ground, W, 5, "#F8EACB")
    # near: scaffolding (pastel, tinted ink)
    for i in range(3):
        c.rect(192 + i * 70, 300, 10, ground - 300 + 8, "#E9EEF4", ink=True, lw=2)
    for j in range(4):
        c.rect(188, 318 + j * 58, 158, 9, "#E9EEF4", ink=True, lw=2)
    c.line((202, 327), (262, 376), INK, 2)
    c.line((272, 385), (332, 434), INK, 2)
    # sand piles, a cement mixer drum and a barrier
    for x, w, h in ((450, 90, 54), (620, 70, 40), (1160, 100, 58)):
        c.poly([(x - w, ground + 8), (x - w * 0.25, ground - h), (x + w * 0.2, ground - h + 4), (x + w, ground + 8)], "#F5E2B5", ink=True)
        c.poly([(x - w * 0.25, ground - h + 3), (x + w * 0.2, ground - h + 7), (x + w * 0.42, ground - h * 0.45),
                (x - w * 0.1, ground - h * 0.5)], "#FBEFD0")
    for i in range(3):
        bx = 700 + i * 46
        c.poly([(bx, ground + 8), (bx + 12, ground - 22), (bx + 22, ground - 22), (bx + 34, ground + 8)], "#F4D3C6", ink=True, w=2)
        c.rect(bx + 9, ground - 12, 16, 5, "#FFFFFF")
    c.save("construction")


def sky_port():
    c = Canvas([(0, "#4F96E8"), (170, "#86BDF0"), (330, "#C9E3F6"), (430, "#FFEBD0"), (540, "#FFF4E2"), (720, "#FFF4E2")])
    c.sun(1010, 130)
    base = 500
    # peaks poking through the cloud sea: far, no outline
    for x, top, w in ((330, 330, 300), (660, 270, 380), (1010, 340, 290)):
        c.poly([(x, base + 30), (x + w * 0.5, top), (x + w, base + 30)], "#B4C9E3")
        c.poly([(x + w * 0.5 - 40, top + 54), (x + w * 0.5, top), (x + w * 0.5 + 40, top + 54),
                (x + w * 0.5 + 14, top + 42), (x + w * 0.5 - 4, top + 58), (x + w * 0.5 - 22, top + 44)], "#F6FAFF")
    # the cloud sea: three rows of puffs, paler toward the front
    rows = (("#DCE9F7", base - 24), ("#ECF3FB", base + 14), ("#FFFFFF", base + 54))
    for ri, (col, y) in enumerate(rows):
        x = -60 + ri * 37
        k = 0
        while x < W + 80:
            r = 44 + ((k * 13 + ri * 7) % 5) * 9
            c.circle(x, y + 18, r, col)
            x += r * 1.3
            k += 1
        c.rect(0, y + 18, W, CURB_Y - y, col)
    # windsock on the cliff edge (near prop)
    c.rect(300, base + 30, 5, CURB_Y - base - 30, "#E9EEF4", ink=True, lw=2)
    c.poly([(305, base + 32), (340, base + 38), (340, base + 48), (305, base + 52)], "#F4D3C6", ink=True, w=2)
    c.save("sky_port")


WORLDS = {"harbor": harbor, "snow": snow, "construction": construction, "sky_port": sky_port}

if __name__ == "__main__":
    for name in (sys.argv[1:] or list(WORLDS)):
        WORLDS[name]()
