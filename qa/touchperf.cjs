const {chromium}=require('playwright');const throttle=+(process.argv[2]||1);
const story=o=>Object.assign({woke:true,tool:true,hatch:true,out:true,road:true,station:true,fixed:false,water:false,radio:false,done:false,said:['wake','tool','hatch','road','mats','station','h-move','h-act','h-climb','h-rotate']},o);
const save=JSON.stringify({version:3,time:120,hero:'einstein',scene:'surface',inv:{wood:12,stone:0,scrap:6,cloth:2,fuse:0,seed:0,dirty:0,water:0,planter:0,berry:2,ammo:12,ore:0,wire:0,medkit:0,can:1,wrench:1,repair:0},built:{bench:true,filter:false,generator:false,purifier:false,torch:false,repair:false},beds:[false,false,false],vault:false,harvested:{'chest-a':1,'chest-b':1},player:{x:560,y:284},stats:{hp:100,food:90,thirst:90},defense:{time:0,hp:100,wave:0},completed:false,forest:[false,false,false],mine:{ore:[false,false,false],crates:[false,false],panel:false},seedvault:{caps:[false,false,false],boss:false,door:false},story:story({})});
(async()=>{const b=await chromium.launch();const ctx=await b.newContext({viewport:{width:844,height:390},hasTouch:true,isMobile:true,deviceScaleFactor:3,locale:'uk-UA'});
await ctx.addInitScript(s=>{if(!sessionStorage.getItem('x')){sessionStorage.setItem('x','1');localStorage.setItem('afterfall-last-greenhouse-v3',s);}},save);
const p=await ctx.newPage();const errs=[];p.on('pageerror',e=>errs.push(e.message));await p.goto('http://localhost:8123/index.html');await p.waitForFunction(()=>!document.querySelector('#start-btn').disabled);await p.tap('#start-btn');await p.waitForTimeout(3500);
const cdp=await ctx.newCDPSession(p);if(throttle>1)await cdp.send('Emulation.setCPUThrottlingRate',{rate:throttle});const T=(t,pts)=>cdp.send('Input.dispatchTouchEvent',{type:t,touchPoints:pts});
const snap=()=>p.evaluate(()=>{const s=window.afterfall.snapshot();return {x:s.player.x,y:s.player.y,ground:s.player.ground,fixed:s.story.fixed,repair:s.state.inv.repair,paused:s.paused};});
const box=async id=>{const r=await p.locator(id).boundingBox();return {x:r.x+r.width/2,y:r.y+r.height/2};};
const m=await box('#move-pad'),j=await box('#jump'),a=await box('#action');
// Frame recorder: rAF intervals and long tasks.
await p.evaluate(()=>{window.__f=[];window.__lt=[];let l=performance.now();const tick=t=>{window.__f.push(t-l);l=t;requestAnimationFrame(tick);};requestAnimationFrame(tick);try{new PerformanceObserver(list=>{for(const e of list.getEntries())window.__lt.push(Math.round(e.duration));}).observe({type:'longtask',buffered:false});}catch{}});
const stats=async label=>{const r=await p.evaluate(()=>{const f=window.__f.slice(2);window.__f=[];const lt=window.__lt.slice();window.__lt=[];return {f,lt};});const f=r.f.sort((x,y)=>x-y);if(!f.length)return console.log(label,'no frames');console.log(label.padEnd(26),'frames',String(f.length).padStart(3),'median',f[f.length>>1].toFixed(1),'p95',f[Math.floor(f.length*.95)].toFixed(1),'max',f[f.length-1].toFixed(1),'ms; long tasks',JSON.stringify(r.lt));};
// 1) Walk left while holding the stick; a second finger taps Jump: the hero must jump without stopping.
await stats('(idle before)');
await T('touchStart',[{x:m.x,y:m.y,id:1}]);await T('touchMove',[{x:m.x-30,y:m.y,id:1}]);await p.waitForTimeout(600);const s0=await snap();
await T('touchStart',[{x:m.x-30,y:m.y,id:1},{x:j.x,y:j.y,id:2}]);await p.waitForTimeout(160);const s1=await snap();await T('touchEnd',[{x:j.x,y:j.y,id:2}]);await p.waitForTimeout(500);const s2=await snap();
console.log('multi-touch: moving',(s0.x>s1.x)&&(s1.x>s2.x),'jumped',s1.y<s0.y-3,'still moving after jump finger lifted',s2.x<s1.x-10);
await p.waitForTimeout(1200);await stats('walking (stick held)');
await T('touchEnd',[{x:m.x-30,y:m.y,id:1}]);await p.waitForTimeout(300);
// 2) Walk to the bench, keep the stick finger down, tap Use: the craft sheet opens and every input is released.
const goto=async x=>{const s=await snap();const d=Math.sign(x-s.x);await T('touchStart',[{x:m.x,y:m.y,id:1}]);await T('touchMove',[{x:m.x+d*30,y:m.y,id:1}]);for(let i=0;i<400;i++){await p.waitForTimeout(16);const px=(await snap()).x;if((px-x)*d>=-2)break;}};
await goto(262);await p.evaluate(()=>{window.__t0=performance.now();});await T('touchStart',[{x:m.x-30,y:m.y,id:1},{x:a.x,y:a.y,id:3}]);
await p.waitForFunction(()=>document.querySelector('#craft-dialog').open);const openMs=await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(()=>r(performance.now()-window.__t0)))));
await T('touchEnd',[]);await p.waitForTimeout(800);await stats('craft sheet open');
console.log('craft open: tap → dialog painted',openMs.toFixed(1),'ms; pressed buttons now:',await p.evaluate(()=>document.querySelectorAll('.pressed').length));
await p.click('[data-craft="repair"]');await p.click('#craft-dialog .close');await p.waitForTimeout(500);const c0=await snap();await p.waitForTimeout(700);const c1=await snap();
console.log('after closing: hero still',Math.abs(c1.x-c0.x)<.5,'paused',c1.paused,'repair units',c1.repair);
// 3) Fixing the filter: interaction frames.
await goto(372);await T('touchEnd',[]);await T('touchStart',[{x:a.x,y:a.y,id:3}]);await p.waitForTimeout(80);await T('touchEnd',[]);await p.waitForTimeout(200);await stats('(walk to spot)');await p.waitForTimeout(2400);await stats('fixing the filter');
console.log('fixed',(await snap()).fixed,'errors',JSON.stringify(errs));await b.close();})();
