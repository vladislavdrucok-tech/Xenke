// Bakes the workshop props from dist/station-art.mjs into PNGs for the Godot project (needs `python3 -m http.server 8123 --directory dist`).
const {chromium}=require('playwright');const fs=require('fs');const out=__dirname+'/../assets/station/';
(async()=>{const b=await chromium.launch();const p=await b.newPage();await p.goto('http://localhost:8123/index.html');
const pngs=await p.evaluate(async()=>{const m=await import('./station-art.mjs');const a=m.bakeStationArt(document);const r={};for(const [k,c] of Object.entries(a))r[k]=c.toDataURL('image/png');return {r,machine:m.MACHINE,P:m.P};});
for(const [k,d] of Object.entries(pngs.r))fs.writeFileSync(out+k+'.png',Buffer.from(d.split(',')[1],'base64'));
fs.writeFileSync(__dirname+'/../data/machine.json',JSON.stringify({...pngs.machine,P:pngs.P}));console.log(Object.keys(pngs.r).join(' '));await b.close();})();
