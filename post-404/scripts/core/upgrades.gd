class_name Upgrades
extends RefCounted
## Everything that can be bought in the post office and what it does.
## Kinds: "upgrade" (levels), "room" (one-off, unlocks), "decor" (one-off,
## small bonus + visible in the office), "equip" (one-off, paid in shards).

const DEFS := {
	# --- Machinery ---
	"lift": {"kind": "upgrade", "max": 5, "cost": 90, "growth": 1.9, "icon": "ic_lift",
		"name": {"uk": "Мотор підйомника", "en": "Lift Motor"},
		"desc": {"uk": "Наступна посилка з'являється швидше.", "en": "The next parcel arrives faster."}},
	"press": {"kind": "upgrade", "max": 8, "cost": 150, "growth": 1.75, "icon": "ic_press",
		"name": {"uk": "Штемпельний прес", "en": "Stamp Press"},
		"desc": {"uk": "+1 монета за кожну правильну посилку.", "en": "+1 coin for every correct parcel."}},
	"overtime": {"kind": "upgrade", "max": 6, "cost": 240, "growth": 1.8, "icon": "ic_clock",
		"name": {"uk": "Годинник понаднормових", "en": "Overtime Clock"},
		"desc": {"uk": "+10 секунд до кожної зміни.", "en": "+10 seconds to every shift."}},
	"chutes": {"kind": "upgrade", "max": 2, "cost": 900, "growth": 2.5, "icon": "ic_chute",
		"name": {"uk": "Посилені жолоби", "en": "Reinforced Chutes"},
		"desc": {"uk": "+1 до надійності: зміна витримує більше помилок.", "en": "+1 reliability: a shift survives one more mistake."}},
	"scanner": {"kind": "upgrade", "max": 3, "cost": 700, "growth": 2.0, "icon": "ic_scanner", "level": 3,
		"name": {"uk": "УФ-сканер", "en": "UV Scanner"},
		"desc": {"uk": "Проявляє стерті цифри на етикетках. Що вищий рівень, то швидше.", "en": "Reveals smudged label digits. Higher levels are faster."}},
	"window": {"kind": "upgrade", "max": 2, "cost": 600, "growth": 2.4, "icon": "ic_window",
		"name": {"uk": "Оглядове віконце", "en": "Belt Window"},
		"desc": {"uk": "Показує роки на наступних посилках у черзі.", "en": "Shows the years on the next parcels in the queue."}},
	"robot": {"kind": "upgrade", "max": 4, "cost": 250, "growth": 2.8, "icon": "ic_robot",
		"name": {"uk": "Ремонт БІТа", "en": "Repair BIT"},
		"desc": {"uk": "1: БІТ оживає й підказує. 2: допомагає із забутою посилкою. 3: рятує серію раз за зміну. 4: сортує свою стрічку.", "en": "1: BIT wakes and gives tips. 2: helps with a stalled parcel. 3: saves the combo once per shift. 4: sorts his own belt."}},
	# --- Rooms ---
	"archive": {"kind": "room", "max": 1, "cost": 1500, "growth": 1.0, "icon": "ic_archive", "level": 3,
		"name": {"uk": "Архів", "en": "Archive Room"},
		"desc": {"uk": "Полиці для колекції. Рідкісні предмети трапляються вдвічі частіше.", "en": "Shelves for the collection. Rare items appear twice as often."}},
	"lounge": {"kind": "room", "max": 1, "cost": 2000, "growth": 1.0, "icon": "ic_lounge", "level": 4,
		"name": {"uk": "Кімната відпочинку", "en": "Lounge"},
		"desc": {"uk": "Кавоварка заробляє монети, поки тебе немає (до 8 год).", "en": "The coffee machine earns coins while you're away (up to 8 h)."}},
	"coffee": {"kind": "upgrade", "max": 5, "cost": 800, "growth": 2.0, "icon": "ic_coffee", "requires": "lounge",
		"name": {"uk": "Кавоварка", "en": "Coffee Machine"},
		"desc": {"uk": "+12 монет за годину відсутності за рівень.", "en": "+12 coins per hour away, per level."}},
	"antenna": {"kind": "room", "max": 1, "cost": 4500, "growth": 1.0, "shards": 3, "icon": "ic_antenna", "level": 6,
		"name": {"uk": "Антена на даху", "en": "Rooftop Antenna"},
		"desc": {"uk": "Ловить щоденні аномалії: +50% нагороди за щоденне завдання.", "en": "Catches daily anomalies: +50% daily challenge reward."}},
	"lab": {"kind": "room", "max": 1, "cost": 6500, "growth": 1.0, "shards": 5, "icon": "ic_lab", "level": 7,
		"name": {"uk": "Квантова лабораторія", "en": "Quantum Lab"},
		"desc": {"uk": "Небезпечні артефакти в карантині дають уламки часу.", "en": "Quarantined hazards yield time shards."}},
	# --- Decorations ---
	"plant": {"kind": "decor", "max": 1, "cost": 400, "growth": 1.0, "icon": "dc_plant",
		"name": {"uk": "Фікус «Генадій»", "en": "Ficus \"Gennady\""},
		"desc": {"uk": "+3% досвіду. Поливати не треба: він з 2090-го.", "en": "+3% XP. Needs no water: it's from 2090."}},
	"lamp": {"kind": "decor", "max": 1, "cost": 600, "growth": 1.0, "icon": "dc_lamp",
		"name": {"uk": "Лампа-гриб", "en": "Mushroom Lamp"},
		"desc": {"uk": "+3% монет. Затишно.", "en": "+3% coins. Cosy."}},
	"poster": {"kind": "decor", "max": 1, "cost": 800, "growth": 1.0, "icon": "dc_poster",
		"name": {"uk": "Плакат «Час не чекає»", "en": "Poster \"Time Waits\""},
		"desc": {"uk": "+3% очок.", "en": "+3% score."}},
	"radio": {"kind": "decor", "max": 1, "cost": 1600, "growth": 1.0, "icon": "dc_radio",
		"name": {"uk": "Лампове радіо", "en": "Valve Radio"},
		"desc": {"uk": "Нова мелодія в меню та +3% монет.", "en": "A new tune in the menu and +3% coins."}},
	"catbed": {"kind": "decor", "max": 1, "cost": 2500, "growth": 1.0, "icon": "dc_catbed", "level": 8,
		"name": {"uk": "Лежанка для Кванта", "en": "Bed for Quant"},
		"desc": {"uk": "Кіт Квант заходить удвічі частіше.", "en": "Quant the cat visits twice as often."}},
	"neon": {"kind": "decor", "max": 1, "cost": 4000, "growth": 1.0, "icon": "dc_neon",
		"name": {"uk": "Неонова вивіска 404", "en": "Neon Sign 404"},
		"desc": {"uk": "+5% очок і +5% досвіду.", "en": "+5% score and +5% XP."}},
	# --- Rare equipment (time shards) ---
	"stabilizer": {"kind": "equip", "max": 1, "cost": 0, "shards": 6, "growth": 1.0, "icon": "eq_stabilizer", "level": 8,
		"name": {"uk": "Хроностабілізатор", "en": "Chrono Stabilizer"},
		"desc": {"uk": "Аномалії правил коротші на 30%, а «золоті години» довші.", "en": "Rule anomalies are 30% shorter, golden hours last longer."}},
	"golden_stamp": {"kind": "equip", "max": 1, "cost": 0, "shards": 10, "growth": 1.0, "icon": "eq_golden",
		"name": {"uk": "Золотий штемпель", "en": "Golden Stamp"},
		"desc": {"uk": "+10% монет назавжди.", "en": "+10% coins forever."}},
	"lens": {"kind": "equip", "max": 1, "cost": 0, "shards": 5, "growth": 1.0, "icon": "eq_lens", "level": 4,
		"name": {"uk": "Тахіонна лінза", "en": "Tachyon Lens"},
		"desc": {"uk": "Термінові посилки дають на 1,5 с більше.", "en": "Urgent parcels allow 1.5 s more."}},
	"filter": {"kind": "equip", "max": 1, "cost": 0, "shards": 8, "growth": 1.0, "icon": "eq_filter", "level": 6,
		"name": {"uk": "Фільтр парадоксів", "en": "Paradox Filter"},
		"desc": {"uk": "Перша помилка за зміну не знімає надійність.", "en": "The first mistake of a shift costs no reliability."}},
}

