extends Node
## Game state: career, money, purchases, current job, records, settings.
## Every change that matters is written to disk in one atomic save
## (temp file + rename), so money and the matching completion flag or
## purchase always land together.

signal changed
signal balance_changed(value: int)

const SAVE_VERSION := 1
const MOPED := ["m_headlight", "m_mirror", "m_speedo", "m_fender"]
const MOTO := ["b_turn", "b_horn", "b_kickstand", "b_case"]
const CAR := ["c_wiper", "c_glovebox", "c_dash", "c_window"]
const FINAL := ["f_light", "f_wiper", "f_dash"]
const DECOR := ["decor_lamp", "decor_cabinet", "decor_gate"]

var data: Dictionary = {}
var orders: Dictionary = {}        # id -> order dict (regular + final stages)
var order_ids: Array = []          # the 12 regular ids, in career order
var state: Dictionary = {}
var save_path := "user://garage_save.json"
var rng := RandomNumberGenerator.new()
var save_count := 0                # for tests: how many times the file was written


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save="):
			save_path = a.substr(7)
	_load_data()
	load_game()


func _load_data() -> void:
	var f := FileAccess.open("res://data/orders.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	for o in data["orders"]:
		orders[o["id"]] = o
		order_ids.append(o["id"])
	var fin: Dictionary = data["final"]
	for st in fin["stages"]:
		var o: Dictionary = st.duplicate(true)
		o["vehicle"] = fin["vehicle"]
		o["client"] = fin["client"]
		o["paint"] = fin["paint"]
		o["final"] = true
		orders[o["id"]] = o


# ------------------------------------------------------------------ state

func default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"started": false,
		"balance": 0,
		"owned": {},
		"done": {},            # order id -> times completed
		"records": {},         # order id -> best seconds
		"final_done": [],
		"sign": false,
		"credits_pending": false,
		"final_arrived": false,
		"free_play": false,
		"photo": false,
		"gate_new_color": false,
		"current": null,
		"last_result": null,
		"job_seq": 0,
		"paid": [],            # uids already paid (idempotency)
		"free_queue": [],
		"last_free": "",
		"last_vehicle": "",
		"tutorial": {},
		"settings": {"sound": true, "vibration": true, "music": true},
		"stats": {"jobs": 0, "earned": 0, "tips": 0},
	}


func load_game() -> void:
	state = default_state()
	var loaded = _read_json(save_path)
	if loaded == null:
		loaded = _read_json(save_path + ".bak")
	if typeof(loaded) == TYPE_DICTIONARY:
		for k in loaded.keys():
			state[k] = loaded[k]
		# keep nested defaults that older saves may lack
		var defs := default_state()
		for k in ["settings", "stats"]:
			for kk in defs[k].keys():
				if not state[k].has(kk):
					state[k][kk] = defs[k][kk]
	state["balance"] = int(state["balance"])
	state["job_seq"] = int(state["job_seq"])
	emit_signal("changed")


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	var res = JSON.parse_string(txt)
	if typeof(res) != TYPE_DICTIONARY:
		return null
	return res


func save() -> void:
	var txt := JSON.stringify(state, "\t")
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save: %s" % tmp)
		return
	f.store_string(txt)
	f.flush()
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		# fallback: direct write
		var f2 := FileAccess.open(save_path, FileAccess.WRITE)
		f2.store_string(txt)
		f2.close()
	save_count += 1


func reset_progress() -> void:
	var keep: Dictionary = state["settings"].duplicate()
	state = default_state()
	state["settings"] = keep
	save()
	emit_signal("changed")
	emit_signal("balance_changed", 0)


func has_progress() -> bool:
	return bool(state.get("started", false))


func setting(key: String) -> bool:
	return bool(state["settings"].get(key, true))


func set_setting(key: String, v: bool) -> void:
	state["settings"][key] = v
	save()
	emit_signal("changed")


func tutorial_seen(key: String) -> bool:
	return bool(state["tutorial"].get(key, false))


func mark_tutorial(key: String) -> void:
	if tutorial_seen(key):
		return
	state["tutorial"][key] = true
	save()


# ------------------------------------------------------------------ money

func balance() -> int:
	return int(state["balance"])


func price(item: String) -> int:
	return int(data["prices"][item])


func owns(item: String) -> bool:
	return bool(state["owned"].get(item, false))


func item_name(item: String) -> String:
	return data["items"][item]["name"]


func item_unlocked(item: String) -> bool:
	match item:
		"stand":
			return true
		"lift":
			return count_done(MOTO) >= 4
		_:
			return bool(state["sign"]) and not bool(state["credits_pending"])


func can_buy(item: String) -> bool:
	return item_unlocked(item) and not owns(item) and balance() >= price(item)


