class_name Defs
extends RefCounted
## Static game data: layout, passenger types, upgrades, events, night rules.

const VERSION := "0.5"
const MAX_FLOORS := 13
const START_FLOORS := 5

# --- World layout (building-local pixels; the building is 360 px wide) ---
const BUILDING_W := 360
const FLOOR_H := 52
const SHAFT_X := 8          # left edge of the shaft opening
const SHAFT_W := 96
const CABIN_W := 88
const CABIN_H := 46
const LANDING_X := 112      # where passengers step out of the cabin
const QUEUE_X0 := 138       # first queue spot (closest to the shaft)
const QUEUE_DX := 18
const QUEUE_MAX := 5        # waiting spots per floor
const DOOR_XS := [250, 318] # guest-room doors on every floor
const WALK_SPEED := 46.0    # px/s

# Passenger types. Everything a type does differently is written in its "rule" text,
# so the player always knows why a passenger behaves the way it does.
# patience — seconds before a waiting passenger complains (before difficulty scaling)
# pay      — fare multiplier; seats — cabin places taken; board — seconds to step in/out
# floors   — how many floors must be open for the type to appear (= shift progression)
const TYPES := {
	"guest": {
		"name": "Турист", "rule": "Звичайний гість. Не поспішає.",
		"patience": 30.0, "pay": 1.0, "seats": 1, "board": 0.42, "speed": 1.0,
		"weight": 10.0, "floors": 5, "ride_drain": 0.5,
	},
	"business": {
		"name": "Бізнесмен", "rule": "Поспішає, зате платить щедро.",
		"patience": 17.0, "pay": 1.7, "seats": 1, "board": 0.32, "speed": 1.3,
		"weight": 5.0, "floors": 5, "ride_drain": 0.6,
	},
	"granny": {
		"name": "Бабуся", "rule": "Дуже терпляча, але заходить повільно.",
		"patience": 52.0, "pay": 1.0, "seats": 1, "board": 0.95, "speed": 0.55,
		"weight": 4.0, "floors": 5, "ride_drain": 0.4,
	},
	"kid": {
		"name": "Дитина", "rule": "У кабіні натискає зайву кнопку. Натисни її ще раз, щоб скасувати.",
		"patience": 26.0, "pay": 1.1, "seats": 1, "board": 0.3, "speed": 1.4,
		"weight": 4.0, "floors": 6, "ride_drain": 0.6,
	},
	"cat": {
		"name": "Кіт", "rule": "Не займає місця в кабіні. Нетерплячий.",
		"patience": 19.0, "pay": 0.9, "seats": 0, "board": 0.25, "speed": 1.5,
		"weight": 3.0, "floors": 7, "ride_drain": 0.5,
	},
	"rocker": {
		"name": "Рок-зірка", "rule": "Платить дуже щедро, але гучна музика дратує інших у кабіні.",
		"patience": 24.0, "pay": 2.6, "seats": 1, "board": 0.4, "speed": 1.1,
		"weight": 2.0, "floors": 8, "ride_drain": 0.5,
	},
	"robot": {
		"name": "Робот-кур'єр", "rule": "Хоче їхати без зупинок: ×2 монет без зупинок, менше — за кожну зайву.",
		"patience": 40.0, "pay": 1.0, "seats": 1, "board": 0.3, "speed": 1.0,
		"weight": 2.5, "floors": 9, "ride_drain": 0.3,
	},
	"couple": {
		"name": "Молодята", "rule": "Займають 2 місця, платять як двоє і ще трохи.",
		"patience": 32.0, "pay": 2.3, "seats": 2, "board": 0.55, "speed": 0.9,
		"weight": 2.0, "floors": 10, "ride_drain": 0.45,
	},
	"inspector": {
		"name": "Інспектор", "rule": "Довези вчасно — скасує одну скаргу і дасть ×3. Не встигнеш — дві скарги.",
		"patience": 40.0, "pay": 3.0, "seats": 1, "board": 0.4, "speed": 1.0,
		"weight": 0.0, "floors": 11, "ride_drain": 0.5,
	},
	"bellhop": {
		"name": "Носій з валізами", "rule": "Займає 3 місця, але платить ×3,5.",
		"patience": 34.0, "pay": 3.5, "seats": 3, "board": 0.7, "speed": 0.8,
		"weight": 1.5, "floors": 12, "ride_drain": 0.45,
	},
	"ghost": {
		"name": "Привид", "rule": "Їздить лише на 13-й і з нього. Не займає місця. Не скаржиться — просто зникає.",
		"patience": 44.0, "pay": 1.9, "seats": 0, "board": 0.3, "speed": 0.8,
		"weight": 3.0, "floors": 13, "ride_drain": 0.4,
	},
}
# Sprite-sheet row of every type (assets/sprites/passengers.png)
const TYPE_ORDER := ["guest", "business", "granny", "kid", "cat", "rocker", "robot", "couple", "inspector", "bellhop", "ghost"]

