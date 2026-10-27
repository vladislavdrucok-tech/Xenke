import {SAVE_KEY,LEGACY_KEY,ITEMS,RECIPES,freshState,parseSave,canCraft,craft,plant,quest} from './expedition.mjs?v=3';
import atlasLayout from './assets/atlas-layout.mjs';
import {icon} from './icons.mjs';
import {bakeShellback} from './creatures.mjs';
const $=s=>document.querySelector(s),$$=s=>Array.from(document.querySelectorAll(s));
const ids=['world','welcome','start-btn','hp','food','thirst','day','restored','mission-title','mission-desc','waypoint','resource-strip','target-label','action-text','toast','saved','craft-dialog','bag-dialog','pause-dialog','win-dialog','station-note','recipes','inventory','drink-btn','eat-btn','quality-btn'];
const ui=Object.fromEntries(ids.map(id=>[id,$('#'+id)]));
const setText=(el,value)=>{if(el.textContent!==String(value))el.textContent=value;};
$$('[data-icon]').forEach(el=>el.innerHTML=icon(el.dataset.icon));
const tracked=['wood','stone','scrap','cloth','seed'];
ui['resource-strip'].innerHTML=tracked.map(k=>`<span class="resource-chip" title="${ITEMS[k]}">${icon(k)}<b id="count-${k}">0</b></span>`).join('');
const counts=Object.fromEntries(tracked.map(k=>[k,$('#count-'+k)]));
let state;try{state=parseSave(localStorage.getItem(SAVE_KEY)||localStorage.getItem(LEGACY_KEY));}catch{}
const continuing=!!state;state=state||freshState();
const GROUND=320,WORLD=2400,BASE=260,STEP=1/60;
const player={x:state.player.x,y:state.player.y,w:15,h:36,vx:0,vy:0,face:1,ground:false,walk:0,hurt:0,kb:0};
const camera={x:0,y:0};
const canvas=ui.world,ctx=canvas.getContext('2d',{alpha:false});
let VW=480,VH=320,scale=1,started=false,modal=false,visible=!document.hidden,quality='smooth',muted=false,audio;
let now=0,last=0,lastPaint=0,accum=0,uiClock=0,saveClock=0,savePending=false,toastUntil=0;
let keys={},held={left:false,right:false,jump:false,action:false},jumpLatch=false,interaction={key:'',value:0},effects=[],targetNow=null,dirtyFrame=true;
let frames=0,frameMs=0,telemetryClock=0,winShown=state.completed,assetsReady=false;
const art={},atlases={},rendered={};
let autoAction=false,tapAction=true,movePointer=null,moveAxis=0,jumpBuffer=0,coyote=0,saveQueued=false;
let adaptiveScale=1,slowWindows=0,fastWindows=0,showFps=false,ecoFallback=false,rafDelta=1000/60,rafCount=0,worstMs=0,hitches=0,prevX=player.x,prevY=player.y,renderX=player.x,renderY=player.y;
let controlSize='m',vibrate=true,swipeJump=false;
let swing=0,shake=0,hitstop=0,squash=0,floats=[];const nodeShake={};
const QUALITY={smooth:{label:'Графіка: плавно · 60 FPS, адаптивна',fps:60,area:200000,sharp:.62},eco:{label:'Графіка: економ · 30 FPS, для слабких телефонів',fps:30,area:280000,sharp:.72},detail:{label:'Графіка: деталізація · до 120 FPS',fps:120,area:650000,sharp:1.15}};
const SIZES={s:'малі',m:'стандартні',l:'великі'};
try{const prefs=JSON.parse(localStorage.getItem('afterfall-controls-v3')||'{}');quality=QUALITY[prefs.quality]?prefs.quality:'smooth';tapAction=prefs.tapAction!==false;controlSize=SIZES[prefs.size]?prefs.size:'m';vibrate=prefs.vibrate!==false;swipeJump=!!prefs.swipeJump;document.querySelector('#game').classList.toggle('left-handed',!!prefs.leftHanded);}catch{}
function savePrefs(){try{localStorage.setItem('afterfall-controls-v3',JSON.stringify({quality,tapAction,size:controlSize,vibrate,swipeJump,leftHanded:$('#game').classList.contains('left-handed')}));}catch{}}
function updateSettings(){const game=$('#game');game.classList.toggle('ctl-s',controlSize==='s');game.classList.toggle('ctl-l',controlSize==='l');setText(ui['quality-btn'],QUALITY[quality].label);setText($('#action-mode-btn'),tapAction?'Добування: одним натисканням':'Добування: утримувати кнопку');setText($('#size-btn'),'Розмір кнопок: '+SIZES[controlSize]);setText($('#vibrate-btn'),'Вібровідгук: '+(vibrate?'увімкнено':'вимкнено'));setText($('#swipe-btn'),'Стрибок свайпом угору: '+(swipeJump?'увімкнено':'вимкнено'));}
function buzz(ms){if(!vibrate||typeof navigator==='undefined'||!navigator.vibrate)return;try{navigator.vibrate(ms);}catch{}}
$('#hand-btn').onclick=()=>{const on=$('#game').classList.toggle('left-handed');setText($('#hand-btn'),on?'Керування: рух праворуч':'Керування: рух ліворуч');savePrefs();measureControls();};
$('#size-btn').onclick=()=>{controlSize={s:'m',m:'l',l:'s'}[controlSize];updateSettings();savePrefs();measureControls();};
$('#vibrate-btn').onclick=()=>{vibrate=!vibrate;updateSettings();savePrefs();buzz(20);};
$('#swipe-btn').onclick=()=>{swipeJump=!swipeJump;updateSettings();savePrefs();};
$('#action-mode-btn').onclick=()=>{tapAction=!tapAction;updateSettings();savePrefs();};
$('#fps-btn').onclick=()=>{showFps=!showFps;hitches=0;worstMs=0;$('#performance').hidden=!showFps;setText($('#fps-btn'),'Лічильник FPS: '+(showFps?'увімкнено':'вимкнено'));};
updateSettings();setText($('#hand-btn'),$('#game').classList.contains?.('left-handed')?'Керування: рух праворуч':'Керування: рух ліворуч');
const nodes=[
 {id:'logs-a',type:'wood',name:'Повалене дерево',x:520,time:2.4,art:0,reward:{wood:12}},
 {id:'stone',type:'stone',name:'Камінь',x:590,time:2.2,art:1,reward:{stone:8}},
 {id:'logs-b',type:'wood',name:'Сухі колоди',x:800,time:2.4,art:0,reward:{wood:10}},
 {id:'supplies',type:'scrap',name:'Аварійні припаси',x:915,time:3.2,art:2,reward:{scrap:8,cloth:3,fuse:1}},
 {id:'forest-cache',type:'scrap',name:'Лісовий ремонтний ящик',x:1680,time:2.8,art:2,reward:{scrap:8,cloth:2}},
 ];
