"""Import the art made after the 'Remaining' pack (blocks M, P, I, C of docs/GPT_MISSING_ART_UK.md) into the Godot project.

  python3 godot/tools/import_new.py --unzip A.zip B.zip ...   unpack archives into art/new/<archive name>/ (PNG, JSON, MD, TXT only)
  python3 godot/tools/import_new.py                           cut everything found in art/new into godot/assets/new + godot/data/new_art.json
  python3 godot/tools/import_new.py --status                  only list which expected files are present and which are missing
  options: --src <dir> (default art/new), --project <dir> (default godot), --scale <name>=<factor> (fix a sheet drawn at another scale)

Files are found by name anywhere under the source folder (M1_crawler_actions.png ...). Missing files are skipped: the game keeps
its current pictures for them. Same rules as tools/import_rest.py: 3 px per world unit, the states of one object share one canvas
(bottom-centred, or pinned at the hinge for the drawbridge), character frames get a foot anchor and a hand point.
Pose sheets with extra moves (M1, M2, P3) are scaled like their base sheet, because the artist drew them at the reference scale;
the script prints how their figure heights compare, so a sheet drawn bigger or smaller shows up at once. Needs Pillow."""
from PIL import Image
from pathlib import Path
import importlib.util, json, statistics, sys, zipfile

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('imp', root / 'scripts/import-art.py'); imp = importlib.util.module_from_spec(spec); spec.loader.exec_module(imp)
PX = 3

# ---------------------------------------------------------------- what is expected
WALK8 = ['jump_crouch', 'jump_up', 'fall', 'land', 'climb_1', 'climb_2', 'hurt', 'run']
CHAR_EXTRA = {   # file -> (character, cols, rows, frame names, base sheet in art/rest)
    'M1_crawler_actions.png': ('crawler', 4, 2, ['sleep', 'sleep_breathe', 'eat', 'alert', 'lunge', 'hit', 'flee', 'land'], 'laundry_mission/A161.png', (3, 2)),
    'M2_einstein_moves.png': ('einstein', 4, 2, WALK8, 'chapter_01/A105.png', (4, 2)),
    'P3_mira_moves.png': ('mira', 4, 2, WALK8, 'chapter_01/A108.png', (4, 2)),
}
CHAR_FULL = {    # file -> (character, cols, rows, frame names); walking height = median of the 4 walk frames
    'P2_sava_sheet.png': ('sava', 4, 2, ['walk_0', 'walk_1', 'walk_2', 'walk_3', 'idle', 'talk', 'arms_crossed', 'point']),
}
# file -> list of (name, [cell indices = states], size, anchor); size: ('h', units) or ('w', units); cells counted left-right, top-bottom.
SHEETS = {
    'M3_beam.png': (1, 2, [('beam', [0, 1], ('w', 210), 'bottom')]),
    'M4_walkway_hole.png': (1, 2, [('walkway_hole', [0, 1], ('w', 300), 'bottom')]),
    'M5_laundry_props.png': (4, 2, [('washer', [0, 1], ('h', 42), 'bottom'), ('washer_toppled', [2], ('sheet', 'washer'), 'bottom'),
                                    ('laundry_basket', [3], ('sheet', 'washer'), 'bottom'), ('drying_rack', [4], ('sheet', 'washer'), 'bottom'),
                                    ('sink', [5], ('sheet', 'washer'), 'bottom'), ('rag_pile', [6], ('sheet', 'washer'), 'bottom'),
                                    ('crawler_nest', [7], ('sheet', 'washer'), 'bottom')]),
    # Cans are drawn too big on the sheet next to the door, so every small prop gets its own height.
    'M7_small_props.png': (4, 2, [('sign_station', [0], ('h', 56), 'bottom'), ('planks', [1], ('h', 9), 'bottom'), ('can', [2], ('h', 7), 'bottom'),
                                  ('can_crushed', [3], ('h', 4), 'bottom'), ('service_door', [4], ('h', 80), 'bottom'),
                                  ('winch', [5, 6], ('h', 30), 'bottom'), ('puddle', [7], ('w', 60), 'bottom')]),
    'C1_lab_mechanisms.png': (4, 2, [('power_switch', [0, 1], ('h', 40), 'bottom'), ('drawbridge', [2, 3], ('w', 110), 'hinge'),
                                     ('bulkhead', [4, 5], ('h', 96), 'bottom'), ('lab_pump', [6, 7], ('h', 32), 'bottom')]),
    'C2_pavlo_shelf.png': (3, 1, [('pavlo_shelf', [0, 1, 2], ('h', 78), 'bottom')]),
}
SINGLES = {'M6_laundry_facade.png': ('laundry_facade', ('h', 300))}
PORTRAITS = ['nazar', 'mira', 'sava', 'pavlo', 'einstein']
ICONS = ['wrench', 'jack', 'planks', 'can', 'filter_body', 'repair_unit', 'rag', 'scrap',
         'seeds', 'measuring_cup', 'flashlight', 'notebook', 'heart', 'saved', 'journal', 'can_open']
