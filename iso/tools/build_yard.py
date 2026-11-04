"""Builds the Station yard for the isometric prototype from the owner's concept (art/concepts-iso/station_yard_concept.png).

  python3 iso/tools/build_yard.py [--debug]      (from the repo root; needs Pillow, numpy, scipy, opencv-python-headless)

TEMPORARY ART. Until the separate PNGs listed in docs/ISO_ART_LIST_UK.md arrive, the yard is cut from the concept:
* the background: the concept with its painted interface and the walking figures removed;
* occluders: objects the hero can walk behind (purifier, garden bed, stall, crates, planter...) cut out along a polygon,
  drawn again over the background and depth-sorted by their base line, so the hero passes behind or in front of them;
* states made by recolouring: the purifier dry and broken, the garden bed dry / sown / watered / sprouting / grown;
* Mira and the researcher cut out of the concept (one 3/4 frame each);
* walk area and obstacle polygons for collisions (bases of objects).
Everything in image pixels; the game uses the same coordinates."""
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import json, sys
import numpy as np
from scipy import ndimage

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
import cut_chars as cc
SRC = root / 'art/concepts-iso/station_yard_concept.png'
OUT = root / 'iso/assets/yard'
DATA = root / 'iso/data/yard.json'

# ---------------------------------------------------------------- what to remove from the painting
FIGURES = {   # painted people that walk (they become real characters or are removed)
    'mira': (604, 496, 670, 614), 'einstein': (694, 488, 776, 614), 'porter': (425, 612, 497, 724), 'walker': (774, 308, 842, 424)}
HUD = [(8, 8, 350, 100), (598, 0, 930, 78), (1160, 12, 1532, 72), (34, 792, 218, 990), (1368, 838, 1498, 972),
       (902, 456, 1016, 474), (1108, 238, 1152, 282)]
BUBBLE_PAVING = [(900, 392), (1018, 392), (1018, 458), (900, 458)]   # the purifier's painted bubble: paving under its upper part
# The purifier's need bubble and the master's speech mark sit over spots the game keeps marked (its own bubble and
# talk mark are drawn exactly there), so the inpainted patches never show.
COBBLE = (600, 614, 700, 660)          # a clean patch of the plaza's paving, tiled into holes

# ---------------------------------------------------------------- geometry (image pixels)
WALK = [(360, 515), (598, 500), (600, 474), (748, 474), (772, 335), (858, 302), (905, 345), (965, 378), (1082, 378),
        (1090, 450), (1166, 462), (1162, 700), (1296, 786), (1250, 840), (1040, 850), (870, 846), (770, 852),
        (560, 862), (470, 846), (340, 792), (330, 772), (410, 712), (410, 560)]
OCCLUDERS = {   # name: (polygon of its picture, base y = the line where it stands on the ground)
    'purifier': ([(796, 600), (806, 470), (846, 418), (1004, 418), (1052, 468), (1176, 478), (1180, 534), (1118, 562),
                  (1118, 652), (1050, 676), (1020, 652), (950, 642), (860, 628)], 625),
    'bed': ([(816, 706), (900, 650), (1080, 700), (1080, 738), (996, 786), (816, 744)], 770),
    'tomatoes': ([(1008, 744), (1100, 690), (1296, 770), (1296, 812), (1206, 860), (1008, 806)], 845),
    'stall': ([(500, 702), (556, 662), (640, 650), (762, 700), (762, 782), (700, 852), (640, 864), (520, 834), (500, 784)], 840),
    'crates_l': ([(404, 602), (420, 574), (472, 556), (562, 574), (566, 642), (502, 670), (420, 668)], 662),
    'crates_r': ([(1046, 472), (1058, 438), (1110, 428), (1162, 444), (1164, 498), (1110, 510), (1048, 494)], 502),
    'planter': ([(596, 452), (598, 372), (642, 366), (748, 398), (752, 466), (700, 478), (600, 474)], 468),
}
OBSTACLES = {   # collision footprints (bases)
    'purifier': [(800, 590), (872, 548), (1112, 566), (1116, 648), (1046, 668), (806, 616)],
    'bed': [(818, 712), (900, 662), (1078, 706), (1078, 736), (996, 778), (818, 742)],
    'tomatoes': [(1010, 760), (1100, 712), (1294, 780), (1294, 808), (1206, 852), (1010, 800)],
    'stall': [(506, 760), (620, 704), (756, 744), (756, 790), (650, 852), (512, 820)],
    'crates_l': [(406, 640), (472, 604), (562, 612), (564, 642), (500, 668), (420, 666)],
    'crates_r': [(1048, 482), (1104, 456), (1162, 470), (1162, 496), (1110, 508), (1048, 494)],
    'planter': [(598, 470), (640, 440), (748, 452), (750, 470), (700, 478)],
}
SPOTS = {   # interaction points: where the hero stands, what it is
    'pavlo': (1150, 600), 'workbench': (1010, 394), 'scrap': (1104, 528), 'storage': (502, 744), 'purifier': (790, 640),
    'basin': (1124, 676), 'bed': (796, 762), 'shelter': (470, 530)}