const forestPatches=[1810,2040,2260];
const beds=[410,450,490],obstacle={x:1056,y:306,w:32,h:14};
const mutant={x:1140,home:1140,dir:1,hp:3,stun:0,walk:0,flash:0,lunge:0,dying:0};
let attackers=[],forestGuard=false;
const particlesLimit=12;
function active(){return started&&!modal&&visible;}
function nearBase(){return Math.abs(player.x-BASE)<245;}
function toast(text){setText(ui.toast,text);ui.toast.classList.add('show');toastUntil=now+3;}
function sound(freq=500,length=.06){if(muted||!started)return;try{audio=audio||new(window.AudioContext||window.webkitAudioContext)();if(audio.state==='suspended')audio.resume();const o=audio.createOscillator(),g=audio.createGain();o.type='triangle';o.frequency.value=freq;g.gain.setValueAtTime(.025,audio.currentTime);g.gain.exponentialRampToValueAtTime(.001,audio.currentTime+length);o.connect(g);g.connect(audio.destination);o.start();o.stop(audio.currentTime+length);}catch{}}
function save(force=false){if(!started)return;state.player={x:player.x,y:player.y};try{localStorage.setItem(SAVE_KEY,JSON.stringify(state));setText(ui.saved,'✓ Збережено на пристрої');savePending=false;}catch{setText(ui.saved,'Збереження недоступне в цьому браузері');} }
function markSave(){savePending=true;}
function burst(x,y,color,count=10){for(let i=0;i<count&&effects.length<particlesLimit;i++)effects.push({x,y,vx:(Math.random()-.5)*42,vy:-20-Math.random()*38,life:.7+Math.random()*.3,color});}
function resetInput(){for(const k of Object.keys(buttonPointers))delete buttonPointers[k];autoAction=false;movePointer=null;moveAxis=0;jumpBuffer=0;jumpLatch=false;restStick();keys={};held={left:false,right:false,jump:false,action:false};interaction={key:'',value:0};$$('.pressed').forEach(e=>e.classList.remove('pressed'));refreshContext();}
function openSheet(id){if(!started)return;modal=true;resetInput();if(id==='craft-dialog')renderCraft();if(id==='bag-dialog')renderInventory();ui[id].showModal();save();dirtyFrame=true;}
function closeSheets(){$$('dialog[open]').forEach(d=>d.close());modal=false;resetInput();dirtyFrame=true;}
$$('dialog .close').forEach(b=>b.onclick=closeSheets);
$$('dialog').forEach(d=>{d.addEventListener('close',()=>{modal=!!$('dialog[open]');resetInput();dirtyFrame=true;});});
$('#craft-btn').onclick=()=>openSheet('craft-dialog');$('#bag-btn').onclick=()=>openSheet('bag-dialog');$('#pause-btn').onclick=()=>openSheet('pause-dialog');$('#resume-btn').onclick=closeSheets;$('#continue-btn').onclick=closeSheets;
$('#sound-btn').onclick=()=>{muted=!muted;setText($('#sound-btn'),'Звук: '+(muted?'вимкнено':'увімкнено'));};
ui['quality-btn'].onclick=()=>{quality={smooth:'eco',eco:'detail',detail:'smooth'}[quality];adaptiveScale=1;slowWindows=0;ecoFallback=false;updateSettings();savePrefs();resize();};
$('#reset-btn').onclick=()=>$('#reset-confirm').hidden=false;$('#reset-no').onclick=()=>$('#reset-confirm').hidden=true;
$('#reset-yes').onclick=()=>{started=false;state=freshState();try{localStorage.setItem(SAVE_KEY,JSON.stringify(freshState()));}catch{}location.reload();};
ui['start-btn'].onclick=()=>{if(!assetsReady)return;started=true;ui.welcome.hidden=true;resetInput();sound(560,.12);toast(continuing?'Експедиція триває. Компас показує мету.':'Торкнись зліва й веди пальцем. Біля колод натисни дію.');refreshHud();dirtyFrame=true;};
function recipeIcon(r){if(r.id==='meal')return icon('berry');return `<span class="atlas-icon atlas-${r.icon}"></span>`;}
function renderCraft(){setText(ui['station-note'],nearBase()?'Біля укриття · зібране обладнання з’явиться поряд':'Повернися до укриття для роботи на верстаку ←');ui.recipes.innerHTML=RECIPES.map(r=>{const reason=canCraft(state,r,nearBase());return `<article class="recipe"><div class="recipe-icon">${recipeIcon(r)}</div><div><h3>${r.name}</h3><p>${r.desc}</p><div class="costs">${Object.entries(r.cost).map(([k,v])=>`<span class="cost ${state.inv[k]<v?'short':''}" title="${ITEMS[k]}">${icon(k)}${state.inv[k]}/${v}</span>`).join('')}</div></div><button class="craft-action" data-craft="${r.id}" ${reason?'disabled':''}>${reason||'Створити'}</button></article>`;}).join('');
 $$('[data-craft]').forEach(b=>b.onclick=()=>{const id=b.dataset.craft;if(!craft(state,id,nearBase()))return;sound(700,.1);markSave();refreshHud();renderCraft();dirtyFrame=true;toast({bench:'Майстерня готова. Час знайти аварійні припаси.',filter:'Фільтр працює. Наступна мета — живлення.',generator:'Електрика є! Сховище насіння доступне.',water:'+1 чиста вода',planter:'Набір готовий. Підійди до грядки.',purifier:'Очищувач готовий. Прямуй у ліс за інститутом.',meal:'Сили відновлено'}[id]);});
}
function renderInventory(){ui.inventory.innerHTML='<div class="inventory-grid">'+Object.entries(ITEMS).map(([k,name])=>`<div class="inv-item">${icon(k)}<b>${state.inv[k]}</b><span>${name}</span></div>`).join('')+'</div>';ui['drink-btn'].disabled=state.inv.water<1;ui['eat-btn'].disabled=state.inv.berry<2;}
ui['drink-btn'].onclick=()=>{if(state.inv.water<1)return;state.inv.water--;state.stats.thirst=Math.min(100,state.stats.thirst+45);markSave();renderInventory();refreshHud();toast('Спрагу втамовано');};
ui['eat-btn'].onclick=()=>{if(craft(state,'meal')){markSave();renderInventory();refreshHud();toast('Сили відновлено');}};
const trackEls=$$('.mission-track i');
function refreshHud(){for(const k of ['hp','food','thirst'])setText(ui[k],Math.ceil(state.stats[k]));for(const k of tracked)setText(counts[k],state.inv[k]);const q=quest(state);setText(ui['mission-title'],q.title);setText(ui['mission-desc'],q.desc);setText(ui.restored,state.completed?`ЛІС ${state.forest.filter(Boolean).length}/3`:`ТЕПЛИЦЯ ${state.beds.filter(Boolean).length}/3`);trackEls.forEach((e,i)=>e.classList.toggle('on',i<Math.round(q.step/10*5)));const seconds=Math.floor(state.time);setText(ui.day,`ЕКСПЕДИЦІЯ · ${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`);const dx=q.x-player.x;setText(ui.waypoint,Math.abs(dx)<60?'◆ Мета поруч':`${dx>0?'→':'←'} До мети · ${Math.round(Math.abs(dx)/10)} м`);canvas.dataset.playerX=Math.round(player.x);canvas.dataset.playerY=Math.round(player.y);canvas.dataset.playTime=seconds;canvas.dataset.stage=q.step;}
function resize(){const r=canvas.getBoundingClientRect();VW=Math.max(320,Math.min(960,r.width/1.65));VH=VW*r.height/r.width;const qualityScale=QUALITY[quality].sharp;const maxArea=QUALITY[quality].area*adaptiveScale;const ratio=Math.min(r.width/VW*qualityScale,Math.sqrt(maxArea/(VW*VH)));canvas.width=Math.round(VW*ratio);canvas.height=Math.round(VH*ratio);scale=canvas.width/VW;ctx.imageSmoothingEnabled=false;dirtyFrame=true;}
let resizePending=false;window.addEventListener('resize',()=>{if(resizePending)return;resizePending=true;requestAnimationFrame(()=>{resizePending=false;resize();measureControls();});});resize();
const buttonPointers={};
for(const name of ['jump','action']){const e=$('#'+name);e.addEventListener('pointerdown',ev=>{ev.preventDefault();if(buttonPointers[name]!=null)return;buttonPointers[name]=ev.pointerId;if(e.setPointerCapture)e.setPointerCapture(ev.pointerId);held[name]=true;if(name==='jump')jumpBuffer=.16;if(name==='action'&&tapAction&&active())autoAction=!autoAction;e.classList.add('pressed');if(name==='action'&&active()&&!findTarget()){if(state.beds.every(Boolean)&&!state.completed){}else if(nearBase())openSheet('craft-dialog');else toast('Підійди до підсвіченого предмета.');}});const release=ev=>{if(ev.pointerId!==undefined&&ev.pointerId!==buttonPointers[name])return;delete buttonPointers[name];if(ev.type==='pointercancel'&&name==='action')autoAction=false;held[name]=false;e.classList.remove('pressed');};for(const type of ['pointerup','pointercancel','lostpointercapture'])e.addEventListener(type,release);}
// Floating stick: touch anywhere in the movement zone; the base follows the thumb so reversing is instant.
const pad=$('#move-pad'),stick=$('#stick'),thumb=$('#pad-thumb');
let zoneRect={left:0,top:0,width:390,height:380},stickRest={x:90,y:280},stickOrigin={x:0,y:0},swipeJumped=false;
function sizeScale(){return {s:.85,m:1,l:1.18}[controlSize];}
function placeStick(x,y,knob,on){if(stick.style)stick.style.transform=`translate(${Math.round(x)}px,${Math.round(y)}px)`;if(thumb.style)thumb.style.transform=`translateX(${Math.round(knob)}px)`;stick.classList?.toggle('on',on);}
function restStick(){placeStick(stickRest.x,stickRest.y,0,false);}
function measureControls(){const r=pad.getBoundingClientRect();zoneRect={left:r.left,top:r.top,width:r.width,height:r.height};const k=sizeScale(),inset=Math.max(70*k,Math.min(r.width*.3,120*k));stickRest={x:$('#game').classList.contains('left-handed')?r.width-inset:inset,y:Math.max(60*k,r.height-92*k)};if(movePointer===null)restStick();}
function movePad(ev){if(ev.pointerId!==movePointer)return;const R=40*sizeScale();let dx=ev.clientX-stickOrigin.x;if(Math.abs(dx)>R){stickOrigin.x=ev.clientX-Math.sign(dx)*R;dx=Math.sign(dx)*R;}const dy=(ev.clientY??stickOrigin.y)-stickOrigin.y;moveAxis=Math.abs(dx)<10?0:Math.sign(dx);if(moveAxis)autoAction=false;
 if(swipeJump){if(-dy>36&&!swipeJumped){swipeJumped=true;jumpBuffer=.16;}else if(-dy<16)swipeJumped=false;}
 placeStick(stickOrigin.x-zoneRect.left,stickOrigin.y-zoneRect.top,dx,true);}
