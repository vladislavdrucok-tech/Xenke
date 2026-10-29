import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const elements=new Map(),listeners={};let resourceRebuilds=0;
class El{
 constructor(id=''){this.id=id;this.dataset={};this.listeners={};this.open=false;this._html='';this.textContent='';this.hidden=false;this.style={};this.classes=new Set();this.classList={add:(v)=>this.classes.add(v),remove:(v)=>this.classes.delete(v),contains:(v)=>this.classes.has(v),toggle:(v,on)=>{const yes=on===undefined?!this.classes.has(v):on;yes?this.classes.add(v):this.classes.delete(v);return yes;}};}
 set innerHTML(v){if(this.id==='hotbar')resourceRebuilds++;this._html=v;for(const match of v.matchAll(/data-(craft|pick)="(\w+)"/g)){const b=new El(match[1]+'-'+match[2]);b.dataset[match[1]]=match[2];elements.set(b.id,b);}}
 get innerHTML(){return this._html;}
 addEventListener(n,f){(this.listeners[n]||=[]).push(f);}
 setPointerCapture(){}
 setAttribute(k,v){(this.attrs||={})[k]=v;}
 getAttribute(k){return this.attrs?.[k]??null;}
 querySelector(){return null;}
 querySelectorAll(){return [];}
 getBoundingClientRect(){return {width:390,height:844,left:0,top:0,right:390,bottom:844};}
 showModal(){this.open=true;}
 close(){this.open=false;}
}
function el(id){if(!elements.has(id))elements.set(id,new El(id));return elements.get(id);}
const gradient={addColorStop(){}};
const context=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient},{get:(o,k)=>k in o?o[k]:()=>{}});
el('world').getContext=()=>context;
for(const id of ['craft-dialog','bag-dialog','pause-dialog','settings-dialog','win-dialog'])el(id);
globalThis.document={hidden:false,querySelector(s){if(s==='dialog[open]')return [...elements.values()].find(e=>e.id.endsWith('-dialog')&&e.open)||null;return el(s.slice(1));},querySelectorAll(s){if(s==='dialog[open]')return [...elements.values()].filter(e=>e.id.endsWith('-dialog')&&e.open);if(s==='dialog')return [...elements.values()].filter(e=>e.id.endsWith('-dialog'));if(s==='[data-craft]')return [...elements.values()].filter(e=>e.dataset.craft);if(s==='[data-pick]')return [...elements.values()].filter(e=>e.dataset.pick);return [];},addEventListener(){}};
globalThis.window={requestIdleCallback:f=>f(),addEventListener(n,f){listeners[n]=f;}};
globalThis.localStorage={data:{},getItem(k){return this.data[k]||null;},setItem(k,v){this.data[k]=v;},removeItem(k){delete this.data[k];}};
let raf;globalThis.requestAnimationFrame=f=>raf=f;
globalThis.setTimeout=()=>1;globalThis.clearTimeout=()=>{};
await import('./dist/expedition-game.mjs');
const {quest}=await import('./dist/expedition.mjs?v=6');
let clock=0;function run(seconds){for(let i=0;i<Math.ceil(seconds*60);i++){clock+=1000/60;raf(clock);}}
const padSend=(type,pointerId,clientX,clientY=600)=>(el('move-pad').listeners[type]||[]).forEach(f=>f({pointerId,clientX,clientY,preventDefault(){}}));
// The stick is a floating zone: 'left'/'right' press it and slide the thumb 60px.
function down(id){if(id==='left'||id==='right'){padSend('pointerdown',1,200);padSend('pointermove',1,id==='right'?225:175);return;}for(const f of el(id).listeners.pointerdown||[])f({preventDefault(){},pointerId:1});}
function up(id){if(id==='left'||id==='right'){padSend('pointerup',1,200);return;}for(const f of el(id).listeners.pointerup||[])f({});}
function snap(){return window.afterfall.snapshot();}
function moveTo(x){const sign=Math.sign(x-snap().player.x),dir=sign>0?'right':'left';down(dir);let iterations=0,jumping=false;while(Math.abs(snap().player.x-x)>2&&iterations++<2500){const px=snap().player.x;const needJump=sign>0?px>1025&&px<1100:px>1020&&px<1120;if(needJump&&!jumping){down('jump');jumping=true;}if(!needJump&&jumping){up('jump');jumping=false;}run(1/60);}up(dir);up('jump');assert.ok(Math.abs(snap().player.x-x)<4,`Could not move to ${x}; at ${snap().player.x}`);}
function hold(seconds){down('action');run(seconds);up('action');}
const mobsNear=(x,r)=>snap().mobs.filter(m=>m.hp>0&&m.same!==false&&Math.abs(m.x-x)<r);
// Walk into melee range of the nearest mutant around `x` and keep striking until none are left.
function clearMobs(x,r=260,limit=30){down('attack');for(let i=0;i<limit*60;i++){const list=mobsNear(x,r);if(!list.length)break;const px=snap().player.x,m=list.sort((a,b)=>Math.abs(a.x-px)-Math.abs(b.x-px))[0];const d=m.x-px;
  if(Math.abs(d)>34){padSend('pointerdown',5,200);padSend('pointermove',5,d>0?260:140);}else padSend('pointerup',5,200);run(1/60);}
 padSend('pointerup',5,200);up('attack');assert.equal(mobsNear(x,r).length,0,`Mutants near ${x} must be defeated`);}
