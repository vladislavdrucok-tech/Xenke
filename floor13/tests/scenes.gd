extends Node
## Staged situations for visual checks (dev only, not exported):
## godot --path floor13 --rendering-driver opengl3 --resolution 360x780 -- --scene=<dir>

var main: Node
var dir := ""


func run() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Save.data = Save.defaults()
	Save.data["tutorial_done"] = true
	Save.data["shift"] = 13
	Save.data["upgrades"]["cabin"] = 4
	Save.data["skins"] = ["classic", "neon"]
	Save.data["skin"] = "neon"
	main.start_game()
	await get_tree().create_timer(0.5).timeout
	var g: Game = main.game
	g._begin_play()
	var s := g.sim
	s.auto_spawn = false
	s.allow_events = false
	s.passengers.clear()
	s.closed[8] = true
	s.coin_pile_floor = 7
	s.coin_pile_amount = 30
	s.pos = 6.0
	s.at_floor = 6
	var seq := 0
	for t in ["couple", "bellhop", "cat", "ghost", "kid"]:
		var p := s.spawn(t, 6, [1, 3, 9, 13, 11][seq] if t != "ghost" else 13)
		p.state = ShiftSim.P_RIDING
		seq += 1
		p.seq = seq
		p.pat = p.pmax * (1.0 - seq * 0.17)
	var i := 0
	for t in ["rocker", "robot", "inspector", "guest", "granny"]:
		var p := s.spawn(t, 6, [2, 12, 4, 10, 1][i])
		p.state = ShiftSim.P_WAITING
		p.x = s.queue_x(i)
		p.pat = p.pmax * (1.0 - i * 0.2)
		i += 1
	var w := s.spawn("business", 5, 9)
	w.state = ShiftSim.P_WAITING
	w.x = s.queue_x(0)
	w.pat = w.pmax * 0.15
	s.stops = [9, 11, 3]
	s.ev_id = "party"
	s.ev_floor = 5
	s.ev_dur = 999.0
	g.world.manual_t = 0.0
	g.world.say(s.passengers[5].id, Defs.line("rocker", "hello"))
	g.world.say(s.passengers[6].id, "БІП. ДОСТАВКА.")
	g.world.say(s.passengers[1].id, Defs.line("bellhop", "hello"))
	await get_tree().create_timer(1.0).timeout
	await _shot("scene_overview")
	var img := get_viewport().get_texture().get_image()
	var crop := img.get_region(Rect2i(0, 230, 360, 260))
	crop.resize(1080, 780, Image.INTERPOLATE_NEAREST)
	crop.save_png(dir.path_join("scene_zoom.png"))
	# kid presses a button: ping on the panel
	s.out.append({"t": "kid", "pid": s.passengers[4].id, "floor": 2})
	s.out.append({"t": "deliver", "pid": s.passengers[0].id, "floor": 6, "coins": 42, "good": true, "frac": 0.9, "forgiven": false, "streak": 5})
	s.out.append({"t": "complaint", "pid": s.passengers[9].id, "floor": 6, "count": 1})
	await get_tree().create_timer(0.25).timeout
	await _shot("scene_effects")
	main.get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", name)


## Plays `n` full shifts through the real screens at high speed (bot input, auto shopping).
func soak(n: int) -> void:
	Save.data = Save.defaults()
	Save.data["tutorial_done"] = true
	Engine.time_scale = 8.0
	var played := 0
	var fails := 0
	main.start_game()
	await get_tree().create_timer(0.3).timeout
	while played < n:
		var g: Game = main.game
		if g == null:
			await get_tree().create_timer(0.2).timeout
			continue
		match g.state:
			Game.S_INTRO:
				g._begin_play()
			Game.S_PLAY:
				g.sim.bot_step(2)
			Game.S_RESULT:
				played += 1
				if g.sim.failed:
					fails += 1
				print("soak: shift %d %s coins %d delivered %d complaints %d events seen" % [g.shift, "FAIL" if g.sim.failed else "ok", g.sim.coins, g.sim.delivered, g.sim.complaints])
				for id in Defs.UPGRADE_ORDER:
					while Save.buy(id):
						pass
				main.start_game()
				await get_tree().create_timer(0.3).timeout
		await get_tree().create_timer(0.35).timeout
	print("soak done: %d shifts, %d failed, wallet %d, next shift %d, achievements %s" % [played, fails, Save.coins(), Save.shift(), str(Save.data["achievements"])])
	Engine.time_scale = 1.0
	main.get_tree().quit()
