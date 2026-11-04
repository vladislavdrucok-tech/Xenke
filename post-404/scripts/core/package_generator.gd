class_name PackageGenerator
extends RefCounted
## Rule-based parcel generator. It first decides what the parcel must teach or
## test (destination, modifier), then builds a label that makes that answer
## deducible, and finally verifies fairness with Rules.is_fair().

var rng := RandomNumberGenerator.new()
var level := 1
var unlocked := {}
var routes: Array = ["town"]
var characters: Array = []          # met characters that may send parcels
var owned_collectibles: Dictionary = {}
var collect_mult := 1.0
var mode := "shift"
var parcels_made := 0
var scripted: Array = []            # tutorial: parcels returned first, in order
var allow_modifiers := true

var _history: Array = []
var _next_id := 1
var _series_left := 0
var _series_id := ""
var _series_len := 0
var _series_style := ""
var _series_sender := ""
var _series_counter := 0


func setup(p_seed: int, p_level: int, p_routes: Array, p_mode: String = "shift") -> void:
	rng.seed = p_seed
	level = p_level
	unlocked = Progression.unlocked_set(level)
	routes = p_routes.duplicate()
	if routes.is_empty():
		routes = ["town"]
	mode = p_mode


func has(mech: String) -> bool:
	return unlocked.has(mech)


func next_parcel(rules: Dictionary) -> Dictionary:
	if not scripted.is_empty():
		var s: Dictionary = scripted.pop_front()
		s["id"] = _next_id
		_next_id += 1
		_finish(s, rules)
		return s
	for _attempt in 12:
		var p := _build(rules)
		if Rules.is_fair(p, rules):
			_remember(Rules.judge(p, rules))
			parcels_made += 1
			return p
	# Fallback that is always fair: a plain parcel with a full year.
	var safe := _plain(Rules.Dest.PAST, rules)
	_remember(Rules.Dest.PAST)
	parcels_made += 1
	return safe


func difficulty() -> float:
	return Progression.difficulty(level, parcels_made)


# ---------------------------------------------------------------- internals

func _remember(dest: int) -> void:
	_history.append(dest)
	if _history.size() > 6:
		_history.pop_front()


func _pick_dest(rules: Dictionary) -> int:
	var options := {Rules.Dest.PAST: 1.0, Rules.Dest.FUTURE: 1.0}
	if has("present"):
		options[Rules.Dest.PRESENT] = 0.55
	# Anti-streak: the same answer three times in a row is rare, four never.
	var n := _history.size()
	if n >= 2 and _history[n - 1] == _history[n - 2]:
		var last: int = _history[n - 1]
		if options.has(last):
			options[last] *= 0.25
			if n >= 3 and _history[n - 3] == last:
				options.erase(last)
	var total := 0.0
	for k in options:
		total += options[k]
	var r := rng.randf() * total
	for k in options:
		r -= options[k]
		if r <= 0.0:
			return k
	return options.keys()[0]


func _year_for(dest: int, rules: Dictionary) -> int:
	var present: int = rules["present_year"]
	if dest == Rules.Dest.PRESENT:
		return present
	var near_chance := 0.15 + 0.35 * difficulty()
	if present != Rules.BASE_YEAR:
		near_chance = 0.55   # calendar shift: test the new boundary
	if rng.randf() < near_chance:
		var off := rng.randi_range(1, 4 if difficulty() < 0.5 else 2)
		return present - off if dest == Rules.Dest.PAST else present + off
	var key := "past" if dest == Rules.Dest.PAST else "future"
	var ranges := []
	for r in routes:
		var rr: Array = Content.ROUTES[r][key]
		if not rr.is_empty():
			ranges.append(rr)
	var yr: Array = ranges[rng.randi() % ranges.size()]
	var lo: int = yr[0]
	var hi: int = yr[1]
	# Keep the year on the correct side of a shifted calendar.
	if dest == Rules.Dest.PAST:
		hi = min(hi, present - 1)
	else:
		lo = max(lo, present + 1)
	if lo > hi:
		return present - rng.randi_range(1, 30) if dest == Rules.Dest.PAST else present + rng.randi_range(1, 30)
	return rng.randi_range(lo, hi)


func _plain(dest: int, rules: Dictionary) -> Dictionary:
	var year := _year_for(dest, rules)
	var p := {
		"id": _next_id, "year": year, "shown": str(year), "box": Content.BOX_STYLES[rng.randi() % Content.BOX_STYLES.size()],
		"hazard": false, "riddle": "", "riddle_dest": -1, "old_year": 0, "urgent": false,
		"series": "", "series_idx": 0, "series_len": 0, "sender": "", "collectible": "",
		"damaged": false, "seed": rng.randi() % 1000,
	}
	_next_id += 1
	return p