## Payment and handing over the item happen in one write.
## A second call (double tap, replay after restart) changes nothing.
func buy(item: String) -> bool:
	if not can_buy(item):
		return false
	state["balance"] = balance() - price(item)
	state["owned"][item] = true
	if item == "decor_gate":
		state["gate_new_color"] = true
	save()
	emit_signal("balance_changed", balance())
	emit_signal("changed")
	return true


func toggle_gate_color() -> void:
	if owns("decor_gate"):
		state["gate_new_color"] = not bool(state["gate_new_color"])
		save()
		emit_signal("changed")


static func tip_for(elapsed: float, target: float, tip_max: int = 30) -> int:
	if elapsed <= target:
		return tip_max
	if elapsed >= target * 2.0:
		return 0
	var k := 1.0 - (elapsed - target) / target
	return int(round(tip_max * k))


# ------------------------------------------------------------------ career

func is_done(id: String) -> bool:
	return int(state["done"].get(id, 0)) > 0


func count_done(ids: Array) -> int:
	var n := 0
	for id in ids:
		if is_done(id):
			n += 1
	return n


func regular_done_count() -> int:
	return count_done(order_ids)


func all_regular_done() -> bool:
	return regular_done_count() >= order_ids.size()


func final_done_list() -> Array:
	return state["final_done"]


func final_complete() -> bool:
	return final_done_list().size() >= FINAL.size()


func order_available(id: String) -> bool:
	var o: Dictionary = orders[id]
	if o.get("final", false):
		return all_regular_done() and not final_done_list().has(id)
	if o.has("requires") and not owns(o["requires"]):
		return false
	if MOTO.has(id) and count_done(MOPED) < 4:
		return false
	if CAR.has(id) and count_done(MOTO) < 4:
		return false
	return true


## Next client during the career: always an order not yet completed, so the
## career never needs grinding or waiting for a random visitor.
func next_career_order() -> String:
	if bool(state["credits_pending"]):
		return ""
	if all_regular_done():
		if not final_complete():
			return "final"
		return ""
	for id in order_ids:
		if not is_done(id) and order_available(id):
			return id
	return ""


func career_stage() -> int:
	if bool(state["free_play"]):
		return 5
	if all_regular_done():
		return 4
	if count_done(MOTO) >= 4:
		return 3
	if count_done(MOPED) >= 4:
		return 2
	return 1


## What the garage shows as the player's goal: {text, item, need}
func goal() -> Dictionary:
	if bool(state["free_play"]):
		var missing := ""
		for d in DECOR:
			if not owns(d):
				missing = d
				break
		if missing != "":
			var need := price(missing) - balance()
			if need > 0:
				return {"text": "%s — ще %d" % [item_name(missing), need], "item": missing, "need": need}
			return {"text": "%s — можна купити!" % item_name(missing), "item": missing, "need": 0}
		return {"text": "Майстерня відкрита · рекорди на дошці", "item": "", "need": 0}
	if bool(state["credits_pending"]):
		return {"text": "Гараж на розі!", "item": "", "need": 0}
	var stage := career_stage()
	if stage == 1:
		if not owns("stand"):
			var need := price("stand") - balance()
			if need > 0:
				return {"text": "Ремонтна стійка — ще %d" % need, "item": "stand", "need": need}
			return {"text": "Ремонтна стійка — можна купити!", "item": "stand", "need": 0}
		return {"text": "Мопеди: %d з 4" % count_done(MOPED), "item": "", "need": 0}
	if stage == 2:
		return {"text": "Мотоцикли: %d з 4" % count_done(MOTO), "item": "", "need": 0}
	if stage == 3:
		if not owns("lift"):
			var need := price("lift") - balance()
			if need > 0:
				return {"text": "Підйомник — ще %d" % need, "item": "lift", "need": need}
			return {"text": "Підйомник — можна купити!", "item": "lift", "need": 0}
		return {"text": "Автомобіль: %d з 4" % count_done(CAR), "item": "", "need": 0}
	return {"text": "Останній клієнт: %d з 3" % final_done_list().size(), "item": "", "need": 0}


# ------------------------------------------------------------------ jobs

func current() -> Variant:
	return state["current"]


func has_client() -> bool:
	return state["current"] != null


## A client arrives with an order. kind: career | free | final
func open_job(order_id: String, kind: String) -> Dictionary:
	if state["current"] != null:
		return state["current"]
	state["job_seq"] = int(state["job_seq"]) + 1
	var job := {
		"uid": int(state["job_seq"]),
		"order": order_id,
		"kind": kind,
		"phase": "waiting",
		"step": "diagnose",
		"found": [],
		"elapsed": 0.0,
		"started": false,
	}
	state["current"] = job
	state["started"] = true
	if kind == "free":
		state["last_free"] = order_id
	state["last_vehicle"] = orders[order_id]["vehicle"]
	save()
	emit_signal("changed")
	return job


## Final: the wagon stays while its three stages are done one by one.
func open_final_stage(stage_id: String) -> Dictionary:
	if state["current"] != null:
		return state["current"]
	if final_done_list().has(stage_id):
		return {}
	return open_job(stage_id, "final")


