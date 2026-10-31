"""Pixelify Sans has no capital Cyrillic П (U+041F) and І (U+0406). Browsers borrow them from a system font;
Godot on the web has none to borrow from. This adds them in the font's own pixel grid:
І uses the Latin I glyph, П is drawn from H's stems with a top bar.
python3 godot/tools/fix_font.py <PixelifySans-Regular.ttf> godot/assets/PixelifySans.ttf"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
f=TTFont(sys.argv[1]);cm=f['cmap'];glyf=f['glyf'];hmtx=f['hmtx']
pen=TTGlyphPen(glyf)
pts=[(60,-12),(60,631),(525,631),(525,-12),(423,-12),(423,530),(161,530),(161,-12)]
pen.moveTo(pts[0])
for p in pts[1:]:pen.lineTo(p)
pen.closePath()
order=f.getGlyphOrder();name='uni041F'
if name not in order:
    order.append(name);f.setGlyphOrder(order)
glyf[name]=pen.glyph();hmtx[name]=hmtx['H']
for t in cm.tables:
    if t.isUnicode():
        t.cmap[0x041F]=name;t.cmap[0x0406]='I'
f['maxp'].numGlyphs=len(order)
f.save(sys.argv[2]);print('ok')