function make(id){el('craft-btn').onclick();window.afterfall.pick(id);const button=el('craft-'+id);assert.equal(typeof button.onclick,'function',`Craft button ${id}`);button.onclick();el('resume-btn').onclick();}
el("start-btn").onclick();el("hero-go").onclick();run(1);assert.equal(snap().player.ground,true);
moveTo(520);
// Chopping is a series of strikes: progress moves on each contact and the wood arrives on the last one, once.
{down('action');up('action');run(.2);assert.equal(snap().work.hits,0,'Wind-up before the first contact');run(.12);assert.equal(snap().work.hits,1,'First contact');assert.equal(snap().state.inv.wood,0);
 run(1.2);assert.equal(snap().state.inv.wood,0,'No wood before the last strike');run(.6);assert.equal(snap().state.inv.wood,12);run(2);assert.equal(snap().state.inv.wood,12,'A cut tree gives wood once');
 hold(3);assert.equal(snap().state.inv.wood,12,'The stump left behind cannot be chopped again');}
console.log('PASS: tool work — wind-up, contact, progress per strike, single reward on the last strike, spent object cannot be farmed.');
moveTo(590);hold(2.4);assert.equal(snap().state.inv.stone,10);
moveTo(260);make('bench');assert.equal(snap().state.built.bench,true);
moveTo(800);hold(2.6);moveTo(915);hold(3.4);assert.equal(snap().state.inv.scrap,8);assert.equal(snap().state.inv.fuse,1);
moveTo(690);{const d0=snap().state.inv.dirty;hold(2.6);assert.equal(snap().state.inv.dirty,d0+1,'Holding Use completes one action, not a stream of them');}for(let i=0;i<2;i++)hold(1);assert.ok(snap().state.inv.dirty>=3);
moveTo(260);make('filter');make('generator');assert.equal(snap().state.built.generator,true);
moveTo(1000);const ammo0=snap().state.inv.ammo,hp0=snap().mobs.find(m=>m.role==='guard').hp;down('shoot');up('shoot');run(.8);assert.equal(snap().state.inv.ammo,ammo0-1,'Shot uses a pebble');assert.equal(snap().mobs.find(m=>m.role==='guard').hp,hp0-1,'Pebble hits the mutant');
moveTo(1100);let seen=false;for(let i=0;i<240&&!seen;i++){run(1/60);seen=snap().mobs.some(m=>m.st==='windup');}assert.ok(seen,'Mutant telegraphs before lunging');
const before=snap().state.stats.hp;run(.9);assert.ok(snap().state.stats.hp<before,'Standing in a lunge hurts');
for(let i=0;i<300&&!snap().mobs.some(m=>m.st==='windup');i++)run(1/60);const hpW=snap().mobs.find(m=>m.hp>0).hp;down('attack');up('attack');run(.15);const mw=snap().mobs.find(m=>m.role==='guard');assert.ok(!mw||mw.hp<hpW,'Strike lands');assert.ok(!mw||mw.hp<=0||mw.st==='stagger','Striking a wind-up interrupts it');
clearMobs(1160);
moveTo(1270);hold(3.4);assert.equal(snap().state.vault,true);assert.equal(snap().state.inv.seed,3);
moveTo(260);for(let i=0;i<3;i++){make('water');make('planter');}
for(const x of [410,450,490]){moveTo(x);hold(1.7);}
assert.equal(snap().state.beds.every(Boolean),true);assert.equal(snap().state.completed,false);moveTo(450);down('attack');for(let i=0;i<95*60&&!snap().state.completed;i++)run(1/60);up('attack');assert.equal(snap().state.completed,true);assert.ok(snap().state.defense.hp>0);assert.equal(snap().state.inv.planter,0);assert.ok(Object.values(snap().state.inv).every(n=>n>=0));
console.log('PASS: actual engine pointer controls, resource holds, crafting, generator unlock, jump obstruction both directions, seed rescue, water, 3 planted beds and full 90-second defense.');
console.log('Optimal route play time:',Math.round(snap().state.time),'seconds, excluding reading and menus.');
const saved=Object.values(localStorage.data).map(JSON.parse).find(x=>x.version===3);assert.ok(saved);assert.ok(saved.time>0);
console.log('PASS: progress written to versioned local save.');

