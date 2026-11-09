#!/usr/bin/env python3
"""Draws every bitmap of Pocket Triples: the five tile symbols, the UI icons, the Android launcher
icons and the boot splash. Everything is drawn at 4x and scaled down for clean edges.
Run from the project folder: python3 tools/make_art.py"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")
FONT = os.path.join(ROOT, "assets", "fonts", "Nunito.ttf")
os.makedirs(ART, exist_ok=True)

# type: (fill, outline, light)
SYMBOL_COLORS = [
    ((255, 111, 89), (196, 64, 44), (255, 196, 182)),    # coral star
    ((67, 176, 92), (36, 116, 58), (176, 232, 186)),     # green leaf
    ((59, 139, 230), (32, 88, 170), (182, 214, 250)),    # blue wave
    ((255, 196, 30), (196, 128, 0), (255, 236, 160)),    # yellow lightning
    ((152, 99, 224), (98, 56, 168), (218, 196, 248)),    # purple diamond
]


def canvas(size=1024):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def finish(img, out_size, name):
    img = img.resize((out_size, out_size), Image.LANCZOS)
    img.save(os.path.join(ART, name))


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for k in range(n * 2):
        r = r_out if k % 2 == 0 else r_in
        a = math.radians(rot + k * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def outlined_polygon(d, pts, fill, outline, width):
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0], pts[1]], fill=outline, width=width, joint="curve")
    for p in pts:
        d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=outline)


def gloss(img, box, alpha=110):
    """Soft white highlight in the upper left of a symbol."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=(255, 255, 255, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(40))
    mask = img.split()[3]
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hl.paste(layer, (0, 0), mask)
    return Image.alpha_composite(img, hl)


def sym_star():
    fill, out, light = SYMBOL_COLORS[0]
    img = canvas()
    d = ImageDraw.Draw(img)
    pts = star_points(512, 545, 430, 195)
    # rounded star: thick outline with round joins, then fill inside again
    d.line(pts + [pts[0], pts[1]], fill=out, width=110, joint="curve")
    for p in pts:
        d.ellipse([p[0] - 55, p[1] - 55, p[0] + 55, p[1] + 55], fill=out)
    inner = star_points(512, 545, 400, 182)
    d.line(inner + [inner[0], inner[1]], fill=fill, width=60, joint="curve")
    for p in inner:
        d.ellipse([p[0] - 30, p[1] - 30, p[0] + 30, p[1] + 30], fill=fill)
    d.polygon(inner, fill=fill)
    img = gloss(img, [290, 300, 520, 420], 70)
    finish(img, 256, "sym_0.png")


def leaf_shape(cx, cy, length, width, angle):
    pts = []
    n = 80
    for k in range(n + 1):
        t = k / n
        x = (t - 0.5) * length
        y = math.sin(math.pi * t) ** 0.85 * width / 2
        pts.append((x, -y))
    for k in range(n, -1, -1):
        t = k / n
        x = (t - 0.5) * length
        y = math.sin(math.pi * t) ** 1.2 * width / 2
        pts.append((x, y))
    a = math.radians(angle)
    return [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]


def sym_leaf():
    fill, out, light = SYMBOL_COLORS[1]
    img = canvas()
    d = ImageDraw.Draw(img)
    # stem
    d.line([(250, 800), (330, 720)], fill=out, width=56)
    d.ellipse([222, 772, 278, 828], fill=out)
    pts = leaf_shape(540, 480, 780, 430, -45)
    outlined_polygon(d, pts, fill, out, 48)
    # veins
    a = math.radians(-45)
    def p(t, off=0.0):
        x = (t - 0.5) * 680
        return (540 + x * math.cos(a) - off * math.sin(a), 480 + x * math.sin(a) + off * math.cos(a))
    d.line([p(0.02), p(0.93)], fill=out, width=26)
    for t in (0.3, 0.5, 0.7):
        for side in (-1, 1):
            a0 = p(t)
            a1 = p(t + 0.13, side * 120 * math.sin(math.pi * t))
            d.line([a0, a1], fill=out, width=18)
    img = gloss(img, [330, 260, 540, 400], 60)
    finish(img, 256, "sym_1.png")


