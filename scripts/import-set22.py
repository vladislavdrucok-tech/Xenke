"""Build the runtime atlases from the owner's art set (art/set22, originals untouched).

  python3 scripts/import-set22.py          heroes, mutants, held items, portraits (needs Pillow)
  python3 scripts/pack-props.py            object states go into props.webp with the other props

Heroes with a moves 4x4 + damage 4x2 sheet get the extended 27-frame layout:
  0-3 walk, 4-7 run, 8-11 climb, 12 idle (empty hands), 13 wind-up, 14 strike, 15 jump,
  16 hit, 17 falling back, 18 lying, 19 kneel, 20 crouch, 21 take-off, 22 falling, 23 landing,
  24-26 idle / wind-up / strike with the pickaxe drawn in (from the base 4x2 sheet).
A hero with only a base sheet keeps the old 8-frame layout.
Scale: every sheet is matched by the walking height (unit). The damage sheet has no walk, so its
lying pose (head to boots) stands in for the standing height; frames are never fitted one by one."""
from PIL import Image
from pathlib import Path
import importlib.util,json,statistics
root=Path(__file__).resolve().parents[1];src=root/'art/set22';gen=root/'art/generated';assets=root/'dist/assets'
spec=importlib.util.spec_from_file_location('imp',root/'scripts/import-art.py');imp=importlib.util.module_from_spec(spec);spec.loader.exec_module(imp)
UNIT=200   # walking height in atlas pixels; the game draws it 70 world units tall

def load(path,legacy=False):
    # The new sheets already have clean alpha: only harden the edge. Older generated sheets need keying.
    if legacy:return imp.keyed(path)
    im=Image.open(path).convert('RGBA');a=im.getchannel('A').point(lambda v:255 if v>110 else 0);im.putalpha(a);return im
def sheet(path,legacy=False):
    im=load(path,legacy);rows=4 if im.height>im.width else 2;return imp.cells(im,4,rows,info=True),im.size,rows
def scaled(c,k):
    c=c.resize((max(1,round(c.width*k)),max(1,round(c.height*k))),Image.Resampling.LANCZOS)
    c.putalpha(c.getchannel('A').point(lambda v:255 if v>110 else 0));return c
def skin(c):
    px=c.load();w,h=c.size
    return [(x,y) for y in range(h) for x in range(w) if (lambda r,g,b,a:a and r>160 and 95<g<215 and 60<b<180 and r-g>18 and r-b>40)(*px[x,y])]
def hand(c,mode):
    # Where a held item goes. front: the leading fist at mid-body; top: a fist raised over the head; fwd: an arm thrust forward.
    if mode=='front':return imp.hand(c)
    pts=skin(c);w,h=c.size
    if not pts:return [w*.8,h*.4]
    if mode=='top':y0=min(y for _,y in pts);near=[p for p in pts if p[1]<y0+max(5,h*.05)]
    else:x0=max(x for x,_ in pts);near=[p for p in pts if p[0]>x0-max(5,w*.05)]
    return [sum(x for x,_ in near)/len(near),sum(y for _,y in near)/len(near)]
def shelf(images,W,pad=2):
    x=y=row=0;pos=[]
    for im in images:
        if x+im.width+pad>W:x=0;y+=row+pad;row=0
        pos.append((x,y));x+=im.width+pad;row=max(row,im.height)
    out=Image.new('RGBA',(W,y+row))
    for im,p in zip(images,pos):out.alpha_composite(im,p)
    return out,pos
def walk_h(parts):return statistics.median(c.height for c,_,_ in parts[:4])

def hero(hid,moves=None,damage=None,base=None,legacy_base=False):
    picks=[]   # (crop, scale, hand mode)
    if moves:
        mv,_,_=sheet(moves);km=UNIT/walk_h(mv)
        modes=['front']*12+['front','top','fwd','front']
        picks+=[(c,km,m) for (c,_,_),m in zip(mv,modes)]
        dm,_,_=sheet(damage);kd=UNIT/(dm[2][0].width*.98)
        picks+=[(c,kd,'front') for c,_,_ in dm]
        bs,_,_=sheet(base,legacy_base);kb=UNIT/walk_h(bs)
        picks+=[(c,kb,'front') for c,_,_ in bs[4:7]]
    else:
        bs,_,_=sheet(base,legacy_base);kb=UNIT/walk_h(bs)
        picks+=[(c,kb,'front') for c,_,_ in bs]
    frames=[];ims=[]
    for c,k,mode in picks:
        hx,hy=hand(c,mode);ax,fy,span=imp.feet(c);im=scaled(c,k);ims.append(im)
        frames.append(dict(w=im.width,h=im.height,anchor=round(ax*k,1),foot=round(fy*k,1),stride=round(span*k,1),hand=[round(hx*k,1),round(hy*k,1)]))
    atlas,pos=shelf(ims,1536)
    for f,(x,y) in zip(frames,pos):f['x'],f['y']=x,y
    atlas.save(assets/f'hero-{hid}.webp',quality=92,method=6)
    print('hero',hid,len(frames),'frames',atlas.size)
    return dict(unit=UNIT,frames=[{k:f[k] for k in ('x','y','w','h','anchor','foot','stride','hand')} for f in frames])

def portrait(hid,path):
    # Same box as the HUD portrait (168x182): crop to that shape first so the face is never stretched.
    im=Image.open(path).convert('RGB');w,h=im.size;cw=min(w,round(h*168/182));ch=round(cw*182/168);x=(w-cw)//2;y=max(0,min(h-ch,(h-ch)//4))
    im.crop((x,y,x+cw,y+ch)).resize((168,182),Image.Resampling.LANCZOS).save(assets/f'portrait-{hid}.webp',quality=90);print('portrait',hid)