pad.addEventListener('pointerdown',ev=>{if(!active()||movePointer!==null)return;ev.preventDefault();movePointer=ev.pointerId;if(pad.setPointerCapture)pad.setPointerCapture(ev.pointerId);stickOrigin={x:ev.clientX,y:ev.clientY??0};swipeJumped=false;movePad(ev);});
pad.addEventListener('pointermove',movePad);
for(const event of ['pointerup','pointercancel','lostpointercapture'])pad.addEventListener(event,ev=>{if(ev.pointerId!==movePointer)return;movePointer=null;moveAxis=0;held.left=false;held.right=false;restStick();});
// Long-press on Android would open a context menu and cancel the touch; block it inside the game.
$('#game').addEventListener('contextmenu',ev=>ev.preventDefault());
measureControls();
window.addEventListener('keydown',e=>{if(['Space','ArrowUp','ArrowLeft','ArrowRight','KeyE','KeyC','KeyI'].includes(e.code))e.preventDefault();if(e.repeat)return;if(e.code==='Escape'){modal?closeSheets():openSheet('pause-dialog');return;}if(!started)return;if(e.code==='KeyC'||e.code==='KeyI'){if(modal)closeSheets();else openSheet(e.code==='KeyC'?'craft-dialog':'bag-dialog');return;}keys[e.code]=true;if(['Space','KeyW','ArrowUp'].includes(e.code))jumpBuffer=.16;});
window.addEventListener('keyup',e=>keys[e.code]=false);
window.addEventListener('blur',()=>{resetInput();save();});
document.addEventListener('visibilitychange',()=>{visible=!document.hidden;resetInput();if(!visible)save();last=0;accum=0;dirtyFrame=true;});window.addEventListener('pagehide',()=>save(true));
function findTarget(){const foot=player.y+player.h;if(Math.abs(foot-GROUND)>36)return null;let best=null,bestD=50;
 for(const n of nodes){if(state.harvested[n.id]||(n.x>1600&&!state.completed))continue;const d=Math.abs(n.x-player.x);if(d<bestD){bestD=d;best={kind:'node',node:n,key:n.id,time:n.time,x:n.x,name:n.name,verb:n.type==='wood'?'Рубати':'Зібрати'};}}
 if(Math.abs(player.x-690)<34)best={kind:'river',key:'river',time:.8,x:690,name:'Струмок · набери 3 пляшки',verb:'Набрати'};
 if(Math.abs(player.x-1270)<42&&!state.vault)best={kind:'vault',key:'vault',time:3.2,x:1270,name:state.built.generator?'Сховище насіння · живлення відновлено':'Сховище зачинене · потрібна електрика',verb:'Відкрити'};
 for(let i=0;i<3;i++)if(!state.beds[i]&&Math.abs(player.x-beds[i])<23)best={kind:'bed',key:'bed-'+i,index:i,time:1.5,x:beds[i],name:state.inv.planter?'Грядка · утримуй кнопку посадки':'Для грядки потрібен набір із крафту',verb:'Посадити'};
 for(let i=0;i<3;i++)if(state.completed&&!state.forest[i]&&Math.abs(player.x-forestPatches[i])<44)best={kind:'clean',key:'clean-'+i,index:i,time:4,x:forestPatches[i],name:state.built.purifier?'Заражений ґрунт · очисть дією':'Спершу створи очищувач на базі',verb:'Очистити'};
 for(const m of attackers)if(m.hp>0&&Math.abs(player.x-m.x)<58)best={kind:'attacker',mob:m,key:'attacker-'+m.id,time:.36,x:m.x,name:'Мутанти атакують теплицю',verb:'Відігнати'};
 if(mutant.hp>0&&Math.abs(player.x-mutant.x)<(forestGuard?75:55))best={kind:'mutant',key:'mutant',time:.42,x:mutant.x,name:forestGuard?'Зарослий панцирник · утримуй дію':'Панцирник · відігнати інструментом',verb:'Відігнати'};
 return best;
}
function finishAction(t){if(t.kind==='node'){const n=t.node;state.harvested[n.id]=1;for(const[k,v]of Object.entries(n.reward))state.inv[k]+=v;const gain=Object.entries(n.reward).map(([k,v])=>`+${v} ${ITEMS[k].toLowerCase()}`);toast(gain.join(' · '));floatText(t.x,GROUND-34,gain[0]);burst(t.x,GROUND-18,'#e4c38e');sound(360,.07);}
 else if(t.kind==='river'){state.inv.dirty++;toast(`Річкова вода: ${state.inv.dirty} · очисть біля бази`);sound(640,.07);}
 else if(t.kind==='vault'){if(!state.built.generator){toast('Віднови живлення в крафті біля бази.');held.action=false;return;}state.vault=true;state.inv.seed+=3;burst(t.x,GROUND-30,'#c4e39b',18);toast('Насіння врятовано! Повернися до теплиці.');sound(820,.2);}
 else if(t.kind==='bed'){if(plant(state,t.index)){burst(t.x,GROUND-12,'#bfe49b',18);sound(740,.15);toast('Життя повертається · '+state.beds.filter(Boolean).length+'/3');if(state.completed&&!winShown){winShown=true;setTimeout(()=>{setText($('#win-dialog .win-stat'),`${Math.floor(state.time/60)}:${String(Math.floor(state.time%60)).padStart(2,'0')}`);openSheet('win-dialog');},1300);}}else{toast('Спершу створи набір для посадки в крафті.');held.action=false;}}
 else if(t.kind==='attacker'){t.mob.hp--;t.mob.stun=.35;t.mob.flash=.14;hitstop=.05;shake=.12;burst(t.mob.x,GROUND-18,'#d7c5a0',4);sound(160,.04);}
 else if(t.kind==='mutant'){mutant.hp--;mutant.stun=1.1;mutant.flash=.14;hitstop=.05;shake=.14;mutant.x+=player.face*12;if(mutant.hp<=0)mutant.dying=.9;burst(mutant.x,GROUND-12,'#d5c6a1',5);sound(160,.06);if(mutant.hp<=0)toast('Панцирник відступив. Шлях вільний.');}
 else if(t.kind==='clean'){if(!state.built.purifier){toast('Потрібен очищувач ґрунту з крафту.');autoAction=false;held.action=false;return;}state.forest[t.index]=true;burst(t.x,GROUND-22,'#bfe49b',12);sound(850,.15);if(state.forest.every(Boolean)){toast('Ліс знову дихає. Друга місія виконана!');setText($('#win-dialog .eyebrow'),'ДРУГА МІСІЯ ВИКОНАНА');setText($('#win-dialog .sheet-note'),'Обидві місії завершено. Можна досліджувати світ або почати нову експедицію.');setText($('#win-dialog h2'),'Ліс знову дихає.');setText($('#win-dialog p'),'Теплиця і три лісові осередки відновлені. Твоя експедиція повернула життя ще одній ділянці планети.');setText($('#win-dialog .win-stat'),'3 / 3');openSheet('win-dialog');}else toast('Осередок очищено · '+state.forest.filter(Boolean).length+'/3');}
 autoAction=false;buzz(12);markSave();refreshHud();dirtyFrame=true;}
