# Afterfall: «Останній сад» — графіка, якої бракує (завдання для ChatGPT)

Цей файл — продовження пакета «Afterfall_Remaining» (архіви 1–15). Місію 2.2 «Пральня» вже зібрано в Godot.
Тут перелічено тільки те, чого в пакеті **немає**, тому зараз воно намальоване кодом або тимчасово підставлене.

---

## Частина 1. Для тебе: як користуватися

1. **Відкрий новий чат** у ChatGPT. Найкраще той самий, де малювався пакет: так стиль лишиться однаковим.
2. **Прикріпи цей файл** і референси, які вказані в кожному завданні (рядок «Референс»).
   - Усі вони лежать у тебе в архівах пакета, а в репозиторії — у `art/rest/…`.
3. **Перше повідомлення:**
   > Прочитай файл. Ти художник гри Afterfall. Дотримуйся правил із Частини 2. Зроби завдання M1.
4. **Одне завдання — одне повідомлення — одна картинка.** До кожного завдання знову прикріпи його референс.
5. **Перевір результат** за чек-листом (Частина 4). Якщо щось не так, скопіюй готову фразу для виправлення.
6. **Назви файли, як у завданні** (`M1_crawler_actions.png` тощо), і надішли мені архівом до 30 МБ.

**Порядок:** спершу блок **M** — він одразу потрапить у готову місію. Потім **P** (люди й портрети), **I** (значки), **C** (глава 1 і місія 2.3).

---

## Частина 2. Для ChatGPT: про гру і правила

### Гра
**Afterfall: «Останній сад»** — 2D-гра з видом збоку для телефона й ПК, рушій **Godot**.
- **Світ:** 40 років після Падіння. Руїни, зарослі міста, затоплені будівлі, мутовані істоти.
- **Герої:**
  - штучний дослідник у подобі Альберта Ейнштейна;
  - Міра — механікиня з поселення «Станція».
- **Мета:** лагодити техніку, рятувати насіння, відновлювати природу.

### Стиль — точно як у прикріплених референсах
- **Детальний піксель-арт:** чіткі краї без розмиття, темний теплий контур, світло зверху ліворуч.
- **Палітра:** іржавий метал, синя облуплена фарба, мокрий бетон, мох; тепле світло ламп.
- **Ракурс:** вид **строго збоку**, як у 2D-платформері. Не 3/4, не ізометрія.

### Технічні правила (кожна картинка)
1. **Фон прозорий.** Якщо прозорість не виходить — суцільний **#FF00FF** без відтінків.
   - Виняток — портрети: у них фон **#1a242c**.
2. **Ніякого тексту, цифр, літер, підписів, водяних знаків, рамок, ліній сітки.** На вивісках — тільки піктограми.
3. **Рівна сітка:** усі клітинки однакові, одна річ у клітинці по центру. Відступ від країв не менше 5%, сусіди не торкаються.
4. **Масштаб і лінія землі:**
   - Масштаб однаковий у межах аркуша **і такий самий, як у референсі**.
   - Ноги персонажів і низ предметів — на одній горизонтальній лінії.
5. **Стани одного предмета** (до / після) — однакового розміру й на тому самому місці клітинки. Змінюються лише деталі.
6. **Напрямок:** персонажі й кроулер дивляться **праворуч**, як у референсах.
7. **Розмір картинки:** 1536×1024 (горизонтальна), 1024×1536 (вертикальна) або 1024×1024 (квадрат).
8. **Тіні й підлога:** без тіні на землі і без підлоги під персонажами чи предметами (якщо завдання не просить землю).

### Масштаб у грі (для довідки)
| Що | Висота |
|---|---|
| Людина | 1 |
| Двері пральні (A158) | 1,3 людини |
| Вантажні ворота (A163) | 1,6 людини |
| Візок (A160), корпус фільтра (A157) | ≈ по пояс |
| Кроулер (A161) | ≈ по коліно (третина людини) |
| Ящик (A111) | по коліно |

---

## Частина 3. Завдання

### M. Місія 2.2 «Пральня» (першочергово)

#### M1. Кроулер — дії
- **Файл:** `M1_crawler_actions.png`.
- **Референс:** `art/rest/laundry_mission/A161.png` (той самий кроулер, той самий масштаб).
- **Формат:** 1536×1024, 4 стовпці × 2 ряди.
- **Кадри:**
  1. спить, згорнувшись клубком;
  2. те саме, вдих (бік трохи піднятий);
  3. гризе їжу, голова донизу;
  4. насторожився — вигнута спина, вищирені зуби;
  5. стрибок-атака в повітрі, лапи вперед;
  6. отримав удар — відкинутий назад, очі заплющені;
  7. тікає — низько до землі, хвіст витягнутий;
  8. приземлився після стрибка, присів.

