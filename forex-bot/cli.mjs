// node cli.mjs run    — виконати один щоденний цикл (зручно для cron / Планувальника завдань)
// node cli.mjs status — коротко показати стан рахунку
// node cli.mjs reset  — почати віртуальний рахунок заново
import { loadConfig } from './lib/config.mjs';
import { runCycle, loadState, saveState, freshState } from './lib/cycle.mjs';

const cfg = loadConfig();
const cmd = process.argv[2] || 'status';
const usd = (v) => '$' + v.toLocaleString('en-US', { maximumFractionDigits: 2 });

function status(s) {
  console.log(`Режим: дані ${s.mode.data === 'live' ? 'Twelve Data' : 'ДЕМО'}, аналітик ${s.mode.ai === 'claude' ? 'Claude' : 'ДЕМО'}`);
  console.log(`Остання свічка: ${s.lastBarDate ?? '—'} · капітал ${s.latest ? usd(s.latest.equity) : usd(s.account.cash)} (старт ${usd(s.account.startEquity)})`);
  console.log(`Ваги: технічний ${s.weights.quant.toFixed(2)}, новини ${s.weights.news.toFixed(2)} · угод закрито: ${s.trades.length}`);
  if (s.latest) for (const [id, a] of Object.entries(s.latest.actions)) console.log(`  ${id}: ${a} (оцінка ${s.latest.plans[id].score.toFixed(2)})`);
  const r = s.runs.at(-1);
  if (r) console.log(`Останній запуск: ${r.at} ${r.ok ? 'OK' : 'ПОМИЛКА'} ${r.note} ${r.errors.join('; ')}`);
}

if (cmd === 'run') { const s = await runCycle(cfg); status(s); process.exitCode = s.runs.at(-1).ok ? 0 : 1; }
else if (cmd === 'reset') { saveState(cfg, freshState(cfg)); console.log('Віртуальний рахунок скинуто.'); }
else if (cmd === 'status') status(loadState(cfg));
else { console.log('Команди: run | status | reset'); process.exitCode = 2; }
