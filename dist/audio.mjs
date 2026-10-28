// Sound effects and generative music on Web Audio; no audio files are downloaded.
// The context is created on the first user gesture (browsers block audio before that).
let ac=null,master,musicBus,sfxBus,noiseBuf,timer=null,nextTime=0,step=0,mood='city',enabled=true;
const vol={music:.5,sfx:.8};
const MOODS={
 // Chords as semitone offsets from A3 (220 Hz); each lasts one bar of 16 steps.
 city:{bpm:84,chords:[[0,3,7],[-4,0,3],[3,7,10],[-2,2,5]],arp:[0,1,2,1,2,3,2,1],drums:false},
 forest:{bpm:76,chords:[[-7,-4,0],[-11,-7,-4],[-4,0,3],[-5,-2,2]],arp:[0,2,1,3,2,1,0,2],drums:false},
 mine:{bpm:70,chords:[[-12,-9,-5],[-14,-10,-7],[-16,-12,-9],[-11,-7,-4]],arp:[0,2,0,1,0,2,1,0],drums:false},
 defense:{bpm:112,chords:[[0,3,7],[-2,2,5],[-4,0,3],[-5,-1,2]],arp:[0,1,2,3,2,1,2,3],drums:true},
};
const hz=semi=>220*Math.pow(2,semi/12);
export function initAudio(){if(ac)return ac.state==='suspended'?ac.resume():undefined;const C=window.AudioContext||window.webkitAudioContext;if(!C)return;
 try{ac=new C();master=ac.createGain();master.connect(ac.destination);musicBus=ac.createGain();sfxBus=ac.createGain();musicBus.connect(master);sfxBus.connect(master);applyVolume();
  noiseBuf=ac.createBuffer(1,ac.sampleRate,ac.sampleRate);const d=noiseBuf.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;startWind();startMusic();}catch{ac=null;}}
