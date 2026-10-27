export const SAVE_KEY='afterfall-last-greenhouse-v3';
export const LEGACY_KEY='afterfall-last-greenhouse-v2';
export const ITEMS={wood:'Деревина',stone:'Камінь',scrap:'Металобрухт',cloth:'Тканина',fuse:'Запобіжник',seed:'Насіння',dirty:'Річкова вода',water:'Чиста вода',planter:'Набір для посадки',berry:'Ягоди'};
export const RECIPES=[
 {id:'bench',name:'Верстак',desc:'Майстерня для ремонту обладнання.',cost:{wood:6,stone:4},once:true,icon:5},
 {id:'filter',name:'Фільтр води',desc:'Дозволяє очищати воду зі струмка.',cost:{wood:3,scrap:4,cloth:2},station:true,once:true,icon:4},
 {id:'generator',name:'Відновити живлення',desc:'Увімкни старий генератор. Це відкриє сховище насіння.',cost:{scrap:4,fuse:1,stone:2},station:true,once:true,icon:2},
 {id:'water',name:'Очистити воду',desc:'Для поливу або пиття. Потрібен фільтр.',cost:{dirty:1},station:true,filter:true,out:{water:1},icon:4},
 {id:'planter',name:'Набір для посадки',desc:'Насіння, чиста вода й дерев’яна опора.',cost:{wood:2,seed:1,water:1},station:true,out:{planter:1},icon:3},
 {id:'purifier',name:'Очищувач ґрунту',desc:'Після захисту теплиці: знешкодь три осередки у зараженому лісі.',cost:{scrap:6,cloth:1,water:2},station:true,once:true,icon:4},
 {id:'meal',name:'Ягідний перекус',desc:'Відновлює сили в дорозі.',cost:{berry:2},out:{},icon:6},
];
export function freshState(){return {version:3,time:0,inv:Object.fromEntries(Object.keys(ITEMS).map(k=>[k,k==='berry'?2:0])),built:{bench:false,filter:false,generator:false,purifier:false},beds:[false,false,false],vault:false,harvested:{},player:{x:240,y:270},stats:{hp:100,food:95,thirst:95},defense:{time:0,hp:100,wave:0},completed:false,forest:[false,false,false]};}
export function parseSave(raw){try{const x=JSON.parse(raw);if(![2,3].includes(x?.version)||!x.inv||!x.built||!Array.isArray(x.beds)||x.beds.length!==3||!x.player||!x.stats)return null;const s=freshState();for(const k of Object.keys(ITEMS)){const v=x.inv[k];if(!Number.isFinite(v)||v<0||v>9999)return null;s.inv[k]=Math.floor(v);}for(const k of Object.keys(s.built))s.built[k]=!!x.built[k];for(const k of Object.keys(s.stats)){if(!Number.isFinite(x.stats[k]))return null;s.stats[k]=Math.max(0,Math.min(100,x.stats[k]));}if(!Number.isFinite(x.player.x)||!Number.isFinite(x.player.y)||!Number.isFinite(x.time))return null;s.player={x:Math.max(24,Math.min(2376,x.player.x)),y:Math.max(0,Math.min(340,x.player.y))};s.time=Math.max(0,x.time);s.vault=!!x.vault;s.beds=x.beds.map(Boolean);s.defense={time:Math.max(0,Math.min(90,Number(x.defense?.time)||0)),hp:Math.max(1,Math.min(100,Number(x.defense?.hp)||100)),wave:Math.max(0,Math.min(7,Math.floor(Number(x.defense?.wave)||0)))};s.completed=s.beds.every(Boolean)&&s.defense.time>=90;s.forest=Array.from({length:3},(_,i)=>s.completed&&!!x.forest?.[i]);for(const[k,v]of Object.entries(x.harvested||{}))if(Number.isFinite(v)&&v>=0&&v<=10)s.harvested[k]=Math.floor(v);return s;}catch{return null;}}
export function canCraft(s,r,near=true){if(r.id==='purifier'&&!s.completed)return 'Спершу захисти теплицю';if(r.once&&s.built[r.id])return 'Готово';if((r.once||r.station)&&!near)return 'Повернися до бази';if(r.station&&!s.built.bench)return 'Потрібен верстак';if(r.filter&&!s.built.filter)return 'Потрібен фільтр';if(Object.entries(r.cost).some(([k,n])=>s.inv[k]<n))return 'Бракує ресурсів';return null;}
export function craft(s,id,near=true){const r=RECIPES.find(r=>r.id===id);if(!r||canCraft(s,r,near))return false;for(const[k,n]of Object.entries(r.cost))s.inv[k]-=n;if(r.once)s.built[id]=true;for(const[k,n]of Object.entries(r.out||{}))s.inv[k]+=n;if(id==='meal'){s.stats.food=Math.min(100,s.stats.food+35);s.stats.hp=Math.min(100,s.stats.hp+15);}return true;}
export function plant(s,i){if(!Number.isInteger(i)||i<0||i>2||s.beds[i]||s.inv.planter<1)return false;s.inv.planter--;s.beds[i]=true;return true;}
export function quest(s){
 if(s.completed){
  if(s.forest.every(Boolean))return {step:10,title:'Ліс знову дихає',desc:'Три осередки очищено. Дві ділянки планети врятовано.',x:2140};
  if(!s.built.purifier)return {step:7,title:'Експедиція у заражений ліс',desc:'Знайди ремонтний ящик за інститутом. Для очищувача також потрібні 2 чисті води.',x:s.inv.scrap<6?1680:s.inv.water<2?(s.inv.dirty>=2?260:690):260};
  const n=s.forest.findIndex(v=>!v);return {step:8,title:`Очисть заражений ліс · ${s.forest.filter(Boolean).length}/3`,desc:'Підійди до фіолетових осередків. Натисни дію для очищення.',x:[1810,2040,2260][n]};
 }
 if(s.beds.every(Boolean)){const t=Math.max(0,Math.ceil(90-s.defense.time));return {step:6,title:`Захисти теплицю · ${Math.floor(t/60)}:${String(t%60).padStart(2,'0')}`,desc:`Відганяй мутантів кнопкою дії. Стан теплиці: ${Math.ceil(s.defense.hp)}%.`,x:450};}
 if(!s.built.bench)return {step:0,title:'Збери матеріали для майстерні',desc:'6 деревини + 4 камені → верстак у меню крафту.',x:s.inv.wood<6?520:s.inv.stone<4?590:260};
 if(!s.built.filter)return {step:1,title:'Зроби фільтр води',desc:'У припасах на сході є метал і тканина. Рецепт — у крафті.',x:s.inv.scrap<4||s.inv.cloth<2?915:s.inv.wood<3?800:260};
 if(!s.built.generator)return {step:2,title:'Поверни електрику',desc:'Віднови живлення біля верстака. Запобіжник шукай у припасах.',x:s.inv.fuse<1?915:260};
 if(!s.vault)return {step:3,title:'Врятуй насіння зі сховища',desc:'Іди до інституту на сході. Утримуй кнопку дії біля дверей.',x:1270};
 if(s.inv.planter<1&&s.inv.water<1)return {step:4,title:'Підготуй чисту воду',desc:'Набери воду зі струмка й очисть біля бази. Знадобиться 3 пляшки.',x:s.inv.dirty>0?260:690};
 if(s.inv.planter<1)return {step:4,title:'Створи набори для посадки',desc:'Біля верстака: 2 деревини + насіння + чиста вода на кожен набір.',x:s.inv.wood<2?800:260};
 return {step:5,title:`Оживи теплицю · ${s.beds.filter(Boolean).length}/3`,desc:'Утримуй «Посадити» біля кожної порожньої грядки.',x:410+s.beds.findIndex(x=>!x)*40};
}
// Progress transfer between devices or addresses: a text code, since file downloads are blocked in some viewers.
const CODE_PREFIX='AFTERFALL-1:';
export function exportCode(s){const bytes=new TextEncoder().encode(JSON.stringify(s));let bin='';for(const b of bytes)bin+=String.fromCharCode(b);return CODE_PREFIX+btoa(bin);}
export function importCode(text){try{const raw=String(text||'').replace(/\s+/g,'');if(!raw.startsWith(CODE_PREFIX))return null;const bin=atob(raw.slice(CODE_PREFIX.length));return parseSave(new TextDecoder().decode(Uint8Array.from(bin,c=>c.charCodeAt(0))));}catch{return null;}}