for(const fps of [15,30,60,90,120]){moveTo(260);const before=snap().player.x;down('right');for(let i=0;i<fps;i++){clock+=1000/fps;raf(clock);}up('right');assert.ok(Math.abs((snap().player.x-before)-85)<2,`Physics drift at ${fps} FPS`);}
assert.equal(resourceRebuilds,1,'Resource icons were rebuilt during gameplay');
// Jump height does not depend on the frame rate.
{const peaks=[];for(const fps of [30,60,120]){moveTo(260);run(.5);const y0=snap().player.y;let top=y0;down('jump');for(let i=0;i<fps;i++){clock+=1000/fps;raf(clock);top=Math.min(top,snap().player.y);}up('jump');run(.5);peaks.push(y0-top);}
 assert.ok(Math.max(...peaks)-Math.min(...peaks)<1.5,'Jump height at 30/60/120 FPS: '+peaks.map(p=>p.toFixed(1)).join(', '));console.log('PASS: jump height equal at 30/60/120 FPS ('+peaks[0].toFixed(1)+' units).');}
{moveTo(260);const x0=snap().player.x;padSend('pointerdown',4,200);padSend('pointermove',4,240);run(1);padSend('pointerup',4,240);assert.ok(snap().player.x-x0>140,'Thumb at the stick edge runs');console.log('PASS: running when the thumb reaches the edge of the stick.');}
console.log('PASS: consistent movement at 15/30/60/90/120 FPS; hotbar built once, not per frame.');

// Tap-to-harvest survives pointer release, movement cancels it, and independent fingers do not cancel each other.
moveTo(690);let water=snap().state.inv.dirty;down('action');up('action');run(1);assert.equal(snap().state.inv.dirty,water+1);run(1);assert.equal(snap().state.inv.dirty,water+1,'Tap must collect exactly one bottle');
down('action');up('action');down('right');run(.2);up('right');run(1);assert.equal(snap().state.inv.dirty,water+1,'Moving must cancel auto action');
const pad=el('move-pad');const event=(pointerId,clientX)=>({pointerId,clientX,preventDefault(){}});const send=(type,e)=>pad.listeners[type].forEach(f=>f(e));
moveTo(260);const x0=snap().player.x;send('pointerdown',event(7,350));run(.5);send('pointermove',event(7,20));run(.5);send('pointerup',event(8,20));run(.2);assert.ok(snap().player.x<x0-10,'Unrelated finger must not release movement');send('pointercancel',event(7,20));const stopped=snap().player.x;run(.5);assert.equal(snap().player.x,stopped,'Cancellation must stop movement');
// Floating stick: small jitter inside the dead zone keeps a tap action running; reversing works after overshoot.
moveTo(690);water=snap().state.inv.dirty;down('action');up('action');send('pointerdown',event(9,200));send('pointermove',event(9,206));run(1);send('pointerup',event(9,206));assert.equal(snap().state.inv.dirty,water+1,'Resting thumb in dead zone must not cancel tap action');
moveTo(260);let x1=snap().player.x;send('pointerdown',event(10,200));send('pointermove',event(10,400));run(.3);assert.ok(snap().player.x>x1+20);x1=snap().player.x;send('pointermove',event(10,350));run(.3);assert.ok(snap().player.x<x1-20,'Base follows thumb: a 50px pull back after overshoot must reverse');send('pointerup',event(10,350));
window.afterfall.set('swipe',true);run(.5);padSend('pointerdown',11,200,600);padSend('pointermove',11,200,550);run(.1);assert.equal(snap().player.ground,false,'Swipe up must jump when enabled');padSend('pointerup',11,200,550);run(1);assert.equal(snap().player.ground,true);window.afterfall.set('swipe',false);
padSend('pointerdown',12,200,600);padSend('pointermove',12,200,550);run(.1);assert.equal(snap().player.ground,true,'Swipe jump is off by default');padSend('pointerup',12,200,550);
console.log('PASS: tap action, cancel on movement, sliding direction change, independent pointer IDs, pointer cancellation, floating stick dead zone, reversal and optional swipe jump.');
moveTo(1680);hold(3.1);assert.equal(snap().state.inv.scrap,8);moveTo(690);hold(1);hold(1);{const s0=snap().state.inv;moveTo(382);hold(1.6);const s1=snap().state.inv;assert.equal(s1.water,s0.water+1,'Filter in the world purifies water');assert.equal(s1.dirty,s0.dirty-1);console.log('PASS: built water filter works as equipment in the world.');}moveTo(260);make('water');make('purifier');assert.equal(snap().state.built.purifier,true);
moveTo(1810);hold(4.3);moveTo(1990);const hpBefore=snap().state.stats.hp;clearMobs(2150,300,40);console.log('Info: hero health lost to the forest shellback when only striking:',Math.round(hpBefore-snap().state.stats.hp));for(const x of [2040,2260]){moveTo(x);hold(4.3);}
assert.deepEqual(snap().state.forest,[true,true,true]);assert.equal(resourceRebuilds,1);
console.log('PASS: combat — pebble shot, telegraphed lunge, interrupt by strike, combo kills, defense by strikes.');
console.log('PASS: second mission, forest cache, purifier crafting, three cleansing sites, completion.');

