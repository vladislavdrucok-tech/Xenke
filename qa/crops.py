import sys
from PIL import Image
out=sys.argv[1];l,t,r,b=map(float,sys.argv[2].split(','));fs=sys.argv[3:];cols=4
ims=[]
for f in fs:
    im=Image.open(f).convert('RGB');w,h=im.size;ims.append(im.crop((int(w*l),int(h*t),int(w*r),int(h*b))))
tw,th=ims[0].size;rows=(len(ims)+cols-1)//cols;o=Image.new('RGB',(tw*cols,th*rows))
for i,im in enumerate(ims):o.paste(im,(i%cols*tw,i//cols*th))
o.thumbnail((2000,2000));o.save(out)
