# Deep Bounce — запуск у Google Play (покроково)

Усе, що можна підготувати без вашого акаунта, вже в репозиторії. Цей документ — що натиснути в Play Console і що
куди завантажити. Паралельно: товари й реклама — [`MONETIZATION_UA.md`](MONETIZATION_UA.md),
назви товарів 12 мовами — [`PLAY_PRODUCTS.md`](PLAY_PRODUCTS.md).

## 0. Що вже готово

| Що | Де |
|---|---|
| Підписаний AAB (versionCode 6, 1.1.1, target API 36, 64-біт) | `builds/DeepBounce-1.1.1.aab` |
| Іконка 512×512 для лістингу | `deep_bounce/assets/art/ui/icon_512.png` |
| Іконка в телефоні (адаптивна + монохромна для тем Android 13) | у збірці (з вашого арту) |
| Заставка під час запуску | у збірці (`assets/brand/splash.png` = ваш арт) |
| Графіка для лістингу 1024×500 | `deep_bounce/store/feature_graphic.png` |
| Скриншоти телефону 1080×1920, по 6 на кожну з 12 мов | `deep_bounce/store/<мова>/phone-screenshots/` |
| Назва, короткий (≤80) і повний (≤4000) опис, 12 мов | `deep_bounce/store/<мова>/*.txt` (усе разом — `store/listing.json`) |
| Політика конфіденційності (англ. + укр.) | `deep_bounce/store/privacy-policy.html` |
| Перевірка «чи можна в продакшн» | `deep_bounce/tools/android/check_store_ready.sh` |

Коди мов у теках збігаються з Play Console: `en-US`, `uk`, `pl-PL`, `de-DE`, `es-ES`, `fr-FR`, `it-IT`, `pt-BR`,
`tr-TR`, `ja-JP`, `ko-KR`, `zh-CN`.

## 1. Що потрібно від вас (без цього не обійтися)