function swingKind(t){return t.kind==='attacker'||t.kind==='mutant'||t.kind==='node'&&t.node.type!=='scrap';}
function impact(t){if(t.kind==='node'){nodeShake[t.node.id]=.16;burst(t.x-player.face*6,GROUND-14,t.node.type==='wood'?'#b88a55':t.node.type==='stone'?'#b3b1a6':'#c9b98d',4);sound(t.node.type==='wood'?210:430,.03);}else if(swingKind(t))burst(t.x,GROUND-20,'#efe6c4',3);else burst(t.x,GROUND-16,t.kind==='river'?'#9fd6e0':'#c4e39b',2);}
function floatText(x,y,text){if(floats.length>=4)floats.shift();floats.push({x,y,text,life:1.2});}
function overlaps(x,y){return x-player.w/2<obstacle.x+obstacle.w&&x+player.w/2>obstacle.x&&y<obstacle.y+obstacle.h&&y+player.h>obstacle.y;}
function simulate(dt){if(!active())return;if(hitstop>0){hitstop-=dt;return;}shake=Math.max(0,shake-dt);for(const k in nodeShake)nodeShake[k]=Math.max(0,nodeShake[k]-dt);for(let i=floats.length-1;i>=0;i--){floats[i].life-=dt;floats[i].y-=dt*16;if(floats[i].life<=0)floats.splice(i,1);}if(!state.forest.every(Boolean))state.time+=dt;player.hurt=Math.max(0,player.hurt-dt);mutant.stun=Math.max(0,mutant.stun-dt);const right=moveAxis>0||held.right||keys.KeyD||keys.ArrowRight,left=moveAxis<0||held.left||keys.KeyA||keys.ArrowLeft,up=held.jump||keys.Space||keys.KeyW||keys.ArrowUp;
 player.vx=((right?1:0)-(left?1:0))*85;if(player.vx){player.face=Math.sign(player.vx);player.walk+=dt*9;}else player.walk=0;
 if(player.ground)coyote=.1;else coyote=Math.max(0,coyote-dt);jumpBuffer=Math.max(0,jumpBuffer-dt);if(player.vx)autoAction=false;
 if((jumpBuffer>0||up&&!jumpLatch)&&coyote>0){jumpBuffer=0;coyote=0;player.vy=-230;player.ground=false;squash=-.1;sound(300,.035);}jumpLatch=!!up;player.vy=Math.min(300,player.vy+620*dt);
 player.kb=Math.abs(player.kb)<4?0:player.kb*(1-7*dt);const dx=(player.vx+player.kb)*dt;const wasGround=player.ground;if(!overlaps(player.x+dx,player.y))player.x+=dx;player.x=Math.max(24,Math.min(state.completed?WORLD-24:1550,player.x));
 player.ground=false;const nextY=player.y+player.vy*dt;if(player.vy>0&&overlaps(player.x,nextY)&&player.y+player.h<=obstacle.y+2){player.y=obstacle.y-player.h;player.vy=0;player.ground=true;}else player.y=nextY;
 if(player.y+player.h>=GROUND){player.y=GROUND-player.h;player.vy=0;player.ground=true;}else if(player.y+player.h<obstacle.y-1)player.ground=false;
 if(player.ground&&!wasGround&&player.vy===0){squash=.13;burst(player.x,player.y+player.h-1,'#9c9378',3);}squash=Math.abs(squash)<.01?0:squash*(1-12*dt);
 targetNow=findTarget();const pressing=held.action||keys.KeyE||autoAction;
 if(pressing&&targetNow){if(interaction.key!==targetNow.key){interaction={key:targetNow.key,value:0};swing=0;}interaction.value+=dt;
  // Tool rhythm: raise, then strike; chips fly at the moment of impact.
  const prev=swing,period=swingKind(targetNow)?(targetNow.kind==='node'?.5:targetNow.time):.8;swing+=dt/period;if(Math.floor(prev-.8)!==Math.floor(swing-.8))impact(targetNow);if(interaction.value>=targetNow.time){finishAction(targetNow);interaction.value=0;}}
 else {interaction={key:'',value:0};swing=0;if(!targetNow)autoAction=false;}
 if(state.completed&&player.x>1600&&!forestGuard){forestGuard=true;mutant.x=2150;mutant.home=2150;mutant.hp=5;mutant.stun=0;mutant.dying=0;toast('Зарослий панцирник охороняє ліс. Утримуй дію, щоб відігнати.');}
 mutant.flash=Math.max(0,mutant.flash-dt);mutant.lunge=Math.max(0,mutant.lunge-dt);mutant.dying=Math.max(0,mutant.dying-dt);
 if(mutant.hp>0&&!mutant.stun){mutant.x+=mutant.dir*11*dt;mutant.walk+=dt*7;if(Math.abs(mutant.x-mutant.home)>32)mutant.dir*=-1;}
 if(mutant.hp>0&&Math.abs(player.x-mutant.x)<(forestGuard?34:22)&&player.y+player.h>GROUND-15&&!player.hurt){state.stats.hp=Math.max(0,state.stats.hp-8);player.hurt=1.8;mutant.lunge=.3;player.kb=(player.x<mutant.x?-1:1)*150;if(player.ground)player.vy=-80;shake=.1;buzz(45);toast('Панцирник! Утримуй кнопку дії або перестрибни.');}

 if(state.beds.every(Boolean)&&!state.completed){state.defense.time=Math.min(90,state.defense.time+dt);const wave=Math.floor(state.defense.time/15)+1;if(wave>state.defense.wave&&wave<=6){state.defense.wave=wave;for(let i=0;i<(wave>3?2:1);i++)attackers.push({id:wave+'-'+i,x:i?185:790+i*30,hp:wave===6?5:3,stun:0,bite:0});toast(wave===1?'Шум генератора привабив мутантів. Захисти теплицю!':`Нова хвиля · ${wave}/6`);}for(const m of attackers){if(m.hp<=0)continue;m.stun=Math.max(0,m.stun-dt);m.flash=Math.max(0,(m.flash||0)-dt);m.bite=Math.max(0,m.bite-dt);const goal=m.x<430?405:490;if(!m.stun&&Math.abs(m.x-goal)>3)m.x+=Math.sign(goal-m.x)*24*dt;if(Math.abs(m.x-goal)<=5&&!m.bite){state.defense.hp-=6;m.bite=2.5;burst(goal,GROUND-15,'#dcaa83',3);}}attackers=attackers.filter(m=>m.hp>0);if(state.defense.hp<=0){state.defense={time:0,hp:100,wave:0};attackers=[];player.x=450;toast('Теплицю пошкоджено. Зберімося й спробуймо захист ще раз.');}if(state.defense.time>=90){state.completed=true;attackers=[];winShown=true;markSave();setTimeout(()=>{const seconds=Math.floor(state.time);setText($('#win-dialog .win-stat'),`${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`);openSheet('win-dialog');},1200);}}
 if(state.stats.hp<=0){state.stats.hp=80;player.x=BASE;player.y=GROUND-player.h;toast('Повернення до укриття. Припаси збережено.');}
 state.stats.food=Math.max(0,state.stats.food-dt*.018);state.stats.thirst=Math.max(0,state.stats.thirst-dt*.025);if(nearBase())state.stats.hp=Math.min(100,state.stats.hp+dt*.5);
 for(let i=effects.length-1;i>=0;i--){const e=effects[i];e.x+=e.vx*dt;e.y+=e.vy*dt;e.vy+=85*dt;e.life-=dt;if(e.life<=0)effects.splice(i,1);}
 uiClock+=dt;saveClock+=dt;if(uiClock>=.25){refreshHud();refreshContext();uiClock=0;}if(saveClock>15&&!saveQueued){saveClock=0;saveQueued=true;const flush=()=>{saveQueued=false;save();};if(window.requestIdleCallback)window.requestIdleCallback(flush,{timeout:3000});else setTimeout(flush,0);}
}
function refreshContext(){let label=targetNow?.name||'',verb=targetNow?.verb||'Дія';if(!targetNow&&state.beds.every(Boolean)&&!state.completed){label='Захищай грядки · утримуй дію, коли мутант наблизиться';verb='Захист';}else if(!targetNow&&nearBase()){label='Укриття · відкрий крафт для ремонту';verb='Крафт';}if(!targetNow&&player.x>1000&&player.x<1100)label='Повалена балка · натисни ↑, щоб перестрибнути';setText(ui['target-label'],label);setText(ui['action-text'],autoAction?'Стоп':verb);$('#action').classList.toggle('auto-working',autoAction);}
function loadImage(src){return new Promise((resolve,reject)=>{const i=new Image();i.onload=()=>{if(i.decode)i.decode().catch(()=>{}).then(()=>resolve(i));else resolve(i);};i.onerror=()=>reject(new Error(src));i.src=src;});}
function drawObject(index,x,ground,width=55,flip=false){const a=atlases.objects?.[index];if(!a||x<camera.x-width||x>camera.x+VW+width)return;const h=a.h/a.w*width;ctx.save();ctx.translate(Math.round(x),Math.round(ground));if(flip)ctx.scale(-1,1);ctx.drawImage(art.objects,a.x,a.y,a.w,a.h,-width/2,-h,width,h);ctx.restore();}
// Forest guard: walk cycle, bite lunge toward the hero, white hit flash, and sinking into the soil when beaten.
function drawShellback(){const sb=rendered.shellback,near=Math.abs(player.x-mutant.x)<70&&mutant.hp>0,face=near?Math.sign(player.x-mutant.x)||1:mutant.dir;
 const f=mutant.flash>0?5:mutant.lunge>0?4:mutant.stun>0||mutant.hp<=0?0:Math.floor(mutant.walk)%4,vis=mutant.hp>0?sb.h:Math.max(1,Math.round(sb.h*mutant.dying/.9));
 ctx.save();ctx.translate(Math.round(mutant.x),GROUND+1);ctx.scale(face*1.3,1.3);ctx.drawImage(sb.canvas,f*sb.w,0,sb.w,vis,-sb.w/2,-vis,sb.w,vis);ctx.restore();}
