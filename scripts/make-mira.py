"""Temporary Mira sprite: Curie's frames repainted as a mechanic (teal work jacket, dark trousers).
Replace with the real Mira sheet when it arrives (see ASSETS_NEEDED.md).  python3 scripts/make-mira.py"""
from PIL import Image
from pathlib import Path
import colorsys,json,re
root=Path(__file__).resolve().parents[1];assets=root/'dist/assets'
im=Image.open(assets/'hero-curie.webp').convert('RGBA');px=im.load();w,h=im.size
for y in range(h):
    for x in range(w):
        r,g,b,a=px[x,y]
        if not a:continue
        hh,l,s=colorsys.rgb_to_hls(r/255,g/255,b/255)
        if l>.5 and r-g<42 and g>120 and r>=g>=b-8:          # cream lab coat (not skin: skin is redder) -> teal jacket
            nr,ng,nb=colorsys.hls_to_rgb(.49,.18+l*.32,.45);px[x,y]=(int(nr*255),int(ng*255),int(nb*255),a)
        elif .5<hh<.75 and s<.4 and l<.42:                    # slate skirt -> darker work trousers
            nr,ng,nb=colorsys.hls_to_rgb(.08,l*.85,.16);px[x,y]=(int(nr*255),int(ng*255),int(nb*255),a)
im.save(assets/'hero-mira.webp',quality=92,method=6)
reg=json.loads(re.search(r'export default (\{.*\});',(assets/'heroes.mjs').read_text(),re.S).group(1))['curie']
f=reg['frames'][12];c=im.crop((f['x'],f['y'],f['x']+f['w'],f['y']+f['h']));head=c.crop((0,0,c.width,int(c.height*.42)));head=head.crop(head.getbbox())
k=min(150/head.width,170/head.height);head=head.resize((round(head.width*k),round(head.height*k)),Image.Resampling.NEAREST)
bg=Image.new('RGBA',(168,182),(26,36,44,255));bg.alpha_composite(head,((168-head.width)//2,182-head.height));bg.convert('RGB').save(assets/'portrait-mira.webp',quality=90)
print('hero-mira.webp, portrait-mira.webp (temporary)')