1. **Акаунт розробника Google Play** (https://play.google.com/console, разовий внесок 25 $, перевірка особи).
2. **Email для зв'язку** (показується в лістингу) — і впишіть його в `store/privacy-policy.html` замість
   `[CONTACT EMAIL]`, разом з ім'ям розробника й датою.
3. **Опублікувати політику конфіденційності за публічним URL.** Найпростіше — GitHub Pages: покладіть
   `privacy-policy.html` у публічний репозиторій → Settings → Pages → вкажіть гілку → отримаєте адресу на
   кшталт `https://<логін>.github.io/<репо>/privacy-policy.html`. Або будь-який власний сайт.
4. **AdMob:** App ID і три рекламні блоки → `config/monetization.cfg` (розділ 3 у `MONETIZATION_UA.md`).
5. **Ключ ліцензування** з Play Console (з'явиться після створення застосунку) → `license_key`.
6. Ключ підпису `deep_bounce_release.jks` і пароль, які у вас уже є (той самий ключ, що для всіх версій).

Після 4–5 пересоберіть AAB (розділ 7). Для внутрішнього й закритого тестування можна вантажити поточний AAB із
тестовою рекламою — це нормально.

## 2. Створити застосунок

Play Console → **Create app**:
- App name: **Deep Bounce**; Default language: **English (United States) – en-US** (решту мов додамо як переклади);
- App or game: **Game**; Free or paid: **Free**;
- поставити галочки декларацій (Developer Program Policies, US export laws) → **Create app**.

**Play App Signing:** при першому завантаженні AAB погодьтесь, щоб Google зберігав ключ підпису застосунку.
Ваш `deep_bounce_release.jks` стане **ключем завантаження** — ним і далі підписуються всі AAB (так налаштований
`build_release.sh`). Не губіть його.

## 3. App content (Policy → App content) — готові відповіді

| Розділ | Відповідь |
|---|---|
| Privacy policy | URL з кроку 1.3 |
| App access | All functionality is available without special access (логіну немає) |
| Ads | **Yes, my app contains ads** |
| Content rating (IARC) | категорія **Game**; насильство — ні (розбиваються абстрактні камені, без персонажів); страх, сексуальний вміст, лайка, наркотики, азартні ігри — ні; користувачі не спілкуються й не діляться вмістом — ні; покупки цифрових товарів — **так**; реклама — так. Очікувано: PEGI 3 / ESRB Everyone / USK 0 |
| Target audience | **13–15, 16–17, 18+** (не обирайте молодші групи: тоді діють правила Families і потрібна інша конфігурація реклами). «Appeals to children» — No |
| News app | No |
| COVID-19 contact tracing | No |
| Data safety | відповіді — `MONETIZATION_UA.md`, розділ 6 |
| Government app | No |
| Financial features | My app doesn't provide any financial features |
| Health | No |
| Advertising ID | **Yes** — використовується для **Advertising or marketing** (і Analytics, Fraud prevention) Google Mobile Ads SDK |

## 4. Store presence → Main store listing

- **App name / Short description / Full description** — з `store/en-US/*.txt`; потім **Manage translations →
  Add your own translations** → для кожної мови вставити тексти з `store/<мова>/`.
- **App icon** — `assets/art/ui/icon_512.png`.
- **Feature graphic** — `store/feature_graphic.png` (одна для всіх мов).
- **Phone screenshots** — 6 файлів з `store/en-US/phone-screenshots/` (порядок за номерами); у кожному перекладі —
  скриншоти тієї мови (вони показують інтерфейс цією мовою).
- Tablet screenshots — необов'язково (гра портретна, телефонна).
- **Store settings:** Category — **Game → Arcade** (або Casual); Tags — Arcade, Casual, Puzzle, Offline;
  Contact details — email (обов'язково), сайт (для `app-ads.txt`, див. `MONETIZATION_UA.md` розділ 3.6).

## 5. Товари

Monetize with Play → Products → One-time products: 11 товарів з `PLAY_PRODUCTS.md` (ID, ціна, назви 12 мовами),
кожен **Activate**. Ця сторінка відкривається лише після завантаження AAB (крок 6.1).

## 6. Тестування → продакшн

1. **Internal testing** → Create new release → завантажити `builds/DeepBounce-1.1.1.aab` → Release name «1.1.1»,
   нотатки (наприклад, з повного опису) → Save → Review → **Start rollout**. Додати себе в Testers, відкрити
   посилання участі на телефоні, встановити з Play. Пройти перевірку з розділу 7 `MONETIZATION_UA.md`
   (тестова картка, PENDING, підтримка, відновлення, refund).
2. **Closed testing.** Для **нових особистих акаунтів розробника** Google вимагає перед продакшном закрите
   тестування щонайменше з **12 тестерами протягом 14 днів поспіль** (для акаунтів організацій цієї вимоги
   немає). Створіть трек Closed testing, додайте список email тестерів, той самий AAB.
3. **Production** (після виконання вимоги й «Apply for production»): спершу пересоберіть AAB з реальними ID
   (розділ 7), потім Production → Create new release → AAB → країни (можна всі) → **Staged rollout** 10–20 % →
   стежити за Android vitals і відгуками → 100 %.

Перший огляд Google зазвичай триває від кількох годин до кількох днів.

## 7. Збірка для продакшну

```bash
cd deep_bounce
# 1) впишіть реальні ID у config/monetization.cfg і use_test_ads=false, license_key
# 2) ключ — змінними середовища (див. README)
tools/android/check_store_ready.sh          # має сказати READY
# 3) збільшіть version/code у export_presets.cfg (кожне завантаження в Play — новий номер), назву за бажанням
tools/android/build_release.sh aab          # build/DeepBounce-<версія>.aab
```

Сценарій перевірки відмовляє, поки в конфігурації тестові блоки AdMob, порожні реальні ID, немає ключа
ліцензування або ключа підпису в середовищі.

## 8. Після публікації

- AdMob → Apps → прив'язати застосунок до лістингу Play; перевірити `app-ads.txt`.
- Play Console → Monetize → перевірити тестову покупку справжнім платежем на невелику суму (і повернути).
- Відповідати на відгуки; збої — у Android vitals.
