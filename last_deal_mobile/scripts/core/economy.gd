class_name Economy
extends RefCounted
## Економічні константи та чисті функції (без стану).

const START_MONEY := 500
const BASE_CUSTOMERS := 6
const SAVE_VERSION := 1
## Роздрібна націнка: крамниця продає на ринку дорожче, ніж «справжня» скупна вартість.
const RETAIL_MARKUP := 1.2

## Покращення магазину (по одному рівню кожне).
const UPGRADES := {
	"scanner": {"name": "Сканер дефектів", "cost": 350,
		"desc": "Перевірка знаходить усі дефекти й показує точну ринкову ціну."},
	"neon": {"name": "Нова неонова вивіска", "cost": 600,
		"desc": "+2 клієнти щодня, частіше приносять дорогі речі."},
	"charisma": {"name": "Курси переговорів", "cost": 800,
		"desc": "Клієнти терплячіші (+1) і поступаються на 6% більше."},
}

const UPGRADE_ORDER := ["scanner", "neon", "charisma"]


## Оренда зростає з кожним днем, але має стелю.
static func rent_for_day(day: int) -> int:
	return mini(30 + 4 * (maxi(day, 1) - 1), 200)


static func customers_per_day(upgrades: Dictionary) -> int:
	return BASE_CUSTOMERS + (2 if upgrades.get("neon", false) else 0)


## Округлення до 5 кредитів (ціни в крамниці «круглі»), мінімум 5.
static func round5(v: float) -> int:
	return maxi(5, int(round(v / 5.0)) * 5)


## Справжня вартість конкретного екземпляра при попиті 1.0.
static func instance_value(item_id: String, condition: float, defects: Array, mystery_factor: float = 1.0) -> int:
	var def := ItemDB.get_def(item_id)
	var v: float = float(def.get("base", 10)) * ItemDB.condition_mult(condition) * mystery_factor
	for d in defects:
		v *= ItemDB.defect_mult(d)
	return maxi(5, int(round(v)))


## Ціна, яку платить ринок за предмет з урахуванням попиту.
static func market_price(item: Dictionary, demand: float) -> int:
	return maxi(1, int(round(float(item.get("value", 0)) * demand * RETAIL_MARKUP)))


static func format_money(v: int) -> String:
	var neg := v < 0
	var s := str(absi(v))
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var rem := n - i - 1
		if rem > 0 and rem % 3 == 0:
			out += " "
	return ("-" if neg else "") + out
