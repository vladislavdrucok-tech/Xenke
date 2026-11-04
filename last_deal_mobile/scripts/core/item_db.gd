class_name ItemDB
extends RefCounted
## Каталог товарів. Базова вартість — ціна предмета в доброму стані без дефектів
## при нормальному попиті (1.0). Відносні ціни підібрано під «реальні» пропорції.

const ITEMS := {
	"phone": {"name": "Смартфон", "base": 180, "cat": "tech", "volatility": 0.10,
		"defects": ["cracked_screen", "weak_battery", "scratches", "locked"],
		"lore": ["Старий, але ще бадьорий.", "Тримав у чохлі, клянуся.", "Знайшов у таксі. Власник не дзвонив."]},
	"laptop": {"name": "Старий ноутбук", "base": 260, "cat": "tech", "volatility": 0.08,
		"defects": ["weak_battery", "dead_pixels", "scratches", "no_power", "worn_keys"],
		"lore": ["На ньому ще курсову писали.", "Працює, якщо не відкривати сто вкладок.", "Колись належав хакеру. Мабуть."]},
	"camera": {"name": "Фотоапарат", "base": 220, "cat": "tech", "volatility": 0.10,
		"defects": ["lens_scratch", "scratches", "no_power", "fungus"],
		"lore": ["Фотографував неон усю юність.", "Плівкову епоху пережив.", "Об'єктив рідний."]},
	"console": {"name": "Ігрова консоль", "base": 240, "cat": "fun", "volatility": 0.15,
		"defects": ["stick_drift", "scratches", "no_power", "overheat"],
		"lore": ["Діти виросли, грати нікому.", "У комплекті три збережені світи.", "Пройшов на ній усе."]},
	"watch": {"name": "Золотий годинник", "base": 600, "cat": "luxury", "volatility": 0.06,
		"defects": ["fake", "scratches", "broken_clasp"],
		"lore": ["Спадок від діда.", "Справжнє золото, не сумнівайтесь.", "Виграв у карти на сьомому рівні."]},
	"headphones": {"name": "Навушники", "base": 70, "cat": "fun", "volatility": 0.12,
		"defects": ["one_side", "worn_pads", "scratches"],
		"lore": ["Басу — як на концерті.", "Шумоподавлення від сусідів-дронів.", "Майже не носив."]},
	"radio": {"name": "Ретрорадіо", "base": 95, "cat": "retro", "volatility": 0.18,
		"defects": ["no_power", "scratches", "noise"],
		"lore": ["Ловить станції, яких уже не існує.", "Бабусине. Пахне чаєм.", "Справжня лампова теплота."]},
	"drone": {"name": "Дрон", "base": 300, "cat": "tech", "volatility": 0.20,
		"defects": ["broken_rotor", "weak_battery", "scratches", "locked"],
		"lore": ["Літав над дахами Нижнього міста.", "Ні разу не падав. Майже.", "Кур'єрська модель, списана."]},
	"cpu": {"name": "Рідкісний процесор", "base": 420, "cat": "tech", "volatility": 0.25,
		"defects": ["bent_pins", "overheat", "fake"],
		"lore": ["Інженерний зразок, таких мало.", "Розганяється до небес.", "Витягнув зі старого сервера."]},
	"player": {"name": "Музичний плеєр", "base": 60, "cat": "retro", "volatility": 0.15,
		"defects": ["weak_battery", "scratches", "noise"],
		"lore": ["Тисяча пісень у кишені.", "Колекційна біла версія.", "Колесо прокрутки ще клацає."]},
	"arm": {"name": "Роботизована рука", "base": 520, "cat": "cyber", "volatility": 0.12,
		"defects": ["servo_fail", "overheat", "scratches", "locked"],
		"lore": ["Протез першого покоління.", "Знята з заводського маніпулятора.", "Стискає з силою преса."]},
	"coin": {"name": "Старовинна монета", "base": 150, "cat": "luxury", "volatility": 0.10,
		"defects": ["fake", "scratches", "cleaned"],
		"lore": ["Викопав на будмайданчику.", "З колекції покійного дядька.", "Кажуть, їй триста років."]},
	"mask": {"name": "Електронна маска", "base": 160, "cat": "cyber", "volatility": 0.22,
		"defects": ["dead_led", "scratches", "no_power"],
		"lore": ["З нічного клубу «Синій шум».", "Міняє вираз обличчя від музики.", "Ховає від камер. Нібито."]},
	"projector": {"name": "Портативний проєктор", "base": 130, "cat": "tech", "volatility": 0.10,
		"defects": ["dead_pixels", "noise", "scratches", "no_power"],
		"lore": ["Кіно на стіні будь-якого сховку.", "Яскравий навіть у неоні.", "Брав у відрядження."]},
	"mystery": {"name": "Загадковий пристрій", "base": 350, "cat": "mystery", "volatility": 0.30,
		"defects": ["no_power", "scratches"],
		"lore": ["Не знаю, що це. Але воно гуде.", "Знайшов у підвалі старої лабораторії.", "Світиться вночі. Іноді шепоче."]},
}

