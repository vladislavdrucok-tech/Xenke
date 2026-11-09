"""Shaft background, balls, crystals, effects, interface pieces, title logo and the app icon."""
import numpy as np
from PIL import ImageFont, ImageDraw
from kit import *
from stones import gem_shape, stone_field, shade_rock, STYLES, drop_shadow

S = 2
FONTS = '/home/user/Xenke/deep_bounce/assets/fonts/'


def shaft(seed=21, W=1080, H=1920):
    """Dark blue-green depth with soft, vertically drawn-out rock masses; tiles vertically."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)

    def stretched(beta, sy):
        # noise with features drawn out vertically (sy > 1), still tileable in y
        n = fft_noise(H // sy, W, beta, rng)
        im = Image.fromarray((n * 65535).astype(np.uint16))
        n2 = np.asarray(im.resize((W, H), Image.BICUBIC), dtype=np.float64) / 65535
        return n2
    big = fft_noise(H, W, 3.0, rng)
    cols = stretched(2.2, 3)
    ridged = 1 - np.abs(2 * stretched(1.9, 2) - 1)
    fine = fft_noise(H, W, 1.5, rng)
    hgt = big * 170 + cols * 90 + ridged ** 3 * 40 + fine * 6
    nrm = normals(blur(hgt, 1.5))
    L = np.array([-0.15, -0.9, 0.42]); L /= np.linalg.norm(L)
    dif = lambert(nrm, L)
    c_dark = rgb('#01100f')
    c_base = rgb('#06363f')
    c_lite = rgb('#1b6068')
    col = lerp(c_dark, c_base, np.clip(dif * 1.35, 0, 1))
    col = lerp(col, c_lite, np.clip((dif - 0.55) * 2.0, 0, 1) * 0.85)
    # cavities: darker hollows between the masses
    col = col * (0.78 + 0.32 * smoothstep(0.2, 0.7, big))[..., None]
    xn = (xx / W - 0.5) * 2
    col = col * (1.08 - 0.30 * xn ** 2)[..., None]
    col = kuwahara(col, 3)
    return to_img(col)


def ball(kind='normal', r=11):
    R = r * S
    size = int(2 * R + 10)
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    dx, dy = (xx - c) / R, (yy - c) / R
    d2 = dx * dx + dy * dy
    m = ellipse_mask(size, size, c, c, R, R)
    n = np.dstack([dx, dy, np.sqrt(np.clip(1 - d2, 0, 1))])
    dif = lambert(n)
    sp = spec(n, 30)
    if kind == 'heavy':
        base = rgb('#f2c98a')
        edge = rgb('#6b3a14')
    elif kind == 'electric':
        base = rgb('#f4f7e8')
        edge = rgb('#1c8f91')
    else:
        base = rgb('#fff0c8')
        edge = rgb('#9c7346')
    col = base * (0.62 + 0.45 * dif)[..., None]
    col = col + (sp * 0.6)[..., None]
    col = lerp(col, rgb('#d7b07a') if kind != 'electric' else rgb('#8fe6df'), np.clip(d2 - 0.55, 0, 1) * 0.9)
    if kind == 'heavy':
        band = smoothstep(0.16, 0.08, np.abs(dy * 0.9 - dx * 0.3)) * m
        col = lerp(col, rgb('#b8652a') * (0.5 + 0.7 * dif)[..., None], band)
    if kind == 'electric':
        # a little turquoise bolt
        bolt = poly_mask(size, size, [[(c - 2, c - 13), (c + 6, c - 13), (c + 1, c - 2), (c + 7, c - 2), (c - 6, c + 14), (c - 2, c + 2), (c - 8, c + 2)]])
        col = lerp(col, rgb('#18b8b4'), bolt * 0.95)
    ring = np.clip(m - ellipse_mask(size, size, c, c, R - 2.4, R - 2.4), 0, 1)
    col = lerp(col, edge, ring * 0.9)
    return to_img(col, m)


def glow(size=128, color='#fff3d6', power=1.8):
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
    a = np.clip(1 - d, 0, 1) ** power
    return to_img(np.zeros((size, size, 3)) + rgb(color), a)


def gem(w=40, h=56, seed=5):
    rng = np.random.default_rng(seed)
    rgb_, a_, _ = gem_shape(w, h, w / 2, h / 2, w * 0.8, h * 0.9, 0.0, rng)
    return to_img(rgb_, a_)


def sparkle(size=48):
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    dx, dy = np.abs(xx - c) / c, np.abs(yy - c) / c
    star = np.clip(1 - (dx * 7 + dy * 1.0), 0, 1) + np.clip(1 - (dy * 7 + dx * 1.0), 0, 1)
    core = np.clip(1 - np.sqrt(dx ** 2 + dy ** 2) * 2.5, 0, 1) ** 2
    a = np.clip(star * 0.9 + core, 0, 1)
    return to_img(np.zeros((size, size, 3)) + 1.0, a)


def dust(size=128, seed=6):
    rng = np.random.default_rng(seed)
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
    nz = fft_noise(size, size, 1.6, rng)
    a = np.clip(1 - d, 0, 1) ** 1.3 * (0.5 + 0.7 * nz)
    a = blur(a, 2.0)
    a = a / a.max() * 0.8
    col = lerp(rgb('#c48a52'), rgb('#e8c48e'), nz)
    return to_img(col, a)


def panel(w=160, h=160, radius=26, fill_top='#0d363a', fill_bot='#06191c', border='#279b9b', border_l='#8ff0e6', rivets=True, seed=7, bw=7):
    rng = np.random.default_rng(seed)
    ss = 4
    im = Image.new('L', (w * ss, h * ss), 0)
    ImageDraw.Draw(im).rounded_rectangle([1 * ss, 1 * ss, (w - 1) * ss, (h - 1) * ss], radius=radius * ss, fill=255)
    outer = np.asarray(im.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
    im2 = Image.new('L', (w * ss, h * ss), 0)
    ImageDraw.Draw(im2).rounded_rectangle([(1 + bw) * ss, (1 + bw) * ss, (w - 1 - bw) * ss, (h - 1 - bw) * ss], radius=max(2, radius - bw) * ss, fill=255)
    inner = np.asarray(im2.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    t = yy / h
    fill = lerp(rgb(fill_top), rgb(fill_bot), t)
    fill = fill * (0.9 + 0.2 * fft_noise(h, w, 1.8, rng))[..., None]
    ring = np.clip(outer - inner, 0, 1)
    dist_out = ndimage.distance_transform_edt(outer > 0.5)
    # metallic border: bright top edge, darker bottom
    bcol = lerp(rgb(border_l), rgb(border), np.clip(t * 1.6, 0, 1))
    bcol = lerp(bcol, rgb('#0a3a3c'), np.clip((dist_out - 2) / bw, 0, 1) * 0.55)
    col = lerp(fill, bcol, ring)
    # inner shadow under the border
    ish = np.clip(1 - ndimage.distance_transform_edt(inner > 0.5) / 6.0, 0, 1) * inner
    col = col * (1 - 0.35 * ish)[..., None]
    rgb_, a_ = col, outer
    if rivets:
        for (px, py) in [(radius * 0.62, radius * 0.62), (w - radius * 0.62, radius * 0.62), (radius * 0.62, h - radius * 0.62), (w - radius * 0.62, h - radius * 0.62)]:
            rr = 3.4
            rm = ellipse_mask(w, h, px, py, rr, rr)
            rn = np.dstack([(xx - px) / rr, (yy - py) / rr, np.ones_like(xx)])
            rn[..., 2] = np.sqrt(np.clip(1 - rn[..., 0] ** 2 - rn[..., 1] ** 2, 0.05, 1))
            rc_ = rgb('#9ff3ea') * (0.3 + 0.9 * lambert(rn))[..., None]
            rgb_, a_ = over(rgb_, a_, rc_, rm)
    return to_img(rgb_, a_)


def stone_button(w=200, h=96, seed=8, tone=1.0):
    """Warm stone plate for primary buttons (9-slice)."""
    rng = np.random.default_rng(seed)
    pad = 6
    poly = jitter_poly(rng, pad, pad, w - pad, h - pad, chamfer=(0.18, 0.26), wobble=0.03, steps=3)
    mk = poly_mask(w, h, [poly])
    style = dict(STYLES[0])
    style['bevel'] = 0.30
    style['scratch'] = 0.3
    hgt, base, idx, crease, dist, s_ = stone_field(w, h, mk, rng, style, cells=1.0)
    col = shade_rock(hgt * 0.7, base * tone * 1.05, crease, dist, mk, rng, style, kuw=1)
    return to_img(col, mk)


def logo(scale=1.0):
    """DEEP BOUNCE in cream with a dark outline and a turquoise brush stroke underneath."""
    font = ImageFont.truetype(FONTS + 'LuckiestGuy.ttf', int(112 * scale))
    W, H = int(560 * scale), int(300 * scale)
    ss = 2
    big = Image.new('RGBA', (W * ss, H * ss), (0, 0, 0, 0))
    fnt = ImageFont.truetype(FONTS + 'LuckiestGuy.ttf', int(112 * scale * ss))
    d = ImageDraw.Draw(big)
    lines = [('DEEP', (20 * scale, 6 * scale)), ('BOUNCE', (20 * scale, 112 * scale))]
    # brush stroke: tapered and slightly curved, with dry-brush streaks
    stroke = Image.new('L', (W * ss, H * ss), 0)
    sd = ImageDraw.Draw(stroke)
    rngb = np.random.default_rng(3)
    for i in range(70):
        t0 = rngb.uniform(0.0, 0.12)
        t1 = rngb.uniform(0.82, 1.0)
        off = rngb.normal(0, 1.0)
        pts = []
        for t in np.linspace(t0, t1, 30):
            x = (26 + 440 * t) * scale * ss
            thick = np.sin(np.pi * t) ** 0.7 * 9.0
            y = (246 - 26 * t + 10 * np.sin(np.pi * t) * 0.3 + off * thick * 0.55) * scale * ss
            pts.append((x, y))
        sd.line(pts, fill=int(rngb.uniform(170, 255)), width=int(2.2 * scale * ss))
    stroke = stroke.filter(ImageFilter.GaussianBlur(0.8 * ss))
    teal = Image.new('RGBA', big.size, (60, 205, 200, 255))
    big.paste(teal, (0, 0), stroke)
    for text, (x, y) in lines:
        for dx, dy in [(6, 8)]:
            d.text(((x + dx * scale) * ss, (y + dy * scale) * ss), text, font=fnt, fill=(20, 8, 4, 160), stroke_width=int(9 * scale * ss), stroke_fill=(20, 8, 4, 160))
        d.text((x * ss, y * ss), text, font=fnt, fill=(255, 240, 200, 255), stroke_width=int(7 * scale * ss), stroke_fill=(58, 26, 10, 255))
    # vertical gradient on the letters
    arr = np.asarray(big).astype(np.float64) / 255
    yy = np.linspace(0, 1, arr.shape[0])[:, None]
    letters = (arr[..., 0] > 0.85) & (arr[..., 3] > 0.9)
    shade = np.where(letters, 1.0 - 0.10 * ((yy * 3.3) % 1.0), 1.0)
    arr[..., :3] = arr[..., :3] * shade[..., None]
    out = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), 'RGBA').resize((W, H), Image.LANCZOS)
    return out


def icon_more_balls(size=128):
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    b = ball('normal', 12)
    for (x, y) in [(6, 58), (38, 36), (40, 66), (8, 22)]:
        canvas.alpha_composite(b, (x, y))
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle([96, 18, 110, 62], 5, fill=(255, 240, 200, 255), outline=(58, 26, 10, 255), width=3)
    d.rounded_rectangle([81, 33, 125, 47], 5, fill=(255, 240, 200, 255), outline=(58, 26, 10, 255), width=3)
    d.rectangle([99, 36, 107, 44], fill=(255, 240, 200, 255))
    return canvas


def icon_ball_kind(kind, size=128):
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    g = glow(120, '#7ff7ee' if kind == 'electric' else '#ffcf8a', 2.2)
    canvas.alpha_composite(g, (4, 4))
    b = ball(kind, 24).resize((92, 92), Image.LANCZOS)
    canvas.alpha_composite(b, (18, 18))
    if kind == 'heavy':
        d = ImageDraw.Draw(canvas)
        for i, y in enumerate([40, 60, 80]):
            d.line([(4, y), (14 + i * 2, y)], fill=(255, 210, 150, 220), width=5)
    return canvas


def lock_icon(size=64):
    im = Image.new('RGBA', (size * 4, size * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = 4
    d.arc([18 * s, 6 * s, 46 * s, 36 * s], 180, 360, fill=(255, 240, 200, 255), width=6 * s)
    d.line([(18 * s + 3 * s, 21 * s), (18 * s + 3 * s, 30 * s)], fill=(255, 240, 200, 255), width=6 * s)
    d.line([(46 * s - 3 * s, 21 * s), (46 * s - 3 * s, 30 * s)], fill=(255, 240, 200, 255), width=6 * s)
    d.rounded_rectangle([12 * s, 28 * s, 52 * s, 58 * s], 6 * s, fill=(255, 240, 200, 255), outline=(58, 26, 10, 255), width=3 * s)
    d.ellipse([29 * s, 37 * s, 35 * s, 43 * s], fill=(58, 26, 10, 255))
    d.rectangle([31 * s, 41 * s, 33 * s, 50 * s], fill=(58, 26, 10, 255))
    return im.resize((size, size), Image.LANCZOS)


def pause_glyph(size=64):
    im = Image.new('RGBA', (size * 4, size * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = 4
    for x in (18, 38):
        d.rounded_rectangle([x * s, 14 * s, (x + 9) * s, 50 * s], 3 * s, fill=(255, 240, 200, 255))
    return im.resize((size, size), Image.LANCZOS)


def speed_glyph(size=64):
    im = Image.new('RGBA', (size * 4, size * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = 4
    for x in (12, 32):
        d.polygon([(x * s, 16 * s), ((x + 20) * s, 32 * s), (x * s, 48 * s)], fill=(255, 240, 200, 255))
    return im.resize((size, size), Image.LANCZOS)
