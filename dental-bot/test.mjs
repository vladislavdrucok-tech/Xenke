// Тести без мережі: вигаданий сайт клініки, заглушка Claude API (SSE) і заглушка Telegram.
//   node test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import Anthropic from '@anthropic-ai/sdk';
import { createApp } from './server.mjs';
import { echoableContent, guessNameFromText, validateLeadInput } from './src/assistant.mjs';
import { loadConfig, ROOT } from './src/config.mjs';
import { crawlSite, parseRobots } from './src/crawl.mjs';
import { createDemo } from './src/demo.mjs';
import { htmlToText } from './src/extract.mjs';
import { buildKb, searchKb } from './src/kb.mjs';
import { serveStatic } from './src/static.mjs';
import { findPhones, normalizePhone, parseCsv, slugFromUrl, toCsv } from './src/util.mjs';

const listen = (server) => new Promise((r) => server.listen(0, '127.0.0.1', () => r(`http://127.0.0.1:${server.address().port}`)));
const close = (server) => new Promise((r) => server.close(r));

const site = serveStatic(join(ROOT, 'examples', 'sample-clinic'));
const SITE = await listen(site);

// ---- Заглушка Telegram: запам'ятовує всі виклики ----
const tgCalls = [];
const tg = createServer(async (req, res) => {
  let body = '';
  for await (const c of req) body += c;
  tgCalls.push({ method: req.url.split('/').pop(), body: JSON.parse(body || '{}') });
  res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify({ ok: true, result: {} }));
});
const TG = await listen(tg);

// ---- Заглушка Claude Messages API (стрімінг SSE) ----
const claude = { requests: [], queue: [] };
function sse(res, msg) {
  res.writeHead(200, { 'Content-Type': 'text/event-stream' });
  const ev = (type, data) => res.write(`event: ${type}\ndata: ${JSON.stringify({ type, ...data })}\n\n`);
  ev('message_start', { message: { id: `msg_${claude.requests.length}`, type: 'message', role: 'assistant', model: 'claude-opus-5-5', content: [], stop_reason: null, stop_sequence: null, usage: { input_tokens: 100, output_tokens: 1, cache_read_input_tokens: 900, cache_creation_input_tokens: 0 } } });
  msg.content.forEach((b, index) => {
    if (b.type === 'thinking') {
      ev('content_block_start', { index, content_block: { type: 'thinking', thinking: '', signature: '' } });
      ev('content_block_delta', { index, delta: { type: 'signature_delta', signature: b.signature } });
    } else if (b.type === 'text') {
      ev('content_block_start', { index, content_block: { type: 'text', text: '' } });
      const half = Math.ceil(b.text.length / 2);
      ev('content_block_delta', { index, delta: { type: 'text_delta', text: b.text.slice(0, half) } });
      ev('content_block_delta', { index, delta: { type: 'text_delta', text: b.text.slice(half) } });
    } else if (b.type === 'tool_use') {
      ev('content_block_start', { index, content_block: { type: 'tool_use', id: b.id, name: b.name, input: {} } });
      const json = JSON.stringify(b.input);
      ev('content_block_delta', { index, delta: { type: 'input_json_delta', partial_json: json.slice(0, 10) } });
      ev('content_block_delta', { index, delta: { type: 'input_json_delta', partial_json: json.slice(10) } });
    }
    ev('content_block_stop', { index });
  });
  ev('message_delta', { delta: { stop_reason: msg.stop_reason, stop_sequence: null }, usage: { output_tokens: 40 } });
  ev('message_stop', {});
  res.end();
}
const claudeServer = createServer(async (req, res) => {
  let body = '';
  for await (const c of req) body += c;
  claude.requests.push({ url: req.url, headers: req.headers, body: JSON.parse(body) });
  const next = claude.queue.shift();
  if (!next) { res.writeHead(500).end('{"type":"error","error":{"type":"api_error","message":"queue empty"}}'); return; }
  if (next.status) { res.writeHead(next.status, { 'Content-Type': 'application/json' }).end(JSON.stringify({ type: 'error', error: { type: 'api_error', message: 'boom' } })); return; }
  sse(res, next);
});
const CLAUDE = await listen(claudeServer);
const thinking = (n) => ({ type: 'thinking', signature: `sig-${n}` });
const text = (t) => ({ type: 'text', text: t });

