// Витягує з HTML текст і факти про клініку: телефони, адреси, графік, ціни, колір бренду.
import { findPhones, normalizePhone } from './util.mjs';

const NAMED_ENTITIES = {
  nbsp: ' ', amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", laquo: '«', raquo: '»',
  mdash: '—', ndash: '–', hellip: '…', rsquo: '’', lsquo: '‘', ldquo: '“', rdquo: '”',
  bdquo: '„', bull: '•', middot: '·', copy: '©', reg: '®', trade: '™', deg: '°', times: '×',
  minus: '−', plusmn: '±', euro: '€', thinsp: ' ', ensp: ' ', emsp: ' ', shy: '', zwnj: '', zwj: '',
};

export function decodeEntities(text) {
  return text.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, code) => {
    if (code[0] === '#') {
      const n = code[1] === 'x' || code[1] === 'X' ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : m;
    }
    const v = NAMED_ENTITIES[code.toLowerCase()];
    return v === undefined ? m : v;
  });
}

// Перетворює HTML на читабельний текст. Рядки таблиць стають "послуга | ціна".
export function htmlToText(html) {
  let s = String(html);
  s = s.replace(/<!--[\s\S]*?-->/g, ' ');
  s = s.replace(/<(script|style|noscript|svg|iframe|template|head|canvas|select)\b[\s\S]*?<\/\1\s*>/gi, ' ');
  s = s.replace(/<br\s*\/?>/gi, '\n');
  s = s.replace(/<li\b[^>]*>/gi, '\n• ');
  s = s.replace(/<\/(td|th)\s*>/gi, ' | ');
  s = s.replace(/<\/(p|div|li|tr|h[1-6]|section|article|header|footer|table|ul|ol|dd|dt|blockquote|address|figcaption|option|label|nav|aside|main|form)\s*>/gi, '\n');
  s = s.replace(/<(p|div|tr|h[1-6]|section|article|table|ul|ol|dd|dt|address)\b[^>]*>/gi, '\n');
  s = s.replace(/<[^>]+>/g, ' ');
  s = decodeEntities(s);
  return s.split('\n')
    .map((line) => line.replace(/[ \t   ]+/g, ' ').replace(/(\s*\|\s*)+$/g, '').replace(/^(\s*\|\s*)+/g, '').replace(/(\s*\|\s*){2,}/g, ' | ').trim())
    .filter((line) => line && line !== '•' && !/^[|•\s]+$/.test(line))
    .join('\n');
}

function metaContent(html, attr, value) {
  const re = new RegExp(`<meta\\b[^>]*${attr}\\s*=\\s*["']${value}["'][^>]*>`, 'i');
  const tag = re.exec(html)?.[0];
  if (!tag) return null;
  const m = /content\s*=\s*["']([^"']*)["']/i.exec(tag);
  return m ? decodeEntities(m[1]).trim() : null;
}

export function extractTitle(html) {
  const t = /<title\b[^>]*>([\s\S]*?)<\/title>/i.exec(html);
  return t ? decodeEntities(t[1]).replace(/\s+/g, ' ').trim() : '';
}

export function extractSiteName(html) {
  return metaContent(html, 'property', 'og:site_name') || null;
}

export function extractLinks(html, baseUrl) {
  const links = [];
  const re = /<a\b[^>]*?href\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))[^>]*>([\s\S]*?)<\/a>/gi;
  for (const m of html.matchAll(re)) {
    const href = decodeEntities((m[1] ?? m[2] ?? m[3] ?? '').trim());
    if (!href) continue;
    let url;
    try { url = new URL(href, baseUrl); } catch { continue; }
    const text = htmlToText(m[4] || '').replace(/\s+/g, ' ').slice(0, 120);
    links.push({ href, url: url.href, protocol: url.protocol, text });
  }
  return links;
}

