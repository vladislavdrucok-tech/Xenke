extends Node
## Game state, economy rules and autosave. Autoload "Game".

const Data = preload("res://scripts/data.gd")

const SAVE_PATH := "user://lot13_save.json"
const TEST_SAVE_PATH := "user://lot13_test_save.json"
const SAVE_VERSION := 1
const START_MONEY := 500
const SCANNER_SPREAD := [0.5, 0.42, 0.33, 0.22, 0.14]

signal money_changed(value: int)
signal xp_changed
signal level_up(new_level: int)
signal state_changed

var rng := RandomNumberGenerator.new()
var save_path := SAVE_PATH
var test_mode := false

var money: int = START_MONEY
var day: int = 1
var level: int = 1
var xp: int = 0
var items: Array = []          # {uid, id, cond, paid, fixed}
var boxes: Array = []          # unopened: {uid, kind, tier, paid, items: [{id, cond}], secret}
var upgrades: Dictionary = {}
var found: Dictionary = {}     # item id -> best sale price (0 = found, not sold yet)
var stats: Dictionary = {}
var trends: Dictionary = {}    # category -> price multiplier for today
var event: Dictionary = {}     # today's random event
var goals_done: Array = []
var settings: Dictionary = {}
var tutorial_done := false
var hints: Dictionary = {}
var next_uid := 1
var buyers_today: Dictionary = {}
var pending_event := false

var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	test_mode = args.has("--selftest") or args.has("--smoke") or args.has("--shots")
	if test_mode:
		save_path = TEST_SAVE_PATH
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)
	reset_state()
	if not test_mode:
		load_game()
	L.set_lang(str(settings.get("lang", "en")))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _save_timer != null:
			save_now()


# ------------------------------------------------------------------ state
func default_stats() -> Dictionary:
	return {"earned": 0, "spent": 0, "boxes": 0, "sold": 0, "repairs": 0, "auctions": 0, "won": 0,
		"best_sale": 0, "rare": 0, "epic": 0, "legendary": 0, "profit": 0, "perfects": 0}


func reset_state() -> void:
	money = START_MONEY
	day = 1
	level = 1
	xp = 0
	items = []
	boxes = []
	upgrades = {}
	for u in Data.UPGRADES:
		upgrades[u["id"]] = 0
	found = {}
	stats = default_stats()
	event = {}
	goals_done = []
	tutorial_done = false
	hints = {}
	next_uid = 1
	buyers_today = {}
	pending_event = false
	if settings.is_empty():
		settings = {"lang": default_lang(), "sound": true, "music": true, "vibrate": true}
	_roll_trends()


func default_lang() -> String:
	return "uk" if OS.get_locale_language() == "uk" else "en"


func new_game() -> void:
	var keep := settings.duplicate()
	reset_state()
	settings = keep
	save_now()
	money_changed.emit(money)
	xp_changed.emit()
	state_changed.emit()


func _uid() -> int:
	next_uid += 1
	return next_uid


# ------------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	return {"v": SAVE_VERSION, "money": money, "day": day, "level": level, "xp": xp, "items": items,
		"boxes": boxes, "upgrades": upgrades, "found": found, "stats": stats, "trends": trends, "event": event,
		"goals_done": goals_done, "settings": settings, "tutorial_done": tutorial_done, "hints": hints,
		"next_uid": next_uid, "buyers_today": buyers_today, "pending_event": pending_event}


func request_save() -> void:
	if _save_timer != null and _save_timer.is_inside_tree():
		_save_timer.start()


