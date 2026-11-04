#!/usr/bin/env python3
"""LAST DEAL — генератор оригінальної піксельної графіки.

Уся графіка гри малюється цим скриптом з геометричних примітивів (жодних
сторонніх зображень). Запуск:  python3 tools/gen_art.py   (з папки last_deal_mobile)
Результат: assets/art/**.png та assets/icons/*.png. Масштаб у грі — ×4, фільтр «nearest».
"""
import math
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")
ICONS = os.path.join(ROOT, "assets", "icons")


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


OUT = hexc("#120d1c")  # outline


class Canvas:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.img = Image.new("RGBA", (w, h), bg)
        self.d = ImageDraw.Draw(self.img)
        self.w, self.h = w, h

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((int(x), int(y)), c)

    def rect(self, x, y, w, h, c):
        if w <= 0 or h <= 0:
            return
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)

    def orect(self, x, y, w, h, fill, line=OUT):
        self.rect(x, y, w, h, line)
        self.rect(x + 1, y + 1, w - 2, h - 2, fill)

    def line(self, x0, y0, x1, y1, c, width=1):
        self.d.line([x0, y0, x1, y1], fill=c, width=width)

    def ellipse(self, x, y, w, h, c):
        self.d.ellipse([x, y, x + w - 1, y + h - 1], fill=c)

    def oellipse(self, x, y, w, h, fill, line=OUT):
        self.ellipse(x, y, w, h, line)
        self.ellipse(x + 1, y + 1, w - 2, h - 2, fill)

    def poly(self, pts, c):
        self.d.polygon(pts, fill=c)

    def blend(self, x, y, c, a):
        if 0 <= x < self.w and 0 <= y < self.h:
            r, g, b, al = self.img.getpixel((x, y))
            nr = int(r + (c[0] - r) * a)
            ng = int(g + (c[1] - g) * a)
            nb = int(b + (c[2] - b) * a)
            self.img.putpixel((x, y), (nr, ng, nb, max(al, int(255 * a)) if al == 0 else al))

    def outline_alpha(self, c=OUT):
        """Додає однопіксельний контур навколо непрозорих пікселів."""
        src = self.img.copy()
        for y in range(self.h):
            for x in range(self.w):
                if src.getpixel((x, y))[3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and src.getpixel((nx, ny))[3] > 0:
                            self.img.putpixel((x, y), c)
                            break

    def save(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.img.save(path)


# ---------------------------------------------------------------- 3x5 pixel font
FONT35 = {
    "L": ["X..", "X..", "X..", "X..", "XXX"],
    "A": [".X.", "X.X", "XXX", "X.X", "X.X"],
    "S": [".XX", "X..", ".X.", "..X", "XX."],
    "T": ["XXX", ".X.", ".X.", ".X.", ".X."],
    "D": ["XX.", "X.X", "X.X", "X.X", "XX."],
    "E": ["XXX", "X..", "XX.", "X..", "XXX"],
    "O": [".X.", "X.X", "X.X", "X.X", ".X."],
    "P": ["XX.", "X.X", "XX.", "X..", "X.."],
    "N": ["X.X", "XXX", "XXX", "X.X", "X.X"],
    "2": ["XX.", "..X", ".X.", "X..", "XXX"],
    "4": ["X.X", "X.X", "XXX", "..X", "..X"],
    "7": ["XXX", "..X", ".X.", ".X.", ".X."],
    "H": ["X.X", "X.X", "XXX", "X.X", "X.X"],
    "R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
    "I": ["XXX", ".X.", ".X.", ".X.", "XXX"],
    "B": ["XX.", "X.X", "XX.", "X.X", "XX."],
    "U": ["X.X", "X.X", "X.X", "X.X", "XXX"],
    "Y": ["X.X", "X.X", ".X.", ".X.", ".X."],
    " ": ["...", "...", "...", "...", "..."],
}


def text35(cv, x, y, s, c, scale=1):
    cx = x
    for ch in s:
        g = FONT35.get(ch, FONT35[" "])
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v == "X":
                    cv.rect(cx + gx * scale, y + gy * scale, scale, scale, c)
        cx += 4 * scale
    return cx


def text35_width(s, scale=1):
    return len(s) * 4 * scale - scale


# ---------------------------------------------------------------- background
W, H = 180, 170


def background():
    rnd = random.Random(7)
    cv = Canvas(W, H, hexc("#1d1430"))
    # стіна: панелі з цегляним малюнком
    wall_a, wall_b, wall_line = hexc("#2a1c40"), hexc("#25183a"), hexc("#1a1029")
    for y in range(0, 128):
        for x in range(W):
            row = y // 6
            off = 0 if row % 2 == 0 else 6
            c = wall_a if ((x + off) // 12 + row) % 2 == 0 else wall_b
            if y % 6 == 0 or (x + off) % 12 == 0:
                c = wall_line
            cv.px(x, y, c)
    # стеля / балка
    cv.rect(0, 0, W, 7, hexc("#140c22"))
    cv.rect(0, 7, W, 2, hexc("#3a2758"))
    # плінтус
    cv.rect(0, 122, W, 6, hexc("#1a1029"))

    # ---- вікно з нічним містом (ліворуч)
    wx, wy, ww, wh = 8, 18, 74, 62
    cv.rect(wx - 3, wy - 3, ww + 6, wh + 6, hexc("#0f0a18"))
    cv.rect(wx - 2, wy - 2, ww + 4, wh + 4, hexc("#4a3566"))
    for y in range(wh):
        t = y / wh
        r = int(18 + 60 * t)
        g = int(14 + 20 * t)
        b = int(52 + 40 * t)
        cv.rect(wx, wy + y, ww, 1, (r, g, b, 255))
    # зорі та місяць
    for _ in range(18):
        cv.px(wx + rnd.randrange(ww), wy + rnd.randrange(wh // 2), hexc("#c9c3ff"))
    cv.ellipse(wx + 52, wy + 6, 9, 9, hexc("#ffe7b8"))
    cv.ellipse(wx + 55, wy + 5, 8, 8, (r, g, b, 0))
    cv.ellipse(wx + 55, wy + 5, 8, 8, hexc("#22183f"))
    # дальні будинки
    x = wx
    while x < wx + ww:
        bw = rnd.randint(6, 12)
        bh = rnd.randint(18, 40)
        cv.rect(x, wy + wh - bh, bw, bh, hexc("#251a45"))
        x += bw
    # ближні будинки з вікнами
    x = wx - 2
    while x < wx + ww:
        bw = rnd.randint(9, 16)
        bh = rnd.randint(12, 32)
        top = wy + wh - bh
        cv.rect(x, top, bw, bh, hexc("#140f28"))
        if rnd.random() < 0.4:
            cv.rect(x + bw // 2, top - 5, 1, 5, hexc("#140f28"))
            cv.px(x + bw // 2, top - 6, hexc("#ff3f6e"))
        for yy in range(top + 2, wy + wh - 1, 3):
            for xx in range(x + 1, x + bw - 1, 2):
                if rnd.random() < 0.35:
                    col = rnd.choice(["#ffcf6b", "#ffcf6b", "#5ff2ff", "#ff6bd6"])
                    cv.px(xx, yy, hexc(col))
        x += bw + 1
    # неонова реклама за вікном
    cv.rect(wx + 30, wy + 30, 10, 4, hexc("#ff3fa4"))
    cv.rect(wx + 31, wy + 31, 8, 2, hexc("#ffb3e0"))
    # рама: хрестовина
    cv.rect(wx + ww // 2 - 1, wy, 2, wh, hexc("#4a3566"))
    cv.rect(wx, wy + wh // 2 - 1, ww, 2, hexc("#4a3566"))
    # підвіконня
    cv.rect(wx - 4, wy + wh + 2, ww + 8, 3, hexc("#5b4180"))
    cv.rect(wx - 4, wy + wh + 5, ww + 8, 1, hexc("#120c1e"))
    # рослинка на підвіконні
    cv.orect(wx + 4, wy + wh - 4, 7, 6, hexc("#b0603a"))
    for i, (dx, dy) in enumerate([(-2, -5), (1, -8), (4, -6), (6, -3), (0, -3)]):
        cv.ellipse(wx + 5 + dx, wy + wh - 4 + dy, 4, 4, hexc("#3fae6a" if i % 2 else "#2f8a55"))

    # ---- полиці праворуч
    sx, sw = 96, 78
    for i, sy in enumerate([58, 80, 102]):
        cv.rect(sx, sy, sw, 3, hexc("#7a4a2c"))
        cv.rect(sx, sy + 3, sw, 1, hexc("#3b2216"))
        cv.rect(sx + 2, sy + 4, 2, 4, hexc("#3b2216"))
        cv.rect(sx + sw - 4, sy + 4, 2, 4, hexc("#3b2216"))
    shelf_items(cv, sx, rnd)

    # ---- годинник на стіні між вікном і полицями
    cv.oellipse(84, 12, 9, 9, hexc("#d8cfa8"))
    cv.px(88, 14, OUT); cv.px(88, 15, OUT); cv.px(89, 16, OUT)

    # ---- підвісна лампа
    cv.rect(58, 0, 1, 8, hexc("#0f0a18"))
    cv.rect(54, 8, 9, 3, hexc("#3a2758"))
    cv.rect(55, 11, 7, 1, hexc("#ffd88a"))

    # ---- плакат на стіні
    cv.orect(84, 88, 9, 14, hexc("#3ff0ff"))
    cv.rect(86, 90, 5, 4, hexc("#ff3fa4"))
    cv.rect(86, 96, 5, 1, OUT); cv.rect(86, 98, 3, 1, OUT)

    # ---- підлога (видна над стійкою трохи) — задній план
    for y in range(128, H):
        for x in range(W):
            c = hexc("#2b1f3a") if ((x // 10 + y // 5) % 2 == 0) else hexc("#251a33")
            cv.px(x, y, c)

    # ---- тепле світло від лампи (м'який конус)
    light = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(light)
    for i in range(14, 0, -1):
        a = int(5 + (14 - i) * 1.5)
        ld.ellipse([58 - i * 7, 10 - i * 2, 58 + i * 7, 10 + i * 8], fill=(255, 190, 110, a))
    cv.img = Image.alpha_composite(cv.img, light)
    cv.d = ImageDraw.Draw(cv.img)
    return cv


def shelf_items(cv, sx, rnd):
    cols = ["#ff3fa4", "#3ff0ff", "#ffb347", "#8f6bff", "#5ad17a", "#e85d5d", "#c9c3ff", "#f2e36b"]
    for sy in [58, 80, 102]:
        x = sx + 3
        while x < sx + 74:
            kind = rnd.randrange(6)
            c = hexc(rnd.choice(cols))
            if kind == 0:  # коробка
                w, h = rnd.randint(7, 11), rnd.randint(6, 10)
                cv.orect(x, sy - h, w, h, c)
                cv.rect(x + 2, sy - h + 2, w - 4, 1, hexc("#ffffff", 120))
            elif kind == 1:  # пляшка
                w, h = 4, rnd.randint(8, 12)
                cv.orect(x, sy - h + 3, w, h - 3, c)
                cv.rect(x + 1, sy - h, 2, 4, OUT)
                cv.px(x + 1, sy - h + 4, hexc("#ffffff", 160))
            elif kind == 2:  # книжки
                w = 0
                for k in range(rnd.randint(2, 4)):
                    h = rnd.randint(7, 11)
                    cv.orect(x + w, sy - h, 3, h, hexc(rnd.choice(cols)))
                    w += 3
            elif kind == 3:  # монітор
                w, h = 11, 8
                cv.orect(x, sy - h - 1, w, h, hexc("#2a2a3a"))
                cv.rect(x + 1, sy - h, w - 2, h - 2, hexc("#3ff0ff", 200))
                cv.rect(x + 4, sy - 1, 3, 1, OUT)
            elif kind == 4:  # банка з болтами
                w, h = 7, 8
                cv.orect(x, sy - h, w, h, hexc("#9bb3c9"))
                for k in range(3):
                    cv.px(x + 2 + k, sy - 3 - k % 2, hexc("#555566"))
            else:  # касета / картридж
                w, h = 9, 5
                cv.orect(x, sy - h, w, h, c)
                cv.px(x + 3, sy - 3, OUT); cv.px(x + 5, sy - 3, OUT)
            x += w + rnd.randint(1, 3)


def neon_sign():
    """Неонова вивіска LAST DEAL — окремий шар для мерехтіння."""
    s = "LAST DEAL"
    scale = 2
    tw = text35_width(s, scale)
    pad = 5
    cv = Canvas(tw + pad * 2, 10 + pad * 2)
    # світіння
    glow = Canvas(cv.w, cv.h)
    text35(glow, pad, pad, s, hexc("#ff3fa4"), scale)
    gimg = glow.img
    from PIL import ImageFilter
    big = gimg.resize((cv.w * 4, cv.h * 4), Image.NEAREST).filter(ImageFilter.GaussianBlur(7))
    big = big.resize((cv.w, cv.h), Image.BILINEAR)
    # посилити альфу світіння
    px = big.load()
    for y in range(cv.h):
        for x in range(cv.w):
            r, g, b, a = px[x, y]
            px[x, y] = (255, 63, 164, min(255, int(a * 2.2)))
    cv.img = Image.alpha_composite(cv.img, big)
    cv.d = ImageDraw.Draw(cv.img)
    text35(cv, pad, pad, s, hexc("#ff7cc4"), scale)
    # «серцевина» трубки
    core = Canvas(cv.w, cv.h)
    text35(core, pad, pad, s, hexc("#ffe0f2"), scale)
    for y in range(cv.h):
        for x in range(cv.w):
            if core.img.getpixel((x, y))[3] and (x + y) % 2 == 0:
                cv.px(x, y, hexc("#ffd6ee"))
    return cv


def open_sign():
    cv = Canvas(20, 9)
    cv.orect(0, 0, 20, 9, hexc("#10202a"), hexc("#3ff0ff"))
    text35(cv, 2, 2, "OPEN", hexc("#7ff8ff"))
    return cv


def counter():
    """Передній план: стійка з касою. Розмір 180x60, низ прилягає до низу сцени."""
    cv = Canvas(W, 60)
    top = 14
    # стільниця
    cv.rect(0, top, W, 6, hexc("#9a6338"))
    cv.rect(0, top, W, 1, hexc("#c98b52"))
    cv.rect(0, top + 6, W, 2, hexc("#4a2a18"))
    # фронтальна панель
    for y in range(top + 8, 60):
        for x in range(W):
            c = hexc("#6b3f24") if (x // 18) % 2 == 0 else hexc("#633a21")
            if x % 18 == 0:
                c = hexc("#3b2216")
            cv.px(x, y, c)
    # неонова смуга на стійці
    cv.rect(0, top + 12, W, 1, hexc("#3ff0ff"))
    cv.rect(0, top + 13, W, 1, hexc("#1d6f7a"))
    # каса праворуч
    kx, ky = 132, top - 26
    cv.orect(kx, ky + 12, 40, 16, hexc("#3b3550"))      # корпус
    cv.orect(kx + 4, ky, 22, 14, hexc("#2a2440"))        # екран-стійка
    cv.rect(kx + 6, ky + 2, 18, 8, hexc("#0e3b2c"))
    text35(cv, kx + 7, ky + 3, "777", hexc("#5dff9e"))
    for i in range(3):
        for j in range(4):
            cv.rect(kx + 4 + j * 6, ky + 16 + i * 4, 4, 2, hexc("#c9c3ff" if (i + j) % 3 else "#ffb347"))
    cv.rect(kx + 28, ky + 14, 9, 3, hexc("#ff3fa4"))
    cv.rect(kx + 2, ky + 26, 36, 2, hexc("#1a1428"))
    # килимок для товару в центрі
    cv.rect(52, top + 1, 64, 4, hexc("#2b6f5f"))
    cv.rect(52, top + 1, 64, 1, hexc("#3f9c86"))
    # дзвіночок ліворуч
    cv.oellipse(14, top - 6, 9, 7, hexc("#ffd36b"))
    cv.rect(12, top - 1, 13, 2, hexc("#7a5a2a"))
    cv.px(18, top - 7, OUT)
    # лупа (інструмент перевірки)
    cv.oellipse(32, top - 5, 7, 7, hexc("#9ee6ff"))
    cv.line(38, top + 1, 41, top + 3, hexc("#4a2a18"), 2)
    return cv


# ---------------------------------------------------------------- customers
SKINS = ["#f1c7a0", "#d9a07a", "#b97a52", "#8a5634", "#5e3a22", "#c8d4dc"]
COATS = ["#3b6fd1", "#d14a6b", "#4aa36b", "#7a4ad1", "#d18a3b", "#2f3b4f", "#a33b3b", "#3ba3a3", "#5a5a6a", "#b3416b"]
HAIRS = ["#1a1018", "#5a3018", "#d9c06b", "#ff3fa4", "#3ff0ff", "#e8e8f0", "#8f6bff", "#c0402a"]


def customer(idx):
    rnd = random.Random(1000 + idx * 37)
    cv = Canvas(60, 72)
    archetype = idx % 8
    tall = rnd.randint(0, 6)
    wide = rnd.choice([0, 2, 4])
    skin = hexc(SKINS[rnd.randrange(5)])
    coat = hexc(COATS[idx % len(COATS)])
    coat_d = tuple(max(0, int(v * 0.7)) for v in coat[:3]) + (255,)
    hair = hexc(HAIRS[rnd.randrange(len(HAIRS))])
    cx = 30
    head_w, head_h = 16, 16
    head_y = 6 + (6 - tall)
    body_y = head_y + head_h - 1
    bw = 26 + wide
    # тулуб (обрізаний стійкою внизу)
    sh = bw + 8  # плечі ширші за тулуб
    cv.ellipse(cx - sh // 2, body_y, sh, 14, coat)
    cv.rect(cx - sh // 2, body_y + 6, sh, 60, coat)
    cv.rect(cx - sh // 2 + 1, body_y + 12, 2, 50, coat_d)
    cv.rect(cx + sh // 2 - 3, body_y + 12, 2, 50, coat_d)
    cv.rect(cx - sh // 2 + 7, body_y + 14, 1, 40, coat_d)
    cv.rect(cx + sh // 2 - 8, body_y + 14, 1, 40, coat_d)
    # комір/деталі
    if archetype in (0, 3, 6):
        cv.poly([(cx - 6, body_y), (cx, body_y + 8), (cx + 6, body_y)], hexc("#e8e2d0"))
        cv.poly([(cx - 1, body_y + 3), (cx + 1, body_y + 3), (cx + 2, body_y + 16), (cx - 2, body_y + 16)], hexc(rnd.choice(["#ff3fa4", "#3ff0ff", "#ffb347"])))
    elif archetype in (1, 4):
        cv.rect(cx - 1, body_y + 2, 2, 30, coat_d)
        for k in range(4):
            cv.px(cx + 3, body_y + 6 + k * 6, hexc("#ffd36b"))
    else:
        cv.rect(cx - bw // 2 + 3, body_y + 10, bw - 6, 2, hexc("#3ff0ff", 200))
    # шия
    cv.rect(cx - 3, body_y - 2, 6, 4, skin)
    # голова
    if archetype == 7:  # робот
        metal = hexc("#9bb3c9")
        cv.orect(cx - 9, head_y, 18, 17, metal)
        cv.rect(cx - 6, head_y + 5, 12, 4, hexc("#121826"))
        cv.rect(cx - 5, head_y + 6, 3, 2, hexc("#ff3f6e"))
        cv.rect(cx + 2, head_y + 6, 3, 2, hexc("#ff3f6e"))
        cv.rect(cx - 4, head_y + 12, 8, 1, hexc("#3b4a5a"))
        cv.rect(cx, head_y - 5, 1, 5, hexc("#3b4a5a"))
        cv.px(cx, head_y - 6, hexc("#5dff9e"))
    else:
        cv.oellipse(cx - head_w // 2, head_y, head_w, head_h + 1, skin)
        eye_y = head_y + 8
        cv.px(cx - 4, eye_y, OUT); cv.px(cx + 3, eye_y, OUT)
        cv.px(cx - 4, eye_y - 1, OUT); cv.px(cx + 3, eye_y - 1, OUT)
        cv.rect(cx - 2, head_y + 12, 4, 1, hexc("#7a3a3a"))
        # зачіска / головний убір
        if archetype == 0:  # кепка
            cv.rect(cx - 8, head_y, 16, 5, hair)
            cv.rect(cx - 8, head_y + 4, 20, 2, coat_d)
            cv.rect(cx - 8, head_y - 1, 16, 2, coat)
        elif archetype == 1:  # капюшон
            cv.poly([(cx - 11, head_y + 17), (cx - 10, head_y - 2), (cx, head_y - 5), (cx + 10, head_y - 2), (cx + 11, head_y + 17), (cx + 7, head_y + 17), (cx + 7, head_y + 3), (cx - 7, head_y + 3), (cx - 7, head_y + 17)], coat_d)
        elif archetype == 2:  # ірокез
            for k in range(6):
                cv.rect(cx - 2, head_y - 6 + k, 4, 7 - k + 2, hair)
            cv.rect(cx - 1, head_y - 7, 2, 2, hair)
        elif archetype == 3:  # капелюх
            cv.rect(cx - 13, head_y + 2, 26, 2, hexc("#2a2030"))
            cv.rect(cx - 8, head_y - 6, 16, 9, hexc("#2a2030"))
            cv.rect(cx - 8, head_y, 16, 2, hexc("#ff3fa4"))
        elif archetype == 4:  # довге волосся
            cv.rect(cx - 9, head_y - 1, 18, 6, hair)
            cv.rect(cx - 10, head_y + 2, 4, 16, hair)
            cv.rect(cx + 6, head_y + 2, 4, 16, hair)
        elif archetype == 5:  # візор
            cv.rect(cx - 8, head_y - 1, 16, 5, hair)
            cv.rect(cx - 9, head_y + 6, 18, 4, hexc("#3ff0ff"))
            cv.rect(cx - 8, head_y + 7, 16, 1, hexc("#c8ffff"))
        elif archetype == 6:  # пучок + окуляри
            cv.rect(cx - 8, head_y - 1, 16, 5, hair)
            cv.oellipse(cx - 4, head_y - 7, 8, 7, hair)
            cv.rect(cx - 7, head_y + 7, 5, 3, hexc("#ffb347", 200))
            cv.rect(cx + 2, head_y + 7, 5, 3, hexc("#ffb347", 200))
            cv.rect(cx - 2, head_y + 8, 4, 1, OUT)
    # кібер-деталь: імплант на щоці
    if archetype not in (7,) and rnd.random() < 0.5:
        cv.px(cx + 5, head_y + 11, hexc("#5dff9e"))
        cv.px(cx + 6, head_y + 11, hexc("#5dff9e"))
    # руки на стійці
    cv.oellipse(cx - bw // 2 - 6, 61, 10, 8, skin if archetype != 7 else hexc("#9bb3c9"))
    cv.oellipse(cx + bw // 2 - 4, 61, 10, 8, skin if archetype != 7 else hexc("#9bb3c9"))
    cv.outline_alpha()
    return cv


# ---------------------------------------------------------------- items (32x32)
def item_canvas():
    return Canvas(32, 32)


def it_phone():
    cv = item_canvas()
    cv.orect(10, 3, 13, 26, hexc("#2b2b3a"))
    cv.rect(12, 6, 9, 17, hexc("#3ff0ff"))
    for y in range(6, 23):
        cv.rect(12, y, 9, 1, (40 + y * 6, 160 + y * 3, 230, 255))
    cv.rect(13, 8, 3, 3, hexc("#ff3fa4")); cv.rect(17, 8, 3, 3, hexc("#ffb347"))
    cv.rect(13, 13, 3, 3, hexc("#5dff9e")); cv.rect(17, 13, 3, 3, hexc("#8f6bff"))
    cv.rect(15, 25, 3, 2, hexc("#55556a"))
    cv.rect(14, 4, 5, 1, hexc("#55556a"))
    cv.line(12, 6, 15, 6, hexc("#ffffff"))
    return cv


def it_laptop():
    cv = item_canvas()
    cv.orect(6, 5, 21, 15, hexc("#4a4a5a"))
    cv.rect(8, 7, 17, 11, hexc("#1f3550"))
    cv.rect(9, 8, 8, 1, hexc("#5dff9e")); cv.rect(9, 10, 12, 1, hexc("#5dff9e"))
    cv.rect(9, 12, 6, 1, hexc("#5dff9e")); cv.rect(9, 14, 10, 1, hexc("#3ff0ff"))
    cv.poly([(4, 21), (28, 21), (31, 27), (1, 27)], OUT)
    cv.poly([(5, 22), (27, 22), (29, 26), (3, 26)], hexc("#8a8a9a"))
    for y in (23, 24):
        for x in range(7, 26, 2):
            cv.px(x, y, hexc("#4a4a5a"))
    cv.rect(13, 25, 6, 1, hexc("#5a5a6a"))
    cv.px(24, 18, hexc("#e85d5d"))  # подряпина/наліпка
    cv.rect(20, 16, 4, 2, hexc("#ffb347"))
    return cv


def it_camera():
    cv = item_canvas()
    cv.orect(10, 7, 9, 5, hexc("#3a3a48"))
    cv.orect(3, 10, 26, 16, hexc("#2b2b3a"))
    cv.rect(4, 11, 24, 3, hexc("#a8865a"))
    cv.oellipse(10, 12, 13, 13, hexc("#55556a"))
    cv.oellipse(12, 14, 9, 9, hexc("#1a2440"))
    cv.ellipse(14, 16, 5, 5, hexc("#3f6fd1"))
    cv.px(15, 16, hexc("#ffffff")); cv.px(16, 17, hexc("#c9c3ff"))
    cv.orect(23, 15, 4, 3, hexc("#fff2c0"))
    cv.rect(5, 8, 4, 2, hexc("#ff3f6e"))
    return cv


def it_console():
    cv = item_canvas()
    cv.oellipse(2, 9, 12, 16, hexc("#3d3f5c"))
    cv.oellipse(18, 9, 12, 16, hexc("#3d3f5c"))
    cv.orect(8, 9, 16, 11, hexc("#3d3f5c"))
    cv.rect(9, 10, 14, 9, hexc("#3d3f5c"))
    cv.rect(6, 13, 6, 2, hexc("#c9c3ff")); cv.rect(8, 11, 2, 6, hexc("#c9c3ff"))
    cv.ellipse(22, 11, 3, 3, hexc("#ff3fa4")); cv.ellipse(25, 14, 3, 3, hexc("#3ff0ff"))
    cv.ellipse(19, 14, 3, 3, hexc("#5dff9e")); cv.ellipse(22, 17, 3, 3, hexc("#ffb347"))
    cv.rect(14, 12, 4, 1, hexc("#8f6bff"))
    cv.oellipse(10, 18, 5, 5, hexc("#22223a")); cv.oellipse(17, 18, 5, 5, hexc("#22223a"))
    return cv


def it_watch():
    cv = item_canvas()
    cv.orect(12, 1, 8, 9, hexc("#8a5634"))
    cv.orect(12, 22, 8, 9, hexc("#8a5634"))
    cv.oellipse(7, 7, 18, 18, hexc("#e8b84a"))
    cv.oellipse(9, 9, 14, 14, hexc("#fff4d6"))
    cv.rect(16, 11, 1, 6, OUT); cv.rect(16, 16, 4, 1, OUT)
    for a in range(12):
        ang = a / 12 * 2 * math.pi
        cv.px(int(16 + 6 * math.cos(ang)), int(16 + 6 * math.sin(ang)), hexc("#a8865a"))
    cv.rect(25, 15, 2, 3, hexc("#e8b84a"))
    cv.px(11, 10, hexc("#ffffff"))
    return cv


def it_headphones():
    cv = item_canvas()
    cv.d.arc([5, 3, 27, 27], 180, 360, fill=OUT, width=4)
    cv.d.arc([6, 4, 26, 26], 180, 360, fill=hexc("#ff3fa4"), width=2)
    cv.orect(3, 15, 8, 12, hexc("#2b2b3a"))
    cv.orect(21, 15, 8, 12, hexc("#2b2b3a"))
    cv.rect(5, 17, 4, 8, hexc("#3ff0ff"))
    cv.rect(23, 17, 4, 8, hexc("#3ff0ff"))
    cv.rect(6, 18, 1, 3, hexc("#c8ffff")); cv.rect(24, 18, 1, 3, hexc("#c8ffff"))
    return cv


def it_radio():
    cv = item_canvas()
    cv.line(22, 2, 26, 10, OUT, 1)
    cv.px(22, 2, hexc("#ffd36b"))
    cv.orect(2, 10, 28, 18, hexc("#a8653a"))
    cv.rect(3, 11, 26, 2, hexc("#c98b52"))
    cv.oellipse(5, 14, 12, 12, hexc("#3b2216"))
    for y in range(16, 25, 2):
        for x in range(7, 16, 2):
            cv.px(x, y, hexc("#c98b52"))
    cv.orect(19, 14, 9, 5, hexc("#fff2c0"))
    cv.rect(21, 15, 1, 3, hexc("#e85d5d"))
    cv.oellipse(19, 21, 4, 4, hexc("#d8cfa8")); cv.oellipse(24, 21, 4, 4, hexc("#d8cfa8"))
    cv.rect(4, 28, 3, 2, OUT); cv.rect(25, 28, 3, 2, OUT)
    return cv


def it_drone():
    cv = item_canvas()
    for (x, y) in [(3, 6), (21, 6), (3, 20), (21, 20)]:
        cv.rect(x, y + 2, 8, 1, OUT)
        cv.rect(x + 1, y + 1, 6, 1, hexc("#c9c3ff", 180))
    cv.line(7, 9, 13, 14, OUT, 2); cv.line(25, 9, 19, 14, OUT, 2)
    cv.line(7, 23, 13, 18, OUT, 2); cv.line(25, 23, 19, 18, OUT, 2)
    for (x, y) in [(5, 8), (23, 8), (5, 22), (23, 22)]:
        cv.orect(x, y, 4, 3, hexc("#55556a"))
    cv.oellipse(10, 11, 12, 10, hexc("#e8e8f0"))
    cv.rect(13, 14, 6, 3, hexc("#1a2440"))
    cv.px(15, 15, hexc("#3ff0ff")); cv.px(16, 15, hexc("#3ff0ff"))
    cv.px(12, 12, hexc("#e85d5d")); cv.px(19, 12, hexc("#5dff9e"))
    return cv


def it_cpu():
    cv = item_canvas()
    for i in range(8):
        cv.rect(8 + i * 2, 3, 1, 4, hexc("#e8b84a")); cv.rect(8 + i * 2, 25, 1, 4, hexc("#e8b84a"))
        cv.rect(3, 8 + i * 2, 4, 1, hexc("#e8b84a")); cv.rect(25, 8 + i * 2, 4, 1, hexc("#e8b84a"))
    cv.orect(6, 6, 20, 20, hexc("#2f6f4a"))
    cv.orect(10, 10, 12, 12, hexc("#8f6bff"))
    cv.rect(12, 12, 8, 8, hexc("#b8a3ff"))
    cv.rect(13, 13, 3, 3, hexc("#e8e2ff"))
    cv.px(8, 8, hexc("#e8b84a"))
    for i in range(3):
        cv.rect(12 + i * 3, 18, 2, 1, hexc("#5a3fc0"))
    return cv


def it_player():
    cv = item_canvas()
    cv.orect(9, 2, 15, 27, hexc("#e8e8f0"))
    cv.rect(11, 4, 11, 9, hexc("#2b2b3a"))
    cv.rect(12, 5, 9, 7, hexc("#5dff9e"))
    cv.rect(13, 7, 5, 1, hexc("#1f5a3a")); cv.rect(13, 9, 7, 1, hexc("#1f5a3a"))
    cv.oellipse(10, 15, 13, 13, hexc("#c9c3d8"))
    cv.oellipse(14, 19, 5, 5, hexc("#e8e8f0"))
    cv.px(16, 16, OUT); cv.px(16, 26, OUT); cv.px(11, 21, OUT); cv.px(21, 21, OUT)
    cv.line(23, 4, 28, 1, hexc("#ff3fa4"), 1)
    return cv


def it_arm():
    cv = item_canvas()
    cv.orect(2, 22, 10, 8, hexc("#55556a"))
    cv.line(7, 23, 13, 12, OUT, 5)
    cv.line(7, 23, 13, 12, hexc("#ffb347"), 3)
    cv.oellipse(10, 9, 7, 7, hexc("#3b3550"))
    cv.line(13, 12, 23, 9, OUT, 5)
    cv.line(13, 12, 23, 9, hexc("#ffb347"), 3)
    cv.oellipse(21, 6, 6, 6, hexc("#3b3550"))
    cv.line(25, 7, 29, 3, OUT, 2); cv.line(25, 10, 29, 13, OUT, 2)
    cv.px(28, 4, hexc("#9bb3c9")); cv.px(28, 12, hexc("#9bb3c9"))
    cv.px(12, 11, hexc("#3ff0ff")); cv.px(23, 8, hexc("#3ff0ff"))
    cv.rect(4, 25, 6, 1, hexc("#ff3f6e"))
    return cv


def it_coin():
    cv = item_canvas()
    cv.oellipse(5, 5, 22, 22, hexc("#b8862e"))
    cv.oellipse(7, 7, 18, 18, hexc("#d9a843"))
    cv.d.arc([9, 9, 22, 22], 0, 360, fill=hexc("#b8862e"))
    # профіль-символ (стилізований тризуб-корона, оригінальний знак)
    cv.rect(15, 11, 2, 10, hexc("#8a5a1a"))
    cv.rect(11, 13, 2, 6, hexc("#8a5a1a")); cv.rect(19, 13, 2, 6, hexc("#8a5a1a"))
    cv.rect(11, 19, 10, 2, hexc("#8a5a1a"))
    cv.px(9, 9, hexc("#fff4d6")); cv.px(10, 8, hexc("#fff4d6"))
    for a in range(20):
        ang = a / 20 * 2 * math.pi
        cv.px(int(16 + 10 * math.cos(ang)), int(16 + 10 * math.sin(ang)), hexc("#8a5a1a"))
    return cv


def it_mask():
    cv = item_canvas()
    cv.poly([(4, 8), (16, 4), (28, 8), (27, 20), (16, 29), (5, 20)], OUT)
    cv.poly([(6, 9), (16, 6), (26, 9), (25, 19), (16, 27), (7, 19)], hexc("#2b2b3a"))
    cv.poly([(7, 10), (16, 7), (25, 10), (24, 13), (8, 13)], hexc("#3b3550"))
    cv.rect(8, 13, 6, 3, hexc("#ff3fa4")); cv.rect(18, 13, 6, 3, hexc("#ff3fa4"))
    cv.rect(9, 14, 4, 1, hexc("#ffd6ee")); cv.rect(19, 14, 4, 1, hexc("#ffd6ee"))
    for x in range(11, 22, 2):
        cv.rect(x, 21, 1, 3, hexc("#3ff0ff"))
    cv.line(16, 7, 16, 11, hexc("#8f6bff"))
    return cv


def it_projector():
    cv = item_canvas()
    cv.poly([(20, 14), (31, 6), (31, 26)], hexc("#fff2c0", 90))
    cv.orect(2, 11, 20, 13, hexc("#d8cfe8"))
    cv.rect(3, 12, 18, 2, hexc("#ffffff"))
    cv.oellipse(14, 13, 9, 9, hexc("#3b3550"))
    cv.oellipse(16, 15, 5, 5, hexc("#9ee6ff"))
    cv.rect(5, 16, 6, 1, hexc("#8a8a9a")); cv.rect(5, 18, 6, 1, hexc("#8a8a9a"))
    cv.px(5, 21, hexc("#5dff9e"))
    cv.rect(4, 24, 3, 2, OUT); cv.rect(17, 24, 3, 2, OUT)
    return cv


def it_mystery():
    cv = item_canvas()
    cv.poly([(16, 2), (29, 9), (29, 23), (16, 30), (3, 23), (3, 9)], OUT)
    cv.poly([(16, 4), (27, 10), (27, 22), (16, 28), (5, 22), (5, 10)], hexc("#2a1c40"))
    cv.poly([(16, 4), (27, 10), (16, 16), (5, 10)], hexc("#3b2a5c"))
    cv.oellipse(11, 11, 10, 10, hexc("#8f6bff"))
    cv.ellipse(13, 13, 6, 6, hexc("#c8b8ff"))
    cv.px(15, 14, hexc("#ffffff"))
    for (x, y) in [(8, 20), (10, 22), (22, 20), (20, 22), (16, 25)]:
        cv.px(x, y, hexc("#5dff9e"))
    cv.line(7, 12, 9, 17, hexc("#ff3fa4")); cv.line(25, 12, 23, 17, hexc("#ff3fa4"))
    return cv


ITEMS = {
    "phone": it_phone, "laptop": it_laptop, "camera": it_camera, "console": it_console,
    "watch": it_watch, "headphones": it_headphones, "radio": it_radio, "drone": it_drone,
    "cpu": it_cpu, "player": it_player, "arm": it_arm, "coin": it_coin, "mask": it_mask,
    "projector": it_projector, "mystery": it_mystery,
}


# ---------------------------------------------------------------- UI icons
def coin_icon():
    cv = Canvas(10, 10)
    cv.oellipse(0, 0, 10, 10, hexc("#ffb347"))
    cv.rect(4, 2, 2, 6, hexc("#a8653a"))
    cv.rect(3, 3, 4, 1, hexc("#a8653a")); cv.rect(3, 6, 4, 1, hexc("#a8653a"))
    cv.px(2, 2, hexc("#fff2c0"))
    return cv


def heart_icon(full=True):
    cv = Canvas(9, 8)
    pat = [".XX.XX...", "XXXXXXX..", "XXXXXXX..", ".XXXXX...", "..XXX....", "...X....."]
    c = hexc("#ff3f6e") if full else hexc("#3b2a4a")
    for y, row in enumerate(pat):
        for x, v in enumerate(row):
            if v == "X":
                cv.px(x + 1, y + 1, c)
    cv.outline_alpha()
    if full:
        cv.px(2, 2, hexc("#ffd6e0"))
    return cv


def gear_icon():
    cv = Canvas(12, 12)
    for a in range(8):
        ang = a / 8 * 2 * math.pi
        x = int(round(6 + 4.5 * math.cos(ang))) - 1
        y = int(round(6 + 4.5 * math.sin(ang))) - 1
        cv.rect(x, y, 2, 2, hexc("#c9c3ff"))
    cv.ellipse(2, 2, 8, 8, hexc("#c9c3ff"))
    cv.ellipse(4, 4, 4, 4, hexc("#2a1c40"))
    return cv


def tab_icon(kind):
    cv = Canvas(12, 12)
    if kind == "shop":
        cv.poly([(1, 5), (6, 1), (11, 5)], hexc("#ff3fa4"))
        cv.rect(2, 5, 8, 6, hexc("#ffb347"))
        cv.rect(5, 7, 2, 4, hexc("#2a1c40"))
    elif kind == "bag":
        cv.rect(2, 4, 8, 7, hexc("#ffb347"))
        cv.d.arc([3, 0, 8, 7], 180, 360, fill=hexc("#ffb347"))
        cv.rect(3, 6, 6, 1, hexc("#a8653a"))
    elif kind == "up":
        cv.poly([(6, 1), (11, 6), (8, 6), (8, 11), (4, 11), (4, 6), (1, 6)], hexc("#5dff9e"))
    elif kind == "stats":
        cv.rect(1, 7, 2, 4, hexc("#3ff0ff")); cv.rect(5, 4, 2, 7, hexc("#3ff0ff")); cv.rect(9, 1, 2, 10, hexc("#3ff0ff"))
    cv.outline_alpha()
    return cv


def app_icon(size):
    s = 48
    cv = Canvas(s, s, hexc("#1d1430"))
    for y in range(s):
        cv.rect(0, y, s, 1, (29 + y, 20, 48 + y // 2, 255))
    # вітрина
    cv.rect(6, 30, 36, 14, hexc("#6b3f24"))
    cv.rect(6, 28, 36, 3, hexc("#9a6338"))
    cv.rect(6, 33, 36, 1, hexc("#3ff0ff"))
    # монета
    cv.oellipse(15, 8, 18, 18, hexc("#ffb347"))
    cv.oellipse(17, 10, 14, 14, hexc("#ffd36b"))
    cv.rect(23, 12, 2, 10, hexc("#a8653a")); cv.rect(20, 14, 8, 2, hexc("#a8653a")); cv.rect(20, 18, 8, 2, hexc("#a8653a"))
    text35(cv, 8, 37, "LAST", hexc("#ff7cc4"))
    text35(cv, 26, 37, "DEAL", hexc("#7ff8ff"))
    return cv.img.resize((size, size), Image.NEAREST)


def main():
    background().save(os.path.join(ART, "shop_bg.png"))
    neon_sign().save(os.path.join(ART, "neon_sign.png"))
    open_sign().save(os.path.join(ART, "open_sign.png"))
    counter().save(os.path.join(ART, "counter.png"))
    for i in range(12):
        customer(i).save(os.path.join(ART, "customers", "customer_%02d.png" % i))
    for name, fn in ITEMS.items():
        fn().save(os.path.join(ART, "items", name + ".png"))
    coin_icon().save(os.path.join(ICONS, "coin.png"))
    heart_icon(True).save(os.path.join(ICONS, "heart_full.png"))
    heart_icon(False).save(os.path.join(ICONS, "heart_empty.png"))
    g = gear_icon().img
    g.resize((g.width * 4, g.height * 4), Image.NEAREST).save(os.path.join(ICONS, "gear.png"))
    for k in ("shop", "bag", "up", "stats"):
        t = tab_icon(k).img
        t.resize((t.width * 3, t.height * 3), Image.NEAREST).save(os.path.join(ICONS, "tab_%s.png" % k))
    app_icon(192).save(os.path.join(ROOT, "icon.png"))
    app_icon(432).save(os.path.join(ICONS, "icon_432.png"))
    bg = Image.new("RGBA", (432, 432), hexc("#1d1430"))
    bg.save(os.path.join(ICONS, "icon_bg_432.png"))
    fg = app_icon(288)
    fgc = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fgc.paste(fg, (72, 72))
    fgc.save(os.path.join(ICONS, "icon_fg_432.png"))
    print("art generated")


if __name__ == "__main__":
    main()
