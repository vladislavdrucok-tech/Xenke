"""The cannon: pre-lit base (cradle + sphere), barrel as albedo + normal map (lit in a shader at any angle),
a round collar over the barrel root, and the stone arch it sits in. Four finishes."""
import numpy as np
from kit import *
from stones import stone_field, shade_rock, STYLES, drop_shadow, C_DEEP

S = 2

SKINS = {
    'classic': dict(paint='#279b9b', paint_l='#7fe3d6', paint_d='#0b4a4e', metal='#c8762e', metal_l='#f3c27a', metal_d='#5e2d10',
                    wear='#9a6a3a', glow='#ffd79a', rivet='#e6a35a', seam=None),
    'ember': dict(paint='#3b3d42', paint_l='#8d8f94', paint_d='#141518', metal='#6b4a35', metal_l='#c08a5c', metal_d='#22140c',
                  wear='#52463e', glow='#ff8a3a', rivet='#a8744a', seam='#ff7a22'),
    'brass': dict(paint='#c99a3c', paint_l='#ffe8a6', paint_d='#5c3d0e', metal='#1f7d84', metal_l='#7fe9e0', metal_d='#0a3236',
                  wear='#8b6a2a', glow='#fff0c0', rivet='#ffe2a0', seam=None),
    'crystal': dict(paint='#173d46', paint_l='#5aa9b0', paint_d='#06161a', metal='#8fa7ab', metal_l='#e9fbff', metal_d='#2a3a3e',
                    wear='#244e56', glow='#7ff7ee', rivet='#c9f4f4', seam='#59f0e4', crystals=True),
}


def sphere(skin, r_world=44, seed=1):
    k = SKINS[skin]
    rng = np.random.default_rng(seed)
    r = r_world * S
    size = int(2 * r + 8)
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    dx, dy = (xx - c) / r, (yy - c) / r
    d2 = dx * dx + dy * dy
    m = ellipse_mask(size, size, c, c, r, r)
    nz = np.sqrt(np.clip(1 - d2, 0, 1))
    n = np.dstack([dx, dy, nz])
    dif = lambert(n)
    sp = spec(n, 34)
    wear_n = fft_noise(size, size, 2.0, rng)
    wear = smoothstep(0.66, 0.78, wear_n)
    paint = lerp(rgb(k['paint']), rgb(k['wear']), wear * 0.85)
    # band around the sphere (tilted great circle) and rivets on it
    axis = np.array([0.30, -0.88, 0.37])
    axis /= np.linalg.norm(axis)
    dot = (n * axis).sum(axis=2)
    band = smoothstep(0.13, 0.09, np.abs(dot)) * m
    base = lerp(paint, rgb(k['metal']), band)
    col = base * (0.24 + 1.0 * dif)[..., None]
    col = lerp(col, rgb(k['paint_d']) * 0.6, np.clip(0.35 - dif, 0, 0.35))
    metalness = 0.5 + 0.5 * band
    col = col + (sp * (0.55 + 0.45 * band))[..., None] * rgb(k['metal_l'])
    # rim light from the shaft (cool) on the lower right edge
    rim = np.clip(d2 - 0.75, 0, 1) * 4 * np.clip(dx * 0.6 + dy * 0.8, 0, 1)
    col = lerp(col, rgb('#3a8c8c'), rim * 0.35 * m)
    # rivets along the band
    rgb_ = col
    a_ = m
    # find band points: parametrize great circle
    u = np.cross(axis, [0, 0, 1.0])
    u /= np.linalg.norm(u)
    v = np.cross(axis, u)
    for t in np.linspace(0, 2 * np.pi, 15)[:-1]:
        p = np.cos(t) * u + np.sin(t) * v
        if p[2] < 0.15:
            continue
        px, py = c + p[0] * r, c + p[1] * r
        rr = 3.2 * S * (0.6 + 0.4 * p[2])
        rm = ellipse_mask(size, size, px, py, rr, rr)
        rn = np.dstack([(xx - px) / rr, (yy - py) / rr, np.ones_like(xx)])
        rn[..., 2] = np.sqrt(np.clip(1 - rn[..., 0] ** 2 - rn[..., 1] ** 2, 0.05, 1))
        rd = lambert(rn)
        rc_ = rgb(k['rivet']) * (0.3 + 0.9 * rd)[..., None] + (spec(rn, 20) * 0.8)[..., None]
        rgb_, a_ = over(rgb_, a_, np.zeros_like(rgb_) + rgb(k['metal_d']) * 0.6, np.clip(blur(rm, 1.0) * 1.3, 0, 1) * 0.8)
        rgb_, a_ = over(rgb_, a_, rc_, rm)
    if k.get('seam'):
        sm = smoothstep(0.035, 0.0, np.abs(dot - 0.16)) * m
        rgb_ = lerp(rgb_, rgb(k['seam']), sm * 0.9)
    if k.get('crystals'):
        for (ox, oy, gw, gh, an) in [(-0.35, -0.42, 0.22, 0.42, -0.5), (0.05, -0.62, 0.18, 0.34, 0.15), (-0.62, -0.08, 0.16, 0.28, -1.0)]:
            from stones import gem_shape
            r2, a2, _ = gem_shape(size, size, c + ox * r, c + oy * r, gw * r, gh * r, an, rng)
            rgb_, a_ = over(rgb_, a_, r2, a2 * m)
    rgb_ = kuwahara(rgb_, 1)
    return rgb_, a_