def portrait_from_sheet(hid,path):
    # Temporary until a real portrait arrives: head and shoulders of the idle pose, enlarged with hard pixels.
    bs,_,_=sheet(path);c=bs[4][0];w,h=c.size;ax,_,_=imp.feet(c);head=c.crop((max(0,int(ax-h*.2)),0,min(w,int(ax+h*.3)),int(h*.42)))
    head=head.crop(head.getbbox());k=min(150/head.width,170/head.height);head=head.resize((round(head.width*k),round(head.height*k)),Image.Resampling.NEAREST)
    bg=Image.new('RGBA',(168,182),(26,36,44,255));bg.alpha_composite(head,((168-head.width)//2,182-head.height));bg.convert('RGB').save(assets/f'portrait-{hid}.webp',quality=90)
    print('portrait',hid,'(temporary, from the sprite sheet)')

# Mutants face left. The cell centre is the anchor, so a lunge reaches forward instead of every pose being centred on its own box.
MOBS={'crawler':('crawler',170,{}),'salamander':('salamander',230,{}),'armadillo':('armadillo',230,{}),
      'deer':('crystal_stag',240,{6:1.4})}   # the stag's charge pose came out ~30% smaller than the rest
def mobs():
    blocks=[];lay={}
    for kind,(f,walkw,fix) in MOBS.items():
        parts,(W,H),rows=sheet(src/f'enemies/{f}_4x2.png');cw,ch=W/4,H/rows
        k=walkw/statistics.median(c.width for c,_,_ in parts[:4])
        fr=[];ims=[]
        for i,(c,ax,_) in enumerate(parts):
            # The second row sits higher in its cells than the first, so the foot line is each pose's own lowest pixel.
            kk=k*fix.get(i,1);im=scaled(c,kk);ims.append(im);fr.append(dict(w=im.width,h=im.height,ax=round(ax*kk,1),fy=im.height))
        cwid=max(im.width for im in ims)+4;chei=max(im.height for im in ims)+4;block=Image.new('RGBA',(cwid*4,chei*2))
        for i,(im,f) in enumerate(zip(ims,fr)):
            x,y=i%4*cwid+(cwid-im.width)//2,i//4*chei+(chei-im.height)//2;block.alpha_composite(im,(x,y));f['x'],f['y']=x,y
        blocks.append((kind,block));lay[kind]=dict(walk=walkw,frames=fr)
    W=max(b.width for _,b in blocks);y=0;out=Image.new('RGBA',(W,sum(b.height+2 for _,b in blocks)))
    for kind,b in blocks:
        out.alpha_composite(b,(0,y));lay[kind]['box']=[0,y,b.width,b.height]
        for f in lay[kind]['frames']:f['y']+=y
        y+=b.height+2
    out.save(assets/'mobs.webp',quality=90,method=6)
    (assets/'mobs-layout.mjs').write_text('// Generated by scripts/import-set22.py: mutant frames in mobs.webp (walk x4, idle, wind-up, attack, hit; facing left).\nexport default '+json.dumps(lay,separators=(',',':'))+';\n')
    print('mobs.webp',out.size)

# Held items stand upright, grip at the bottom; grip = fraction of the height from the bottom, len = length in world units.
HELD=[('sword',.13,30),('pickaxe',.12,28),('axe',.14,26),('sling',.14,15),('torch',.18,22),('flashlight',.22,13),('shovel',.08,30),('wrench',.2,15)]
def held():
    parts,_,_=sheet(src/'props/held_items_4x2.png');ims=[];lay={}
    for (name,grip,length),(c,_,_) in zip(HELD,parts):
        k=min(1,length*4.5/c.height);im=scaled(c,k);ims.append(im);lay[name]=dict(w=im.width,h=im.height,gx=round(im.width/2,1),gy=round(im.height*(1-grip),1),len=length)
    atlas,pos=shelf(ims,1024)
    for (name,_,_),(x,y) in zip(HELD,pos):lay[name]['x'],lay[name]['y']=x,y
    atlas.save(assets/'held.webp',quality=92,method=6)
    (assets/'held-layout.mjs').write_text('// Generated by scripts/import-set22.py: items drawn in the hero\'s hand (upright, grip at gx,gy).\nexport default '+json.dumps(lay,separators=(',',':'))+';\n')
    print('held.webp',atlas.size)

if __name__=='__main__':
    reg={}
    reg['einstein']=hero('einstein',src/'einstein/moves_4x4.png',src/'einstein/damage_jump_4x2.png',gen/'einstein-sheet-v2.png',True)
    reg['curie']=hero('curie',src/'curie/moves_4x4.png',src/'curie/damage_jump_4x2.png',gen/'curie-sheet.png',True)
    reg['darwin']=hero('darwin',src/'darwin/moves_4x4.png',src/'darwin/damage_jump_4x2.png',src/'darwin/base_4x2.png')
    reg['tesla']=hero('tesla',base=src/'tesla/base_4x2.png')
    (assets/'heroes.mjs').write_text('// Generated by scripts/import-set22.py: pose frames of every hero in hero-<id>.webp (unit = walking height).\nexport default '+json.dumps(reg,separators=(',',':'))+';\n')
    for h in ('einstein','curie'):portrait(h,gen/f'portrait-{h}.png')
    portrait('darwin',src/'darwin/portrait.png');portrait_from_sheet('tesla',src/'tesla/base_4x2.png')
    mobs();held()
