"""Pixel-art sprites for the squad prototype, taken from the owner's art pack (the style of the earlier versions).

  python3 squad/tools/prepare_assets.py      (from the repo root; needs Pillow, numpy)

* Characters: the atlases already cut for the side-view game (godot/assets/rest + godot/assets/new: Mira A108,
  Einstein A105 + M2, crawler A161 + M1) with their frames (foot anchor, foot line) -> squad/assets/chars + data.
* Props: states cut from art/rest the same way as godot/tools/import_rest.py (states share one canvas, bottom-centred)
  -> squad/assets/props/<name>_<state>.png, heights in world units of this prototype (a person is 1.7 tall).
* Ground: small tiling pixel textures (moss and dirt, cracked asphalt, concrete) drawn here from the pack's palette.
In the game every sprite stands upright facing the camera (billboard), pixels kept sharp (nearest filter)."""
from PIL import Image
from pathlib import Path
import importlib.util, json, shutil
import numpy as np

root = Path(__file__).resolve().parents[2]
out = root / 'squad/assets'
spec = importlib.util.spec_from_file_location('ir', root / 'godot/tools/import_rest.py'); ir = importlib.util.module_from_spec(spec); spec.loader.exec_module(ir)
OLD = 1.7 / 70.0       # old world units (a person 70) -> prototype units (a person 1.7)

def chars():
    (out / 'chars').mkdir(parents=True, exist_ok=True)
    rest = json.loads((root / 'godot/data/rest_chars.json').read_text())
    new = json.loads((root / 'godot/data/new_art.json').read_text())['chars']
    data = {}
    for name in ['mira', 'einstein', 'crawler']:
        shutil.copy(root / f'godot/assets/rest/{name}.png', out / f'chars/{name}.png')
        d = {'unit': rest[name]['unit'], 'frames': [dict(f, sheet=0) for f in rest[name]['frames']], 'names': {}, 'sheets': [f'res://assets/chars/{name}.png']}
        if name in new and 'extra' in new[name]:
            shutil.copy(root / f'godot/assets/new/{name}_extra.png', out / f'chars/{name}_extra.png')
            d['sheets'].append(f'res://assets/chars/{name}_extra.png')
            base = len(d['frames'])
            d['frames'] += [dict(f, sheet=1) for f in new[name]['frames']]
            d['names'] = {k: base + v for k, v in new[name]['names'].items()}
        data[name] = d
    return data

PROPS = {}
def from_rest(name, h_old):
    """A prop already cut for the side-view game: copy its states, convert its height."""
    i = 0
    while (root / f'godot/assets/rest/{name}_{i}.png').exists() or (root / f'godot/assets/new/{name}_{i}.png').exists():
        src = root / f'godot/assets/rest/{name}_{i}.png'
        if not src.exists():
            src = root / f'godot/assets/new/{name}_{i}.png'
        shutil.copy(src, out / f'props/{name}_{i}.png')
        i += 1
    PROPS[name] = {'states': i, 'h': round(h_old * OLD, 3)}

def cut(aid, name, n, h):
    """New states from the pack, side by side, on one canvas."""
    ir.out = out / 'props'
    ir.PROPS.clear()
    ir.states(aid, name, n, h / OLD)
    PROPS[name] = {'states': ir.PROPS[name]['states'], 'h': h}

