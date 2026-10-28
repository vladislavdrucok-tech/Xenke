# Afterfall — ТЗ на графіку (v0.6)

Як користуватися: копіюй англійський промпт у генератор зображень (ChatGPT / DALL·E, Midjourney тощо). До кожного запиту **прикріплюй референс стилю**: `art/concepts-v06/mine.png` або `art/concepts-v06/workbench.png`, а для героїв ще й `dist/assets/einstein-atlas.webp`. Готові файли надсилай мені, я їх наріжу й підключу. Скрипт `scripts/import-art.py` робить це автоматично.

Загальні правила для **всіх** спрайтів і предметів:
- Детальний піксель-арт у стилі концептів (Terraria-подібний, теплі контури, без розмиття).
- **Суцільний пурпуровий фон #FF00FF** без тіней на фоні, без підлоги, без тексту, без рамок, без інтерфейсу.
- Об'єкти не торкаються країв клітинки та один одного.
- Вид збоку, герої дивляться **праворуч**.

---

## 1. Герої (аркуш поз 4×2)

Розмір аркуша: **1536×1024**, 8 клітинок по 384×512, у кожній клітинці одна поза, ноги на одній лінії, однаковий масштаб у всіх клітинках.
Порядок поз (зліва направо, згори вниз): хода 1, хода 2, хода 3, хода 4, стоїть із киркою, замах киркою над головою, удар киркою вперед, стрибок.

Шаблон промпту (підставляй опис героя в `{HERO}`):

```
Pixel art character sprite sheet for a 2D side-scrolling survival game, detailed Terraria-like style matching the attached reference.
Character: {HERO}. Carries a worn leather backpack with tools and a pickaxe.
Layout: 4 columns × 2 rows, 1536×1024 px, each cell 384×512, one full-body pose per cell, all poses at the same scale with feet on the same baseline, character facing right.
Poses in order: walk cycle frame 1, walk 2, walk 3, walk 4, idle holding a pickaxe, overhead pickaxe wind-up, forward pickaxe strike, mid-air jump.
Flat solid magenta background #FF00FF, no ground, no shadows, no text, no UI, poses do not overlap cell borders.
```

Персонажі (вже є в грі з перевагами, чекають на графіку):
- **Марія Склодовська-Кюрі** — `{HERO}`: `Marie Skłodowska-Curie as a friendly stylised scientist explorer: dark long skirt, high-collar blouse, lab coat over it, hair in a bun, small round brass goggles on her forehead`
- **Нікола Тесла** — `{HERO}`: `Nikola Tesla as a friendly stylised inventor explorer: slim, centre-parted dark hair, moustache, dark three-piece suit with rolled sleeves, a small coil device on his belt`
- **Чарлз Дарвін** — `{HERO}`: `Charles Darwin as a friendly stylised naturalist explorer: older, big white beard, bald top, tweed coat, field notebook and a butterfly net strapped to the backpack`

**Карикатури політиків.** Напиши, кого саме ти хочеш бачити, і я підготую для них промпти та переваги. Майте на увазі:
- **Генератори:** багато з них відмовляються малювати впізнаваних реальних політиків, тому, можливо, доведеться формулювати описово, без імен.
- **Тон:** для міжнародної аудиторії й магазинів застосунків краще дружній шарж без образливих деталей.

Після генерації: `python3 scripts/import-art.py hero curie sheet.png`. Герой одразу стає доступним на екрані вибору.

## 2. Портрети героїв (для панелі здоров'я та вибору)

```
Pixel art head-and-shoulders portrait of {HERO}, 3/4 view facing right, detailed Terraria-like style matching the attached reference portrait,
square 512×512, plain dark slate background #1a242c, no frame, no text.
```
Після генерації: `python3 scripts/import-art.py portrait curie portrait.png`.

## 3. Предмети (аркуш іконок 8×4)

Зараз іконки вирізані з концептів (`scripts/extract-concept-icons.py`), і частини предметів у них немає. Потрібен один аркуш **1024×512**, 8×4 клітинок по 128 px, у кожній клітинці один предмет по центру з невеликим відступом.