func update_job(fields: Dictionary, write := true) -> void:
	if state["current"] == null:
		return
	for k in fields.keys():
		state["current"][k] = fields[k]
	if write:
		save()


func cancel_job() -> void:
	# The client leaves without a repair (used only in free play from the board).
	state["current"] = null
	save()
	emit_signal("changed")


## Pays once per job uid. Base pay is guaranteed for any duration; tips fall
## from 30 at the target time to 0 at double the target.
func complete_job(uid: int, elapsed: float) -> Dictionary:
	if state["paid"].has(uid):
		return {}
	var job = state["current"]
	if job == null or int(job["uid"]) != uid:
		return {}
	var id: String = job["order"]
	var o: Dictionary = orders[id]
	var base := int(data["base_pay"])
	var tip := tip_for(elapsed, float(o["target"]), int(data["tip_max"]))
	var prev_best := float(state["records"].get(id, 0.0))
	var record := prev_best <= 0.0 or elapsed < prev_best
	if record:
		state["records"][id] = snappedf(elapsed, 0.1)
	var first_time := not is_done(id)
	state["done"][id] = int(state["done"].get(id, 0)) + 1
	state["balance"] = balance() + base + tip
	state["paid"].append(uid)
	if state["paid"].size() > 64:
		state["paid"] = state["paid"].slice(state["paid"].size() - 64)
	state["stats"]["jobs"] = int(state["stats"]["jobs"]) + 1
	state["stats"]["earned"] = int(state["stats"]["earned"]) + base + tip
	state["stats"]["tips"] = int(state["stats"]["tips"]) + tip
	var events: Array = []
	if job["kind"] == "final":
		if not state["final_done"].has(id):
			state["final_done"].append(id)
		if final_complete():
			state["sign"] = true
			state["credits_pending"] = true
			events.append("finale")
	else:
		if first_time and MOTO.has(id) and not bool(state["photo"]):
			state["photo"] = true
			events.append("photo")
		if first_time and MOPED.has(id) and count_done(MOPED) == 4:
			events.append("moto_unlocked")
		if first_time and MOTO.has(id) and count_done(MOTO) == 4:
			events.append("lift_unlocked")
		if first_time and CAR.has(id) and count_done(CAR) == 4:
			events.append("final_unlocked")
	var result := {
		"uid": uid, "order": id, "kind": job["kind"], "base": base, "tip": tip,
		"elapsed": snappedf(elapsed, 0.1), "target": float(o["target"]),
		"record": record and prev_best > 0.0, "first": first_time, "events": events,
		"seen": false,
	}
	state["last_result"] = result
	state["current"] = null
	save()
	emit_signal("balance_changed", balance())
	emit_signal("changed")
	return result


func dismiss_result() -> void:
	if state["last_result"] != null:
		state["last_result"]["seen"] = true
		save()
		emit_signal("changed")


func pending_result() -> Variant:
	var r = state["last_result"]
	if r != null and not bool(r.get("seen", true)):
		return r
	return null


func finish_credits() -> void:
	if not bool(state["credits_pending"]):
		return
	state["credits_pending"] = false
	state["final_arrived"] = false
	state["free_play"] = true
	state["free_queue"] = []
	save()
	emit_signal("changed")


# ------------------------------------------------------------------ free play

func free_pool() -> Array:
	var pool: Array = []
	for id in order_ids:
		if is_done(id):
			pool.append(id)
	return pool


## Queue of upcoming clients: vehicles alternate, one breakdown never twice in a row.
func refill_free_queue() -> void:
	var q: Array = state["free_queue"]
	var pool := free_pool()
	if pool.is_empty():
		return
	var guard := 0
	while q.size() < 3 and guard < 50:
		guard += 1
		var last_id: String = q[-1] if q.size() > 0 else String(state["last_free"])
		var last_v: String = orders[last_id]["vehicle"] if last_id != "" and orders.has(last_id) else String(state["last_vehicle"])
		var cands: Array = []
		for id in pool:
			if id == last_id:
				continue
			if orders[id]["vehicle"] != last_v:
				cands.append(id)
		if cands.is_empty():
			for id in pool:
				if id != last_id:
					cands.append(id)
		if cands.is_empty():
			cands = pool.duplicate()
		q.append(cands[rng.randi_range(0, cands.size() - 1)])
	state["free_queue"] = q


func peek_free_queue() -> Array:
	refill_free_queue()
	return state["free_queue"]


func next_free_order() -> String:
	refill_free_queue()
	var q: Array = state["free_queue"]
	if q.is_empty():
		return ""
	var id: String = q.pop_front()
	state["free_queue"] = q
	refill_free_queue()
	return id


func client_info(id: String) -> Dictionary:
	return data["clients"][id]


func order(id: String) -> Dictionary:
	return orders[id]