const SHOP_TABS := {
	"machines": ["lift", "press", "overtime", "chutes", "scanner", "window", "robot"],
	"rooms": ["archive", "lounge", "coffee", "antenna", "lab"],
	"decor": ["plant", "lamp", "poster", "radio", "catbed", "neon"],
	"equip": ["stabilizer", "golden_stamp", "lens", "filter"],
}


static func level_of(profile: Dictionary, id: String) -> int:
	return int(profile.get("upgrades", {}).get(id, 0))


static func cost(id: String, current_level: int) -> int:
	var d: Dictionary = DEFS[id]
	return int(round(float(d["cost"]) * pow(float(d["growth"]), current_level)))


static func shard_cost(id: String) -> int:
	return int(DEFS[id].get("shards", 0))


## "ok", "max", "coins", "shards", "level", "requires"
static func can_buy(profile: Dictionary, id: String) -> String:
	var d: Dictionary = DEFS[id]
	var lvl := level_of(profile, id)
	if lvl >= int(d["max"]):
		return "max"
	if int(profile.get("level", 1)) < int(d.get("level", 1)):
		return "level"
	var req: String = d.get("requires", "")
	if req != "" and level_of(profile, req) <= 0:
		return "requires"
	if int(profile.get("coins", 0)) < cost(id, lvl):
		return "coins"
	if int(profile.get("shards", 0)) < shard_cost(id):
		return "shards"
	return "ok"


