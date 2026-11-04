class_name EventDirector
extends RefCounted
## Random in-shift events. Rule-changing events (calendar, mirror) are always
## announced, start only between parcels and refresh the queue, so the player
## is never judged by a rule they could not see.

const DEFS := {
	"golden": {"unlock": "ev_golden", "dur": 12.0, "weight": 1.0, "rule": false},
	"calendar": {"unlock": "ev_calendar", "dur": 18.0, "weight": 0.9, "rule": true},
	"cat": {"unlock": "ev_cat", "dur": 6.0, "weight": 0.6, "rule": false},
	"mirror": {"unlock": "ev_mirror", "dur": 14.0, "weight": 0.8, "rule": true},
	"storm": {"unlock": "ev_storm", "dur": 14.0, "weight": 0.7, "rule": false},
}

var rng := RandomNumberGenerator.new()
var unlocked := {}
var active := {}            # {"id", "time_left", "data"}
var next_in := 30.0
var stabilizer := false
var cat_mult := 1.0
var enabled := true


func setup(p_seed: int, p_unlocked: Dictionary, p_stabilizer: bool, p_cat_mult: float) -> void:
	rng.seed = p_seed
	unlocked = p_unlocked
	stabilizer = p_stabilizer
	cat_mult = p_cat_mult
	next_in = rng.randf_range(18.0, 28.0)


func available() -> Array:
	var out := []
	for id in DEFS:
		if unlocked.has(DEFS[id]["unlock"]):
			out.append(id)
	return out


func is_active(id: String) -> bool:
	return not active.is_empty() and active["id"] == id


## Advances timers. Returns "ended:<id>" when an event finishes, "due" when a
## new event may start at the next parcel boundary, or "".
func tick(delta: float) -> String:
	if not active.is_empty():
		active["time_left"] = float(active["time_left"]) - delta
		if float(active["time_left"]) <= 0.0:
			var id: String = active["id"]
			active = {}
			next_in = rng.randf_range(22.0, 38.0)
			return "ended:" + id
		return ""
	if not enabled or available().is_empty():
		return ""
	next_in -= delta
	return "due" if next_in <= 0.0 else ""


func start_random(rules: Dictionary) -> Dictionary:
	var pool := available()
	if pool.is_empty():
		next_in = 999.0
		return {}
	var total := 0.0
	var weights := []
	for id in pool:
		var w: float = DEFS[id]["weight"]
		if id == "cat":
			w *= cat_mult
		weights.append(w)
		total += w
	var r := rng.randf() * total
	var pick: String = pool[0]
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0:
			pick = pool[i]
			break
	return start(pick, rules)


func start(id: String, rules: Dictionary) -> Dictionary:
	var d: Dictionary = DEFS[id]
	var dur: float = d["dur"]
	if stabilizer:
		dur *= 0.7 if d["rule"] else 1.3
	var data := {}
	if id == "calendar":
		var off := rng.randi_range(4, 19) * (1 if rng.randf() < 0.5 else -1)
		data["present_year"] = Rules.BASE_YEAR + off
		rules["present_year"] = data["present_year"]
	elif id == "mirror":
		rules["mirrored"] = true
	active = {"id": id, "time_left": dur, "dur": dur, "data": data}
	return active


func stop_rules(id: String, rules: Dictionary) -> void:
	if id == "calendar":
		rules["present_year"] = Rules.BASE_YEAR
	elif id == "mirror":
		rules["mirrored"] = false


func coin_mult() -> float:
	if is_active("golden"):
		return 2.0
	if is_active("storm"):
		return 1.5
	return 1.0


func score_mult() -> float:
	return 2.0 if is_active("storm") else 1.0
