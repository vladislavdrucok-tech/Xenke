"""Store and launcher graphics from the key art (assets/brand/key_art.png, 941x1672):
   assets/art/ui/icon_512.png (Play hi-res icon), icon.png (192, legacy launcher), icon_fg.png / icon_bg.png
   (adaptive layers 432), assets/brand/splash.png (boot splash), store/feature_graphic.png (1024x500).
   python3 tools/store/brand.py"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = Image.open(os.path.join(ROOT, 'assets/brand/key_art.png')).convert('RGB')
CX, CY, R = 462, 594, 330          # emblem centre and radius (rivet tips included)
TITLE = (120, 935, 830, 1330)      # "DEEP BOUNCE" with the turquoise stroke


def circle_mask(size, r, feather=2.0):
    m = Image.new('L', (size * 4, size * 4), 0)
    c = size * 2
    ImageDraw.Draw(m).ellipse([c - r * 4, c - r * 4, c + r * 4, c + r * 4], fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    return m.filter(ImageFilter.GaussianBlur(feather)) if feather else m


def emblem(alpha=True, pad=1.0):
    half = int(R * pad)
    crop = SRC.crop((CX - half, CY - half, CX + half, CY + half)).convert('RGBA')
    if alpha:
        crop.putalpha(circle_mask(crop.width, R - 1, 1.5))
    return crop


def stone_bg(w, h, seed_box=(110, 1330, 832, 1672)):
    box = SRC.crop(seed_box)
    s = max(w / box.width, h / box.height)
    box = box.resize((int(box.width * s) + 1, int(box.height * s) + 1), Image.LANCZOS)
    x = (box.width - w) // 2
    y = (box.height - h) // 2
    return box.crop((x, y, x + w, y + h)).filter(ImageFilter.GaussianBlur(0.6)).convert('RGBA')


def out(*p):
    path = os.path.join(ROOT, *p)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def main():
    # Play hi-res icon: the emblem filling a full square of the same stone (Play rounds the corners itself)
    sq = emblem(alpha=False, pad=1.1).resize((512, 512), Image.LANCZOS)
    sq.convert('RGB').save(out('assets/art/ui/icon_512.png'))
    sq.resize((192, 192), Image.LANCZOS).convert('RGB').save(out('icon.png'))
    # adaptive icon: background = stone, foreground = emblem inside the 66 % safe circle
    stone_bg(432, 432).convert('RGB').save(out('assets/art/ui/icon_bg.png'))
    fg = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
    e = emblem().resize((300, 300), Image.LANCZOS)
    fg.alpha_composite(e, ((432 - 300) // 2, (432 - 300) // 2))
    fg.save(out('assets/art/ui/icon_fg.png'))
    # monochrome (Android 13 themed icons): the emblem's light shapes as a white silhouette
    a = np.asarray(e.convert('RGBA')).astype(float)
    lum = (a[..., 0] * 0.3 + a[..., 1] * 0.5 + a[..., 2] * 0.2)
    ring = np.clip((a[..., 0] - a[..., 2] - 40) / 60, 0, 1)
    light = np.clip((lum - 150) / 60, 0, 1)
    mono_a = np.clip(np.maximum(ring, light), 0, 1)
    mono_a = np.asarray(Image.fromarray((mono_a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6))).astype(float) / 255
    mono_a = np.clip((mono_a - 0.45) * 4, 0, 1) * (a[..., 3] / 255)
    mono = np.zeros((300, 300, 4), np.uint8)
    mono[..., :3] = 255
    mono[..., 3] = (mono_a * 255).astype(np.uint8)
    mfg = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
    mfg.alpha_composite(Image.fromarray(mono, 'RGBA'), (66, 66))
    mfg.save(out('assets/art/ui/icon_mono.png'))
    # boot splash: the key art as it is
    SRC.save(out('assets/brand/splash.png'))
    # feature graphic 1024 x 500: emblem left, title right, on the same stone
    fgph = stone_bg(1024, 500)
    glow = Image.new('L', (1024, 500), 0)
    ImageDraw.Draw(glow).ellipse([40, 20, 480, 480], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    teal = Image.new('RGBA', (1024, 500), (40, 160, 150, 0))
    teal.putalpha(glow)
    fgph.alpha_composite(teal)
    em = emblem().resize((430, 430), Image.LANCZOS)
    fgph.alpha_composite(em, (45, 35))
    # the title's letters and stroke cut out by colour (cream letters, turquoise stroke) with a soft shadow
    title = SRC.crop(TITLE).convert('RGB')
    ta = np.asarray(title).astype(float)
    cream = np.clip((np.minimum(ta[..., 0] - 140, ta[..., 1] - 120) / 50), 0, 1) * (ta[..., 0] - ta[..., 2] > 20)
    stroke = np.clip((np.minimum(ta[..., 1], ta[..., 2]) - 130) / 50, 0, 1) * (ta[..., 0] < 150)
    alpha = Image.fromarray((np.clip(np.maximum(cream, stroke), 0, 1) * 255).astype(np.uint8), 'L').filter(ImageFilter.GaussianBlur(0.8))
    t = title.convert('RGBA')
    t.putalpha(alpha)
    h = 300
    t = t.resize((int(t.width * h / t.height), h), Image.LANCZOS)
    x, y = 1024 - t.width - 30, (500 - h) // 2 + 5
    shadow = Image.new('RGBA', t.size, (5, 15, 15, 0))
    shadow.putalpha(t.getchannel('A').filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.8)))
    fgph.alpha_composite(shadow, (x + 4, y + 8))
    fgph.alpha_composite(t, (x, y))
    fgph.convert('RGB').save(out('store/feature_graphic.png'))
    # the in-game title (menu, HUD, all-clear) uses the same lettering as the key art
    logo = Image.open(out('assets/art/ui/logo.png'))
    lt = Image.new('RGBA', logo.size, (0, 0, 0, 0))
    full = title.convert('RGBA')
    full.putalpha(alpha)
    k = min(logo.width / full.width, logo.height / full.height)
    full = full.resize((int(full.width * k), int(full.height * k)), Image.LANCZOS)
    sh = Image.new('RGBA', full.size, (20, 8, 2, 0))
    sh.putalpha(full.getchannel('A').filter(ImageFilter.GaussianBlur(4)).point(lambda v: int(v * 0.85)))
    ox, oy = (logo.width - full.width) // 2, (logo.height - full.height) // 2
    lt.alpha_composite(sh, (ox + 3, oy + 6))
    lt.alpha_composite(full, (ox, oy))
    lt.save(out('assets/art/ui/logo.png'))
    print('ok')


if __name__ == '__main__':
    main()