```
Pixel art sprite sheet for a 2D side-scrolling game. The SAME mutant crawler creature as in the attached reference sheet:
hairless grey-green rat-like body, blue armour plates on the back, long segmented tail, orange eyes. Same scale, same colours.
Layout: 1536x1024, exactly 4 columns x 2 rows of equal 384x512 cells, one pose per cell, feet on the same baseline, facing right, strict side view.
Frames: 1 sleeping curled up; 2 sleeping, breathing in (side slightly raised); 3 eating, head down; 4 alert, arched back, bared teeth;
5 lunging attack in mid-air, front claws forward; 6 hit, knocked back, eyes shut; 7 fleeing, low to the ground, tail stretched; 8 landing crouch.
Transparent background. No text, no ground, no shadows, no grid lines.
```

#### M2. Ейнштейн — стрибок, драбина, поранення
- **Файл:** `M2_einstein_moves.png`.
- **Референс:** `art/rest/chapter_01/A105.png` (той самий одяг, рюкзак, зачіска, той самий масштаб).
- **Формат:** 1536×1024, 4×2.
- **Руки:** порожні, ключ гра вкладає сама.
- **Кадри:**
  1. відштовхується для стрибка;
  2. у повітрі вгору;
  3. падає вниз;
  4. приземлення, присів;
  5–6. лізе по драбині (видно збоку, одна рука вгорі, потім друга; драбину не малювати);
  7. отримав удар, відхилився назад;
  8. біг (один кадр широкого кроку).

```
Pixel art sprite sheet for a 2D side-scrolling game. The SAME elderly scientist character as in the attached reference sheet
(wild white hair, moustache, brown jacket, backpack, worn trousers and boots). Identical face, clothes, colours and scale.
Layout: 1536x1024, exactly 4 columns x 2 rows of equal 384x512 cells, one full-body pose per cell, feet on the same baseline, facing right, strict side view, empty hands.
Frames: 1 crouching to jump; 2 jumping up in mid-air; 3 falling down; 4 landing crouch; 5 climbing a ladder seen from the side, right hand up;
6 climbing, left hand up (do NOT draw the ladder); 7 hit, leaning back in pain; 8 running, wide stride.
Transparent background. No text, no ground, no shadows, no grid lines.
```

#### M3. Просіла балка над завалом
- **Файл:** `M3_beam.png`.
- **Референси:** `art/rest/chapter_01/A115.png` (завал), `art/rest/laundry_mission/A164.png` (домкрат).
- **Формат:** 1536×1024, 1 стовпець × 2 ряди. Балка займає 90% ширини.
- **Стани:**
  1. сталевий двотавр просів дугою посередині, тріщини в бетоні на кінцях, з нього сиплеться пил;
  2. та сама балка рівна: під нею праворуч від центру стоїть піднятий домкрат (як A164, стан «піднятий»).
- Кінці балки — обламані бетонні опори. **Завал не малювати** (він окремо).

```
Pixel art game object, two states, for a 2D side-scrolling game, style matching the attached references.
A long rusty steel I-beam with broken concrete supports at both ends, strict side view, spanning 90% of the image width.
Layout: 1536x1024, 1 column x 2 rows of equal cells, same size and position in both cells.
State 1: the beam sags in the middle in a curve, cracks at the ends, dust falling. State 2: the same beam straight, a raised screw jack under it right of centre.
Transparent background. Do not draw rubble, ground, text or grid lines.
```

#### M4. Пролом у настилі
- **Файл:** `M4_walkway_hole.png`.
- **Референс:** `art/rest/laundry_mission/A159.png` (та сама платформа: решітка, перила, іржа).
- **Формат:** 1536×1024, 1×2. Шматок настилу на всю ширину.
- **Стани:**
  1. посередині пролом приблизно на третину ширини: обірвана решітка, погнуті краї, перила обірвані;
  2. той самий пролом закладено **двома дошками**, перила лишились обірвані.
- Лівий і правий краї шматка мають **стикуватися з A159** (та сама висота настилу й перил).

