#!/usr/bin/env python3
"""Generates every sprite of FLOOR 13 into ../assets/sprites (run from anywhere)."""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art_people  # noqa: E402
import art_world  # noqa: E402
import art_ui  # noqa: E402

OUT = os.path.join(HERE, '..', 'assets', 'sprites')
FONT = os.path.join(HERE, '..', 'assets', 'fonts', 'PressStart2P.ttf')


def save(img, name):
    img.save(os.path.join(OUT, name))


def main():
    os.makedirs(OUT, exist_ok=True)
    save(art_people.make_sheet(), 'passengers.png')
    floors = Image.new('RGBA', (art_world.W, art_world.FH * 13), (0, 0, 0, 0))
    for i in range(1, 14):
        floors.alpha_composite(art_world.make_floor(i), (0, (i - 1) * art_world.FH))
    save(floors, 'floors.png')
    save(art_world.make_shaft_tile(), 'shaft.png')
    back, front = art_world.make_cabin()
    save(back, 'cabin_back.png')
    save(front, 'cabin_front.png')
    save(art_world.make_roof(), 'roof.png')
    save(art_world.make_neon(FONT), 'neon.png')
    save(art_world.make_street(), 'street.png')
    save(art_world.make_lamp(), 'lamp.png')
    save(art_world.make_taxi(), 'taxi.png')
    save(art_world.make_skyline(), 'skyline.png')
    save(art_world.make_moon(), 'moon.png')
    save(art_world.make_door_open(), 'door_open.png')
    save(art_world.make_coin_pile(), 'coin_pile.png')
    save(art_ui.make_icons(), 'icons.png')
    save(art_ui.make_digits(), 'digits.png')
    save(art_ui.make_buttons(), 'floor_buttons.png')
    for name, img in art_ui.make_ninepatches().items():
        save(img, 'ui_%s.png' % name)
    save(art_ui.make_finger(), 'finger.png')
    logo = art_ui.make_logo(FONT)
    save(logo, 'logo.png')
    splash = Image.new('RGBA', (logo.width * 3, logo.height * 3 + 60), (0, 0, 0, 0))
    splash.alpha_composite(logo.resize((logo.width * 3, logo.height * 3), Image.NEAREST), (0, 30))
    save(splash, 'splash.png')
    icon = art_ui.make_app_icon(FONT)
    icon.save(os.path.join(HERE, '..', 'icon.png'))
    print('sprites written to', os.path.normpath(OUT))


if __name__ == '__main__':
    main()
