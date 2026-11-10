"""Builds every image of Deep Bounce into assets/art.   python3 tools/art/build.py [group ...]
Groups: stones walls shaft cannon balls fx ui icon. Deterministic (fixed seeds)."""
import os
import sys
import json
import time
sys.path.insert(0, os.path.dirname(__file__))
from kit import *
import stones
import cannon
import misc

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'art')
SHAPES = [(1, 1), (2, 1), (1, 2), (2, 2)]


def path(*p):
    full = os.path.join(OUT, *p)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def build_stones():
    for (w, h) in SHAPES:
        for v in range(4):
            im, _ = stones.block(w, h, v, 1000 + v * 37 + w * 7 + h * 3)
            im.save(path('stones', f'stone_{w}x{h}_v{v}.png'))
        for st in (1, 2, 3):
            stones.crack_overlay(w, h, st, 2000 + st * 11 + w * 5 + h).save(path('stones', f'crack_{w}x{h}_s{st}.png'))
        stones.vein_overlay(w, h, 3000 + w * 5 + h).save(path('stones', f'vein_{w}x{h}.png'))
    for i in range(6):
        stones.debris(4000 + i, [26, 30, 34, 22, 38, 28][i]).save(path('fx', f'debris_{i}.png'))


def build_walls():
    stones.wall_strip('L', 51).save(path('walls', 'wall_left.png'))
    stones.wall_strip('R', 52).save(path('walls', 'wall_right.png'))


def build_shaft():
    misc.shaft().save(path('bg', 'shaft.png'))
    misc.bedrock().save(path('bg', 'bedrock.png'))
    misc.crust().save(path('bg', 'crust.png'))


def build_cannon():
    meta = {}
    for skin in cannon.SKINS:
        im, piv = cannon.base_sprite(skin)
        im.save(path('cannon', f'base_{skin}.png'))
        alb, nrm, bpiv = cannon.barrel(skin)
        alb.save(path('cannon', f'barrel_{skin}.png'))
        if skin == 'classic':
            nrm.save(path('cannon', 'barrel_normal.png'))
        cannon.collar(skin).save(path('cannon', f'collar_{skin}.png'))
        cannon.preview(skin).save(path('cannon', f'preview_{skin}.png'))
        meta[skin] = {'base_pivot': [piv[0], piv[1]], 'barrel_pivot': [bpiv[0], bpiv[1]]}
    a, origin = cannon.arch()
    a.save(path('cannon', 'arch.png'))
    meta['arch_origin'] = list(origin)
    with open(path('cannon', 'meta.json'), 'w') as f:
        json.dump(meta, f, indent=1)


def build_balls():
    for k in ('normal', 'heavy', 'electric'):
        misc.ball(k).save(path('balls', f'ball_{k}.png'))
    misc.glow(96, '#fff3d6', 1.6).save(path('fx', 'glow_warm.png'))
    misc.glow(128, '#ffffff', 2.4).save(path('fx', 'glow_white.png'))
    misc.glow(96, '#7ff7ee', 1.6).save(path('fx', 'glow_teal.png'))
    misc.gem(40, 56, 5).save(path('fx', 'gem.png'))
    misc.gem(80, 112, 6).save(path('ui', 'gem_icon.png'))
    misc.ball('normal', 22).save(path('ui', 'ball_icon.png'))


def build_fx():
    misc.sparkle().save(path('fx', 'sparkle.png'))
    misc.dust().save(path('fx', 'dust.png'))


def build_ui():
    misc.panel().save(path('ui', 'panel.png'))
    misc.panel(160, 160, 26, '#0d363a', '#06191c', '#279b9b', '#8ff0e6', True, 9, 7).save(path('ui', 'card.png'))
    misc.panel(96, 96, 20, '#0d363a', '#071f22', '#279b9b', '#8ff0e6', False, 10, 5).save(path('ui', 'button_teal.png'))
    misc.panel(96, 96, 20, '#123f43', '#0a2c30', '#4fd6cc', '#d2fff9', False, 12, 5).save(path('ui', 'button_teal_hover.png'))
    misc.panel(96, 96, 20, '#2bb3ac', '#147a78', '#bffaf3', '#ffffff', False, 13, 5).save(path('ui', 'button_on.png'))
    misc.stone_button(240, 104, 8, 1.0).save(path('ui', 'button_stone.png'))
    misc.stone_button(240, 104, 8, 1.18).save(path('ui', 'button_stone_hover.png'))
    misc.stone_button(240, 104, 8, 0.55).save(path('ui', 'button_stone_dim.png'))
    misc.logo(1.0).save(path('ui', 'logo.png'))
    misc.icon_more_balls().save(path('ui', 'up_balls.png'))
    misc.icon_ball_kind('heavy').save(path('ui', 'up_heavy.png'))
    misc.icon_ball_kind('electric').save(path('ui', 'up_electric.png'))
    misc.lock_icon().save(path('ui', 'lock.png'))
    misc.pause_glyph().save(path('ui', 'pause.png'))
    misc.speed_glyph().save(path('ui', 'speed.png'))


def build_icon():
    import icon
    icon.build(ROOT)


GROUPS = dict(stones=build_stones, walls=build_walls, shaft=build_shaft, cannon=build_cannon, balls=build_balls,
              fx=build_fx, ui=build_ui, icon=build_icon)

if __name__ == '__main__':
    todo = sys.argv[1:] or list(GROUPS)
    for g in todo:
        t = time.time()
        GROUPS[g]()
        print(f'{g}: {time.time() - t:.1f}s')
