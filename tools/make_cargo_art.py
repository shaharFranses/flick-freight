"""Draws the self-made cargo sprites (CC0) in the flat Kenney style of the other cargo:
ice block, tire, plank, gas canister.   python3 tools/make_cargo_art.py
"""
from PIL import Image, ImageDraw

SS = 4  # supersample


def canvas(w, h):
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def save(im, w, h, path):
    im.resize((w, h), Image.LANCZOS).save(path)


def s(*v):
    return [x * SS for x in v]


def ice():
    im, d = canvas(128, 128)
    d.rounded_rectangle(s(2, 2, 126, 126), radius=14 * SS, fill=(126, 190, 228, 255))
    d.rounded_rectangle(s(12, 12, 116, 116), radius=8 * SS, fill=(178, 224, 246, 255))
    d.polygon(s(20, 30, 46, 20, 30, 56), fill=(236, 249, 255, 255))
    d.polygon(s(82, 108, 108, 84, 108, 104), fill=(236, 249, 255, 200))
    d.line(s(60, 30, 96, 66), fill=(126, 190, 228, 255), width=5 * SS)
    d.line(s(40, 80, 58, 98), fill=(126, 190, 228, 255), width=5 * SS)
    save(im, 128, 128, "art/v2/cargo/ice.png")


def tire():
    im, d = canvas(128, 128)
    d.ellipse(s(2, 2, 126, 126), fill=(46, 52, 64, 255))
    for i in range(16):  # tread blocks
        import math
        a = i * math.pi / 8
        cx, cy = 64 + 56 * math.cos(a), 64 + 56 * math.sin(a)
        d.ellipse(s(cx - 6, cy - 6, cx + 6, cy + 6), fill=(30, 34, 42, 255))
    d.ellipse(s(26, 26, 102, 102), fill=(74, 82, 96, 255))
    d.ellipse(s(38, 38, 90, 90), fill=(201, 206, 214, 255))
    d.ellipse(s(56, 56, 72, 72), fill=(74, 82, 96, 255))
    save(im, 128, 128, "art/v2/cargo/tire.png")


def plank():
    im, d = canvas(300, 48)
    d.rounded_rectangle(s(1, 1, 299, 47), radius=8 * SS, fill=(122, 78, 42, 255))
    d.rounded_rectangle(s(6, 6, 294, 42), radius=5 * SS, fill=(168, 116, 68, 255))
    for y, x0, x1 in [(16, 20, 130), (28, 150, 280), (22, 60, 200), (34, 20, 90)]:
        d.line(s(x0, y, x1, y), fill=(147, 99, 58, 255), width=3 * SS)
    for x in (20, 280):
        d.ellipse(s(x - 5, 19, x + 5, 29), fill=(90, 60, 35, 255))
    save(im, 300, 48, "art/v2/cargo/plank.png")


def canister():
    im, d = canvas(96, 128)
    d.rounded_rectangle(s(10, 22, 86, 126), radius=22 * SS, fill=(200, 60, 48, 255))
    d.rounded_rectangle(s(18, 30, 78, 118), radius=16 * SS, fill=(232, 87, 46, 255))
    d.rectangle(s(36, 4, 60, 24), fill=(90, 98, 112, 255))
    d.rectangle(s(30, 2, 66, 10), fill=(120, 128, 140, 255))
    d.rectangle(s(18, 86, 78, 102), fill=(255, 211, 78, 255))  # caution band
    for x in range(18, 78, 14):
        d.polygon(s(x, 102, x + 7, 86, x + 13, 86, x + 6, 102), fill=(27, 42, 65, 255))
    d.ellipse(s(30, 40, 66, 76), fill=(245, 245, 240, 255))  # pressure gauge
    d.ellipse(s(30, 40, 66, 76), outline=(27, 42, 65, 255), width=3 * SS)
    d.line(s(48, 58, 60, 48), fill=(200, 60, 48, 255), width=3 * SS)
    d.ellipse(s(45, 55, 51, 61), fill=(27, 42, 65, 255))
    save(im, 96, 128, "art/v2/cargo/canister.png")


if __name__ == "__main__":
    ice()
    tire()
    plank()
    canister()
