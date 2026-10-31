p='/home/user/Xenke/dist/expedition-game.mjs';s=open(p).read()
def R(a,b,n=1):
    global s
    assert s.count(a)==n,(s.count(a),a[:90]);s=s.replace(a,b)
R("newGame,inPrologue,STORY,BUNKER,STATION,CHESTS,","newGame,inPrologue,STORY,BUNKER,STATION,CHESTS,BEDS,TANK,")
# world layout: planter boxes in front of the greenhouse, the first logs and stone moved clear of them
R(" {id:'logs-a',type:'wood',x:520,"," {id:'logs-a',type:'wood',x:640,")
R(" {id:'stone',type:'stone',x:590,"," {id:'stone',type:'stone',x:760,")
R("const beds=[410,450,490],obstacle=","const beds=BEDS,obstacle=")
R("goal:fromLeft?405:490,","goal:fromLeft?BEDS[0]:BEDS[2],")
R("const x=440+Math.sin(now*.65+i*2)*65,","const x=BEDS[1]+Math.sin(now*.65+i*2)*65,")
# contact point: chips fly where the tool meets the object, the reward appears there too
R("function impact(tg){const gy=groundY();if(tg.kind==='ore'){nodeShake[tg.key]=.16;burst(tg.x-player.face*6,gy-14,'#e0802c',4);sfx('pick');}else if(tg.kind==='node'){nodeShake[tg.node.id]=.16;burst(tg.x-player.face*6,gy-14,",
  "// Where the tool meets the object: its near edge, at the height the swing lands (the reward and chips appear there).\nfunction contactPoint(tg){const gy=groundY(),half=tg.kind==='ore'?16:tg.node?.type==='wood'?14:tg.node?.type==='stone'?13:10,h=tg.kind==='ore'?14:tg.node?.type==='wood'?16:12;return [tg.x-player.face*half,gy-h];}\nfunction impact(tg){const gy=groundY(),[cx,cy]=contactPoint(tg);if(tg.kind==='ore'){nodeShake[tg.key]=.16;burst(cx,cy,'#e0802c',4);sfx('pick');}else if(tg.kind==='node'){nodeShake[tg.node.id]=.16;burst(cx,cy,")
R(" if(tg.kind==='node'){const n=tg.node;state.harvested[n.id]=1;for(const[k,v]of Object.entries(n.reward))state.inv[k]+=v;const g=gain(n.reward);toast(g.join(' · '));floatText(tg.x,gy-34,g[0]);burst(tg.x,gy-18,'#e4c38e');sfx('gain');}",
  " if(tg.kind==='node'){const n=tg.node,[cx,cy]=contactPoint(tg);state.harvested[n.id]=1;for(const[k,v]of Object.entries(n.reward))state.inv[k]+=v;const g=gain(n.reward);toast(g.join(' · '));floatText(cx,cy-18,g[0]);burst(cx,cy,'#e4c38e');sfx('gain');}")
# block messages and target names may carry parameters
R(" else if(pressing&&targetNow?.block){toast(t(targetNow.block));"," else if(pressing&&targetNow?.block){const b=targetNow.block;toast(Array.isArray(b)?t(b[0],b[1]):t(b));")
R("function refreshContext(){let label=targetNow?(kbHints?'E · ':'')+t(targetNow.name):'',","function refreshContext(){let label=targetNow?(kbHints?'E · ':'')+t(targetNow.name,targetNow.np):'',")
# pulse jobs: kneeling work at the tank and the bed joins the wrench jobs
R("const TURN=.42,WRENCH_JOBS=new Set(['valve','fixFilter','startWater']);","const TURN=.42,WRENCH_JOBS=new Set(['valve','fixFilter','startWater','tank','sow','waterBed','pour']);")
R("function turnPulse(tg){const gy=groundY();sfx('pick');buzz(6);if(tg.kind==='fixFilter')burst(tg.x,gy-30,'#ffe08a',3);else if(tg.kind==='valve')burst(tg.x,gy-44,'#c9c2b0',2);else burst(tg.x,gy-36,'#9fd6e0',2);}",
  "function turnPulse(tg){const gy=groundY();buzz(6);\n if(tg.kind==='fixFilter'){sfx('pick');burst(tg.x,gy-30,'#ffe08a',3);}else if(tg.kind==='valve'){sfx('pick');burst(tg.x,gy-44,'#c9c2b0',2);}else if(tg.kind==='startWater'){sfx('pick');burst(tg.x,gy-42,'#9fd6e0',2);}\n else if(tg.kind==='tank'||tg.kind==='pour'){sfx('water');burst(tg.x,gy-10,'#9fd6e0',3);}else if(tg.kind==='sow'){sfx('plant');burst(tg.x+player.face*-4,gy-9,'#6a4a2a',3);}else if(tg.kind==='waterBed'){sfx('water');burst(tg.x,gy-10,'#9fd6e0',4);}}")