# Floors and their themes (index 1..13)
const FLOOR_NAMES := ["", "Хол", "Ресторан", "Номери", "Басейн", "Бібліотека", "Спортзал",
	"Оранжерея", "Диско", "Спа", "Казино", "Обсерваторія", "Пентхаус", "???"]

# Upgrades: values per level (level 0 = start). cost[i] = price of going from level i to i+1.
const UPGRADES := {
	"motor": {"name": "Мотор", "desc": "Ліфт їздить швидше",
		"values": [1.5, 1.85, 2.2, 2.55, 2.9, 3.3], "fmt": "%.1f пов/с",
		"cost": [80, 160, 300, 520, 850]},
	"cabin": {"name": "Кабіна", "desc": "Більше місць для гостей",
		"values": [3, 4, 5, 6, 7], "fmt": "%d місць",
		"cost": [120, 260, 480, 800]},
	"doors": {"name": "Двері", "desc": "Двері й посадка швидші",
		"values": [1.0, 0.85, 0.72, 0.6, 0.5], "fmt": "×%.2f час",
		"cost": [90, 190, 360, 620]},
	"coffee": {"name": "Кава в холах", "desc": "Гості чекають довше",
		"values": [1.0, 1.12, 1.24, 1.36, 1.48], "fmt": "×%.2f терпіння",
		"cost": [110, 230, 430, 720]},
	"jazz": {"name": "Джаз у кабіні", "desc": "У кабіні гості спокійніші",
		"values": [1.0, 0.82, 0.66, 0.52], "fmt": "×%.2f роздратування",
		"cost": [100, 240, 480]},
	"tips": {"name": "Нова уніформа", "desc": "Більше чайових",
		"values": [1.0, 1.15, 1.3, 1.45, 1.6, 1.8], "fmt": "×%.2f чайових",
		"cost": [100, 200, 380, 640, 1000]},
	"hearts": {"name": "Книга скарг", "desc": "Більше скарг до кінця зміни",
		"values": [3, 4, 5], "fmt": "%d скарг",
		"cost": [400, 1100]},
}
const UPGRADE_ORDER := ["motor", "cabin", "doors", "coffee", "jazz", "tips", "hearts"]

# Random events during a shift. Each one is announced with a banner and its own icon;
# none of them can make a passenger impossible to deliver.
const EVENTS := {
	"jazz": {"name": "Джазова пауза", "desc": "Усі гості терплять удвічі довше", "dur": 16.0, "weight": 3.0, "shift": 2, "good": true},
	"rich": {"name": "Щедра ніч", "desc": "Усі монети ×2", "dur": 14.0, "weight": 3.0, "shift": 2, "good": true},
	"party": {"name": "Вечірка", "desc": "Гості їдуть на %d-й: +50%% монет", "dur": 18.0, "weight": 3.0, "shift": 2, "good": true},
	"turbo": {"name": "Турбо-мотор", "desc": "Ліфт на 50% швидший", "dur": 14.0, "weight": 2.5, "shift": 2, "good": true},
	"coins": {"name": "Розсипані монети", "desc": "Зупинись на %d-му й забери монети", "dur": 22.0, "weight": 2.5, "shift": 2, "good": true},
	"drill": {"name": "Навчальна тривога", "desc": "Нові гості їдуть у хол (1-й поверх)", "dur": 15.0, "weight": 2.0, "shift": 3, "good": false},
	"sticky": {"name": "Липкі двері", "desc": "Двері відчиняються повільніше", "dur": 12.0, "weight": 2.0, "shift": 3, "good": false},
	"blackout": {"name": "Аварійне світло", "desc": "Темно, ліфт на 25% повільніший", "dur": 12.0, "weight": 1.5, "shift": 4, "good": false},
	"prank": {"name": "Привид-жартівник", "desc": "Натиснув %d. Скасуй, якщо треба", "dur": 4.0, "weight": 2.0, "shift": 3, "good": false},
	"lostcat": {"name": "Загубився кіт", "desc": "Кіт із золотою табличкою: ×3", "dur": 6.0, "weight": 2.0, "shift": 7, "good": true},
	"inspector": {"name": "Інспектор у готелі", "desc": "Довези інспектора вчасно!", "dur": 6.0, "weight": 2.5, "shift": 11, "good": false},
}

