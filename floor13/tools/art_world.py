"""Hotel art: 13 themed floors, shaft, cabin, roof, street, skyline."""
import random
from art_lib import C, Canvas, shade, mix, outline

W, FH = 360, 52
SHAFT_X, SHAFT_W = 8, 96
DOORS = (250, 318)
FEET = 48
K = C('1a1020')
GOLD = C('f2c14e')
GOLD_D = C('b8862a')
GOLD_L = C('ffe08a')
WHITE = C('f4f0e8')
SLAB = C('1b1528')
EXT = C('3b2d55')
EXT_D = C('2c2142')

THEMES = {
    1: dict(wall=C('7a2c3a'), wall2=C('8c3646'), pat='damask', patc=C('a8464f'), wains=C('4a2a22'),
            floor=C('d8ccb4'), floor2=C('b8a88e'), fpat='checker', trim=GOLD, door=C('5a3020')),
    2: dict(wall=C('9a4a2c'), wall2=C('a85a34'), pat='stripes', patc=C('b06a3c'), wains=C('5a3420'),
            floor=C('e8e0d0'), floor2=C('2a2230'), fpat='checker', trim=GOLD, door=C('6a3a22')),
    3: dict(wall=C('2f6670'), wall2=C('367480'), pat='damask', patc=C('428892'), wains=C('d8c8a8'),
            floor=C('a8343a'), floor2=C('8a2a30'), fpat='carpet', trim=GOLD, door=C('6a4026')),
    4: dict(wall=C('5fb0d0'), wall2=C('6cbcdc'), pat='tiles', patc=C('4a98b8'), wains=None,
            floor=C('cfe8f0'), floor2=C('a8d0e0'), fpat='tiles', trim=C('f4f0e8'), door=C('3a7a9a')),
    5: dict(wall=C('35553a'), wall2=C('3c5f40'), pat='stripes', patc=C('42684a'), wains=C('4a2e1e'),
            floor=C('8a5a34'), floor2=C('6e4628'), fpat='planks', trim=GOLD, door=C('4a2e1e')),
    6: dict(wall=C('4a5670'), wall2=C('52607a'), pat='band', patc=C('e8a23a'), wains=C('3a4258'),
            floor=C('34303c'), floor2=C('2a2632'), fpat='rubber', trim=C('c0c8d8'), door=C('5a6680')),
    7: dict(wall=C('5c8a3a'), wall2=C('6a9a44'), pat='glass', patc=C('8ac46a'), wains=C('6a4a30'),
            floor=C('c0603a'), floor2=C('a04e2e'), fpat='terracotta', trim=C('e8f0e0'), door=C('5a7a3a')),
    8: dict(wall=C('3e1d5a'), wall2=C('4a2468'), pat='stars', patc=C('ff6ad5'), wains=C('2a1440'),
            floor=C('ff4fa0'), floor2=C('4fd8ff'), fpat='disco', trim=C('ff6ad5'), door=C('2a1440')),
    9: dict(wall=C('7d6ea6'), wall2=C('8778b0'), pat='waves', patc=C('9a8cc4'), wains=C('d8c8b0'),
            floor=C('d8b888'), floor2=C('c8a474'), fpat='planks', trim=C('f4f0e8'), door=C('a08a6a')),
    10: dict(wall=C('1e4a36'), wall2=C('245640'), pat='diamonds', patc=C('c8a040'), wains=C('3a1a1a'),
             floor=C('9a2030'), floor2=C('7a1828'), fpat='carpet', trim=GOLD, door=C('3a1a1a')),
    11: dict(wall=C('1f2a50'), wall2=C('24305a'), pat='stars', patc=C('c8d8ff'), wains=C('161e3a'),
             floor=C('3a4060'), floor2=C('30364f'), fpat='planks', trim=C('a8b8e8'), door=C('2a3460')),
    12: dict(wall=C('c8a86c'), wall2=C('d0b278'), pat='stripes', patc=C('dcc088'), wains=C('f0e8d8'),
             floor=C('f0ece4'), floor2=C('d8d0c4'), fpat='marble', trim=GOLD, door=C('8a6a3a')),
    13: dict(wall=C('2c3838'), wall2=C('324040'), pat='cracks', patc=C('1e2828'), wains=C('1e2626'),
             floor=C('3a3a3a'), floor2=C('2e2e2e'), fpat='planks', trim=C('6a8a7a'), door=C('2a2420')),
}