// Mission 3: torch, metro, ore on two levels, ladders, the stone armadillo, wire at the workbench, panel repair.
{make('torch');assert.equal(snap().state.built.torch,true);moveTo(1420);hold(.5);assert.equal(snap().state.scene,'mine','Metro stairs lead into the mine');
 const climb=()=>{hold(.4);for(let i=0;i<600&&snap().player.climbing;i++)run(1/60);};
 moveTo(300);hold(2.8);assert.equal(snap().state.inv.ore,2);moveTo(930);climb();assert.equal(snap().player.floor,1,'Ladder leads to the middle level');
// Priority: next to a hostile mutant, Use strikes it instead of mining the ore beside it.
 {moveTo(1150);for(let i=0;i<240&&!snap().danger;i++)run(1/60);assert.ok(snap().danger,'Mutant becomes a threat');const ore0=snap().state.inv.ore,hp0=snap().mobs.find(m=>m.kind==='stoneback').hp;down('action');run(.3);up('action');
  assert.equal(snap().state.inv.ore,ore0,'No mining while a mutant attacks');assert.ok(snap().mobs.find(m=>m.kind==='stoneback').hp<hp0,'Use struck the mutant');console.log('PASS: a dangerous mutant in reach takes priority over gathering.');}
 clearMobs(1080,300,40);moveTo(820);hold(2.8);moveTo(1180);hold(2.8);assert.equal(snap().state.inv.ore,6);
 moveTo(930);climb();assert.equal(snap().player.floor,0);moveTo(74);hold(.5);assert.equal(snap().state.scene,'surface');
 moveTo(260);make('wire');make('wire');assert.equal(snap().state.inv.wire,2);
 moveTo(1420);hold(.5);moveTo(930);climb();moveTo(1330);climb();assert.equal(snap().player.floor,2);clearMobs(1100,400,40);
 moveTo(1240);hold(3);assert.equal(snap().state.mine.panel,true,'Panel repaired with two wires');assert.equal(snap().state.inv.wire,0);assert.equal(quest(snap().state).step,16);
 run(1.5);assert.equal(el('win-dialog').open,true,'Third mission shows its win dialog');el('continue-btn').onclick();
 console.log('PASS: mission 3 — torch, metro door, mine ladders, ore, stone armadillo, wire crafting, panel repair, win dialog.');}