## Дефект: назва та множник вартості.
const DEFECTS := {
	"cracked_screen": {"name": "Тріснутий екран", "mult": 0.55},
	"weak_battery": {"name": "Слабкий акумулятор", "mult": 0.80},
	"scratches": {"name": "Подряпини", "mult": 0.90},
	"locked": {"name": "Заблокований паролем", "mult": 0.45},
	"dead_pixels": {"name": "Биті пікселі", "mult": 0.75},
	"no_power": {"name": "Не вмикається", "mult": 0.30},
	"worn_keys": {"name": "Стерті клавіші", "mult": 0.88},
	"lens_scratch": {"name": "Подряпаний об'єктив", "mult": 0.60},
	"fungus": {"name": "Пліснява в лінзі", "mult": 0.50},
	"stick_drift": {"name": "Дрейф стіків", "mult": 0.75},
	"overheat": {"name": "Перегрівається", "mult": 0.65},
	"fake": {"name": "Підробка!", "mult": 0.12},
	"broken_clasp": {"name": "Зламана застібка", "mult": 0.85},
	"one_side": {"name": "Грає лише один бік", "mult": 0.45},
	"worn_pads": {"name": "Зношені амбушури", "mult": 0.85},
	"noise": {"name": "Шумить і тріщить", "mult": 0.75},
	"broken_rotor": {"name": "Зламаний гвинт", "mult": 0.60},
	"bent_pins": {"name": "Погнуті контакти", "mult": 0.50},
	"servo_fail": {"name": "Несправний сервопривід", "mult": 0.55},
	"cleaned": {"name": "Почищена абразивом", "mult": 0.60},
	"dead_led": {"name": "Згорілі світлодіоди", "mult": 0.65},
}

const CATEGORY_NAMES := {
	"tech": "Техніка", "fun": "Розваги", "luxury": "Розкіш", "retro": "Ретро",
	"cyber": "Кібер", "mystery": "Невідоме",
}

## Рівні стану (поріг -> назва). Стан — число 0..1.
const CONDITION_LEVELS := [
	[0.88, "Як новий"],
	[0.68, "Добрий"],
	[0.42, "Вживаний"],
	[0.0, "Зношений"],
]


static func ids() -> Array:
	var a := ITEMS.keys()
	a.sort()
	return a


static func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


static func defect_name(id: String) -> String:
	return DEFECTS.get(id, {}).get("name", id)


static func defect_mult(id: String) -> float:
	return float(DEFECTS.get(id, {}).get("mult", 1.0))


static func condition_label(c: float) -> String:
	for lv in CONDITION_LEVELS:
		if c >= lv[0]:
			return lv[1]
	return CONDITION_LEVELS[-1][1]


static func condition_level_index(c: float) -> int:
	for i in CONDITION_LEVELS.size():
		if c >= CONDITION_LEVELS[i][0]:
			return i
	return CONDITION_LEVELS.size() - 1


## Множник від стану: 0.35 для повністю зношеного, 1.0 для нового.
static func condition_mult(c: float) -> float:
	return 0.35 + 0.65 * clampf(c, 0.0, 1.0)


static func icon_path(id: String) -> String:
	return "res://assets/art/items/%s.png" % id