def cut_grid(aid, name, cols, rows, h):
    im = ir.load(aid)
    cw, ch = im.width // cols, im.height // rows
    parts = []
    for r in range(rows):
        for c in range(cols):
            p = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            parts.append(p.crop(p.getbbox()))
    W = max(p.width for p in parts); H = max(p.height for p in parts)
    k = 300 / H
    for i, p in enumerate(parts):
        cv = Image.new('RGBA', (W, H)); cv.alpha_composite(p, ((W - p.width) // 2, H - p.height))
        ir.scaled(cv, k).save(out / f'props/{name}_{i}.png')
    PROPS[name] = {'states': len(parts), 'h': h}

def single(aid, name, h):
    im = ir.load(aid); im = im.crop(im.getbbox())
    k = min(1.0, 420 / im.height)
    ir.scaled(im, k).save(out / f'props/{name}_0.png')
    PROPS[name] = {'states': 1, 'h': h}

def tile(name, base, spots, seed, cracks=0, lines=0):
    """A 64x64 tiling pixel texture: a base colour, speckles from a small palette, optional cracks and seams."""
    rng = np.random.default_rng(seed)
    a = np.zeros((64, 64, 3), np.uint8); a[:] = base
    for col, n, size in spots:
        for _ in range(n):
            x, y = rng.integers(0, 64, 2); s = rng.integers(1, size + 1)
            for dy in range(s):
                for dx in range(s):
                    a[(y + dy) % 64, (x + dx) % 64] = col
    for _ in range(cracks):
        x, y = rng.integers(0, 64, 2)
        for _ in range(rng.integers(8, 20)):
            a[y % 64, x % 64] = (0.6 * np.array(base)).astype(np.uint8)
            x += rng.integers(-1, 2); y += 1
    if lines:
        a[::lines, :] = (0.8 * np.array(base)).astype(np.uint8); a[:, ::lines] = (0.8 * np.array(base)).astype(np.uint8)
    Image.fromarray(a).save(out / f'ground/{name}.png')

def main():
    (out / 'props').mkdir(parents=True, exist_ok=True)
    (out / 'ground').mkdir(parents=True, exist_ok=True)
    data = chars()
    # Props already cut for the side-view game (old heights, a person = 70).
    for name, h in [('barrel', 32), ('crate', 24), ('rubble', 60), ('generator', 34), ('purifier', 52), ('cart', 44),
                    ('lantern', 22), ('tap', 56), ('cabinet', 72), ('workbench', 48), ('beam', 64.4), ('crawler_nest', 13),
                    ('planks', 9), ('washer', 40), ('rag_pile', 13.4), ('sign_station', 56), ('puddle', 9.5), ('laundry_facade', 293.3),
                    ('jack', 30), ('pipe', 14)]:
        from_rest(name, h)
    # New from the pack.
    cut('A176', 'tank', 2, 1.3)
    cut('A135', 'minecart', 2, 0.9)
    cut('A124', 'radio', 2, 0.5)
    cut_grid('A117', 'bed', 2, 2, 0.45)
    single('A199', 'trees', 2.9)
    single('A040', 'stump', 1.1)
    single('A031', 'metro', 4.2)
    single('A030', 'bench', 1.2)
    single('A034', 'genset', 1.1)
    # Ground textures (tiling): moss and dirt, cracked asphalt, concrete slabs, mud.
    tile('grass', (52, 74, 40), [((63, 88, 46), 260, 2), ((43, 61, 34), 220, 2), ((92, 104, 58), 40, 1), ((86, 70, 46), 30, 2), ((160, 140, 70), 6, 1)], 1)
    tile('road', (68, 66, 62), [((80, 78, 72), 200, 2), ((56, 54, 50), 160, 2), ((70, 92, 52), 40, 2)], 2, cracks=4)
    tile('concrete', (104, 100, 92), [((116, 112, 104), 160, 2), ((90, 86, 80), 140, 2), ((120, 84, 56), 20, 2)], 3, cracks=2, lines=32)
    tile('mud', (78, 62, 44), [((90, 72, 50), 200, 2), ((64, 50, 36), 200, 2), ((60, 84, 44), 50, 2)], 4)
    (root / 'squad/data').mkdir(exist_ok=True)
    (root / 'squad/data/sprites.json').write_text(json.dumps({'chars': data, 'props': PROPS}, ensure_ascii=False, separators=(',', ':')))
    print('chars', list(data), '| props', len(PROPS))

if __name__ == '__main__':
    main()