async function makeApp({ ai }) {
  const dataDir = await mkdtemp(join(tmpdir(), 'dental-test-'));
  const config = loadConfig({
    file: join(dataDir, 'none.json'),
    env: { DATA_DIR: dataDir, AI_MODE: ai ? 'on' : 'off', ADMIN_PASSWORD: 'pw', TELEGRAM_BOT_TOKEN: 'TEST', TELEGRAM_ADMIN_CHAT_ID: '42', TELEGRAM_API_BASE: TG, PUBLIC_URL: 'https://demo.example' },
  });
  const quiet = { log() {}, warn() {}, error() {} };
  const client = ai ? new Anthropic({ apiKey: 'test-key', baseURL: CLAUDE, maxRetries: 0 }) : undefined;
  const app = await createApp({ config, log: quiet, assistantClient: client });
  const base = await listen(app.server);
  const demo = await createDemo(`${SITE}/`, { store: app.store, config, assistant: app.assistant, slug: 'demodent', screenshot: false, sample: false });
  const chat = async (message, conversationId) => {
    const r = await fetch(`${base}/api/chat`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ clinic: 'demodent', message, conversationId }) });
    return r.json();
  };
  return { ...app, base, demo, chat, dataDir, done: async () => { await close(app.server); await rm(dataDir, { recursive: true, force: true }); } };
}

test('телефони нормалізуються', () => {
  assert.equal(normalizePhone('067 123 45 67'), '+380671234567');
  assert.equal(normalizePhone('+38 (044) 123-45-67'), '+380441234567');
  assert.equal(normalizePhone('80501234567'), '+380501234567');
  assert.equal(normalizePhone('abc'), null);
  assert.equal(normalizePhone('12345'), null);
  assert.deepEqual(findPhones('Олена, 050-111-22-33, або +380 67 999 88 77'), ['+380501112233', '+380679998877']);
  assert.equal(slugFromUrl('https://www.smile-dent.com.ua/uk/'), 'smile-dent');
});

test('CSV: лапки й коми', () => {
  const rows = parseCsv('name,website\n"Клініка ""Усмішка"", Київ",https://a.ua\n');
  assert.equal(rows[0].name, 'Клініка "Усмішка", Київ');
  assert.equal(parseCsv(toCsv(rows))[0].name, rows[0].name);
});

test('HTML-таблиця стає рядками «послуга | ціна»', () => {
  const t = htmlToText('<table><tr><td>Імплант</td><td>18&nbsp;500 грн</td></tr></table><script>x=1</script><p>Текст</p>');
  assert.match(t, /Імплант \| 18 500 грн/);
  assert.doesNotMatch(t, /x=1/);
});

test('robots.txt: найдовше правило перемагає', () => {
  const allowed = parseRobots('User-agent: *\nDisallow: /admin/\nDisallow: /p*\nAllow: /price\n\nUser-agent: Googlebot\nDisallow: /');
  assert.equal(allowed('/admin/x'), false);
  assert.equal(allowed('/private'), false);
  assert.equal(allowed('/price'), true);
  assert.equal(allowed('/'), true);
});

test('обхід вигаданого сайту й база знань', async () => {
  const crawl = await crawlSite(`${SITE}/`);
  const urls = crawl.pages.map((p) => new URL(p.url).pathname);
  assert.ok(urls.includes('/tsiny') && urls.includes('/poslugy/implantatsiya') && urls.includes('/kontakty'));
  assert.ok(!urls.some((u) => u.startsWith('/ru')), 'російська версія не обходиться');
  assert.ok(!urls.some((u) => u.startsWith('/admin') || u.startsWith('/private')), 'robots.txt дотримано');
  assert.ok(crawl.skipped.robots >= 1 && crawl.skipped.language >= 1);
  assert.ok(urls.indexOf('/tsiny') < urls.indexOf('/blog/yak-dohlyadaty'), 'ціни обходяться раніше за блог');

  const kb = buildKb(crawl);
  assert.equal(kb.name, 'ДемоДент');
  assert.equal(kb.brandColor, '#1b8fa3');
  assert.deepEqual(kb.facts.phones.slice(0, 2).sort(), ['+380441234567', '+380671112233']);
  assert.ok(kb.facts.addresses[0].includes('Прикладна'));
  assert.ok(kb.facts.hours[0].includes('09:00'));
  assert.equal(kb.implantPrice.amount, 18500);
  assert.equal(kb.implantPrice.currency, 'UAH');
  assert.ok(kb.prices.length >= 10);
  assert.match(searchKb(kb, 'хто ставить імпланти Straumann')[0].text, /Straumann/);
});

