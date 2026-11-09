"""Painted rock: blocks (4 rock patterns x 4 shapes), three crack stages, crystal veins, wall stones, debris."""
import numpy as np
from kit import *

S = 2                    # art pixels per world unit
CELL = 92
GAP = 3
PAD = 14                 # room for the cast shadow around a block sprite

# warm stone palette from the reference
C_DEEP = rgb('#3c1608')
C_DARK = rgb('#6e3014')
C_MID = rgb('#b45c26')
C_RED = rgb('#9c4320')
C_SAND = rgb('#c97a3a')
C_LIGHT = rgb('#e8ab5e')
C_PALE = rgb('#f3bf7c')
C_GREY = rgb('#7c5446')
C_PURP = rgb('#6a3f3a')

STYLES = [
    # interior planes per cell, plane tilt, bevel fraction, grey patches, strata, speckle, sand mix, tone, scratches
    dict(seeds=6, tilt=0.9, bevel=0.15, grey=0.25, strata=0.0, speck=0.9, warm=0.0, tone=1.0, scratch=1.0),    # rusty chiselled
    dict(seeds=3, tilt=0.6, bevel=0.14, grey=0.10, strata=1.0, speck=0.6, warm=0.06, tone=1.02, scratch=0.4),  # layered sandstone
    dict(seeds=9, tilt=1.1, bevel=0.13, grey=0.75, strata=0.0, speck=1.6, warm=-0.1, tone=0.86, scratch=0.7),  # dark granite-like
    dict(seeds=4, tilt=0.5, bevel=0.22, grey=0.05, strata=0.0, speck=1.2, warm=0.22, tone=1.08, scratch=0.5),  # pale pitted boulder
]


def brush(h, w, rng, n=3, length=7.0):
    """Painterly streaks: noise smeared along a few random directions."""
    acc = np.zeros((h, w))
    for i in range(n):
        ang = rng.uniform(0, np.pi)
        base = rng.standard_normal((h, w))
        sm = ndimage.gaussian_filter(base, (0.8, length))
        sm = ndimage.rotate(sm, np.degrees(ang), reshape=False, mode='wrap', order=1)
        acc += sm / (sm.std() + 1e-9)
    acc /= n
    return np.clip(acc * 0.5 + 0.5, 0, 1)