def tiled_fill(a, mask, patch):
    """Fills `mask` with the paving patch repeated in place (the pattern lines up with the plaza)."""
    x0, y0, x1, y1 = patch
    p = a[y0:y1, x0:x1]
    ph, pw = p.shape[:2]
    ys, xs = np.nonzero(mask)
    a[ys, xs] = p[(ys - y0) % ph, (xs - x0) % pw]

PAVING_SRC = [(420, 476, 598, 610), (604, 622, 790, 660), (752, 430, 848, 545), (440, 610, 520, 650)]   # clean open paving

def patch_fill(a, mask, block=26, ring=5, step=2):
    """Fills holes block by block (top-left first) with patches of clean paving: for each block the source is the spot
    in PAVING_SRC whose surroundings match what is already around the block, so joints and stones continue."""
    H, W = mask.shape
    remaining = mask.copy()
    af = a.astype(np.float32)
    ok = np.zeros(mask.shape, bool)
    for x0, y0, x1, y1 in PAVING_SRC:
        ok[y0:y1, x0:x1] = True
    ok &= ~ndimage.binary_dilation(mask, iterations=3)
    ys, xs = np.nonzero(mask)
    pad = ring + 1
    for by in range(ys.min(), ys.max() + 1, block):
        for bx in range(xs.min(), xs.max() + 1, block):
            cell = np.zeros(mask.shape, bool)
            cell[by:by + block, bx:bx + block] = True
            reg = cell & remaining
            if not reg.any():
                continue
            ctx = ndimage.binary_dilation(reg, iterations=ring) & ~remaining
            y0, y1 = max(0, by - pad), min(H, by + block + pad)
            x0, x1 = max(0, bx - pad), min(W, bx + block + pad)
            r, c = reg[y0:y1, x0:x1], ctx[y0:y1, x0:x1]
            tgt = af[y0:y1, x0:x1]
            h, w = y1 - y0, x1 - x0
            best, bo = None, None
            for sx0, sy0, sx1, sy1 in PAVING_SRC:
                for sy in range(sy0, sy1 - h + 1, step):
                    for sx in range(sx0, sx1 - w + 1, step):
                        if not ok[sy:sy + h, sx:sx + w][r | c].all():
                            continue
                        src = af[sy:sy + h, sx:sx + w]
                        d = float(((src[c] - tgt[c]) ** 2).mean()) if c.any() else 0.0
                        if best is None or d < best:
                            best, bo = d, (sy, sx)
            if bo is None:
                continue
            sy, sx = bo
            blk = a[y0:y1, x0:x1]
            blk[r] = a[sy:sy + h, sx:sx + w][r]
            af[y0:y1, x0:x1][r] = blk[r]
            remaining &= ~reg

