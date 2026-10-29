# Afterfall: завдання для ChatGPT (художник гри)

---

## Частина 1. Для тебе: як цим користуватися

1. **Відкрий новий чат** у ChatGPT.
2. **Прикріпи файли:**
   - цей файл;
   - 2–3 референси стилю з папки `art/generated/` (див. список нижче).
3. **Перше повідомлення:**
   > Прочитай файл. Ти художник гри Afterfall. Дотримуйся всіх правил із Частини 2. Зроби **Завдання 1**.
4. **Одне завдання — одне повідомлення — одна картинка.** Не проси кілька аркушів разом, бо тоді GPT плутає пози.
5. **Перевір результат** за чек-листом (Частина 4). Якщо щось не так, скопіюй готову фразу виправлення звідти.
6. **Надішли картинку мені** з підписом, наприклад: «Завдання 1, Ейнштейн». Я наріжу її й підключу в гру.
7. **Наступне завдання** — у тому ж чаті: «Зроби Завдання 2». Так GPT пам'ятає стиль і героя.

**Які референси прикріпляти:**

| Завдання | Файли з `art/generated/` |
|---|---|
| Герой (завдання 1–2, 7) | `einstein-sheet-v2.png` або `curie-sheet.png` |
| Вороги (5–6) | `enemy-armadillo.png`, `enemy-salamander.png`, `enemy-deer.png` |
| Предмети й об'єкти (3–4) | `prop-stump.png`, `prop-crate.png`, `prop-ore.png` |
| Загальний стиль | `../concepts-v06/mine.png` |

---

## Частина 2. Для ChatGPT: про гру і правила

### Що за гра
**Afterfall** — 2D піксельна гра на виживання з видом збоку для телефона й комп'ютера, у дусі Terraria.

- **Світ:** після катастрофи місто заросло, ліс заражений мутантами.
- **Мета гравця:** відновлювати природу.
- **Ігровий цикл:**
  - збирати дерево, камінь і руду;
  - крафтити обладнання (фільтр води, генератор, очищувач ґрунту);
  - садити теплицю;
  - очищати ліс;
  - спускатися в шахту та сховище насіння.
- **Герої:** знамениті вчені в дружньому стилізованому вигляді (Ейнштейн, Марія Кюрі, Тесла, Дарвін).

Твої картинки йдуть прямо в гру: скрипт автоматично ріже їх на кадри. Тому **технічні правила важливіші за красу**.

### Стиль (обов'язково)
- **Піксель-арт:**
  - детальний, як у Terraria або Owlboy, у тому ж стилі, що й прикріплені референси;
  - чіткі пікселі, без розмиття й градієнтного «аерографа»;
  - теплий темний контур, світло зверху ліворуч;
  - палітра приглушена (мох, іржа, бурштин), без неону, крім кристалів і грибів.
- **Ракурс:** вид строго збоку (профіль), як у 2D-платформері. Не 3/4 і не ізометрія.

### Технічні правила (обов'язково, кожна картинка)
1. **Фон:**
   - **прозорий**;
   - якщо прозорий не виходить — **суцільний пурпуровий #FF00FF** без жодних відтінків і градієнтів.
2. **На зображенні нічого зайвого:**
   - підлога, земля, тінь під ногами, рамки, сітка;
   - номери кадрів, підписи, текст, водяні знаки.
3. **Сітка:**
   - рівна, усі клітинки однакового розміру;
   - **одна фігура чи предмет на клітинку**, по центру;
   - фігури не торкаються країв клітинки й одна одної, відступ щонайменше 5 % клітинки.
4. **Однаковість у всіх клітинках аркуша:**
   - **той самий масштаб**: однаковий зріст, голова того ж розміру;
   - **ноги на одній горизонтальній лінії** (крім поз «лежить» і «стрибок»);
   - **той самий персонаж**: обличчя, одяг, кольори, рюкзак ідентичні в усіх кадрах.
5. **Напрямок погляду:**
   - **герої дивляться праворуч**;
   - **вороги дивляться ліворуч**, як на референсах.
6. **Розмір картинки:**
   - горизонтальний аркуш — 1536×1024 (3:2);
   - вертикальний — 1024×1536 (2:3);
   - портрет — 1024×1024.
   Точні пікселі не критичні, головне — рівна сітка.

---

## Частина 3. Завдання (за пріоритетом)

