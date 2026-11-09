extends Node
## Automated checks. Run: godot --headless --path . -- --selftest
## Exit code 0 = everything passed. Uses its own save file, never the player's.

var main: Node
var passed := 0
var failed := 0
var lines: Array = []


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		lines.append("FAIL: " + what)
		print("FAIL: ", what)


func section(name: String) -> void:
	print("--- ", name)
	lines.append("--- " + name)


func run_all(p_main: Node) -> void:
	main = p_main
	Store.path = "user://test_save.json"
	Store.wipe()
	await get_tree().process_frame
	test_rules()
	test_solver_cross_check()
	test_levels()
	test_generated()
	test_generator_budget()
	test_translations()
	await test_game_flow()
	await test_input()
	await test_restore()
	await test_language_switch()
	Store.wipe()
	print("RESULT: %d passed, %d failed" % [passed, failed])
	var f := FileAccess.open("user://test_report.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\nRESULT: %d passed, %d failed\n" % [passed, failed])
	f.close()
	get_tree().quit(0 if failed == 0 else 1)


# ------------------------------------------------------------------ pure rules

func _play(layout: Array, moves: Array) -> GameState:
	var g := GameState.new()
	g.setup(layout)
	for m in moves:
		g.take(m)
	return g


func test_rules() -> void:
	section("rules")
	# stars: 2 in stack 0 + 1 in stack 2; leaves: 2 in stack 1 + 1 in stack 3
	var lay := [[0, 0], [1, 1], [0], [1]]
	check(Rules.validate_layout(lay) == "", "small layout is valid")
	var g := _play(lay, [0, 0, 1, 1])
	check(g.tray_count() == 4 and not g.lost, "four tiles in the tray, still playing")
	var r := g.take(2)
	check(r["cleared"].size() == 3, "a star on the fifth slot completes the triple")
	check(not r["lost"] and not g.lost, "triple on the fifth slot does not lose")
	check(g.tray_count() == 2 and g.tray.count(-1) == 3, "two leaves left, three slots free")
	check(g.tray.count(1) == 2, "the leaves stay in the tray")
	r = g.take(3)
	check(r["won"] and g.won and g.tray_count() == 0, "the last triple of the level wins")
	check(not g.can_take(0) and not g.take(0)["ok"], "no moves after a win")

	var lay2 := [[0, 0, 0], [1, 1, 1], [2, 2, 2], []]
	var g2 := _play(lay2, [0, 0, 1, 1])
	r = g2.take(2)
	check(r["lost"] and g2.lost and r["cleared"].is_empty(), "fifth tile without a triple loses")
	check(g2.tray_count() == 5, "the full tray holds five tiles")
	check(not g2.can_take(0), "no moves after a loss")

	# shared rule: add_tile directly
	var c := PackedInt32Array([2, 2, 0, 0, 0])
	var f := Rules.add_tile(c, 0)
	check(f == Rules.CLEARED and c[0] == 0, "add_tile clears before checking the tray")
	c = PackedInt32Array([2, 2, 0, 0, 0])
	f = Rules.add_tile(c, 2)
	check(f == Rules.LOST, "add_tile: five without a triple is LOST")

	# snapshots
	var g3 := _play(lay, [0, 0, 1, 1])
	var snap := g3.snapshot()
	g3.take(2)
	check(g3.restore(snap), "restore of a pre-clear snapshot")
	check(g3.tray_count() == 4 and g3.heights[2] == 1, "restoring brings the cleared triple and the stack back")
	check(not g3.restore({"h": [2, 2, 1, 1], "tray": [0, 0, 0, -1, -1]}), "an impossible tray is rejected")
	check(Rules.validate_layout([[0, 0], [1], [], []]) != "", "counts not divisible by three are rejected")


