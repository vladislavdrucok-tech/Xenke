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
globalThis.document={hidden:false,querySelector(s){if(s==='dialog[open]')return [...elements.values()].find(e=>e.id.endsWith('-dialog')&&e.open)||null;return el(s.slice(1));},querySelectorAll(s){if(s==='dialog[open]')return [...elements.values()].filter(e=>e.id.endsWith('-dialog')&&e.open);if(s==='dialog')return [...elements.values()].filter(e=>e.id.endsWith('-dialog'));if(s==='[data-craft]')return [...elements.values()].filter(e=>e.dataset.craft);if(s==='[data-pick]')return [...elements.values()].filter(e=>e.dataset.pick);return [];},addEventListener(n,f){(this.ls||={})[n]=f;}};
globalThis.window={requestIdleCallback:f=>f(),addEventListener(n,f){listeners[n]=f;}};
globalThis.localStorage={data:{},getItem(k){return this.data[k]||null;},setItem(k,v){this.data[k]=v;},removeItem(k){delete this.data[k];}};
let raf;globalThis.requestAnimationFrame=f=>raf=f;
globalThis.setTimeout=()=>1;globalThis.clearTimeout=()=>{};
await import('./dist/expedition-game.mjs');
let clock=0;function run(seconds){for(let i=0;i<Math.ceil(seconds*60);i++){clock+=1000/60;raf(clock);}}
const padSend=(type,pointerId,clientX,clientY=600)=>(el('move-pad').listeners[type]||[]).forEach(f=>f({pointerId,clientX,clientY,preventDefault(){}}));
function down(id){if(id==='left'||id==='right'){padSend('pointerdown',1,200);padSend('pointermove',1,id==='right'?225:175);return;}for(const f of el(id).listeners.pointerdown||[])f({preventDefault(){},pointerId:1});}
function up(id){if(id==='left'||id==='right'){padSend('pointerup',1,200);return;}for(const f of el(id).listeners.pointerup||[])f({});}
const snap=()=>window.afterfall.snapshot(),st=()=>snap().story,inv=()=>snap().state.inv;
function moveTo(x){const sign=Math.sign(x-snap().player.x),dir=sign>0?'right':'left';down(dir);let n=0,jumping=false;while(Math.abs(snap().player.x-x)>2&&n++<3000){const px=snap().player.x;const needJump=snap().state.scene==='surface'&&(sign>0?px>1025&&px<1100:px>1020&&px<1120);if(needJump&&!jumping){down('jump');jumping=true;}if(!needJump&&jumping){up('jump');jumping=false;}run(1/60);}up(dir);up('jump');run(.1);assert.ok(Math.abs(snap().player.x-x)<5,`Could not move to ${x}; at ${snap().player.x}`);}
function press(){down('action');run(.05);up('action');}
function hold(s){down('action');run(s);up('action');}
const saved=()=>parseSave(localStorage.data['afterfall-last-greenhouse-v3']);
const {parseSave,quest,STORY,BUNKER}=await import('./dist/expedition.mjs?v=10');

// Scene 1 — awakening. A new game starts in the bunker with Einstein in the capsule; no hero picker, no fighting buttons.
el('start-btn').onclick();run(.3);
assert.equal(snap().state.scene,'bunker');assert.equal(snap().intro,true,'Capsule cut-scene runs');assert.ok(el('game').classes.has('calm'),'Strike and shoot are hidden in the prologue');
down('left');run(1);up('left');assert.ok(snap().player.x>=BUNKER.capsule-1,'No control while the capsule opens');
run(3);assert.equal(snap().intro,false);assert.equal(st().woke,true);assert.ok(snap().talk,'Mira talks');assert.ok(snap().player.x>BUNKER.capsule+20,'Hero stepped out of the capsule');
// Far from everything the button does nothing to the story.
press();run(.5);assert.equal(st().tool,false);
// The valve needs the wrench: a reason, no progress.
moveTo(BUNKER.valve);assert.equal(snap().target.kind,'valve');assert.equal(snap().target.block,'toast.noTool');hold(2.5);assert.equal(st().hatch,false,'Valve does not open without the wrench');assert.equal(el('toast').textContent.length>0,true);
moveTo(BUNKER.ladder);hold(1);assert.equal(st().out,false,'Hatch shut: the ladder leads nowhere');assert.equal(snap().player.climbing,false);
moveTo(BUNKER.tool);assert.equal(snap().target.kind,'wrench');press();run(.6);assert.equal(st().tool,true);assert.equal(inv().wrench,1);
hold(1);assert.equal(inv().wrench,1,'The wrench is taken once');
moveTo(BUNKER.valve);hold(2.2);assert.equal(st().hatch,true,'Valve turned with the wrench opens the hatch');
{const s=saved();assert.equal(s.scene,'bunker');assert.equal(s.story.hatch,true);assert.equal(quest(s).step,103,'Reload resumes at the ladder');}
moveTo(BUNKER.ladder);press();run(.2);assert.equal(snap().player.climbing,true,'Climbs the ladder');run(4);
console.log('PASS: scene 1 — capsule cut-scene, wrench pickup once, valve blocked without the tool, hatch, ladder out.');