def cradle(skin, seed=2):
    """Copper mount under the sphere: two cheeks, a cross bar and a foot plate with rivets."""
    k = SKINS[skin]
    rng = np.random.default_rng(seed)
    W, H = 200 * S // 2 * 1, 70 * S
    W = 130 * S
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    cx = W / 2
    rgb_ = np.zeros((H, W, 3))
    a_ = np.zeros(H * W).reshape(H, W)
    parts = [
        # (polygon in world units relative to the sphere centre at (0, 0); the canvas spans y 0..70 => world y -10..60)
        [(-54, 46), (54, 46), (58, 56), (-58, 56)],          # foot plate
        [(-50, 6), (-34, 6), (-28, 48), (-55, 48)],          # left cheek
        [(34, 6), (50, 6), (55, 48), (28, 48)],              # right cheek
        [(-34, 34), (34, 34), (30, 46), (-30, 46)],          # cross bar
    ]
    for pi, poly in enumerate(parts):
        pts = [(cx + x * S, (y + 10) * S) for x, y in poly]
        pm = poly_mask(W, H, [pts])
        dist = ndimage.distance_transform_edt(pm > 0.5)
        hgt = np.clip(dist / 7.0, 0, 1) ** 0.6 * 10 + fft_noise(H, W, 1.6, rng) * 1.5
        n = normals(hgt)
        dif = lambert(n)
        sp = spec(n, 24)
        base = rgb(k['metal']) * (0.85 + 0.25 * fft_noise(H, W, 2.2, rng))[..., None]
        col = base * (0.25 + 0.95 * dif)[..., None] + (sp * 0.6)[..., None] * rgb(k['metal_l'])
        col = lerp(col, rgb(k['metal_d']) * 0.5, np.exp(-dist / 1.4) * 0.8)
        sh = drop_shadow(pm, 3, 4, 2.5, 0.55)
        rgb_, a_ = over(rgb_, a_, np.zeros_like(rgb_), sh)
        rgb_, a_ = over(rgb_, a_, col, pm)
    for (x, y) in [(-48, 51), (-22, 51), (22, 51), (48, 51), (-42, 14), (42, 14), (-43, 38), (43, 38)]:
        px, py = cx + x * S, (y + 10) * S
        rr = 2.6 * S
        rm = ellipse_mask(W, H, px, py, rr, rr)
        rn = np.dstack([(xx - px) / rr, (yy - py) / rr, np.ones_like(xx)])
        rn[..., 2] = np.sqrt(np.clip(1 - rn[..., 0] ** 2 - rn[..., 1] ** 2, 0.05, 1))
        rc_ = rgb(k['rivet']) * (0.3 + 0.9 * lambert(rn))[..., None] + (spec(rn, 20) * 0.7)[..., None]
        rgb_, a_ = over(rgb_, a_, rc_, rm)
    return rgb_, a_


