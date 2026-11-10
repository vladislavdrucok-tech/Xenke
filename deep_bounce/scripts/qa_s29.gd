extends RefCounted
## The situation from the owner's screenshot (29 m, 16 balls, 382 crystals): stones hugging the walls with an
## empty middle, a big 88 on the floor line, an 8 right under the red line. Uses only the basic Sim API so the
## same scene renders in older builds for before/after frames.   godot --path . -- --qa=s29 --out=DIR

const LAYOUT := [
	# column, visible row, w, h, strength, starting strength, rock pattern
	[6, 0, 1, 1, 8, 9, 2],
	[0, 1, 1, 2, 14, 15, 1], [1, 1, 1, 1, 9, 12, 3], [5, 2, 1, 1, 5, 11, 0], [6, 2, 1, 2, 12, 21, 3],
	[0, 4, 2, 2, 31, 40, 2], [5, 5, 2, 1, 17, 30, 1], [6, 6, 1, 1, 7, 16, 0],
	[0, 6, 1, 1, 11, 11, 0], [0, 7, 1, 2, 19, 26, 3], [6, 7, 1, 1, 6, 6, 2],
	[1, 8, 1, 1, 4, 13, 1], [4, 8, 2, 1, 22, 35, 0], [6, 8, 1, 1, 9, 9, 3],
	[2, 9, 2, 2, 88, 104, 1], [0, 9, 1, 1, 13, 13, 2], [4, 9, 1, 1, 10, 18, 3], [5, 9, 2, 2, 46, 52, 0],
	[0, 10, 2, 1, 39, 39, 1], [4, 10, 1, 1, 25, 25, 2], [1, 11, 1, 2, 50, 50, 3], [3, 11, 2, 1, 41, 41, 0],
	[5, 11, 1, 1, 21, 21, 1], [6, 11, 1, 2, 33, 33, 2], [0, 12, 1, 1, 18, 18, 0], [3, 12, 2, 2, 77, 77, 3],
]

func build(s: Sim) -> void:
	s.new_run(2929)
	s.depth = 29
	s.volleys = 29
	s.top = 29
	s.balls = 16
	s.heavy = 1
	s.electric = 2
	s.picks = 7
	s.blocks = {}
	s.grid = {}
	for L in LAYOUT:
		var id := s.next_id
		s._add_block({"c": L[0], "r": s.top + L[1], "w": L[2], "h": L[3], "hp": L[4], "g": L[2] * L[3], "v": L[6], "vein": false})
		s.blocks[id].mhp = L[5]
		s.blocks[id].v = L[6]
	s.gen_rows = s.top + 14

func run(qa) -> void:
	var main = qa.main
	var lang := "en"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			lang = a.substr(7)
	G.settings.lang = lang
	G.lang_changed.emit()
	G.meta.skin = "classic"
	G.meta.tutorial = 6
	main.start_new_run(2929)
	build(main.sim)
	G.meta.crystals = 382
	main.world.clear_blocks()
	main.world.sync_blocks(true)
	main.world.scroll = 29 * Sim.CELL
	main.world.scroll_target = main.world.scroll
	main.world.danger = main.sim.danger_level()
	main.hud.hide_hint()
	await qa.frames(6)
	await qa.shot("s29_aim")
	var s: Sim = main.sim
	var ang := 2.05
	main.world.aim_angle = ang
	main.world.aim_pts = s.preview(ang)
	main.world.aim_visible = true
	await qa.frames(10)
	await qa.shot("s29_aiming")
	main.world.aim_visible = false
	main._fire(ang)
	main.paused = true
	qa.step_ticks(64)
	main.volley_time = 4.0
	if "freeze" in main:
		main.freeze = true
		main.paused = false
	main.hud.update_state(s, 0, 2, true)
	await qa.frames(6)
	await qa.shot("s29_volley")
