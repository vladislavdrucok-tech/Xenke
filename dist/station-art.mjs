// Station workshop props drawn in code (until the painted sheets in ASSETS_NEEDED.md arrive).
// Each prop is baked once into a canvas at P canvas pixels per world unit, the same density as the hero sprites,
// so they share one look: dark outline, light from the upper left, worn steel and brass, rust and grime.
export const P=3;
const hash=(x,y)=>{let h=(x*374761393+y*668265263)|0;h=(h^(h>>>13))*1274126177|0;return ((h^(h>>>16))>>>0)/4294967296;};
function canvas(doc,w,h){const c=doc.createElement('canvas');c.width=w;c.height=h;const g=c.getContext('2d');return [c,g];}
// Pixel helpers in canvas pixels.
function kit(g){
 const R=(x,y,w,h,c)=>{g.fillStyle=c;g.fillRect(Math.round(x),Math.round(y),Math.round(w),Math.round(h));};
 // Vertical cylinder: banded shading (highlight left, shadow right) with a dark outline.
 const cyl=(x,y,w,h,[hi,mid,lo,dark])=>{R(x-2,y-2,w+4,h+4,'#141414');const b=[hi,mid,mid,mid,lo,lo,dark];for(let i=0;i<w;i++){R(x+i,y,1,h,b[Math.min(b.length-1,Math.floor(i/w*b.length))]);}R(x+Math.round(w*.18),y,2,h,'rgba(255,255,255,.18)');};
 const dome=(x,y,w,h,cols)=>{for(let j=0;j<h;j++){const k=Math.sqrt(1-((h-j)/h)**2),ww=Math.round(w*k),xx=x+(w-ww)/2;R(xx-2,y+j-1,ww+4,2,'#141414');}for(let j=0;j<h;j++){const k=Math.sqrt(1-((h-j)/h)**2),ww=Math.round(w*k),xx=Math.round(x+(w-ww)/2);for(let i=0;i<ww;i++)R(xx+i,y+j,1,1,cols[Math.min(3,Math.floor(i/ww*4.2))]);}};
 const rivets=(x,y,w,step,c='#c9d3d8')=>{for(let i=x;i<x+w;i+=step){R(i,y,2,2,c);R(i+1,y+1,1,1,'#2a2a2a');}};
 const rust=(x,y,w,h,amount,seed)=>{for(let i=0;i<w;i+=2)for(let j=0;j<h;j+=2){const v=hash(i+seed,j*3+seed);if(v<amount)R(x+i,y+j,2,2,v<amount*.4?'#7a3a18':v<amount*.75?'#a8582a':'#5a3a24');}};
 const circle=(cx,cy,r,c)=>{for(let j=-r;j<=r;j++){const w=Math.round(Math.sqrt(r*r-j*j));R(cx-w,cy+j,w*2+1,1,c);}};
 return {R,cyl,dome,rivets,rust,circle};}
