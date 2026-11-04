# CONTINUE — як продовжити роботу без повторного планування

**Назва гри:** Time Post (робоча назва була POST 404; папка `post-404/`, пакет `ua.post404.parcels` — не міняти).

**Стан:** версія 0.1.0 грається повністю (пролог → навчання → зміни → глави → фінал → нескінченна гра).
Логічні тести 246/246, скриншот-тур без помилок, debug APK у `builds/`.

## Відновити середовище (хмарний контейнер)
1. Godot 4.7.2: `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
   → `/usr/local/bin/godot`.
2. Шаблони експорту: `Godot_v4.7.2-stable_export_templates.tpz` → розпакувати вміст `templates/` у
   `~/.local/share/godot/export_templates/4.7.2.stable/`.
3. APK без повного Android SDK (dl.google.com у цьому середовищі заблоковано): папка-заглушка `~/android-sdk` з
   `platform-tools/adb` (порожній скрипт) і `build-tools/34.0.0/apksigner` — обгортка над
   `uber-apk-signer-1.3.0.jar` (GitHub releases patrickfav/uber-apk-signer, покласти в `~/tools/`).
   Готова обгортка: `tools/android_sdk_shim/apksigner` (скопіювати й `chmod +x`).
   Debug keystore: `keytool -genkeypair -keystore ~/.local/share/godot/keystores/debug.keystore -storepass android
   -alias androiddebugkey -keypass android -keyalg RSA -validity 10000 -dname "CN=Android Debug,O=Android,C=US"`.
   У `~/.config/godot/editor_settings-4.7.tres` вказати `export/android/android_sdk_path`.
4. Python 3 + Pillow + numpy — для `tools/make_art.py` і `tools/make_audio.py`.

## Команди
- Імпорт: `godot --headless --path post-404 --import`
- Тести: `godot --headless --path post-404 -s res://tests/run_tests.gd`
- Скриншоти: `xvfb-run -a godot --path post-404 --resolution 720x1280 --rendering-driver opengl3 -- --save=user://tour.json --shots=/tmp/shots`
- APK: `godot --headless --path post-404 --export-debug "Android" build/post404-debug.apk`
- Перегенерувати графіку/звук: `python3 tools/make_art.py`, `python3 tools/make_audio.py` (потім імпорт).

## Де що міняти
- Баланс: `scripts/core/upgrades.gd` (ціни/ефекти), `content.gd` (маршрути), `progression.gd` (досвід, рівні відкриття),
  `shift_session.gd` (монети за посилку, бонуси, надійність). Після змін — тест `test_balance` друкує графік.
- Новий тип посилки: `package_generator.gd::_build` + `Rules.deduce/judge` + `ShiftSession.mechanics_of` +
  тексти `tip_*`/`mech_*` в `i18n.gd` + малювання в `parcel_view.gd`.
- Нова подія: `events.gd::DEFS` + обробка в `shift.gd::_on_event_started/_ended` + `Progression.UNLOCKS`.
- Сюжет: `story_data.gd` (рядок = [мовець, uk, en]; вибір = {"choice": [...]}).

## Наступні кроки
Дивись `TODO.md`, розділ «Далі». Найперше — перевірка на телефоні власника.
