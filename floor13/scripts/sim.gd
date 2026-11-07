class_name ShiftSim
extends RefCounted
## The rules of one night shift, without any drawing. The view reads this state and
## drains `out` for sounds and effects; tests drive it headlessly with a bot.

enum { L_IDLE, L_MOVING, L_OPENING, L_LOADING, L_CLOSING }
enum { P_WALK_IN, P_WAITING, P_BOARDING, P_RIDING, P_EXITING, P_WALK_OUT, P_LEAVING, P_GONE }

const BASE_DOOR_TIME := 0.42

# --- configuration ---
var shift := 1
var floors := Defs.START_FLOORS
var duration := 90.0
var tutorial := false
var auto_spawn := true
var allow_events := true
var rule_id := "none"
var rule_floor := 0
var closed := {}
var base_speed := 1.5
var capacity := 3
var door_mult := 1.0
var wait_mult := 1.0
var ride_mult := 1.0
var tip_mult := 1.0

# --- shift state ---
var rng := RandomNumberGenerator.new()
var time := 0.0
var over := false
var failed := false
var hearts := 3
var complaints := 0
var coins := 0
var delivered := 0
var streak := 0
var best_streak := 0
var angry := 0
var out: Array = []          # events for the view: {"t": name, ...}

# --- lift ---
var pos := 1.0               # in floors (1.0 = lobby)
var vel := 0.0
var lift := L_IDLE
var door := 0.0              # 0 closed .. 1 open
var stops: Array = []        # floors that will be served (pressed buttons)
var target := -1
var parking := false
var at_floor := 1
var load_cd := 0.0
var load_idle := 0.0
var load_wait := 0.0

# --- passengers ---
var passengers: Array = []
var next_id := 1
var board_seq := 0
var spawn_t := 1.5

# --- random event ---
var ev_id := ""
var ev_t := 0.0
var ev_dur := 0.0
var ev_floor := 0
var ev_gap := 18.0
var coin_pile_floor := 0
var coin_pile_amount := 0
var recent_events: Array = []


func setup(cfg: Dictionary) -> void:
	shift = int(cfg.get("shift", 1))
	floors = int(cfg.get("floors", Defs.floors_for_shift(shift)))
	duration = float(cfg.get("duration", Defs.shift_duration(shift)))
	tutorial = bool(cfg.get("tutorial", false))
	auto_spawn = bool(cfg.get("auto_spawn", not tutorial))
	rule_id = String(cfg.get("rule", "none"))
	rule_floor = int(cfg.get("rule_floor", 0))
	if cfg.has("seed"):
		rng.seed = int(cfg["seed"])
	else:
		rng.randomize()
	var up: Dictionary = cfg.get("upgrades", {})
	base_speed = float(Defs.upgrade_value("motor", int(up.get("motor", 0))))
	capacity = int(Defs.upgrade_value("cabin", int(up.get("cabin", 0))))
	door_mult = float(Defs.upgrade_value("doors", int(up.get("doors", 0))))
	wait_mult = float(Defs.upgrade_value("coffee", int(up.get("coffee", 0))))
	ride_mult = float(Defs.upgrade_value("jazz", int(up.get("jazz", 0))))
	tip_mult = float(Defs.upgrade_value("tips", int(up.get("tips", 0))))
	hearts = int(Defs.upgrade_value("hearts", int(up.get("hearts", 0))))
	closed.clear()
	if rule_id == "repair" and rule_floor >= 2 and rule_floor <= floors:
		closed[rule_floor] = true
	allow_events = shift >= 2 and rule_id != "quiet" and not tutorial
	ev_gap = rng.randf_range(12.0, 20.0)
	spawn_t = 1.0


# ---------------------------------------------------------------- derived values

func speed() -> float:
	var s := base_speed
	if rule_id == "oldmotor":
		s *= 0.8
	if ev_id == "turbo":
		s *= 1.5
	elif ev_id == "blackout":
		s *= 0.75
	return s


func accel() -> float:
	return speed() * 2.2


func door_time() -> float:
	var t := BASE_DOOR_TIME * door_mult
	if ev_id == "sticky":
		t *= 2.2
	return t


func drain_mult() -> float:
	return 0.5 if ev_id == "jazz" else 1.0