def sym_wave():
    fill, out, light = SYMBOL_COLORS[2]
    img = canvas()
    d = ImageDraw.Draw(img)

    def band(y0, amp, thick, x0=150, x1=874, phase=0.0):
        top, bot = [], []
        n = 120
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k / n
            y = y0 + amp * math.sin(phase + 2 * math.pi * 1.25 * k / n)
            top.append((x, y - thick / 2))
            bot.append((x, y + thick / 2))
        return top + bot[::-1]

    for y0, th in ((370, 150), (620, 150)):
        pts = band(y0, 80, th, phase=-0.6)
        outlined_polygon(d, pts, fill, out, 46)
    # light crest line along each band
    for y0 in (370, 620):
        crest = []
        for k in range(14, 52):
            x = 150 + 724 * k / 120
            crest.append((x, y0 - 28 + 80 * math.sin(-0.6 + 2 * math.pi * 1.25 * k / 120)))
        d.line(crest, fill=light + (255,), width=26, joint="curve")
        for q in (crest[0], crest[-1]):
            d.ellipse([q[0] - 13, q[1] - 13, q[0] + 13, q[1] + 13], fill=light + (255,))
    finish(img, 256, "sym_2.png")


def sym_bolt():
    fill, out, light = SYMBOL_COLORS[3]
    img = canvas()
    d = ImageDraw.Draw(img)
    pts = [(600, 110), (250, 560), (470, 560), (380, 920), (780, 420), (545, 420), (650, 110)]
    outlined_polygon(d, pts, fill, out, 56)
    img = gloss(img, [450, 200, 600, 400], 80)
    finish(img, 256, "sym_3.png")


def sym_diamond():
    fill, out, light = SYMBOL_COLORS[4]
    img = canvas()
    d = ImageDraw.Draw(img)
    top, right, bottom, left = (512, 110), (840, 512), (512, 914), (184, 512)
    outlined_polygon(d, [top, right, bottom, left], fill, out, 56)
    # facets
    c = (512, 470)
    d.polygon([top, c, left], fill=light)
    d.polygon([top, right, c], fill=(186, 146, 240))
    d.line([left, c, right], fill=out, width=20)
    d.line([top, c], fill=out, width=20)
    d.line([c, bottom], fill=out, width=14)
    d.line([top, right, bottom, left, top], fill=out, width=56, joint="curve")
    for p in (top, right, bottom, left):
        d.ellipse([p[0] - 28, p[1] - 28, p[0] + 28, p[1] + 28], fill=out)
    finish(img, 256, "sym_3.png" if False else "sym_4.png")


# ---------------------------------------------------------------- UI icons (white, tinted in Godot)
W = (255, 255, 255, 255)


def round_line(d, pts, w):
    d.line(pts, fill=W, width=w, joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=W)


def arc_arrow(d, cx, cy, r, a0, a1, w, head_at_end=True, head=150):
    # arc from a0 to a1 degrees (PIL: 0 = 3 o'clock, clockwise)
    d.arc([cx - r, cy - r, cx + r, cy + r], a0, a1, fill=W, width=w)
    s = math.radians(a0)
    d.ellipse([cx + r * math.cos(s) - w / 2 + w / 2 * math.cos(s) * 0 - 0, cy + r * math.sin(s) - w / 2,
               cx + r * math.cos(s) + w / 2, cy + r * math.sin(s) + w / 2], fill=W)
    e = math.radians(a1 if head_at_end else a0)
    ex, ey = cx + (r - w / 2 + w / 2) * math.cos(e), cy + (r) * math.sin(e)
    # tangent direction (clockwise)
    tx, ty = -math.sin(e), math.cos(e)
    if not head_at_end:
        tx, ty = -tx, -ty
    nx, ny = math.cos(e), math.sin(e)
    tip = (ex + tx * head * 0.9, ey + ty * head * 0.9)
    b1 = (ex + nx * head * 0.75, ey + ny * head * 0.75)
    b2 = (ex - nx * head * 0.75, ey - ny * head * 0.75)
    d.polygon([tip, b1, b2], fill=W)


