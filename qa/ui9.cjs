const {chromium}=require('playwright');const S=process.argv[2];
(async()=>{const b=await chromium.launch();const res=[];
for(const [w,h,hand] of [[360,740,'left'],[320,640,'left'],[640,320,'left'],[844,390,'right']]){const ctx=await b.newContext({viewport:{width:w,height:h},hasTouch:true,isMobile:true,deviceScaleFactor:2});
 await ctx.addInitScript(([hand])=>{if(!sessionStorage.getItem('x')){sessionStorage.setItem('x','1');localStorage.setItem('afterfall-last-greenhouse-v3',JSON.stringify({version:3,time:60,hero:'einstein',scene:'surface',inv:{wood:3,stone:0,scrap:0,cloth:0,fuse:0,seed:0,dirty:0,water:0,planter:0,berry:2,ammo:12,ore:0,wire:0,medkit:0,can:0},built:{bench:false,filter:false,generator:false,purifier:false,torch:false},beds:[false,false,false],vault:false,harvested:{},player:{x:500,y:284},stats:{hp:90,food:80,thirst:80},defense:{time:0,hp:100,wave:0},completed:false,forest:[false,false,false]}));localStorage.setItem('afterfall-controls-v3',JSON.stringify({hand,music:0,sfx:0}));}},[hand]);
 const p=await ctx.newPage();await p.goto('http://localhost:8123/index.html');await p.waitForFunction(()=>!document.querySelector('#start-btn').disabled);await p.tap('#start-btn');await p.waitForTimeout(4200);
 // Overlap check between all controls and HUD blocks.
 const r=await p.evaluate(()=>{const sel=['#jump','#action','#attack','#shoot','#hotbar','#quest','.hero-card','.hud-right','#target-label'];const boxes=sel.map(s=>[s,document.querySelector(s)?.getBoundingClientRect()]).filter(([s,b])=>b&&b.width);const out=[];
  for(let i=0;i<boxes.length;i++)for(let j=i+1;j<boxes.length;j++){const [a,A]=boxes[i],[c,B]=boxes[j];const ox=Math.min(A.right,B.right)-Math.max(A.left,B.left),oy=Math.min(A.bottom,B.bottom)-Math.max(A.top,B.top);if(ox>2&&oy>2)out.push(a+'×'+c);}
  const off=boxes.filter(([s,b])=>b.left<0||b.right>innerWidth||b.top<0||b.bottom>innerHeight).map(([s])=>s);return {overlaps:out,offscreen:off};});
 await p.screenshot({path:`${S}/ui-${w}x${h}.png`});res.push(`${w}x${h} ${hand}: ${JSON.stringify(r)}`);await ctx.close();}
console.log(res.join('\n'));await b.close();})();