test('echoableContent: після fallback прибирає thinking/tool_use до межі', () => {
  const content = [{ type: 'thinking', thinking: '', signature: 'a' }, { type: 'text', text: 'част' }, { type: 'tool_use', id: 't', name: 'x', input: {} },
    { type: 'fallback', from: { model: 'a' }, to: { model: 'b' } }, { type: 'thinking', thinking: '', signature: 'b' }, { type: 'text', text: 'відповідь' }];
  assert.deepEqual(echoableContent(content).map((b) => b.type), ['text', 'thinking', 'text']);
  const plain = [{ type: 'thinking', signature: 's' }, { type: 'text', text: 'ok' }];
  assert.equal(echoableContent(plain), plain);
});

test('валідація заявки й імені', () => {
  assert.equal(validateLeadInput({ name: 'Олена', phone: '0671234567' }).lead.phone, '+380671234567');
  assert.equal(validateLeadInput({ name: 'Олена', phone: '123' }).ok, false);
  assert.equal(validateLeadInput({ name: '', phone: '0671234567' }).ok, false);
  assert.equal(validateLeadInput({ name: 'Олена', phone: '0671234567', notes: 5 }).ok, false);
  assert.equal(guessNameFromText('Мене звати Андрій, 050 123 45 67'), 'Андрій');
  assert.equal(guessNameFromText('Добрий день! Ірина 0671234567'), 'Ірина');
});

test('локальний режим: чат, заявка, Telegram, сторінки, адмінка', async () => {
  const app = await makeApp({ ai: false });
  try {
    tgCalls.length = 0;
    const a = await app.chat('Скільки коштує імплант?');
    assert.match(a.reply, /18 500 грн/);
    assert.equal(a.mode, 'local');
    const b = await app.chat('Мене звати Андрій, 050 123 45 67', a.conversationId);
    assert.equal(b.leadSaved, true);
    assert.equal(b.conversationId, a.conversationId);
    assert.equal(tgCalls.length, 1);
    assert.equal(tgCalls[0].body.chat_id, '42');
    assert.match(tgCalls[0].body.text, /Андрій/);
    assert.match(tgCalls[0].body.text, /\+38 \(050\) 123-45-67/);
    // повторна заявка в тій самій розмові не дублюється
    await app.chat('Андрій, 050 123 45 67, краще після 18:00', a.conversationId);
    assert.equal((await app.store.listLeads()).length, 1);
    assert.equal(tgCalls.length, 1);

    const widget = await fetch(`${app.base}/widget.js`);
    assert.equal(widget.status, 200);
    assert.equal(widget.headers.get('access-control-allow-origin'), '*');
    const cfg = await (await fetch(`${app.base}/api/clinic/demodent`)).json();
    assert.equal(cfg.name, 'ДемоДент');
    assert.equal((await fetch(`${app.base}/api/clinic/nope`)).status, 404);

    const demo = await (await fetch(`${app.base}/demo/demodent`)).text();
    assert.match(demo, /data-clinic="demodent"/);
    const pitch = await (await fetch(`${app.base}/pitch/demodent`)).text();
    assert.match(pitch, /від 18\s500 грн/);
    assert.match(pitch, /≈ 4 пацієнти/);

    const badLead = await fetch(`${app.base}/api/lead`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ clinic: 'demodent', name: 'Іра', phone: '12' }) });
    assert.equal(badLead.status, 400);
    const okLead = await fetch(`${app.base}/api/lead`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ clinic: 'demodent', name: 'Іра', phone: '093 000 11 22', preferredTime: 'завтра зранку' }) });
    assert.equal(okLead.status, 200);

    assert.equal((await fetch(`${app.base}/admin`)).status, 401);
    const auth = { Authorization: `Basic ${Buffer.from('admin:pw').toString('base64')}` };
    assert.equal((await fetch(`${app.base}/admin`, { headers: { Authorization: `Basic ${Buffer.from('admin:wrong').toString('base64')}` } })).status, 401);
    const ov = await (await fetch(`${app.base}/admin/api/overview`, { headers: auth })).json();
    assert.equal(ov.leads.length, 2);
    assert.equal(ov.topics['Ціни'], 1);
    const csv = await (await fetch(`${app.base}/admin/leads.csv`, { headers: auth })).text();
    assert.match(csv, /\+38 \(093\) 000-11-22/);
    const upd = await fetch(`${app.base}/admin/api/clinic/demodent`, { method: 'POST', headers: { ...auth, 'Content-Type': 'application/json' },
      body: JSON.stringify({ audit: { channel: 'Instagram', askedAt: '2026-11-09T20:10:00.000Z', answeredAt: '2026-11-10T08:40:00.000Z' } }) });
    assert.equal(upd.status, 200);
    const pitch2 = await (await fetch(`${app.base}/pitch/demodent`)).text();
    assert.match(pitch2, /через 12 год 30 хв/);
  } finally {
    await app.done();
  }
});

