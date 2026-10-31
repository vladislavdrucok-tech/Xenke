p='/home/user/Xenke/dist/expedition-game.mjs';s=open(p).read()
def R(a,b,n=1):
    global s
    assert s.count(a)==n,(s.count(a),a[:90]);s=s.replace(a,b)
R("const CANS=[{art:'bucket',x:438},{art:'canRed',x:454},{art:'canOlive',x:468},{art:'drum',x:486}];","const CANS=[{art:'bucket',x:STATION.tank},{art:'canRed',x:450},{art:'canOlive',x:462},{art:'drum',x:474}];")
R(" const grow=state.beds.filter(Boolean).length;"," // Fireflies over planted beds; the first story bed brings them only once its sprout is up.\n const grow=state.beds.filter((b,i)=>b&&!(state.story&&i===0&&!story().sprout)).length;")
R("drawProp('greenhouse',GREENHOUSE_X,GROUND+3,300,false,1,1,inPrologue(state));","drawProp('greenhouse',GREENHOUSE_X,GROUND+3,300,false,1,1,inPrologue(state)&&!story().sprout);")
# ---- settings: frame-rate limit is its own setting; picture quality only sets sharpness; effects cover light, particles, shake ----
R("const QUALITY={smooth:{fps:60,area:560000,density:1.6},eco:{fps:30,area:300000,density:1},detail:{fps:120,area:1300000,density:2.5}};",
  "const QUALITY={smooth:{area:560000,density:1.6},eco:{area:300000,density:1},detail:{area:1300000,density:2.5}};\nconst FPS_CAPS=['30','60','120'];")
R("const prefs={quality:'smooth',","const prefs={fpsCap:'',quality:'smooth',")
R(" for(const k of Object.keys(prefs))if(p[k]!==undefined&&typeof p[k]===typeof prefs[k])prefs[k]=p[k];if(!QUALITY[prefs.quality])prefs.quality='smooth';}catch{}",
  " for(const k of Object.keys(prefs))if(p[k]!==undefined&&typeof p[k]===typeof prefs[k])prefs[k]=p[k];if(!QUALITY[prefs.quality])prefs.quality='smooth';}catch{}\n// Before v0.13 the quality preset also set the frame rate (saver 30, detail 120); keep that for players who picked it.\nif(!FPS_CAPS.includes(prefs.fpsCap))prefs.fpsCap=prefs.quality==='eco'?'30':prefs.quality==='detail'?'120':'60';")
R(" quality:v=>{prefs.quality=v;adaptiveScale=1;slowWindows=0;ecoFallback=false;resize();},"," quality:v=>{prefs.quality=v;adaptiveScale=1;slowWindows=0;resize();},\n fpsCap:v=>{if(!FPS_CAPS.includes(v))return;prefs.fpsCap=v;ecoFallback=false;slowWindows=0;},")
R(" const Q=QUALITY[prefs.quality],fps=ecoFallback?Q.fps/2:Q.fps,every=Math.max(1,Math.round(1000/fps/rafDelta));rafCount++;",
  " const cap=+prefs.fpsCap,fps=ecoFallback?cap/2:cap,every=Math.max(1,Math.round(1000/fps/rafDelta));rafCount++;")
# light glows and the bunker alarm wash follow the Effects switch
R("function drawStationLight(){const A=rendered.station,G=GROUND,st=story();if(camera.x>520||camera.x+VW<180)return;","function drawStationLight(){const A=rendered.station,G=GROUND,st=story();if(!prefs.effects||camera.x>620||camera.x+VW<180)return;")
R("if(on){ctx.globalAlpha=.1;rect(ax-22,top+38,54,44,'#ff3a2a');","if(on&&prefs.effects){ctx.globalAlpha=.1;rect(ax-22,top+38,54,44,'#ff3a2a');")
open(p,'w').write(s)
p='/home/user/Xenke/dist/index.html';h=open(p).read()
a='<div class="field row"><label data-i18n="set.effects"></label>'
assert h.count(a)==1
h=h.replace(a,'<div class="field"><label data-i18n="set.fpsCap"></label><div class="seg" data-setting="fpsCap"><button data-value="30" data-i18n="fps.30"></button><button data-value="60" data-i18n="fps.60"></button><button data-value="120" data-i18n="fps.120"></button></div><p class="sheet-note" data-i18n="set.fpsCapNote"></p></div>\n  '+a)
open(p,'w').write(h);print('ok')
