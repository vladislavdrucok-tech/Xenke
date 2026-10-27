// Procedural pixel art for the overgrown shellback that guards the forest.
// Frames are generated once at boot; pixels() is pure so it can be tested without a canvas.
export const SHELLBACK={w:72,h:46,frames:['walk0','walk1','walk2','walk3','bite','hurt']};
const C={line:'#1a1420',seam:'#22301f',shell:['#26342b','#33482f','#4a6a40','#678f50','#8fb866'],belly:['#3d3140','#5a4757'],leg:['#2e2530','#4b3d48'],moss:['#7fae4e','#a9d06f'],cap:['#7d5a96','#a57ec2','#dcc3ef'],stem:'#cdbfd6',eye:'#f6d56a',eyeGlow:'#fff3b8',jaw:'#c9b48e'};
const BAYER=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const hash=(x,y)=>{let h=(x*374761393+y*668265263)|0;h=(h^(h>>>13))*1274126177|0;return ((h^(h>>>16))>>>0)/4294967296;};
export function pixels(frame){
 const {w,h}=SHELLBACK,px=Array.from({length:h},()=>Array(w).fill(null));
 const set=(x,y,c)=>{x=Math.round(x);y=Math.round(y);if(x>=0&&y>=0&&x<w&&y<h)px[y][x]=c;};
 const walk=frame.startsWith('walk')?+frame[4]:0,bite=frame==='bite';
 const bob=walk%2?1:0,cx=33,cy=27+bob,rx=27,ry=18;
 // Legs first so the shell overlaps them: three visible legs, alternating stride.
 for(let i=0;i<3;i++){const phase=(walk+i*2)%4,lx=16+i*16+[-2,-1,1,2][phase]*(frame==='hurt'?0:1),lift=phase===1||phase===2?1:0;
  for(let y=33+bob;y<44-lift;y++){set(lx-1,y,C.leg[1]);set(lx,y,C.leg[1]);set(lx+1,y,C.leg[0]);set(lx+2,y,C.leg[0]);}
  for(let x=-2;x<4;x++)set(lx+x,44-lift,C.line);set(lx+4,44-lift,C.jaw);set(lx+3,43-lift,C.jaw);}
 // Belly band under the dome.
 for(let x=8;x<60;x++)for(let y=31+bob;y<37+bob;y++)set(x,y,y<34+bob?C.belly[1]:C.belly[0]);
 // Head with glowing eye and jaws; the bite frame thrusts it forward and opens the mandibles.
 const hx=60+(bite?4:0),hy=31+bob;
 for(let y=-7;y<=6;y++)for(let x=-9;x<=9;x++){if((x*x)/81+(y*y)/49<=1)set(hx+x,hy+y,x+y<-2?C.belly[1]:C.belly[0]);}
 set(hx+3,hy-2,C.eye);set(hx+4,hy-2,C.eyeGlow);set(hx+3,hy-3,C.eye);set(hx+4,hy-3,C.eye);set(hx+5,hy-2,C.eye);
 const open=bite?3:1;for(let i=0;i<4;i++){set(hx+7+i,hy-open+Math.floor(i/2),C.jaw);set(hx+7+i,hy+2+open-Math.floor(i/2),C.jaw);}
 // Dome: ordered-dither shading lit from the top-left, with plate seams.
 for(let y=cy-ry;y<=cy+4;y++)for(let x=cx-rx;x<=cx+rx;x++){const nx=(x-cx)/rx,ny=(y-cy)/ry,d=nx*nx+ny*ny;if(d>1)continue;
  const light=.55-nx*.35-ny*.55+(1-d)*.25,t=BAYER[(y&3)*4+(x&3)]/16-.5,i=Math.max(0,Math.min(4,Math.floor(light*4+t*.9)));
  const r=Math.sqrt(d),a=Math.atan2(ny,nx),seam=Math.abs(r-.62)<.05||(r>.62&&Math.abs(((a+Math.PI)%.7)-.35)<.045&&ny<.1);
  const rot=!seam&&ny<-.05&&hash(x>>1,y>>1)<.13;set(x,y,seam?C.seam:rot?C.cap[hash(x,y)<.5?0:1]:C.shell[i]);}
 // Outline every filled pixel that touches transparency.
 const solid=(x,y)=>x>=0&&y>=0&&x<w&&y<h&&px[y][x]&&px[y][x]!==C.line;
 const edges=[];for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(solid(x,y)&&(!solid(x-1,y)||!solid(x+1,y)||!solid(x,y-1)||!solid(x,y+1)))edges.push([x,y]);
 for(const[x,y]of edges)if(!solid(x,y-1)||y>=40)set(x,y,C.line);
 // Moss tufts and contaminated mushrooms on the shell crest.
 const top=x=>{for(let y=0;y<h;y++)if(px[y][x])return y;return h;};
 for(let x=cx-rx+6;x<=cx+rx-6;x+=5){const y=top(x);set(x,y-1,C.line);set(x,y-2,C.line);set(x+1,y-1,C.seam);}
 for(let x=cx-rx+4;x<=cx+rx-4;x++){const y=top(x);if(hash(x,3)<.5){set(x,y-1,C.moss[hash(x,7)<.5?0:1]);if(hash(x,9)<.3)set(x,y-2,C.moss[1]);}}
 for(const [mx,size] of [[20,3],[33,4],[46,3]]){const y=top(mx)-1+bob*0;for(let s=0;s<size+1;s++)set(mx,y-s,C.stem);const cy2=y-size-1;
  for(let x=-size;x<=size;x++){set(mx+x,cy2,C.cap[1]);set(mx+x,cy2-1,Math.abs(x)<size?C.cap[x<0?2:1]:C.cap[0]);}set(mx,cy2-2,C.cap[0]);}
 return px;
}
// Paint every frame into one strip canvas; returns {canvas, w, h} with frame i at x=i*w.
export function bakeShellback(doc=document){const {w,h,frames}=SHELLBACK,c=doc.createElement('canvas');c.width=w*frames.length;c.height=h;const g=c.getContext('2d');
 frames.forEach((f,i)=>{const px=pixels(f==='hurt'?'walk0':f);for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(px[y][x]){g.fillStyle=px[y][x];g.fillRect(i*w+x,y,1,1);}
  if(f==='hurt'){g.globalCompositeOperation='source-atop';g.fillStyle='rgba(255,246,226,.72)';g.fillRect(i*w,0,w,h);g.globalCompositeOperation='source-over';}});
 return {canvas:c,w,h};}