// schema.org із <script type="application/ld+json">: назва, телефон, адреса, графік.
export function extractJsonLd(html) {
  const found = [];
  const re = /<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  const wanted = /(Dentist|MedicalClinic|MedicalBusiness|LocalBusiness|MedicalOrganization|Organization|Physician|HealthAndBeautyBusiness)/i;
  const visit = (node) => {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) { node.forEach(visit); return; }
    if (node['@graph']) visit(node['@graph']);
    const type = [].concat(node['@type'] || []).join(' ');
    if (wanted.test(type)) found.push(node);
  };
  for (const m of html.matchAll(re)) {
    try { visit(JSON.parse(m[1].trim())); } catch { /* зламаний JSON-LD трапляється часто */ }
  }
  const out = { names: [], phones: [], addresses: [], hours: [], sameAs: [], priceRange: null };
  for (const n of found) {
    if (typeof n.name === 'string') out.names.push(n.name.trim());
    for (const t of [].concat(n.telephone || [])) { const p = normalizePhone(t); if (p) out.phones.push(p); }
    for (const a of [].concat(n.address || [])) {
      if (typeof a === 'string') out.addresses.push(a.trim());
      else if (a && typeof a === 'object') {
        const parts = [a.streetAddress, a.addressLocality].filter(Boolean).map((x) => String(x).trim());
        if (parts.length) out.addresses.push(parts.join(', '));
      }
    }
    for (const h of [].concat(n.openingHours || [])) if (typeof h === 'string') out.hours.push(h.trim());
    for (const spec of [].concat(n.openingHoursSpecification || [])) {
      if (!spec || typeof spec !== 'object') continue;
      const days = [].concat(spec.dayOfWeek || []).map((d) => String(d).replace(/^https?:\/\/schema\.org\//, '')).join(', ');
      if (spec.opens && spec.closes) out.hours.push(`${days}: ${spec.opens}–${spec.closes}`.trim());
    }
    for (const s of [].concat(n.sameAs || [])) if (typeof s === 'string') out.sameAs.push(s);
    if (typeof n.priceRange === 'string') out.priceRange = n.priceRange;
  }
  return out;
}

const ADDRESS_RE = /(вул\.|вулиця|просп\.|проспект|пр-т|пр\.|бульв\.|бульвар|бул\.|пров\.|провулок|площа|пл\.|ул\.|улица|шосе|набережна|узвіз)\s*[«"]?[А-ЯІЇЄҐA-Z0-9]/;
const HOURS_DAY_RE = /(пн|пон|вт|ср|чт|пт|сб|нд|нед|щодня|щоденно|без вихідних|цілодобово|понеділ|вівтор|серед|четвер|п['’]ятниц|субот|неділ|вихідн|ежедневно|mon|sat|sun)/i;
const TIME_RANGE_RE = /\d{1,2}[:.]\d{2}\s*(?:[-–—]|до)\s*\d{1,2}[:.]\d{2}|цілодобово|24\/7/i;
const SOCIAL_RE = /^https?:\/\/(www\.)?(instagram\.com|facebook\.com|fb\.com|t\.me|tiktok\.com|youtube\.com|youtu\.be|viber\.com|wa\.me|api\.whatsapp\.com)\//i;

export function extractFacts(pages) {
  const phones = new Map();
  const emails = new Set();
  const addresses = new Map();
  const hours = new Map();
  const socials = new Set();
  const names = [];
  let priceRange = null;
  const bump = (map, key) => map.set(key, (map.get(key) || 0) + 1);

  for (const page of pages) {
    const ld = extractJsonLd(page.html);
    names.push(...ld.names);
    ld.phones.forEach((p) => bump(phones, p));
    ld.addresses.forEach((a) => bump(addresses, a));
    ld.hours.forEach((h) => bump(hours, h));
    ld.sameAs.filter((s) => SOCIAL_RE.test(s)).forEach((s) => socials.add(s));
    priceRange ||= ld.priceRange;

    for (const link of page.links || []) {
      if (link.protocol === 'tel:') { const p = normalizePhone(link.href.replace(/^tel:/i, '')); if (p) bump(phones, p); }
      else if (link.protocol === 'mailto:') { const e = link.href.replace(/^mailto:/i, '').split('?')[0].trim(); if (e.includes('@')) emails.add(e.toLowerCase()); }
      else if (SOCIAL_RE.test(link.url)) socials.add(link.url.split('?')[0]);
    }
    for (const line of page.text.split('\n')) {
      if (line.length < 200) findPhones(line).forEach((p) => bump(phones, p));
      for (const e of line.match(/[\w.+-]+@[\w-]+\.[\w.-]+/g) || []) emails.add(e.toLowerCase());
      if (line.length <= 160 && ADDRESS_RE.test(line)) bump(addresses, line.replace(/^[•\s]+/, ''));
      if (line.length <= 140 && HOURS_DAY_RE.test(line) && TIME_RANGE_RE.test(line)) bump(hours, line.replace(/^[•\s]+/, ''));
    }
  }
  const top = (map, n) => [...map.entries()].sort((a, b) => b[1] - a[1]).slice(0, n).map(([k]) => k);
  return {
    names: [...new Set(names)],
    phones: top(phones, 6),
    emails: [...emails].filter((e) => !/\.(png|jpe?g|webp|svg|gif)$/.test(e)).slice(0, 4),
    addresses: top(addresses, 5),
    hours: top(hours, 8),
    socials: [...socials].slice(0, 8),
    priceRange,
  };
}

const PRICE_RE = /(\d[\d\s.,]{0,10}\d|\d)\s*(грн|₴|uah|гривень|гривні|\$|usd|дол|€|eur|у\.\s?о\.|у\.о)/i;
const PRICE_PREFIX_RE = /(\$|€)\s*\d/;

// Рядки з цінами. Якщо рядок — лише сума, до нього додається попередній рядок (назва послуги).
export function extractPrices(pages) {
  const seen = new Set();
  const out = [];
  for (const page of pages) {
    const lines = page.text.split('\n');
    lines.forEach((line, i) => {
      if (line.length > 220) return;
      if (!PRICE_RE.test(line) && !PRICE_PREFIX_RE.test(line)) return;
      let text = line.replace(/^[•\s]+/, '');
      const onlyPrice = text.replace(PRICE_RE, '').replace(/(від|от|до|from|\||—|–|-|\s)/gi, '').length < 3;
      if (onlyPrice && i > 0 && lines[i - 1].length < 140) text = `${lines[i - 1].replace(/^[•\s]+/, '')} — ${text}`;
      const key = text.toLowerCase().replace(/\s+/g, ' ');
      if (seen.has(key)) return;
      seen.add(key);
      out.push({ text, url: page.url });
    });
  }
  return out;
}

function parseAmount(raw) {
  const cleaned = raw.replace(/\s/g, '').replace(/,(\d{2})$/, '.$1').replace(/,/g, '');
  const n = parseFloat(cleaned);
  return Number.isFinite(n) ? n : null;
}

// Найменша ціна на імплантацію з прайсу (для слайда про окупність).
export function findServicePrice(prices, pattern = /(імплант|имплант|implant)/i) {
  let best = null;
  for (const p of prices) {
    if (!pattern.test(p.text)) continue;
    for (const m of p.text.matchAll(new RegExp(PRICE_RE.source, 'gi'))) {
      const amount = parseAmount(m[1]);
      if (!amount) continue;
      const cur = /\$|usd|дол|у\.\s?о|у\.о/i.test(m[2]) ? 'USD' : /€|eur/i.test(m[2]) ? 'EUR' : 'UAH';
      const plausible = cur === 'UAH' ? amount >= 3000 : amount >= 100;
      if (!plausible) continue;
      if (!best || (cur === best.currency && amount < best.amount)) best = { amount, currency: cur, text: p.text, url: p.url };
    }
  }
  return best;
}

function hexToRgb(hex) {
  let h = hex.replace('#', '');
  if (h.length === 3) h = h.split('').map((c) => c + c).join('');
  const n = parseInt(h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function saturationAndLightness([r, g, b]) {
  const max = Math.max(r, g, b) / 255, min = Math.min(r, g, b) / 255;
  const l = (max + min) / 2;
  const s = max === min ? 0 : (max - min) / (1 - Math.abs(2 * l - 1));
  return { s, l };
}

// Колір бренду: meta theme-color або найчастіший насичений колір у CSS сторінки.
export function detectBrandColor(html, fallback = '#0f7c8a') {
  const theme = metaContent(html, 'name', 'theme-color');
  const usable = (hex) => {
    if (!/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(hex)) return false;
    const { s, l } = saturationAndLightness(hexToRgb(hex));
    return s > 0.25 && l > 0.18 && l < 0.7;
  };
  if (theme && usable(theme)) return theme.toLowerCase();
  const counts = new Map();
  const css = [...html.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/gi)].map((m) => m[1]).join('\n')
    + [...html.matchAll(/style\s*=\s*"([^"]*)"/gi)].map((m) => m[1]).join('\n');
  for (const m of css.matchAll(/#([0-9a-f]{6}|[0-9a-f]{3})\b/gi)) {
    const hex = `#${m[1].toLowerCase()}`;
    if (usable(hex)) counts.set(hex, (counts.get(hex) || 0) + 1);
  }
  const best = [...counts.entries()].sort((a, b) => b[1] - a[1])[0];
  return best ? best[0] : fallback;
}

// Рядки, що повторюються на більшості сторінок (меню, футер), лишаються один раз окремо.
export function splitBoilerplate(pages) {
  if (pages.length < 3) return { common: [], pages };
  const freq = new Map();
  for (const p of pages) for (const line of new Set(p.text.split('\n'))) freq.set(line, (freq.get(line) || 0) + 1);
  const threshold = Math.max(3, Math.ceil(pages.length * 0.6));
  const boiler = new Set([...freq.entries()].filter(([, n]) => n >= threshold).map(([l]) => l));
  return {
    common: [...boiler],
    pages: pages.map((p) => ({ ...p, text: p.text.split('\n').filter((l) => !boiler.has(l)).join('\n') })),
  };
}
