extends Node
## Visual check: walks through every screen and saves screenshots.
##   xvfb-run godot --path . --resolution 720x1280 -- --save=user://tour.json --shots=/abs/dir
## Optional: --tour-level=12 to show a progressed profile.

var dir := ""
var n := 0


func run(p_dir: String) -> void:
	dir = p_dir
	DirAccess.make_dir_recursive_absolute(dir)
	_tour.call_deferred()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [dir, n, name])
	print("shot ", name)


func main() -> Node:
	return Game.main


func _sort_correct(times: int, delay: float) -> void:
	for i in times:
		var s: Control = main().current
		if s == null or not ("session" in s):
			return
		var t := 0.0
		while s.session.current.is_empty() and t < 3.0:
			await _wait(0.05)
			t += 0.05
		if s.session.over:
			return
		var d := Rules.dest_to_dir(Rules.judge(s.session.current, s.session.rules), s.session.rules["mirrored"])
		s._try_sort(d)
		await _wait(delay)


func _tour() -> void:
	await _wait(1.0)
	await shot("story_prologue")
	for i in 4:
		main().current._advance()
		main().current._advance()
	await _wait(0.8)
	await shot("story_future_self")
	main().current._skip_all()
	await _wait(1.5)
	await shot("tutorial_first")
	await _sort_correct(1, 0.15)
	await shot("tutorial_fly")
	await _wait(0.6)
	await shot("tutorial_second")
	await _sort_correct(7, 0.5)
	await _wait(1.6)
	await shot("results_tutorial")
	# progressed profile for the remaining screens
	var p := Game.profile
	p["level"] = 12
	p["coins"] = 5400
	p["shards"] = 7
	p["shifts_done"] = 9
	p["upgrades"] = {"robot": 2, "press": 3, "lift": 2, "window": 2, "scanner": 1, "plant": 1, "poster": 1, "lamp": 1, "neon": 1}
	p["collection"] = {"floppy": 1, "pocket_watch": 2, "holo_cube": 1, "mars_rock": 1, "vinyl": 1}
	for id in ["rusty", "wake", "olena", "kai"]:
		var idx := Story.index_of(id)
		Story.complete(p, idx)
	p["story"]["letters"].append({"from": "olena", "uk": StoryData.CHAPTERS[3]["lines"][5]["choice"][0]["letter"][1],
		"en": StoryData.CHAPTERS[3]["lines"][5]["choice"][0]["letter"][2], "read": false})
	p["story"]["vars"]["hope"] = 3
	Game.goto("menu")
	await _wait(1.2)
	await shot("menu")
	Game.goto("shift", {"mode": "shift"})
	await _wait(1.6)
	await shot("shift_start")
	await _sort_correct(6, 0.35)
	await shot("shift_combo")
	var s: Control = main().current
	# show special parcels
	for kind in ["damaged", "paradox", "mystery", "hazard", "series", "collectible"]:
		s.session.paused = true
		for c in s.get_children():
			if c == s.overlay:
				s._close_overlay()
		var parcel := _special(kind, s.session)
		s.session.current = {}
		if s.current_view:
			s.current_view.queue_free()
			s.current_view = null
		s.session.current = parcel
		s._on_parcel_ready(parcel)
		s.session.paused = false
		await _wait(0.9 if kind != "damaged" else 2.2)
		if s.overlay:
			await shot("tip_" + kind)
			s._close_overlay()
			s.session.paused = false
			await _wait(0.4)
		await shot("parcel_" + kind)
	s.session.paused = false
	s.session.sort(Rules.dest_to_dir(Rules.judge(s.session.current, s.session.rules), s.session.rules["mirrored"]))
	await _wait(0.5)
	s.session.events.start("mirror", s.session.rules)
	s._refresh_queue_for_test()
	s._on_event_started(s.session.events.active)
	await _wait(1.0)
	if s.overlay:
		s._close_overlay()
		s.session.paused = false
	await _wait(0.6)
	await shot("event_mirror")
	s.session.events.active["time_left"] = 0.01
	await _wait(1.0)
	s.session.events.start("calendar", s.session.rules)
	s._refresh_queue_for_test()
	s._on_event_started(s.session.events.active)
	await _wait(0.8)
	await shot("event_calendar")
	s._open_pause()
	await _wait(0.4)
	await shot("pause")
	s._close_overlay()
	s.session.paused = false
	s.session.finish(true)
	await _wait(2.0)
	await shot("results_shift")
	for scr in ["office", "collection", "letters", "settings"]:
		Game.goto(scr)
		await _wait(1.0)
		await shot(scr)
	Game.goto("letters", {"tab": "chapters"})
	await _wait(1.0)
	await shot("chapters")
	Game.goto("story", {"chapter": Story.index_of("olena")})
	await _wait(0.6)
	main().current._skip_all()
	await _wait(0.8)
	await shot("story_choice")
	Game.goto("shift", {"mode": "record"})
	await _wait(1.6)
	await shot("record")
	print("tour done")
	get_tree().quit()


func _special(kind: String, session: ShiftSession) -> Dictionary:
	var p := {"id": 9000 + n, "year": 1987, "shown": "1987", "box": "cardboard", "hazard": false, "riddle": "",
		"riddle_dest": -1, "old_year": 0, "urgent": false, "series": "", "series_idx": 0, "series_len": 0,
		"sender": "", "collectible": "", "damaged": false, "seed": 1}
	match kind:
		"damaged":
			p["year"] = 2061
			p["shown"] = "20?1"
			p["shown"] = "206?"
			p["damaged"] = true
			p["urgent"] = true
		"paradox":
			p["year"] = 2044
			p["shown"] = "2044"
			p["old_year"] = 1999
		"mystery":
			p["riddle"] = "r_mars"
			p["riddle_dest"] = Rules.Dest.FUTURE
			p["shown"] = "????"
			p["box"] = "mystery"
		"hazard":
			p["hazard"] = true
			p["box"] = "hazard"
		"series":
			p["series"] = "B"
			p["series_idx"] = 2
			p["series_len"] = 3
			p["sender"] = "olena"
			p["box"] = "paper"
		"collectible":
			p["collectible"] = "time_crystal"
			p["box"] = "gold"
			p["year"] = 2038
			p["shown"] = "2038"
	return p
