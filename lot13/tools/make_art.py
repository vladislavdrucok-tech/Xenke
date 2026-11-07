"""Generates every PNG of LOT 13: Lucky Garage into assets/art.  python3 tools/make_art.py
All art shares one palette and one pixel size; Godot draws it with nearest filtering at 2x.
UI nine-patch frames are written pre-scaled 2x so their borders match the 2x art pixel."""
import os
import random
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from art_items import ITEMS, ORDER  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "art")

PAL = {
    "k": "#1a1626", "x": "#2b2b3a", "d": "#4a4a5e", "g": "#7c7c94", "l": "#b4b4c8", "w": "#f2f0f5",
    "r": "#d8434b", "R": "#8e2a3c", "o": "#f0903c", "O": "#b4582c", "y": "#f8d448", "Y": "#c08a26",
    "n": "#8a5a3a", "N": "#5a3828", "b": "#c99560", "B": "#e8c08a", "e": "#72c04c", "E": "#2f7f45",
    "c": "#62d0e4", "C": "#2f8aa8", "u": "#4f7ae0", "U": "#2c3f8c", "p": "#a060dc", "P": "#5e3090",
    "i": "#f28cba", "s": "#f2c29a", "S": "#c8865a", "m": "#dfe6ee", "M": "#8e9eb2", "h": "#6a4a8a",
}
OUTLINE = (26, 22, 38, 255)


def rgba(c, a=255):
    if isinstance(c, tuple):
        return c if len(c) == 4 else c + (a,)
    c = PAL.get(c, c)
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), a)


def from_rows(rows, w=None):
    w = w or max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        if len(row) != w:
            raise ValueError(f"row {y} has {len(row)} pixels, expected {w}: {row!r}")
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), rgba(ch))
    return img


def outline(img, col=OUTLINE, grow=True):
    w, h = img.size
    src = img
    if grow:
        src = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
        src.paste(img, (1, 1))
        w, h = src.size
    out = src.copy()
    px = src.load()
    po = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0 and px[nx, ny] != col:
                        po[x, y] = col
                        break
    return out


def center16(img):
    """Centres the drawn pixels inside the 16x16 cell (sprites were drawn in different corners)."""
    bb = img.getbbox()
    if not bb:
        return img
    crop = img.crop(bb)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ox = (img.size[0] - crop.size[0]) // 2
    oy = (img.size[1] - crop.size[1] + 1) // 2
    out.paste(crop, (ox, oy))
    return out


def save(img, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)
    return p


def scale(img, k):
    return img.resize((img.size[0] * k, img.size[1] * k), Image.NEAREST)


