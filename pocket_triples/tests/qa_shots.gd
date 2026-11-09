extends Node
## Visual walk-through: plays the start, middle and end of the set in both languages, saves a
## screenshot of every screen and checks that no text overflows its box.
## Run (needs a display, e.g. xvfb-run):
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 -- --qa=/tmp/shots

var main: Node
var out := ""
var n := 0
var overflow: Array = []


func run_all(p_main: Node, p_out: String) -> void:
	main = p_main
	out = p_out
	DirAccess.make_dir_recursive_absolute(out)
	Store.path = "user://qa_save.json"
	for lang in ["uk", "en"]:
		await walk(lang)
	var f := FileAccess.open(out.path_join("overflow.txt"), FileAccess.WRITE)
	f.store_string("\n".join(overflow) if not overflow.is_empty() else "no overflow")
	f.close()
	print("QA shots done, overflow: ", overflow.size())
	get_tree().quit()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s_%02d_%s.png" % [Loc.lang(), n, name]))
	audit(name)


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func audit(where: String) -> void:
	for c in main.find_children("*", "Control", true, false):
		var ctl: Control = c
		if not ctl.is_visible_in_tree() or ctl.size.x <= 0:
			continue
		if ctl is Label and (ctl as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (ctl as Label).text != "":
			var tw := UiKit.text_width(ctl)
			if tw > ctl.size.x + 1:
				overflow.append("%s/%s: label '%s' %d > %d" % [Loc.lang(), where, ctl.text, tw, ctl.size.x])
		elif ctl is Button and (ctl as Button).text != "":
			var b: Button = ctl
			var tw := UiKit.text_width(b)
			var sb: StyleBox = b.get_theme_stylebox("normal")
			var room := b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
			if b.icon != null and b.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER:
				room -= minf(b.get_theme_constant("icon_max_width"), b.icon.get_width()) + b.get_theme_constant("h_separation")
			if tw > room + 1:
				overflow.append("%s/%s: button '%s' %d > %d" % [Loc.lang(), where, b.text, tw, room])


func tap(i: int) -> void:
	main.on_column_tapped(i)


## Finds moves from the start that end with `want_tray` tiles in the tray (or a loss).
func find_line(layout: Array, want_tray: int, want_loss: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for attempt in 3000:
		var g := GameState.new()
		g.setup(layout)
		var moves := []
		while not g.is_over():
			var opts := []
			for i in 4:
				if g.heights[i] > 0:
					opts.append(i)
			var m: int = opts[rng.randi_range(0, opts.size() - 1)]
			g.take(m)
			moves.append(m)
			if not want_loss and g.tray_count() == want_tray and not g.lost and moves.size() >= 8:
				return moves
		if want_loss and g.lost and moves.size() >= 6:
			return moves
	return []


func walk(lang: String) -> void:
	Store.wipe()
	Store.settings()["lang"] = lang
	Loc.apply(lang)
	main.panels.close_all()
	main.boot()
	await wait(0.4)
	await shot("first_launch_tutorial")
	var sol: Array = main.run["puzzle"]["solution"]
	tap(int(sol[0]))
	await wait(0.09)
	await shot("tile_in_flight")
	await wait(0.5)
	await shot("hint_match")
	var k := 1
	while k < sol.size():
		var before: int = main.gs.tray_count()
		tap(int(sol[k]))
		k += 1
		if main.gs.tray_count() < before:
			await wait(Board.FLY + 0.1)
			await shot("triple_vanishing")
			await wait(0.35)
			await shot("freed_slots_glow")
			break
		await wait(0.3)
	while k < sol.size():
		tap(int(sol[k]))
		k += 1
		await wait(0.12)
	await wait(0.5)
	await shot("win_confetti")
	await wait(1.0)
	await shot("win_panel")
	main._on_panel_action("next", null)
	await wait(0.4)
	await shot("level_2")
	main._open_menu()
	await wait(0.4)
	await shot("main_menu")
	var p := Store.progress()
	p["unlocked"] = 14
	p["solved_levels"] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
	main._open_panel("levels")
	await wait(0.4)
	await shot("levels")
	main.start_level(16)
	await wait(0.3)
	await shot("level_16_start")
	var line := find_line(main.gs.layout, 4, false)
	for m in line:
		tap(m)
	await wait(0.6)
	await shot("tray_one_slot_left")
	main.restart()
	line = find_line(main.gs.layout, 0, true)
	for m in line:
		tap(m)
	await wait(0.35)
	await shot("tray_full_moment")
	await wait(1.0)
	await shot("lose_panel")
	main._on_panel_action("undo", null)
	await wait(0.5)
	await shot("after_undo")
	main._open_panel("pause")
	await wait(0.3)
	await shot("pause")
	main._open_panel("settings")
	await wait(0.3)
	await shot("settings")
	main.panels.close_all()
	main._open_panel("stats")
	await wait(0.3)
	await shot("stats")
	main.panels.close_all()
	main._open_panel("confirm")
	await wait(0.3)
	await shot("confirm_restart")
	main.panels.close_all()
	main.start_level(30)
	await wait(0.4)
	await shot("level_30")
	sol = main.run["puzzle"]["solution"]
	for i in 14:
		tap(int(sol[i]))
	await wait(0.6)
	await shot("level_30_middle")
	main._prepare_endless()
	while main.worker.busy:
		await get_tree().process_frame
	await get_tree().process_frame
	main.new_endless()
	await wait(0.4)
	await shot("another_puzzle")
	main._open_panel("pause")
	await wait(0.3)
	await shot("pause_endless")
	main.panels.close_all()
