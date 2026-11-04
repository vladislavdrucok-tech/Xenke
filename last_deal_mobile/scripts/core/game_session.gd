class_name GameSession
extends RefCounted
## Повний стан однієї гри та всі ігрові дії. Не залежить від UI — тому його легко тестувати.

signal money_changed(new_value: int, delta: int)
signal changed

var money := Economy.START_MONEY
var day := 1
var customer_number := 0          # скільки клієнтів уже приходило сьогодні
var customers_today := Economy.BASE_CUSTOMERS
var current: Dictionary = {}      # поточний клієнт (див. CustomerGenerator.generate)
var inventory := Inventory.new()
var market := Market.new()
var upgrades := {}                # id -> true
var stats_day := {}
var stats_total := {}
var history: Array = []           # короткі підсумки минулих днів (до 30)
var game_over := false
var next_uid := 1
var rng := RandomNumberGenerator.new()


func new_game(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	money = Economy.START_MONEY
	day = 1
	customer_number = 0
	upgrades = {}
	current = {}
	inventory = Inventory.new()
	market = Market.new()
	market.init_random(rng)
	history = []
	game_over = false
	next_uid = 1
	stats_total = {"days": 0, "bought": 0, "sold": 0, "spent": 0, "revenue": 0, "profit": 0,
		"best_deal": 0, "best_deal_name": "", "rent": 0, "max_money": money}
	_start_day()


func _start_day() -> void:
	customers_today = Economy.customers_per_day(upgrades)
	customer_number = 0
	current = {}
	stats_day = {"day": day, "start_money": money, "customers": 0, "bought": 0, "spent": 0,
		"sold": 0, "revenue": 0, "profit": 0, "best_deal": 0, "best_deal_name": "",
		"declined": 0, "left": 0}


func _add_money(delta: int) -> void:
	if delta == 0:
		return
	money += delta
	stats_total["max_money"] = maxi(int(stats_total.get("max_money", 0)), money)
	money_changed.emit(money, delta)


# ------------------------------------------------------------------ клієнти
func has_open_customer() -> bool:
	return not current.is_empty() and current["nego"].get("status", "") == "open"


func customers_left() -> int:
	return maxi(0, customers_today - customer_number)


func day_done() -> bool:
	return customer_number >= customers_today and not has_open_customer()


## Кличе наступного клієнта. false — якщо поточний ще торгується або день скінчився.
func next_customer() -> bool:
	if game_over or has_open_customer() or customer_number >= customers_today:
		return false
	customer_number += 1
	stats_day["customers"] = int(stats_day["customers"]) + 1
	current = CustomerGenerator.generate(money, upgrades, market, next_uid, rng)
	next_uid += 1
	changed.emit()
	return true


func _nego() -> Negotiation:
	return Negotiation.new(current["nego"], rng)


func current_ask() -> int:
	if current.is_empty():
		return 0
	return int(current["nego"]["ask"])


func can_afford_ask() -> bool:
	return has_open_customer() and money >= current_ask()


## Огляд предмета. Можна лише раз на клієнта.
func inspect() -> Dictionary:
	if not has_open_customer() or current.get("inspected", false):
		return {}
	current["inspected"] = true
	var item: Dictionary = current["item"]
	var scanner: bool = upgrades.get("scanner", false)
	var found: Array = []
	for d in item["defects"]:
		if scanner or rng.randf() < 0.65:
			found.append(d)
	current["found_defects"] = found
	var demand := market.get_demand(item["id"])
	var mf: float = float(item.get("mf", 1.0))
	if not scanner and item["id"] == "mystery":
		mf = clampf(mf * exp(rng.randfn(0.0, 0.45)), 0.1, 8.0)
	var est := float(Economy.instance_value(item["id"], item["condition"], found, mf)) * demand * Economy.RETAIL_MARKUP
	if scanner:
		current["est_low"] = int(round(est))
		current["est_high"] = int(round(est))
	else:
		var spread := 0.35 if item["id"] == "mystery" else 0.18
		var center := est * rng.randf_range(0.93, 1.07)
		current["est_low"] = Economy.round5(center * (1.0 - spread))
		current["est_high"] = Economy.round5(center * (1.0 + spread))
	var nego := _nego()
	var res := nego.on_inspect()
	var line: String = res["line"]
	# Клієнт, що не врахував дефекти (приховав або не знав), знижує ціну.
	var unaccounted: bool = CustomerDB.get_type(current["type"]).get("hides", false) or not current.get("knows", false)
	if found.size() > 0 and unaccounted:
		var mult := 1.0
		for d in found:
			mult *= ItemDB.defect_mult(d)
		var c := nego.caught(mult)
		if not c.is_empty():
			line = c["line"]
	current["line"] = line
	changed.emit()
	return {"found": found, "line": line}


## Гравець пропонує свою ціну.
func offer(amount: int) -> Dictionary:
	if not has_open_customer():
		return {"result": "closed"}
	amount = clampi(amount, 0, money)
	if amount <= 0:
		return {"result": "invalid"}
	var res := _nego().offer(amount)
	current["line"] = res.get("line", "")
	if res["result"] == "deal":
		if not _complete_purchase(int(res["price"])):
			res["result"] = "no_money"
	elif res["result"] == "leave":
		stats_day["left"] = int(stats_day["left"]) + 1
	changed.emit()
	return res


## Купити за ціною клієнта.
func buy() -> Dictionary:
	if not has_open_customer():
		return {"result": "closed"}
	if money < current_ask():
		return {"result": "no_money"}
	if inventory.is_full():
		return {"result": "full"}
	var res := _nego().accept_ask()
	current["line"] = res.get("line", "")
	if res["result"] == "deal":
		_complete_purchase(int(res["price"]))
	changed.emit()
	return res


func _complete_purchase(price: int) -> bool:
	if price > money or inventory.is_full():
		# не повинно траплятися (пропозиція обмежена балансом), але страхуємось
		current["nego"]["status"] = "declined"
		return false
	var item: Dictionary = current["item"].duplicate(true)
	item["bought_price"] = price
	item["bought_day"] = day
	item["inspected"] = current.get("inspected", false)
	if not inventory.add(item):
		current["nego"]["status"] = "declined"
		return false
	_add_money(-price)
	stats_day["bought"] = int(stats_day["bought"]) + 1
	stats_day["spent"] = int(stats_day["spent"]) + price
	stats_total["bought"] = int(stats_total["bought"]) + 1
	stats_total["spent"] = int(stats_total["spent"]) + price
	return true


func decline() -> void:
	if not has_open_customer():
		return
	_nego().decline()
	stats_day["declined"] = int(stats_day["declined"]) + 1
	changed.emit()


# ------------------------------------------------------------------ продаж
func sell_price(item: Dictionary) -> int:
	return Economy.market_price(item, market.get_demand(item["id"]))


func sell(uid: int) -> Dictionary:
	if game_over:
		return {}
	var item := inventory.remove(uid)
	if item.is_empty():
		return {}
	var price := sell_price(item)
	var profit := price - int(item["bought_price"])
	_add_money(price)
	stats_day["sold"] = int(stats_day["sold"]) + 1
	stats_day["revenue"] = int(stats_day["revenue"]) + price
	stats_day["profit"] = int(stats_day["profit"]) + profit
	stats_total["sold"] = int(stats_total["sold"]) + 1
	stats_total["revenue"] = int(stats_total["revenue"]) + price
	stats_total["profit"] = int(stats_total["profit"]) + profit
	if profit > int(stats_day["best_deal"]):
		stats_day["best_deal"] = profit
		stats_day["best_deal_name"] = ItemDB.item_name(item["id"])
	if profit > int(stats_total["best_deal"]):
		stats_total["best_deal"] = profit
		stats_total["best_deal_name"] = ItemDB.item_name(item["id"])
	changed.emit()
	return {"price": price, "profit": profit, "item": item}


# ------------------------------------------------------------------ покращення
func can_buy_upgrade(id: String) -> bool:
	return Economy.UPGRADES.has(id) and not upgrades.get(id, false) and money >= int(Economy.UPGRADES[id]["cost"])


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	_add_money(-int(Economy.UPGRADES[id]["cost"]))
	upgrades[id] = true
	if id == "neon":
		customers_today += 2  # ефект уже сьогодні
	changed.emit()
	return true


# ------------------------------------------------------------------ кінець дня
func end_day() -> Dictionary:
	if game_over or not day_done():
		return {}
	var rent := Economy.rent_for_day(day)
	var forced: Array = []
	if money < rent and inventory.count() > 0:
		# Примусовий розпродаж за півціни — від найдорожчого
		var sorted_items: Array = inventory.items.duplicate()
		sorted_items.sort_custom(func(a, b): return sell_price(a) > sell_price(b))
		for it in sorted_items:
			if money >= rent:
				break
			inventory.remove(int(it["uid"]))
			var p := maxi(1, int(sell_price(it) * 0.5))
			_add_money(p)
			forced.append({"name": ItemDB.item_name(it["id"]), "price": p})
			stats_day["revenue"] = int(stats_day["revenue"]) + p
			stats_day["profit"] = int(stats_day["profit"]) + p - int(it["bought_price"])
	_add_money(-rent)
	stats_total["rent"] = int(stats_total["rent"]) + rent
	stats_total["days"] = int(stats_total["days"]) + 1
	var summary := stats_day.duplicate()
	summary["rent"] = rent
	summary["forced"] = forced
	summary["end_money"] = money
	summary["net"] = money - int(stats_day["start_money"])
	summary["inventory_value"] = inventory.total_market_value(market)
	summary["bankrupt"] = money < 0
	if money < 0:
		game_over = true
	history.append({"day": day, "net": summary["net"], "money": money, "profit": summary["profit"]})
	if history.size() > 30:
		history = history.slice(history.size() - 30)
	if not game_over:
		day += 1
		market.advance_day(rng)
		_start_day()
	summary["next_rent"] = Economy.rent_for_day(day)
	summary["news"] = market.news
	changed.emit()
	return summary


# ------------------------------------------------------------------ збереження
func to_dict() -> Dictionary:
	return {
		"version": Economy.SAVE_VERSION,
		"money": money, "day": day,
		"customer_number": customer_number, "customers_today": customers_today,
		"current": current.duplicate(true),
		"inventory": inventory.to_array(),
		"market": market.to_dict(),
		"upgrades": upgrades.duplicate(),
		"stats_day": stats_day.duplicate(), "stats_total": stats_total.duplicate(),
		"history": history.duplicate(true),
		"game_over": game_over, "next_uid": next_uid,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
	}


func from_dict(d: Dictionary) -> bool:
	if d.is_empty() or int(d.get("version", 0)) != Economy.SAVE_VERSION:
		return false
	money = int(d.get("money", Economy.START_MONEY))
	day = maxi(1, int(d.get("day", 1)))
	customer_number = maxi(0, int(d.get("customer_number", 0)))
	customers_today = maxi(1, int(d.get("customers_today", Economy.BASE_CUSTOMERS)))
	current = d.get("current", {}) if d.get("current", {}) is Dictionary else {}
	if not current.is_empty():
		if not (current.get("nego") is Dictionary and current.get("item") is Dictionary):
			current = {}
		else:
			_normalize_current()
	inventory = Inventory.new()
	inventory.from_array(d.get("inventory", []))
	market = Market.new()
	market.from_dict(d.get("market", {}))
	upgrades = {}
	var up: Dictionary = d.get("upgrades", {})
	for k in up:
		if Economy.UPGRADES.has(k) and up[k]:
			upgrades[k] = true
	stats_day = d.get("stats_day", {})
	stats_total = d.get("stats_total", {})
	for k in ["day", "start_money", "customers", "bought", "spent", "sold", "revenue", "profit", "best_deal", "declined", "left"]:
		stats_day[k] = int(stats_day.get(k, 0))
	stats_day["best_deal_name"] = str(stats_day.get("best_deal_name", ""))
	for k in ["days", "bought", "sold", "spent", "revenue", "profit", "best_deal", "rent", "max_money"]:
		stats_total[k] = int(stats_total.get(k, 0))
	stats_total["best_deal_name"] = str(stats_total.get("best_deal_name", ""))
	history = d.get("history", [])
	game_over = bool(d.get("game_over", false))
	next_uid = maxi(int(d.get("next_uid", 1)), 1)
	for it in inventory.items:
		next_uid = maxi(next_uid, int(it["uid"]) + 1)
	rng.seed = int(str(d.get("rng_seed", "0")))
	rng.state = int(str(d.get("rng_state", "0")))
	return true


## JSON перетворює всі числа на float — повертаємо цілі там, де треба.
func _normalize_current() -> void:
	var n: Dictionary = current["nego"]
	for k in ["ask", "start_ask", "floor", "patience", "max_patience", "rounds", "last_offer", "deal_price", "insults"]:
		n[k] = int(n.get(k, 0))
	n["accept"] = float(n.get("accept", 0.4))
	n["concede"] = float(n.get("concede", 0.4))
	n["status"] = str(n.get("status", "declined"))
	n["type"] = str(n.get("type", "calm"))
	var it: Dictionary = current["item"]
	it["uid"] = int(it.get("uid", 0))
	it["value"] = int(it.get("value", 5))
	it["bought_price"] = int(it.get("bought_price", 0))
	it["bought_day"] = int(it.get("bought_day", 0))
	if not ItemDB.ITEMS.has(str(it.get("id", ""))):
		current = {}
		return
	current["sprite"] = int(current.get("sprite", 0))
	current["est_low"] = int(current.get("est_low", 0))
	current["est_high"] = int(current.get("est_high", 0))
	current["type"] = str(current.get("type", "calm"))
