from PIL import Image
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]/'dist/assets'
meta={}
for name in ['einstein','objects']:
    src=Image.open(root/f'{name}-atlas.webp').convert('RGBA')
    cw,ch=src.width/4,src.height/2
    cells=[]
    for i in range(8):
        ox,oy=round(i%4*cw),round(i//4*ch)
        cell=src.crop((ox,oy,round((i%4+1)*cw),round((i//4+1)*ch)))
        alpha=cell.getchannel('A').point(lambda a:255 if a>80 else 0)
        l,t,r,b=alpha.getbbox()
        cells.append((cell.crop((l,t,r,b)),cw/2-l))
    sheet=Image.new('RGBA',(640,320))
    boxes=[]
    factor=144/max(c.height for c,a in cells)
    for i,(cell,anchor) in enumerate(cells):
        k=min(144/cell.width,144/cell.height) if name=='objects' else factor
        w,h=round(cell.width*k),round(cell.height*k)
        cell=cell.resize((w,h),Image.Resampling.NEAREST)
        x,y=i%4*160+(160-w)//2,i//4*160+(160-h)//2
        sheet.paste(cell,(x,y))
        boxes.append(dict(x=x,y=y,w=w,h=h,anchor=anchor*k))
    sheet.save(root/f'{name}-mobile.webp',lossless=True,method=6)
    meta['hero' if name=='einstein' else 'objects']=boxes
(root/'atlas-layout.mjs').write_text('export default '+json.dumps(meta,separators=(',',':'))+';\n')
