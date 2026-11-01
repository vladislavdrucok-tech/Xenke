// Новини: RSS/Atom центробанків + додаткові стрічки з NEWS_FEEDS.
// Стрічки ще не перевірені з цього середовища (мережа закрита): якщо якась не відповідає,
// цикл продовжується без неї, а помилка видна в дашборді.

export const DEFAULT_FEEDS = [
  { url: 'https://www.ecb.europa.eu/rss/press.html', source: 'ЄЦБ' },
  { url: 'https://www.federalreserve.gov/feeds/press_all.xml', source: 'ФРС' },
  { url: 'https://www.bankofengland.co.uk/rss/news', source: 'Банк Англії' },
];

const decode = (s) => s
  .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
  .replace(/<[^>]+>/g, '')
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
  .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n)).replace(/&amp;/g, '&')
  .replace(/\s+/g, ' ').trim();
const tag = (block, name) => { const m = block.match(new RegExp(`<${name}\\b[^>]*>([\\s\\S]*?)</${name}>`, 'i')); return m ? decode(m[1]) : ''; };

export function parseFeed(xml, source) {
  const items = [];
  const blocks = xml.match(/<item\b[\s\S]*?<\/item>/gi) || xml.match(/<entry\b[\s\S]*?<\/entry>/gi) || [];
  for (const b of blocks) {
    const title = tag(b, 'title');
    if (!title) continue;
    let link = tag(b, 'link');
    if (!link) { const m = b.match(/<link\b[^>]*href="([^"]+)"/i); link = m ? m[1] : ''; }
    const raw = tag(b, 'pubDate') || tag(b, 'updated') || tag(b, 'published') || tag(b, 'dc:date');
    const t = Date.parse(raw);
    items.push({ title: title.slice(0, 300), link, source, date: Number.isFinite(t) ? new Date(t).toISOString().slice(0, 10) : '' });
  }
  return items;
}

export async function fetchNewsLive(cfg, { fetchImpl = fetch, now = new Date(), days = 4 } = {}) {
  const feeds = [...DEFAULT_FEEDS, ...cfg.newsFeeds.map((url) => ({ url, source: new URL(url).hostname }))];
  const since = new Date(now.getTime() - days * 86400000).toISOString().slice(0, 10);
  const errors = [];
  const all = [];
  await Promise.all(feeds.map(async (f) => {
    try {
      const res = await fetchImpl(f.url, { signal: AbortSignal.timeout(15000), headers: { 'User-Agent': 'PulseFX/0.1 (+paper trading research)' } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      all.push(...parseFeed(await res.text(), f.source));
    } catch (e) {
      errors.push(`${f.source}: ${e.message}`);
    }
  }));
  const seen = new Set();
  const items = all
    .filter((i) => !i.date || i.date >= since)
    .filter((i) => (seen.has(i.title) ? false : seen.add(i.title)))
    .sort((a, b) => b.date.localeCompare(a.date))
    .slice(0, 40);
  return { items, errors };
}
