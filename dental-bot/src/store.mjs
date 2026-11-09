// Сховище на JSON-файлах у data/. Для MVP і десятків клінік цього достатньо.
//   data/clinics/<slug>/clinic.json   налаштування клініки
//   data/clinics/<slug>/kb.json       база знань із сайту
//   data/clinics/<slug>/shot.png      скріншот сайту для демо (необов'язково)
//   data/conversations/<slug>/<id>.json
//   data/leads.json
import { mkdir, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { randomId, readJson, writeJson } from './util.mjs';

export function createStore(dataDir) {
  const queues = new Map();
  // Послідовні записи в один файл, щоб паралельні запити не затирали одне одного.
  const serial = (key, fn) => {
    const prev = queues.get(key) || Promise.resolve();
    const next = prev.then(fn, fn);
    queues.set(key, next.catch(() => {}));
    return next;
  };
  const clinicDir = (slug) => join(dataDir, 'clinics', safe(slug));
  const kbCache = new Map();

  return {
    dataDir,
    clinicDir,
    shotPath: (slug) => join(clinicDir(slug), 'shot.png'),

    async listClinics() {
      let names = [];
      try { names = await readdir(join(dataDir, 'clinics')); } catch { return []; }
      const out = [];
      for (const n of names) {
        const c = await readJson(join(dataDir, 'clinics', n, 'clinic.json'));
        if (c) out.push(c);
      }
      return out.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    },
    getClinic: (slug) => readJson(join(clinicDir(slug), 'clinic.json')),
    saveClinic: (clinic) => serial(`clinic:${clinic.slug}`, () => writeJson(join(clinicDir(clinic.slug), 'clinic.json'), clinic)),
    async updateClinic(slug, patch) {
      return serial(`clinic:${slug}`, async () => {
        const c = await readJson(join(clinicDir(slug), 'clinic.json'));
        if (!c) return null;
        const merged = deepMerge(c, patch);
        await writeJson(join(clinicDir(slug), 'clinic.json'), merged);
        return merged;
      });
    },
    async getKb(slug) {
      if (kbCache.has(slug)) return kbCache.get(slug);
      const kb = await readJson(join(clinicDir(slug), 'kb.json'));
      if (kb) kbCache.set(slug, kb);
      return kb;
    },
    async saveKb(slug, kb) {
      kbCache.set(slug, kb);
      await serial(`kb:${slug}`, () => writeJson(join(clinicDir(slug), 'kb.json'), kb));
    },

    async getConversation(slug, id) {
      return readJson(join(dataDir, 'conversations', safe(slug), `${safe(id)}.json`));
    },
    saveConversation: (conv) => serial(`conv:${conv.clinic}:${conv.id}`,
      () => writeJson(join(dataDir, 'conversations', safe(conv.clinic), `${safe(conv.id)}.json`), conv)),
    async listConversations(slug) {
      const slugs = slug ? [slug] : await readdir(join(dataDir, 'conversations')).catch(() => []);
      const out = [];
      for (const s of slugs) {
        const files = await readdir(join(dataDir, 'conversations', safe(s))).catch(() => []);
        for (const f of files.filter((x) => x.endsWith('.json'))) {
          const c = await readJson(join(dataDir, 'conversations', safe(s), f));
          if (c) out.push(c);
        }
      }
      return out.sort((a, b) => (b.updatedAt || '').localeCompare(a.updatedAt || ''));
    },

    listLeads: async () => (await readJson(join(dataDir, 'leads.json'), [])),
    // Та сама розмова й той самий телефон за 30 хв → оновлюємо заявку, а не створюємо дубль.
    addLead(lead) {
      return serial('leads', async () => {
        const leads = await readJson(join(dataDir, 'leads.json'), []);
        const recent = leads.find((l) => l.clinic === lead.clinic && l.phone === lead.phone
          && l.conversationId && l.conversationId === lead.conversationId
          && Date.now() - Date.parse(l.createdAt) < 30 * 60 * 1000);
        if (recent) {
          for (const k of ['name', 'service', 'preferredTime', 'notes']) if (lead[k]) recent[k] = lead[k];
          recent.updatedAt = new Date().toISOString();
          await writeJson(join(dataDir, 'leads.json'), leads);
          return { lead: recent, duplicate: true };
        }
        const full = { id: randomId(6), status: 'new', createdAt: new Date().toISOString(), ...lead };
        leads.unshift(full);
        await writeJson(join(dataDir, 'leads.json'), leads);
        return { lead: full, duplicate: false };
      });
    },
    updateLead(id, patch) {
      return serial('leads', async () => {
        const leads = await readJson(join(dataDir, 'leads.json'), []);
        const l = leads.find((x) => x.id === id);
        if (!l) return null;
        Object.assign(l, patch, { updatedAt: new Date().toISOString() });
        await writeJson(join(dataDir, 'leads.json'), leads);
        return l;
      });
    },
    ensure: () => mkdir(join(dataDir, 'clinics'), { recursive: true }),
  };
}

function safe(name) {
  return String(name).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 80);
}

function deepMerge(a, b) {
  if (!b || typeof b !== 'object' || Array.isArray(b)) return b;
  const out = { ...(a && typeof a === 'object' && !Array.isArray(a) ? a : {}) };
  for (const [k, v] of Object.entries(b)) {
    out[k] = v && typeof v === 'object' && !Array.isArray(v) ? deepMerge(out[k], v) : v;
  }
  return out;
}
