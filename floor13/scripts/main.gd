extends Node
## App entry: switches between menu, shift, shop, records and settings; handles the
## Android back button. `-- --shots=<dir>` runs an automatic tour with screenshots.

var ui: Control
var screen: Control
var fade: ColorRect
var game: Game


func _ready() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = Art.theme()
	add_child(ui)
	fade = ColorRect.new()
	fade.color = Color("0b0a1c")
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	if shots != "":
		_tour(shots)
	else:
		show_menu()


func _switch(s: Control) -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	game = null
	screen = s
	ui.add_child(s)
	ui.move_child(fade, -1)
	fade.modulate.a = 1.0
	fade.create_tween().tween_property(fade, "modulate:a", 0.0, 0.25)


func show_menu() -> void:
	Engine.time_scale = 1.0
	var m := MainMenu.new()
	m.play.connect(start_game)
	m.open_shop.connect(show_shop)
	m.open_records.connect(func(): show_info("records"))
	m.open_settings.connect(func(): show_info("settings"))
	m.open_tutorial.connect(func(): start_game(true))
	_switch(m)


func start_game(force_tutorial := false) -> void:
	var g := Game.new()
	g.go_menu.connect(show_menu)
	g.go_shop.connect(show_shop)
	_switch(g)
	game = g
	await get_tree().process_frame
	if force_tutorial or not Save.data["tutorial_done"]:
		g.start_shift(1, true)
	else:
		g.start_shift(Save.shift())


func show_shop() -> void:
	var s := Shop.new()
	s.back.connect(show_menu)
	s.play.connect(func(): start_game())
	_switch(s)


func show_info(mode: String) -> void:
	var s := InfoScreen.new()
	s.mode = mode
	s.back.connect(show_menu)
	s.replay_tutorial.connect(func(): start_game(true))
	_switch(s)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		_back()


func _back() -> void:
	if screen and is_instance_valid(screen) and screen.has_method("on_back"):
		screen.on_back()


# ------------------------------------------------------------------ screenshot tour

func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _play_bot(sec: float) -> void:
	var t := 0.0
	while t < sec:
		if game and game.sim and game.state == Game.S_PLAY:
			game.sim.bot_step(2)
		await _wait(0.3)
		t += 0.3


func _tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Save.data = Save.defaults()
	show_menu()
	await _wait(1.5)
	await _shot(dir, "01_menu")
	start_game()
	await _wait(1.0)
	await _shot(dir, "02_tutorial")
	game.tutorial._next()
	await _wait(3.0)
	await _shot(dir, "03_tutorial_step")
	Save.data["tutorial_done"] = true
	start_game()
	await _wait(0.8)
	await _shot(dir, "04_intro_shift1")
	game._begin_play()
	await _play_bot(12.0)
	await _shot(dir, "05_shift1_play")
	await _play_bot(8.0)
	await _shot(dir, "06_shift1_more")
	# a late shift: 13 floors, events
	Save.data["shift"] = 9
	Save.data["seen_types"] = ["guest", "business", "granny"]
	start_game()
	await _wait(0.8)
	await _shot(dir, "07_intro_shift9")
	game._begin_play()
	await _play_bot(6.0)
	game.sim.start_event("party")
	await _play_bot(4.0)
	await _shot(dir, "08_shift9_party")
	game.sim._end_event()
	game.sim.start_event("blackout")
	await _play_bot(3.0)
	await _shot(dir, "09_blackout")
	game.sim._end_event()
	game.world.manual_t = 5.0
	game.world.cam_y = game.world.world_top() + 300
	await _wait(0.3)
	await _shot(dir, "10_roof")
	game.sim.time = game.sim.duration - 0.2
	await _wait(2.5)
	await _shot(dir, "11_results")
	show_shop()
	Save.data["coins"] = 900
	await _wait(0.6)
	await _shot(dir, "12_shop")
	show_info("records")
	await _wait(0.6)
	await _shot(dir, "13_records")
	show_info("settings")
	await _wait(0.6)
	await _shot(dir, "14_settings")
	start_game()
	await _wait(0.8)
	game._begin_play()
	await _wait(0.5)
	game.pause()
	await _wait(0.5)
	await _shot(dir, "15_pause")
	get_tree().quit()
