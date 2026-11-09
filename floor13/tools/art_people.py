"""Passenger sprites v2: 11 types x 18 frames in 32x32 cells, facing right, feet on row FEET.

Columns: idle 0-3 (breath + blink), walk 4-9 (full step cycle), wait 10-13 (each type's own
fidget), angry 14-15, happy 16-17 (hop). A JSON file next to the sheet tells the game where
each animation starts and how tall each type is (for speech bubbles).
"""
import json
from art_lib import C, Canvas, shade, mix

CW, CH = 32, 32
FEET = 30
CX = 16
ANIMS = [('idle', 4), ('walk', 6), ('wait', 4), ('angry', 2), ('happy', 2)]
ANIM_START = {}
_c = 0
for _n, _k in ANIMS:
    ANIM_START[_n] = _c
    _c += _k
COLS = _c
ORDER = ['guest', 'business', 'granny', 'kid', 'cat', 'rocker', 'robot', 'couple', 'inspector', 'bellhop', 'ghost']

INK = C('1a1020')
EYE = C('24142a')
MOUTH = C('8a2a3a')
BLUSH = C('ff8a9a', 150)
WHITE = C('f8f4ec')


def ramp(h):
    b = C(h) if isinstance(h, str) else h
    return (shade(b, 1.28), b, shade(b, 0.74), shade(b, 0.52))


def line(c, x0, y0, x1, y1, col, w=1):
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        c.rect(x0, y0, w, 1, col)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


# ---------------------------------------------------------------- poses

WALK = [  # back leg dx, front leg dx, back lift, front lift, body dy, back arm, front arm
    (-2, 2, 0, 0, 0, 'fwd', 'back'),
    (-1, 1, 0, 0, 1, 'fwd', 'back'),
    (0, 0, 0, 1, -1, 'down', 'down'),
    (2, -2, 0, 0, 0, 'back', 'fwd'),
    (1, -1, 0, 0, 1, 'back', 'fwd'),
    (0, 0, 1, 0, -1, 'down', 'down'),
]


def base_pose(anim, i):
    p = {'dy': 0, 'lean': 0, 'legs': (0, 0, 0, 0), 'arms': ('down', 'down'), 'eyes': 'open',
         'mouth': 'smile', 'head_dy': 0, 'anim': anim, 'i': i}
    if anim == 'idle':
        p['dy'] = [0, 0, 1, 0][i]
        if i == 3:
            p['eyes'] = 'blink'
    elif anim == 'walk':
        w = WALK[i]
        p['legs'] = w[:4]
        p['dy'] = w[4]
        p['arms'] = (w[5], w[6])
    elif anim == 'wait':
        p['dy'] = [0, 0, 1, 0][i]
    elif anim == 'angry':
        p['eyes'] = 'angry'
        p['mouth'] = 'frown'
        p['arms'] = ('hip', 'out') if i == 0 else ('out', 'hip')
        p['dy'] = [0, 1][i]
        p['legs'] = (0, 0, 0, 1) if i == 0 else (0, 0, 0, 0)
    elif anim == 'happy':
        p['eyes'] = 'happy'
        p['mouth'] = 'open'
        if i == 0:
            p['dy'] = 1
            p['arms'] = ('out', 'out')
        else:
            p['dy'] = -2
            p['arms'] = ('up', 'up')
            p['legs'] = (-1, 1, 1, 1)
    return p


BODIES = {
    'adult': {'head_top': 7, 'torso_top': 16, 'leg_top': 24, 'head_dx': 0, 'lean': 0, 'arm_w': 2},
    'kid': {'head_top': 11, 'torso_top': 20, 'leg_top': 26, 'head_dx': 0, 'lean': 0, 'arm_w': 1},
    'hunch': {'head_top': 9, 'torso_top': 17, 'leg_top': 24, 'head_dx': 1, 'lean': 0, 'arm_w': 2},
}

ARM = {  # hand offset from shoulder
    'down': (0, 6), 'fwd': (2, 5), 'back': (-2, 5), 'up': (4, -6), 'out': (4, 2), 'chest': (-2, 4),
    'hold': (3, 4), 'eye': (2, -2), 'brow': (1, -5), 'hip': (2, 3),
}


# ---------------------------------------------------------------- humanoid