def base_sprite(skin):
    """Cradle + sphere composited; pivot (sphere centre) at (W/2, PIV_Y)."""
    sr, sa = sphere(skin)
    cr, ca = cradle(skin)
    W = cr.shape[1]
    ssz = sr.shape[0]
    H = int(ssz / 2 + 64 * S) + 4
    piv_y = ssz // 2 + 2
    rgb_ = np.zeros((H, W, 3))
    a_ = np.zeros((H, W))
    # cradle canvas starts at world y = -10 relative to the pivot
    oy = piv_y - 10 * S
    rgb_[oy:oy + cr.shape[0]], a_[oy:oy + cr.shape[0]] = over(rgb_[oy:oy + cr.shape[0]], a_[oy:oy + cr.shape[0]], cr, ca)
    ox = (W - ssz) // 2
    sh = drop_shadow(sa, 6, 9, 5, 0.6)
    region = (slice(piv_y - ssz // 2, piv_y - ssz // 2 + ssz), slice(ox, ox + ssz))
    r2, a2 = over(rgb_[region], a_[region], np.zeros_like(sr), sh)
    rgb_[region], a_[region] = over(r2, a2, sr, sa)
    return to_img(rgb_, a_), (W / 2, piv_y)


def barrel(skin, seed=3):
    """Barrel pointing +x from the hinge at the left-middle. Returns albedo (RGBA) and normal map (RGB + spec in A)."""
    k = SKINS[skin]
    rng = np.random.default_rng(seed)
    L = 76  # world (profile below is in these units, drawn 1.12x larger)
    K = 1.12
    W = int((L + 4) * S * K)
    H = int(2 * 21 * S * K)
    cy = H / 2
    xs = np.arange(W) / (S * K)  # profile x along the barrel

    def radius(x):
        r = 14.0 - 0.025 * x
        if 17 <= x <= 23 or 39 <= x <= 45:
            r = 16.0
        if 54 <= x < 68:
            r = 14.5 + (x - 54) / 14 * 2.5
        if 68 <= x <= 75:
            r = 18.5
        if x > 75:
            r = 0
        return r

    rad = np.array([radius(x) for x in xs])
    dr = np.gradient(rad) * S * K
    is_metal = np.array([1.0 if (17 <= x <= 23 or 39 <= x <= 45 or 68 <= x <= 75) else 0.0 for x in xs])
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    rr = rad[None, :] * S * K
    v = (yy - cy) / np.maximum(rr, 1e-6)
    inside = (np.abs(v) <= 1.0) & (rr > 0)
    m = np.clip((rr - np.abs(yy - cy)) + 0.5, 0, 1) * (rr > 0)
    nz = np.sqrt(np.clip(1 - v * v, 0, 1))
    nx = np.clip(-dr[None, :] / (S * K) * 0.9, -0.8, 0.8) * nz
    ny = v
    n = np.dstack([nx * np.ones_like(v), ny, nz])
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
    wear = smoothstep(0.64, 0.8, fft_noise(H, W, 2.0, rng))
    paint = lerp(rgb(k['paint']), rgb(k['wear']), wear * 0.8)
    alb = lerp(paint, rgb(k['metal']), is_metal[None, :])
    # soft AO in the grooves next to the bands
    groove = np.array([1.0 if (16 <= x < 17 or 23 < x <= 24 or 38 <= x < 39 or 45 < x <= 46 or 67 <= x < 68) else 0.0 for x in xs])
    alb = alb * (1 - 0.45 * groove)[None, :, None]
    if k.get('seam'):
        seam = np.array([1.0 if (30 <= x <= 31 or 58 <= x <= 59) else 0.0 for x in xs])
        alb = lerp(alb, rgb(k['seam']) * 1.2, seam[None, :] * (np.abs(v) < 0.95))
    # bore: dark mouth seen slightly from the side at the tip
    bore = ellipse_mask(W, H, 75.0 * S * K, cy, 2.6 * S * K, 11 * S * K)
    rimm = ellipse_mask(W, H, 75.0 * S * K, cy, 4.0 * S * K, 18 * S * K)
    alb = lerp(alb, rgb(k['metal_d']) * 0.8, rimm * 0.0)
    alb = lerp(alb, rgb('#120804'), bore)
    m = np.maximum(m, rimm)
    n = np.where((rimm > 0.5)[..., None] & (bore < 0.5)[..., None], np.dstack([np.full_like(v, 0.75), v * 0.4, np.full_like(v, 0.55)]), n)
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
    specmask = 0.45 + 0.5 * is_metal[None, :] * np.ones_like(v)
    specmask = np.where(bore > 0.5, 0.0, specmask)
    # rivets on the bands (normal bumps)
    for bx in (20.0, 42.0, 71.5):
        for vy in (-0.55, 0.0, 0.55):
            px, py = bx * S * K, cy + vy * radius(bx) * S * K
            r0 = 1.8 * S * K
            rm = ellipse_mask(W, H, px, py, r0, r0)
            alb = lerp(alb, rgb(k['rivet']), rm)
            bump = np.dstack([(xx - px) / r0 * 0.8, (yy - py) / r0 * 0.8 + ny * 0.5, np.ones_like(xx)])
            bump /= np.linalg.norm(bump, axis=2, keepdims=True)
            n = lerp(n, bump, rm)
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
    albedo = to_img(kuwahara(alb, 1), m)
    nm = (n * 0.5 + 0.5)
    normal = to_img(nm, specmask)
    return albedo, normal, (0, cy)


def collar(skin, seed=4):
    k = SKINS[skin]
    r = 24 * S
    size = int(2 * r + 12)
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    dx, dy = (xx - c) / r, (yy - c) / r
    d = np.sqrt(dx * dx + dy * dy)
    m = ellipse_mask(size, size, c, c, r, r)
    # a raised ring with a domed cap
    hgt = np.where(d < 0.62, 6 + 5 * np.sqrt(np.clip(1 - (d / 0.62) ** 2, 0, 1)), 9 * np.sqrt(np.clip(1 - ((d - 0.81) / 0.19) ** 2, 0, 1)))
    hgt = blur(hgt * S, 1.0)
    n = normals(hgt)
    dif = lambert(n)
    sp = spec(n, 26)
    inner = d < 0.62
    alb = np.where(inner[..., None], rgb(k['paint']), rgb(k['metal']))
    col = alb * (0.25 + 1.0 * dif)[..., None] + (sp * 0.7)[..., None] * rgb(k['metal_l'])
    rgb_, a_ = col, m
    for t in np.linspace(0, 2 * np.pi, 9)[:-1]:
        px, py = c + np.cos(t + 0.3) * r * 0.81, c + np.sin(t + 0.3) * r * 0.81
        rr = 2.2 * S
        rm = ellipse_mask(size, size, px, py, rr, rr)
        rn = np.dstack([(xx - px) / rr, (yy - py) / rr, np.ones_like(xx)])
        rn[..., 2] = np.sqrt(np.clip(1 - rn[..., 0] ** 2 - rn[..., 1] ** 2, 0.05, 1))
        rc_ = rgb(k['rivet']) * (0.3 + 0.9 * lambert(rn))[..., None] + (spec(rn, 20) * 0.7)[..., None]
        rgb_, a_ = over(rgb_, a_, rc_, rm)
    sh = drop_shadow(m, 3, 4, 2.5, 0.5)
    out_r, out_a = over(np.zeros_like(rgb_), sh, rgb_, a_)
    return to_img(out_r, out_a)


def arch(seed=11):
    """Stone arch around the cannon: wedge stones on a half circle, two pillars, a sill.
    Canvas covers world x 200..520, y -40..200; the opening is centred on x 360."""
    rng = np.random.default_rng(seed)
    X0, Y0, X1, Y1 = 200, -40, 520, 200
    W, H = (X1 - X0) * S, (Y1 - Y0) * S
    CX, CY = 360, 96          # centre of the half circle
    RI, RO = 92, 136          # inner and outer radius of the arch ring

    def P(x, y):
        return ((x - X0) * S, (y - Y0) * S)
    rgb_ = np.zeros((H, W, 3))
    a_ = np.zeros((H, W))
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    # dark alcove behind the cannon
    pts = [P(CX - RI, 176)]
    for t in np.linspace(np.pi, 2 * np.pi, 32):
        pts.append(P(CX + np.cos(t) * RI, CY + np.sin(t) * RI))
    pts.append(P(CX + RI, 176))
    rec = poly_mask(W, H, [pts])
    rc = lerp(rgb('#020b0d'), rgb('#0a2628'), np.clip(yy / H, 0, 1))
    rc = rc * (0.8 + 0.4 * fft_noise(H, W, 2.2, rng))[..., None]
    gx, gy = P(CX, 120)
    glow = np.exp(-(((xx - gx) / (80 * S)) ** 2 + ((yy - gy) / (66 * S)) ** 2))
    rc = rc + glow[..., None] * rgb('#3b2a14') * 0.7
    rgb_, a_ = over(rgb_, a_, rc, rec)
    shapes = []
    # wedge stones of the ring
    n = 7
    edges = np.linspace(np.pi, 2 * np.pi, n + 1) + np.concatenate([[0], rng.uniform(-0.05, 0.05, n - 1), [0]])
    for i in range(n):
        t0, t1 = edges[i] + 0.012, edges[i + 1] - 0.012
        ro = RO + rng.uniform(-6, 8)
        poly = []
        for t in np.linspace(t0, t1, 6):
            poly.append((CX + np.cos(t) * RI, CY + np.sin(t) * RI))
        for t in np.linspace(t1, t0, 6):
            poly.append((CX + np.cos(t) * ro, CY + np.sin(t) * ro))
        shapes.append(poly)
    # pillars (two stones each) and the sill
    for side in (-1, 1):
        xi, xo = CX + side * RI, CX + side * (RO + 4)
        a0, a1 = sorted([xi, xo])
        shapes.append([(a0, CY + 2), (a1, CY + 2), (a1, 140), (a0, 140)])
        shapes.append([(a0, 142), (a1, 142), (a1, 176), (a0, 176)])
    shapes.append([(212, 172), (300, 172), (300, 200), (212, 200)])
    shapes.append([(302, 170), (420, 170), (420, 200), (302, 200)])
    shapes.append([(422, 172), (508, 172), (508, 200), (422, 200)])
    for poly in shapes:
        xs_ = [p[0] for p in poly]
        ys_ = [p[1] for p in poly]
        bx0, by0, bx1, by1 = min(xs_), min(ys_), max(xs_), max(ys_)
        sw, sh_ = int((bx1 - bx0) * S + 24), int((by1 - by0) * S + 24)
        local = [((x - bx0) * S + 12, (y - by0) * S + 12) for x, y in poly]
        # soften: shrink a little towards the centre and round the corners
        cxl = np.mean([p[0] for p in local]); cyl = np.mean([p[1] for p in local])
        local = [(cxl + (x - cxl) * 0.97, cyl + (y - cyl) * 0.95) for x, y in local]
        mk = poly_mask(sw, sh_, [local], blur=1.2)
        mk = np.clip((mk - 0.5) * 2.2 + 0.5, 0, 1)
        style = dict(STYLES[rng.integers(0, 4)])
        style['bevel'] = 0.30
        hgt, base, idx, crease, dist, s_ = stone_field(sw, sh_, mk, rng, style, cells=1.0)
        col = shade_rock(hgt, base * 1.06, crease, dist, mk, rng, style, kuw=2)
        sh = drop_shadow(mk, 4, 6, 3, 0.65)
        tx, ty = int((bx0 - X0) * S - 12), int((by0 - Y0) * S - 12)
        ys0, xs0 = max(0, ty), max(0, tx)
        ye0, xe0 = min(H, ty + sh_), min(W, tx + sw)
        sub = (slice(ys0 - ty, ye0 - ty), slice(xs0 - tx, xe0 - tx))
        dst = (slice(ys0, ye0), slice(xs0, xe0))
        r2, a2 = over(rgb_[dst], a_[dst], np.zeros_like(rgb_[dst]), sh[sub])
        rgb_[dst], a_[dst] = over(r2, a2, col[sub], mk[sub])
    return to_img(rgb_, a_), (X0, Y0)


def lit_barrel(skin, angle):
    """The barrel lit exactly like shaders/barrel.gdshader at a given aim angle (for previews and the icon)."""
    alb, nrm, piv = barrel(skin)
    A = np.asarray(alb, dtype=np.float64) / 255
    N = np.asarray(nrm, dtype=np.float64) / 255
    n = N[..., :3] * 2 - 1
    c, s = np.cos(angle), np.sin(angle)
    nw = np.dstack([c * n[..., 0] - s * n[..., 1], s * n[..., 0] + c * n[..., 1], n[..., 2]])
    nw /= np.maximum(np.linalg.norm(nw, axis=2, keepdims=True), 1e-6)
    dif = lambert(nw)
    sp = spec(nw, 26) * N[..., 3]
    col = A[..., :3] * (0.24 + 1.0 * dif)[..., None] + (sp * 0.8)[..., None] * np.array([1.0, 0.86, 0.62])
    img = to_img(col, A[..., 3])
    # rotate around the hinge (left middle)
    W, H = img.size
    big = Image.new('RGBA', (W * 2 + 8, W * 2 + 8), (0, 0, 0, 0))
    big.paste(img, (W + 4, W + 4 - H // 2))
    rot = big.rotate(-np.degrees(angle), resample=Image.BICUBIC, center=(W + 4, W + 4))
    return rot, (W + 4, W + 4)


def preview(skin, angle=1.0):
    """Cannon finish preview for the cosmetics screen (art scale 2)."""
    base, piv = base_sprite(skin)
    br, bpiv = lit_barrel(skin, angle)
    col = collar(skin)
    W, H = 300 * 2 // 2 + 60, 200
    W = 340
    canvas = Image.new('RGBA', (W, 220), (0, 0, 0, 0))
    cx, cy = 150, 80
    canvas.alpha_composite(base, (int(cx - piv[0]), int(cy - piv[1])))
    canvas.alpha_composite(br, (int(cx - bpiv[0]), int(cy - bpiv[1])))
    canvas.alpha_composite(col, (int(cx - col.width / 2), int(cy - col.height / 2)))
    return canvas