## Independent brute force (no memo, no shared state) on small layouts must agree with the solver.
func _brute(layout: Array, h: Array, counts: Array) -> bool:
	var left := 0
	for x in h:
		left += x
	if left == 0:
		return true
	for i in 4:
		if h[i] == 0:
			continue
		var t: int = layout[i][h[i] - 1]
		var c2 := counts.duplicate()
		c2[t] += 1
		if c2[t] == 3:
			c2[t] = 0
		var tot := 0
		for v in c2:
			tot += v
		if tot >= 5:
			continue
		var h2 := h.duplicate()
		h2[i] -= 1
		if _brute(layout, h2, c2):
			return true
	return false


func test_solver_cross_check() -> void:
	section("solver vs brute force")
	var agree := 0
	var solvable := 0
	for s in 150:
		var rng := Generator._rng(777 + s, 0)
		var lay := Generator.make_layout(rng, [9, 12, 12, 15][s % 4], [3, 3, 4, 4][s % 4])
		var m := Solver.analyze(lay)
		var h := []
		for col in lay:
			h.append(col.size())
		var b := _brute(lay, h, [0, 0, 0, 0, 0])
		if b == m["solvable"]:
			agree += 1
		if b:
			solvable += 1
	check(agree == 150, "solver agrees with brute force on 150 small layouts (%d agree, %d solvable)" % [agree, solvable])


func _replays(p: Dictionary) -> bool:
	var g := GameState.new()
	g.setup(p["stacks"])
	for m in p["solution"]:
		var r := g.take(int(m))
		if not r["ok"]:
			return false
	return g.won


func test_levels() -> void:
	section("30 levels")
	var lv := Puzzles.levels()
	check(lv.size() == 30, "30 levels present")
	var prev := -1.0
	var dips := 0
	for p in lv:
		var n: int = p["level"]
		var items := Rules.tile_total(p["stacks"])
		var types := Rules.types_used(p["stacks"])
		check(Rules.validate_layout(p["stacks"]) == "", "L%d: layout valid, every type a multiple of 3" % n)
		var m := Solver.analyze(p["stacks"])
		check(m["solvable"], "L%d: solver finds a win with a 5-slot tray" % n)
		check(_replays(p), "L%d: stored solution replays to a win through GameState.take" % n)
		check(p["solution"].size() == items, "L%d: solution takes every tile" % n)
		var hmax := 0
		for col in p["stacks"]:
			hmax = maxi(hmax, col.size())
		check(hmax <= Generator.MAX_HEIGHT, "L%d: stacks fit on screen (max height %d)" % [n, hmax])
		if n <= 5:
			check(items >= 9 and items <= 12 and types >= 2 and types <= 3, "L%d: early level has 9-12 tiles, 2-3 types" % n)
		if n >= 13 and n <= 21:
			check(items >= 18 and items <= 24 and types >= 3 and types <= 5, "L%d: middle level has 18-24 tiles, 3-5 types" % n)
		check(items <= 30, "L%d: at most 30 tiles" % n)
		var rng := Generator._rng(int(p["seed"]), 0)
		var again := Generator.make_layout(rng, items, types)
		check(str(again) == str(p["stacks"]), "L%d: seed rebuilds the same layout" % n)
		var sc: float = m["score"]
		if sc < prev - 0.6:
			dips += 1
		prev = sc
		lines.append("L%02d tiles %2d types %d score %5.2f greedy %s critical %d" % [n, items, types, sc, m["greedy"], m["critical"]])
	check(dips == 0, "difficulty never drops sharply from one level to the next")
	check(Solver.analyze(lv[0]["stacks"])["score"] < 1.0 and Solver.analyze(lv[29]["stacks"])["score"] > 10.0, "level 1 is easy, level 30 is hard")
	check(Solver.analyze(lv[0]["stacks"])["greedy"], "level 1 is won by plain matching")
	var late_plan := 0
	for k in range(20, 30):
		if not Solver.analyze(lv[k]["stacks"])["greedy"]:
			late_plan += 1
	check(late_plan == 10, "levels 21-30 all need planning ahead (pair-first play loses)")