def icon(name, draw_fn):
    img = canvas()
    d = ImageDraw.Draw(img)
    draw_fn(d)
    finish(img, 128, "ic_%s.png" % name)


def ic_pause(d):
    d.rounded_rectangle([290, 230, 440, 794], 60, fill=W)
    d.rounded_rectangle([584, 230, 734, 794], 60, fill=W)


def ic_play(d):
    pts = [(340, 210), (820, 512), (340, 814)]
    d.polygon(pts, fill=W)
    d.line(pts + [pts[0], pts[1]], fill=W, width=90, joint="curve")


def ic_gear(d):
    cx, cy = 512, 512
    teeth = 8
    pts = []
    for k in range(teeth * 4):
        a = math.radians(k * 360 / (teeth * 4) + 360 / (teeth * 8))
        r = 400 if (k % 4) in (0, 1) else 300
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=W)
    d.line(pts + [pts[0], pts[1]], fill=W, width=40, joint="curve")
    d.ellipse([cx - 135, cy - 135, cx + 135, cy + 135], fill=(0, 0, 0, 0))


def ic_undo(d):
    # arrow curving back to the left
    d.arc([250, 290, 800, 840], 200, 450, fill=W, width=120)
    d.polygon([(130, 470), (420, 300), (430, 640)], fill=W)


def ic_restart(d):
    cx, cy, r, w = 512, 530, 300, 115
    d.arc([cx - r, cy - r, cx + r, cy + r], -60, 225, fill=W, width=w)
    a = math.radians(225)
    p = (cx + (r - w / 2) * math.cos(a), cy + (r - w / 2) * math.sin(a))
    d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=W)
    a = math.radians(-60)
    ex, ey = cx + (r - w / 2) * math.cos(a), cy + (r - w / 2) * math.sin(a)
    tx, ty = -math.sin(a), math.cos(a)        # clockwise tangent
    nx, ny = math.cos(a), math.sin(a)
    head = 175
    d.polygon([(ex + nx * head, ey + ny * head), (ex - nx * head, ey - ny * head),
               (ex - tx * head * 1.05, ey - ty * head * 1.05)], fill=W)


def ic_next(d):
    round_line(d, [(220, 512), (760, 512)], 120)
    round_line(d, [(520, 260), (780, 512), (520, 764)], 120)


def ic_levels(d):
    for r in range(3):
        for c in range(3):
            x, y = 210 + c * 220, 210 + r * 220
            d.rounded_rectangle([x, y, x + 170, y + 170], 40, fill=W)


def ic_stats(d):
    for i, h in enumerate((300, 520, 420, 640)):
        x = 200 + i * 170
        d.rounded_rectangle([x, 820 - h, x + 120, 820], 40, fill=W)


def ic_lock(d):
    d.arc([320, 170, 704, 560], 180, 360, fill=W, width=90)
    d.rectangle([320 + 0, 360, 365, 470], fill=W)
    d.rectangle([659, 360, 704, 470], fill=W)
    d.rounded_rectangle([250, 440, 774, 860], 80, fill=W)
    d.ellipse([462, 560, 562, 660], fill=(0, 0, 0, 0))
    d.rectangle([492, 620, 532, 740], fill=(0, 0, 0, 0))


def ic_sound(d):
    d.polygon([(170, 400), (330, 400), (520, 230), (520, 794), (330, 624), (170, 624)], fill=W)
    d.arc([440, 330, 700, 694], -55, 55, fill=W, width=70)
    d.arc([440, 210, 860, 814], -55, 55, fill=W, width=70)


