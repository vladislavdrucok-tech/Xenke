# Карта міграції з Afterfall

Afterfall лишається недоторканим: теки `iso/`, `squad/`, `godot/`, `dist/`, `art/`, `docs/`, `builds/`, `qa/`, `scripts/` і `trading-bot/` не змінювались. Перевірка — `tools/check_legacy_untouched.sh`.
Знімок стану до міграції — коміт `a552fe2` у гілці `ccr-25f5a5c0-7a2lif`. Тег поставимо після рішення власника.

## Базова перевірка Afterfall (до міграції)
- Рушій: Godot 4.3-stable.
- `iso`, `squad`, `godot` імпортуються без помилок.
- `iso -- --selftest`: 7/7 PASS (04.11.2026, на копіях у тимчасовій теці).

## Що взято
Код не копіювався. Нижче перелічено ідеї, які переписано під нову архітектуру.
| Ідея | Звідки | Куди | Що змінено |
|---|---|---|---|
| Плаваючий джойстик із захопленням дотику за індексом; дотик на кнопці не рухає героя | `iso/scripts/hud.gd:308` | `ui/touch_controls.gd` | безпечна зона, мінімум 72 px, `InputRouter` замість прямого читання |
| Рух із прискоренням і гальмуванням, ковзання вздовж стін | `iso/scripts/yard.gd:286` | `actors/player/player.gd` | `CharacterBody2D.move_and_slide` і справжня ізометрія замість `Y_FACTOR` |
| Глибина за лінією основи, прозорість того, що закриває героя | `iso/scripts/yard.gd:347-400` | `world/iso_block.gd`, `world.gd::_occlusion` | будинки нарізано на клітинки, тому окремі полігони основи не потрібні |
| Самотест і автопрохід без редактора (`--selftest`, `--demo`) | `iso/scripts/yard.gd:982` | `tests/runner.tscn`, `tools/shot_tour.gd` | окремий набір тестів, а не код усередині сцени гри |
| Експорт `.pck` і запуск у xvfb | `qa/check_export.sh` | `tools/run_tests.sh` (тести) | перевірка експорту — у ROADMAP (потрібні шаблони) |

## Що свідомо не взято
- **Уся графіка Afterfall:** концепти, нарізки, персонажі (Міра, Ейнштейн та інші), шрифт PixelifySans (без кириличної «О»).
- **Сюжет, тексти, ID квестів, формат збережень** `user://iso_save.json`: збереження Afterfall наш завантажувач відхиляє (тест `test_foreign_file_refused`).
- **ID пакетів:** нові — `ua.chicago.bloodloyalty`. Тека користувача — `chicago_blood_loyalty`.
- `dist/` (браузерна JS-версія), `trading-bot/` — не стосуються гри.

## Нове в Chicago
Усе в `chicago/`. Структура — в `docs/TECH_ARCHITECTURE.md`.
