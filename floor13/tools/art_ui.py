"""Interface art: icons, digits, floor buttons, 9-slice panels, logo, app icon."""
import math
from PIL import Image, ImageDraw, ImageFont
from art_lib import C, Canvas, shade, outline

K = C('1a1020')
PAL = {
    'k': K, 'w': C('f4f0e8'), 'W': C('c8c0d8'), 'y': C('f2c14e'), 'Y': C('ffe08a'), 'o': C('b8862a'),
    'r': C('e04848'), 'R': C('9a2a3a'), 'p': C('ff8aa8'), 'b': C('4a7ad8'), 'B': C('8fd0ff'),
    'c': C('6af0ff'), 'g': C('5ad85a'), 'G': C('2a8a4a'), 's': C('b8c0d0'), 'S': C('6a7888'),
    'n': C('8a5a2a'), 'N': C('5a3a1a'), 'v': C('a05ad8'), 'V': C('5a2a8a'), 'm': C('f2c9a0'),
    'd': C('3a3048'), 'e': C('2a2238'), 'f': C('ffb347'),
}

ICONS = {
    'heart': """
................
................
..kkkk....kkkk..
.krrrrk..krrrrk.
krpwrrrkkrrrrrRk
krwrrrrrrrrrrrRk
krrrrrrrrrrrrrRk
krrrrrrrrrrrrRRk
.krrrrrrrrrrRRk.
..krrrrrrrrRRk..
...krrrrrrRRk...
....krrrrRRk....
.....krrRRk.....
......kRRk......
.......kk.......""",
    'pause': """
................
................
...kkkk..kkkk...
...kwwk..kwwk...
...kwwk..kwwk...
...kwwk..kwwk...
...kwwk..kwwk...
...kwwk..kwwk...
...kwwk..kwwk...
...kwwk..kwwk...
...kwwk..kwwk...
...kWWk..kWWk...
...kkkk..kkkk...""",
    'play': """
................
................
....kk..........
....kwkk........
....kwwwkk......
....kwwwwwkk....
....kwwwwwwwkk..
....kwwwwwwwwWk.
....kwwwwwwwkk..
....kwwwwwkk....
....kwwwkk......
....kwkk........
....kk..........""",
    'lock': """
................
.....kkkkkk.....
....kssssssk....
...ksSkkkkSsk...
...ksk....ksk...
...ksk....ksk...
..kkkkkkkkkkkk..
..kyYyyyyyyyok..
..kyyyykkyyyok..
..kyyyykkyyyok..
..kyyyyykyyyok..
..kyyyyykyyyok..
..kyyyyyyyyyok..
..kooooooooook..
..kkkkkkkkkkkk..""",
    'wrench': """
................
.........kkk....
........kssk.kk.
.......kssk.ksk.
.......ksskkssk.
.......kssssssk.
......kssssSSk..
.....kssskkkk...
....ksssk.......
...ksssk........
..ksssk.........
.ksssk..........
.kssk...........
.kSk............
..k.............""",
    'sound': """
................
.......kk.......
......kwk...w...
.....kwwk....w..
.kkkkwwwk..w..w.
.kwwwwwwk...w.w.
.kwwwwwwk...w.w.
.kwwwwwwk...w.w.
.kWWWwwwk..w..w.
.kkkkWwwk....w..
.....kWwk...w...
......kWk.......
.......kk.......""",
    'sound_off': """
................
.......kk.......
......kwk.......
.....kwwk.......
.kkkkwwwk.kk..kk
.kwwwwwwk.krrkrk
.kwwwwwwk..krrk.
.kwwwwwwk..krrk.
.kWWWwwwk.krkrrk
.kkkkWwwk.kk..kk
.....kWwk.......
......kWk.......
.......kk.......""",
    'music': """
................
......kkkkkkkk..
......kwwwwwwk..
......kwkkkkwk..
......kwk..kwk..
......kwk..kwk..
......kwk..kwk..
......kwk..kwk..
...kkkkwk.kkwk..
..kwwwwwkkwwwk..
..kwwwwwkwwwwk..
..kWwwwWkWwwWk..
...kWWWk.kWWk...
....kkk...kk....""",
    'vibe': """
................
.....kkkkkk.....
.w..kssssssk..w.
w...ksBBBBsk...w
.w..ksBBBBsk..w.
w...ksBBBBsk...w
.w..ksBBBBsk..w.
w...ksBBBBsk...w
.w..ksBBBBsk..w.
....ksssssssk...
....kssSSssk....
....kssssssk....
.....kkkkkk.....""",
    'home': """
................
.......kk.......
......kwwk......
.....kwwwwk.....
....kwwwwwwk....
...kwwwwwwwwk...
..kwwwwwwwwwwk..
.kkkwwwwwwwwkkk.
...kwwwkkwwwk...
...kwwkNNkwwk...
...kwwkNNkwwk...
...kwwkNNkwwk...
...kWWkNNkWWk...
...kkkkkkkkkk...""",
    'retry': """
................
.....kkkkk......
...kkwwwwwkk.k..
..kwwkkkkkwwkwk.
.kwwk.....kwwwk.
.kwk.....kwwwwk.
kwwk.....kkkkkk.
kwk.............
kwk.............
kwwk.........k..
.kwk........kwk.
.kwwk......kwwk.
..kwwkkkkkkwwk..
...kkwwwwwwkk...
.....kkkkkk.....""",
    'cabin': """
................
.kkkkkkkkkkkkkk.
.kyyyyyyyyyyyyk.
.kykkkkkkkkkkyk.
.kykddddddddkyk.
.kykdkkddkkdkyk.
.kykkmmkkmmkkyk.
.kykdkkddkkdkyk.
.kykkbbkkrrkkyk.
.kykbbbbrrrrkyk.
.kykbbbbrrrrkyk.
.kykdbbddrrdkyk.
.kykkkkkkkkkkyk.
.kyyyyyyyyyyyyk.
.kkkkkkkkkkkkkk.""",
    'door': """
................
...kkkkkkkkkk...
...knnnnnnnnk...
...knNNNNNNnk...
...knNnnnnNnk...
...knNnnnnNnk...
...knNNNNNNnk...
...knnnnnnnnk...
...knNNNNNNnk...
...knNnnnnyyk...
...knNnnnnyyk...
...knNnnnnNnk...
...knNNNNNNnk...
...knnnnnnnnk...
..kkkkkkkkkkkk..""",
    'coffee': """
................
.....w..w.......
......w..w......
.....w..w.......
................
..kkkkkkkkkk....
..kwwwwwwwwkkk..
..kwNNNNNNwk.k..
..kwwwwwwwwk.k..
..kwwwwwwwwkkk..
..kwwwwwwwwk....
...kwwwwwwk.....
....kWWWWk......
.kkkkkkkkkkkk...
..kssssssssk....
...kkkkkkkk.....""",
    'tie': """
................
...kkk....kkk...
..kwwwk..kwwwk..
..kwwwwkkwwwwk..
...kwwkrrkwwk...
....kkrrrrkk....
......krrk......
.....krrrrk.....
.....krrrrk.....
....krrrrrrk....
....krrrRrrk....
....krrrRRrk....
.....krrRrk.....
......krrk......
.......kk.......""",
    'book': """
................
..kkkkkkkkkkk...
..kRrrrrrrrrrk..
..kRrwwwwwwrrk..
..kRrrrrrrrrrk..
..kRrrrrrrrrrk..
..kRrrryyrrrrk..
..kRrrryyrrrrk..
..kRrrrrrrrrrk..
..kRrrrrrrrrrk..
..kRrrrrrrrrrk..
..kRkkkkkkkkkk..
..kRwwwwwwwwwk..
..kkkkkkkkkkk...""",
    'bolt': """
................
.........kkkk...
........kyyyk...
.......kyyyk....
......kyyyk.....
.....kyyyk......
....kyyyykkkk...
...kyyyyyyyyk...
...kkkkyyyyk....
......kyyyk.....
.....kyyyk......
....kyyyk.......
...kyyk.........
...kyk..........
...kk...........""",
    'siren': """
................
.......kk.......
..w...kwwk...w..
...w.krrrrk.w...
.....krwrrk.....
....krwrrrrk....
w...krwrrrrk...w
....krrrrrrk....
....krrrrrrk....
...kkkkkkkkkk...
...ksssssssSk...
...kkkkkkkkkk...""",
    'drop': """
................
.......kk.......
......kgk.......
......kggk......
.....kggggk.....
.....kggggk.....
....kgwgggGk....
....kgwgggGk....
...kgwggggGGk...
...kgggggggGk...
...kggggggGGk...
....kgggggGk....
.....kGGGGk.....
......kkkk......""",
    'ghost': """
................
.....kkkkkk.....
....kwwwwwwk....
...kwwwwwwwwk...
...kwwkwwkwwk...
...kwwkwwkwwk...
..kwwwwwwwwwwk..
..kwwwwkkwwwwk..
..kwwwwkkwwwwk..
..kwwwwwwwwwwk..
..kwwwwwwwwwwk..
..kwwwwwwwwwWk..
..kwkwwkkwwkWk..
..kk.kk..kk.kk..""",
    'cat': """
................
................
..kk........kk..
..kek......kek..
..keekkkkkkeek..
..keeeeeeeeeek..
.keeeeeeeeeeeek.
.keegkeeeekgeek.
.keeggeeeeggeek.
.keeeeeeeeeeeek.
.kwweeepeeeewwk.
..keeeekkeeeek..
...keeeeeeeek...
....kkkkkkkk....""",
    'tophat': """
................
................
....kkkkkkkk....
....kSddddSk....
....kSddddSk....
....kSddddSk....
....kSddddSk....
....kSddddSk....
....kRRRRRRk....
....kRRRRRRk....
....kSddddSk....
.kkkkSddddSkkkk.
.kSSSSSSSSSSSSk.
.kkkkkkkkkkkkkk.""",
    'briefcase': """
................
................
......kkkk......
.....knnnnk.....
.....kn..nk.....
..kkkkkkkkkkkk..
..knnnnnnnnnnk..
..knnnnnnnnnnk..
..knnnnyynnnnk..
..kNNNNyyNNNNk..
..knnnnnnnnnnk..
..knnnnnnnnnnk..
..kNNNNNNNNNNk..
..kkkkkkkkkkkk..""",
    'granny': """
................
......kkkk......
.....kWWWWk.....
....kkWWWWkk....
...kWWWWWWWWk...
..kWWWWWWWWWWk..
..kWmmmmmmmmWk..
..kmkkkmmkkkmk..
..kmkwkkkkwkmk..
..kmkkkmmkkkmk..
..kmmmmmmmmmmk..
..kmmmmppmmmmk..
...kmmmmmmmmk...
....kkkkkkkk....""",
    'express': """
................
................
..kk.....kk.....
..kwk....kwk....
..kwwk...kwwk...
...kwwk...kwwk..
....kwwk...kwwk.
.....kwwk...kwwk
....kwwk...kwwk.
...kwwk...kwwk..
..kwwk...kwwk...
..kwk....kwk....
..kk.....kk.....""",
    'confetti': """
................
..r......y...b..
.....p........r.
.y.......g......
....b..r....y...
..............p.
.kk...y...b.....
.kykk......g....
.kyyykk..r......
.kyyyyykk....y..
.kyyyyyyykk.....
.kyyyyyyyyykk...
.kyyyyyyyyyyykk.
.kkkkkkkkkkkkkk.""",
    'bag': """
................
.....kkkkkk.....
....kk....kk....
...kkkkkkkkkk...
..kbbbbbbbbbbk..
..kbBBBBBBBBbk..
..kbbbbbbbbbbk..
..kbbkkkkkkbbk..
..kbbkyyyykbbk..
..kbbkbbbbkbbk..
..kbbkbbbbkbbk..
..kbbkkkkkkbbk..
..kbbbbbbbbbbk..
...kkkkkkkkkk...""",
    'trophy': """
................
...kkkkkkkkkk...
.kkkyYyyyyyokkk.
kyk.kYyyyyyok.yk
kyk.kYyyyyyok.yk
.kyykyyyyyyokyk.
..kkkyyyyyyokk..
.....kyyyyok....
......kyyok.....
.......kyk......
.......kyk......
.....kkyyokk....
....kyyyyyyok...
....kkkkkkkkk...""",
    'person': """
................
......kkkk......
.....kwwwwk.....
.....kwwwwk.....
.....kwwwwk.....
......kkkk......
....kkwwwwkk....
...kwwwwwwwwk...
...kwwwwwwwwk...
...kwkwwwwkwk...
...kk.kwwk.kk...
......kwwk......
......kkkk......""",
    'check': """
................
................
............kk..
...........kgk..
..........kggk..
.........kggk...
..kk....kggk....
.kgk...kggk.....
.kggk.kggk......
..kggkggk.......
...kgggk........
....kgk.........
.....k..........""",
    'cross': """
................
................
..kk.......kk...
.krrk.....krrk..
..krrk...krrk...
...krrk.krrk....
....krrkrrk.....
.....krrrk......
....krrkrrk.....
...krrk.krrk....
..krrk...krrk...
.krrk.....krrk..
..kk.......kk...""",
    'up': """
................
.......kk.......
......kwwk......
.....kwwwwk.....
....kwwwwwwk....
...kwwwwwwwwk...
..kkkkwwwwkkkk..
.....kwwwwk.....
.....kwwwwk.....
.....kwwwwk.....
.....kwwwwk.....
.....kWWWWk.....
.....kkkkkk.....""",
    'info': """
................
.....kkkkkk.....
...kkbbbbbbkk...
..kbbbbwwbbbbk..
..kbbbbwwbbbbk..
.kbbbbbbbbbbbbk.
.kbbbbwwwbbbbbk.
.kbbbbbwwbbbbbk.
.kbbbbbwwbbbbbk.
.kbbbbbwwbbbbbk.
..kbbbwwwwbbbk..
..kbbbbbbbbbbk..
...kkbbbbbbkk...
.....kkkkkk.....""",
}