// Mission 4: freight lift, cold without a torch, seed capsules, the crystal deer, the main vault door.
{moveTo(1336);hold(.5);assert.equal(snap().state.scene,'vault','Lift leads to the seed vault');
 window.afterfall.useHot('torch');const hpCold=snap().state.stats.hp;run(3);assert.ok(snap().state.stats.hp<hpCold-1,'Cold drains health without a torch');window.afterfall.useHot('torch');
 moveTo(650);hold(1.7);moveTo(900);hold(1.7);assert.deepEqual(snap().state.seedvault.caps,[true,true,false]);
 moveTo(1370);hold(2.6);assert.equal(snap().state.seedvault.door,false,'Door stays shut while the deer guards it');
 window.afterfall.useHot('medkit');window.afterfall.useHot('food');clearMobs(1180,600,60);assert.equal(snap().state.seedvault.boss,true,'Crystal deer defeated');
 moveTo(1140);hold(1.7);moveTo(1370);hold(2.6);assert.equal(snap().state.seedvault.door,true);assert.equal(quest(snap().state).step,20);
 assert.equal(el('win-dialog').open,true,'Fourth mission shows its win dialog');el('continue-btn').onclick();
 moveTo(90);hold(.5);assert.equal(snap().state.scene,'mine','Lift returns to the mine');assert.equal(snap().player.floor,2);
 // Defeat: freezing without a torch knocks the hero out, then they wake at the shelter with health restored.
 moveTo(1336);hold(.5);window.afterfall.useHot('torch');let wasDown=false;for(let i=0;i<200*60&&snap().state.scene!=='surface';i++){run(1/60);wasDown=wasDown||snap().player.down;}
 assert.ok(wasDown,'Hero falls down at 0 health');assert.equal(snap().state.scene,'surface');assert.equal(snap().state.stats.hp>=79,true);window.afterfall.useHot('torch');
 console.log('PASS: mission 4 — lift to the vault, cold without torch, capsules, crystal deer boss, main door, lift back.');}
globalThis.location={reload(){}};el('reset-yes').onclick();listeners.pagehide();assert.equal(JSON.parse(localStorage.data['afterfall-last-greenhouse-v3']).completed,false);assert.equal(JSON.parse(localStorage.data['afterfall-last-greenhouse-v3']).time,0);console.log('PASS: resetting cannot be overwritten by pagehide autosave.');
{const {exportCode,freshState}=await import('./dist/expedition.mjs');const other=freshState();other.inv.wood=42;other.time=77;
el('import-code').value='garbage';el('import-btn').onclick();assert.equal(el('import-confirm').hidden,true,'Garbage code must not offer import');
el('import-code').value=exportCode(other);el('import-btn').onclick();assert.equal(el('import-confirm').hidden,false);el('import-yes').onclick();listeners.pagehide();
const saved=JSON.parse(localStorage.data['afterfall-last-greenhouse-v3']);assert.equal(saved.inv.wood,42);assert.equal(saved.time,77);
console.log('PASS: progress import through the pause menu, rejected garbage, not overwritten by pagehide autosave.');}
// Atlases built by scripts/import-set22.py: every frame the game asks for exists, has a foot line and stays inside its image.
{const {readFileSync}=await import('node:fs');const size=f=>{const b=readFileSync('dist/assets/'+f);const i=b.indexOf('VP8X');return i>0?[1+b.readUIntLE(i+12,3),1+b.readUIntLE(i+15,3)]:null;};
 const heroes=(await import('./dist/assets/heroes.mjs')).default,mobs=(await import('./dist/assets/mobs-layout.mjs')).default,held=(await import('./dist/assets/held-layout.mjs')).default,props=(await import('./dist/assets/props-layout.mjs')).default;
 for(const [id,h] of Object.entries(heroes)){assert.ok([8,27].includes(h.frames.length),`${id}: 8 or 27 frames`);assert.ok(h.unit>0);const [W,H]=size(`hero-${id}.webp`);
  for(const f of h.frames){assert.ok(f.x+f.w<=W&&f.y+f.h<=H,`${id} frame inside the atlas`);assert.ok(f.foot>0&&f.foot<=f.h+1,`${id} foot line`);}}
 assert.equal(heroes.einstein.frames.length,27,'Einstein has the full move, damage and pickaxe set');
 const [MW,MH]=size('mobs.webp');for(const k of ['crawler','salamander','armadillo','deer']){assert.equal(mobs[k].frames.length,8,k);for(const f of mobs[k].frames)assert.ok(f.x+f.w<=MW&&f.y+f.h<=MH,`${k} frame inside mobs.webp`);}
 for(const k of ['sword','axe','sling','torch','wrench'])assert.ok(held[k]?.len>0,k);
 for(const k of ['stumpCut','oreSpent','crateOpen','soilClean','boulder','rubble','vaultDoor','beam'])assert.ok(props[k],k);
 console.log('PASS: hero, mutant, held-item and object-state atlases complete and in bounds.');}
