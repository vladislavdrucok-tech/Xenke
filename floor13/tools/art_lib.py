"""Small pixel-art toolkit used by make_art.py (PIL only)."""
from PIL import Image


def C(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(col, k):
    """k>1 lighter, k<1 darker (keeps alpha)."""
    r, g, b, a = col
    if k >= 1:
        t = k - 1
        return (int(r + (255 - r) * t), int(g + (255 - g) * t), int(b + (255 - b) * t), a)
    return (int(r * k), int(g * k), int(b * k), a)


def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


class Canvas:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.img = Image.new('RGBA', (w, h), bg)
        self.p = self.img.load()
        self.w, self.h = w, h

    def px(self, x, y, c):
        if c is None:
            return
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 4 and c[3] < 255 and c[3] > 0:
                o = self.p[x, y]
                a = c[3] / 255.0
                self.p[x, y] = (int(o[0] * (1 - a) + c[0] * a), int(o[1] * (1 - a) + c[1] * a),
                                int(o[2] * (1 - a) + c[2] * a), max(o[3], c[3]))
            else:
                self.p[x, y] = c

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.p[x, y]
        return (0, 0, 0, 0)

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, c)

    def clear(self, x, y, w, h):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.set(xx, yy, (0, 0, 0, 0))

    def frame(self, x, y, w, h, c):
        self.rect(x, y, w, 1, c)
        self.rect(x, y + h - 1, w, 1, c)
        self.rect(x, y, 1, h, c)
        self.rect(x + w - 1, y, 1, h, c)

    def hline(self, x0, x1, y, c):
        for x in range(int(x0), int(x1) + 1):
            self.px(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(int(y0), int(y1) + 1):
            self.px(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.px(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def disc(self, cx, cy, r, c):
        for yy in range(int(cy - r - 1), int(cy + r + 2)):
            for xx in range(int(cx - r - 1), int(cx + r + 2)):
                if (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r + r * 0.6:
                    self.px(xx, yy, c)

    def ring(self, cx, cy, r, c):
        for yy in range(int(cy - r - 1), int(cy + r + 2)):
            for xx in range(int(cx - r - 1), int(cx + r + 2)):
                d = ((xx - cx) ** 2 + (yy - cy) ** 2) ** 0.5
                if abs(d - r) < 0.6:
                    self.px(xx, yy, c)

    def pattern(self, x, y, rows, pal):
        """Draw ASCII rows; each char maps through pal (missing/space = skip)."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                col = pal.get(ch)
                if col is not None:
                    self.px(x + i, y + j, col)

    def paste(self, other, x, y):
        self.img.alpha_composite(other.img if isinstance(other, Canvas) else other, (int(x), int(y)))
        self.p = self.img.load()


def outline(img, col, box=None, diag=False):
    """Adds a 1px outline around opaque pixels (inside box)."""
    p = img.load()
    w, h = img.size
    x0, y0, x1, y1 = box if box else (0, 0, w, h)
    marks = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if p[x, y][3] != 0:
                continue
            n = [(1, 0), (-1, 0), (0, 1), (0, -1)]
            if diag:
                n += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
            for dx, dy in n:
                xx, yy = x + dx, y + dy
                if x0 <= xx < x1 and y0 <= yy < y1 and p[xx, yy][3] > 40:
                    marks.append((x, y))
                    break
    for x, y in marks:
        p[x, y] = col


def flip_rows(rows):
    return [r[::-1] for r in rows]