def human(c, L, P, ox=0):
    """Draws a person; returns geometry (head box, hands, torso) for props."""
    b = BODIES[L.get('body', 'adult')]
    dy = P['dy']
    lean = P['lean'] + b['lean'] + ox
    feet = FEET
    hip = b['leg_top'] + dy
    tt = b['torso_top'] + dy
    ht = b['head_top'] + dy + P.get('head_dy', 0)
    tx = CX - 4 + lean
    hx = CX - 4 + lean + b['head_dx']
    skin = ramp(L['skin'])
    pants = ramp(L.get('pants', '3b4a6b'))
    shoes = ramp(L.get('shoes', '2b2030'))
    shirt = ramp(L['shirt'])
    sleeve = ramp(L.get('sleeve', L['shirt']))
    legs = L.get('legs', 'pants')
    bdx, fdx, bl, fl = P['legs']
    g = {'hx': hx, 'ht': ht, 'tx': tx, 'tt': tt, 'hip': hip, 'feet': feet}

    # legs (back leg darker)
    for k, (lx, dx, lift) in enumerate(((tx + 2, bdx, bl), (tx + 5, fdx, fl))):
        fy = feet - lift
        n = max(1, fy - hip - 1)
        for j, y in enumerate(range(hip, fy)):
            x = lx + round(dx * j / n)
            col = pants[2] if k == 0 else pants[1]
            if legs == 'shorts' and y >= hip + 2:
                col = skin[2] if k == 0 else skin[1]
            c.rect(x, y, 2, 1, col)
            if k == 1 and legs != 'shorts':
                c.px(x + 1, y, pants[2])
        sx = lx + dx
        c.rect(sx, fy, 3, 1, shoes[2] if k == 0 else shoes[1])
        if k == 1:
            c.px(sx + 2, fy, shoes[0])
        if legs == 'jeans' and k == 1:
            c.px(lx + round(dx * 0.5), hip + 3, pants[0])

    if legs in ('skirt', 'dress'):
        sk = ramp(L.get('skirt', L.get('pants')))
        top = tt + (5 if legs == 'skirt' else 4)
        bottom = feet - (2 if legs == 'skirt' else 1)
        for j, y in enumerate(range(top, bottom + 1)):
            w = 9 + j // 2
            x0 = tx + 4 - w // 2
            c.rect(x0, y, w, 1, sk[1])
            c.px(x0 + w - 1, y, sk[2])
            c.px(x0, y, sk[0])
            if (j + P['i']) % 4 == 0 and P['anim'] == 'walk':
                c.px(x0 + w // 2, y, sk[2])
        c.rect(tx + 4 - 4, bottom, 9 + (bottom - top) // 2, 1, sk[2])

    # back arm
    g['back_hand'] = _arm(c, tx, tt + 1, P['arms'][0], sleeve, skin, b['arm_w'], back=True)

    # torso: rounded shoulders, light from top-left
    th = hip - tt
    for j in range(th):
        a, e = (1, 7) if j == 0 else (0, 8)
        c.hline(tx + a, tx + e, tt + j, shirt[1])
        c.px(tx + a, tt + j, shirt[0])
        c.px(tx + e, tt + j, shirt[2])
        c.px(tx + e - 1, tt + j, shirt[2] if j > 1 else shirt[1])
    c.hline(tx + 1, tx + 6, tt, shirt[0])
    pat = L.get('pattern')
    if pat == 'flowers':
        for (x, y) in ((2, 1), (5, 2), (3, 4), (6, 5), (1, 6), (4, 7)):
            if y < th:
                c.px(tx + x, tt + y, C(L.get('pattern_col', 'ffe066')))
                c.px(tx + x + 1, tt + y, shade(C(L.get('pattern_col', 'ffe066')), 0.8))
    elif pat == 'stripes':
        for y in range(0, th, 2):
            c.hline(tx, tx + 8, tt + y, C(L.get('pattern_col', 'f4f0e8')))
    if L.get('jacket'):
        jk = ramp(L['jacket'])
        for j in range(th):
            a, e = (1, 7) if j == 0 else (0, 8)
            w_open = max(0, 2 - j // 2) if j < 4 else 0
            for x in range(tx + a, tx + e + 1):
                if abs(x - (tx + 4)) > w_open:
                    c.px(x, tt + j, jk[1])
            c.px(tx + a, tt + j, jk[0])
            c.px(tx + e, tt + j, jk[2])
        # lapels and shirt V
        for j in range(3):
            c.px(tx + 4 - (2 - j), tt + j, jk[2])
            c.px(tx + 4 + (2 - j), tt + j, jk[3])
        c.rect(tx + 4 - 1, tt, 3, 1, C(L.get('collar', 'f4f0e8')))
        c.px(tx + 4, tt + 1, C(L.get('collar', 'f4f0e8')))
        if L.get('tie'):
            tie = ramp(L['tie'])
            c.px(tx + 4, tt + 1, tie[1])
            c.rect(tx + 4, tt + 2, 1, 3, tie[1])
            c.px(tx + 4, tt + 5, tie[2])
        for y in (5, 7):
            if y < th:
                c.px(tx + 5, tt + y, jk[0])
    if L.get('buttons'):
        for y in range(1, th, 2):
            c.px(tx + 4, tt + y, C(L['buttons']))
    if L.get('belt'):
        c.hline(tx, tx + 8, hip - 1, C(L['belt']))
        c.px(tx + 5, hip - 1, C('ffe08a'))

    # head
    _head(c, hx, ht, L, P, skin)
    g['front_hand'] = _arm(c, tx + 7, tt + 1, P['arms'][1], sleeve, skin, b['arm_w'], back=False)
    return g


def _arm(c, sx, sy, state, sleeve, skin, w, back):
    dx, dy = ARM.get(state, ARM['down'])
    hx, hy = sx + dx, sy + dy
    col = sleeve[2] if back else sleeve[1]
    line(c, sx, sy, hx, hy - (1 if dy > 0 else -1), col, w)
    if not back:
        line(c, sx + w - 1, sy + 1, hx + w - 1, hy - (1 if dy > 0 else -1), sleeve[2], 1)
    c.rect(hx, hy, w, 2 if w > 1 else 1, skin[2] if back else skin[1])
    return (hx, hy)


HEAD_ROWS = [(2, 6), (1, 7), (0, 8), (0, 8), (0, 8), (0, 8), (0, 8), (1, 7), (2, 6)]


def _head(c, hx, ht, L, P, skin):
    for j, (a, e) in enumerate(HEAD_ROWS):
        c.hline(hx + a, hx + e, ht + j, skin[1])
    c.vline(hx, ht + 2, ht + 6, skin[2])
    c.px(hx + 1, ht + 7, skin[2])
    c.hline(hx + 2, hx + 6, ht + 8, skin[2])
    c.px(hx + 6, ht + 2, skin[0])
    c.px(hx + 7, ht + 3, skin[0])
    c.px(hx + 3, ht + 4, skin[2])        # ear
    c.px(hx + 3, ht + 5, skin[2])
    c.px(hx + 2, ht + 5, skin[3])
    angry_red = P['eyes'] == 'angry'
    if angry_red:
        for j in range(3, 7):
            for x in range(hx + 4, hx + 9):
                c.px(x, ht + j, C('e8584a', 90))
    ex1, ex2, ey = hx + 5, hx + 7, ht + 4
    e = P['eyes']
    if e == 'open':
        c.vline(ex1, ey, ey + 1, EYE)
        c.vline(ex2, ey, ey + 1, EYE)
        c.px(ex2, ey, C('6a5a8a'))
    elif e == 'blink':
        c.px(ex1, ey + 1, EYE)
        c.px(ex2, ey + 1, EYE)
        c.px(ex1 - 1, ey + 1, skin[2])
    elif e == 'happy':
        c.px(ex1, ey, EYE)
        c.px(ex2, ey, EYE)
        c.px(ex1 - 1, ey + 1, EYE)
        c.px(ex2 + 1, ey + 1, EYE)
    elif e == 'angry':
        c.px(ex1, ey + 1, EYE)
        c.px(ex2, ey + 1, EYE)
        c.px(ex1 - 1, ey - 1, EYE)
        c.px(ex1, ey, EYE)
        c.px(ex2 + 1, ey - 1, EYE)
        c.px(ex2, ey, EYE)
    elif e == 'down':
        c.px(ex1, ey + 1, EYE)
        c.px(ex2, ey + 1, EYE)
    m = P['mouth']
    my = ht + 7
    if m == 'smile':
        c.px(hx + 6, my, MOUTH)
        c.px(hx + 7, my - 1, shade(skin[1], 0.8))
    elif m == 'open':
        c.rect(hx + 6, my - 1, 2, 2, MOUTH)
        c.px(hx + 6, my, C('ff7a8a'))
    elif m == 'frown':
        c.hline(hx + 5, hx + 7, my, EYE)
        c.px(hx + 5, my - 1, skin[2])
    elif m == 'o':
        c.rect(hx + 6, my - 1, 2, 2, MOUTH)
    elif m == 'flat':
        c.hline(hx + 6, hx + 7, my, MOUTH)
    if e != 'angry':
        c.px(hx + 8, ht + 6, BLUSH)
        c.px(hx + 4, ht + 6, BLUSH)
    if L.get('glasses'):
        gl = C(L['glasses'])
        c.hline(ex1 - 1, ex2 + 1, ey - 1, gl)
        c.px(ex1 - 1, ey, gl)
        c.px(ex1 + 1, ey, gl)
        c.px(ex2 + 1, ey, gl)
        c.hline(hx + 3, ex1 - 2, ey - 1, shade(gl, 0.8))
        c.px(ex1, ey - 1, C('d8e8ff'))
        c.px(ex2, ey - 1, C('d8e8ff'))
    if L.get('shades'):
        c.rect(ex1 - 1, ey - 1, 5, 2, C('141018'))
        c.px(ex2, ey - 1, C('7a8ac8'))
        c.px(ex1, ey - 1, C('4a5a90'))
        c.hline(hx + 2, ex1 - 1, ey - 1, C('141018'))
    if L.get('mustache'):
        mu = ramp(L['mustache'])
        c.hline(hx + 5, hx + 8, ht + 6, mu[1])
        c.px(hx + 4, ht + 7, mu[2])
    if L.get('monocle'):
        for (x, y) in ((0, -1), (1, 0), (1, 1), (0, 2), (-1, 0), (-1, 1)):
            c.px(ex2 + x, ey + y, C('f2c14e'))
        c.px(ex2 - 1, ey + 2, C('b8862a'))
        c.vline(ex2 - 2, ey + 3, ey + 5, C('b8862a'))
    _hair(c, hx, ht, L, P)


def _hair(c, hx, ht, L, P):
    if not L.get('hair'):
        return
    h = ramp(L['hair'])
    st = L.get('hair_style', 'short')
    if st in ('short', 'slick'):
        c.hline(hx + 2, hx + 6, ht - 1, h[1])
        c.hline(hx + 1, hx + 7, ht, h[1])
        c.hline(hx, hx + 8, ht + 1, h[1])
        c.rect(hx, ht + 2, 3, 2, h[2])
        c.px(hx, ht + 4, h[2])
        c.px(hx + 8, ht + 2, h[1])
        c.hline(hx + 3, hx + 5, ht - 1, h[0])
        if st == 'slick':
            c.hline(hx + 2, hx + 6, ht, h[0])
            c.px(hx + 7, ht + 1, h[0])
    elif st == 'bun':
        c.hline(hx + 1, hx + 7, ht - 1, h[1])
        c.rect(hx, ht, 9, 2, h[1])
        c.rect(hx, ht + 2, 3, 4, h[2])
        c.hline(hx + 3, hx + 6, ht, h[0])
        for (x, y) in ((-2, -3), (-1, -3), (0, -3), (-3, -2), (1, -2), (-3, -1), (1, -1), (-2, 0), (-1, 0), (0, 0)):
            c.px(hx + x + 1, ht + y, h[1])
        c.rect(hx - 1, ht - 2, 2, 2, h[1])
        c.px(hx - 1, ht - 3, h[0])
    elif st == 'spiky':
        c.rect(hx, ht + 1, 3, 3, h[2])
        c.hline(hx + 1, hx + 7, ht, h[1])
        heights = [3, 5, 4, 6, 4, 3]
        for k, hh in enumerate(heights):
            x = hx + 2 + k
            c.vline(x, ht - hh, ht, h[1] if k % 2 else h[0])
        c.px(hx + 8, ht + 1, h[1])
    elif st == 'long':
        c.hline(hx + 2, hx + 6, ht - 1, h[1])
        c.rect(hx, ht, 9, 2, h[1])
        c.hline(hx + 3, hx + 6, ht, h[0])
        c.rect(hx - 1, ht + 1, 3, 10, h[1])
        c.rect(hx - 1, ht + 6, 2, 5, h[2])
        c.px(hx + 8, ht + 2, h[1])


def hat(c, g, kind, col):
    hx, ht = g['hx'], g['ht']
    r = ramp(col)
    if kind == 'sunhat':
        c.hline(hx - 2, hx + 10, ht, r[1])
        c.hline(hx - 1, hx + 9, ht + 1, r[2])
        c.rect(hx + 1, ht - 3, 7, 3, r[1])
        c.hline(hx + 2, hx + 6, ht - 3, r[0])
        c.hline(hx + 1, hx + 7, ht - 1, C('d84a4a'))
        c.px(hx + 2, ht - 1, C('ffd84a'))
    elif kind == 'cap':
        c.rect(hx + 1, ht - 2, 7, 2, r[1])
        c.hline(hx, hx + 8, ht, r[1])
        c.hline(hx + 2, hx + 5, ht - 2, r[0])
        c.rect(hx - 3, ht + 1, 4, 1, r[2])
        c.px(hx + 4, ht - 3, r[2])
        c.rect(hx + 5, ht - 1, 2, 1, WHITE)
    elif kind == 'tophat':
        c.hline(hx - 1, hx + 9, ht - 1, r[1])
        c.hline(hx, hx + 8, ht, r[2])
        c.rect(hx + 1, ht - 6, 7, 5, r[1])
        c.vline(hx + 2, ht - 6, ht - 2, r[0])
        c.hline(hx + 1, hx + 7, ht - 2, C('9a2a3a'))
    elif kind == 'pillbox':
        c.rect(hx + 2, ht - 3, 6, 3, r[1])
        c.hline(hx + 2, hx + 7, ht - 1, C('f2c14e'))
        c.hline(hx + 3, hx + 6, ht - 3, r[0])
        c.vline(hx + 8, ht - 1, ht + 3, C('2a2030'))


# ---------------------------------------------------------------- types

def draw_guest(c, anim, i):
    P = base_pose(anim, i)
    flash = False
    if anim == 'wait':      # takes a photo
        P['arms'] = ('hold', 'eye') if i in (1, 2) else ('down', 'hold')
        P['eyes'] = 'blink' if i == 2 else 'open'
        flash = i == 2
    L = dict(skin='f2c9a0', hair='8a5a2b', shirt='f08a3c', pattern='flowers', pattern_col='ffe066',
             pants='c9b27c', legs='shorts', shoes='8a5a34')
    g = human(c, L, P)
    hat(c, g, 'sunhat', C('e9cf7a'))
    fx, fy = g['front_hand']
    if anim == 'wait' and i in (1, 2):
        c.rect(g['hx'] + 7, g['ht'] + 3, 4, 3, C('2a2230'))
        c.px(g['hx'] + 10, g['ht'] + 4, C('8fd0ff'))
        if flash:
            for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, -2), (-2, 2), (2, 2), (-2, -2)):
                c.px(g['hx'] + 12 + dx, g['ht'] + 2 + dy, C('fff8c0'))
    else:
        tx, tt = g['tx'], g['tt']
        c.rect(tx + 3, tt + 3, 3, 2, C('2a2230'))
        c.px(tx + 5, tt + 3, C('8fd0ff'))
        line(c, tx + 1, tt, tx + 3, tt + 3, C('2a2230'))


def draw_business(c, anim, i):
    P = base_pose(anim, i)
    if anim == 'wait':      # checks the watch, taps a foot
        P['arms'] = ('down', 'chest')
        P['head_dy'] = 1 if i in (1, 2) else 0
        P['eyes'] = 'down' if i in (1, 2) else 'open'
        P['mouth'] = 'flat'
        P['legs'] = (0, 0, 0, 1 if i % 2 else 0)
    L = dict(skin='d79a6b', hair='2a2030', hair_style='slick', shirt='2c3a66', jacket='2c3a66',
             tie='d0383a', pants='243055', shoes='151018', sleeve='2c3a66')
    g = human(c, L, P)
    bx, by = g['back_hand']
    fx, fy = g['front_hand']
    case_hand = (fx, fy) if P['arms'][1] in ('down', 'fwd', 'back') else (bx, by)
    hx, hy = case_hand
    br = ramp('7a4a28')
    c.rect(hx - 2, hy + 2, 6, 4, br[1])
    c.hline(hx - 2, hx + 3, hy + 2, br[0])
    c.hline(hx - 2, hx + 3, hy + 5, br[2])
    c.px(hx, hy + 1, br[3])
    c.px(hx + 1, hy + 1, br[3])
    c.px(hx + 1, hy + 3, C('f2c14e'))
    if anim == 'wait':
        c.px(fx - 1, fy + 1, C('f2c14e'))   # watch
        c.px(fx, fy + 1, C('d0e8ff'))


def draw_granny(c, anim, i):
    P = base_pose(anim, i)
    knit = anim == 'wait'
    if knit:
        P['arms'] = ('hold', 'hold')
        P['eyes'] = 'down'
        P['head_dy'] = 1
    L = dict(body='hunch', skin='f2c9a0', hair='dcd8e6', hair_style='bun', shirt='8a5aa8', sleeve='8a5aa8',
             legs='skirt', skirt='d77a9a', pants='d77a9a', shoes='4a3040', glasses='6a5a7a', buttons='f2e6ff')
    g = human(c, L, P)
    fx, fy = g['front_hand']
    if knit:
        # needles move, yarn ball at her feet, a scarf grows
        k = i % 2
        line(c, fx - 3, fy - 2 + k, fx + 2, fy + 1 - k, C('c8c0d8'))
        line(c, fx - 2, fy + 2 - k, fx + 3, fy - 1 + k, C('c8c0d8'))
        c.rect(fx - 2, fy + 1, 4, 2 + i // 2, C('e84a6a'))
        c.disc(g['tx'] - 2, FEET - 1, 1.6, C('e84a6a'))
        c.px(g['tx'] - 2, FEET - 2, C('ff8aa8'))
    elif anim not in ('happy', 'angry'):
        cane = ramp('7a4a2a')
        c.vline(fx + 2, fy, FEET, cane[1])
        c.px(fx + 1, fy, cane[1])
        c.px(fx + 2, fy - 1, cane[0])


def draw_kid(c, anim, i):
    P = base_pose(anim, i)
    if anim == 'wait':      # hops on the spot
        P['dy'] = [0, -2, -3, -1][i]
        P['legs'] = (0, 0, 0, 0) if i == 0 else (-1, 1, 1, 1)
        P['arms'] = ('down', 'up') if i in (1, 2) else ('down', 'out')
        P['mouth'] = 'open'
    L = dict(body='kid', skin='e8b48a', hair='5a3a1a', shirt='4a7ad8', pattern='stripes', pattern_col='f4f0e8',
             pants='3a5a3a', legs='shorts', shoes='d84a3a')
    g = human(c, L, P)
    hat(c, g, 'cap', C('e04848'))
    fx, fy = g['front_hand']
    if anim != 'happy':
        c.vline(fx, fy - 4, fy - 1, WHITE)
        c.disc(fx, fy - 6, 1.5, C('ff6fae'))
        c.px(fx - 1, fy - 7, C('ffd0e6'))
        c.px(fx + 1, fy - 6, C('ff9ad0'))


def draw_cat(c, anim, i):
    body = ramp('2a2238')
    eye = C('9cff6a')
    pink = C('ff9ab0')
    dy = 0
    arch = 0
    if anim == 'idle':
        dy = [0, 0, 0, 0][i]
    elif anim == 'walk':
        dy = [0, -1, 0, 0, -1, 0][i]
    elif anim == 'angry':
        arch = 2 + i
    elif anim == 'happy':
        dy = [0, -3][i]
    by = 23 + dy
    x0 = 8
    # body
    for j in range(5):
        a = 1 if j in (0, 4) else 0
        c.hline(x0 + a, x0 + 11 - a, by + j - (arch if 3 < j + 3 < 8 and j < 2 else 0), body[1])
    if arch:
        for k in range(arch):
            c.hline(x0 + 2, x0 + 9, by - 1 - k, body[1])
        for x in range(x0 + 2, x0 + 10, 2):
            c.px(x, by - 1 - arch, body[1])
    c.hline(x0 + 2, x0 + 8, by, body[0])
    c.hline(x0 + 1, x0 + 10, by + 4, body[2])
    # legs (4), walk cycle
    legs = [(x0 + 1, 0), (x0 + 3, 0), (x0 + 8, 0), (x0 + 10, 0)]
    if anim == 'walk':
        ph = [(-1, 1, 1, -1), (0, 1, 0, -1), (1, 0, -1, 0), (1, -1, -1, 1), (0, -1, 0, 1), (-1, 0, 1, 0)][i]
        legs = [(lx, ph[k]) for k, (lx, _) in enumerate(legs)]
    sit = anim == 'wait'
    for k, (lx, dx) in enumerate(legs):
        col = body[2] if k in (0, 2) else body[1]
        top = by + 4
        if sit and k >= 2:
            continue
        for y in range(top, FEET + 1):
            c.px(lx + (dx if y > top + 1 else 0), y, col)
    if sit:
        c.rect(x0 + 7, by + 2, 4, FEET - by - 1, body[1])   # haunches
    # head
    hx = x0 + 9
    hy = by - 4 + (2 if sit and i in (1, 2) else 0)
    c.rect(hx, hy, 6, 5, body[1])
    c.hline(hx + 1, hx + 4, hy, body[0])
    for (x, y) in ((0, -1), (1, -2), (1, -1), (4, -1), (4, -2), (5, -1)):
        c.px(hx + x, hy + y, body[1])
    c.px(hx + 1, hy - 1, pink)
    c.px(hx + 4, hy - 1, pink)
    if anim == 'angry':
        c.px(hx + 2, hy + 2, C('ff5050'))
        c.px(hx + 4, hy + 2, C('ff5050'))
        c.hline(hx + 2, hx + 4, hy + 4, WHITE)
    elif anim == 'happy' or (anim == 'idle' and i == 3) or (sit and i in (1, 2)):
        c.px(hx + 2, hy + 2, EYE)
        c.px(hx + 4, hy + 2, EYE)
        c.px(hx + 3, hy + 3, pink)
    else:
        c.vline(hx + 2, hy + 1, hy + 2, eye)
        c.vline(hx + 4, hy + 1, hy + 2, eye)
        c.px(hx + 3, hy + 3, pink)
    for k in (-1, 1):
        c.px(hx + 6, hy + 2 + k, C('8a8098', 160))
    if sit and i in (1, 2):   # licks a paw
        c.rect(hx + 3, hy + 4, 2, 2, body[1])
        c.px(hx + 4, hy + 4, pink)
    # tail
    sway = {'idle': [0, 1, 2, 1], 'walk': [0, 1, 1, 0, -1, -1], 'wait': [1, 2, 2, 1], 'angry': [0, 0], 'happy': [1, 2]}[anim][i]
    tx, ty = x0, by + 1
    if anim == 'angry':
        for y in range(ty - 7, ty + 1):
            c.rect(tx - 1, y, 2, 1, body[1])
        c.rect(tx - 2, ty - 7, 3, 3, body[1])
    else:
        pts = [(tx, ty), (tx - 1, ty - 1), (tx - 2, ty - 2), (tx - 2, ty - 3), (tx - 2 + sway // 2, ty - 4),
               (tx - 1 + sway, ty - 5), (tx + sway, ty - 6)]
        for (x, y) in pts:
            c.px(x, y, body[1])
    if anim == 'happy' and i == 1:
        for (x, y) in ((hx + 7, hy - 4), (hx + 8, hy - 4), (hx + 7, hy - 3), (hx + 8, hy - 3), (hx + 9, hy - 4)):
            c.px(x, y, C('ff6a8a'))


def draw_rocker(c, anim, i):
    P = base_pose(anim, i)
    air = anim == 'wait'
    if air:      # air guitar
        P['arms'] = ('hold', 'out' if i % 2 == 0 else 'hip')
        P['head_dy'] = [0, 1, 0, 1][i]
        P['mouth'] = 'open'
        P['lean'] = -1 if i % 2 else 0
    L = dict(skin='f2c9a0', hair='b04ae0', hair_style='spiky', shirt='2a2230', jacket='1f1a26',
             collar='3a3048', sleeve='1f1a26', pants='4a6aa0', legs='jeans', shoes='101010', shades=True)
    if not air:
        g0 = {'tx': CX - 4 + P['lean'], 'tt': BODIES['adult']['torso_top'] + P['dy']}
        gt = ramp('d83a3a')
        tx, tt = g0['tx'], g0['tt']
        line(c, tx + 1, tt - 6, tx + 2, tt + 2, C('7a4a2a'))
        c.rect(tx - 2, tt + 2, 5, 6, gt[1])
        c.rect(tx - 1, tt + 1, 3, 1, gt[1])
        c.px(tx, tt + 4, C('2a1a1a'))
        c.rect(tx, tt - 7, 3, 1, C('2a2030'))
    g = human(c, L, P)
    tx, tt = g['tx'], g['tt']
    c.px(tx + 6, tt + 1, C('d8d8e0'))
    c.px(tx + 6, tt + 3, C('d8d8e0'))
    c.px(tx + 1, tt + 5, C('d8d8e0'))
    if air:
        bx, by = g['back_hand']
        # imaginary guitar sparkle lines
        for k in range(3):
            c.px(tx + 10 + k, tt + 2 - k + (i % 2), C('ffe14f', 200))
        c.px(tx + 12, tt - 2 + (i % 2) * 2, C('ff6ad5'))


def draw_robot(c, anim, i):
    body = ramp('9aa8b8')
    scr = C('162434')
    eye = C('6af0ff')
    dy = 0
    if anim in ('idle', 'wait'):
        dy = [0, 0, 1, 0][i]
    elif anim == 'walk':
        dy = [0, -1, 0, 0, -1, 0][i]
    elif anim == 'happy':
        dy = [1, -2][i]
    elif anim == 'angry':
        dy = i
    top = 10 + dy
    # treads
    tr = ramp('2a2a34')
    c.rect(9, 26, 14, 4, tr[1])
    c.hline(9, 22, 26, tr[0])
    ph = i % 3 if anim == 'walk' else 0
    for x in range(10 + ph, 22, 3):
        c.px(x, 28, C('8a8a9a'))
    c.disc(10, 28, 1.2, tr[2])
    c.disc(21, 28, 1.2, tr[2])
    c.rect(12, top + 13, 8, 26 - (top + 13), body[2])
    # body box
    c.rect(9, top + 7, 14, 7, body[1])
    c.hline(10, 21, top + 7, body[0])
    c.vline(22, top + 7, top + 13, body[2])
    c.vline(9, top + 8, top + 13, body[0])
    c.rect(12, top + 9, 8, 3, C('f2c14e'))
    c.hline(12, 19, top + 11, C('b8862a'))
    c.px(13, top + 10, C('fff0a0'))
    # head + screen
    c.rect(10, top, 12, 7, body[1])
    c.hline(11, 20, top, body[0])
    c.vline(21, top, top + 6, body[2])
    c.rect(12, top + 1, 8, 5, scr)
    if anim == 'angry':
        col = C('ff4a4a')
        for (x, y) in ((13, 2), (14, 3), (15, 2), (13, 4)):
            c.px(x, top + y, col)
        for (x, y) in ((17, 2), (18, 3), (19, 2), (19, 4)):
            c.px(x, top + y, col)
    elif anim == 'happy':
        for (x, y) in ((14, 2), (15, 2), (14, 3), (15, 3), (16, 4), (17, 3), (18, 3), (17, 2), (18, 2)):
            c.px(x, top + y, C('ff6a9a'))
    elif anim == 'wait':
        for k in range(3):
            c.px(13 + k * 3, top + 3, eye if k <= i % 3 else C('2a4a5a'))
    elif anim == 'idle' and i == 3:
        c.hline(13, 14, top + 3, eye)
        c.hline(17, 18, top + 3, eye)
    else:
        look = 1 if anim == 'walk' else 0
        c.rect(13 + look, top + 2, 2, 2, eye)
        c.rect(17 + look, top + 2, 2, 2, eye)
    c.px(12, top + 1, C('3a5a7a'))
    # antenna
    c.vline(16, top - 4, top - 1, body[2])
    blink = (i % 2 == 0) or anim == 'angry'
    c.px(16, top - 5, C('ff4a4a') if blink else C('ffb0b0'))
    if anim == 'wait':
        c.px(16 + [1, 0, -1, 0][i], top - 5, C('ff4a4a'))
    # arms holding the parcel (or up)
    if anim in ('happy', 'angry'):
        for sx in (8, 23):
            c.vline(sx, top + 2, top + 8, body[2])
            c.rect(sx - 1 if sx < 16 else sx, top + 1, 2, 2, body[1])
    else:
        c.hline(22, 24, top + 9, body[2])
        pr = ramp('c8925a')
        c.rect(21, top + 4, 6, 5, pr[1])
        c.hline(21, 26, top + 4, pr[0])
        c.hline(21, 26, top + 6, pr[2])
        c.px(23, top + 6, C('8a5a2a'))


def draw_couple(c, anim, i):
    P1 = base_pose(anim, i)
    P2 = base_pose(anim, (i + 3) % 6 if anim == 'walk' else i)
    if anim == 'wait':      # lean in, a heart pops up
        P1['lean'] = 1 if i in (1, 2) else 0
        P2['lean'] = -1 if i in (1, 2) else 0
        P1['eyes'] = P2['eyes'] = 'happy' if i in (1, 2) else 'open'
    P1['arms'] = (P1['arms'][0], 'hold' if anim not in ('happy', 'angry') else P1['arms'][1])
    P2['arms'] = ('hold' if anim not in ('happy', 'angry') else P2['arms'][0], P2['arms'][1])
    groom = dict(skin='d79a6b', hair='2a2030', hair_style='slick', shirt='1a1622', jacket='1a1622', tie='1a1622',
                 pants='1a1622', shoes='101010', sleeve='1a1622')
    bride = dict(skin='f2c9a0', hair='e0b050', hair_style='long', shirt='f4f0f8', sleeve='f4f0f8',
                 legs='dress', skirt='f4f0f8', pants='f4f0f8', shoes='e0e0f0')
    g1 = human(c, groom, P1, ox=-6)
    c.px(g1['tx'] + 6, g1['tt'] + 1, C('ff7aa8'))   # boutonniere
    g2 = human(c, bride, P2, ox=5)
    hx, ht = g2['hx'], g2['ht']
    c.rect(hx - 2, ht - 1, 3, 11, C('e8f0ff', 190))
    c.px(hx + 3, ht - 1, C('ffffff'))
    fx, fy = g2['front_hand']
    if anim != 'happy':
        c.rect(fx, fy - 1, 3, 3, C('ff7aa8'))
        c.px(fx + 1, fy - 2, C('7ad87a'))
        c.px(fx + 2, fy - 1, C('ffd0e0'))
    if anim == 'wait' and i in (1, 2):
        hx0 = CX - 1
        hy0 = 2 - i
        for (x, y) in ((0, 1), (1, 0), (2, 1), (3, 0), (4, 1), (1, 2), (2, 2), (3, 2), (2, 3), (0, 1)):
            c.px(hx0 + x, hy0 + y + 2, C('ff4a7a'))


def draw_inspector(c, anim, i):
    P = base_pose(anim, i)
    if anim == 'happy':
        P['dy'] = [1, -1][i]
    write = anim == 'wait'
    if write:      # writes on the clipboard, then peers through the monocle
        P['arms'] = ('chest', 'chest' if i < 3 else 'down')
        P['eyes'] = 'down' if i < 3 else 'open'
        P['mouth'] = 'flat'
    L = dict(skin='f2c9a0', hair='8a8a8a', shirt='5a5a6a', jacket='5a5a6a', tie='2a2a3a', sleeve='5a5a6a',
             pants='4a4a58', shoes='151018', mustache='d8d8d8', monocle=True)
    g = human(c, L, P)
    hat(c, g, 'tophat', C('1a1622'))
    tx, tt = g['tx'], g['tt']
    c.px(tx + 2, tt + 2, C('f2c14e'))
    c.px(tx + 2, tt + 3, C('b8862a'))
    if anim not in ('happy', 'angry'):
        bx, by = g['back_hand'] if write else g['front_hand']
        cx0 = bx + (1 if write else 0)
        cb = ramp('c8925a')
        c.rect(cx0, by - 3, 5, 6, cb[1])
        c.rect(cx0 + 1, by - 2, 3, 4, WHITE)
        c.px(cx0 + 2, by - 4, C('8a8a9a'))
        for k in range((i % 3) + 1 if write else 2):
            c.hline(cx0 + 1, cx0 + 3, by - 1 + k, C('6a6a8a'))
        if write and i < 3:
            fx, fy = g['front_hand']
            line(c, fx, fy, fx - 1 + (i % 2), fy - 3, C('2a2030'))


def draw_bellhop(c, anim, i):
    P = base_pose(anim, i)
    P['lean'] = -6
    push = anim in ('idle', 'walk', 'wait')
    if push:
        P['arms'] = ('out', 'out')
    if anim == 'wait':      # wipes the brow, catches breath
        P['arms'] = ('out', 'brow' if i in (1, 2) else 'out')
        P['eyes'] = 'blink' if i in (1, 2) else 'open'
        P['mouth'] = 'o'
    L = dict(skin='d79a6b', hair='2a2030', shirt='c83a3a', sleeve='c83a3a', pants='2a2030', shoes='151018',
             belt='f2c14e', buttons='f2c14e')
    # cart in front
    cart = ramp('f2c14e')
    cx0 = 18
    wob = [0, 0, 1, 0][i] if anim == 'wait' else 0
    c.hline(cx0, cx0 + 11, 27, cart[1])
    c.hline(cx0, cx0 + 11, 28, cart[2])
    c.vline(cx0, 14, 27, cart[1])
    c.vline(cx0 + 1, 14, 27, cart[2])
    c.px(cx0, 13, cart[0])
    for wx in (cx0 + 2, cx0 + 9):
        c.disc(wx + 1, 29.5, 1.3, C('2a2a34'))
        c.px(wx + 1 + (i % 2 if anim == 'walk' else 0), 29, C('8a8a9a'))
    s1 = ramp('7a3a8a')
    c.rect(cx0 + 2, 20 - wob, 9, 7, s1[1])
    c.hline(cx0 + 2, cx0 + 10, 20 - wob, s1[0])
    c.vline(cx0 + 10, 20 - wob, 26 - wob, s1[2])
    c.hline(cx0 + 5, cx0 + 7, 19 - wob, s1[3])
    c.vline(cx0 + 6, 21 - wob, 26 - wob, C('f2c14e'))
    s2 = ramp('3a7a5a')
    c.rect(cx0 + 3, 14 - wob, 7, 6, s2[1])
    c.hline(cx0 + 3, cx0 + 9, 14 - wob, s2[0])
    c.vline(cx0 + 9, 14 - wob, 19 - wob, s2[2])
    c.hline(cx0 + 5, cx0 + 7, 13 - wob, s2[3])
    c.rect(cx0 + 4, 16 - wob, 2, 2, C('f4f0e8'))
    g = human(c, L, P)
    hat(c, g, 'pillbox', C('c83a3a'))
    if anim == 'wait' and i in (1, 2):
        c.px(g['hx'] + 9, g['ht'] + 2, C('8fd0ff'))
        c.px(g['hx'] + 9, g['ht'] + 4 + i, C('8fd0ff'))


def draw_ghost(c, anim, i):
    w = C('eef0ff', 220)
    s = C('b8c0e8', 220)
    hi = C('ffffff', 230)
    bob = 0
    lean = 0
    if anim == 'idle':
        bob = [0, -1, -1, 0][i]
    elif anim == 'walk':
        bob = [0, -1, -2, -1, 0, -1][i]
        lean = 1
    elif anim == 'wait':
        bob = [-1, -2, -2, -1][i]
    elif anim == 'happy':
        bob = [-1, -4][i]
    elif anim == 'angry':
        bob = [0, -1][i]
    top = 8 + bob
    cx = CX + lean
    rows = 16
    for y in range(rows):
        half = 4 if y < 2 else (5 if y < 5 else 6)
        if y == 0:
            half = 3
        off = lean if y > 8 else 0
        c.hline(cx - half - off, cx + half - 1 - off, top + y, w)
        c.px(cx - half - off, top + y, s)
        c.px(cx + half - 1 - off, top + y, shade(s, 0.95))
    c.hline(cx - 2, cx + 1, top, hi)
    c.px(cx - 3, top + 1, hi)
    # wavy hem
    ph = i % 3
    for k, x in enumerate(range(cx - 6 - lean, cx + 6 - lean, 2)):
        h = (1, 2, 3)[(k + ph) % 3]
        c.rect(x, top + rows, 2, h, w)
    # arms (sheet bumps)
    if anim in ('wait', 'angry', 'happy'):
        up = anim == 'happy' or (anim == 'wait' and i in (1, 2)) or anim == 'angry'
        for sx, d in ((cx - 7, -1), (cx + 6, 1)):
            c.rect(sx, top + (6 if up else 9), 2, 3, w)
            c.px(sx + (0 if d < 0 else 1), top + (5 if up else 8), w)
    ey = top + 5
    if anim == 'angry':
        c.rect(cx - 3, ey, 2, 2, EYE)
        c.rect(cx + 1, ey, 2, 2, EYE)
        c.px(cx - 4, ey - 1, EYE)
        c.px(cx + 3, ey - 1, EYE)
        c.rect(cx - 2, ey + 4, 4, 3, EYE)
        c.px(cx - 1, ey + 6, C('8a2a5a'))
    elif anim == 'happy':
        c.px(cx - 3, ey + 1, EYE)
        c.px(cx - 2, ey, EYE)
        c.px(cx + 1, ey, EYE)
        c.px(cx + 2, ey + 1, EYE)
        c.hline(cx - 1, cx, ey + 4, EYE)
        c.px(cx - 4, ey + 3, BLUSH)
        c.px(cx + 3, ey + 3, BLUSH)
    elif anim == 'wait' and i in (1, 2):
        c.rect(cx - 3, ey, 2, 2, EYE)
        c.rect(cx + 1, ey, 2, 2, EYE)
        c.rect(cx - 1, ey + 3, 2, 3, EYE)       # "Boo!"
    elif anim == 'idle' and i == 3:
        c.hline(cx - 3, cx - 2, ey + 1, EYE)
        c.hline(cx + 1, cx + 2, ey + 1, EYE)
        c.rect(cx - 1, ey + 4, 2, 1, EYE)
    else:
        c.rect(cx - 3 + lean, ey, 2, 3, EYE)
        c.rect(cx + 1 + lean, ey, 2, 3, EYE)
        c.px(cx - 3 + lean, ey, C('8a80b0'))
        c.px(cx + 1 + lean, ey, C('8a80b0'))
        c.rect(cx - 1 + lean, ey + 4, 2, 2, EYE)


DRAW = {
    'guest': draw_guest, 'business': draw_business, 'granny': draw_granny, 'kid': draw_kid,
    'cat': draw_cat, 'rocker': draw_rocker, 'robot': draw_robot, 'couple': draw_couple,
    'inspector': draw_inspector, 'bellhop': draw_bellhop, 'ghost': draw_ghost,
}


def outline_selective(img, ghost=False):
    """1px outline in a darkened tint of the neighbouring colour (softer than pure black)."""
    p = img.load()
    w, h = img.size
    marks = []
    for y in range(h):
        for x in range(w):
            if p[x, y][3] != 0:
                continue
            best = None
            for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and p[xx, yy][3] > 60:
                    best = p[xx, yy]
                    if dy == -1:      # pixel below an opaque one: ground side, darkest
                        break
            if best:
                if ghost:
                    marks.append((x, y, (150, 156, 220, 140)))
                else:
                    r, g, b, _ = best
                    k = 0.28
                    col = (int(r * k + 26 * (1 - k) * 0.6), int(g * k + 16 * (1 - k) * 0.6), int(b * k + 32 * (1 - k) * 0.6), 255)
                    marks.append((x, y, col))
    for x, y, col in marks:
        p[x, y] = col


def make_sheet():
    sheet = Canvas(CW * COLS, CH * len(ORDER))
    meta = {'cell': [CW, CH], 'feet': FEET, 'anims': {n: [ANIM_START[n], k] for n, k in ANIMS}, 'top': {}}
    for row, t in enumerate(ORDER):
        col = 0
        for anim, n in ANIMS:
            for i in range(n):
                cell = Canvas(CW, CH)
                DRAW[t](cell, anim, i)
                outline_selective(cell.img, ghost=(t == 'ghost'))
                cell.p = cell.img.load()
                if anim == 'idle' and i == 0:
                    ys = [y for y in range(CH) for x in range(CW) if cell.p[x, y][3] > 0]
                    meta['top'][t] = FEET - min(ys) + 1
                sheet.paste(cell, col * CW, row * CH)
                col += 1
    return sheet.img, meta


def write(out_dir):
    img, meta = make_sheet()
    img.save(out_dir + '/passengers.png')
    with open(out_dir + '/passengers.json', 'w') as f:
        json.dump(meta, f, indent=1)
    return img, meta
