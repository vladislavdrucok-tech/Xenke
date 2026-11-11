"""Ball finishes (6 looks x normal / heavy / electric), shop icons, chapter decor, stars and the video glyph.
Heavy and electric balls carry the same markers on every finish so the series stays readable:
heavy = dark iron band with copper edges and an orange rim; electric = a turquoise bolt with a dark outline
and a turquoise rim. Same light direction (upper left) as the rest of the art."""
import numpy as np
from PIL import Image, ImageDraw
from kit import *
from stones import gem_shape
import misc

S = 2


def _sphere(R, size):
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    dx, dy = (xx - c) / R, (yy - c) / R
    d2 = dx * dx + dy * dy
    m = ellipse_mask(size, size, c, c, R, R)
    n = np.dstack([dx, dy, np.sqrt(np.clip(1 - d2, 0, 1))])
    return c, xx, yy, dx, dy, d2, m, n


def _base(skin, R, size, rng):
    c, xx, yy, dx, dy, d2, m, n = _sphere(R, size)
    dif = lambert(n)
    sp = spec(n, 30)
    d = np.sqrt(np.clip(d2, 0, 1))
    alpha = m.copy()
    if skin == 'copper':
        base = rgb('#d9783a')
        col = base * (0.3 + 0.85 * dif)[..., None]
        col = lerp(col, rgb('#5a2410'), np.clip(d2 - 0.6, 0, 1) * 1.4)
        col = col + (spec(n, 18) * 1.1)[..., None] * rgb('#ffe2b8')
        # brushed bands of warmer copper
        band = 0.5 + 0.5 * np.sin((dy * 0.8 + dx * 0.3) * 9.0)
        col = lerp(col, col * rgb('#ffb070') * 1.2, band * 0.18 * m)
        # a spark glint
        for (sx, sy, sr) in [(-0.38, -0.42, 0.16), (0.32, 0.36, 0.08)]:
            g = np.clip(1 - np.sqrt((dx - sx) ** 2 * 9 + (dy - sy) ** 2 * 0.6) / sr, 0, 1) + np.clip(1 - np.sqrt((dx - sx) ** 2 * 0.6 + (dy - sy) ** 2 * 9) / sr, 0, 1)
            col = lerp(col, rgb('#fff6dc'), np.clip(g, 0, 1) * 0.9)
    elif skin == 'teal':
        base = rgb('#4ccfc2')
        col = base * (0.45 + 0.65 * dif)[..., None]
        # pearl iridescence: lilac and cream sheen sliding with the normal
        irid = 0.5 + 0.5 * np.sin(n[..., 0] * 3.2 + n[..., 1] * 2.1 + 0.6)
        col = lerp(col, lerp(rgb('#b9a8ff'), rgb('#fff3c8'), irid), np.clip(d2, 0, 1) * 0.45)
        col = col + (spec(n, 12) * 0.75)[..., None] + (sp * 0.6)[..., None]
        col = lerp(col, rgb('#0f5a56'), np.clip(d2 - 0.8, 0, 1) * 2.5)
    elif skin == 'amber':
        # translucent honey: dark rim, light passing through the bottom right, bubbles inside
        through = np.clip(1 - np.sqrt((dx - 0.25) ** 2 + (dy - 0.3) ** 2) / 0.95, 0, 1)
        col = lerp(rgb('#7a3a06'), rgb('#f0a028'), np.clip(0.25 + 0.8 * through, 0, 1))
        col = lerp(col, rgb('#ffe08a'), through ** 2.2 * 0.85)
        col = col * (0.75 + 0.35 * dif)[..., None]
        for _ in range(7):
            bx, by = rng.uniform(-0.55, 0.55, 2)
            br = rng.uniform(0.05, 0.11)
            bm = np.clip(1 - np.sqrt((dx - bx) ** 2 + (dy - by) ** 2) / br, 0, 1)
            col = lerp(col, rgb('#ffe9b0'), smoothstep(0.0, 0.5, bm) * 0.5)
            col = lerp(col, rgb('#9a5010'), smoothstep(0.6, 1.0, bm) * 0.35)
        col = col + (spec(n, 40) * 1.2)[..., None] + (spec(n, 8) * 0.18)[..., None] * rgb('#ffd890')
        alpha = m * (0.86 + 0.14 * np.clip(d2 * 1.4, 0, 1))
    elif skin == 'frost':
        # milky ice: a bright frosted core in a clear pale-blue shell
        core = np.clip(1 - d / 0.62, 0, 1)
        col = lerp(rgb('#8fc6e8'), rgb('#eaf7ff'), np.clip(0.3 + 0.7 * dif, 0, 1))
        col = lerp(col, rgb('#ffffff'), smoothstep(0.0, 0.7, core) * 0.75)
        frost = fft_noise(size, size, 1.2, rng)
        col = lerp(col, rgb('#ffffff'), smoothstep(0.62, 0.8, frost) * 0.35 * m)
        # facet lines like cracks in ice
        for _ in range(3):
            a0 = rng.uniform(0, np.pi)
            ln = np.abs(np.cos(a0) * dy - np.sin(a0) * dx - rng.uniform(-0.3, 0.3))
            col = lerp(col, rgb('#c8e8ff'), smoothstep(0.05, 0.0, ln) * (d < 0.85) * 0.6)
        col = lerp(col, rgb('#4a7fa6'), np.clip(d2 - 0.78, 0, 1) * 2.8)
        col = col + (spec(n, 36) * 1.1)[..., None]
        alpha = m * (0.9 + 0.1 * core)
    elif skin == 'obsidian':
        # dark glassy core, a light rim (fresnel) and turquoise cracks glowing from inside
        col = rgb('#121419') * (0.6 + 0.7 * dif)[..., None]
        rim = np.clip(d2 - 0.55, 0, 1) / 0.45
        col = lerp(col, rgb('#a9b6c6'), rim ** 1.6 * 0.75)
        cracks = np.zeros_like(d)
        for _ in range(4):
            px, py = rng.uniform(-0.4, 0.4, 2)
            a0 = rng.uniform(0, 2 * np.pi)
            for seg in range(4):
                a0 += rng.uniform(-0.9, 0.9)
                L = rng.uniform(0.18, 0.32)
                qx, qy = px + np.cos(a0) * L, py + np.sin(a0) * L
                # distance to segment
                vx, vy = qx - px, qy - py
                t = np.clip(((dx - px) * vx + (dy - py) * vy) / (vx * vx + vy * vy + 1e-9), 0, 1)
                dist = np.sqrt((dx - px - t * vx) ** 2 + (dy - py - t * vy) ** 2)
                cracks = np.maximum(cracks, smoothstep(0.06, 0.0, dist))
                px, py = qx, qy
        cracks *= (d < 0.92)
        col = lerp(col, rgb('#1a8a84'), blur(cracks, 1.6) * 0.8)
        col = lerp(col, rgb('#7ffff0'), cracks * 0.95)
        col = col + (spec(n, 50) * 1.2)[..., None]
    else:
        raise ValueError(skin)
    return col, alpha, (c, xx, yy, dx, dy, d2, m, n)