func coin_mult() -> float:
	var m := 1.0
	if rule_id == "festival":
		m *= 1.3
	elif rule_id == "oldmotor":
		m *= 1.35
	if ev_id == "rich":
		m *= 2.0
	return m


func patience_scale() -> float:
	var s := maxf(0.72, 1.12 - 0.03 * float(shift - 1))
	s *= wait_mult
	if rule_id == "grannies":
		s *= 1.15
	return s


func spawn_interval() -> float:
	var base := maxf(1.35, 3.6 * pow(0.945, float(shift - 1)))
	var prog := clampf(time / maxf(duration, 1.0), 0.0, 1.0)
	base *= lerpf(1.25, 0.85, prog)
	if rule_id == "festival":
		base /= 1.3
	elif rule_id == "quiet":
		base *= 1.12
	return base * rng.randf_range(0.7, 1.3)


func max_waiting() -> int:
	return 4 + floors / 2


func is_open(f: int) -> bool:
	return f >= 1 and f <= floors and not closed.has(f)


func open_floors() -> Array:
	var a := []
	for f in range(1, floors + 1):
		if not closed.has(f):
			a.append(f)
	return a


func seats_used() -> int:
	var n := 0
	for p in passengers:
		if p.state == P_RIDING or p.state == P_BOARDING:
			n += int(Defs.TYPES[p.type]["seats"])
	return n


func riders() -> Array:
	var a := []
	for p in passengers:
		if p.state == P_RIDING or p.state == P_BOARDING or p.state == P_EXITING:
			a.append(p)
	a.sort_custom(func(x, y): return x.seq < y.seq)
	return a


func queue_on(f: int) -> Array:
	var a := []
	for p in passengers:
		if p.floor == f and (p.state == P_WALK_IN or p.state == P_WAITING):
			a.append(p)
	a.sort_custom(func(x, y): return x.qorder < y.qorder)
	return a


func waiting_count() -> int:
	var n := 0
	for p in passengers:
		if p.state == P_WALK_IN or p.state == P_WAITING:
			n += 1
	return n


func dest_count(f: int) -> int:
	var n := 0
	for p in passengers:
		if (p.state == P_RIDING or p.state == P_BOARDING) and p.dest == f:
			n += 1
	return n


func min_wait_frac(f: int) -> float:
	var m := 2.0
	for p in passengers:
		if p.floor == f and (p.state == P_WALK_IN or p.state == P_WAITING):
			m = minf(m, p.pat / p.pmax)
	return m


func lift_floor() -> int:
	return clampi(int(round(pos)), 1, floors)


func stopped_at(f: int) -> bool:
	return absf(pos - float(f)) < 0.01 and absf(vel) < 0.01 and lift != L_MOVING


# ---------------------------------------------------------------- main step

func step(dt: float) -> void:
	if over:
		return
	time += dt
	_update_event(dt)
	_update_spawns(dt)
	_update_lift(dt)
	_update_passengers(dt)
	if tutorial:
		return
	if complaints >= hearts:
		over = true
		failed = true
		_emit("fail")
	elif time >= duration:
		over = true
		_emit("end")


func _emit(t: String, data: Dictionary = {}) -> void:
	data["t"] = t
	out.append(data)


# ---------------------------------------------------------------- input

## Toggles a floor button. Returns 1 added, -1 removed, 2 doors opened here, 0 refused.
func press(f: int) -> int:
	if not is_open(f):
		_emit("deny", {"floor": f})
		return 0
	if stops.has(f):
		stops.erase(f)
		_emit("unpress", {"floor": f})
		return -1
	if stopped_at(f):
		if lift == L_IDLE:
			_arrive(f)
			return 2
		if lift == L_CLOSING:
			lift = L_OPENING
			return 2
		return 0
	stops.append(f)
	_emit("press", {"floor": f})
	return 1


# ---------------------------------------------------------------- lift

func _update_lift(dt: float) -> void:
	match lift:
		L_IDLE:
			if stops.is_empty():
				return
			var here := lift_floor()
			if stops.has(here) and absf(pos - here) < 0.01:
				stops.erase(here)
				_arrive(here)
				return
			lift = L_MOVING
			_emit("depart")
		L_MOVING:
			_move(dt)
		L_OPENING:
			door = minf(1.0, door + dt / door_time())
			if door >= 1.0:
				lift = L_LOADING
				load_cd = 0.0
				load_idle = 0.0
				load_wait = 0.0
				_emit("opened", {"floor": at_floor})
				_collect_pile()
		L_LOADING:
			_update_loading(dt)
		L_CLOSING:
			door = maxf(0.0, door - dt / door_time())
			if door <= 0.0:
				lift = L_IDLE
				_emit("closed", {"floor": at_floor})