func _build(rules: Dictionary) -> Dictionary:
	var dest := _pick_dest(rules)
	var shifted := int(rules["present_year"]) != Rules.BASE_YEAR
	var d := difficulty()
	var p: Dictionary

	# Hazards replace the normal destination entirely.
	if allow_modifiers and has("hazard") and rng.randf() < 0.05 + 0.03 * d:
		p = _plain(_pick_dest(rules), rules)
		p["hazard"] = true
		p["box"] = "hazard"
		_finish(p, rules)
		return p

	p = _plain(dest, rules)
	var special := false
	if allow_modifiers:
		if has("mystery") and not shifted and rng.randf() < 0.07 + 0.04 * d:
			var ids := Content.riddle_ids_for(dest)
			if not ids.is_empty():
				p["riddle"] = ids[rng.randi() % ids.size()]
				p["riddle_dest"] = dest
				p["shown"] = "????"
				p["box"] = "mystery"
				special = true
		if not special and has("paradox") and dest != Rules.Dest.PRESENT and rng.randf() < 0.06 + 0.04 * d:
			var other := Rules.Dest.FUTURE if dest == Rules.Dest.PAST else Rules.Dest.PAST
			p["old_year"] = _year_for(other, rules)
			if p["old_year"] == p["year"]:
				p["old_year"] = 0
			else:
				special = true
		if not special and has("damaged") and dest != Rules.Dest.PRESENT and rng.randf() < 0.12 + 0.12 * d:
			var mask := _find_mask(p, rules)
			if mask != "":
				p["shown"] = mask
				p["damaged"] = true
				special = true
		if has("urgent") and rng.randf() < 0.10 + 0.05 * d:
			p["urgent"] = true
		if not characters.is_empty() and rng.randf() < 0.06:
			p["sender"] = characters[rng.randi() % characters.size()]
			if p["box"] != "mystery":
				p["box"] = {"olena": "paper", "kai": "metal", "vera": "crate", "future": "tube"}.get(p["sender"], p["box"])
		if has("collectibles") and p["riddle"] == "" and rng.randf() < 0.022 * collect_mult:
			var c := _pick_collectible()
			if c != "":
				p["collectible"] = c
				p["box"] = "gold"
		_apply_series(p)
		if has("boomerang") and mode != "record" and p["series"] == "" and rng.randf() < 0.05:
			p["boomerang"] = true
	_finish(p, rules)
	return p


func _apply_series(p: Dictionary) -> void:
	if _series_left > 0:
		_series_left -= 1
		p["series"] = _series_id
		p["series_len"] = _series_len
		p["series_idx"] = _series_len - _series_left
		if p["box"] in Content.BOX_STYLES:
			p["box"] = _series_style
		if _series_sender != "":
			p["sender"] = _series_sender
		return
	if has("series") and mode != "record" and rng.randf() < 0.05:
		_series_counter += 1
		_series_id = ["A", "B", "C", "D", "E", "F", "G", "H"][_series_counter % 8]
		_series_len = 3
		_series_left = 2
		_series_style = Content.BOX_STYLES[rng.randi() % Content.BOX_STYLES.size()]
		_series_sender = p["sender"]
		p["series"] = _series_id
		p["series_len"] = 3
		p["series_idx"] = 1
		if p["box"] in Content.BOX_STYLES:
			p["box"] = _series_style


## A label with 1–2 smudged digits that still has exactly one answer.
func _find_mask(p: Dictionary, rules: Dictionary) -> String:
	var y := str(p["year"])
	if y.length() != 4:
		return ""
	var candidates := []
	for i in range(1, 4):
		candidates.append([i])
	if difficulty() > 0.35:
		candidates.append([2, 3])
		candidates.append([1, 3])
	# Deterministic shuffle with our own RNG for reproducible sessions.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = t
	for c in candidates:
		var m := y
		for idx in c:
			m[idx] = "?"
		var ds := Rules.dests_for_pattern(m, int(rules["present_year"]))
		if ds.size() == 1 and int(ds[0]) == Rules.judge(p, rules):
			return m
	return ""


func _pick_collectible() -> String:
	var pool := []
	var weights := []
	for id in Content.COLLECTIBLE_ORDER:
		var c: Dictionary = Content.COLLECTIBLES[id]
		if int(c["rarity"]) >= 3:
			continue
		var w := 3.0 if int(owned_collectibles.get(id, 0)) == 0 else 1.0
		if int(c["rarity"]) == 2:
			w *= 0.45
		pool.append(id)
		weights.append(w)
	if pool.is_empty():
		return ""
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


func _finish(p: Dictionary, _rules: Dictionary) -> void:
	for k in ["hazard", "riddle", "riddle_dest", "old_year", "urgent", "series", "series_idx", "series_len",
			"sender", "collectible", "damaged", "box", "seed", "boomerang", "returned"]:
		if not p.has(k):
			p[k] = {"hazard": false, "riddle": "", "riddle_dest": -1, "old_year": 0, "urgent": false,
				"series": "", "series_idx": 0, "series_len": 0, "sender": "", "collectible": "",
				"damaged": false, "box": "cardboard", "seed": 0, "boomerang": false, "returned": false}[k]
	if not p.has("shown"):
		p["shown"] = str(p["year"])


## Fixed parcels for the first, guided shift.
static func tutorial_script() -> Array:
	return [
		{"year": 1998, "box": "cardboard", "tip": "tut_past"},
		{"year": 2077, "box": "metal", "tip": "tut_future"},
		{"year": 1961, "box": "paper"},
		{"year": 2040, "box": "crate", "tip": "tut_close"},
		{"year": 2036, "box": "envelope"},
		{"year": 2101, "box": "tube"},
		{"year": 1887, "box": "crate"},
		{"year": 2052, "box": "cardboard"},
	]