R("return ['panel','purify','clean','valve','fixFilter','startWater'].includes(tg.kind)?'wrench':'';}","if(['tank','sow','waterBed'].includes(tg.kind))return 'kneel';return ['panel','purify','clean','valve','fixFilter','startWater'].includes(tg.kind)?'wrench':'';}")
# station targets: tank, pouring raw water, Mira's seeds, the first bed
R(" if(st.water&&!st.radio&&near(STATION.radio,18))best={kind:'radio',key:'radio',time:.2,x:STATION.radio,name:'target.radio',verb:'verb.listen',w:24,h:30};",
""" if(st.water&&!st.radio&&near(STATION.radio,18))best={kind:'radio',key:'radio',time:.2,x:STATION.radio,name:'target.radio',verb:'verb.listen',w:24,h:30};
 // Clean water: the tank under the spout. Empty, it says when it will refill; raw stream water can be poured into the filter.
 if(st.water&&state.inv.dirty>0&&st.tank<TANK.max&&near(FILTER_X-20,36))best={kind:'pour',key:'pour',time:TURN*2,x:machineAt(MACHINE.wheel[0],0)[0],spot:STATION.spot,name:'target.pour',verb:'verb.pour',w:16,h:16,lift:36};
 if(st.water&&near(STATION.tank,13)){const sec=Math.ceil(TANK.refill-tankT);best=st.tank>0?{kind:'tank',key:'tank',time:TURN*2,x:STATION.tank,spot:STATION.tank-15,name:'target.tank',np:{n:st.tank,max:TANK.max},verb:'verb.fill',w:16,h:14}:{kind:'tank',key:'tank',time:1,x:STATION.tank,name:'target.tankEmpty',np:{s:sec},verb:'verb.fill',block:['toast.tankEmpty',{s:sec}],w:16,h:14};}
 // The first bed: plant the kit, then water it.
 if(st.seeds&&near(BEDS[0],20)){if(!state.beds[0])best=state.inv.planter>0?{kind:'sow',key:'sow',time:TURN*3,x:BEDS[0],spot:BEDS[0]-19,name:'target.bedSow',verb:'verb.sow',w:34,h:14}:{kind:'sow',key:'sow',time:1,x:BEDS[0],name:'target.bedNoKit',verb:'verb.sow',block:'toast.needKit2',w:34,h:14};
  else if(!st.watered)best=state.inv.water>0?{kind:'waterBed',key:'waterBed',time:TURN*3,x:BEDS[0],spot:BEDS[0]-19,name:'target.bedWater',verb:'verb.water',w:34,h:14}:{kind:'waterBed',key:'waterBed',time:1,x:BEDS[0],name:'target.bedDry',verb:'verb.water',block:'toast.needWater',w:34,h:14};}
 if(st.radio&&!st.seeds&&near(mira.x,26))best={kind:'seeds',key:'seeds',time:.2,x:mira.x,name:'target.miraSeeds',verb:'verb.get',w:24,h:64};""")
