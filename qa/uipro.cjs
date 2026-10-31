const {chromium}=require('playwright');const S=process.argv[2];
(async()=>{const b=await chromium.launch();
for(const [w,h] of [[844,390],[640,320],[740,360],[1280,720],[390,844]]){const ctx=await b.newContext({viewport:{width:w,height:h},hasTouch:w<1000,isMobile:w<1000,deviceScaleFactor:2,locale:'uk-UA'});const p=await ctx.newPage();
 await p.goto('http://localhost:8123/index.html');await p.waitForFunction(()=>!document.querySelector('#start-btn').disabled);await p.click('#start-btn');await p.waitForTimeout(1300);
 await p.evaluate(()=>{const r=document.querySelector('#rotate-hint');if(r)r.hidden=true;});
 // walk to the wrench so the target label, dialog and toast are all up
 await p.keyboard.down('ArrowRight');for(let i=0;i<200;i++){await p.waitForTimeout(25);const x=await p.evaluate(()=>window.afterfall.snapshot().player.x);if(x>505)break;}await p.keyboard.up('ArrowRight');await p.waitForTimeout(300);
 const res=await p.evaluate(()=>{const ids=['#dialog','#target-label','#toast','#jump','#action','#hotbar','.hud-left','.hud-right','#move-pad .stick'];const boxes=[];for(const id of ids){const e=document.querySelector(id);if(!e||e.hidden)continue;const cs=getComputedStyle(e);if(cs.display==='none'||cs.visibility==='hidden'||(id==='#toast'&&!e.classList.contains('show'))||(id==='#target-label'&&!e.textContent))continue;const r=e.getBoundingClientRect();if(r.width&&r.height)boxes.push([id,r]);}
  const ov=[];for(let i=0;i<boxes.length;i++)for(let j=i+1;j<boxes.length;j++){const a=boxes[i][1],c=boxes[j][1];if(a.left<c.right-2&&c.left<a.right-2&&a.top<c.bottom-2&&c.top<a.bottom-2)ov.push(boxes[i][0]+'×'+boxes[j][0]);}
  const off=boxes.filter(([id,r])=>r.left<-1||r.top<-1||r.right>innerWidth+1||r.bottom>innerHeight+1).map(b=>b[0]);return {shown:boxes.map(b=>b[0]),ov,off};});
 console.log(w+'x'+h,JSON.stringify(res));await p.screenshot({path:`${S}/uip-${w}.png`});await ctx.close();}
await b.close();})();