def ic_sound_off(d):
    d.polygon([(170, 400), (330, 400), (520, 230), (520, 794), (330, 624), (170, 624)], fill=W)
    round_line(d, [(630, 400), (850, 620)], 80)
    round_line(d, [(850, 400), (630, 620)], 80)


def ic_vibration(d):
    d.rounded_rectangle([352, 190, 672, 834], 60, outline=W, width=70)
    for side in (-1, 1):
        x0 = 512 + side * 260
        round_line(d, [(x0, 360), (x0 + side * 40, 430), (x0, 500), (x0 + side * 40, 570), (x0, 640)], 50)


def ic_home(d):
    d.polygon([(512, 170), (870, 500), (154, 500)], fill=W)
    d.rounded_rectangle([250, 450, 774, 850], 50, fill=W)
    d.rounded_rectangle([450, 620, 574, 850], 30, fill=(0, 0, 0, 0))


def ic_check(d):
    round_line(d, [(220, 540), (420, 740), (810, 300)], 130)


def ic_close(d):
    round_line(d, [(270, 270), (754, 754)], 120)
    round_line(d, [(754, 270), (270, 754)], 120)


def ic_lang(d):
    d.ellipse([170, 170, 854, 854], outline=W, width=70)
    d.ellipse([370, 170, 654, 854], outline=W, width=60)
    d.line([(170, 512), (854, 512)], fill=W, width=60)
    d.line([(230, 340), (794, 340)], fill=W, width=50)
    d.line([(230, 684), (794, 684)], fill=W, width=50)


def ic_star_small(d):
    pts = star_points(512, 540, 430, 190)
    d.polygon(pts, fill=W)
    d.line(pts + [pts[0], pts[1]], fill=W, width=60, joint="curve")


# ---------------------------------------------------------------- tiles for the launcher icon / splash
def tile_img(t, size, lift=False):
    """A tile as the game draws it, for the icon and the splash."""
    fill, out, light = SYMBOL_COLORS[t]
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(S * 0.2)
    tint = tuple(int(c * 0.22 + 255 * 0.78) for c in fill)
    edge = tuple(int(c * 0.75 + o * 0.25) for c, o in zip(fill, out))
    d.rounded_rectangle([0, int(S * 0.06), S - 1, S - 1], r, fill=edge + (255,))
    d.rounded_rectangle([0, 0, S - 1, int(S * 0.92)], r, fill=tint + (255,))
    sym = Image.open(os.path.join(ART, "sym_%d.png" % t)).convert("RGBA").resize((int(S * 0.7), int(S * 0.7)), Image.LANCZOS)
    img.alpha_composite(sym, (int(S * 0.15), int(S * 0.11)))
    return img.resize((size, size), Image.LANCZOS)


