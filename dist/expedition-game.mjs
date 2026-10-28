import {SAVE_KEY,LEGACY_KEY,ITEMS,RECIPES,freshState,parseSave,canCraft,craft,plant,quest,exportCode,importCode} from './expedition.mjs?v=5';
import atlasLayout from './assets/atlas-layout.mjs';
import {icon} from './icons.mjs';
import {bakeShellback} from './creatures.mjs';
import {LANGS,t,setLang,getLang,detectLang} from './i18n.mjs';
import {initAudio,sfx,setVolume,setMood,setActive as setAudioActive} from './audio.mjs';
const $=s=>document.querySelector(s),$$=s=>Array.from(document.querySelectorAll(s));
const ids=['world','welcome','start-btn','hp','food','thirst','day','restored','mission-title','mission-desc','waypoint','resource-strip','target-label','action-text','toast','craft-dialog','bag-dialog','pause-dialog','settings-dialog','win-dialog','station-note','recipes','inventory','drink-btn','eat-btn','quest'];
const ui=Object.fromEntries(ids.map(id=>[id,$('#'+id)]));
const setText=(el,value)=>{if(el&&el.textContent!==String(value))el.textContent=value;};
const attr=(el,k,v)=>el?.setAttribute?.(k,v);
$$('[data-icon]').forEach(el=>el.innerHTML=icon(el.dataset.icon));
const tracked=['wood','stone','scrap','cloth','seed'];
ui['resource-strip'].innerHTML=tracked.map(k=>`<span class="res" id="res-${k}">${icon(k)}<b id="count-${k}">0</b></span>`).join('');
const counts=Object.fromEntries(tracked.map(k=>[k,$('#count-'+k)]));
let state;try{state=parseSave(localStorage.getItem(SAVE_KEY)||localStorage.getItem(LEGACY_KEY));}catch{}
const continuing=!!state;state=state||freshState();
const GROUND=320,WORLD=2400,BASE=260,STEP=1/60;
const player={x:state.player.x,y:state.player.y,w:15,h:36,vx:0,vy:0,face:1,ground:false,walk:0,hurt:0,kb:0};
const camera={x:0,y:0};
const canvas=ui.world,ctx=canvas.getContext('2d',{alpha:false});
let VW=480,VH=320,scale=1,started=false,modal=false,visible=!document.hidden;
let now=0,last=0,accum=0,uiClock=0,saveClock=0,toastUntil=0;
let keys={},held={jump:false,action:false,attack:false,shoot:false},jumpLatch=false,interaction={key:'',value:0},effects=[],targetNow=null,dirtyFrame=true;
let frames=0,frameMs=0,telemetryClock=0,winShown=state.completed,assetsReady=false;
const art={},atlases={},rendered={};
let autoAction=false,movePointer=null,moveAxis=0,jumpBuffer=0,coyote=0,saveQueued=false;
let adaptiveScale=1,slowWindows=0,fastWindows=0,ecoFallback=false,rafDelta=1000/60,rafCount=0,worstMs=0,hitches=0,prevX=player.x,prevY=player.y,renderX=player.x,renderY=player.y;
let swing=0,shake=0,hitstop=0,squash=0,floats=[];const nodeShake={};

// ---------- settings ----------
const QUALITY={smooth:{fps:60,area:200000,sharp:.62},eco:{fps:30,area:280000,sharp:.72},detail:{fps:120,area:650000,sharp:1.15}};
const prefs={quality:'smooth',hand:'left',size:'m',actionMode:'tap',swipe:false,vibrate:true,effects:true,hints:true,fps:false,music:.5,sfx:.8,lang:''};
try{const p=JSON.parse(localStorage.getItem('afterfall-controls-v3')||'{}');
 // v0.4 stored a few of these under older names.
 if(p.leftHanded!==undefined&&p.hand===undefined)p.hand=p.leftHanded?'right':'left';if(p.tapAction!==undefined&&p.actionMode===undefined)p.actionMode=p.tapAction===false?'hold':'tap';if(p.swipeJump!==undefined&&p.swipe===undefined)p.swipe=p.swipeJump;
 for(const k of Object.keys(prefs))if(p[k]!==undefined&&typeof p[k]===typeof prefs[k])prefs[k]=p[k];if(!QUALITY[prefs.quality])prefs.quality='smooth';}catch{}
setLang(detectLang(prefs.lang));
function savePrefs(){try{localStorage.setItem('afterfall-controls-v3',JSON.stringify({...prefs,lang:getLang()}));}catch{}}
const SETTERS={
 quality:v=>{prefs.quality=v;adaptiveScale=1;slowWindows=0;ecoFallback=false;resize();},
 hand:v=>{prefs.hand=v;measureControls();},size:v=>{prefs.size=v;measureControls();},actionMode:v=>{prefs.actionMode=v;},
 swipe:v=>{prefs.swipe=!!v;},vibrate:v=>{prefs.vibrate=!!v;if(v)buzz(20);},effects:v=>{prefs.effects=!!v;},hints:v=>{prefs.hints=!!v;},
 fps:v=>{prefs.fps=!!v;hitches=0;worstMs=0;},music:v=>{prefs.music=+v;setVolume('music',prefs.music);},sfx:v=>{prefs.sfx=+v;setVolume('sfx',prefs.sfx);sfx('click');},
 lang:v=>{prefs.lang=setLang(v);applyLanguage();},
};
function setSetting(key,value){if(!SETTERS[key])return;SETTERS[key](value);savePrefs();syncSettings();}
function syncSettings(){const game=$('#game');game.classList.toggle('left-handed',prefs.hand==='right');game.classList.toggle('ctl-s',prefs.size==='s');game.classList.toggle('ctl-l',prefs.size==='l');game.classList.toggle('hide-hints',!prefs.hints);
 const perf=$('#performance');if(perf)perf.hidden=!prefs.fps;
 for(const seg of $$('.seg[data-setting]')){const v=seg.dataset.setting==='lang'?getLang():prefs[seg.dataset.setting];for(const b of seg.querySelectorAll('button'))attr(b,'aria-pressed',String(b.dataset.value===v));}
 for(const tg of $$('.toggle[data-setting]')){const on=!!prefs[tg.dataset.setting];attr(tg,'aria-pressed',String(on));tg.textContent='';attr(tg,'aria-label',t(on?'common.on':'common.off'));}
 for(const r of $$('input[type=range][data-setting]')){r.value=Math.round(prefs[r.dataset.setting]*100);setText($('#'+r.dataset.setting+'-out'),r.value+'%');}}
function buildSettings(){
 for(const seg of $$('.seg[data-setting="lang"]'))seg.innerHTML=Object.entries(LANGS).map(([code,name])=>`<button data-value="${code}" lang="${code}">${seg.classList.contains('small')?code.toUpperCase():name}</button>`).join('');
 for(const seg of $$('.seg[data-setting]'))seg.onclick=e=>{const b=e.target.closest?.('button');if(b)setSetting(seg.dataset.setting,b.dataset.value);};
 for(const tg of $$('.toggle[data-setting]'))tg.onclick=()=>setSetting(tg.dataset.setting,!prefs[tg.dataset.setting]);
 for(const r of $$('input[type=range][data-setting]'))r.oninput=()=>setSetting(r.dataset.setting,r.value/100);
 for(const tab of $$('[role=tab]'))tab.onclick=()=>{for(const x of $$('[role=tab]'))attr(x,'aria-selected',String(x===tab));for(const p of $$('.tab-panel'))p.hidden=p.dataset.panel!==tab.dataset.tab;if(tab.dataset.tab==='progress')prepareTransfer();};}
function buzz(ms){if(!prefs.vibrate||typeof navigator==='undefined'||!navigator.vibrate)return;try{navigator.vibrate(ms);}catch{}}
setVolume('music',prefs.music);setVolume('sfx',prefs.sfx);

