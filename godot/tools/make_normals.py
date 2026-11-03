"""Normal maps for the pixel art, so Godot's 2D lights shade it as if it had volume.

  python3 godot/tools/make_normals.py            (from the repo root; needs Pillow, numpy, scipy)

For every picture in godot/assets/rest and godot/assets/new it writes <name>_n.png next to it (skipping portraits,
icons and the normal maps themselves). Two kinds of relief are mixed:
  * sprites (pictures with transparency): a rounded bevel from the silhouette inwards - edges turn away from the
    viewer, so a lamp lights the side of a crate or a person that faces it - plus fine detail from brightness;
  * backgrounds (opaque): relief from brightness only, at two scales (tile seams, bricks, pipes; broad shapes).
Encoding: OpenGL convention (x right, y up, z towards the viewer), as Godot expects."""
from PIL import Image
from pathlib import Path
import numpy as np
from scipy import ndimage

root = Path(__file__).resolve().parents[2]
DIRS = [root / 'godot/assets/rest', root / 'godot/assets/new']
SKIP = ('portrait', '_n.', 'icons', 'portraits')

def luminance(rgb):
    return (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255.0

def encode(h, strength, mask=None):
    gy, gx = np.gradient(h)
    n = np.dstack([-gx * strength, gy * strength, np.ones_like(h)])   # y flipped: image rows go down, normals go up
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    if mask is not None:
        n[~mask] = (0.0, 0.0, 1.0)
    out = ((n * 0.5 + 0.5) * 255).round().astype(np.uint8)
    return Image.fromarray(out, 'RGB')

def sprite(im):
    a = np.asarray(im.getchannel('A')) > 110
    rgb = np.asarray(im.convert('RGB')).astype(np.float32)
    # Bevel: distance to the outline, eased, so the rim curves away over ~2 world units (6 px).
    r = 7.0
    d = ndimage.distance_transform_edt(a)
    bevel = np.sin(np.clip(d / r, 0, 1) * np.pi / 2)
    detail = ndimage.gaussian_filter(luminance(rgb), 0.9)
    h = bevel * 3.2 + detail * 1.4
    return encode(h, 2.2, a)

def background(im):
    rgb = np.asarray(im.convert('RGB')).astype(np.float32)
    l = luminance(rgb)
    h = ndimage.gaussian_filter(l, 1.1) * 2.2 + ndimage.gaussian_filter(l, 5.0) * 3.0
    return encode(h, 2.6)

def main():
    n = 0
    for d in DIRS:
        for f in sorted(list(d.glob('*.png')) + list(d.glob('*.jpg'))):
            if any(s in f.name for s in SKIP):
                continue
            im = Image.open(f)
            has_alpha = im.mode in ('RGBA', 'LA', 'P') and im.convert('RGBA').getextrema()[3][0] < 200
            nm = sprite(im.convert('RGBA')) if has_alpha else background(im)
            if not has_alpha:
                # Backgrounds: relief is broad, half resolution is plenty (Godot samples it by UV, any size works).
                nm = nm.resize((nm.width // 2, nm.height // 2), Image.Resampling.BILINEAR)
            nm.save(f.with_name(f.stem + '_n.png'))
            n += 1
    print('normal maps:', n)

if __name__ == '__main__':
    main()