// The filter machine (72 x 76 world units): left supply pipe with the tap wheel, the main tank with an inspection window,
// a side tank, a gauge, a lamp box and the spout that feeds the water cans. Window, lamp, gauge needle, wheel and water are drawn live.
export const MACHINE={w:72,h:76,window:[24,28,18,30],lamp:[46,19],gauge:[55,25,4],wheel:[8,32,5],unit:[1,38,10,9],spout:[70,38],drip:[8,57]};
function bakeMachine(doc){const W=MACHINE.w*P,H=MACHINE.h*P,[c,g]=canvas(doc,W,H),{R,cyl,dome,rivets,rust,circle}=kit(g);
 const blue=['#6a8ca3','#466a84','#334f66','#1f3142'],blue2=['#7096ad','#4c7690','#385a72','#22384a'],brass=['#e2b46a','#b3843f','#8a5f2a','#5a3c1a'],steel=['#9aa6ad','#6b777e','#4c565c','#2e353a'];
 // Base platform.
 R(6,H-20,W-12,18,'#141414');R(8,H-18,W-16,14,'#4c565c');R(8,H-18,W-16,3,'#6f7a80');rivets(14,H-12,W-28,16);
 // Side tank (behind), with rust streaks.
 cyl(152,96,40,H-118,blue2);dome(152,82,40,16,blue2);rust(152,110,40,H-140,.12,7);R(152,140,40,4,'#2a4256');R(152,180,40,4,'#2a4256');
 // Main tank with rounded top, rivet bands and grime.
 cyl(52,58,96,H-80,blue);dome(52,30,96,30,blue);rivets(56,64,90,8);rivets(56,H-30,90,8);rust(54,70,92,H-104,.14,3);rust(54,34,92,30,.1,11);
 for(let i=0;i<24;i++){const v=hash(i,9);R(56+v*86,180+hash(i,4)*30,3,8+v*10,'rgba(40,30,20,.35)');}
 // Inspection window frame (glass drawn live).
 const [wx,wy,ww,wh]=MACHINE.window.map(v=>v*P);R(wx-6,wy-6,ww+12,wh+12,'#141414');R(wx-4,wy-4,ww+8,wh+8,'#8a949a');R(wx-4,wy-4,ww+8,2,'#c3ccd0');rivets(wx-2,wy-4,ww+4,10,'#e0e6e8');rivets(wx-2,wy+wh+2,ww+4,10,'#e0e6e8');
 // Supply pipe on the left: brass with flanged joints, elbow into the tank top.
 cyl(16,40,16,H-62,brass);for(const y of [70,118,160,196])R(12,y,24,8,'#5a3c1a'),R(13,y+1,22,3,'#e2b46a');
 R(16,26,60,16,'#141414');for(let i=0;i<14;i++)R(18,28+i,56,1,brass[Math.min(3,Math.floor(i/4))]);R(66,26,16,20,'#5a3c1a');
 // Pipe from the side tank to the spout, ending in a downward nozzle.
 R(188,104,26,14,'#141414');for(let i=0;i<10;i++)R(188,106+i,24,1,steel[Math.min(3,Math.floor(i/3))]);R(204,104,12,22,'#141414');R(206,106,8,18,'#6b777e');R(206,106,2,18,'#9aa6ad');
 // Gauge housing and lamp box.
 const [gx,gy,gr]=MACHINE.gauge.map(v=>v*P);circle(gx,gy,gr+3,'#141414');circle(gx,gy,gr+1,'#b3843f');circle(gx,gy,gr-1,'#e9e4d2');for(let a=0;a<6;a++){const t=Math.PI*(.8+a*.28);R(gx+Math.cos(t)*(gr-3),gy+Math.sin(t)*(gr-3),2,2,'#2a2a2a');}
 const [lx,ly]=MACHINE.lamp.map(v=>v*P);R(lx-8,ly-8,16,16,'#141414');R(lx-6,ly-6,12,12,'#3b4449');
 // Hoses and a valve stub on the side tank.
 g.strokeStyle='#2a3a40';g.lineWidth=5;g.beginPath();g.moveTo(170,H-26);g.quadraticCurveTo(196,H-10,206,H-34);g.stroke();g.strokeStyle='#4f6a74';g.lineWidth=2;g.stroke();
 return c;}
// Cracked and clean glass for the window; the water inside is drawn live when the filter runs.
function bakeGlass(doc,cracked){const [ww,wh]=[MACHINE.window[2]*P,MACHINE.window[3]*P],[c,g]=canvas(doc,ww,wh),{R}=kit(g);
 const gr=g.createLinearGradient(0,0,ww,wh);gr.addColorStop(0,cracked?'#24343a':'#2b4650');gr.addColorStop(1,cracked?'#111a1e':'#16262c');g.fillStyle=gr;g.fillRect(0,0,ww,wh);
 R(4,4,3,wh-8,'rgba(220,240,245,.25)');R(9,4,1,wh*.5,'rgba(220,240,245,.18)');
 if(cracked){g.strokeStyle='rgba(225,240,240,.85)';g.lineWidth=1.5;g.beginPath();g.moveTo(ww*.62,wh*.18);g.lineTo(ww*.48,wh*.42);g.lineTo(ww*.58,wh*.55);g.lineTo(ww*.36,wh*.86);g.moveTo(ww*.48,wh*.42);g.lineTo(ww*.2,wh*.36);g.moveTo(ww*.58,wh*.55);g.lineTo(ww*.86,wh*.66);g.stroke();
  R(ww*.44,wh*.38,8,8,'#0a0f12');R(ww*.45,wh*.39,6,6,'#050709');for(let i=0;i<10;i++)R(hash(i,1)*ww,wh*.88+hash(i,2)*wh*.1,2,2,'#3a2a1a');}
 return c;}
// The repair unit: a brass coupling with flanges and a pressure screw.
function bakeUnit(doc){const [w,h]=[MACHINE.unit[2]*P,MACHINE.unit[3]*P],[c,g]=canvas(doc,w,h),{R}=kit(g);R(0,0,w,h,'#141414');R(2,2,w-4,h-4,'#c9954a');R(2,2,w-4,4,'#f2cf86');R(2,h-6,w-4,4,'#7a5226');R(0,h*.35,w,h*.3,'#141414');R(1,h*.35+2,w-2,h*.3-4,'#8a949a');R(w*.4,1,w*.2,h-2,'#e2b46a');return c;}
// Water cans, a bucket and a blue drum (world units ~12-16 wide). Fill levels are drawn live.
function bakeCan(doc,body){const W=13*P,H=18*P,[c,g]=canvas(doc,W,H),{R,rivets}=kit(g);R(0,6,W,H-6,'#141414');R(2,8,W-4,H-10,body[1]);R(2,8,6,H-10,body[0]);R(W-8,8,6,H-10,body[2]);R(6,0,W-20,9,'#141414');R(8,2,W-24,5,body[2]);R(W-14,2,10,8,'#141414');R(W-12,3,6,6,'#8a949a');
 g.strokeStyle='rgba(0,0,0,.35)';g.lineWidth=2;g.beginPath();g.moveTo(6,16);g.lineTo(W-6,H-6);g.moveTo(W-6,16);g.lineTo(6,H-6);g.stroke();rivets(5,H-8,W-10,8,'#d0d6d8');return c;}
