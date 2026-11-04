class_name ShiftSession
extends RefCounted
## Core game loop of one shift, independent of rendering so it can be tested
## headless. The UI calls update(delta) every frame and sort(dir) on a swipe.

signal parcel_ready(parcel: Dictionary)
signal parcel_sorted(result: Dictionary)
signal event_started(ev: Dictionary)
signal event_ended(id: String)
signal tip_requested(mech: String)
signal robot_action(kind: String, coins: int)
signal shift_over(summary: Dictionary)
signal queue_changed

const QUEUE_SIZE := 3

var mode := "shift"            # shift, calm, record, daily, tutorial
var stats: Dictionary = {}
var gen := PackageGenerator.new()
var events := EventDirector.new()
var rules := Rules.make()
var seen_tips: Dictionary = {}

var time_left := 0.0
var time_total := 0.0
var elapsed := 0.0
var reliability := 3
var max_reliability := 3
var combo := 0
var best_combo := 0
var score := 0
var coins := 0
var xp := 0
var shards := 0
var sorted_count := 0
var correct_count := 0
var mistakes := 0
var current: Dictionary = {}
var queue: Array = []
var lift_timer := 0.0
var parcel_time := 0.0
var paused := false
var over := false
var completed := false
var shield_ready := false
var free_mistake_ready := false
var found: Array = []
var series_state: Dictionary = {}
var series_done := 0
var friends: Dictionary = {}
var robot_timer := 0.0
var robot_sorted := 0
var daily_mutator := ""
var events_seen: Array = []
var hazards_done := 0
var boomerangs_done := 0
var events_count := 0


func setup(p_mode: String, profile: Dictionary, p_seed: int) -> void:
	mode = p_mode
	stats = Upgrades.stats(profile)
	seen_tips = {}
	for t in profile.get("seen_tips", []):
		seen_tips[t] = true
	var level := int(profile.get("level", 1))
	var routes: Array = profile.get("routes", ["town"])
	gen.setup(p_seed, level, routes, mode)
	gen.characters = profile.get("story", {}).get("met", []).filter(func(c): return c != "bit" and c != "oracle" and c != "quant")
	gen.owned_collectibles = profile.get("collection", {})
	gen.collect_mult = stats["collect_mult"]
	events.setup(p_seed + 7, gen.unlocked, stats["stabilizer"], stats["cat_mult"])
	max_reliability = int(stats["reliability"])
	reliability = max_reliability
	shield_ready = bool(stats["combo_shield"])
	free_mistake_ready = bool(stats["first_mistake_free"])
	match mode:
		"shift":
			time_total = float(stats["shift_time"])
		"daily":
			time_total = 60.0
			_setup_daily(p_seed)
		"record":
			max_reliability = 3
			reliability = 3
			time_total = 0.0
		"tutorial":
			time_total = 0.0
			gen.scripted = PackageGenerator.tutorial_script()
			gen.allow_modifiers = false
			events.enabled = false
		_:
			time_total = 0.0
	time_left = time_total
	lift_timer = 0.6
	_fill_queue()


func _setup_daily(p_seed: int) -> void:
	var options := ["mirror", "calendar", "rush", "mystery", "blackout", "boomerang"]
	daily_mutator = options[abs(p_seed) % options.size()]
	events.enabled = false
	match daily_mutator:
		"mirror":
			rules["mirrored"] = true
		"calendar":
			rules["present_year"] = 2050
		"mystery":
			gen.unlocked["mystery"] = true
		"rush":
			gen.unlocked["urgent"] = true
		"boomerang":
			gen.unlocked["boomerang"] = true
	gen.unlocked["present"] = true
	gen.unlocked["damaged"] = true


func timed() -> bool:
	return mode == "shift" or mode == "daily"


func record_limit() -> float:
	return maxf(1.7, 4.6 - 0.035 * float(sorted_count))


func urgent_window() -> float:
	return 3.0 + float(stats.get("urgent_bonus_time", 0.0))


func combo_mult() -> float:
	if combo >= 35:
		return 3.0
	if combo >= 20:
		return 2.5
	if combo >= 10:
		return 2.0
	if combo >= 5:
		return 1.5
	return 1.0


