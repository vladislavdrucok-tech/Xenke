import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const elements=new Map(),listeners={};let resourceRebuilds=0;
class El{
 constructor(id=''){this.id=id;this.dataset={};this.listeners={};this.open=false;this._html='';this.textContent='';this.hidden=false;this.style={};this.classes=new Set();this.classList={add:(v)=>this.classes.add(v),remove:(v)=>this.classes.delete(v),contains:(v)=>this.classes.has(v),toggle:(v,on)=>{const yes=on===undefined?!this.classes.has(v):on;yes?this.classes.add(v):this.classes.delete(v);return yes;}};}
 set innerHTML(v){if(this.id==='resource-strip')resourceRebuilds++;this._html=v;for(const match of v.matchAll(/data-craft="(\w+)"/g)){const b=new El('craft-'+match[1]);b.dataset.craft=match[1];elements.set(b.id,b);}}
 get innerHTML(){return this._html;}
 addEventListener(n,f){(this.listeners[n]||=[]).push(f);}
 setPointerCapture(){}
 getBoundingClientRect(){return {width:390,height:844,left:0,top:0,right:390,bottom:844};}
 showModal(){this.open=true;}
 close(){this.open=false;}
}
function el(id){if(!elements.has(id))elements.set(id,new El(id));return elements.get(id);}
const gradient={addColorStop(){}};
const context=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient},{get:(o,k)=>k in o?o[k]:()=>{}});
el('world').getContext=()=>context;
for(const id of ['craft-dialog','bag-dialog','pause-dialog','win-dialog'])el(id);
globalThis.document={hidden:false,querySelector(s){if(s==='dialog[open]')return [...elements.values()].find(e=>e.id.endsWith('-dialog')&&e.open)||null;return el(s.slice(1));},querySelectorAll(s){if(s==='dialog[open]')return [...elements.values()].filter(e=>e.id.endsWith('-dialog')&&e.open);if(s==='dialog')return [...elements.values()].filter(e=>e.id.endsWith('-dialog'));if(s==='[data-craft]')return [...elements.values()].filter(e=>e.dataset.craft);return [];},addEventListener(){}};
globalThis.window={requestIdleCallback:f=>f(),addEventListener(n,f){listeners[n]=f;}};
globalThis.localStorage={data:{},getItem(k){return this.data[k]||null;},setItem(k,v){this.data[k]=v;},removeItem(k){delete this.data[k];}};
let raf;globalThis.requestAnimationFrame=f=>raf=f;
globalThis.setTimeout=()=>1;globalThis.clearTimeout=()=>{};
await import('./dist/expedition-game.mjs');
let clock=0;function run(seconds){for(let i=0;i<Math.ceil(seconds*60);i++){clock+=1000/60;raf(clock);}}
function down(id){for(const f of el(id).listeners.pointerdown||[])f({preventDefault(){},pointerId:1});}
function up(id){for(const f of el(id).listeners.pointerup||[])f({});}
function snap(){return window.afterfall.snapshot();}
function moveTo(x){const sign=Math.sign(x-snap().player.x),dir=sign>0?'right':'left';down(dir);let iterations=0,jumping=false;while(Math.abs(snap().player.x-x)>2&&iterations++<2500){const px=snap().player.x;const needJump=sign>0?px>1025&&px<1100:px>1020&&px<1120;if(needJump&&!jumping){down('jump');jumping=true;}if(!needJump&&jumping){up('jump');jumping=false;}run(1/60);}up(dir);up('jump');assert.ok(Math.abs(snap().player.x-x)<4,`Could not move to ${x}; at ${snap().player.x}`);}
function hold(seconds){down('action');run(seconds);up('action');}
function make(id){el('craft-btn').onclick();const button=el('craft-'+id);assert.equal(typeof button.onclick,'function',`Craft button ${id}`);button.onclick();el('resume-btn').onclick();}
el('start-btn').onclick();run(1);assert.equal(snap().player.ground,true);
moveTo(520);hold(2.6);assert.equal(snap().state.inv.wood,12);
moveTo(590);hold(2.4);assert.equal(snap().state.inv.stone,8);
moveTo(260);make('bench');assert.equal(snap().state.built.bench,true);
moveTo(800);hold(2.6);moveTo(915);hold(3.4);assert.equal(snap().state.inv.scrap,8);assert.equal(snap().state.inv.fuse,1);
moveTo(690);hold(2.6);assert.ok(snap().state.inv.dirty>=3);
moveTo(260);make('filter');make('generator');assert.equal(snap().state.built.generator,true);
moveTo(1270);hold(3.4);assert.equal(snap().state.vault,true);assert.equal(snap().state.inv.seed,3);
moveTo(260);for(let i=0;i<3;i++){make('water');make('planter');}
for(const x of [410,450,490]){moveTo(x);hold(1.7);}
assert.equal(snap().state.beds.every(Boolean),true);assert.equal(snap().state.completed,false);moveTo(450);hold(90.2);assert.equal(snap().state.completed,true);assert.ok(snap().state.defense.hp>0);assert.equal(snap().state.inv.planter,0);assert.ok(Object.values(snap().state.inv).every(n=>n>=0));
console.log('PASS: actual engine pointer controls, resource holds, crafting, generator unlock, jump obstruction both directions, seed rescue, water, 3 planted beds and full 90-second defense.');
console.log('Optimal route play time:',Math.round(snap().state.time),'seconds, excluding reading and menus.');
const saved=Object.values(localStorage.data).map(JSON.parse).find(x=>x.version===3);assert.ok(saved);assert.ok(saved.time>0);
console.log('PASS: progress written to versioned local save.');