def wall_pattern(c, t, x0, x1, y0, y1, rnd):
    wall, wall2, patc = t['wall'], t['wall2'], t['patc']
    c.rect(x0, y0, x1 - x0, y1 - y0, wall)
    pat = t['pat']
    for x in range(x0, x1):
        for y in range(y0, y1):
            lx, ly = x - x0, y - y0
            if pat == 'stripes':
                if (x // 4) % 2 == 0:
                    c.set(x, y, wall2)
                if x % 8 == 0:
                    c.set(x, y, patc)
            elif pat == 'damask':
                if (x // 6 + y // 6) % 2 == 0:
                    c.set(x, y, wall2)
                if (x % 12 == 6 and y % 12 in (5, 6, 7)) or (y % 12 == 6 and x % 12 in (5, 7)):
                    c.set(x, y, patc)
            elif pat == 'tiles':
                if x % 8 == 0 or y % 8 == 0:
                    c.set(x, y, patc)
                elif (x // 8 + y // 8) % 3 == 0:
                    c.set(x, y, wall2)
            elif pat == 'band':
                if ly in range(14, 17):
                    c.set(x, y, patc if (x // 6) % 2 == 0 else shade(patc, 0.8))
                elif (x // 10) % 2 == 0:
                    c.set(x, y, wall2)
            elif pat == 'glass':
                cell_x, cell_y = x % 16, ly % 14
                if cell_x == 0 or cell_y == 0:
                    c.set(x, y, C('e8f0e0'))
                else:
                    # translucent greenhouse panes: the sky shows through a little
                    c.set(x, y, mix(C('9ad87a', 110), C('c8f0a8', 120), (cell_x + cell_y) / 30))
            elif pat == 'stars':
                if (x // 8) % 2 == 0:
                    c.set(x, y, wall2)
            elif pat == 'waves':
                if (y + (x // 4) % 3) % 7 == 0:
                    c.set(x, y, patc)
            elif pat == 'diamonds':
                dx, dy = x % 12, y % 12
                if abs(dx - 6) + abs(dy - 6) == 5:
                    c.set(x, y, patc)
                elif abs(dx - 6) + abs(dy - 6) < 2:
                    c.set(x, y, wall2)
            elif pat == 'cracks':
                if (x // 5 + y // 7) % 2 == 0:
                    c.set(x, y, wall2)
    if pat == 'stars':
        for _ in range((x1 - x0) // 10):
            sx, sy = rnd.randint(x0, x1 - 1), rnd.randint(y0, y1 - 1)
            c.set(sx, sy, patc)
            if rnd.random() < 0.3:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    c.px(sx + dx, sy + dy, shade(patc, 0.6))
    if pat == 'cracks':
        for _ in range(6):
            x, y = rnd.randint(x0, x1 - 1), rnd.randint(y0, y1 - 8)
            for i in range(rnd.randint(4, 9)):
                c.set(x, y, patc)
                x += rnd.choice((-1, 0, 1))
                y += 1


def floor_surface(c, t, x0, x1, rnd):
    f1, f2 = t['floor'], t['floor2']
    fp = t['fpat']
    for x in range(x0, x1):
        for y in range(46, 52):
            col = f1
            if fp == 'checker':
                col = f1 if ((x // 6) + (y // 3)) % 2 == 0 else f2
            elif fp == 'carpet':
                col = f1 if y not in (47, 50) else (GOLD_D if fp == 'carpet' else f2)
                if y == 48 and x % 6 == 0:
                    col = f2
            elif fp == 'tiles':
                col = f2 if x % 6 == 0 or y == 48 else f1
            elif fp == 'planks':
                col = f1 if ((x + (y // 2) * 7) // 14) % 2 == 0 else f2
                if (x + (y // 2) * 7) % 14 == 0:
                    col = shade(f2, 0.8)
            elif fp == 'rubber':
                col = f2 if (x + y) % 4 == 0 else f1
            elif fp == 'terracotta':
                col = f1 if ((x // 8) + (y // 3)) % 2 == 0 else f2
                if x % 8 == 0:
                    col = shade(f2, 0.8)
            elif fp == 'disco':
                pal = (C('ff4fa0'), C('4fd8ff'), C('ffe14f'), C('8aff6a'), C('b06aff'))
                col = pal[((x // 8) + (y // 3) * 2) % 5]
                if x % 8 == 0:
                    col = C('2a1440')
            elif fp == 'marble':
                col = f1 if ((x // 10) + (y // 3)) % 2 == 0 else f2
                if (x * 7 + y * 13) % 23 == 0:
                    col = shade(f2, 0.9)
            c.set(x, y, col)
        c.set(x, 46, shade(c.get(x, 46), 1.15))


def window(c, t, x, y, w=22, h=22, curtains=True):
    frame = t['trim'] if t['trim'] != GOLD else C('e8dcc0')
    c.rect(x - 1, y - 1, w + 2, h + 2, shade(frame, 0.7))
    c.rect(x, y, w, h, frame)
    c.clear(x + 2, y + 2, w - 4, h - 4)                 # glass: the sky shows through
    c.rect(x + w // 2 - 1, y + 2, 2, h - 4, frame)
    c.rect(x + 2, y + h // 2 - 1, w - 4, 1, frame)
    c.rect(x - 2, y + h, w + 4, 2, shade(frame, 0.85))   # sill
    if curtains:
        cur = shade(t['wall'], 1.35) if t['wall'][0] + t['wall'][1] < 300 else shade(t['wall'], 0.7)
        for i in range(h + 2):
            wv = 3 if i < h - 4 else 4
            c.rect(x - 3, y - 1 + i, wv, 1, cur)
            c.rect(x + w - wv + 3, y - 1 + i, wv, 1, cur)
        c.rect(x - 4, y - 3, w + 8, 2, shade(cur, 0.7))


def room_door(c, t, cx, num):
    d = t['door']
    x, y, w, h = cx - 8, 16, 16, 30
    c.rect(x - 2, y - 2, w + 4, h + 2, shade(d, 0.6))
    c.rect(x - 1, y - 1, w + 2, h + 1, t['trim'] if t['trim'] != GOLD else C('8a6a3a'))
    c.rect(x, y, w, h, d)
    c.rect(x + 2, y + 2, w - 4, 10, shade(d, 1.12))
    c.rect(x + 2, y + 15, w - 4, 12, shade(d, 1.12))
    c.rect(x + 2, y + 2, w - 4, 1, shade(d, 0.8))
    c.rect(x + 2, y + 15, w - 4, 1, shade(d, 0.8))
    c.rect(x + w - 4, y + 15, 2, 2, GOLD)
    c.rect(cx - 4, y - 7, 8, 4, GOLD_D)                 # room number plate
    c.rect(cx - 3, y - 6, 6, 2, GOLD)


def sconce(c, x, y, glow=C('ffd27a')):
    c.rect(x, y + 3, 2, 3, GOLD_D)
    c.rect(x - 1, y, 4, 3, glow)
    c.px(x, y - 1, shade(glow, 1.3))
    for r in range(1, 6):
        for dx in range(-r, r + 3):
            c.px(x + dx, y + 1 - r // 2 - 2, C('ffd27a', max(0, 26 - r * 5)))


def plant(c, x, base, tall=14, pot=C('b0603a')):
    c.rect(x - 4, base - 6, 8, 6, pot)
    c.rect(x - 5, base - 7, 10, 2, shade(pot, 1.15))
    c.rect(x - 4, base - 2, 8, 1, shade(pot, 0.75))
    leaf, leaf2 = C('3a9a4a'), C('5ac25a')
    rnd = random.Random(x * 31 + base)
    for i in range(tall * 3):
        lx = x + rnd.randint(-6, 6)
        ly = base - 7 - rnd.randint(0, tall)
        if abs(lx - x) > 6 - (base - 7 - ly) // 4 + 2:
            continue
        c.px(lx, ly, leaf if rnd.random() < 0.6 else leaf2)
        c.px(lx + 1, ly, leaf)
    c.vline(x, base - tall - 4, base - 7, C('2a7a3a'))


def painting(c, x, y, w, h, frame, art):
    c.rect(x - 1, y - 1, w + 2, h + 2, shade(frame, 0.6))
    c.rect(x, y, w, h, frame)
    c.rect(x + 2, y + 2, w - 4, h - 4, art[0])
    rnd = random.Random(x * 7 + y)
    # tiny landscape: hills + moon
    for i in range(w - 4):
        hh = int(2 + 2 * abs(((i * 3) % 11) - 5) / 5)
        c.rect(x + 2 + i, y + h - 2 - hh, 1, hh, art[1])
    c.px(x + w - 6, y + 4, art[2])
    c.px(x + w - 5, y + 4, art[2])


def floor_props(c, i, t, rnd):
    y_wall0, base = 3, 46
    if i == 1:   # lobby: reception desk, bell, plant, revolving door instead of room 2
        c.rect(263, 30, 42, 16, C('6a3a22'))
        c.rect(262, 28, 44, 3, C('8a5030'))
        c.rect(262, 28, 44, 1, GOLD)
        for x in range(266, 304, 8):
            c.rect(x, 33, 5, 10, C('5a3020'))
        c.rect(282, 25, 5, 3, GOLD)
        c.px(284, 24, GOLD_L)
        c.rect(268, 8, 32, 9, C('2a1a20'))
        for k, x in enumerate(range(270, 298, 4)):
            c.rect(x, 10, 3, 5, (GOLD if k % 2 == 0 else GOLD_D))
        plant(c, 341, base, 16)
        # glass entrance (door 2)
        x0 = DOORS[1] - 10
        c.rect(x0 - 2, 12, 24, 34, GOLD_D)
        c.clear(x0, 14, 20, 32)
        c.rect(x0, 14, 20, 32, C('8fd0ff', 70))
        c.rect(x0 + 9, 14, 2, 32, GOLD_D)
        c.rect(x0 - 4, 9, 28, 4, C('a8343a'))
        c.rect(x0 - 4, 12, 28, 1, shade(C('a8343a'), 0.7))
        # chandelier
        cx = 200
        c.vline(cx, 3, 6, GOLD_D)
        c.rect(cx - 7, 7, 15, 2, GOLD)
        for dx in (-7, -3, 1, 5):
            c.rect(cx + dx, 5, 2, 2, C('fff0b0'))
    elif i == 2:  # restaurant: table, chairs, menu board
        tx = 284
        c.rect(tx - 14, 33, 28, 3, WHITE)
        c.rect(tx - 15, 36, 30, 4, shade(WHITE, 0.9))
        c.rect(tx - 2, 40, 4, 6, C('5a3420'))
        c.rect(tx - 1, 28, 2, 5, WHITE)
        c.px(tx, 27, C('ffb84a'))
        c.px(tx, 26, C('ffe08a'))
        c.rect(tx - 9, 32, 4, 1, C('c84a3a'))
        c.rect(tx + 5, 32, 4, 1, C('7ac25a'))
        for sx in (tx - 20, tx + 17):
            c.rect(sx, 34, 4, 2, C('7a4628'))
            c.rect(sx, 36, 1, 10, C('5a3420'))
            c.rect(sx + 3, 36, 1, 10, C('5a3420'))
            c.rect(sx + (0 if sx < tx else 3), 24, 1, 10, C('5a3420'))
        c.rect(133, 7, 30, 18, C('2a2a2a'))
        c.frame(132, 6, 32, 20, C('8a5a30'))
        for k in range(4):
            c.rect(136, 10 + k * 4, 14 + (k * 5) % 9, 1, C('e8e0d0'))
        c.rect(334, 30, 12, 16, C('8a5a30'))
        c.rect(333, 28, 14, 2, C('a87040'))
        c.rect(336, 22, 8, 6, C('f4f0e8'))
    elif i == 3:  # rooms corridor: painting, sconces, plant
        painting(c, 270, 12, 28, 18, GOLD, (C('2a3a6a'), C('3a5a3a'), C('fff0b0')))
        sconce(c, 266, 20)
        sconce(c, 302, 20)
        plant(c, 340, base, 12, C('d8c8a8'))
        painting(c, 140, 8, 20, 13, GOLD, (C('6a2a3a'), C('a8464f'), WHITE))
    elif i == 4:  # pool: water, ladder, lifebuoy
        c.rect(262, 44, 46, 4, C('2a8ac8'))
        for x in range(262, 308):
            if (x // 3) % 2 == 0:
                c.px(x, 44, C('8fe0ff'))
        c.rect(262, 48, 46, 4, C('1e6a9a'))
        for lx in (270, 278):
            c.vline(lx, 30, 47, C('d0d8e0'))
        for y in range(34, 46, 4):
            c.hline(270, 278, y, C('d0d8e0'))
        c.ring(296, 20, 5, C('f4f0e8'))
        c.ring(296, 20, 4, C('e04848'))
        c.ring(296, 20, 6, C('e04848'))
        for (dx, dy) in ((-5, 0), (5, 0), (0, -5), (0, 5)):
            c.px(296 + dx, 20 + dy, WHITE)
        c.rect(334, 34, 12, 12, C('f4f0e8'))
        c.rect(334, 34, 12, 3, C('4a98b8'))
        c.rect(336, 38, 8, 6, C('4a98b8'))
    elif i == 5:  # library: bookshelf, reading lamp
        c.rect(262, 8, 44, 38, C('4a2e1e'))
        c.rect(264, 10, 40, 34, C('2a1a12'))
        cols = (C('c84a3a'), C('3a6ac8'), C('e8b84a'), C('4a9a5a'), C('8a4ab0'), C('d8d0c0'))
        for sy in (10, 21, 32):
            x = 265
            while x < 302:
                bw = rnd.randint(2, 3)
                bh = rnd.randint(7, 9)
                c.rect(x, sy + 10 - bh, bw, bh, rnd.choice(cols))
                c.px(x, sy + 10 - bh, shade(cols[0], 1.3) if rnd.random() < 0.2 else c.get(x, sy + 10 - bh))
                x += bw + (1 if rnd.random() < 0.3 else 0)
            c.rect(264, sy + 10, 40, 1, C('6a4430'))
        c.vline(340, 24, 45, GOLD_D)
        c.rect(336, 44, 9, 2, GOLD_D)
        c.rect(334, 18, 12, 6, C('3a7a4a'))
        c.rect(336, 24, 8, 1, C('ffe08a', 160))
        painting(c, 138, 8, 22, 14, C('8a5a30'), (C('4a3a2a'), C('6a5a3a'), GOLD_L))
    elif i == 6:  # gym: dumbbell rack, treadmill, mirror
        c.rect(262, 10, 30, 24, C('a8c8e0'))
        c.frame(261, 9, 32, 26, C('c0c8d8'))
        c.line(266, 30, 276, 14, C('d8ecff'))
        c.rect(262, 38, 42, 2, C('6a7080'))
        for k, x in enumerate(range(264, 302, 7)):
            col = (C('e04848'), C('3a6ac8'), C('e8a23a'), C('4a9a5a'), C('8a4ab0'), C('d0d0d0'))[k % 6]
            c.rect(x, 35, 2, 3, col)
            c.rect(x + 4, 35, 2, 3, col)
            c.rect(x + 2, 36, 2, 1, C('9aa0b0'))
        c.rect(263, 40, 2, 6, C('6a7080'))
        c.rect(301, 40, 2, 6, C('6a7080'))
        c.rect(328, 40, 20, 5, C('2a2a34'))
        c.line(344, 40, 348, 26, C('9aa0b0'))
        c.rect(345, 24, 6, 3, C('3a3a48'))
        c.px(347, 25, C('6af0ff'))
    elif i == 7:  # greenhouse: big plants, vines
        plant(c, 272, base, 22, C('a04e2e'))
        plant(c, 296, base, 18, C('8a4a2e'))
        plant(c, 340, base, 20, C('a04e2e'))
        for x in range(112, 350, 9):
            for k in range(rnd.randint(3, 9)):
                c.px(x + (k % 2), 3 + k, C('4aa84a'))
            c.px(x, 4 + rnd.randint(0, 6), C('ff8ac8'))
    elif i == 8:  # disco: ball, speakers, light beams
        c.vline(200, 3, 7, C('b8c0d0'))
        c.disc(200, 11, 4, C('c8d0e0'))
        for (dx, dy) in ((-2, -2), (1, -1), (-1, 2), (2, 1), (0, 0), (3, -2), (-3, 1)):
            c.px(200 + dx, 11 + dy, WHITE)
        for (bx, col) in ((180, C('ff4fa0', 50)), (220, C('4fd8ff', 50)), (240, C('ffe14f', 45))):
            c.line(200, 14, bx, 45, col)
            c.line(201, 14, bx + 1, 45, col)
        for sx in (264, 292):
            c.rect(sx, 22, 13, 24, C('1a1420'))
            c.disc(sx + 6, 30, 4, C('3a3048'))
            c.disc(sx + 6, 30, 2, C('6a5a80'))
            c.disc(sx + 6, 40, 2, C('3a3048'))
        c.rect(330, 12, 20, 8, C('1a1420'))
        for k, ch in enumerate((C('ff4fa0'), C('4fd8ff'), C('ffe14f'))):
            c.rect(332 + k * 6, 14, 4, 4, ch)
    elif i == 9:  # spa: towels, bamboo, candles, stones
        for k in range(4):
            c.rect(266, 40 - k * 3, 14, 3, (C('f4f0e8'), C('a8d8c8'), C('f4f0e8'), C('d8b8e8'))[k])
            c.rect(266, 42 - k * 3, 14, 1, shade(C('d8d0c8'), 0.9))
        for bx in (292, 296, 300):
            for y in range(10, 46):
                c.px(bx, y, C('6aa84a') if y % 7 else C('4a8a3a'))
            c.px(bx + 1, 14 + bx % 5, C('8ac86a'))
        for cx2 in (334, 340, 346):
            c.rect(cx2, 41, 3, 5, C('f4ead8'))
            c.px(cx2 + 1, 40, C('ffb84a'))
            c.px(cx2 + 1, 39, C('ffe08a', 180))
        c.rect(140, 10, 24, 12, C('e8dcc8'))
        c.frame(139, 9, 26, 14, C('a08a6a'))
        c.disc(152, 16, 3, C('9a8cc4'))
    elif i == 10:  # casino: slot machine, card table
        sx = 266
        c.rect(sx, 18, 16, 28, C('c83a3a'))
        c.rect(sx, 18, 16, 3, GOLD)
        c.rect(sx + 2, 24, 12, 8, C('1a1420'))
        for k, col in enumerate((C('ffe14f'), C('ff4a4a'), C('6af06a'))):
            c.rect(sx + 3 + k * 4, 26, 3, 4, col)
        c.vline(sx + 17, 22, 30, C('c0c8d8'))
        c.disc(sx + 17, 21, 1.2, C('ff4a4a'))
        c.rect(sx + 3, 36, 10, 2, C('1a1420'))
        c.rect(288, 34, 20, 3, C('1e6a3e'))
        c.rect(288, 34, 20, 1, GOLD_D)
        c.rect(296, 37, 4, 9, C('3a1a1a'))
        c.rect(292, 32, 3, 2, WHITE)
        c.rect(300, 32, 3, 2, WHITE)
        c.px(301, 32, C('e04848'))
        for k in range(3):
            c.rect(334 + k * 4, 40 - k * 2, 3, 6 + k * 2, (C('e04848'), C('3a6ac8'), C('1a1420'))[k])
            c.rect(334 + k * 4, 40 - k * 2, 3, 1, WHITE)
    elif i == 11:  # observatory: telescope, round window, constellations
        c.rect(264, 44, 14, 2, C('6a7090'))
        c.line(270, 44, 266, 34, C('8a90b0'))
        c.line(272, 44, 276, 34, C('8a90b0'))
        for k in range(16):
            c.rect(266 + k, 30 - k // 2, 4, 3, C('c0c8e8') if k < 14 else GOLD)
        c.ring(300, 22, 9, C('a8b8e8'))
        c.ring(300, 22, 10, C('6a78a8'))
        for yy in range(14, 31):
            for xx in range(292, 309):
                if (xx - 300) ** 2 + (yy - 22) ** 2 <= 64:
                    c.set(xx, yy, (0, 0, 0, 0))
        pts = [(135, 10), (142, 14), (150, 9), (158, 15), (166, 11)]
        for a, b in zip(pts, pts[1:]):
            c.line(a[0], a[1], b[0], b[1], C('6a78c8'))
        for p in pts:
            c.px(p[0], p[1], WHITE)
        c.rect(332, 26, 16, 20, C('2a3460'))
        c.rect(334, 28, 12, 6, C('c8d8ff'))
    elif i == 12:  # penthouse: piano, chandelier, sofa
        c.rect(264, 30, 30, 12, C('1a1622'))
        c.rect(264, 28, 30, 3, C('2a2632'))
        c.rect(266, 31, 26, 3, WHITE)
        for x in range(267, 292, 3):
            c.rect(x, 31, 1, 2, C('1a1622'))
        for lx in (266, 290):
            c.rect(lx, 42, 2, 4, C('1a1622'))
        c.rect(296, 20, 8, 1, C('1a1622'))
        c.line(264, 28, 278, 18, C('2a2632'))
        cx = 200
        c.vline(cx, 3, 6, GOLD_D)
        c.rect(cx - 9, 7, 19, 2, GOLD)
        c.rect(cx - 6, 9, 13, 2, GOLD_D)
        for dx in (-9, -5, -1, 3, 7):
            c.rect(cx + dx, 5, 2, 2, C('fff0b0'))
            c.px(cx + dx, 11, C('d8f0ff'))
        c.rect(330, 34, 20, 8, C('8a2a4a'))
        c.rect(330, 30, 4, 12, C('8a2a4a'))
        c.rect(346, 30, 4, 12, C('8a2a4a'))
        c.rect(334, 32, 12, 3, C('a83a5a'))
    elif i == 13:  # ???: candles, portrait with eyes, cobwebs, mist
        painting(c, 270, 10, 24, 22, C('5a4a3a'), (C('1a1414'), C('2a2420'), C('2a2420')))
        c.rect(278, 15, 8, 9, C('8a8a7a'))
        c.rect(277, 13, 10, 3, C('2a2420'))
        c.px(280, 18, C('ff4a4a'))
        c.px(283, 18, C('ff4a4a'))
        for cx2 in (300, 304):
            c.rect(cx2, 38, 2, 8, C('e8e0c8'))
            c.px(cx2, 37, C('8aff8a'))
            c.px(cx2, 36, C('c8ffc8', 160))
        for (x, y, flip) in ((110, 3, 1), (346, 3, -1), (236, 3, 1)):
            for r in range(1, 10):
                c.px(x + r * flip, y, C('c8c8c8', 140))
                c.px(x, y + r, C('c8c8c8', 140))
                c.px(x + r * flip // 2, y + r // 2, C('c8c8c8', 140))
            for r in (3, 6):
                for k in range(r):
                    c.px(x + k * flip, y + r - k, C('c8c8c8', 110))
        for x in range(110, 352):
            for y in range(38, 46):
                if rnd.random() < 0.25:
                    c.px(x, y, C('8affb0', 28))


def make_floor(i):
    t = THEMES[i]
    rnd = random.Random(i * 1009)
    c = Canvas(W, FH)
    # exterior walls
    for x0 in (0, W - 8):
        c.rect(x0, 0, 8, FH, EXT)
        for y in range(0, FH, 4):
            off = 0 if (y // 4) % 2 == 0 else 4
            c.hline(x0, x0 + 7, y, EXT_D)
            c.px(x0 + off, y + 1, EXT_D)
            c.px(x0 + off, y + 2, EXT_D)
    cx0, cx1 = 104, W - 8
    wall_pattern(c, t, cx0, cx1, 3, 44, rnd)
    if t['wains']:
        c.rect(cx0, 30, cx1 - cx0, 14, t['wains'])
        c.rect(cx0, 30, cx1 - cx0, 1, shade(t['wains'], 1.25))
        for x in range(cx0 + 6, cx1, 14):
            c.rect(x, 33, 10, 9, shade(t['wains'], 1.08))
            c.rect(x, 33, 10, 1, shade(t['wains'], 0.85))
    # slab and ceiling line
    c.rect(cx0, 0, cx1 - cx0, 3, SLAB)
    c.rect(cx0, 2, cx1 - cx0, 1, C('2c2242'))
    c.rect(cx0, 3, cx1 - cx0, 1, shade(t['wall'], 0.7))
    # baseboard + floor
    c.rect(cx0, 44, cx1 - cx0, 2, shade(t['trim'] if t['trim'] != WHITE else C('d0c8b8'), 0.75))
    floor_surface(c, t, cx0, cx1, rnd)
    # window(s) behind the queue area
    if i not in (4, 7, 11):
        window(c, t, 212, 9, 22, 20)
    elif i == 4:
        window(c, t, 212, 9, 22, 20, curtains=False)
    # doors
    for k, dx in enumerate(DOORS):
        if i == 1 and k == 1:
            continue
        room_door(c, t, dx, i * 100 + k + 1)
    floor_props(c, i, t, rnd)
    for x0 in (0, W - 8):
        c.rect(x0, 0, 8, FH, EXT)
        for y in range(0, FH, 4):
            off = 0 if (y // 4) % 2 == 0 else 4
            c.hline(x0, x0 + 7, y, EXT_D)
            c.px(x0 + off, y + 1, EXT_D)
            c.px(x0 + off, y + 2, EXT_D)
        c.rect(x0 + (7 if x0 == 0 else 0), 0, 1, FH, C('4e3d70'))
    # landing pillar next to the shaft with the floor plate
    c.rect(104, 3, 6, 43, shade(t['trim'], 0.7) if t['trim'] in (GOLD,) else shade(t['wall'], 0.6))
    c.rect(104, 3, 1, 43, shade(c.get(105, 10), 1.25))
    c.rect(111, 6, 15, 12, GOLD_D)
    c.rect(112, 7, 13, 10, C('2a1a20'))
    c.rect(111, 6, 15, 1, GOLD_L)
    # call button
    c.rect(114, 21, 9, 7, C('8a8a9a'))
    c.rect(115, 22, 7, 5, C('3a3048'))
    return c.img


def make_shaft_tile():
    c = Canvas(SHAFT_W, FH)
    b1, b2, mortar = C('1f1834'), C('261d3e'), C('15102a')
    for y in range(FH):
        row = y // 5
        for x in range(SHAFT_W):
            off = 0 if row % 2 == 0 else 6
            col = b1 if ((x + off) // 12 + row) % 3 else b2
            if y % 5 == 0 or (x + off) % 12 == 0:
                col = mortar
            c.set(x, y, col)
    # depth shading at the sides
    for x in range(10):
        a = 120 - x * 12
        c.rect(x, 0, 1, FH, C('0a0614', a))
        c.rect(SHAFT_W - 1 - x, 0, 1, FH, C('0a0614', a))
    # guide rails
    for rx in (2, SHAFT_W - 4):
        c.rect(rx, 0, 2, FH, C('6a6a7a'))
        c.rect(rx, 0, 1, FH, C('9a9aaa'))
        for y in range(4, FH, 13):
            c.rect(rx - 1, y, 4, 2, C('4a4a58'))
    # floor slab edge inside the shaft
    c.rect(0, 0, SHAFT_W, 3, C('140f22'))
    c.rect(0, 3, SHAFT_W, 1, C('2a2244'))
    return c.img


def make_cabin():
    """Two images: back wall (behind passengers) and front frame (over the gate)."""
    w, h = 88, 46
    back = Canvas(w, h)
    wood, wood2 = C('6b3f2a'), C('7d4c33')
    back.rect(2, 4, w - 4, h - 6, wood)
    for x in range(4, w - 4, 10):
        back.rect(x, 8, 8, 28, wood2)
        back.rect(x, 8, 8, 1, shade(wood2, 1.2))
        back.rect(x, 35, 8, 1, shade(wood, 0.8))
    back.rect(2, 4, w - 4, 3, C('3a2418'))
    back.rect(w // 2 - 8, 6, 16, 2, C('fff0c0'))                      # ceiling light
    for r in range(10):
        back.rect(w // 2 - 8 - r, 8 + r, 16 + r * 2, 1, C('fff0c0', max(0, 40 - r * 4)))
    back.rect(4, 26, w - 8, 2, GOLD)                                   # handrail
    back.rect(4, 27, w - 8, 1, GOLD_D)
    back.rect(2, h - 4, w - 4, 2, C('2a1a14'))                         # floor
    back.rect(2, h - 4, w - 4, 1, C('4a3024'))

    front = Canvas(w, h)
    brass, brass_d, brass_l = C('c9963b'), C('8a5a22'), C('f2c66d')
    front.rect(0, 0, w, 6, brass)                                       # header
    front.rect(0, 0, w, 1, brass_l)
    front.rect(0, 5, w, 1, brass_d)
    front.rect(w // 2 - 9, 1, 18, 4, C('1a0e0a'))                       # floor indicator window
    front.rect(0, 0, 3, h, brass)                                       # posts
    front.rect(w - 3, 0, 3, h, brass)
    front.rect(0, 0, 1, h, brass_l)
    front.rect(w - 1, 0, 1, h, brass_d)
    front.rect(0, h - 2, w, 2, brass_d)                                 # sill
    front.rect(0, h - 2, w, 1, brass)
    for y in (10, 22, 34):
        front.px(1, y, brass_l)
        front.px(w - 2, y, brass_l)
    return back.img, front.img


def make_roof():
    w, h = W, 96
    c = Canvas(w, h)
    # roof slab and parapet
    c.rect(0, h - 10, w, 10, EXT)
    c.rect(0, h - 10, w, 2, C('5a4878'))
    c.rect(0, h - 3, w, 3, SLAB)
    for x in range(0, w, 12):
        c.rect(x, h - 14, 8, 4, EXT)
        c.rect(x, h - 14, 8, 1, C('5a4878'))
    # machine room above the shaft
    c.rect(6, h - 44, 100, 34, C('2c2142'))
    c.rect(6, h - 44, 100, 2, C('4a3a6a'))
    c.rect(20, h - 34, 20, 14, C('3a2e58'))
    for y in range(h - 32, h - 22, 2):
        c.hline(22, 37, y, C('1a1430'))
    c.disc(78, h - 27, 9, C('3a2e58'))
    c.disc(78, h - 27, 7, C('1a1430'))
    for k in range(4):
        c.line(78, h - 27, 78 + (6 if k % 2 == 0 else -6) * (1 if k < 2 else -1) // 1,
               h - 27 + (6 if k in (1, 2) else -6), C('6a5a90'))
    c.disc(78, h - 27, 2, C('8a7ab0'))
    c.rect(50, h - 40, 10, 6, C('ff4a4a'))                               # warning light box
    c.rect(52, h - 39, 6, 3, C('ffa0a0'))
    # water tower
    tx = 300
    for lx in (tx - 12, tx + 10):
        c.line(lx, h - 12, lx + (4 if lx < tx else -4), h - 40, C('4a3a5a'))
    c.hline(tx - 10, tx + 9, h - 26, C('4a3a5a'))
    c.rect(tx - 14, h - 66, 28, 26, C('6a4a3a'))
    for x in range(tx - 14, tx + 14, 4):
        c.rect(x, h - 66, 1, 26, C('5a3a2e'))
    c.rect(tx - 15, h - 58, 30, 1, C('3a2a2a'))
    c.rect(tx - 15, h - 47, 30, 1, C('3a2a2a'))
    for k in range(6):
        c.rect(tx - 14 + k * 2 + 2, h - 70 - k, 24 - k * 4 - 2, 1, C('5a3a2e'))
    # antenna
    c.vline(130, h - 70, h - 14, C('6a6a7a'))
    c.hline(124, 136, h - 60, C('6a6a7a'))
    c.hline(126, 134, h - 52, C('6a6a7a'))
    c.px(130, h - 71, C('ff4a4a'))
    # neon sign frame (the glowing letters are a separate sprite)
    c.rect(150, h - 58, 130, 2, C('4a3a5a'))
    for lx in (160, 214, 268):
        c.rect(lx, h - 56, 2, 44, C('4a3a5a'))
    c.line(160, h - 30, 214, h - 50, C('3a2e48'))
    c.line(214, h - 30, 268, h - 50, C('3a2e48'))
    return c.img


def make_neon(font_path):
    from PIL import ImageFont, ImageDraw, Image, ImageFilter
    w, h = 150, 48
    out = []
    for on in (True, False):
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        ft = ImageFont.truetype(font_path, 16)
        ft2 = ImageFont.truetype(font_path, 8)
        pink, cyan = (255, 79, 160), (79, 216, 255)
        if not on:
            pink, cyan = (90, 40, 70), (40, 80, 100)
        # back plate
        d.rectangle([2, 4, w - 3, h - 6], fill=(26, 18, 40, 255), outline=(60, 46, 90, 255))
        d.text((10, 10), "HOTEL", font=ft, fill=pink + (255,))
        d.text((104, 10), "13", font=ft, fill=cyan + (255,))
        d.text((24, 32), "NIGHT SHIFT", font=ft2, fill=(255, 225, 79, 255) if on else (90, 80, 40, 255))
        if on:
            glow = img.copy().filter(ImageFilter.MaxFilter(3))
            px = glow.load()
            for y in range(h):
                for x in range(w):
                    r, g, b, a = px[x, y]
                    if (r, g, b) == (26, 18, 40) or (r, g, b) == (60, 46, 90):
                        px[x, y] = (0, 0, 0, 0)
                    elif a:
                        px[x, y] = (r, g, b, 70)
            base = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            d2 = ImageDraw.Draw(base)
            d2.rectangle([2, 4, w - 3, h - 6], fill=(26, 18, 40, 255), outline=(60, 46, 90, 255))
            base.alpha_composite(glow)
            # redraw letters crisp on top
            d3 = ImageDraw.Draw(base)
            d3.text((10, 10), "HOTEL", font=ft, fill=pink + (255,))
            d3.text((104, 10), "13", font=ft, fill=cyan + (255,))
            d3.text((24, 32), "NIGHT SHIFT", font=ft2, fill=(255, 225, 79, 255))
            # white-hot core
            p = base.load()
            for y in range(h):
                for x in range(w):
                    r, g, b, a = p[x, y]
                    if a == 255 and (r, g, b) in (pink, cyan):
                        if y % 2 == 0 and x % 3 == 0:
                            p[x, y] = (min(255, r + 120), min(255, g + 120), min(255, b + 120), 255)
            img = base
        out.append(img)
    sheet = Image.new('RGBA', (w * 2, h), (0, 0, 0, 0))
    sheet.alpha_composite(out[0], (0, 0))
    sheet.alpha_composite(out[1], (w, 0))
    return sheet


def make_street():
    w, h = W, 64
    c = Canvas(w, h)
    c.rect(0, 0, w, 10, C('4a4260'))                 # sidewalk
    for x in range(0, w, 16):
        c.vline(x, 0, 9, C('3a3450'))
    c.rect(0, 0, w, 1, C('6a6080'))
    c.rect(0, 10, w, 3, C('8a8098'))                 # curb
    c.rect(0, 13, w, h - 13, C('252033'))            # road
    for x in range(4, w, 28):
        c.rect(x, 34, 14, 2, C('d8c86a'))
    c.rect(0, h - 6, w, 6, C('1e1a2a'))
    # street lamp
    lx = 346
    c.vline(lx, -1, 9, C('3a3450'))
    # hydrant
    c.rect(20, 3, 5, 7, C('d83a3a'))
    c.rect(19, 4, 7, 1, C('a82a2a'))
    return c.img


def make_lamp():
    c = Canvas(16, 60)
    c.rect(7, 8, 2, 52, C('3a3450'))
    c.rect(2, 4, 12, 4, C('3a3450'))
    c.rect(3, 8, 10, 2, C('ffe8a0'))
    for r in range(14):
        c.rect(8 - r // 2 - 3, 10 + r, 6 + r, 1, C('ffe8a0', max(0, 50 - r * 3)))
    return c.img


def make_taxi():
    w, h = 44, 18
    frames = []
    for f in range(2):
        c = Canvas(w, h)
        y = 4
        c.rect(4, y + 4, 38, 7, C('f2c14e'))
        c.rect(10, y, 22, 5, C('f2c14e'))
        c.rect(12, y + 1, 8, 3, C('8fd0ff'))
        c.rect(22, y + 1, 8, 3, C('8fd0ff'))
        c.rect(17, y - 2, 8, 2, C('1a1420'))
        c.rect(18, y - 2, 6, 1, C('ffe08a'))
        for x in range(6, 40, 4):
            c.px(x, y + 8, C('1a1420'))
        c.rect(40, y + 5, 2, 2, C('fff0b0'))
        c.rect(4, y + 5, 2, 2, C('ff4a4a'))
        for wx in (11, 33):
            c.disc(wx, y + 11, 3, C('1a1420'))
            c.px(wx + (1 if f else -1), y + 11, C('8a8a9a'))
        outline(c.img, K)
        frames.append(c.img)
    from PIL import Image
    sheet = Image.new('RGBA', (w * 2, h), (0, 0, 0, 0))
    sheet.alpha_composite(frames[0], (0, 0))
    sheet.alpha_composite(frames[1], (w, 0))
    return sheet


def make_skyline():
    w, h = 360, 140
    c = Canvas(w, h)
    rnd = random.Random(42)
    for layer, (col, win, mh) in enumerate(((C('231a40'), C('ffd27a', 90), 120), (C('171130'), C('ffe8a0', 150), 90))):
        x = -rnd.randint(0, 20)
        while x < w:
            bw = rnd.randint(18, 40)
            bh = rnd.randint(30, mh)
            for xx in range(x, x + bw):
                c.rect(xx % w, h - bh, 1, bh, col)
            if rnd.random() < 0.3:
                c.rect((x + bw // 2) % w, h - bh - 8, 1, 8, col)
            for wy in range(h - bh + 4, h - 4, 6):
                for wx in range(x + 3, x + bw - 3, 5):
                    if rnd.random() < 0.28:
                        c.rect(wx % w, wy, 2, 3, win)
            x += bw + rnd.randint(0, 6)
    return c.img


def make_moon():
    c = Canvas(32, 32)
    c.disc(16, 16, 12, C('fff4d6'))
    for (x, y, r) in ((11, 12, 2.5), (19, 20, 3), (20, 10, 1.5), (12, 21, 1.5)):
        c.disc(x, y, r, C('e8dcb8'))
    for r in range(13, 16):
        c.ring(16, 16, r, C('fff4d6', 40 - (r - 13) * 12))
    return c.img


def make_door_open():
    c = Canvas(16, 30)
    c.rect(0, 0, 16, 30, C('120c1a'))
    for y in range(30):
        c.rect(0, y, 16, 1, C('ffd27a', max(0, 80 - y * 2)))
    c.rect(13, 0, 3, 30, C('3a2418'))
    return c.img


def make_coin_pile():
    c = Canvas(20, 12)
    for (x, y) in ((3, 8), (8, 8), (13, 8), (5, 5), (10, 5), (8, 2)):
        c.rect(x, y, 5, 3, GOLD_D)
        c.rect(x, y, 5, 2, GOLD)
        c.px(x + 1, y, GOLD_L)
    outline(c.img, K)
    return c.img