// ---------- language ----------
function applyLanguage(){
 for(const el of $$('[data-i18n]'))setText(el,t(el.dataset.i18n));
 for(const el of $$('[data-i18n-aria]'))attr(el,'aria-label',t(el.dataset.i18nAria));
 for(const el of $$('[data-i18n-title]'))attr(el,'title',t(el.dataset.i18nTitle));
 for(const k of tracked)attr($('#res-'+k),'title',t(ITEMS[k]));
 document.title='Afterfall · '+t('title.sub').toLowerCase().replace(/(^|\s)\S/g,c=>c.toUpperCase());
 setText(ui['start-btn'],assetsReady?t(continuing?'menu.continue':'menu.start'):t('menu.loading'));
 if(rendered.world)bakeGate();
 if(ui['craft-dialog']?.open)renderCraft();if(ui['bag-dialog']?.open)renderInventory();if(ui['win-dialog']?.open)fillWin(winStage);
 lastQuestKey='';refreshHud();refreshContext();syncSettings();dirtyFrame=true;}

// ---------- world ----------
const nodes=[
 {id:'logs-a',type:'wood',x:520,time:2.4,art:0,reward:{wood:12}},
 {id:'stone',type:'stone',x:590,time:2.2,art:1,reward:{stone:10}},
 {id:'logs-b',type:'wood',x:800,time:2.4,art:0,reward:{wood:10}},
 {id:'supplies',type:'scrap',x:915,time:3.2,art:2,reward:{scrap:8,cloth:3,fuse:1}},
 {id:'forest-cache',type:'scrap',x:1680,time:2.8,art:2,reward:{scrap:8,cloth:2,stone:3}},
];
const forestPatches=[1810,2040,2260];
const beds=[410,450,490],obstacle={x:1056,y:306,w:32,h:14};
// Enemy archetypes. reach: distance at which they start a lunge; half: half body width for hits.
const KIND={
 crawler:{armored:false,patrol:11,chase:30,lunge:150,reach:30,half:22,height:34,aggro:95,windup:.5,dmg:8,width:54},
 shellback:{armored:true,patrol:9,chase:24,lunge:130,reach:44,half:40,height:52,aggro:125,windup:.62,dmg:14,width:94},
};
let mobs=[],mobSeq=0,forestGuard=false,bittenHint=false;
function makeMob(kind,x,opt={}){return {id:++mobSeq,kind,x,home:x,dir:-1,face:-1,hp:opt.hp||3,max:opt.hp||3,role:opt.role||'guard',min:opt.min??0,max_x:opt.max??WORLD,goal:opt.goal,st:'patrol',t:0,poise:0,flash:0,walk:0,dying:0,kb:0,bite:0,hitPlayer:false};}
mobs.push(makeMob('crawler',1140,{hp:3,min:1100,max:1300}));
const shots=[];const atk={cool:0,combo:0,comboT:0,anim:0,hitDone:true,heavy:false};const sling={cool:0,anim:0};let slash=null;

function active(){return started&&!modal&&visible;}
function nearBase(){return Math.abs(player.x-BASE)<245;}
function toast(text){setText(ui.toast,text);ui.toast.classList.add('show');toastUntil=now+3;}
function save(){if(!started)return;state.player={x:player.x,y:player.y};try{localStorage.setItem(SAVE_KEY,JSON.stringify(state));}catch{}}
function burst(x,y,color,count=10){for(let i=0;i<count&&effects.length<16;i++)effects.push({x,y,vx:(Math.random()-.5)*42,vy:-20-Math.random()*38,life:.7+Math.random()*.3,color});}
const buttonPointers={};
function resetInput(){for(const k of Object.keys(buttonPointers))delete buttonPointers[k];autoAction=false;movePointer=null;moveAxis=0;jumpBuffer=0;jumpLatch=false;restStick();keys={};held={jump:false,action:false,attack:false,shoot:false};interaction={key:'',value:0};$$('.pressed').forEach(e=>e.classList.remove('pressed'));refreshContext();}

