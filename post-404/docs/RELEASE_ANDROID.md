# Випуск Time Post у Google Play — що лишилось зробити вам

Уже готово (не треба нічого робити):
- проєкт переведено на **Godot 4.7.2** — він збирає гру під **API 36 (Android 16)**, як вимагає Google з 31.08.2026
  (перевірено в зібраному APK: targetSdk 36, minSdk 24 = Android 7.0+, дозвіл лише на вібрацію, портрет);
- пресет експорту **«Android Play (AAB)»** (Gradle, формат AAB, ключ береться зі змінних середовища);
- скрипти: `tools/release/1_make_upload_key.bat`, `tools/release/2_build_aab.bat` (Windows) та `.sh` (macOS/Linux);
- графіка й тексти магазину, політика конфіденційності (`docs/store/`);
- готові відповіді на всі анкети Play Console — `docs/store/PLAY_CONSOLE_ANSWERS.md`;
- повідомлення для тестувальників — `docs/store/TESTERS.md`.

У хмарному середовищі, де робилась гра, AAB зібрати неможливо: Gradle завантажує Android-плагін із серверів Google,
а вони там заблоковані (перевірено: `could not resolve com.android.application ... 8.6.1`). На вашому ПК це
відбудеться автоматично.

## Ваші кроки

### 1. Встановити програми (≈30 хв, один раз)
1. **Android Studio** — developer.android.com/studio. Відкрийте її один раз: вона встановить Android SDK і Java.
   У SDK Manager (More Actions → SDK Manager) переконайтесь, що є **Android 16 (API 36)** і **Build-Tools 36**.
2. **Godot 4.7.2** — godotengine.org/download/archive/4.7.2-stable (Windows, Standard) — розпакуйте, напр.,
   у `C:\Godot\`.
3. У Godot: **Editor → Manage Export Templates → Download and Install** (шаблони 4.7.2).
4. У Godot: **Editor → Editor Settings → Export → Android → Android SDK Path** — вкажіть шлях із SDK Manager
   (зазвичай `C:\Users\<ім'я>\AppData\Local\Android\Sdk`).
5. Завантажте проєкт із GitHub (гілка `ccr-38649251-wfvorb` → Code → Download ZIP), розпакуйте.

### 2. Ключ (5 хв, один раз)
Двічі клацніть `post-404\tools\release\1_make_upload_key.bat`, придумайте пароль.
Файл `timepost-upload.keystore` з'явиться у вашій папці користувача.
**Зробіть дві резервні копії файлу й пароля.** Не кладіть їх у GitHub.

### 3. Зібрати AAB (≈5 хв)
Відкрийте `2_build_aab.bat` у Блокноті, перевірте шлях до Godot у рядку `set GODOT=...`, збережіть,
двічі клацніть, введіть пароль. Перша збірка довша (Gradle завантажує бібліотеки).
Результат: `post-404\build\timepost.aab`. Якщо буде помилка — надішліть мені її текст.

### 4. Play Console
1. play.google.com/console → особистий акаунт → $25 → підтвердження особи.
2. Create app → заповнити все за `docs/store/PLAY_CONSOLE_ANSWERS.md`.
3. Увімкнути **Play App Signing** (пропонується при першому завантаженні — погоджуйтесь).
4. Closed testing → завантажити `timepost.aab` → запросити 15–20 людей (`docs/store/TESTERS.md`).
5. Через 14 днів — Apply for production → після перевірки гра в магазині.

### Оновлення в майбутньому
Перед кожним новим завантаженням збільшити у `export_presets.cfg` (обидва Android-пресети) `version/code`
(+1) і `version/name`. Я можу робити це сам у кожній новій версії.

## Технічні параметри
- Пакет: `ua.post404.parcels` (після першої публікації змінити неможливо; користувачі його не бачать).
- Target API 36, мінімальний Android 7.0 (API 24), архітектури arm64-v8a + armeabi-v7a.
- Дозволи: лише вібрація. Інтернет не потрібен.
