"""Visible stone faces against the collision rectangles: coverage, side inset and corner gap in game units.
python3 tools/art/check_silhouettes.py"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import stones
from build import SHAPES

S = stones.S
worst = dict(cov=1.0, side=0.0, corner=0.0)
rows = []
for (w, h) in SHAPES:
    for v in range(4):
        _, mask = stones.block(w, h, v, 1000 + v * 37 + w * 7 + h * 3)
        P = stones.PAD
        W = int((w * stones.CELL - 2 * stones.GAP) * S)
        H = int((h * stones.CELL - 2 * stones.GAP) * S)
        m = mask > 0.5
        rect = m[P:P + H, P:P + W]
        cov = rect.mean()
        outside = m.copy()
        outside[P:P + H, P:P + W] = False
        spill = outside.sum()
        insets = []
        for x in range(int(W * 0.15), int(W * 0.85)):
            col = rect[:, x]
            insets.append(np.argmax(col))
            insets.append(np.argmax(col[::-1]))
        for y in range(int(H * 0.15), int(H * 0.85)):
            row = rect[y, :]
            insets.append(np.argmax(row))
            insets.append(np.argmax(row[::-1]))
        side = max(insets) / S
        ys, xs = np.nonzero(rect)
        corners = [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)]
        cg = max(np.min(np.hypot(xs - cx, ys - cy)) for cx, cy in corners) / S
        rows.append(f"{w}x{h} v{v}: covers {cov * 100:5.1f}% of the collider, side inset <= {side:4.1f}, corner gap <= {cg:4.1f}, pixels outside {spill}")
        worst['cov'] = min(worst['cov'], cov)
        worst['side'] = max(worst['side'], side)
        worst['corner'] = max(worst['corner'], cg)
print("\n".join(rows))
print(f"WORST: coverage {worst['cov'] * 100:.1f}%, side inset {worst['side']:.1f} units, corner gap {worst['corner']:.1f} units (ball radius {11})")
