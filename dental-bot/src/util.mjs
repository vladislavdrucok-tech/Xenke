// Дрібні допоміжні функції без залежностей.
import { createHash, randomBytes } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

export const KYIV_TZ = 'Europe/Kyiv';

export function sha1(text) {
  return createHash('sha1').update(text).digest('hex');
}

export function randomId(bytes = 9) {
  return randomBytes(bytes).toString('base64url');
}

// "https://www.smile-dent.com.ua/uk/" → "smile-dent"
export function slugFromUrl(url) {
  let host = url;
  try { host = new URL(url).hostname; } catch { /* лишаємо як є */ }
  host = host.replace(/^www\./, '');
  const parts = host.split('.');
  const generic = new Set(['com', 'ua', 'net', 'org', 'kiev', 'kyiv', 'in', 'biz', 'info', 'clinic', 'dental']);
  while (parts.length > 1 && generic.has(parts[parts.length - 1])) parts.pop();
  return slugify(parts.join('-')) || 'clinic';
}

export function slugify(text) {
  return String(text).toLowerCase().normalize('NFKD')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 48);
}

// Українські номери → +380XXXXXXXXX. Інші міжнародні (з плюсом) лишаються цифрами з плюсом.
export function normalizePhone(raw) {
  if (raw == null) return null;
  const str = String(raw).trim();
  const digits = str.replace(/\D/g, '');
  if (/^380\d{9}$/.test(digits)) return '+' + digits;
  if (/^80\d{9}$/.test(digits)) return '+3' + digits;
  if (/^0\d{9}$/.test(digits)) return '+38' + digits;
  if (str.startsWith('+') && digits.length >= 8 && digits.length <= 15) return '+' + digits;
  return null;
}

// +380671234567 → "+38 (067) 123-45-67"
export function formatPhone(phone) {
  const m = /^\+38(0\d{2})(\d{3})(\d{2})(\d{2})$/.exec(phone || '');
  return m ? `+38 (${m[1]}) ${m[2]}-${m[3]}-${m[4]}` : (phone || '');
}

// Знаходить усі схожі на телефон фрагменти в тексті й повертає нормалізовані номери.
export function findPhones(text) {
  const out = new Set();
  const re = /(?:\+?3?8?[\s(.-]*)?\(?0\s?\d{2}\)?[\s.-]*\d{3}[\s.-]*\d{2}[\s.-]*\d{2}(?!\d)/g;
  for (const m of String(text).matchAll(re)) {
    const p = normalizePhone(m[0]);
    if (p) out.add(p);
  }
  return [...out];
}

const HTML_ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
export function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => HTML_ESCAPES[c]);
}

export function kyivNowText(date = new Date()) {
  return new Intl.DateTimeFormat('uk-UA', {
    timeZone: KYIV_TZ, weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  }).format(date);
}

export function formatDateTime(iso) {
  if (!iso) return '';
  return new Intl.DateTimeFormat('uk-UA', {
    timeZone: KYIV_TZ, day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
  }).format(new Date(iso));
}

export function formatMoney(amount, currency = 'UAH') {
  const n = new Intl.NumberFormat('uk-UA', { maximumFractionDigits: 0 }).format(Math.round(amount));
  if (currency === 'USD') return `$${n}`;
  if (currency === 'EUR') return `€${n}`;
  return `${n} грн`;
}

export async function readJson(file, fallback = null) {
  try {
    return JSON.parse(await readFile(file, 'utf8'));
  } catch (err) {
    if (err.code === 'ENOENT') return fallback;
    throw err;
  }
}

// Запис через тимчасовий файл, щоб обрив не лишив напівзаписаний JSON.
export async function writeJson(file, value) {
  await mkdir(dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
  await writeFile(tmp, JSON.stringify(value, null, 2));
  await rename(tmp, file);
}

export function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const [key, inline] = a.slice(2).split('=');
      if (inline !== undefined) args[key] = inline;
      else if (argv[i + 1] && !argv[i + 1].startsWith('--')) args[key] = argv[++i];
      else args[key] = true;
    } else {
      args._.push(a);
    }
  }
  return args;
}

// Мінімальний CSV (RFC 4180: лапки, коми, переноси всередині лапок).
export function parseCsv(text) {
  const rows = [];
  let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); rows.push(row); row = []; field = '';
    } else field += c;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  const nonEmpty = rows.filter((r) => r.some((v) => v.trim() !== ''));
  const [header = [], ...body] = nonEmpty;
  return body.map((r) => Object.fromEntries(header.map((h, i) => [h.trim(), (r[i] ?? '').trim()])));
}

export function toCsv(rows, columns) {
  const cols = columns || [...new Set(rows.flatMap((r) => Object.keys(r)))];
  const cell = (v) => {
    const s = String(v ?? '');
    return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [cols.join(','), ...rows.map((r) => cols.map((c) => cell(r[c])).join(','))].join('\n') + '\n';
}
