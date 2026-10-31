p='/home/user/Xenke/dist/expedition-game.mjs';s=open(p).read()
def R(a,b,n=1):
    global s
    assert s.count(a)==n,(s.count(a),a[:90]);s=s.replace(a,b)
old=s[s.index(" for(let i=0;i<3;i++){const x=beds[i];rect(x-15,GROUND-4,30,5,'#856443');"):]
old=old[:old.index("\n")+1]
R(old," for(let i=0;i<3;i++)drawBed(i);\n")
R("// Lamp light, added on top:",r"""// Planter boxes. The first bed of a story save shows each step of the first planting in its own look:
// dry and cracked → sown (dark furrow, seeds) → watered (wet, glistening) → a sprout that grows in and sways.
function drawBed(i){const x=beds[i],G=GROUND,st=story(),first=state.story&&i===0,stage=first?(st.sprout?3:st.watered?2:state.beds[0]?1:0):state.beds[i]?4:0;
 if(x<camera.x-30||x>camera.x+VW+30)return;
 drawShadow(x,G+1,38,.6);rect(x-18,G-13,36,13,'#1e140c');rect(x-17,G-12,34,12,'#6b4a2c');rect(x-17,G-12,34,2,'#8c6136');rect(x-17,G-6,34,1,'#4a3020');for(const nx of [-15,13])rect(x+nx,G-10,2,2,'#c9c2b0');
 const soil=stage===2||stage===3?'#3a2818':stage===1?'#5a3e26':stage===4?'#4a3420':'#8a6a4a';rect(x-15,G-14,30,3,soil);
 if(stage===0){rect(x-9,G-14,1,2,'#5a4430');rect(x+4,G-13,3,1,'#5a4430');for(let j=0;j<3;j++)rect(x-10+j*9,G-20-j%2*2,1,6+j%2*2,'#7a6040');}
 if(stage===1){rect(x-12,G-13,24,1,'#2a1c10');for(let j=0;j<4;j++)rect(x-9+j*6,G-14,2,1,'#e8d9a0');}
 if(stage===2||stage===3){for(let j=0;j<5;j++)rect(x-12+j*6,G-14,2,1,'#9fd6e0');if(Math.floor(now*2)%2)rect(x+5,G-14,1,1,'#e6fbff');}
 if(stage===3){const g=Math.min(1,sproutT/1.6),e=1-Math.pow(1-g,3),h=Math.round(2+e*12),sw=Math.sin(now*2)*(g>=1?1:0);rect(x+sw*.5,G-14-h,1,h,'#5aa04a');if(h>6){rect(x-4+sw,G-14-h,4,2,'#8ed06a');rect(x+1+sw,G-15-h,4,2,'#a8e07a');rect(x-4+sw,G-14-h,1,1,'#c6f0a0');}}
 if(stage===4)for(let j=0;j<4;j++){const xx=x-10+j*7,height=15+(j%2)*9;rect(xx,G-height,2,height-4,'#93b36e');rect(xx-4,G-height+3,5,3,'#b2ce82');rect(xx+2,G-height-1,5,3,'#c6dda1');rect(xx+1,G-height-4,3,3,j%2?'#dcc17f':'#bccea1');}
 // Watering: a stream from the hero's hand into the box on each pour.
 if(first&&interaction.key==='waterBed'){const f=turnPhase();if(f<.7){const hx=player.x+player.face*10,hy=G-24;for(let k=0;k<5;k++){const t=(f/.7+k/5)%1;rect(hx+(x-hx)*t,hy+(G-15-hy)*t*t,1,2,'#7fd0ec');}}}}
// Lamp light, added on top:""")
R("  {const b=CANS[0],lvl=Math.round((running?.2+.6*waterFillT:.08)*8);rect(b.x-5,G-10+(8-lvl),10,1,'#7fd0ec');}",
  "  // Bucket level shows the clean-water stock (story saves); a ripple while the stream runs into it.\n  {const b=CANS[0],stock=state.story?story().tank/TANK.max:waterFillT,lvl=Math.round((running?.15+.75*stock:.08)*8);rect(b.x-5,G-10+(8-lvl),10,1,'#7fd0ec');if(running&&Math.floor(now*6)%2)rect(b.x-2,G-10+(8-lvl),3,1,'#e6fbff');}")
# a soft green glow over the first sprout, part of the visible change at the end of the episode
R(" if(running){ctx.globalAlpha=.22;ctx.drawImage(A.cyan,CANS[0].x-18,G-30,36,30);}"," if(running){ctx.globalAlpha=.22;ctx.drawImage(A.cyan,CANS[0].x-18,G-30,36,30);}\n if(st.sprout){ctx.globalAlpha=.3*Math.min(1,sproutT);ctx.drawImage(A.green,BEDS[0]-26,G-44,52,44);}")
open(p,'w').write(s);print('ok')
