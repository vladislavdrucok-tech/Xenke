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
# file -> (character, cols, rows, frame names, base sheet in art/rest, its grid, reference frame).
# The reference frame is matched to the base sheet's walk frames ('h' = height, 'w' = body length), because the artist
# did not keep the reference scale: M2 came out ~0.8x of A105, M1 ~0.7x of A161.
CHAR_EXTRA = {
    'M1_crawler_actions.png': ('crawler', 4, 2, ['sleep', 'sleep_breathe', 'eat', 'alert', 'lunge', 'hit', 'flee', 'land'], 'laundry_mission/A161.png', (3, 2), (6, 'w')),
    'M2_einstein_moves.png': ('einstein', 4, 2, WALK8, 'chapter_01/A105.png', (4, 2), (7, 'h')),
    'P3_mira_moves.png': ('mira', 4, 2, WALK8, 'chapter_01/A108.png', (4, 2), (7, 'h')),
}
CHAR_FULL = {    # file -> (character, cols, rows, frame names); walking height = median of the 4 walk frames
    'P2_sava_sheet.png': ('sava', 4, 2, ['walk_0', 'walk_1', 'walk_2', 'walk_3', 'idle', 'talk', 'arms_crossed', 'point']),
}
# file -> list of (name, [cell indices = states], size, anchor); size: ('h', units) or ('w', units); cells counted left-right, top-bottom.
# anchor = how the states are laid on their shared canvas: 'bottom' (bottom-centre), 'top' (top-centre: the beam rests on the same
# supports whether it sags or not), 'bottomleft' (washer body stays put when its door swings open), 'topleft' (winch plate), 'hinge'.
SHEETS = {
    'M3_beam.png': (1, 2, [('beam', [0, 1], ('w', 210), 'top')]),
    # Same pixel scale as the walkway A159 (1905 px -> 300 units), so the pieces join it exactly.
    'M4_walkway_hole.png': (1, 2, [('walkway_hole', [0, 1], ('k', 300 / 1905), 'bottom')]),
    'M5_laundry_props.png': (4, 2, [('washer', [0, 1], ('h', 40), 'bottomleft'), ('washer_toppled', [2], ('sheet', 'washer'), 'bottom'),
                                    ('laundry_basket', [3], ('sheet', 'washer'), 'bottom'), ('drying_rack', [4], ('sheet', 'washer'), 'bottom'),
                                    ('sink', [5], ('sheet', 'washer'), 'bottom'), ('rag_pile', [6], ('sheet', 'washer'), 'bottom'),
                                    ('crawler_nest', [7], ('sheet', 'washer'), 'bottom')]),
    # Cans are drawn too big on the sheet next to the door, so every small prop gets its own height.
    'M7_small_props.png': (4, 2, [('sign_station', [0], ('h', 56), 'bottom'), ('planks', [1], ('h', 9), 'bottom'), ('can', [2], ('h', 7), 'bottom'),
                                  ('can_crushed', [3], ('h', 4), 'bottom'), ('service_door', [4], ('h', 80), 'bottom'),
                                  ('winch', [5, 6], ('h', 36), 'topleft'), ('puddle', [7], ('w', 60), 'bottom')]),
    'C1_lab_mechanisms.png': (4, 2, [('power_switch', [0, 1], ('h', 40), 'bottom'), ('drawbridge', [2, 3], ('w', 110), 'hinge'),
                                     ('bulkhead', [4, 5], ('h', 96), 'bottom'), ('lab_pump', [6, 7], ('h', 32), 'bottom')]),
    'C2_pavlo_shelf.png': (3, 1, [('pavlo_shelf', [0, 1, 2], ('h', 78), 'bottom')]),
}
# The facade is scaled by its doorway: 96 units tall, so the door A158 (92) fits in it.
SINGLES = {'M6_laundry_facade.png': ('laundry_facade', ('door_h', 96))}
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

