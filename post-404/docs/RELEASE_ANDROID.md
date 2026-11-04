# Випуск у Google Play — покрокова інструкція

Усе, що можна було підготувати без вашого облікового запису й ключа, вже готово:
пресет експорту, графіка магазину (`docs/store/`), тексти сторінки, політика конфіденційності.

## 1. Ключ підпису (робите ви, один раз)
Ключ — це ваш «паспорт» застосунку. **Не втрачайте його і не кладіть у GitHub.**
```
keytool -genkeypair -v -keystore post404-upload.keystore -alias post404 \
  -keyalg RSA -keysize 2048 -validity 10000
```
Збережіть файл і пароль у надійному місці (менеджер паролів + резервна копія).
У Play Console увімкніть **Play App Signing** — тоді Google зберігає основний ключ, а цей стає «ключем завантаження»
(якщо його загубити, Google може його замінити).

## 2. Збірка AAB (Google Play приймає лише AAB)
AAB потребує Gradle-збірки Godot:
1. Godot 4.3 → Project → Install Android Build Template.
2. Повний Android SDK (Android Studio або `sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"`).
3. У пресеті «Android»: `gradle_build/use_gradle_build = true`, `gradle_build/export_format = 1` (AAB).
4. Ключ — через змінні середовища (не в `export_presets.cfg`):
```
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/шлях/post404-upload.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=post404
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=ваш_пароль
godot --headless --path post-404 --export-release "Android" build/post404.aab
```
У хмарному середовищі, де робилася гра, сервери Google (dl.google.com) заблоковані, тому AAB тут зібрати
не вдалося — це треба зробити на вашому ПК (Windows/macOS/Linux). Debug APK для тестів збирається і тут.

Перед кожним новим завантаженням збільшуйте `version/code` (ціле число) і `version/name` у пресеті.

## 3. Play Console (робите ви)
1. Обліковий запис розробника Google Play (разовий внесок $25).
2. Створити застосунок: назва «POST 404: Parcels From Tomorrow», мова за замовчуванням — українська, гра, безкоштовна.
3. **Сторінка в магазині:** тексти з `docs/store/listing_uk.md` і `listing_en.md`;
   іконка `docs/store/icon_512.png`; графіка `docs/store/feature_graphic_1024x500.png`;
   скриншоти `docs/store/screenshots/` (720×1280, підходять для телефонів).
4. **Політика конфіденційності:** опублікуйте `docs/store/privacy_policy.md` за публічним посиланням
   (напр. GitHub Pages або Google Sites) і вкажіть URL.
5. **Безпека даних:** гра не збирає й не передає жодних даних → «No data collected», «No data shared».
6. **Рейтинг вмісту (IARC):** без насильства, азартних ігор, покупок, чатів → очікуваний рейтинг 3+/PEGI 3.
7. **Цільова аудиторія:** 13+ або «усі», реклами немає.
8. Почати з **внутрішнього тестування** (до 100 тестувальників), потім закрите → відкрите → продакшн.
   Для нових особистих акаунтів Google вимагає закрите тестування з ≥12 тестувальниками протягом 14 днів.

## Технічні параметри
- Пакет: `ua.post404.parcels` (змінити можна лише до першої публікації).
- Мінімальний Android: 5.0 (API 21, за замовчуванням Godot 4.3); цільовий API 34.
- Архітектури: arm64-v8a, armeabi-v7a. Дозволи: лише вібрація. Інтернет не потрібен.
