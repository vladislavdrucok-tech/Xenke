extends SceneTree
## Headless checks of the shift rules and a bot campaign for balance.
## Run: godot --headless --path floor13 -s res://tests/run_tests.gd [-- --campaign]

var failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	test_lift_moves_and_stops()
	test_toggle_and_order()
	test_boarding_and_delivery()
	test_capacity()
	test_complaint_and_fail()
	test_kid_and_cancel()
	test_routes_valid()
	test_events_safe()
	test_grumpy_rider_self_presses()
	test_tasks()
	if args.has("--campaign") or args.has("--all"):
		campaign(int(_arg(args, "--shifts", "16")), int(_arg(args, "--seed", "7")))
	print("TESTS: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(0 if failures == 0 else 1)


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	var i := args.find(key)
	if i != -1 and i + 1 < args.size():
		return args[i + 1]
	return def


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func make(cfg: Dictionary = {}) -> ShiftSim:
	var s := ShiftSim.new()
	var c := {"shift": 1, "seed": 1, "auto_spawn": false}
	c.merge(cfg, true)
	s.setup(c)
	return s


func run(s: ShiftSim, seconds: float, bot := false) -> void:
	var t := 0.0
	var think := 0.0
	while t < seconds and not s.over:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if bot:
			think -= 1.0 / 60.0
			if think <= 0.0:
				think = 0.6
				bot_policy(s)


func test_lift_moves_and_stops() -> void:
	var s := make()
	s.press(4)
	run(s, 6.0)
	check(is_equal_approx(s.pos, 4.0), "lift reaches floor 4 (pos=%f)" % s.pos)
	check(s.lift == ShiftSim.L_LOADING or s.lift == ShiftSim.L_CLOSING or s.lift == ShiftSim.L_IDLE, "doors cycle at 4")
	run(s, 3.0)
	check(s.lift == ShiftSim.L_IDLE and s.door == 0.0, "doors closed and idle after stop")
	# smooth: velocity never jumps by more than accel*dt
	var s2 := make()
	s2.press(5)
	var last := 0.0
	var max_jump := 0.0
	for i in 400:
		s2.step(1.0 / 60.0)
		if s2.vel != 0.0:
			max_jump = maxf(max_jump, absf(s2.vel - last))
		last = s2.vel
	check(max_jump <= s2.accel() / 60.0 + 0.001, "smooth acceleration (jump %f)" % max_jump)


func test_toggle_and_order() -> void:
	var s := make()
	check(s.press(3) == 1, "press adds stop")
	check(s.press(3) == -1, "second press removes stop")
	check(s.stops.is_empty(), "no stops after toggle")
	check(s.press(9) == 0, "locked floor refused")
	s.press(5)
	s.press(3)
	run(s, 1.2)
	# lift goes up towards 5 and stops at 3 on the way
	var arrived := []
	var t := 0.0
	while t < 10.0:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
		for e in s.out:
			if e.t == "arrive":
				arrived.append(e.floor)
		s.out.clear()
	check(arrived == [3, 5], "stops served on the way: %s" % str(arrived))


func test_boarding_and_delivery() -> void:
	var s := make()
	s.spawn("guest", 3, 5)
	run(s, 5.0)
	check(s.queue_on(3).size() == 1 and s.queue_on(3)[0].state == ShiftSim.P_WAITING, "guest waits on 3")
	s.press(3)
	run(s, 4.0)
	check(s.riders().size() == 1, "guest boarded")
	s.press(5)
	run(s, 4.0)
	check(s.delivered == 1 and s.coins > 0, "guest delivered with coins (%d)" % s.coins)
	run(s, 6.0)
	check(s.passengers.is_empty(), "guest left through a door")


func test_capacity() -> void:
	var s := make()
	for i in 5:
		s.spawn("guest", 2, 4)
	run(s, 3.0)
	s.press(2)
	run(s, 6.0)
	check(s.seats_used() == s.capacity, "cabin filled to capacity %d (used %d)" % [s.capacity, s.seats_used()])
	check(s.queue_on(2).size() == 5 - s.capacity, "rest keep waiting")


func test_complaint_and_fail() -> void:
	var s := make()
	for f in [2, 3, 4]:
		s.spawn("business", f, 1)
	run(s, 80.0)
	check(s.complaints == 3, "three complaints (%d)" % s.complaints)
	check(s.over and s.failed, "shift failed at the complaint limit")


func test_kid_and_cancel() -> void:
	var found := false
	for seed in 20:
		var s := make({"shift": 2, "seed": seed})
		s.spawn("kid", 1, 5)
		run(s, 2.5)
		s.press(1)
		run(s, 3.0)
		for e in s.out:
			if e.t == "kid":
				found = true
				check(s.stops.has(e.floor), "kid's floor is in the stops")
				s.press(e.floor)
				check(not s.stops.has(e.floor), "player cancels kid's floor")
		if found:
			break
	check(found, "kid presses a button")


func test_routes_valid() -> void:
	for shift in [1, 3, 6, 9, 12]:
		for rule in ["none", "repair", "moon", "vip"]:
			var floors := Defs.floors_for_shift(shift)
			var s := make({"shift": shift, "seed": shift * 13, "rule": rule, "rule_floor": 3, "auto_spawn": true})
			s.duration = 9999.0
			for i in 3000:
				s.step(1.0 / 30.0)
				if i % 15 == 0:
					bot_policy(s)
			for p in s.passengers:
				check(p.origin != p.dest, "origin != dest")
				check(s.is_open(p.origin) and s.is_open(p.dest), "route uses open floors (%d->%d, rule %s)" % [p.origin, p.dest, rule])
				check(p.dest <= floors, "dest unlocked")
				check(Defs.type_unlocked(p.type, floors), "type %s unlocked at %d floors" % [p.type, floors])
				if p.type == "ghost" and rule != "moon":
					check(p.origin == 13 or p.dest == 13, "ghost route touches 13")
			for f in range(1, floors + 1):
				check(s.queue_on(f).size() <= Defs.QUEUE_MAX, "queue limit")


func test_events_safe() -> void:
	for id in Defs.EVENTS:
		var s := make({"shift": 13, "seed": 5, "auto_spawn": true})
		s.time = 10.0
		s.allow_events = false
		s.start_event(id)
		run(s, 30.0, true)
		check(s.ev_id == "" or s.ev_id == id, "event %s ends or runs" % id)
		for p in s.passengers:
			check(s.is_open(p.dest) and p.origin != p.dest, "event %s keeps routes valid" % id)
		for f in s.stops:
			check(s.is_open(f), "event %s only presses open floors" % id)


func test_grumpy_rider_self_presses() -> void:
	var s := make()
	s.spawn("business", 2, 5)
	run(s, 1.5)
	s.press(2)
	run(s, 5.0)
	check(s.riders().size() == 1, "boarded")
	run(s, 60.0)
	check(s.delivered == 1, "grumpy rider pressed own floor and was delivered")


func test_tasks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var kinds := {}
	for shift in range(1, 20):
		for i in 20:
			var t := Defs.make_task(shift, Defs.floors_for_shift(shift), r)
			kinds[t.kind] = true
			check(t.goal > 0 and t.reward > 0, "task goal/reward positive")
			check(String(t.text).find("%") == -1, "task text formatted: " + String(t.text))
			if t.kind == "type":
				check(Defs.type_unlocked(t.type, Defs.floors_for_shift(shift)), "task type unlocked")
	check(kinds.size() == 6, "all task kinds appear (%d)" % kinds.size())


# ------------------------------------------------------------------ bot & campaign

func bot_policy(s: ShiftSim) -> void:
	for p in s.riders():
		if p.state == ShiftSim.P_RIDING and not s.stops.has(p.dest) and not s.stopped_at(p.dest):
			s.press(p.dest)
	var free := s.capacity - s.seats_used()
	if free <= 0:
		return
	var calls := []
	for f in s.open_floors():
		if s.queue_on(f).size() > 0 and not s.stops.has(f):
			calls.append([s.min_wait_frac(f), f])
	calls.sort()
	var pickups := 0
	for c in calls:
		if pickups >= 2:
			break
		if s.stopped_at(c[1]) and s.lift != ShiftSim.L_IDLE:
			continue
		s.press(c[1])
		pickups += 1


func campaign(shifts: int, seed: int) -> void:
	print("--- bot campaign (seed %d) ---" % seed)
	var up := {}
	for id in Defs.UPGRADE_ORDER:
		up[id] = 0
	var wallet := 0
	var shift := 1
	var tries := 0
	var played := 0
	var rules := Defs.RULES.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	while shift <= shifts and played < shifts * 4:
		played += 1
		var rule := "none"
		if shift >= 3:
			rule = rules[rng.randi_range(0, rules.size() - 1)]
			if rule == "moon" and Defs.floors_for_shift(shift) < 13:
				rule = "none"
		var s := ShiftSim.new()
		s.setup({"shift": shift, "seed": seed * 100 + played, "upgrades": up, "rule": rule, "rule_floor": 3})
		run(s, 999.0, true)
		wallet += s.coins
		print("shift %2d %-9s floors %2d  coins %4d  delivered %3d  complaints %d/%d  streak %2d  %s" % [
			shift, rule, s.floors, s.coins, s.delivered, s.complaints, s.hearts, s.best_streak,
			"FAIL" if s.failed else "ok"])
		if s.failed:
			tries += 1
		else:
			shift += 1
			tries = 0
		# greedy shopping: cheapest affordable upgrade first
		var bought := true
		while bought:
			bought = false
			var best := ""
			var best_cost := 1 << 30
			for id in Defs.UPGRADE_ORDER:
				var c := Defs.upgrade_cost(id, up[id])
				if c > 0 and c <= wallet and c < best_cost:
					best = id
					best_cost = c
			if best != "":
				wallet -= best_cost
				up[best] += 1
				bought = true
	print("upgrades: ", up, " wallet ", wallet)