def _markers(kind, col, alpha, geo, R, size):
    c, xx, yy, dx, dy, d2, m, n = geo
    dif = lambert(n)
    if kind == 'heavy':
        band = smoothstep(0.2, 0.12, np.abs(dy * 0.9 - dx * 0.3)) * m
        edge = smoothstep(0.24, 0.2, np.abs(dy * 0.9 - dx * 0.3)) * m - band
        col = lerp(col, rgb('#3c2414') * (0.55 + 0.7 * dif)[..., None], band)
        col = lerp(col, rgb('#e08a3e') * (0.6 + 0.6 * dif)[..., None], np.clip(edge, 0, 1))
        ring = np.clip(m - ellipse_mask(size, size, c, c, R - 3.2, R - 3.2), 0, 1)
        col = lerp(col, rgb('#ff9a3a'), ring * 0.95)
        dark = np.clip(m - ellipse_mask(size, size, c, c, R - 1.0, R - 1.0), 0, 1)
        col = lerp(col, rgb('#4a1e06'), dark * 0.9)
        alpha = np.maximum(alpha, ring)
    elif kind == 'electric':
        k = R / 22.0
        pts = [(c - 2 * k, c - 13 * k), (c + 6 * k, c - 13 * k), (c + 1 * k, c - 2 * k), (c + 7 * k, c - 2 * k), (c - 6 * k, c + 14 * k), (c - 2 * k, c + 2 * k), (c - 8 * k, c + 2 * k)]
        bolt = poly_mask(size, size, [pts])
        outline = np.clip(blur(bolt, 1.4 * k) * 3.0, 0, 1)
        col = lerp(col, rgb('#062a2a'), outline * 0.9)
        col = lerp(col, rgb('#6ffaf0'), bolt)
        ring = np.clip(m - ellipse_mask(size, size, c, c, R - 3.0, R - 3.0), 0, 1)
        col = lerp(col, rgb('#4fe8de'), ring * 0.95)
        dark = np.clip(m - ellipse_mask(size, size, c, c, R - 1.0, R - 1.0), 0, 1)
        col = lerp(col, rgb('#06403e'), dark * 0.9)
        alpha = np.maximum(alpha, np.maximum(ring, bolt))
    return col, alpha