test('AI-режим: формат запиту, кеш, заявка через інструмент, відмова, лише дописування історії', async () => {
  const app = await makeApp({ ai: true });
  try {
    tgCalls.length = 0;
    claude.requests.length = 0;
    claude.queue.push(
      { content: [thinking(1), text('На сайті вказано: імплант Osstem — 18 500 грн. Хочете записатися на консультацію?')], stop_reason: 'end_turn' },
      { content: [thinking(2), { type: 'tool_use', id: 'toolu_1', name: 'save_lead', input: { name: 'Олена', phone: '067 123 45 67', service: 'Імплантація' } }], stop_reason: 'tool_use' },
      { content: [text('Дякую, Олено! Адміністратор зателефонує вам найближчим часом.')], stop_reason: 'end_turn' },
      { content: [], stop_reason: 'refusal' },
      { content: [text('Будь ласка!')], stop_reason: 'end_turn' },
    );
    const r1 = await app.chat('Скільки коштує імплант?');
    assert.equal(r1.mode, 'ai');
    assert.match(r1.reply, /18 500/);

    const q1 = claude.requests[0];
    assert.match(q1.url, /^\/v1\/messages/);
    assert.match(q1.headers['anthropic-beta'], /server-side-fallback-2026-07-01/);
    assert.equal(q1.body.model, 'claude-opus-5-5');
    assert.equal(q1.body.fallbacks, 'default');
    assert.equal(q1.body.stream, true);
    assert.equal(q1.body.output_config.effort, 'low');
    assert.equal(q1.body.thinking, undefined);
    assert.equal(q1.body.temperature, undefined);
    assert.deepEqual(q1.body.system[0].cache_control, { type: 'ephemeral', ttl: '1h' });
    assert.deepEqual(q1.body.cache_control, { type: 'ephemeral' });
    assert.match(q1.body.system[0].text, /<knowledge_base>[\s\S]*18 500 грн/);
    assert.doesNotMatch(q1.body.system[0].text, /2026|Поточний час/, 'системний промпт без дати — інакше кеш не працює');
    assert.equal(q1.body.tools[0].name, 'save_lead');
    assert.equal(q1.body.tools[0].eager_input_streaming, true);
    assert.deepEqual(q1.body.tool_choice, { type: 'auto' });
    assert.deepEqual(q1.body.messages.map((m) => m.role), ['user', 'system']);
    assert.match(q1.body.messages[1].content, /Поточний час у Києві/);

    const r2 = await app.chat('Олена, 067 123 45 67', r1.conversationId);
    assert.equal(r2.leadSaved, true);
    assert.match(r2.reply, /Дякую, Олено/);
    const leads = await app.store.listLeads();
    assert.equal(leads.length, 1);
    assert.equal(leads[0].phone, '+380671234567');
    assert.equal(leads[0].service, 'Імплантація');
    assert.equal(leads[0].channel, 'web');
    assert.equal(tgCalls.length, 1);
    assert.match(tgCalls[0].body.text, /Олена/);

    const [, q2, q3] = claude.requests;
    assert.deepEqual(q2.body.messages.slice(0, 2), q1.body.messages, 'історія лише дописується');
    assert.deepEqual(q2.body.messages[2], { role: 'assistant', content: [{ type: 'thinking', thinking: '', signature: 'sig-1' }, { type: 'text', text: 'На сайті вказано: імплант Osstem — 18 500 грн. Хочете записатися на консультацію?' }] });
    assert.deepEqual(q3.body.messages.slice(0, q2.body.messages.length), q2.body.messages);
    const toolResult = q3.body.messages.at(-1).content[0];
    assert.equal(toolResult.type, 'tool_result');
    assert.equal(toolResult.tool_use_id, 'toolu_1');
    assert.equal(JSON.parse(toolResult.content).ok, true);
    assert.equal(q3.body.messages.at(-2).content.at(-1).input.phone, '067 123 45 67');

    const r3 = await app.chat('Розкажи щось заборонене', r1.conversationId);
    assert.match(r3.reply, /адміністратор/);
    assert.match(r3.reply, /\+38 \(044\) 123-45-67/);
    const r4 = await app.chat('Дякую', r1.conversationId);
    assert.equal(r4.reply, 'Будь ласка!');
    const [, , , q4, q5] = claude.requests;
    assert.deepEqual(q4.body.messages.slice(0, q3.body.messages.length), q3.body.messages);
    assert.ok(!JSON.stringify(q5.body.messages).includes('заборонене'), 'хід із відмовою прибрано з історії');
    assert.deepEqual(q5.body.messages.slice(0, q3.body.messages.length + 1), q4.body.messages.slice(0, q3.body.messages.length + 1));

    const sys = new Set(claude.requests.map((q) => JSON.stringify([q.body.system, q.body.tools])));
    assert.equal(sys.size, 1, 'system і tools однакові в усіх запитах (кеш префікса)');
    const conv = await app.store.getConversation('demodent', r1.conversationId);
    assert.equal(conv.usage.calls, 5);
    assert.equal(conv.usage.cacheRead, 4500);
  } finally {
    await app.done();
  }
});

