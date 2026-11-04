#!/usr/bin/env python3
"""Generates every sprite of POST 404 as original pixel art with one palette.

Run from the project root:  python3 tools/make_art.py
Output: assets/sprites/*.png (1x pixel size; the game scales them with
nearest-neighbour filtering). Everything here is drawn procedurally or from
the ASCII maps below, so the art is original and license-free.
"""
import math
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
os.makedirs(OUT, exist_ok=True)

# ----------------------------------------------------------------- palette
P = {
    "ink": (20, 18, 36), "ink2": (31, 27, 51), "ink3": (45, 39, 71),
    "wall": (58, 49, 80), "wall2": (75, 64, 103), "wall3": (93, 84, 128),
    "wood0": (54, 33, 30), "wood": (74, 47, 39), "wood2": (107, 68, 48), "wood3": (140, 92, 58), "wood4": (176, 122, 74),
    "card0": (110, 70, 40), "card": (138, 90, 53), "card2": (176, 122, 72), "card3": (211, 160, 102), "card4": (232, 196, 140),
    "paper": (242, 230, 201), "paper2": (255, 246, 224), "paper0": (205, 188, 160),
    "met0": (52, 62, 80), "met": (76, 90, 110), "met2": (111, 129, 153), "met3": (159, 177, 199), "met4": (212, 224, 238),
    "cy0": (20, 70, 96), "cy": (31, 111, 139), "cy2": (47, 180, 201), "cy3": (127, 240, 240),
    "am0": (98, 52, 20), "am": (138, 75, 22), "am2": (208, 138, 46), "am3": (245, 192, 86), "am4": (255, 228, 150),
    "gr0": (24, 70, 48), "gr": (46, 125, 79), "gr2": (79, 192, 106), "gr3": (166, 240, 160),
    "mg0": (70, 24, 70), "mg": (122, 42, 110), "mg2": (201, 79, 176), "mg3": (255, 138, 230),
    "rd0": (90, 24, 36), "rd": (158, 43, 58), "rd2": (224, 72, 90), "rd3": (255, 140, 140),
    "go0": (122, 80, 16), "go": (184, 134, 11), "go2": (232, 185, 35), "go3": (255, 240, 138),
    "sk0": (140, 82, 60), "sk": (196, 128, 92), "sk2": (232, 170, 128), "sk3": (248, 206, 168),
    "white": (255, 255, 255), "glass": (120, 170, 210),
    "night": (24, 26, 52), "night2": (40, 44, 84), "night3": (62, 70, 120),
}


def C(c, a=255):
    if isinstance(c, str):
        c = P[c]
    return (c[0], c[1], c[2], a)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p = self.img.load()

    def px(self, x, y, c, a=255):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = C(c, a)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.p[x, y]
        return (0, 0, 0, 0)

    def rect(self, x0, y0, x1, y1, c, a=255):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.px(x, y, c, a)

    def frame(self, x0, y0, x1, y1, c):
        self.hline(x0, x1, y0, c)
        self.hline(x0, x1, y1, c)
        self.vline(x0, y0, y1, c)
        self.vline(x1, y0, y1, c)

    def hline(self, x0, x1, y, c, a=255):
        for x in range(int(x0), int(x1) + 1):
            self.px(x, y, c, a)

    def vline(self, x, y0, y1, c, a=255):
        for y in range(int(y0), int(y1) + 1):
            self.px(x, y, c, a)

    def disc(self, cx, cy, r, c, a=255):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.3:
                    self.px(x, y, c, a)

    def ring(self, cx, cy, r, c, th=1.0):
        for y in range(int(cy - r - 2), int(cy + r + 3)):
            for x in range(int(cx - r - 2), int(cx + r + 3)):
                d = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
                if r - th < d <= r + 0.35:
                    self.px(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c, a=255):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x - cx) / max(rx, 0.1)) ** 2 + ((y - cy) / max(ry, 0.1)) ** 2 <= 1.02:
                    self.px(x, y, c, a)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            self.px(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)

    def outline(self, c="ink"):
        """Adds a 1px outline around all opaque pixels (outside)."""
        src = self.img.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] > 0 and src[nx, ny][:3] != C(c)[:3]:
                            self.p[x, y] = C(c)
                            break

    def paste(self, other, x, y):
        self.img.alpha_composite(other.img if isinstance(other, Canvas) else other, (int(x), int(y)))
        self.p = self.img.load()

    def ascii(self, rows, keys, ox=0, oy=0):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in keys and keys[ch] is not None:
                    self.px(ox + i, oy + j, keys[ch])

    def save(self, name):
        self.img.save(os.path.join(OUT, name + ".png"))
        return self


def strip(frames, name):
    w, h = frames[0].w, frames[0].h
    s = Canvas(w * len(frames), h)
    for i, f in enumerate(frames):
        s.paste(f, i * w, 0)
    s.save(name)


rnd = random.Random(404)

# ------------------------------------------------------------- background

def wall_tile():
    c = Canvas(32, 32)
    c.rect(0, 0, 31, 31, "wall")
    # plaster panels with subtle bricks
    for row in range(4):
        y = row * 8
        off = 0 if row % 2 == 0 else 8
        c.hline(0, 31, y, "ink3")
        for x in range(off, 32, 16):
            c.vline(x, y, y + 7, "ink3")
        for x in range(0, 32):
            if rnd.random() < 0.08:
                c.px(x, y + 1 + rnd.randint(0, 5), "wall2")
    for i in range(10):
        c.px(rnd.randint(0, 31), rnd.randint(0, 31), "wall3")
    c.save("wall_tile")


def wainscot_tile():
    c = Canvas(32, 40)
    c.rect(0, 0, 31, 39, "wood2")
    c.rect(0, 0, 31, 3, "wood4")
    c.hline(0, 31, 4, "wood")
    for x0 in (2, 18):
        c.rect(x0, 8, x0 + 11, 35, "wood")
        c.rect(x0 + 1, 9, x0 + 10, 34, "wood3")
        c.rect(x0 + 2, 10, x0 + 9, 33, "wood2")
        c.hline(x0 + 1, x0 + 10, 9, "wood4")
    c.hline(0, 31, 38, "wood0")
    c.hline(0, 31, 39, "ink")
    c.save("wainscot_tile")


def floor_tile():
    c = Canvas(32, 16)
    c.rect(0, 0, 31, 15, "ink3")
    for x in range(0, 32, 16):
        c.rect(x + 1, 1, x + 14, 6, "wall")
        c.rect(x + 9, 9, x + 22 if x + 22 < 32 else 31, 14, "wall")
    c.rect(0, 9, 6, 14, "wall")
    c.hline(0, 31, 0, "ink2")
    c.save("floor_tile")