// Scene 2 — the road. Out of the metro; chests open once and stay open; the road is free of mutants.
assert.equal(snap().state.scene,'surface');assert.equal(st().out,true);assert.ok(Math.abs(snap().player.x-1392)<6);assert.equal(snap().mobs.length,0,'No mutants during the prologue');
moveTo(1180);assert.equal(snap().target.kind,'node');assert.equal(snap().target.name,'node.chest-a');press();run(1.4);
assert.equal(snap().state.harvested['chest-a'],1);assert.equal(inv().scrap,3);assert.equal(inv().cloth,1);
hold(2);assert.equal(inv().scrap,3,'An opened chest gives nothing again');assert.equal(saved().harvested['chest-a'],1,'Opened chest is saved');
moveTo(985);press();run(1.4);assert.equal(inv().scrap,5);assert.equal(inv().wood,3);
// Minimising the game while walking: input is released, nothing keeps moving on return.
down('left');run(.3);document.hidden=true;document.ls.visibilitychange();run(.5);document.hidden=false;document.ls.visibilitychange();{const x0=snap().player.x;run(1);assert.ok(Math.abs(snap().player.x-x0)<1,'No stuck movement after returning to the game');}up('left');
console.log('PASS: scene 2 — chests open once (no repeat loot, saved), no mutants on the road, no stuck input after minimising.');

// Scene 3 — the Station. Too few materials first: the workbench refuses, repeated taps change nothing.
moveTo(300);assert.equal(st().station,true,'Arrival at the Station');
moveTo(FILTER());assert.equal(snap().target.block,'toast.needPart');hold(2.5);assert.equal(st().fixed,false,'No repair without the unit');
moveTo(262);assert.equal(snap().target.kind,'bench');press();run(.1);assert.equal(el('craft-dialog').open,true,'The workbench opens the craft sheet');
window.afterfall.pick('repair');for(let i=0;i<3;i++)el('craft-repair').onclick?.();assert.equal(inv().repair,0,'Not enough wood: nothing is made');el('resume-btn').onclick();
moveTo(800);hold(4);assert.ok(inv().wood>=STORY.repairCost.wood,'Chopped the logs');
moveTo(262);press();run(.1);window.afterfall.pick('repair');const before={...inv()};for(let i=0;i<5;i++)el('craft-repair').onclick();
assert.equal(inv().repair,1,'Five taps make one unit');for(const [k,n] of Object.entries(STORY.repairCost))assert.equal(inv()[k],before[k]-n,`${k} spent once`);el('resume-btn').onclick();
moveTo(FILTER());hold(2.4);assert.equal(st().fixed,true);assert.equal(inv().repair,0);
assert.equal(snap().state.built.filter,false,'Fitted but not running yet');hold(1.2);assert.equal(st().water,true);assert.equal(snap().state.built.filter,true,'Water runs: the filter counts as built');
// Losing focus mid-press releases the button.
down('action');listeners.blur();run(1);assert.equal(snap().work.key,'','Blur releases the action button');
moveTo(322);assert.equal(snap().target.kind,'radio');press();run(40);
assert.equal(st().done,true,'Radio message ends the prologue');assert.equal(el('win-dialog').open,true,'End card shown');
{const s=saved();assert.equal(s.story.done,true);assert.equal(s.inv.repair,0);assert.equal(s.harvested['chest-b'],1);assert.equal(s.built.filter,true);assert.equal(quest(s).step,2,'Campaign continues at the generator');}
console.log('PASS: scene 3 — refusal without materials, one unit per five taps, fit + start water, radio, end card, saved and resumes in the campaign.');
function FILTER(){return 382;}
