"""Cut the owner's 'Remaining' art pack (art/rest) into game-ready pieces for the Godot project.

  python3 godot/tools/import_rest.py        (from the repo root; needs Pillow)

Props: the states of one object (closed/open, broken/fixed...) are cut apart and put on one shared canvas,
bottom-centred, so switching state never moves or resizes the object. Characters: frames are cut by figure,
not by grid, and get a foot anchor (middle of the boots) and foot line, like the hero sheets before.
Everything is scaled to 3 px per world unit (the hero walks 70 units tall)."""
from PIL import Image
from pathlib import Path
import importlib.util,json,statistics
root=Path(__file__).resolve().parents[2];src=root/'art/rest';out=root/'godot/assets/rest';data=root/'godot/data'
spec=importlib.util.spec_from_file_location('imp',root/'scripts/import-art.py');imp=importlib.util.module_from_spec(spec);spec.loader.exec_module(imp)
PX=3   # pixels per world unit
out.mkdir(parents=True,exist_ok=True)

def load(aid):
    f=next(src.glob(f'*/{aid}.png'));im=Image.open(f).convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda v:255 if v>110 else 0));return im
def groups(im,n):
    # Column runs of opaque pixels, merged at the widest gaps until there are n groups.
    a=im.getchannel('A');w,h=im.size;sm=a.resize((w//2,h//2));px=sm.load();W,H=sm.size
    cols=[any(px[x,y] for y in range(H)) for x in range(W)];runs=[];s=None
    for x,v in enumerate(cols+[False]):
        if v and s is None:s=x
        if not v and s is not None:runs.append([s,x]);s=None
    while len(runs)>n:
        gaps=[runs[i+1][0]-runs[i][1] for i in range(len(runs)-1)];i=gaps.index(min(gaps));runs[i]=[runs[i][0],runs[i+1][1]];del runs[i+1]
    return [(s*2,e*2) for s,e in runs]
def scaled(im,k):
    im=im.resize((max(1,round(im.width*k)),max(1,round(im.height*k))),Image.Resampling.LANCZOS)
    im.putalpha(im.getchannel('A').point(lambda v:255 if v>110 else 0));return im

PROPS={}
def states(aid,name,n,world_h):
    """Cut n states laid out left to right; save <name>_<i>.png on one shared canvas world_h units tall."""
    im=load(aid);parts=[]
    for x0,x1 in groups(im,n):
        c=im.crop((x0,0,x1,im.height));c=c.crop(c.getbbox());parts.append(c)
    W=max(p.width for p in parts);H=max(p.height for p in parts);k=world_h*PX/H
    for i,p in enumerate(parts):
        canvas=Image.new('RGBA',(W,H));canvas.alpha_composite(p,((W-p.width)//2,H-p.height));scaled(canvas,k).save(out/f'{name}_{i}.png')
    PROPS[name]={'states':len(parts),'w':round(W*k/PX,1),'h':round(H*k/PX,1),'src':aid}
def single(aid,name,world_h=None,world_w=None):
    im=load(aid);im=im.crop(im.getbbox());k=(world_h*PX/im.height) if world_h else (world_w*PX/im.width)
    scaled(im,k).save(out/f'{name}_0.png');PROPS[name]={'states':1,'w':round(im.width*k/PX,1),'h':round(im.height*k/PX,1),'src':aid}
def background(aid,name,world_h):
    im=Image.open(next(src.glob(f'*/{aid}.png'))).convert('RGB');k=world_h*2/im.height   # backgrounds at 2 px per unit
    im.resize((round(im.width*k),round(im.height*k)),Image.Resampling.LANCZOS).save(out/f'{name}.jpg',quality=90)
    PROPS[name]={'states':0,'w':round(im.width*k/2,1),'h':world_h,'src':aid}

CHARS={}
def character(aid,name,cols,rows,extra=None):
    """Pose sheet -> atlas <name>.png + frames with anchor/foot; unit = walking height in atlas pixels."""
    im=load(aid);parts=imp.cells(im,cols,rows)
    walk=statistics.median(c.height for c,_ in parts[:4]);k=70*PX/walk;frames=[];ims=[]
    for c,_ in parts:
        ax,fy,span=imp.feet(c);hx,hy=imp.hand(c);s=scaled(c,k);ims.append(s)
        frames.append(dict(w=s.width,h=s.height,anchor=round(ax*k,1),foot=round(fy*k,1),hand=[round(hx*k,1),round(hy*k,1)]))
    for extra_img,meta in (extra or []):
        ims.append(extra_img);frames.append(meta)
    x=y=row=0;W=2048;pos=[]
    for s in ims:
        if x+s.width+2>W:x=0;y+=row+2;row=0
        pos.append((x,y));x+=s.width+2;row=max(row,s.height)
    atlas=Image.new('RGBA',(W,y+row))
    for s,(px_,py_),f in zip(ims,pos,frames):atlas.alpha_composite(s,(px_,py_));f['x'],f['y']=px_,py_
    atlas.save(out/f'{name}.png');CHARS[name]={'unit':70*PX,'frames':frames,'src':aid}

def einstein_jumps():
    """Jump phases from the older set-22 atlas (A105 has none yet), rescaled to the same walking height."""
    reg=json.loads((root/'dist/assets/heroes.mjs').read_text().split('export default ',1)[1].rstrip().rstrip(';'))['einstein']
    atlas=Image.open(root/'dist/assets/hero-einstein.webp').convert('RGBA');k=70*PX/reg['unit'];res=[]
    for i in (21,15,22,23):   # take-off, apex, falling, landing
        f=reg['frames'][i];c=atlas.crop((f['x'],f['y'],f['x']+f['w'],f['y']+f['h']));s=scaled(c,k)
        res.append((s,dict(w=s.width,h=s.height,anchor=round(f['anchor']*k,1),foot=round(f['foot']*k,1),hand=[round(f['hand'][0]*k,1),round(f['hand'][1]*k,1)])))
    return res

if __name__=='__main__':
    # Characters. Einstein frames: 0-3 walk, 4 idle, 5 wrench, 6 kneel, 7 reach / knee up (also the jump pose).
    character('A105','einstein',4,2)   # older set-22 jump frames do not match this style; jumps use frames 6-7
    character('A166','nazar',4,2)      # 0-3 walk, 4 idle, 5 knock, 6 push cart, 7 crouch
    character('A161','crawler',3,2)    # six motion phases
    character('A108','mira',4,2)       # 0-3 walk, 4 idle, 5 reach, 6 crouch, 7 point (extra moves: P3 via import_new.py)
    character('A127','pavlo',4,2)      # 0-3 walk, 4 seed packet, 5 crouch, 6 watering, 7 bend
    # Props with states (world heights in units; the hero is 70).
    states('A158','laundry_door',2,92); states('A156','valve',2,40); states('A164','jack',2,30)
    states('A160','cart',2,44); states('A163','cargo_gate',2,112); states('A167','gauge',3,16)
    states('A111','crate',2,24); states('A126','barrel',2,32); states('A162','pipe',2,14); states('A154','pump',2,30)
    states('A115','rubble',2,60); states('A173','tap',2,56)
    single('A157','filter_body',world_h=44); single('A159','walkway',world_w=300); single('A113','floor_bunker',world_w=420)
    single('A114','floor_city',world_w=420); single('A110','ladder',world_h=110); single('A112','wrench',world_h=20)
    # Backgrounds (one layer each, opaque).
    background('A014','bg_street',480); background('A165','bg_laundry',300); background('A026','bg_yard',480)
    (data/'rest_props.json').write_text(json.dumps(PROPS,indent=1,ensure_ascii=False))
    (data/'rest_chars.json').write_text(json.dumps(CHARS,separators=(',',':')))
    print('props',len(PROPS),'chars',list(CHARS))