Опис героя для підстановки замість `{HERO}`:
- **Ейнштейн:** `Albert Einstein as a friendly stylised elderly scientist explorer: wild white hair, white moustache, brown tweed jacket, teal scarf, grey trousers, brown boots, big worn leather backpack with tools`
- **Кюрі:** `Marie Skłodowska-Curie as a friendly stylised scientist explorer: dark long skirt, high-collar blouse, lab coat, hair in a bun, small round brass goggles on her forehead, leather backpack`
- **Тесла:** `Nikola Tesla as a friendly stylised inventor explorer: slim, centre-parted dark hair, moustache, dark three-piece suit with rolled sleeves, small copper coil device on his belt, leather backpack`
- **Дарвін:** `Charles Darwin as a friendly stylised naturalist explorer: older, big white beard, bald top, tweed coat, field notebook and a butterfly net strapped to the leather backpack`

---

### Завдання 1. Ейнштейн: розширений аркуш рухів
**Навіщо:** зараз біг і лазіння по драбині зібрані з кадрів ходи, а інструмент завжди в руці.

- **Формат:** вертикальний 1024×1536, сітка **4 стовпці × 4 рядки**.
- **Рядки:**
  1. хода, 4 кадри;
  2. біг, 4 кадри: довгий крок, корпус нахилений уперед, руки активно працюють;
  3. лізе по драбині, 4 кадри, вид збоку, руки по черзі тягнуться вгору. **Драбину не малювати.**
  4. стоїть з порожніми руками · замах (порожній кулак позаду над головою) · удар (рука витягнута вперед-вниз) · стрибок.
- **У руках нічого немає**: гра сама вкладає меч, кирку, факел.

```
Pixel art character sprite sheet for a 2D side-scrolling survival game, same character and style as the attached sheet.
Character: {HERO}.
Layout: portrait image 1024x1536, exactly 4 columns x 4 rows of equal cells, one full-body pose per cell, centred, same scale in every cell, feet on the same baseline, character facing right, strict side view.
Row 1: walk cycle, 4 frames.
Row 2: run cycle, 4 frames, long stride, body leaning forward, arms pumping.
Row 3: climbing a ladder seen from the side, 4 frames, hands reaching up alternately, knees raised — do NOT draw the ladder.
Row 4: idle with empty hands; wind-up with an empty fist raised behind the head; forward strike with the arm extended down-forward; mid-air jump.
Hands are EMPTY in every frame, no tools, no weapons.
Transparent background (or flat solid magenta #FF00FF). No ground, no shadows, no text, no numbers, no grid lines, no frames.
```

---

### Завдання 2. Ейнштейн: поранення, падіння, стрибок
**Навіщо:** зараз поранення — це просто нахил із червоним відтінком, а поразка — повернутий кадр «стоїть».

- **Формат:** горизонтальний 1536×1024, сітка **4 × 2**.
- **Рядок 1:**
  - отримав удар: відкинутий назад, гримаса болю;
  - падає назад;
  - лежить на спині на землі (поразка);
  - встає на одне коліно.
- **Рядок 2:**
  - присів перед стрибком;
  - летить угору;
  - падає вниз, руки догори;
  - приземлився, присів.
- **У руках нічого немає.**

```
Pixel art character sprite sheet for a 2D side-scrolling survival game, same character and style as the attached sheet.
Character: {HERO}.
Layout: landscape image 1536x1024, exactly 4 columns x 2 rows of equal cells, one full-body pose per cell, centred, same scale in every cell, facing right, strict side view.
Row 1: hit reaction knocked backwards with a pained face; falling backwards; lying on his back defeated (lying flat, horizontal); getting up on one knee.
Row 2: crouch before a jump; rising in a jump; falling down with arms up; landing crouch.
Hands are EMPTY, no tools, no weapons.
Transparent background (or flat solid magenta #FF00FF). No ground, no shadows, no text, no numbers, no grid lines.
```

---

### Завдання 3. Предмети в руку героя
**Навіщо:** зараз меч і рогатку малює код, вони виглядають простими.

- **Формат:** горизонтальний 1536×1024, сітка **4 × 2**.
- **Порядок:** меч, кирка, сокира, рогатка, факел (горить), ліхтарик, лопата, гайковий ключ.
- **Положення:** кожен предмет **вертикально**, робоча частина вгорі, руків'я внизу по центру клітинки.
- **Масштаб:** як у руці героя з референсу (меч приблизно на півзросту героя).

