"""Cut the painted Mira and Einstein out of the concept, to use as placeholders until their sheets arrive.
Pixel-art figures have a dark outline: flood-fill the background from the box edges through everything that is not
outline-dark; what stays unfilled is the figure."""
import numpy as np, sys
from PIL import Image
from collections import deque

def cut(img, box, dark=58, out=None):
    x0, y0, x1, y1 = box
    a = np.asarray(img.crop(box).convert("RGB")).astype(int)
    h, w, _ = a.shape
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    wall = lum < dark
    bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not wall[y, x]: q.append((y, x)); bg[y, x] = True
    for y in range(h):
        for x in (0, w - 1):
            if not wall[y, x] and not bg[y, x]: q.append((y, x)); bg[y, x] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and not wall[ny, nx]:
                bg[ny, nx] = True; q.append((ny, nx))
    fg = ~bg
    # Drop isolated dark specks of the cobblestone joints: keep the biggest connected blob only.
    lab = np.zeros((h, w), int); best = (0, 0); n = 0
    for y in range(h):
        for x in range(w):
            if fg[y, x] and not lab[y, x]:
                n += 1; size = 0; q.append((y, x)); lab[y, x] = n
                while q:
                    cy, cx = q.popleft(); size += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = n; q.append((ny, nx))
                if size > best[1]: best = (n, size)
    fg = lab == best[0]
    rgba = np.dstack([a, np.where(fg, 255, 0)]).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    return im.crop(im.getbbox())

if __name__ == "__main__":
    img = Image.open(sys.argv[1]); out = sys.argv[2]
    for name, box in {"mira": (604, 496, 670, 614), "einstein": (694, 488, 776, 614)}.items():
        c = cut(img, box)
        c.save(f"{out}/{name}_cut.png")
        big = c.resize((c.width * 4, c.height * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (90, 40, 110, 255)); bg.alpha_composite(big); bg.save(f"{out}/{name}_preview.png")
    print("ok")

def grab(img, box):
    import cv2
    a = cv2.cvtColor(np.asarray(img.convert("RGB")), cv2.COLOR_RGB2BGR)
    mask = np.zeros(a.shape[:2], np.uint8)
    bgd = np.zeros((1, 65), np.float64); fgd = np.zeros((1, 65), np.float64)
    x0, y0, x1, y1 = box
    cv2.grabCut(a, mask, (x0, y0, x1 - x0, y1 - y0), bgd, fgd, 8, cv2.GC_INIT_WITH_RECT)
    return ((mask == 1) | (mask == 3))[y0:y1, x0:x1]

def union_cut(img, box):
    """GrabCut keeps the bright parts (face, hair, jacket), the outline flood keeps the dark ones (boots, trousers):
    their union, holes filled, is the figure."""
    from scipy import ndimage
    g = grab(img, box)
    f = np.asarray(cut_mask(img, box))
    m = ndimage.binary_fill_holes(ndimage.binary_closing(g | f, iterations=1))
    lab, n = ndimage.label(m)
    if n > 1:
        sizes = ndimage.sum(m, lab, range(1, n + 1)); m = lab == (1 + int(np.argmax(sizes)))
    a = np.asarray(img.crop(box).convert("RGB"))
    im = Image.fromarray(np.dstack([a, np.where(m, 255, 0)]).astype(np.uint8), "RGBA")
    return im.crop(im.getbbox())

def cut_mask(img, box, dark=58):
    c = cut(img, box, dark)
    # rebuild the mask in box coordinates
    x0, y0, x1, y1 = box
    full = Image.new("L", (x1 - x0, y1 - y0), 0)
    a = np.asarray(img.crop(box).convert("RGB")).astype(int)
    return np.zeros((y1 - y0, x1 - x0), bool) | _flood_fg(a, dark)

def _flood_fg(a, dark):
    h, w, _ = a.shape
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    wall = lum < dark
    bg = np.zeros((h, w), bool); q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not wall[y, x]: bg[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not wall[y, x] and not bg[y, x]: bg[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and not wall[ny, nx]:
                bg[ny, nx] = True; q.append((ny, nx))
    return ~bg