// ---------- dialogs ----------
let settingsReturn=false,winStage=1;
function openSheet(id){if(!started&&id!=='settings-dialog')return;modal=true;resetInput();if(id==='craft-dialog')renderCraft();if(id==='bag-dialog')renderInventory();if(id==='settings-dialog')syncSettings();ui[id].showModal();save();dirtyFrame=true;sfx('click');}
function closeSheets(){$$('dialog[open]').forEach(d=>d.close());modal=false;resetInput();dirtyFrame=true;}
$$('dialog .close').forEach(b=>b.onclick=closeSheets);
$$('dialog').forEach(d=>{d.addEventListener('close',()=>{modal=!!$('dialog[open]');resetInput();dirtyFrame=true;if(d.id==='settings-dialog'&&settingsReturn){settingsReturn=false;openSheet('pause-dialog');}});});
$('#craft-btn').onclick=()=>openSheet('craft-dialog');$('#bag-btn').onclick=()=>openSheet('bag-dialog');$('#pause-btn').onclick=()=>openSheet('pause-dialog');$('#resume-btn').onclick=closeSheets;$('#continue-btn').onclick=closeSheets;
$('#pause-settings').onclick=()=>{settingsReturn=true;ui['pause-dialog'].close();openSheet('settings-dialog');};
$('#menu-settings').onclick=()=>{initAudio();openSheet('settings-dialog');};
$('#quest-toggle').onclick=()=>{const c=!ui.quest.classList.contains('collapsed');ui.quest.classList.toggle('collapsed',c);attr($('#quest-toggle'),'aria-expanded',String(!c));questOpenUntil=c?0:now+8;};
// Progress transfer: copy a code here, paste it on another device; the code goes through the same save validator.
let pendingImport=null;const transferNote=k=>setText($('#transfer-note'),k?t(k):'');
function prepareTransfer(){state.player={x:player.x,y:player.y};$('#export-code').value=exportCode(state);transferNote('');}
$('#copy-code').onclick=()=>{const area=$('#export-code'),manual=()=>{area.focus?.();area.select?.();transferNote('transfer.manual');};if(navigator.clipboard?.writeText)navigator.clipboard.writeText(area.value).then(()=>transferNote('transfer.copied'),manual);else manual();};
$('#import-btn').onclick=()=>{pendingImport=importCode($('#import-code').value);if(!pendingImport){$('#import-confirm').hidden=true;transferNote('transfer.bad');return;}const q=quest(pendingImport);setText($('#import-summary'),t('transfer.found',{quest:t(q.title,q.params),time:clock(pendingImport.time)}));$('#import-confirm').hidden=false;transferNote('');};
$('#import-no').onclick=()=>{pendingImport=null;$('#import-confirm').hidden=true;};
$('#import-yes').onclick=()=>{if(!pendingImport)return;started=false;state=pendingImport;try{localStorage.setItem(SAVE_KEY,JSON.stringify(pendingImport));}catch{transferNote('transfer.fail');return;}location.reload();};
function wipe(){started=false;state=freshState();try{localStorage.setItem(SAVE_KEY,JSON.stringify(freshState()));}catch{}location.reload();}
$('#reset-btn').onclick=()=>$('#reset-confirm').hidden=false;$('#reset-no').onclick=()=>$('#reset-confirm').hidden=true;$('#reset-yes').onclick=wipe;
$('#new-btn').onclick=()=>$('#new-confirm').hidden=false;$('#new-no').onclick=()=>$('#new-confirm').hidden=true;$('#new-yes').onclick=wipe;
$('#new-btn').hidden=!continuing;
ui['start-btn'].onclick=()=>{if(!assetsReady)return;initAudio();started=true;ui.welcome.hidden=true;resetInput();sfx('craft');toast(t(continuing?'toast.back':'toast.welcome'));refreshHud();dirtyFrame=true;};
const clock=s=>{s=Math.floor(s);return `${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;};
function recipeIcon(r){if(r.id==='meal')return icon('berry');if(r.id==='ammo')return icon('ammo');return `<span class="atlas-icon atlas-${r.icon}"></span>`;}
function renderCraft(){setText(ui['station-note'],t(nearBase()?'craft.near':'craft.far'));ui.recipes.innerHTML=RECIPES.map(r=>{const reason=canCraft(state,r,nearBase());return `<article class="recipe"><div class="recipe-icon">${recipeIcon(r)}</div><div><h3>${t('recipe.'+r.id)}</h3><p>${t('recipe.'+r.id+'.d')}</p><div class="costs">${Object.entries(r.cost).map(([k,v])=>`<span class="cost ${state.inv[k]<v?'short':''}" title="${t(ITEMS[k])}">${icon(k)}${state.inv[k]}/${v}</span>`).join('')}</div></div><button class="px-btn craft-action ${reason?'':'primary'}" data-craft="${r.id}" ${reason?'disabled':''}>${t(reason||'craft.make')}</button></article>`;}).join('');
 $$('[data-craft]').forEach(b=>b.onclick=()=>{const id=b.dataset.craft;if(!craft(state,id,nearBase()))return;sfx('craft');buzz(10);refreshHud();renderCraft();dirtyFrame=true;toast(t('craft.done.'+id));});}
function renderInventory(){ui.inventory.innerHTML='<div class="inventory-grid">'+Object.entries(ITEMS).map(([k,key])=>`<div class="inv-item ${state.inv[k]?'':'zero'}">${icon(k==='ammo'?'ammo':k)}<b>${state.inv[k]}</b><span>${t(key)}</span></div>`).join('')+'</div>';ui['drink-btn'].disabled=state.inv.water<1;ui['eat-btn'].disabled=state.inv.berry<2;}
ui['drink-btn'].onclick=()=>{if(state.inv.water<1)return;state.inv.water--;state.stats.thirst=Math.min(100,state.stats.thirst+45);sfx('water');renderInventory();refreshHud();toast(t('toast.drink'));};
ui['eat-btn'].onclick=()=>{if(craft(state,'meal')){sfx('gain');renderInventory();refreshHud();toast(t('toast.meal'));}};
function fillWin(stage){winStage=stage;const k='win'+stage;setText($('#win-eyebrow'),t(k+'.eyebrow'));setText($('#win-title'),t(k+'.title'));setText($('#win-text'),t(k+'.text'));setText($('#win-label'),t(k+'.stat'));setText($('#win-note'),t(k+'.note'));setText($('#win-value'),stage===1?clock(state.time):'3 / 3');}
function showWin(stage){fillWin(stage);sfx('win');openSheet('win-dialog');}

// ---------- HUD ----------
let lastQuestKey='',questOpenUntil=0;const lastStat={},lastCount={};
function refreshHud(){
 for(const k of ['hp','food','thirst']){const v=Math.ceil(state.stats[k]);if(lastStat[k]!==v){lastStat[k]=v;setText(ui[k],v);const f=$('#'+k+'-fill');if(f?.style)f.style.transform=`scaleX(${v/100})`;}}
 for(const k of tracked){const v=state.inv[k];if(lastCount[k]!==v){const up=lastCount[k]!==undefined&&v>lastCount[k];lastCount[k]=v;setText(counts[k],v);if(up){const r=$('#res-'+k);r?.classList.remove('bump');void r?.offsetWidth;r?.classList.add('bump');}}}
 setText($('#ammo-count'),state.inv.ammo);$('#shoot')?.classList.toggle('empty',state.inv.ammo<1);
 const q=quest(state);setText(ui['mission-title'],t(q.title,q.params));setText(ui['mission-desc'],t(q.desc,q.params));
 // A new quest step opens the ribbon for a few seconds, then it folds back to one line.
 if(q.title!==lastQuestKey){lastQuestKey=q.title;ui.quest.classList.remove('collapsed');attr($('#quest-toggle'),'aria-expanded','true');questOpenUntil=now+8;}
 else if(questOpenUntil&&now>questOpenUntil&&started){questOpenUntil=0;ui.quest.classList.add('collapsed');attr($('#quest-toggle'),'aria-expanded','false');}
 setText(ui.restored,state.completed?t('hud.forest',{n:state.forest.filter(Boolean).length}):t('hud.greenhouse',{n:state.beds.filter(Boolean).length}));
 setText(ui.day,'⏱ '+clock(state.time));const dx=q.x-player.x;setText(ui.waypoint,Math.abs(dx)<60?'◆ '+t('hud.near'):`${dx>0?'→':'←'} ${t('hud.dist',{n:Math.round(Math.abs(dx)/10)})}`);
 canvas.dataset.stage=q.step;}
function resize(){const r=canvas.getBoundingClientRect();VW=Math.max(320,Math.min(960,r.width/1.65));VH=VW*r.height/r.width;const Q=QUALITY[prefs.quality];const maxArea=Q.area*adaptiveScale;const ratio=Math.min(r.width/VW*Q.sharp,Math.sqrt(maxArea/(VW*VH)));canvas.width=Math.round(VW*ratio);canvas.height=Math.round(VH*ratio);scale=canvas.width/VW;ctx.imageSmoothingEnabled=false;dirtyFrame=true;}
let resizePending=false;window.addEventListener('resize',()=>{if(resizePending)return;resizePending=true;requestAnimationFrame(()=>{resizePending=false;resize();measureControls();});});resize();

// ---------- input ----------
for(const name of ['jump','action','attack','shoot']){const e=$('#'+name);e.addEventListener('pointerdown',ev=>{ev.preventDefault();if(buttonPointers[name]!=null)return;buttonPointers[name]=ev.pointerId;if(e.setPointerCapture)e.setPointerCapture(ev.pointerId);held[name]=true;e.classList.add('pressed');
  if(name==='jump')jumpBuffer=.16;else if(name==='attack')attack();else if(name==='shoot')shoot();
  else if(active()){if(prefs.actionMode==='tap')autoAction=!autoAction;if(!findTarget()){autoAction=false;if(nearestMob(90))toast(t('toast.useAttack'));else if(nearBase()&&!(state.beds.every(Boolean)&&!state.completed))openSheet('craft-dialog');else toast(t('toast.goCloser'));}}});
 const release=ev=>{if(ev.pointerId!==undefined&&ev.pointerId!==buttonPointers[name])return;delete buttonPointers[name];if(ev.type==='pointercancel'&&name==='action')autoAction=false;held[name]=false;e.classList.remove('pressed');};for(const type of ['pointerup','pointercancel','lostpointercapture'])e.addEventListener(type,release);}
// Floating stick: touch anywhere in the movement zone; the base follows the thumb so reversing is instant.
const pad=$('#move-pad'),stick=$('#stick'),thumb=$('#pad-thumb');
let zoneRect={left:0,top:0,width:390,height:380},stickRest={x:90,y:280},stickOrigin={x:0,y:0},swipeJumped=false;
function sizeScale(){return {s:.85,m:1,l:1.18}[prefs.size];}
function placeStick(x,y,knob,on){if(stick.style)stick.style.transform=`translate(${Math.round(x)}px,${Math.round(y)}px)`;if(thumb.style)thumb.style.transform=`translateX(${Math.round(knob)}px)`;stick.classList?.toggle('on',on);}
function restStick(){placeStick(stickRest.x,stickRest.y,0,false);}
function measureControls(){const r=pad.getBoundingClientRect();zoneRect={left:r.left,top:r.top,width:r.width,height:r.height};const k=sizeScale(),inset=Math.max(70*k,Math.min(r.width*.3,120*k));stickRest={x:prefs.hand==='right'?r.width-inset:inset,y:Math.max(60*k,r.height-92*k)};if(movePointer===null)restStick();}
function movePad(ev){if(ev.pointerId!==movePointer)return;const R=40*sizeScale();let dx=ev.clientX-stickOrigin.x;if(Math.abs(dx)>R){stickOrigin.x=ev.clientX-Math.sign(dx)*R;dx=Math.sign(dx)*R;}const dy=(ev.clientY??stickOrigin.y)-stickOrigin.y;moveAxis=Math.abs(dx)<10?0:Math.sign(dx);if(moveAxis)autoAction=false;
 if(prefs.swipe){if(-dy>36&&!swipeJumped){swipeJumped=true;jumpBuffer=.16;}else if(-dy<16)swipeJumped=false;}
 placeStick(stickOrigin.x-zoneRect.left,stickOrigin.y-zoneRect.top,dx,true);}
pad.addEventListener('pointerdown',ev=>{if(!active()||movePointer!==null)return;ev.preventDefault();movePointer=ev.pointerId;if(pad.setPointerCapture)pad.setPointerCapture(ev.pointerId);stickOrigin={x:ev.clientX,y:ev.clientY??0};swipeJumped=false;movePad(ev);});
pad.addEventListener('pointermove',movePad);
for(const event of ['pointerup','pointercancel','lostpointercapture'])pad.addEventListener(event,ev=>{if(ev.pointerId!==movePointer)return;movePointer=null;moveAxis=0;restStick();});
// Long-press on Android would open a context menu and cancel the touch; block it inside the game.
$('#game').addEventListener('contextmenu',ev=>ev.preventDefault());
// Browsers only allow sound after a gesture, so the first touch anywhere unlocks it.
window.addEventListener('pointerdown',()=>initAudio(),{once:true});
const KEYMAP={KeyJ:'attack',KeyF:'attack',KeyK:'shoot',KeyL:'shoot'};
window.addEventListener('keydown',e=>{if(/^(TEXTAREA|INPUT)$/.test(e.target?.tagName||''))return;initAudio();if(['Space','ArrowUp','ArrowLeft','ArrowRight','KeyE','KeyC','KeyI','KeyJ','KeyK'].includes(e.code))e.preventDefault();if(e.repeat)return;if(e.code==='Escape'){modal?closeSheets():openSheet('pause-dialog');return;}if(!started)return;if(e.code==='KeyC'||e.code==='KeyI'){if(modal)closeSheets();else openSheet(e.code==='KeyC'?'craft-dialog':'bag-dialog');return;}
 if(KEYMAP[e.code]){held[KEYMAP[e.code]]=true;KEYMAP[e.code]==='attack'?attack():shoot();return;}keys[e.code]=true;if(['Space','KeyW','ArrowUp'].includes(e.code))jumpBuffer=.16;});
window.addEventListener('keyup',e=>{keys[e.code]=false;if(KEYMAP[e.code])held[KEYMAP[e.code]]=false;});
window.addEventListener('blur',()=>{resetInput();save();});
document.addEventListener('visibilitychange',()=>{visible=!document.hidden;setAudioActive(visible);resetInput();if(!visible)save();last=0;accum=0;dirtyFrame=true;});window.addEventListener('pagehide',()=>save());

// ---------- interactions (Use button) ----------
function findTarget(){const foot=player.y+player.h;if(Math.abs(foot-GROUND)>36)return null;let best=null,bestD=50;
 for(const n of nodes){if(state.harvested[n.id]||(n.x>1600&&!state.completed))continue;const d=Math.abs(n.x-player.x);if(d<bestD){bestD=d;best={kind:'node',node:n,key:n.id,time:n.time,x:n.x,name:'node.'+n.id,verb:n.type==='wood'?'verb.chop':'verb.collect'};}}
 if(Math.abs(player.x-690)<34)best={kind:'river',key:'river',time:.8,x:690,name:'target.river',verb:'verb.fill'};
 if(Math.abs(player.x-1270)<42&&!state.vault)best={kind:'vault',key:'vault',time:3.2,x:1270,name:state.built.generator?'target.vaultOn':'target.vaultOff',verb:'verb.open'};
 for(let i=0;i<3;i++)if(!state.beds[i]&&Math.abs(player.x-beds[i])<23)best={kind:'bed',key:'bed-'+i,index:i,time:1.5,x:beds[i],name:state.inv.planter?'target.bed':'target.bedNoKit',verb:'verb.plant'};
 for(let i=0;i<3;i++)if(state.completed&&!state.forest[i]&&Math.abs(player.x-forestPatches[i])<44)best={kind:'clean',key:'clean-'+i,index:i,time:4,x:forestPatches[i],name:state.built.purifier?'target.clean':'target.cleanNo',verb:'verb.clean'};
 return best;}
function finishAction(tg){if(tg.kind==='node'){const n=tg.node;state.harvested[n.id]=1;for(const[k,v]of Object.entries(n.reward))state.inv[k]+=v;const gain=Object.entries(n.reward).map(([k,v])=>t('toast.gain',{n:v,item:t(ITEMS[k]).toLowerCase()}));toast(gain.join(' · '));floatText(tg.x,GROUND-34,gain[0]);burst(tg.x,GROUND-18,'#e4c38e');sfx('gain');}
 else if(tg.kind==='river'){state.inv.dirty++;toast(t('toast.river',{n:state.inv.dirty}));sfx('water');}
 else if(tg.kind==='vault'){if(!state.built.generator){toast(t('toast.needPower'));held.action=false;autoAction=false;return;}state.vault=true;state.inv.seed+=3;burst(tg.x,GROUND-30,'#c4e39b',18);toast(t('toast.seeds'));sfx('plant');}
 else if(tg.kind==='bed'){if(plant(state,tg.index)){burst(tg.x,GROUND-12,'#bfe49b',18);sfx('plant');toast(t('toast.bed',{n:state.beds.filter(Boolean).length}));}else{toast(t('toast.needKit'));held.action=false;}}
 else if(tg.kind==='clean'){if(!state.built.purifier){toast(t('toast.needPurifier'));autoAction=false;held.action=false;return;}state.forest[tg.index]=true;burst(tg.x,GROUND-22,'#bfe49b',12);sfx('plant');if(state.forest.every(Boolean)){toast(t('toast.forestDone'));showWin(2);}else toast(t('toast.cleaned',{n:state.forest.filter(Boolean).length}));}
 autoAction=false;buzz(12);refreshHud();dirtyFrame=true;}
function swingKind(tg){return tg.kind==='node'&&tg.node.type!=='scrap';}
function impact(tg){if(tg.kind==='node'){nodeShake[tg.node.id]=.16;burst(tg.x-player.face*6,GROUND-14,tg.node.type==='wood'?'#b88a55':tg.node.type==='stone'?'#b3b1a6':'#c9b98d',4);sfx(tg.node.type==='wood'?'chop':'pick');}else burst(tg.x,GROUND-16,tg.kind==='river'?'#9fd6e0':'#c4e39b',2);}
function floatText(x,y,text){if(floats.length>=4)floats.shift();floats.push({x,y,text,life:1.2});}
function overlaps(x,y){return x-player.w/2<obstacle.x+obstacle.w&&x+player.w/2>obstacle.x&&y<obstacle.y+obstacle.h&&y+player.h>obstacle.y;}

// ---------- combat ----------
function liveMobs(){return mobs.filter(m=>m.hp>0);}
function nearestMob(range){let best=null,bd=range;for(const m of mobs){if(m.hp<=0)continue;const d=Math.abs(m.x-player.x);if(d<bd){bd=d;best=m;}}return best;}
// Strike: instant, three-hit combo; the third hit is heavier and knocks back. Turns toward the nearest enemy.
function attack(){if(!active()||atk.cool>0)return;const near=nearestMob(70);if(near)player.face=Math.sign(near.x-player.x)||player.face;atk.combo=atk.comboT>0?atk.combo%3+1:1;atk.heavy=atk.combo===3;atk.anim=.22;atk.hitDone=false;atk.cool=atk.heavy?.42:.26;atk.comboT=.6;autoAction=false;sfx('swing');}
function resolveStrike(){const reach=30;let hits=0;for(const m of mobs){if(m.hp<=0)continue;const P=KIND[m.kind],dx=(m.x-player.x)*player.face;if(dx>-12&&dx<reach+P.half&&player.y+player.h>GROUND-P.height-20){hitMob(m,atk.heavy?2:1,player.face*(atk.heavy?200:90));hits++;}}
 slash={life:.14,face:player.face,x:player.x,y:player.y+player.h-26,heavy:atk.heavy};if(hits)sfx(atk.heavy?'heavy':'hit');}
function shoot(){if(!active()||sling.cool>0)return;if(state.inv.ammo<=0){toast(t('toast.noAmmo'));sfx('click');return;}const near=nearestMob(230);if(near)player.face=Math.sign(near.x-player.x)||player.face;state.inv.ammo--;shots.push({x:player.x+player.face*12,y:player.y+12,vx:player.face*320,vy:-40,life:1.1});sling.cool=.36;sling.anim=.16;autoAction=false;sfx('shoot');refreshHud();}
function hitMob(m,dmg,kb){const P=KIND[m.kind];m.hp-=dmg;m.flash=.12;m.kb=P.armored?kb*.4:kb;hitstop=.045;if(prefs.effects)shake=Math.max(shake,dmg>1?.14:.08);burst(m.x,GROUND-KIND[m.kind].height*.6,'#efe6c4',4);buzz(dmg>1?18:10);
 // Hitting a winding-up mutant interrupts its lunge: the reward for reading the red glow.
 // Poise stops endless stun-locks; armoured shellbacks only flinch from the heavy third hit.
 if(m.poise<=0&&(P.armored?dmg>1:m.st==='windup'||dmg>1)){m.st='stagger';m.t=.45;m.poise=1.4;}
 if(m.hp<=0){m.dying=.9;m.st='dead';sfx('mob');if(m.role==='guard')toast(t(m.kind==='shellback'?'toast.guardDown':'toast.mutantDown'));}}
function hurtPlayer(m){const P=KIND[m.kind];state.stats.hp=Math.max(0,state.stats.hp-P.dmg);player.hurt=1.2;player.kb=(player.x<m.x?-1:1)*160;if(player.ground)player.vy=-80;if(prefs.effects)shake=.12;buzz(45);sfx('hurt');if(!bittenHint){bittenHint=true;toast(t('toast.bitten'));}}
function updateMobs(dt){
 for(const m of mobs){const P=KIND[m.kind];m.flash=Math.max(0,m.flash-dt);m.poise=Math.max(0,m.poise-dt);m.kb=Math.abs(m.kb)<4?0:m.kb*(1-8*dt);m.x+=m.kb*dt;m.x=Math.max(m.min,Math.min(m.max_x,m.x));
  if(m.st==='dead'){m.dying=Math.max(0,m.dying-dt);continue;}
  const dx=player.x-m.x,dist=Math.abs(dx),grounded=player.y+player.h>GROUND-14,inZone=player.x>m.min-20&&player.x<m.max_x+20;
  if(m.st==='patrol'){
   if(m.role==='raider'){m.bite=Math.max(0,m.bite-dt);const goal=m.goal;if(Math.abs(m.x-goal)>3){m.dir=Math.sign(goal-m.x);m.x+=m.dir*24*dt;m.walk+=dt*7;}else if(!m.bite){state.defense.hp-=6;m.bite=2.5;burst(goal,GROUND-15,'#dcaa83',3);sfx('mob');}if(dist<P.reach&&grounded)startWindup(m);}
   else{m.x+=m.dir*P.patrol*dt;m.walk+=dt*6;if(Math.abs(m.x-m.home)>32||m.x<=m.min||m.x>=m.max_x)m.dir*=-1;if(dist<P.aggro&&inZone)m.st='chase';}
   m.face=m.dir;}
  else if(m.st==='chase'){m.dir=Math.sign(dx)||m.dir;m.face=m.dir;if(!inZone){m.st='patrol';}else if(dist>P.reach){m.x+=m.dir*P.chase*dt;m.walk+=dt*8;}else startWindup(m);}
  else if(m.st==='windup'){m.face=Math.sign(dx)||m.face;m.t-=dt;if(m.t<=0){m.st='lunge';m.t=.22;m.dir=m.face;m.hitPlayer=false;}}
  else if(m.st==='lunge'){m.x+=m.dir*P.lunge*dt;m.t-=dt;if(!m.hitPlayer&&!player.hurt&&grounded&&Math.abs(player.x-m.x)<P.half*.6+12){m.hitPlayer=true;hurtPlayer(m);}if(m.t<=0){m.st='recover';m.t=.7;}}
  else if(m.st==='recover'||m.st==='stagger'){m.t-=dt;if(m.t<=0)m.st=m.role==='raider'?'patrol':'chase';}
 }
 mobs=mobs.filter(m=>m.hp>0||m.dying>0);}
function startWindup(m){m.st='windup';m.t=KIND[m.kind].windup;m.face=Math.sign(player.x-m.x)||m.face;sfx('warn');}
function updateShots(dt){for(let i=shots.length-1;i>=0;i--){const s=shots[i];s.vy+=170*dt;s.x+=s.vx*dt;s.y+=s.vy*dt;s.life-=dt;let gone=s.life<=0;
  if(!gone)for(const m of mobs){if(m.hp<=0)continue;const P=KIND[m.kind];if(Math.abs(s.x-m.x)<P.half&&s.y>GROUND-P.height){hitMob(m,1,Math.sign(s.vx)*70);sfx('hit');gone=true;break;}}
  if(!gone&&s.y>=GROUND-1){burst(s.x,GROUND-2,'#9c9378',2);gone=true;}
  if(gone)shots.splice(i,1);}}

// ---------- simulation ----------
function simulate(dt){if(!active())return;if(hitstop>0){hitstop-=dt;return;}shake=Math.max(0,shake-dt);for(const k in nodeShake)nodeShake[k]=Math.max(0,nodeShake[k]-dt);for(let i=floats.length-1;i>=0;i--){floats[i].life-=dt;floats[i].y-=dt*16;if(floats[i].life<=0)floats.splice(i,1);}if(!state.forest.every(Boolean))state.time+=dt;player.hurt=Math.max(0,player.hurt-dt);
 const right=moveAxis>0||keys.KeyD||keys.ArrowRight,left=moveAxis<0||keys.KeyA||keys.ArrowLeft,up=held.jump||keys.Space||keys.KeyW||keys.ArrowUp;
 player.vx=((right?1:0)-(left?1:0))*85;if(atk.anim>0&&player.ground)player.vx*=.35;if(player.vx){player.face=Math.sign(player.vx);player.walk+=dt*9;}else player.walk=0;
 if(player.ground)coyote=.1;else coyote=Math.max(0,coyote-dt);jumpBuffer=Math.max(0,jumpBuffer-dt);if(player.vx)autoAction=false;
 if((jumpBuffer>0||up&&!jumpLatch)&&coyote>0){jumpBuffer=0;coyote=0;player.vy=-230;player.ground=false;squash=-.1;sfx('jump');}jumpLatch=!!up;player.vy=Math.min(300,player.vy+620*dt);
 player.kb=Math.abs(player.kb)<4?0:player.kb*(1-7*dt);const dx=(player.vx+player.kb)*dt;const wasGround=player.ground;if(!overlaps(player.x+dx,player.y))player.x+=dx;player.x=Math.max(24,Math.min(state.completed?WORLD-24:1550,player.x));
 player.ground=false;const nextY=player.y+player.vy*dt;if(player.vy>0&&overlaps(player.x,nextY)&&player.y+player.h<=obstacle.y+2){player.y=obstacle.y-player.h;player.vy=0;player.ground=true;}else player.y=nextY;
 if(player.y+player.h>=GROUND){player.y=GROUND-player.h;player.vy=0;player.ground=true;}else if(player.y+player.h<obstacle.y-1)player.ground=false;
 if(player.ground&&!wasGround&&player.vy===0){squash=.13;burst(player.x,player.y+player.h-1,'#9c9378',3);sfx('land');}squash=Math.abs(squash)<.01?0:squash*(1-12*dt);
 // Combat timers; holding Strike keeps the combo going.
 atk.cool=Math.max(0,atk.cool-dt);atk.comboT=Math.max(0,atk.comboT-dt);sling.cool=Math.max(0,sling.cool-dt);sling.anim=Math.max(0,sling.anim-dt);if(slash){slash.life-=dt;if(slash.life<=0)slash=null;}
 if(atk.anim>0){atk.anim-=dt;if(!atk.hitDone&&atk.anim<=.14){atk.hitDone=true;resolveStrike();}}
 if((held.attack)&&atk.cool<=0)attack();if(held.shoot&&sling.cool<=0&&state.inv.ammo>0)shoot();
 targetNow=atk.anim>0?null:findTarget();const pressing=held.action||keys.KeyE||autoAction;
 if(pressing&&targetNow){if(interaction.key!==targetNow.key){interaction={key:targetNow.key,value:0};swing=0;}interaction.value+=dt;
  // Tool rhythm: raise, then strike; chips fly at the moment of impact.
  const prev=swing,period=swingKind(targetNow)?.5:.8;swing+=dt/period;if(Math.floor(prev-.8)!==Math.floor(swing-.8))impact(targetNow);if(interaction.value>=targetNow.time){finishAction(targetNow);interaction.value=0;}}
 else {interaction={key:'',value:0};swing=0;if(!targetNow)autoAction=false;}
 if(state.completed&&player.x>1600&&!forestGuard){forestGuard=true;mobs.push(makeMob('shellback',2150,{hp:10,min:1960,max:2380}));toast(t('toast.guard'));}
 updateMobs(dt);updateShots(dt);
 if(state.beds.every(Boolean)&&!state.completed){state.defense.time=Math.min(90,state.defense.time+dt);const wave=Math.floor(state.defense.time/15)+1;
  if(wave>state.defense.wave&&wave<=6){state.defense.wave=wave;for(let i=0;i<(wave>3?2:1);i++){const fromLeft=i===1;mobs.push(makeMob('crawler',fromLeft?185:790,{hp:wave===6?5:3,role:'raider',goal:fromLeft?405:490,min:150,max:830}));}toast(wave===1?t('toast.wave1'):t('toast.wave',{n:wave}));}
  if(state.defense.hp<=0){state.defense={time:0,hp:100,wave:0};mobs=mobs.filter(m=>m.role!=='raider');player.x=450;toast(t('toast.defenseFail'));}
  if(state.defense.time>=90){state.completed=true;mobs=mobs.filter(m=>m.role!=='raider');winShown=true;save();setTimeout(()=>showWin(1),1200);}}
 if(state.stats.hp<=0){state.stats.hp=80;player.x=BASE;player.y=GROUND-player.h;player.kb=0;for(const m of mobs)if(m.st!=='dead'&&m.role==='guard'){m.st='patrol';m.x=m.home;}toast(t('toast.respawn'));}
 state.stats.food=Math.max(0,state.stats.food-dt*.018);state.stats.thirst=Math.max(0,state.stats.thirst-dt*.025);if(nearBase())state.stats.hp=Math.min(100,state.stats.hp+dt*.5);
 for(let i=effects.length-1;i>=0;i--){const e=effects[i];e.x+=e.vx*dt;e.y+=e.vy*dt;e.vy+=85*dt;e.life-=dt;if(e.life<=0)effects.splice(i,1);}
 uiClock+=dt;saveClock+=dt;if(uiClock>=.25){refreshHud();refreshContext();setMood(state.beds.every(Boolean)&&!state.completed?'defense':player.x>1600?'forest':'city');uiClock=0;}if(saveClock>15&&!saveQueued){saveClock=0;saveQueued=true;const flush=()=>{saveQueued=false;save();};if(window.requestIdleCallback)window.requestIdleCallback(flush,{timeout:3000});else setTimeout(flush,0);}
}
function refreshContext(){let label=targetNow?t(targetNow.name):'',verb=targetNow?.verb||'verb.act';
 if(!targetNow){if(state.beds.every(Boolean)&&!state.completed)label=t('target.defend');else if(nearestMob(110))label=t('target.enemy');else if(nearBase()){label=t('target.base');verb='verb.craft';}else if(player.x>1000&&player.x<1100)label=t('target.beam');}
 setText(ui['target-label'],label);setText(ui['action-text'],t(autoAction?'verb.stop':verb));$('#action')?.classList.toggle('auto-working',autoAction);}

// ---------- rendering ----------
function loadImage(src){return new Promise((resolve,reject)=>{const i=new Image();i.onload=()=>{if(i.decode)i.decode().catch(()=>{}).then(()=>resolve(i));else resolve(i);};i.onerror=()=>reject(new Error(src));i.src=src;});}
function drawObject(index,x,ground,width=55,flip=false){const a=atlases.objects?.[index];if(!a||x<camera.x-width||x>camera.x+VW+width)return;const h=a.h/a.w*width;ctx.save();ctx.translate(Math.round(x),Math.round(ground));if(flip)ctx.scale(-1,1);ctx.drawImage(art.objects,a.x,a.y,a.w,a.h,-width/2,-h,width,h);ctx.restore();}
function tinted(src,sx,sy,w,h,color){const c=document.createElement('canvas');c.width=w;c.height=h;const g=c.getContext('2d');g.drawImage(src,sx,sy,w,h,0,0,w,h);g.globalCompositeOperation='source-atop';g.fillStyle=color;g.fillRect(0,0,w,h);return c;}
function rect(x,y,w,h,color){ctx.fillStyle=color;ctx.fillRect(Math.round(x),Math.round(y),w,h);}
// One draw routine for every mutant: walk, red wind-up glow with a "!" marker, lunge, hit flash, sinking when beaten.
function drawMob(m){const P=KIND[m.kind];if(m.x<camera.x-P.width||m.x>camera.x+VW+P.width)return;
 const sink=m.st==='dead'?Math.round(P.height*(1-m.dying/.9)):0,wind=m.st==='windup',jit=wind&&Math.floor(now*30)%2?1:0,x=Math.round(m.x)+jit;
 ctx.save();if(sink){ctx.beginPath();ctx.rect(x-P.width,GROUND-P.height-30,P.width*2,P.height+31);ctx.clip();}
 if(m.kind==='shellback'&&rendered.shellback){const sb=rendered.shellback,f=m.flash>0&&prefs.effects?5:m.st==='lunge'?4:m.st==='patrol'||m.st==='chase'?Math.floor(m.walk)%4:0;ctx.translate(x,GROUND+1+sink);ctx.scale(m.face*1.3,1.3);ctx.drawImage(sb.canvas,f*sb.w,0,sb.w,sb.h,-sb.w/2,-sb.h,sb.w,sb.h);if(wind&&rendered.shellRed&&Math.floor(now*10)%2){ctx.globalAlpha=.55;ctx.drawImage(rendered.shellRed,0,0,sb.w,sb.h,-sb.w/2,-sb.h,sb.w,sb.h);}}
 else{const a=atlases.objects?.[7];if(a){const w=m.role==='raider'?48:P.width,h=a.h/a.w*w,lx=m.st==='lunge'?m.dir*3:0;ctx.translate(x+lx,GROUND+sink);if(m.face>0)ctx.scale(-1,1);ctx.drawImage(art.objects,a.x,a.y,a.w,a.h,-w/2,-h,w,h);
  const over=m.flash>0&&prefs.effects?rendered.mobWhite:wind&&Math.floor(now*10)%2?rendered.mobRed:null;if(over){ctx.globalAlpha=.7;ctx.drawImage(over,0,0,a.w,a.h,-w/2,-h,w,h);}}}
 ctx.restore();
 if(wind){const top=GROUND-P.height-16+Math.round(Math.sin(now*20));rect(m.x-2,top-9,4,9,'#ff6b4f');rect(m.x-2,top+2,4,3,'#ff6b4f');}
 if(m.hp>0&&m.hp<m.max){const by=GROUND-P.height-8;rect(m.x-15,by,30,3,'#120d09');rect(m.x-15,by,30*m.hp/m.max,2,m.kind==='shellback'?'#c99ae0':'#e6c48f');}}
function drawHero(){if(player.hurt>0&&Math.floor(now*12)%2===0)return;const working=(held.action||keys.KeyE||autoAction)&&targetNow;
 const frame=!player.ground?7:atk.anim>0?(atk.anim>.14?5:6):sling.anim>0?6:working?(swingKind(targetNow)?(swing%1<.6?5:6):4):player.vx?Math.floor(player.walk)%4:4,a=atlases.hero?.[frame];if(!a)return;
 const k=72/atlases.heroMaxHeight,bob=working&&!swingKind(targetNow)?Math.round(Math.sin(now*9)):0,lunge=atk.anim>0&&atk.anim<=.14?player.face*3:0;ctx.save();ctx.translate(Math.round(renderX)+lunge,Math.round(renderY+player.h)+bob);ctx.scale(player.face*(1+squash*.6),1-squash);ctx.drawImage(art.hero,a.x,a.y,a.w,a.h,-a.anchor*k,-a.h*k,a.w*k,a.h*k);ctx.restore();}
// Pixel slash arc in front of the hero; heavier and wider on the third combo hit.
function drawSlash(){if(!slash)return;const r=slash.heavy?30:24,n=slash.heavy?9:7,p=1-slash.life/.14;for(let i=0;i<n;i++){const a=-1.1+i*(1.9/(n-1)),rr=r+(i%2);const x=slash.x+slash.face*(10+Math.cos(a)*rr),y=slash.y+Math.sin(a)*rr;if(i/n>p+.3)continue;rect(x-1,y-1,3,3,i%3?'#f5ecd0':'#ffffff');}}
const FOREST={x:1600,w:800,ground:.7227*768/724};
function bakeGate(){const gate=document.createElement('canvas');gate.width=300;gate.height=54;const g=gate.getContext('2d');g.fillStyle='#2a1b10';g.fillRect(0,0,300,54);g.fillStyle='#5b3b22';g.fillRect(4,4,292,46);g.fillStyle='#f1e4c3';g.font='600 26px "Pixelify Sans", system-ui';g.textAlign='center';g.fillText(t('gate'),150,36);rendered.gate=gate;dirtyFrame=true;}
function bakeBackground(){const c=document.createElement('canvas');c.width=WORLD;c.height=800;const g=c.getContext('2d');g.imageSmoothingEnabled=true;g.imageSmoothingQuality='high';const h=1600/art.environment.width*art.environment.height;const top=400-h*.78;g.fillStyle='#233d48';g.fillRect(0,0,WORLD,800);g.drawImage(art.environment,0,top,1600,h);
 g.fillStyle='#1d2d3c';g.fillRect(FOREST.x,0,FOREST.w,800);
 rendered.world=c;rendered.top=GROUND-400;rendered.artBottom=GROUND+h*.22;
 if(art.forest)bakeForest();
 const detail=document.createElement('canvas');detail.width=WORLD;detail.height=240;const d=detail.getContext('2d');d.fillStyle='#203036';d.fillRect(0,0,WORLD,240);for(let x=0;x<WORLD;x+=16)for(let y=0;y<240;y+=16){d.fillStyle=(x+y)%48?'#344039':'#3b463b';d.fillRect(x+2,y+3,8,2);d.fillStyle='#17292c';d.fillRect(x,y+15,16,1);}rendered.earth=detail;
 bakeGate();}
// The forest plate is painted into the already baked world once it arrives, so it never blocks the start or costs per-frame work.
function bakeForest(){const g=rendered.world.getContext('2d');g.imageSmoothingEnabled=true;g.imageSmoothingQuality='high';const f=art.forest,fade=64,w=FOREST.w+fade,h=w/f.width*f.height,top=400-h*FOREST.ground;
 // The plate overlaps the city by `fade` units and dissolves into it, so there is no hard seam at x1600.
 const plate=document.createElement('canvas');plate.width=w;plate.height=800;const p=plate.getContext('2d');p.imageSmoothingEnabled=true;p.imageSmoothingQuality='high';const sky=p.createLinearGradient(0,0,0,Math.max(1,top+40));sky.addColorStop(0,'#1d2d3c');sky.addColorStop(1,'#2d3550');p.fillStyle=sky;p.fillRect(0,0,w,top+40);p.drawImage(f,0,top,w,h);
 const mask=p.createLinearGradient(0,0,fade,0);mask.addColorStop(0,'rgba(0,0,0,0)');mask.addColorStop(1,'rgba(0,0,0,1)');p.globalCompositeOperation='destination-in';p.fillStyle=mask;p.fillRect(0,0,w,800);
 g.drawImage(plate,FOREST.x-fade,0);dirtyFrame=true;}
function paint(){ctx.setTransform(scale,0,0,scale,0,0);ctx.imageSmoothingEnabled=false;ctx.fillStyle='#223945';ctx.fillRect(0,0,VW,VH);
 // Camera snaps to device pixels, not world units, so scrolling stays even at any canvas scale.
 const targetX=Math.max(0,Math.min(WORLD-VW,renderX-VW*.42));camera.x=Math.round(targetX*scale)/scale;camera.y=Math.round((GROUND-VH*(VW>VH?.76:.73))*scale)/scale;if(shake>0){const m=shake*14;camera.x+=Math.round((Math.random()-.5)*m*scale)/scale;camera.y+=Math.round((Math.random()-.5)*m*scale)/scale;}
 if(rendered.world){const sx=Math.max(0,Math.floor(camera.x)),sy=Math.max(0,Math.floor(camera.y-rendered.top)),sw=Math.min(Math.ceil(VW)+2,WORLD-sx),sh=Math.min(Math.ceil(VH)+2,800-sy);if(sw>0&&sh>0)ctx.drawImage(rendered.world,sx,sy,sw,sh,sx-camera.x,rendered.top+sy-camera.y,sw,sh);const gy=rendered.artBottom-camera.y;if(gy<VH){const eh=Math.min(240,Math.ceil(VH-gy)+1);if(eh>0&&sw>0)ctx.drawImage(rendered.earth,sx,0,sw,eh,sx-camera.x,gy,sw,eh);}}
 ctx.save();ctx.translate(-camera.x,-camera.y);
 if(!state.completed&&camera.x+VW>1510){rect(1545,GROUND-55,5,55,'#8e7d68');if(rendered.gate){ctx.imageSmoothingEnabled=true;ctx.drawImage(rendered.gate,1495,GROUND-54,100,18);ctx.imageSmoothingEnabled=false;}}
 for(let i=0;i<3;i++){const x=forestPatches[i];if(x<camera.x-90||x>camera.x+VW+90)continue;const clean=state.forest[i];rect(x-47,GROUND-5,94,7,clean?'#779968':'#785983');for(let j=0;j<8;j++){const xx=x-39+j*11,h=12+j%3*7;rect(xx,GROUND-h,3,h,clean?'#98bc7a':'#9774aa');rect(xx-3,GROUND-h,9,4,clean?'#c5df98':'#b090c6');}if(clean)drawObject(6,x+24,GROUND,32);}
 rect(camera.x,GROUND,Math.min(VW,WORLD-camera.x),2,'#8b9668');
 for(const n of nodes){if(n.x<camera.x-70||n.x>camera.x+VW+70||state.harvested[n.id])continue;drawObject(n.art,n.x+(nodeShake[n.id]>0?Math.sin(now*80)*1.6:0),GROUND,n.type==='wood'?64:n.type==='stone'?48:56);}
 if(state.built.bench)drawObject(5,265,GROUND,72);
 if(state.built.filter)drawObject(4,345,GROUND,48);
 if(state.built.generator){rect(300,GROUND-24,16,23,'#495d58');rect(303,GROUND-20,10,5,'#d9bc74');rect(307,GROUND-12,2,7,'#d5e9a7');}
 if(!state.vault){drawObject(3,1270,GROUND,54);rect(1247,GROUND-51,46,2,state.built.generator?'#c3e5a1':'#b99a76');}
 drawObject(0,1072,GROUND,47);
 const grow=state.beds.filter(Boolean).length;
 for(let i=0;i<3;i++){const x=beds[i];rect(x-15,GROUND-4,30,5,'#856443');rect(x-12,GROUND-5,24,2,'#493d2d');if(state.beds[i]){for(let j=0;j<4;j++){const xx=x-10+j*7,height=15+(j%2)*9;rect(xx,GROUND-height,2,height-4,'#93b36e');rect(xx-4,GROUND-height+3,5,3,'#b2ce82');rect(xx+2,GROUND-height-1,5,3,'#c6dda1');rect(xx+1,GROUND-height-4,3,3,j%2?'#dcc17f':'#bccea1');}}}
 for(const m of mobs)drawMob(m);
 if(state.vault)drawObject(6,545+Math.sin(now*.5)*14,GROUND,38,Math.sin(now*.5)<0);
 if(grow>0)for(let i=0;i<grow*2;i++){const x=440+Math.sin(now*.65+i*2)*65,y=GROUND-35+Math.sin(now*1.3+i)*12;rect(x-1,y,2,3,'#e4dcaa');rect(x-5,y-2,4,3,'#a9d9c7');rect(x+1,y-2,4,3,'#c5df9c');}
 drawHero();drawSlash();
 for(const s of shots){rect(s.x-1,s.y-1,3,3,'#d8d2c0');rect(s.x-Math.sign(s.vx)*4,s.y,2,1,'#d8d2c066');}
 for(const e of effects)rect(e.x,e.y,2,2,e.color);
 if(floats.length){ctx.font='600 8px "Pixelify Sans", system-ui';ctx.textAlign='center';for(const f of floats){ctx.globalAlpha=Math.min(1,f.life*2);ctx.fillStyle='#14100c';ctx.fillText(f.text,f.x+.6,f.y+.6);ctx.fillStyle='#f3e3b4';ctx.fillText(f.text,f.x,f.y);}ctx.globalAlpha=1;ctx.textAlign='start';}
 if(targetNow){const tx=targetNow.x,ty=GROUND-74;rect(tx-4,ty+Math.sin(now*2)*2,8,2,'#d9dda6');if(interaction.value>0){rect(tx-24,GROUND-66,48,4,'#14100c');rect(tx-24,GROUND-66,48*Math.min(1,interaction.value/targetNow.time),3,'#9fd36b');}}
 ctx.restore();dirtyFrame=false;}
function loop(timestamp){const t0=performance.now();const raw=last?timestamp-last:1000/60;const elapsed=last?Math.min(.1,raw/1000):STEP;if(last&&raw>4&&raw<40)rafDelta+=(raw-rafDelta)*.05;last=timestamp;now+=elapsed;
 if(active()){if(raw>worstMs)worstMs=raw;if(raw>50)hitches++;accum+=elapsed;let n=0;while(accum>=STEP&&n<6){prevX=player.x;prevY=player.y;simulate(STEP);accum-=STEP;n++;}if(accum>STEP)accum=STEP;}else accum=0;
 // Render between the last two physics steps so motion stays smooth when paint and physics rates differ.
 const alpha=Math.min(1,accum/STEP);renderX=prevX+(player.x-prevX)*alpha;renderY=prevY+(player.y-prevY)*alpha;if(Math.abs(player.x-prevX)>20){renderX=player.x;renderY=player.y;}
 if(toastUntil&&now>toastUntil){ui.toast.classList.remove('show');toastUntil=0;}
 // Paint on every n-th display refresh: 60 Hz→1, 120 Hz→2, so frame pacing stays even instead of alternating.
 const Q=QUALITY[prefs.quality],fps=ecoFallback?Q.fps/2:Q.fps,every=Math.max(1,Math.round(1000/fps/rafDelta));rafCount++;
 if(assetsReady&&visible&&(dirtyFrame||active()&&rafCount>=every)){rafCount=0;paint();frames++;frameMs+=performance.now()-t0;}
 // Telemetry counts only live gameplay: pauses, menus and the start screen must not look like slow frames.
 if(!active()){frames=0;frameMs=0;telemetryClock=0;fastWindows=0;}else telemetryClock+=elapsed;
 if(telemetryClock>=2){const rate=frames/telemetryClock;canvas.dataset.renderFps=Math.round(rate);if(prefs.fps)setText($('#performance'),t('perf',{fps:Math.round(rate),ms:Math.round(worstMs),n:hitches,res:`${canvas.width}×${canvas.height}`})+(ecoFallback?' · auto '+fps:''));
  const goal=Math.min(fps,1000/rafDelta/every);if(rate<goal*.8)slowWindows++;else slowWindows=0;
  if(slowWindows>=2){slowWindows=0;fastWindows=0;if(prefs.quality==='detail'){if(!ecoFallback&&fps>60)ecoFallback=true;}else if(adaptiveScale>.55){adaptiveScale=Math.max(.55,adaptiveScale-.15);resize();}else if(prefs.quality==='smooth'&&!ecoFallback)ecoFallback=true;}
  // Recover sharpness after ~10 s of steady frames, so one bad moment does not leave the picture blurry for good.
  else if(rate>=goal*.95&&worstMs<34){if(++fastWindows>=5){fastWindows=0;if(ecoFallback)ecoFallback=false;else if(adaptiveScale<1){adaptiveScale=Math.min(1,adaptiveScale+.15);resize();}}}else fastWindows=0;
  worstMs=0;frames=0;frameMs=0;telemetryClock=0;}
 requestAnimationFrame(loop);}
async function boot(){try{const loaded=await Promise.all([loadImage('assets/expedition-world.webp'),loadImage('assets/einstein-mobile.webp'),loadImage('assets/objects-mobile.webp')]);[art.environment,art.hero,art.objects]=loaded;atlases.hero=atlasLayout.hero;atlases.objects=atlasLayout.objects;atlases.heroMaxHeight=Math.max(...atlases.hero.map(a=>a.h));bakeBackground();
  try{rendered.shellback=bakeShellback();const sb=rendered.shellback;rendered.shellRed=tinted(sb.canvas,0,0,sb.w,sb.h,'#ff5a3c');const a=atlases.objects[7];rendered.mobWhite=tinted(art.objects,a.x,a.y,a.w,a.h,'#fff6e2');rendered.mobRed=tinted(art.objects,a.x,a.y,a.w,a.h,'#ff5a3c');}catch{}
  assetsReady=true;ui['start-btn'].disabled=false;setText(ui['start-btn'],t(continuing?'menu.continue':'menu.start'));dirtyFrame=true;
  // Repaint the gate sign once the pixel font arrives, and fetch the forest after start-up.
  document.fonts?.ready?.then(()=>bakeGate());loadImage('assets/forest-world.webp').then(img=>{art.forest=img;bakeForest();}).catch(()=>{});}
 catch{setText(ui['start-btn'],t('menu.loadFail'));setText($('.title-hint'),t('menu.loadFailNote'));}}
buildSettings();applyLanguage();syncSettings();measureControls();requestAnimationFrame(loop);if(typeof Image!=='undefined')boot();else{assetsReady=true;ui['start-btn'].disabled=false;}
window.afterfall={snapshot:()=>structuredClone({state,player:{x:player.x,y:player.y,ground:player.ground,face:player.face},mobs:mobs.map(m=>({kind:m.kind,role:m.role,x:m.x,hp:m.hp,st:m.st})),paused:!active(),nearBase:nearBase(),lang:getLang()}),set:setSetting};
