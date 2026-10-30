import {SAVE_KEY,LEGACY_KEY,ITEMS,RECIPES,HEROES,freshState,newGame,inPrologue,STORY,BUNKER,STATION,CHESTS,parseSave,canCraft,craft,plant,quest,exportCode,importCode} from './expedition.mjs?v=10';
import atlasLayout from './assets/atlas-layout.mjs';
import itemLayout from './assets/items-layout.mjs';
import extraHeroes from './assets/heroes.mjs';
import propLayout from './assets/props-layout.mjs';
import mobLayout from './assets/mobs-layout.mjs';
import heldLayout from './assets/held-layout.mjs';
import {icon} from './icons.mjs';
import {bakeShellback} from './creatures.mjs';
import {LANGS,t,setLang,getLang,detectLang} from './i18n.mjs';
import {initAudio,sfx,setVolume,setMood,setActive as setAudioActive} from './audio.mjs';
const $=s=>document.querySelector(s),$$=s=>Array.from(document.querySelectorAll(s));
const ids=['world','welcome','start-btn','hp','food','thirst','day','restored','mission-title','mission-desc','waypoint','goal-list','hotbar','target-label','action-text','toast','craft-dialog','bag-dialog','pause-dialog','settings-dialog','win-dialog','station-note','recipes','inventory','drink-btn','eat-btn','quest'];
const ui=Object.fromEntries(ids.map(id=>[id,$('#'+id)]));
const setText=(el,value)=>{if(el&&el.textContent!==String(value))el.textContent=value;};
const attr=(el,k,v)=>el?.setAttribute?.(k,v);
$$('[data-icon]').forEach(el=>el.innerHTML=icon(el.dataset.icon));
// Item art comes from items.webp (cut from the owner's concepts); a few items fall back to pixel SVG icons.
const ITEM_ART={wood:'wood',stone:'stone',scrap:'scrap',cloth:'cloth',seed:'seed',dirty:'canteen',water:'bottle',planter:'planter',ore:'ore',wire:'rope',medkit:'medkit',can:'can',ammo:'stone',torch:'torch',
 bench:'workbench',filter:'filter',generator:'generator',purifier:'purifier',crate:'crate',pick:'pickaxe',bag:'bag',capsule:'capsule',flashlight:'flashlight',repair:'gear'};
function itemIcon(id,cls=''){const k=ITEM_ART[id],i=itemLayout.index[k];if(i===undefined)return `<span class="ico svg ${cls}">${icon(id==='meal'?'berry':id)}</span>`;const c=itemLayout.cols,r=itemLayout.rows;return `<span class="ico ${cls}" style="background-position:${(i%c)*100/(c-1)}% ${Math.floor(i/c)*100/(r-1)}%"></span>`;}
let state;try{state=parseSave(localStorage.getItem(SAVE_KEY)||localStorage.getItem(LEGACY_KEY));}catch{}
const continuing=!!state;state=state||newGame();
const GROUND=320,WORLD=2400,BASE=260,STEP=1/60,METRO=1420;
// Hero perks. Only heroes with finished art are selectable; the rest wait for their sprite sheets.
const HERO_ART={einstein:true,...Object.fromEntries(Object.keys(extraHeroes).map(k=>[k,true]))};
let heroLoaded='';
// Every hero's poses live in heroes.mjs (scripts/import-set22.py or import-art.py): unit = walking height in atlas pixels,
// drawn 70 world units tall. 27 frames = moves + damage + pickaxe poses; 8 frames = the older single sheet.
const heroId=id=>extraHeroes[id]?id:'einstein';
function useHero(id,img){const d=extraHeroes[id];art.hero=img;atlases.hero=Array.isArray(d)?d:d.frames;atlases.heroMaxHeight=(d.unit||Math.max(...atlases.hero.map(a=>a.h))*.97)*72/70;for(const k in rendered)if(k.startsWith('hero'))delete rendered[k];heroLoaded=id;}
async function loadHeroArt(id){id=heroId(id);if(heroLoaded===id||typeof Image==='undefined')return;try{useHero(id,await loadImage(`assets/hero-${id}.webp`));}catch{}}
const PERK={einstein:{work:1.2},curie:{clean:2,armor:.85},tesla:{light:1.5,repair:true},darwin:{aggro:.65}};
const perk=(k,d)=>PERK[state.hero]?.[k]??d;
// The mine under the metro: three levels joined by ladders. Coordinates are the mine's own.
// Things you can use on one floor stay apart (ladder 1330, panel 1260, lift 1170), so the action button never offers the wrong one.
const MINEMAP={w:1400,h:900,floors:[{y:300,x1:46,x2:960},{y:560,x1:380,x2:1362},{y:820,x1:700,x2:1362}],
 ladders:[{x:930,a:0,b:1},{x:1330,a:1,b:2}],exit:{x:74,f:0},ore:[{x:300,f:0},{x:820,f:1},{x:1180,f:1}],
 crates:[{x:560,f:0,loot:{can:2,cloth:1}},{x:770,f:2,loot:{medkit:1,scrap:1,ammo:5}}],panel:{x:1260,f:2},lift:{x:1170,f:2},
 lamps:[[150,0],[420,0],[700,0],[520,1],[1000,1],[1240,1],[860,2],[1100,2]]};
const player={x:state.player.x,y:state.player.y,w:15,h:36,vx:0,vy:0,face:1,ground:false,walk:0,hurt:0,kb:0,floor:0,climb:null,hitT:0,getup:0,land:0};
// The seed vault under the institute (mission 4): one hall, capsules on shelves, the crystal deer by the main door.
const VAULT={w:1600,exit:90,caps:[650,900,1140],door:1370,deer:1180};
if(state.scene==='mine'){player.floor=0;player.x=110;player.y=MINEMAP.floors[0].y-player.h;}
if(state.scene==='vault'){player.x=VAULT.exit+40;player.y=GROUND-player.h;}
let torchOn=true,darkHint=false;
const inMine=()=>state.scene==='mine',inVault=()=>state.scene==='vault';let coldHint=false;
const groundY=()=>inMine()?MINEMAP.floors[player.floor].y:GROUND;
const camera={x:0,y:0};
const canvas=ui.world,ctx=canvas.getContext('2d',{alpha:false});
let VW=480,VH=320,scale=1,started=false,modal=false,visible=!document.hidden;
let now=0,last=0,accum=0,uiClock=0,saveClock=0,toastUntil=0;
let keys={},held={jump:false,action:false,attack:false,shoot:false},jumpLatch=false,interaction={key:'',value:0},effects=[],targetNow=null,dirtyFrame=true;
let frames=0,frameMs=0,telemetryClock=0,winShown=state.completed,assetsReady=false;
const art={},atlases={},rendered={};
let autoAction=false,movePointer=null,moveAxis=0,jumpBuffer=0,coyote=0,saveQueued=false;
let adaptiveScale=1,slowWindows=0,fastWindows=0,ecoFallback=false,rafDelta=1000/60,rafCount=0,worstMs=0,hitches=0,prevX=player.x,prevY=player.y,renderX=player.x,renderY=player.y;
let swing=0,hits=0,shake=0,hitstop=0,squash=0,floats=[],actionLatch=false,downTime=0;const nodeShake={};

// ---------- settings ----------
// density: canvas pixels per CSS pixel (capped by the screen's own density); area caps the total for weak GPUs.
const QUALITY={smooth:{fps:60,area:560000,density:1.6},eco:{fps:30,area:300000,density:1},detail:{fps:120,area:1300000,density:2.5}};
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
 document.title='Afterfall · '+t('title.sub').toLowerCase().replace(/(^|\s)\S/g,c=>c.toUpperCase());
 setText(ui['start-btn'],assetsReady?t(continuing?'menu.continue':'menu.start'):t('menu.loading'));
 if(rendered.world)bakeGate();
 buildHotbar();renderHeroes();if(ui['craft-dialog']?.open)renderCraft();if(ui['bag-dialog']?.open)renderInventory();if(ui['win-dialog']?.open)fillWin(winStage);
 lastQuestKey='';refreshHud();refreshContext();syncSettings();dirtyFrame=true;}

// ---------- world ----------
const nodes=[
 {id:'logs-a',type:'wood',x:520,time:2.4,art:0,reward:{wood:12}},
 {id:'stone',type:'stone',x:590,time:2.2,art:1,reward:{stone:10}},
 {id:'logs-b',type:'wood',x:800,time:2.4,art:0,reward:{wood:10}},
 {id:'supplies',type:'scrap',x:915,time:3.2,art:2,reward:{scrap:8,cloth:3,fuse:1}},
 {id:'forest-cache',type:'scrap',x:1680,time:2.8,art:2,reward:{scrap:8,cloth:2,stone:3}},
 // Chests on the road from the metro (prologue): opened once, then they stay open.
 ...CHESTS.map(c=>({id:c.id,type:'scrap',x:c.x,time:.9,art:2,reward:c.loot,chest:true})),
];
const forestPatches=[1810,2040,2260];
const beds=[410,450,490],obstacle={x:1056,y:306,w:32,h:14};
// Enemy archetypes. reach: distance at which they start a lunge; half: half body width for hits.
const KIND={
 crawler:{armored:false,patrol:11,chase:30,lunge:150,reach:30,half:22,height:34,aggro:95,windup:.5,dmg:8,width:54},
 shellback:{armored:true,patrol:9,chase:24,lunge:130,reach:40,half:34,height:42,aggro:125,windup:.62,dmg:14,width:86,sprite:'salamander'},
 stoneback:{armored:true,patrol:8,chase:26,lunge:140,reach:40,half:34,height:42,aggro:115,windup:.58,dmg:12,width:82,sprite:'armadillo'},
 deer:{armored:true,patrol:14,chase:34,lunge:215,reach:64,half:44,height:118,aggro:175,windup:.8,dmg:14,width:112,sprite:'deer',recover:1.3},
};
// Each scene keeps its own mutants; gy is the floor a mutant stands on.
let mobs=[],mobSeq=0,forestGuard=false,bittenHint=false;const sceneMobs={surface:mobs,mine:[]};
function makeMob(kind,x,opt={}){return {id:++mobSeq,kind,x,home:x,gy:opt.gy??GROUND,dir:-1,face:-1,hp:opt.hp||3,max:opt.hp||3,role:opt.role||'guard',min:opt.min??0,max_x:opt.max??WORLD,goal:opt.goal,st:'patrol',t:0,poise:0,flash:0,walk:0,dying:0,kb:0,bite:0,hitPlayer:false};}
// The road is quiet during the prologue; the mutant appears once it is over.
if(!inPrologue(state))mobs.push(makeMob('crawler',1140,{hp:3,min:1100,max:1300}));
function spawnMineMobs(){const F=MINEMAP.floors;return [makeMob('stoneback',1080,{hp:8,gy:F[1].y,min:960,max:1290}),makeMob('crawler',980,{hp:4,gy:F[2].y,min:820,max:1150})];}
// Doors swap the whole scene: player position, mutants, music and lighting.
function spawnVaultMobs(){return state.seedvault.boss?[]:[makeMob('deer',VAULT.deer,{hp:18,min:960,max:1520})];}
// Doors swap the whole scene: player position, mutants, music and lighting.
// Scene art is fetched at start-up; a door waits for it (and pre-tints the scene's sprites) before switching,
// so a large image is never decoded or first-uploaded in the middle of play.
const sceneArt={};let sceneBusy=false;
function goScene(scene){if(sceneBusy)return;const p=sceneArt[scene];if(!p){enterScene(scene);return;}sceneBusy=true;toast(t('toast.loading'));
 p.then(()=>{prewarm(scene==='mine'?'mine':scene==='vault'?'vault':toneAt(METRO));}).catch(()=>{}).finally(()=>{sceneBusy=false;enterScene(scene);});}
const PREWARM={bunker:['crate'],city:['greenhouse','metro','stump','workbench','filter','generator','purifier','crate','fox'],garden:['greenhouse','metro','stump','workbench','filter','generator','purifier','crate','fox'],forest:['fox','crate','stump','purifier','stumpCut','crateOpen','soilClean'],mine:['ore','oreSpent','crate','crateOpen','lift'],vault:['lift']};
for(const k of ['city','garden'])PREWARM[k].push('stumpCut','crateOpen','boulder','rubble','vaultDoor','beam');
// Mutants seen under each light, so their frames are tinted before the first encounter.
const MOBS_AT={city:['crawler'],garden:['crawler'],forest:['salamander','crawler'],mine:['armadillo','crawler'],vault:['deer']};
const SPENT={};
function prewarm(tone){if(!art.props||typeof document==='undefined'||!document.createElement)return;for(const n of PREWARM[tone]||[]){const b=propLayout[n];if(!b)continue;graded(art.props,b.x,b.y,b.w,b.h,n,tone,FAR[n]||0);}
 for(const n of MOBS_AT[tone]||[])if(art.mobs&&mobLayout[n]){mobArt(n,tone);mobTint(n,'#fff6e2');mobTint(n,'#ff5a3c');}
 if(art.hero){graded(art.hero,0,0,art.hero.width,art.hero.height,'hero-'+heroLoaded,tone);heroRed();}
 if(art.mira&&state.story)graded(art.mira,0,0,art.mira.width,art.mira.height,'mira',tone);}
function prewarmLater(tones){const run=()=>{const t0=tones.shift();if(!t0)return;prewarm(t0);if(tones.length)(window.requestIdleCallback||setTimeout)(run,{timeout:2000});};(window.requestIdleCallback||setTimeout)(run,{timeout:2000});}
function enterScene(scene){const prev=state.scene;sceneMobs[prev]=mobs;state.scene=scene;shots.length=0;effects.length=0;player.kb=0;player.vy=0;player.climb=null;player.floor=0;if(state.story)flushTalk();
 if(scene==='mine'){if(prev==='vault'){player.floor=2;player.x=MINEMAP.lift.x+40;}else player.x=110;player.y=MINEMAP.floors[player.floor].y-player.h;mobs=spawnMineMobs();
  if(prev!=='vault'){toast(t('toast.enterMine'));if(!state.built.torch||!torchOn){darkHint=true;setTimeout(()=>toast(t('toast.dark')),1600);}}}
 else if(scene==='vault'){player.x=VAULT.exit+40;player.y=GROUND-player.h;mobs=spawnVaultMobs();coldHint=false;toast(t('toast.enterVault'));if(mobs.length)setTimeout(()=>toast(t('toast.deer')),2200);}
 else if(scene==='bunker'){player.x=BUNKER.capsule;player.y=GROUND-player.h;mobs=[];}
 // Out of the bunker's hatch and up through the metro: the road to the Station starts at the metro entrance.
 else if(prev==='bunker'){player.x=METRO-28;player.face=-1;player.y=GROUND-player.h;mobs=sceneMobs.surface;state.story.out=true;mira.x=METRO+16;sceneTitle(2);say('road');}
 else{player.x=METRO+30;player.y=GROUND-player.h;mobs=sceneMobs.surface;toast(t('toast.surface'));}
 prevX=renderX=player.x;prevY=renderY=player.y;sfx('land');save();refreshHud();dirtyFrame=true;}
if(state.scene==='vault')mobs=spawnVaultMobs();
if(state.scene==='mine')mobs=spawnMineMobs();
const shots=[];const atk={cool:0,combo:0,comboT:0,anim:0,hitDone:true,heavy:false};const sling={cool:0,anim:0};let slash=null;