func _choose_target() -> int:
	if stops.is_empty():
		return -1
	var d := 0
	if absf(vel) > 0.05:
		d = 1 if vel > 0.0 else -1
	if d != 0:
		var stopping := vel * vel / (2.0 * accel())
		var best := -1
		var best_dist := INF
		for f in stops:
			var delta := (float(f) - pos) * d
			if delta >= stopping - 0.02 and delta < best_dist:
				best = f
				best_dist = delta
		if best != -1:
			return best
	return int(stops[0])


func _park_floor() -> int:
	# No more stops: halt gently at the next floor we can still stop at.
	if absf(vel) < 0.05:
		return lift_floor()
	var d := 1.0 if vel > 0.0 else -1.0
	var stopping := vel * vel / (2.0 * accel())
	var f := pos + d * stopping
	var fl := int(ceil(f - 0.001)) if d > 0.0 else int(floor(f + 0.001))
	return clampi(fl, 1, floors)


func _move(dt: float) -> void:
	var t := _choose_target()
	parking = t == -1
	if parking:
		t = _park_floor()
	target = t
	var a := accel()
	var d := float(t) - pos
	var desired := signf(d) * minf(speed(), sqrt(2.0 * a * 0.92 * absf(d)))
	vel = move_toward(vel, desired, a * dt)
	pos += vel * dt
	pos = clampf(pos, 1.0, float(floors))
	var nd := float(t) - pos
	if (absf(nd) < 0.012 and absf(vel) < 0.45) or (signf(nd) != signf(d) and absf(vel) < 0.6):
		pos = float(t)
		vel = 0.0
		if parking:
			lift = L_IDLE
			at_floor = t
			_emit("park", {"floor": t})
		else:
			stops.erase(t)
			_arrive(t)


func _arrive(f: int) -> void:
	at_floor = f
	lift = L_OPENING
	for p in passengers:
		if p.state == P_RIDING and p.dest != f:
			p.stops += 1
	_emit("arrive", {"floor": f})


func _update_loading(dt: float) -> void:
	load_cd -= dt
	if load_cd > 0.0:
		return
	# 1) passengers for this floor step out
	for p in riders():
		if p.state == P_RIDING and p.dest == at_floor:
			_start_exit(p)
			load_cd = float(Defs.TYPES[p.type]["board"]) * door_mult * 0.8
			load_idle = 0.0
			return
	# 2) waiting passengers step in (in queue order; those who do not fit wait)
	var free := capacity - seats_used()
	for p in queue_on(at_floor):
		if p.state != P_WAITING:
			continue
		var need := int(Defs.TYPES[p.type]["seats"])
		if need <= free:
			_start_board(p)
			load_cd = float(Defs.TYPES[p.type]["board"]) * door_mult
			load_idle = 0.0
			return
	# 3) hold the doors briefly for someone who is about to reach the queue
	if load_wait < 1.2:
		for p in queue_on(at_floor):
			if p.state == P_WALK_IN and int(Defs.TYPES[p.type]["seats"]) <= free:
				var eta := absf(p.x - p.tx) / (Defs.WALK_SPEED * float(Defs.TYPES[p.type]["speed"]))
				if eta < 1.0:
					load_wait += dt
					return
	load_idle += dt
	if load_idle >= 0.25:
		lift = L_CLOSING
		_emit("closing", {"floor": at_floor})


func _collect_pile() -> void:
	if coin_pile_floor == at_floor and coin_pile_amount > 0:
		var amount := coin_pile_amount
		coins += amount
		coin_pile_amount = 0
		coin_pile_floor = 0
		_emit("pickup", {"floor": at_floor, "coins": amount})
		if ev_id == "coins":
			_end_event()


# ---------------------------------------------------------------- passengers

