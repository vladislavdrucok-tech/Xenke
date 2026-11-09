// HTML сторінок демо й презентації (рендер на сервері, без шаблонізаторів).
import { escapeHtml as h, formatMoney, formatPhone, KYIV_TZ } from './util.mjs';

function sellerLine(seller) {
  return [seller.name, seller.phone, seller.telegram && `Telegram ${seller.telegram}`, seller.email].filter(Boolean).map(h).join(' · ');
}

export function renderDemoPage({ clinic, kb, config }) {
  const color = clinic.brandColor;
  const prices = kb.prices.slice(0, 6);
  const mock = `
    <section class="mock">
      <header><div class="logo" style="background:${h(color)}">${h(clinic.name.slice(0, 1))}</div><div><b>${h(clinic.name)}</b><span>${h(kb.url.replace(/^https?:\/\//, ''))}</span></div>
      <div class="ph">${kb.facts.phones.slice(0, 1).map((p) => h(formatPhone(p))).join('')}</div></header>
      <div class="hero"><h1>${h(clinic.name)}</h1><p>${h(kb.facts.addresses[0] || 'Стоматологічна клініка')}</p>
      ${kb.facts.hours[0] ? `<p class="muted">${h(kb.facts.hours[0])}</p>` : ''}</div>
      ${prices.length ? `<div class="cards">${prices.map((p) => `<div class="card">${h(p.text)}</div>`).join('')}</div>` : ''}
      <p class="note">Макет замість вашого сайту: тут лише дані, які бот узяв із ${h(kb.url)}.</p>
    </section>`;
  return `<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex,nofollow">
<title>Демо для ${h(clinic.name)}</title>
<style>
:root{--brand:${h(color)};--ink:#14212b;--muted:#5b6b78;--bg:#eef2f5}
*{box-sizing:border-box}body{margin:0;font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;color:var(--ink);background:var(--bg)}
.bar{position:sticky;top:0;z-index:5;display:flex;gap:16px;align-items:center;justify-content:space-between;flex-wrap:wrap;padding:10px 16px;background:#14212b;color:#fff;font-size:14px}
.bar b{color:#fff}.bar .by{opacity:.75;font-size:13px}
.site{max-width:1366px;margin:0 auto}
.shot{display:block;width:100%;height:auto;filter:saturate(.95)}
.mock{background:#fff;min-height:calc(100vh - 44px);padding:0 0 60px}
.mock header{display:flex;align-items:center;gap:12px;padding:16px 24px;border-bottom:1px solid #e3e8ec}
.mock header span{display:block;color:var(--muted);font-size:13px}.mock .ph{margin-left:auto;font-weight:600}
.logo{width:40px;height:40px;border-radius:10px;color:#fff;display:grid;place-items:center;font-weight:700;font-size:20px}
.hero{padding:56px 24px 24px;max-width:760px}.hero h1{font-size:clamp(28px,5vw,44px);line-height:1.1;margin:0 0 12px}
.muted{color:var(--muted)}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:12px;padding:12px 24px}
.card{border:1px solid #e3e8ec;border-left:4px solid var(--brand);border-radius:10px;padding:12px 14px;background:#fbfcfd}
.note{padding:24px;color:var(--muted);font-size:13px}
@media (max-width:640px){.bar{font-size:13px}.mock header .ph{display:none}}
</style></head><body>
<div class="bar"><div><b>Демо для ${h(clinic.name)}</b> — так AI-адміністратор виглядатиме на вашому сайті. Запитайте про ціни, графік або спробуйте записатися.</div>
<div class="by">${sellerLine(config.seller)}</div></div>
<main class="site">${clinic.hasShot ? `<img class="shot" src="/shots/${h(clinic.slug)}.png" alt="Головна сторінка сайту ${h(clinic.name)}">` : mock}</main>
<script src="/widget.js" data-clinic="${h(clinic.slug)}" data-open="1" defer></script>
</body></html>`;
}