```
Pixel art platform segment, two states, for a 2D side-scrolling game. The SAME rusty industrial walkway as in the attached reference
(metal grating, wooden inserts, railings, rust and moss), same height, same scale, strict side view, full image width, edges must match the reference so they connect.
Layout: 1536x1024, 1 column x 2 rows of equal cells.
State 1: a hole in the middle about one third of the width, torn grating, bent edges, broken railing.
State 2: the same hole covered with two wooden planks, railing still broken.
Transparent background. No text, no ground, no grid lines.
```

#### M5. Обладнання пральні
- **Файл:** `M5_laundry_props.png`.
- **Референс:** `art/rest/laundry_mission/A165.png` (стіна пральні, той самий колір і бруд).
- **Формат:** 1536×1024, 4×2.
- **Предмети:**
  1. промислова пральна машина, ціла, дверцята зачинені (по груди людині);
  2. та сама машина: дверцята відчинені, зсередини звисає ганчір'я;
  3. перекинута машина на боці;
  4. металевий візок-кошик для білизни;
  5. рама-сушарка з ганчір'ям;
  6. іржава мийка з краном;
  7. купа мокрого ганчір'я та сміття;
  8. гніздо кроулера: обгризені кістки, консервні бляшанки, огризки (низьке, плоске).

```
Pixel art prop sheet for a 2D side-scrolling game, abandoned flooded laundry, style and colours matching the attached reference wall
(blue chipped paint, rust, wet concrete, moss). Strict side view.
Layout: 1536x1024, exactly 4 columns x 2 rows of equal cells, one object per cell, same scale, bottoms on the same baseline.
Objects: 1 industrial washing machine, closed (chest high to a person); 2 the same machine with its door open, rags hanging out;
3 the same machine toppled on its side; 4 metal laundry cart basket; 5 drying rack with rags; 6 rusty sink with a tap;
7 pile of wet rags and debris; 8 crawler nest: gnawed bones, empty tin cans, scraps, low and flat.
Transparent background. No text, no ground, no shadows, no grid lines.
```

#### M6. Фасад пральні (вхід із вулиці)
- **Файл:** `M6_laundry_facade.png`.
- **Референси:**
  - `art/rest/story_concepts/A014.png` (вулиця);
  - `art/rest/laundry_mission/A158.png` (двері);
  - `art/rest/laundry_mission/A165.png` (стіна всередині).
- **Формат:** 1024×1536 (вертикальна).
- **Що на картинці:** край будівлі пральні від землі до даху, вид збоку.
  - Цегла, облуплена синя штукатурка, ліани, розбиті вікна.
  - Вивіска з **піктограмою пральної машини** (без літер).
  - **Отвір для дверей знизу посередині**: пустий, прозорий, на ширину й висоту дверей A158 (двері підставлю окремо).
  - Низ картинки — лінія тротуару, сам тротуар **не малювати**.

```
Pixel art building facade piece for a 2D side-scrolling game, style matching the attached references.
The front edge of an old abandoned laundry building, strict side view, from the ground up to the roof: bricks, chipped blue plaster, vines,
broken windows, a hanging sign showing only a washing machine pictogram (no letters).
Layout: 1024x1536 vertical. At the bottom centre an EMPTY transparent doorway exactly the size of the attached door (the door is added separately).
The bottom edge of the image is the ground line; do not draw the pavement.
Transparent background around the building. No text, no grid lines.
```

#### M7. Дрібниці для місії
- **Файл:** `M7_small_props.png`.
- **Формат:** 1536×1024, 4×2. Масштаб — як у ящика A111 (`art/rest/chapter_01/A111.png`).
- **Предмети:**
  1. дорожній вказівник-стрілка праворуч на стовпчику, з піктограмою потяга (без літер);
  2. стос із двох дощок;
  3. одна консервна бляшанка;
  4. пом'ята бляшанка з розсипаною їжею (кроулер з'їв);
  5. двері службової підсобки (вузькі, темні, прочинені);
  6. ланцюговий ворот на стіні (колесо з ланцюгом), стан «спокій»;
  7. той самий ворот, ланцюг натягнутий, колесо повернуте;
  8. калюжа на підлозі (плоска, бірюзова).