func spawn(type_id: String, origin: int, dest: int, opts: Dictionary = {}) -> Dictionary:
	var td: Dictionary = Defs.TYPES[type_id]
	var door_x: int = Defs.DOOR_XS[rng.randi_range(0, Defs.DOOR_XS.size() - 1)]
	var pmax := float(td["patience"]) * patience_scale()
	# never less than a slow full trip across the building plus loading
	var need := float(floors - 1) / base_speed + 4.0 * BASE_DOOR_TIME * door_mult + 6.0
	pmax = maxf(pmax, need) * float(opts.get("patience_mult", 1.0))
	var p := {
		"id": next_id, "type": type_id, "origin": origin, "dest": dest, "floor": origin,
		"state": P_WALK_IN, "x": float(door_x), "tx": float(door_x), "door": door_x,
		"pat": pmax, "pmax": pmax, "t": 0.0, "dur": 0.0, "stops": 0, "seq": 0,
		"qorder": next_id, "grumpy": false, "party": bool(opts.get("party", false)),
		"vip": bool(opts.get("vip", false)), "kid_pressed": 0, "coins": 0,
	}
	next_id += 1
	passengers.append(p)
	_emit("spawn", {"pid": p.id, "floor": origin})
	return p


func _update_spawns(dt: float) -> void:
	if not auto_spawn or time > duration - 4.0:
		return
	spawn_t -= dt
	if spawn_t > 0.0:
		return
	spawn_t = spawn_interval()
	if not _spawn_random():
		spawn_t = 0.8


func _spawn_random(forced_type: String = "", opts: Dictionary = {}) -> bool:
	if forced_type == "" and waiting_count() >= max_waiting():
		return false
	var type_id := forced_type if forced_type != "" else _pick_type()
	var route := _pick_route(type_id)
	if route.is_empty():
		return false
	var o := opts.duplicate()
	if route.size() > 2 and route[2]:
		o["party"] = true
	spawn(type_id, route[0], route[1], o)
	return true


func _pick_type() -> String:
	var ids := []
	var weights := []
	for t in Defs.TYPE_ORDER:
		var td: Dictionary = Defs.TYPES[t]
		if not Defs.type_unlocked(t, floors):
			continue
		var w := float(td["weight"])
		if w <= 0.0:
			continue
		if t == "ghost" and not is_open(13) and rule_id != "moon":
			continue
		match rule_id:
			"vip":
				if t == "business": w *= 3.0
			"grannies":
				if t == "granny": w *= 4.0
			"school":
				if t == "kid": w *= 4.0
			"moon":
				if t == "ghost": w *= 2.5
		ids.append(t)
		weights.append(w)
	return String(ids[_weighted(weights)])