def stone_field(w, h, mask, rng, style, cells=1.0, light_bias=1.0):
    """Height, albedo and facet ids for a rock surface under `mask` (w x h art pixels).
    The shape is the lower envelope of tangent planes of a rounded slab: flat chiselled faces that meet
    in ridges (continuous, no cracks), more and smaller faces along the edges."""
    inside = mask > 0.5
    dist = ndimage.distance_transform_edt(inside)
    m = min(w, h)
    bw = max(10.0, style['bevel'] * min(m, 2 * CELL * S * 0.6) * 1.6)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    t = np.clip(dist / bw, 0, 1)
    shoulder = 1.0 - (1.0 - t) ** 1.8
    cx, cy = w / 2, h / 2
    dome = np.clip(1.0 - (((xx - cx) / (w * 0.75)) ** 2 + ((yy - cy) / (h * 0.75)) ** 2), 0, 1)
    f = 40.0 * shoulder + 12.0 * dome
    f = blur(f, 1.0)
    gyf, gxf = np.gradient(f)
    # seeds: dense along the bevel, sparse inside
    edge_ids = np.argwhere((dist > 2) & (dist < bw * 1.1))
    in_ids = np.argwhere(dist >= bw * 1.1)
    ne = max(10, int(len(edge_ids) / 420 * style.get('edge_density', 1.0)))
    ni = max(2, int(style['seeds'] * cells * 0.45))
    seeds = []
    if len(edge_ids):
        seeds += [tuple(edge_ids[i]) for i in rng.choice(len(edge_ids), size=min(ne, len(edge_ids)), replace=False)]
    if len(in_ids):
        seeds += [tuple(in_ids[i]) for i in rng.choice(len(in_ids), size=min(ni, len(in_ids)), replace=False)]
    height = np.full((h, w), 1e9)
    idx = np.zeros((h, w), dtype=np.int32)
    tilt = style['tilt'] * 0.10
    for i, (sy, sx) in enumerate(seeds):
        z = f[sy, sx] + rng.uniform(0, 1.5)
        gx = gxf[sy, sx] + rng.uniform(-tilt, tilt)
        gy = gyf[sy, sx] + rng.uniform(-tilt, tilt)
        plane = z + gx * (xx - sx) + gy * (yy - sy)
        lower = plane < height
        idx = np.where(lower, i, idx)
        height = np.minimum(height, plane)
    height = np.minimum(height, f + 6.0)
    height = np.where(inside, height, 0.0)
    crease = np.zeros((h, w))
    grain = fft_noise(h, w, 1.3, rng) - 0.5
    undul = fft_noise(h, w, 2.4, rng) - 0.5
    height = height + grain * 1.3 + undul * 5.0 * shoulder
    if style['strata'] > 0:
        wav = fft_noise(h, w, 2.6, rng)
        bands = np.sin((yy / (h + 1)) * np.pi * rng.uniform(5, 8) * max(1.0, h / (CELL * S)) * 0.6 + wav * 6.0)
        steps = np.floor((bands + 1) * 1.5) / 3.0
        height += style['strata'] * (steps * 2.0) * shoulder
    n = len(seeds)
    # albedo: rusty orange; redder and greyer patches; painterly streaks
    n1 = fft_noise(h, w, 2.4, rng)
    n2 = fft_noise(h, w, 2.0, rng)
    n3 = fft_noise(h, w, 1.8, rng)
    br = brush(h, w, rng)
    base = lerp(C_MID, C_RED, smoothstep(0.3, 0.85, n1) * 0.8)
    base = lerp(base, C_SAND, np.clip(smoothstep(0.5, 0.9, n3) * 0.5 + style['warm'], 0, 1))
    gp = smoothstep(0.64, 0.88, n2) * style['grey']
    base = lerp(base, lerp(C_GREY, C_PURP, n1), gp)
    tint = rng.uniform(0.92, 1.07, max(n, 1))
    base = base * tint[idx][..., None]
    base = base * (0.84 + 0.30 * br)[..., None]
    if style['strata'] > 0:
        band = np.sin(yy / 11.0 + undul * 9 + n3 * 3) * 0.5 + 0.5
        base = lerp(base, C_RED * 0.8, band * 0.30 * style['strata'])
        thin = smoothstep(0.93, 0.99, np.sin(yy / 4.3 + undul * 14) * 0.5 + 0.5)
        base = lerp(base, C_PALE, thin * 0.35 * style['strata'])
    base = base * style['tone']
    # scratches: short light and dark strokes
    if style['scratch'] > 0:
        from PIL import ImageDraw
        sc = Image.new('L', (w, h), 0)
        sd = ImageDraw.Draw(sc)
        scd = Image.new('L', (w, h), 0)
        sdd = ImageDraw.Draw(scd)
        for i in range(int(w * h / 900 * style['scratch'])):
            x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
            ang = rng.uniform(0, np.pi)
            L = rng.uniform(4, 16)
            (sd if rng.random() < 0.55 else sdd).line([(x0, y0), (x0 + np.cos(ang) * L, y0 + np.sin(ang) * L)], fill=int(rng.uniform(90, 200)), width=1)
        lt = np.asarray(sc, dtype=np.float64) / 255 * shoulder
        dk = np.asarray(scd, dtype=np.float64) / 255 * shoulder
        base = lerp(base, C_PALE, lt * 0.45)
        base = base * (1 - dk * 0.35)[..., None]
    return height, base, idx, crease, dist, shoulder