function delayText(audit) {
  if (!audit?.askedAt) return null;
  const asked = new Date(audit.askedAt);
  const fmt = new Intl.DateTimeFormat('uk-UA', { timeZone: KYIV_TZ, weekday: 'long', hour: '2-digit', minute: '2-digit' });
  const askedText = fmt.format(asked);
  if (!audit.answeredAt) return { askedText, text: 'відповіді досі немає' };
  const mins = Math.max(0, Math.round((new Date(audit.answeredAt) - asked) / 60000));
  const hh = Math.floor(mins / 60), mm = mins % 60;
  return { askedText, text: hh ? `через ${hh} год${mm ? ` ${mm} хв` : ''}` : `через ${mm} хв`, mins };
}

export function renderPitchPage({ clinic, kb, config, dialog }) {
  const offer = { ...config.offer, ...(clinic.offer || {}) };
  const rate = offer.uahPerUsd || 42;
  const color = clinic.brandColor;
  const audit = delayText(clinic.audit);
  const ip = kb.implantPrice;
  const implantUah = ip ? (ip.currency === 'USD' ? ip.amount * rate : ip.currency === 'EUR' ? ip.amount * rate * 1.08 : ip.amount) : null;
  const patients = implantUah ? Math.max(1, Math.ceil((offer.setupUsd * rate) / implantUah)) : null;
  const monthlyShare = implantUah ? (offer.monthlyUsd * rate) / implantUah : null;
  const demoUrl = `${config.publicUrl}/demo/${clinic.slug}`;
  const turns = (dialog || []).slice(0, 3);
  const channel = clinic.audit?.channel || 'месенджер';

  const slide1 = audit
    ? `<p class="kicker">Перевірка, яку ми зробили</p>
       <h1>Пацієнт написав вам у ${h(channel)} — <span class="hl">${h(audit.text)}</span></h1>
       <p class="lead">${h(audit.askedText)} ми надіслали звичайне питання пацієнта. ${audit.mins == null || audit.mins > 60 ? 'За цей час людина з болем чи з питанням про імплант зазвичай уже пише в іншу клініку.' : 'Це добрий результат — але вночі й у вихідні так відповідати складно.'}</p>`
    : `<p class="kicker">${h(clinic.name)}</p>
       <h1>Пацієнти пишуть увечері й у вихідні, <span class="hl">а відповідь отримують зранку</span></h1>
       <p class="lead">Поки адміністратор зайнятий чи клініка зачинена, питання про ціну імпланта або біль чекає. За цей час пацієнт може записатися в іншу клініку.</p>`;

  const dialogHtml = turns.length
    ? turns.map((t) => `<div class="msg me">${h(t.q)}</div><div class="msg bot">${h(t.a).replace(/\n/g, '<br>')}</div>`).join('')
    : '<p class="lead">Живе демо відкриємо прямо зараз за посиланням нижче.</p>';

  const econ = implantUah
    ? `<div class="big"><span>Імплантація у вас</span><b>від ${h(formatMoney(ip.amount, ip.currency))}</b><small>з вашого сайту: «${h(ip.text.slice(0, 90))}»</small></div>
       <div class="big"><span>Впровадження</span><b>$${h(offer.setupUsd)}</b><small>≈ ${patients} ${patients === 1 ? 'пацієнт' : patients < 5 ? 'пацієнти' : 'пацієнтів'} на імплантацію (лише імплант, без коронки)</small></div>
       <div class="big"><span>Супровід</span><b>$${h(offer.monthlyUsd)}/міс</b><small>${monthlyShare < 1 ? `менше ніж ${Math.max(1, Math.round(monthlyShare * 100))}% вартості одного імпланта` : 'хостинг, AI, оновлення бази знань'}</small></div>`
    : `<div class="big"><span>Впровадження</span><b>$${h(offer.setupUsd)}</b><small>налаштування під вашу клініку, запуск на сайті й у Telegram</small></div>
       <div class="big"><span>Супровід</span><b>$${h(offer.monthlyUsd)}/міс</b><small>хостинг, AI, оновлення бази знань</small></div>
       <div class="big"><span>Окупність</span><b>1 записаний пацієнт</b><small>на імплантацію чи протезування зазвичай перекриває місяць супроводу</small></div>`;

  return `<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex,nofollow">
<title>AI-адміністратор для ${h(clinic.name)}</title>
<style>
:root{--brand:${h(color)};--ink:#13202a;--muted:#5a6a77;--line:#e2e8ed;--bg:#f3f6f8}
*{box-sizing:border-box}html,body{margin:0;height:100%}
body{font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;color:var(--ink);background:#0f1a22}
.deck{height:100%;display:grid;place-items:center;padding:16px}
.slide{display:none;width:min(1200px,100%);aspect-ratio:16/9;background:#fff;border-radius:18px;padding:clamp(20px,5vw,64px);position:relative;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.35)}
.slide.on{display:flex;flex-direction:column;justify-content:center}
.slide::before{content:"";position:absolute;inset:0 auto 0 0;width:10px;background:var(--brand)}
.kicker{text-transform:uppercase;letter-spacing:.08em;font-size:13px;font-weight:700;color:var(--brand);margin:0 0 12px}
h1{font-size:clamp(24px,4vw,48px);line-height:1.12;margin:0 0 18px;max-width:22ch}
h2{font-size:clamp(22px,3.2vw,38px);line-height:1.15;margin:0 0 20px}
.hl{color:var(--brand)}.lead{font-size:clamp(15px,1.7vw,21px);color:var(--muted);max-width:52ch;margin:0}
.chat{display:flex;flex-direction:column;gap:8px;max-width:760px;overflow:auto}
.msg{padding:10px 14px;border-radius:14px;max-width:80%;font-size:clamp(13px,1.35vw,16px)}
.me{align-self:flex-end;background:var(--brand);color:#fff;border-bottom-right-radius:4px}
.bot{align-self:flex-start;background:var(--bg);border-bottom-left-radius:4px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px}
.card{border:1px solid var(--line);border-radius:14px;padding:16px 18px;background:#fbfcfd}
.card b{display:block;font-size:clamp(15px,1.6vw,19px);margin-bottom:4px}.card span{color:var(--muted);font-size:clamp(13px,1.3vw,15px)}
.big{border-top:3px solid var(--brand);padding:14px 0}.big span{display:block;color:var(--muted);font-size:14px}
.big b{display:block;font-size:clamp(24px,3.4vw,42px);line-height:1.1;margin:4px 0}.big small{color:var(--muted);font-size:13px}
ul.terms{margin:0;padding-left:20px;font-size:clamp(15px,1.7vw,20px)}ul.terms li{margin:6px 0}
.foot{position:absolute;left:clamp(20px,5vw,64px);right:clamp(20px,5vw,64px);bottom:18px;display:flex;justify-content:space-between;color:var(--muted);font-size:12px}
a{color:var(--brand)}
.nav{position:fixed;bottom:14px;left:50%;transform:translateX(-50%);display:flex;gap:8px}
.nav button{width:11px;height:11px;border-radius:50%;border:0;background:#4b5b66;cursor:pointer;padding:0}.nav button.on{background:#fff}
.meta{font-size:13px;color:var(--muted);margin-top:14px}
@media print{@page{size:landscape;margin:0}body{background:#fff}.deck{display:block;padding:0}.slide{display:flex!important;flex-direction:column;justify-content:center;page-break-after:always;box-shadow:none;border-radius:0;width:100%;height:100vh;aspect-ratio:auto}.nav{display:none}}
@media (max-width:700px){.slide{aspect-ratio:auto;min-height:80vh}}
</style></head><body>
<div class="deck">
<section class="slide on">${slide1}<div class="foot"><span>${h(clinic.name)}</span><span>1 / 5</span></div></section>

<section class="slide"><p class="kicker">Рішення</p><h2>AI-адміністратор, який уже знає <span class="hl">вашу клініку</span></h2>
<div class="chat">${dialogHtml}</div>
<p class="meta">Навчений на ${kb.stats.pages} сторінках вашого сайту${kb.prices.length ? ` і ${kb.prices.length} рядках прайсу` : ''}. Спробуйте самі: <a href="${h(demoUrl)}">${h(demoUrl.replace(/^https?:\/\//, ''))}</a></p>
<div class="foot"><span>${turns.length ? 'Відповіді вище — справжні, з демо для вашого сайту' : h(clinic.name)}</span><span>2 / 5</span></div></section>

<section class="slide"><p class="kicker">Що отримує клініка</p><h2>Жодне звернення не чекає до ранку</h2>
<div class="grid">
<div class="card"><b>Відповідь за секунди, 24/7</b><span>Ціни, послуги, адреса, графік — з вашого сайту й прайсу, мовою пацієнта.</span></div>
<div class="card"><b>Заявки — одразу в Telegram</b><span>Ім'я, телефон, послуга й зручний час приходять адміністратору миттєво.</span></div>
<div class="card"><b>Не вигадує й не лікує</b><span>Чого немає на сайті — передає людині. Діагнозів не ставить; при гострому болю радить дзвонити.</span></div>
<div class="card"><b>Видно, про що питають</b><span>Усі діалоги й заявки в кабінеті: які послуги цікавлять, о котрій пишуть.</span></div>
</div><div class="foot"><span>Сайт + Telegram-бот клініки</span><span>3 / 5</span></div></section>

<section class="slide"><p class="kicker">Економіка</p><h2>Окупається кількома записаними пацієнтами</h2>
<div class="grid">${econ}</div>
<div class="foot"><span>Розрахунок за курсом ${rate} грн/$</span><span>4 / 5</span></div></section>

<section class="slide"><p class="kicker">Пропозиція</p><h2>Запуск за ${h(offer.launchHours)} годин</h2>
<ul class="terms">
<li>Впровадження <b>$${h(offer.setupUsd)}</b>: 50% передоплата, 50% після запуску.</li>
<li>Супровід <b>$${h(offer.monthlyUsd)}/міс</b>: хостинг, AI, оновлення цін і послуг.</li>
${offer.guaranteeDays > 0 ? `<li>Гарантія: якщо за ${h(offer.guaranteeDays)} днів через бота не прийде жодної заявки — повертаю оплату за впровадження.</li>` : ''}
<li>Від вас: доступ до сайту (або ваш розробник додає один рядок коду) і Telegram адміністратора.</li>
${offer.slots ? `<li>Цього тижня беру ${h(offer.slots)} клініки: налаштовую кожну вручну.</li>` : ''}
</ul>
<p class="meta">${sellerLine(config.seller)}</p>
<div class="foot"><span>${h(clinic.name)}</span><span>5 / 5</span></div></section>
</div>
<nav class="nav" aria-label="Слайди"></nav>
<script>
const slides=[...document.querySelectorAll('.slide')];const nav=document.querySelector('.nav');let i=0;
slides.forEach((_,n)=>{const b=document.createElement('button');b.setAttribute('aria-label','Слайд '+(n+1));b.onclick=()=>go(n);nav.appendChild(b)});
function go(n){i=Math.max(0,Math.min(slides.length-1,n));slides.forEach((s,k)=>s.classList.toggle('on',k===i));[...nav.children].forEach((b,k)=>b.classList.toggle('on',k===i))}
addEventListener('keydown',e=>{if(['ArrowRight','PageDown',' '].includes(e.key)){e.preventDefault();go(i+1)}if(['ArrowLeft','PageUp'].includes(e.key)){e.preventDefault();go(i-1)}});
document.querySelector('.deck').addEventListener('click',e=>{if(e.target.closest('a'))return;go(e.clientX>innerWidth/2?i+1:i-1)});go(0);
</script></body></html>`;
}