func update(delta: float) -> void:
	if over or paused:
		return
	elapsed += delta
	if timed():
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			finish(true)
			return
	# A rule event never ends while a parcel judged by it is on the pad.
	if not events.active.is_empty() and EventDirector.DEFS[events.active["id"]]["rule"] and not current.is_empty():
		events.active["time_left"] = maxf(float(events.active["time_left"]), delta + 0.01)
	var ev := events.tick(delta)
	if ev.begins_with("ended:"):
		var id := ev.substr(6)
		events.stop_rules(id, rules)
		if EventDirector.DEFS[id]["rule"]:
			_refresh_queue()
		event_ended.emit(id)
	elif ev == "due" and current.is_empty():
		_start_event()
	if current.is_empty():
		lift_timer -= delta
		if lift_timer <= 0.0:
			_bring_next()
	else:
		parcel_time += delta
		if mode == "record" and parcel_time >= record_limit():
			_resolve(-1, true)
		elif int(stats["robot"]) >= 2 and (mode == "shift" or mode == "calm") and parcel_time >= float(stats["robot_assist_after"]):
			var d := Rules.judge(current, rules)
			_resolve(Rules.dest_to_dir(d, rules["mirrored"]), false, true)
	if int(stats["robot"]) >= 4 and (mode == "shift" or mode == "calm"):
		robot_timer += delta
		if robot_timer >= float(stats["robot_belt_period"]):
			robot_timer = 0.0
			var c := int(stats["coin_base"])
			coins += c
			robot_sorted += 1
			robot_action.emit("belt", c)


func _start_event() -> void:
	var ev := events.start_random(rules)
	if ev.is_empty():
		return
	if EventDirector.DEFS[ev["id"]]["rule"]:
		_refresh_queue()
	events_count += 1
	if not events_seen.has(ev["id"]):
		events_seen.append(ev["id"])
	event_started.emit(ev)
	_maybe_tip("ev_" + str(ev["id"]))


func _fill_queue() -> void:
	while queue.size() < QUEUE_SIZE:
		queue.append(gen.next_parcel(rules))
	queue_changed.emit()


## Rules changed: parcels that were generated for the old rules are replaced.
func _refresh_queue() -> void:
	queue.clear()
	_fill_queue()


func _bring_next() -> void:
	if queue.is_empty():
		_fill_queue()
	current = queue.pop_front()
	parcel_time = 0.0
	_fill_queue()
	parcel_ready.emit(current)
	for m in mechanics_of(current):
		_maybe_tip(m)


func _maybe_tip(mech: String) -> void:
	if mode == "record" or mode == "daily":
		return
	if seen_tips.has(mech):
		return
	seen_tips[mech] = true
	tip_requested.emit(mech)


static func mechanics_of(p: Dictionary) -> Array:
	var out := []
	if p.get("hazard", false):
		out.append("hazard")
	if p.get("riddle", "") != "":
		out.append("mystery")
	if p.get("damaged", false):
		out.append("damaged")
	if int(p.get("old_year", 0)) != 0:
		out.append("paradox")
	if p.get("urgent", false):
		out.append("urgent")
	if p.get("series", "") != "":
		out.append("series")
	if p.get("collectible", "") != "":
		out.append("collectible")
	if p.get("sender", "") != "":
		out.append("sender")
	if not p.get("hazard", false) and p.get("riddle", "") == "" and int(p.get("year", 0)) == Rules.BASE_YEAR:
		out.append("present")
	if p.get("boomerang", false):
		out.append("boomerang")
	return out


func sort(dir: int) -> Dictionary:
	if over or paused or current.is_empty():
		return {}
	return _resolve(dir, false)


