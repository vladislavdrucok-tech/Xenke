p='/home/user/Xenke/dist/expedition-game.mjs';s=open(p).read()
def R(a,b,n=1):
    global s
    assert s.count(a)==n,(s.count(a),a[:90]);s=s.replace(a,b)
R("for(const b of $$('#craft-tabs [data-cat]'))b.hidden=pro&&b.dataset.cat!=='build';","for(const b of $$('#craft-tabs [data-cat]'))b.hidden=pro;")
R(" radio:[['radio','dlg.radio1'],['radio','dlg.radio2'],['mira','dlg.radio3'],['einstein','dlg.radio4']]};",
  " radio:[['radio','dlg.radio1'],['radio','dlg.radio2'],['mira','dlg.radio3'],['einstein','dlg.radio4']],\n seeds0:[['mira','dlg.seeds0']],seeds:[['mira','dlg.seeds1'],['einstein','dlg.seeds2']],kit:[['mira','dlg.kit']],planted:[['mira','dlg.planted']],watered:[['mira','dlg.watered']],\n sprout:[['mira','dlg.sprout1'],['einstein','dlg.sprout2'],['mira','dlg.sprout3']]};")
R("const NUDGE={101:'dlg.wake5',102:'dlg.tool',103:'dlg.hatch',104:'dlg.road2',105:'dlg.mats',106:'dlg.station3',107:'dlg.made',108:'dlg.fixed',109:'dlg.water3'};",
  "const NUDGE={101:'dlg.wake5',102:'dlg.tool',103:'dlg.hatch',104:'dlg.road2',105:'dlg.mats',106:'dlg.station3',107:'dlg.made',108:'dlg.fixed',109:'dlg.water3',110:'dlg.seeds0',111:'dlg.seeds2',112:'dlg.kit',113:'dlg.planted',114:'dlg.watered'};")
# water targets shared by the prologue and the campaign for story saves
i=s.index(" // Clean water: the tank under the spout.");j=s.index(" // The first bed: plant the kit, then water it.")
block=s[i:j];s=s[:i]+" best=waterTargets(best);\n"+s[j:]
fn="// Clean water at the Station (story saves, during and after the prologue): the tank under the spout, raw water into the filter.\nfunction waterTargets(best){const st=story(),near=(x,r)=>Math.abs(player.x-x)<r;if(!st.water)return best;\n"+block.replace(" // Clean water: the tank under the spout. Empty, it says when it will refill; raw stream water can be poured into the filter.\n","").replace("if(st.water&&state.inv.dirty>0","if(state.inv.dirty>0").replace("if(st.water&&near(STATION.tank,13))","if(near(STATION.tank,13))")+" return best;}\n"
R("// Prologue actions. Returns true when it handled the target.",fn+"// Prologue actions. Returns true when it handled the target.")
R(" if(state.built.filter&&near(FILTER_X,26))best={kind:'purify',"," if(state.story)best=waterTargets(best);else if(state.built.filter&&near(FILTER_X,26))best={kind:'purify',")
# tank and pour handled after the prologue too
R("function finishAction(tg){const gy=groundY();\n if(state.story&&prologueFinish(tg))return;","function finishAction(tg){const gy=groundY();\n if(state.story&&prologueFinish(tg))return;")
# markers over usable things
R(" if(st.station){out.push([262,GROUND-46]);if(!st.water)out.push([FILTER_X-28,GROUND-62]);else if(!st.radio)out.push([STATION.radio,GROUND-40]);}",
  " if(st.station){out.push([262,GROUND-46]);if(!st.water)out.push([FILTER_X-28,GROUND-62]);else if(!st.radio)out.push([STATION.radio,GROUND-40]);else if(!st.seeds)out.push([mira.x,GROUND-76]);else{if(st.tank>0)out.push([STATION.tank,GROUND-22]);if(!st.watered)out.push([BEDS[0],GROUND-22]);}}")
open(p,'w').write(s);print('ok')
