"""Import generated art into the game.

  python3 scripts/import-art.py hero <id> <sheet.png>      4x2 pose sheet (or 4x4 extended sheet) -> dist/assets/hero-<id>.webp + dist/assets/heroes.mjs
  python3 scripts/import-art.py portrait <id> <image.png>  head-and-shoulders -> dist/assets/portrait-<id>.webp
  python3 scripts/import-art.py check <sheet.png>          show what the keyer finds, write nothing

Sheets may have transparency or a flat chroma background (magenta #FF00FF or green #00FF00), which is keyed out.
Pose order (left to right, top to bottom): walk1 walk2 walk3 walk4, idle with pickaxe, overhead swing, forward strike, jump.
Extended 4x4 sheet (taller than wide): walk x4, run x4, climb x4, idle empty-handed, wind-up, strike, jump (tools drawn by the game).
Needs Pillow."""
from PIL import Image
from pathlib import Path
import json,sys,re
root=Path(__file__).resolve().parents[1];assets=root/'dist/assets'
def clean(im):
    # Hard pixel edges, then strip red/magenta halo left over from chroma backgrounds, only on the outline.
    px=im.load();w,h=im.size
    for y in range(h):
        for x in range(w):
            r,g,b,a=px[x,y]
            px[x,y]=(r,g,b,0) if a<110 else (r,g,b,255)
    def tinted(r,g,b):return (r>120 and g<0.62*r and b>0.55*r) or (r>140 and g<0.5*r and b<0.6*r)
    for _ in range(3):
        drop=[]
        for y in range(1,h-1):
            for x in range(1,w-1):
                r,g,b,a=px[x,y]
                if a and tinted(r,g,b) and (px[x-1,y][3]==0 or px[x+1,y][3]==0 or px[x,y-1][3]==0 or px[x,y+1][3]==0):drop.append((x,y))
        for x,y in drop:px[x,y]=(0,0,0,0)
        if not drop:break
    return im
def keyed(path):
    im=Image.open(path).convert('RGBA');px=im.load();w,h=im.size
    if im.getextrema()[3][0]<200:return clean(im)   # already has transparency
    corners=[px[2,2],px[w-3,2],px[2,h-3],px[w-3,h-3]];bg=max(set(corners),key=corners.count)
    tol=90
    for y in range(h):
        for x in range(w):
            r,g,b,_=px[x,y]
            if abs(r-bg[0])+abs(g-bg[1])+abs(b-bg[2])<tol:px[x,y]=(0,0,0,0)
            elif bg[0]>200 and bg[2]>200 and g<120 and r>150 and b>150:px[x,y]=(0,0,0,0)  # magenta fringe
    return clean(im)