def shadowed(base, tile, pos, blur=10, alpha=80, off=(0, 10)):
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    m = tile.split()[3].point(lambda v: v * alpha // 255)
    sh.paste((70, 45, 25, 255), (pos[0] + off[0], pos[1] + off[1]), m)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(sh)
    base.alpha_composite(tile, pos)


CREAM = (248, 240, 225)
CREAM_DARK = (238, 224, 198)


def launcher_art(size):
    """Three tiles fanned above a little tray: the whole game in one picture.
    Kept inside the middle 60% so round and squircle launcher masks never clip it."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s = size / 432
    tray = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    td = ImageDraw.Draw(tray)
    td.rounded_rectangle([int(112 * s), int(272 * s), int(320 * s), int(318 * s)], int(20 * s), fill=(192, 140, 92, 255))
    td.rounded_rectangle([int(120 * s), int(278 * s), int(312 * s), int(306 * s)], int(14 * s), fill=(226, 190, 145, 255))
    img.alpha_composite(tray)
    tsz = int(104 * s)
    for t, ang, cx, cy in ((0, 14, 140, 210), (2, -14, 292, 210), (1, 0, 216, 182)):
        tile = tile_img(t, tsz).rotate(ang, resample=Image.BICUBIC, expand=True)
        pos = (int(cx * s - tile.width / 2), int(cy * s - tile.height / 2))
        shadowed(img, tile, pos, blur=int(6 * s) + 1, alpha=90, off=(0, int(8 * s)))
    return img


def make_icons():
    # adaptive background: warm cream with a soft vignette
    bg = Image.new("RGBA", (432, 432), CREAM + (255,))
    v = Image.new("L", (432, 432), 0)
    ImageDraw.Draw(v).ellipse([-120, -120, 552, 552], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(60))
    dark = Image.new("RGBA", (432, 432), CREAM_DARK + (255,))
    bg = Image.composite(bg, dark, v)
    bg.save(os.path.join(ART, "icon_bg.png"))
    fg = launcher_art(432)
    fg.save(os.path.join(ART, "icon_fg.png"))
    # legacy square icon (192) and a large preview
    for size, name in ((192, "icon.png"), (512, "icon_512.png")):
        full = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        mask = Image.new("L", (size * 4, size * 4), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], size * 4 // 5, fill=255)
        mask = mask.resize((size, size), Image.LANCZOS)
        b = bg.resize((size, size), Image.LANCZOS)
        art = launcher_art(int(size * 1.25)).crop((int(size * 0.125), int(size * 0.1), int(size * 0.125) + size, int(size * 0.1) + size))
        b.alpha_composite(art)
        full.paste(b, (0, 0), mask)
        full.save(os.path.join(ROOT if name == "icon.png" else ART, name))


def make_splash():
    w, h = 720, 720
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    art = launcher_art(640)
    img.alpha_composite(art, (40, -80))
    font = ImageFont.truetype(FONT, 96)
    try:
        font.set_variation_by_axes([900])
    except Exception:
        pass
    d = ImageDraw.Draw(img)
    text = "Pocket Triples"
    tw = d.textlength(text, font=font)
    d.text(((w - tw) / 2 + 3, 512 + 5), text, font=font, fill=(160, 120, 80, 90))
    d.text(((w - tw) / 2, 512), text, font=font, fill=(74, 52, 36, 255))
    img.save(os.path.join(ART, "splash.png"))


def make_paper():
    """Seamless faint paper grain for the background."""
    import random
    rnd = random.Random(7)
    n = 256
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(900):
        x, y = rnd.randrange(n), rnd.randrange(n)
        a = rnd.randrange(8, 22)
        r = rnd.choice((1, 1, 1, 2))
        col = (120, 90, 50, a) if rnd.random() < 0.6 else (255, 255, 255, a + 10)
        for dx in (-n, 0, n):
            for dy in (-n, 0, n):
                d.ellipse([x + dx - r, y + dy - r, x + dx + r, y + dy + r], fill=col)
    img.save(os.path.join(ART, "paper.png"))


if __name__ == "__main__":
    sym_star()
    sym_leaf()
    sym_wave()
    sym_bolt()
    sym_diamond()
    for name, fn in (("pause", ic_pause), ("play", ic_play), ("gear", ic_gear), ("undo", ic_undo),
                     ("restart", ic_restart), ("next", ic_next), ("levels", ic_levels), ("stats", ic_stats),
                     ("lock", ic_lock), ("sound", ic_sound), ("sound_off", ic_sound_off),
                     ("vibration", ic_vibration), ("home", ic_home), ("check", ic_check),
                     ("close", ic_close), ("lang", ic_lang), ("star", ic_star_small)):
        icon(name, fn)
    make_icons()
    logo = launcher_art(864)
    logo.crop(logo.getbbox()).save(os.path.join(ART, "logo.png"))
    make_splash()
    make_paper()
    print("art written to", ART)
