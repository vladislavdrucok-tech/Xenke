// Обхід сайту клініки: до N сторінок того самого домену, спершу ціни/послуги/контакти.
// Поважає robots.txt і не чіпає файли, адмінки та мовні дублікати (/ru/, /en/).
import { extractLinks, extractTitle, htmlToText } from './extract.mjs';

export const USER_AGENT = 'Mozilla/5.0 (compatible; ClinicAssistantDemo/0.1; one-time crawl for a demo)';

const SKIP_EXT = /\.(pdf|jpe?g|png|gif|webp|svg|ico|zip|rar|docx?|xlsx?|pptx?|mp4|mp3|avi|mov|css|js|json|xml|txt|woff2?|ttf|eot)$/i;
const SKIP_PATH = /(\/wp-admin|\/wp-login|\/wp-json|\/admin|\/login|\/cart|\/checkout|\/account|\/feed\/?$|\/tag\/|\/author\/|\/search|\/cdn-cgi\/|\/xmlrpc|\/print\/)/i;
const LANG_DUP = /^\/(ru|en|pl|de)(\/|$)/i;

const PRIORITY = [
  [/(price|prices|price-list|pricelist|tsin|tsiny|cin[iy]|ceny|ціни|цiни|цены|прайс|vartist|вартість|stoimost|стоимость|cost)/i, 100],
  [/(implant|імплант|имплант)/i, 70],
  [/(contact|kontakt|контакт)/i, 65],
  [/(poslug|uslug|послуг|услуг|service|likuvann|лікуван|лечени)/i, 55],
  [/(akci|акці|акци|promo|special|znyzhk|знижк)/i, 45],
  [/(about|pro-nas|o-nas|про-нас|о-нас|clinic|klinik|клінік)/i, 40],
  [/(doctor|likar|vrach|лікар|врач|team|komanda|команда|specialist)/i, 35],
  [/(faq|pytann|vopros|питання|вопрос)/i, 35],
  [/(ortodont|orthodont|brekety|брекет|elayner|aligner|vinir|вінір|виниры|protez|протез|koronk|коронк|gigien|гігієн|гигиен|vidbil|відбіл|отбел|terap|терап|hirurg|хірург|хирург|dytyach|дитяч|детск|kids)/i, 30],
  [/(blog|news|novyny|новини|новости|stat|статт|article|post)/i, -40],
];

function scoreLink(url, text) {
  const hay = `${decodeURIComponent(url.pathname)} ${text}`;
  let score = 0;
  for (const [re, w] of PRIORITY) if (re.test(hay)) score += w;
  score -= url.pathname.split('/').filter(Boolean).length * 3;
  return score;
}

function sameSite(a, b) {
  return a.replace(/^www\./, '') === b.replace(/^www\./, '');
}

function cleanUrl(url) {
  const u = new URL(url);
  u.hash = '';
  for (const key of [...u.searchParams.keys()]) {
    if (/^(utm_|fbclid|gclid|yclid|_ga|ref$|lang$)/i.test(key)) u.searchParams.delete(key);
  }
  if (u.pathname !== '/' && u.pathname.endsWith('/')) u.pathname = u.pathname.replace(/\/+$/, '');
  return u.href;
}