# One rule per night (from shift 3 on). Shown on the card before the shift.
const RULES := {
	"none": {"name": "Звичайна ніч", "desc": "Жодних особливих правил."},
	"vip": {"name": "VIP-ніч", "desc": "Бізнесменів утричі більше, їхні монети +30%."},
	"grannies": {"name": "Ніч бабусь", "desc": "Бабусь учетверо більше. Усі гості на 15% терплячіші."},
	"repair": {"name": "Ремонт", "desc": "%d-й поверх зачинено: туди ніхто не їде."},
	"express": {"name": "Експрес", "desc": "+5 монет за кожного, кого довіз без проміжних зупинок."},
	"festival": {"name": "Свято", "desc": "Гостей на 30% більше, монети +30%."},
	"quiet": {"name": "Тиха ніч", "desc": "Без випадкових подій. Гостей трохи менше."},
	"oldmotor": {"name": "Старий мотор", "desc": "Ліфт на 20% повільніший, монети +35%."},
	"school": {"name": "Шкільна екскурсія", "desc": "Дітей учетверо більше."},
	"moon": {"name": "Повня", "desc": "Привиди виходять на всі поверхи (не лише на 13-й)."},
}


static func floors_for_shift(shift: int) -> int:
	return clampi(START_FLOORS + shift - 1, START_FLOORS, MAX_FLOORS)


static func shift_duration(shift: int) -> float:
	return 90.0 + 6.0 * float(mini(shift - 1, 10))


static func type_unlocked(type_id: String, floors: int) -> bool:
	return int(TYPES[type_id]["floors"]) <= floors


static func types_new_at(floors: int) -> Array:
	var out := []
	for t in TYPE_ORDER:
		if int(TYPES[t]["floors"]) == floors:
			out.append(t)
	return out


static func upgrade_value(id: String, level: int):
	var v: Array = UPGRADES[id]["values"]
	return v[clampi(level, 0, v.size() - 1)]


static func upgrade_max(id: String) -> int:
	return (UPGRADES[id]["values"] as Array).size() - 1


static func upgrade_cost(id: String, level: int) -> int:
	var c: Array = UPGRADES[id]["cost"]
	if level >= c.size():
		return -1
	return int(c[level])


static func clock_text(frac: float) -> String:
	# The night runs from 22:00 to 06:00.
	var minutes := int(clampf(frac, 0.0, 1.0) * 480.0) + 22 * 60
	var h := (minutes / 60) % 24
	var m := minutes % 60
	return "%02d:%02d" % [h, m]


# Cabin decorations: cosmetic only, a long-term use for coins.
const SKINS := {
	"classic": {"name": "Класика", "cost": 0, "floors": 0, "gate": ["d8a040", "8a5a22", "ffe08a"]},
	"neon": {"name": "Неон", "cost": 1500, "floors": 0, "gate": ["ff6ad5", "6a1a8a", "6af0ff"]},
	"mint": {"name": "Ретро-м'ята", "cost": 2500, "floors": 0, "gate": ["c8d4e0", "6a7888", "ffffff"]},
	"gold": {"name": "Золото", "cost": 4000, "floors": 0, "gate": ["f2c14e", "a87a1a", "fff0a0"]},
	"haunted": {"name": "Привидна", "cost": 6000, "floors": 13, "gate": ["a8b8a8", "3a4a42", "d8f0d8"]},
}
const SKIN_ORDER := ["classic", "neon", "mint", "gold", "haunted"]

# What passengers say (short, shown in a speech bubble). Keys: hello, thanks, angry.
const LINES := {
	"guest": {"hello": ["Який готель!", "Де тут басейн?", "Я у відпустці!"], "thanks": ["Дякую!", "Супер ліфт!"], "angry": ["Жахливий сервіс!"]},
	"business": {"hello": ["Час — гроші!", "Швидше, прошу!", "У мене нарада!"], "thanks": ["Тримай чайові", "Вчасно!"], "angry": ["Я спізнююсь!", "Пишу скаргу!"]},
	"granny": {"hello": ["Добрий вечір, синку", "Не поспішай...", "Ох, ці ліфти..."], "thanks": ["Ось тобі цукерка", "Дай Боже здоров'я"], "angry": ["Не діждуся..."]},
	"kid": {"hello": ["А можна кнопку?", "Ліфт! Ура!"], "thanks": ["Ще раз!"], "angry": ["Мамо-о-о!"], "press": ["Хі-хі!", "Я натиснув!", "Ой..."]},
	"cat": {"hello": ["Мяу?", "Мррр"], "thanks": ["Мур-мур"], "angry": ["Ш-ш-ш!"]},
	"rocker": {"hello": ["Йе-е-е!", "Рок-н-рол!"], "thanks": ["Ти рок-зірка!"], "angry": ["Скасовую тур!"]},
	"robot": {"hello": ["БІП. ДОСТАВКА.", "МАРШРУТ ЗАДАНО"], "thanks": ["ДОСТАВЛЕНО"], "angry": ["ПОМИЛКА 404"]},
	"couple": {"hello": ["Ми одружилися!", "Медовий місяць!"], "thanks": ["Ти найкращий!"], "angry": ["Зіпсував свято!"]},
	"inspector": {"hello": ["Хм... перевірка", "Записую..."], "thanks": ["Задовільно."], "angry": ["Неприпустимо!"]},
	"bellhop": {"hello": ["Обережно, валізи!", "Багаж прибув!"], "thanks": ["Дякую, колего"], "angry": ["Валізи важкі!"]},
	"ghost": {"hello": ["Бу-у-у...", "У-у-у..."], "thanks": ["Дякую-у-у"], "angry": ["БУ!"]},
}