ICON_ORDER = ['coin', 'heart', 'heart_empty', 'clock', 'pause', 'play', 'lock', 'wrench', 'star', 'star_empty',
              'sound', 'sound_off', 'music', 'music_off', 'vibe', 'home', 'retry', 'gear', 'cabin', 'door',
              'coffee', 'note', 'tie', 'book', 'balloon', 'bolt', 'pile', 'siren', 'drop', 'bulb', 'ghost', 'cat',
              'tophat', 'briefcase', 'granny', 'express', 'confetti', 'moon', 'gear_rust', 'bag', 'fullmoon',
              'trophy', 'person', 'check', 'cross', 'up', 'down', 'info', 'heart_broken', 'calendar']


def icon_from_ascii(art, remap=None):
    c = Canvas(16, 16)
    rows = [r for r in art.split('\n') if r != '']
    pal = dict(PAL)
    if remap:
        pal.update(remap)
    for j, row in enumerate(rows[:16]):
        for i, ch in enumerate(row[:16]):
            col = pal.get(ch)
            if col is not None:
                c.set(i, j, col)
    return c


def proc_icon(name):
    c = Canvas(16, 16)
    y, Y, o, w = PAL['y'], PAL['Y'], PAL['o'], PAL['w']
    if name == 'coin':
        c.disc(7.5, 7.5, 6.2, o)
        c.disc(7.2, 7.0, 5.6, y)
        c.ring(7.5, 7.5, 3.6, o)
        c.px(5, 4, Y)
        c.px(4, 5, Y)
        c.px(6, 3, Y)
        c.rect(7, 5, 1, 5, o)
    elif name == 'clock':
        c.disc(7.5, 7.5, 6.2, PAL['W'])
        c.disc(7.3, 7.2, 5.5, w)
        c.vline(7, 3, 8, K)
        c.hline(7, 10, 8, K)
        c.px(7, 8, PAL['r'])
    elif name in ('star', 'star_empty'):
        img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        pts = []
        for i in range(10):
            r = 7.2 if i % 2 == 0 else 3.1
            a = -math.pi / 2 + i * math.pi / 5
            pts.append((7.5 + r * math.cos(a), 8.0 + r * math.sin(a)))
        d.polygon(pts, fill=y if name == 'star' else PAL['d'])
        c.img = img
        c.p = img.load()
        if name == 'star':
            c.px(7, 3, Y)
            c.px(7, 4, Y)
            c.px(6, 6, Y)
    elif name in ('moon', 'fullmoon'):
        c.disc(7.5, 7.5, 6, C('fff4d6'))
        if name == 'moon':
            c.disc(10.5, 5.5, 5, (0, 0, 0, 0))
            for yy in range(16):
                for xx in range(16):
                    if (xx - 10.5) ** 2 + (yy - 5.5) ** 2 <= 25:
                        c.set(xx, yy, (0, 0, 0, 0))
            c.px(12, 10, w)
            c.px(13, 12, w)
        else:
            c.disc(5.5, 6, 1.5, C('e8dcb8'))
            c.disc(9.5, 10, 2, C('e8dcb8'))
    elif name == 'balloon':
        c.disc(7.5, 6, 5, PAL['r'])
        c.px(5, 3, C('ffb0b0'))
        c.px(5, 4, C('ffb0b0'))
        c.rect(7, 11, 2, 1, PAL['R'])
        c.line(8, 12, 6, 15, w)
    elif name == 'bulb':
        c.disc(7.5, 6.5, 5, C('6a6478'))
        c.disc(7.0, 6.0, 4, C('8a849a'))
        c.rect(5, 11, 6, 3, PAL['s'])
        c.hline(5, 10, 12, PAL['S'])
        c.line(3, 2, 12, 13, PAL['r'])
    elif name in ('gear', 'gear_rust'):
        col = PAL['s'] if name == 'gear' else C('b8703a')
        dk = PAL['S'] if name == 'gear' else C('7a4a2a')
        for i in range(8):
            a = i * math.pi / 4
            c.disc(7.5 + 6 * math.cos(a), 7.5 + 6 * math.sin(a), 1.4, col)
        c.disc(7.5, 7.5, 5, col)
        c.disc(7.5, 7.5, 2, (0, 0, 0, 0))
        for yy in range(16):
            for xx in range(16):
                if (xx - 7.5) ** 2 + (yy - 7.5) ** 2 <= 4.4:
                    c.set(xx, yy, (0, 0, 0, 0))
        c.ring(7.5, 7.5, 3.4, dk)
    elif name == 'pile':
        for (x, yy) in ((2, 10), (7, 10), (12 - 1, 10), (4, 7), (9, 7), (6, 4)):
            c.rect(x, yy, 5, 3, o)
            c.rect(x, yy, 5, 2, y)
            c.px(x + 1, yy, Y)
    elif name == 'calendar':
        c.rect(2, 3, 12, 11, w)
        c.rect(2, 3, 12, 3, PAL['r'])
        c.rect(4, 1, 1, 3, PAL['S'])
        c.rect(11, 1, 1, 3, PAL['S'])
        for yy in (8, 11):
            for x in (4, 7, 10):
                c.rect(x, yy, 2, 2, PAL['d'])
    return c