def shade_rock(height, base, crease, dist, mask, rng, style, speck=1.0, kuw=3, rim=1.0):
    h, w = height.shape
    nrm = normals(height)
    dif = lambert(nrm)
    sp = spec(nrm, 8.0)
    shade = 0.16 + 1.18 * dif ** 1.2
    # warm bounce light on the faces turned down and right (light reflected by the stones below)
    fill = np.clip((nrm * np.array([0.35, 0.75, 0.55])).sum(axis=2), 0, 1)
    shade = shade + 0.30 * fill
    col = base * shade[..., None]
    lum = col.mean(axis=2, keepdims=True)
    col = lum + (col - lum) * 1.18
    # shadowed planes go towards a deep red-brown, not grey
    col = lerp(col, C_DEEP * 0.75, np.clip((0.42 - dif) * 1.1, 0, 0.55))
    col = lerp(col, C_PALE, np.clip(sp * 0.45 + np.clip(dif - 0.88, 0, 1) * 2.2, 0, 0.7))
    col *= (1 - 0.16 * crease)[..., None]
    # painted rim on edges that face the light, dark contour on the far side
    edge = np.exp(-dist / 2.6) * mask
    facing = np.clip(-(nrm[..., 0] * 0.7 + nrm[..., 1] * 0.9), 0, 1)
    col = lerp(col, C_PALE, np.clip(edge * facing * 1.5 * rim, 0, 0.75))
    col = lerp(col, C_DEEP * 0.5, np.clip(np.exp(-dist / 1.8) * (1 - facing * 0.8) * 0.9, 0, 0.9))
    # pits and chips
    hf = fft_noise(h, w, 0.7, rng)
    hf2 = fft_noise(h, w, 0.9, rng)
    pits = smoothstep(0.80 - 0.03 * speck * style['speck'], 0.88, hf) * 0.45
    col *= (1 - pits)[..., None]
    chips = smoothstep(0.80, 0.9, hf2) * 0.32 * style['speck']
    col = lerp(col, C_PALE, chips * dif)
    if kuw:
        col = kuwahara(col, kuw)
    yy = np.linspace(0, 1, h)[:, None]
    col *= (1.05 - 0.12 * yy)[..., None]
    return np.clip(col, 0, 1)


def drop_shadow(mask, ox=5, oy=7, s=4.0, a=0.6):
    sh = ndimage.shift(mask, (oy, ox), order=1, mode='constant')
    return np.clip(blur(sh, s) * a, 0, 1)


def block(wc, hc, variant, seed):
    """One stone block of wc x hc cells at art scale, with padding and cast shadow."""
    rng = np.random.default_rng(seed)
    W = int((wc * CELL - 2 * GAP) * S)
    H = int((hc * CELL - 2 * GAP) * S)
    w, h = W + 2 * PAD, H + 2 * PAD
    style = STYLES[variant]
    poly = jitter_poly(rng, PAD, PAD, PAD + W, PAD + H, chamfer=(0.06, 0.2), wobble=0.04, steps=1 + wc + hc)
    mask = poly_mask(w, h, [poly])
    height, base, idx, crease, dist, sh = stone_field(w, h, mask, rng, style, cells=wc * hc)
    col = shade_rock(height, base, crease, dist, mask, rng, style)
    shadow = drop_shadow(mask, 6, 9, 5.0, 0.78)
    outline = np.clip(ndimage.grey_dilation(mask, size=(4, 4)), 0, 1)
    r0, a0 = over(np.zeros_like(col) + rgb('#03100f'), shadow, np.zeros_like(col) + rgb('#2a0f05'), outline * 0.9)
    out_rgb, out_a = over(r0, a0, col, mask)
    return to_img(out_rgb, out_a), mask