class C:
    """Tiny pixel canvas helper."""

    def __init__(self, w, h, fill=None):
        self.img = Image.new("RGBA", (w, h), rgba(fill) if fill else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.w, self.h = w, h

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), rgba(c))

    def rect(self, x0, y0, x1, y1, c):  # inclusive
        if x1 < x0 or y1 < y0:
            return
        self.d.rectangle([x0, y0, x1, y1], fill=rgba(c))

    def frame(self, x0, y0, x1, y1, c):
        self.d.rectangle([x0, y0, x1, y1], outline=rgba(c))

    def hl(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vl(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def line(self, a, b, c):
        self.d.line([a, b], fill=rgba(c))

    def ellipse(self, x0, y0, x1, y1, c):
        self.d.ellipse([x0, y0, x1, y1], fill=rgba(c))

    def paste(self, img, x, y):
        self.img.alpha_composite(img, (x, y))


# ------------------------------------------------------------------ items
def make_items():
    sheet = []
    for iid in ORDER:
        img = outline(center16(from_rows(ITEMS[iid], 16)))
        save(img, "items", iid + ".png")
        sheet.append(img)
    return sheet


# ------------------------------------------------------------------ containers (32x32)
BOXES = {
    # name: top, front, side-shade, edge-dark, accent
    "cardboard": ("B", "b", "n", "N", "w"),
    "crate": ("b", "n", "N", "N", "M"),
    "suitcase": ("O", "n", "N", "N", "Y"),
    "locker": ("m", "M", "g", "d", "r"),
    "trunk": ("n", "N", "x", "x", "Y"),
    "golden": ("y", "Y", "O", "N", "r"),
}


def box_body(c, top, front, side, dark, accent, kind, opened):
    # front face
    c.rect(3, 13, 28, 29, front)
    c.rect(26, 13, 28, 29, side)
    c.hl(3, 28, 29, dark)
    if not opened:
        # top face (3/4 view)
        c.rect(4, 6, 27, 12, top)
        c.hl(4, 27, 6, rgba("w", 255) if kind in ("cardboard", "golden", "locker") else top)
        c.hl(3, 28, 12, dark)
    else:
        c.rect(4, 7, 27, 12, "x")
        c.rect(5, 8, 26, 12, "k")
        c.hl(3, 28, 12, dark)
    if kind == "cardboard":
        if not opened:
            c.rect(14, 6, 17, 12, "l")
            c.rect(14, 13, 17, 18, "l")
            c.hl(14, 17, 6, "w")
        else:
            # flaps open
            for i in range(6):
                c.hl(0 + i, 9 + i, 6 - i + 6, top)
                c.hl(22 - i, 31 - i, 12 - i, top)
            c.hl(3, 13, 12, dark)
        c.rect(6, 21, 12, 25, "w")
        c.hl(7, 11, 23, "g")
        c.px(24, 16, side)
        c.px(5, 27, side)
    elif kind == "crate":
        for y in (17, 22, 27):
            c.hl(3, 28, y, dark)
        c.line((4, 28), (25, 14), side)
        c.line((4, 27), (25, 13), "b")
        for (x, y) in ((5, 15), (24, 15), (5, 26), (24, 26)):
            c.px(x, y, accent)
        if not opened:
            for x in (10, 18):
                c.vl(x, 6, 12, side)
    elif kind == "suitcase":
        c.rect(3, 13, 28, 29, front)
        c.rect(26, 13, 28, 29, side)
        c.vl(9, 13, 29, dark)
        c.vl(22, 13, 29, dark)
        c.rect(8, 18, 10, 20, accent)
        c.rect(21, 18, 23, 20, accent)
        c.hl(3, 28, 29, dark)
        if not opened:
            c.rect(12, 2, 19, 3, "N")
            c.vl(12, 2, 6, "N")
            c.vl(19, 2, 6, "N")
            c.hl(4, 27, 9, dark)
    elif kind == "locker":
        for (x, y) in ((5, 15), (24, 15), (5, 27), (24, 27), (14, 15), (14, 27)):
            c.px(x, y, "l")
        c.rect(12, 19, 19, 23, "d")
        c.rect(14, 20, 17, 22, accent)
        c.hl(3, 28, 13, "l")
        if not opened:
            c.hl(4, 27, 9, "g")
            c.rect(13, 7, 18, 8, "d")
    elif kind == "trunk":
        for x in (8, 23):
            c.rect(x - 1, 13, x, 29, accent)
            if not opened:
                c.rect(x - 1, 6, x, 12, accent)
        c.rect(13, 15, 18, 20, accent)
        c.rect(15, 17, 16, 19, "k")
        c.hl(3, 28, 13, "Y")
    elif kind == "golden":
        for x in (8, 23):
            c.rect(x - 1, 13, x, 29, "y")
        c.rect(13, 16, 18, 21, accent)
        c.px(14, 17, "w")
        c.hl(3, 28, 13, "w")
        for (x, y) in ((5, 16), (25, 25), (11, 26), (20, 15)):
            c.px(x, y, "w")
        if not opened:
            c.rect(7, 6, 8, 12, "y")
            c.rect(22, 6, 23, 12, "y")
    if opened and kind != "cardboard":
        # lid leaning back
        c.rect(4, 0, 27, 5, top)
        c.hl(4, 27, 5, dark)
        c.hl(4, 27, 0, "w" if kind in ("golden", "locker") else top)
        if kind == "trunk":
            c.rect(7, 0, 8, 5, accent)
            c.rect(22, 0, 23, 5, accent)


def make_boxes():
    out = {}
    for kind, (top, front, side, dark, accent) in BOXES.items():
        for opened in (False, True):
            c = C(32, 32)
            box_body(c, top, front, side, dark, accent, kind, opened)
            img = outline(c.img, grow=False)
            name = f"{kind}_{'open' if opened else 'closed'}"
            save(img, "boxes", name + ".png")
            out[name] = img
    return out


# ------------------------------------------------------------------ portraits (24x24)
SKINS = ["#f2c29a", "#e0a878", "#c8865a", "#9a6040", "#6e4430", "#f5d5b5"]
HAIRS = ["#2b2b3a", "#5a3828", "#8a5a3a", "#c08a26", "#f8d448", "#b4b4c8", "#f2f0f5", "#d8434b", "#62d0e4", "#a060dc"]
SHIRTS = ["#4f7ae0", "#d8434b", "#72c04c", "#a060dc", "#f0903c", "#2f8aa8", "#7c7c94", "#5a3828", "#f28cba"]


def shade(hexc, k):
    r, g, b, a = rgba(hexc)
    return (max(0, min(255, int(r * k))), max(0, min(255, int(g * k))), max(0, min(255, int(b * k))), 255)


def portrait(skin, hair, shirt, style, acc=(), seed=0):
    c = C(24, 24)
    # shoulders
    c.rect(3, 19, 20, 23, shirt)
    c.rect(4, 18, 19, 18, shirt)
    c.rect(16, 19, 20, 23, shade(shirt, 0.75))
    c.rect(10, 17, 13, 19, shade(skin, 0.85))  # neck
    if "tie" in acc:
        c.rect(11, 19, 12, 23, "r")
    if "collar" in acc:
        c.px(9, 19, "w"), c.px(14, 19, "w"), c.px(10, 20, "w"), c.px(13, 20, "w")
    # head
    c.rect(6, 6, 17, 16, skin)
    c.rect(7, 5, 16, 17, skin)
    c.rect(15, 6, 17, 16, shade(skin, 0.88))
    c.px(5, 11, skin), c.px(18, 11, shade(skin, 0.85))  # ears
    c.px(5, 12, skin), c.px(18, 12, shade(skin, 0.85))
    # eyes
    c.rect(9, 10, 9, 11, "k")
    c.rect(14, 10, 14, 11, "k")
    c.px(8, 9, shade(hair, 0.9)), c.px(9, 9, shade(hair, 0.9)), c.px(14, 9, shade(hair, 0.9)), c.px(15, 9, shade(hair, 0.9))
    # nose and mouth
    c.px(12, 12, shade(skin, 0.75)), c.px(12, 13, shade(skin, 0.75))
    mouth = "#b85060" if "lipstick" not in acc else "#d8434b"
    c.hl(10, 13, 15, mouth)
    if "smile" in acc:
        c.px(9, 14, mouth), c.px(14, 14, mouth)
    c.px(8, 13, shade(skin, 0.93)), c.px(15, 13, shade(skin, 0.83))
    # hair styles
    hd = shade(hair, 0.75)
    if style == "short":
        c.rect(6, 3, 17, 6, hair)
        c.rect(5, 5, 6, 9, hair)
        c.rect(17, 5, 18, 9, hd)
        c.hl(7, 16, 3, hair)
    elif style == "long":
        c.rect(6, 3, 17, 6, hair)
        c.rect(4, 5, 6, 18, hair)
        c.rect(17, 5, 19, 18, hd)
    elif style == "bun":
        c.rect(6, 4, 17, 6, hair)
        c.rect(9, 1, 14, 3, hair)
        c.rect(5, 5, 6, 10, hair)
        c.rect(17, 5, 18, 10, hd)
    elif style == "spiky":
        c.rect(6, 4, 17, 6, hair)
        for x in range(6, 18, 3):
            c.px(x, 3, hair), c.px(x + 1, 2, hair), c.px(x + 1, 3, hair)
        c.rect(5, 5, 6, 8, hair)
        c.rect(17, 5, 18, 8, hd)
    elif style == "slick":
        c.rect(6, 3, 17, 6, hair)
        c.rect(5, 4, 6, 9, hair)
        c.rect(17, 4, 18, 9, hd)
        c.hl(8, 13, 4, shade(hair, 1.4))
    elif style == "curly":
        for (x, y) in ((6, 4), (9, 3), (12, 3), (15, 4), (5, 7), (18, 7), (7, 2), (13, 2)):
            c.rect(x - 1, y - 1, x + 1, y + 1, hair)
        c.rect(6, 4, 17, 6, hair)
        c.rect(4, 6, 6, 12, hair)
        c.rect(17, 6, 19, 12, hd)
    elif style == "bald":
        c.rect(5, 8, 6, 12, hair)
        c.rect(17, 8, 18, 12, hd)
        c.px(9, 5, shade(skin, 1.12)), c.px(10, 5, shade(skin, 1.12))
    # accessories
    if "mustache" in acc:
        c.hl(9, 14, 14, hair)
        c.px(8, 15, hair), c.px(15, 15, hair)
    if "beard" in acc:
        c.rect(7, 14, 16, 17, hair)
        c.rect(8, 18, 15, 18, hair)
        c.hl(10, 13, 15, mouth)
    if "glasses" in acc:
        c.frame(7, 9, 10, 12, "k")
        c.frame(13, 9, 16, 12, "k")
        c.hl(11, 12, 10, "k")
    if "shades" in acc:
        c.rect(7, 9, 10, 11, "k")
        c.rect(13, 9, 16, 11, "k")
        c.hl(10, 13, 9, "k")
        c.px(8, 9, "c"), c.px(14, 9, "c")
    if "cap" in acc:
        col = acc[acc.index("cap") + 1] if acc.index("cap") + 1 < len(acc) and str(acc[acc.index("cap") + 1]).startswith("#") else "#d8434b"
        c.rect(6, 2, 17, 6, col)
        c.rect(4, 6, 12, 7, shade(col, 0.7))
        c.px(11, 3, "w")
    if "tophat" in acc:
        c.rect(7, 0, 16, 4, "x")
        c.rect(4, 5, 19, 6, "x")
        c.hl(7, 16, 4, "r")
    if "beanie" in acc:
        c.rect(6, 2, 17, 6, "#72c04c")
        c.hl(6, 17, 6, "#2f7f45")
        c.rect(11, 0, 12, 1, "w")
    if "earrings" in acc:
        c.px(5, 14, "y"), c.px(18, 14, "y")
    if "necklace" in acc:
        c.hl(8, 15, 19, "y")
        c.px(11, 20, "c"), c.px(12, 20, "c")
    if "scar" in acc:
        c.px(15, 12, "R"), c.px(16, 13, "R")
    return outline(c.img, grow=False)


CHARACTERS = {
    # name: skin, hair, shirt, style, accessories
    "auctioneer": ("#f2c29a", "#7c7c94", "#2b2b3a", "bald", ("tophat", "mustache", "tie", "collar", "smile")),
    "lou": ("#e0a878", "#b4b4c8", "#4f7ae0", "short", ("cap", "#2f8aa8", "beard", "smile")),
    "tony": ("#e0a878", "#2b2b3a", "#d8434b", "bald", ("mustache", "scar")),
    "rose": ("#f5d5b5", "#f2f0f5", "#a060dc", "bun", ("glasses", "earrings", "smile")),
    "max": ("#f2c29a", "#2b2b3a", "#2b2b3a", "slick", ("shades", "tie")),
    "byte": ("#c8865a", "#62d0e4", "#72c04c", "spiky", ("glasses",)),
    "gold": ("#f2c29a", "#f8d448", "#f28cba", "long", ("lipstick", "earrings", "necklace")),
    "kim": ("#f5d5b5", "#5a3828", "#2f8aa8", "short", ("beanie",)),
}


def make_portraits():
    out = {}
    for name, (sk, ha, sh, st, acc) in CHARACTERS.items():
        img = portrait(sk, ha, sh, st, acc)
        save(img, "portraits", name + ".png")
        out[name] = img
    rnd = random.Random(1313)
    styles = ["short", "long", "bun", "spiky", "slick", "curly", "bald"]
    extras = [(), ("glasses",), ("mustache",), ("beard",), ("cap",), ("earrings",), ("smile",), ("shades",),
              ("beanie",), ("glasses", "smile"), ("cap", "mustache"), ("necklace", "smile")]
    for i in range(12):
        img = portrait(rnd.choice(SKINS), rnd.choice(HAIRS), rnd.choice(SHIRTS), styles[i % len(styles)],
                       extras[i % len(extras)])
        save(img, "portraits", f"buyer_{i}.png")
        out[f"buyer_{i}"] = img
    return out


# ------------------------------------------------------------------ icons (16x16)
ICONS = {
"coin": [
"................",
"................",
".....YYYYYY.....",
"....YyyyyyyY....",
"...YyyyYYyyyY...",
"...YyyYyyyyyY...",
"...YyyyYyyyyY...",
"...YyyyyYyyyY...",
"...YyyyyyYyyY...",
"...YyyYYYyyyY...",
"...YyyyYyyyyY...",
"....YyyyyyyY....",
".....YYYYYY.....",
"................",
"................",
"................",
],
"star": [
"................",
".......y........",
"......yyy.......",
"......yyy.......",
".yyyyyyyyyyyyy..",
"..yyyyyyyyyyy...",
"...yyyywyyyy....",
"....yyyyyyy.....",
"....yyyYyyy.....",
"...yyyY.Yyyy....",
"...yyY...Yyy....",
"..yYY.....YYy...",
"................",
"................",
"................",
"................",
],
"calendar": [
"................",
"...d......d.....",
"..rrrrrrrrrrr...",
"..rrdrrrrrdrr...",
"..wwwwwwwwwww...",
"..wgwgwgwgwgw...",
"..wwwwwwwwwww...",
"..wgwgwrwgwgw...",
"..wwwwwwwwwww...",
"..wgwgwgwgwgw...",
"..wwwwwwwwwww...",
"..lllllllllll...",
"................",
"................",
"................",
"................",
],
"gear": [
"................",
"......ll........",
"...l..ll..l.....",
"..lllllllll.....",
"...llggggll.....",
"..llgg..ggll....",
"llllg....gllll..",
"llllg....gllll..",
"..llgg..ggll....",
"...llggggll.....",
"..lllllllll.....",
"...l..ll..l.....",
"......ll........",
"................",
"................",
"................",
],
"garage": [
"................",
"................",
".......rr.......",
".....rrrrrr.....",
"...rrrrrrrrrr...",
".rrrrrrrrrrrrrr.",
"..llllllllllll..",
"..lggggggggggl..",
"..ldddddddddl...",
"..lggggggggggl..",
"..lddddddddddl..",
"..lggggggggggl..",
"..lddddddddddl..",
"..llllllllllll..",
"................",
"................",
],
"gavel": [
"................",
"......NNNN......",
".....NnnnnN.....",
"....NnnnnnnN....",
"...NnnnnnnnnN...",
"....NnnnnnnNnN..",
".....NnnnnNnnN..",
"......NNNNnnN...",
".........NnN....",
"........NnN.....",
".......NnN......",
"......NnN.......",
"...bbbbbbbb.....",
"..bbbbbbbbbb....",
"..nnnnnnnnnn....",
"................",
],
"box": [
"................",
"................",
"...BBBBBBBBBB...",
"..BBBBlllBBBBB..",
"..bbbblllbbbbn..",
"..bbbblllbbbbn..",
"..bbbbbbbbbbbn..",
"..bwwwbbbbbbbn..",
"..bgggbbbbbbbn..",
"..bbbbbbbbbbbn..",
"..bbbbbbbbbbbn..",
"..NNNNNNNNNNNN..",
"................",
"................",
"................",
"................",
],
"wrench": [
"................",
"..........ll....",
".........lw.l...",
".........ll.ll..",
"..........llll..",
".........lll....",
"........lll.....",
".......lll......",
"......lll.......",
".....lll........",
"....lll.........",
"..llll..........",
".ll.ll..........",
".l..l...........",
"..ll............",
"................",
],
"tag": [
"................",
"........yyyyyy..",
".......yyyyyyy..",
"......yyyyyykyy.",
".....yyyyyyyyyy.",
"....yyyyyyyyyy..",
"...yyyYyyyyyy...",
"..yyyyYYyyyy....",
".yyyyYyyyyy.....",
"..yyyyYyyy......",
"...yyYYyy.......",
"....yyyy........",
".....yy.........",
"................",
"................",
"................",
],
"up": [
"................",
".......ee.......",
"......eeee......",
".....eeeeee.....",
"....eeeeeeee....",
"...eeeeeeeeee...",
"..eeeeeeeeeeee..",
"......eeee......",
"......eeee......",
"......eeee......",
"......eeee......",
"......EEEE......",
"................",
"................",
"................",
"................",
],
"book": [
"................",
"................",
"..uuuuuu.uuuuuu.",
".uwwwwwwuwwwwwwu",
".uwggggwuwggggwu",
".uwwwwwwuwwwwwwu",
".uwgggwwuwgggwwu",
".uwwwwwwuwwwwwwu",
".uwggggwuwggggwu",
".uwwwwwwuwwwwwwu",
".uwgggwwuwgggwwu",
".uwwwwwwuwwwwwwu",
".UUUUUUUUUUUUUUU",
"................",
"................",
"................",
],
"sound": [
"................",
"................",
"......l.........",
".....ll....l....",
"....lll.....l...",
"lllllll..l...l..",
"lllllll...l..l..",
"lllllll...l..l..",
"lllllll..l...l..",
"....lll.....l...",
".....ll....l....",
"......l.........",
"................",
"................",
"................",
"................",
],
"music": [
"................",
"......llllllll..",
"......llllllll..",
"......l......l..",
"......l......l..",
"......l......l..",
"......l......l..",
"......l......l..",
"...llll...llll..",
"..lllll..lllll..",
"..lllll..lllll..",
"...lll....lll...",
"................",
"................",
"................",
"................",
],
"lock": [
"................",
".....llllll.....",
"....l......l....",
"....l......l....",
"....l......l....",
"...yyyyyyyyyy...",
"...yyyyyyyyyy...",
"...yyyykkyyyy...",
"...yyyykkyyyy...",
"...yyyyykyyyy...",
"...yyyyyyyyyy...",
"...YYYYYYYYYY...",
"................",
"................",
"................",
"................",
],
"check": [
"................",
"................",
"..............e.",
".............ee.",
"............ee..",
"...........ee...",
"..e.......ee....",
"..ee.....ee.....",
"...ee...ee......",
"....ee.ee.......",
".....eee........",
"......e.........",
"................",
"................",
"................",
"................",
],
"heart": [
"................",
"................",
"..rrr...rrr.....",
".rrwrr.rrrrr....",
".rwrrrrrrrrr....",
".rrrrrrrrrrr....",
"..rrrrrrrrr.....",
"...rrrrrrr......",
"....rrrrr.......",
".....rrr........",
"......r.........",
"................",
"................",
"................",
"................",
"................",
],
"clock": [
"................",
"....wwwwww......",
"...wwwwwwww.....",
"..wwwwkwwwww....",
"..wwwwkwwwww....",
"..wwwwkwwwww....",
"..wwwwkkkkww....",
"..wwwwwwwwww....",
"..wwwwwwwwww....",
"...wwwwwwww.....",
"....wwwwww......",
"................",
"................",
"................",
"................",
"................",
],
"magnifier": [
"................",
"...MMMMM........",
"..MccccwM.......",
".MccccwccM......",
".MccwccccM......",
".McccccccM......",
".McccccccM......",
"..MccccccM......",
"...MMMMMNN......",
"........NnN.....",
".........NnN....",
"..........NnN...",
"...........NN...",
"................",
"................",
"................",
],
"truck": [
"................",
"................",
"................",
"uuuuuuuuuu......",
"uwwwwwwwwu......",
"uwwwwwwwwurrrr..",
"uwwwwwwwwurccr..",
"uwwwwwwwwurccrr.",
"uuuuuuuuuurrrrr.",
"uuuuuuuuuurrrrr.",
".xx....xx..xx...",
".xlx..xlx..xlx..",
"..x....x....x...",
"................",
"................",
"................",
],
"shelf": [
"................",
".nn.........nn..",
".nn.rr.uu.e.nn..",
".nn.rr.uu.e.nn..",
".nNNNNNNNNNNNn..",
".nn.........nn..",
".nn.yyy.cc..nn..",
".nn.yyy.cc..nn..",
".nNNNNNNNNNNNn..",
".nn.........nn..",
".nn.pp.ooo..nn..",
".nn.pp.ooo..nn..",
".nNNNNNNNNNNNn..",
".nn.........nn..",
"................",
"................",
],
"cat": [
"................",
"...w......w.....",
"...ww....ww.....",
"...wwwwwwww.....",
"...wkwwwwkw.....",
"...wwwiiwww..y..",
"...wwwwwwww.yw..",
"....rrrrrr..yw..",
"...wwwywwwwwyw..",
"..wwwwwwwwwwww..",
"..wwwwwwwwwwww..",
"..wwwwwwwwwww...",
"...llllllllll...",
"................",
"................",
"................",
],
"sign": [
"................",
"................",
"iiiiiiiiiiiiiii.",
"i.............i.",
"i.c...ccc.ccc.i.",
"i.c...c.c..c..i.",
"i.c...c.c..c..i.",
"i.c...c.c..c..i.",
"i.ccc.ccc..c..i.",
"i.............i.",
"iiiiiiiiiiiiiii.",
"................",
"................",
"................",
"................",
"................",
],
"flag": [
"................",
"................",
".d..............",
".duuuuuuuuuuu...",
".duuuuuuuuuuu...",
".duuuuuuuuuuu...",
".duuuuuuuuuuu...",
".dyyyyyyyyyyy...",
".dyyyyyyyyyyy...",
".dyyyyyyyyyyy...",
".dyyyyyyyyyyy...",
".d..............",
".d..............",
".d..............",
"................",
"................",
],
"close": [
"................",
"................",
"..rr........rr..",
"..rrr......rrr..",
"...rrr....rrr...",
"....rrr..rrr....",
".....rrrrrr.....",
"......rrrr......",
"......rrrr......",
".....rrrrrr.....",
"....rrr..rrr....",
"...rrr....rrr...",
"..rrr......rrr..",
"..rr........rr..",
"................",
"................",
],
"back": [
"................",
"................",
".....l..........",
"....ll..........",
"...lll..........",
"..lllllllllll...",
".llllllllllll...",
"..lllllllllll...",
"...lll..........",
"....ll..........",
".....l..........",
"................",
"................",
"................",
"................",
"................",
],
"phone": [
"................",
"....xxxxxxx.....",
"....xcccccx.....",
"....xcccccx..l..",
".l..xcccccx...l.",
"l...xcccccx...l.",
"l...xcccccx...l.",
".l..xcccccx..l..",
"....xcccccx.....",
"....xxxxxxx.....",
"....xxxlxxx.....",
"....xxxxxxx.....",
"................",
"................",
"................",
"................",
],
"hand": [
"................",
"......w.w.w.....",
"......w.w.w.w...",
"......wwwwwww...",
".w....wwwwwww...",
".ww...wwwwwww...",
"..ww.wwwwwwww...",
"...wwwwwwwwww...",
"....wwwwwwwww...",
".....wwwwwww....",
"......wwwww.....",
"......wwwww.....",
"................",
"................",
"................",
"................",
],
"sparkle": [
"................",
".......w........",
".......w........",
"......wyw.......",
"...wwwyyywww....",
"......wyw.......",
".......w........",
".......w........",
"................",
"................",
"................",
"................",
"................",
"................",
"................",
"................",
],
"trophy": [
"................",
"...yyyyyyyyyy...",
".yyywyyyyyyyyyy.",
".y.yyyyyyyyyy.y.",
".y.yyyyyyyyyy.y.",
"..yyyyyyyyyyyy..",
"....yyyyyyyy....",
".....yyyyyy.....",
"......yyyy......",
".......yy.......",
".......yy.......",
".....YYYYYY.....",
"....nnnnnnnn....",
"....nnnnnnnn....",
"................",
"................",
],
"rain": [
"................",
"....llll........",
"..llwwwwll......",
".lwwwwwwwwl.....",
".lllllllllll....",
"................",
"..c...c...c.....",
".c...c...c......",
"................",
"...c...c...c....",
"..c...c...c.....",
"................",
"................",
"................",
"................",
"................",
],
}


def make_icons():
    out = {}
    for name, rows in ICONS.items():
        img = outline(center16(from_rows(rows, 16)))
        save(img, "icons", name + ".png")
        out[name] = img
    return out


# ------------------------------------------------------------------ UI nine-patches (pre-scaled 2x)
BTN = {
    "gold": ("#f8c848", "#fbe08a", "#b07a1c"),
    "green": ("#5cb848", "#8ad870", "#2f7a33"),
    "red": ("#d8434b", "#f07a80", "#8e2a3c"),
    "blue": ("#4f7ae0", "#86a6f0", "#2c3f8c"),
    "dark": ("#4a4060", "#6a5e88", "#2b2638"),
    "grey": ("#5c5c6c", "#74748a", "#3a3a48"),
    "purple": ("#a060dc", "#c896f0", "#5e3090"),
}


def make_ui():
    for name, (mid, hi, lo) in BTN.items():
        # normal: 12x14 with a 3px base
        c = C(12, 14)
        c.rect(1, 1, 10, 12, lo)
        c.rect(1, 1, 10, 9, mid)
        c.hl(2, 9, 1, hi)
        c.vl(1, 2, 8, hi)
        c.frame(0, 0, 11, 13, OUTLINE)
        c.px(0, 0, (0, 0, 0, 0)), c.px(11, 0, (0, 0, 0, 0)), c.px(0, 13, (0, 0, 0, 0)), c.px(11, 13, (0, 0, 0, 0))
        save(scale(c.img, 2), "ui", f"btn_{name}.png")
        # pressed: pushed down, thin base
        c = C(12, 14)
        c.rect(1, 3, 10, 12, lo)
        c.rect(1, 3, 10, 11, mid)
        c.hl(2, 9, 3, hi)
        c.frame(0, 2, 11, 13, OUTLINE)
        c.px(0, 2, (0, 0, 0, 0)), c.px(11, 2, (0, 0, 0, 0)), c.px(0, 13, (0, 0, 0, 0)), c.px(11, 13, (0, 0, 0, 0))
        save(scale(c.img, 2), "ui", f"btn_{name}_pressed.png")
    # panels
    for name, (fill, border, hi) in {
        "panel": ("#2b2638", "#5a4f73", "#3a3350"),
        "card": ("#3a3350", "#7a6c9a", "#4a4266"),
        "paper": ("#efe2c4", "#a8865a", "#fff4dc"),
        "dark": ("#16131f", "#3a3350", "#221d2e"),
        "slot": ("#221d2e", "#4a4266", "#1a1626"),
    }.items():
        c = C(12, 12)
        c.rect(1, 1, 10, 10, fill)
        c.frame(1, 1, 10, 10, border)
        c.hl(2, 9, 2, hi)
        c.frame(0, 0, 11, 11, OUTLINE)
        c.px(0, 0, (0, 0, 0, 0)), c.px(11, 0, (0, 0, 0, 0)), c.px(0, 11, (0, 0, 0, 0)), c.px(11, 11, (0, 0, 0, 0))
        save(scale(c.img, 2), "ui", f"{name}.png")
    # rarity frames for item slots
    for name, col in {"common": "#9a9aae", "uncommon": "#72c04c", "rare": "#4f9ae8", "epic": "#b070ec",
                      "legendary": "#f8c848"}.items():
        c = C(12, 12)
        c.rect(1, 1, 10, 10, "#221d2e")
        c.frame(1, 1, 10, 10, col)
        c.frame(2, 2, 9, 9, shade(col, 0.55))
        c.frame(0, 0, 11, 11, OUTLINE)
        c.px(0, 0, (0, 0, 0, 0)), c.px(11, 0, (0, 0, 0, 0)), c.px(0, 11, (0, 0, 0, 0)), c.px(11, 11, (0, 0, 0, 0))
        save(scale(c.img, 2), "ui", f"slot_{name}.png")
    # speech bubble (nine-patch body) and its tail
    c = C(12, 12)
    c.rect(1, 1, 10, 10, "w")
    c.frame(0, 0, 11, 11, OUTLINE)
    c.px(0, 0, (0, 0, 0, 0)), c.px(11, 0, (0, 0, 0, 0)), c.px(0, 11, (0, 0, 0, 0)), c.px(11, 11, (0, 0, 0, 0))
    c.px(1, 1, OUTLINE), c.px(10, 1, OUTLINE), c.px(1, 10, OUTLINE), c.px(10, 10, OUTLINE)
    save(scale(c.img, 2), "ui", "bubble.png")
    t = from_rows(["kwwwwk", ".kwwk.", "..kk..", "......"], 6)
    save(scale(t, 2), "ui", "bubble_tail.png")
    # bars
    c = C(8, 6)
    c.rect(0, 0, 7, 5, OUTLINE)
    c.rect(1, 1, 6, 4, "#16131f")
    save(scale(c.img, 2), "ui", "bar_bg.png")


def make_bg():
    """Subtle dark brick tile behind the menus (pre-scaled 2x, drawn tiled)."""
    c = C(32, 32, "#18151f")
    for row in range(4):
        y = row * 8
        c.hl(0, 31, y, "#1d1926")
        off = 0 if row % 2 == 0 else 8
        for x in range(off, 32 + off, 16):
            c.vl(x % 32, y + 1, y + 7, "#1d1926")
    for (x, y) in ((5, 3), (21, 12), (12, 27), (28, 20)):
        c.px(x, y, "#211c2b")
    save(scale(c.img, 2), "ui", "bg_tile.png")


# ------------------------------------------------------------------ effects
def make_fx():
    # light rays
    import math
    c = C(64, 64)
    for y in range(64):
        for x in range(64):
            dx, dy = x - 31.5, y - 31.5
            r = math.hypot(dx, dy)
            if r > 31:
                continue
            a = math.atan2(dy, dx)
            ray = (math.cos(a * 8) + 1) / 2
            fall = max(0.0, 1 - r / 31)
            v = ray * fall
            if v > 0.55:
                c.px(x, y, (255, 246, 200, 150))
            elif v > 0.3:
                c.px(x, y, (255, 246, 200, 70))
            elif r < 9:
                c.px(x, y, (255, 246, 200, 60))
    save(c.img, "fx", "rays.png")
    # glow
    c = C(32, 32)
    for y in range(32):
        for x in range(32):
            r = math.hypot(x - 15.5, y - 15.5)
            if r < 7:
                c.px(x, y, (255, 255, 255, 170))
            elif r < 11:
                c.px(x, y, (255, 255, 255, 100))
            elif r < 15 and (x + y) % 2 == 0:
                c.px(x, y, (255, 255, 255, 60))
    save(c.img, "fx", "glow.png")
    star = from_rows([
        "...w...",
        "...w...",
        "..wyw..",
        "wwyyyww",
        "..wyw..",
        "...w...",
        "...w...",
    ], 7)
    save(star, "fx", "sparkle.png")
    coin = from_rows([
        "..YYYY..",
        ".YyyyyY.",
        "YyywyyyY",
        "YyywyyyY",
        "YyyyYyyY",
        "YyyyYyyY",
        ".YyyyyY.",
        "..YYYY..",
    ], 8)
    save(outline(coin), "fx", "coin.png")
    dust = from_rows([".ll.", "llll", "llll", ".ll."], 4)
    save(dust, "fx", "dust.png")
    pix = from_rows(["ww", "ww"], 2)
    save(pix, "fx", "pixel.png")


# ------------------------------------------------------------------ garage scene
def make_garage():
    W, H = 180, 260
    c = C(W, H)
    # corrugated wall
    for x in range(W):
        col = "#3e4a5c" if (x // 3) % 2 == 0 else "#47566c"
        if x % 6 == 5:
            col = "#33404f"
        c.vl(x, 0, 190, col)
    c.hl(0, W - 1, 96, "#2b3442")
    c.hl(0, W - 1, 97, "#56667e")
    # ceiling beam
    c.rect(0, 0, W - 1, 7, "#22283a")
    c.hl(0, W - 1, 7, "#141824")
    for x in range(4, W, 16):
        c.px(x, 3, "#5a6278")
    # floor
    c.rect(0, 190, W - 1, H - 1, "#5a5560")
    c.hl(0, W - 1, 188, "#1f1d28")
    c.hl(0, W - 1, 189, "#2e2b38")
    c.hl(0, W - 1, 190, "#7a7482")
    for y in range(200, H, 14):
        c.hl(0, W - 1, y, "#524d58")
    rnd = random.Random(7)
    for _ in range(140):
        x, y = rnd.randrange(W), rnd.randrange(192, H)
        c.px(x, y, "#4e4954" if rnd.random() < 0.6 else "#66606c")
    for i in range(18):
        c.px(30 + i, 230 + (i % 5 == 0), "#45404c")
    # a stack of old tyres and an oil drum on the floor
    for (tx, ty) in ((6, 214), (8, 205)):
        c.ellipse(tx, ty, tx + 30, ty + 14, "#1f1d28")
        c.ellipse(tx + 2, ty + 2, tx + 28, ty + 12, "#2e2b38")
        c.ellipse(tx + 9, ty + 4, tx + 21, ty + 10, "#141824")
        c.hl(tx + 6, tx + 24, ty + 2, "#46424f")
    c.rect(150, 196, 170, 226, "#2f7f45")
    c.rect(150, 196, 170, 198, "#72c04c")
    c.hl(150, 170, 206, "#235e33"), c.hl(150, 170, 216, "#235e33")
    c.rect(167, 199, 168, 224, "#4f9a5c")
    c.rect(156, 194, 160, 195, "#2b2b3a")
    c.hl(150, 170, 226, "#1f1d28")
    c.ellipse(130, 236, 160, 244, "#45404c")
    c.ellipse(134, 237, 154, 242, "#3c3844")
    # light pool under the lamp
    for y in range(194, 226):
        for x in range(54, 128):
            dx, dy = (x - 91) / 37.0, (y - 210) / 15.0
            if dx * dx + dy * dy < 1 and (x + y) % 2 == 0:
                c.px(x, y, "#686270")
    # roll-up door frame and the outside
    c.rect(64, 72, 120, 190, "#2a2f3c")
    c.rect(67, 76, 117, 188, "#86c8ea")
    c.rect(67, 76, 117, 120, "#9ad4f0")
    c.rect(67, 140, 117, 188, "#4a4a52")
    c.rect(67, 140, 117, 141, "#8a8a92")
    c.rect(67, 132, 117, 139, "#5c8c48")
    for x in range(70, 117, 9):
        c.rect(x, 126, x + 4, 133, "#4a7a3c")
    for x in range(67, 118, 12):
        c.rect(x, 163, x + 5, 164, "#c8c8c8")
    # half-open door slats
    c.rect(67, 76, 117, 116, "#8a8f9c")
    for y in range(79, 116, 4):
        c.hl(67, 117, y, "#6c707c")
        c.hl(67, 117, y + 1, "#9ca1ae")
    c.rect(67, 115, 117, 117, "#5a5e6a")
    c.rect(89, 112, 95, 114, "#3a3e48")
    # door track
    c.vl(64, 72, 190, "#1c202a"), c.vl(120, 72, 190, "#1c202a")
    # lamp
    c.vl(91, 8, 30, "#1c202a")
    c.rect(85, 30, 97, 33, "#2f8aa8")
    c.rect(83, 34, 99, 35, "#2f8aa8")
    c.hl(84, 98, 30, "#62d0e4")
    c.rect(89, 36, 93, 37, "#fff4b0")
    # shelf posts (boards are separate sprites)
    for x in (2, 60):
        c.rect(x, 40, x + 2, 188, "#6a4a32")
        c.vl(x, 40, 188, "#8a6446")
    # notice board
    c.rect(124, 16, 176, 60, "#5a3828")
    c.rect(126, 18, 174, 58, "#b0845a")
    for (x, y, w, h, col) in ((129, 21, 14, 16, "#f2f0f5"), (146, 23, 12, 10, "#f8d448"), (160, 20, 11, 14, "#86c8ea"),
                              (131, 40, 16, 14, "#f28cba"), (151, 37, 18, 18, "#f2f0f5")):
        c.rect(x, y, x + w - 1, y + h - 1, col)
        c.px(x + w // 2, y + 1, "#d8434b")
        for ly in range(y + 4, y + h - 2, 3):
            c.hl(x + 2, x + w - 3, ly, "#7c7c94")
    # pegboard
    c.rect(124, 68, 176, 130, "#a87a52")
    for y in range(71, 129, 5):
        for x in range(127, 175, 5):
            c.px(x, y, "#7a5434")
    c.frame(124, 68, 176, 130, "#5a3828")
    # tools on pegboard
    c.rect(130, 74, 131, 92, "#8a5a3a"), c.rect(127, 74, 134, 77, "#8e9eb2")                    # hammer
    c.rect(140, 75, 142, 100, "#8e9eb2"), c.rect(139, 100, 143, 104, "#d8434b")                   # screwdriver
    c.rect(150, 76, 162, 82, "#dfe6ee"), c.rect(162, 76, 166, 84, "#8a5a3a")                       # saw
    for x in range(150, 162, 2):
        c.px(x, 83, "#dfe6ee")
    c.rect(170, 76, 171, 96, "#8e9eb2"), c.rect(168, 74, 173, 77, "#8e9eb2")                       # wrench
    c.ellipse(146, 106, 162, 122, "#f0903c"), c.ellipse(150, 110, 158, 118, "#a87a52")              # tape/cable
    save(c.img, "garage", "garage_bg.png")

    # shelf boards: wood (levels 0-3) and steel (level 4)
    for name, top, front in (("board_wood", "#b07a50", "#7a5434"), ("board_steel", "#c0c8d4", "#7c8698")):
        b = C(62, 5)
        b.rect(0, 0, 61, 1, top)
        b.rect(0, 2, 61, 3, front)
        b.hl(0, 61, 4, "#1f1d28")
        save(b.img, "garage", name + ".png")

    # workbench levels 0..4 (60x46)
    for lvl in range(5):
        b = C(60, 46)
        if lvl <= 1:
            top, leg, dark = "#b07a50", "#7a5434", "#4a3020"
        elif lvl <= 3:
            top, leg, dark = "#c08a5a", "#6a4a32", "#3a2618"
        else:
            top, leg, dark = "#dfe6ee", "#7c8698", "#3a404c"
        b.rect(0, 4, 59, 9, top)
        b.hl(0, 59, 4, "#fff4dc" if lvl >= 4 else "#d8a878")
        b.hl(0, 59, 9, dark)
        b.rect(3, 10, 6, 45, leg), b.rect(53, 10, 56, 45, leg)
        if lvl == 0:
            b.line((7, 20), (52, 36), leg)  # rickety cross brace
            b.rect(53, 10, 56, 41, leg)
        if lvl >= 1:
            b.rect(7, 34, 52, 36, leg)  # lower shelf
            b.rect(46, 0, 54, 3, "#5a6278"), b.rect(49, -1, 51, 0, "#5a6278")  # vise
            b.rect(44, 1, 56, 2, "#7c8698")
        if lvl >= 2:
            b.rect(9, 12, 30, 30, dark)
            for y in (13, 21):
                b.rect(10, y, 29, y + 6, "#8a5a3a" if lvl < 4 else "#d8434b")
                b.rect(18, y + 3, 21, y + 3, "#f8d448")
        if lvl >= 3:
            b.vl(4, -10, 3, "#2b2b3a")
            b.rect(2, -12, 8, -10, "#f8d448")
        if lvl >= 4:
            b.rect(32, 12, 51, 33, "#d8434b")
            for y in (14, 20, 26):
                b.hl(33, 50, y, "#8e2a3c")
                b.rect(40, y + 2, 43, y + 2, "#dfe6ee")
        save(outline(b.img, grow=False), "garage", f"bench_{lvl}.png")
    # tall bench sprites (vise/lamp go above the top) need extra headroom: redraw with offset canvas
    for lvl in range(5):
        src = Image.open(os.path.join(ROOT, "garage", f"bench_{lvl}.png"))
        tall = Image.new("RGBA", (60, 58), (0, 0, 0, 0))
        tall.paste(src, (0, 12))
        save(tall, "garage", f"bench_{lvl}.png")
    # workbench extras with headroom drawn separately (lamp arm for level 3+)
    lamp = C(16, 22)
    lamp.vl(3, 6, 21, "#2b2b3a"), lamp.line((3, 6), (10, 2), "#2b2b3a")
    lamp.rect(8, 1, 14, 4, "#f8d448"), lamp.rect(9, 5, 13, 5, "#fff4b0")
    lamp.rect(0, 20, 6, 21, "#2b2b3a")
    save(outline(lamp.img, grow=False), "garage", "bench_lamp.png")

    # scanner levels 1..4 (16x14)
    for lvl in range(1, 5):
        s = C(16, 14)
        if lvl == 1:  # magnifier on a stand
            s.rect(6, 12, 12, 13, "#5a6278")
            s.vl(9, 6, 12, "#5a6278")
            s.ellipse(3, 0, 11, 8, "#8e9eb2")
            s.ellipse(5, 2, 9, 6, "#9ad4f0")
            s.px(6, 3, "w")
        else:  # appraisal screen device
            col = {2: "#72c04c", 3: "#62d0e4", 4: "#f28cba"}[lvl]
            s.rect(1, 1, 14, 10, "#2b2b3a")
            s.rect(2, 2, 13, 8, "#16131f")
            for x in range(3, 13):
                y = 5 + int(2 * __import__("math").sin(x * 1.3 + lvl))
                s.px(x, y, col)
            s.rect(5, 11, 10, 13, "#5a6278")
            s.px(12, 9, "#d8434b")
        save(outline(s.img, grow=False), "garage", f"scanner_{lvl}.png")
    # lucky cat levels 1..4 (14x16)
    for lvl in range(1, 5):
        body = {1: "#f2f0f5", 2: "#f2f0f5", 3: "#f8d448", 4: "#f8d448"}[lvl]
        rows = [
            "..w......w....",
            "..ww....ww....",
            "..wwwwwwww....",
            "..wkwwwwkw..w.",
            "..wwwiiwww.ww.",
            "..wwwwwwww.ww.",
            "...rrrrrr..ww.",
            "..wwwyywww.ww.",
            ".wwwwwwwwwww..",
            ".wwwwwwwwwww..",
            ".wwwwwwwwww...",
            ".wwwwwwwwww...",
            "..llllllll....",
        ]
        img = from_rows(rows, 14)
        px = img.load()
        for y in range(img.size[1]):
            for x in range(img.size[0]):
                if px[x, y] == rgba("w"):
                    px[x, y] = rgba(body)
        if lvl >= 2:
            px[2, 9] = rgba("r")
        if lvl == 4:
            px[6, 7] = rgba("c")
            px[7, 7] = rgba("c")
        save(outline(img), "garage", f"cat_{lvl}.png")
    # sign levels 1..4 (56x18): wooden board, then neon with growing glow
    for lvl in range(1, 5):
        s = C(56, 18)
        letters = {
            "L": ["1.", "1.", "1.", "1.", "11"],
            "O": ["111", "1.1", "1.1", "1.1", "111"],
            "T": ["111", ".1.", ".1.", ".1.", ".1."],
            "1": [".1", "11", ".1", ".1", ".1"],
            "3": ["111", "..1", ".11", "..1", "111"],
        }
        if lvl == 1:
            s.rect(1, 2, 54, 15, "#8a5a3a")
            s.frame(1, 2, 54, 15, "#5a3828")
            ink = "#f2f0f5"
        else:
            s.rect(1, 2, 54, 15, "#16131f")
            s.frame(1, 2, 54, 15, "#3a3350")
            ink = {2: "#f28cba", 3: "#62d0e4", 4: "#f8d448"}[lvl]
        x = 6
        for ch in "LOT 13":
            if ch == " ":
                x += 4
                continue
            glyph = letters[ch]
            for gy, row in enumerate(glyph):
                for gx, v in enumerate(row):
                    if v == "1":
                        s.rect(x + gx * 2, 4 + gy * 2, x + gx * 2 + 1, 4 + gy * 2 + 1, ink)
            x += len(glyph[0]) * 2 + 3
        if lvl >= 3:
            s.vl(10, 0, 1, "#2b2b3a"), s.vl(45, 0, 1, "#2b2b3a")
        save(outline(s.img, grow=False), "garage", f"sign_{lvl}.png")
    # truck levels 1..3 (48x26), seen through the door
    for lvl in range(1, 4):
        body = {1: "#d8434b", 2: "#4f7ae0", 3: "#f8c848"}[lvl]
        t = C(48, 26)
        t.rect(0, 6, 30, 19, "#dfe6ee" if lvl < 3 else "#2b2b3a")
        t.rect(0, 6, 30, 7, "#f2f0f5" if lvl < 3 else "#4a4a5e")
        t.rect(31, 9, 46, 19, body)
        t.rect(34, 10, 42, 14, "#9ad4f0")
        t.rect(44, 15, 46, 16, "#f8d448")
        t.hl(0, 46, 19, "#2b2b3a")
        for wx in (6, 22, 38):
            t.ellipse(wx - 4, 17, wx + 4, 25, "#2b2b3a")
            t.rect(wx - 1, 20, wx + 1, 22, "#b4b4c8")
        if lvl >= 2:
            t.rect(4, 10, 26, 14, body)
        if lvl >= 3:
            t.rect(8, 11, 22, 13, "#f8d448")
        save(outline(t.img, grow=False), "garage", f"truck_{lvl}.png")


# ------------------------------------------------------------------ auction stage
def make_auction():
    W, H = 180, 150
    c = C(W, H, "#2a1830")
    for y in range(0, 118):
        for x in range(30, 150):
            if (x + y) % 7 == 0:
                c.px(x, y, "#331d3a")
    # spotlight cone
    for y in range(14, 120):
        half = 8 + (y - 14) * 0.32
        for x in range(int(90 - half), int(90 + half)):
            if (x + y) % 2 == 0:
                c.px(x, y, "#3e2a48")
    # stage floor
    c.rect(0, 118, W - 1, H - 1, "#6a4a32")
    for y in range(122, H, 6):
        c.hl(0, W - 1, y, "#5a3e2a")
    for i in range(0, W, 23):
        c.vl(i, 118, H - 1, "#5a3e2a")
    c.hl(0, W - 1, 118, "#8a6446")
    c.ellipse(52, 116, 128, 132, "#7c5a3e")
    # curtains
    for side in (0, 1):
        for x in range(0, 32):
            xx = x if side == 0 else W - 1 - x
            fold = (x // 4) % 2
            col = "#a82838" if fold else "#8e2030"
            if x % 4 == 3:
                col = "#6a1626"
            c.vl(xx, 0, 140 - (x // 3), col)
        # tie-back
        cx = 22 if side == 0 else W - 23
        c.rect(cx - 2, 70, cx + 2, 73, "#f8c848")
    # valance with fringe
    c.rect(0, 0, W - 1, 12, "#8e2030")
    for x in range(0, W, 10):
        c.ellipse(x - 2, 6, x + 8, 16, "#a82838")
    c.hl(0, W - 1, 14, "#c08a26")
    for x in range(0, W, 2):
        c.px(x, 15, "#f8c848")
    # pedestal
    c.rect(68, 104, 112, 108, "#c99560")
    c.rect(72, 109, 108, 124, "#8a5a3a")
    c.rect(68, 124, 112, 127, "#5a3828")
    c.hl(68, 112, 104, "#e8c08a")
    c.vl(106, 109, 124, "#5a3828")
    save(c.img, "auction", "stage.png")
    # podium for the auctioneer (40x30)
    p = C(40, 30)
    p.rect(0, 0, 39, 4, "#c08a26")
    p.rect(3, 5, 36, 29, "#5a3828")
    p.rect(6, 8, 33, 26, "#6a4630")
    p.rect(15, 12, 24, 20, "#c08a26")
    p.rect(17, 14, 22, 18, "#f8d448")
    save(outline(p.img, grow=False), "auction", "podium.png")


# ------------------------------------------------------------------ app icon
def make_icon(boxes):
    c = C(48, 48, "#1d1a26")
    for y in range(48):
        for x in range(48):
            d = (x - 23.5) ** 2 + (y - 27) ** 2
            if d < 300:
                c.px(x, y, "#3a2c50" if (x + y) % 2 == 0 or d < 120 else "#2b2240")
    rays = Image.open(os.path.join(ROOT, "fx", "rays.png")).resize((44, 44), Image.NEAREST)
    c.img.alpha_composite(rays, (2, 8))
    c.paste(boxes["golden_open"], 8, 16)
    # big "13" above the chest, gold with a dark outline
    digits = {
        "1": [".1.", "11.", ".1.", ".1.", "111"],
        "3": ["111.", "...1", ".11.", "...1", "111."],
    }
    glyph = C(11, 7)
    x0 = 1
    for ch in "13":
        rows = digits[ch]
        for gy, row in enumerate(rows):
            for gx, v in enumerate(row):
                if v == "1":
                    glyph.rect(x0 + gx * 1, 1 + gy * 1, x0 + gx * 1, 1 + gy * 1, "#f8d448")
        x0 += max(len(r) for r in rows) + 1
    big = scale(outline(glyph.img, grow=False), 2)
    c.paste(big, 24 - big.size[0] // 2, 0)
    for (x, y) in ((6, 10), (41, 8), (42, 36), (5, 34)):
        c.paste(from_rows(["..w..", "..w..", "wwyww", "..w..", "..w.."], 5), x - 2, y - 2)
    icon = scale(c.img, 4)
    icon.save(os.path.join(ROOT, "..", "..", "icon.png"))
    return icon


def contact_sheet(items, boxes, portraits, icons, path):
    cell = 20
    rows = []
    sheet = Image.new("RGBA", (10 * cell, 4 * cell), rgba("#2b2638"))
    for i, img in enumerate(items):
        sheet.alpha_composite(img, ((i % 10) * cell + 1, (i // 10) * cell + 1))
    rows.append(scale(sheet, 4))
    bs = Image.new("RGBA", (6 * 34, 2 * 34), rgba("#2b2638"))
    names = list(boxes.keys())
    kinds = list(BOXES.keys())
    for i, k in enumerate(kinds):
        bs.alpha_composite(boxes[f"{k}_closed"], (i * 34 + 1, 1))
        bs.alpha_composite(boxes[f"{k}_open"], (i * 34 + 1, 35))
    rows.append(scale(bs, 4))
    ps = Image.new("RGBA", (10 * 26, 2 * 26), rgba("#2b2638"))
    for i, (k, img) in enumerate(portraits.items()):
        ps.alpha_composite(img, ((i % 10) * 26 + 1, (i // 10) * 26 + 1))
    rows.append(scale(ps, 3))
    ic = Image.new("RGBA", (16 * 20, 2 * 20), rgba("#2b2638"))
    for i, (k, img) in enumerate(icons.items()):
        ic.alpha_composite(img, ((i % 16) * 20 + 1, (i // 16) * 20 + 1))
    rows.append(scale(ic, 3))
    W = max(r.size[0] for r in rows)
    H = sum(r.size[1] for r in rows) + 8 * len(rows)
    out = Image.new("RGBA", (W, H), rgba("#16131f"))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.size[1] + 8
    out.save(path)


def garage_preview(path):
    g = Image.open(os.path.join(ROOT, "garage", "garage_bg.png")).copy()
    board = Image.open(os.path.join(ROOT, "garage", "board_wood.png"))
    for y in (66, 94, 122, 150, 178):
        g.alpha_composite(board, (1, y))
    g.alpha_composite(Image.open(os.path.join(ROOT, "garage", "bench_3.png")), (120, 132))
    g.alpha_composite(Image.open(os.path.join(ROOT, "garage", "sign_3.png")), (64, 50))
    g.alpha_composite(Image.open(os.path.join(ROOT, "garage", "truck_2.png")), (68, 150))
    g.alpha_composite(Image.open(os.path.join(ROOT, "garage", "cat_3.png")), (124, 129))
    g.alpha_composite(Image.open(os.path.join(ROOT, "garage", "scanner_3.png")), (158, 130))
    box = Image.open(os.path.join(ROOT, "boxes", "crate_closed.png"))
    g.alpha_composite(box, (74, 200))
    g.alpha_composite(Image.open(os.path.join(ROOT, "boxes", "cardboard_closed.png")), (98, 210))
    for i, iid in enumerate(ORDER[:9]):
        it = Image.open(os.path.join(ROOT, "items", iid + ".png"))
        g.alpha_composite(it, (5 + (i % 3) * 18, 66 - 18 + (i // 3) * 28))
    st = Image.open(os.path.join(ROOT, "auction", "stage.png"))
    out = Image.new("RGBA", (g.size[0] + st.size[0] + 4, max(g.size[1], st.size[1])), rgba("#16131f"))
    out.alpha_composite(g, (0, 0))
    out.alpha_composite(st, (g.size[0] + 4, 0))
    out.alpha_composite(Image.open(os.path.join(ROOT, "auction", "podium.png")), (g.size[0] + 4 + 132, 90))
    scale(out, 3).save(path)


if __name__ == "__main__":
    items = make_items()
    boxes = make_boxes()
    portraits = make_portraits()
    icons = make_icons()
    make_ui()
    make_bg()
    make_fx()
    make_garage()
    make_auction()
    make_icon(boxes)
    if len(sys.argv) > 1:
        contact_sheet(items, boxes, portraits, icons, os.path.join(sys.argv[1], "sheet.png"))
        garage_preview(os.path.join(sys.argv[1], "garage.png"))
    print("art ok:", len(items), "items")