function active(){return started&&!modal&&visible;}
function nearBase(){return state.scene==='surface'&&Math.abs(player.x-BASE)<245;}
function toast(text){setText(ui.toast,text);ui.toast.classList.add('show');toastUntil=now+3;}
function save(){if(!started)return;state.player={x:player.x,y:player.y};try{localStorage.setItem(SAVE_KEY,JSON.stringify(state));}catch{}}
function burst(x,y,color,count=10){for(let i=0;i<count&&effects.length<16;i++)effects.push({x,y,vx:(Math.random()-.5)*42,vy:-20-Math.random()*38,life:.7+Math.random()*.3,color});}
const buttonPointers={};
function resetInput(){for(const k of Object.keys(buttonPointers))delete buttonPointers[k];autoAction=false;actionLatch=false;movePointer=null;moveAxis=0;jumpBuffer=0;jumpLatch=false;restStick();keys={};held={jump:false,action:false,attack:false,shoot:false};interaction={key:'',value:0};$$('.pressed').forEach(e=>e.classList.remove('pressed'));refreshContext();}

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
function wipe(){started=false;state=newGame();try{localStorage.setItem(SAVE_KEY,JSON.stringify(state));}catch{}location.reload();}
$('#reset-btn').onclick=()=>$('#reset-confirm').hidden=false;$('#reset-no').onclick=()=>$('#reset-confirm').hidden=true;$('#reset-yes').onclick=wipe;
$('#new-btn').onclick=()=>$('#new-confirm').hidden=false;$('#new-no').onclick=()=>$('#new-confirm').hidden=true;$('#new-yes').onclick=wipe;
$('#new-btn').hidden=!continuing;
function beginGame(){started=true;syncCalm();ui.welcome.hidden=true;$('#hero-select').hidden=true;$('#portrait').src=`assets/portrait-${HERO_ART[state.hero]?state.hero:'einstein'}.webp`;resetInput();sfx('craft');if(inPrologue(state))startPrologue();else toast(t(continuing?'toast.back':'toast.welcome'));refreshHud();dirtyFrame=true;}
ui['start-btn'].onclick=()=>{if(!assetsReady)return;initAudio();if(continuing||inPrologue(state))return beginGame();renderHeroes();ui.welcome.hidden=true;$('#hero-select').hidden=false;};
$('#hero-go').onclick=()=>{state.hero=pickedHero;if(typeof Image!=='undefined'&&heroLoaded!==heroId(state.hero))loadHeroArt(state.hero).then(()=>prewarm(toneAt(player.x))).finally(beginGame);else beginGame();};
const clock=s=>{s=Math.floor(s);return `${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;};
// ---------- workbench ----------
let craftCat='build',craftPick=null;
function renderCraft(){const near=nearBase();setText(ui['station-note'],t(near?'craft.near':'craft.far'));
 // During the prologue the workbench offers only the repair unit; afterwards story recipes stay hidden.
 const pro=inPrologue(state);if(pro)craftCat='build';for(const b of $$('#craft-tabs [data-cat]'))b.hidden=pro&&b.dataset.cat!=='build';
 const list=RECIPES.filter(r=>r.cat===craftCat&&(pro?r.story:!r.story||state.built[r.id]));if(!list.some(r=>r.id===craftPick))craftPick=(list.find(r=>!canCraft(state,r,near))||list.find(r=>canCraft(state,r,near)!=='reason.done')||list[0]).id;
 for(const b of $$('#craft-tabs [data-cat]'))attr(b,'aria-selected',String(b.dataset.cat===craftCat));
 $('#craft-badge').innerHTML=itemIcon('bench','big');
 ui.recipes.innerHTML=list.map(r=>{const reason=canCraft(state,r,near);return `<button class="recipe-row ${r.id===craftPick?'sel':''} ${reason==='reason.done'?'done':''} ${reason?'':'ready'}" data-pick="${r.id}">${itemIcon(r.id)}<span>${t('recipe.'+r.id)}</span>${reason==='reason.done'?'<i class="tick">✓</i>':''}</button>`;}).join('');
 const r=RECIPES.find(x=>x.id===craftPick),reason=canCraft(state,r,near);
 $('#recipe-detail').innerHTML=`<h3>${t('recipe.'+r.id)}</h3><div class="detail-main"><div class="detail-art">${itemIcon(r.id,'huge')}</div><div class="needs">${Object.entries(r.cost).map(([k,v])=>`<div class="need ${state.inv[k]>=v?'ok':''}">${itemIcon(k)}<span>${t(ITEMS[k])}</span><b>${state.inv[k]}/${v}</b><i>${state.inv[k]>=v?'✓':'✕'}</i></div>`).join('')}</div></div><p>${t('recipe.'+r.id+'.d')}</p><button class="px-btn gold big craft-action" data-craft="${r.id}" ${reason?'disabled':''}>${t(reason||'craft.make')}</button>`;
 $('#craft-inv').innerHTML=['wood','stone','scrap','cloth','seed','ore','wire','water'].map(k=>`<span class="slot" title="${t(ITEMS[k])}">${itemIcon(k)}<em>${state.inv[k]}</em></span>`).join('');
 $$('[data-pick]').forEach(b=>b.onclick=()=>{craftPick=b.dataset.pick;craftCat=RECIPES.find(r=>r.id===craftPick).cat;sfx('click');renderCraft();});
 $$('[data-craft]').forEach(b=>b.onclick=()=>{const id=b.dataset.craft;if(!craft(state,id,nearBase()))return;sfx('craft');buzz(10);refreshHud();renderCraft();dirtyFrame=true;toast(t('craft.done.'+id));if(id==='repair'){save();say('made');}});}
for(const b of $$('#craft-tabs [data-cat]'))b.onclick=()=>{craftCat=b.dataset.cat;craftPick=null;sfx('click');renderCraft();};
// ---------- hotbar ----------
const HOT=[{id:'torch',art:'torch',label:'hot.torch'},{id:'water',art:'water',label:'hot.water'},{id:'food',art:'can',label:'hot.food'},{id:'medkit',art:'medkit',label:'hot.medkit'},{id:'sling',art:'ammo',label:'hot.sling'}];
function hotCount(id){return id==='torch'?(state.built.torch?'':'–'):id==='water'?state.inv.water:id==='food'?state.inv.can+Math.floor(state.inv.berry/2):id==='medkit'?state.inv.medkit:state.inv.ammo;}
function buildHotbar(){ui.hotbar.innerHTML=HOT.map((h,i)=>`<button class="slot" data-hot="${h.id}" aria-label="${t(h.label)}">${itemIcon(h.art)}<em></em><i>${i+1}</i></button>`).join('');for(const b of $$('[data-hot]'))b.onclick=()=>useHot(b.dataset.hot);lastCount.hot='';refreshHotbar();}
function refreshHotbar(){const key=HOT.map(h=>hotCount(h.id)).join()+torchOn;if(lastCount.hot===key)return;lastCount.hot=key;for(const b of $$('[data-hot]')){const id=b.dataset.hot,c=hotCount(id);setText(b.querySelector?.('em'),c);b.classList?.toggle('empty',id==='torch'?!state.built.torch:!c);b.classList?.toggle('sel',id==='torch'&&state.built.torch&&torchOn);}}
function useHot(id){if(!active())return;initAudio();
 if(id==='torch'){if(!state.built.torch){toast(t('hot.noTorch'));return;}torchOn=!torchOn;toast(t(torchOn?'hot.torchOn':'hot.torchOff'));sfx('click');}
 else if(id==='water'){if(state.inv.water<1)return toast(t('toast.nothing'));state.inv.water--;state.stats.thirst=Math.min(100,state.stats.thirst+45);sfx('water');toast(t('toast.drink'));}
 else if(id==='food'){if(state.inv.can>0){state.inv.can--;state.stats.food=Math.min(100,state.stats.food+40);sfx('gain');toast(t('toast.can'));}else if(!craft(state,'meal'))return toast(t('toast.nothing'));else{sfx('gain');toast(t('toast.meal'));}}
 else if(id==='medkit'){if(state.inv.medkit<1)return toast(t('toast.nothing'));state.inv.medkit--;state.stats.hp=Math.min(100,state.stats.hp+45);sfx('plant');toast(t('toast.medkit'));}
 else if(id==='sling')shoot();
 buzz(8);refreshHud();dirtyFrame=true;}
// ---------- hero select ----------
let pickedHero=state.hero;
function renderHeroes(){const box=$('#hero-cards');if(!box)return;box.innerHTML=HEROES.map(h=>`<button class="hero-card-btn ${HERO_ART[h]?'':'locked'} ${h===pickedHero?'sel':''}" data-hero="${h}" ${HERO_ART[h]?'':'disabled'}><span class="hero-face">${HERO_ART[h]?`<img src="assets/portrait-${h}.webp" alt="">`:`<b>${t('hero.'+h).split(' ').map(w=>w[0]).join('').slice(0,2)}</b>`}</span><strong>${t('hero.'+h)}</strong><small>${t('hero.'+h+'.p')}</small>${HERO_ART[h]?'':`<em>${t('hero.locked')}</em>`}</button>`).join('');
 for(const b of $$('[data-hero]'))b.onclick=()=>{pickedHero=b.dataset.hero;sfx('click');renderHeroes();};}
function renderInventory(){ui.inventory.innerHTML='<div class="inventory-grid">'+Object.entries(ITEMS).map(([k,key])=>`<div class="inv-item ${state.inv[k]?'':'zero'}">${itemIcon(k,'big')}<b>${state.inv[k]}</b><span>${t(key)}</span></div>`).join('')+'</div>';ui['drink-btn'].disabled=state.inv.water<1;ui['eat-btn'].disabled=state.inv.berry<2;}
ui['drink-btn'].onclick=()=>{if(state.inv.water<1)return;state.inv.water--;state.stats.thirst=Math.min(100,state.stats.thirst+45);sfx('water');renderInventory();refreshHud();toast(t('toast.drink'));};
ui['eat-btn'].onclick=()=>{if(craft(state,'meal')){sfx('gain');renderInventory();refreshHud();toast(t('toast.meal'));}};
function fillWin(stage){winStage=stage;const k='win'+stage;setText($('#win-eyebrow'),t(k+'.eyebrow'));setText($('#win-title'),t(k+'.title'));setText($('#win-text'),t(k+'.text'));setText($('#win-label'),t(k+'.stat'));setText($('#win-note'),t(k+'.note'));setText($('#win-value'),stage===1||stage===5?clock(state.time):stage===3?String(state.mine.ore.filter(Boolean).length*2):'3 / 3');}
function showWin(stage){fillWin(stage);sfx('win');openSheet('win-dialog');}

// ---------- HUD ----------
let lastQuestKey='',questOpenUntil=0;const lastStat={},lastCount={};
function refreshHud(){
 for(const k of ['hp','food','thirst']){const v=Math.ceil(state.stats[k]);if(lastStat[k]!==v){lastStat[k]=v;setText(ui[k],v);const f=$('#'+k+'-fill');if(f?.style)f.style.transform=`scaleX(${v/100})`;}}
 setText($('#ammo-count'),state.inv.ammo);$('#shoot')?.classList.toggle('empty',state.inv.ammo<1);
 const q=quest(state);if(q.scene!==state.scene)q.x=inMine()?(q.scene==='vault'?MINEMAP.lift.x:MINEMAP.exit.x):inVault()?VAULT.exit:METRO;setText(ui['mission-title'],t(q.title,q.params));setText(ui['mission-desc'],t(q.desc,q.params));
 // Goal panel: the resources the current step needs, with have/need and a tick once enough.
 const gk=JSON.stringify(q.need)+JSON.stringify(q.need&&Object.keys(q.need).map(k=>state.inv[k]));if(lastCount.goal!==gk){lastCount.goal=gk;ui['goal-list'].innerHTML=q.need?Object.entries(q.need).map(([k,n])=>`<span class="goal ${state.inv[k]>=n?'ok':''}" title="${t(ITEMS[k])}">${itemIcon(k)}<b>${Math.min(state.inv[k],999)}/${n}</b></span>`).join(''):'';}
 refreshHotbar();

 // A new quest step opens the ribbon for a few seconds, then it folds back to one line.
 if(q.title!==lastQuestKey){lastQuestKey=q.title;ui.quest.classList.remove('collapsed');attr($('#quest-toggle'),'aria-expanded','true');questOpenUntil=now+8;}
 else if(questOpenUntil&&now>questOpenUntil&&started){questOpenUntil=0;ui.quest.classList.add('collapsed');attr($('#quest-toggle'),'aria-expanded','false');}
// In the prologue the corner shows which scene you are in instead of the greenhouse counter.
 setText(ui.restored,inPrologue(state)?t('scene.'+(inBunker()?1:state.story.station?3:2)).split(' · ')[0]:state.completed?t('hud.forest',{n:state.forest.filter(Boolean).length}):t('hud.greenhouse',{n:state.beds.filter(Boolean).length}));
 setText(ui.day,'⏱ '+clock(state.time));const dx=q.x-player.x;setText(ui.waypoint,Math.abs(dx)<60?'◆ '+t('hud.near'):`${dx>0?'→':'←'} ${t('hud.dist',{n:Math.round(Math.abs(dx)/10)})}`);
 canvas.dataset.stage=q.step;}
function resize(){const r=canvas.getBoundingClientRect();VW=Math.max(320,Math.min(960,r.width/1.65));VH=VW*r.height/r.width;const Q=QUALITY[prefs.quality],dpr=typeof devicePixelRatio==='number'?devicePixelRatio:1;const maxArea=Q.area*adaptiveScale;const ratio=Math.min(r.width/VW*Math.min(dpr,Q.density),Math.sqrt(maxArea/(VW*VH)));canvas.width=Math.round(VW*ratio);canvas.height=Math.round(VH*ratio);scale=canvas.width/VW;ctx.imageSmoothingEnabled=false;dirtyFrame=true;}
let resizePending=false;window.addEventListener('resize',()=>{if(resizePending)return;resizePending=true;requestAnimationFrame(()=>{resizePending=false;resize();measureControls();});});resize();

// ---------- input ----------
for(const name of ['jump','action','attack','shoot']){const e=$('#'+name);e.addEventListener('pointerdown',ev=>{ev.preventDefault();if(buttonPointers[name]!=null)return;buttonPointers[name]=ev.pointerId;if(e.setPointerCapture)e.setPointerCapture(ev.pointerId);held[name]=true;e.classList.add('pressed');
  if(name==='jump')jumpBuffer=.16;else if(name==='attack')attack();else if(name==='shoot')shoot();
  else actionPress();});
 const release=ev=>{if(ev.pointerId!==undefined&&ev.pointerId!==buttonPointers[name])return;delete buttonPointers[name];if(ev.type==='pointercancel'&&name==='action')autoAction=false;if(name==='action')actionLatch=false;held[name]=false;e.classList.remove('pressed');};for(const type of ['pointerup','pointercancel','lostpointercapture'])e.addEventListener(type,release);}
// The Use button and the E key behave the same: one tap starts the job (tap mode), a hostile mutant in reach is struck instead.
function actionPress(){if(!active())return;if(threat()){autoAction=false;attack();return;}if(prefs.actionMode==='tap')autoAction=!autoAction;if(!findTarget()){autoAction=false;if(nearestMob(90))toast(t('toast.useAttack'));else if(nearBase()&&!inPrologue(state)&&!(state.beds.every(Boolean)&&!state.completed))openSheet('craft-dialog');else toast(t('toast.goCloser'));}}
// Floating stick: touch anywhere in the movement zone; the base follows the thumb so reversing is instant.
const pad=$('#move-pad'),stick=$('#stick'),thumb=$('#pad-thumb');
let zoneRect={left:0,top:0,width:390,height:380},stickRest={x:90,y:280},stickOrigin={x:0,y:0},swipeJumped=false,stickRun=false;
function sizeScale(){return {s:.85,m:1,l:1.18}[prefs.size];}
function placeStick(x,y,knob,on){if(stick.style)stick.style.transform=`translate(${Math.round(x)}px,${Math.round(y)}px)`;if(thumb.style)thumb.style.transform=`translateX(${Math.round(knob)}px)`;stick.classList?.toggle('on',on);}
function restStick(){placeStick(stickRest.x,stickRest.y,0,false);}
function measureControls(){const r=pad.getBoundingClientRect();zoneRect={left:r.left,top:r.top,width:r.width,height:r.height};const k=sizeScale(),inset=Math.max(70*k,Math.min(r.width*.3,120*k));stickRest={x:prefs.hand==='right'?r.width-inset:inset,y:Math.max(60*k,r.height-92*k)};if(movePointer===null)restStick();}
function movePad(ev){if(ev.pointerId!==movePointer)return;const R=40*sizeScale();let dx=ev.clientX-stickOrigin.x;if(Math.abs(dx)>R){stickOrigin.x=ev.clientX-Math.sign(dx)*R;dx=Math.sign(dx)*R;}const dy=(ev.clientY??stickOrigin.y)-stickOrigin.y;moveAxis=Math.abs(dx)<10?0:Math.sign(dx);if(moveAxis)autoAction=false;
 // Pushing the thumb to the edge of the stick switches from walking to running.
 stickRun=Math.abs(dx)>=R*.75;stick.classList?.toggle('run',stickRun);
 if(prefs.swipe){if(-dy>36&&!swipeJumped){swipeJumped=true;jumpBuffer=.16;}else if(-dy<16)swipeJumped=false;}
 placeStick(stickOrigin.x-zoneRect.left,stickOrigin.y-zoneRect.top,dx,true);}
pad.addEventListener('pointerdown',ev=>{if(!active()||movePointer!==null)return;ev.preventDefault();movePointer=ev.pointerId;if(pad.setPointerCapture)pad.setPointerCapture(ev.pointerId);stickOrigin={x:ev.clientX,y:ev.clientY??0};swipeJumped=false;movePad(ev);});
pad.addEventListener('pointermove',movePad);
for(const event of ['pointerup','pointercancel','lostpointercapture'])pad.addEventListener(event,ev=>{if(ev.pointerId!==movePointer)return;movePointer=null;moveAxis=0;stickRun=false;stick.classList?.remove('run');restStick();});
// Long-press on Android would open a context menu and cancel the touch; block it inside the game.
$('#game').addEventListener('contextmenu',ev=>ev.preventDefault());
// Browsers only allow sound after a gesture, so the first touch anywhere unlocks it.
window.addEventListener('pointerdown',()=>initAudio(),{once:true});
const KEYMAP={KeyJ:'attack',KeyF:'attack',KeyK:'shoot',KeyL:'shoot'};
window.addEventListener('keydown',e=>{if(/^(TEXTAREA|INPUT)$/.test(e.target?.tagName||''))return;initAudio();if(['Space','ArrowUp','ArrowLeft','ArrowRight','KeyE','KeyC','KeyI','KeyJ','KeyK'].includes(e.code))e.preventDefault();if(e.repeat)return;if(e.code==='Escape'){modal?closeSheets():openSheet('pause-dialog');return;}if(!started)return;if(e.code==='KeyC'||e.code==='KeyI'){if(modal)closeSheets();else openSheet(e.code==='KeyC'?'craft-dialog':'bag-dialog');return;}
 if(/^Digit[1-5]$/.test(e.code)){useHot(HOT[+e.code.slice(5)-1].id);return;}if(e.code==='KeyE'){actionPress();keys.KeyE=true;return;}if(KEYMAP[e.code]){held[KEYMAP[e.code]]=true;KEYMAP[e.code]==='attack'?attack():shoot();return;}keys[e.code]=true;if(['Space','KeyW','ArrowUp'].includes(e.code))jumpBuffer=.16;});
window.addEventListener('keyup',e=>{keys[e.code]=false;if(e.code==='KeyE')actionLatch=false;if(KEYMAP[e.code])held[KEYMAP[e.code]]=false;});
window.addEventListener('blur',()=>{resetInput();save();});
document.addEventListener('visibilitychange',()=>{visible=!document.hidden;setAudioActive(visible);resetInput();if(!visible)save();last=0;accum=0;dirtyFrame=true;});window.addEventListener('pagehide',()=>save());

// ---------- interactions (Use button) ----------
function findTarget(){if(player.climb)return null;const foot=player.y+player.h;if(Math.abs(foot-groundY())>36)return null;let best=null,bestD=50;const near=(x,r)=>Math.abs(player.x-x)<r;
 if(inBunker())return bunkerTarget();
 if(inMine()){const M=MINEMAP,f=player.floor,mine=state.mine;
  if(f===M.exit.f&&near(M.exit.x,36))best={kind:'door',to:'surface',key:'exit',time:.3,x:M.exit.x,name:'target.exit',verb:'verb.enter'};
  for(const l of M.ladders){if(l.a===f&&near(l.x,24))best={kind:'ladder',to:l.b,key:'ladder-'+l.x,time:.15,x:l.x,name:'target.ladderDown',verb:'verb.climb'};if(l.b===f&&near(l.x,24))best={kind:'ladder',to:l.a,key:'ladder-'+l.x,time:.15,x:l.x,name:'target.ladderUp',verb:'verb.climb'};}
  M.ore.forEach((o,i)=>{if(o.f===f&&!mine.ore[i]&&near(o.x,34))best={kind:'ore',index:i,key:'ore-'+i,time:2.2,x:o.x,name:'target.ore',verb:'verb.mine'};});
  M.crates.forEach((c,i)=>{if(c.f===f&&!mine.crates[i]&&near(c.x,30))best={kind:'crate',index:i,key:'crate-'+i,time:1.4,x:c.x,name:'target.crate',verb:'verb.open2'};});
  if(M.panel.f===f&&!mine.panel&&near(M.panel.x,34))best={kind:'panel',key:'panel',time:perk('repair',false)?.3:2.6,x:M.panel.x,name:state.inv.wire>=2?'target.panelOk':'target.panel',verb:'verb.repair'};
  if(M.lift.f===f&&near(M.lift.x,26))best={kind:'lift',key:'lift',time:.3,x:M.lift.x,name:'target.lift',verb:'verb.enter'};
  return best;}
 if(inVault()){const v=state.seedvault;
  if(near(VAULT.exit,30))best={kind:'door',to:'mine',key:'liftback',time:.3,x:VAULT.exit,name:'target.liftBack',verb:'verb.enter'};
  VAULT.caps.forEach((x,i)=>{if(!v.caps[i]&&near(x,28))best={kind:'capsule',index:i,key:'cap-'+i,time:1.4,x,name:'target.capsule',verb:'verb.take'};});
  if(!v.door&&near(VAULT.door,40))best={kind:'vaultdoor',key:'vaultdoor',time:2.4,x:VAULT.door,name:v.boss&&v.caps.every(Boolean)?'target.vaultDoor':'target.vaultDoorLocked',verb:'verb.open'};
  return best;}
 for(const n of nodes){if(state.harvested[n.id]||(n.x>1600&&!state.completed))continue;const d=Math.abs(n.x-player.x);if(d<bestD){bestD=d;best={kind:'node',node:n,key:n.id,time:n.time,x:n.x,name:'node.'+n.id,verb:n.type==='wood'?'verb.chop':n.type==='scrap'?'verb.open2':'verb.collect',w:n.type==='wood'?50:40,h:n.type==='wood'?42:30};}}
 if(near(690,34))best={kind:'river',key:'river',time:.8,x:690,name:'target.river',verb:'verb.fill'};
 if(inPrologue(state))return stationTargets(best);
 if(state.built.filter&&near(FILTER_X,26))best={kind:'purify',key:'purify',time:1.2,x:FILTER_X,name:state.inv.dirty?'target.filter':'target.filterEmpty',verb:'verb.purify'};
 if(near(1270,42)&&!state.vault)best={kind:'vault',key:'vault',time:3.2,x:1270,name:state.built.generator?'target.vaultOn':'target.vaultOff',verb:'verb.open'};
 if(near(METRO,30))best=state.forest.every(Boolean)?{kind:'door',to:'mine',key:'metro',time:.3,x:METRO,name:'target.metro',verb:'verb.enter'}:{kind:'locked',key:'metro',time:.3,x:METRO,name:'target.metroLocked',verb:'verb.act'};
 for(let i=0;i<3;i++)if(!state.beds[i]&&near(beds[i],23))best={kind:'bed',key:'bed-'+i,index:i,time:1.5,x:beds[i],name:state.inv.planter?'target.bed':'target.bedNoKit',verb:'verb.plant'};
 for(let i=0;i<3;i++)if(state.completed&&!state.forest[i]&&near(forestPatches[i],44))best={kind:'clean',key:'clean-'+i,index:i,time:4/perk('clean',1),x:forestPatches[i],name:state.built.purifier?'target.clean':'target.cleanNo',verb:'verb.clean'};
 return best;}
const gain=(loot)=>Object.entries(loot).map(([k,v])=>t('toast.gain',{n:v,item:t(ITEMS[k]).toLowerCase()}));
function finishAction(tg){const gy=groundY();
 if(state.story&&prologueFinish(tg))return;
 if(tg.kind==='node'){const n=tg.node;state.harvested[n.id]=1;for(const[k,v]of Object.entries(n.reward))state.inv[k]+=v;const g=gain(n.reward);toast(g.join(' · '));floatText(tg.x,gy-34,g[0]);burst(tg.x,gy-18,'#e4c38e');sfx('gain');}
 else if(tg.kind==='river'){state.inv.dirty++;toast(t('toast.river',{n:state.inv.dirty}));floatText(tg.x,gy-40,t('toast.gain',{n:1,item:t(ITEMS.dirty).toLowerCase()}));sfx('water');}
 else if(tg.kind==='purify'){if(!state.inv.dirty){toast(t('toast.filterEmpty'));autoAction=false;return;}state.inv.dirty--;state.inv.water++;floatText(tg.x,gy-56,t('toast.gain',{n:1,item:t(ITEMS.water).toLowerCase()}));burst(tg.x+8,gy-12,'#9fd6e0',6);sfx('water');}
 else if(tg.kind==='vault'){if(!state.built.generator){toast(t('toast.needPower'));held.action=false;autoAction=false;return;}state.vault=true;state.inv.seed+=3;burst(tg.x,gy-30,'#c4e39b',18);toast(t('toast.seeds'));sfx('plant');}
 else if(tg.kind==='bed'){if(plant(state,tg.index)){burst(tg.x,gy-12,'#bfe49b',18);sfx('plant');toast(t('toast.bed',{n:state.beds.filter(Boolean).length}));}else{toast(t('toast.needKit'));held.action=false;}}
 else if(tg.kind==='clean'){if(!state.built.purifier){toast(t('toast.needPurifier'));autoAction=false;held.action=false;return;}state.forest[tg.index]=true;burst(tg.x,gy-22,'#bfe49b',12);sfx('plant');if(state.forest.every(Boolean)){toast(t('toast.forestDone'));showWin(2);}else toast(t('toast.cleaned',{n:state.forest.filter(Boolean).length}));}
 else if(tg.kind==='door'){autoAction=false;held.action=false;actionLatch=true;goScene(tg.to);return;}
 else if(tg.kind==='locked'){toast(t('target.metroLocked'));held.action=false;autoAction=false;return;}
 else if(tg.kind==='ladder'){const M=MINEMAP,to=M.floors[tg.to];player.climb={x:tg.x,from:player.y,to:to.y-player.h,floor:tg.to};player.x=tg.x;held.action=false;autoAction=false;sfx('click');return;}
 else if(tg.kind==='ore'){state.mine.ore[tg.index]=true;state.inv.ore+=2;const g=gain({ore:2});toast(g[0]);floatText(tg.x,gy-40,g[0]);burst(tg.x,gy-20,'#e0802c',10);sfx('gain');}
 else if(tg.kind==='crate'){const loot=MINEMAP.crates[tg.index].loot;state.mine.crates[tg.index]=true;for(const[k,v]of Object.entries(loot))state.inv[k]+=v;toast(t('toast.crate',{items:gain(loot).join(', ')}));burst(tg.x,gy-14,'#c9b98d',8);sfx('gain');}
 else if(tg.kind==='panel'){if(state.inv.wire<2){toast(t('toast.needWire'));held.action=false;autoAction=false;return;}state.inv.wire-=2;state.mine.panel=true;burst(tg.x,gy-30,'#ffe27a',16);sfx('win');toast(t('toast.panel'));save();showWin(3);}
 else if(tg.kind==='lift'){held.action=false;autoAction=false;actionLatch=true;if(!state.mine.panel){toast(t('toast.liftLocked'));return;}goScene('vault');return;}
 else if(tg.kind==='capsule'){state.seedvault.caps[tg.index]=true;state.inv.seed+=2;const n=state.seedvault.caps.filter(Boolean).length;burst(tg.x,gy-30,'#9fe0ff',12);sfx('plant');toast(t('toast.capsule',{n}));floatText(tg.x,gy-44,t('toast.gain',{n:2,item:t(ITEMS.seed).toLowerCase()}));save();}
 else if(tg.kind==='vaultdoor'){const v=state.seedvault;if(!v.boss||!v.caps.every(Boolean)){toast(t('toast.doorLocked'));held.action=false;autoAction=false;return;}v.door=true;state.inv.seed+=10;burst(tg.x,gy-50,'#c8f0ff',18);sfx('win');save();showWin(4);}
 // Saved right away: a reload can never grant the same loot twice or lose it.
 autoAction=false;buzz(12);save();refreshHud();dirtyFrame=true;}
let lockedTarget=null;
function stillValid(tg){if(Math.abs(player.x-tg.x)>60||player.climb)return false;const m=state.mine;switch(tg.kind){case 'node':return !state.harvested[tg.node.id];case 'ore':return !m.ore[tg.index];case 'crate':return !m.crates[tg.index];case 'bed':return !state.beds[tg.index];case 'clean':return !state.forest[tg.index];case 'capsule':return !state.seedvault.caps[tg.index];default:return true;}}
function swingKind(tg){return tg.kind==='ore'||tg.kind==='node'&&tg.node.type!=='scrap';}
// Swing cycle (seconds) and the phase at which the tool touches the target.
const SWING=.62,CONTACT=.5;
function strikesFor(tg){return tg.kind==='ore'?4:tg.node?.type==='stone'?4:4;}
function impact(tg){const gy=groundY();if(tg.kind==='ore'){nodeShake[tg.key]=.16;burst(tg.x-player.face*6,gy-14,'#e0802c',4);sfx('pick');}else if(tg.kind==='node'){nodeShake[tg.node.id]=.16;burst(tg.x-player.face*6,gy-14,tg.node.type==='wood'?'#b88a55':tg.node.type==='stone'?'#b3b1a6':'#c9b98d',4);sfx(tg.node.type==='wood'?'chop':'pick');}else burst(tg.x,gy-16,tg.kind==='river'?'#9fd6e0':'#c4e39b',2);}
function floatText(x,y,text){if(floats.length>=4)floats.shift();floats.push({x,y,text,life:1.2});}
function overlaps(x,y){return x-player.w/2<obstacle.x+obstacle.w&&x+player.w/2>obstacle.x&&y<obstacle.y+obstacle.h&&y+player.h>obstacle.y;}

// ---------- combat ----------
function liveMobs(){return mobs.filter(m=>m.hp>0);}
// A mutant that is close and hostile takes priority over gathering: the Use button strikes it instead.
function threat(){const m=nearestMob(62);return m&&(m.st!=='patrol'||m.role==='raider'||Math.abs(m.x-player.x)<44)?m:null;}
const sameFloor=m=>Math.abs(m.gy-groundY())<4;
function nearestMob(range){let best=null,bd=range;for(const m of mobs){if(m.hp<=0||!sameFloor(m))continue;const d=Math.abs(m.x-player.x);if(d<bd){bd=d;best=m;}}return best;}
// Strike: instant, three-hit combo; the third hit is heavier and knocks back. Turns toward the nearest enemy.
function attack(){if(!active()||atk.cool>0)return;const near=nearestMob(70);if(near)player.face=Math.sign(near.x-player.x)||player.face;atk.combo=atk.comboT>0?atk.combo%3+1:1;atk.heavy=atk.combo===3;atk.anim=.22;atk.hitDone=false;atk.cool=atk.heavy?.42:.26;atk.comboT=.6;autoAction=false;sfx('swing');}
function resolveStrike(){const reach=30;let hits=0;for(const m of mobs){if(m.hp<=0)continue;const P=KIND[m.kind],dx=(m.x-player.x)*player.face;if(sameFloor(m)&&dx>-12&&dx<reach+P.half&&player.y+player.h>m.gy-P.height-20){hitMob(m,atk.heavy?2:1,player.face*(atk.heavy?200:90));hits++;}}
 slash={life:.14,face:player.face,x:player.x,y:player.y+player.h-26,heavy:atk.heavy};if(hits)sfx(atk.heavy?'heavy':'hit');}
function shoot(){if(!active()||sling.cool>0)return;if(state.inv.ammo<=0){toast(t('toast.noAmmo'));sfx('click');return;}const near=nearestMob(230);if(near)player.face=Math.sign(near.x-player.x)||player.face;state.inv.ammo--;shots.push({x:player.x+player.face*12,y:player.y+12,vx:player.face*320,vy:-40,life:1.1,gy:groundY()});sling.cool=.36;sling.anim=.16;autoAction=false;sfx('shoot');refreshHud();}
function hitMob(m,dmg,kb){const P=KIND[m.kind];m.hp-=dmg;m.flash=.12;m.kb=P.armored?kb*.4:kb;hitstop=.045;if(prefs.effects)shake=Math.max(shake,dmg>1?.14:.08);burst(m.x,m.gy-KIND[m.kind].height*.6,'#efe6c4',4);buzz(dmg>1?18:10);
 // Hitting a winding-up mutant interrupts its lunge: the reward for reading the red glow.
 // Poise stops endless stun-locks; armoured shellbacks only flinch from the heavy third hit.
 if(m.poise<=0&&(P.armored?dmg>1:m.st==='windup'||dmg>1)){m.st='stagger';m.t=.45;m.poise=1.4;}
 if(m.hp<=0){m.dying=.9;m.st='dead';sfx('mob');if(m.kind==='deer'){state.seedvault.boss=true;save();toast(t('toast.deerDown'));refreshHud();return;}if(m.role==='guard')toast(t(m.kind==='crawler'?'toast.mutantDown':'toast.guardDown'));}}
function hurtPlayer(m){if(downTime)return;const P=KIND[m.kind];state.stats.hp=Math.max(0,state.stats.hp-P.dmg*perk('armor',1));player.hurt=1.2;player.hitT=.28;player.kb=(player.x<m.x?-1:1)*160;if(player.ground)player.vy=-80;if(prefs.effects)shake=.12;buzz(45);sfx('hurt');if(!bittenHint){bittenHint=true;toast(t('toast.bitten'));}}
function updateMobs(dt){
 for(const m of mobs){const P=KIND[m.kind];m.flash=Math.max(0,m.flash-dt);m.poise=Math.max(0,m.poise-dt);m.kb=Math.abs(m.kb)<4?0:m.kb*(1-8*dt);m.x+=m.kb*dt;m.x=Math.max(m.min,Math.min(m.max_x,m.x));
  if(m.st==='dead'){m.dying=Math.max(0,m.dying-dt);continue;}
  const dx=player.x-m.x,dist=sameFloor(m)&&!player.climb?Math.abs(dx):1e4,grounded=player.y+player.h>m.gy-14,inZone=dist<1e4&&player.x>m.min-20&&player.x<m.max_x+20;
  if(m.st==='patrol'){
   if(m.role==='raider'){m.bite=Math.max(0,m.bite-dt);const goal=m.goal;if(Math.abs(m.x-goal)>3){m.dir=Math.sign(goal-m.x);m.x+=m.dir*24*dt;m.walk+=dt*7;}else if(!m.bite){state.defense.hp-=6;m.bite=2.5;burst(goal,m.gy-15,'#dcaa83',3);sfx('mob');}if(dist<P.reach&&grounded)startWindup(m);}
   else{m.x+=m.dir*P.patrol*dt;m.walk+=dt*6;if(Math.abs(m.x-m.home)>32||m.x<=m.min||m.x>=m.max_x)m.dir*=-1;if(dist<P.aggro*perk('aggro',1)&&inZone)m.st='chase';}
   m.face=m.dir;}
  else if(m.st==='chase'){m.dir=Math.sign(dx)||m.dir;m.face=m.dir;if(!inZone){m.st='patrol';}else if(dist>P.reach){m.x+=m.dir*P.chase*dt;m.walk+=dt*8;}else startWindup(m);}
  else if(m.st==='windup'){m.face=Math.sign(dx)||m.face;m.t-=dt;if(m.t<=0){m.st='lunge';m.t=.22;m.dir=m.face;m.hitPlayer=false;}}
  else if(m.st==='lunge'){m.x+=m.dir*P.lunge*dt;m.t-=dt;if(!m.hitPlayer&&!player.hurt&&grounded&&dist<1e4&&Math.abs(player.x-m.x)<P.half*.6+12){m.hitPlayer=true;hurtPlayer(m);}if(m.t<=0){m.st='recover';m.t=P.recover||.7;}}
  else if(m.st==='recover'||m.st==='stagger'){m.t-=dt;if(m.t<=0)m.st=m.role==='raider'?'patrol':'chase';}
 }
 mobs=mobs.filter(m=>m.hp>0||m.dying>0);}
function startWindup(m){m.st='windup';m.t=KIND[m.kind].windup;m.face=Math.sign(player.x-m.x)||m.face;sfx('warn');}
function updateShots(dt){for(let i=shots.length-1;i>=0;i--){const s=shots[i];s.vy+=170*dt;s.x+=s.vx*dt;s.y+=s.vy*dt;s.life-=dt;let gone=s.life<=0;
  if(!gone)for(const m of mobs){if(m.hp<=0)continue;const P=KIND[m.kind];if(Math.abs(m.gy-s.gy)<4&&Math.abs(s.x-m.x)<P.half&&s.y>m.gy-P.height){hitMob(m,1,Math.sign(s.vx)*70);sfx('hit');gone=true;break;}}
  if(!gone&&s.y>=s.gy-1){burst(s.x,s.gy-2,'#9c9378',2);gone=true;}
  if(gone)shots.splice(i,1);}}

// ---------- simulation ----------
function respawn(){state.stats.hp=80;if(inMine()||inVault())enterScene('surface');player.x=BASE;player.y=GROUND-player.h;player.kb=0;player.vy=0;prevX=renderX=player.x;for(const m of mobs)if(m.st!=='dead'&&m.role==='guard'){m.st='patrol';m.x=m.home;}player.hurt=1.5;player.getup=.5;player.hitT=0;toast(t('toast.respawn'));}
function simulate(dt){if(!active())return;if(hitstop>0){hitstop-=dt;return;}
 if(downTime>0){downTime-=dt;effects.forEach(e=>{e.life-=dt;});if(downTime<=0){downTime=0;respawn();}return;}shake=Math.max(0,shake-dt);for(const k in nodeShake)nodeShake[k]=Math.max(0,nodeShake[k]-dt);for(let i=floats.length-1;i>=0;i--){floats[i].life-=dt;floats[i].y-=dt*16;if(floats[i].life<=0)floats.splice(i,1);}if(!state.forest.every(Boolean))state.time+=dt;player.hurt=Math.max(0,player.hurt-dt);player.hitT=Math.max(0,player.hitT-dt);player.getup=Math.max(0,player.getup-dt);player.land=Math.max(0,player.land-dt);
 // While the capsule opens the hero is not yet in control; he steps out on his own.
 const walkOut=!!intro&&intro.t>1.9&&player.x<BUNKER.capsule+34,right=intro?walkOut:moveAxis>0||keys.KeyD||keys.ArrowRight,left=!intro&&(moveAxis<0||keys.KeyA||keys.ArrowLeft),up=!intro&&(held.jump||keys.Space||keys.KeyW||keys.ArrowUp);
 // Ladders: climbing is automatic once started, so it needs no vertical stick on a phone.
 if(player.climb){const c=player.climb,dir=Math.sign(c.to-player.y);player.y+=dir*120*dt;player.walk+=dt*6;if((c.to-player.y)*dir<=0){player.y=c.to;player.floor=c.floor;player.climb=null;player.vy=0;player.ground=true;if(c.exit){player.y=GROUND-player.h;goScene('surface');}}targetNow=null;interaction={key:'',value:0};updateMobs(dt);updateShots(dt);uiClock+=dt;if(uiClock>=.25){refreshHud();refreshContext();uiClock=0;}return;}
 player.running=(stickRun&&moveAxis!==0)||(keys.ShiftLeft||keys.ShiftRight)&&(left||right);
 player.vx=((right?1:0)-(left?1:0))*(player.running?150:85);if(atk.anim>0&&player.ground)player.vx*=.35;
 // Cadence: one 4-frame cycle covers two steps, so feet keep pace with the ground instead of sliding.
 if(player.vx){player.face=Math.sign(player.vx);player.walk+=dt*Math.abs(player.vx)*4/(2*stepLength());}else player.walk=0;
 if(player.running&&player.ground){player.dust=(player.dust||0)-dt;if(player.dust<=0){player.dust=.16;burst(player.x-player.face*6,groundY()-2,'#a39a80',2);}state.stats.food=Math.max(0,state.stats.food-dt*.02);}
 if(player.ground)coyote=.1;else coyote=Math.max(0,coyote-dt);jumpBuffer=Math.max(0,jumpBuffer-dt);if(player.vx)autoAction=false;
 if((jumpBuffer>0||up&&!jumpLatch)&&coyote>0){jumpBuffer=0;coyote=0;player.vy=-230;player.ground=false;squash=-.1;sfx('jump');}jumpLatch=!!up;player.vy=Math.min(300,player.vy+620*dt);
 player.kb=Math.abs(player.kb)<4?0:player.kb*(1-7*dt);const dx=(player.vx+player.kb)*dt;const wasGround=player.ground,gy=groundY();
 if(inMine()){const F=MINEMAP.floors[player.floor];player.x=Math.max(F.x1,Math.min(F.x2,player.x+dx));player.ground=false;player.y+=player.vy*dt;if(player.y+player.h>=gy){player.y=gy-player.h;player.vy=0;player.ground=true;}}
 else if(inBunker()){player.x=Math.max(40,Math.min(BUNKER.w-48,player.x+dx));player.ground=false;player.y+=player.vy*dt;if(player.y+player.h>=GROUND){player.y=GROUND-player.h;player.vy=0;player.ground=true;}}
 else if(inVault()){player.x=Math.max(40,Math.min(VAULT.w-40,player.x+dx));player.ground=false;player.y+=player.vy*dt;if(player.y+player.h>=GROUND){player.y=GROUND-player.h;player.vy=0;player.ground=true;}}
 else{if(!overlaps(player.x+dx,player.y))player.x+=dx;player.x=Math.max(24,Math.min(state.completed?WORLD-24:1550,player.x));
 player.ground=false;const nextY=player.y+player.vy*dt;if(player.vy>0&&overlaps(player.x,nextY)&&player.y+player.h<=obstacle.y+2){player.y=obstacle.y-player.h;player.vy=0;player.ground=true;}else player.y=nextY;
 if(player.y+player.h>=GROUND){player.y=GROUND-player.h;player.vy=0;player.ground=true;}else if(player.y+player.h<obstacle.y-1)player.ground=false;}
 if(player.ground&&!wasGround&&player.vy===0){squash=.13;player.land=.1;burst(player.x,player.y+player.h-1,'#9c9378',3);sfx('land');}squash=Math.abs(squash)<.01?0:squash*(1-12*dt);
 // Combat timers; holding Strike keeps the combo going.
 atk.cool=Math.max(0,atk.cool-dt);atk.comboT=Math.max(0,atk.comboT-dt);sling.cool=Math.max(0,sling.cool-dt);sling.anim=Math.max(0,sling.anim-dt);if(slash){slash.life-=dt;if(slash.life<=0)slash=null;}
 if(atk.anim>0){atk.anim-=dt;if(!atk.hitDone&&atk.anim<=.14){atk.hitDone=true;resolveStrike();}}
 if((held.attack)&&atk.cool<=0)attack();if(held.shoot&&sling.cool<=0&&state.inv.ammo>0)shoot();
 targetNow=atk.anim>0?null:findTarget();
 // The object being worked on stays the target while it is in reach, even if another one is now closer.
 if(lockedTarget&&interaction.key===lockedTarget.key&&targetNow?.key!==lockedTarget.key&&atk.anim<=0&&stillValid(lockedTarget))targetNow=lockedTarget;lockedTarget=interaction.key?targetNow:null;
 const pushing=held.action||keys.KeyE,pressing=(pushing&&!actionLatch)||autoAction,danger=threat();
 // Holding Use next to a hostile mutant strikes it (rate-limited by the strike cooldown) instead of gathering.
 if(pushing&&danger&&!actionLatch){autoAction=false;interaction={key:'',value:0};swing=0;if(atk.cool<=0)attack();}
 // Something stands in the way (a missing tool or part): say why, once per press, and start no progress.
 else if(pressing&&targetNow?.block){toast(t(targetNow.block));actionLatch=true;autoAction=false;interaction={key:'',value:0};sfx('click');}
 else if(pressing&&targetNow){if(interaction.key!==targetNow.key){interaction={key:targetNow.key,value:0};swing=0;hits=0;}
  // Step to the side of the object and face it, so the tool lands on it and the hero does not hide it.
  if(swingKind(targetNow)||targetNow.kind==='clean'){const side=player.x<targetNow.x-1?-1:player.x>targetNow.x+1?1:(player.face>0?-1:1),spot=targetNow.x+side*(targetNow.kind==='clean'?14:24),d=spot-player.x;player.face=-side;if(Math.abs(d)>1){const nx=player.x+Math.sign(d)*Math.min(Math.abs(d),70*dt);if(inMine()){const F=MINEMAP.floors[player.floor];player.x=Math.max(F.x1,Math.min(F.x2,nx));}else if(!overlaps(nx,player.y))player.x=nx;player.walk+=dt*5;}}
  if(swingKind(targetNow)){
   // Tool work is a series of strikes: wind-up, contact, recovery. Chips, sound and progress happen on contact;
   // the resource is granted on the last contact, never by holding or by frame changes.
   const need=strikesFor(targetNow),prev=swing;swing+=dt/(SWING/perk('work',1));
   if(Math.floor(prev-CONTACT)!==Math.floor(swing-CONTACT)&&swing>=CONTACT){hits++;impact(targetNow);interaction.value=hits/need*targetNow.time;if(hits>=need){finishAction(targetNow);interaction={key:'',value:0};hits=0;actionLatch=true;}}}
  else{swing+=dt/.8;interaction.value+=dt*perk('work',1);if(interaction.value>=targetNow.time){finishAction(targetNow);interaction={key:'',value:0};actionLatch=true;}}}
 else {interaction={key:'',value:0};swing=0;hits=0;if(!targetNow)autoAction=false;}
 if(state.scene==='surface'&&state.completed&&player.x>1600&&!forestGuard){forestGuard=true;mobs.push(makeMob('shellback',2150,{hp:10,min:1960,max:2380}));toast(t('toast.guard'));}
 if(inMine()&&!mobs.caveHint&&mobs.some(m=>m.kind==='stoneback'&&m.st==='chase')){mobs.caveHint=true;toast(t('toast.cave'));}
 updateMobs(dt);updateShots(dt);updateMira(dt);updateStory(dt);
 if(state.beds.every(Boolean)&&!state.completed){state.defense.time=Math.min(90,state.defense.time+dt);const wave=Math.floor(state.defense.time/15)+1;
  if(wave>state.defense.wave&&wave<=6){state.defense.wave=wave;for(let i=0;i<(wave>3?2:1);i++){const fromLeft=i===1;mobs.push(makeMob('crawler',fromLeft?185:790,{hp:wave===6?5:3,role:'raider',goal:fromLeft?405:490,min:150,max:830}));}toast(wave===1?t('toast.wave1'):t('toast.wave',{n:wave}));}
  if(state.defense.hp<=0){state.defense={time:0,hp:100,wave:0};mobs=mobs.filter(m=>m.role!=='raider');player.x=450;toast(t('toast.defenseFail'));}
  if(state.defense.time>=90){state.completed=true;if(art.garden)bakeBackground();mobs=mobs.filter(m=>m.role!=='raider');winShown=true;save();setTimeout(()=>showWin(1),1200);}}
 // The vault is frozen: without a lit torch the cold slowly drains health.
 if(inVault()&&!(state.built.torch&&torchOn)){state.stats.hp=Math.max(0,state.stats.hp-dt*.8);if(!coldHint){coldHint=true;toast(t('toast.cold'));}}
 if(state.stats.hp<=0&&!downTime){downTime=1.6;autoAction=false;interaction={key:'',value:0};sfx('hurt');toast(t('toast.down'));}
 state.stats.food=Math.max(0,state.stats.food-dt*.018);state.stats.thirst=Math.max(0,state.stats.thirst-dt*.025);if(state.scene==='surface'&&nearBase())state.stats.hp=Math.min(100,state.stats.hp+dt*.5);
 for(let i=effects.length-1;i>=0;i--){const e=effects[i];e.x+=e.vx*dt;e.y+=e.vy*dt;e.vy+=85*dt;e.life-=dt;if(e.life<=0)effects.splice(i,1);}
 uiClock+=dt;saveClock+=dt;if(uiClock>=.25){refreshHud();refreshContext();setMood(inMine()||inVault()||inBunker()?'mine':state.beds.every(Boolean)&&!state.completed?'defense':player.x>1600?'forest':'city');uiClock=0;}if(saveClock>15&&!saveQueued){saveClock=0;saveQueued=true;const flush=()=>{saveQueued=false;save();};if(window.requestIdleCallback)window.requestIdleCallback(flush,{timeout:3000});else setTimeout(flush,0);}
}
function refreshContext(){let label=targetNow?(kbHints?'E · ':'')+t(targetNow.name):'',verb=targetNow?.verb||'verb.act';
 if(!targetNow&&!inPrologue(state)){if(state.beds.every(Boolean)&&!state.completed)label=t('target.defend');else if(nearestMob(110))label=t('target.enemy');else if(nearBase()){label=t('target.base');verb='verb.craft';}else if(state.scene==='surface'&&player.x>1000&&player.x<1100)label=t('target.beam');}
 setText(ui['target-label'],label);setText(ui['action-text'],t(autoAction?'verb.stop':verb));$('#action')?.classList.toggle('auto-working',autoAction);}

// ---------- prologue: the bunker, the road, the Station ----------
// The story state lives in state.story (saved). Lines already heard are kept in story.said, so a reload never replays them.
const inBunker=()=>state.scene==='bunker';
const story=()=>state.story||{};
const kbHints=typeof matchMedia==='function'&&matchMedia('(hover:hover) and (pointer:fine)').matches;
const mira={x:BUNKER.mira,y:0,face:1,walk:0,hop:0,moving:false,joy:0};
const DIALOG={
 wake:[['mira','dlg.wake1'],['einstein','dlg.wake2'],['mira','dlg.wake3'],['einstein','dlg.wake4'],['mira','dlg.wake5']],
 tool:[['mira','dlg.tool']],hatch:[['mira','dlg.hatch']],road:[['mira','dlg.road1'],['mira','dlg.road2']],mats:[['mira','dlg.mats']],
 station:[['mira','dlg.station1'],['mira','dlg.station2'],['mira','dlg.station3']],made:[['mira','dlg.made']],fixed:[['mira','dlg.fixed']],
 water:[['mira','dlg.water1'],['einstein','dlg.water2'],['mira','dlg.water3']],
 radio:[['radio','dlg.radio1'],['radio','dlg.radio2'],['mira','dlg.radio3'],['einstein','dlg.radio4']]};
// What Mira repeats when you talk to her: the line that explains the current step.
const NUDGE={101:'dlg.wake5',102:'dlg.tool',103:'dlg.hatch',104:'dlg.road2',105:'dlg.mats',106:'dlg.station3',107:'dlg.made',108:'dlg.fixed',109:'dlg.water3'};
let talk={lines:[],i:0,t:0,then:null,shown:''},intro=null,waterFill=.12;
// A new story beat replaces chatter that is still queued (its follow-ups still run), so lines never lag behind events.
function flushTalk(){const rest=talk.lines.slice(talk.i+1);talk={lines:[],i:0,t:0,then:null,shown:''};for(const l of rest)if(l[0]==='@')l[1]();const box=$('#dialog');if(box){box.hidden=true;$('#game').classList.remove('talking');}}
function say(id,then=null,force=false){const st=story();if(!force&&st.said?.includes(id)){then?.();return;}if(st.said&&!st.said.includes(id))st.said.push(id);
 flushTalk();talk.lines.push(...DIALOG[id].map(l=>l.slice()));if(then)talk.lines.push(['@',then]);if(!talk.lines.length)return;showLine();}
function sayLine(who,key){flushTalk();talk.lines.push([who,key]);showLine();}
function showLine(){const l=talk.lines[talk.i];const box=$('#dialog');if(!box)return;
 while(l&&l[0]==='@'){talk.i++;l[1]();return showLine();}
 if(!l){talk={lines:[],i:0,t:0,then:null,shown:''};box.hidden=true;$('#game').classList.remove('talking');return;}
 const text=t(l[1],STORY.repairCost),key=l[0]+l[1];if(talk.shown===key&&!box.hidden)return;talk.shown=key;talk.t=Math.min(5.5,Math.max(2.4,1.4+text.length*.035));
 box.hidden=false;$('#game').classList.add('talking');box.classList.toggle('radio',l[0]==='radio');setText($('#dlg-who'),t('who.'+l[0]));setText($('#dlg-text'),text);
 const face=$('#dlg-face');if(face){const src=l[0]==='radio'?'':`assets/portrait-${l[0]}.webp`;face.hidden=!src;if(src&&face.getAttribute('src')!==src)face.src=src;}
 if(l[0]==='mira')mira.face=Math.sign(player.x-mira.x)||mira.face;sfx('click');}
function nextLine(){if(!talk.lines.length)return;talk.i++;talk.shown='';showLine();}
$('#dialog')?.addEventListener('pointerdown',ev=>{ev.preventDefault?.();ev.stopPropagation?.();nextLine();});
function sceneTitle(n){const el=$('#scene-title');if(!el)return;setText(el,t('scene.'+n));el.hidden=false;el.style&&(el.style.animation='none');void el.offsetWidth;if(el.style)el.style.animation='';clearTimeout(sceneTitle.tm);sceneTitle.tm=setTimeout(()=>{el.hidden=true;},3300);}
// One-off teaching hints, shown at the moment the action is needed.
function hint(id){const st=story();if(!st.said||st.said.includes('h-'+id))return;st.said.push('h-'+id);const k=kbHints&&t('hint.'+id+'Keys')!=='hint.'+id+'Keys'?'hint.'+id+'Keys':'hint.'+id;toast(t(k));}
function syncCalm(){$('#game').classList.toggle('calm',inPrologue(state));$('#game').classList.toggle('kb',kbHints);}
// Starting or resuming the prologue: title card, the capsule cut-scene on a fresh start, the right lines on a reload.
function startPrologue(){if(!inPrologue(state))return;const st=story();syncCalm();
 if(inBunker()){sceneTitle(1);if(!st.woke){intro={t:0};player.x=BUNKER.capsule;player.face=1;}}
 else{sceneTitle(st.station?3:2);mira.x=st.station?STATION.mira:player.x+40;}
 if(!kbHints&&typeof matchMedia==='function'&&matchMedia('(orientation:portrait)').matches&&!st.said.includes('h-rotate')){st.said.push('h-rotate');const r=$('#rotate-hint');if(r)r.hidden=false;}}
$('#rotate-ok')&&($('#rotate-ok').onclick=()=>{$('#rotate-hint').hidden=true;});
// Things the hero can use in the bunker. block: why it cannot be done yet (no progress bar, just the reason).
function bunkerTarget(){const st=story(),near=(x,r)=>Math.abs(player.x-x)<r;let best=null;
 if(intro)return null;
 if(!st.tool&&near(BUNKER.tool,30))best={kind:'wrench',key:'wrench',time:.35,x:BUNKER.tool,name:'target.wrench',verb:'verb.get',w:34,h:30};
 if(!st.hatch&&near(BUNKER.valve,28))best={kind:'valve',key:'valve',time:1.6,x:BUNKER.valve,name:st.tool?'target.valve':'target.valveNoTool',verb:'verb.use',block:st.tool?null:'toast.noTool',w:24,h:60,lift:22};
 if(near(BUNKER.ladder,22))best=st.hatch?{kind:'exitLadder',key:'exit-ladder',time:.15,x:BUNKER.ladder,name:'target.ladderOut',verb:'verb.climb',w:24,h:90}:{kind:'shut',key:'exit-ladder',time:.1,x:BUNKER.ladder,name:'target.ladderShut',verb:'verb.climb',block:'toast.hatchShut',w:24,h:90};
 if(!best&&near(mira.x,24))best={kind:'mira',key:'mira',time:.1,x:mira.x,name:'target.mira',verb:'verb.talk',w:24,h:64};
 return best;}
// The Station's own targets, added on top of the road's chests and logs while the prologue runs.
function stationTargets(best){const st=story(),near=(x,r)=>Math.abs(player.x-x)<r;
 if(near(262,30))best={kind:'bench',key:'bench',time:.1,x:262,name:'target.bench',verb:'verb.open2',w:66,h:40};
 if(!st.fixed&&near(FILTER_X,28))best={kind:'fixFilter',key:'fix',time:1.8,x:FILTER_X,name:state.inv.repair?'target.filterBroken':'target.filterNoPart',verb:'verb.repair2',block:state.inv.repair?null:'toast.needPart',w:46,h:56};
 else if(st.fixed&&!st.water&&near(FILTER_X,28))best={kind:'startWater',key:'tap',time:.8,x:FILTER_X,name:'target.filterStart',verb:'verb.use',w:46,h:56};
 if(st.water&&!st.radio&&near(STATION.radio,24))best={kind:'radio',key:'radio',time:.2,x:STATION.radio,name:'target.radio',verb:'verb.listen',w:20,h:34};
 if(!best&&st.out&&near(mira.x,22))best={kind:'mira',key:'mira',time:.1,x:mira.x,name:'target.mira',verb:'verb.talk',w:24,h:64};
 return best;}
// Prologue actions. Returns true when it handled the target.
function prologueFinish(tg){const st=story(),gy=groundY();
 switch(tg.kind){
  case 'wrench':st.tool=true;state.inv.wrench=1;floatText(tg.x,gy-40,'+1 '+t(ITEMS.wrench).toLowerCase());toast(t('toast.wrench'));burst(tg.x,gy-26,'#f2c14e',8);sfx('gain');say('tool');break;
  case 'valve':st.hatch=true;shake=prefs.effects?.18:0;burst(BUNKER.ladder,gy-176,'#c9c2b0',14);sfx('craft');toast(t('toast.hatchOpen'));say('hatch',()=>hint('climb'));break;
  case 'exitLadder':player.climb={x:tg.x,from:player.y,to:BUNKER.top,floor:0,exit:true};player.x=tg.x;held.action=false;autoAction=false;sfx('click');return true;
  case 'mira':{const q=quest(state);sayLine('mira',NUDGE[q.step]||'dlg.mats');held.action=false;autoAction=false;actionLatch=true;return true;}
  case 'bench':held.action=false;autoAction=false;actionLatch=true;craftCat='build';openSheet('craft-dialog');return true;
  case 'fixFilter':state.inv.repair--;st.fixed=true;burst(tg.x,gy-30,'#f2c14e',12);sfx('craft');toast(t('toast.fixed'));say('fixed');break;
  case 'startWater':st.water=true;state.built.filter=true;burst(tg.x+14,gy-20,'#9fd6e0',16);sfx('water');toast(t('toast.water'));mira.joy=1.2;save();say('water');break;
  case 'radio':held.action=false;autoAction=false;actionLatch=true;say('radio',finishPrologue,true);return true;
  default:return false;}
 autoAction=false;held.action=false;buzz(12);save();refreshHud();dirtyFrame=true;return true;}
// The end of the first chapter: the campaign takes over (filter and workbench already stand), mutants return to the city.
function finishPrologue(){const st=story();if(st.done)return;st.radio=true;st.done=true;syncCalm();if(!mobs.length&&state.scene==='surface')mobs.push(makeMob('crawler',1140,{hp:3,min:1100,max:1300}));save();refreshHud();showWin(5);}
// Story beats that happen by walking: leaving the metro, reaching the Station, having enough for the repair unit.
function updateStory(dt){const st=story();if(!state.story||st.done)return;
 if(intro){intro.t+=dt;if(intro.t>.9&&!intro.talk){intro.talk=true;say('wake',()=>hint('move'));}
  if(intro.t>1.9&&player.x<BUNKER.capsule+34){player.x+=40*dt;player.face=1;player.walk+=dt*5;}
  if(intro.t>2.6){intro=null;st.woke=true;save();}}
 if(talk.lines.length){talk.t-=dt;if(talk.t<=0)nextLine();}
 if(state.scene==='surface'){
  if(!st.station&&player.x<STATION.edge){st.station=true;sceneTitle(3);say('station');save();}
  const cost=STORY.repairCost;if(!st.station&&!st.road&&Object.entries(cost).every(([k,n])=>state.inv[k]>=n)){st.road=true;say('mats');}}
 if(targetNow&&!st.said.includes('h-act'))hint('act');}
function updateMira(dt){const st=story();if(!state.story)return;let tx;
 if(inBunker())tx=BUNKER.mira;else if(state.scene!=='surface')return;else if(st.station||st.done)tx=STATION.mira;else tx=player.x-player.face*46;
 const dx=tx-mira.x;mira.moving=Math.abs(dx)>4;if(mira.moving){const v=Math.min(135,Math.abs(dx)*3+30);mira.x+=Math.sign(dx)*Math.min(Math.abs(dx),v*dt);mira.face=Math.sign(dx);mira.walk+=dt*v*4/56;}
 else{mira.walk=0;mira.face=inBunker()&&!talk.lines.length?1:Math.sign(player.x-mira.x)||mira.face;}
 // She hops over the fallen beam instead of walking through it.
 const b0=obstacle.x-10,b1=obstacle.x+obstacle.w+10;mira.hop=state.scene==='surface'&&mira.x>b0&&mira.x<b1?Math.sin((mira.x-b0)/(b1-b0)*Math.PI)*18:0;
 mira.joy=Math.max(0,mira.joy-dt);}
function miraFrame(){if(mira.joy>0)return mira.joy>.6?21:15;if(mira.hop>1)return 21;if(mira.moving)return Math.floor(mira.walk)%4;return 12;}
function drawMira(){if(!art.mira||!state.story||!miraData())return;if(state.scene==='surface'&&!story().out)return;const d=miraData(),f=d.frames[miraFrame()];if(!f)return;
 const k=64/d.unit,x=Math.round(mira.x),y=GROUND+Math.round(-mira.hop-(mira.joy>0?Math.sin(mira.joy/1.2*Math.PI)*14:0));if(x<camera.x-60||x>camera.x+VW+60)return;
 drawShadow(x,GROUND+1,26,.7);const img=graded(art.mira,0,0,art.mira.width,art.mira.height,'mira',toneAt(x));ctx.save();ctx.translate(x,y);ctx.scale(mira.face,1);ctx.imageSmoothingEnabled=true;ctx.drawImage(img,f.x,f.y,f.w,f.h,-f.anchor*k,-(f.foot??f.h)*k,f.w*k,f.h*k);ctx.restore();ctx.imageSmoothingEnabled=false;}
const miraData=()=>extraHeroes.curie&&!Array.isArray(extraHeroes.curie)?extraHeroes.curie:null;
// Faint markers over things that can be used nearby, so they read apart from the decoration; the current target gets brackets.
function interactables(){const st=story(),out=[];if(!inPrologue(state))return out;
 if(inBunker()){if(!st.tool)out.push([BUNKER.tool,GROUND-34]);if(!st.hatch)out.push([BUNKER.valve,GROUND-66]);out.push([BUNKER.ladder,GROUND-96]);return out;}
 for(const c of CHESTS)if(!state.harvested[c.id])out.push([c.x,GROUND-34]);
 if(st.station){out.push([262,GROUND-46]);if(!st.water)out.push([FILTER_X,GROUND-62]);else if(!st.radio)out.push([STATION.radio,GROUND-40]);}
 return out;}
function drawHints(){for(const [x,y] of interactables()){if(Math.abs(x-player.x)>170||targetNow&&Math.abs(targetNow.x-x)<4)continue;const b=Math.round(Math.sin(now*3+x)*1.5);ctx.globalAlpha=.75;rect(x-2,y-6+b,4,4,'#f2c14e');rect(x-1,y-7+b,2,6,'#f2c14e');ctx.globalAlpha=1;}}
// ---------- prologue art (drawn in code until the painted sprites arrive; see ASSETS_NEEDED.md) ----------
function bakeBunker(){if(typeof document==='undefined'||!document.createElement)return;const K=2,W=BUNKER.w,Y0=-160,H=600,c=document.createElement('canvas');c.width=W*K;c.height=H*K;const g=c.getContext('2d');g.scale(K,K);g.translate(0,-Y0);
 const R=(x,y,w,h,col)=>{g.fillStyle=col;g.fillRect(x,y,w,h);},G=GROUND,top=G-176,E=BUNKER.ladder+28,cap=BUNKER.capsule,win=BUNKER.console+84;
 R(0,Y0,W,H,'#0d1012');
 // Rock above the ceiling and on the right, with roots.
 for(let y=Y0;y<top;y+=10)for(let x=-(Math.floor(y/10)%2)*10;x<W;x+=20){const v=hash(x,y);R(x+1,y+1,18,8,['#1d1a17','#22201c','#1a1715','#26231e'][Math.floor(v*4)]);R(x+1,y+1,18,1,'#2f2b25');}
 R(0,top-6,W,8,'#2b3034');R(0,top-6,W,1,'#4a5258');
 // Back wall: riveted steel panels with colour variation and grime.
 for(let x=0;x<E;x+=40)for(let y=top+2;y<G;y+=29){const v=hash(x,y);R(x,y,40,29,['#252b2f','#283035','#22282c','#2c3337'][Math.floor(v*4)]);R(x,y,40,1,'#3a4248');R(x,y,1,29,'#1a1f22');for(const [rx,ry] of [[3,3],[35,3],[3,24],[35,24]])R(x+rx,y+ry,2,2,'#4f585e');if(v>.7)R(x+6,y+12,28*v,10,'rgba(40,30,20,.35)');}
 // Pipes and cables under the ceiling.
 R(0,top+8,E,8,'#5a3e2c');R(0,top+8,E,2,'#8a6040');R(0,top+15,E,1,'#2b1d14');R(0,top+22,E,4,'#4c565c');R(0,top+22,E,1,'#76828a');for(let x=30;x<E;x+=90){R(x,top+5,6,24,'#2b3034');}
 R(250,top,7,G-top,'#3b4449');R(250,top,2,G-top,'#5d676d');R(BUNKER.valve-4,top,8,G-top,'#4c3a2c');R(BUNKER.valve-4,top,2,G-top,'#7a5a40');
 g.strokeStyle='#15191b';g.lineWidth=2;for(const [a,b,s] of [[10,130,18],[60,240,26],[270,420,14],[520,700,20],[690,820,16]]){g.beginPath();g.moveTo(a,top+30);g.quadraticCurveTo((a+b)/2,top+30+s*2,b,top+30);g.stroke();}
 // Cracked observation windows with a faint seal on the middle one.
 for(let i=0;i<3;i++){const x=win+i*62,y=top+44;R(x,y,58,68,'#353d42');const gr=g.createLinearGradient(0,y,0,y+68);gr.addColorStop(0,'#173e45');gr.addColorStop(1,'#0c2226');g.fillStyle=gr;g.fillRect(x+3,y+3,52,62);g.strokeStyle='rgba(120,200,205,.45)';g.lineWidth=1;g.beginPath();g.moveTo(x+10+i*9,y+4);g.lineTo(x+24,y+30);g.lineTo(x+16,y+64);g.moveTo(x+24,y+30);g.lineTo(x+52,y+22);g.stroke();
  if(i===1){g.strokeStyle='rgba(200,170,90,.35)';g.beginPath();g.arc(x+29,y+33,14,0,Math.PI*2);g.moveTo(x+29,y+19);g.lineTo(x+16,y+42);g.lineTo(x+42,y+42);g.closePath();g.stroke();}}
 // Shelves with jars and a faded microscope poster on the left.
 R(8,top+30,46,40,'#bfb08a');R(10,top+32,42,36,'#d8caa0');g.strokeStyle='#5a4a30';g.beginPath();g.moveTo(22,top+60);g.lineTo(40,top+60);g.moveTo(31,top+60);g.lineTo(31,top+42);g.lineTo(36,top+38);g.stroke();
 for(let s=0;s<3;s++){const y=top+92+s*26;R(6,y,58,3,'#4a3a2c');for(let j=0;j<5;j++){const v=hash(j,s);R(9+j*11,y-10-v*6,7,10+v*6,['#7a9a6a','#a85a3a','#6a8aa0','#c9a050'][Math.floor(v*4)]);}}
 // Hazard-striped walkway, the understructure and the flooded channel below.
 R(0,G,W,6,'#4a5258');R(0,G,W,1,'#76828a');for(let x=0;x<W;x+=6)R(x,G+2,3,3,'#353c41');for(let x=cap-32;x<cap+36;x+=8){R(x,G-6,4,6,'#e0b030');R(x+4,G-6,4,6,'#1a1a1a');}
 R(0,G+6,W,134,'#0b0e10');for(let x=20;x<W;x+=64){R(x,G+6,8,90,'#262c30');R(x,G+6,2,90,'#3b4449');}R(0,G+34,W,6,'#3a2a20');R(0,G+50,W,4,'#2c3236');
 const wg=g.createLinearGradient(0,G+86,0,G+130);wg.addColorStop(0,'#123c42');wg.addColorStop(1,'#071a1d');g.fillStyle=wg;g.fillRect(0,G+86,W,44);
 // Hanging vines and dripping water.
 for(let x=8;x<E;x+=23){const v=hash(x,3);if(v<.45)continue;const L=10+v*40;for(let i=0;i<L;i+=3)R(x+Math.sin(i*.4)*2,top+i,3,3,i%6?'#3d5a2a':'#55753a');}
 // The rock face on the right and the ladder shaft up to the hatch.
 for(let y=top-6;y<G;y+=10)for(let x=E;x<W;x+=14){const v=hash(x,y+7);R(x,y,13,9,['#2a2622','#322d27','#26221e'][Math.floor(v*3)]);}
 const L=BUNKER.ladder;R(L-16,Y0,32,top-Y0,'#08090a');g.fillStyle='#5b3b22';g.fillRect(L-11,Y0,3,G-Y0);g.fillRect(L+8,Y0,3,G-Y0);for(let y=Y0+4;y<G;y+=9){R(L-10,y,19,2,'#8c6136');}
 // Warm lamps.
 for(const lx of [60,win+96,BUNKER.valve+30]){const lg=g.createRadialGradient(lx,top+34,0,lx,top+34,70);lg.addColorStop(0,'rgba(255,190,110,.35)');lg.addColorStop(1,'rgba(255,190,110,0)');g.fillStyle=lg;g.fillRect(lx-70,top+34-70,140,140);R(lx-5,top+26,10,6,'#3a3a3a');R(lx-3,top+32,6,4,'#ffd08a');}
 rendered.bunker={canvas:c,K,Y0,H};
 // Daylight falling through the opened hatch.
 const s=document.createElement('canvas');s.width=32;s.height=128;const sg=s.getContext('2d'),sl=sg.createLinearGradient(0,0,0,128);sl.addColorStop(0,'rgba(220,235,220,.55)');sl.addColorStop(1,'rgba(220,235,220,0)');sg.fillStyle=sl;sg.fillRect(0,0,32,128);rendered.shaft=s;}
function drawCapsule(front){const x=BUNKER.capsule,G=GROUND,open=intro?Math.min(1,Math.max(0,(intro.t-.5)/1.1)):story().woke?1:0;
 if(!front){rect(x-26,G-6,52,6,'#3b4449');rect(x-28,G-96,8,92,'#7c878d');rect(x+20,G-96,8,92,'#5d676d');rect(x-28,G-96,1,92,'#a9b4ba');rect(x-30,G-108,60,14,'#8b969c');rect(x-30,G-108,60,2,'#c3ccd0');rect(x-16,G-104,32,6,'#2b3236');
  ctx.globalAlpha=.55+.15*Math.sin(now*2);rect(x-20,G-94,40,88,'#2fa7b8');ctx.globalAlpha=1;rect(x-20,G-94,40,4,'#9fe8f0');for(let i=0;i<4;i++)rect(x-18+i*11,G-12,6,3,'#173e45');return;}
 // Glass door slides up into the cap; mist spills out while it opens.
 const lift=Math.round(open*84),h=88-lift;if(h>0){ctx.globalAlpha=.32;rect(x-20,G-94,40,h,'#8fe6ee');ctx.globalAlpha=.6;rect(x-16,G-90,3,Math.max(0,h-8),'#e6fbff');ctx.globalAlpha=1;}
 if(open>0&&open<1)for(let i=0;i<6;i++){ctx.globalAlpha=.35*(1-open);rect(x-26+((i*13+now*30)%52),G-8-((i*7+now*12)%14),6,3,'#cfeff2');}ctx.globalAlpha=1;}
function drawBunkerProps(){const st=story(),G=GROUND,B=BUNKER;
 // Console with a battery wired into it; its screen flickers while it drains.
 rect(B.console-14,G-50,30,50,'#3b4449');rect(B.console-14,G-50,30,2,'#6f7a80');rect(B.console-10,G-44,22,16,'#0f3a2c');for(let i=0;i<3;i++)rect(B.console-8,G-41+i*5,Math.floor(8+((now*3+i*5)%12)),2,'#6ad08a');rect(B.console-8,G-22,6,6,'#d9a441');rect(B.console+2,G-22,8,3,'#e2483c');
 ctx.strokeStyle='#8a2a1f';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(B.battery,G-14);ctx.quadraticCurveTo(B.battery-8,G+2,B.console+14,G-18);ctx.stroke();
 rect(B.battery-9,G-14,18,14,'#d9a441');rect(B.battery-9,G-14,18,2,'#ffe08a');rect(B.battery-6,G-17,4,3,'#2c2c2c');rect(B.battery+2,G-17,4,3,'#2c2c2c');rect(B.battery-2,G-10,4,6,'#1a1a1a');
 // Tool box with the wrench on top (gone once taken).
 drawProp('crate',B.tool,G+1,34);if(!st.tool&&art.held&&heldLayout.wrench){const L=heldLayout.wrench,sc=22/L.h;ctx.save();ctx.translate(B.tool,G-26+Math.round(Math.sin(now*3)));ctx.rotate(-Math.PI/2);ctx.imageSmoothingEnabled=true;ctx.drawImage(art.held,L.x,L.y,L.w,L.h,-L.w*sc/2,-L.h*sc/2,L.w*sc,L.h*sc);ctx.restore();ctx.imageSmoothingEnabled=false;}
 // Emergency valve: turns while the hero works it; its lamp goes green when the hatch is open.
 const vx=B.valve,vy=G-44,turning=interaction.key==='valve',ang=(turning?interaction.value*4:0)+(st.hatch?2:0);rect(vx-3,vy-16,6,6,st.hatch?'#6ad04a':Math.floor(now*3)%2?'#e2483c':'#5a2a24');
 ctx.save();ctx.translate(vx,vy);ctx.rotate(ang);ctx.strokeStyle='#b03a2e';ctx.lineWidth=3;ctx.beginPath();ctx.arc(0,0,8,0,Math.PI*2);ctx.stroke();for(let i=0;i<4;i++){ctx.rotate(Math.PI/2);rect(-1,0,2,8,'#8a2a1f');}ctx.restore();rect(vx-2,vy-2,4,4,'#d9a441');
 // The hatch at the top of the ladder: shut with a red lamp, or open with daylight pouring in.
 const L=B.ladder,top=G-176;if(st.hatch){rect(L-16,top-8,32,10,'#050607');if(rendered.shaft){ctx.globalAlpha=.8+.1*Math.sin(now*2);ctx.imageSmoothingEnabled=true;ctx.drawImage(rendered.shaft,L-16,top-4,32,150);ctx.imageSmoothingEnabled=false;ctx.globalAlpha=1;}}
 else{rect(L-17,top-8,34,10,'#4a5258');for(let i=0;i<4;i++)rect(L-15+i*8,top-6,4,6,i%2?'#e0b030':'#1a1a1a');rect(L+14,top+4,4,4,Math.floor(now*2)%2?'#ff5a3c':'#6a2a20');}
 // Red alarm lamp in the ceiling until the exit is open.
 if(!st.hatch){const ax=B.valve-110,on=Math.floor(now*1.5)%2;rect(ax,top+30,10,8,on?'#ff4a3a':'#5a2020');if(on){ctx.globalAlpha=.1;rect(ax-22,top+38,54,44,'#ff3a2a');ctx.globalAlpha=.05;rect(ax-44,top+82,98,60,'#ff3a2a');ctx.globalAlpha=1;}}
 // Water glints in the channel under the floor.
 for(let i=0;i<5;i++)rect((i*137+now*18)%BUNKER.w,G+92+(i%3)*8,6,1,'#4fa3ac');}
function paintBunker(){const B=BUNKER,bw=B.w;const cx=bw<=VW?(bw-VW)/2:Math.max(0,Math.min(bw-VW,renderX-VW*.42));camera.x=Math.round(cx*scale)/scale;camera.y=Math.round((GROUND-VH*(VW>VH?.72:.66))*scale)/scale;if(shake>0){const m=shake*14;camera.x+=Math.round((Math.random()-.5)*m*scale)/scale;camera.y+=Math.round((Math.random()-.5)*m*scale)/scale;}
 const bb=rendered.bunker;if(bb){const sx=Math.max(0,camera.x),sy=Math.max(bb.Y0,camera.y),ex=Math.min(bw,camera.x+VW),ey=Math.min(bb.Y0+bb.H,camera.y+VH);if(ex>sx&&ey>sy){ctx.imageSmoothingEnabled=false;ctx.drawImage(bb.canvas,sx*bb.K,(sy-bb.Y0)*bb.K,(ex-sx)*bb.K,(ey-sy)*bb.K,sx-camera.x,sy-camera.y,ex-sx,ey-sy);}}
 ctx.save();ctx.translate(-camera.x,-camera.y);drawCapsule(false);drawBunkerProps();drawMira();drawHero();drawCapsule(true);
 for(const e of effects)rect(e.x,e.y,2,2,e.color);
 if(Math.floor(now*4)%2===0)for(let i=0;i<6;i++){rect(camera.x+((i*137+now*9)%VW),camera.y+((i*71+now*5)%VH),1,1,'#c8d4d8');}
 drawHints();drawFloats();drawTargetMarker();ctx.restore();dirtyFrame=false;}
// The Station while the prologue runs: the broken filter with its alarm, the empty tanks, the radio, dry beds, a sign on the road.
function bakeSign(){const c=document.createElement('canvas');c.width=160;c.height=44;const g=c.getContext('2d');g.fillStyle='#2b3a33';g.fillRect(0,0,160,44);g.fillStyle='#3d5246';g.fillRect(3,3,154,38);g.fillStyle='#e8efe4';g.font='600 22px "Pixelify Sans", system-ui';g.textAlign='center';g.fillText('← '+t('sign.station'),80,30);rendered.sign=c;}
function drawStation(){const st=story(),G=GROUND,F=FILTER_X;
 // Tanks next to the filter: their water level rises once the filter runs.
 waterFill=st.water?Math.min(1,waterFill+.004):.12;const fill=waterFill;for(const [x,col] of [[412,'#5c6a72'],[426,'#5c6a72'],[442,'#3c6a9a']]){rect(x-6,G-20,12,20,col);rect(x-6,G-20,12,2,'#9aa8b0');rect(x-4,G-4-Math.round(14*fill),8,Math.round(14*fill),'#4fb3d0');}
 // Water line from the filter into the tanks when running; a slow drip from the cracked pipe while broken.
 if(st.water){for(let i=0;i<4;i++)rect(F+18+i*5,G-30+((now*30+i*6)%8),2,2,'#9fe0f0');}else for(let i=0;i<2;i++)rect(F+16,G-24+((now*20+i*12)%22),1,2,'#7fb8c4');
 // Status lamp on the filter: red alarm, amber once the unit is fitted, green when running.
 const lamp=st.water?'#6ad04a':st.fixed?'#f2c14e':Math.floor(now*3)%2?'#ff4a3a':'#5a2020';rect(F-3,G-58,6,5,lamp);if(!st.fixed){ctx.globalAlpha=.25+.15*Math.sin(now*6);rect(F-8,G-62,16,12,'#ff4a3a');ctx.globalAlpha=1;}
 if(st.fixed){rect(F-20,G-26,8,8,'#c9a050');rect(F-19,G-25,6,2,'#ffe08a');}
 // Radio on a crate by the workbench; it blinks once the power is back.
 const rx=STATION.radio;drawProp('crate',rx,G+1,24);rect(rx-8,G-24,16,10,'#3b4449');rect(rx-6,G-22,6,6,'#1a1f22');rect(rx+2,G-22,4,2,st.water?'#6ad04a':'#5a2a24');rect(rx+5,G-36,1,12,'#8a949a');
 if(st.water&&!st.radio){const p=(now*1.5)%1;ctx.globalAlpha=1-p;ctx.strokeStyle='#9fe0c8';ctx.lineWidth=1;ctx.beginPath();ctx.arc(rx+5,G-36,4+p*10,-2.4,-.7);ctx.stroke();ctx.globalAlpha=1;}
 // Road sign towards the Station.
 if(!rendered.sign)bakeSign();const sx=1330;rect(sx-1,G-40,3,40,'#5b4a3a');ctx.imageSmoothingEnabled=true;ctx.drawImage(rendered.sign,sx-26,G-52,52,15);ctx.imageSmoothingEnabled=false;}
function drawBrokenFilter(){const G=GROUND,F=FILTER_X,fixed=story().fixed;drawProp('filter',F,G+2,46,false,1,1,!fixed);if(!fixed){rect(F-6,G-40,2,10,'#0a0a0a');rect(F-4,G-34,2,6,'#0a0a0a');rect(F-2,G-30,3,2,'#0a0a0a');}}

// ---------- rendering ----------
function loadImage(src){return new Promise((resolve,reject)=>{const i=new Image();i.onload=()=>{if(i.decode)i.decode().catch(()=>{}).then(()=>resolve(i));else resolve(i);};i.onerror=()=>reject(new Error(src));i.src=src;});}
function drawObject(index,x,ground,width=55,flip=false){const a=atlases.objects?.[index];if(!a||x<camera.x-width||x>camera.x+VW+width)return;const h=a.h/a.w*width;ctx.save();ctx.translate(Math.round(x),Math.round(ground));if(flip)ctx.scale(-1,1);ctx.drawImage(art.objects,a.x,a.y,a.w,a.h,-width/2,-h,width,h);ctx.restore();}
// Scene light: every sprite gets the colour cast of its scene, darker feet and a soft contact shadow,
// so generated props sit in the painted backgrounds instead of looking pasted on top.
const TONES={bunker:{tint:'#2f6f7a',a:.12,ao:.45},city:{tint:'#6a3f86',a:.16,ao:.42},garden:{tint:'#ff8a3a',a:.1,ao:.36},forest:{tint:'#3b4a9a',a:.2,ao:.42},mine:{tint:'#3a1e0c',a:.3,ao:.5},vault:{tint:'#3fa6cc',a:.2,ao:.4}};
function toneAt(x){return inVault()?'vault':inMine()?'mine':inBunker()?'bunker':x>1560?'forest':state.completed&&art.garden?'garden':'city';}
// Buildings stand a little further back: a touch of haze matches the background's depth.
const FAR={greenhouse:.14,metro:.1,lift:.06};
function graded(src,sx,sy,w,h,key,tone,haze=0,spent=false){const k=key+'|'+tone;if(rendered[k])return rendered[k];const T=TONES[tone],c=document.createElement('canvas');c.width=w;c.height=h;const g=c.getContext('2d');g.drawImage(src,sx,sy,w,h,0,0,w,h);g.globalCompositeOperation='source-atop';
 g.globalAlpha=T.a;g.fillStyle=T.tint;g.fillRect(0,0,w,h);g.globalAlpha=1;const ao=g.createLinearGradient(0,h*.55,0,h);ao.addColorStop(0,'rgba(0,0,0,0)');ao.addColorStop(1,`rgba(8,6,10,${T.ao})`);g.fillStyle=ao;g.fillRect(0,0,w,h);
 if(haze){g.globalAlpha=haze;g.fillStyle=T.tint;g.fillRect(0,0,w,h);}if(spent){g.globalAlpha=.42;g.fillStyle='#120e0c';g.fillRect(0,0,w,h);}return rendered[k]=c;}
function shadowBlob(){if(rendered.shadow)return rendered.shadow;const c=document.createElement('canvas');c.width=64;c.height=16;const g=c.getContext('2d'),r=g.createRadialGradient(32,8,0,32,8,32);r.addColorStop(0,'rgba(0,0,0,.6)');r.addColorStop(.6,'rgba(0,0,0,.28)');r.addColorStop(1,'rgba(0,0,0,0)');g.setTransform(1,0,0,.25,0,6);g.fillStyle=r;g.fillRect(0,-24,64,64);return rendered.shadow=c;}
function drawShadow(x,ground,width,alpha=1){if(typeof document==='undefined'||!document.createElement)return;ctx.save();ctx.globalAlpha=alpha;ctx.imageSmoothingEnabled=true;ctx.drawImage(shadowBlob(),Math.round(x-width/2),Math.round(ground-width*.09),width,Math.max(4,width*.18));ctx.restore();}
// Generated props (props.webp): drawn standing on the ground at their native aspect ratio.
// keep: fraction of the sprite kept from the bottom (a cut stump, an emptied ore vein); spent: drawn darker.
function drawProp(name,x,ground,width,flip=false,alpha=1,keep=1,spent=false){const b=propLayout[name];if(!b||!art.props||x<camera.x-width||x>camera.x+VW+width)return;const h=b.h/b.w*width,img=graded(art.props,b.x,b.y,b.w,b.h,name+(spent?'~':''),toneAt(x),(FAR[name]||0)+(spent?.0:0),spent);
 drawShadow(x,ground,width*1.05,FAR[name]?.6:1);ctx.save();if(alpha<1)ctx.globalAlpha=alpha;ctx.translate(Math.round(x),Math.round(ground));if(flip)ctx.scale(-1,1);ctx.imageSmoothingEnabled=smoothFor(b.w/width);const sh=b.h*keep;ctx.drawImage(img,0,b.h-sh,b.w,sh,-width/2,-h*keep,width,h*keep);ctx.restore();ctx.imageSmoothingEnabled=false;}
// Sharp pixels when the source is enlarged; smoothing only when it is shrunk (prevents shimmering).
function smoothFor(srcPerUnit){return srcPerUnit/scale>.9;}
function propTint(name,color){const key=name+color;if(rendered[key])return rendered[key];const b=propLayout[name];return rendered[key]=tinted(art.props,b.x,b.y,b.w,b.h,color);}
function tinted(src,sx,sy,w,h,color){const c=document.createElement('canvas');c.width=w;c.height=h;const g=c.getContext('2d');g.drawImage(src,sx,sy,w,h,0,0,w,h);g.globalCompositeOperation='source-atop';g.fillStyle=color;g.fillRect(0,0,w,h);return c;}
function rect(x,y,w,h,color){ctx.fillStyle=color;ctx.fillRect(Math.round(x),Math.round(y),w,h);}
// One draw routine for every mutant: walk, red wind-up glow with a "!" marker, lunge, hit flash, sinking when beaten.
// Mutant frames (mobs.webp): walk x4, idle, wind-up, attack, hit. Each kind is one block, graded per scene light.
const MOB_ART={crawler:'crawler',shellback:'salamander',stoneback:'armadillo',deer:'deer'};
function mobArt(n,tone){const b=mobLayout[n].box;return graded(art.mobs,b[0],b[1],b[2],b[3],'mob-'+n,tone);}
function mobTint(n,color){const key='mob-'+n+color;if(rendered[key])return rendered[key];const b=mobLayout[n].box;return rendered[key]=tinted(art.mobs,b[0],b[1],b[2],b[3],color);}
function mobFrame(m){if(m.st==='dead'||m.flash>0||m.st==='stagger')return 7;if(m.st==='windup')return 5;if(m.st==='lunge')return 6;
 if(m.st==='recover')return m.kind==='deer'?7:4;   // the stag stands dazed after a charge: that is the opening to hit it
 if(m.role==='raider'&&m.goal!==undefined&&Math.abs(m.x-m.goal)<=3)return m.bite>2.2?6:4;
 return m.st==='patrol'||m.st==='chase'?Math.floor(m.walk)%4:4;}
function drawMob(m){const P=KIND[m.kind];if(m.x<camera.x-P.width||m.x>camera.x+VW+P.width)return;
 const sink=m.st==='dead'?Math.round(P.height*(1-m.dying/.9)):0,wind=m.st==='windup',jit=wind&&Math.floor(now*30)%2?1:0,x=Math.round(m.x)+jit;
 ctx.save();if(sink){ctx.beginPath();ctx.rect(x-P.width,m.gy-P.height-30,P.width*2,P.height+31);ctx.clip();}
 const n=MOB_ART[m.kind],L=art.mobs&&mobLayout[n];
 if(L){const fi=mobFrame(m),f=L.frames[fi],b=L.box,kk=P.width/L.walk*(m.role==='raider'?.9:1),sx=f.x-b[0],sy=f.y-b[1];
  if(!sink)drawShadow(x,m.gy+1,P.width*.85);ctx.translate(x+(m.st==='lunge'?m.dir*3:0),m.gy+1+sink);if(m.face>0)ctx.scale(-1,1);ctx.imageSmoothingEnabled=smoothFor(1/kk);
  // The armadillo's attack frame is a ball: roll it about its centre as it travels.
  if(n==='armadillo'&&fi===6){const r=f.h*kk/2;ctx.translate(0,-r);ctx.rotate(-(m.x*m.face)/r);ctx.translate(0,r);}
  const dx=-f.ax*kk,dy=-f.fy*kk,dw=f.w*kk,dh=f.h*kk;ctx.drawImage(mobArt(n,toneAt(m.x)),sx,sy,f.w,f.h,dx,dy,dw,dh);
  const over=m.flash>0&&prefs.effects?mobTint(n,'#fff6e2'):wind&&Math.floor(now*10)%2?mobTint(n,'#ff5a3c'):null;if(over){ctx.globalAlpha=.55;ctx.drawImage(over,sx,sy,f.w,f.h,dx,dy,dw,dh);}ctx.imageSmoothingEnabled=false;}
 else if(P.sprite&&art.props&&propLayout[P.sprite]){
  // Single generated pose, animated in code: stride bob, crouch on wind-up, lean into the lunge. Sprites face left.
  const b=propLayout[P.sprite],w=P.width,h=b.h/b.w*w,moving=m.st==='patrol'||m.st==='chase',bob=moving?Math.round(Math.abs(Math.sin(m.walk*1.6))*-2):0,lean=m.st==='lunge'?-.09:m.st==='stagger'?.06:0,sq=wind?.94:1;
  if(!sink)drawShadow(x,m.gy+1,w*.9);const img=graded(art.props,b.x,b.y,b.w,b.h,P.sprite,toneAt(m.x));ctx.translate(x+(m.st==='lunge'?m.dir*4:0),m.gy+1+sink+bob);if(m.face>0)ctx.scale(-1,1);ctx.rotate(lean);ctx.scale(1/sq*.98+.02,sq);ctx.imageSmoothingEnabled=true;ctx.drawImage(img,0,0,b.w,b.h,-w/2,-h,w,h);
  const over=m.flash>0&&prefs.effects?propTint(P.sprite,'#fff6e2'):wind&&Math.floor(now*10)%2?propTint(P.sprite,'#ff5a3c'):null;if(over){ctx.globalAlpha=.6;ctx.drawImage(over,0,0,b.w,b.h,-w/2,-h,w,h);}ctx.imageSmoothingEnabled=false;}
 else if(m.kind!=='crawler'&&rendered.shellback){const sb=m.kind==='stoneback'?rendered.stoneback:rendered.shellback,red=m.kind==='stoneback'?rendered.stoneRed:rendered.shellRed,f=m.flash>0&&prefs.effects?5:m.st==='lunge'?4:m.st==='patrol'||m.st==='chase'?Math.floor(m.walk)%4:0;ctx.translate(x,m.gy+1+sink);ctx.scale(m.face*1.3,1.3);ctx.drawImage(sb.canvas,f*sb.w,0,sb.w,sb.h,-sb.w/2,-sb.h,sb.w,sb.h);if(wind&&red&&Math.floor(now*10)%2){ctx.globalAlpha=.55;ctx.drawImage(red,0,0,sb.w,sb.h,-sb.w/2,-sb.h,sb.w,sb.h);}}
 else{const a=atlases.objects?.[7];if(a){const w=m.role==='raider'?48:P.width,h=a.h/a.w*w,lx=m.st==='lunge'?m.dir*3:0;ctx.translate(x+lx,m.gy+sink);if(m.face>0)ctx.scale(-1,1);ctx.drawImage(art.objects,a.x,a.y,a.w,a.h,-w/2,-h,w,h);
  const over=m.flash>0&&prefs.effects?rendered.mobWhite:wind&&Math.floor(now*10)%2?rendered.mobRed:null;if(over){ctx.globalAlpha=.7;ctx.drawImage(over,0,0,a.w,a.h,-w/2,-h,w,h);}}}
 ctx.restore();
 if(wind){const top=m.gy-P.height-16+Math.round(Math.sin(now*20));rect(m.x-2,top-9,4,9,'#ff6b4f');rect(m.x-2,top+2,4,3,'#ff6b4f');}
 if(m.hp>0&&m.hp<m.max){const by=m.gy-P.height-8;rect(m.x-15,by,30,3,'#120d09');rect(m.x-15,by,30*m.hp/m.max,2,m.kind==='shellback'?'#c99ae0':m.kind==='stoneback'?'#e0802c':m.kind==='deer'?'#9fe0ff':'#e6c48f');}}
// What the hero holds: a sword near enemies and while striking, the slingshot when shooting, a lit torch underground.
function stepLength(){const a=atlases.hero;if(!a)return 34;const k=72/atlases.heroMaxHeight,s=Math.max(...a.slice(0,4).map(f=>f.stride||0));return s?Math.max(22,s*.75*k):34;}
// Which tool a job needs: pickaxe poses are drawn into the sheet, an axe goes in the empty hand, low jobs are done kneeling.
function toolFor(tg){if(swingKind(tg))return tg.kind==='node'&&tg.node.type==='wood'?'axe':'pick';
 if(tg.kind==='bed'||tg.kind==='river'||tg.kind==='crate'||tg.kind==='node')return 'kneel';return ['panel','purify','clean','valve','fixFilter','startWater'].includes(tg.kind)?'wrench':'';}
function heldItem(working){if(player.climb)return null;if(working){const tl=toolFor(targetNow);return atlases.hero?.length>=27&&(tl==='axe'||tl==='wrench')?tl:null;}if(sling.anim>0)return 'sling';if(atk.anim>0||nearestMob(120))return 'sword';if((inMine()||inVault())&&state.built.torch&&torchOn)return 'torch';return null;}
function bakeWeapons(){if(rendered.sword||typeof document==='undefined'||!document.createElement)return;
 // Sword at 4 px per world unit, blade pointing up, grip centre at (14,104).
 const c=document.createElement('canvas');c.width=28;c.height=120;const g=c.getContext('2d');
 const poly=(pts,fill)=>{g.beginPath();g.moveTo(...pts[0]);for(const p of pts.slice(1))g.lineTo(...p);g.closePath();g.fillStyle=fill;g.fill();};
 poly([[14,0],[21,12],[21,86],[7,86],[7,12]],'#1a1d22');poly([[14,3],[19,13],[19,84],[9,84],[9,13]],'#c9d3dc');poly([[14,3],[14,84],[9,84],[9,13]],'#eef4f8');g.fillStyle='#8f9aa5';g.fillRect(13,14,2,68);
 g.fillStyle='#1a1d22';g.fillRect(1,84,26,9);g.fillStyle='#d9a441';g.fillRect(3,86,22,5);g.fillStyle='#ffe08a';g.fillRect(3,86,22,1);
 g.fillStyle='#1a1d22';g.fillRect(9,93,10,20);g.fillStyle='#6b3f22';g.fillRect(11,93,6,18);g.fillStyle='#8c5a33';for(let y=94;y<111;y+=4)g.fillRect(11,y,6,2);
 g.fillStyle='#1a1d22';g.fillRect(8,110,12,10);g.fillStyle='#d9a441';g.fillRect(10,112,8,6);g.fillStyle='#ffe08a';g.fillRect(10,112,3,2);rendered.sword=c;
 // Slingshot: Y fork with a rubber band, grip centre at (14,46).
 const l=document.createElement('canvas');l.width=28;l.height=56;const q=l.getContext('2d');q.lineCap='round';q.strokeStyle='#1a120c';q.lineWidth=7;q.beginPath();q.moveTo(14,54);q.lineTo(14,30);q.lineTo(5,6);q.moveTo(14,30);q.lineTo(23,6);q.stroke();
 q.strokeStyle='#8c5a33';q.lineWidth=4;q.stroke();q.strokeStyle='#c7473a';q.lineWidth=2;q.beginPath();q.moveTo(5,7);q.lineTo(14,18);q.lineTo(23,7);q.stroke();rendered.sling=l;}
// Angle of the sword (0 = blade up, positive = forward) through wind-up and strike.
function swordAngle(){if(atk.anim<=0)return .45;const heavy=atk.heavy?1.25:1;if(atk.anim>.14){const p=(.22-atk.anim)/.08;return .45-p*2.35*heavy;}const p=1-atk.anim/.14,e=1-(1-p)*(1-p);return -1.9*heavy+e*(3.9*heavy);}
function heroRed(){const k='heroRed-'+heroLoaded;return rendered[k]||(rendered[k]=tinted(art.hero,0,0,art.hero.width,art.hero.height,'#ff4630'));}
// Axe through a chop: raised back on the wind-up, driven forward-down at contact, then lowered.
function axeAngle(){const p=swing%1;if(p<CONTACT)return .6-(p/CONTACT)*2.5;if(p<.82)return 2.1;return 2.1-(p-.82)/.18*.9;}
function drawHeld(item,a,k){const hx=-a.anchor*k+a.hand[0]*k,hy=-(a.foot??a.h)*k+a.hand[1]*k;ctx.save();ctx.translate(hx,hy);ctx.imageSmoothingEnabled=true;
 const L=art.held&&heldLayout[item==='sling'?'sling':item];
 if(L){const sc=L.len/L.h,ang=item==='sword'?swordAngle():item==='sling'?1.15:item==='torch'?.25:item==='axe'?axeAngle():item==='wrench'?.9+Math.sin(now*9)*.25:0;
  ctx.rotate(ang);ctx.drawImage(art.held,L.x,L.y,L.w,L.h,-L.gx*sc,-L.gy*sc,L.w*sc,L.h*sc);
  if(item==='torch'){const fl=Math.floor(now*14)%3,top=-L.gy*sc;ctx.globalAlpha=.55;rect(-2,top-1-fl,4,3+fl,'#ffe27a');ctx.globalAlpha=1;}}
 else if(item==='sword'&&rendered.sword){ctx.rotate(swordAngle());ctx.drawImage(rendered.sword,-3.5,-26,7,30);}
 else if(item==='sling'&&rendered.sling){ctx.rotate(1.15);ctx.drawImage(rendered.sling,-3.5,-11.5,7,14);}
 else if(item==='torch'){ctx.rotate(.25);if(art.items&&itemLayout.index.torch!==undefined){const i=itemLayout.index.torch,c=itemLayout.cell;ctx.drawImage(art.items,(i%itemLayout.cols)*c,Math.floor(i/itemLayout.cols)*c,c,c,-8,-20,16,24);}else{rect(-1,-12,3,14,'#6b4a2c');}
  const fl=Math.floor(now*14)%3;ctx.globalAlpha=.9;rect(-2,-24-fl,5,6+fl,'#ff9a2e');rect(-1,-26-fl,3,4,'#ffe27a');ctx.globalAlpha=1;}
 ctx.restore();ctx.imageSmoothingEnabled=false;}
// Full hero sheet (27 frames): 0-3 walk, 4-7 run, 8-11 climb, 12 idle, 13 wind-up, 14 strike, 15 jump, 16 hit, 17 falling back,
// 18 lying, 19 kneel, 20 crouch, 21 take-off, 22 falling, 23 landing, 24-26 pickaxe idle / wind-up / strike.
function heroFrame(working){const step=Math.floor(player.walk),p=swing%1;
 if(downTime)return 1.6-downTime<.3?17:18;if(player.getup>0)return 19;if(player.hitT>0)return 16;
 if(player.climb)return 8+step%4;if(!player.ground)return player.vy<-90?21:player.vy>90?22:15;
 if(atk.anim>0)return atk.anim>.14?13:14;if(sling.anim>0)return 14;
 if(working){const tl=toolFor(targetNow);if(tl==='pick')return p<CONTACT?25:p<.82?26:24;if(tl==='axe')return p<CONTACT?13:p<.82?14:12;return tl==='kneel'?19:12;}
 if(player.land>0)return 23;if(player.vx)return (player.running?4:0)+step%4;return 12;}
// Items stay in hand only in poses whose fist is where the item belongs (not while hit, fallen, kneeling or landing).
const HOLDS=f=>f<=15||f===21;
function drawHero(){const working=(held.action||keys.KeyE||autoAction)&&targetNow,full=atlases.hero?.length>=27;let item=heldItem(working),ext=!full&&atlases.hero?.length>=16;
 if(player.ground&&!player.climb)drawShadow(renderX,groundY()+1,30,.8);
 if(player.hurt>0&&player.hurt<1&&!downTime&&!player.getup&&Math.floor(now*12)%2===0)return;
 const walkF=i=>ext&&player.running?4+i%4:i%4,step=Math.floor(player.walk);
 // Climbing: a climb row in an extended sheet, otherwise alternate mirrored strides while hands-and-feet bob on the rungs.
 let frame,mirror=1,bob=0,lean=0;
 if(full){frame=heroFrame(working);if(!HOLDS(frame))item=null;}
 else if(player.climb){if(ext)frame=8+step%4;else{frame=step%2?7:3;mirror=step%2?-1:1;bob=Math.round(Math.sin(player.walk*Math.PI)*2);}}
 else if(!player.ground)frame=ext?15:7;
 else if(atk.anim>0)frame=ext?(atk.anim>.14?13:14):3;
 else if(sling.anim>0)frame=ext?14:3;
 else if(working)frame=swingKind(targetNow)?(swing%1<CONTACT?5:swing%1<.82?6:4):4;
 else if(player.vx)frame=walkF(step);
 else frame=item?(ext?12:3):(ext?12:4);
 const a=atlases.hero?.[frame];if(!a)return;
 const k=72/atlases.heroMaxHeight;if(working&&!swingKind(targetNow)&&frame!==19)bob=Math.round(Math.sin(now*9));if(player.running&&player.ground)lean=.07;
 // Hurt: lean back from the hit for a moment. Defeat: fall to the side (temporary until a fall frame exists).
 if(player.hurt>.95&&!downTime&&!full)lean=-.16;let fall=downTime&&!full?Math.min(1,(1.6-downTime)/.35):0;
 const lunge=atk.anim>0&&atk.anim<=.14?player.face*3:0,face=player.face*mirror,img=graded(art.hero,0,0,art.hero.width,art.hero.height,'hero-'+heroLoaded,toneAt(player.x));
 const fy=(a.foot??a.h)*k;ctx.save();ctx.translate(Math.round(renderX)+lunge,Math.round(renderY+player.h)+bob);ctx.scale(face*(1+squash*.6),1-squash);ctx.rotate(lean+(atk.anim>0&&atk.anim<=.14?.05:0)-fall*1.45);
 ctx.imageSmoothingEnabled=true;ctx.drawImage(img,a.x,a.y,a.w,a.h,-a.anchor*k,-fy,a.w*k,a.h*k);if(player.hurt>1&&!downTime&&!player.getup&&prefs.effects){ctx.globalAlpha=.45;ctx.drawImage(heroRed(),a.x,a.y,a.w,a.h,-a.anchor*k,-fy,a.w*k,a.h*k);ctx.globalAlpha=1;}if(item&&a.hand&&!downTime)drawHeld(item,a,k-0);ctx.restore();ctx.imageSmoothingEnabled=false;
 // Rails in front of the climber make it read as being on the ladder, not floating beside it.
 if(player.climb){const x=Math.round(player.climb.x),y=Math.round(renderY);for(const dx of [-10,8]){rect(x+dx,y-6,3,player.h+10,'#5b3b22');rect(x+dx,y-6,1,player.h+10,'#8c6136');}for(let ry=y+((player.walk*9)%9)-6;ry<y+player.h;ry+=9)rect(x-9,Math.round(ry),18,2,'#8c6136');}}
// Slash trail: a tapered bright arc in front of the hero; wider on the heavy third hit.
function drawSlash(){if(!slash)return;const p=slash.life/.14,r=slash.heavy?30:24,cx=slash.x+slash.face*8,cy=slash.y;ctx.save();ctx.translate(cx,cy);ctx.scale(slash.face,1);ctx.lineCap='round';
 for(const [w,c,a] of [[slash.heavy?7:5,'#fff2c4',.35*p],[slash.heavy?3:2,'#ffffff',.9*p]]){ctx.globalAlpha=a;ctx.strokeStyle=c;ctx.lineWidth=w;ctx.beginPath();ctx.arc(0,0,r,-1.25,.95-(1-p)*.5);ctx.stroke();}ctx.restore();}
// Ground line of each generated background as a fraction of its height.
const FILTER_X=382,GREENHOUSE_X=468;
const FOREST={x:1600,w:800,ground:.72*768/724},CITY_GROUND=.775,GARDEN_GROUND=.73,VAULT_GROUND=.735,MINE_WALK=507;
function bakeGate(){const gate=document.createElement('canvas');gate.width=300;gate.height=54;const g=gate.getContext('2d');g.fillStyle='#2a1b10';g.fillRect(0,0,300,54);g.fillStyle='#5b3b22';g.fillRect(4,4,292,46);g.fillStyle='#f1e4c3';g.font='600 26px "Pixelify Sans", system-ui';g.textAlign='center';g.fillText(t('gate'),150,36);rendered.gate=gate;dirtyFrame=true;}
// After the greenhouse is saved the ruined city is replaced by the restored garden.
function bakeBackground(){const img=state.completed&&art.garden?art.garden:art.environment,gf=img===art.garden?GARDEN_GROUND:CITY_GROUND;rendered.cityArt=img;rendered.citySky=topColor(img);const h=1600/img.width*img.height;
 // Only small helpers are baked now; the painted backgrounds are drawn directly at full resolution.
 const c=document.createElement('canvas');c.width=1;c.height=1;const g=c.getContext('2d');
 g.fillStyle='#1d2d3c';g.fillRect(FOREST.x,0,FOREST.w,800);
 rendered.world=c;rendered.top=GROUND-400;rendered.artBottom=GROUND+h*(1-gf)-2;
 // Metro entrance fallback (the generated metro sprite is drawn over it when loaded).
 if(!art.props){const x=METRO,y=400;g.fillStyle='#1b2226';g.fillRect(x-34,y-66,68,66);g.fillStyle='#050608';g.fillRect(x-26,y-56,52,56);for(let i=0;i<6;i++){g.fillStyle=i%2?'#2c3236':'#3a4247';g.fillRect(x-24+i*2,y-10-i*7,48-i*4,4);}
  g.fillStyle='#55626a';g.fillRect(x-34,y-66,68,4);g.fillRect(x-34,y-66,4,66);g.fillRect(x+30,y-66,4,66);g.fillStyle='#7b8a92';g.fillRect(x-34,y-66,68,1);
  g.fillStyle='#14100c';g.fillRect(x-13,y-96,26,26);g.fillStyle='#2a62b8';g.fillRect(x-11,y-94,22,22);g.fillStyle='#ffffff';g.fillRect(x-7,y-90,3,14);g.fillRect(x+4,y-90,3,14);g.fillRect(x-4,y-88,2,4);g.fillRect(x+2,y-88,2,4);g.fillRect(x-2,y-86,4,3);g.fillStyle='#3b4247';g.fillRect(x-1,y-70,2,4);}
 if(art.forest)bakeForest();
 const detail=document.createElement('canvas');detail.width=WORLD;detail.height=240;const d=detail.getContext('2d');d.fillStyle='#203036';d.fillRect(0,0,WORLD,240);for(let x=0;x<WORLD;x+=16)for(let y=0;y<240;y+=16){d.fillStyle=(x+y)%48?'#344039':'#3b463b';d.fillRect(x+2,y+3,8,2);d.fillStyle='#17292c';d.fillRect(x,y+15,16,1);}rendered.earth=detail;
 bakeGate();}
// The forest plate is painted into the already baked world once it arrives, so it never blocks the start or costs per-frame work.
function bakeForest(){const f=art.forest,fade=64,w=FOREST.w+fade,h=w/f.width*f.height,top=GROUND-h*FOREST.ground;
 // The plate overlaps the city by `fade` units and dissolves into it, so there is no hard seam at x1600.
 // The plate keeps the source resolution; only its left edge is faded so it dissolves into the city.
 const plate=document.createElement('canvas');plate.width=f.width;plate.height=f.height;const p=plate.getContext('2d');p.drawImage(f,0,0);const fs=fade/w*f.width;
 const mask=p.createLinearGradient(0,0,fs,0);mask.addColorStop(0,'rgba(0,0,0,0)');mask.addColorStop(1,'rgba(0,0,0,1)');p.globalCompositeOperation='destination-in';p.fillStyle=mask;p.fillRect(0,0,f.width,f.height);
 rendered.forestPlate={canvas:plate,x:FOREST.x-fade,y:top,w,h,fade,sky:topColor(f)};dirtyFrame=true;}
const hash=(x,y)=>{let h=(x*374761393+y*668265263)|0;h=(h^(h>>>13))*1274126177|0;return ((h^(h>>>16))>>>0)/4294967296;};
// The mine is painted once into a canvas: rock mass, carved galleries, timber, floors, ladders, lamps, daylight at the exit and a blue cave.
function bakeMine(){const M=MINEMAP,c=document.createElement('canvas');c.width=M.w;c.height=M.h;let g=c.getContext('2d');
 g.fillStyle='#16120f';g.fillRect(0,0,M.w,M.h);
 for(let y=0;y<M.h;y+=12)for(let x=-(Math.floor(y/12)%2)*12;x<M.w;x+=24){const v=hash(x,y);g.fillStyle=['#231d18','#2a231d','#1f1a16','#2e2620'][Math.floor(v*4)];g.fillRect(x+1,y+1,22,10);g.fillStyle='#3a3129';g.fillRect(x+1,y+1,22,1);g.fillStyle='#110e0b';g.fillRect(x+1,y+10,22,1);if(v>.93){g.fillStyle='#8a4a1c';g.fillRect(x+6+v*10,y+4,2,2);}}
 // With painted walls the props (ladders, lamps, exit) go to a separate front layer drawn over them.
 if(art.mineWall){const f=document.createElement('canvas');f.width=M.w;f.height=M.h;rendered.mineFront=f;g=f.getContext('2d');}
 if(!art.mineWall)M.floors.forEach((F,fi)=>{const top=F.y-132;
  for(let y=top;y<F.y;y+=8)for(let x=F.x1-28-(Math.floor(y/8)%2)*8;x<F.x2+28;x+=16){const v=hash(x,y+fi);const cave=fi===2&&x>1020;g.fillStyle=cave?(v<.5?'#1d2a36':'#22313f'):(v<.5?'#3b302a':'#342a24');g.fillRect(x,y,15,7);g.fillStyle=cave?'#2d4152':'#46392f';g.fillRect(x,y,15,1);}
  const grad=g.createLinearGradient(0,top,0,F.y);grad.addColorStop(0,'rgba(10,8,6,.75)');grad.addColorStop(.5,'rgba(10,8,6,.15)');grad.addColorStop(1,'rgba(10,8,6,.35)');g.fillStyle=grad;g.fillRect(F.x1-28,top,F.x2-F.x1+56,F.y-top);
  for(let x=F.x1-28;x<F.x2+28;x+=5){const h=3+Math.floor(hash(x,F.y)*9);g.fillStyle='#16120f';g.fillRect(x,top,5,h);}
  if(fi===2)for(let x=1040;x<F.x2;x+=34){const h=10+Math.floor(hash(x,7)*22);for(let i=0;i<h;i+=2){const w=Math.max(1,6-Math.floor(i/4));g.fillStyle=i<4?'#3b5568':'#2b3f50';g.fillRect(x-w/2,top+8+i,w,2);}g.fillStyle='#7fc8d8';g.fillRect(x,top+8+h,1,2);}
  for(let x=F.x1+60;x<F.x2-10;x+=150){if(fi===2&&x>1020)continue;g.fillStyle='#3d2717';g.fillRect(x,top+6,9,F.y-top-6);g.fillStyle='#6b4a2c';g.fillRect(x+1,top+6,2,F.y-top-6);g.fillStyle='#3d2717';g.fillRect(x-22,top+6,54,9);g.fillStyle='#7a5636';g.fillRect(x-22,top+6,54,2);}
  g.fillStyle='#463b33';g.fillRect(F.x1-28,F.y,F.x2-F.x1+56,16);g.fillStyle='#82715f';g.fillRect(F.x1-28,F.y,F.x2-F.x1+56,2);g.fillStyle='#5d4f43';g.fillRect(F.x1-28,F.y+2,F.x2-F.x1+56,1);for(let x=F.x1-28;x<F.x2+28;x+=18){g.fillStyle='#2b241f';g.fillRect(x,F.y+3,1,13);}
  if(fi===1){g.fillStyle='#5b5650';g.fillRect(F.x1,F.y-3,F.x2-F.x1,1);g.fillRect(F.x1,F.y-6,F.x2-F.x1,1);for(let x=F.x1;x<F.x2;x+=12){g.fillStyle='#4a3020';g.fillRect(x,F.y-2,8,2);}}});
 for(const l of M.ladders){const a=M.floors[l.a].y,b=M.floors[l.b].y;g.fillStyle='#0b0907';g.fillRect(l.x-13,a,26,16);g.fillStyle='#5b3b22';g.fillRect(l.x-10,a-34,3,b-a+34);g.fillRect(l.x+7,a-34,3,b-a+34);for(let y=a-28;y<b;y+=9){g.fillStyle='#8c6136';g.fillRect(l.x-9,y,18,2);}}
 {const F=M.floors[0],x=M.exit.x;const sh=g.createLinearGradient(0,0,0,F.y);sh.addColorStop(0,'#9fb3b0');sh.addColorStop(1,'rgba(159,179,176,.15)');g.fillStyle=sh;g.fillRect(x-30,0,48,F.y-40);for(let i=0;i<8;i++){g.fillStyle=i%2?'#4f4740':'#625850';g.fillRect(x-30+i*3,F.y-8-i*8,40-i*3,8);}}
 for(const [x,f] of M.lamps){const y=M.floors[f].y-104;g.fillStyle='#2a221c';g.fillRect(x-1,y-10,2,10);g.fillStyle='#3d3d3d';g.fillRect(x-4,y,8,11);g.fillStyle='#5a4a2a';g.fillRect(x-3,y+2,6,7);}
 {const p=M.panel,y=M.floors[p.f].y;g.fillStyle='#202a2e';g.fillRect(p.x-30,y-70,2,70);g.fillRect(p.x-30,y-70,60,2);}
 if(!art.props){const L=M.lift,y=M.floors[L.f].y;g.fillStyle='#0b0d0f';g.fillRect(L.x-20,y-74,40,74);for(let i=0;i<5;i++){g.fillStyle='#4a5258';g.fillRect(L.x-20+i*10,y-74,2,74);}g.fillStyle='#6f7a80';g.fillRect(L.x-22,y-76,44,3);g.fillRect(L.x-22,y-2,44,2);}
 rendered.mine=c;}
function lightBlob(){const c=document.createElement('canvas');c.width=c.height=128;const g=c.getContext('2d'),gr=g.createRadialGradient(64,64,0,64,64,64);gr.addColorStop(0,'rgba(0,0,0,1)');gr.addColorStop(.55,'rgba(0,0,0,.85)');gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.fillRect(0,0,128,128);return c;}
// Darkness at half resolution with holes cut for each light; it is upscaled smoothly so the edges stay soft.
function drawDarkness(){const lc=rendered.light||(rendered.light=document.createElement('canvas')),blob=rendered.blob||(rendered.blob=lightBlob());const w=Math.ceil(VW/2),h=Math.ceil(VH/2);if(lc.width!==w||lc.height!==h){lc.width=w;lc.height=h;}const g=lc.getContext('2d'),M=MINEMAP;
 g.globalCompositeOperation='source-over';g.globalAlpha=1;g.clearRect(0,0,w,h);g.fillStyle=state.mine.panel?'rgba(5,4,8,.45)':'rgba(4,4,7,.9)';g.fillRect(0,0,w,h);g.globalCompositeOperation='destination-out';
 const light=(x,y,r,a=1)=>{g.globalAlpha=a;g.drawImage(blob,(x-camera.x-r)/2,(y-camera.y-r)/2,r,r);};
 const flick=1+Math.sin(now*11)*.03+Math.sin(now*23)*.02,R=(state.built.torch&&torchOn?100:30)*perk('light',1)*flick;light(renderX,renderY+14,R);
 light(M.exit.x,M.floors[0].y-60,110,.85);
 M.ore.forEach((o,i)=>{if(!state.mine.ore[i])light(o.x,M.floors[o.f].y-16,34,.55);});
 if(state.mine.panel)for(const [x,f] of M.lamps)light(x,M.floors[f].y-98,120,.95);
 else{const p=M.panel;if(Math.floor(now*3)%2)light(p.x,M.floors[p.f].y-50,40,.5);}
 g.globalAlpha=1;ctx.imageSmoothingEnabled=true;ctx.drawImage(lc,0,0,w,h,0,0,w*2,h*2);ctx.imageSmoothingEnabled=false;}
function paintMine(){const M=MINEMAP;
 const cx=M.w<=VW?(M.w-VW)/2:Math.max(0,Math.min(M.w-VW,renderX-VW*.45)),cy=M.h<=VH?(M.h-VH)/2:Math.max(0,Math.min(M.h-VH,renderY+player.h-VH*.64));
 camera.x=Math.round(cx*scale)/scale;camera.y=Math.round(cy*scale)/scale;if(shake>0){const m=shake*14;camera.x+=Math.round((Math.random()-.5)*m*scale)/scale;camera.y+=Math.round((Math.random()-.5)*m*scale)/scale;}
 const layer=c=>{const sx=Math.max(0,Math.floor(camera.x)),sy=Math.max(0,Math.floor(camera.y)),sw=Math.min(Math.ceil(VW)+2,M.w-sx),sh=Math.min(Math.ceil(VH)+2,M.h-sy);if(sw>0&&sh>0)ctx.drawImage(c,sx,sy,sw,sh,sx-camera.x,sy-camera.y,sw,sh);};
 if(rendered.mine)layer(rendered.mine);
 if(art.mineWall&&rendered.mineFront){const k=240/MINE_WALK,ww=art.mineWall.width*k,wh=art.mineWall.height*k;ctx.imageSmoothingEnabled=true;
  M.floors.forEach((F,fi)=>{const top=F.y-240-camera.y;if(top>VH||top+wh<0)return;ctx.save();ctx.beginPath();ctx.rect(F.x1-34-camera.x,top,F.x2-F.x1+68,wh);ctx.clip();const cx=(F.x1+F.x2)/2-camera.x;ctx.translate(cx,top);if(fi===1)ctx.scale(-1,1);ctx.drawImage(art.mineWall,-ww/2,0,ww,wh);ctx.restore();
   const fade=rendered.mineFade||(rendered.mineFade=(()=>{const c=document.createElement('canvas');c.width=64;c.height=64;const g=c.getContext('2d'),gr=g.createLinearGradient(0,0,64,0);gr.addColorStop(0,'rgba(22,18,15,1)');gr.addColorStop(1,'rgba(22,18,15,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);return c;})());
   ctx.drawImage(fade,F.x1-34-camera.x,top,60,wh);ctx.save();ctx.translate(F.x2+34-camera.x,top);ctx.scale(-1,1);ctx.drawImage(fade,0,0,60,wh);ctx.restore();ctx.save();ctx.translate(F.x1-34-camera.x,top);ctx.rotate(Math.PI/2);ctx.scale(1,-1);ctx.drawImage(fade,0,0,36,F.x2-F.x1+68);ctx.restore();});
  ctx.imageSmoothingEnabled=false;layer(rendered.mineFront);}
 ctx.save();ctx.translate(-camera.x,-camera.y);
 M.ore.forEach((o,i)=>{const y=M.floors[o.f].y,wob=nodeShake['ore-'+i]>0?Math.round(Math.sin(now*80)*1.5):0,x=o.x+wob;if(state.mine.ore[i]){if(art.props)drawProp('oreSpent',x,y+2,46);return;}if(art.props)return drawProp('ore',x,y+2,46);rect(x-16,y-26,32,26,'#3b332c');rect(x-14,y-28,26,4,'#4b4239');rect(x-16,y-26,2,26,'#5a5048');for(const [dx,dy,c] of [[-9,-20,'#e0802c'],[-2,-14,'#ffb36b'],[5,-22,'#c4621e'],[8,-9,'#e0802c'],[-11,-8,'#ffb36b'],[1,-6,'#c4621e']])rect(x+dx,y+dy,4,3,c);});
 M.crates.forEach((c,i)=>{const open=state.mine.crates[i];art.props?drawProp(open?'crateOpen':'crate',c.x,M.floors[c.f].y+1,36):open||drawObject(2,c.x,M.floors[c.f].y,46);});
 drawProp('lift',M.lift.x-6,M.floors[M.lift.f].y+2,88);
 {const p=M.panel,y=M.floors[p.f].y,on=state.mine.panel;rect(p.x-12,y-62,24,34,'#46535a');rect(p.x-10,y-60,20,30,'#2c363b');rect(p.x-12,y-62,24,2,'#6f7f86');rect(p.x-6,y-56,4,4,on?'#6ad04a':'#e2483c');rect(p.x+2,y-56,4,4,on?'#6ad04a':'#5a2a24');rect(p.x-1,y-28,2,28,'#2c2c2c');if(!on&&Math.floor(now*7)%5===0){rect(p.x+8+Math.random()*6,y-40+Math.random()*10,2,2,'#ffe27a');}if(!on)for(let i=0;i<3;i++)rect(p.x-6+i*5,y-46,3,10,'#1a1f22');}
 for(const [x,f] of M.lamps){const y=M.floors[f].y-104;rect(x-2,y+3,4,5,state.mine.panel?'#ffe9a0':'#5a4a2a');}
 for(const m of mobs)drawMob(m);
 drawHero();drawSlash();
 for(const s2 of shots){rect(s2.x-1,s2.y-1,3,3,'#d8d2c0');}
 for(const e of effects)rect(e.x,e.y,2,2,e.color);
 drawFloats();drawTargetMarker();
 ctx.restore();if(rendered.mine)drawDarkness();dirtyFrame=false;}
function drawFloats(){if(!floats.length)return;ctx.font='600 8px "Pixelify Sans", system-ui';ctx.textAlign='center';for(const f of floats){ctx.globalAlpha=Math.min(1,f.life*2);ctx.fillStyle='#14100c';ctx.fillText(f.text,f.x+.6,f.y+.6);ctx.fillStyle='#f3e3b4';ctx.fillText(f.text,f.x,f.y);}ctx.globalAlpha=1;ctx.textAlign='start';}
function drawTargetMarker(){if(!targetNow)return;const gy=groundY(),tx=targetNow.x,ty=gy-74;rect(tx-4,ty+Math.sin(now*2)*2,8,2,'#f2c14e');
 // Gold corner brackets around the object the action button will use.
 if(targetNow.w){const w=targetNow.w/2+3,b=gy-(targetNow.lift||0),tp=b-targetNow.h-3,c='#f2c14e',p=Math.round(Math.sin(now*4));for(const [x,y,sx,sy] of [[tx-w-p,tp-p,1,1],[tx+w+p,tp-p,-1,1],[tx-w-p,b+2+p,1,-1],[tx+w+p,b+2+p,-1,-1]]){rect(Math.min(x,x+sx*6),y-(sy<0?1:0),6,1,c);rect(x-(sx<0?1:0),Math.min(y,y+sy*6),1,6,c);}}if(interaction.value>0){rect(tx-24,gy-66,48,4,'#14100c');rect(tx-24,gy-66,48*Math.min(1,interaction.value/targetNow.time),3,'#f2c14e');}}
function bakeVault(){if(!art.vault)return;rendered.vaultSky=topColor(art.vault);rendered.vault=true;dirtyFrame=true;}
// Backgrounds are drawn straight from the source image each frame (only the visible slice), so they keep full detail.
function blit(img,wx,wy,ww,wh){ctx.imageSmoothingEnabled=smoothFor(img.width/ww);const x0=Math.max(wx,camera.x),x1=Math.min(wx+ww,camera.x+VW),y0=Math.max(wy,camera.y),y1=Math.min(wy+wh,camera.y+VH);if(x1<=x0||y1<=y0)return;const kx=img.width/ww,ky=img.height/wh;ctx.drawImage(img,(x0-wx)*kx,(y0-wy)*ky,(x1-x0)*kx,(y1-y0)*ky,x0-camera.x,y0-camera.y,x1-x0,y1-y0);}
function warmImage(img){try{const c=document.createElement('canvas');c.width=c.height=2;c.getContext('2d').drawImage(img,0,0,2,2);}catch{}}
function topColor(img){try{const c=document.createElement('canvas');c.width=c.height=1;const g=c.getContext('2d');g.drawImage(img,0,0,img.width,6,0,0,1,1);const d=g.getImageData(0,0,1,1).data;return `rgb(${d[0]},${d[1]},${d[2]})`;}catch{return '#1c1630';}}
function drawEarth(from){if(!rendered.earth)return;const gy=from-camera.y;if(gy>=VH)return;const sx=Math.max(0,Math.floor(camera.x)),sw=Math.min(Math.ceil(VW)+2,WORLD-sx),eh=Math.min(240,Math.ceil(VH-gy)+1);if(eh>0&&sw>0)ctx.drawImage(rendered.earth,sx,0,sw,eh,sx-camera.x,gy,sw,eh);}
function paintVault(){const v=state.seedvault,targetX=Math.max(0,Math.min(VAULT.w-VW,renderX-VW*.42));camera.x=Math.round(targetX*scale)/scale;camera.y=Math.round((GROUND-VH*(VW>VH?.76:.73))*scale)/scale;if(shake>0){const m=shake*14;camera.x+=Math.round((Math.random()-.5)*m*scale)/scale;camera.y+=Math.round((Math.random()-.5)*m*scale)/scale;}
 if(art.vault){const h=VAULT.w/art.vault.width*art.vault.height,top=GROUND-h*VAULT_GROUND;ctx.fillStyle=rendered.vaultSky||'#0d1620';ctx.fillRect(0,0,VW,VH);drawEarth(top+h-4);ctx.imageSmoothingEnabled=true;blit(art.vault,0,top,VAULT.w,h);ctx.imageSmoothingEnabled=false;}
 ctx.save();ctx.translate(-camera.x,-camera.y);
 drawProp('lift',VAULT.exit,GROUND+2,88);
 // Capsules glow on their shelves until taken; the opened main door spills warm light.
 VAULT.caps.forEach((x,i)=>{if(v.caps[i])return;const y=GROUND-6+Math.round(Math.sin(now*2+i)*1.5);ctx.globalAlpha=.35+.2*Math.sin(now*3+i);rect(x-10,y-26,20,24,'#9fe0ff');ctx.globalAlpha=1;drawItem('capsule',x,y,22);});
 if(v.door){ctx.globalAlpha=.55+.1*Math.sin(now*2);rect(VAULT.door-40,GROUND-90,80,90,'#ffe6a0');ctx.globalAlpha=1;}
 for(const m of mobs)drawMob(m);
 drawHero();drawSlash();
 for(const s2 of shots)rect(s2.x-1,s2.y-1,3,3,'#d8d2c0');
 for(const e of effects)rect(e.x,e.y,2,2,e.color);
 if(Math.floor(now*4)%2===0)for(let i=0;i<6;i++){const fx=(camera.x+((i*137+now*14)%VW)),fy=camera.y+((i*71+now*22)%VH);rect(fx,fy,1,1,'#e6f6ff');}
 drawFloats();drawTargetMarker();ctx.restore();dirtyFrame=false;}
function drawItem(id,x,ground,size){if(!art.items)return;const i=itemLayout.index[id];if(i===undefined)return;const c=itemLayout.cell;ctx.imageSmoothingEnabled=true;ctx.drawImage(art.items,(i%itemLayout.cols)*c,Math.floor(i/itemLayout.cols)*c,c,c,Math.round(x-size/2),Math.round(ground-size),size,size);ctx.imageSmoothingEnabled=false;}
function paint(){ctx.setTransform(scale,0,0,scale,0,0);if(inBunker()){ctx.imageSmoothingEnabled=false;ctx.fillStyle='#0d1012';ctx.fillRect(0,0,VW,VH);paintBunker();return;}if(inVault()){ctx.imageSmoothingEnabled=false;ctx.fillStyle='#0d1620';ctx.fillRect(0,0,VW,VH);paintVault();return;}if(inMine()){ctx.imageSmoothingEnabled=false;ctx.fillStyle='#0b0907';ctx.fillRect(0,0,VW,VH);paintMine();return;}ctx.imageSmoothingEnabled=false;ctx.fillStyle='#223945';ctx.fillRect(0,0,VW,VH);
 // Camera snaps to device pixels, not world units, so scrolling stays even at any canvas scale.
 const targetX=Math.max(0,Math.min(WORLD-VW,renderX-VW*.42));camera.x=Math.round(targetX*scale)/scale;camera.y=Math.round((GROUND-VH*(VW>VH?.76:.73))*scale)/scale;if(shake>0){const m=shake*14;camera.x+=Math.round((Math.random()-.5)*m*scale)/scale;camera.y+=Math.round((Math.random()-.5)*m*scale)/scale;}
 if(rendered.cityArt){const img=rendered.cityArt,gf=img===art.garden?GARDEN_GROUND:CITY_GROUND,h=1600/img.width*img.height,top=GROUND-h*gf;
  ctx.fillStyle=rendered.citySky;ctx.fillRect(0,0,VW,VH);
  if(rendered.forestPlate){const P=rendered.forestPlate;ctx.fillStyle=P.sky;const fx=P.x-camera.x;if(fx<VW)ctx.fillRect(Math.max(0,fx+P.fade),0,VW,Math.max(0,P.y-camera.y+2));}
  drawEarth(top+h-4);ctx.imageSmoothingEnabled=true;blit(img,0,top,1600,h);
  if(rendered.forestPlate){const P=rendered.forestPlate;blit(P.canvas,P.x,P.y,P.w,P.h);}ctx.imageSmoothingEnabled=false;}
 ctx.save();ctx.translate(-camera.x,-camera.y);
 if(!state.completed&&camera.x+VW>1510){rect(1545,GROUND-55,5,55,'#8e7d68');if(rendered.gate){ctx.imageSmoothingEnabled=true;ctx.drawImage(rendered.gate,1495,GROUND-54,100,18);ctx.imageSmoothingEnabled=false;}}
 for(let i=0;i<3;i++){const x=forestPatches[i];if(x<camera.x-90||x>camera.x+VW+90)continue;const clean=state.forest[i];rect(x-47,GROUND-5,94,7,clean?'#779968':'#785983');if(clean&&art.props){drawProp('soilClean',x-22,GROUND+2,50);drawProp('soilClean',x+14,GROUND+2,44,true);}else for(let j=0;j<8;j++){const xx=x-39+j*11,h=12+j%3*7;rect(xx,GROUND-h,3,h,clean?'#98bc7a':'#9774aa');rect(xx-3,GROUND-h,9,4,clean?'#c5df98':'#b090c6');}if(clean){art.props?drawProp('fox',x+24,GROUND+1,29,Math.sin(now*.7+i)<0):drawObject(6,x+24,GROUND,32);for(let j=0;j<3;j++){const bx=x-20+Math.sin(now*.9+j*2+i)*26,by=GROUND-30+Math.sin(now*1.7+j)*9;rect(bx-2,by,2,2,'#f7d36a');rect(bx,by,2,2,'#9fe0ff');}}
  else if(interaction.key==='clean-'+i)drawProp('purifier',x-34,GROUND+2,52);}
 rect(camera.x,GROUND,Math.min(VW,WORLD-camera.x),2,'#8b9668');
 // The last greenhouse stands behind the three beds; equipment appears at the shelter as it is built.
 // Sizes follow the hero (68 units ≈ 1.75 m): doorways and cages are taller than a person, a workbench is waist-high.
 drawProp('greenhouse',GREENHOUSE_X,GROUND+3,300,false,1,1,inPrologue(state));drawProp('metro',METRO,GROUND+4,124);
 for(const n of nodes){if(n.x<camera.x-70||n.x>camera.x+VW+70)continue;const done=state.harvested[n.id],nx=n.x+(nodeShake[n.id]>0?Math.sin(now*80)*1.6:0);
  // What remains after the job: a cut stump, an opened crate, a pile of rubble.
  if(art.props&&n.type==='wood')done?drawProp('stumpCut',nx,GROUND+3,44):drawProp('stump',nx,GROUND+3,50);
  else if(art.props&&n.type==='scrap')drawProp(done?'crateOpen':'crate',nx,GROUND+2,36);
  else if(art.props)done?drawProp('rubble',nx,GROUND+2,38):drawProp('boulder',nx,GROUND+2,44);
  else if(!done)drawObject(n.art,nx,GROUND,n.type==='stone'?44:56);else{rect(nx-12,GROUND-4,9,4,'#5d5850');rect(nx+2,GROUND-3,7,3,'#4a463f');rect(nx-3,GROUND-6,6,6,'#6b665d');}}
 if(art.props){if(state.built.purifier&&!interaction.key.startsWith('clean'))drawProp('purifier',196,GROUND+2,52);if(state.built.bench)drawProp('workbench',262,GROUND+2,66);
  if(state.built.generator){drawProp('generator',326,GROUND+2,46);if(Math.floor(now*4)%2){rect(318,GROUND-26,3,2,'#ffd35a');}}if(state.built.filter){drawProp('filter',FILTER_X,GROUND+2,46);if(interaction.key==='purify')for(let i=0;i<3;i++)rect(FILTER_X+14,GROUND-22+((now*40+i*7)%16),1,2,'#9fd6e0');}else if(state.story)drawBrokenFilter();if(state.story)drawStation();}
 else{if(state.built.bench)drawObject(5,265,GROUND,72);if(state.built.filter)drawObject(4,345,GROUND,48);if(state.built.generator){rect(300,GROUND-24,16,23,'#495d58');rect(303,GROUND-20,10,5,'#d9bc74');rect(307,GROUND-12,2,7,'#d5e9a7');}}
 if(art.props){drawProp('vaultDoor',1270,GROUND+2,60);rect(1247,GROUND-53,46,2,state.vault?'#3a3f36':state.built.generator?'#c3e5a1':'#b99a76');if(state.vault)rect(1255,GROUND-41,32,40,'#0b0d10');}
 else if(!state.vault){drawObject(3,1270,GROUND,54);rect(1247,GROUND-51,46,2,state.built.generator?'#c3e5a1':'#b99a76');}else{ctx.globalAlpha=.55;drawObject(3,1270,GROUND,54);ctx.globalAlpha=1;rect(1257,GROUND-40,26,40,'#0b0d10');}
 art.props?drawProp('beam',1072,GROUND+2,42):drawObject(0,1072,GROUND,47);
 const grow=state.beds.filter(Boolean).length;
 for(let i=0;i<3;i++){const x=beds[i];rect(x-15,GROUND-4,30,5,'#856443');rect(x-12,GROUND-5,24,2,'#493d2d');if(!state.beds[i]&&state.story&&!state.completed)for(let j=0;j<4;j++)rect(x-10+j*6,GROUND-8-j%2*3,1,4+j%2*3,'#7a6040');if(state.beds[i]){for(let j=0;j<4;j++){const xx=x-10+j*7,height=15+(j%2)*9;rect(xx,GROUND-height,2,height-4,'#93b36e');rect(xx-4,GROUND-height+3,5,3,'#b2ce82');rect(xx+2,GROUND-height-1,5,3,'#c6dda1');rect(xx+1,GROUND-height-4,3,3,j%2?'#dcc17f':'#bccea1');}}}
 for(const m of mobs)drawMob(m);drawMira();
 if(state.vault){const fx=545+Math.sin(now*.5)*14,left=Math.cos(now*.5)<0;art.props?drawProp('fox',fx,GROUND+1,29,left):drawObject(6,fx,GROUND,38,Math.sin(now*.5)<0);}
 if(grow>0)for(let i=0;i<grow*2;i++){const x=440+Math.sin(now*.65+i*2)*65,y=GROUND-35+Math.sin(now*1.3+i)*12;rect(x-1,y,2,3,'#e4dcaa');rect(x-5,y-2,4,3,'#a9d9c7');rect(x+1,y-2,4,3,'#c5df9c');}
 drawHero();drawSlash();
 for(const s of shots){rect(s.x-1,s.y-1,3,3,'#d8d2c0');rect(s.x-Math.sign(s.vx)*4,s.y,2,1,'#d8d2c066');}
 for(const e of effects)rect(e.x,e.y,2,2,e.color);
 drawHints();drawFloats();drawTargetMarker();
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
async function boot(){
 // Underground scenes start downloading right away (in parallel with the surface) so doors rarely have to wait.
 sceneArt.mine=loadImage('assets/mine-wall.webp').then(img=>{art.mineWall=img;if(assetsReady)bakeMine();warmImage(img);dirtyFrame=true;});
 sceneArt.vault=loadImage('assets/vault-world.webp').then(img=>{art.vault=img;bakeVault();warmImage(img);});
 sceneArt.mine.catch(()=>{});sceneArt.vault.catch(()=>{});
 try{const loaded=await Promise.all([loadImage('assets/expedition-world.webp'),loadImage(`assets/hero-${heroId(state.hero)}.webp`),loadImage('assets/objects-mobile.webp'),loadImage('assets/props.webp').catch(()=>null),loadImage('assets/mobs.webp').catch(()=>null),loadImage('assets/held.webp').catch(()=>null),state.story?loadImage('assets/hero-mira.webp').catch(()=>null):null]);[art.environment,,art.objects,art.props,art.mobs,art.held,art.mira]=loaded;bakeBunker();useHero(heroId(state.hero),loaded[1]);atlases.objects=atlasLayout.objects;bakeBackground();
  try{rendered.shellback=bakeShellback();const sb=rendered.shellback;rendered.shellRed=tinted(sb.canvas,0,0,sb.w,sb.h,'#ff5a3c');rendered.stoneback=bakeShellback(document,'stone');rendered.stoneRed=tinted(rendered.stoneback.canvas,0,0,sb.w,sb.h,'#ff5a3c');const a=atlases.objects[7];rendered.mobWhite=tinted(art.objects,a.x,a.y,a.w,a.h,'#fff6e2');rendered.mobRed=tinted(art.objects,a.x,a.y,a.w,a.h,'#ff5a3c');}catch{}
  bakeMine();bakeWeapons();await loadHeroArt(state.hero);if(state.scene==='mine'&&sceneArt.mine)await sceneArt.mine.catch(()=>{});if(state.scene==='vault'&&sceneArt.vault)await sceneArt.vault.catch(()=>{});prewarm(state.scene==='surface'?toneAt(player.x):state.scene);if(inBunker())prewarm('city');if(state.scene==='surface'&&player.x<1560)prewarm(toneAt(300));assetsReady=true;ui['start-btn'].disabled=false;setText(ui['start-btn'],t(continuing?'menu.continue':'menu.start'));dirtyFrame=true;
  // Repaint the gate sign once the pixel font arrives, and fetch the forest after start-up.
  document.fonts?.ready?.then(()=>bakeGate());loadImage('assets/forest-world.webp').then(img=>{art.forest=img;bakeForest();}).catch(()=>{});
  // Backgrounds for later scenes load after start-up so the first screen appears quickly.
  loadImage('assets/items.webp').then(img=>{art.items=img;}).catch(()=>{});
  loadImage('assets/world-garden.webp').then(img=>{art.garden=img;if(state.completed){bakeBackground();if(art.forest)bakeForest();}}).catch(()=>{});
  const tones=[state.completed?'forest':null,state.forest.every(Boolean)?'mine':null,state.mine.panel?'vault':null].filter(Boolean);prewarmLater(tones);}
 catch{setText(ui['start-btn'],t('menu.loadFail'));setText($('.title-hint'),t('menu.loadFailNote'));}}
buildSettings();applyLanguage();syncSettings();measureControls();requestAnimationFrame(loop);if(typeof Image!=='undefined')boot();else{assetsReady=true;ui['start-btn'].disabled=false;}
window.afterfall={useHot,pick:id=>{craftPick=id;craftCat=RECIPES.find(r=>r.id===id).cat;renderCraft();},snapshot:()=>structuredClone({story:state.story,mira:{x:mira.x},talk:typeof talk.lines[talk.i]?.[1]==='string'?talk.lines[talk.i][1]:null,intro:!!intro,target:targetNow?{kind:targetNow.kind,name:targetNow.name,block:targetNow.block||null}:null,state,player:{x:player.x,y:player.y,ground:player.ground,face:player.face,floor:player.floor,climbing:!!player.climb,down:downTime>0},work:{hits,key:interaction.key,progress:targetNow?interaction.value/targetNow.time:0},danger:!!threat(),torchOn,mobs:mobs.map(m=>({kind:m.kind,role:m.role,x:m.x,hp:m.hp,st:m.st,same:sameFloor(m)})),paused:!active(),nearBase:nearBase(),lang:getLang()}),set:setSetting};
