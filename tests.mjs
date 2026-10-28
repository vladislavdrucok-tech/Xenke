import assert from 'node:assert/strict';
import {freshState,craft,plant,canCraft,RECIPES,parseSave,quest} from './dist/expedition.mjs';
const s=freshState();assert.equal(craft(s,'bench'),false);assert.equal(plant(s,0),false);
Object.assign(s.inv,{wood:22,stone:8,scrap:8,cloth:3,fuse:1,dirty:3,seed:3});
assert.equal(craft(s,'bench',false),false);assert.equal(craft(s,'bench'),true);assert.equal(craft(s,'bench'),false);
assert.equal(craft(s,'filter',false),false);assert.equal(craft(s,'filter'),true);assert.equal(craft(s,'generator'),true);
s.vault=true;
for(let i=0;i<3;i++){assert.equal(craft(s,'water'),true);assert.equal(craft(s,'planter'),true);assert.equal(plant(s,i),true);assert.equal(plant(s,i),false);}
assert.equal(s.completed,false);assert.equal(quest(s).step,6);
s.defense={time:90,hp:75,wave:6};s.completed=true;assert.equal(quest(s).step,7);
assert.ok(Object.values(s.inv).every(n=>n>=0));assert.deepEqual(parseSave(JSON.stringify(s)),s);
assert.equal(parseSave('{broken'),null);assert.equal(parseSave(JSON.stringify({...s,inv:{...s.inv,wood:-1}})),null);
assert.equal(parseSave(JSON.stringify({...s,stats:{...s.stats,hp:null}})),null);
const noFilter=freshState();noFilter.built.bench=true;noFilter.inv.dirty=1;assert.equal(canCraft(noFilter,RECIPES.find(r=>r.id==='water')),'reason.needFilter');
console.log('PASS: complete v0.2 economy, station gates, no duplicate planting, defense completion, save validation.');

const old=JSON.parse(JSON.stringify(s));old.version=2;delete old.forest;delete old.built.purifier;const migrated=parseSave(JSON.stringify(old));assert.equal(migrated.version,3);assert.equal(migrated.completed,true);assert.deepEqual(migrated.forest,[false,false,false]);assert.equal(migrated.inv.wood,s.inv.wood);
const purifier=RECIPES.find(r=>r.id==='purifier');assert.equal(canCraft(freshState(),purifier),'reason.defendFirst');Object.assign(migrated.inv,{scrap:6,cloth:1,water:2});assert.equal(craft(migrated,'purifier'),true);assert.equal(craft(migrated,'purifier'),false);assert.equal(quest(migrated).step,8);migrated.forest=[true,true,true];assert.equal(quest(migrated).step,10);assert.deepEqual(parseSave(JSON.stringify(migrated)).forest,[true,true,true]);
console.log('PASS: v0.2 save migration, forest unlock and purifier gate, forest save round-trip.');
import {exportCode,importCode} from './dist/expedition.mjs';
const code=exportCode(migrated);assert.ok(code.startsWith('AFTERFALL-1:'));assert.deepEqual(importCode(code),parseSave(JSON.stringify(migrated)));
assert.deepEqual(importCode(' '+code.slice(0,30)+'\n'+code.slice(30)+' '),importCode(code),'Line breaks from messengers are ignored');
assert.equal(importCode('hello'),null);assert.equal(importCode('AFTERFALL-1:!!!'),null);assert.equal(importCode(exportCode({...migrated,inv:{...migrated.inv,wood:-5}})),null);
console.log('PASS: progress transfer code round-trip, tolerant of line breaks, rejects garbage and invalid saves.');
import {LANGS,setLang,t,missingKeys} from './dist/i18n.mjs';
import {ITEMS as ITEM_KEYS} from './dist/expedition.mjs';
assert.deepEqual(missingKeys(),{},'Every language has every key');
for(const l of Object.keys(LANGS)){setLang(l);
 for(const k of Object.values(ITEM_KEYS))assert.notEqual(t(k),k,`${l}: ${k}`);
 for(const r of RECIPES){assert.notEqual(t('recipe.'+r.id),'recipe.'+r.id);assert.notEqual(t('recipe.'+r.id+'.d'),'recipe.'+r.id+'.d');assert.notEqual(t('craft.done.'+r.id),'craft.done.'+r.id);}
 const probe=freshState();for(let step=0;step<12;step++){const q=quest(probe);assert.ok(!/\{\w+\}/.test(t(q.title,q.params)+t(q.desc,q.params)),`${l}: unfilled params in ${q.title}`);assert.notEqual(t(q.title),q.title);
  Object.assign(probe.inv,{wood:30,stone:10,scrap:20,cloth:5,fuse:1,dirty:5});['bench','filter','generator'].forEach(id=>craft(probe,id));probe.vault=true;if(step>3){craft(probe,'water');craft(probe,'planter');plant(probe,probe.beds.indexOf(false));}if(step>6){probe.defense.time=90;probe.completed=true;}if(step>8){craft(probe,'water');craft(probe,'water');craft(probe,'purifier');probe.forest[probe.forest.indexOf(false)]=true;}}}
setLang('uk');const v3=JSON.parse(JSON.stringify(freshState()));delete v3.inv.ammo;assert.equal(parseSave(JSON.stringify(v3)).inv.ammo,12,'Old saves get starting pebbles');
assert.equal(craft(freshState(),'ammo'),false);const am=freshState();am.inv.stone=1;assert.equal(craft(am,'ammo',false),true,'Pebbles can be crafted away from base');assert.equal(am.inv.ammo,17);
console.log('PASS: 5 languages complete; items, recipes, quests translated without unfilled params; slingshot pebbles recipe and migration.');
