// Full prologue in the browser with touch input: capsule -> water -> radio. Screenshots along the way.
const {chromium}=require('playwright');const S=__dirname+'/out/pro',W=+(process.argv[3]||844),H=+(process.argv[4]||390),touch=process.argv[5]!=='pc';
(async()=>{const b=await chromium.launch();const ctx=await b.newContext({viewport:{width:W,height:H},hasTouch:touch,isMobile:touch,deviceScaleFactor:2,locale:'uk-UA'});
const p=await ctx.newPage();const errs=[];p.on('pageerror',e=>errs.push(e.message));p.on('console',m=>{if(m.type()==='error')errs.push(m.text())});
await p.goto('http://localhost:8123/index.html');await p.waitForFunction(()=>!document.querySelector('#start-btn').disabled);await p.screenshot({path:`${S}/00-title-${W}.png`});
touch?await p.tap('#start-btn'):await p.click('#start-btn');await p.waitForTimeout(1200);await p.screenshot({path:`${S}/01-capsule-${W}.png`});await p.waitForTimeout(2600);await p.screenshot({path:`${S}/02-awake-${W}.png`});
const cdp=await ctx.newCDPSession(p);const T=(t,pts)=>cdp.send('Input.dispatchTouchEvent',{type:t,touchPoints:pts});const snap=()=>p.evaluate(()=>window.afterfall.snapshot());
const box=async id=>{const r=await p.locator(id).boundingBox();return {x:r.x+r.width/2,y:r.y+r.height/2};};
const log=async tag=>{const s=await snap();console.log(tag,s.state.scene,Math.round(s.player.x),JSON.stringify(s.story&&{t:s.story.tool,h:s.story.hatch,o:s.story.out,st:s.story.station,f:s.story.fixed,w:s.story.water,d:s.story.done}),JSON.stringify({w:s.state.inv.wood,s:s.state.inv.scrap,c:s.state.inv.cloth,r:s.state.inv.repair}));};
async function moveTo(x){if(!touch){const s0=await snap();const k=x>s0.player.x?'ArrowRight':'ArrowLeft';await p.keyboard.down(k);for(let i=0;i<900;i++){await p.waitForTimeout(20);const s=await snap();const px=s.player.x;if(s.state.scene==='surface'&&px>1020&&px<1110&&s.player.ground)await p.keyboard.press('Space');if((x>s0.player.x)?px>=x-2:px<=x+2)break;}await p.keyboard.up(k);await p.waitForTimeout(200);return;}
 const m=await box('#move-pad');const s0=await snap();const d=Math.sign(x-s0.player.x);await T('touchStart',[{x:m.x,y:m.y,id:1}]);await T('touchMove',[{x:m.x+d*30,y:m.y,id:1}]);
 const j=await box('#jump');let jumping=false;for(let i=0;i<900;i++){await p.waitForTimeout(20);const s=await snap();const px=s.player.x;const need=s.state.scene==='surface'&&px>1020&&px<1110;
  if(need&&!jumping&&s.player.ground){await T('touchStart',[{x:m.x+d*30,y:m.y,id:1},{x:j.x,y:j.y,id:2}]);jumping=true;}else if(jumping&&!need){await T('touchEnd',[{x:j.x,y:j.y,id:2}]);await T('touchMove',[{x:m.x+d*30,y:m.y,id:1}]);jumping=false;}
  if((px-x)*d>=-2)break;}await T('touchEnd',[]);await p.waitForTimeout(250);}
async function act(ms=150){if(!touch){await p.keyboard.down('KeyE');await p.waitForTimeout(ms);await p.keyboard.up('KeyE');return;}const a=await box('#action');await T('touchStart',[{x:a.x,y:a.y,id:3}]);await p.waitForTimeout(ms);await T('touchEnd',[]);}
await moveTo(770);await p.screenshot({path:`${S}/03-valve-locked-${W}.png`});await act();await p.waitForTimeout(400);await p.screenshot({path:`${S}/04-no-tool-${W}.png`});
await moveTo(520);await p.screenshot({path:`${S}/05-wrench-${W}.png`});await act();await p.waitForTimeout(800);await log('tool');
await moveTo(770);await act(150);await p.waitForTimeout(1000);await p.screenshot({path:`${S}/06-turning-${W}.png`});await p.waitForTimeout(1200);await log('hatch');await p.screenshot({path:`${S}/07-hatch-${W}.png`});
await moveTo(840);await act();await p.waitForTimeout(900);await p.screenshot({path:`${S}/08-climb-${W}.png`});await p.waitForTimeout(3000);await log('out');await p.screenshot({path:`${S}/09-road-${W}.png`});
await moveTo(1180);await p.screenshot({path:`${S}/10-chest-${W}.png`});await act();await p.waitForTimeout(1500);await p.screenshot({path:`${S}/11-chest-open-${W}.png`});await act(1500);await log('chest-a twice');
await moveTo(985);await act();await p.waitForTimeout(1500);await moveTo(800);await act();await p.waitForTimeout(3600);await log('logs');await p.screenshot({path:`${S}/12-logs-${W}.png`});
await moveTo(400);await p.waitForTimeout(1500);await p.screenshot({path:`${S}/13-station-${W}.png`});await moveTo(382);await p.screenshot({path:`${S}/14-filter-broken-${W}.png`});
await moveTo(262);await act();await p.waitForTimeout(700);await p.screenshot({path:`${S}/15-craft-${W}.png`});
for(let i=0;i<4;i++){await p.click('[data-craft="repair"]',{timeout:2000}).catch(()=>{});}await p.waitForTimeout(400);await p.screenshot({path:`${S}/16-crafted-${W}.png`});await p.click('#craft-dialog .close').catch(async()=>{await p.keyboard.press('Escape');});await p.waitForTimeout(300);await log('crafted');
await moveTo(372);await act();await p.waitForTimeout(1500);await p.screenshot({path:`${S}/17-fixing-${W}.png`});await p.waitForTimeout(2600);await log("fixed");await act();await p.waitForTimeout(2200);await log('water');await p.screenshot({path:`${S}/18-water-${W}.png`});
await moveTo(214);await act();await p.waitForTimeout(2500);await p.screenshot({path:`${S}/19-radio-${W}.png`});
for(let i=0;i<10;i++){await p.click('#dialog').catch(()=>{});await p.waitForTimeout(300);}await p.waitForTimeout(1200);await log('end');await p.screenshot({path:`${S}/20-end-${W}.png`});
await p.reload();await p.waitForFunction(()=>!document.querySelector('#start-btn').disabled);await log('reloaded');console.log('errors',JSON.stringify(errs));await b.close();})();