func test_generated() -> void:
	section("generated puzzles")
	var ok := 0
	var replay := 0
	var fallback_needed := 0
	var total := 0
	var t0 := Time.get_ticks_msec()
	for k in 120:
		var tier := Puzzles.endless_tier(k)
		var seed := 5000 + k * 13
		var r := Generator.generate(seed, tier, 3000000, 400)
		total += 1
		if not r["ok"]:
			fallback_needed += 1
			continue
		ok += 1
		var p: Dictionary = r["puzzle"]
		if Rules.validate_layout(p["stacks"]) == "" and _replays(p):
			replay += 1
		var again := Generator.regenerate_layout(seed, p["attempt"], tier)
		check(str(again) == str(p["stacks"]), "generated #%d: seed + attempt rebuild the layout" % k)
		var sc: float = p["score"]
		check(sc >= tier["score"][0] and sc <= tier["score"][1], "generated #%d: difficulty inside its band" % k)
	lines.append("generated %d/%d in %d ms, %d replayed, %d needed the spare pool" % [ok, total, Time.get_ticks_msec() - t0, replay, fallback_needed])
	check(ok >= 110, "generator delivers at least 110 of 120 requests (%d)" % ok)
	check(replay == ok, "every generated puzzle replays to a win (%d/%d)" % [replay, ok])
	var pool := Puzzles.fallback()
	var pool_ok := 0
	for p in pool:
		if Rules.validate_layout(p["stacks"]) == "" and _replays(p) and Solver.analyze(p["stacks"])["solvable"]:
			pool_ok += 1
	check(pool.size() >= 100 and pool_ok == pool.size(), "spare pool: %d of %d verified" % [pool_ok, pool.size()])


func test_generator_budget() -> void:
	section("generator limits")
	var r := Generator.generate(42, {"items": [30, 30], "types": [5, 5], "score": [500.0, 600.0]}, 0, 400)
	check(not r["ok"] and r["attempts"] == 1, "zero time budget stops after one attempt")
	r = Generator.generate(42, {"items": [30, 30], "types": [5, 5], "score": [500.0, 600.0]}, 10000000, 25)
	check(not r["ok"] and r["attempts"] == 25, "attempt limit is respected")
	r = Generator.generate(43, {"items": [30, 30], "types": [5, 5], "score": [500.0, 600.0]}, 200000, 100000)
	check(r["usec"] < 400000, "time budget is respected (%d us)" % r["usec"])


func test_translations() -> void:
	section("translations")
	var f := FileAccess.open("res://translations/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	check(header[0] == "keys" and header.has("en") and header.has("uk"), "table has en and uk columns")
	var keys := {}
	var rx := RegEx.create_from_string("\\{[a-z]+\\}")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0] == "":
			continue
		keys[row[0]] = true
		check(row[1].strip_edges() != "" and row[2].strip_edges() != "", "%s: text in both languages" % row[0])
		var a := []
		for m in rx.search_all(row[1]):
			a.append(m.get_string())
		var b := []
		for m in rx.search_all(row[2]):
			b.append(m.get_string())
		a.sort()
		b.sort()
		check(a == b, "%s: same placeholders in both languages" % row[0])
	# every key the code shows must be in the table
	var used := {}
	var krx := RegEx.create_from_string("\"([A-Z][A-Z0-9_]{2,})\"")
	for path in ["res://scripts/main.gd", "res://scripts/panels.gd", "res://scripts/ui_kit.gd"]:
		for m in krx.search_all(FileAccess.get_file_as_string(path)):
			used[m.get_string(1)] = true
	var missing := []
	for k in used:
		if k in ["PUZZLES_SOLVED", "STAT_LEVELS", "STAT_EXTRA", "STAT_CLEAN", "STAT_TRIPLES"] or k.begins_with("A11Y") or k.begins_with("TYPE_") or true:
			if not keys.has(k) and not k in ["SoftButton", "AccentButton", "ChosenButton"]:
				missing.append(k)
	check(missing.is_empty(), "every key used in code exists in the table %s" % str(missing))
	check(Loc.detect("uk") == "uk" and Loc.detect("uk_UA") == "uk" and Loc.detect("uk-UA") == "uk", "Ukrainian system -> uk")
	check(Loc.detect("en_US") == "en" and Loc.detect("ru_RU") == "en" and Loc.detect("de") == "en" and Loc.detect("") == "en", "other systems -> en")
	TranslationServer.set_locale("uk")
	check(Loc.t("LEVEL_N", {"n": 7}) == "Рівень 7", "uk template: Рівень 7")
	TranslationServer.set_locale("en")
	check(Loc.t("LEVEL_N", {"n": 7}) == "Level 7", "en template: Level 7")
	check(Loc.t("APP_TITLE") == "Pocket Triples", "title is Pocket Triples in English")
	TranslationServer.set_locale("uk")
	check(Loc.t("APP_TITLE") == "Pocket Triples", "title is Pocket Triples in Ukrainian")