export function setVolume(kind,v){vol[kind]=Math.max(0,Math.min(1,v));applyVolume();if(kind==='music')vol.music>0?startMusic():stopMusic();}
export function getVolume(kind){return vol[kind];}
function applyVolume(){if(!ac)return;const t=ac.currentTime;musicBus.gain.setTargetAtTime(vol.music*.2,t,.05);sfxBus.gain.setTargetAtTime(vol.sfx*.9,t,.02);if(wind)wind.gain.gain.setTargetAtTime(vol.music*.018,t,.3);}
// Pause everything while the page is hidden or the game is paused at the OS level.
export function setActive(on){enabled=on;if(!ac)return;if(on){ac.resume?.();startMusic();}else{stopMusic();ac.suspend?.();}}
export function setMood(m){if(MOODS[m])mood=m;}
function env(g,t,a,peak,len){g.gain.setValueAtTime(0.0001,t);g.gain.exponentialRampToValueAtTime(peak,t+a);g.gain.exponentialRampToValueAtTime(0.0001,t+len);}
function osc(type,f,t,len,peak,bus,{a=.005,slide=0,filter=0}={}){const o=ac.createOscillator(),g=ac.createGain();o.type=type;o.frequency.setValueAtTime(f,t);if(slide)o.frequency.exponentialRampToValueAtTime(Math.max(20,slide),t+len);let n=o;if(filter){const fl=ac.createBiquadFilter();fl.type='lowpass';fl.frequency.value=filter;o.connect(fl);n=fl;}n.connect(g);g.connect(bus);env(g,t,a,peak,len);o.start(t);o.stop(t+len+.05);}
function noise(t,len,peak,bus,{type='bandpass',freq=1200,q=1}={}){const s=ac.createBufferSource(),f=ac.createBiquadFilter(),g=ac.createGain();s.buffer=noiseBuf;f.type=type;f.frequency.value=freq;f.Q.value=q;s.connect(f);f.connect(g);g.connect(bus);env(g,t,.004,peak,len);s.start(t,Math.random()*.5);s.stop(t+len+.05);}
// Named effects, so the game says what happened rather than which frequency to play.
const FX={
 jump:t=>osc('square',260,t,.09,.18,sfxBus,{slide:420,filter:2200}),
 land:t=>noise(t,.06,.25,sfxBus,{freq:400}),
 swing:t=>noise(t,.08,.18,sfxBus,{type:'highpass',freq:1800}),
 hit:t=>{osc('square',180,t,.08,.35,sfxBus,{slide:80,filter:1400});noise(t,.07,.3,sfxBus,{freq:900});},
 heavy:t=>{osc('sawtooth',140,t,.16,.4,sfxBus,{slide:50,filter:900});noise(t,.12,.35,sfxBus,{freq:500});},
 shoot:t=>{osc('triangle',700,t,.07,.25,sfxBus,{slide:240});noise(t,.05,.15,sfxBus,{type:'highpass',freq:2500});},
 chop:t=>{noise(t,.07,.4,sfxBus,{freq:650,q:2});osc('triangle',150,t,.06,.25,sfxBus,{slide:90});},
 pick:t=>{osc('square',1250,t,.05,.18,sfxBus,{filter:3000});noise(t,.05,.25,sfxBus,{freq:2600,q:3});},
 water:t=>{for(let i=0;i<3;i++)osc('sine',500+i*170,t+i*.05,.08,.14,sfxBus,{slide:900+i*120});},
 gain:t=>{osc('square',660,t,.08,.14,sfxBus,{filter:2500});osc('square',990,t+.07,.12,.14,sfxBus,{filter:2500});},
 craft:t=>{[523,659,784].forEach((f,i)=>osc('triangle',f,t+i*.06,.14,.2,sfxBus));},
 plant:t=>{[392,523,659,784].forEach((f,i)=>osc('sine',f,t+i*.08,.25,.18,sfxBus));},
 hurt:t=>{osc('sawtooth',220,t,.22,.3,sfxBus,{slide:90,filter:1100});},
 mob:t=>{osc('sawtooth',120,t,.18,.22,sfxBus,{slide:70,filter:700});},
 warn:t=>{osc('square',330,t,.06,.12,sfxBus,{filter:1600});osc('square',330,t+.1,.06,.12,sfxBus,{filter:1600});},
 click:t=>osc('square',880,t,.03,.1,sfxBus,{filter:3000}),
 win:t=>{[523,659,784,1047].forEach((f,i)=>osc('triangle',f,t+i*.12,.4,.22,sfxBus));},
};
export function sfx(name){if(!ac||!enabled||vol.sfx<=0||!FX[name])return;try{FX[name](ac.currentTime+.005);}catch{}}
// Soft wind bed under the music.
let wind=null;function startWind(){if(!ac||wind)return;const s=ac.createBufferSource(),f=ac.createBiquadFilter(),g=ac.createGain();s.buffer=noiseBuf;s.loop=true;f.type='lowpass';f.frequency.value=380;s.connect(f);f.connect(g);g.connect(master);g.gain.value=0;s.start();wind={gain:g};applyVolume();}
function startMusic(){if(!ac||timer||vol.music<=0||!enabled)return;nextTime=ac.currentTime+.1;timer=setInterval(schedule,40);}
function stopMusic(){if(timer){clearInterval(timer);timer=null;}}
// Look-ahead scheduler: queue the notes of the next ~0.15 s on the audio clock.
function schedule(){const m=MOODS[mood],dur=60/m.bpm/4;while(nextTime<ac.currentTime+.15){playStep(m,step,nextTime,dur);nextTime+=dur;step=(step+1)%64;}}
function playStep(m,s,t,dur){const bar=Math.floor(s/16),i=s%16,chord=m.chords[bar%m.chords.length];
 if(i===0)chord.forEach((c,k)=>{osc('triangle',hz(c),t,dur*16,.07,musicBus,{a:.6,filter:900});osc('triangle',hz(c)*1.004,t,dur*16,.05,musicBus,{a:.8,filter:700});});
 if(i===0||i===8)osc('sine',hz(chord[0]-12),t,dur*7,.22,musicBus,{a:.02});
 if(i%2===0&&((s*7+bar*3)%5!==0)){const note=chord[m.arp[(i/2)%m.arp.length]%3]+(m.arp[(i/2)%m.arp.length]>2?12:12);osc('square',hz(note),t,dur*1.6,.035,musicBus,{filter:1800});}
 if(m.drums){if(i%4===0)osc('sine',120,t,.14,.5,musicBus,{slide:45});if(i%2===1)noise(t,.03,.12,musicBus,{type:'highpass',freq:6000});if(i===4||i===12)noise(t,.09,.18,musicBus,{freq:1800});}
}
