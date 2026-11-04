class_name CustomerGenerator
extends RefCounted
## Створює клієнта з предметом і стартовою ціною.

## Ваги характерів: новачки й спокійні трапляються частіше.
const TYPE_WEIGHTS := {"impatient": 1.0, "calm": 1.3, "cunning": 1.0, "expert": 0.8, "novice": 1.1}


static func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[-1]


## Вибір товару: дорогі речі рідше, коли гравцеві не по кишені.
static func pick_item_id(money: int, upgrades: Dictionary, rng: RandomNumberGenerator) -> String:
	var w := {}
	for id in ItemDB.ids():
		var base: int = int(ItemDB.get_def(id)["base"])
		var weight := 1.0
		if base * 0.75 > money:
			weight = 0.15
		elif base * 0.75 > money * 0.6:
			weight = 0.55
		if id == "mystery":
			weight *= 0.55
		if upgrades.get("neon", false) and base >= 250:
			weight *= 1.5
		if money > 1500 and base >= 200:
			weight *= 1.6  # заможна крамниця приваблює дорожчий товар
		w[id] = weight
	return _weighted_pick(w, rng)


static func make_item(id: String, type_id: String, uid: int, rng: RandomNumberGenerator) -> Dictionary:
	var cond := clampf(pow(rng.randf(), 0.65), 0.05, 1.0)
	var defects: Array = []
	var pool: Array = ItemDB.get_def(id)["defects"].duplicate()
	var p1 := 0.40
	var p2 := 0.10
	if type_id == "cunning":
		p1 = 0.70
		p2 = 0.30
	elif type_id == "expert":
		p1 = 0.30
		p2 = 0.05
	if rng.randf() < p1 and pool.size() > 0:
		defects.append(_pick_defect(pool, type_id, rng))
		if rng.randf() < p2 and pool.size() > 0:
			defects.append(_pick_defect(pool, type_id, rng))
	var mf := 1.0
	if id == "mystery":
		mf = clampf(exp(rng.randfn(0.0, 0.85)), 0.12, 6.0)
	return {
		"uid": uid,
		"id": id,
		"condition": snappedf(cond, 0.01),
		"defects": defects,
		"mf": snappedf(mf, 0.01),
		"value": Economy.instance_value(id, cond, defects, mf),
		"bought_price": 0,
		"bought_day": 0,
	}


static func _pick_defect(pool: Array, type_id: String, rng: RandomNumberGenerator) -> String:
	# «Підробка» — рідкісна, але в хитрих вдвічі частіше.
	for _i in 4:
		var d: String = pool[rng.randi_range(0, pool.size() - 1)]
		if d == "fake":
			var chance := 0.30 if type_id == "cunning" else 0.12
			if rng.randf() > chance:
				continue
		pool.erase(d)
		return d
	var nf: Array = pool.filter(func(x): return x != "fake")
	if nf.is_empty():
		var d0: String = pool[0]
		pool.erase(d0)
		return d0
	var d2: String = nf[rng.randi_range(0, nf.size() - 1)]
	pool.erase(d2)
	return d2


## Повний клієнт: ім'я, характер, спрайт, предмет, торг.
static func generate(money: int, upgrades: Dictionary, market: Market, uid: int, rng: RandomNumberGenerator) -> Dictionary:
	var type_id := _weighted_pick(TYPE_WEIGHTS, rng)
	var t := CustomerDB.get_type(type_id)
	var item_id := pick_item_id(money, upgrades, rng)
	var item := make_item(item_id, type_id, uid, rng)
	var demand := market.get_demand(item_id)

	# Як клієнт сам оцінює річ
	var knows := rng.randf() < float(t["knows"])
	var hides: bool = t["hides"]
	var claimed_cond: float = item["condition"]
	if hides:
		claimed_cond = minf(0.95, claimed_cond + rng.randf_range(0.15, 0.3))
	var perceived: float = float(ItemDB.get_def(item_id)["base"]) * ItemDB.condition_mult(claimed_cond)
	if item_id == "mystery":
		# ніхто точно не знає, що це; досвідчені вгадують краще
		var guess := float(item["mf"]) if t["aware"] >= 0.9 else exp(rng.randfn(0.0, 0.5))
		perceived *= guess
	if knows and not hides:
		for d in item["defects"]:
			perceived *= ItemDB.defect_mult(d)
	var aware: float = t["aware"]
	perceived *= 1.0 + (demand - 1.0) * aware
	var ask_mult := rng.randf_range(t["ask"][0], t["ask"][1])
	var ask := Economy.round5(perceived * ask_mult)
	var floor_ratio := rng.randf_range(t["floor"][0], t["floor"][1])
	var nego := Negotiation.create(type_id, ask, floor_ratio, upgrades.get("charisma", false), rng)

	var name: String = CustomerDB.FIRST_NAMES[rng.randi_range(0, CustomerDB.FIRST_NAMES.size() - 1)]
	if rng.randf() < 0.35:
		name += " «%s»" % CustomerDB.NICKNAMES[rng.randi_range(0, CustomerDB.NICKNAMES.size() - 1)]
	var lore_arr: Array = ItemDB.get_def(item_id)["lore"]
	var greet_arr: Array = t["greet"]
	var greet: String = greet_arr[rng.randi_range(0, greet_arr.size() - 1)]
	greet = greet % [ItemDB.item_name(item_id).to_lower(), ask]
	greet += " " + str(lore_arr[rng.randi_range(0, lore_arr.size() - 1)])
	return {
		"name": name,
		"type": type_id,
		"sprite": rng.randi_range(0, CustomerDB.SPRITE_COUNT - 1),
		"item": item,
		"claimed_condition": snappedf(claimed_cond, 0.01),
		"nego": nego,
		"knows": knows,
		"inspected": false,
		"found_defects": [],
		"est_low": 0,
		"est_high": 0,
		"line": greet,
	}