function drawFlash(x,width,flip){const a=atlases.objects?.[7],c=rendered.mutantWhite;if(!a||!c)return;const h=a.h/a.w*width;ctx.save();ctx.globalAlpha=.75;ctx.translate(Math.round(x),GROUND);if(flip)ctx.scale(-1,1);ctx.drawImage(c,0,0,a.w,a.h,-width/2,-h,width,h);ctx.restore();}
function rect(x,y,w,h,color){ctx.fillStyle=color;ctx.fillRect(Math.round(x),Math.round(y),w,h);}
function drawHero(){if(player.hurt>0&&Math.floor(now*9)%2===0)return;const working=(held.action||keys.KeyE||autoAction)&&targetNow,frame=!player.ground?7:working?(swingKind(targetNow)?(swing%1<.6?5:6):4):player.vx?Math.floor(player.walk)%4:4,a=atlases.hero?.[frame];if(!a)return;const k=72/atlases.heroMaxHeight,bob=working&&!swingKind(targetNow)?Math.round(Math.sin(now*9)):0;ctx.save();ctx.translate(Math.round(renderX),Math.round(renderY+player.h)+bob);ctx.scale(player.face*(1+squash*.6),1-squash);ctx.drawImage(art.hero,a.x,a.y,a.w,a.h,-a.anchor*k,-a.h*k,a.w*k,a.h*k);ctx.restore();}
const FOREST={x:1600,w:800,ground:.7227*768/724};
function bakeBackground(){const c=document.createElement('canvas');c.width=WORLD;c.height=800;const g=c.getContext('2d');g.imageSmoothingEnabled=true;g.imageSmoothingQuality='high';const h=1600/art.environment.width*art.environment.height;const top=400-h*.78;g.fillStyle='#233d48';g.fillRect(0,0,WORLD,800);g.drawImage(art.environment,0,top,1600,h);
 g.fillStyle='#1d2d3c';g.fillRect(FOREST.x,0,FOREST.w,800);
 rendered.world=c;rendered.top=GROUND-400;rendered.artBottom=GROUND+h*.22;
 if(art.forest)bakeForest();
 // Pre-baked texture, flower plots and lamp gradients avoid per-frame geometry.
 const detail=document.createElement('canvas');detail.width=WORLD;detail.height=240;const d=detail.getContext('2d');d.fillStyle='#203036';d.fillRect(0,0,WORLD,240);for(let x=0;x<WORLD;x+=16)for(let y=0;y<240;y+=16){d.fillStyle=(x+y)%48?'#344039':'#3b463b';d.fillRect(x+2,y+3,8,2);d.fillStyle='#17292c';d.fillRect(x,y+15,16,1);}rendered.earth=detail;
 const gate=document.createElement('canvas');gate.width=270;gate.height=54;const t=gate.getContext('2d');t.fillStyle='#273b3a';t.fillRect(0,0,270,54);t.fillStyle='#e2d0a3';t.font='27px system-ui';t.fillText('Спершу теплиця',15,36);rendered.gate=gate;
}
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
 // World gate and forest patches, with static forest geometry baked at boot.
 if(!state.completed&&camera.x+VW>1510){rect(1545,GROUND-55,5,55,'#8e7d68');if(rendered.gate){ctx.imageSmoothingEnabled=true;ctx.drawImage(rendered.gate,1495,GROUND-54,90,18);ctx.imageSmoothingEnabled=false;}}
 for(let i=0;i<3;i++){const x=forestPatches[i];if(x<camera.x-90||x>camera.x+VW+90)continue;const clean=state.forest[i];rect(x-47,GROUND-5,94,7,clean?'#779968':'#785983');for(let j=0;j<8;j++){const xx=x-39+j*11,h=12+j%3*7;rect(xx,GROUND-h,3,h,clean?'#98bc7a':'#9774aa');rect(xx-3,GROUND-h,9,4,clean?'#c5df98':'#b090c6');}if(clean)drawObject(6,x+24,GROUND,32);}
 // Slim walkable edge unifies scenery and physical ground.
 rect(camera.x,GROUND,Math.min(VW,WORLD-camera.x),2,'#8b9668');
 for(const n of nodes){if(n.x<camera.x-70||n.x>camera.x+VW+70||state.harvested[n.id])continue;drawObject(n.art,n.x+(nodeShake[n.id]>0?Math.sin(now*80)*1.6:0),GROUND,n.type==='wood'?64:n.type==='stone'?48:56);}
 if(state.built.bench)drawObject(5,265,GROUND,72);
 if(state.built.filter)drawObject(4,345,GROUND,48);
 if(state.built.generator){rect(300,GROUND-24,16,23,'#495d58');rect(303,GROUND-20,10,5,'#d9bc74');rect(307,GROUND-12,2,7,'#d5e9a7');}
 if(!state.vault){drawObject(3,1270,GROUND,54);rect(1247,GROUND-51,46,2,state.built.generator?'#c3e5a1':'#b99a76');}
 drawObject(0,1072,GROUND,47);
 const grow=state.beds.filter(Boolean).length;
 for(let i=0;i<3;i++){const x=beds[i];rect(x-15,GROUND-4,30,5,'#856443');rect(x-12,GROUND-5,24,2,'#493d2d');if(state.beds[i]){for(let j=0;j<4;j++){const xx=x-10+j*7,height=15+(j%2)*9;rect(xx,GROUND-height,2,height-4,'#93b36e');rect(xx-4,GROUND-height+3,5,3,'#b2ce82');rect(xx+2,GROUND-height-1,5,3,'#c6dda1');rect(xx+1,GROUND-height-4,3,3,j%2?'#dcc17f':'#bccea1');}}}
 if((mutant.hp>0||mutant.dying>0)&&mutant.x>camera.x-60&&mutant.x<camera.x+VW+60){if(forestGuard&&rendered.shellback)drawShellback();else{drawObject(7,mutant.x,GROUND,54,mutant.dir>0);if(mutant.flash>0)drawFlash(mutant.x,54,mutant.dir>0);}}
 if(mutant.hp>0&&mutant.x>camera.x-60&&mutant.x<camera.x+VW+60){if(mutant.hp<(forestGuard?5:3)){const by=GROUND-(forestGuard?68:37);rect(mutant.x-15,by,30,3,'#152c2c');rect(mutant.x-15,by,30*mutant.hp/(forestGuard?5:3),2,'#dac899');}}
 for(const m of attackers)if(m.hp>0&&m.x>camera.x-60&&m.x<camera.x+VW+60){drawObject(7,m.x,GROUND,48,m.x<430);if(m.flash>0)drawFlash(m.x,48,m.x<430);rect(m.x-14,GROUND-37,28,3,'#233537');rect(m.x-14,GROUND-37,28*Math.min(1,m.hp/3),2,'#d7ad8b');}
 if(state.vault)drawObject(6,545+Math.sin(now*.5)*14,GROUND,38,Math.sin(now*.5)<0);
 if(grow>0)for(let i=0;i<grow*2;i++){const x=440+Math.sin(now*.65+i*2)*65,y=GROUND-35+Math.sin(now*1.3+i)*12;rect(x-1,y,2,3,'#e4dcaa');rect(x-5,y-2,4,3,'#a9d9c7');rect(x+1,y-2,4,3,'#c5df9c');}
 drawHero();
 for(const e of effects)rect(e.x,e.y,2,2,e.color);
 if(floats.length){ctx.font='bold 8px system-ui';ctx.textAlign='center';for(const f of floats){ctx.globalAlpha=Math.min(1,f.life*2);ctx.fillStyle='#142a2e';ctx.fillText(f.text,f.x+.6,f.y+.6);ctx.fillStyle='#f3e3b4';ctx.fillText(f.text,f.x,f.y);}ctx.globalAlpha=1;ctx.textAlign='start';}
 if(targetNow){const tx=targetNow.x,ty=GROUND-74;rect(tx-4,ty+Math.sin(now*2)*2,8,2,'#d9dda6');if(interaction.value>0){rect(tx-24,GROUND-66,48,4,'#142c30');rect(tx-24,GROUND-66,48*Math.min(1,interaction.value/targetNow.time),3,'#c5e49a');}}
 ctx.restore();dirtyFrame=false;
}
function loop(timestamp){const t=performance.now();const raw=last?timestamp-last:1000/60;const elapsed=last?Math.min(.1,raw/1000):STEP;if(last&&raw>4&&raw<40)rafDelta+=(raw-rafDelta)*.05;last=timestamp;now+=elapsed;
 if(active()){if(raw>worstMs)worstMs=raw;if(raw>50)hitches++;accum+=elapsed;let n=0;while(accum>=STEP&&n<6){prevX=player.x;prevY=player.y;simulate(STEP);accum-=STEP;n++;}if(accum>STEP)accum=STEP;}else accum=0;
 // Render between the last two physics steps so motion stays smooth when paint and physics rates differ.
 const alpha=Math.min(1,accum/STEP);renderX=prevX+(player.x-prevX)*alpha;renderY=prevY+(player.y-prevY)*alpha;if(Math.abs(player.x-prevX)>20){renderX=player.x;renderY=player.y;}
 if(toastUntil&&now>toastUntil){ui.toast.classList.remove('show');toastUntil=0;}
 // Paint on every n-th display refresh: 60 Hz→1, 120 Hz→2, so frame pacing stays even instead of alternating.
 const fps=ecoFallback?QUALITY[quality].fps/2:QUALITY[quality].fps,every=Math.max(1,Math.round(1000/fps/rafDelta));rafCount++;
 if(assetsReady&&visible&&(dirtyFrame||active()&&rafCount>=every)){rafCount=0;paint();frames++;frameMs+=performance.now()-t;}
 // Telemetry counts only live gameplay: pauses, menus and the start screen must not look like slow frames.
 if(!active()){frames=0;frameMs=0;telemetryClock=0;fastWindows=0;}else telemetryClock+=elapsed;
 if(telemetryClock>=2){const rate=frames/telemetryClock;canvas.dataset.renderFps=Math.round(rate);canvas.dataset.cpuMs=(frameMs/Math.max(1,frames)).toFixed(2);if(showFps)setText($('#performance'),`${Math.round(rate)} FPS · найдовший кадр ${Math.round(worstMs)} мс · ривків ${hitches} · ${canvas.width}×${canvas.height}${ecoFallback?' · авто '+fps:''}`);
  const goal=Math.min(fps,1000/rafDelta/every);if(rate<goal*.8)slowWindows++;else slowWindows=0;
  if(slowWindows>=2){slowWindows=0;fastWindows=0;if(quality==='detail'){if(!ecoFallback&&fps>60)ecoFallback=true;}else if(adaptiveScale>.55){adaptiveScale=Math.max(.55,adaptiveScale-.15);resize();}else if(quality==='smooth'&&!ecoFallback)ecoFallback=true;}
  // Recover sharpness after ~10 s of steady frames, so one bad moment does not leave the picture blurry for good.
  else if(rate>=goal*.95&&worstMs<34){if(++fastWindows>=5){fastWindows=0;if(ecoFallback)ecoFallback=false;else if(adaptiveScale<1){adaptiveScale=Math.min(1,adaptiveScale+.15);resize();}}}else fastWindows=0;
  worstMs=0;frames=0;frameMs=0;telemetryClock=0;}
 requestAnimationFrame(loop);
}
async function boot(){try{const loaded=await Promise.all([loadImage('assets/expedition-world.webp'),loadImage('assets/einstein-mobile.webp'),loadImage('assets/objects-mobile.webp')]);[art.environment,art.hero,art.objects]=loaded;atlases.hero=atlasLayout.hero;atlases.objects=atlasLayout.objects;atlases.heroMaxHeight=Math.max(...atlases.hero.map(a=>a.h));bakeBackground();try{rendered.shellback=bakeShellback();const a=atlases.objects[7],c=document.createElement('canvas');c.width=a.w;c.height=a.h;const g=c.getContext('2d');g.drawImage(art.objects,a.x,a.y,a.w,a.h,0,0,a.w,a.h);g.globalCompositeOperation='source-atop';g.fillStyle='#fff6e2';g.fillRect(0,0,a.w,a.h);rendered.mutantWhite=c;}catch{}assetsReady=true;ui['start-btn'].disabled=false;setText(ui['start-btn'],continuing?'Продовжити експедицію':'Почати експедицію');dirtyFrame=true;loadImage('assets/forest-world.webp').then(img=>{art.forest=img;bakeForest();}).catch(()=>{});}catch{setText(ui['start-btn'],'Не вдалося завантажити графіку');const note=ui.welcome.querySelector('small');if(note)setText(note,'Перевір з’єднання та онови сторінку.');}}
refreshHud();requestAnimationFrame(loop);if(typeof Image!=='undefined')boot();else{assetsReady=true;ui['start-btn'].disabled=false;}
window.afterfall={snapshot:()=>structuredClone({state,player:{x:player.x,y:player.y,ground:player.ground},paused:!active(),nearBase:nearBase()})};