def crack_overlay(wc, hc, stage, seed):
    """Crack lines for damage stage 1..3, clipped to the inner part of any block of that shape."""
    rng = np.random.default_rng(seed)
    W = int((wc * CELL - 2 * GAP) * S)
    H = int((hc * CELL - 2 * GAP) * S)
    w, h = W + 2 * PAD, H + 2 * PAD
    ss = 3
    from PIL import ImageDraw
    dark = Image.new('L', (w * ss, h * ss), 0)
    lite = Image.new('L', (w * ss, h * ss), 0)
    halo = Image.new('L', (w * ss, h * ss), 0)
    dd, dl, dh = ImageDraw.Draw(dark), ImageDraw.Draw(lite), ImageDraw.Draw(halo)
    area = wc * hc
    count = {1: 2, 2: 3, 3: 5}[stage] + (area - 1) * {1: 1, 2: 1, 3: 2}[stage]
    length = {1: 0.32, 2: 0.55, 3: 0.8}[stage]
    width = {1: 3.2, 2: 4.4, 3: 5.6}[stage]
    m = min(W, H)

    def walk(x, y, ang, L, wd, depth):
        pts = [(x, y)]
        travelled = 0.0
        while travelled < L:
            seg = rng.uniform(14, 30)
            ang += rng.normal(0, 0.45)
            x += np.cos(ang) * seg
            y += np.sin(ang) * seg
            travelled += seg
            pts.append((x, y))
            if depth < 1 and rng.random() < 0.06 * stage:
                walk(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.7, 1.3), L * rng.uniform(0.25, 0.45), wd * 0.6, depth + 1)
        for i in range(len(pts) - 1):
            t = i / max(1, len(pts) - 1)
            ww = max(1.0, wd * (1 - 0.65 * t))
            a = [(pts[i][0] * ss, pts[i][1] * ss), (pts[i + 1][0] * ss, pts[i + 1][1] * ss)]
            b = [((pts[i][0] + 1.8) * ss, (pts[i][1] + 1.8) * ss), ((pts[i + 1][0] + 1.8) * ss, (pts[i + 1][1] + 1.8) * ss)]
            dh.line(a, fill=150, width=int((ww + 6) * ss))
            dl.line(b, fill=210, width=int(max(1, ww * 0.7) * ss))
            dd.line(a, fill=255, width=int(ww * ss))
            for p in (a[0], a[1]):
                r = ww * ss / 2
                dd.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)

    for i in range(count):
        side = rng.integers(0, 4)
        if side == 0:
            x, y, ang = PAD + rng.uniform(0.15, 0.85) * W, PAD + 4, np.pi / 2
        elif side == 1:
            x, y, ang = PAD + W - 4, PAD + rng.uniform(0.15, 0.85) * H, np.pi
        elif side == 2:
            x, y, ang = PAD + rng.uniform(0.15, 0.85) * W, PAD + H - 4, -np.pi / 2
        else:
            x, y, ang = PAD + 4, PAD + rng.uniform(0.15, 0.85) * H, 0.0
        ang += rng.uniform(-0.5, 0.5)
        walk(x, y, ang, length * m * rng.uniform(0.8, 1.3), width, 0)
    D = np.asarray(dark.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
    Lt = np.asarray(lite.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
    Hh = blur(np.asarray(halo.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255, 2.0)
    # clip to the safe interior shared by all rock patterns of this shape
    clip = poly_mask(w, h, [[(PAD + 0.16 * m, PAD + 5), (PAD + W - 0.16 * m, PAD + 5), (PAD + W - 5, PAD + 0.16 * m),
                             (PAD + W - 5, PAD + H - 0.16 * m), (PAD + W - 0.16 * m, PAD + H - 5), (PAD + 0.16 * m, PAD + H - 5),
                             (PAD + 5, PAD + H - 0.16 * m), (PAD + 5, PAD + 0.16 * m)]], blur=1.5)
    a_rgb = np.zeros((h, w, 3))
    a_a = np.zeros((h, w))
    a_rgb, a_a = over(a_rgb, a_a, np.zeros((h, w, 3)) + C_DEEP * 0.5, Hh * 0.35 * clip)
    a_rgb, a_a = over(a_rgb, a_a, np.zeros((h, w, 3)) + C_PALE, Lt * 0.75 * clip)
    a_rgb, a_a = over(a_rgb, a_a, np.zeros((h, w, 3)) + rgb('#1e0b04'), D * 0.95 * clip)
    if stage == 3:
        # chipped corners: broken-off recesses
        for k in range(2 + area // 2):
            cx = PAD + rng.choice([0.12, 0.88]) * W + rng.uniform(-10, 10)
            cy = PAD + rng.choice([0.12, 0.88]) * H + rng.uniform(-10, 10)
            r = rng.uniform(0.07, 0.11) * m
            pts = [(cx + np.cos(t) * r * rng.uniform(0.6, 1.2), cy + np.sin(t) * r * rng.uniform(0.6, 1.2)) for t in np.linspace(0, 2 * np.pi, 7)[:-1]]
            pm = poly_mask(w, h, [pts]) * clip
            rim_ = np.clip(pm - ndimage.shift(pm, (2.5, 2.5), order=1), 0, 1)
            a_rgb, a_a = over(a_rgb, a_a, np.zeros((h, w, 3)) + rgb('#3a1808'), pm * 0.8)
            a_rgb, a_a = over(a_rgb, a_a, np.zeros((h, w, 3)) + C_PALE, rim_ * 0.6)
    return to_img(a_rgb, a_a)


def gem_shape(w, h, cx, cy, gw, gh, ang, rng, glow=True, palette=None):
    """A faceted turquoise crystal (elongated hexagonal bipyramid) rendered into float rgb/alpha layers."""
    pal = palette or dict(light=rgb('#d9fffa'), mid=rgb('#46dcd2'), dark=rgb('#11868e'), deep=rgb('#0a4f57'), line=rgb('#063a40'))
    ca, sa = np.cos(ang), np.sin(ang)

    def P(x, y):
        return (cx + x * ca - y * sa, cy + x * sa + y * ca)
    hw, hh = gw / 2, gh / 2
    top = P(0, -hh)
    bot = P(0, hh)
    l1 = P(-hw, -hh * 0.38)
    l2 = P(-hw, hh * 0.38)
    r1 = P(hw, -hh * 0.38)
    r2 = P(hw, hh * 0.38)
    m1 = P(-hw * 0.1, -hh * 0.42)
    m2 = P(-hw * 0.1, hh * 0.40)
    faces = [
        ([top, l1, m1], pal['light'] * 1.0),
        ([top, m1, r1], pal['mid'] * 1.08),
        ([l1, l2, m2, m1], pal['light'] * 0.92),
        ([m1, m2, r2, r1], pal['mid']),
        ([l2, bot, m2], pal['mid'] * 0.85),
        ([m2, bot, r2], pal['dark']),
    ]
    rgb_ = np.zeros((h, w, 3))
    a_ = np.zeros((h, w))
    outline = poly_mask(w, h, [[top, r1, r2, bot, l2, l1]])
    grown = np.clip(blur(outline, 0.9) * 2.2, 0, 1)
    rgb_, a_ = over(rgb_, a_, np.zeros((h, w, 3)) + pal['line'], grown)
    for pts, c in faces:
        fm = poly_mask(w, h, [pts])
        rgb_, a_ = over(rgb_, a_, np.zeros((h, w, 3)) + np.clip(c, 0, 1), fm * 0.98)
    # glints
    gl = poly_mask(w, h, [[P(-hw * 0.75, -hh * 0.30), P(-hw * 0.45, -hh * 0.62), P(-hw * 0.38, -hh * 0.5), P(-hw * 0.62, -hh * 0.18)]])
    rgb_, a_ = over(rgb_, a_, np.zeros((h, w, 3)) + 1.0, gl * 0.85)
    return rgb_, a_, outline


def vein_overlay(wc, hc, seed):
    """A cluster of crystals growing out of the rock: marks a stone that pays extra crystals."""
    rng = np.random.default_rng(seed)
    W = int((wc * CELL - 2 * GAP) * S)
    H = int((hc * CELL - 2 * GAP) * S)
    w, h = W + 2 * PAD, H + 2 * PAD
    rgb_ = np.zeros((h, w, 3))
    a_ = np.zeros((h, w))
    # socket: a dark hollow in the rock near the lower right
    cx = PAD + W * rng.uniform(0.66, 0.74)
    cy = PAD + H * rng.uniform(0.66, 0.74)
    hole = ellipse_mask(w, h, cx, cy + 6, 34, 20)
    rgb_, a_ = over(rgb_, a_, np.zeros((h, w, 3)) + rgb('#2a1006'), blur(hole, 2.0) * 0.85)
    glow = ellipse_mask(w, h, cx, cy, 40, 34)
    rgb_, a_ = over(rgb_, a_, np.zeros((h, w, 3)) + rgb('#5ff3e6'), blur(glow, 9.0) * 0.45)
    for i, (dx, dy, gw, gh, an) in enumerate([(-14, 4, 16, 38, -0.45), (12, 6, 14, 30, 0.5), (0, -2, 20, 50, 0.05), (-26, 12, 10, 20, -0.9), (24, 14, 10, 18, 0.95)]):
        r2, a2, _ = gem_shape(w, h, cx + dx, cy + dy - gh * 0.3, gw, gh, an, rng)
        rgb_, a_ = over(rgb_, a_, r2, a2)
    return to_img(rgb_, a_)


def debris(seed, size):
    rng = np.random.default_rng(seed)
    w = h = size + 10
    c = w / 2
    n = rng.integers(5, 8)
    pts = []
    for i in range(n):
        t = i / n * 2 * np.pi + rng.uniform(-0.25, 0.25)
        r = size / 2 * rng.uniform(0.55, 1.0)
        pts.append((c + np.cos(t) * r, c + np.sin(t) * r * rng.uniform(0.75, 1.0)))
    mask = poly_mask(w, h, [pts])
    style = dict(STYLES[rng.integers(0, 4)])
    style['seeds'] = 3
    height, base, idx, crease, dist, sh = stone_field(w, h, mask, rng, style, cells=1.0)
    col = shade_rock(height * 0.6, base, crease, dist, mask, rng, style, kuw=0)
    return to_img(col, mask)


def wall_strip(side, seed, width=220, height=1024):
    """Vertically tileable column of stacked stones. side 'L' stones end on the right edge (field side)."""
    rng = np.random.default_rng(seed)
    w, h = width, height
    rgb_ = np.zeros((h, w, 3)) + rgb('#1d0c05')
    a_ = np.ones((h, w))
    # back: dark mortar with a little texture
    mort = fft_noise(h, w, 1.4, rng)
    rgb_ = lerp(rgb('#140703'), rgb('#3a1a0a'), mort * 0.8)
    style_ids = [0, 1, 2, 3]
    y = 0.0
    stones = []
    while y < h:
        sh_ = rng.uniform(150, 260)
        if y + sh_ > h - 90:
            sh_ = h - y
        # mostly one big stone across; sometimes a small one tucked at the outer side
        if rng.random() < 0.3:
            split = rng.uniform(0.25, 0.4) * w
            if side == 'L':
                stones.append((0, y, split, y + sh_))
                stones.append((split, y, w, y + sh_))
            else:
                stones.append((0, y, w - split, y + sh_))
                stones.append((w - split, y, w, y + sh_))
        else:
            stones.append((0, y, w, y + sh_))
        y += sh_
    for (x0, y0, x1, y1) in stones:
        g = 5.0
        # field edge: irregular but never more than a few pixels past the line
        fx0, fx1 = x0 + g, x1 - g
        if side == 'L' and x1 >= w - 1:
            fx1 = w - rng.uniform(2, 14)
        if side == 'R' and x0 <= 0:
            fx0 = rng.uniform(2, 14)
        sw, shh = int(fx1 - fx0 + 24), int(y1 - y0 + 24)
        if sw < 20 or shh < 20:
            continue
        poly = jitter_poly(rng, 12, 12, 12 + fx1 - fx0, 12 + (y1 - y0) - 2 * g, chamfer=(0.12, 0.3), wobble=0.06, steps=3)
        mask = poly_mask(sw, shh, [poly])
        style = dict(STYLES[rng.choice(style_ids)])
        style['bevel'] = 0.22
        height_, base, idx, crease, dist, s_ = stone_field(sw, shh, mask, rng, style, cells=max(1.0, (y1 - y0) / 120))
        col = shade_rock(height_, base * 1.04, crease, dist, mask, rng, style, kuw=2)
        shadow = drop_shadow(mask, 4, 6, 3.0, 0.7)
        # paste with vertical wrap
        for oy in (0, -h, h):
            ty, tx = int(y0 + g + oy - 12), int(fx0 - 12)
            ys, xs = max(0, ty), max(0, tx)
            ye, xe = min(h, ty + shh), min(w, tx + sw)
            if ye <= ys or xe <= xs:
                continue
            sub = (slice(ys - ty, ye - ty), slice(xs - tx, xe - tx))
            dst = (slice(ys, ye), slice(xs, xe))
            r2, a2 = over(rgb_[dst], a_[dst], np.zeros_like(rgb_[dst]), shadow[sub])
            r2, a2 = over(r2, a2, col[sub], mask[sub])
            rgb_[dst], a_[dst] = r2, a2
    # field side darker towards the outer screen edge, slight ambient from the shaft
    xx = np.linspace(0, 1, w)[None, :]
    falloff = (0.62 + 0.40 * xx) if side == 'L' else (1.02 - 0.40 * xx)
    rgb_ *= falloff[..., None]
    return to_img(rgb_, a_)
