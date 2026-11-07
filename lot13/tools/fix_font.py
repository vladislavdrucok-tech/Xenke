"""Makes the LOT 13 copy of Pixelify Sans (OFL) complete for Ukrainian.
The source copy in this repository already has П (U+041F) and І (U+0406) added, but still lacks capital
Cyrillic О (U+041E) and the modifier apostrophe ʼ (U+02BC). Both look exactly like existing glyphs,
so they are mapped onto Latin O and the plain apostrophe.
python3 tools/fix_font.py ../iso/assets/PixelifySans.ttf assets/fonts/pixelify_lot13.ttf"""
import sys
from fontTools.ttLib import TTFont

f = TTFont(sys.argv[1])
glyph_o = f.getBestCmap()[ord("O")]
glyph_q = f.getBestCmap()[ord("'")]
for t in f["cmap"].tables:
    if t.isUnicode():
        t.cmap[0x041E] = glyph_o
        t.cmap[0x02BC] = glyph_q
        t.cmap[0x2019] = t.cmap.get(0x2019, glyph_q)
f.save(sys.argv[2])
cm = TTFont(sys.argv[2]).getBestCmap()
need = "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюяʼ'$%+-/:!?.,()«»—…"
missing = [c for c in need if ord(c) not in cm]
print("missing:", missing)
sys.exit(1 if missing else 0)