```
Pixel art held items for a 2D side-scrolling survival game, detailed style matching the attached hero sheet.
Layout: landscape image 1536x1024, exactly 4 columns x 2 rows of equal cells.
Each item stands upright, working end at the top, grip at the bottom centre of its cell, all at a consistent in-hand scale:
sword, pickaxe, axe, slingshot, burning torch, flashlight, shovel, wrench.
Worn, post-apocalyptic, hand-made look. Transparent background (or flat solid magenta #FF00FF). No hands, no text, no shadows, no grid lines.
```

---

### Завдання 4. Стани об'єктів
**Навіщо:** після рубки, видобутку чи відкриття об'єкти мають виглядати інакше. Зараз це просто обрізаний і притемнений спрайт.

- **Формат:** горизонтальний 1536×1024, сітка **4 × 2**.
- **Ракурс:** вид збоку; низ кожного об'єкта стоїть на уявній землі.
- **Порядок клітинок:**
  1. **зрубаний пень:** низький, свіжий світлий зріз, тріски поруч (пара до `prop-stump.png`);
  2. **вибрана рудна жила:** сіра скеля з порожніми вибоїнами, **без** помаранчевої руди (пара до `prop-ore.png`);
  3. **відкритий ящик припасів:** кришка відкинута, всередині порожньо (пара до `prop-crate.png`);
  4. **очищена ділянка землі:** темний пухкий ґрунт, молоді зелені паростки, квіточка;
  5. **кам'яна брила для видобутку:** сіра, з тріщинами;
  6. **купка кам'яних уламків** після видобутку;
  7. **двері сховища насіння на поверхні:** важкі сталеві двері в бетонній стіні, закриті, моховиті;
  8. **упала сталева балка** з мохом, лежить горизонтально.

```
Pixel art game props for a 2D side-scrolling post-apocalyptic survival game, strict side view, detailed style matching the attached props.
Layout: landscape image 1536x1024, exactly 4 columns x 2 rows of equal cells, one object per cell, the bottom of each object resting on an invisible ground line.
In order: freshly chopped low tree stump with a pale cut top and wood chips; depleted ore rock — grey rock with empty pits and no orange ore;
opened empty wooden supply crate with the lid thrown back; cleaned soil patch — dark loose soil with young green sprouts and a small flower;
grey cracked stone boulder for mining; small pile of stone rubble; heavy closed steel seed-vault door set in a mossy concrete wall; fallen mossy steel girder lying horizontally.
Transparent background (or flat solid magenta #FF00FF). No shadows, no text, no grid lines.
```

---

### Завдання 5. Новий мутант-краулер
**Навіщо:** це найчастіший ворог (ліс, шахта, напади на теплицю), а графіка в нього стара.

- **Формат:** горизонтальний 1536×1024, сітка **4 × 2**, **дивиться ліворуч**.
- **Рядок 1:** хода, 4 кадри.
- **Рядок 2:**
  - стоїть;
  - присів перед кидком;
  - кидок і укус;
  - отримав удар.

```
Pixel art enemy sprite sheet for a 2D side-scrolling survival game, strict side view, detailed style matching the attached enemies.
Creature: a dog-sized mutant crawler — hunched, crawling on four long thin limbs, grey-green leathery skin with patches of moss and small glowing fungus, glowing amber eyes, sharp jaws.
Facing LEFT. Layout: landscape image 1536x1024, exactly 4 columns x 2 rows of equal cells, one pose per cell, same scale, feet on the same baseline.
Row 1: walk cycle, 4 frames. Row 2: idle; crouch preparing to pounce; pounce bite lunging forward; hit reaction recoiling.
Transparent background (or flat solid magenta #FF00FF). No ground, no shadows, no text, no grid lines.
```

---

### Завдання 6. Вороги з рухом (3 окремі картинки)
**Навіщо:** у кожного ворога зараз одна поза, а ходу «малює» код. Робиться три окремі аркуші, по одному на ворога.