static func line(type_id: String, key: String) -> String:
	var l: Dictionary = LINES.get(type_id, {})
	var a: Array = l.get(key, [])
	if a.is_empty():
		return ""
	return String(a[randi() % a.size()])


# Achievements: [id, name, description, record key, goal, coin reward]
const ACHIEVEMENTS := [
	["first", "Перша зміна", "Заверши першу нічну зміну", "best_shift", 1, 50],
	["veteran", "Нічний ветеран", "Заверши 5 змін", "best_shift", 5, 150],
	["floor13", "Тринадцятий", "Відкрий 13-й поверх", "best_shift", 8, 300],
	["iron", "Залізні нерви", "Заверши 15-ту зміну", "best_shift", 15, 1000],
	["guests100", "Сотня гостей", "Довези 100 гостей", "total_delivered", 100, 100],
	["guests1000", "Тисяча гостей", "Довези 1000 гостей", "total_delivered", 1000, 500],
	["streak15", "У ритмі", "Серія з 15 доставок", "best_streak", 15, 150],
	["streak40", "Ліфт-віртуоз", "Серія з 40 доставок", "best_streak", 40, 400],
	["perfect", "Бездоганно", "3 зміни без жодної скарги", "perfect_shifts", 3, 200],
	["ghosts", "Друг привидів", "Довези 25 привидів", "ghosts", 25, 300],
	["robots", "Пунктуальність", "Довези 10 роботів без зупинок", "robots_direct", 10, 200],
	["inspect", "Перевірку пройдено", "Вчасно довези 5 інспекторів", "inspectors", 5, 300],
	["treasure", "Скарбошукач", "Збери 10 розсипаних куп монет", "pickups", 10, 150],
	["style", "Стиляга", "Маєш 3 оздоблення кабіни", "skins_owned", 3, 200],
]


# Night tasks: one optional goal per shift with a coin reward.
const TASK_TEXT := {
	"deliver": "Довези %d гостей",
	"streak": "Зроби серію з %d доставок",
	"type": "Довези: %s ×%d",
	"clean": "Без скарг (і хоча б 8 гостей)",
	"coins": "Зароби %d монет за зміну",
	"express": "%d доставок без проміжних зупинок",
}


static func make_task(shift: int, floors: int, rng: RandomNumberGenerator) -> Dictionary:
	var kinds := ["deliver", "streak", "coins", "type", "express"]
	if shift >= 2:
		kinds.append("clean")
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var goal := 0
	var type_id := ""
	match kind:
		"deliver":
			goal = mini(12 + 3 * (shift - 1), 45)
		"streak":
			goal = mini(5 + shift, 20)
		"coins":
			goal = mini(100 + 60 * (shift - 1), 1100)
		"express":
			goal = mini(4 + shift / 2, 12)
		"clean":
			goal = 1
		"type":
			var pool := []
			for t in TYPE_ORDER:
				if t != "guest" and float(TYPES[t]["weight"]) > 0.0 and type_unlocked(t, floors):
					pool.append(t)
			type_id = pool[rng.randi_range(0, pool.size() - 1)]
			goal = 4 if ["business", "granny", "kid", "cat"].has(type_id) else 2
	var text := String(TASK_TEXT[kind])
	if kind == "type":
		text = text % [String(TYPES[type_id]["name"]), goal]
	elif kind != "clean":
		text = text % goal
	return {"kind": kind, "goal": goal, "type": type_id, "progress": 0, "done": false,
		"reward": 40 + 15 * shift, "text": text}