# ------------------------------------------------------------------ the real game screen

func _custom(layout: Array) -> void:
	main.panels.close_all()
	main._begin("level", {"stacks": layout, "solution": [], "seed": 1, "level": 1}, 1)


func test_game_flow() -> void:
	section("game flow")
	Store.wipe()
	Store.progress()["tutorial_done"] = true
	_custom([[0, 0], [1, 1], [0], [1]])
	for m in [0, 0, 1, 1]:
		main.on_column_tapped(m)
	main.on_column_tapped(2)
	check(main.gs.tray_count() == 2 and not main.gs.lost, "game: triple on the fifth slot keeps playing")
	await get_tree().create_timer(0.05).timeout
	main.undo()
	check(main.gs.tray_count() == 4 and main.gs.heights[2] == 1, "game: undo brings back the cleared triple and the stack")
	check(main.gs.tray.count(0) == 2 and main.gs.tray.count(1) == 2, "game: the two stars and two leaves are back")
	main.on_column_tapped(2)
	main.on_column_tapped(3)
	check(main.gs.won, "game: the last triple wins")
	var p := Store.progress()
	check(int(p["solved_total"]) == 1 and p["solved_levels"].has(1) and int(p["unlocked"]) == 2, "win recorded: 1 solved, level 2 unlocked")
	check(not main._record_win() and not main._record_win(), "a second win signal is not recorded")
	main.on_column_tapped(0)
	check(int(p["solved_total"]) == 1, "taps after the win change nothing")
	await get_tree().create_timer(1.2).timeout
	check(main.panels.is_open("win"), "win panel shown")
	# reload from disk: still recorded once
	Store.load_data()
	check(main._resume("level") and main.gs.won, "won puzzle restored as won")
	check(not main._record_win(), "restored win is not recorded again")
	check(int(Store.progress()["solved_total"]) == 1 and int(Store.progress()["unlocked"]) == 2, "still exactly one win after restore")
	# replaying the same level is a new run and may count again, but only once
	main.restart()
	for m in [0, 0, 1, 1, 2, 3]:
		main.on_column_tapped(m)
	check(int(Store.progress()["solved_total"]) == 2, "a replay is a new solve")
	check(int(Store.progress()["unlocked"]) == 2, "unlock is not repeated by the replay")

	# loss and undo after the loss
	_custom([[0, 0, 0], [1, 1, 1], [2, 2, 2], []])
	for m in [0, 0, 1, 1, 2]:
		main.on_column_tapped(m)
	check(main.gs.lost, "game: five without a triple loses")
	await get_tree().create_timer(1.0).timeout
	check(main.panels.is_open("lose"), "tray-full panel shown")
	main.on_column_tapped(0)
	check(main.gs.tray_count() == 5, "no move while lost")
	main._on_panel_action("undo", null)
	check(not main.gs.lost and main.gs.tray_count() == 4 and not main.panels.is_open("lose"), "undo works after a loss")
	main.restart()
	check(main.gs.tray_count() == 0 and main.gs.heights[0] == 3 and main.run["history"].is_empty(), "restart returns the same starting layout")
	check(str(main.gs.layout) == str([[0, 0, 0], [1, 1, 1], [2, 2, 2], []]), "restart keeps the very same puzzle")

	# every level through the real game screen, by its stored solution
	var all_ok := true
	for n in range(1, 31):
		main.start_level(n)
		for m in main.run["puzzle"]["solution"]:
			main.on_column_tapped(int(m))
		if not main.gs.won:
			all_ok = false
	check(all_ok, "all 30 levels won on the game screen with their stored solutions")
	check(int(Store.progress()["unlocked"]) == 30 and Store.progress()["solved_levels"].size() == 30, "all levels unlocked and solved once")

	# endless: explicit request, prepared on a thread
	main._prepare_endless()
	var t0 := Time.get_ticks_msec()
	while main.worker.busy and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
	await get_tree().process_frame
	main.new_endless()
	check(main.mode == "endless" and main.run["puzzle"]["stacks"].size() == 4, "Another Puzzle starts a generated puzzle")
	check(_replays(main.run["puzzle"]), "the endless puzzle has a verified winning line")
	var first: String = str(main.run["puzzle"]["stacks"])
	main.restart()
	check(str(main.gs.layout) == first, "restart of an endless puzzle keeps its layout")
	var idx: int = main.run["index"]
	await get_tree().create_timer(0.3).timeout
	main._on_panel_action("next", null)
	var t1 := Time.get_ticks_msec()
	while main.waiting_endless >= 0.0 and Time.get_ticks_msec() - t1 < 4000:
		await get_tree().process_frame
	check(main.run["index"] == idx + 1, "Next Puzzle creates the next one")
	# budget exhausted -> spare pool
	main.prepared = {}
	main.worker.stop()
	var before := int(Store.progress()["fallback_index"])
	main.waiting_endless = 0.0001
	main.panels.open("preparing")
	await get_tree().process_frame
	await get_tree().process_frame
	if main.waiting_endless >= 0.0:
		await get_tree().create_timer(0.1).timeout
	check(int(Store.progress()["fallback_index"]) >= before + 1 or main.run.get("puzzle", {}).get("fallback", false), "when the generator is out of time a verified spare puzzle is used")


