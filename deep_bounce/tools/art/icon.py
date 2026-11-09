"""App icon: the cannon in its arch firing a ball past a crystal, on the dark shaft. Legacy 192 px icon plus
adaptive foreground/background layers (432 px)."""
import os
import numpy as np
from PIL import Image, ImageFilter
from kit import *
import cannon
import misc
import stones


def background(size):
    rng = np.random.default_rng(31)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64) / size
    d = np.sqrt((xx - 0.45) ** 2 + (yy - 0.35) ** 2)
    col = lerp(rgb('#0f4a50'), rgb('#03191c'), np.clip(d * 1.4, 0, 1))
    col = col * (0.85 + 0.3 * fft_noise(size, size, 2.4, rng))[..., None]
    return to_img(col).convert('RGBA')


def foreground(size, safe=1.0):
    """Content scaled to `safe` of the canvas (adaptive icons keep the middle 66%)."""
    S0 = 512
    fg = Image.new('RGBA', (S0, S0), (0, 0, 0, 0))
    stone, _ = stones.block(2, 2, 0, 77)
    stone = stone.resize((300, 300), Image.LANCZOS)
    fg.alpha_composite(stone, (262, 360))
    base, piv = cannon.base_sprite('classic')
    br, bpiv = cannon.lit_barrel('classic', 0.75)
    col = cannon.collar('classic')
    k = 1.25
    base = base.resize((int(base.width * k), int(base.height * k)), Image.LANCZOS)
    br = br.resize((int(br.width * k), int(br.height * k)), Image.LANCZOS)
    col = col.resize((int(col.width * k), int(col.height * k)), Image.LANCZOS)
    cx, cy = 190, 170
    fg.alpha_composite(base, (int(cx - piv[0] * k), int(cy - piv[1] * k)))
    fg.alpha_composite(br, (int(cx - bpiv[0] * k), int(cy - bpiv[1] * k)))
    fg.alpha_composite(col, (int(cx - col.width / 2), int(cy - col.height / 2)))
    glow = misc.glow(200, '#ffe2a8', 1.6)
    ball = misc.ball('normal', 22)
    bx, by = 372, 300
    fg.alpha_composite(glow, (bx + ball.width // 2 - 100, by + ball.height // 2 - 100))
    fg.alpha_composite(ball, (bx, by))
    gem = misc.gem(64, 90, 9)
    fg.alpha_composite(gem, (430, 250))
    if safe < 1.0:
        inner = int(S0 * safe)
        small = fg.resize((inner, inner), Image.LANCZOS)
        fg = Image.new('RGBA', (S0, S0), (0, 0, 0, 0))
        fg.alpha_composite(small, ((S0 - inner) // 2, (S0 - inner) // 2))
    return fg.resize((size, size), Image.LANCZOS)


def build(root):
    full = background(512)
    full.alpha_composite(foreground(512))
    # rounded square for the legacy icon
    mask = Image.new('L', (512, 512), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 511, 511], 96, fill=255)
    legacy = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    legacy.paste(full, (0, 0), mask)
    legacy.resize((192, 192), Image.LANCZOS).save(os.path.join(root, 'icon.png'))
    legacy.save(os.path.join(root, 'assets', 'art', 'ui', 'icon_512.png'))
    foreground(432, 0.72).save(os.path.join(root, 'assets', 'art', 'ui', 'icon_fg.png'))
    background(432).save(os.path.join(root, 'assets', 'art', 'ui', 'icon_bg.png'))
