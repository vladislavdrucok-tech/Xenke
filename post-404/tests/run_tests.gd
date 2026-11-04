extends SceneTree
## Headless logic tests. Run:
##   godot --headless --path post-404 -s res://tests/run_tests.gd
## Exit code 0 = all passed.

var passed := 0
var failed := 0
var current := ""


func _init() -> void:
	var tests := [
		"test_rules", "test_patterns", "test_generator_fairness", "test_generator_unlocks",
		"test_anti_streak", "test_session_perfect", "test_session_bad_player", "test_session_record",
		"test_session_calm_and_tutorial", "test_rule_events", "test_upgrades", "test_economy",
		"test_save_roundtrip", "test_save_corruption", "test_story", "test_balance", "test_daily",
		"test_robot_and_shield", "test_i18n_keys", "test_boomerang", "test_achievements", "test_friend_letters",
		"test_seasons",
	]
	for t in tests:
		current = t
		call(t)
	print("\n==== %d passed, %d failed ====" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL [%s] %s" % [current, msg])


func profile_at(level: int) -> Dictionary:
	var p := SaveSystem.default_profile()
	p["level"] = level
	return p


# ------------------------------------------------------------------ rules

func test_rules() -> void:
	check(Rules.dest_for_year(1998, 2038) == Rules.Dest.PAST, "1998 is past")
	check(Rules.dest_for_year(2038, 2038) == Rules.Dest.PRESENT, "2038 is present")
	check(Rules.dest_for_year(2039, 2038) == Rules.Dest.FUTURE, "2039 is future")
	check(Rules.dest_for_year(2040, 2045) == Rules.Dest.PAST, "calendar shift moves boundary")
	check(Rules.dir_to_dest(Rules.Dir.LEFT, false) == Rules.Dest.PAST, "left = past")
	check(Rules.dir_to_dest(Rules.Dir.RIGHT, false) == Rules.Dest.FUTURE, "right = future")
	check(Rules.dir_to_dest(Rules.Dir.UP, false) == Rules.Dest.PRESENT, "up = present")
	check(Rules.dir_to_dest(Rules.Dir.DOWN, false) == Rules.Dest.QUARANTINE, "down = quarantine")
	check(Rules.dir_to_dest(Rules.Dir.LEFT, true) == Rules.Dest.FUTURE, "mirror swaps left")
	for d in [0, 1, 2, 3]:
		for m in [false, true]:
			check(Rules.dir_to_dest(Rules.dest_to_dir(d, m), m) == d, "dir/dest roundtrip %d %s" % [d, m])
	var hz := {"year": 1990, "shown": "1990", "hazard": true}
	check(Rules.judge(hz, Rules.make()) == Rules.Dest.QUARANTINE, "hazard -> quarantine")
	var rd := {"year": 1990, "shown": "????", "riddle": "r_mars", "riddle_dest": Rules.Dest.FUTURE}
	check(Rules.judge(rd, Rules.make()) == Rules.Dest.FUTURE, "riddle dest wins")
	check(not Rules.is_fair(rd, Rules.make(2050)), "riddle unfair under calendar shift")


func test_patterns() -> void:
	check(Rules.dests_for_pattern("19??", 2038) == [Rules.Dest.PAST], "19?? past")
	check(Rules.dests_for_pattern("205?", 2038) == [Rules.Dest.FUTURE], "205? future")
	check(Rules.dests_for_pattern("203?", 2038).size() == 3, "203? ambiguous")
	check(Rules.dests_for_pattern("?041", 2038).size() == 2, "?041 ambiguous")
	check(Rules.expand_pattern("2??1").size() == 100, "two wildcards expand to 100")


# -------------------------------------------------------------- generator

func test_generator_fairness() -> void:
	var rules_list := [Rules.make(), Rules.make(2045), Rules.make(2027), Rules.make(2038, true), Rules.make(2055, true)]
	var all_routes := Content.ROUTE_ORDER.duplicate()
	var unfair := 0
	var total := 0
	for level in [1, 3, 6, 10, 15, 25, 60]:
		for routes in [["town"], all_routes]:
			var g := PackageGenerator.new()
			g.setup(1000 + level, level, routes)
			g.characters = ["olena", "kai", "vera"]
			for rules in rules_list:
				for i in 1500:
					var p := g.next_parcel(rules)
					total += 1
					if not Rules.is_fair(p, rules):
						unfair += 1
						if unfair < 5:
							printerr("unfair parcel ", p, " rules ", rules)
					if str(p["year"]).length() != 4:
						unfair += 1
	check(unfair == 0, "all %d generated parcels are solvable (unfair=%d)" % [total, unfair])


func test_generator_unlocks() -> void:
	var counts := {}
	var g := PackageGenerator.new()
	g.setup(7, 1, ["town"])
	var any_present := false
	var any_mod := false
	for i in 2000:
		var p := g.next_parcel(Rules.make())
		if Rules.judge(p, Rules.make()) == Rules.Dest.PRESENT:
			any_present = true
		if ShiftSession.mechanics_of(p).size() > 0:
			any_mod = true
	check(not any_present, "level 1 has no present parcels")
	check(not any_mod, "level 1 has no special parcels")
	g = PackageGenerator.new()
	g.setup(8, 12, ["town"])
	g.characters = ["olena"]
	for i in 6000:
		var p := g.next_parcel(Rules.make())
		for m in ShiftSession.mechanics_of(p):
			counts[m] = int(counts.get(m, 0)) + 1
	for m in ["hazard", "mystery", "damaged", "paradox", "urgent", "series", "collectible", "sender", "present"]:
		check(int(counts.get(m, 0)) > 0, "level 12 produces '%s' (%d)" % [m, int(counts.get(m, 0))])
	var special := 0
	for m in ["hazard", "mystery", "damaged", "paradox"]:
		special += int(counts.get(m, 0))
	check(special < 6000 * 0.45, "special parcels stay a minority (%d)" % special)


func test_anti_streak() -> void:
	var g := PackageGenerator.new()
	g.setup(99, 5, ["town"])
	var last := -1
	var run := 0
	var worst := 0
	for i in 5000:
		var p := g.next_parcel(Rules.make())
		var d := Rules.judge(p, Rules.make())
		if d == last:
			run += 1
		else:
			run = 1
			last = d
		worst = max(worst, run)
	check(worst <= 4, "no long streaks of the same answer (worst %d)" % worst)


# ---------------------------------------------------------------- session

func play(s: ShiftSession, accuracy: float, think: float, max_time: float = 600.0, seed: int = 5) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var result := {}
	s.shift_over.connect(func(sum): result.merge(sum))
	s.tip_requested.connect(func(_m): pass)
	var t := 0.0
	var wait := 0.0
	while not s.over and t < max_time:
		s.update(0.05)
		t += 0.05
		if not s.current.is_empty():
			wait += 0.05
			if wait >= think:
				wait = 0.0
				var correct := Rules.dest_to_dir(Rules.judge(s.current, s.rules), s.rules["mirrored"])
				if rng.randf() < accuracy:
					s.sort(correct)
				else:
					s.sort((correct + 1) % 4)
	return result


func test_session_perfect() -> void:
	var s := ShiftSession.new()
	s.setup("shift", profile_at(8), 42)
	var sum := play(s, 1.0, 0.9)
	check(s.over and s.completed, "perfect player completes the shift")
	check(int(sum.get("stars", 0)) == 3, "perfect long shift gives 3 stars (%s)" % str(sum.get("stars")))
	check(int(sum.get("coins", 0)) > 100, "perfect shift earns coins (%d)" % int(sum.get("coins", 0)))
	check(int(sum.get("best_combo", 0)) >= 20, "combo builds up")
	check(s.mistakes == 0, "no mistakes")


func test_session_bad_player() -> void:
	var s := ShiftSession.new()
	s.setup("shift", profile_at(3), 43)
	var sum := play(s, 0.2, 0.8)
	check(s.over and not s.completed, "random player loses the shift")
	check(int(sum.get("stars", 0)) == 0, "failed shift has no stars")
	check(int(sum.get("coins", 0)) >= 0, "coins never negative")
	check(s.elapsed < s.time_total, "ended early by reliability")


func test_session_record() -> void:
	var s := ShiftSession.new()
	s.setup("record", profile_at(10), 44)
	var sum := play(s, 0.97, 1.2, 900.0)
	check(s.over, "record run eventually ends")
	check(int(sum.get("score", 0)) > 0, "record has score")
	# Timeout path: a player who never sorts loses 3 lives by timer.
	var s2 := ShiftSession.new()
	s2.setup("record", profile_at(10), 45)
	var t := 0.0
	while not s2.over and t < 60.0:
		s2.update(0.1)
		t += 0.1
	check(s2.over and s2.mistakes == 3, "idle record player times out after 3 parcels")


func test_session_calm_and_tutorial() -> void:
	var s := ShiftSession.new()
	s.setup("calm", profile_at(5), 46)
	play(s, 0.5, 0.6, 300.0)
	check(not s.over, "calm mode never ends by itself")
	check(s.reliability == s.max_reliability, "calm mode does not lose reliability")
	s.finish(true)
	check(s.over and s.completed, "calm can be finished by the player")
	var tut := ShiftSession.new()
	tut.setup("tutorial", profile_at(1), 1)
	var years := []
	tut.parcel_ready.connect(func(p): years.append(p["year"]))
	play(tut, 1.0, 0.5, 120.0)
	check(tut.over and tut.completed, "tutorial finishes")
	check(years.slice(0, 3) == [1998, 2077, 1961], "tutorial parcels are scripted %s" % str(years))


func test_rule_events() -> void:
	var s := ShiftSession.new()
	s.setup("calm", profile_at(20), 47)
	var unfair := 0
	var seen_events := {}
	s.event_started.connect(func(ev): seen_events[ev["id"]] = true)
	var t := 0.0
	var rng := RandomNumberGenerator.new()
	while t < 900.0:
		s.update(0.05)
		t += 0.05
		if not s.current.is_empty() and rng.randf() < 0.05:
			if not Rules.is_fair(s.current, s.rules):
				unfair += 1
			s.sort(Rules.dest_to_dir(Rules.judge(s.current, s.rules), s.rules["mirrored"]))
	check(unfair == 0, "parcels stay fair across rule events (unfair=%d)" % unfair)
	for id in ["golden", "calendar", "mirror", "cat", "storm", "blackout"]:
		check(seen_events.has(id), "event '%s' happens at high level" % id)
	# Forced calendar event: judged by the new year.
	var s2 := ShiftSession.new()
	s2.setup("calm", profile_at(20), 48)
	s2.events.start("calendar", s2.rules)
	s2._refresh_queue()
	check(int(s2.rules["present_year"]) != 2038, "calendar shifts the present")
	for p in s2.queue:
		check(Rules.is_fair(p, s2.rules), "queue regenerated for new calendar")
	s2.events.stop_rules("calendar", s2.rules)
	check(int(s2.rules["present_year"]) == 2038, "calendar restored")


func test_robot_and_shield() -> void:
	var p := profile_at(6)
	p["upgrades"] = {"robot": 3}
	var s := ShiftSession.new()
	s.setup("shift", p, 50)
	var t := 0.0
	while s.sorted_count < 3 and t < 60.0:
		s.update(0.1)
		t += 0.1
	check(s.sorted_count >= 3 and s.correct_count == s.sorted_count, "robot L2+ sorts stalled parcels correctly")
	check(s.combo == 0, "robot sorting gives no combo")
	# Shield keeps the combo once.
	var s2 := ShiftSession.new()
	s2.setup("shift", p, 51)
	var mistakes_done := 0
	t = 0.0
	while t < 40.0 and mistakes_done < 2:
		s2.update(0.05)
		t += 0.05
		if not s2.current.is_empty():
			var correct := Rules.dest_to_dir(Rules.judge(s2.current, s2.rules), s2.rules["mirrored"])
			if s2.combo >= 6:
				var r := s2.sort((correct + 1) % 4)
				mistakes_done += 1
				if mistakes_done == 1:
					check(r["shield"] and s2.combo >= 6, "first mistake shielded")
				else:
					check(not r["shield"] and s2.combo == 0, "second mistake resets combo")
			else:
				s2.sort(correct)


# ------------------------------------------------------ economy & upgrades

func test_upgrades() -> void:
	var p := SaveSystem.default_profile()
	check(Upgrades.can_buy(p, "press") == "coins", "no money -> can't buy")
	p["coins"] = 10000
	check(Upgrades.buy(p, "press"), "buy press")
	check(int(p["coins"]) == 10000 - 150, "press cost 150")
	check(Upgrades.cost("press", 1) > 150, "cost grows")
	for i in 20:
		Upgrades.buy(p, "chutes")
	check(Upgrades.level_of(p, "chutes") == 2, "max level respected")
	check(Upgrades.stats(p)["reliability"] == 6, "chutes add reliability")
	check(Upgrades.can_buy(p, "coffee") == "requires", "coffee needs lounge")
	check(Upgrades.can_buy(p, "lab") == "level", "lab needs level 7")
	p["level"] = 10
	p["shards"] = 0
	check(Upgrades.can_buy(p, "golden_stamp") == "shards", "equipment needs shards")
	for id in Upgrades.DEFS:
		check(Upgrades.DEFS[id]["kind"] in ["upgrade", "room", "decor", "equip"], "kind valid " + id)
	var tabbed := []
	for tab in Upgrades.SHOP_TABS:
		tabbed.append_array(Upgrades.SHOP_TABS[tab])
	check(tabbed.size() == Upgrades.DEFS.size(), "every purchase appears in the shop")
	var st := Upgrades.stats({"upgrades": {"lift": 5}})
	check(float(st["lift_time"]) > 0.05, "lift time stays positive")


func test_economy() -> void:
	var p := SaveSystem.default_profile()
	var s := {"mode": "shift", "coins": 120, "shards": 1, "xp": 70, "sorted": 40, "correct": 38,
		"best_combo": 22, "duration": 90.0, "stars": 3, "found": ["floppy", "floppy"], "friends": {"kai": 2},
		"score": 900, "seen_tips": ["damaged"]}
	var out := Economy.apply_summary(p, s)
	var ach_shards := 0
	for id in out["achievements"]:
		ach_shards += int(Achievements.def(id)[3])
	check(int(p["coins"]) == 145 and int(p["shards"]) == 1 + ach_shards, "currency added: coins + duplicate sold + achievements (%d, %d)" % [int(p["coins"]), int(p["shards"])])
	check(int(p["level"]) == 2 and out["levels"] == [2], "level up to 2")
	check(out["unlocks"].has("present"), "present unlocked at level 2")
	check(int(p["collection"]["floppy"]) == 2 and out["new_items"].count("floppy") == 1, "collection counted")
	check(int(p["story"]["friendship"]["kai"]) == 2, "friendship tracked")
	check(p["seen_tips"].has("damaged"), "tips remembered")
	p["upgrades"] = {"lounge": 1, "coffee": 2}
	p["last_seen"] = 1000
	check(Economy.idle_income(p, 1000 + 3600) == 24, "coffee 2 = 24/h")
	check(Economy.idle_income(p, 1000 + 3600 * 100) == 24 * 8, "idle income capped at 8h")
	check(Economy.idle_income(p, 500) == 0, "clock going backwards gives nothing")


func test_balance() -> void:
	# Simulates a typical player (93% accuracy, ~1.1 s per parcel) who buys the
	# cheapest available item after each shift.
	var p := SaveSystem.default_profile()
	var first_buy := -1
	var shifts := 0
	var all_bought_at := -1
	var level12_at := -1
	var fails := 0
	var log := []
	for i in 400:
		var s := ShiftSession.new()
		s.setup("shift", p, 1000 + i)
		var sum := play(s, 0.93, 1.1, 600.0, 77 + i)
		Economy.apply_summary(p, sum)
		shifts += 1
		if not sum["completed"]:
			fails += 1
		if int(p["level"]) >= 12 and level12_at < 0:
			level12_at = shifts
		var bought := true
		while bought:
			bought = false
			var best := ""
			var best_cost := 1 << 30
			for id in Upgrades.DEFS:
				if Upgrades.can_buy(p, id) == "ok":
					var c := Upgrades.cost(id, Upgrades.level_of(p, id))
					if c < best_cost:
						best_cost = c
						best = id
			for id in Content.ROUTES:
				if Economy.can_buy_route(p, id) == "ok" and int(Content.ROUTES[id]["cost"]) < best_cost:
					best_cost = int(Content.ROUTES[id]["cost"])
					best = "route:" + id
			if best.begins_with("route:"):
				Economy.buy_route(p, best.substr(6))
				bought = true
			elif best != "":
				Upgrades.buy(p, best)
				bought = true
			if bought and first_buy < 0:
				first_buy = shifts
		if shifts in [1, 5, 10, 25, 50, 100, 150, 200, 300]:
			log.append("s%d: lv%d coins%d shards%d sum%d" % [shifts, int(p["level"]), int(p["coins"]), int(p["shards"]), int(sum["coins"])])
		var all_max := (p["routes"] as Array).size() == Content.ROUTES.size()
		for id in Upgrades.DEFS:
			if Upgrades.level_of(p, id) < int(Upgrades.DEFS[id]["max"]):
				all_max = false
		if all_max and all_bought_at < 0:
			all_bought_at = shifts
			break
	print("  balance: first buy after shift %d, level 12 at shift %d, everything at %d, failed shifts %d" % [first_buy, level12_at, all_bought_at, fails])
	print("  ", " | ".join(log))
	check(first_buy >= 1 and first_buy <= 2, "first upgrade within two shifts")
	check(all_bought_at < 0 or all_bought_at > 100, "can't buy everything quickly (%d)" % all_bought_at)
	check(level12_at > 0 and level12_at <= 45, "story levels reachable in a reasonable number of shifts")


func test_daily() -> void:
	var p := profile_at(6)
	var s := ShiftSession.new()
	s.setup("daily", p, 20261104)
	check(s.daily_mutator != "", "daily has a mutator")
	var sum := play(s, 1.0, 0.8)
	sum["day"] = "2026-11-04"
	var out := Economy.apply_summary(p, sum)
	check(int(out["daily_reward"]) == 3, "daily reward once")
	var out2 := Economy.apply_summary(p, sum)
	check(int(out2["daily_reward"]) == 0, "daily reward not twice")


# -------------------------------------------------------------------- save

func test_save_roundtrip() -> void:
	var path := "user://test_save.json"
	var p := SaveSystem.default_profile()
	p["coins"] = 777
	p["upgrades"] = {"press": 3}
	p["collection"] = {"floppy": 2}
	check(SaveSystem.save_profile(p, path), "save ok")
	var r := SaveSystem.load_profile(path)
	check(r["status"] == "ok", "load ok")
	check(int(r["profile"]["coins"]) == 777, "coins restored")
	check(Upgrades.level_of(r["profile"], "press") == 3, "upgrades restored")
	check(Upgrades.stats(r["profile"])["coin_base"] == 6, "stats work after JSON floats")
	var v1 := {"version": 1, "coins": 5, "routes": {"town": true, "steam": true}}
	var m := SaveSystem.migrate(v1)
	check(m["routes"] is Array and (m["routes"] as Array).has("steam"), "v1 routes migrated")
	check(m.has("settings") and m["settings"].has("music"), "missing keys filled")
	var weird := SaveSystem.migrate({"coins": "lots", "level": 900})
	check(int(weird["coins"]) == 0 and int(weird["level"]) == Progression.MAX_LEVEL, "bad values sanitised")


func test_save_corruption() -> void:
	var path := "user://test_corrupt.json"
	var p := SaveSystem.default_profile()
	p["coins"] = 11
	SaveSystem.save_profile(p, path)
	p["coins"] = 22
	SaveSystem.save_profile(p, path)   # .bak now holds 11
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var r := SaveSystem.load_profile(path)
	check(r["status"] == "backup" and int(r["profile"]["coins"]) == 11, "corrupt save recovered from backup")
	f = FileAccess.open(path + ".bak", FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	r = SaveSystem.load_profile(path)
	check(r["status"] == "reset", "both corrupt -> fresh profile")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	r = SaveSystem.load_profile(path)
	check(r["status"] == "new", "no file -> new")


# ------------------------------------------------------------------- story

func test_story() -> void:
	var p := SaveSystem.default_profile()
	check(Story.next_available(p) == 0, "prologue first")
	Story.complete(p, 0)
	check(Story.next_available(p) == -1, "chapter 1 needs a shift")
	p["shifts_done"] = 1
	check(Story.next_available(p) == 1, "chapter 1 after a shift")
	Story.complete(p, 1)
	check(int(p["coins"]) == 120 and p["story"]["met"].has("bit"), "rewards and met")
	check(Story.next_available(p) == -1, "chapter 2 needs robot repair")
	p["upgrades"] = {"robot": 1}
	check(Story.next_available(p) == 2, "chapter 2 after robot repair")
	# Every chapter is well formed.
	for i in StoryData.CHAPTERS.size():
		var c: Dictionary = StoryData.CHAPTERS[i]
		check(c["title"].size() == 2, "title uk/en " + c["id"])
		for line in c["lines"]:
			if line is Array:
				check(line.size() == 3 and (line[0] == "" or Content.CHARACTERS.has(line[0])), "line ok in " + c["id"])
			else:
				for o in line["choice"]:
					check(o.has("uk") and o.has("en"), "choice text " + c["id"])
	# Secret ending needs memory and hope.
	var fin: Dictionary = StoryData.CHAPTERS[Story.index_of("finale")]
	var balance: Dictionary = {}
	for line in fin["lines"]:
		if line is Dictionary:
			for o in line["choice"]:
				if o.get("ending", "") == "balance":
					balance = o
	check(not Story.option_available(p, balance), "secret ending locked by default")
	p["story"]["vars"] = {"memory": 3, "hope": 2, "trust": 0}
	check(Story.option_available(p, balance), "secret ending unlocked by choices")
	Story.apply_choice(p, balance)
	check(p["story"]["ending"] == "balance" and Story.city_mood(p) == "bright", "ending changes the city")


func test_i18n_keys() -> void:
	var i18n = load("res://scripts/autoload/i18n.gd").new()
	var missing := []
	for k in i18n.STRINGS:
		var e: Dictionary = i18n.STRINGS[k]
		if not (e.has("uk") and e.has("en")):
			missing.append(k)
	check(missing.is_empty(), "every UI string has uk and en: %s" % str(missing))
	for m in Progression.UNLOCK_ORDER:
		check(i18n.STRINGS.has("unlock_" + m), "unlock text for " + m)
	for m in ["hazard", "mystery", "damaged", "paradox", "urgent", "series", "collectible", "sender", "present",
			"ev_golden", "ev_calendar", "ev_mirror", "ev_cat", "ev_storm", "boomerang", "ev_blackout"]:
		check(i18n.STRINGS.has("tip_" + m), "tip text for " + m)
	i18n.free()


func test_boomerang() -> void:
	var g := PackageGenerator.new()
	g.setup(3, 20, ["town"])
	var n := 0
	for i in 3000:
		if g.next_parcel(Rules.make()).get("boomerang", false):
			n += 1
	check(n > 30, "boomerangs appear at level 20 (%d)" % n)
	var g2 := PackageGenerator.new()
	g2.setup(3, 13, ["town"])
	var n2 := 0
	for i in 2000:
		if g2.next_parcel(Rules.make()).get("boomerang", false):
			n2 += 1
	check(n2 == 0, "no boomerangs before level 14")
	var s := ShiftSession.new()
	s.setup("shift", profile_at(20), 60)
	var t := 0.0
	while s.current.is_empty() and t < 5.0:
		s.update(0.05)
		t += 0.05
	var p := s.current.duplicate()
	p["boomerang"] = true
	p["returned"] = false
	p["hazard"] = false
	p["riddle"] = ""
	p["year"] = 1990
	p["shown"] = "1990"
	s.current = p
	var rel := s.reliability
	var r := s.sort(Rules.Dir.RIGHT)
	check(not r["ok"] and r["boomerang_back"], "wrong boomerang comes back")
	check(s.reliability == rel and not r["life_lost"], "boomerang mistake costs no reliability")
	check(s.queue[0]["id"] == p["id"] and s.queue[0]["returned"], "boomerang is first in the queue")
	s.lift_timer = 0.0
	s.update(0.01)
	var r2 := s.sort(Rules.Dir.RIGHT)
	check(r2["life_lost"] and not r2["boomerang_back"], "second miss of a boomerang counts")


func test_achievements() -> void:
	var p := SaveSystem.default_profile()
	check(Achievements.check(p).is_empty(), "fresh profile has no achievements")
	p["shifts_done"] = 1
	p["stats"]["best_combo"] = 25
	var got := Achievements.check(p)
	check(got.has("first_shift") and got.has("combo_20"), "achievements granted %s" % str(got))
	check(int(p["shards"]) == 2, "achievement shards granted (%d)" % int(p["shards"]))
	check(Achievements.check(p).is_empty(), "achievements granted only once")
	var ids := {}
	for d in Achievements.DEFS:
		check(not ids.has(d[0]), "unique achievement " + d[0])
		ids[d[0]] = true
		check(d[4].size() == 2 and d[5].size() == 2, "achievement texts uk/en " + d[0])


func test_friend_letters() -> void:
	var p := SaveSystem.default_profile()
	var s := {"mode": "shift", "coins": 0, "shards": 0, "xp": 0, "sorted": 10, "correct": 10, "best_combo": 3,
		"duration": 60.0, "stars": 1, "found": [], "friends": {"olena": 9}, "score": 10, "seen_tips": []}
	var out := Economy.apply_summary(p, s)
	check(out["letters"].size() == 1 and out["letters"][0]["from"] == "olena", "friend letter at 8 parcels")
	out = Economy.apply_summary(p, s)
	check(out["letters"].is_empty(), "same letter not sent twice")
	for who in StoryData.FRIEND_LETTERS:
		check(Content.CHARACTERS.has(who), "friend letter sender exists " + who)


func test_seasons() -> void:
	check(Content.season(1) == "winter" and Content.season(12) == "winter", "winter")
	check(Content.season(4) == "spring" and Content.season(7) == "summer" and Content.season(11) == "autumn", "seasons")
	var seen := {}
	for d in 40:
		var ss := ShiftSession.new()
		ss.setup("daily", profile_at(6), 20261100 + d)
		seen[ss.daily_mutator] = true
	check(seen.size() == 6, "all 6 daily mutators occur (%s)" % str(seen.keys()))
