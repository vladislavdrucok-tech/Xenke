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

## Що перевіряє валідатор (план `tools/validate_assets`)
- **Цілісність пакета:**
  - кожен файл зі списку існує;
  - ID унікальні й відповідають `^[a-z]+(_[a-z0-9]+)+$`;
  - є ліцензія й походження.
- **Формат PNG:**
  - RGBA;
  - кути кадру прозорі (немає залитого фону);
  - немає «магічного» пурпурного (#FF00FF).
- **Кадри:**
  - розмір кадру = `frame_size`;
  - кількість кадрів = `states.*.frames`;
  - жоден кадр не порожній;
  - для персонажа нижній непрозорий рядок у межах ±2 px від `pivot.y`.
- **Будинки:**
  - ширина зображення ≥ `(fx+fy)·64`;
  - `pivot` = нижня вершина основи.
- **Помилки:** при будь-якій помилці пакет не імпортується, а звіт перелічує всі проблеми. Нічого не розтягується й не обрізається.