def split_hole(canvases, k, out, meta, note):
    """M4: the open hole as a left and a right piece, and the planks alone, so the game can set the gap it needs."""
    open_, mended = canvases[0], canvases[1]; A = open_.getchannel('A').load(); W, H = open_.size
    clear = [all(A[x, y] == 0 for y in range(H)) for x in range(W)]; runs = []; s = None
    for x, v in enumerate(clear + [False]):
        if v and s is None: s = x
        if not v and s is not None: runs.append((s, x)); s = None
    mid = [r for r in runs if r[0] > W * 0.2 and r[1] < W * 0.8]
    if not mid: note('M4: no gap found in the open state'); return
    g0, g1 = max(mid, key=lambda r: r[1] - r[0])
    left = open_.crop((0, 0, g0, H)); right = open_.crop((g1, 0, W, H))
    scaled(left, k).save(out / 'walkway_hole_left.png'); scaled(right, k).save(out / 'walkway_hole_right.png')
    # Planks: the mended state inside the gap (the board ends lie on the deck, where they cannot be told apart from it);
    # the game repeats this strip across the gap it needs.
    strip = mended.crop((g0, 0, g1, H)); bb0 = strip.getbbox()
    bb = (g0 + bb0[0], bb0[1], g0 + bb0[2], bb0[3]); planks = strip.crop(bb0); scaled(planks, k).save(out / 'walkway_hole_planks.png')
    u = k / PX
    meta.update({'left_w': round(g0 * u, 1), 'right_w': round((W - g1) * u, 1), 'gap': round((g1 - g0) * u, 1),
                 'planks_x': round((bb[0] - g0) * u, 1), 'planks_y': round(bb[1] * u, 1), 'planks_w': round(planks.width * u, 1), 'planks_h': round(planks.height * u, 1)})
    note(f'M4: gap in the art {meta["gap"]} units, planks {meta["planks_w"]} long; pieces {meta["left_w"]} + {meta["right_w"]}, height {meta["h"]}')

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

    for fn, (name, cols, rows, names, base, bgrid, (ref, dim)) in CHAR_EXTRA.items():
        if not found[fn]: continue
        base_parts = imp.cells(opaque(Image.open(root / 'art/rest' / base)), *bgrid)
        walk = statistics.median(c.height for c, _ in base_parts[:4])
        parts = imp.cells(imp.keyed(found[fn]), cols, rows)
        size = (lambda c: c.height) if dim == 'h' else (lambda c: c.width)
        ratio = size(parts[ref][0]) / statistics.median(size(c) for c, _ in base_parts[:4])
        k = 70 * PX / walk / ratio * o['scale'].get(name, 1.0)
        ims, frames = char_frames(parts, k); pack(ims, frames, out / f'{name}_extra.png')
        data['chars'][name] = {'extra': f'res://assets/new/{name}_extra.png', 'frames': frames, 'names': {n: i for i, n in enumerate(names)}}
        note(f'{fn}: drawn at {ratio:.2f}x of {base} (frame "{names[ref]}" vs its walk frames), rescaled to match')

    for fn, (name, cols, rows, names) in CHAR_FULL.items():
        if not found[fn]: continue
        parts = imp.cells(imp.keyed(found[fn]), cols, rows)
        k = 70 * PX / statistics.median(c.height for c, _ in parts[:4]) * o['scale'].get(name, 1.0)
        ims, frames = char_frames(parts, k); pack(ims, frames, out / f'{name}.png')
        data['chars'][name] = {'atlas': f'res://assets/new/{name}.png', 'unit': 70 * PX, 'frames': frames, 'names': {n: i for i, n in enumerate(names)}}

    for fn, (cols, rows, items) in SHEETS.items():
        if not found[fn]: continue
        cells = grid_cells(imp.keyed(found[fn]), cols, rows); sheet_k = {}
        place = {'bottom': lambda W, H, p: ((W - p.width) // 2, H - p.height), 'top': lambda W, H, p: ((W - p.width) // 2, 0),
                 'bottomleft': lambda W, H, p: (0, H - p.height), 'hinge': lambda W, H, p: (0, H - p.height), 'topleft': lambda W, H, p: (0, 0)}
        for name, idx, size, anchor in items:
            parts = [cells[i] for i in idx]
            if any(p is None for p, _ in parts): note(f'{fn}: {name} has an empty cell, skipped'); continue
            # Raised and lowered bridge turn about the same hinge: the bottom-left corner of each part.
            W = max(p.width for p, _ in parts); H = max(p.height for p, _ in parts); canvases = []
            for p, _ in parts: c = Image.new('RGBA', (W, H)); c.alpha_composite(p, place[anchor](W, H, p)); canvases.append(c)
            if size[0] == 'sheet': k = sheet_k[size[1]]
            elif size[0] == 'k': k = size[1] * PX
            else: k = size[1] * PX / (H if size[0] == 'h' else W)
            k *= o['scale'].get(name, 1.0); sheet_k[name] = k
            for i, c in enumerate(canvases): scaled(c, k).save(out / f'{name}_{i}.png')
            data['props'][name] = {'states': len(canvases), 'w': round(W * k / PX, 1), 'h': round(H * k / PX, 1), 'anchor': anchor, 'src': fn}
            if name == 'walkway_hole': split_hole(canvases, k, out, data['props'][name], note)

    for fn, (name, size) in SINGLES.items():
        if not found[fn]: continue
        im = imp.keyed(found[fn]); bb = im.getbbox(); im = im.crop(bb)
        # The doorway: the widest fully transparent run along the bottom rows, and how high it stays clear above it.
        a = im.getchannel('A').load(); y = im.height - 3; runs = []; s = None
        for x in range(im.width + 1):
            clear = x < im.width and a[x, y] == 0
            if clear and s is None: s = x
            if not clear and s is not None: runs.append((s, x)); s = None
        door = max(runs, key=lambda r: r[1] - r[0]) if runs else (im.width // 2, im.width // 2)
        cx = (door[0] + door[1]) // 2; dh = 0
        while dh < im.height and a[cx, im.height - 1 - dh] == 0: dh += 1
        base = {'h': im.height, 'w': im.width, 'door_h': max(1, dh)}[size[0]]
        k = size[1] * PX / base * o['scale'].get(name, 1.0)
        scaled(im, k).save(out / f'{name}_0.png')
        data['props'][name] = {'states': 1, 'w': round(im.width * k / PX, 1), 'h': round(im.height * k / PX, 1), 'anchor': 'bottom', 'src': fn,
                               'door_x': round(((door[0] + door[1]) / 2 - im.width / 2) * k / PX, 1), 'door_w': round((door[1] - door[0]) * k / PX, 1),
                               'door_h': round(dh * k / PX, 1)}
        m = data['props'][name]
        note(f'{fn}: doorway {m["door_w"]} x {m["door_h"]} units (closed door A158 is about 48 x 92), centre {m["door_x"]} from the middle; facade {m["w"]} x {m["h"]}')

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
