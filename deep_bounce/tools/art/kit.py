"""Painting helpers for Deep Bounce: tileable noise, Voronoi facets, height-field lighting, AA masks,
a Kuwahara filter for the brushed look. Everything is numpy; images are float arrays in 0..1."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

LIGHT = np.array([-0.52, -0.72, 0.86])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hexc(h, a=1.0):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + ([a] if a is not None else []))


def rgb(h):
    return hexc(h)[:3]


def fft_noise(h, w, beta, rng):
    """Tileable fractal noise in 0..1; larger beta = smoother."""
    white = rng.standard_normal((h, w))
    F = np.fft.fft2(white)
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1.0
    F = F / (f ** beta)
    F[0, 0] = 0
    n = np.real(np.fft.ifft2(F))
    n -= n.min()
    n /= max(n.max(), 1e-9)
    return n


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def poly_mask(w, h, polys, ss=4, blur=0.0):
    """Anti-aliased mask of polygons (list of point lists in pixel coords)."""
    im = Image.new('L', (w * ss, h * ss), 0)
    d = ImageDraw.Draw(im)
    for p in polys:
        d.polygon([(x * ss, y * ss) for x, y in p], fill=255)
    im = im.resize((w, h), Image.LANCZOS)
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, dtype=np.float64) / 255.0


def ellipse_mask(w, h, cx, cy, rx, ry, ss=4):
    im = Image.new('L', (w * ss, h * ss), 0)
    ImageDraw.Draw(im).ellipse([(cx - rx) * ss, (cy - ry) * ss, (cx + rx) * ss, (cy + ry) * ss], fill=255)
    return np.asarray(im.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255.0


def voronoi(h, w, pts, wrap_y=False):
    """Returns (index of nearest point, F1, F2) for every pixel."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    best = np.full((h, w), 1e18)
    second = np.full((h, w), 1e18)
    idx = np.zeros((h, w), dtype=np.int32)
    shifts = [0.0, -h, h] if wrap_y else [0.0]
    for i, (px, py) in enumerate(pts):
        for s in shifts:
            d = (xx - px) ** 2 + (yy - py - s) ** 2
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d))
            idx = np.where(closer, i, idx)
            best = np.where(closer, d, best)
    return idx, np.sqrt(best), np.sqrt(second)


def normals(height):
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, -gy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def lambert(n, light=LIGHT):
    return np.clip((n * light).sum(axis=2), 0, 1)


def spec(n, power=18.0, light=LIGHT):
    hv = light + np.array([0, 0, 1.0])
    hv /= np.linalg.norm(hv)
    return np.clip((n * hv).sum(axis=2), 0, 1) ** power


def kuwahara(img, r=2):
    """Edge-preserving painterly filter (4-quadrant Kuwahara)."""
    k = r + 1
    lum = img[..., :3].mean(axis=2)
    pad = r
    P = np.pad(img, ((pad, pad), (pad, pad), (0, 0)), mode='edge')
    L = np.pad(lum, pad, mode='edge')
    means = []
    vars_ = []
    H, W = lum.shape
    for oy in (0, r):
        for ox in (0, r):
            sub = P[oy:oy + H + r, ox:ox + W + r]
            subl = L[oy:oy + H + r, ox:ox + W + r]
            m = np.stack([ndimage.uniform_filter(sub[..., c], size=k, mode='nearest') for c in range(img.shape[2])], -1)
            ml = ndimage.uniform_filter(subl, size=k, mode='nearest')
            sq = ndimage.uniform_filter(subl * subl, size=k, mode='nearest')
            c0 = k // 2
            means.append(m[c0:c0 + H, c0:c0 + W])
            vars_.append((sq - ml * ml)[c0:c0 + H, c0:c0 + W])
    V = np.stack(vars_, 0)
    M = np.stack(means, 0)
    pick = np.argmin(V, axis=0)
    out = np.take_along_axis(M, pick[None, ..., None].repeat(img.shape[2], -1), 0)[0]
    return out


def to_img(rgb_arr, alpha=None):
    rgb_arr = np.clip(rgb_arr, 0, 1)
    if alpha is None:
        return Image.fromarray((rgb_arr * 255 + 0.5).astype(np.uint8), 'RGB')
    a = np.clip(alpha, 0, 1)
    return Image.fromarray((np.dstack([rgb_arr, a]) * 255 + 0.5).astype(np.uint8), 'RGBA')


def over(dst_rgb, dst_a, src_rgb, src_a):
    """Porter-Duff over for float arrays."""
    out_a = src_a + dst_a * (1 - src_a)
    safe = np.maximum(out_a, 1e-6)[..., None]
    out_rgb = (src_rgb * src_a[..., None] + dst_rgb * (dst_a * (1 - src_a))[..., None]) / safe
    return out_rgb, out_a


def lerp(a, b, t):
    t = np.asarray(t)
    if t.ndim == 2:
        t = t[..., None]
    return a + (b - a) * t


def jitter_poly(rng, x0, y0, x1, y1, chamfer, wobble, steps=3, inset=0.0):
    """Irregular rock outline inside the rectangle: chamfered corners, slightly wavy sides (inward only)."""
    w = x1 - x0
    h = y1 - y0
    m = min(w, h)
    cs = [rng.uniform(chamfer[0], chamfer[1]) * m for _ in range(8)]
    pts = []

    def side(ax, ay, bx, by, nx, ny):
        for i in range(1, steps + 1):
            t = i / (steps + 1)
            d = rng.uniform(0, wobble) * m + inset
            pts.append((ax + (bx - ax) * t + nx * d, ay + (by - ay) * t + ny * d))

    # clockwise from the top-left corner
    pts.append((x0 + cs[0], y0 + rng.uniform(0, 0.3) * cs[0]))
    side(x0 + cs[0], y0, x1 - cs[1], y0, 0, 1)
    pts.append((x1 - cs[1], y0 + rng.uniform(0, 0.3) * cs[1]))
    pts.append((x1 - rng.uniform(0, 0.3) * cs[2], y0 + cs[2]))
    side(x1, y0 + cs[2], x1, y1 - cs[3], -1, 0)
    pts.append((x1 - rng.uniform(0, 0.3) * cs[3], y1 - cs[3]))
    pts.append((x1 - cs[4], y1 - rng.uniform(0, 0.3) * cs[4]))
    side(x1 - cs[4], y1, x0 + cs[5], y1, 0, -1)
    pts.append((x0 + cs[5], y1 - rng.uniform(0, 0.3) * cs[5]))
    pts.append((x0 + rng.uniform(0, 0.3) * cs[6], y1 - cs[6]))
    side(x0, y1 - cs[6], x0, y0 + cs[7], 1, 0)
    pts.append((x0 + rng.uniform(0, 0.3) * cs[7], y0 + cs[7]))
    # pull the first corner to match the last chamfer
    return pts


def blur(a, s):
    return ndimage.gaussian_filter(a, s)


def save(img, path):
    img.save(path, optimize=True)