def ball(skin, kind, r=11, seed=0):
    if skin == 'classic':
        return misc.ball(kind, r)
    R = r * S
    size = int(2 * R + 10)
    rng = np.random.default_rng(seed + {'copper': 1, 'teal': 2, 'amber': 3, 'frost': 4, 'obsidian': 5}[skin] * 17)
    col, alpha, geo = _base(skin, R, size, rng)
    col, alpha = _markers(kind, col, alpha, geo, R, size)
    return to_img(col, alpha)


def icon(skin, W=300, H=192):
    """Shop card icon: a large normal ball with an electric and a heavy one of the same finish."""
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    big = ball(skin, 'normal', 40, seed=3)
    e = ball(skin, 'electric', 22, seed=3)
    h = ball(skin, 'heavy', 22, seed=3)
    canvas.alpha_composite(big, (W // 2 - big.width // 2, H // 2 - big.height // 2 - 4))
    canvas.alpha_composite(e, (W // 2 - big.width // 2 - e.width // 2 - 8, H - e.height - 2))
    canvas.alpha_composite(h, (W // 2 + big.width // 2 - h.width // 2 + 8, H - h.height - 2))
    return canvas


def star(on, size=96):
    s = 4
    im = Image.new('RGBA', (size * s, size * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size * s / 2
    pts = []
    for i in range(10):
        a = -np.pi / 2 + i * np.pi / 5
        rr = (0.47 if i % 2 == 0 else 0.2) * size * s
        pts.append((c + np.cos(a) * rr, c + np.sin(a) * rr * 0.98 + size * s * 0.03))
    d.polygon(pts, fill=(58, 26, 10, 255))
    inner = [(c + (x - c) * 0.8, c + (y - c) * 0.8 + 2 * s) for x, y in pts]
    if on:
        d.polygon(inner, fill=(255, 205, 80, 255))
        hl = [(c + (x - c) * 0.5 - 4 * s, c + (y - c) * 0.5 - 2 * s) for x, y in pts]
        d.polygon(hl, fill=(255, 238, 160, 255))
    else:
        d.polygon(inner, fill=(28, 70, 72, 255))
    return im.resize((size, size), Image.LANCZOS)


def video_glyph(size=64):
    s = 4
    im = Image.new('RGBA', (size * s, size * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([6 * s, 14 * s, 58 * s, 50 * s], 8 * s, fill=(255, 240, 200, 255), outline=(58, 26, 10, 255), width=3 * s)
    d.polygon([(26 * s, 22 * s), (42 * s, 32 * s), (26 * s, 42 * s)], fill=(30, 120, 118, 255))
    return im.resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------- chapter decor (along the walls)

def _rock_lump(W, H, rng, base, dark):
    m = poly_mask(W, H, [[(0, H * 0.15), (W * 0.55, H * 0.05), (W * 0.9, H * 0.3), (W * 0.75, H * 0.75), (W * 0.35, H * 0.95), (0, H * 0.85)]], blur=0.8)
    h = fft_noise(H, W, 1.8, rng) * 6 + ndimage_dist(m) * 0.35
    nrm = normals(blur(h, 1.2))
    col = rgb(base) * (0.35 + 0.8 * lambert(nrm))[..., None]
    col = lerp(col, rgb(dark), np.clip(0.4 - lambert(nrm), 0, 0.4))
    return col, m


def ndimage_dist(m):
    from scipy import ndimage
    return ndimage.distance_transform_edt(m > 0.5)


def decor(kind, i, seed):
    rng = np.random.default_rng(seed)
    W, H = 120, 170
    rgb_ = np.zeros((H, W, 3))
    a_ = np.zeros((H, W))
    if kind == 'crystal':
        pal = dict(light=rgb('#e8fffb'), mid=rgb('#5fe6dc'), dark=rgb('#178c92'), deep=rgb('#0a4f57'), line=rgb('#063a40'))
        rc, rm = _rock_lump(W, H, rng, '#3b5157', '#101c20')
        rgb_, a_ = over(rgb_, a_, rc, rm * 0.95)
        for j in range(3 + i):
            gw = rng.uniform(16, 26)
            gh = rng.uniform(44, 74)
            cx = rng.uniform(26, 84)
            cy = rng.uniform(50, 120)
            g, ga, _ = gem_shape(W, H, cx, cy, gw, gh, rng.uniform(-0.9, 0.5), rng, palette=pal)
            rgb_, a_ = over(rgb_, a_, g, ga)
    elif kind == 'water':
        rc, rm = _rock_lump(W, H, rng, '#2e4a4c', '#0c1a1c')
        rgb_, a_ = over(rgb_, a_, rc, rm * 0.9)
        # moss on the top and water running down
        moss = rm * smoothstep(0.35, 0.1, np.mgrid[0:H, 0:W][0] / H) * (0.5 + 0.5 * fft_noise(H, W, 1.4, rng))
        rgb_ = lerp(rgb_, rgb('#4c8a52'), moss * 0.8)
        for j in range(2 + i):
            x = rng.uniform(20, 90)
            yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
            wob = x + 3 * np.sin(yy / 13 + j)
            stream = smoothstep(3.5, 0.5, np.abs(xx - wob)) * smoothstep(20, 40, yy) * smoothstep(H, H - 30, yy)
            rgb_, a_ = over(rgb_, a_, np.zeros_like(rgb_) + rgb('#9fe8f0'), stream * 0.55)
            dy = rng.uniform(H * 0.6, H * 0.9)
            drop = ellipse_mask(W, H, x, dy, 4, 6)
            rgb_, a_ = over(rgb_, a_, np.zeros_like(rgb_) + rgb('#d8fbff'), drop * 0.8)
    elif kind == 'obsidian':
        rc, rm = _rock_lump(W, H, rng, '#2a2d36', '#08090c')
        rgb_, a_ = over(rgb_, a_, rc, rm * 0.95)
        for j in range(3 + i):
            cx = rng.uniform(20, 90)
            cy = rng.uniform(30, 140)
            L = rng.uniform(30, 60)
            ang = rng.uniform(-0.6, 0.6)
            ca, sa = np.cos(ang), np.sin(ang)
            w = rng.uniform(10, 18)
            pts = [(cx - sa * L, cy - ca * L), (cx + ca * w, cy + sa * w), (cx + sa * L * 0.4, cy + ca * L * 0.4), (cx - ca * w, cy - sa * w)]
            sm = poly_mask(W, H, [pts])
            half = poly_mask(W, H, [[pts[0], pts[1], pts[2]]])
            col = lerp(np.zeros_like(rgb_) + rgb('#0e1014'), np.zeros_like(rgb_) + rgb('#5a6475'), half)
            edge = np.clip(sm - np.clip(blur(sm, 1.0) * 1.6 - 0.5, 0, 1), 0, 1)
            col = lerp(col, rgb('#6ff8ec'), np.clip(edge * 1.6, 0, 1))
            rgb_, a_ = over(rgb_, a_, col, sm)
    elif kind == 'heart':
        rc, rm = _rock_lump(W, H, rng, '#4a2a22', '#120806')
        rgb_, a_ = over(rgb_, a_, rc, rm * 0.95)
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
        vein = np.zeros((H, W))
        px, py = rng.uniform(10, 40), rng.uniform(20, 60)
        for seg in range(5):
            qx, qy = px + rng.uniform(10, 30), py + rng.uniform(10, 30)
            vx, vy = qx - px, qy - py
            t = np.clip(((xx - px) * vx + (yy - py) * vy) / (vx * vx + vy * vy), 0, 1)
            dist = np.sqrt((xx - px - t * vx) ** 2 + (yy - py - t * vy) ** 2)
            vein = np.maximum(vein, smoothstep(3.0, 0.5, dist))
            px, py = qx, qy
        vein *= rm
        rgb_ = lerp(rgb_, rgb('#ff6a20'), blur(vein, 3.0) * 0.6)
        rgb_ = lerp(rgb_, rgb('#ffd27a'), vein)
        pal = dict(light=rgb('#fff0c0'), mid=rgb('#ff9a3a'), dark=rgb('#c0461a'), deep=rgb('#6a1a08'), line=rgb('#3a0a02'))
        g, ga, _ = gem_shape(W, H, rng.uniform(40, 80), rng.uniform(60, 110), 18, 46, rng.uniform(-0.6, 0.6), rng, palette=pal)
        rgb_, a_ = over(rgb_, a_, g, ga)
    return to_img(kuwahara(rgb_, 1), a_)


SKINS = ['classic', 'copper', 'teal', 'amber', 'frost', 'obsidian']
