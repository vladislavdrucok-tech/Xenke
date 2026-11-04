# Схема маніфесту графіки

Пакет від художника:
```
<package>/
  manifest.json
  assets/<category>/<asset_id>.png      (або кадри: <asset_id>_<state>_<dir>_<nn>.png)
  previews/<asset_id>.png               (на сітці 2:1, з маркером pivot — лише для перегляду)
  sources/                              (оригінали без змін, у гру не потрапляють)
  QA.md                                 (чек-лист, заповнений художником)
```

## manifest.json
```json
{
  "package": "chicago_art_C1",
  "version": 1,
  "art_spec": "ART_SPEC.md draft 1",
  "assets": [
    {
      "id": "char_enzo",
      "category": "characters",
      "license": "generated for this project; no third-party assets",
      "origin": "ChatGPT image generation, ticket C1, 2026-11-05",
      "version": 1,
      "type": "character",
      "frame_size": [96, 128],
      "pivot": [48, 124],
      "height_px": 112,
      "directions": ["N", "NE", "E", "SE", "S", "SW", "W", "NW"],
      "mirror": {"W": null},
      "states": {
        "idle": {"frames": 4, "fps": 6},
        "walk": {"frames": 8, "fps": 12}
      },
      "files": "assets/characters/char_enzo_{state}_{dir}_{nn}.png",
      "shadow": "assets/characters/char_enzo_shadow.png"
    },
    {
      "id": "bld_bellini_garage",
      "category": "buildings",
      "type": "building",
      "license": "generated for this project",
      "origin": "ChatGPT, ticket B1",
      "version": 1,
      "footprint": [4, 3],
      "wall_height_px": 112,
      "pivot": [256, 384],
      "layers": {"base": "assets/buildings/bld_bellini_garage_base.png",
                 "front": "assets/buildings/bld_bellini_garage_front.png",
                 "shadow": "assets/buildings/bld_bellini_garage_shadow.png"},
      "doors": [{"cell": [1, 3], "face": "+y", "states": ["closed", "open"]}],
      "sign_anchor": [180, 210]
    }
  ]
}
```

## Валідатор (`tools/asset_validator.gd`, готовий)
Запуск: `godot --headless --path chicago -s res://tools/validate_assets_cli.gd -- <тека пакета>`.
Скрипт виводить кожну помилку (`ERROR …`) і повертає код 1; якщо помилок немає — `valid` і код 0. Тест: `tests/test_asset_validator.gd`.

### Що перевіряється
- **Цілісність пакета:**
  - кожен файл зі списку існує;
  - ID унікальні й відповідають `^[a-z]+(_[a-z0-9]+)+$`;
  - є ліцензія й походження.
- **Формат PNG:**
  - RGBA;
  - є справжня прозорість;
  - кути кадру прозорі (немає залитого фону);
  - немає «магічного» пурпурного (#FF00FF).
- **Кадри:**
  - розмір кадру = `frame_size`;
  - кількість кадрів = `states.*.frames`;
  - жоден кадр не порожній;
  - для персонажа нижній непрозорий рядок у межах ±2 px від `pivot.y`.
- **Будинки:**
  - ширина зображення ≥ `(fx+fy)·64`;
  - `pivot` = нижня вершина основи;
  - шари (`front`, `shadow`) мають той самий розмір, що й `base`;
  - клітинка дверей лежить одразу за гранню `+y` або `+x`.
- **Тайли:** рівно 128×64.
- **Помилки:** при будь-якій помилці пакет не імпортується, а звіт перелічує всі проблеми. Нічого не розтягується й не обрізається.

## Імпорт у гру (`tools/art_importer.gd`, готовий)
```
godot --headless --path chicago -s res://tools/import_art_cli.gd -- <тека пакета>
godot --headless --path chicago --import
```
1. Пакет спершу проходить валідатор. Якщо є хоч одна помилка, нічого не копіюється.
2. Файли копіюються з `assets/<категорія>/…` у `res://art/<категорія>/…`, а записи об'єднуються в `res://art/manifest.json`.
3. Запис із тим самим `id` замінюється лише вищою `version`.
4. Оригінальний пакет не змінюється. Зберігай його в `sources/` поза грою.

Після імпорту гра сама бере графіку замість заглушок (`core/art_registry.gd`):
- персонаж `char_enzo` стає героєм; `char_<id NPC>` (наприклад `char_salvatore`, `char_marco`) — іменованими NPC;
- для напрямку без власних кадрів використовується віддзеркалення (`mirror`) або найближчий намальований напрямок;
- усе, чого ще немає в маніфесті, лишається заглушкою.

Будинки, земля й машини поки малюються кодом. Їхня заміна піде тим самим шляхом, коли прийдуть тікети B1/G1/V1.
**Візуально перевірено лише на тестових прямокутниках, а не на справжній графіці.**
