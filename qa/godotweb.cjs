// Opens the Godot web build on an emulated phone, walks to the filter by touch and saves screenshots.
const {chromium}=require('playwright');const url=process.argv[2]||'http://localhost:8124/index.html';const out=__dirname+'/out/godotweb';require('fs').mkdirSync(out,{recursive:true});
(async()=>{const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});const ctx=await b.newContext({viewport:{width:844,height:390},hasTouch:true,isMobile:true,deviceScaleFactor:2});
const p=await ctx.newPage();const logs=[];p.on('console',m=>logs.push(m.type()+': '+m.text()));p.on('pageerror',e=>logs.push('pageerror: '+e.message));
const t0=Date.now();await p.goto(url);await p.waitForFunction(()=>document.querySelector('#status')?.style.display==='none'||document.querySelector('#status')?.style.visibility==='hidden',null,{timeout:90000}).catch(e=>logs.push('wait: '+e.message));
console.log('loaded in',((Date.now()-t0)/1000).toFixed(1),'s');await p.waitForTimeout(2500);await p.screenshot({path:out+'/1-start.png'});
const cdp=await ctx.newCDPSession(p);const T=(t,pts)=>cdp.send('Input.dispatchTouchEvent',{type:t,touchPoints:pts});
// right button sits at about x=8+44+6+22, y=height-30 (scaled UI)
await T('touchStart',[{x:80,y:360,id:1}]);await p.waitForTimeout(700);await T('touchEnd',[]);await p.waitForTimeout(400);await p.screenshot({path:out+'/2-walked.png'});
const fps=await p.evaluate(()=>new Promise(r=>{let n=0;const t=performance.now();const f=()=>{n++;if(performance.now()-t<2000)requestAnimationFrame(f);else r(n/2);};requestAnimationFrame(f);}));console.log('browser rAF fps',fps);
console.log(logs.filter(l=>!/^log: /.test(l)).slice(0,12).join('\n'));await b.close();})();