# story actions
R("  case 'startWater':st.water=true;state.built.filter=true;","  case 'startWater':st.water=true;st.tank=TANK.start;state.built.filter=true;")
R("  case 'radio':held.action=false;autoAction=false;actionLatch=true;say('radio',finishPrologue,true);return true;",
"""  case 'radio':held.action=false;autoAction=false;actionLatch=true;say('radio',()=>{st.radio=true;save();refreshHud();say('seeds0');},true);return true;
  case 'seeds':held.action=false;autoAction=false;actionLatch=true;st.seeds=true;state.inv.seed+=2;floatText(tg.x,gy-70,t('toast.seedsGot'));burst(tg.x,gy-40,'#c4e39b',8);sfx('gain');toast(t('toast.seedsGot'));say('seeds');save();refreshHud();return true;
  case 'tank':st.tank--;state.inv.water++;floatText(tg.x,gy-26,t('toast.gain',{n:1,item:t(ITEMS.water).toLowerCase()}));sfx('water');break;
  case 'pour':state.inv.dirty--;st.tank=Math.min(TANK.max,st.tank+1);burst(tg.x,gy-40,'#9fd6e0',6);sfx('water');break;
  case 'sow':state.inv.planter--;state.beds[0]=true;burst(tg.x,gy-8,'#6a4a2a',10);sfx('plant');toast(t('toast.sown'));say('planted');break;
  case 'waterBed':state.inv.water--;st.watered=true;sproutAt=now+3.2;burst(tg.x,gy-8,'#9fd6e0',12);sfx('water');toast(t('toast.watered'));say('watered');break;""")
R("function finishPrologue(){const st=story();if(st.done)return;st.radio=true;st.done=true;","function finishPrologue(){const st=story();if(st.done)return;st.done=true;")
# the sprout: a few seconds after watering, then the episode ends; the tank refills while the filter runs
R("function updateStory(dt){const st=story();if(!state.story||st.done)return;",
"""// Clean-water tank: refills one can every TANK.refill seconds while the filter runs (story saves, also after the prologue).
let tankT=0,sproutAt=0,sproutT=0;
function updateTank(dt){const st=story();if(!state.story||!st.water)return;if(st.tank>=TANK.max){tankT=0;return;}tankT+=dt;if(tankT>=TANK.refill){tankT=0;st.tank++;}}
function updateStory(dt){const st=story();if(!state.story)return;updateTank(dt);if(st.sprout)sproutT=Math.min(2,sproutT+dt);if(st.done)return;
 if(st.watered&&!st.sprout){if(!sproutAt)sproutAt=now+3.2;if(now>=sproutAt){st.sprout=true;sproutT=0;mira.joy=1.4;burst(BEDS[0],GROUND-14,'#bfe49b',14);sfx('win');toast(t('toast.sprout'));save();say('sprout',finishPrologue);}}""")
# Mira: waits with the seeds by the door, otherwise keeps near the hero and stops a few steps away while he works
R(" if(inBunker())tx=BUNKER.mira;else if(state.scene!=='surface')return;else if(st.station||st.done)tx=STATION.mira;else tx=player.x-player.face*46;",
""" if(inBunker())tx=BUNKER.mira;else if(state.scene!=='surface')return;
 else if(st.done&&!st.sprout||st.radio&&!st.seeds)tx=STATION.mira;
 else if(st.station){const busy=interaction.key&&targetNow;tx=busy?player.x-(Math.sign(targetNow.x-player.x)||player.face)*44:Math.abs(mira.x-player.x)>90?player.x-player.face*52:mira.x;}
 else tx=player.x-player.face*46;""")
# craft: the planting kit is part of the prologue once Mira hands over the seeds
R("const list=RECIPES.filter(r=>r.cat===craftCat&&(pro?r.story:!r.story||state.built[r.id]));",
  "const list=RECIPES.filter(r=>(pro||r.cat===craftCat)&&(pro?r.story||r.id==='planter'&&story().seeds:!r.story||state.built[r.id]));")
R("toast(t('craft.done.'+id));if(id==='repair'){save();say('made');}});}","toast(t('craft.done.'+id));if(id==='repair'){save();say('made');}if(id==='planter'&&inPrologue(state)){save();say('kit');}});}")
R("ui['craft-dialog'].classList?.toggle('single',pro);","ui['craft-dialog'].classList?.toggle('single',pro&&!story().seeds);")
open(p,'w').write(s);print('ok')