func _touch(pos: Vector2, index := 0, pressed := true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	main.get_viewport().push_input(e, true)


func _mouse(pos: Vector2, emulated := true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = true
	e.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
	main.get_viewport().push_input(e, true)
	var u := e.duplicate()
	u.pressed = false
	main.get_viewport().push_input(u, true)


func _consistent() -> bool:
	var g: GameState = main.gs
	var taken := 0
	for i in g.layout.size():
		taken += g.layout[i].size() - g.heights[i]
	var cleared := 0
	for h in main.run["history"]:
		cleared += h["move"]["cleared"].size()
	var sum := 0
	for c in g.counts:
		sum += c
	return taken == cleared + g.tray_count() and sum == g.tray_count() and main.run["history"].size() == taken


func test_input() -> void:
	section("touch input")
	Store.progress()["tutorial_done"] = true
	_custom([[0, 1, 2, 0], [1, 2, 0, 1], [2, 0, 1, 2], [3, 3, 3]])
	await get_tree().process_frame
	var b: Board = main.board
	var c0: Vector2 = b.col_rects[0].get_center()
	var c1: Vector2 = b.col_rects[1].get_center()
	_touch(c0)
	_touch(c0, 0, false)
	check(main.run["history"].size() == 1, "one tap = one move")
	_mouse(c0, true)
	check(main.run["history"].size() == 1, "the emulated mouse click of the same tap is ignored")
	_touch(c0)
	_touch(c0, 0, false)
	_touch(c0)
	_touch(c0, 0, false)
	check(main.run["history"].size() == 3, "a fast double tap makes exactly two moves")
	check(_consistent(), "tile count consistent after fast taps")
	main.undo()
	main.undo()
	main.undo()
	_touch(c0, 0)
	_touch(c1, 1)
	_touch(c0, 0, false)
	_touch(c1, 1, false)
	check(main.run["history"].size() == 2, "two fingers on two stacks = two moves")
	check(_consistent(), "tile count consistent with two fingers")
	var tray_before: int = main.gs.tray_count()
	_touch(Vector2(c0.x, b.tray_rect.get_center().y))
	check(main.gs.tray_count() == tray_before and main.run["history"].size() == 2, "a tap on the tray is not a move")
	main._open_panel("pause")
	_touch(c0)
	check(main.run["history"].size() == 2, "no moves through the pause panel")
	main._on_panel_action("resume", null)
	_touch(c0)
	check(main.run["history"].size() == 3, "moves again after Resume")
	# taps during the flight animation
	for k in 4:
		_touch(b.col_rects[k % 3].get_center(), k)
	check(_consistent(), "tile count consistent with taps during the animation")
	await get_tree().create_timer(0.6).timeout
	var shown := 0
	for v in b.tray_nodes:
		if v != null:
			shown += 1
	check(shown == main.gs.tray_count(), "the tray on screen matches the logical tray after the animations")
	var stack_ok := true
	for i in 4:
		if b.stack_nodes[i].size() != main.gs.heights[i]:
			stack_ok = false
	check(stack_ok, "stacks on screen match the logical stacks")


func test_restore() -> void:
	section("save and restore")
	Store.progress()["tutorial_done"] = true
	main.start_level(12)
	var sol: Array = main.run["puzzle"]["solution"]
	for k in 5:
		main.on_column_tapped(int(sol[k]))
	# interrupted mid-animation: the app goes to the background right after a tap
	main.on_column_tapped(int(sol[5]))
	main._go_background()
	var heights := Array(main.gs.heights)
	var tray: Array = main.gs.tray.duplicate()
	var hist: int = main.run["history"].size()
	check(main.panels.is_open("pause"), "going to the background pauses the game")
	check(FileAccess.file_exists(Store.path), "save file written")
	var raw = JSON.parse_string(FileAccess.get_file_as_string(Store.path))
	check(raw is Dictionary, "save file is valid JSON")
	# simulate closing and starting again
	Store.load_data()
	check(not Store.first_launch, "second start is not a first launch")
	main.panels.close_all()
	check(main._resume("level"), "puzzle restored after restart")
	check(Array(main.gs.heights) == heights and main.gs.tray == tray, "stacks and tray restored exactly (finished move)")
	check(main.run["history"].size() == hist, "undo history restored")
	var stack_ok := true
	for i in 4:
		if main.board.stack_nodes[i].size() != main.gs.heights[i]:
			stack_ok = false
	check(stack_ok, "the restored board shows the finished move, no half animation")
	main.undo()
	check(main.run["history"].size() == hist - 1, "undo works after a restore")
	for k in range(5, sol.size()):
		main.on_column_tapped(int(sol[k]))
	check(main.gs.won, "the restored puzzle can still be won by its solution")
	# a broken save file falls back to the backup copy
	Store.write()
	Store.write()
	var f := FileAccess.open(Store.path, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	Store.load_data()
	check(not Store.first_launch and int(Store.progress()["unlocked"]) >= 12, "a damaged save falls back to save.bak")


func test_language_switch() -> void:
	section("language switch mid-puzzle")
	main.panels.close_all()
	main.start_level(10)
	var sol: Array = main.run["puzzle"]["solution"]
	for k in 4:
		main.on_column_tapped(int(sol[k]))
	var heights := Array(main.gs.heights)
	var hist: int = main.run["history"].size()
	var solved := int(Store.progress()["solved_total"])
	await main.set_language("en")
	check(main.w["title"].text == "Level 10", "title switches to English at once")
	check(main.w["undo"].text == "Undo" and main.w["restart"].text == "Restart", "buttons switch to English")
	check(Array(main.gs.heights) == heights and main.run["history"].size() == hist, "puzzle and history untouched by the switch")
	check(int(Store.progress()["solved_total"]) == solved, "progress untouched by the switch")
	await main.set_language("uk")
	check(main.w["title"].text == "Рівень 10" and main.w["undo"].text == "Скасувати", "back to Ukrainian")
	Store.load_data()
	check(Store.settings()["lang"] == "uk", "chosen language saved")
