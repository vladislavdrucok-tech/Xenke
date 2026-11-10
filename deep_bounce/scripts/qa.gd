extends Node
## Automated checks that need the real scene (run with a renderer, e.g. under xvfb):
##   godot --path . -- --qa=ref   --out=DIR    reference scene: 42 m, 16 balls, 28 crystals, mid-volley
##   godot --path . -- --qa=tour  --out=DIR    every screen in both languages
##   godot --path . -- --qa=flow  --out=DIR    first launch -> runs -> purchase -> next run -> restart restore
##   godot --path . -- --qa=perf  --out=DIR    longest volley: 32 balls, all upgrades, frame times
## Nothing here runs in normal play. Writes report lines to DIR/qa_<mode>.txt.

var main: Node
var mode := ""
var out := "user://qa"
var lines: PackedStringArray = []
var fails := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			mode = a.substr(5)
		elif a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	G.set_meta("qa", true)
	_run.call_deferred()

func log_line(s: String) -> void:
	print(s)
	lines.append(s)

func check(cond: bool, name: String, info := "") -> void:
	log_line(("PASS  " if cond else "FAIL  ") + name + ("" if info == "" else "  (" + info + ")"))
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	log_line("shot " + name)

func finish() -> void:
	log_line("QA %s %s" % [mode, "PASS" if fails == 0 else "FAIL (%d)" % fails])
	var f := FileAccess.open(out.path_join("qa_%s.txt" % mode), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	get_tree().quit(0 if fails == 0 else 1)

func _run() -> void:
	await frames(5)
	match mode:
		"ref":
			await _ref()
		"tour":
			await _tour()
		"flow":
			await _flow()
		"perf":
			await _perf()
		"speed":
			await _speed()
		"shifts":
			await _shifts()
		"demo":
			await _demo()
		"start":
			await _start()
		"s29":
			await load("res://scripts/qa_s29.gd").new().run(self)
		_:
			log_line("unknown qa mode " + mode)
	finish()

func step_ticks(n: int) -> void:
	var s: Sim = main.sim
	for i in n:
		if s.phase != Sim.PH_VOLLEY:
			break
		main.world.remember_positions()
		s.step()
		main._consume_events()
	main.world.interp = 1.0

# ---------------------------------------------------------------- reference scene

func build_ref_board() -> void:
	## Same situation as the concept frame: 42 m deep, 16 balls, 28 crystals, a volley ricocheting down the
	## open right side past the big 3, 5, 8, 12 and 16 stones.
	var s: Sim = main.sim
	s.new_run(4242)
	s.depth = 42
	s.volleys = 42
	s.top = 42
	s.balls = 16
	s.heavy = 0
	s.electric = 0
	s.blocks = {}
	s.grid = {}
	var T := s.top
	var layout := [
		# c, visible row, w, h, hp, max hp, rock pattern
		[0, 0, 1, 1, 2, 2, 2], [1, 1, 1, 1, 1, 1, 3],
		[0, 2, 2, 2, 3, 4, 0], [2, 2, 2, 2, 5, 6, 1],
		[0, 4, 2, 2, 8, 9, 3], [2, 4, 2, 2, 12, 30, 0],
		[0, 6, 1, 1, 2, 2, 1], [1, 6, 2, 2, 16, 18, 2], [0, 7, 1, 1, 1, 1, 0],
		[3, 7, 1, 1, 1, 2, 3], [5, 7, 1, 1, 3, 3, 0], [6, 6, 1, 2, 4, 5, 1],
		[0, 8, 1, 2, 5, 5, 3], [3, 8, 1, 1, 2, 2, 2], [4, 8, 1, 1, 1, 1, 1], [5, 8, 1, 1, 2, 2, 3],
		[1, 8, 2, 1, 7, 7, 1], [1, 9, 2, 1, 9, 9, 0], [3, 9, 2, 1, 6, 6, 2], [5, 9, 2, 1, 4, 4, 1],
	]
	for L in layout:
		var id := s.next_id
		s._add_block({"c": L[0], "r": T + L[1], "w": L[2], "h": L[3], "hp": L[4], "g": L[2] * L[3], "v": L[6], "vein": false})
		s.blocks[id].mhp = L[5]
		s.blocks[id].v = L[6]
	s.gen_rows = T + Sim.VIS_ROWS
	s._ensure_rows()
	G.meta.crystals = 28

func _ref() -> void:
	G.settings.lang = "en"
	G.meta.skin = "classic"
	main.start_new_run(4242)
	build_ref_board()
	main.world.clear_blocks()
	main.world.sync_blocks(true)
	main.world.scroll = 42 * Sim.CELL
	main.world.scroll_target = main.world.scroll
	main.hud.hide_hint()
	G.meta.tutorial = 6
	await frames(4)
	await shot("ref_aim_before")
	var s: Sim = main.sim
	var ang := 0.92
	main.world.aim_angle = ang
	main.world.aim_pts = s.preview(ang)
	main.world.aim_visible = true
	await frames(10)
	await shot("ref_aiming")
	main.world.aim_visible = false
	s.fire(ang)
	main.paused = true
	step_ticks(52)
	main.world.fx.break_stone(Vector2(Sim.FIELD_X0 + 4.5 * Sim.CELL, Sim.DANGER_Y + 2.5 * Sim.CELL), 1, 1, 2)
	await frames(8)
	await shot("ref_volley")
	step_ticks(30)
	await frames(2)
	await shot("ref_volley_later")
	check(main.hud.balls_label.text == "16 balls", "reference HUD shows 16 balls", main.hud.balls_label.text)
	check(main.hud.depth_label.text == "Depth 42 m", "reference HUD shows Depth 42 m", main.hud.depth_label.text)
	check(main.hud.gems_label.text == "28" or int(main.hud.gems_label.text) >= 28, "reference HUD shows 28 crystals", main.hud.gems_label.text)
	G.settings.lang = "uk"
	G.lang_changed.emit()
	await frames(4)
	await shot("ref_volley_uk")

# ---------------------------------------------------------------- tour of screens

func _tour() -> void:
	for lang in ["en", "uk"]:
		G.settings.lang = lang
		G.lang_changed.emit()
		main.to_menu()
		await shot("menu_" + lang)
		main.screens.show_settings()
		await shot("settings_" + lang)
		main.screens.show_cosmetics()
		await shot("cosmetics_" + lang)
		main.screens.close()
		G.meta.tutorial = 0
		main.start_new_run(777)
		await frames(10)
		await shot("tutorial_aim_" + lang)
		main.sim.heavy = 1
		main.sim.electric = 2
		main.sim.balls = 16
		main.sim.volleys = 1
		main.hud.update_state(main.sim, 0, 1, false)
		main.hud.show_series_info()
		await frames(4)
		await shot("info_series_" + lang)
		main.hud.hide_info()
		main.hud.show_upgrade_info()
		await frames(4)
		await shot("info_upgrade_" + lang)
		main.hud.hide_info()
		main.screens.show_upgrade(["balls", "heavy", "electric"])
		await shot("upgrade_" + lang)
		main.screens.show_pause()
		await shot("pause_" + lang)
		main.screens.close()
		main.screens.show_gameover({"record": true, "depth": 37, "gems": 64, "broken": 51})
		await shot("gameover_" + lang)
		main.screens.close()

# ---------------------------------------------------------------- full player path

func play_volley(angle: float) -> void:
	var s: Sim = main.sim
	main._fire(angle)
	var guard := 0
	while s.phase == Sim.PH_VOLLEY and guard < 5000:
		main.world.remember_positions()
		s.step()
		main._consume_events()
		guard += 1
	await frames(1)

func _flow() -> void:
	# 1) first launch: no save
	G.run = {}
	G.meta = {"crystals": 0, "best": 0, "owned": ["classic"], "skin": "classic", "tutorial": 0, "runs": 0, "broken": 0, "spent": 0}
	G.save_game()
	main.to_menu()
	await frames(3)
	check(not G.has_run(), "fresh install: no run, Continue disabled")
	await shot("flow_01_menu_fresh")
	main.menu_play()
	await frames(5)
	check(main.mode == main.M_GAME and main.sim.phase == Sim.PH_AIM, "Play starts a run in aiming phase")
	check(main.hud.hint.visible, "first run shows the aiming hint")
	await shot("flow_02_first_aim")
	# 2) play runs until crystals buy the first finish
	var runs := 0
	var volleys := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	while G.meta.crystals < G.SKIN_PRICE["ember"] and runs < 12:
		var s: Sim = main.sim
		while s.phase != Sim.PH_OVER and volleys < 4000:
			if s.phase == Sim.PH_UPGRADE:
				main.pick_upgrade(s.upgrade_opts[rng.randi_range(0, s.upgrade_opts.size() - 1)])
			elif s.phase == Sim.PH_AIM:
				await play_volley(_bot_angle(s, rng))
				volleys += 1
				if volleys == 6:
					# interruption in the middle of a volley, then a cold restart from the save file
					await _check_restart_restore()
		runs += 1
		main.over_timer = -1.0
		main._game_over()
		await frames(2)
		if runs == 1:
			await shot("flow_03_gameover")
			check(not G.has_run() and G.meta.best > 0, "game over clears the run and records the depth", "best %d" % G.meta.best)
		main.start_new_run()
	log_line("runs played: %d, volleys: %d, crystals: %d, best %d m" % [runs, volleys, G.meta.crystals, G.meta.best])
	# 3) purchase
	var before := int(G.meta.crystals)
	check(G.buy_skin("ember"), "buy Ember Iron with earned crystals")
	var reread := FileAccess.get_file_as_string(G.SAVE_PATH)
	var d: Dictionary = JSON.parse_string(reread)
	check(int(d.meta.crystals) == before - G.SKIN_PRICE["ember"] and d.meta.owned.has("ember") and d.meta.skin == "ember",
		"purchase stored atomically: price spent and finish owned in one save")
	check(not G.buy_skin("ember"), "the same finish cannot be bought twice")
	main.apply_skin()
	main.start_new_run()
	await frames(5)
	check(main.world.skin == "ember", "the next run uses the purchased finish")
	await shot("flow_04_new_skin")
	# 4) restart: the save restores the run exactly
	await play_volley(1.2)
	G.store_run(main.sim)
	var h1: int = main.sim.state_hash()
	G.run = {}
	G.load_game()
	var s2 := Sim.new()
	s2.from_dict(G.run)
	check(s2.state_hash() == h1, "after a restart the run loads identically")

func _check_restart_restore() -> void:
	var s: Sim = main.sim
	if s.phase != Sim.PH_AIM:
		return
	main._fire(1.05)
	for i in 40:
		s.step()
		main._consume_events()
	main._notification(NOTIFICATION_APPLICATION_PAUSED)   # app minimised mid-flight
	check(main.paused and main.screens.current == "pause", "minimising during a volley saves and shows the pause screen")
	var wallet := int(G.meta.crystals)
	# finish the volley in memory, remember the outcome
	var ref := s.clone()
	while ref.phase == Sim.PH_VOLLEY:
		ref.step()
	# cold start: read the file into a new simulation
	G.load_game()
	var s2 := Sim.new()
	s2.from_dict(G.run)
	while s2.phase == Sim.PH_VOLLEY:
		s2.step()
	check(s2.state_hash() == ref.state_hash(), "volley resumed from the saved file ends exactly like the uninterrupted one")
	check(int(G.meta.crystals) == wallet, "no crystals duplicated by the restore")
	main.resume_from_pause()
	while s.phase == Sim.PH_VOLLEY:
		s.step()
		main._consume_events()

func _bot_angle(s: Sim, rng: RandomNumberGenerator) -> float:
	# a decent human-like player: tries 9 angles, keeps the one that deals the most damage
	var best := 1.2
	var best_score := -1.0
	for i in 9:
		var a := 0.18 + (PI - 0.36) * (float(i) + rng.randf()) / 9.0
		var c := s.clone()
		c.fire(a)
		var n := 0
		while c.phase == Sim.PH_VOLLEY and n < 3000:
			c.step()
			n += 1
		var score: float = float(c.v_damage) + c.stats.destroyed * 2.0
		if score > best_score:
			best_score = score
			best = a
	return best

# ---------------------------------------------------------------- performance

func _perf() -> void:
	## Worst case: 32 balls with every upgrade drop through a single gap into a closed chamber and bounce
	## there until they find the gap again (or the flight limit recalls them).
	G.meta.skin = "classic"
	main.start_new_run(31337)
	var s: Sim = main.sim
	s.balls = 32
	s.heavy = 3
	s.electric = 3
	main.world.clear_blocks()
	s.blocks = {}
	s.grid = {}
	for c in 7:
		if c != 3:
			s._add_block({"c": c, "r": s.top + 1, "w": 1, "h": 1, "hp": 9999, "g": 1, "v": c % 4, "vein": false})
	for vr in range(6, 10):
		for c in 7:
			if (c + vr) % 3 == 0:
				s._add_block({"c": c, "r": s.top + vr, "w": 1, "h": 1, "hp": 9999, "g": 1, "v": (c + vr) % 4, "vein": false})
	main.world.sync_blocks(true)
	G.meta.tutorial = 6
	await frames(5)
	main._fire(PI * 0.5 - 0.06)
	var times: Array = []
	var sim_us := 0
	var t0 := Time.get_ticks_usec()
	var n := 0
	var ticks0 := s.v_tick
	while s.phase == Sim.PH_VOLLEY and n < 6000:
		var t1 := Time.get_ticks_usec()
		await get_tree().process_frame
		times.append((Time.get_ticks_usec() - t1) / 1000.0)
		n += 1
		if n == 150:
			await shot("perf_32_balls")
	var total_ticks := s.v_tick if s.phase == Sim.PH_VOLLEY else 0
	# pure simulation cost of the same volley, measured without rendering
	var c := Sim.new()
	c.from_dict(main.sim.to_dict())
	times.sort()
	var avg := 0.0
	for x in times:
		avg += x
	avg /= maxf(1.0, times.size())
	log_line("render+sim frames %d, avg %.2f ms, p95 %.2f ms, max %.2f ms, wall %.1f s" % [times.size(), avg, times[int(times.size() * 0.95)], times[-1], (Time.get_ticks_usec() - t0) / 1e6])
	check(s.phase != Sim.PH_VOLLEY, "longest volley finishes")
	# simulation alone: replay the same volley headless-style
	var r := Sim.new()
	r.new_run(31337)
	r.balls = 32; r.heavy = 3; r.electric = 3
	r.blocks = {}; r.grid = {}
	for cc in 7:
		if cc != 3:
			r._add_block({"c": cc, "r": r.top + 1, "w": 1, "h": 1, "hp": 9999, "g": 1, "v": 0, "vein": false})
	for vr in range(6, 10):
		for cc in 7:
			if (cc + vr) % 3 == 0:
				r._add_block({"c": cc, "r": r.top + vr, "w": 1, "h": 1, "hp": 9999, "g": 1, "v": 0, "vein": false})
	r.fire(PI * 0.5 - 0.06)
	var tt := Time.get_ticks_usec()
	var k := 0
	var worst := 0
	while r.phase == Sim.PH_VOLLEY:
		var a := Time.get_ticks_usec()
		r.step()
		worst = maxi(worst, Time.get_ticks_usec() - a)
		k += 1
	log_line("simulation only: %d ticks (%.1f s of flight), %.3f ms per tick avg, worst tick %.3f ms" % [k, k / 60.0, (Time.get_ticks_usec() - tt) / 1000.0 / k, worst / 1000.0])
	check(k <= Sim.VOLLEY_MAX_TICKS + 1, "flight time limit holds", "%d ticks" % k)


# ---------------------------------------------------------------- the same volley at x1, x2, x4

func _run_volley_at(speed: int, seed: int, ang: float) -> int:
	main.start_new_run(seed)
	G.meta.tutorial = 6
	main.hud.hide_hint()
	main.speed_override = speed
	main._fire(ang)
	var guard := 0
	while main.sim.phase == Sim.PH_VOLLEY and guard < 20000:
		main._process(1.0 / 60.0)      # the real game loop, frame by frame
		guard += 1
	main.speed_override = 0
	return main.sim.state_hash()

func _speed() -> void:
	var same := true
	var info := ""
	for t in [[101, 0.7], [202, 1.9], [303, 1.25]]:
		var h1 := _run_volley_at(1, t[0], t[1])
		var h2 := _run_volley_at(2, t[0], t[1])
		var h4 := _run_volley_at(4, t[0], t[1])
		same = same and h1 == h2 and h2 == h4
		info += "seed %d: %s; " % [t[0], "same" if h1 == h2 and h2 == h4 else "DIFFERENT"]
	check(same, "the same volley run through the game loop at x1, x2 and x4 ends in the same state", info)
	# where the ball appears: the tip of the drawn barrel
	var w: Node2D = main.world
	var img: Image = w.barrel.texture.get_image()
	var mid := img.get_height() / 2
	var dark: Array = []
	var last := 0
	for x in img.get_width():
		var c := img.get_pixel(x, mid)
		if c.a > 0.5:
			last = x
			if x > img.get_width() * 0.7 and c.get_luminance() < 0.12:
				dark.append(x)
	var bore := 0.0
	for x in dark:
		bore += float(x)
	bore = bore / maxf(1.0, dark.size())
	var bore_len: float = (bore + 0.5 + w.barrel.offset.x) * w.barrel.scale.x
	var rim_len: float = (last + 1 + w.barrel.offset.x) * w.barrel.scale.x
	check(dark.size() > 0 and absf(bore_len - Sim.BARREL) < 2.0, "balls appear in the bore of the drawn barrel",
		"bore centre %.1f, outer rim %.1f, launch point %.1f units from the hinge" % [bore_len, rim_len, Sim.BARREL])


# ---------------------------------------------------------------- shifts: dimming and numbers follow whole stones

func _shifts() -> void:
	var S29 = load("res://scripts/qa_s29.gd").new()
	G.settings.lang = "uk"
	G.lang_changed.emit()
	G.meta.tutorial = 6
	main.start_new_run(2929)
	S29.build(main.sim)
	var s: Sim = main.sim
	# the 8 under the red line would end the run on the first shift (as the warning says): take it out here
	for id in s.blocks.keys():
		if s.will_cross_next(s.blocks[id]):
			var b0: Dictionary = s.blocks[id]
			for yy in b0.h:
				for xx in b0.w:
					s.grid.erase((b0.r + yy) * Sim.COLS + b0.c + xx)
			s.blocks.erase(id)
	main.world.clear_blocks()
	main.world.sync_blocks(true)
	main.hud.hide_hint()
	var bad := 0
	var checked := 0
	for k in 3:
		if s.phase == Sim.PH_UPGRADE:
			main.pick_upgrade(s.upgrade_opts[0])
		if s.phase != Sim.PH_AIM:
			break
		# keep the run going for the display check: stones flagged for the next shift are removed first
		for id in s.blocks.keys():
			if s.will_cross_next(s.blocks[id]):
				var b1: Dictionary = s.blocks[id]
				for yy in b1.h:
					for xx in b1.w:
						s.grid.erase((b1.r + yy) * Sim.COLS + b1.c + xx)
				s.blocks.erase(id)
		main.world.sync_blocks()
		main._fire([1.4, 0.6, 2.4][k])
		var guard := 0
		while s.phase == Sim.PH_VOLLEY and guard < 6000:
			main.world.remember_positions()
			s.step()
			main._consume_events()
			guard += 1
		main.over_timer = -1.0
		await frames(50)          # the shift animation settles
		var w: Node2D = main.world
		for id in w.block_nodes:
			var n: Node2D = w.block_nodes[id]
			var b: Dictionary = s.blocks[id]
			checked += 1
			var fut: bool = s.is_future(b)
			var f: float = n.get_meta("future")
			if (fut and f < 0.99) or (not fut and f > 0.01):
				bad += 1
			var lab: Label = n.get_node("num")
			var cy: float = n.position.y + lab.position.y + lab.size.y * 0.5
			if not fut and cy > Sim.FLOOR_Y:
				bad += 1          # the number of an active stone must sit above the floor
			if n.position.distance_to(s.block_rect(b).get_center()) > 1.0:
				bad += 1
		await shot("shift_%d" % (k + 1))
	check(bad == 0 and checked > 0, "after each of 3 shifts every stone is dimmed only while it is below the floor, numbers of active stones stay above it", "%d stone states checked, %d wrong" % [checked, bad])


# ---------------------------------------------------------------- short gameplay recording (Movie Maker)

func _best_angle(s: Sim) -> float:
	var best := 1.2
	var bh := -1
	for i in 40:
		var a := 0.25 + (PI - 0.5) * float(i) / 39.0
		var c := s.clone()
		c.fire(a)
		var n := 0
		while c.phase == Sim.PH_VOLLEY and n < 3000:
			c.step()
			n += 1
		if c.v_hits > bh and n < 900:
			bh = c.v_hits
			best = a
	return best

func _aim_sweep(from_a: float, to_a: float, secs: float) -> void:
	var n := int(secs * 30.0)
	for i in n:
		var k := float(i) / maxf(1.0, n - 1)
		var e := k * k * (3.0 - 2.0 * k)
		var a := lerpf(from_a, to_a, e)
		main.world.aim_angle = a
		main.world.aim_pts = main.sim.preview(a)
		main.world.aim_visible = true
		await get_tree().process_frame

func _demo() -> void:
	## A new run from its first volley (the situation of the owner's recordings): aim sweep, volley, shift.
	G.settings.lang = "uk"
	G.lang_changed.emit()
	G.meta.tutorial = 6
	G.meta.skin = "classic"
	var seed := 2024
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
	main.start_new_run(seed)
	var s: Sim = main.sim
	main.hud.hide_hint()
	await frames(20)
	for v in 4:
		if s.phase == Sim.PH_UPGRADE:
			await frames(25)
			main.pick_upgrade(s.upgrade_opts[0])
			await frames(20)
		if s.phase != Sim.PH_AIM:
			break
		var target := _best_angle(s)
		await _aim_sweep(main.world.aim_angle, clampf(target + 0.5, 0.3, PI - 0.3), 0.9)
		await _aim_sweep(main.world.aim_angle, clampf(target - 0.4, 0.3, PI - 0.3), 1.0)
		await _aim_sweep(main.world.aim_angle, target, 0.8)
		await frames(10)
		main.world.aim_visible = false
		main._fire(target)
		var guard := 0
		while s.phase == Sim.PH_VOLLEY and guard < 30 * 14:
			await get_tree().process_frame
			guard += 1
		await frames(28)
	log_line("demo recorded, depth %d m" % s.depth)

# ---------------------------------------------------------------- the first volleys of a new run (as in the owner's recordings)

func _start() -> void:
	G.settings.lang = "en"
	G.lang_changed.emit()
	G.meta.tutorial = 6
	G.meta.skin = "classic"
	G.meta.crystals = 583
	var seed := 2024
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
	main.start_new_run(seed)
	main.hud.hide_hint()
	var s: Sim = main.sim
	await frames(8)
	var angles := [0.5, 0.62, 0.45, 2.5, 0.55, 2.2]
	for k in 6:
		if s.phase == Sim.PH_UPGRADE:
			main.pick_upgrade("balls")
			await frames(4)
		if s.phase != Sim.PH_AIM:
			break
		var stones := 0
		for b in s.blocks.values():
			if not s.is_future(b):
				stones += 1
		log_line("depth %d m: %d stones in play, rows in use %d, balls %d" % [s.depth, stones, s.field_rows_in_use(), s.balls])
		await shot("start_%dm" % s.depth)
		var ang: float = angles[k]
		main.world.aim_angle = ang
		main.world.aim_pts = s.preview(ang)
		main.world.aim_visible = true
		await frames(6)
		main.world.aim_visible = false
		main._fire(ang)
		var t := 0
		while s.phase == Sim.PH_VOLLEY and t < 6000:
			main.world.remember_positions()
			s.step()
			main._consume_events()
			t += 1
			if k == 0 and t == 70:
				main.freeze = true
				await shot("start_volley")
				main.freeze = false
		main.over_timer = -1.0
		await frames(45)
	check(true, "opening sequence rendered")