```
Pixel art small prop sheet for a 2D side-scrolling game, style matching the attached reference crate. Strict side view.
Layout: 1536x1024, exactly 4 columns x 2 rows of equal cells, one object per cell, same scale, bottoms on one baseline.
Objects: 1 road sign arrow pointing right on a post with a train pictogram (no letters); 2 stack of two wooden planks; 3 a single tin can;
4 crushed tin can with spilled food; 5 a narrow dark service door, slightly open; 6 wall chain winch (wheel with chain), at rest;
7 the same winch, chain taut, wheel turned; 8 a flat turquoise water puddle.
Transparent background. No text, no grid lines.
```

---

### P. Люди й портрети

#### P1. Портрети
- **Файли:** `P1_portrait_nazar.png`, `P1_portrait_mira.png`, `P1_portrait_sava.png`, `P1_portrait_pavlo.png`, `P1_portrait_einstein.png`.
- **Референс подачі:** `art/rest/water_mission/A177.png` (портрет Яни: однакова подача, світло, кадр).
- **Референси облич:**

  | Хто | Файл |
  |---|---|
  | Назар | `art/rest/laundry_mission/A166.png` |
  | Міра | `art/rest/chapter_01/A108.png` |
  | Павло | `art/rest/chapter_02/A127.png` |
  | Ейнштейн | `art/rest/chapter_01/A105.png` |
  | Сава | див. P2 |

- **Формат:** 1024×1024, по плечі, обличчя 3/4 праворуч, фон суцільний **#1a242c**. По одному файлу на кожного.

```
Pixel art character portrait for dialogue boxes, same framing, lighting and style as the attached portrait.
Character: {NAME AND LOOK — same face and clothes as in the attached sprite sheet}. Head and shoulders, three-quarter view facing right,
warm lamp light from the upper left. 1024x1024, solid background colour #1a242c. No text, no frame.
```

#### P2. Сава — аркуш рухів
- **Файл:** `P2_sava_sheet.png`.
- **Хто це:** Сава — старший у поселенні біля пральні, приблизно 60 років.
  - Широкоплечий, сива коротка борода, лисина.
  - Довгий латаний плащ кольору хакі, шарф, окуляри на шнурку, палиця-посох.
- **Референс масштабу й подачі:** `art/rest/laundry_mission/A166.png` (Назар).
- **Формат:** 1536×1024, 4×2.
- **Кадри:** хода ×4 · стоїть · говорить (жест рукою) · схрестив руки · показує вперед.

```
Pixel art character sprite sheet for a 2D side-scrolling game, same scale, framing and style as the attached sheet.
Character: Sava, about 60, elder of a survivor settlement: broad shoulders, short grey beard, bald head, long patched khaki coat, scarf,
glasses on a cord, wooden walking staff.
Layout: 1536x1024, exactly 4 columns x 2 rows of equal cells, one full-body pose per cell, feet on the same baseline, facing right, strict side view.
Frames: 4 walk cycle frames; idle; talking with a hand gesture; arms crossed; pointing ahead.
Transparent background. No text, no ground, no shadows, no grid lines.
```

#### P3. Міра — стрибок, драбина, біг
- **Файл:** `P3_mira_moves.png`.
- **Референс:** `art/rest/chapter_01/A108.png` (той самий одяг і масштаб).
- **Формат і кадри:** як у M2 (1536×1024, 4×2): відштовхується · вгору · падає · приземлилась · драбина ×2 · отримала удар · біг.
- **Промпт:** промпт M2 із заміною опису персонажа на Міру з референсу.

---

### I. Значки предметів (інвентар і підказки)