def make_icons():
    n = len(ICON_ORDER)
    cols = 10
    rows = (n + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 16, rows * 16), (0, 0, 0, 0))
    for i, name in enumerate(ICON_ORDER):
        if name in ICONS:
            c = icon_from_ascii(ICONS[name])
        elif name == 'heart_empty':
            c = icon_from_ascii(ICONS['heart'], {'r': C('4a3a5a'), 'R': C('3a2c48'), 'p': C('5a4a6a'), 'w': C('5a4a6a')})
        elif name == 'heart_broken':
            c = icon_from_ascii(ICONS['heart'], {'r': C('7a3a4a'), 'R': C('5a2a3a'), 'p': C('8a4a5a'), 'w': C('8a4a5a')})
            for yy in range(3, 15):
                c.set(7 + (yy % 2), yy, (0, 0, 0, 0))
        elif name == 'music_off':
            c = icon_from_ascii(ICONS['music'], {'w': C('8a849a'), 'W': C('6a6478')})
            c.line(2, 2, 13, 13, PAL['r'])
            c.line(3, 2, 14, 13, PAL['r'])
        elif name == 'note':
            c = icon_from_ascii(ICONS['music'], {'w': PAL['y'], 'W': PAL['o']})
        elif name == 'down':
            c = icon_from_ascii(ICONS['up'], {'W': PAL['w']})
            c.img = c.img.transpose(Image.FLIP_TOP_BOTTOM)
        else:
            c = proc_icon(name)
            outline(c.img, K)
        sheet.alpha_composite(c.img, ((i % cols) * 16, (i // cols) * 16))
    return sheet


DIGITS = {
    '0': ['.###.', '##.##', '##.##', '##.##', '##.##', '##.##', '.###.'],
    '1': ['..##.', '.###.', '..##.', '..##.', '..##.', '..##.', '.####'],
    '2': ['.###.', '##.##', '...##', '..##.', '.##..', '##...', '#####'],
    '3': ['####.', '...##', '...##', '.###.', '...##', '...##', '####.'],
    '4': ['...##', '..###', '.#.##', '##.##', '#####', '...##', '...##'],
    '5': ['#####', '##...', '####.', '...##', '...##', '##.##', '.###.'],
    '6': ['.###.', '##...', '##...', '####.', '##.##', '##.##', '.###.'],
    '7': ['#####', '...##', '..##.', '..##.', '.##..', '.##..', '.##..'],
    '8': ['.###.', '##.##', '##.##', '.###.', '##.##', '##.##', '.###.'],
    '9': ['.###.', '##.##', '##.##', '.####', '...##', '...##', '.###.'],
    '?': ['.###.', '##.##', '...##', '..##.', '.##..', '.....', '.##..'],
    '+': ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'],
    'x': ['.....', '##.##', '.###.', '..#..', '.###.', '##.##', '.....'],
    '!': ['.##..', '.##..', '.##..', '.##..', '.##..', '.....', '.##..'],
    '-': ['.....', '.....', '.....', '####.', '.....', '.....', '.....'],
}
DIGIT_ORDER = '0123456789?+x!-'


def make_digits():
    img = Image.new('RGBA', (5 * len(DIGIT_ORDER), 7), (0, 0, 0, 0))
    p = img.load()
    for i, ch in enumerate(DIGIT_ORDER):
        for y, row in enumerate(DIGITS[ch]):
            for x, v in enumerate(row):
                if v == '#':
                    p[i * 5 + x, y] = (255, 255, 255, 255)
    return img


def rounded(c, x, y, w, h, col, r=3):
    for yy in range(h):
        for xx in range(w):
            dx = min(xx, w - 1 - xx)
            dy = min(yy, h - 1 - yy)
            if dx < r and dy < r and (r - dx - 0.5) ** 2 + (r - dy - 0.5) ** 2 > r * r:
                continue
            c.px(x + xx, y + yy, col)


def floor_button(state):
    w, h = 52, 38
    c = Canvas(w, h)
    dy = 1 if state == 'pressed' else 0
    if state in ('locked', 'closed'):
        b_l, b, b_d = C('8a8498'), C('6a6478'), C('3e3a4a')
    else:
        b_l, b, b_d = C('ffe08a'), C('d8a040'), C('8a5a22')
    rounded(c, 0, dy, w, h - 1, K, 6)
    rounded(c, 1, 1 + dy, w - 2, h - 3, b_d, 5)
    rounded(c, 1, 1 + dy, w - 2, h - 5, b, 5)
    rounded(c, 2, 2 + dy, w - 4, 3, b_l, 2)
    inner_w, inner_h = w - 10, h - 12
    ix, iy = 5, 5 + dy
    if state in ('normal', 'pressed'):
        inner = C('2a2038')
        rounded(c, ix - 1, iy - 1, inner_w + 2, inner_h + 2, C('140e1e'), 4)
        rounded(c, ix, iy, inner_w, inner_h, inner, 3)
        c.rect(ix + 3, iy + 1, inner_w - 6, 1, C('3e3252'))
    elif state == 'lit':
        rounded(c, ix - 1, iy - 1, inner_w + 2, inner_h + 2, C('8a4a10'), 4)
        rounded(c, ix, iy, inner_w, inner_h, C('ffa82e'), 3)
        rounded(c, ix + 3, iy + 2, inner_w - 6, inner_h - 4, C('ffc65a'), 3)
        rounded(c, ix + 8, iy + 4, inner_w - 16, inner_h - 8, C('ffe08a'), 3)
    elif state == 'locked':
        rounded(c, ix - 1, iy - 1, inner_w + 2, inner_h + 2, C('0e0a14'), 4)
        rounded(c, ix, iy, inner_w, inner_h, C('1a1622'), 3)
    elif state == 'closed':
        rounded(c, ix - 1, iy - 1, inner_w + 2, inner_h + 2, C('0e0a14'), 4)
        rounded(c, ix, iy, inner_w, inner_h, C('2a2430'), 3)
        for yy in range(iy + 2, iy + inner_h - 2):
            for xx in range(ix + 2, ix + inner_w - 2):
                if ((xx + yy) // 4) % 2 == 0:
                    c.set(xx, yy, C('8a7a2a'))
                else:
                    c.set(xx, yy, C('2a2430'))
    return c.img


def make_buttons():
    states = ['normal', 'lit', 'locked', 'closed', 'pressed']
    sheet = Image.new('RGBA', (52 * len(states), 38), (0, 0, 0, 0))
    for i, s in enumerate(states):
        sheet.alpha_composite(floor_button(s), (i * 52, 0))
    return sheet


def nine(fill, light, dark, border=K, screws=False, r=4):
    c = Canvas(24, 24)
    rounded(c, 0, 0, 24, 24, border, r)
    rounded(c, 1, 1, 22, 22, dark, r - 1)
    rounded(c, 1, 1, 22, 20, fill, r - 1)
    c.rect(3, 1, 18, 1, light)
    c.rect(1, 3, 1, 16, light)
    if screws:
        for (x, y) in ((4, 4), (19, 4), (4, 18), (19, 18)):
            c.px(x, y, light)
            c.px(x + 1, y + 1, dark)
    return c.img


def make_ninepatches():
    out = {}
    out['panel'] = nine(C('2a2040'), C('4a3a6a'), C('16101f'), screws=True)
    out['panel_light'] = nine(C('3a2e58'), C('5a4a80'), C('1e1630'))
    out['btn'] = nine(C('7a3ab0'), C('a868e0'), C('4a2070'))
    out['btn_pressed'] = nine(C('5a2a8a'), C('7a3ab0'), C('3a1858'))
    out['btn_gold'] = nine(C('e0a838'), C('ffe08a'), C('8a5a22'))
    out['btn_gold_pressed'] = nine(C('b8862a'), C('e0a838'), C('6a4418'))
    out['btn_green'] = nine(C('3aa85a'), C('7ae08a'), C('1e6a36'))
    out['btn_green_pressed'] = nine(C('2a884a'), C('3aa85a'), C('145028'))
    out['btn_grey'] = nine(C('4a4458'), C('6a6478'), C('2a2636'))
    out['btn_grey_pressed'] = nine(C('3a3448'), C('4a4458'), C('1e1a28'))
    out['bubble'] = nine(C('f4f0e8'), C('ffffff'), C('c8c0d8'), r=3)
    out['banner'] = nine(C('1e1630', 235), C('ff6ad5'), C('120c1e', 235))
    out['banner_good'] = nine(C('16302a', 235), C('6af0a0'), C('0c1e18', 235))
    return out


def make_finger():
    art = """
......kk........
.....kwwk.......
.....kwwk.......
.....kwwk.......
.....kwwk.......
.....kwwkkk.....
.....kwwkwwkk...
..kk.kwwkwwkwkk.
.kwwkkwwkwwkwwwk
.kwwwkwwwwwwwwwk
..kwwwwwwwwwwwwk
..kwwwwwwwwwwwk.
...kwwwwwwwwwwk.
...kwwwwwwwwwk..
....kwwwwwwwwk..
....kWWWWWWWWk..
....kkkkkkkkkk.."""
    rows = [r for r in art.split('\n') if r]
    c = Canvas(16, 18)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            col = PAL.get(ch)
            if col:
                c.set(i, j, col)
    return c.img


def make_logo(font_path):
    w, h = 240, 84
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    big = ImageFont.truetype(font_path, 24)
    small = ImageFont.truetype(font_path, 16)
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    t1 = "FLOOR 13"
    tw = d.textlength(t1, font=big)
    x1 = int((w - tw) / 2)
    t2 = "NIGHT SHIFT"
    tw2 = d.textlength(t2, font=small)
    x2 = int((w - tw2) / 2)
    # deep shadow
    for dx, dy in ((3, 3), (2, 3), (3, 2)):
        d.text((x1 + dx, 10 + dy), t1, font=big, fill=(40, 10, 60, 255))
        d.text((x2 + dx, 48 + dy), t2, font=small, fill=(10, 40, 50, 255))
    img.alpha_composite(layer)
    # outlines
    ol = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ol)
    for dx in (-2, -1, 0, 1, 2):
        for dy in (-2, -1, 0, 1, 2):
            if abs(dx) + abs(dy) in (1, 2, 3):
                d.text((x1 + dx, 10 + dy), t1, font=big, fill=(26, 16, 32, 255))
                d.text((x2 + dx, 48 + dy), t2, font=small, fill=(26, 16, 32, 255))
    img.alpha_composite(ol)
    # gradient letters
    fg = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(fg)
    d.text((x1, 10), t1, font=big, fill=(255, 255, 255, 255))
    d.text((x2, 48), t2, font=small, fill=(255, 255, 255, 255))
    p = fg.load()
    for y in range(h):
        for x in range(w):
            if p[x, y][3]:
                if y < 40:
                    t = (y - 10) / 24
                    col = (255, int(120 + 100 * (1 - t)), int(80 + 140 * (1 - t)), 255) if t > 0.5 else (255, 230, 150, 255)
                    if 10 <= y < 14:
                        col = (255, 250, 220, 255)
                    p[x, y] = col
                else:
                    t = (y - 48) / 16
                    p[x, y] = (int(120 + 60 * (1 - t)), int(220 + 30 * (1 - t)), 255, 255)
    img.alpha_composite(fg)
    return img


def icon_sky(s, moon=(39, 9)):
    c = Canvas(s, s)
    for y in range(s):
        for x in range(s):
            t = y / s
            c.set(x, y, (int(30 + 40 * t), int(16 + 10 * t), int(70 + 30 * t), 255))
    k = s / 48.0
    for (x, y) in ((5, 6), (40, 4), (44, 14), (8, 20), (36, 9), (3, 32), (45, 30)):
        c.set(int(x * k), int(y * k), C('fff4d6'))
    mx, my = int(moon[0] * k), int(moon[1] * k)
    c.disc(mx, my, 4, C('fff4d6'))
    t = (my - 1) / s
    c.disc(mx + 2, my - 1, 3.5, (int(30 + 40 * t), int(16 + 10 * t), int(70 + 30 * t), 255))
    return c


def make_adaptive_icon(font_path):
    fg = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
    art = make_app_icon(font_path, with_sky=False, size=48)
    fg.alpha_composite(art.resize((288, 288), Image.NEAREST), (72, 72))
    bg = icon_sky(72, moon=(37, 13)).img.resize((432, 432), Image.NEAREST)
    return fg, bg


def make_app_icon(font_path, with_sky=True, size=192):
    s = 48
    c = icon_sky(s) if with_sky else Canvas(s, s)
    # elevator frame
    fx, fy, fw, fh = 10, 12, 28, 32
    rounded(c, fx - 2, fy - 6, fw + 4, fh + 8, K, 3)
    c.rect(fx - 1, fy - 5, fw + 2, fh + 6, C('d8a040'))
    c.rect(fx - 1, fy - 5, fw + 2, 1, C('ffe08a'))
    c.rect(fx + 8, fy - 5, 12, 7, C('1a0e0a'))
    c.rect(fx, fy + 2, fw, fh - 3, C('fff0c0'))
    for y in range(fy + 2, fy + fh - 1):
        c.rect(fx + 11, y, 6, 1, C('ffe8a0'))
    # half-open doors
    for x0 in (fx, fx + 17):
        c.rect(x0, fy + 2, 11, fh - 3, C('8a5a2a'))
        c.rect(x0 + 1, fy + 3, 9, 12, C('a87040'))
        c.rect(x0 + 1, fy + 17, 9, 11, C('a87040'))
    c.rect(fx - 1, fy + fh - 1, fw + 2, 2, C('8a5a22'))
    # ghost peeking out of the gap
    gx, gy = fx + 11, fy + 10
    c.rect(gx, gy, 6, 10, C('eef0ff'))
    c.px(gx + 1, gy + 3, K)
    c.px(gx + 4, gy + 3, K)
    c.rect(gx + 2, gy + 6, 2, 1, K)
    amber = C('ffa82e')
    one = ['.#.', '##.', '.#.', '.#.', '###']
    three = ['###', '..#', '.##', '..#', '###']
    for j in range(5):
        for i in range(3):
            if one[j][i] == '#':
                c.set(fx + 10 + i, fy - 4 + j, amber)
            if three[j][i] == '#':
                c.set(fx + 15 + i, fy - 4 + j, amber)
    img = c.img
    return img if size == 48 else img.resize((size, size), Image.NEAREST)