```
Pixel art item icon sheet for a post-apocalyptic survival game, detailed style matching the attached hotbar icons.
8 columns × 4 rows, 1024×512 px, 128 px cells, one item centred per cell with padding, slight top-left lighting, dark outline.
Items in order: wood logs, stone chunk, scrap metal gear, folded cloth, seeds with a sprout, glass fuse, canteen of murky stream water, clear water bottle,
wooden planter crate with seedlings, red berries, slingshot pebbles, iron ore chunk, coil of copper wire, red medkit, food tin can, torch,
pickaxe, axe, slingshot, flashlight, workbench hammer, water filter barrel, generator, soil purifier device, seed capsule (glass jar with leaf),
handheld scanner, rope coil, backpack, frost crystal, antler shard, key card, battery.
Flat solid magenta background #FF00FF, no text, no numbers, no slot frames.
```

## 4. Шахта (місія 3) — фон і реквізит

Шахту гра зараз малює сама. Щоб вона виглядала як на концепті, потрібні два файли.

**4а. Задня стіна шахти**, тайл, що безшовно повторюється по горизонталі, **1024×512**:
```
Seamless horizontally tileable pixel art back wall of an old mine tunnel, side view, dark stone blocks with mortar, wooden support beams every ~340 px,
a few orange iron ore specks, damp patches, detailed Terraria-like style matching the attached mine concept. No characters, no UI, no foreground floor.
```
**4б. Реквізит шахти** (аркуш 4×2, 1024×512, пурпуровий фон): дерев'яна драбина (вертикальна, 1 сегмент), настінний ліхтар, жила залізної руди в скелі, вагонетка з рудою, електрощиток закритий, електрощиток відкритий з іскрами, кліть вантажного ліфта, ящик із припасами.

## 5. Сховище насіння під інститутом (місія 4, наступна)

**5а. Задня стіна холодного сховища**, тайл 1024×512: металеві стелажі з банками насіння, іній на панелях, холодне блакитне світло, як на третьому концепті.
**5б. Реквізит** (4×2, пурпуровий фон): стелаж із банками, капсула насіння, термінал, морозильна двері, обігрівач, сходи вниз, розбита труба з парою, ящик.

## 6. Вороги

Кожен аркуш **1536×512**, 6 клітинок по 256×512 в один ряд, пурпуровий фон, дивиться праворуч.
- **Кам'яний броненосець** (шахта): `stone-plated armadillo mutant with glowing red eyes and amber crystal growths` — хода 1–4, кидок-укус, отримав удар.
- **Олень із кришталевими рогами** (бос сховища, концепт 3): `huge mutated deer covered in moss and pink fungus, glowing crystal antlers` — хода 1–2, замах рогами, ривок, оглушений, поразка.
- **Павук-мутант** (сховище): `crab-like spider mutant with a mossy shell and amber eyes` — хода 1–4, стрибок, отримав удар.

---

## Що вже зроблено в коді, поки графіка в роботі
- Інтерфейс у стилі концептів, хотбар, верстак із вкладками, вибір героя.
- Іконки предметів і портрет Ейнштейна вирізані з концептів (тимчасово).
- Шахта, кам'яний броненосець і вхід у метро намальовані кодом (тимчасово).
- `scripts/import-art.py` перевірено: тестовий аркуш на пурпуровому фоні розрізається правильно, герой з'являється на екрані вибору.

---

# Додаток v0.8: нові рухи й предмети в руках

У грі вже працюють біг, лазіння драбиною, меч у руці під час бою, рогатка й факел. Поки ці рухи зібрані з наявних 8 поз, тому виглядають простіше, ніж могли б. Щоб вони стали справжніми, потрібен **розширений аркуш героя 4×4**. Скрипт розпізнає його сам, а гра почне брати пози з нього.

## А. Розширений аркуш героя (по одному на кожного героя)
Розмір **1024×1536** (вертикальний), 4 стовпці × 4 рядки, клітинка 256×384, **прозорий фон**, герой дивиться праворуч, у всіх позах однаковий масштаб і ноги на одній лінії.
Рядки:
1. хода — 4 кадри;
2. **біг** — 4 кадри (довгий крок, корпус нахилений уперед, руки активно працюють);
3. **лізе по драбині** — 4 кадри, вигляд збоку, руки по черзі тягнуться вгору, ноги на щаблях (саму драбину **не** малювати);
4. стоїть з порожніми руками · замах (рука з порожнім кулаком позаду над головою) · удар (рука витягнута вперед-вниз) · стрибок.