for(const fps of [15,30,60]){moveTo(260);const before=snap().player.x;down('right');for(let i=0;i<fps;i++){clock+=1000/fps;raf(clock);}up('right');assert.ok(Math.abs((snap().player.x-before)-85)<2,`Physics drift at ${fps} FPS`);}
assert.equal(resourceRebuilds,1,'Resource icons were rebuilt during gameplay');
console.log('PASS: consistent movement at 15/30/60 FPS; resource HUD built once, not per frame.');

// Tap-to-harvest survives pointer release, movement cancels it, and independent fingers do not cancel each other.
moveTo(690);let water=snap().state.inv.dirty;down('action');up('action');run(1);assert.equal(snap().state.inv.dirty,water+1);run(1);assert.equal(snap().state.inv.dirty,water+1,'Tap must collect exactly one bottle');
down('action');up('action');down('right');run(.2);up('right');run(1);assert.equal(snap().state.inv.dirty,water+1,'Moving must cancel auto action');
const pad=el('move-pad');const event=(pointerId,clientX)=>({pointerId,clientX,preventDefault(){}});const send=(type,e)=>pad.listeners[type].forEach(f=>f(e));
moveTo(260);const x0=snap().player.x;send('pointerdown',event(7,350));run(.5);send('pointermove',event(7,20));run(.5);send('pointerup',event(8,20));run(.2);assert.ok(snap().player.x<x0-10,'Unrelated finger must not release movement');send('pointercancel',event(7,20));const stopped=snap().player.x;run(.5);assert.equal(snap().player.x,stopped,'Cancellation must stop movement');
console.log('PASS: tap action, cancel on movement, sliding direction change, independent pointer IDs, pointer cancellation.');
moveTo(1680);hold(3.1);assert.equal(snap().state.inv.scrap,8);moveTo(690);hold(2);moveTo(260);make('water');make('water');make('purifier');assert.equal(snap().state.built.purifier,true);
for(const x of [1810,2040,2260]){moveTo(x);hold(4.3);}
assert.deepEqual(snap().state.forest,[true,true,true]);assert.equal(resourceRebuilds,1);
console.log('PASS: second mission, forest cache, purifier crafting, three cleansing sites, completion.');

globalThis.location={reload(){}};el('reset-yes').onclick();listeners.pagehide();assert.equal(JSON.parse(localStorage.data['afterfall-last-greenhouse-v3']).completed,false);assert.equal(JSON.parse(localStorage.data['afterfall-last-greenhouse-v3']).time,0);console.log('PASS: resetting cannot be overwritten by pagehide autosave.');