test('AI-режим: невалідний телефон → помилка інструмента, заявка не створюється', async () => {
  const app = await makeApp({ ai: true });
  try {
    claude.requests.length = 0;
    claude.queue.push(
      { content: [{ type: 'tool_use', id: 'toolu_bad', name: 'save_lead', input: { name: 'Петро', phone: 'нема' } }], stop_reason: 'tool_use' },
      { content: [text('Підкажіть, будь ласка, номер телефону для зв\'язку.')], stop_reason: 'end_turn' },
    );
    const r = await app.chat('Запишіть мене, Петро');
    assert.match(r.reply, /номер телефону/);
    const tr = claude.requests[1].body.messages.at(-1).content[0];
    assert.equal(tr.is_error, true);
    assert.match(tr.content, /INVALID_INPUT/);
    assert.equal((await app.store.listLeads()).length, 0);
  } finally {
    await app.done();
  }
});

test('AI-режим: збій API → відповідь у локальному режимі, історія без хвостів', async () => {
  const app = await makeApp({ ai: true });
  try {
    claude.requests.length = 0;
    claude.queue.push({ status: 500 }, { content: [text('Ми працюємо в суботу з 10:00 до 16:00.')], stop_reason: 'end_turn' });
    const r = await app.chat('Ви працюєте в суботу?');
    assert.equal(r.mode, 'local');
    assert.match(r.reply, /Сб: 10:00–16:00/);
    const r2 = await app.chat('А в неділю?', r.conversationId);
    assert.equal(r2.mode, 'ai');
    assert.deepEqual(claude.requests[1].body.messages.map((m) => m.role), ['user', 'system'], 'невдалий хід не лишився в історії');
  } finally {
    await app.done();
  }
});

test('приклад діалогу для презентації генерується в AI-режимі', async () => {
  const app = await makeApp({ ai: true });
  try {
    claude.queue.push(
      { content: [text('Імплант Osstem — 18 500 грн, Straumann — від 32 000 грн.')], stop_reason: 'end_turn' },
      { content: [text('Так, у суботу з 10:00 до 16:00.')], stop_reason: 'end_turn' },
      { content: [text('Зателефонуйте нам: +38 (044) 123-45-67.')], stop_reason: 'end_turn' },
    );
    const r = await createDemo(`${SITE}/`, { store: app.store, config: app.config, assistant: app.assistant, slug: 'demodent2', screenshot: false });
    assert.equal(r.clinic.sampleDialog.length, 3);
    const pitch = await (await fetch(`${app.base}/pitch/demodent2`)).text();
    assert.match(pitch, /Скільки коштує імплантація зуба/);
    assert.match(pitch, /Straumann — від 32 000 грн/);
    const ov = await (await fetch(`${app.base}/admin/api/overview`, { headers: { Authorization: `Basic ${Buffer.from('a:pw').toString('base64')}` } })).json();
    assert.equal(ov.conversations.length, 0, 'приклади не рахуються як діалоги пацієнтів');
  } finally {
    await app.done();
  }
});

test.after(async () => {
  await Promise.all([close(site), close(tg), close(claudeServer)]);
});