def city(mood):
    c = Canvas(64, 44)
    sky = {"grey": ("night", "night2", "night3"), "warm": ("am0", "rd", "am2"), "neat": ("cy0", "cy", "met2"),
           "bright": ("mg", "mg2", "am3")}[mood]
    for y in range(44):
        t = y / 43
        col = sky[0] if t < 0.35 else (sky[1] if t < 0.7 else sky[2])
        c.hline(0, 63, y, col)
        if 0.3 < t < 0.4 and y % 2 == 0:
            for x in range(0, 64, 2):
                c.px(x + (y // 2) % 2, y, sky[1])
        if 0.65 < t < 0.75 and y % 2 == 0:
            for x in range(0, 64, 2):
                c.px(x + (y // 2) % 2, y, sky[2])
    r = random.Random(7)
    for i in range(14):
        c.px(r.randint(0, 63), r.randint(0, 14), "white" if mood != "warm" else "am4")
    if mood in ("grey", "neat"):
        # The ORACLE tower with its red eye.
        c.rect(28, 4, 35, 43, "ink2")
        c.rect(30, 0, 33, 4, "ink2")
        c.disc(31.5, 8, 2, "rd2" if mood == "grey" else "cy3")
    buildings = [(0, 22, 9), (8, 28, 7), (14, 18, 8), (21, 26, 6), (37, 20, 9), (45, 30, 6), (50, 16, 7), (57, 24, 7)]
    for (x, top, w) in buildings:
        col = "ink3" if mood != "bright" else "wall2"
        c.rect(x, top, x + w, 43, col)
        c.hline(x, x + w, top, "wall3")
        for wy in range(top + 2, 42, 3):
            for wx in range(x + 1, x + w, 2):
                lit = r.random() < {"grey": 0.15, "warm": 0.55, "neat": 0.35, "bright": 0.7}[mood]
                if lit:
                    c.px(wx, wy, {"grey": "met2", "warm": "am3", "neat": "cy3", "bright": "go3"}[mood])
    if mood in ("warm", "bright"):
        # Lanterns and string lights of a returned festival.
        for x in range(0, 64, 4):
            yy = 33 + int(2 * math.sin(x / 6))
            c.px(x, yy, "ink2")
            if x % 8 == 0:
                c.px(x, yy + 1, "go3" if mood == "bright" else "am3")
        if mood == "bright":
            for i in range(5):
                bx, by = r.randint(4, 60), r.randint(6, 18)
                c.disc(bx, by, 1, "mg3")
                c.px(bx, by + 2, "go3")
    if mood == "neat":
        for x in range(0, 64, 6):
            c.vline(x + 2, 38, 43, "cy2")
    c.save("city_" + mood)


def window():
    c = Canvas(72, 54)
    c.rect(0, 6, 71, 53, "wood2")
    c.ellipse(35.5, 10, 35.5, 10, "wood2")
    c.rect(4, 8, 67, 49, (0, 0, 0))
    c.ellipse(35.5, 11, 31.5, 8, (0, 0, 0))
    # cut glass hole to transparent (city goes behind)
    for y in range(c.h):
        for x in range(c.w):
            if c.get(x, y)[:3] == (0, 0, 0) and c.get(x, y)[3] == 255:
                c.p[x, y] = (0, 0, 0, 0)
    c.vline(35, 2, 49, "wood3")
    c.vline(36, 2, 49, "wood")
    c.hline(4, 67, 28, "wood3")
    c.hline(4, 67, 29, "wood")
    c.rect(0, 50, 71, 53, "wood4")
    c.hline(0, 71, 53, "wood0")
    c.outline()
    c.save("window")


def shelf():
    c = Canvas(44, 60)
    c.rect(0, 0, 43, 59, "wood")
    c.rect(2, 2, 41, 57, "wood0")
    for row in range(5):
        for col in range(4):
            x0, y0 = 3 + col * 10, 3 + row * 11
            c.rect(x0, y0, x0 + 8, y0 + 9, "ink2")
            c.hline(x0, x0 + 8, y0 + 9, "wood3")
            k = rnd.random()
            if k < 0.75:
                # letters and small parcels in pigeonholes
                h = rnd.randint(4, 7)
                colr = rnd.choice(["paper", "paper0", "card3", "am3", "cy3", "paper2"])
                c.rect(x0 + 1, y0 + 9 - h, x0 + 7 - rnd.randint(0, 2), y0 + 8, colr)
                c.hline(x0 + 1, x0 + 5, y0 + 9 - h, "white")
                if rnd.random() < 0.4:
                    c.px(x0 + 4, y0 + 10 - h + 1, "rd2")
    c.rect(0, 0, 43, 1, "wood3")
    c.outline()
    c.save("shelf")


def clock():
    c = Canvas(22, 22)
    c.disc(10.5, 10.5, 10, "wood3")
    c.disc(10.5, 10.5, 8, "paper")
    for i in range(12):
        a = i / 12 * math.tau
        c.px(10.5 + 7 * math.sin(a), 10.5 - 7 * math.cos(a), "ink3")
    c.line(10, 10, 10, 5, "ink")
    c.line(10, 10, 14, 12, "rd")
    c.px(10, 10, "ink")
    c.outline()
    c.save("clock")


def pipes():
    c = Canvas(16, 10)
    c.rect(0, 1, 15, 8, "met2")
    c.hline(0, 15, 2, "met4")
    c.hline(0, 15, 7, "met")
    c.rect(6, 0, 9, 9, "am2")
    c.hline(6, 9, 1, "am4")
    c.hline(0, 15, 0, "ink")
    c.hline(0, 15, 9, "ink")
    c.save("pipe_h")


def tube_present():
    frames = []
    for f in range(4):
        c = Canvas(40, 64)
        c.rect(10, 0, 29, 63, "glass", 110)
        c.rect(12, 0, 27, 63, "gr3", 40)
        # rising green glow bands
        for k in range(4):
            y = (k * 16 - f * 4) % 64
            c.rect(12, y, 27, y + 2, "gr2", 120)
        c.vline(13, 0, 63, "white", 120)
        c.vline(10, 0, 63, "met3")
        c.vline(29, 0, 63, "met")
        for y in (4, 34):
            c.rect(8, y, 31, y + 4, "am2")
            c.hline(8, 31, y, "am4")
            c.hline(8, 31, y + 4, "am0")
        # mouth
        c.rect(4, 52, 35, 63, "met2")
        c.rect(6, 55, 33, 63, "ink2")
        c.rect(8, 57, 31, 63, "gr", 255)
        c.rect(10, 58, 29, 63, "gr2" if f % 2 == 0 else "gr3")
        c.hline(4, 35, 52, "met4")
        c.outline()
        frames.append(c)
    strip(frames, "tube_present")


def portal(kind):
    pal = {"past": ("am0", "am", "am2", "am3", "am4"), "future": ("cy0", "cy", "cy2", "cy3", "white")}[kind]
    frames = []
    for f in range(4):
        c = Canvas(48, 88)
        # arch frame (stone/brass)
        frame_col = ("wood3", "wood2", "wood0") if kind == "past" else ("met3", "met2", "met0")
        c.rect(2, 20, 45, 87, frame_col[1])
        c.ellipse(23.5, 22, 21.5, 20, frame_col[1])
        c.rect(7, 24, 40, 84, "ink")
        c.ellipse(23.5, 25, 16.5, 17, "ink")
        # swirl
        for y in range(8, 85):
            for x in range(7, 41):
                if c.get(x, y)[:3] != P["ink"]:
                    continue
                dx, dy = (x - 23.5) / 17, (y - 46) / 38
                d = math.sqrt(dx * dx + dy * dy)
                a = math.atan2(dy, dx)
                v = math.sin(a * 3 + d * 9 - f * math.pi / 2)
                idx = 0 if d > 0.95 else (1 if v < -0.3 else (2 if v < 0.4 else 3))
                if d < 0.22:
                    idx = 4
                c.px(x, y, pal[idx])
        # rim highlights and rivets / ornaments
        c.vline(2, 22, 87, frame_col[0])
        c.vline(45, 22, 87, frame_col[2])
        for y in range(30, 86, 10):
            c.px(4, y, pal[3])
            c.px(43, y, pal[3])
        c.rect(0, 82, 47, 87, frame_col[2])
        c.hline(0, 47, 82, frame_col[0])
        # glyph: hourglass for past, rocket-star for future
        if kind == "past":
            c.ascii(["#####", ".###.", "..#..", ".#.#.", "#####"], {"#": "am4"}, 21, 4)
        else:
            c.ascii(["..#..", ".###.", "#####", ".###.", "..#.."], {"#": "cy3"}, 21, 4)
        c.outline()
        frames.append(c)
    strip(frames, "portal_" + kind)


def hatch():
    for name, open_ in (("hatch", False), ("hatch_open", True)):
        c = Canvas(64, 22)
        c.rect(0, 0, 63, 21, "met")
        c.rect(2, 2, 61, 19, "ink")
        if not open_:
            for x in range(-20, 64, 8):
                for y in range(3, 19):
                    for k in range(4):
                        xx = x + y + k
                        if 3 <= xx <= 60:
                            c.px(xx, y, "mg2")
            c.rect(26, 6, 37, 15, "ink")
            c.ascii(["..##..", ".#..#.", "#.##.#", "#.##.#", ".#..#.", "..##.."], {"#": "mg3"}, 29, 8)
        else:
            c.rect(3, 3, 60, 18, "mg0")
            c.rect(6, 6, 57, 15, "mg")
            c.rect(12, 8, 51, 13, "mg2")
        c.hline(0, 63, 0, "met3")
        c.outline()
        c.save(name)


def belt():
    frames = []
    for f in range(4):
        c = Canvas(16, 14)
        c.rect(0, 0, 15, 13, "met0")
        c.rect(0, 1, 15, 9, "ink2")
        for x in range(-4, 20, 4):
            xx = x + f
            c.vline(xx, 2, 8, "met")
            c.px(xx, 2, "met2")
        c.hline(0, 15, 1, "met2")
        c.hline(0, 15, 10, "met3")
        c.rect(0, 11, 15, 13, "met")
        for x in range(0, 16, 8):
            c.disc(x + 3 + (f % 2), 12, 1, "met2")
        c.hline(0, 15, 13, "ink")
        frames.append(c)
    strip(frames, "belt")


def pad():
    for name, col in (("pad", "cy2"), ("pad_ok", "gr2"), ("pad_bad", "rd2")):
        c = Canvas(80, 16)
        c.ellipse(39.5, 7, 39.5, 7, "met")
        c.ellipse(39.5, 6, 37.5, 5, "met2")
        c.ellipse(39.5, 6, 31.5, 3.5, "met0")
        c.ellipse(39.5, 6, 29.5, 2.5, col, 150)
        for i in range(8):
            a = i / 8 * math.tau
            c.px(39.5 + 35 * math.cos(a), 6.5 + 5 * math.sin(a), col)
        c.rect(30, 12, 49, 15, "met0")
        c.outline()
        c.save(name)


def today_board():
    c = Canvas(84, 30)
    c.rect(0, 0, 83, 29, "wood2")
    c.rect(2, 2, 81, 27, "ink")
    c.rect(3, 3, 80, 26, "ink2")
    c.hline(3, 80, 14, "ink")
    c.hline(0, 83, 0, "wood4")
    for x in (6, 77):
        c.px(x, 6, "am3")
        c.px(x, 23, "am3")
    c.outline()
    c.save("today_board")


# ------------------------------------------------------------------ boxes
LABEL = (8, 13, 25, 22)   # sticker rectangle inside every box sprite (x0,y0,x1,y1)


def label(c, col="paper2"):
    x0, y0, x1, y1 = LABEL
    c.rect(x0, y0, x1, y1, col)
    c.hline(x0, x1, y1, "paper0")
    c.px(x0, y0, "paper0")


def box_cardboard():
    c = Canvas(34, 30)
    c.rect(1, 9, 32, 28, "card2")
    c.rect(1, 3, 32, 9, "card3")       # top face
    c.hline(1, 32, 3, "card4")
    c.hline(1, 32, 9, "card")
    c.rect(14, 3, 19, 12, "card4")     # tape
    c.hline(14, 19, 12, "card")
    c.vline(1, 9, 28, "card3")
    c.vline(32, 9, 28, "card")
    c.hline(1, 32, 28, "card0")
    label(c)
    c.outline()
    return c


def box_paper():
    c = Canvas(34, 30)
    c.rect(2, 6, 31, 28, "card3")
    c.rect(2, 3, 31, 6, "card4")
    for y in range(7, 28, 3):
        c.px(4 + (y * 7) % 25, y, "card2")
    c.vline(23, 3, 28, "rd")
    c.hline(2, 31, 9, "rd")
    c.ascii(["#.#", ".#.", "#.#"], {"#": "rd2"}, 22, 7)
    c.hline(2, 31, 28, "card")
    label(c)
    c.outline()
    return c


def box_crate():
    c = Canvas(34, 30)
    c.rect(1, 4, 32, 28, "wood3")
    for y in (4, 12, 20):
        c.hline(1, 32, y, "wood4")
        c.hline(1, 32, y + 7, "wood")
    c.rect(1, 4, 4, 28, "wood2")
    c.rect(29, 4, 32, 28, "wood2")
    for (x, y) in ((2, 5), (30, 5), (2, 26), (30, 26)):
        c.px(x, y, "met3")
    label(c, "paper")
    c.outline()
    return c


def box_envelope():
    c = Canvas(34, 30)
    c.rect(1, 8, 32, 27, "paper")
    c.line(1, 8, 16, 18, "paper0")
    c.line(32, 8, 17, 18, "paper0")
    c.hline(1, 32, 27, "paper0")
    c.rect(26, 10, 30, 14, "rd2")
    c.px(28, 12, "paper2")
    c.disc(16.5, 18, 2, "rd")
    label(c, "paper2")
    c.outline()
    return c


def box_tube():
    c = Canvas(34, 30)
    c.rect(2, 9, 31, 26, "am2")
    c.hline(2, 31, 10, "am3")
    c.hline(2, 31, 25, "am")
    c.rect(0, 8, 3, 27, "met2")
    c.rect(30, 8, 33, 27, "met2")
    c.vline(1, 9, 26, "met4")
    c.vline(31, 9, 26, "met4")
    label(c)
    c.outline()
    return c


def box_metal():
    c = Canvas(34, 30)
    c.rect(1, 5, 32, 28, "met2")
    c.rect(1, 2, 32, 5, "met3")
    c.hline(1, 32, 2, "met4")
    c.hline(3, 30, 8, "cy3")
    c.hline(3, 30, 25, "cy2")
    c.rect(1, 5, 2, 28, "met3")
    c.rect(31, 5, 32, 28, "met")
    for x in (4, 29):
        c.px(x, 4, "cy3")
    label(c, "met4")
    c.outline()
    return c


def box_mystery():
    c = Canvas(34, 30)
    c.rect(1, 6, 32, 28, "mg")
    c.rect(1, 2, 32, 6, "mg2")
    c.hline(1, 32, 2, "mg3")
    for i in range(16):
        c.px(rnd.randint(2, 31), rnd.randint(7, 27), "mg3")
    c.rect(1, 6, 2, 28, "mg2")
    c.hline(1, 32, 28, "mg0")
    c.ascii([".##.", "#..#", "..#.", ".#..", "....", ".#.."], {"#": "go3"}, 26, 3)
    label(c, "paper")
    c.outline()
    return c


def box_hazard(f=0):
    c = Canvas(34, 30)
    c.rect(4, 4, 29, 28, "met0")
    c.rect(6, 4, 27, 28, "met")
    glow = ["mg2", "mg3", "mg2", "mg"][f % 4]
    c.rect(8, 6, 25, 26, glow)
    c.rect(10, 8, 23, 24, "mg3" if f % 2 == 0 else "mg2")
    c.rect(3, 2, 30, 5, "met3")
    c.rect(3, 26, 30, 29, "met3")
    c.hline(3, 30, 2, "met4")
    for x in range(4, 30, 4):
        c.px(x, 27, "go2")
        c.px(x + 1, 28, "ink")
    label(c, "go3")
    c.outline()
    return c


def box_gold():
    c = Canvas(34, 30)
    c.rect(1, 8, 32, 28, "go2")
    c.rect(1, 3, 32, 8, "go3")
    c.hline(1, 32, 8, "go")
    c.rect(15, 3, 18, 28, "rd2")
    c.rect(1, 15, 32, 16, "rd2")
    c.ascii(["##..##", "#.##.#", ".####."], {"#": "rd"}, 14, 0)
    c.vline(32, 8, 28, "go")
    c.hline(1, 32, 28, "go0")
    label(c, "paper2")
    c.outline()
    return c


def boxes():
    for name, fn in (("cardboard", box_cardboard), ("paper", box_paper), ("crate", box_crate),
                     ("envelope", box_envelope), ("tube", box_tube), ("metal", box_metal),
                     ("mystery", box_mystery), ("gold", box_gold)):
        fn().save("box_" + name)
    strip([box_hazard(i) for i in range(4)], "box_hazard")


# ------------------------------------------------------------------ icons
ICONS = {
    "coin": (["..####..", ".#oooo#.", "#oo##oo#", "#o#oo#o#", "#o#oo#o#", "#oo##oo#", ".#oooo#.", "..####.."],
             {"#": "go0", "o": "go2"}),
    "shard": (["...#...", "..#c#..", ".#cwc#.", "#cccc#.", ".#ccc#.", "..#c#..", "...#..."],
              {"#": "cy0", "c": "cy2", "w": "cy3"}),
    "xp": (["...#...", "..#y#..", "##yyy##", "#yyyyy#", ".#yyy#.", ".#y#y#.", "##...##"],
           {"#": "am0", "y": "am3"}),
    "heart": ([".##.##.", "#rr#rr#", "#rrrrr#", "#rrrrr#", ".#rrr#.", "..#r#..", "...#..."],
              {"#": "rd0", "r": "rd2"}),
    "heart_empty": ([".##.##.", "#..#..#", "#.....#", "#.....#", ".#...#.", "..#.#..", "...#..."],
                    {"#": "ink3"}),
    "flame": (["...#....", "..#o#...", "..#oo#..", ".#oyo#..", "#oyyo#.#", "#oyyyo#o", ".#oyyo#.", "..####.."],
              {"#": "rd0", "o": "rd2", "y": "am3"}),
    "pause": (["##.##", "##.##", "##.##", "##.##", "##.##"], {"#": "paper2"}),
    "gear": (["..#.#..", ".#####.", "##...##", ".#.#.#.", "##...##", ".#####.", "..#.#.."], {"#": "paper2"}),
    "mail": (["#########", "##.....##", "#.#...#.#", "#..#.#..#", "#...#...#", "#########"], {"#": "paper2"}),
    "book": ([".######.", "#o#oooo#", "#o#oooo#", "#o#oooo#", "#o#oooo#", "#o######", "#o#....."],
             {"#": "paper2", "o": "am2"}),
    "lock": (["..###..", ".#...#.", ".#...#.", "#######", "#ooooo#", "#oo#oo#", "#######"],
             {"#": "met3", "o": "met"}),
    "check": (["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."], {"#": "gr2"}),
    "star": (["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "#.....#"], {"#": "go2"}),
    "star_empty": (["...#...", "...#...", "#######", ".#...#.", "..#.#..", ".##.##.", "#.....#"], {"#": "ink3"}),
    "clock_small": (["..###..", ".#...#.", "#..#..#", "#..##.#", "#.....#", ".#...#.", "..###.."], {"#": "rd2"}),
    "chain": (["##.....", "#.#....", ".###...", "..#.#..", "...###.", "....#.#", ".....##"], {"#": "cy3"}),
    "hazard": (["...#...", "..#y#..", "..#y#..", ".#yky#.", ".#yky#.", "#yyyyy#", "#######"],
               {"#": "ink", "y": "go2", "k": "ink"}),
    "trophy": (["#######", "#.yyy.#", ".#yyy#.", "..#y#..", "...#...", "..###..", ".#####."], {"#": "go0", "y": "go2", ".": None}),
    "calendar": (["#.#.#.#", "#######", "#.....#", "#.#.#.#", "#.....#", "#.#.#.#", "#######"], {"#": "paper2"}),
    "home": (["...#...", "..###..", ".#####.", "#######", ".#...#.", ".#.#.#.", ".#.#.#."], {"#": "paper2"}),
    "play": (["#....", "##...", "###..", "####.", "###..", "##...", "#...."], {"#": "paper2"}),
    "music": (["..####", "..#..#", "..#..#", "..#..#", "###.##", "###.##"], {"#": "paper2"}),
    "story": (["..###..", ".#...#.", ".....#.", "....#..", "...#...", ".......", "...#..."], {"#": "go3"}),
}


def icons():
    for name, (rows, keys) in ICONS.items():
        w = max(len(r) for r in rows)
        c = Canvas(w, len(rows))
        c.ascii(rows, keys)
        c.save("ic_" + name)
    arrows = {
        "left": ["....#....", "...##....", "..#######", ".########", "#########", ".########", "..#######", "...##....", "....#...."],
    }
    a = Canvas(9, 9)
    a.ascii(arrows["left"], {"#": "paper2"})
    a.save("arrow_left")
    a.img.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(OUT, "arrow_right.png"))
    a.img.rotate(-90).save(os.path.join(OUT, "arrow_up.png"))
    a.img.rotate(90).save(os.path.join(OUT, "arrow_down.png"))
    # pointer hand for the tutorial
    h = Canvas(12, 14)
    h.ascii(["...##.......", "..#ww#......", "..#ww#......", "..#ww###....", "..#ww#ww##..", "###ww#ww#w#.",
             "#ww#wwwww#w#", "#wwwwwwwwww#", ".#wwwwwwwww#", "..#wwwwwwww#", "..#wwwwwww#.", "...#wwwwww#.",
             "...#######..", "............"], {"#": "ink", "w": "paper2"})
    h.save("hand")


# -------------------------------------------------------------- characters

def robot_frame(state, f):
    c = Canvas(36, 40)
    body = "met2" if state != "broken" else "met"
    body2 = "met3" if state != "broken" else "met2"
    # wheels / base
    c.rect(8, 33, 27, 37, "met0")
    c.disc(11, 36, 2.5, "ink3")
    c.disc(24, 36, 2.5, "ink3")
    # body
    bob = 1 if (f % 2 == 1 and state in ("idle", "talk", "happy")) else 0
    y0 = 18 - bob
    c.rect(7, y0, 28, 33, body)
    c.rect(7, y0, 28, y0 + 1, body2)
    c.rect(11, y0 + 4, 24, y0 + 11, "ink2")       # chest slot / mail drop
    c.hline(12, 23, y0 + 7, "paper" if state != "broken" else "ink3")
    c.rect(12, y0 + 12, 23, y0 + 13, "am2" if state != "broken" else "am0")
    # arms
    arm_y = y0 + 4
    if state == "happy":
        c.rect(3, arm_y - 6, 5, arm_y + 2, body)
        c.rect(30, arm_y - 6, 32, arm_y + 2, body)
    else:
        c.rect(3, arm_y, 5, arm_y + 9, body)
        c.rect(30, arm_y, 32, arm_y + 9, body)
    # head
    hy = 5 - bob
    c.rect(6, hy, 29, hy + 12, body2)
    c.rect(6, hy, 29, hy + 1, "met4" if state != "broken" else "met2")
    c.rect(9, hy + 3, 26, hy + 10, "ink")       # screen face
    eye = {"idle": "cy3", "talk": "cy3", "happy": "gr3", "sad": "cy2", "broken": "rd"}[state]
    if state == "broken":
        c.px(13, hy + 6, eye if f % 2 == 0 else "ink3")
        c.ascii(["#.#", ".#.", "#.#"], {"#": "rd2" if f % 2 == 0 else "rd0"}, 19, hy + 5)
    elif state == "happy":
        c.ascii([".#.", "#.#"], {"#": eye}, 12, hy + 5)
        c.ascii([".#.", "#.#"], {"#": eye}, 20, hy + 5)
        c.hline(15, 20, hy + 9, eye)
    elif state == "sad":
        c.rect(12, hy + 6, 14, hy + 7, eye)
        c.rect(21, hy + 6, 23, hy + 7, eye)
        c.px(15, hy + 9, eye)
        c.px(20, hy + 9, eye)
        c.hline(16, 19, hy + 8, eye)
    else:
        blink = (state == "idle" and f == 3)
        if blink:
            c.hline(12, 14, hy + 6, eye)
            c.hline(21, 23, hy + 6, eye)
        else:
            c.rect(12, hy + 5, 14, hy + 7, eye)
            c.rect(21, hy + 5, 23, hy + 7, eye)
        if state == "talk" and f % 2 == 0:
            c.rect(15, hy + 8, 20, hy + 9, eye)
        else:
            c.hline(15, 20, hy + 9, eye)
    # antenna with blinking tip
    c.vline(17, hy - 4, hy - 1, "met3")
    c.disc(17, hy - 4, 1.2, "rd2" if (f % 2 == 0 or state == "broken") else "am3")
    if state == "broken":
        for i in range(12):
            c.px(rnd.randint(6, 29), rnd.randint(hy, 33), "card")   # dust and rust
    c.outline()
    return c


def robot():
    for state in ("idle", "talk", "happy", "sad", "broken"):
        strip([robot_frame(state, i) for i in range(4)], "bit_" + state)


def portrait_base(bg):
    c = Canvas(44, 44)
    c.rect(0, 0, 43, 43, bg)
    for y in range(0, 44, 2):
        c.hline(0, 43, y, bg)
    return c


def portraits():
    # BIT
    c = portrait_base("cy0")
    big = robot_frame("talk", 1)
    c.paste(big, 4, 4)
    c.save("pt_bit")
    # Granny Olena: grey bun, glasses, yellow umbrella hint
    c = portrait_base("am0")
    c.rect(10, 34, 33, 43, "rd")            # cardigan
    c.rect(14, 34, 29, 43, "rd2")
    c.hline(10, 33, 34, "rd3")
    c.rect(19, 30, 24, 34, "sk")
    c.ellipse(21.5, 21, 9, 10, "sk2")
    c.ellipse(21.5, 11, 9.5, 5, "met4")     # hair
    c.disc(21.5, 5, 4, "met3")              # bun
    c.rect(12, 11, 14, 20, "met4")
    c.rect(29, 11, 31, 20, "met4")
    c.ring(17.5, 21, 3, "go")
    c.ring(26, 21, 3, "go")
    c.hline(20, 23, 21, "go")
    c.px(17, 21, "ink")
    c.px(26, 21, "ink")
    c.hline(19, 24, 27, "rd")
    c.px(14, 24, "rd3")
    c.px(29, 24, "rd3")
    c.outline()
    c.save("pt_olena")
    # Kai: teen courier with cap, goggles, teal jacket
    c = portrait_base("gr0")
    c.rect(8, 34, 35, 43, "cy")
    c.rect(18, 34, 25, 43, "cy3")
    c.rect(19, 29, 24, 34, "sk")
    c.ellipse(21.5, 21, 8.5, 9.5, "sk")
    c.rect(12, 8, 31, 14, "rd2")            # cap
    c.rect(26, 12, 37, 14, "rd")
    c.ellipse(21.5, 10, 9.5, 4, "rd2")
    c.rect(12, 15, 31, 18, "met")           # goggles band
    c.rect(14, 15, 19, 18, "cy3")
    c.rect(24, 15, 29, 18, "cy3")
    c.rect(16, 21, 17, 23, "ink")
    c.rect(26, 21, 27, 23, "ink")
    c.line(18, 27, 25, 26, "rd0")
    c.rect(11, 13, 12, 25, "wood0")         # hair
    c.outline()
    c.save("pt_kai")
    # Inspector Vera: sharp bob, suit, visor
    c = portrait_base("mg0")
    c.rect(8, 33, 35, 43, "ink3")
    c.rect(19, 33, 24, 43, "paper2")
    c.px(21, 36, "rd2")
    c.px(21, 38, "rd2")
    c.rect(19, 29, 24, 33, "sk2")
    c.ellipse(21.5, 21, 8, 9.5, "sk3")
    c.ellipse(21.5, 15, 10.5, 8, "ink2")    # hair
    c.rect(11, 15, 14, 28, "ink2")
    c.rect(29, 15, 32, 28, "ink2")
    c.rect(14, 19, 29, 22, "rd2", 230)      # visor
    c.hline(14, 29, 19, "rd3")
    c.hline(19, 24, 27, "rd")
    c.outline()
    c.save("pt_vera")
    # Future self: hooded silhouette with glowing eyes and stars
    c = portrait_base("ink2")
    for i in range(20):
        c.px(rnd.randint(0, 43), rnd.randint(0, 43), "mg3" if i % 3 else "white")
    c.ellipse(21.5, 26, 15, 17, "wall")
    c.ellipse(21.5, 24, 9, 10, "ink")
    c.rect(16, 23, 18, 24, "mg3")
    c.rect(25, 23, 27, 24, "mg3")
    c.rect(8, 36, 35, 43, "wall")
    c.hline(10, 33, 36, "wall3")
    c.outline()
    c.save("pt_future")
    # ORACLE: a red eye in concentric rings
    c = portrait_base("ink")
    for r, col in ((19, "rd0"), (15, "rd"), (11, "ink2"), (8, "rd2"), (4, "rd3")):
        c.disc(21.5, 21.5, r, col)
    c.disc(21.5, 21.5, 2, "ink")
    c.px(19, 19, "white")
    for i in range(0, 44, 4):
        c.px(i, 2, "rd")
        c.px(i, 41, "rd")
    c.save("pt_oracle")
    # Quant the cat
    c = portrait_base("night2")
    c.ellipse(21.5, 30, 13, 11, "am2")
    c.ellipse(21.5, 22, 11, 9, "am3")
    for (x0, x1) in ((11, 17), (26, 32)):
        c.line(x0, 16, x0 + 2, 6, "am3")
        c.line(x0 + 2, 6, x1, 14, "am3")
        c.px(x0 + 2, 9, "rd3")
    c.ellipse(21.5, 22, 11, 9, "am3")
    c.rect(15, 19, 17, 22, "gr2")
    c.rect(26, 19, 28, 22, "gr2")
    c.vline(16, 19, 22, "ink")
    c.vline(27, 19, 22, "ink")
    c.px(21, 25, "rd2")
    c.px(22, 25, "rd2")
    c.line(10, 25, 4, 24, "paper")
    c.line(33, 25, 39, 24, "paper")
    for i in range(3):
        c.hline(14 + i * 6, 16 + i * 6, 31, "am")
    c.outline()
    c.save("pt_quant")
    # The hero: postal cap and badge
    c = portrait_base("wall")
    c.rect(8, 33, 35, 43, "cy0")
    c.rect(19, 33, 24, 43, "paper")
    c.disc(29, 38, 2, "go2")
    c.rect(19, 29, 24, 33, "sk")
    c.ellipse(21.5, 21, 8.5, 9.5, "sk2")
    c.rect(11, 9, 32, 14, "cy0")
    c.ellipse(21.5, 9, 10, 4, "cy")
    c.rect(11, 14, 32, 15, "ink2")
    c.rect(19, 9, 24, 12, "go2")
    c.rect(16, 20, 17, 22, "ink")
    c.rect(26, 20, 27, 22, "ink")
    c.line(18, 26, 25, 26, "rd")
    c.outline()
    c.save("pt_hero")


def cat():
    frames = []
    for f in range(4):
        c = Canvas(24, 16)
        c.ellipse(11, 10, 7, 4, "am2")
        c.ellipse(18, 7, 4, 3.5, "am3")
        c.px(16, 3, "am3")
        c.px(16, 4, "am3")
        c.px(20, 3, "am3")
        c.px(20, 4, "am3")
        c.px(17, 6, "ink")
        c.px(20, 6, "ink")
        tail = [(-1, 0), (0, -1), (1, -2), (0, -1)][f]
        c.line(4, 9, 1, 5 + tail[1], "am2")
        legs = [(6, 15), (8, 14)] if f % 2 == 0 else [(7, 14), (5, 15)]
        for (x, _) in legs:
            c.vline(x, 13, 15, "am")
            c.vline(x + 8, 13, 15, "am")
        c.hline(8, 14, 9, "am")
        c.outline()
        frames.append(c)
    strip(frames, "cat")


# ------------------------------------------------------------------ decor

def decor():
    c = Canvas(18, 28)          # ficus
    c.rect(4, 19, 13, 27, "rd")
    c.hline(3, 14, 19, "rd2")
    c.vline(8, 8, 19, "wood2")
    for (x, y, r) in ((8, 8, 4), (4, 12, 3), (13, 11, 3.5), (6, 4, 3), (12, 5, 3)):
        c.disc(x, y, r, "gr")
        c.disc(x - 1, y - 1, r - 1.5, "gr2")
    c.px(11, 4, "cy3")
    c.outline()
    c.save("dc_plant")
    c = Canvas(16, 24)          # mushroom lamp
    c.ellipse(7.5, 6, 7.5, 5, "rd2")
    c.ellipse(7.5, 5, 6, 3.5, "rd3")
    for (x, y) in ((4, 4), (9, 3), (11, 6)):
        c.px(x, y, "paper2")
    c.rect(6, 10, 9, 20, "paper")
    c.rect(3, 20, 12, 23, "wood2")
    c.ellipse(7.5, 12, 7, 2, "am4", 90)
    c.outline()
    c.save("dc_lamp")
    c = Canvas(22, 28)          # poster
    c.rect(0, 0, 21, 27, "paper")
    c.rect(2, 2, 19, 17, "cy0")
    c.disc(10.5, 10, 6, "am2")
    c.disc(10.5, 10, 4, "paper2")
    c.line(10, 10, 10, 7, "ink")
    c.line(10, 10, 13, 11, "ink")
    for y in (20, 23):
        c.hline(3, 18, y, "ink3")
    c.outline()
    c.save("dc_poster")
    c = Canvas(24, 16)          # valve radio
    c.rect(0, 2, 23, 15, "wood3")
    c.rect(2, 4, 13, 13, "card3")
    for y in range(5, 13, 2):
        c.hline(3, 12, y, "wood")
    c.disc(18, 7, 2.5, "go2")
    c.disc(18, 12, 1.5, "met3")
    c.rect(8, 0, 15, 2, "am3")
    c.outline()
    c.save("dc_radio")
    c = Canvas(28, 12)          # cat bed
    c.ellipse(13.5, 7, 13.5, 4.5, "mg")
    c.ellipse(13.5, 6, 10, 2.5, "mg3")
    c.outline()
    c.save("dc_catbed")
    c = Canvas(48, 18)          # neon 404
    c.rect(0, 0, 47, 17, "ink2")
    digits = {"4": ["#..#", "#..#", "####", "...#", "...#"], "0": ["####", "#..#", "#..#", "#..#", "####"]}
    for i, d in enumerate("404"):
        rows = digits[d]
        big = [r.replace("#", "##").replace(".", "..") for r in rows]
        big = [r for r in big for _ in (0, 1)]
        c.ascii(big, {"#": "mg3"}, 5 + i * 14, 4)
    c.frame(1, 1, 46, 16, "cy2")
    c.outline()
    c.save("dc_neon")


# --------------------------------------------------------- shop/collection

def icon16(name, draw):
    c = Canvas(16, 16)
    draw(c)
    c.outline()
    c.save(name)


def shop_icons():
    icon16("ic_lift", lambda c: (c.rect(3, 2, 12, 14, "met2"), c.rect(5, 4, 10, 8, "card3"), c.vline(7, 0, 2, "met3"),
                                 c.ascii(["..#..", ".###.", "#####"], {"#": "gr2"}, 5, 10)))
    icon16("ic_press", lambda c: (c.rect(4, 1, 11, 4, "met3"), c.rect(7, 4, 8, 8, "met2"), c.rect(3, 8, 12, 11, "rd2"),
                                  c.rect(2, 12, 13, 14, "wood3")))
    icon16("ic_clock", lambda c: (c.disc(7.5, 7.5, 6.5, "paper"), c.ring(7.5, 7.5, 6.5, "am2"), c.line(7, 7, 7, 3, "ink"),
                                  c.line(7, 7, 10, 9, "rd")))
    icon16("ic_chute", lambda c: (c.rect(2, 2, 13, 5, "met3"), c.rect(4, 5, 11, 14, "met2"), c.rect(6, 7, 9, 14, "ink2"),
                                  c.hline(4, 11, 9, "am3")))
    icon16("ic_scanner", lambda c: (c.rect(2, 3, 13, 9, "met2"), c.rect(4, 5, 11, 7, "mg3"), c.rect(6, 9, 9, 14, "met"),
                                    c.px(12, 4, "rd2")))
    icon16("ic_window", lambda c: (c.rect(1, 3, 14, 12, "wood3"), c.rect(3, 5, 12, 10, "glass"), c.vline(7, 5, 10, "wood3"),
                                   c.px(4, 6, "white")))
    icon16("ic_robot", lambda c: (c.rect(3, 3, 12, 9, "met3"), c.rect(5, 5, 10, 7, "ink"), c.px(6, 6, "cy3"), c.px(9, 6, "cy3"),
                                  c.rect(4, 10, 11, 14, "met2"), c.vline(7, 0, 3, "met3"), c.px(7, 0, "rd2")))
    icon16("ic_archive", lambda c: (c.rect(1, 2, 14, 14, "wood2"), [c.hline(2, 13, y, "wood0") for y in (6, 10)],
                                    c.rect(3, 3, 5, 5, "go2"), c.rect(8, 7, 10, 9, "cy2"), c.rect(4, 11, 6, 13, "mg2")))
    icon16("ic_lounge", lambda c: (c.rect(1, 7, 14, 12, "rd"), c.rect(1, 5, 3, 13, "rd2"), c.rect(12, 5, 14, 13, "rd2"),
                                   c.rect(3, 8, 12, 10, "rd3")))
    icon16("ic_coffee", lambda c: (c.rect(3, 4, 10, 13, "paper"), c.rect(4, 5, 9, 7, "wood0"), c.ring(12, 8, 2, "paper"),
                                   c.px(5, 1, "met3"), c.px(7, 2, "met3"), c.px(6, 0, "met3")))
    icon16("ic_antenna", lambda c: (c.line(7, 14, 7, 4, "met3"), c.line(3, 14, 7, 6, "met2"), c.line(12, 14, 7, 6, "met2"),
                                    c.ring(7.5, 3, 2.5, "cy3"), c.disc(7.5, 3, 1, "rd2")))
    icon16("ic_lab", lambda c: (c.rect(6, 1, 9, 6, "glass"), c.ellipse(7.5, 10, 5.5, 4.5, "glass"), c.ellipse(7.5, 11, 4.5, 3, "mg2"),
                                c.px(6, 10, "mg3"), c.hline(5, 10, 1, "met3")))
    icon16("eq_stabilizer", lambda c: (c.disc(7.5, 7.5, 6.5, "met2"), c.disc(7.5, 7.5, 4, "cy2"), c.disc(7.5, 7.5, 2, "cy3"),
                                       c.line(1, 7, 14, 7, "met3")))
    icon16("eq_golden", lambda c: (c.rect(3, 1, 12, 4, "go3"), c.rect(6, 4, 9, 8, "go2"), c.rect(2, 8, 13, 12, "go2"),
                                   c.hline(2, 13, 12, "go0"), c.px(7, 10, "rd2")))
    icon16("eq_lens", lambda c: (c.ring(6.5, 6.5, 5, "met3", 1.5), c.disc(6.5, 6.5, 3.5, "cy3", 200), c.line(10, 10, 14, 14, "met2")))
    icon16("eq_filter", lambda c: (c.rect(2, 2, 13, 13, "met"), c.rect(4, 4, 11, 11, "mg2"), c.line(4, 4, 11, 11, "mg3"),
                                   c.line(11, 4, 4, 11, "mg3")))
    # routes
    icon16("rt_town", lambda c: (c.rect(1, 6, 5, 14, "wall3"), c.rect(6, 3, 10, 14, "met2"), c.rect(11, 8, 14, 14, "wall3"),
                                 c.px(8, 5, "am3"), c.px(3, 8, "am3"), c.px(12, 10, "am3")))
    icon16("rt_steam", lambda c: (c.rect(2, 7, 11, 12, "ink3"), c.rect(9, 4, 11, 7, "ink3"), c.disc(4, 13, 1.5, "rd2"),
                                  c.disc(9, 13, 1.5, "rd2"), c.disc(4, 3, 2, "paper0"), c.disc(7, 2, 1.5, "paper0")))
    icon16("rt_orbit", lambda c: (c.disc(7.5, 7.5, 3.5, "cy2"), c.ellipse(7.5, 7.5, 7, 2.5, "met3"), c.disc(7.5, 7.5, 3, "cy2"),
                                  c.px(13, 3, "white")))
    icon16("rt_medieval", lambda c: (c.rect(2, 5, 13, 14, "met2"), [c.rect(x, 2, x + 1, 5, "met2") for x in (2, 6, 10, 12)],
                                     c.rect(6, 9, 9, 14, "wood0"), c.px(7, 7, "am3")))
    icon16("rt_deep", lambda c: (c.disc(7.5, 7.5, 6, "mg"), c.disc(7.5, 7.5, 4, "mg2"), c.disc(7.5, 7.5, 1.5, "white"),
                                 c.px(1, 2, "cy3"), c.px(14, 12, "cy3")))


def collectibles():
    D = {}
    D["pocket_watch"] = lambda c: (c.disc(7.5, 8.5, 6, "go2"), c.disc(7.5, 8.5, 4.5, "paper"), c.line(7, 8, 7, 5, "ink"),
                                   c.line(7, 8, 9, 9, "ink"), c.rect(6, 0, 9, 2, "go"), c.ring(7.5, 8.5, 6, "go0"))
    D["wax_seal"] = lambda c: (c.disc(7.5, 8, 6, "rd"), c.disc(7.5, 8, 4, "rd2"), c.ascii(["#.#", ".#.", "#.#"], {"#": "rd0"}, 6, 7),
                               c.px(2, 4, "rd2"), c.px(13, 12, "rd2"))
    D["floppy"] = lambda c: (c.rect(1, 1, 14, 14, "ink3"), c.rect(4, 1, 11, 5, "met3"), c.rect(8, 2, 9, 4, "ink3"),
                             c.rect(3, 8, 12, 14, "paper"), c.hline(4, 11, 10, "cy2"))
    D["cassette"] = lambda c: (c.rect(0, 3, 15, 12, "ink3"), c.rect(2, 4, 13, 7, "am3"), c.disc(5, 9, 1.5, "paper"),
                               c.disc(10, 9, 1.5, "paper"), c.rect(4, 11, 11, 12, "ink2"))
    D["rotary_phone"] = lambda c: (c.rect(2, 8, 13, 14, "rd"), c.ellipse(7.5, 4, 7, 2.5, "rd2"), c.disc(7.5, 11, 2.5, "paper"),
                                   c.px(7, 11, "ink"))
    D["steam_gear"] = lambda c: (c.disc(7.5, 7.5, 6, "am"), [c.rect(7 + int(6.5 * math.cos(a)) - 1, 7 + int(6.5 * math.sin(a)) - 1,
                                  7 + int(6.5 * math.cos(a)), 7 + int(6.5 * math.sin(a)), "am") for a in [i * math.tau / 8 for i in range(8)]],
                                 c.disc(7.5, 7.5, 4, "am2"), c.disc(7.5, 7.5, 1.5, "ink2"))
    D["quill"] = lambda c: (c.line(3, 14, 13, 1, "paper2"), c.line(4, 13, 13, 3, "paper0"), c.line(6, 12, 12, 5, "paper"),
                            c.line(2, 15, 4, 13, "ink"))
    D["tin_robot"] = lambda c: (c.rect(4, 2, 11, 7, "met3"), c.px(6, 4, "rd2"), c.px(9, 4, "rd2"), c.rect(3, 8, 12, 12, "met2"),
                                c.rect(4, 13, 5, 15, "met"), c.rect(10, 13, 11, 15, "met"), c.vline(7, 0, 2, "met3"))
    D["vinyl"] = lambda c: (c.disc(7.5, 7.5, 7, "ink"), c.ring(7.5, 7.5, 5, "ink3"), c.disc(7.5, 7.5, 2.5, "rd2"),
                            c.px(7, 7, "ink"), c.px(4, 3, "met2"))
    D["postcard"] = lambda c: (c.rect(0, 3, 15, 12, "paper"), c.rect(1, 4, 7, 11, "cy2"), c.disc(4, 7, 1.5, "am3"),
                               c.rect(11, 4, 14, 7, "rd2"), c.hline(9, 14, 9, "ink3"), c.hline(9, 13, 11, "ink3"))
    D["stamp_404"] = lambda c: (c.rect(1, 1, 14, 14, "paper2"), [c.px(x, y, (0, 0, 0, 0)) for x in range(1, 15, 2) for y in (1, 14)],
                                c.rect(3, 3, 12, 12, "mg"), c.ascii(["#.#.#", "###.#", "..#.#"], {"#": "go3"}, 5, 6))
    D["umbrella"] = lambda c: (c.ellipse(7.5, 6, 7, 5, "go2"), c.rect(0, 6, 15, 8, (0, 0, 0, 0)), c.hline(1, 14, 6, "go0"),
                               c.vline(7, 6, 13, "wood"), c.px(6, 13, "wood"), c.px(5, 12, "wood"))
    D["holo_cube"] = lambda c: (c.rect(3, 5, 10, 12, "cy", ), c.rect(5, 3, 12, 10, "cy2"), c.rect(6, 4, 11, 9, "cy3"),
                                c.line(3, 5, 5, 3, "white"), c.line(10, 12, 12, 10, "cy0"))
    D["mars_rock"] = lambda c: (c.ellipse(7.5, 9, 6.5, 5, "rd"), c.ellipse(6.5, 8, 4.5, 3, "rd2"), c.px(5, 7, "rd3"),
                                c.px(10, 11, "rd0"), c.px(8, 10, "rd0"))
    D["hover_skate"] = lambda c: (c.ellipse(7.5, 7, 7, 2.5, "rd2"), c.hline(2, 13, 6, "rd3"), c.ellipse(4, 11, 2, 1.2, "cy3"),
                                  c.ellipse(11, 11, 2, 1.2, "cy3"))
    D["neural_chip"] = lambda c: (c.rect(3, 3, 12, 12, "gr"), c.rect(5, 5, 10, 10, "ink2"), c.px(7, 7, "gr3"),
                                  [c.px(x, y, "go2") for x in (4, 6, 8, 10) for y in (1, 14)])
    D["plasma_stamp"] = lambda c: (c.rect(5, 1, 10, 7, "met3"), c.rect(3, 7, 12, 10, "met2"), c.rect(2, 11, 13, 13, "cy3"),
                                   c.px(4, 14, "cy2"), c.px(11, 14, "cy2"))
    D["robo_pet"] = lambda c: (c.rect(3, 6, 11, 11, "met3"), c.rect(10, 3, 14, 7, "met3"), c.px(12, 4, "cy3"),
                               c.rect(4, 12, 5, 14, "met"), c.rect(9, 12, 10, 14, "met"), c.line(2, 6, 1, 3, "met2"))
    D["star_map"] = lambda c: (c.rect(1, 1, 14, 14, "night"), [c.px(x, y, "white") for (x, y) in ((3, 3), (11, 4), (6, 9), (12, 12), (4, 12))],
                               c.line(3, 3, 6, 9, "cy2"), c.line(6, 9, 12, 12, "cy2"), c.disc(8, 6, 1, "go3"))
    D["time_crystal"] = lambda c: (c.ascii(["...##...", "..#cc#..", ".#cwwc#.", "#cwwccc#", "#ccccc#.", ".#ccc#..", "..#c#...", "...#...."],
                                           {"#": "mg0", "c": "mg2", "w": "mg3"}, 4, 3),)
    D["paradox_cup"] = lambda c: (c.rect(3, 5, 10, 13, "paper"), c.ring(12, 9, 2, "paper"), c.line(6, 5, 8, 13, "ink3"),
                                  c.rect(4, 6, 9, 7, "wood0"), c.px(11, 3, "mg3"), c.px(2, 2, "mg3"))
    D["mobius_letter"] = lambda c: (c.rect(1, 4, 14, 12, "paper"), c.line(1, 4, 7, 9, "paper0"), c.line(14, 4, 8, 9, "paper0"),
                                    c.ring(7.5, 8, 3, "mg2"))
    D["quant_whisker"] = lambda c: (c.line(1, 12, 14, 3, "paper2"), c.line(2, 12, 14, 4, "paper0"), c.px(14, 3, "go3"))
    D["erased_photo"] = lambda c: (c.rect(1, 2, 14, 13, "paper2"), c.rect(2, 3, 13, 10, "am0"),
                                   [c.disc(x, 5, 0.8, "go3") for x in (4, 7, 10)], c.rect(3, 8, 12, 10, "ink3"), c.hline(2, 13, 12, "paper0"))
    D["oracle_shard"] = lambda c: (c.ascii(["....#", "...#r", "..#rr", ".#rrw", "#rrr#", ".#r#.", "..#.."], {"#": "rd0", "r": "rd2", "w": "rd3"}, 5, 4),)
    D["future_key"] = lambda c: (c.ring(4.5, 7.5, 3.5, "mg3", 1.6), c.rect(8, 7, 15, 8, "mg3"), c.rect(12, 9, 13, 11, "mg3"),
                                 c.rect(14, 9, 15, 10, "mg3"), c.px(4, 7, "white"))
    for k, fn in D.items():
        icon16("it_" + k, fn)
    # silhouette used for unknown items
    c = Canvas(16, 16)
    c.ascii(["....####....", "...#....#...", "........#...", ".......#....", "......#.....", "......#.....", "............", "......#....."],
            {"#": "ink3"}, 2, 4)
    c.save("it_unknown")


# --------------------------------------------------------------------- ui

def ui():
    def panel(name, fill, edge, hi, lo):
        c = Canvas(18, 18)
        c.rect(1, 1, 16, 16, fill)
        c.hline(2, 15, 0, edge)
        c.hline(2, 15, 17, edge)
        c.vline(0, 2, 15, edge)
        c.vline(17, 2, 15, edge)
        c.px(1, 1, edge)
        c.px(16, 1, edge)
        c.px(1, 16, edge)
        c.px(16, 16, edge)
        c.hline(2, 15, 1, hi)
        c.vline(1, 2, 15, hi)
        c.hline(2, 15, 16, lo)
        c.vline(16, 2, 15, lo)
        c.save(name)
    panel("ui_panel", "ink2", "ink", "ink3", "ink")
    panel("ui_panel_paper", "paper", "wood0", "paper2", "paper0")
    panel("ui_btn", "wall2", "ink", "wall3", "wall")
    panel("ui_btn_press", "wall", "ink", "ink3", "wall2")
    panel("ui_btn_accent", "am2", "am0", "am4", "am")
    panel("ui_btn_accent_press", "am", "am0", "am2", "am2")
    panel("ui_btn_cyan", "cy", "cy0", "cy2", "cy0")
    panel("ui_btn_off", "ink3", "ink", "wall", "ink2")
    panel("ui_chip", "ink", "ink3", "ink2", "ink")
    c = Canvas(6, 6)
    c.disc(2.5, 2.5, 2.5, "white")
    c.save("fx_spark")
    c = Canvas(7, 7)
    c.ascii(["...#...", "...#...", ".#####.", "#######", ".#####.", "...#...", "...#..."], {"#": "white"})
    c.save("fx_star")


def app_icon():
    c = Canvas(48, 48)
    c.rect(0, 0, 47, 47, "ink2")
    for y in range(48):
        if y % 4 == 0:
            c.hline(0, 47, y, "wall")
    b = box_cardboard()
    big = b.img.resize((68, 60), Image.NEAREST)
    c.paste(big.crop((0, 0, 68, 60)).resize((40, 35), Image.NEAREST), 4, 9)
    digits = {"4": ["#.#", "#.#", "###", "..#", "..#"], "0": ["###", "#.#", "#.#", "#.#", "###"]}
    for i, d in enumerate("404"):
        c.ascii(digits[d], {"#": "rd2"}, 14 + i * 4 + 2, 22)
    c.ascii(["..#..", ".###.", "#####", ".###.", "..#.."], {"#": "cy3"}, 38, 3)
    c.ascii(["#####", ".###.", "..#..", ".###.", "#####"], {"#": "am3"}, 4, 3)
    c.img.resize((192, 192), Image.NEAREST).save(os.path.join(OUT, "icon.png"))
    c.img.resize((432, 432), Image.NEAREST).save(os.path.join(OUT, "icon_432.png"))


def extras():
    c = Canvas(9, 9)            # boomerang badge
    c.ascii(["...####..", "..#oooo#.", ".#oo##o#.", "#oo#..##.", "#o#......", "#o#......", "#oo#.....", ".#oo#....", "..##....."],
            {"#": "ink", "o": "am3"})
    c.save("ic_boomerang")
    c = Canvas(5, 5)            # dust puff
    c.ascii([".###.", "#####", "#####", "#####", ".###."], {"#": "paper0"})
    c.save("fx_dust")
    c = Canvas(5, 5)            # snowflake
    c.ascii(["..#..", "#.#.#", ".###.", "#.#.#", "..#.."], {"#": "white"})
    c.save("fx_snow")
    c = Canvas(6, 5)            # autumn leaf
    c.ascii(["...##.", ".####.", "#####.", ".###..", "#....."], {"#": "am2"})
    c.save("fx_leaf")
    c = Canvas(4, 4)            # spring petal
    c.ascii([".##.", "####", "####", ".##."], {"#": "mg3"})
    c.save("fx_petal")
    c = Canvas(3, 3)            # summer firefly
    c.ascii([".#.", "###", ".#."], {"#": "go3"})
    c.save("fx_firefly")


if __name__ == "__main__":
    wall_tile()
    wainscot_tile()
    floor_tile()
    for m in ("grey", "warm", "neat", "bright"):
        city(m)
    window()
    shelf()
    clock()
    pipes()
    tube_present()
    portal("past")
    portal("future")
    hatch()
    belt()
    pad()
    today_board()
    boxes()
    icons()
    robot()
    portraits()
    cat()
    decor()
    shop_icons()
    collectibles()
    ui()
    app_icon()
    extras()
    print("sprites:", len(os.listdir(OUT)))