def cells(im,cols=4,rows=2):
    # Split by connected figures, not by the grid: a pickaxe that pokes into the next cell stays with its owner.
    w,h=im.size;cw,ch=w/cols,h/rows;a=im.getchannel('A').point(lambda v:255 if v>80 else 0)
    sm=a.resize((w//2,h//2),Image.Resampling.NEAREST);sw,sh=sm.size;px=sm.load();lab=[[-1]*sw for _ in range(sh)];comps=[]
    for y0 in range(sh):
        for x0 in range(sw):
            if not px[x0,y0] or lab[y0][x0]>=0:continue
            n=len(comps);st=[(x0,y0)];lab[y0][x0]=n;xs=[];ys=[]
            while st:
                x,y=st.pop();xs.append(x);ys.append(y)
                for nx,ny in((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                    if 0<=nx<sw and 0<=ny<sh and px[nx,ny] and lab[ny][nx]<0:lab[ny][nx]=n;st.append((nx,ny))
            comps.append((len(xs),sum(xs)/len(xs)*2,sum(ys)/len(ys)*2,min(xs)*2,min(ys)*2,max(xs)*2+2,max(ys)*2+2))
    big=max(c[0] for c in comps);groups={}
    for c in comps:
        if c[0]<big*.002:continue
        i=min(cols-1,int(c[1]//cw))+cols*min(rows-1,int(c[2]//ch));groups.setdefault(i,[]).append(c)
    out=[]
    for i in range(cols*rows):
        if i not in groups:raise SystemExit(f'cell {i+1} is empty')
        g=groups[i];box=(min(c[3] for c in g),min(c[4] for c in g),max(c[5] for c in g),max(c[6] for c in g))
        crop=im.crop(box);mask=Image.new('L',crop.size,0);mp=mask.load()
        for c in g:
            for y in range(max(0,c[4]-box[1]),min(crop.height,c[6]-box[1])):
                for x in range(max(0,c[3]-box[0]),min(crop.width,c[5]-box[0])):
                    sx,sy=(x+box[0])//2,(y+box[1])//2
                    if sy<sh and sx<sw and lab[sy][sx]>=0 and comps[lab[sy][sx]] in g:mp[x,y]=255
        mask=mask.resize(crop.size);r,gg,b,al=crop.split();from PIL import ImageChops
        crop.putalpha(ImageChops.multiply(al,mask.point(lambda v:255 if v else 0)))
        bb=crop.getbbox();crop=crop.crop(bb);left=box[0]+bb[0]
        out.append((crop,(i%cols+.5)*cw-left))
    return out
def hand(c):
    # Front fist: right-most skin-coloured pixels in the middle of the body (characters face right).
    px=c.load();w,h=c.size;pts=[]
    for y in range(int(h*.3),int(h*.72)):
        for x in range(w):
            r,g,b,a=px[x,y]
            if a and r>160 and 95<g<215 and 60<b<180 and r-g>18 and r-b>40:pts.append((x,y))
    if not pts:return [w*.8,h*.5]
    mx=max(x for x,_ in pts);near=[(x,y) for x,y in pts if x>mx-max(6,w*.05)]
    return [sum(x for x,_ in near)/len(near),sum(y for _,y in near)/len(near)]
def feet(c):
    # Ground contact: the lowest opaque rows near the body. Returns (anchor x, foot y, stride width).
    # Anchor = middle of the boots, so swapping poses never shifts the hero sideways; a tool that hangs
    # below the boots (outside the body band) does not lift the hero off the ground.
    a=c.getchannel('A').point(lambda v:255 if v>110 else 0);px=a.load();w,h=c.size
    cols=[x for x in range(w) if any(px[x,y] for y in range(int(h*.55),h))]
    mid=(min(cols)+max(cols))/2 if cols else w/2;band=h*.3
    foot=max((y for y in range(h) for x in range(max(0,int(mid-band)),min(w,int(mid+band))) if px[x,y]),default=h-1)+1
    row=[x for y in range(max(0,foot-int(h*.06)),foot) for x in range(w) if px[x,y] and abs(x-mid)<band*1.4]
    return ((min(row)+max(row))/2 if row else mid),foot,(max(row)-min(row) if row else 0)
FIT=240
def hero(hid,path):
    if not re.fullmatch(r'[a-z0-9_-]+',hid):raise SystemExit('id: lowercase letters, digits, - or _')
    src=keyed(path);rows=4 if src.height>src.width else 2;parts=cells(src,4,rows);k=FIT/max(c.height for c,_ in parts)
    # Cells grow to fit the widest pose (a swung pickaxe), so nothing is clipped into a neighbour.
    CW=max(256,max(round(c.width*k) for c,_ in parts)+4);CH=256
    sheet=Image.new('RGBA',(CW*4,CH*rows));frames=[]
    for i,(c,_) in enumerate(parts):
        hx,hy=hand(c);ax,fy,span=feet(c);w,h=round(c.width*k),round(c.height*k);c=c.resize((w,h),Image.Resampling.LANCZOS)
        a=c.getchannel('A').point(lambda v:255 if v>110 else 0);c.putalpha(a)
        x,y=i%4*CW+(CW-w)//2,i//4*CH+(CH-h)//2;sheet.paste(c,(x,y))
        frames.append(dict(x=x,y=y,w=w,h=h,anchor=round(ax*k,1),foot=round(fy*k,1),stride=round(span*k,1),hand=[round(hx*k,1),round(hy*k,1)]))
    if hid=='einstein':
        # Einstein is the built-in hero: replace his atlas and keep the object frames in atlas-layout.mjs.
        sheet.save(assets/'einstein-mobile.webp',quality=92,method=6)
        lay=assets/'atlas-layout.mjs';data=json.loads(re.search(r'export default (\{.*\});',lay.read_text(),re.S).group(1));data['hero']=frames
        lay.write_text('export default '+json.dumps(data,separators=(',',':'))+';\n');print('hero einstein replaced');return
    sheet.save(assets/f'hero-{hid}.webp',quality=92,method=6)
    reg=assets/'heroes.mjs';data={}
    if reg.exists():
        m=re.search(r'export default (\{.*\});',reg.read_text(),re.S);data=json.loads(m.group(1)) if m else {}
    data[hid]=frames
    reg.write_text('// Generated by scripts/import-art.py: pose frames of extra heroes in hero-<id>.webp.\nexport default '+json.dumps(data,separators=(',',':'))+';\n')
    print('hero',hid,'frames',len(frames),'->',f'hero-{hid}.webp')
def portrait(hid,path):
    im=Image.open(path).convert('RGB');s=min(im.size);x,y=(im.width-s)//2,max(0,(im.height-s)//4)
    im.crop((x,y,x+s,y+s)).resize((168,182),Image.Resampling.LANCZOS).save(assets/f'portrait-{hid}.webp',quality=90)
    print('portrait',hid)
if __name__=='__main__':
    if len(sys.argv)<3:raise SystemExit(__doc__)
    cmd=sys.argv[1]
    if cmd=='hero':hero(sys.argv[2],sys.argv[3])
    elif cmd=='portrait':portrait(sys.argv[2],sys.argv[3])
    elif cmd=='check':
        for i,(c,a) in enumerate(cells(keyed(sys.argv[2]))):print(f'pose {i+1}: {c.width}x{c.height}, anchor {a:.0f}')
    else:raise SystemExit(__doc__)
