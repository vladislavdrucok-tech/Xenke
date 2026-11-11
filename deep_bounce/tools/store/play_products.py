"""Writes docs/PLAY_PRODUCTS.md: every Google Play product with its ID, type, starting price and the localized
name/description for each Console language, taken from the game's own string tables (i18n/*.json).
   python3 tools/store/play_products.py"""
import json, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
LANGS = [('uk', 'uk'), ('en', 'en-US'), ('pl', 'pl-PL'), ('de', 'de-DE'), ('es', 'es-ES'), ('fr', 'fr-FR'), ('it', 'it-IT'),
         ('pt_BR', 'pt-BR'), ('tr', 'tr-TR'), ('ja', 'ja-JP'), ('ko', 'ko-KR'), ('zh_CN', 'zh-CN')]
PRODUCTS = [
    ('db_no_ads', 'permanent', '3.99', 'noads'),
    ('db_ball_amber', 'permanent', '0.99', 'ball_amber'), ('db_ball_frost', 'permanent', '1.99', 'ball_frost'),
    ('db_ball_obsidian', 'permanent', '1.99', 'ball_obsidian'),
    ('db_cannon_bronze', 'permanent', '1.99', 'cannon_bronze'), ('db_cannon_crystal', 'permanent', '2.99', 'cannon_crystal_engine'),
    ('db_cannon_obsidian', 'permanent', '2.99', 'cannon_obsidian'),
    ('db_support_small', 'consumable', '0.99', 'db_support_small'), ('db_support_medium', 'consumable', '2.99', 'db_support_medium'),
    ('db_support_large', 'consumable', '4.99', 'db_support_large'), ('db_support_extra', 'consumable', '9.99', 'db_support_extra'),
]
T = {l: json.load(open(os.path.join(ROOT, 'i18n', l + '.json'), encoding='utf-8')) for l, _ in LANGS}


def name_desc(l, key):
    t = T[l]
    if key == 'noads':
        return 'Deep Bounce: ' + t['noads_title'], t['store_noads_d']
    if key.startswith('db_support'):
        return t['support'] + ' · ' + t[key], t['support_note']
    kind = 'tab_balls' if key.startswith('ball') else 'tab_cannons'
    return t[key], t[key + '_d'] + ' (' + t[kind] + ')'


out = ['# Google Play: товари Deep Bounce', '',
       'Згенеровано `tools/store/play_products.py` із рядків гри (`i18n/*.json`). Назва ≤ 55 символів, опис ≤ 200 — перевірено.',
       'Ціна в таблиці — стартова в USD для Play Console; гравцеві гра завжди показує ціну, яку повертає Google Play (`ProductDetails.formatted_price`).', '',
       '| Product ID | Тип у Play Console | Стартова ціна | Що дає |', '|---|---|---|---|']
what = {'db_no_ads': 'Без реклами назавжди (відновлюється)'}
for _p in ('db_support_small', 'db_support_medium', 'db_support_large', 'db_support_extra'):
    what[_p] = 'Підтримка автора, нічого не відкриває'
for pid, typ, usd, key in PRODUCTS:
    n, _ = name_desc('uk', key)
    kind = 'One-time product (постійний): гра робить acknowledge, не consume; відновлюється' if typ == 'permanent' else 'One-time product (витратний): гра робить consume після зарахування, тож його можна купувати знову'
    out.append(f'| `{pid}` | {kind} | US${usd} | {what.get(pid, n)} |')
out.append('')
problems = []
for pid, typ, usd, key in PRODUCTS:
    out += [f'## `{pid}`', '', '| Мова Console | Назва | Опис |', '|---|---|---|']
    for l, code in LANGS:
        n, d = name_desc(l, key)
        if len(n) > 55 or len(d) > 200:
            problems.append(f'{pid} {code}: {len(n)}/{len(d)}')
        out.append(f'| {code} | {n} | {d} |')
    out.append('')
if problems:
    out.append('**Перевищення довжини:** ' + ', '.join(problems))
open(os.path.join(ROOT, 'docs', 'PLAY_PRODUCTS.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('ok', 'problems:', problems)
