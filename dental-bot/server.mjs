// HTTP-сервер: API чату для віджета, демо й презентації, адмінка, роздача widget.js.
//   node server.mjs            → http://localhost:8787
import { createServer as createHttpServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { timingSafeEqual } from 'node:crypto';
import { createAssistant, validateLeadInput } from './src/assistant.mjs';
import { loadConfig, ROOT } from './src/config.mjs';
import { createDemo } from './src/demo.mjs';
import { createNotifier } from './src/notify.mjs';
import { renderDemoPage, renderPitchPage } from './src/pages.mjs';
import { createStore } from './src/store.mjs';
import { startTelegramBot } from './src/telegram.mjs';
import { formatPhone, randomId, toCsv } from './src/util.mjs';

const TOPICS = [
  ['Ціни', /(ціна|ціни|цін|скільки|кошту|вартіст|прайс|цена|сколько|стоит|стоимост)/i],
  ['Імплантація', /(імплант|имплант)/i],
  ['Біль / терміново', /(болить|біль|болит|боль|набряк|опух|флюс|кров|терміново|срочно)/i],
  ['Запис', /(запис|прийом|приём|консультац)/i],
  ['Графік', /(графік|працюєте|субот|неділ|вихідн|график|работаете)/i],
  ['Адреса / як доїхати', /(адрес|де ви|знаходит|доїхати|метро|паркув)/i],
  ['Брекети / елайнери', /(брекет|елайнер|элайнер|прикус|ортодонт)/i],
  ['Гігієна / чистка', /(гігієн|гигиен|чистк|чищен|камін|камен)/i],
  ['Відбілювання', /(відбіл|отбел)/i],
  ['Протезування / коронки / вініри', /(протез|коронк|вінір|винир)/i],
  ['Дитяча стоматологія', /(дитин|дитяч|ребен|детск|син |донь)/i],
];

const CONV_ID_RE = /^[A-Za-z0-9_-]{8,40}$/;

export async function createApp({ config = loadConfig(), log = console, assistantClient } = {}) {
  const store = createStore(config.dataDir);
  await store.ensure();
  const notifier = createNotifier({ config, log });
  const assistant = createAssistant({ store, notifier, config, log, client: assistantClient });
  let adminPassword = config.adminPassword;
  if (!adminPassword) {
    adminPassword = randomId(9);
    log.log(`ADMIN_PASSWORD не задано — тимчасовий пароль адмінки: ${adminPassword}`);
  }
  const rate = new Map();

  const send = (res, status, body, headers = {}) => {
    const isBuf = Buffer.isBuffer(body);
    const payload = isBuf || typeof body === 'string' ? body : JSON.stringify(body);
    res.writeHead(status, {
      'Content-Type': isBuf ? 'application/octet-stream' : typeof body === 'string' ? 'text/html; charset=utf-8' : 'application/json; charset=utf-8',
      ...headers,
    });
    res.end(payload);
  };
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };

  const clientIp = (req) => String(req.headers['cf-connecting-ip'] || req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim();
  const allowRate = (ip) => {
    const now = Date.now();
    const list = (rate.get(ip) || []).filter((t) => now - t < 10 * 60 * 1000);
    if (list.length >= config.limits.messagesPerIpPer10Min) { rate.set(ip, list); return false; }
    list.push(now);
    rate.set(ip, list);
    if (rate.size > 5000) for (const [k, v] of rate) if (!v.length || now - v[v.length - 1] > 600000) rate.delete(k);
    return true;
  };

  async function readBody(req, limit = 16 * 1024) {
    let size = 0;
    const chunks = [];
    for await (const c of req) {
      size += c.length;
      if (size > limit) throw Object.assign(new Error('too large'), { status: 413 });
      chunks.push(c);
    }
    try { return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { throw Object.assign(new Error('bad json'), { status: 400 }); }
  }

  const isAdmin = (req) => {
    const m = /^Basic\s+(.+)$/i.exec(req.headers.authorization || '');
    if (!m) return false;
    const pass = Buffer.from(m[1], 'base64').toString('utf8').split(':').slice(1).join(':');
    const a = Buffer.from(pass), b = Buffer.from(adminPassword);
    return a.length === b.length && timingSafeEqual(a, b);
  };

  async function publicClinic(slug) {
    const clinic = await store.getClinic(slug);
    const kb = clinic && await store.getKb(slug);
    return clinic && kb ? { clinic, kb } : null;
  }

  function dialogFor(clinic, conversations) {
    if (clinic.sampleDialog?.length) return clinic.sampleDialog;
    for (const c of conversations) {
      const pairs = [];
      const t = c.transcript || [];
      for (let i = 0; i + 1 < t.length; i++) if (t[i].role === 'user' && t[i + 1].role === 'assistant' && t[i + 1].mode === 'ai' && !t[i + 1].leadId) pairs.push({ q: t[i].text, a: t[i + 1].text });
      if (pairs.length >= 2) return pairs;
    }
    return [];
  }

  function costOf(usage) {
    if (!usage) return 0;
    const p = config.ai.pricing;
    return (usage.input * p.input + usage.output * p.output + usage.cacheRead * p.cacheRead + usage.cacheWrite * p.cacheWrite) / 1e6;
  }

  async function overview() {
    const [clinics, leads, convs] = await Promise.all([store.listClinics(), store.listLeads(), store.listConversations()]);
    const kbs = Object.fromEntries(await Promise.all(clinics.map(async (c) => [c.slug, await store.getKb(c.slug)])));
    const real = convs.filter((c) => !c.sample);
    const topics = Object.fromEntries(TOPICS.map(([n]) => [n, 0]));
    for (const c of real) {
      const text = (c.transcript || []).filter((t) => t.role === 'user').map((t) => t.text).join(' ');
      for (const [n, re] of TOPICS) if (re.test(text)) topics[n]++;
    }
    return {
      mode: assistant.mode, model: config.ai.model, publicUrl: config.publicUrl,
      clinics: clinics.map((c) => ({ ...c, kbStats: kbs[c.slug]?.stats, phones: kbs[c.slug]?.facts.phones || [], implantPrice: kbs[c.slug]?.implantPrice || null })),
      leads,
      conversations: real.map((c) => ({
        id: c.id, clinic: c.clinic, channel: c.channel, createdAt: c.createdAt, updatedAt: c.updatedAt,
        messages: (c.transcript || []).filter((t) => t.role === 'user').length,
        first: (c.transcript || []).find((t) => t.role === 'user')?.text || '', leadIds: c.leadIds || [], cost: costOf(c.usage),
      })),
      topics,
      totals: {
        conversations: real.length, leads: leads.length,
        aiCostUsd: convs.reduce((s, c) => s + costOf(c.usage), 0),
      },
    };
  }

  async function handle(req, res) {
    const url = new URL(req.url, 'http://localhost');
    const path = url.pathname;
    const method = req.method;

    if (method === 'OPTIONS' && path.startsWith('/api/')) return send(res, 204, '', cors);
    if (path === '/') return send(res, 302, '', { Location: '/admin' });
    if (path === '/healthz') return send(res, 200, { ok: true, mode: assistant.mode });

    if (path === '/widget.js') {
      const js = await readFile(join(ROOT, 'public', 'widget.js'));
      return send(res, 200, js, { ...cors, 'Content-Type': 'text/javascript; charset=utf-8', 'Cache-Control': 'public, max-age=300' });
    }

    let m;
    if ((m = /^\/api\/clinic\/([\w-]+)$/.exec(path)) && method === 'GET') {
      const found = await publicClinic(m[1]);
      if (!found) return send(res, 404, { error: 'clinic not found' }, cors);
      const { clinic, kb } = found;
      return send(res, 200, {
        slug: clinic.slug, name: clinic.name, greeting: clinic.greeting, brandColor: clinic.brandColor,
        quickReplies: clinic.quickReplies, phone: kb.facts.phones[0] ? formatPhone(kb.facts.phones[0]) : '',
      }, cors);
    }

    if (path === '/api/chat' && method === 'POST') {
      const body = await readBody(req);
      const found = await publicClinic(String(body.clinic || ''));
      if (!found) return send(res, 404, { error: 'clinic not found' }, cors);
      const text = String(body.message || '').trim().slice(0, config.limits.maxMessageChars);
      if (!text) return send(res, 400, { error: 'empty message' }, cors);
      if (!allowRate(clientIp(req))) return send(res, 429, { error: 'rate', reply: 'Забагато повідомлень за короткий час. Спробуйте за кілька хвилин або зателефонуйте в клініку.' }, cors);
      const { clinic, kb } = found;
      let conversation = CONV_ID_RE.test(body.conversationId || '') ? await store.getConversation(clinic.slug, body.conversationId) : null;
      if (conversation && conversation.channel !== 'web') conversation = null; // чужі канали (Telegram, приклади) з віджета недоступні
      if (!conversation) conversation = { id: randomId(12), clinic: clinic.slug, channel: 'web', createdAt: new Date().toISOString(), messages: [], transcript: [], page: String(body.page || '').slice(0, 300) };
      if ((conversation.transcript || []).filter((t) => t.role === 'user').length >= config.limits.messagesPerConversation) {
        return send(res, 200, { conversationId: conversation.id, reply: 'Для подальшої допомоги зателефонуйте, будь ласка, в клініку — адміністратор відповість на всі питання.' }, cors);
      }
      const result = await assistant.reply({ clinic, kb, conversation, text, channel: 'web' });
      return send(res, 200, { conversationId: conversation.id, reply: result.reply, leadSaved: Boolean(result.leadSaved), mode: result.mode }, cors);
    }

    if (path === '/api/lead' && method === 'POST') {
      const body = await readBody(req);
      const found = await publicClinic(String(body.clinic || ''));
      if (!found) return send(res, 404, { error: 'clinic not found' }, cors);
      if (!allowRate(clientIp(req))) return send(res, 429, { error: 'rate' }, cors);
      const v = validateLeadInput({ name: body.name, phone: body.phone, service: body.service || '', preferred_time: body.preferredTime || '', notes: '' });
      if (!v.ok) return send(res, 400, { error: v.error }, cors);
      let conversation = CONV_ID_RE.test(body.conversationId || '') ? await store.getConversation(found.clinic.slug, body.conversationId) : null;
      if (conversation && conversation.channel !== 'web') conversation = null;
      const { lead } = await assistant.saveLead({ clinic: found.clinic, conversation, input: v.lead, channel: 'form' });
      if (conversation) {
        conversation.transcript.push({ role: 'user', text: `[Форма запису] ${lead.name}, ${formatPhone(lead.phone)}${lead.service ? `, ${lead.service}` : ''}`, at: new Date().toISOString() });
        await store.saveConversation(conversation);
      }
      return send(res, 200, { ok: true, reply: `Дякуємо, ${lead.name}! Заявку передано адміністратору — вам зателефонують на ${formatPhone(lead.phone)}.` }, cors);
    }

    if ((m = /^\/demo\/([\w-]+)$/.exec(path))) {
      const found = await publicClinic(m[1]);
      if (!found) return send(res, 404, 'Демо не знайдено');
      return send(res, 200, renderDemoPage({ ...found, config }));
    }
    if ((m = /^\/pitch\/([\w-]+)$/.exec(path))) {
      const found = await publicClinic(m[1]);
      if (!found) return send(res, 404, 'Презентацію не знайдено');
      const convs = await store.listConversations(m[1]);
      return send(res, 200, renderPitchPage({ ...found, config, dialog: dialogFor(found.clinic, convs) }));
    }
    if ((m = /^\/shots\/([\w-]+)\.png$/.exec(path))) {
      try { return send(res, 200, await readFile(store.shotPath(m[1])), { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=3600' }); }
      catch { return send(res, 404, 'not found'); }
    }

    if (path === '/admin' || path.startsWith('/admin/')) {
      if (!isAdmin(req)) return send(res, 401, 'Потрібен пароль адмінки', { 'WWW-Authenticate': 'Basic realm="admin", charset="UTF-8"' });
      const noStore = { 'Cache-Control': 'no-store', 'X-Frame-Options': 'DENY' };
      if (path === '/admin') return send(res, 200, await readFile(join(ROOT, 'public', 'admin.html'), 'utf8'), noStore);
      if (path === '/admin/api/overview') return send(res, 200, await overview(), noStore);
      if ((m = /^\/admin\/api\/conversation\/([\w-]+)\/([\w-]+)$/.exec(path))) {
        const c = await store.getConversation(m[1], m[2]);
        return c ? send(res, 200, { ...c, messages: undefined, cost: costOf(c.usage) }, noStore) : send(res, 404, { error: 'not found' });
      }
      if ((m = /^\/admin\/api\/lead\/([\w-]+)$/.exec(path)) && method === 'POST') {
        const body = await readBody(req);
        const allowed = ['new', 'called', 'booked', 'lost'];
        if (!allowed.includes(body.status)) return send(res, 400, { error: 'status' });
        const l = await store.updateLead(m[1], { status: body.status });
        return l ? send(res, 200, l, noStore) : send(res, 404, { error: 'not found' });
      }
      if ((m = /^\/admin\/api\/clinic\/([\w-]+)$/.exec(path)) && method === 'POST') {
        const body = await readBody(req);
        const patch = {};
        for (const k of ['name', 'greeting', 'status']) if (typeof body[k] === 'string' && body[k].trim()) patch[k] = body[k].trim().slice(0, 400);
        if (typeof body.brandColor === 'string' && /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(body.brandColor.trim())) patch.brandColor = body.brandColor.trim();
        if (body.telegram && typeof body.telegram.adminChatId === 'string') patch.telegram = { adminChatId: body.telegram.adminChatId.trim() };
        if (body.audit && typeof body.audit === 'object') {
          const a = body.audit;
          patch.audit = a.askedAt ? { channel: String(a.channel || '').slice(0, 40), askedAt: a.askedAt, answeredAt: a.answeredAt || null } : null;
        }
        if (Array.isArray(body.quickReplies)) patch.quickReplies = body.quickReplies.map((q) => String(q).slice(0, 60)).filter(Boolean).slice(0, 6);
        const c = await store.updateClinic(m[1], patch);
        return c ? send(res, 200, c, noStore) : send(res, 404, { error: 'not found' });
      }
      if (path === '/admin/api/demo' && method === 'POST') {
        const body = await readBody(req);
        if (!body.url) return send(res, 400, { error: 'url' });
        try {
          const r = await createDemo(String(body.url), {
            store, config, assistant, log: () => {}, name: body.name || undefined,
            maxPages: Math.min(Number(body.maxPages) || 25, 60), screenshot: body.screenshot !== false,
          });
          return send(res, 200, { slug: r.clinic.slug, name: r.clinic.name, demoUrl: r.demoUrl, pitchUrl: r.pitchUrl, warnings: r.warnings, stats: r.kb.stats }, noStore);
        } catch (err) {
          return send(res, 422, { error: err.message }, noStore);
        }
      }
      if (path === '/admin/leads.csv') {
        const leads = await store.listLeads();
        const rows = leads.map((l) => ({ ...l, phone: formatPhone(l.phone) }));
        return send(res, 200, '﻿' + toCsv(rows, ['createdAt', 'clinicName', 'name', 'phone', 'service', 'preferredTime', 'notes', 'channel', 'status', 'id']), { 'Content-Type': 'text/csv; charset=utf-8', 'Content-Disposition': 'attachment; filename="leads.csv"' });
      }
      return send(res, 404, { error: 'not found' });
    }
    return send(res, 404, 'Не знайдено');
  }

  const server = createHttpServer((req, res) => {
    handle(req, res).catch((err) => {
      if (!err.status) log.error(err);
      if (!res.headersSent) send(res, err.status || 500, { error: err.status ? err.message : 'internal error' }, cors);
      else res.end();
    });
  });
  const bot = startTelegramBot({ config, store, assistant, log });
  server.on('close', () => bot?.stop());
  return { server, store, assistant, config, adminPassword };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const config = loadConfig();
  const { server, assistant } = await createApp({ config });
  server.listen(config.port, () => {
    console.log(`AI-адміністратор для стоматологій → http://localhost:${config.port}/admin`);
    console.log(`Режим: ${assistant.mode === 'ai' ? `AI (${config.ai.model}, effort ${config.ai.effort})` : 'локальний пошук (немає ANTHROPIC_API_KEY)'}`);
    console.log(`Публічна адреса для посилань: ${config.publicUrl}`);
  });
}
