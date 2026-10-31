import sys
from PIL import Image
out=sys.argv[1];fs=sys.argv[2:];box=None
cols=3;ims=[Image.open(f).convert('RGB') for f in fs]
w,h=ims[0].size;s=0.5;tw,th=int(w*s),int(h*s);rows=(len(ims)+cols-1)//cols
o=Image.new('RGB',(tw*cols,th*rows))
for i,im in enumerate(ims):o.paste(im.resize((tw,th)),(i%cols*tw,i//cols*th))
o.save(out)