def offset_fill(a, mask, avoid, search=260, step=3, fallback=None):
    """Fills each hole with a copy of the picture from somewhere nearby, at the offset whose surroundings match the
    hole's own surroundings best: the paving's joints then continue through the filled place instead of a pasted tile.
    `avoid`: places that must not be copied from (other holes, figures)."""
    lab, n = ndimage.label(mask)
    af = a.astype(np.float32)
    H, W = mask.shape
    for i in range(1, n + 1):
        hole = lab == i
        ring = ndimage.binary_dilation(hole, iterations=7) & ~hole
        ys, xs = np.nonzero(hole | ring)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        hr, rr = hole[y0:y1, x0:x1], ring[y0:y1, x0:x1]
        target = af[y0:y1, x0:x1]
        best, bo = None, (0, 0)
        for dy in range(-search, search + 1, step):
            for dx in range(-search, search + 1, step):
                if abs(dy) < 20 and abs(dx) < 20:
                    continue
                sy0, sx0 = y0 + dy, x0 + dx
                if sy0 < 0 or sx0 < 0 or sy0 + (y1 - y0) > H or sx0 + (x1 - x0) > W:
                    continue
                if avoid[sy0:sy0 + (y1 - y0), sx0:sx0 + (x1 - x0)][hr | rr].any():
                    continue
                src = af[sy0:sy0 + (y1 - y0), sx0:sx0 + (x1 - x0)]
                d = float(((src[rr] - target[rr]) ** 2).mean())
                if best is None or d < best:
                    best, bo = d, (dy, dx)
        if best is None and fallback is not None:
            # Nowhere fully on open paving: allow any place that is not a hole.
            for dy in range(-search, search + 1, step):
                for dx in range(-search, search + 1, step):
                    if abs(dy) < 20 and abs(dx) < 20:
                        continue
                    sy0, sx0 = y0 + dy, x0 + dx
                    if sy0 < 0 or sx0 < 0 or sy0 + (y1 - y0) > H or sx0 + (x1 - x0) > W:
                        continue
                    if fallback[sy0:sy0 + (y1 - y0), sx0:sx0 + (x1 - x0)][hr | rr].any():
                        continue
                    src = af[sy0:sy0 + (y1 - y0), sx0:sx0 + (x1 - x0)]
                    d = float(((src[rr] - target[rr]) ** 2).mean())
                    if best is None or d < best:
                        best, bo = d, (dy, dx)
        print('  fill hole %d at (%d,%d) %dx%d from offset %s, mismatch %.0f' % (i, x0, y0, x1 - x0, y1 - y0, bo, best if best is not None else -1))
        dy, dx = bo
        src = a[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
        blk = a[y0:y1, x0:x1]
        blk[hr] = src[hr]
        # Feather the seam over two pixels.
        edge = ndimage.binary_dilation(hr, iterations=2) & ~ndimage.binary_erosion(hr, iterations=1)
        mix = (0.5 * blk[edge].astype(np.float32) + 0.5 * src[edge].astype(np.float32)).astype(np.uint8)
        blk[edge] = mix

def _figure_mask(img, box, grow):
    x0, y0, x1, y1 = box
    m = cc._flood_fg(np.asarray(img.crop(box).convert('RGB')).astype(int), 58) | cc.grab(img, box)
    m = ndimage.binary_fill_holes(ndimage.binary_closing(m))
    lab, n = ndimage.label(m)
    if n > 1:
        sizes = ndimage.sum(m, lab, range(1, n + 1)); m = lab == (1 + int(np.argmax(sizes)))
    full = np.zeros((img.height, img.width), bool)
    full[y0:y1, x0:x1] = ndimage.binary_dilation(m, iterations=grow)
    return full

def clean(img):
    import cv2
    a = np.asarray(img.convert('RGB')).copy()
    # Mira and the researcher stand on open paving: the paving pattern is laid back into their place.
    hole = _figure_mask(img, FIGURES['mira'], 4) | _figure_mask(img, FIGURES['einstein'], 4)
    extra = Image.new('L', img.size, 0)
    dr = ImageDraw.Draw(extra)
    dr.polygon([(776, 326), (832, 326), (834, 424), (774, 424)], fill=255)          # the walker in front of the workshop
    dr.ellipse((598, 590, 682, 618), fill=255)                                        # Mira's painted shadow
    dr.ellipse((688, 592, 784, 620), fill=255)                                        # the researcher's
    dr.polygon(BUBBLE_PAVING, fill=255)
    hole |= np.asarray(extra) > 0
    # Copy only from open paving: the walk area without objects, figures and other holes.
    pav = Image.new('L', img.size, 0)
    dp = ImageDraw.Draw(pav)
    dp.polygon(WALK, fill=255)
    for poly in OBSTACLES.values():
        dp.polygon(poly, fill=0)
    for poly, base in OCCLUDERS.values():
        dp.polygon(poly, fill=0)
    avoid = ~(np.asarray(pav) > 0) | ndimage.binary_dilation(hole, iterations=9) | _figure_mask(img, FIGURES['porter'], 6)
    avoid = ndimage.binary_dilation(avoid, iterations=2)
    fallback = ndimage.binary_dilation(hole, iterations=9) | _figure_mask(img, FIGURES['porter'], 6)
    # The purifier's bubble sits over its pipes, not only paving: allow it to borrow from anywhere on the plaza edge.
    patch_fill(a, hole)
    # The porter by the storage stays painted: he is the storekeeper the hero talks to.
    hm = np.zeros(a.shape[:2], np.uint8)
    for x0, y0, x1, y1 in HUD:          # the painted interface
        hm[y0:y1, x0:x1] = 255
    a = cv2.cvtColor(cv2.inpaint(cv2.cvtColor(a, cv2.COLOR_RGB2BGR), hm, 5, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB)
    return Image.fromarray(a)

def cut_poly(img, poly):
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    rgba = img.convert('RGBA')
    rgba.putalpha(m)
    bb = m.getbbox()
    return rgba.crop(bb), bb

def purifier_broken(im):
    """The purifier dry and broken: the clean water in the tank, the stream and the basin turned to murky dark."""
    a = np.asarray(im.convert('RGBA')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    water = (b > 150) & (g > 120) & (r < 140) & (b > r + 50)
    lum = (r + g + b) / 3
    a[water, 0] = (28 + lum[water] * 0.12).astype(int)
    a[water, 1] = (36 + lum[water] * 0.14).astype(int)
    a[water, 2] = (40 + lum[water] * 0.16).astype(int)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), 'RGBA')

def bed_states(im, poly_local):
    """Garden bed: 0 dry soil, 1 sown, 2 watered, 3 sprouts, 4 grown (the painting itself).
    The soil inside the wooden frame is repainted whole, with furrows along the bed."""
    a = np.asarray(im.convert('RGBA')).astype(int)
    h, w = a.shape[:2]
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).polygon(poly_local, fill=255)
    inner = np.asarray(m) > 0
    rng = np.random.default_rng(3)
    yy, xx = np.mgrid[0:h, 0:w]
    furrow = ((xx * 0.5 + yy) % 11) < 3          # furrows running along the bed's long side (iso diagonal)
    noise = rng.integers(0, 3, (h, w))
    pal = np.array([[150, 116, 78], [134, 102, 68], [162, 128, 86]])
    dry = a.copy()
    dry[inner, :3] = pal[noise[inner]]
    dry[inner & furrow, :3] = (dry[inner & furrow, :3] * 0.8).astype(int)
    sown = dry.copy()
    seeds = inner & ~furrow & ((xx % 7 == 3) & (yy % 9 == 4))
    seeds = ndimage.binary_dilation(seeds) & inner
    sown[seeds, :3] = [86, 60, 36]
    wet = sown.copy()
    wet[inner, :3] = (wet[inner, :3] * np.array([0.55, 0.52, 0.56])).astype(int)
    sprout = wet.copy()
    pts = [(x, y) for y in range(4, h - 4, 9) for x in range(4 + (y // 9 % 2) * 7, w - 4, 14) if inner[y, x]]
    for x, y in pts:
        for dy, dx, c in ((0, 0, (70, 140, 50)), (-1, 0, (90, 170, 64)), (-2, -1, (120, 200, 84)), (-2, 1, (120, 200, 84))):
            if 0 <= y + dy < h and 0 <= x + dx < w:
                sprout[y + dy, x + dx, :3] = c
    out = [dry, sown, wet, sprout, a]
    return [Image.fromarray(o.clip(0, 255).astype(np.uint8), 'RGBA') for o in out]

def legs(im):
    """Where the legs begin and the column between them, for the walking legs in the game: going up from the feet,
    the rows that show two separate legs (a gap near the middle), until the gap closes for good (the coat)."""
    a = np.asarray(im)[..., 3] > 0
    h, w = a.shape
    found, top, misses, centres = False, None, 0, []
    for y in range(h - 1, int(h * 0.45), -1):
        xs = np.nonzero(a[y])[0]
        gap = None
        for i in range(len(xs) - 1):
            c = (xs[i] + xs[i + 1]) / 2.0
            if xs[i + 1] - xs[i] > 1 and w * 0.3 < c < w * 0.7:
                gap = c
        if gap is not None:
            found, top, misses = True, y, 0
            centres.append(gap)
        elif found:
            misses += 1
            if misses > 3:
                break
    if top is None:
        return round(h * 0.72), round(w / 2.0, 1)
    return int(top) - 1, round(float(np.mean(centres)), 1)

# ---------------------------------------------------------------- the owner's art for the start (docs/START_ART_UK.md)
START = root / 'art/start'
NPCS = {'pavlo': (1236, 576, 1346, 704), 'keeper': (412, 600, 508, 732)}   # painted people kept as living background
WHEEL_AREA = [(800, 600), (880, 618), (884, 676), (820, 680), (796, 640)]   # where S2a drops the purifier's valve wheel

def diff_cut(con, s1, box, thr=70):
    """A painted figure as what the concept has and the clean yard S1 does not: the difference of the two (slightly
    blurred, so the small generative drift between them does not count), without the figure's painted shadow."""
    cb = np.asarray(con.filter(ImageFilter.GaussianBlur(1.5))).astype(int)
    sb = np.asarray(s1.filter(ImageFilter.GaussianBlur(1.5))).astype(int)
    x0, y0, x1, y1 = box
    m = np.abs(cb - sb).sum(2)[y0:y1, x0:x1] > thr
    c = np.asarray(con).astype(float)[y0:y1, x0:x1]
    s = np.asarray(s1).astype(float)[y0:y1, x0:x1]
    ratio = c / np.maximum(s, 1.0)
    shadow = (ratio.max(2) < 0.92) & (ratio.min(2) > 0.3) & ((ratio.max(2) - ratio.min(2)) < 0.12)
    # The painted shadow differs from S1 too: keep what the figure's dark outline encloses (flood from the box edges
    # through everything that is not outline), and drop pale shadow-only pixels outside it.
    enclosed = ndimage.binary_dilation(cc._flood_fg(np.asarray(con)[y0:y1, x0:x1].astype(int), 58), iterations=1)
    m &= enclosed | ~shadow
    m = ndimage.binary_opening(m, iterations=1)

    m = ndimage.binary_fill_holes(ndimage.binary_closing(m, iterations=2))
    lab, n = ndimage.label(m)
    if n > 1:
        sizes = ndimage.sum(m, lab, range(1, n + 1)); m = lab == (1 + int(np.argmax(sizes)))
    rgba = np.dstack([np.asarray(con)[y0:y1, x0:x1], np.where(m, 255, 0)]).astype(np.uint8)
    im = Image.fromarray(rgba, 'RGBA')
    bb = im.getbbox()
    return im.crop(bb), (x0 + bb[0], y0 + bb[1])

def walk_frames(src, cols, height):
    """A strip of walking frames (S3a...): each cell trimmed, scaled so the figure is `height` px tall, and all put on
    one canvas with the point between the feet at the bottom centre, so swapping frames never shifts the character."""
    im = Image.open(src).convert('RGBA')
    cw = im.width // cols
    parts = []
    for i in range(cols):
        c = im.crop((i * cw, 0, (i + 1) * cw, im.height))
        a = np.asarray(c)[..., 3] > 110
        ys, xs = np.nonzero(a)
        top, bot = ys.min(), ys.max()
        upper = a[top:top + int((bot - top) * 0.55)]
        ax = float(np.nonzero(upper)[1].mean())                   # body centre (head and torso), not the swinging legs
        parts.append((c, ax, bot, bot - top))
    k = height / float(np.mean([p[3] for p in parts]))
    out = []
    for c, ax, bot, h in parts:
        bb = c.getbbox()
        c = c.crop(bb)
        ax -= bb[0]; bot -= bb[1]
        s = c.resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.Resampling.LANCZOS)
        s.putalpha(s.getchannel('A').point(lambda v: 255 if v > 110 else 0))
        out.append((s, ax * k, (bot + 1) * k))
    half = int(max(max(ax, s.width - ax) for s, ax, f in out)) + 2
    up = int(max(f for s, ax, f in out)) + 2
    frames = []
    for s, ax, f in out:
        cv = Image.new('RGBA', (half * 2, up))
        cv.alpha_composite(s, (round(half - ax), round(up - f)))
        frames.append(cv)
    return frames

PACK2 = START / 'pack2/outputs'
BED_POLY = [(804, 704), (898, 634), (1092, 692), (1092, 744), (996, 798), (804, 752)]   # covers the bed in all S2 states

def figure_frames(src, n, height, ref=None, anchor='body', canvas=None):
    """Frames of a sheet found as figures, not grid cells (the artist does not keep the cells): the n largest blobs,
    left to right; small loose bits (water drops) go with the nearest figure. Scaled so the `ref` frames (standing
    ones) are `height` px tall; feet (bottom of the figure itself) at the bottom centre of one shared canvas;
    horizontal anchor = the body's centre ('body', for walking) or the feet ('feet', for crouching work)."""
    im = Image.open(src).convert('RGBA')
    alpha = np.asarray(im)[..., 3] > 110
    lab, num = ndimage.label(ndimage.binary_dilation(alpha, iterations=5))
    sizes = ndimage.sum(alpha, lab, range(1, num + 1))
    order = sorted(range(1, num + 1), key=lambda i: -sizes[i - 1])
    main = sorted(order[:n], key=lambda i: ndimage.center_of_mass(alpha, lab, i)[1])
    cx = [ndimage.center_of_mass(alpha, lab, i)[1] for i in main]
    groups = {m: [m] for m in main}
    for i in order[n:]:
        c = ndimage.center_of_mass(alpha, lab, i)[1]
        groups[main[int(np.argmin([abs(c - x) for x in cx]))]].append(i)
    a_img = np.asarray(im)
    parts = []
    for m in main:
        body = (lab == m) & alpha
        whole = np.isin(lab, groups[m]) & alpha
        ys, xs = np.nonzero(whole)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        rgba = a_img[y0:y1, x0:x1].copy()
        rgba[..., 3] = np.where(whole[y0:y1, x0:x1], 255, 0)
        bys, bxs = np.nonzero(body)
        foot = bys.max() + 1 - y0
        top = bys.min()
        if anchor == 'feet':
            low = body[bys.max() - max(3, int((bys.max() - top) * 0.08)):bys.max() + 1]
            ax = float(np.nonzero(low)[1].mean()) - x0
        else:
            up = body[top:top + int((bys.max() - top) * 0.55)]
            ax = float(np.nonzero(up)[1].mean()) - x0
        parts.append((Image.fromarray(rgba, 'RGBA'), ax, foot, bys.max() - top))
    refs = ref if ref is not None else range(n)
    k = height / float(np.mean([parts[i][3] for i in refs]))
    out = []
    for c, ax, foot, h in parts:
        s_ = c.resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.Resampling.LANCZOS)
        s_.putalpha(s_.getchannel('A').point(lambda v: 255 if v > 110 else 0))
        out.append((s_, ax * k, foot * k))
    half = int(max(max(ax, s_.width - ax) for s_, ax, f in out)) + 2
    up_ = int(max(f for s_, ax, f in out)) + 2
    below = int(max(s_.height - f for s_, ax, f in out)) + 1     # drops or tools that hang below the feet
    frames = []
    for s_, ax, f in out:
        cv = Image.new('RGBA', (half * 2, up_ + below))
        cv.alpha_composite(s_, (round(half - ax), round(up_ - f)))
        frames.append(cv)
    return frames, below

def save_set(frames, name, below=0):
    paths = []
    for i, f in enumerate(frames):
        f.save(OUT / f'{name}_{i}.png')
        paths.append(f'res://assets/yard/{name}_{i}.png')
    return {'frames': paths, 'below': below}

def main(debug=False):
    OUT.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert('RGB')
    s1_path, s2a_path, s3a_path = START / 'S1_yard_clean.png', START / 'S2a_purifier_broken.png', START / 'S3a_mira_walk_SE.png'
    have_s1 = s1_path.exists()
    # S1 (the owner's clean yard) when it is there; otherwise the concept cleaned here.
    bg = Image.open(s1_path).convert('RGB') if have_s1 else clean(img)
    bg.save(OUT / 'background.png')
    data = {'size': list(img.size), 'walk': WALK, 'obstacles': dict(OBSTACLES), 'spots': SPOTS, 'occluders': {}, 'chars': {},
            'overlays': {}, 'npcs': {}}
    for name, (poly, base) in OCCLUDERS.items():
        piece, bb = cut_poly(bg, poly)
        piece.save(OUT / f'{name}.png')
        data['occluders'][name] = {'x': bb[0], 'y': bb[1], 'base': base, 'tex': f'res://assets/yard/{name}.png', 'poly': poly}
    # States.
    pur = Image.open(OUT / 'purifier.png')
    if s2a_path.exists():
        # S2a: the broken purifier as the owner's picture. The piece the hero can walk behind, and under it a wider
        # patch of S2a (purifier, dropped wheel, dry basin) on the ground layer with a soft edge, so where S2a's
        # generative drift differs from S1 no seam shows.
        s2a = Image.open(s2a_path).convert('RGB')
        piece, bb = cut_poly(s2a, OCCLUDERS['purifier'][0])
        piece.save(OUT / 'purifier_broken.png')
        m = Image.new('L', s2a.size, 0)
        dm = ImageDraw.Draw(m)
        dm.polygon(OCCLUDERS['purifier'][0], fill=255)
        dm.polygon(WHEEL_AREA, fill=255)
        hard = ndimage.binary_dilation(np.asarray(m) > 0, iterations=8)
        soft = ndimage.gaussian_filter(hard.astype(float), 3.0)
        alpha = np.clip(soft * 1.6, 0, 1) * 255
        ov = Image.fromarray(np.dstack([np.asarray(s2a), alpha]).astype(np.uint8), 'RGBA')
        obb = Image.fromarray(alpha.astype(np.uint8)).getbbox()
        ov.crop(obb).save(OUT / 'purifier_broken_bg.png')
        data['overlays']['purifier_broken'] = {'x': obb[0], 'y': obb[1], 'tex': 'res://assets/yard/purifier_broken_bg.png'}
    else:
        purifier_broken(pur).save(OUT / 'purifier_broken.png')
    bed = Image.open(OUT / 'bed.png')
    bx, by = data['occluders']['bed']['x'], data['occluders']['bed']['y']
    inner = [(x - bx, y - by) for x, y in [(840, 700), (912, 660), (1058, 696), (986, 736)]]
    s2 = [PACK2 / f'environment/{n}.png' for n in ('S2c_bed_dry', 'S2d_bed_sown', 'S2e_bed_watered', 'S2f_bed_sprouts')]
    if all(p_.exists() for p_ in s2):
        # The owner's bed states: each cut from its picture with one polygon that covers the bed in every state, soft
        # edge so the drift of the generated pictures round the bed does not show. The grown bed is S1's own.
        m = Image.new('L', bg.size, 0)
        ImageDraw.Draw(m).polygon(BED_POLY, fill=255)
        soft = np.clip(ndimage.gaussian_filter((np.asarray(m) > 0).astype(float), 2.0) * 1.8, 0, 1)
        soft[np.asarray(m) > 0] = np.maximum(soft[np.asarray(m) > 0], 0.0)
        bb = Image.fromarray((soft * 255).astype(np.uint8)).getbbox()
        srcs = [Image.open(p_).convert('RGB') for p_ in s2] + [bg]
        for i, src in enumerate(srcs):
            piece = np.dstack([np.asarray(src), (soft * 255).astype(np.uint8)])
            Image.fromarray(piece, 'RGBA').crop(bb).save(OUT / f'bed_{i}.png')
        data['occluders']['bed'].update({'x': bb[0], 'y': bb[1], 'poly': BED_POLY})
        bx, by = bb[0], bb[1]
    else:
        for i, s in enumerate(bed_states(bed, inner)):
            s.save(OUT / f'bed_{i}.png')
    # The background must not show the grown bed or the working purifier under their other states: paint the
    # broken purifier and the dry bed into the background too (the live sprites sit exactly on top).
    bgr = bg.convert('RGBA')
    if not s2a_path.exists():
        bgr.alpha_composite(purifier_broken(pur), (data['occluders']['purifier']['x'], data['occluders']['purifier']['y']))
    bgr.alpha_composite(Image.open(OUT / 'bed_0.png'), (bx, by))
    bgr.convert('RGB').save(OUT / 'background.png')
    # Characters. Mira walks with the owner's S3a frames; the researcher is still the figure from the concept
    # (cut by its difference from S1 when S1 is there), walking with split legs until his sheet arrives.
    for name in ('mira', 'einstein'):
        c = cc.union_cut(img, FIGURES[name])
        c.save(OUT / f'{name}.png')
        hip, split = legs(c)
        data['chars'][name] = {'tex': f'res://assets/yard/{name}.png', 'w': c.width, 'h': c.height, 'hip': hip, 'split': split}
    if s3a_path.exists():
        fr = walk_frames(s3a_path, 4, 104)
        for i, f in enumerate(fr):
            f.save(OUT / f'mira_walk_{i}.png')
        data['chars']['mira']['walk'] = [f'res://assets/yard/mira_walk_{i}.png' for i in range(len(fr))]
        data['chars']['mira']['idle_frame'] = 1
        sets = {'walk_se': {'frames': data['chars']['mira']['walk'], 'below': 0}}
        M = PACK2 / 'mira'
        for key, fn in (('walk_ne', 'S3b_mira_walk_NE.png'), ('walk_s', 'S3c_mira_walk_S.png'), ('walk_n', 'S3d_mira_walk_N.png')):
            if (M / fn).exists():
                fr, below = figure_frames(M / fn, 4, 104)
                sets[key] = save_set(fr, 'mira_' + key, below)
        if (M / 'S3f_mira_wrench_groundwork_v2.png').exists():
            fr, below = figure_frames(M / 'S3f_mira_wrench_groundwork_v2.png', 4, 104, ref=(0, 1), anchor='feet')
            sets['wrench'] = save_set(fr[:2], 'mira_wrench', below)
            sets['ground'] = save_set(fr[2:], 'mira_ground', below)
        if (M / 'S3g_mira_watering_pickup_happy_v1.png').exists():
            fr, below = figure_frames(M / 'S3g_mira_watering_pickup_happy_v1.png', 4, 104, ref=(0, 1), anchor='feet')
            sets['water'] = save_set(fr[:2], 'mira_water', below)
            sets['pickup'] = save_set(fr[2:3], 'mira_pickup', below)
            sets['happy'] = save_set(fr[3:4], 'mira_happy', below)
        data['chars']['mira']['sets'] = sets
    E = PACK2 / 'einstein'
    if (E / 'S4a_einstein_walk_SE.png').exists():
        sets = {}
        fr, below = figure_frames(E / 'S4a_einstein_walk_SE.png', 4, 114)
        sets['walk_se'] = save_set(fr, 'einstein_walk_se', below)
        if (E / 'S4a_einstein_wrench_repair_v1.png').exists():
            fr, below = figure_frames(E / 'S4a_einstein_wrench_repair_v1.png', 4, 114, ref=(0, 1), anchor='feet')
            sets['wrench'] = save_set(fr[:2], 'einstein_wrench', below)
            sets['ground'] = save_set(fr[2:], 'einstein_ground', below)
        data['chars']['einstein']['sets'] = sets
    # People of the yard kept from the concept until their own sheets come (S5): Pavlo in the greenhouse, the storekeeper.
    if have_s1:
        for name, box in NPCS.items():
            c, (x, y) = diff_cut(img, bg, box)
            c.save(OUT / f'npc_{name}.png')
            data['npcs'][name] = {'tex': f'res://assets/yard/npc_{name}.png', 'x': x + c.width / 2.0, 'y': y + c.height}
        k = data['npcs']['keeper']
        data['obstacles']['keeper'] = [(k['x'] - 22, k['y'] - 6), (k['x'], k['y'] - 16), (k['x'] + 22, k['y'] - 6), (k['x'], k['y'] + 6)]
    DATA.write_text(json.dumps(data, indent=1))
    if debug:
        dbg = bgr.convert('RGB')
        d = ImageDraw.Draw(dbg)
        d.polygon(WALK, outline=(0, 255, 0))
        for p in OBSTACLES.values():
            d.polygon(p, outline=(255, 0, 0))
        for n, (poly, base) in OCCLUDERS.items():
            d.polygon(poly, outline=(0, 160, 255))
            xs = [p[0] for p in poly]
            d.line((min(xs), base, max(xs), base), fill=(255, 255, 0))
        for n, p in SPOTS.items():
            d.ellipse((p[0] - 6, p[1] - 6, p[0] + 6, p[1] + 6), outline=(255, 0, 255), width=2)
            d.text((p[0] + 8, p[1] - 6), n, fill=(255, 0, 255))
        dbg.save(root / 'qa/out/yard_debug.png')
    print('yard built', bg.size)

if __name__ == '__main__':
    main('--debug' in sys.argv)