function bakeBucket(doc){const W=14*P,H=11*P,[c,g]=canvas(doc,W,H),{R}=kit(g);for(let j=0;j<H;j++){const inset=Math.round(j/H*5);R(inset,j,W-inset*2,1,'#141414');R(inset+2,j,W-inset*2-4,1,j<4?'#c3ccd0':j%9<2?'#6b777e':'#8a949a');}R(4,0,W-8,4,'#1c2a30');return c;}
function bakeDrum(doc){const W=16*P,H=22*P,[c,g]=canvas(doc,W,H),{R,cyl,rivets}=kit(g);cyl(2,6,W-4,H-8,['#6f9fd0','#3c6a9a','#2c5078','#1a3048']);R(0,4,W,6,'#141414');R(2,5,W-4,3,'#5b8ac0');for(const y of [22,44])R(2,y,W-4,3,'#1a3048');rivets(6,H-8,W-12,8);return c;}
// Old radio: wooden case, metal front with speaker grill, tuning dial window and two knobs.
function bakeRadio(doc){const W=20*P,H=14*P,[c,g]=canvas(doc,W,H),{R,circle}=kit(g);R(0,0,W,H,'#141414');R(2,2,W-4,H-4,'#6b4a2c');R(2,2,W-4,3,'#8c6136');R(5,6,W-10,H-11,'#3b4449');R(5,6,W-10,2,'#5d676d');
 for(let x=8;x<26;x+=3)for(let y=10;y<H-8;y+=3)R(x,y,2,2,'#1a1f22');R(30,10,22,9,'#141414');for(let i=0;i<5;i++)R(32+i*4,14,1,4,'#5a4a2a');circle(36,H-11,3,'#c9c2b0');circle(48,H-11,3,'#c9c2b0');R(0,H-3,W,3,'#141414');return c;}
// Tarp canopy over the workbench on two poles, with a hanging lamp.
function bakeCanopy(doc){const W=96*P,H=82*P,[c,g]=canvas(doc,W,H),{R}=kit(g);
 for(const x of [6,W-12]){R(x-1,30,8,H-30,'#141414');R(x,30,6,H-30,'#6b4a2c');R(x,30,2,H-30,'#8c6136');}
 // The tarp sags between the poles; ragged hem, two tones, a patch.
 for(let x=0;x<W;x++){const sag=Math.sin(x/W*Math.PI)*16,top=18+sag*.4,bot=46+sag+Math.round(hash(x>>2,5)*6);R(x,top-2,1,bot-top+4,'#141414');R(x,top,1,bot-top,x%40<20?'#4f6478':'#465a6d');R(x,top,1,3,'#7088a0');}
 R(W*.3,30,30,16,'#7a6a52');R(W*.3,30,30,2,'#9a8a6a');
 g.strokeStyle='#141414';g.lineWidth=2;g.beginPath();g.moveTo(W*.5,40);g.lineTo(W*.5,64);g.stroke();R(W*.5-7,62,14,8,'#2b2b2b');R(W*.5-5,70,10,6,'#ffd08a');return c;}
// Soft warm light, added on top of the scene around lamps.
function bakeGlow(doc,color){const [c,g]=canvas(doc,64,64),gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,color);gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);return c;}
export function bakeStationArt(doc){if(!doc?.createElement)return null;
 return {machine:bakeMachine(doc),glassBroken:bakeGlass(doc,true),glassClean:bakeGlass(doc,false),unit:bakeUnit(doc),canRed:bakeCan(doc,['#c0503a','#9a3a2a','#6a2418']),canOlive:bakeCan(doc,['#8a9a5a','#6a7a40','#46522a']),
  bucket:bakeBucket(doc),drum:bakeDrum(doc),radio:bakeRadio(doc),canopy:bakeCanopy(doc),warm:bakeGlow(doc,'rgba(255,190,110,.55)'),red:bakeGlow(doc,'rgba(255,70,50,.6)'),green:bakeGlow(doc,'rgba(110,230,120,.55)'),cyan:bakeGlow(doc,'rgba(120,210,240,.5)')};}
