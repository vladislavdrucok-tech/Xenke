// База знань клініки: факти, ціни й текст сторінок + простий пошук для режиму без AI.
import { detectBrandColor, extractFacts, extractPrices, extractSiteName, findServicePrice, splitBoilerplate } from './extract.mjs';
import { sha1 } from './util.mjs';

export const MAX_PROMPT_CHARS = 180_000;

function guessName(crawl, facts) {
  if (facts.names.length) return facts.names[0];
  const home = crawl.pages[0];
  const site = extractSiteName(home.html);
  if (site) return site;
  const title = (home.title || '').split(/\s[|—–-]\s|\s·\s/)[0].trim();
  return title || new URL(crawl.origin).hostname.replace(/^www\./, '');
}

export function buildKb(crawl) {
  const facts = extractFacts(crawl.pages);
  const prices = extractPrices(crawl.pages);
  const { common, pages } = splitBoilerplate(crawl.pages.map(({ url, title, text, html }) => ({ url, title, text, html })));
  const kb = {
    url: crawl.origin,
    name: guessName(crawl, facts),
    brandColor: detectBrandColor(crawl.pages[0].html),
    crawledAt: new Date().toISOString(),
    facts,
    prices,
    implantPrice: findServicePrice(prices),
    common,
    pages: pages.map(({ url, title, text }) => ({ url, title, text })).filter((p) => p.text.length > 40),
    stats: {
      pages: crawl.pages.length,
      prices: prices.length,
      skipped: crawl.skipped,
      errors: crawl.errors.length,
      remainingLinks: crawl.remaining,
    },
  };
  const prompt = kbToPromptText(kb);
  kb.stats.promptChars = prompt.text.length;
  kb.stats.omittedPages = prompt.omitted;
  kb.hash = sha1(prompt.text).slice(0, 12);
  return kb;
}

// Текст бази знань для системного промпту. Він стабільний між запитами (кешується),
// тому тут немає дат, часу чи випадкових значень.
export function kbToPromptText(kb) {
  const head = [];
  head.push(`Сайт клініки: ${kb.url}`);
  const f = kb.facts;
  if (f.phones.length) head.push(`Телефони: ${f.phones.join(', ')}`);
  if (f.addresses.length) head.push(`Адреси (з сайту):\n${f.addresses.map((a) => `- ${a}`).join('\n')}`);
  if (f.hours.length) head.push(`Графік роботи (з сайту):\n${f.hours.map((h) => `- ${h}`).join('\n')}`);
  if (f.emails.length) head.push(`Email: ${f.emails.join(', ')}`);
  if (f.socials.length) head.push(`Соцмережі: ${f.socials.join(', ')}`);
  if (kb.prices.length) head.push(`Ціни з сайту (рядки як є):\n${kb.prices.map((p) => `- ${p.text}`).join('\n')}`);
  else head.push('Ціни: на сайті не знайдено.');
  if (kb.common.length) head.push(`Загальний текст, що повторюється на всіх сторінках (меню, футер):\n${kb.common.join('\n')}`);

  let text = `<facts>\n${head.join('\n\n')}\n</facts>\n`;
  const ordered = [...kb.pages].sort((a, b) => pagePriority(b) - pagePriority(a));
  const omitted = [];
  for (const p of ordered) {
    const block = `\n<page url="${p.url}" title="${(p.title || '').replace(/"/g, "'")}">\n${p.text}\n</page>\n`;
    if (text.length + block.length > MAX_PROMPT_CHARS) { omitted.push(p.url); continue; }
    text += block;
  }
  return { text, omitted };
}

function pagePriority(p) {
  const s = `${p.url} ${p.title}`;
  if (/(blog|news|novyny|stat|article|post)/i.test(s)) return 0;
  if (/(price|tsin|cin|ціни|прайс|vartist)/i.test(s)) return 3;
  return 1 + (p.url.split('/').length < 5 ? 1 : 0);
}

// ---------- Пошук для режиму без AI ----------

const STOP = new Set(['для', 'але', 'або', 'вас', 'вам', 'нас', 'нам', 'мене', 'мені', 'який', 'яка', 'які', 'чи', 'що', 'як', 'так', 'это', 'как', 'что', 'где', 'при', 'від', 'про', 'the', 'and']);

export function stems(text) {
  return String(text).toLowerCase().replace(/ё/g, 'е')
    .split(/[^a-zа-яіїєґ0-9]+/i)
    .filter((w) => w.length >= 3 && !STOP.has(w))
    .map((w) => w.slice(0, 5));
}

export function chunkKb(kb) {
  const chunks = [];
  for (const p of kb.pages) {
    let buf = '';
    for (const line of p.text.split('\n')) {
      if (buf.length + line.length > 450 && buf) { chunks.push({ url: p.url, title: p.title, text: buf.trim() }); buf = ''; }
      buf += line + '\n';
    }
    if (buf.trim()) chunks.push({ url: p.url, title: p.title, text: buf.trim() });
  }
  return chunks;
}

const chunkCache = new WeakMap();

export function searchKb(kb, query, k = 2) {
  const q = new Set(stems(query));
  if (!q.size) return [];
  let chunks = chunkCache.get(kb);
  if (!chunks) { chunks = chunkKb(kb); chunkCache.set(kb, chunks); }
  const df = new Map();
  const chunkStems = chunks.map((c) => new Set(stems(c.text)));
  for (const set of chunkStems) for (const s of set) df.set(s, (df.get(s) || 0) + 1);
  const scored = chunks.map((c, i) => {
    let score = 0;
    for (const s of q) if (chunkStems[i].has(s)) score += Math.log(1 + chunks.length / (df.get(s) || 1));
    return { ...c, score };
  }).filter((c) => c.score > 0);
  return scored.sort((a, b) => b.score - a.score).slice(0, k);
}

export function matchPrices(kb, query, limit = 6) {
  const q = new Set(stems(query).filter((s) => !/^(скіль|скоко|сколь|кошту|стоит|варті|ціна|цін|цени|прайс|стоим)/.test(s)));
  if (!q.size) return [];
  return kb.prices.filter((p) => stems(p.text).some((s) => q.has(s))).slice(0, limit);
}