func _resolve(dir: int, timeout: bool, by_robot: bool = false) -> Dictionary:
	var p := current
	var correct_dest := Rules.judge(p, rules)
	var dest := -1 if timeout else Rules.dir_to_dest(dir, rules["mirrored"])
	var ok := dest == correct_dest
	var r := {"ok": ok, "dest": dest, "correct": correct_dest, "dir": dir, "parcel": p, "coins": 0,
		"points": 0, "timeout": timeout, "robot": by_robot, "urgent_hit": false, "collectible": "",
		"series_complete": false, "shard": 0, "shield": false, "life_lost": false, "boomerang_back": false}
	sorted_count += 1
	if ok:
		correct_count += 1
		if not by_robot:
			combo += 1
			best_combo = max(best_combo, combo)
		var mult := combo_mult()
		var route_mult := _route_mult(int(p["year"]))
		var mode_coin: float = {"calm": 0.6, "record": 0.8, "tutorial": 1.0, "daily": 1.0}.get(mode, 1.0)
		var c := float(stats["coin_base"]) * route_mult * float(stats["coin_mult"]) * events.coin_mult() * mode_coin
		c *= 1.0 + 0.1 * (mult - 1.0)
		var pts := 10.0 * mult * float(stats["score_mult"]) * events.score_mult()
		var special := mechanics_of(p).size() > 0
		if special:
			pts += 5.0
		if p.get("urgent", false) and parcel_time <= urgent_window():
			r["urgent_hit"] = true
			c *= 1.6
			pts += 15.0
		if p.get("boomerang", false) and not p.get("returned", false):
			c *= 1.5
			pts += 10.0
		if by_robot:
			c *= 0.5
			pts = 0.0
		r["coins"] = max(1, int(round(c)))
		r["points"] = int(round(pts))
		coins += r["coins"]
		score += r["points"]
		xp += 2 if special else 1
		if p.get("collectible", "") != "":
			r["collectible"] = p["collectible"]
			found.append(p["collectible"])
		if p.get("hazard", false):
			hazards_done += 1
		if p.get("boomerang", false) and not p.get("returned", false):
			boomerangs_done += 1
		if p.get("hazard", false) and stats["lab"] and gen.rng.randf() < 0.25:
			r["shard"] = 1
			shards += 1
		# Steady work repairs the chutes: every 10 correct in a row restore 1.
		if combo > 0 and combo % 10 == 0 and reliability < max_reliability and (mode == "shift"):
			reliability += 1
			r["repaired"] = true
		var sender: String = p.get("sender", "")
		if sender != "":
			friends[sender] = int(friends.get(sender, 0)) + 1
	else:
		mistakes += 1
		if shield_ready and combo >= 5:
			shield_ready = false
			r["shield"] = true
		else:
			combo = 0
		var costs_life := mode == "shift" or mode == "record"
		# A boomerang parcel comes back once instead of costing reliability.
		if p.get("boomerang", false) and not p.get("returned", false) and not timeout:
			var back := p.duplicate()
			back["returned"] = true
			queue.push_front(back)
			r["boomerang_back"] = true
			costs_life = false
			queue_changed.emit()
		if costs_life and mode == "shift" and free_mistake_ready:
			free_mistake_ready = false
			costs_life = false
		if costs_life:
			reliability -= 1
			r["life_lost"] = true
	_track_series(p, ok, r)
	current = {}
	lift_timer = 0.06 if events.is_active("storm") else float(stats["lift_time"])
	parcel_sorted.emit(r)
	if r["life_lost"] and reliability <= 0:
		finish(mode == "record")
	elif mode == "tutorial" and sorted_count >= 8:
		finish(true)
	return r


func _track_series(p: Dictionary, ok: bool, r: Dictionary) -> void:
	var sid: String = p.get("series", "")
	if sid == "":
		return
	if int(p["series_idx"]) == 1:
		series_state[sid] = true
	if not ok:
		series_state[sid] = false
	if int(p["series_idx"]) == int(p["series_len"]) and series_state.get(sid, false):
		series_done += 1
		r["series_complete"] = true
		var bonus := 10 + 2 * int(stats["coin_base"])
		coins += bonus
		score += 60
		r["coins"] = int(r["coins"]) + bonus
		series_state.erase(sid)


func _route_mult(year: int) -> float:
	var best := 1.0
	for id in gen.routes:
		var rt: Dictionary = Content.ROUTES[id]
		for key in ["past", "future"]:
			var rr: Array = rt[key]
			if not rr.is_empty() and year >= int(rr[0]) and year <= int(rr[1]):
				best = maxf(best, float(rt["mult"]))
	return best


func tap_cat() -> int:
	if not events.is_active("cat"):
		return 0
	events.active["time_left"] = 0.01
	shards += 1
	return 1


func accuracy() -> float:
	return float(correct_count) / float(sorted_count) if sorted_count > 0 else 0.0


func stars() -> int:
	if mode == "record" or mode == "calm":
		return 0
	if not completed:
		return 0
	var acc := accuracy()
	if mode == "tutorial":
		return 3 if acc >= 0.99 else (2 if acc >= 0.75 else 1)
	if acc >= 0.95 and sorted_count >= 25:
		return 3
	if acc >= 0.85 and sorted_count >= 15:
		return 2
	return 1


func finish(by_time: bool) -> void:
	if over:
		return
	over = true
	completed = by_time
	if not events.active.is_empty():
		events.stop_rules(events.active["id"], rules)
	var bonus := 0
	if completed and (mode == "shift" or mode == "daily" or mode == "tutorial"):
		bonus = 10 + correct_count
	if mode == "calm":
		completed = true
	coins += bonus
	var xp_mult: float = float({"calm": 0.7, "record": 0.8}.get(mode, 1.0)) * float(stats["xp_mult"])
	var total_xp := int(round(float(xp + (5 if completed else 0)) * xp_mult))
	var summary := {
		"mode": mode, "completed": completed, "score": score, "coins": coins, "bonus": bonus,
		"xp": total_xp, "shards": shards, "sorted": sorted_count, "correct": correct_count,
		"mistakes": mistakes, "accuracy": accuracy(), "best_combo": best_combo, "stars": stars(),
		"found": found.duplicate(), "series_done": series_done, "friends": friends.duplicate(),
		"duration": elapsed, "robot_sorted": robot_sorted, "daily_mutator": daily_mutator,
		"seen_tips": seen_tips.keys(), "hazards": hazards_done, "boomerangs": boomerangs_done,
		"events": events_count,
	}
	shift_over.emit(summary)
