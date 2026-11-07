"""Passenger sprites: 11 types x 8 frames, 24x28 cells, facing right, feet on row 26."""
from art_lib import C, Canvas, shade, outline

CW, CH = 24, 28
FRAMES = 8  # 0 idle, 1 idle-breath, 2..5 walk, 6 happy, 7 angry
OUTLINE = C('1a1020')

SKIN_L = C('f2c9a0')
SKIN_M = C('d79a6b')
SKIN_D = C('9c6343')
DARK = C('1d1628')


def leg_offsets(f):
    """(back_leg_dx_bottom, front_leg_dx_bottom, together, bob)"""
    return {2: (-1, 1, False, 0), 3: (0, 0, True, -1), 4: (1, -1, False, 0), 5: (0, 0, True, -1)}.get(f, (0, 0, False, 0))


def humanoid(c, f, o):
    """Generic chibi person. o: dict of look options."""
    kind = o.get('body', 'normal')
    if kind == 'kid':
        head_top, torso_top, leg_top = 10, 18, 23
    elif kind == 'hunch':
        head_top, torso_top, leg_top = 9, 16, 21
    else:
        head_top, torso_top, leg_top = 6, 14, 21
    feet = 26
    bdx, fdx, together, bob = leg_offsets(f)
    if f == 1:
        bob = 1 if kind != 'kid' else 0
    if f == 6:
        bob = -1
    hx = 1 if kind == 'hunch' else 0
    skin = o.get('skin', SKIN_L)
    skin_s = shade(skin, 0.82)
    pants = o.get('pants', C('3b4a6b'))
    pants_s = shade(pants, 0.75)
    shoes = o.get('shoes', C('2b2030'))
    legs = o.get('legs', 'pants')

    # ---- legs
    lx_back, lx_front = (10, 12) if together else (9, 13)
    for i, (lx, dxb, col) in enumerate(((lx_back, bdx, pants_s), (lx_front, fdx, pants))):
        for y in range(leg_top, feet):
            dx = dxb if y >= feet - 2 else 0
            cc = col
            if legs == 'shorts' and y >= leg_top + 2:
                cc = skin_s if i == 0 else skin
            c.rect(lx + dx, y, 2, 1, cc)
        dx = dxb
        c.rect(lx + dx, feet, 2 if i == 0 else 3, 1, shoes)
    if legs == 'skirt' or legs == 'dress':
        sk = o.get('skirt', pants)
        top = torso_top + 5 if legs == 'skirt' else torso_top + 4
        bottom = feet - 2 if legs == 'skirt' else feet - 1
        for y in range(top, bottom + 1):
            w = 8 + (y - top) // 2
            c.rect(12 - w // 2 + hx, y, w, 1, sk if (y - top) % 4 else shade(sk, 0.9))
        c.rect(12 + hx + (8 + (bottom - top) // 2) // 2 - 2, top, 2, bottom - top + 1, shade(sk, 0.85))

    ty = torso_top + bob
    # ---- back arm
    arm = o.get('sleeve', o.get('shirt'))
    arm_s = shade(arm, 0.7)
    swing = {2: 1, 4: -1}.get(f, 0)
    if f == 6:
        c.rect(7 + hx, ty - 4, 1, 5, arm_s)
        c.px(7 + hx, ty - 5, skin_s)
    else:
        c.rect(7 + hx - (1 if swing > 0 else 0), ty + 1, 1, 4, arm_s)
        c.px(7 + hx - (1 if swing > 0 else 0), ty + 5, skin_s)

    # ---- torso
    shirt = o['shirt']
    shirt_s = shade(shirt, 0.8)
    th = leg_top - torso_top
    for y in range(th):
        w = 8
        x0 = 8 + hx
        c.rect(x0, ty + y, w, 1, shirt)
        c.px(x0, ty + y, shirt_s)
        c.px(x0 + 1, ty + y, shirt_s)
    pat = o.get('pattern')
    if pat == 'flowers':
        for (x, y) in ((10, 1), (13, 2), (11, 4), (14, 5), (9, 5)):
            if y < th:
                c.px(x + hx, ty + y, o.get('pattern_col', C('ffe066')))
    elif pat == 'stripes':
        for y in range(0, th, 2):
            c.rect(8 + hx, ty + y, 8, 1, o.get('pattern_col', C('ffffff')))
    jacket = o.get('jacket')
    if jacket:
        js = shade(jacket, 0.8)
        for y in range(th):
            c.rect(8 + hx, ty + y, 3, 1, js if y else jacket)
            c.rect(13 + hx, ty + y, 3, 1, jacket)
        if o.get('tie'):
            c.px(12 + hx, ty, C('f4f0e8'))
            c.px(11 + hx, ty, C('f4f0e8'))
            c.rect(12 + hx, ty + 1, 1, 3, o['tie'])
    belt = o.get('belt')
    if belt:
        c.rect(8 + hx, ty + th - 1, 8, 1, belt)

    # ---- head
    hy = head_top + bob
    for y in range(8):
        for x in range(8):
            if (x in (0, 7)) and (y in (0, 7)):
                continue
            c.px(8 + hx + x, hy + y, skin)
    c.rect(8 + hx, hy + 2, 1, 5, skin_s)  # back of head shading
    c.px(10 + hx, hy + 5, skin_s)          # ear
    # face
    ey = hy + 4
    if f == 7:
        red = C('e0705a')
        c.rect(11 + hx, hy + 3, 5, 4, shade(red, 1.1))
    if f == 6:
        c.px(12 + hx, ey, DARK)
        c.px(14 + hx, ey, DARK)
        c.px(12 + hx, ey - 1, None)
        c.rect(12 + hx, ey + 2, 3, 1, C('8a2a2a'))
        c.px(13 + hx, ey + 3, C('e05050'))
    elif f == 7:
        c.px(12 + hx, ey, DARK)
        c.px(14 + hx, ey, DARK)
        c.px(11 + hx, ey - 1, DARK)
        c.px(15 + hx, ey - 1, DARK)
        c.rect(12 + hx, ey + 2, 3, 1, DARK)
    else:
        c.px(12 + hx, ey, DARK)
        c.px(14 + hx, ey, DARK)
        c.px(13 + hx, ey + 2, shade(skin, 0.65))
        c.px(15 + hx, ey + 1, C('f08a8a', 160))
    if o.get('glasses'):
        g = o['glasses']
        c.rect(11 + hx, ey, 2, 1, g)
        c.rect(14 + hx, ey, 2, 1, g)
        c.px(13 + hx, ey, g)
    if o.get('shades'):
        c.rect(11 + hx, ey - 1 if f != 6 else ey, 5, 2, DARK)
        c.px(14 + hx, ey - 1 if f != 6 else ey, C('6a7aa8'))
    if o.get('mustache'):
        c.rect(12 + hx, ey + 1, 4, 1, o['mustache'])

    # ---- hair
    hair = o.get('hair')
    style = o.get('hair_style', 'short')
    if hair:
        hs = shade(hair, 0.75)
        if style in ('short', 'slick', 'kid'):
            c.rect(9 + hx, hy - 1, 6, 1, hair)
            c.rect(8 + hx, hy, 8, 2, hair)
            c.rect(8 + hx, hy + 2, 2, 3, hs)
            if style == 'slick':
                c.px(15 + hx, hy + 2, hair)
                c.rect(10 + hx, hy - 1, 5, 1, shade(hair, 1.3))
        elif style == 'bun':
            c.rect(8 + hx, hy - 1, 8, 3, hair)
            c.rect(8 + hx, hy + 2, 2, 4, hs)
            c.rect(6 + hx, hy - 1, 3, 3, hair)
            c.px(7 + hx, hy - 1, shade(hair, 1.2))
        elif style == 'spiky':
            c.rect(8 + hx, hy - 1, 8, 3, hair)
            for i, x in enumerate(range(8, 16, 2)):
                c.rect(x + hx, hy - 3 - (i % 2), 1, 3, hair)
                c.px(x + 1 + hx, hy - 2, hs)
            c.rect(8 + hx, hy + 2, 2, 3, hs)
        elif style == 'long':
            c.rect(8 + hx, hy - 1, 8, 3, hair)
            c.rect(7 + hx, hy + 1, 3, 9, hair)
            c.rect(7 + hx, hy + 6, 2, 4, hs)
        elif style == 'curly':
            for (x, y) in ((8, -1), (10, -2), (12, -2), (14, -1), (7, 1), (16, 1), (7, 3)):
                c.rect(x + hx, hy + y, 2, 2, hair)
            c.rect(8 + hx, hy, 8, 2, hair)

    # ---- front arm
    if f == 6:
        c.rect(16 + hx, ty - 4, 1, 5, arm)
        c.px(16 + hx, ty - 5, skin)
    else:
        c.rect(16 + hx + (1 if swing < 0 else 0), ty + 1, 1, 4, arm)
        c.px(16 + hx + (1 if swing < 0 else 0), ty + 5, skin)
    return {'head_top': hy, 'torso_top': ty, 'hx': hx, 'swing': swing, 'feet': feet}


def hat(c, g, kind, col):
    hy, hx = g['head_top'], g['hx']
    cs = shade(col, 0.75)
    if kind == 'sunhat':
        c.rect(6 + hx, hy, 12, 1, col)
        c.rect(9 + hx, hy - 3, 6, 3, col)
        c.rect(9 + hx, hy - 1, 6, 1, C('e05a5a'))
        c.rect(6 + hx, hy, 3, 1, cs)
    elif kind == 'cap':
        c.rect(8 + hx, hy - 2, 7, 3, col)
        c.rect(5 + hx, hy, 4, 1, cs)  # worn backwards
        c.px(11 + hx, hy - 2, shade(col, 1.3))
    elif kind == 'tophat':
        c.rect(7 + hx, hy - 1, 10, 1, col)
        c.rect(9 + hx, hy - 7, 6, 6, col)
        c.rect(9 + hx, hy - 3, 6, 1, C('8a2a3a'))
        c.rect(9 + hx, hy - 7, 1, 6, shade(col, 1.4))
    elif kind == 'pillbox':
        c.rect(9 + hx, hy - 3, 6, 3, col)
        c.rect(9 + hx, hy - 1, 6, 1, C('f2c14e'))
        c.px(10 + hx, hy - 3, shade(col, 1.3))


def draw_guest(c, f):
    g = humanoid(c, f, dict(skin=SKIN_L, hair=C('8a5a2b'), shirt=C('f08a3c'), pattern='flowers',
                            pattern_col=C('ffe066'), pants=C('c9b27c'), legs='shorts', shoes=C('7a4a2a')))
    hat(c, g, 'sunhat', C('e9cf7a'))
    ty, hx = g['torso_top'], g['hx']
    c.rect(11 + hx, ty + 2, 3, 2, DARK)          # camera
    c.px(12 + hx, ty + 2, C('8fb8e0'))
    c.line(10 + hx, ty, 14 + hx, ty + 2, DARK)


def draw_business(c, f):
    g = humanoid(c, f, dict(skin=SKIN_M, hair=C('2a2030'), hair_style='slick', shirt=C('2c3a66'),
                            jacket=C('2c3a66'), tie=C('d0383a'), pants=C('243055'), shoes=C('151018'),
                            sleeve=C('2c3a66')))
    ty, hx, sw = g['torso_top'], g['hx'], g['swing']
    if f != 6:
        bx = 16 + hx + (1 if sw < 0 else 0)
        c.rect(bx - 1, ty + 5, 5, 4, C('7a4a28'))   # briefcase
        c.rect(bx - 1, ty + 5, 5, 1, C('9c6438'))
        c.px(bx + 1, ty + 4, C('3a2418'))


def draw_granny(c, f):
    g = humanoid(c, f, dict(body='hunch', skin=SKIN_L, hair=C('d8d4e0'), hair_style='bun',
                            shirt=C('8a5aa8'), sleeve=C('8a5aa8'), legs='skirt', skirt=C('d77a9a'),
                            pants=C('d77a9a'), shoes=C('4a3040'), glasses=C('6a5a7a')))
    ty, hx = g['torso_top'], g['hx']
    if f != 6:
        x = 18 + hx
        c.vline(x, ty + 4, 26, C('7a4a2a'))      # cane
        c.px(x - 1, ty + 4, C('7a4a2a'))
    c.px(10 + hx, ty + 2, C('f2e6ff'))          # brooch


def draw_kid(c, f):
    g = humanoid(c, f, dict(body='kid', skin=C('e8b48a'), hair=C('5a3a1a'), shirt=C('4a7ad8'),
                            pattern='stripes', pattern_col=C('f4f0e8'), pants=C('3a5a3a'),
                            legs='shorts', shoes=C('d84a3a')))
    hat(c, g, 'cap', C('e04848'))
    ty, hx = g['torso_top'], g['hx']
    if f != 6:
        c.vline(18 + hx, ty, ty + 3, C('f4f0e8'))  # lollipop
        c.disc(18 + hx, ty - 2, 1.4, C('ff6fae'))
        c.px(18 + hx, ty - 2, C('ffd0e6'))


def draw_cat(c, f):
    body = C('2a2238')
    hi = C('4a3e60')
    eye = C('9cff6a')
    bob = -1 if f in (3, 5) else 0
    if f == 7:
        bob = -2
    by = 21 + bob
    # body
    c.rect(7, by, 10, 4, body)
    c.rect(8, by - 1, 8, 1, body)
    if f == 7:
        c.rect(9, by - 2, 6, 1, body)       # arched back
    c.rect(8, by, 6, 1, hi)
    # legs
    leg = {2: (0, 1, 0, -1), 4: (1, 0, -1, 0)}.get(f, (0, 0, 0, 0))
    for i, x in enumerate((7, 9, 14, 16)):
        c.rect(x + leg[i], by + 4, 1, 26 - by - 4 + 1, body)
    # head
    hx, hy = 15, by - 4
    c.rect(hx, hy, 6, 5, body)
    c.px(hx, hy - 1, body)
    c.px(hx + 1, hy - 2, body)
    c.px(hx + 5, hy - 1, body)
    c.px(hx + 4, hy - 2, body)
    c.px(hx + 1, hy - 1, C('ff9ab0'))
    c.px(hx + 4, hy - 1, C('ff9ab0'))
    if f == 6:
        c.px(hx + 2, hy + 2, eye)
        c.px(hx + 4, hy + 2, eye)
        c.px(hx + 3, hy + 3, C('ff9ab0'))
    elif f == 7:
        c.px(hx + 2, hy + 2, C('ff5050'))
        c.px(hx + 4, hy + 2, C('ff5050'))
        c.px(hx + 3, hy + 4, C('f4f0e8'))
    else:
        c.px(hx + 2, hy + 2, eye)
        c.px(hx + 4, hy + 2, eye)
    # tail
    tail = {0: [(6, by - 1), (5, by - 2), (5, by - 3), (5, by - 4), (6, by - 5)],
            1: [(6, by - 1), (5, by - 2), (5, by - 3), (6, by - 4), (7, by - 4)]}
    pts = tail[0] if f % 2 == 0 else tail[1]
    if f == 7:
        pts = [(6, by - 1), (6, by - 2), (6, by - 3), (6, by - 4), (6, by - 5), (6, by - 6)]
    for (x, y) in pts:
        c.rect(x, y, 2 if f == 7 else 1, 1, body)


def draw_rocker(c, f):
    g = humanoid(c, f, dict(skin=SKIN_L, hair=C('b04ae0'), hair_style='spiky', shirt=C('2a2230'),
                            jacket=C('1f1a26'), sleeve=C('1f1a26'), pants=C('4a6aa0'), shoes=C('101010'),
                            shades=True))
    ty, hx = g['torso_top'], g['hx']
    # guitar on the back
    c.rect(4 + hx, ty + 2, 4, 5, C('d83a3a'))
    c.rect(5 + hx, ty + 1, 2, 1, C('d83a3a'))
    c.px(5 + hx, ty + 4, DARK)
    c.vline(6 + hx, ty - 6, ty + 1, C('7a4a2a'))
    c.rect(5 + hx, ty - 7, 3, 1, C('2a2030'))
    c.px(14 + hx, ty + 1, C('d0d0d0'))           # studs
    c.px(14 + hx, ty + 3, C('d0d0d0'))


def draw_robot(c, f):
    body = C('9aa8b8')
    bs = C('6a7888')
    hi = C('d0dae6')
    bob = -1 if f in (3, 5) else 0
    if f == 6:
        bob = -2
    top = 9 + bob
    # wheels
    for x in (8, 14):
        c.rect(x, 23, 3, 3, C('2a2a34'))
        c.px(x + (f % 3), 24, C('8a8a9a'))
    c.rect(8, 22, 9, 1, bs)
    # body
    c.rect(7, top + 7, 11, 7, body)
    c.rect(7, top + 7, 2, 7, bs)
    c.rect(9, top + 7, 8, 1, hi)
    c.rect(10, top + 10, 5, 2, C('f2c14e'))        # parcel slot / logo
    # head
    c.rect(8, top, 9, 7, body)
    c.rect(8, top, 2, 7, bs)
    c.rect(10, top + 1, 6, 4, C('1a2a3a'))
    eye = C('6af0ff') if f != 7 else C('ff4a4a')
    if f == 6:
        c.rect(11, top + 2, 1, 1, eye)
        c.rect(14, top + 2, 1, 1, eye)
        c.rect(11, top + 3, 4, 1, eye)
    elif f == 7:
        c.rect(11, top + 2, 2, 1, eye)
        c.rect(14, top + 2, 2, 1, eye)
    else:
        c.rect(11, top + 2, 1, 2, eye)
        c.rect(14, top + 2, 1, 2, eye)
    c.vline(13, top - 3, top - 1, bs)
    c.px(13, top - 4, C('ff4a4a') if f % 2 == 0 else C('ffa0a0'))
    # arms holding a parcel
    c.rect(17, top + 9, 2, 1, bs)
    c.rect(16, top + 4, 5, 5, C('c8925a'))
    c.rect(16, top + 6, 5, 1, C('8a5a2a'))


def draw_couple(c, f):
    # groom (back, left) + bride (front, right) drawn as two small people
    g1 = Canvas(CW, CH)
    humanoid(g1, f, dict(skin=SKIN_M, hair=C('2a2030'), hair_style='slick', shirt=C('1a1622'),
                         jacket=C('1a1622'), tie=C('1a1622'), pants=C('1a1622'), shoes=C('101010'),
                         sleeve=C('1a1622')))
    g2 = Canvas(CW, CH)
    hb = humanoid(g2, f if f not in (2, 4) else 6 - f, dict(skin=SKIN_L, hair=C('e0b050'), hair_style='long',
                                                            shirt=C('f4f0f8'), sleeve=C('f4f0f8'),
                                                            legs='dress', skirt=C('f4f0f8'), pants=C('f4f0f8'),
                                                            shoes=C('e0e0f0')))
    # veil + flowers
    hy = hb['head_top']
    g2.rect(7, hy - 1, 3, 9, C('e8f0ff', 200))
    g2.rect(15, hb['torso_top'] + 3, 2, 2, C('ff7aa8'))
    g2.px(16, hb['torso_top'] + 2, C('7ad87a'))
    c.paste(g1, -4, 0)
    c.paste(g2, 3, 0)


def draw_inspector(c, f):
    g = humanoid(c, f, dict(skin=SKIN_L, hair=C('7a7a7a'), shirt=C('5a5a6a'), jacket=C('5a5a6a'),
                            tie=C('2a2a3a'), sleeve=C('5a5a6a'), pants=C('4a4a58'), shoes=C('151018'),
                            mustache=C('d0d0d0')))
    hat(c, g, 'tophat', C('1a1622'))
    ty, hx, hy = g['torso_top'], g['hx'], g['head_top']
    c.ring(14 + hx, hy + 4, 1.0, C('f2c14e'))     # monocle
    c.px(9 + hx, ty + 2, C('f2c14e'))             # badge
    c.px(10 + hx, ty + 2, C('ffe08a'))
    if f != 6:
        c.rect(16 + hx, ty + 2, 4, 5, C('c8925a'))  # clipboard
        c.rect(17 + hx, ty + 3, 2, 3, C('f4f0e8'))
        c.px(17 + hx, ty + 1, C('8a8a9a'))


def draw_bellhop(c, f):
    # luggage cart in front
    cart = C('f2c14e')
    c.rect(14, 24, 9, 1, cart)
    c.rect(22, 12, 1, 13, cart)
    c.rect(15, 25, 2, 2, C('2a2a34'))
    c.rect(20, 25, 2, 2, C('2a2a34'))
    c.rect(14, 19, 8, 5, C('7a3a8a'))     # suitcase
    c.rect(14, 19, 8, 1, C('9a5aaa'))
    c.rect(15, 14, 6, 5, C('3a7a5a'))     # bag
    c.rect(17, 13, 2, 1, C('2a5a3a'))
    c.rect(16, 16, 4, 1, C('f2c14e'))
    g = Canvas(CW, CH)
    hb = humanoid(g, f, dict(skin=SKIN_M, hair=C('2a2030'), shirt=C('c83a3a'), sleeve=C('c83a3a'),
                             pants=C('2a2030'), shoes=C('151018'), belt=C('f2c14e')))
    for y in (1, 3, 5):
        g.px(13 + hb['hx'], hb['torso_top'] + y, C('f2c14e'))
    hat(g, hb, 'pillbox', C('c83a3a'))
    c.paste(g, -4, 0)


def draw_ghost(c, f):
    w = C('eef0ff', 215)
    s = C('b8c0e8', 215)
    bob = [0, -1, 0, -1, -2, -1, -2, 0][f]
    top = 8 + bob
    for y in range(13):
        half = 4 if y < 2 else 5
        if y == 0:
            half = 3
        c.rect(12 - half, top + y, half * 2, 1, w)
        c.px(12 - half, top + y, s)
    # wavy hem
    phase = f % 2
    for i, x in enumerate(range(7, 17, 2)):
        h = 2 if (i + phase) % 2 == 0 else 1
        c.rect(x, top + 13, 2, h, w)
    if f == 7:
        c.rect(10, top + 4, 1, 2, DARK)
        c.rect(14, top + 4, 1, 2, DARK)
        c.px(9, top + 3, DARK)
        c.px(15, top + 3, DARK)
        c.rect(11, top + 8, 3, 2, DARK)
    elif f == 6:
        c.px(10, top + 4, DARK)
        c.px(14, top + 4, DARK)
        c.rect(11, top + 7, 3, 1, DARK)
        c.px(12, top + 8, C('ff8aa8'))
    else:
        c.rect(10, top + 4, 2, 2, DARK)
        c.rect(14, top + 4, 2, 2, DARK)
        c.rect(12, top + 8, 2, 2, DARK)
    c.px(9, top + 6, C('ffb0c8', 150))
    c.px(16, top + 6, C('ffb0c8', 150))


DRAW = {
    'guest': draw_guest, 'business': draw_business, 'granny': draw_granny, 'kid': draw_kid,
    'cat': draw_cat, 'rocker': draw_rocker, 'robot': draw_robot, 'couple': draw_couple,
    'inspector': draw_inspector, 'bellhop': draw_bellhop, 'ghost': draw_ghost,
}
ORDER = ['guest', 'business', 'granny', 'kid', 'cat', 'rocker', 'robot', 'couple', 'inspector', 'bellhop', 'ghost']


def make_sheet():
    sheet = Canvas(CW * FRAMES, CH * len(ORDER))
    for row, t in enumerate(ORDER):
        for f in range(FRAMES):
            cell = Canvas(CW, CH)
            DRAW[t](cell, f)
            outline(cell.img, C('c0c8ff', 120) if t == 'ghost' else OUTLINE)
            cell.p = cell.img.load()
            sheet.paste(cell, f * CW, row * CH)
    return sheet.img