func _weighted(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := rng.randf() * total
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return weights.size() - 1


## Returns [origin, dest, party] or [] if nobody can be placed right now.
func _pick_route(type_id: String) -> Array:
	var open := open_floors()
	if open.size() < 2:
		return []
	var origins := []
	var ow := []
	for f in open:
		if queue_on(f).size() >= Defs.QUEUE_MAX:
			continue
		if ev_id == "drill" and f == 1:
			continue
		origins.append(f)
		ow.append(2.2 if f == 1 else 1.0)
	if origins.is_empty():
		return []
	var party := false
	var origin := -1
	var dest := -1
	if type_id == "ghost" and rule_id != "moon":
		if not is_open(13):
			return []
		if origins.has(13) and rng.randf() < 0.5:
			origin = 13
		else:
			dest = 13
	if ev_id == "drill":
		dest = 1
	elif ev_id == "party" and dest == -1 and rng.randf() < 0.55 and is_open(ev_floor):
		dest = ev_floor
		party = true
	if origin == -1:
		var cand := []
		var cw := []
		for i in origins.size():
			if origins[i] != dest:
				cand.append(origins[i])
				cw.append(ow[i])
		if cand.is_empty():
			return []
		origin = int(cand[_weighted(cw)])
	if dest == -1:
		var dc := []
		var dw := []
		for f in open:
			if f != origin:
				dc.append(f)
				dw.append(2.0 if f == 1 else 1.0)
		dest = int(dc[_weighted(dw)])
	if origin == dest or not is_open(origin) or not is_open(dest):
		return []
	return [origin, dest, party]


func queue_x(i: int) -> float:
	return float(Defs.QUEUE_X0 + i * Defs.QUEUE_DX)


func _update_passengers(dt: float) -> void:
	var rocker_riding := false
	for p in passengers:
		if p.state == P_RIDING and p.type == "rocker":
			rocker_riding = true
			break
	var queued_floors := {}
	for p in passengers:
		if (p.state == P_WALK_IN or p.state == P_WAITING) and not queued_floors.has(p.floor):
			queued_floors[p.floor] = true
			var q := queue_on(p.floor)
			for i in q.size():
				q[i].tx = queue_x(i)
	var dm := drain_mult()
	for p in passengers:
		var td: Dictionary = Defs.TYPES[p.type]
		var walk := Defs.WALK_SPEED * float(td["speed"])
		match p.state:
			P_WALK_IN, P_WAITING:
				p.x = move_toward(p.x, p.tx, walk * dt)
				if p.state == P_WALK_IN and absf(p.x - p.tx) < 0.5:
					p.state = P_WAITING
				p.pat -= dt * dm
				if p.pat <= 0.0:
					p.pat = 0.0
					_leave_angry(p)
			P_BOARDING:
				p.t += dt
				if p.t >= p.dur:
					p.state = P_RIDING
					_on_boarded(p)
			P_RIDING:
				var rate := float(td["ride_drain"]) * ride_mult * dm
				if rocker_riding and p.type != "rocker":
					rate *= 1.6
				p.pat -= dt * rate
				if p.pat <= 0.0 and not p.grumpy:
					p.pat = 0.0
					p.grumpy = true
					if not stops.has(p.dest):
						stops.append(p.dest)
					streak = 0
					_emit("grumpy", {"pid": p.id, "floor": p.dest})
			P_EXITING:
				p.t += dt
				if p.t >= p.dur:
					p.state = P_WALK_OUT
					p.x = float(Defs.LANDING_X)
					p.tx = float(p.door)
			P_WALK_OUT, P_LEAVING:
				p.x = move_toward(p.x, p.tx, walk * dt)
				if absf(p.x - p.tx) < 0.5:
					p.state = P_GONE
					_emit("door", {"pid": p.id, "floor": p.floor, "x": p.tx})
	for i in range(passengers.size() - 1, -1, -1):
		if passengers[i].state == P_GONE:
			passengers.remove_at(i)


func _start_board(p: Dictionary) -> void:
	p.state = P_BOARDING
	p.t = 0.0
	p.dur = float(Defs.TYPES[p.type]["board"]) * door_mult
	board_seq += 1
	p.seq = board_seq
	_emit("board", {"pid": p.id, "floor": at_floor})


func _on_boarded(p: Dictionary) -> void:
	if p.type == "kid" and rng.randf() < 0.8:
		var cand := []
		for f in open_floors():
			if f != at_floor and f != p.dest and not stops.has(f):
				cand.append(f)
		if not cand.is_empty():
			var f: int = cand[rng.randi_range(0, cand.size() - 1)]
			stops.append(f)
			p.kid_pressed = f
			_emit("kid", {"pid": p.id, "floor": f})


func fare_for(p: Dictionary) -> int:
	var td: Dictionary = Defs.TYPES[p.type]
	var frac := clampf(p.pat / p.pmax, 0.0, 1.0)
	var dist := absi(p.dest - p.origin)
	var fare := (3.0 + 1.1 * float(dist)) * float(td["pay"])
	if p.type == "robot":
		fare *= 2.0 if p.stops == 0 else maxf(0.4, 1.0 - 0.3 * float(p.stops))
	var tip := 0.0 if p.grumpy else frac * 0.8 * tip_mult
	var mult := coin_mult() * (1.0 + float(mini(streak, 10)) * 0.05)
	if p.party:
		mult *= 1.5
	if p.vip:
		mult *= 3.0
	if rule_id == "vip" and p.type == "business":
		mult *= 1.3
	var total := int(round(fare * (1.0 + tip) * mult))
	if rule_id == "express" and p.stops == 0:
		total += 5
	return maxi(1, total)


func _start_exit(p: Dictionary) -> void:
	var frac := clampf(p.pat / p.pmax, 0.0, 1.0)
	var good: bool = frac >= 0.35 and not p.grumpy
	var amount := fare_for(p)
	p.coins = amount
	p.state = P_EXITING
	p.t = 0.0
	p.dur = float(Defs.TYPES[p.type]["board"]) * door_mult * 0.8
	p.floor = at_floor
	p.door = Defs.DOOR_XS[rng.randi_range(0, Defs.DOOR_XS.size() - 1)]
	coins += amount
	delivered += 1
	var forgiven := false
	if p.type == "inspector" and frac >= 0.5 and not p.grumpy and complaints > 0:
		complaints -= 1
		forgiven = true
	if good:
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0
	_emit("deliver", {"pid": p.id, "floor": at_floor, "coins": amount, "good": good,
		"frac": frac, "forgiven": forgiven, "streak": streak})


func _leave_angry(p: Dictionary) -> void:
	p.state = P_LEAVING
	p.tx = float(p.door)
	if p.type == "ghost":
		_emit("vanish", {"pid": p.id, "floor": p.floor})
		p.state = P_GONE
		return
	var n := 2 if p.type == "inspector" else 1
	if not tutorial:
		complaints += n
	angry += 1
	streak = 0
	_emit("complaint", {"pid": p.id, "floor": p.floor, "count": n})


# ---------------------------------------------------------------- random events

func _update_event(dt: float) -> void:
	if ev_id != "":
		ev_t += dt
		if ev_t >= ev_dur:
			_end_event()
		return
	if not allow_events or time > duration - 14.0:
		return
	ev_gap -= dt
	if ev_gap <= 0.0:
		ev_gap = rng.randf_range(20.0, 32.0)
		start_event(_pick_event())


func _pick_event() -> String:
	var ids := []
	var weights := []
	for id in Defs.EVENTS:
		var e: Dictionary = Defs.EVENTS[id]
		if int(e["shift"]) > shift or recent_events.has(id):
			continue
		if id == "lostcat" and not Defs.type_unlocked("cat", floors):
			continue
		if id == "inspector" and not Defs.type_unlocked("inspector", floors):
			continue
		ids.append(id)
		weights.append(float(e["weight"]))
	if ids.is_empty():
		return ""
	return String(ids[_weighted(weights)])


func _random_open_floor(exclude: Array) -> int:
	var cand := []
	for f in open_floors():
		if not exclude.has(f):
			cand.append(f)
	if cand.is_empty():
		return -1
	return int(cand[rng.randi_range(0, cand.size() - 1)])


func start_event(id: String) -> void:
	if id == "" or not Defs.EVENTS.has(id):
		return
	var e: Dictionary = Defs.EVENTS[id]
	ev_floor = 0
	match id:
		"party":
			ev_floor = _random_open_floor([1])
			if ev_floor == -1:
				return
		"coins":
			ev_floor = _random_open_floor([lift_floor()])
			if ev_floor == -1:
				return
			coin_pile_floor = ev_floor
			coin_pile_amount = 12 + 3 * shift
		"prank":
			var ex := stops.duplicate()
			ex.append(lift_floor())
			ev_floor = _random_open_floor(ex)
			if ev_floor == -1:
				return
			stops.append(ev_floor)
		"lostcat":
			if not _spawn_random("cat", {"vip": true, "patience_mult": 1.4}):
				return
		"inspector":
			if not _spawn_random("inspector"):
				return
	ev_id = id
	ev_t = 0.0
	ev_dur = float(e["dur"])
	recent_events.append(id)
	if recent_events.size() > 2:
		recent_events.pop_front()
	_emit("event", {"id": id, "floor": ev_floor})


func _end_event() -> void:
	var id := ev_id
	if id == "coins":
		coin_pile_floor = 0
		coin_pile_amount = 0
	ev_id = ""
	ev_t = 0.0
	_emit("event_end", {"id": id})


func event_text() -> String:
	if ev_id == "":
		return ""
	var d := String(Defs.EVENTS[ev_id]["desc"])
	if d.find("%d") != -1:
		d = d % ev_floor
	return d


# ---------------------------------------------------------------- autopilot (menu demo, tests, screenshots)

## A simple player: presses every rider's floor and up to `max_pickups` calls, most impatient first.
func bot_step(max_pickups := 2) -> void:
	for p in riders():
		if p.state == P_RIDING and not stops.has(p.dest) and not stopped_at(p.dest):
			press(p.dest)
	if capacity - seats_used() <= 0:
		return
	var calls := []
	for f in open_floors():
		if queue_on(f).size() > 0 and not stops.has(f):
			calls.append([min_wait_frac(f), f])
	calls.sort()
	var n := 0
	for c in calls:
		if n >= max_pickups:
			break
		if stopped_at(c[1]) and lift != L_IDLE:
			continue
		press(c[1])
		n += 1