EXPECTED = list(CHAR_EXTRA) + list(CHAR_FULL) + list(SHEETS) + list(SINGLES) + [f'P1_portrait_{p}.png' for p in PORTRAITS] + ['I1_item_icons.png']

# ---------------------------------------------------------------- helpers
def args():
    a = sys.argv[1:]; o = {'src': root / 'art/new', 'project': root / 'godot', 'scale': {}, 'unzip': [], 'status': False}
    i = 0
    while i < len(a):
        if a[i] == '--src': o['src'] = Path(a[i + 1]).resolve(); i += 2
        elif a[i] == '--project': o['project'] = Path(a[i + 1]).resolve(); i += 2
        elif a[i] == '--scale': n, v = a[i + 1].split('='); o['scale'][n] = float(v); i += 2
        elif a[i] == '--status': o['status'] = True; i += 1
        elif a[i] == '--unzip':
            i += 1
            while i < len(a) and not a[i].startswith('--'): o['unzip'].append(Path(a[i])); i += 1
        else: raise SystemExit(__doc__)
    return o

def unzip(paths, dest):
    for z in paths:
        d = dest / z.stem; d.mkdir(parents=True, exist_ok=True); n = 0
        with zipfile.ZipFile(z) as zf:
            for m in zf.infolist():
                name = Path(m.filename)
                if m.is_dir() or name.is_absolute() or '..' in name.parts or name.suffix.lower() not in ('.png', '.json', '.md', '.txt'): continue
                (d / name.name).write_bytes(zf.read(m)); n += 1
        print(f'unzipped {z.name}: {n} files -> {d.relative_to(root) if d.is_relative_to(root) else d}')

def find(src, name):
    hits = sorted(src.rglob(name)) if src.exists() else []
    return hits[0] if hits else None

def opaque(im):
    im = im.convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda v: 255 if v > 110 else 0))   # also drops the stray alpha=1 pixels
    return im

def scaled(im, k):
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.Resampling.LANCZOS)
    im.putalpha(im.getchannel('A').point(lambda v: 255 if v > 110 else 0)); return im

def grid_cells(im, cols, rows):
    """Plain grid cut (state sheets): each cell trimmed to its opaque box, remembering where it sat in the cell."""
    cw, ch = im.width / cols, im.height / rows; out = []
    for r in range(rows):
        for c in range(cols):
            cell = im.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch))); bb = cell.getbbox()
            out.append((cell.crop(bb), bb) if bb else (None, None))
    return out

def pack(ims, frames, path):
    x = y = row = 0; W = 2048; pos = []
    for s in ims:
        if x + s.width + 2 > W: x = 0; y += row + 2; row = 0
        pos.append((x, y)); x += s.width + 2; row = max(row, s.height)
    atlas = Image.new('RGBA', (W, y + row))
    for s, (px_, py_), f in zip(ims, pos, frames): atlas.alpha_composite(s, (px_, py_)); f['x'], f['y'] = px_, py_
    atlas.save(path)

def char_frames(parts, k):
    ims, frames = [], []
    for c, _ in parts:
        ax, fy, _ = imp.feet(c); hx, hy = imp.hand(c); s = scaled(c, k); ims.append(s)
        frames.append(dict(w=s.width, h=s.height, anchor=round(ax * k, 1), foot=round(fy * k, 1), hand=[round(hx * k, 1), round(hy * k, 1)]))
    return ims, frames

