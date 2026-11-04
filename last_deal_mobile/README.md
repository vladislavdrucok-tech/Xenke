# LAST DEAL: Shop Simulator

2D-симулятор крамниці вживаних речей у кіберпанковому місті. Godot 4.3, GDScript, Android, портрет, українська.

**Як грати:** клієнт приносить річ і називає ціну → «Перевірити» (стан, приховані дефекти, оцінка) → «Торгуватися» або «Купити»/«Відмовитися» → на вкладці «Склад» продаєте за ринковою ціною (попит змінюється щодня) → увечері сплачуєте оренду → купуєте покращення на вкладці «Розвиток». Прогрес зберігається автоматично.

- Запуск у редакторі: Godot 4.3 → Import → `last_deal_mobile/project.godot` → F5.
- Тести, збірка APK, архітектура та журнал: `PROGRESS.md`.
- Готовий APK: `builds/`.
- Графіка оригінальна, генерується `tools/gen_art.py`; шрифти — вільні ліцензії (`assets/fonts/README.md`).

## Експорт Android вручну (зі справжнім Android SDK)
1. Встановити шаблони експорту Godot 4.3, JDK 17+, Android SDK (platform-tools, build-tools).
2. Editor Settings → Export → Android: шляхи до SDK і JDK.
3. Project → Export → «Android» → Export Project (ключ: змінні `GODOT_ANDROID_KEYSTORE_RELEASE_*` або поля пресету).
Без SDK: `tools/build_android.sh` (див. коментар у скрипті).