**Інструментів у руках не малювати.** Гра сама вкладає в кулак меч, кирку, сокиру, рогатку чи факел.

```
Pixel art character sprite sheet for a 2D side-scrolling survival game, same character and style as the attached sheet.
Layout: 4 columns × 4 rows, 1024×1536 px, each cell 256×384, one full-body pose per cell, same scale, feet on the same baseline, facing right, transparent background.
Row 1: walk cycle, 4 frames. Row 2: run cycle, 4 frames, long stride, body leaning forward, arms pumping.
Row 3: climbing a ladder seen from the side, 4 frames, hands reaching up alternately, feet on rungs — do NOT draw the ladder.
Row 4: idle with empty hands, wind-up with an empty fist raised behind the head, forward strike with the arm extended down-forward, mid-air jump.
No tools or weapons in the hands, no text, no ground, no shadows.
```
Потім надішли файл мені з підписом, наприклад: «розширений аркуш Ейнштейна».

## Б. Зброя та інструменти в руку (один аркуш)
**1024×512**, 4×2 клітинки по 256×256, прозорий фон, кожен предмет **вертикально, робочою частиною вгору**, руків'я внизу по центру клітинки:
меч, кирка, сокира, рогатка, факел, ліхтарик, лопата, гайковий ключ.
```
Pixel art held items for a 2D side-scrolling game, detailed style matching the attached hero sheet. 4 columns × 2 rows, 1024×512, 256 px cells, transparent background.
Each item standing upright with the working end at the top and the grip at the bottom centre of its cell: sword, pickaxe, axe, slingshot, torch, flashlight, shovel, wrench. No text.
```

## В. Вороги з рухом
Зараз у кожного ворога одна поза, а рух малює код. Для живої анімації потрібен аркуш **1536×768**: 4×2 клітинки по 384×384, прозорий фон, ворог дивиться **ліворуч** (як на твоїх картинках).
Рядок 1: хода, 4 кадри. Рядок 2: стоїть, підготовка до кидка (присів), кидок/укус, отримав удар.
Потрібні три таких аркуші: моховий саламандр, кам'яний броненосець і кришталевий олень.

---

# Додаток v0.9: чого бракує (за пріоритетом)

Зараз у грі тимчасово зібрано з наявних кадрів, кодом або старим атласом:
1. **Кадри героя** (для кожного героя): отримав удар (відхил назад), падіння/поразка (лежить), окреме падіння після стрибка, біг ×4, драбина ×4, стоїть з порожніми руками. Зараз поранення = нахил + червоний відтінок, поразка = поворот кадру «стоїть», біг = хода з нахилом. Формат: розширений аркуш 4×4 із розділу А вище, плюс **5-й рядок**: отримав удар · падає · лежить · встає.
2. **Предмети в руку** — аркуш Б вище (меч, кирка, сокира, рогатка, факел...). Зараз меч і рогатка намальовані кодом.
3. **Вороги з рухом** — аркуші В вище для саламандра, броненосця й оленя (зараз одна поза, рух робить код).
4. **Мутант-краулер** (місто/ліс): новий аркуш у форматі В. Зараз використовується старий атлас.
5. **Стани об'єктів** (один аркуш 4×2, 1024×512, прозорий фон, вид збоку): пень зрубаного дерева, вибрана жила руди (порожня скеля), відкритий ящик, очищена ділянка з паростками, камінь для видобутку, кам'яні уламки, двері сховища насіння на поверхні (закриті), упала балка. Зараз пень/руда/ящик — це обрізаний і притемнений цілий спрайт, а камінь, двері й балка — зі старого атласу.
6. **Тесла й Дарвін:** аркуші поз і портрети (промпти в розділах 1–2).
7. **Карикатури політиків:** потрібні імена, щоб підготувати промпти.
