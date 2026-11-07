"""Static checks for LOT 13 that run without Godot:  python3 tools/check.py
- every .gd file parses (gdtoolkit's GDScript 4 parser);
- every res:// path and every art/icon/portrait/box name used in code exists;
- every translation key used in code exists in both languages, with the same {placeholders};
- no duplicate keys in the translation tables (Godot refuses duplicate dictionary keys);
- a few GDScript 4 patterns that compile in other languages but fail in Godot (Variant type inference etc.)."""
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
errors = []


def err(msg):
    errors.append(msg)


def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


gd_files = []
for d, _, fs in os.walk(os.path.join(ROOT, "scripts")):
    for f in fs:
        if f.endswith(".gd"):
            gd_files.append(os.path.relpath(os.path.join(d, f), ROOT))
gd_files.sort()

# 1. parse
r = subprocess.run(["gdparse"] + [os.path.join(ROOT, f) for f in gd_files], capture_output=True, text=True)
if r.returncode != 0:
    err("gdparse failed:\n" + r.stdout + r.stderr)

src = {f: read(f) for f in gd_files}
allsrc = "\n".join(src.values())
allsrc = "\n".join(l for l in allsrc.split("\n") if not l.strip().startswith("#"))

# 2. resources
for f, s in list(src.items()) + [("project.godot", read("project.godot")), ("main.tscn", read("main.tscn"))]:
    for m in re.finditer(r'res://[A-Za-z0-9_./-]+', s):
        p = m.group(0)
        if p.endswith("/") or "%" in s[m.end():m.end() + 1]:
            continue
        if not os.path.exists(os.path.join(ROOT, p[len("res://"):])):
            err(f"{f}: missing resource {p}")
art = os.path.join(ROOT, "assets", "art")
for m in re.finditer(r'UI\.art\("([^"%]+)"\)', allsrc):
    if not os.path.exists(os.path.join(art, m.group(1) + ".png")):
        err(f"missing art {m.group(1)}")
for m in re.finditer(r'UI\.art\("([^"]+)" if [^)]* else "([^"]+)"\)', allsrc):
    for g in m.groups():
        if not os.path.exists(os.path.join(art, g + ".png")):
            err(f"missing art {g}")
for m in re.finditer(r'UI\.(?:icon|icon_tex|icon_button)\("([a-z_]+)"', allsrc):
    if not os.path.exists(os.path.join(art, "icons", m.group(1) + ".png")):
        err(f"missing icon {m.group(1)}")
for m in re.finditer(r'"(?:icon|icon_name)":\s*"([a-z_]+)"', allsrc):
    if not os.path.exists(os.path.join(art, "icons", m.group(1) + ".png")):
        err(f"missing icon {m.group(1)}")
for m in re.finditer(r'UI\.portrait_tex\("([a-z_0-9]+)"\)', allsrc):
    if not os.path.exists(os.path.join(art, "portraits", m.group(1) + ".png")):
        err(f"missing portrait {m.group(1)}")
for m in re.finditer(r'main\.(?:toast|popup)\([^\n]*?"([a-z_]+)"\)\s*$', allsrc, re.M):
    pass

# data tables
data = read("scripts/data.gd")
items = re.findall(r'^\t"([a-z_]+)": \{"r": (\d)', data, re.M)
item_ids = [i for i, _ in items]
if len(item_ids) != 40:
    err(f"expected 40 items, found {len(item_ids)}")
for i in item_ids:
    if not os.path.exists(os.path.join(art, "items", i + ".png")):
        err(f"missing item art {i}")
order = re.search(r'const ITEM_ORDER := \[(.*?)\]', data, re.S).group(1)
if sorted(re.findall(r'"([a-z_]+)"', order)) != sorted(item_ids):
    err("ITEM_ORDER does not match ITEMS")
cats = re.findall(r'"([a-z]+)"', re.search(r'const CATEGORIES := \[(.*?)\]', data, re.S).group(1))
auction_ids = re.findall(r'\{"id": "([a-z]+)", "rep"', data)
box_kinds = set(re.findall(r'"boxes": \[([^\]]*)\]', data))
box_kinds = sorted({k for grp in box_kinds for k in re.findall(r'"([a-z]+)"', grp)})
for k in box_kinds:
    for st in ("closed", "open"):
        if not os.path.exists(os.path.join(art, "boxes", f"{k}_{st}.png")):
            err(f"missing box art {k}_{st}")
rivals = re.findall(r'^\t"([a-z]+)": \{"aggr"', data, re.M)
for rv in rivals:
    if not os.path.exists(os.path.join(art, "portraits", rv + ".png")):
        err(f"missing rival portrait {rv}")
events = re.findall(r'"([a-z_]+)": \d+', re.search(r'const EVENTS := \{(.*?)\}', data, re.S).group(1))
goals = re.findall(r'\{"id": "([a-z_0-9]+)", "kind"', data)
upgrades = re.findall(r'\{"id": "([a-z]+)", "icon": "([a-z]+)"', data)
for _, ic in upgrades:
    if not os.path.exists(os.path.join(art, "icons", ic + ".png")):
        err(f"missing upgrade icon {ic}")
event_icons = re.findall(r'"[a-z_]+": "([a-z]+)"', re.search(r'const EVENT_ICONS := \{(.*?)\}', data, re.S).group(1))
for ic in event_icons:
    if not os.path.exists(os.path.join(art, "icons", ic + ".png")):
        err(f"missing event icon {ic}")