// Дуже простий robots.txt: групи для "*" і для нашого агента, Disallow/Allow із * та $.
export function parseRobots(text) {
  const rules = [];
  let applies = false, lastWasAgent = false;
  for (const raw of String(text).split(/\r?\n/)) {
    const line = raw.replace(/#.*/, '').trim();
    if (!line) continue;
    const idx = line.indexOf(':');
    if (idx < 0) continue;
    const key = line.slice(0, idx).trim().toLowerCase();
    const value = line.slice(idx + 1).trim();
    if (key === 'user-agent') {
      const ua = value.toLowerCase();
      const match = ua === '*' || 'clinicassistantdemo'.includes(ua);
      applies = lastWasAgent ? applies || match : match;
      lastWasAgent = true;
    } else {
      lastWasAgent = false;
      if (!applies) continue;
      if ((key === 'disallow' || key === 'allow') && value) rules.push({ allow: key === 'allow', path: value });
    }
  }
  const toRe = (p) => new RegExp('^' + p.replace(/[.+?^{}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\\\$$|\$$/, '$'));
  const compiled = rules.map((r) => ({ ...r, re: toRe(r.path), len: r.path.length }));
  return (path) => {
    let best = null;
    for (const r of compiled) if (r.re.test(path) && (!best || r.len > best.len)) best = r;
    return !best || best.allow;
  };
}

async function fetchText(url, { timeoutMs, fetchImpl, accept = 'text/html,application/xhtml+xml' }) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetchImpl(url, {
      redirect: 'follow', signal: ctrl.signal,
      headers: { 'User-Agent': USER_AGENT, Accept: accept, 'Accept-Language': 'uk,ru;q=0.8,en;q=0.5' },
    });
    const type = res.headers.get('content-type') || '';
    const buf = Buffer.from(await res.arrayBuffer());
    let charset = /charset=([\w-]+)/i.exec(type)?.[1];
    if (!charset) {
      const head = buf.subarray(0, 2048).toString('latin1');
      charset = /<meta[^>]+charset=["']?([\w-]+)/i.exec(head)?.[1];
    }
    let text;
    try { text = new TextDecoder(charset || 'utf-8').decode(buf); } catch { text = new TextDecoder('utf-8').decode(buf); }
    return { ok: res.ok, status: res.status, url: res.url || url, type, text };
  } finally {
    clearTimeout(timer);
  }
}

export async function crawlSite(startUrl, opts = {}) {
  const { maxPages = 25, timeoutMs = 12000, concurrency = 3, fetchImpl = fetch, log = () => {}, includeLanguageDuplicates = false } = opts;
  if (!/^https?:\/\//i.test(startUrl)) startUrl = `https://${startUrl}`;

  let first;
  try {
    first = await fetchText(startUrl, { timeoutMs, fetchImpl });
  } catch (err) {
    const why = err.name === 'AbortError' ? 'не відповів вчасно' : (err.cause?.code || err.message);
    throw new Error(`Сайт недоступний (${why}): ${startUrl}`);
  }
  if (!first.ok) throw new Error(`Сайт відповів ${first.status} на ${startUrl}`);
  const origin = new URL(first.url);
  const startLangDup = LANG_DUP.test(origin.pathname);

  let allowed = () => true;
  try {
    const robots = await fetchText(new URL('/robots.txt', origin).href, { timeoutMs: 6000, fetchImpl, accept: 'text/plain' });
    if (robots.ok && !/<html/i.test(robots.text)) allowed = parseRobots(robots.text);
  } catch { /* немає robots.txt — можна */ }

  const queued = new Set([cleanUrl(first.url)]);
  const queue = [];
  const pages = [];
  const skipped = { robots: 0, language: 0, other: 0 };
  const errors = [];

  const enqueueLinks = (links) => {
    for (const link of links) {
      if (link.protocol !== 'http:' && link.protocol !== 'https:') continue;
      let u;
      try { u = new URL(cleanUrl(link.url)); } catch { continue; }
      if (!sameSite(u.hostname, origin.hostname)) continue;
      if (queued.has(u.href)) continue;
      queued.add(u.href);
      if (SKIP_EXT.test(u.pathname) || SKIP_PATH.test(u.pathname)) { skipped.other++; continue; }
      if (!includeLanguageDuplicates && !startLangDup && LANG_DUP.test(u.pathname)) { skipped.language++; continue; }
      if (!allowed(u.pathname + u.search)) { skipped.robots++; continue; }
      if (u.search && u.searchParams.size > 2) { skipped.other++; continue; }
      queue.push({ url: u.href, score: scoreLink(u, link.text) });
    }
    queue.sort((a, b) => b.score - a.score);
  };

  const addPage = (url, html) => {
    const links = extractLinks(html, url);
    pages.push({ url, title: extractTitle(html), html, text: htmlToText(html), links });
    enqueueLinks(links);
  };

  if (!allowed(origin.pathname)) throw new Error('robots.txt забороняє обхід цього сайту — демо зробити не можна');
  addPage(cleanUrl(first.url), first.text);
  log(`  ✓ ${first.url}`);

  while (queue.length && pages.length < maxPages) {
    const batch = queue.splice(0, Math.min(concurrency, maxPages - pages.length));
    await Promise.all(batch.map(async ({ url }) => {
      try {
        const res = await fetchText(url, { timeoutMs, fetchImpl });
        if (!res.ok || !/html/i.test(res.type)) { skipped.other++; return; }
        const finalUrl = cleanUrl(res.url);
        if (!sameSite(new URL(finalUrl).hostname, origin.hostname)) { skipped.other++; return; }
        if (finalUrl !== url && pages.some((p) => p.url === finalUrl)) return;
        if (pages.length >= maxPages) return;
        addPage(finalUrl, res.text);
        log(`  ✓ ${finalUrl}`);
      } catch (err) {
        errors.push({ url, error: err.name === 'AbortError' ? 'timeout' : err.message });
      }
    }));
  }
  return { startUrl, origin: origin.origin, pages, skipped, errors, remaining: queue.length };
}