#### I1. Значки
- **Файл:** `I1_item_icons.png`.
- **Формат:** 1024×1024, 4×4, клітинка 256×256. Предмет займає ~70% клітинки, вид 3/4 збоку. Колір і стиль — як у пакеті.
- **Ряди:**
  1. розвідний ключ · домкрат · дві дошки · консерва;
  2. корпус фільтра · ремонтний вузол · ганчірка · брухт;
  3. пакетик насіння · мірна чашка · ліхтарик · записник;
  4. серце (здоров'я) · знак «точку збережено» (дискета-шестерня) · журнал (книжка із закладкою) · ще одна консерва з відкритою кришкою.

```
Pixel art inventory icon sheet for a 2D game, style and colours matching the attached references.
Layout: 1024x1024, exactly 4x4 equal 256x256 cells, one item per cell, each item about 70% of its cell, consistent light from the upper left.
Row 1: adjustable wrench; screw jack; two wooden planks; tin can. Row 2: blue water filter housing; repair unit; rag; scrap metal.
Row 3: seed packet; measuring cup; flashlight; notebook. Row 4: heart; "game saved" icon (floppy disk with a gear); journal book with a bookmark; opened tin can.
Transparent background. No text, no numbers, no grid lines.
```

---

### C. Глава 1 і місія 2.3 (пізніше)

#### C1. Механізми лабораторії (глава 1)
- **Файл:** `C1_lab_mechanisms.png`.
- **Референси:** `art/rest/chapter_01/A106.png` (стіна лабораторії), `art/rest/chapter_01/A109.png` (аварійні двері).
- **Формат:** 1536×1024, 4×2. Стани — попарно в однаковому розмірі.
- **Кадри:**
  1–2. щиток із рубильником: вимкнено (червона лампа) / увімкнено (зелена);
  3–4. підйомний місток: піднятий (стоїть вертикально) / опущений (лежить горизонтально);
  5–6. гермоперегородка: відчинена / зачинена;
  7–8. насос аварійного відкачування: вимкнений / працює.

#### C2. Стелаж Павла (місія 2.3)
- **Файл:** `C2_pavlo_shelf.png`.
- **Референс:** `art/rest/chapter_02/A127.png` (Павло, для масштабу).
- **Формат:** 1536×1024, 3×1. Дерев'яний стелаж у теплиці в одному розмірі:
  1. прогнилий і похилений, на ньому горщики;
  2. наполовину розібраний;
  3. розібраний — акуратний стос дощок і горщиків.

Промпт для C1 і C2 будуй як у M3: «same size and position in every cell, only details change».

---

## Частина 4. Чек-лист перед відправкою (перевіряєш ти)
- [ ] Фон прозорий (крім портретів — там **#1a242c**).
- [ ] Сітка рівна, кількість клітинок як у завданні, в кожній одна річ.
- [ ] Порядок кадрів чи предметів як у завданні.
- [ ] Масштаб такий самий, як у референсі: кроулер не більший, Ейнштейн не нижчий.
- [ ] Ноги й низ предметів на одній лінії.
- [ ] Стани одного предмета однакового розміру й на тому самому місці.
- [ ] Персонаж однаковий у всіх кадрах і такий самий, як у референсі.
- [ ] Немає тексту, літер, цифр, рамок, сітки, підлоги й тіней.
- [ ] Вид строго збоку, дивляться праворуч.

### Готові фрази для виправлення (копіюй у ChatGPT)
| Що не так | Фраза |
|---|---|
| Інший масштаб, ніж у референсі | `Redo it at exactly the same scale as the attached reference sheet.` |
| Персонаж не схожий | `Redo it: the character must look identical to the attached reference — same face, hair, clothes, colours.` |
| Стани зсунуті | `Redo it: all states must be exactly the same size and position in their cells; only the details change.` |
| Є тінь, підлога, текст | `Redo it without any ground, shadows, text, letters or grid lines. Transparent background.` |
| Не та сітка | `Redo it: exactly {N} columns x {M} rows of equal cells, one item per cell, in the order I listed.` |
| Ракурс 3/4 чи перспектива | `Redo it in a strict side view, like a 2D platformer.` |
| Настил не стикується | `Redo it: the left and right edges must match the attached walkway exactly so the pieces connect.` |
| Двері намальовані у фасаді | `Redo it: leave the doorway empty and transparent; the door is added separately.` |

---

## Частина 5. Для мене (куди що піде в грі)
| Завдання | Де в грі | Що замінить |
|---|---|---|
| M1 | кроулери в залі й у дворі | кадри 4–5 з A161 для сну, замаху й удару |
| M2 | герой: стрибок, драбина, удар | кадри «присів / коліно вгору» з A105 |
| M3 | балка над завалом | лінія, намальована кодом |
| M4 | пролом у верхньому настилі | прямокутники-дошки з коду |
| M5 | машинний зал, затоплений зал | порожні стіни (лише фон A165) |
| M6 | межа вулиця → пральня | різкий шов між фоном вулиці й стіною |
| M7 | вказівник «Станція», дошки, консерви, підсобка, ворот, калюжі | малюнки кодом і темний прямокутник |
| P1 | діалоги | Назар і Сава зараз без портретів, Міра й Ейнштейн — старі портрети |
| P2 | місія 2.1 / повернення з пральні | Сави в грі ще немає |
| P3 | Міра в главі 1 | — |
| I1 | журнал, підказки «+ предмет», здоров'я | текст і символ ♥ |
| C1, C2 | глава 1, місія 2.3 | — |