- **Формат:** такий самий, як у Завданні 5 (1536×1024, 4 × 2, **дивиться ліворуч**).
- **Референс:** прикріпи картинку цього ворога.
- **Вороги:**
  - **6а. Моховий саламандр** (`enemy-salamander.png`): ряд 2 — стоїть · присів · укус · отримав удар.
  - **6б. Кам'яний броненосець** (`enemy-armadillo.png`): ряд 2 — стоїть · згорнувся в клубок · кидок клубком · отримав удар.
  - **6в. Кришталевий олень, бос** (`enemy-deer.png`): ряд 2 — стоїть · замах рогами (голова опущена) · ривок уперед · оглушений, похитується.

```
Pixel art enemy sprite sheet, same creature and style as the attached image, strict side view, facing LEFT.
Layout: landscape image 1536x1024, exactly 4 columns x 2 rows of equal cells, one pose per cell, same scale in every cell, feet on the same baseline.
Row 1: walk cycle, 4 frames. Row 2: {ROW2}.
Transparent background (or flat solid magenta #FF00FF). No ground, no shadows, no text, no grid lines.
```

**Що підставити замість `{ROW2}`:**
- **Саламандр:** `idle; crouch before attacking; bite lunging forward; hit reaction recoiling`
- **Броненосець:** `idle; curling into a ball; rolling ball attack; hit reaction recoiling`
- **Олень:** `idle; antler wind-up with head lowered; charging forward; stunned and staggering`

---

### Завдання 7. Марія Кюрі
Повтори **Завдання 1 і 2** з `{HERO}` = Кюрі, референс `curie-sheet.png`.

---

### Завдання 8. Тесла і Дарвін
Для кожного героя:

- **8а. Основний аркуш:** горизонтальний 1536×1024, **4 × 2**. Порядок: хода ×4 · стоїть з киркою · замах киркою над головою · удар киркою вперед · стрибок. Після нього зроби Завдання 1 і 2 для цього героя.

```
Pixel art character sprite sheet for a 2D side-scrolling survival game, detailed style matching the attached sheet.
Character: {HERO}.
Layout: landscape image 1536x1024, exactly 4 columns x 2 rows of equal cells, one full-body pose per cell, centred, same scale, feet on the same baseline, facing right, strict side view.
Poses in order: walk 1, walk 2, walk 3, walk 4, idle holding a pickaxe, overhead pickaxe wind-up, forward pickaxe strike, mid-air jump.
Transparent background (or flat solid magenta #FF00FF). No ground, no shadows, no text, no grid lines.
```

- **8б. Портрет:** квадратний 1024×1024.

```
Pixel art head-and-shoulders portrait of {HERO}, 3/4 view facing right, detailed style matching the attached portrait,
square 1024x1024, plain dark slate background #1a242c, no frame, no text.
```

---

### Завдання 9. Карикатури політиків (пізніше)
Спочатку власник гри має назвати конкретних людей.

- **Тон:** дружній шарж, без образливих деталей.
- **Якщо генератор відмовляється малювати реальну людину:** опиши її образ без імені (зачіска, одяг, характерні риси).

---

## Частина 4. Чек-лист перед відправкою (перевіряєш ти)

- [ ] Фон прозорий або рівно пурпуровий, без підлоги й тіні.
- [ ] Сітка правильна (4×4 або 4×2), у кожній клітинці рівно одна фігура.
- [ ] Порядок поз саме такий, як у завданні.
- [ ] Персонаж однаковий у всіх кадрах: обличчя, одяг, кольори.
- [ ] Зріст і масштаб однакові, ноги на одній лінії.
- [ ] Герой дивиться праворуч, ворог ліворуч.
- [ ] Немає тексту, цифр і рамок.
- [ ] Нічого не обрізано краєм клітинки (кирка, роги, хвіст).

### Готові фрази для виправлення (копіюй у ChatGPT)

| Що не так | Фраза |
|---|---|
| Різний розмір у клітинках | `Redo it: every pose must be exactly the same scale and height, feet on one baseline.` |
| Персонаж змінюється | `Redo it: the character must look identical in every frame — same face, clothes, colours and backpack as the attached sheet.` |
| Є підлога, тінь або текст | `Redo it without any ground, shadows, text, numbers or grid lines. Transparent background.` |
| Не той бік | `Mirror it: heroes face RIGHT, enemies face LEFT.` |
| Обрізано краєм | `Redo it with more padding — nothing may touch or cross the cell borders.` |
| Не та кількість кадрів | `Redo it: exactly 4 columns x 2 rows, one pose per cell, in the order I listed.` |
| Ракурс 3/4 | `Redo it in a strict side view (profile), like a 2D platformer.` |