func save_now() -> void:
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("LOT13: cannot write save (%d)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var main_name := save_path.get_file()
	if dir.file_exists(main_name):
		dir.remove(main_name)
	dir.rename(tmp.get_file(), main_name)


func load_game() -> bool:
	var data = _read_json(save_path)
	if typeof(data) != TYPE_DICTIONARY:
		data = _read_json(save_path + ".tmp")
	if typeof(data) != TYPE_DICTIONARY:
		return false
	from_dict(data)
	return true


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var txt := FileAccess.get_file_as_string(path)
	if txt.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(txt) != OK:
		return null
	return json.data


func from_dict(d: Dictionary) -> void:
	reset_state()
	money = maxi(0, int(d.get("money", START_MONEY)))
	day = maxi(1, int(d.get("day", 1)))
	level = maxi(1, int(d.get("level", 1)))
	xp = maxi(0, int(d.get("xp", 0)))
	next_uid = maxi(1, int(d.get("next_uid", 1)))
	items = []
	var raw_items = d.get("items", [])
	if typeof(raw_items) == TYPE_ARRAY:
		for it in raw_items:
			if typeof(it) == TYPE_DICTIONARY and Data.ITEMS.has(str(it.get("id", ""))):
				items.append({"uid": int(it.get("uid", _uid())), "id": str(it["id"]),
					"cond": clampf(float(it.get("cond", 0.5)), 0.05, 1.0),
					"paid": int(it.get("paid", 0)), "fixed": int(it.get("fixed", 0))})
	boxes = []
	var raw_boxes = d.get("boxes", [])
	if typeof(raw_boxes) == TYPE_ARRAY:
		for b in raw_boxes:
			if typeof(b) != TYPE_DICTIONARY:
				continue
			var contents := []
			var raw_c = b.get("items", [])
			if typeof(raw_c) == TYPE_ARRAY:
				for c in raw_c:
					if typeof(c) == TYPE_DICTIONARY and Data.ITEMS.has(str(c.get("id", ""))):
						contents.append({"id": str(c["id"]), "cond": clampf(float(c.get("cond", 0.5)), 0.05, 1.0)})
			if contents.size() > 0:
				boxes.append({"uid": int(b.get("uid", _uid())), "kind": str(b.get("kind", "cardboard")),
					"tier": clampi(int(b.get("tier", 0)), 0, Data.AUCTIONS.size() - 1),
					"paid": int(b.get("paid", 0)), "items": contents, "secret": bool(b.get("secret", false))})
	var raw_up = d.get("upgrades", {})
	if typeof(raw_up) == TYPE_DICTIONARY:
		for u in Data.UPGRADES:
			upgrades[u["id"]] = clampi(int(raw_up.get(u["id"], 0)), 0, int(u["max"]))
	found = {}
	var raw_found = d.get("found", {})
	if typeof(raw_found) == TYPE_DICTIONARY:
		for k in raw_found.keys():
			if Data.ITEMS.has(str(k)):
				found[str(k)] = int(raw_found[k])
	var raw_stats = d.get("stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		for k in stats.keys():
			stats[k] = int(raw_stats.get(k, 0))
	var raw_trends = d.get("trends", {})
	if typeof(raw_trends) == TYPE_DICTIONARY and not raw_trends.is_empty():
		trends = {}
		for k in raw_trends.keys():
			trends[str(k)] = clampf(float(raw_trends[k]), 0.5, 2.0)
	var raw_event = d.get("event", {})
	event = raw_event if typeof(raw_event) == TYPE_DICTIONARY else {}
	goals_done = []
	var raw_goals = d.get("goals_done", [])
	if typeof(raw_goals) == TYPE_ARRAY:
		for g in raw_goals:
			goals_done.append(str(g))
	var raw_set = d.get("settings", {})
	if typeof(raw_set) == TYPE_DICTIONARY:
		for k in ["sound", "music", "vibrate"]:
			settings[k] = bool(raw_set.get(k, settings.get(k, true)))
		var lang := str(raw_set.get("lang", settings.get("lang", "en")))
		settings["lang"] = lang if lang in ["uk", "en"] else "en"
	tutorial_done = bool(d.get("tutorial_done", false))
	var raw_hints = d.get("hints", {})
	hints = raw_hints if typeof(raw_hints) == TYPE_DICTIONARY else {}
	var raw_buyers = d.get("buyers_today", {})
	buyers_today = raw_buyers if typeof(raw_buyers) == TYPE_DICTIONARY else {}
	pending_event = bool(d.get("pending_event", false)) and not event.is_empty()
	for it in items:
		next_uid = maxi(next_uid, int(it["uid"]) + 1)
	for b in boxes:
		next_uid = maxi(next_uid, int(b["uid"]) + 1)


# ------------------------------------------------------------------ money and reputation
func add_money(n: int, earned: bool = false) -> void:
	money += n
	if earned and n > 0:
		stats["earned"] = int(stats["earned"]) + n
	money_changed.emit(money)
	request_save()


func spend(n: int) -> bool:
	if n < 0 or n > money:
		return false
	money -= n
	stats["spent"] = int(stats["spent"]) + n
	money_changed.emit(money)
	request_save()
	return true


func xp_needed(lvl: int) -> int:
	return int(round(40.0 * pow(float(lvl), 1.5)))


func add_xp(n: int) -> void:
	if n <= 0:
		return
	xp += n
	var gained := 0
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		gained += 1
	xp_changed.emit()
	if gained > 0:
		level_up.emit(level)
	request_save()


func xp_for_sale(price: int, profit: int) -> int:
	return maxi(1, int(price / 5.0) + maxi(0, int(profit / 4.0)))


# ------------------------------------------------------------------ values
static func cond_mult(c: float) -> float:
	return 0.2 + 0.8 * pow(clampf(c, 0.0, 1.0), 1.4)


static func nice_round(x: float) -> int:
	if x < 20.0:
		return maxi(1, roundi(x))
	if x < 100.0:
		return roundi(x / 5.0) * 5
	if x < 1000.0:
		return roundi(x / 10.0) * 10
	if x < 10000.0:
		return roundi(x / 50.0) * 50
	return roundi(x / 100.0) * 100


static func nice_step(x: float) -> int:
	var best := 1
	for s in [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000, 10000]:
		if float(s) <= x:
			best = int(s)
	return best


func bid_step(price: int) -> int:
	return nice_step(maxf(1.0, float(price) * 0.08))


func item_base(id: String) -> int:
	return int(Data.item(id)["v"])


func base_value(id: String, cond: float) -> int:
	return maxi(1, roundi(float(item_base(id)) * cond_mult(cond)))


func trend_of(id: String) -> float:
	var cat := str(Data.item(id)["cat"])
	var t := float(trends.get(cat, 1.0))
	if str(event.get("id", "")) == "collector" and str(event.get("cat", "")) == cat:
		t *= 1.5
	return t


func expertise_bonus() -> float:
	return minf(0.2, float(found.size()) * 0.005)


func value_at(id: String, cond: float) -> int:
	var v := float(item_base(id)) * cond_mult(cond) * trend_of(id) * (1.0 + expertise_bonus())
	return maxi(1, roundi(v))


func market_value(it: Dictionary) -> int:
	return value_at(str(it["id"]), float(it["cond"]))


func pawn_price(it: Dictionary) -> int:
	return maxi(1, roundi(float(market_value(it)) * 0.45))


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_val(id: String) -> int:
	var u: Dictionary = Data.upgrade(id)
	var vals: Array = u["vals"]
	return int(vals[clampi(upgrade_level(id), 0, vals.size() - 1)])


func capacity() -> int:
	return upgrade_val("shelves")


func repair_cap() -> float:
	return float(upgrade_val("bench")) / 100.0


func can_repair(it: Dictionary) -> bool:
	return float(it["cond"]) < repair_cap() - 0.005


func repair_cost(it: Dictionary) -> int:
	var gap := maxf(0.05, repair_cap() - float(it["cond"]))
	return maxi(2, roundi(float(item_base(str(it["id"]))) * 0.08 * gap))


func cond_key(c: float) -> String:
	if c < 0.3:
		return "cond.broken"
	if c < 0.55:
		return "cond.worn"
	if c < 0.8:
		return "cond.used"
	if c < 0.95:
		return "cond.good"
	return "cond.mint"


static func cond_color(c: float) -> Color:
	if c < 0.3:
		return Color("e05a60")
	if c < 0.55:
		return Color("f0903c")
	if c < 0.8:
		return Color("f8d448")
	return Color("72c04c")


# ------------------------------------------------------------------ lots and boxes
func weighted_index(w: Array) -> int:
	var total := 0.0
	for x in w:
		total += float(x)
	if total <= 0.0:
		return 0
	var r := rng.randf() * total
	for i in range(w.size()):
		r -= float(w[i])
		if r <= 0.0:
			return i
	return w.size() - 1


func roll_rarity(tier: int, golden: bool = false) -> int:
	var a: Dictionary = Data.auction(tier)
	var base: Array = a["weights"]
	var w := []
	for x in base:
		w.append(float(x))
	var luck := 1.0 + float(upgrade_val("charm")) / 100.0
	if str(event.get("id", "")) == "lucky":
		luck *= 2.0
	for i in range(2, 5):
		w[i] = float(w[i]) * luck
	if golden:
		w[0] = float(w[0]) * 0.15
		w[1] = float(w[1]) * 0.6
		w[3] = float(w[3]) * 2.0
		w[4] = float(w[4]) * 2.5
	return weighted_index(w)


func roll_item_id(rarity: int, theme: String) -> String:
	var pool := []
	var weights := []
	for id in Data.ITEM_ORDER:
		var d: Dictionary = Data.ITEMS[id]
		if int(d["r"]) == rarity:
			pool.append(id)
			weights.append(4.0 if str(d["cat"]) == theme else 1.0)
	if pool.is_empty():
		return "rusty_wrench"
	return str(pool[weighted_index(weights)])


func roll_condition() -> float:
	if rng.randf() < 0.05:
		return 1.0
	return snappedf(0.15 + 0.8 * pow(rng.randf(), 1.2), 0.01)


func make_lot(tier: int) -> Dictionary:
	var a: Dictionary = Data.auction(tier)
	var kinds: Array = a["boxes"]
	var kind := str(kinds[rng.randi() % kinds.size()])
	var golden := kind == "golden" or rng.randf() < 0.02
	if golden:
		kind = "golden"
	var range_n: Array = a["items"]
	var n := rng.randi_range(int(range_n[0]), int(range_n[1]))
	if golden:
		n = maxi(n, 4)
	var theme := ""
	if rng.randf() < 0.65:
		theme = str(Data.CATEGORIES[rng.randi() % Data.CATEGORIES.size()])
	var contents := []
	var value := 0
	var best := 0
	for i in range(n):
		var r := roll_rarity(tier, golden)
		var id := roll_item_id(r, theme)
		var c := roll_condition()
		contents.append({"id": id, "cond": c})
		value += base_value(id, c)
		best = maxi(best, r)
	var spread: float = SCANNER_SPREAD[clampi(upgrade_level("scanner"), 0, 4)]
	var center := float(value) * rng.randf_range(1.0 - spread * 0.6, 1.0 + spread * 0.6)
	var peek := ""
	if upgrade_level("scanner") >= 4:
		peek = str(contents[rng.randi() % contents.size()]["id"])
	return {"kind": kind, "tier": tier, "items": contents, "value": value, "count": n, "theme": theme,
		"best": best, "peek": peek, "golden": golden,
		"low": nice_round(center * (1.0 - spread)), "high": nice_round(center * (1.0 + spread)),
		"start": maxi(1, nice_round(center * rng.randf_range(0.22, 0.36)))}


func add_box(lot: Dictionary, price: int) -> void:
	var contents: Array = lot["items"]
	boxes.append({"uid": _uid(), "kind": str(lot["kind"]), "tier": int(lot["tier"]), "paid": price,
		"items": contents.duplicate(true), "secret": rng.randf() < 0.06})
	stats["won"] = int(stats["won"]) + 1
	request_save()
	state_changed.emit()


func box_index(uid: int) -> int:
	for i in range(boxes.size()):
		if int(boxes[i]["uid"]) == uid:
			return i
	return -1


func open_box(uid: int) -> Dictionary:
	var idx := box_index(uid)
	if idx < 0:
		return {}
	var b: Dictionary = boxes[idx]
	boxes.remove_at(idx)
	var src: Array = b["items"]
	var contents := src.duplicate(true)
	var bonus := bool(b.get("secret", false))
	if bonus:
		var r := maxi(1, roll_rarity(int(b["tier"]), true))
		contents.append({"id": roll_item_id(r, ""), "cond": roll_condition()})
	var share := int(int(b["paid"]) / maxi(1, contents.size()))
	var out := []
	for c in contents:
		var id := str(c["id"])
		var cond := float(c["cond"])
		var res := {"id": id, "cond": cond, "uid": 0, "pawned": 0, "new": not found.has(id)}
		if not found.has(id):
			found[id] = 0
		var r: int = Data.rarity_of(id)
		if r == 2:
			stats["rare"] = int(stats["rare"]) + 1
		elif r == 3:
			stats["epic"] = int(stats["epic"]) + 1
		elif r == 4:
			stats["legendary"] = int(stats["legendary"]) + 1
		if items.size() < capacity():
			var it := {"uid": _uid(), "id": id, "cond": cond, "paid": share, "fixed": 0}
			items.append(it)
			res["uid"] = it["uid"]
		else:
			var p := pawn_price({"id": id, "cond": cond})
			res["pawned"] = p
			add_money(p, true)
		out.append(res)
	stats["boxes"] = int(stats["boxes"]) + 1
	request_save()
	state_changed.emit()
	return {"items": out, "paid": int(b["paid"]), "kind": str(b["kind"]), "bonus": bonus}


# ------------------------------------------------------------------ items: repair and sale
func item_index(uid: int) -> int:
	for i in range(items.size()):
		if int(items[i]["uid"]) == uid:
			return i
	return -1


func get_item(uid: int) -> Dictionary:
	var i := item_index(uid)
	return items[i] if i >= 0 else {}


func pay_repair(uid: int) -> bool:
	var it := get_item(uid)
	if it.is_empty() or not can_repair(it):
		return false
	var cost := repair_cost(it)
	if not spend(cost):
		return false
	it["fixed"] = int(it.get("fixed", 0)) + cost
	return true


func finish_repair(uid: int, new_cond: float, perfects: int) -> void:
	var it := get_item(uid)
	if it.is_empty():
		return
	it["cond"] = snappedf(clampf(new_cond, 0.05, maxf(repair_cap(), float(it["cond"]))), 0.01)
	stats["repairs"] = int(stats["repairs"]) + 1
	stats["perfects"] = int(stats["perfects"]) + perfects
	add_xp(2 + perfects)
	request_save()
	state_changed.emit()


func sell_item(uid: int, price: int) -> int:
	var idx := item_index(uid)
	if idx < 0:
		return 0
	var it: Dictionary = items[idx]
	items.remove_at(idx)
	var id := str(it["id"])
	var profit := price - int(it.get("paid", 0)) - int(it.get("fixed", 0))
	stats["sold"] = int(stats["sold"]) + 1
	stats["profit"] = int(stats["profit"]) + profit
	stats["best_sale"] = maxi(int(stats["best_sale"]), price)
	found[id] = maxi(int(found.get(id, 0)), price)
	buyers_today.erase(str(uid))
	add_money(price, true)
	add_xp(xp_for_sale(price, profit))
	state_changed.emit()
	return profit


func pawn_item(uid: int) -> int:
	var it := get_item(uid)
	if it.is_empty():
		return 0
	var p := pawn_price(it)
	sell_item(uid, p)
	return p


func buyer_mult() -> float:
	var m := 1.0 + float(upgrade_val("showroom")) / 100.0
	if str(event.get("id", "")) == "sale_day":
		m *= 1.15
	return m


func buyer_patience() -> int:
	var lvl := upgrade_level("showroom")
	return 3 + (1 if lvl >= 2 else 0) + (1 if lvl >= 4 else 0)


func max_buyers() -> int:
	return 3 + (1 if upgrade_level("showroom") >= 3 else 0)


func buyers_left(uid: int) -> int:
	return maxi(0, max_buyers() - int(buyers_today.get(str(uid), 0)))


func use_buyer(uid: int) -> void:
	buyers_today[str(uid)] = int(buyers_today.get(str(uid), 0)) + 1
	request_save()


# ------------------------------------------------------------------ upgrades
func upgrade_cost(id: String) -> int:
	var u: Dictionary = Data.upgrade(id)
	return nice_round(float(u["base"]) * pow(2.6, float(upgrade_level(id))))


func can_upgrade(id: String) -> bool:
	var u: Dictionary = Data.upgrade(id)
	return upgrade_level(id) < int(u["max"])


func buy_upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	if not spend(upgrade_cost(id)):
		return false
	upgrades[id] = upgrade_level(id) + 1
	add_xp(10 + 5 * upgrade_level(id))
	request_save()
	state_changed.emit()
	return true


func garage_level() -> int:
	var s := 1
	for k in upgrades.keys():
		s += int(upgrades[k])
	return s


# ------------------------------------------------------------------ auctions
func auction_unlocked(tier: int) -> bool:
	return level >= int(Data.auction(tier)["rep"])


func auction_fee(tier: int) -> int:
	if str(event.get("id", "")) == "free_entry":
		return 0
	return int(Data.auction(tier)["fee"])


func lots_per_auction() -> int:
	return upgrade_val("truck")


func rival_count(tier: int) -> int:
	var n := int(Data.auction(tier)["count"])
	if str(event.get("id", "")) == "rain":
		n -= 1
	return maxi(1, n)


func rival_bonus() -> float:
	return 1.12 if str(event.get("id", "")) == "bidding_war" else 1.0


func pick_rivals(tier: int) -> Array:
	var pool: Array = Data.auction(tier)["rivals"]
	var p := pool.duplicate()
	for i in range(p.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = p[i]
		p[i] = p[j]
		p[j] = t
	return p.slice(0, mini(rival_count(tier), p.size()))


# ------------------------------------------------------------------ days and events
func end_day() -> void:
	day += 1
	buyers_today = {}
	stats["auctions"] = int(stats["auctions"]) + 1
	_roll_trends()
	_roll_event()
	if money < 25 and items.is_empty() and boxes.is_empty():
		# never leave the player stuck: Uncle Lou helps out
		event = {"id": "lou_help", "amount": 100}
		add_money(100)
	pending_event = not event.is_empty()
	request_save()
	state_changed.emit()


func _roll_trends() -> void:
	trends = {}
	var cats := Data.CATEGORIES.duplicate()
	for i in range(cats.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cats[i]
		cats[i] = cats[j]
		cats[j] = t
	trends[str(cats[0])] = snappedf(rng.randf_range(1.2, 1.5), 0.05)
	trends[str(cats[1])] = snappedf(rng.randf_range(1.1, 1.3), 0.05)
	trends[str(cats[2])] = snappedf(rng.randf_range(0.7, 0.85), 0.05)


func _roll_event() -> void:
	event = {}
	if day <= 2 or rng.randf() > 0.5:
		return
	var keys: Array = Data.EVENTS.keys()
	var w := []
	for k in keys:
		w.append(float(Data.EVENTS[k]))
	apply_event(str(keys[weighted_index(w)]))


## Starts today's event and applies its immediate effect (also used by the automated tests).
func apply_event(id: String) -> void:
	event = {"id": id}
	match id:
		"collector":
			event["cat"] = str(Data.CATEGORIES[rng.randi() % Data.CATEGORIES.size()])
		"found_cash":
			var amount := clampi(int(money * 0.05), 20, 500)
			event["amount"] = amount
			add_money(amount)
		"leak":
			if items.is_empty():
				event = {}
			elif upgrade_level("shelves") >= 3:
				event["protected"] = true
			else:
				var it: Dictionary = items[rng.randi() % items.size()]
				it["cond"] = snappedf(maxf(0.05, float(it["cond"]) - 0.15), 0.01)
				event["item"] = str(it["id"])
		"tv":
			var x := 15 + level * 8
			event["xp"] = x
			add_xp(x)
		"ticket":
			var fine := mini(money, clampi(int(money * 0.03), 10, 150))
			if fine <= 0:
				event = {}
			else:
				event["amount"] = fine
				spend(fine)
		"stranger":
			if items.is_empty():
				event = {}
			else:
				var it2: Dictionary = items[rng.randi() % items.size()]
				event["uid"] = int(it2["uid"])
				event["item"] = str(it2["id"])
				event["offer"] = maxi(2, roundi(float(market_value(it2)) * rng.randf_range(1.4, 1.8)))


func accept_stranger() -> bool:
	if str(event.get("id", "")) != "stranger":
		return false
	var uid := int(event.get("uid", -1))
	if item_index(uid) < 0:
		return false
	sell_item(uid, int(event.get("offer", 0)))
	event["done"] = true
	return true


# ------------------------------------------------------------------ goals and collection
func goal_progress(g: Dictionary) -> int:
	match str(g["kind"]):
		"boxes":
			return int(stats["boxes"])
		"sold":
			return int(stats["sold"])
		"repairs":
			return int(stats["repairs"])
		"earned":
			return int(stats["earned"])
		"level":
			return level
		"rare":
			return int(stats["rare"]) + int(stats["epic"]) + int(stats["legendary"])
		"epic":
			return int(stats["epic"]) + int(stats["legendary"])
		"legendary":
			return int(stats["legendary"])
		"found":
			return found.size()
	return 0


func goal_ready(g: Dictionary) -> bool:
	return not goals_done.has(str(g["id"])) and goal_progress(g) >= int(g["n"])


func claimable_goals() -> int:
	var n := 0
	for g in Data.GOALS:
		if goal_ready(g):
			n += 1
	return n


func claim_goal(id: String) -> int:
	var g: Dictionary = Data.goal(id)
	if not goal_ready(g):
		return 0
	goals_done.append(id)
	var reward := int(g["reward"])
	add_money(reward)
	request_save()
	state_changed.emit()
	return reward


func hint_once(key: String) -> bool:
	if hints.has(key):
		return false
	hints[key] = true
	request_save()
	return true


func buzz(ms: int = 25) -> void:
	if bool(settings.get("vibrate", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