# ---------------------------------------------------------------- main
def main():
    o = args(); src, proj = o['src'], o['project']
    if o['unzip']: unzip(o['unzip'], src)
    found = {n: find(src, n) for n in EXPECTED}
    print('present:', ', '.join(n for n in EXPECTED if found[n]) or '—')
    print('missing:', ', '.join(n for n in EXPECTED if not found[n]) or '—')
    if o['status']: return
    out = proj / 'assets/new'; out.mkdir(parents=True, exist_ok=True); (out / 'portraits').mkdir(exist_ok=True); (out / 'icons').mkdir(exist_ok=True)
    data = {'chars': {}, 'props': {}, 'portraits': [], 'icons': [], 'present': [n for n in EXPECTED if found[n]], 'notes': []}
    note = lambda t: (data['notes'].append(t), print('note:', t))

    for fn, (name, cols, rows, names, base, bgrid) in CHAR_EXTRA.items():
        if not found[fn]: continue
        base_parts = imp.cells(opaque(Image.open(root / 'art/rest' / base)), *bgrid)
        walk = statistics.median(c.height for c, _ in base_parts[:4])
        k = 70 * PX / walk * o['scale'].get(name, 1.0)
        parts = imp.cells(imp.keyed(found[fn]), cols, rows)
        ratio = statistics.median(c.height for c, _ in parts) / statistics.median(c.height for c, _ in base_parts)
        ims, frames = char_frames(parts, k); pack(ims, frames, out / f'{name}_extra.png')
        data['chars'][name] = {'extra': f'res://assets/new/{name}_extra.png', 'frames': frames, 'names': {n: i for i, n in enumerate(names)}}
        note(f'{fn}: figures are {ratio:.2f}x the height of the base sheet {base} (about 1.0 expected, unless the poses crouch or stretch)')

    for fn, (name, cols, rows, names) in CHAR_FULL.items():
        if not found[fn]: continue
        parts = imp.cells(imp.keyed(found[fn]), cols, rows)
        k = 70 * PX / statistics.median(c.height for c, _ in parts[:4]) * o['scale'].get(name, 1.0)
        ims, frames = char_frames(parts, k); pack(ims, frames, out / f'{name}.png')
        data['chars'][name] = {'atlas': f'res://assets/new/{name}.png', 'unit': 70 * PX, 'frames': frames, 'names': {n: i for i, n in enumerate(names)}}

    for fn, (cols, rows, items) in SHEETS.items():
        if not found[fn]: continue
        cells = grid_cells(imp.keyed(found[fn]), cols, rows); sheet_k = {}
        for name, idx, size, anchor in items:
            parts = [cells[i] for i in idx]
            if any(p is None for p, _ in parts): note(f'{fn}: {name} has an empty cell, skipped'); continue
            if anchor == 'hinge':
                # Raised and lowered bridge turn about the same hinge: the bottom-left corner of each part.
                W = max(p.width for p, _ in parts); H = max(p.height for p, _ in parts)
                canvases = []
                for p, _ in parts: c = Image.new('RGBA', (W, H)); c.alpha_composite(p, (0, H - p.height)); canvases.append(c)
            else:
                W = max(p.width for p, _ in parts); H = max(p.height for p, _ in parts); canvases = []
                for p, _ in parts: c = Image.new('RGBA', (W, H)); c.alpha_composite(p, ((W - p.width) // 2, H - p.height)); canvases.append(c)
            if size[0] == 'sheet': k = sheet_k[size[1]]
            else: k = size[1] * PX / (H if size[0] == 'h' else W)
            k *= o['scale'].get(name, 1.0); sheet_k[name] = k
            for i, c in enumerate(canvases): scaled(c, k).save(out / f'{name}_{i}.png')
            data['props'][name] = {'states': len(canvases), 'w': round(W * k / PX, 1), 'h': round(H * k / PX, 1), 'anchor': anchor, 'src': fn}

    for fn, (name, size) in SINGLES.items():
        if not found[fn]: continue
        im = imp.keyed(found[fn]); bb = im.getbbox(); im = im.crop(bb)
        k = size[1] * PX / (im.height if size[0] == 'h' else im.width) * o['scale'].get(name, 1.0)
        # The doorway: the widest fully transparent run along the bottom rows, so the door can be centred in it.
        a = im.getchannel('A').load(); y = im.height - 3; runs = []; s = None
        for x in range(im.width + 1):
            clear = x < im.width and a[x, y] == 0
            if clear and s is None: s = x
            if not clear and s is not None: runs.append((s, x)); s = None
        door = max(runs, key=lambda r: r[1] - r[0]) if runs else (im.width // 2, im.width // 2)
        scaled(im, k).save(out / f'{name}_0.png')
        data['props'][name] = {'states': 1, 'w': round(im.width * k / PX, 1), 'h': round(im.height * k / PX, 1), 'anchor': 'bottom', 'src': fn,
                               'door_x': round(((door[0] + door[1]) / 2 - im.width / 2) * k / PX, 1), 'door_w': round((door[1] - door[0]) * k / PX, 1)}
        note(f'{fn}: doorway {data["props"][name]["door_w"]} units wide (door A158 is 67.8), centre {data["props"][name]["door_x"]} from the middle')

    for p in PORTRAITS:
        f = found[f'P1_portrait_{p}.png']
        if not f: continue
        im = Image.open(f).convert('RGB'); s = min(im.size)
        im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width + s) // 2, (im.height + s) // 2)).resize((256, 256), Image.Resampling.LANCZOS).save(out / f'portraits/{p}.png')
        data['portraits'].append(p)

    if found['I1_item_icons.png']:
        for i, (c, _) in enumerate(grid_cells(imp.keyed(found['I1_item_icons.png']), 4, 4)):
            if c is None: note(f'I1: icon {ICONS[i]} is empty'); continue
            k = 56 / max(c.size); s = scaled(c, k); canvas = Image.new('RGBA', (64, 64))
            canvas.alpha_composite(s, ((64 - s.width) // 2, (64 - s.height) // 2)); canvas.save(out / f'icons/{ICONS[i]}.png'); data['icons'].append(ICONS[i])

    (proj / 'data/new_art.json').write_text(json.dumps(data, indent=1, ensure_ascii=False))
    print('chars', list(data['chars']), '| props', list(data['props']), '| portraits', data['portraits'], '| icons', len(data['icons']))

if __name__ == '__main__':
    main()