# 3. translations
loc = read("scripts/loc.gd")
uk_block = loc[loc.index('"uk": {'):loc.index('"en": {')]
en_block = loc[loc.index('"en": {'):loc.index("\n}\n")]
pair = re.compile(r'"([a-z0-9_.]+)":\s*"((?:[^"\\]|\\.)*)"')


def table(block, name):
    out = {}
    for k, v in pair.findall(block):
        if k in out:
            err(f"duplicate key in {name}: {k}")
        out[k] = v
    return out


uk = table(uk_block, "uk")
en = table(en_block, "en")
for k in uk:
    if k not in en:
        err(f"missing english text: {k}")
for k in en:
    if k not in uk:
        err(f"missing ukrainian text: {k}")
for k in uk:
    if k in en:
        a = sorted(set(re.findall(r'\{(\w+)\}', uk[k])))
        b = sorted(set(re.findall(r'\{(\w+)\}', en[k])))
        if a != b:
            err(f"placeholders differ for {k}: uk {a} en {b}")

used = set(re.findall(r'L\.t\("([a-z0-9_.]+)"[,)]', allsrc))
used |= set(re.findall(r'L\.t\("([a-z0-9_.]+)" if ', allsrc))
used |= set(re.findall(r'else L\.t\("([a-z0-9_.]+)"\)', allsrc))
used |= set(re.findall(r'"((?:cond|size|weight)\.[a-z]+)"', allsrc))
used |= {"event.leak.safe", "sell.result_profit", "sell.result_loss"}
dyn = set()
dyn |= {"nav." + n for n in ("garage", "auctions", "storage", "upgrades", "collection")}
dyn |= {"item." + i for i in item_ids}
dyn |= {"cat." + c for c in cats} | {"cat.mixed"}
dyn |= {"rarity." + r for r in ("common", "uncommon", "rare", "epic", "legendary")}
dyn |= {"auction." + a for a in auction_ids}
dyn |= {"box." + b for b in box_kinds}
dyn |= {"rival." + r for r in rivals}
dyn |= {f"event.{e}.title" for e in events} | {f"event.{e}.text" for e in events}
dyn |= {f"tut.{i}" for i in range(5)}
dyn |= {f"up.{u}.name" for u, _ in upgrades} | {f"up.scanner.fx{i}" for i in range(5)}
dyn |= {f"up.{u}.desc" for u, _ in upgrades if u != "scanner"}
dyn |= {"goal." + g for g in goals}
dyn |= {f"sell.hello{i}" for i in range(3)} | {f"sell.counter{i}" for i in range(3)} | {f"sell.leave{i}" for i in range(2)}
dyn |= {"lang.uk", "lang.en", "set.sound", "set.music", "set.vibrate"}
dyn |= {"cond.broken", "cond.worn", "cond.used", "cond.good", "cond.mint"}
for k in sorted(used | dyn):
    if k.endswith("."):
        continue
    if k not in uk or k not in en:
        err(f"translation key used but missing: {k}")
unused = sorted(set(uk) - used - dyn)
if unused:
    print("note: texts not referenced directly:", ", ".join(unused))

# 4. risky GDScript patterns
variant_funcs = r'\b(round|abs|max|min|clamp|floor|ceil|lerp|snapped|sign|wrap)\('
for f, s in src.items():
    lines = s.split("\n")
    for n, line in enumerate(lines, 1):
        code = line.split("#")[0]
        m = re.search(r'\bvar\s+\w+\s*:=\s*(.+)$', code)
        if m:
            rhs = m.group(1)
            if re.search(variant_funcs, rhs) and not re.search(r'\b(int|float|str|bool)\(' + variant_funcs[2:], rhs):
                if not re.match(r'(int|float|str)\(', rhs.strip()):
                    err(f"{f}:{n}: ':=' infers from a Variant utility function: {line.strip()}")
            bare = re.sub(r'\b(int|float|str|bool)\([^()]*\.get\([^()]*\)\)', 'X', rhs)
            if re.search(r'\.get\(', bare) and not re.match(r'(int|float|str|bool)\(', rhs.strip()):
                err(f"{f}:{n}: ':=' from Dictionary.get() (Variant): {line.strip()}")
            if re.match(r'[a-z_]+\[[^\]]+\]\s*$', rhs.strip()):
                err(f"{f}:{n}: ':=' from an indexed Variant: {line.strip()}")
            if re.match(r'(main|args|scr|o|rep|sell)\.', rhs.strip()):
                err(f"{f}:{n}: ':=' from an untyped object: {line.strip()}")
        if re.search(r'func\([^)]*\):\s*$', code):
            err(f"{f}:{n}: multi-line lambda (use a method instead)")
        if re.search(r'\bstatic func\b', code) and "ui.gd" in f:
            err(f"{f}:{n}: UI helpers must be instance methods (autoload)")
        if re.search(r'^\s*var (ready|tr|theme|size|position|scale|name|owner)\s*[:=]', code) and "extends Node" not in s[:30]:
            err(f"{f}:{n}: local variable shadows a Node/Control member: {line.strip()}")

if errors:
    print("\n".join("ERROR: " + e for e in errors))
    print(f"\n{len(errors)} problem(s)")
    sys.exit(1)
print(f"check ok: {len(gd_files)} scripts, {len(item_ids)} items, {len(uk)} texts per language")
