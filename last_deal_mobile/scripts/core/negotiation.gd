class_name Negotiation
extends RefCounted
## Логіка торгу з одним клієнтом. Увесь стан — у словнику `s` (легко зберігати).
##
## Ключі s: type, ask, floor, patience, max_patience, accept, concede, status
## ("open" | "deal" | "left" | "declined"), rounds, last_offer, deal_price, insults.
##
## Економічна логіка (без «монетки»):
##  * пропозиція >= поточної ціни -> згода;
##  * пропозиція між межею і ціною -> згода, якщо вона достатньо близька до ціни
##    (поріг accept залежить від характеру), інакше зустрічна ціна ближче до гравця;
##  * пропозиція нижче межі -> відмова, втрата терпіння (дуже низька — образа, -2);
##  * терпіння 0 -> клієнт іде.

var s: Dictionary
var rng: RandomNumberGenerator


func _init(state: Dictionary, random: RandomNumberGenerator) -> void:
	s = state
	rng = random


static func create(type_id: String, ask: int, floor_ratio: float, charisma: bool, rng: RandomNumberGenerator) -> Dictionary:
	var t := CustomerDB.get_type(type_id)
	var patience: int = int(t["patience"]) + (1 if charisma else 0)
	var fl: float = ask * floor_ratio * (0.94 if charisma else 1.0)
	return {
		"type": type_id,
		"ask": ask,
		"start_ask": ask,
		"floor": maxi(5, int(round(fl))),
		"patience": patience,
		"max_patience": patience,
		"accept": clampf(float(t["accept"]) + rng.randf_range(-0.08, 0.08), 0.05, 0.95),
		"concede": float(t["concede"]),
		"status": "open",
		"rounds": 0,
		"last_offer": 0,
		"deal_price": 0,
		"insults": 0,
	}


func is_open() -> bool:
	return s.get("status", "") == "open"


func _line(key: String) -> String:
	var arr: Array = CustomerDB.get_type(s["type"]).get(key, [""])
	return str(arr[rng.randi_range(0, arr.size() - 1)])


## Гравець пропонує суму. Повертає {result, price, line}.
func offer(amount: int) -> Dictionary:
	if not is_open():
		return {"result": "closed", "price": 0, "line": ""}
	amount = maxi(0, amount)
	s["rounds"] = int(s["rounds"]) + 1
	s["last_offer"] = amount
	var ask: int = int(s["ask"])
	var fl: int = int(s["floor"])
	if amount >= ask:
		return _deal(ask if amount > ask else amount)
	if amount >= fl:
		var gap := float(ask - amount) / float(maxi(1, ask - fl))  # 0 = як просив, 1 = на межі
		if gap <= float(s["accept"]):
			return _deal(amount)
		# зустрічна пропозиція
		s["patience"] = int(s["patience"]) - 1
		if int(s["patience"]) <= 0:
			# остання спроба: якщо пропозиція близька до межі — погоджується неохоче
			if gap <= 0.85:
				return _deal(amount)
			return _leave()
		var new_ask := Economy.round5(ask - (ask - amount) * float(s["concede"]))
		new_ask = clampi(new_ask, maxi(fl, amount + 5), ask)
		s["ask"] = new_ask
		return {"result": "counter", "price": new_ask, "line": _line("counter").replace("%d", str(new_ask))}
	# нижче межі
	var ratio := float(amount) / float(maxi(1, fl))
	var loss := 2 if ratio < 0.6 else 1
	if loss == 2:
		s["insults"] = int(s["insults"]) + 1
	s["patience"] = int(s["patience"]) - loss
	if int(s["patience"]) <= 0:
		return _leave()
	# невелика поступка навіть на відмову, але не нижче межі
	var step := Economy.round5((ask - fl) * float(s["concede"]) * 0.4)
	var na := maxi(fl, ask - step) if step > 5 else ask
	s["ask"] = na
	var line := _line("reject")
	if na < ask:
		line += " " + _line("counter").replace("%d", str(na))
	return {"result": "reject", "price": na, "line": line}


## Гравець погоджується на поточну ціну.
func accept_ask() -> Dictionary:
	if not is_open():
		return {"result": "closed", "price": 0, "line": ""}
	return _deal(int(s["ask"]))


func decline() -> void:
	if is_open():
		s["status"] = "declined"


## Нетерплячий клієнт втрачає терпіння, поки гравець оглядає річ.
func on_inspect() -> Dictionary:
	var cost: int = int(CustomerDB.get_type(s["type"]).get("inspect_cost", 0))
	var line := _line("inspect")
	if cost > 0 and is_open():
		s["patience"] = maxi(1, int(s["patience"]) - cost)
	return {"line": line}


## Хитрий клієнт, якого спіймали на дефекті, знижує ціну.
func caught(mult: float) -> Dictionary:
	if not is_open():
		return {}
	var f := clampf(pow(mult, 0.75), 0.2, 1.0)
	s["ask"] = Economy.round5(int(s["ask"]) * f)
	s["floor"] = mini(int(s["ask"]), Economy.round5(int(s["floor"]) * f))
	var arr: Array = CustomerDB.get_type(s["type"]).get("caught", ["Гаразд, %d."])
	var line := str(arr[rng.randi_range(0, arr.size() - 1)]).replace("%d", str(s["ask"]))
	return {"line": line, "price": s["ask"]}


func _deal(price: int) -> Dictionary:
	s["status"] = "deal"
	s["deal_price"] = price
	return {"result": "deal", "price": price, "line": _line("accept_line")}


func _leave() -> Dictionary:
	s["status"] = "left"
	s["patience"] = 0
	return {"result": "leave", "price": 0, "line": _line("leave")}