static func buy(profile: Dictionary, id: String) -> bool:
	if can_buy(profile, id) != "ok":
		return false
	var lvl := level_of(profile, id)
	profile["coins"] = int(profile["coins"]) - cost(id, lvl)
	profile["shards"] = int(profile.get("shards", 0)) - shard_cost(id)
	if not profile.has("upgrades"):
		profile["upgrades"] = {}
	profile["upgrades"][id] = lvl + 1
	return true


## Gameplay numbers derived from the purchases. One place, used by the shift
## session and the tests, so the UI never computes its own.
static func stats(profile: Dictionary) -> Dictionary:
	var u: Dictionary = profile.get("upgrades", {})
	var lv := func(id: String) -> int: return int(u.get(id, 0))
	var coin_mult: float = 1.0 + 0.03 * lv.call("lamp") + 0.03 * lv.call("radio") + 0.10 * lv.call("golden_stamp")
	var xp_mult: float = 1.0 + 0.03 * lv.call("plant") + 0.05 * lv.call("neon")
	var score_mult: float = 1.0 + 0.03 * lv.call("poster") + 0.05 * lv.call("neon")
	var scanner_lv: int = lv.call("scanner")
	return {
		"lift_time": 0.42 - 0.06 * lv.call("lift"),
		"coin_base": 3 + lv.call("press"),
		"shift_time": 75.0 + 10.0 * lv.call("overtime"),
		"reliability": 4 + lv.call("chutes"),
		"scanner_delay": [999.0, 1.6, 0.8, 0.0][clampi(scanner_lv, 0, 3)],
		"preview": lv.call("window"),
		"robot": lv.call("robot"),
		"robot_assist_after": 5.0,
		"robot_belt_period": 9.0,
		"combo_shield": lv.call("robot") >= 3,
		"collect_mult": 2.0 if lv.call("archive") > 0 else 1.0,
		"coffee_rate": 12 * lv.call("coffee"),
		"daily_mult": 1.5 if lv.call("antenna") > 0 else 1.0,
		"lab": lv.call("lab") > 0,
		"cat_mult": 2.0 if lv.call("catbed") > 0 else 1.0,
		"stabilizer": lv.call("stabilizer") > 0,
		"urgent_bonus_time": 1.5 if lv.call("lens") > 0 else 0.0,
		"first_mistake_free": lv.call("filter") > 0,
		"coin_mult": coin_mult,
		"xp_mult": xp_mult,
		"score_mult": score_mult,
	}
