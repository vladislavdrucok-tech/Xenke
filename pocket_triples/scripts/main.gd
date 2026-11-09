extends Node
## Pocket Triples: the one main screen. Owns the puzzle in play, the undo history, progress,
## saving and every button. The board only draws; the panels only report button presses.

const BOARD_MAX_W := 700.0
const RESULT_DELAY := 0.75

var gs := GameState.new()
var run: Dictionary = {}          # the puzzle in play (also what is saved)
var mode := "level"
var board: Board
var panels: Panels
var hud: Control
var w := {}                       # HUD widgets
var worker := EndlessWorker.new()
var prepared: Dictionary = {}     # a verified endless puzzle waiting to be played
var waiting_endless := -1.0       # seconds left to wait for the generator, < 0 when not waiting
var _result_timer := -1.0
var _result_kind := ""
var _hint_hide := -1.0
var _qa := ""
var _view := Vector2(720, 1280)
var _tray_top := 980.0


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	_build()
	get_viewport().size_changed.connect(_layout)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_qa = a.substr(5)
		elif a == "--selftest":
			_qa = "test"
		elif a.begins_with("--insets="):
			var parts := a.substr(9).split(",")
			if parts.size() == 2:
				forced_insets = Vector2(float(parts[0]), float(parts[1]))
	var st := Store.settings()
	if st["lang"] == "":
		st["lang"] = Loc.detect(OS.get_locale())
	Loc.apply(st["lang"])
	Sfx.sound_on = st["sound"]
	Sfx.vibration_on = st["vibration"]
	_layout()
	if _qa == "test":
		var t: Node = load("res://tests/run_tests.gd").new()
		add_child(t)
		t.call_deferred("run_all", self)
		return
	if _qa != "":
		var q: Node = load("res://tests/qa_shots.gd").new()
		add_child(q)
		q.call_deferred("run_all", self, _qa)
		return
	boot()


## First launch goes straight into an easy puzzle with the tutorial; later launches restore the
## puzzle exactly as it was left and show the main menu over it.
func boot() -> void:
	mode = Store.data.get("active", "level")
	var first := Store.first_launch
	if not _resume(mode):
		if mode == "endless" and _resume("level"):
			mode = "level"
		else:
			mode = "level"
			start_level(int(Store.progress()["unlocked"]))
	Store.data["active"] = mode
	save()
	_refresh_all()
	if not first:
		panels.open("menu")
		_refresh_menu()
	elif gs.won:
		_show_result("win")
	elif gs.lost:
		_show_result("lose")


# ------------------------------------------------------------------ building the screen

func _build() -> void:
	var theme := UiKit.make_theme()
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)
	var paper := TextureRect.new()
	paper.texture = UiKit.tex("paper")
	paper.stretch_mode = TextureRect.STRETCH_TILE
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(paper)

	board = Board.new()
	board.name = "Board"
	add_child(board)
	board.column_tapped.connect(on_column_tapped)
	board.landed.connect(_on_landed)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud = Control.new()
	hud.name = "Hud"
	hud.theme = theme
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)

	w["menu"] = _icon_button("home", "A11Y_MENU", func(): _open_menu())
	w["settings"] = _icon_button("gear", "A11Y_SETTINGS", func(): _open_panel("settings"))
	w["title"] = UiKit.label("", 44, 900)
	hud.add_child(w["title"])
	w["subtitle"] = UiKit.label("", 26, 700, UiKit.INK_SOFT)
	hud.add_child(w["subtitle"])
	w["tray_note"] = UiKit.label("", 28, 800, UiKit.WARN.darkened(0.2))
	hud.add_child(w["tray_note"])
	for spec in [["undo", "UNDO", "undo", "A11Y_UNDO"], ["pause", "PAUSE", "pause", "A11Y_PAUSE"], ["restart", "RESTART", "restart", "A11Y_RESTART"]]:
		var b := UiKit.button("", spec[2], "SoftButton", 26)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 36)
		b.custom_minimum_size = Vector2(0, 0)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb: StyleBox = theme.get_stylebox(state, "SoftButton").duplicate()
			var down: bool = (state as String).contains("pressed")
			sb.content_margin_top = 10 if down else 6
			sb.content_margin_bottom = 6 if down else 10
			b.add_theme_stylebox_override(state, sb)
		Loc.bind(b, spec[1])
		Loc.bind(b, spec[3], {}, "tooltip_text")
		var id: String = spec[0]
		b.pressed.connect(func(): _hud_button(id))
		hud.add_child(b)
		w[spec[0]] = b
	w["bubble"] = Bubble.new()
	hud.add_child(w["bubble"])

	panels = Panels.new()
	add_child(panels)
	panels.build()
	for o in panels.overlays.values():
		o.theme = theme
	panels.action.connect(_on_panel_action)


func _icon_button(icon: String, a11y: String, cb: Callable) -> Button:
	var b := UiKit.button("", icon, "SoftButton")
	b.custom_minimum_size = Vector2(84, 84)
	b.add_theme_constant_override("icon_max_width", 40)
	Loc.bind(b, a11y, {}, "tooltip_text")
	b.pressed.connect(func():
		Sfx.play("button")
		cb.call())
	hud.add_child(b)
	return b


## Places everything for the current screen size. The viewport is at least 720 wide; taller phones
## get more room for the stacks. The tray sits above the bottom buttons and the system bar.
func _layout() -> void:
	_view = get_viewport().get_visible_rect().size
	var ins := _safe_insets()
	var W := _view.x
	var H := _view.y
	var bw := minf(W - 32.0, BOARD_MAX_W)
	var x0 := (W - bw) / 2.0
	var top := ins.x + 14.0
	(w["menu"] as Control).position = Vector2(x0, top)
	(w["menu"] as Control).size = Vector2(84, 84)
	(w["settings"] as Control).position = Vector2(x0 + bw - 84, top)
	(w["settings"] as Control).size = Vector2(84, 84)
	var title: Label = w["title"]
	title.position = Vector2(x0 + 96, top - 2)
	title.size = Vector2(bw - 192, 56)
	var sub: Label = w["subtitle"]
	sub.position = Vector2(x0 + 96, top + 52)
	sub.size = Vector2(bw - 192, 34)
	var bar_h := maxf(100.0, (w["undo"] as Control).get_combined_minimum_size().y)
	var bar_y := H - ins.y - 18.0 - bar_h
	var gap := 14.0
	var bwid := (bw - gap * 2) / 3.0
	for k in 3:
		var b: Button = w[["undo", "pause", "restart"][k]]
		b.position = Vector2(x0 + k * (bwid + gap), bar_y)
		b.size = Vector2(bwid, bar_h)
	var tray_h := 150.0
	_tray_top = bar_y - 24.0 - tray_h
	var note: Label = w["tray_note"]
	note.position = Vector2(x0, _tray_top - 52)
	note.size = Vector2(bw, 44)
	var stacks_top := top + 84 + 26
	board.set_layout(Rect2(x0, stacks_top, bw, _tray_top - 66 - stacks_top), Rect2(x0, _tray_top, bw, tray_h))
	panels.layout(_view, _tray_top)
	_fit_texts()
	_update_hint()


## Top and bottom insets in viewport units. On a phone the game is full-screen, but Android still
## keeps touches in the hidden navigation-bar strip (and the gesture area) for itself, and the status
## bar or a camera cut-out sits on top. So the buttons stay out of 24 dp at the top and 48 dp at the
## bottom, or out of the display's safe area if that is larger. A forced value can be given for
## checking the phone layout on a computer: -- --insets=top,bottom
var forced_insets := Vector2(-1, -1)


func _safe_insets() -> Vector2:
	if forced_insets.x >= 0.0:
		return forced_insets
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0 or win.y <= 0:
		return Vector2.ZERO
	var k := _view.x / win.x
	var dp := maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	var top := 24.0 * dp * k
	var bottom := 48.0 * dp * k
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.y > 0:
		top = maxf(top, float(safe.position.y) * k)
	return Vector2(clampf(top, 0.0, _view.y * 0.08), clampf(bottom, 0.0, _view.y * 0.1))


func _fit_texts() -> void:
	var title: Label = w["title"]
	UiKit.fit_width(title, 44, 28, title.size.x)
	for id in ["undo", "pause", "restart"]:
		var b: Button = w[id]
		UiKit.fit_width(b, 26, 18, b.size.x + 44 + 12)
	var mt: Label = panels.widgets["menu_title"]
	UiKit.fit_width(mt, 78, 40, panels.card_w - 20)
	for n in panels.overlays:
		for b in panels.overlays[n].find_children("*", "Button", true, false):
			if b.has_meta("fit_kind"):
				UiKit.fit_width(b, 32, 20, panels.fit_width_for(b))
		# buttons side by side share one font size so the row looks even
		for row in panels.overlays[n].find_children("*", "HBoxContainer", true, false):
			var smallest := 99
			var row_buttons := []
			for b in row.get_children():
				if b is Button and b.has_meta("fit_kind"):
					smallest = mini(smallest, b.get_theme_font_size("font_size"))
					row_buttons.append(b)
			for b in row_buttons:
				b.add_theme_font_size_override("font_size", smallest)


# ------------------------------------------------------------------ runs

func _new_run(p_mode: String, puzzle: Dictionary, index: int) -> Dictionary:
	return {
		"id": "%s-%d-%d-%d" % [p_mode, index, Time.get_unix_time_from_system(), randi() % 100000],
		"mode": p_mode,
		"index": index,
		"puzzle": puzzle,
		"state": {},
		"history": [],
		"undos": 0,
		"elapsed": 0.0,
		"won_recorded": false,
		"unlocked_new": 0,
		"tut_cleared": false,
	}


func _begin(p_mode: String, puzzle: Dictionary, index: int) -> void:
	mode = p_mode
	run = _new_run(p_mode, puzzle, index)
	gs.setup(puzzle["stacks"])
	run["state"] = gs.snapshot()
	Store.data["active"] = mode
	board.attach(gs)
	board.interactive = true
	panels.close_all()
	_result_timer = -1.0
	save()
	_refresh_all()


func start_level(n: int) -> void:
	n = clampi(n, 1, Puzzles.LEVEL_COUNT)
	var p := Puzzles.level(n)
	if p.is_empty():
		push_error("level %d missing" % n)
		return
	_begin("level", p, n)


func _resume(p_mode: String) -> bool:
	var r: Dictionary = Store.data.get(p_mode + "_run", {})
	if r.is_empty() or not r.has("puzzle"):
		return false
	var puzzle := Puzzles.normalize(r["puzzle"])
	if Rules.validate_layout(puzzle["stacks"]) != "":
		return false
	var g := GameState.new()
	g.setup(puzzle["stacks"])
	if not g.restore(r.get("state", {})):
		return false
	for h in r.get("history", []):
		if not (h is Dictionary) or not h.has("snap"):
			return false
	mode = p_mode
	run = r
	run["puzzle"] = puzzle
	run["undos"] = int(run.get("undos", 0))
	run["index"] = int(run.get("index", 1))
	run["elapsed"] = float(run.get("elapsed", 0.0))
	gs = g
	board.attach(gs)
	return true


func save() -> void:
	if run.is_empty():
		return
	run["state"] = gs.snapshot()
	Store.data[mode + "_run"] = run
	Store.data["active"] = mode
	Store.write()


# ------------------------------------------------------------------ playing

func can_play() -> bool:
	return not panels.any_open() and not gs.is_over() and waiting_endless < 0.0


func on_column_tapped(i: int) -> void:
	if not can_play():
		return
	if not gs.can_take(i):
		board.nope(i)
		return
	var snap := gs.snapshot()
	var res := gs.take(i)
	if not res["ok"]:
		return
	run["history"].append({"snap": snap, "move": {"stack": i, "slot": res["slot"], "cleared": res["cleared"]}})
	board.play_move(res)
	if res["won"]:
		_record_win()
		_schedule_result("win")
	elif res["lost"]:
		_schedule_result("lose")
	save()
	_refresh_hud()
	if not res["cleared"].is_empty() and _tutorial_on() and not run.get("tut_cleared", false):
		run["tut_cleared"] = true
		_show_bubble_tray("HINT_FREED")
		_hint_hide = 2.4
		(w["tray_note"] as Label).visible = false
	else:
		_update_hint()


func _on_landed(_res: Dictionary) -> void:
	_refresh_hud()


func undo() -> void:
	var hist: Array = run.get("history", [])
	if hist.is_empty() or gs.won:
		return
	var h: Dictionary = hist.pop_back()
	gs.restore(h["snap"])
	run["undos"] = int(run["undos"]) + 1
	_result_timer = -1.0
	panels.close("lose")
	board.interactive = true
	board.play_undo(h["move"])
	Sfx.play("undo")
	save()
	_refresh_hud()
	_update_hint()


func restart() -> void:
	var p: Dictionary = run["puzzle"]
	var idx: int = run["index"]
	_begin(mode, p, idx)
	Sfx.play("undo", 0.8)


func _schedule_result(kind: String) -> void:
	_result_kind = kind
	_result_timer = RESULT_DELAY if kind == "lose" else RESULT_DELAY + 0.2
	board.interactive = false
	if kind == "win":
		var tw := create_tween()
		tw.tween_interval(Board.FLY + 0.15)
		tw.tween_callback(func():
			board.celebrate()
			Sfx.play("win")
			Sfx.buzz(60))


func _show_result(kind: String) -> void:
	_result_timer = -1.0
	w["bubble"].hide_now()
	if kind == "win":
		_refresh_win()
		panels.open("win")
	else:
		panels.widgets["lose_next"].visible = mode == "endless"
		panels.open("lose")


## A win is written once: the run remembers it, and the progress keeps the ids of recorded runs,
## so restoring a finished puzzle or a second win signal never counts it again.
func _record_win() -> bool:
	if run.get("won_recorded", false):
		return false
	var p := Store.progress()
	var ledger: Array = p["wins_recorded"]
	if ledger.has(run["id"]):
		run["won_recorded"] = true
		return false
	run["won_recorded"] = true
	ledger.append(run["id"])
	while ledger.size() > 40:
		ledger.pop_front()
	p["solved_total"] = int(p["solved_total"]) + 1
	p["triples"] = int(p["triples"]) + Rules.tile_total(run["puzzle"]["stacks"]) / Rules.MATCH
	if int(run["undos"]) == 0:
		p["clean_solves"] = int(p["clean_solves"]) + 1
	if mode == "level":
		var n: int = run["index"]
		if not p["solved_levels"].has(n):
			p["solved_levels"].append(n)
		if n < Puzzles.LEVEL_COUNT and int(p["unlocked"]) < n + 1:
			p["unlocked"] = n + 1
			run["unlocked_new"] = n + 1
	else:
		p["endless_solved"] = int(p["endless_solved"]) + 1
	p["tutorial_done"] = true
	save()
	return true


func _process(delta: float) -> void:
	if not run.is_empty() and not panels.any_open() and not gs.is_over() and waiting_endless < 0.0:
		run["elapsed"] = float(run["elapsed"]) + delta
	if _result_timer >= 0.0:
		_result_timer -= delta
		if _result_timer < 0.0:
			_show_result(_result_kind)
	if _hint_hide >= 0.0:
		_hint_hide -= delta
		if _hint_hide < 0.0:
			_update_hint()
			_refresh_hud()
	_poll_worker(delta)


# ------------------------------------------------------------------ endless mode

func _endless_seed(index: int) -> int:
	return (int(Store.progress()["install_seed"]) * 31 + index * 7919 + 12345) & 0x7fffffff


func _prepare_endless() -> void:
	var idx := int(Store.progress()["endless_index"])
	if prepared.get("index", -1) == idx or worker.busy:
		return
	worker.start(idx, _endless_seed(idx), Puzzles.endless_tier(idx))


func _poll_worker(delta: float) -> void:
	var r := worker.poll()
	if not r.is_empty():
		var idx: int = r["index"]
		if r.get("ok", false):
			prepared = {"index": idx, "puzzle": r["puzzle"]}
		else:
			prepared = {"index": idx, "puzzle": _fallback_puzzle()}
		if waiting_endless >= 0.0:
			waiting_endless = -1.0
			panels.close("preparing")
			new_endless()
			return
	if waiting_endless >= 0.0:
		waiting_endless -= delta
		if waiting_endless < 0.0:
			# The generator ran over its budget: hand out a verified spare puzzle instead.
			var idx := int(Store.progress()["endless_index"])
			prepared = {"index": idx, "puzzle": _fallback_puzzle()}
			panels.close("preparing")
			new_endless()


func _fallback_puzzle() -> Dictionary:
	var p := Store.progress()
	var puzzle := Puzzles.fallback_puzzle(int(p["fallback_index"]))
	p["fallback_index"] = int(p["fallback_index"]) + 1
	puzzle["fallback"] = true
	return puzzle


## "Next Puzzle" / "Another Puzzle": an explicit request for a new verified layout.
func new_endless() -> void:
	var p := Store.progress()
	var idx := int(p["endless_index"])
	if prepared.get("index", -1) != idx:
		_prepare_endless()
		waiting_endless = 2.0
		panels.open("preparing")
		return
	var puzzle: Dictionary = Puzzles.normalize(prepared["puzzle"])
	prepared = {}
	p["endless_index"] = idx + 1
	_begin("endless", puzzle, idx + 1)
	_prepare_endless()


func _enter_endless() -> void:
	if not Store.progress()["tutorial_done"]:
		return
	if _resume("endless") and not gs.won:
		Store.data["active"] = "endless"
		panels.close_all()
		save()
		_refresh_all()
		if gs.lost:
			_show_result("lose")
		_prepare_endless()
		return
	new_endless()


# ------------------------------------------------------------------ buttons

func _hud_button(id: String) -> void:
	Sfx.play("button")
	match id:
		"undo":
			if panels.any_open():
				return
			undo()
		"pause":
			if not panels.any_open():
				_open_panel("pause")
		"restart":
			if not panels.any_open():
				_open_panel("confirm")


func _open_menu() -> void:
	panels.close_all()
	_refresh_menu()
	panels.open("menu")


func _open_panel(name: String) -> void:
	match name:
		"settings":
			_refresh_settings()
		"stats":
			_refresh_stats()
		"levels":
			_refresh_levels()
		"pause":
			_refresh_pause()
			save()
	w["bubble"].hide_now()
	panels.open(name)


func _on_panel_action(id: String, arg: Variant) -> void:
	match id:
		"play":
			panels.close_all()
			if gs.won:
				_show_result("win")
			elif gs.lost:
				_show_result("lose")
			_update_hint()
		"resume":
			panels.close("pause")
			_update_hint()
		"levels":
			_open_panel("levels")
		"pick_level":
			var n: int = arg
			if n <= int(Store.progress()["unlocked"]):
				if mode == "level" and int(run.get("index", 0)) == n and not gs.is_over() and not run["history"].is_empty():
					panels.close_all()
				else:
					start_level(n)
				_update_hint()
		"endless":
			_enter_endless()
		"stats":
			_open_panel("stats")
		"settings":
			_open_panel("settings")
		"menu":
			_open_menu()
		"back":
			panels.close(panels.top())
			if panels.top() == "menu":
				_refresh_menu()
			_update_hint()
		"restart":
			panels.close("pause")
			_open_panel("confirm")
		"restart_now":
			restart()
			_update_hint()
		"undo":
			undo()
		"next":
			if mode == "level" and int(run["index"]) < Puzzles.LEVEL_COUNT and gs.won:
				start_level(int(run["index"]) + 1)
			elif mode == "level" and gs.won:
				new_endless()
			elif mode == "endless":
				new_endless()
			_update_hint()
		"replay":
			restart()
		"lang":
			set_language(arg)
		"toggle_sound":
			Sfx.sound_on = not Sfx.sound_on
			Store.settings()["sound"] = Sfx.sound_on
			Store.write()
			_refresh_settings()
		"toggle_vibration":
			Sfx.vibration_on = not Sfx.vibration_on
			Store.settings()["vibration"] = Sfx.vibration_on
			Store.write()
			_refresh_settings()
			Sfx.buzz(40)


## Switches language at once; the puzzle, its history and the progress are untouched.
func set_language(lang: String) -> void:
	Store.settings()["lang"] = lang
	Loc.apply(lang)
	Store.write()
	_refresh_all()
	_refresh_settings()
	await get_tree().process_frame
	_fit_texts()


# ------------------------------------------------------------------ texts on screen

func _run_name_key() -> Array:
	if mode == "endless":
		return ["ANOTHER_N", {"n": int(run.get("index", 1))}]
	return ["LEVEL_N", {"n": int(run.get("index", 1))}]


func _refresh_all() -> void:
	_refresh_hud()
	_refresh_menu()
	_update_hint()
	call_deferred("_fit_texts")


func _refresh_hud() -> void:
	if run.is_empty():
		return
	var nk := _run_name_key()
	Loc.bind(w["title"], nk[0], nk[1])
	Loc.bind(w["subtitle"], "SOLVED_COUNT", {"n": int(Store.progress()["solved_total"])})
	(w["undo"] as Button).disabled = run["history"].is_empty() or gs.won
	var note: Label = w["tray_note"]
	if gs.lost:
		Loc.bind(note, "LOSE_TITLE")
		note.add_theme_color_override("font_color", UiKit.DANGER)
		note.visible = true
	elif gs.tray_count() == Rules.TRAY_SIZE - 1:
		Loc.bind(note, "TRAY_ONE_LEFT")
		note.add_theme_color_override("font_color", UiKit.WARN.darkened(0.25))
		note.visible = true
	else:
		Loc.bind(note, "TRAY_LABEL", {"n": gs.tray_count()})
		note.add_theme_color_override("font_color", UiKit.INK_SOFT)
		note.visible = not (_tutorial_on() and not run.get("tut_cleared", false) and not run["history"].is_empty()) and _hint_hide < 0.0
	UiKit.fit_width(w["title"], 44, 28, (w["title"] as Control).size.x)


func _refresh_menu() -> void:
	var p := Store.progress()
	var nk := _run_name_key()
	Loc.bind(panels.widgets["menu_continue"], nk[0], nk[1])
	Loc.bind(panels.widgets["menu_solved"], "SOLVED_COUNT", {"n": int(p["solved_total"])})
	(panels.widgets["menu_endless"] as Button).disabled = not p["tutorial_done"]


func _refresh_settings() -> void:
	var lang := Loc.lang()
	for code in ["uk", "en"]:
		var b: Button = panels.widgets["lang_" + code]
		b.theme_type_variation = "ChosenButton" if code == lang else "SoftButton"
		b.icon = UiKit.tex("ic_check") if code == lang else null
	var s: Button = panels.widgets["toggle_sound"]
	Loc.bind(s, "ON" if Sfx.sound_on else "OFF")
	s.theme_type_variation = "ChosenButton" if Sfx.sound_on else "SoftButton"
	s.icon = UiKit.tex("ic_sound" if Sfx.sound_on else "ic_sound_off")
	var v: Button = panels.widgets["toggle_vibration"]
	Loc.bind(v, "ON" if Sfx.vibration_on else "OFF")
	v.theme_type_variation = "ChosenButton" if Sfx.vibration_on else "SoftButton"


func _refresh_stats() -> void:
	var p := Store.progress()
	var rows: Dictionary = panels.widgets["stat_rows"]
	(rows["PUZZLES_SOLVED"] as Label).text = str(p["solved_total"])
	Loc.bind(rows["STAT_LEVELS"], "STAT_LEVELS_VALUE", {"a": p["solved_levels"].size(), "b": Puzzles.LEVEL_COUNT})
	(rows["STAT_EXTRA"] as Label).text = str(p["endless_solved"])
	(rows["STAT_CLEAN"] as Label).text = str(p["clean_solves"])
	(rows["STAT_TRIPLES"] as Label).text = str(p["triples"])


func _refresh_levels() -> void:
	var p := Store.progress()
	var unlocked := int(p["unlocked"])
	var solved: Array = p["solved_levels"]
	var buttons: Array = panels.widgets["level_buttons"]
	for k in buttons.size():
		var n: int = k + 1
		var b: Button = buttons[k]
		if n > unlocked:
			b.disabled = true
			b.theme_type_variation = "SoftButton"
			b.icon = UiKit.tex("ic_lock")
			Loc.bind(b, "A11Y_LEVEL_LOCKED", {"n": n}, "tooltip_text")
		elif solved.has(n):
			b.disabled = false
			b.theme_type_variation = "ChosenButton"
			b.icon = UiKit.tex("ic_star")
			Loc.bind(b, "A11Y_LEVEL_SOLVED", {"n": n}, "tooltip_text")
		else:
			b.disabled = false
			b.theme_type_variation = "AccentButton" if n == unlocked else ""
			b.icon = null
			Loc.bind(b, "A11Y_LEVEL", {"n": n}, "tooltip_text")


func _refresh_pause() -> void:
	var nk := _run_name_key()
	Loc.bind(panels.widgets["pause_name"], nk[0], nk[1])
	(panels.widgets["pause_next"] as Button).visible = mode == "endless"


func _refresh_win() -> void:
	var pw: Dictionary = panels.widgets
	var nk := _run_name_key()
	Loc.bind(pw["win_name"], nk[0], nk[1])
	var secs := int(run.get("elapsed", 0.0))
	Loc.bind(pw["win_time"], "TIME_N", {"t": "%d:%02d" % [secs / 60, secs % 60]})
	if int(run["undos"]) == 0:
		Loc.bind(pw["win_undo"], "NO_UNDO")
	else:
		Loc.bind(pw["win_undo"], "UNDOS_N", {"n": int(run["undos"])})
	var un := int(run.get("unlocked_new", 0))
	pw["win_unlock"].visible = un > 0
	if un > 0:
		Loc.bind(pw["win_unlock"], "LEVEL_UNLOCKED", {"n": un})
	var last := mode == "level" and int(run["index"]) >= Puzzles.LEVEL_COUNT
	pw["win_all"].visible = last
	Loc.bind(pw["win_solved"], "SOLVED_COUNT", {"n": int(Store.progress()["solved_total"])})
	Loc.bind(pw["win_next"], "ANOTHER_PUZZLE" if last else "NEXT_PUZZLE")


# ------------------------------------------------------------------ tutorial hints

func _tutorial_on() -> bool:
	return not Store.progress()["tutorial_done"] and mode == "level" and int(run.get("index", 0)) == 1


func _update_hint() -> void:
	if not is_instance_valid(board) or not w.has("bubble"):
		return
	var b: Bubble = w["bubble"]
	if run.is_empty() or not _tutorial_on() or panels.any_open() or gs.is_over():
		b.hide_now()
		return
	if _hint_hide >= 0.0:
		return
	if run["history"].is_empty():
		# Point at the tallest stack: the bubble then sits above every tile and hides none.
		var col := 0
		var sol: Array = run["puzzle"].get("solution", [])
		if not sol.is_empty():
			col = int(sol[0])
		for i in gs.heights.size():
			if gs.heights[i] > gs.heights[col]:
				col = i
		var p := board.top_tile_pos(col)
		b.show_at("HINT_TAP_TOP", p - Vector2(0, 8), true, _view.x)
	elif not run.get("tut_cleared", false):
		_show_bubble_tray("HINT_MATCH")
	else:
		b.hide_now()


func _show_bubble_tray(key: String) -> void:
	var p := Vector2(_view.x / 2, _tray_top + 2)
	(w["bubble"] as Bubble).show_at(key, p, true, _view.x)


# ------------------------------------------------------------------ app life cycle

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _qa != "test":
				_go_background()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_go_background()
			worker.stop()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_back()


## Folded, locked or switched away: finish the move on screen, save, and come back paused.
func _go_background() -> void:
	if run.is_empty() or (_qa != "" and _qa != "test"):
		return
	if _result_timer >= 0.0:
		_show_result(_result_kind)
	board.finish_animations()
	save()
	if not panels.any_open() and not gs.is_over():
		_open_panel("pause")


func _back() -> void:
	if panels.any_open():
		var t := panels.top()
		if t == "menu":
			save()
			worker.stop()
			get_tree().quit()
		elif t in ["win", "lose"]:
			_open_menu()
		elif t != "preparing":
			_on_panel_action("back", null)
	else:
		_open_panel("pause")


func _exit_tree() -> void:
	worker.stop()


## A speech bubble with a small pointer, used for the first-puzzle hints.
class Bubble extends Control:
	var label: Label
	var point := Vector2.ZERO
	var down := true
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		label = UiKit.label("", 28, 800, Color.WHITE)
		label.position = Vector2(22, 12)
		add_child(label)

	func show_at(key: String, p: Vector2, pointer_down: bool, view_w: float) -> void:
		Loc.bind(label, key)
		var f: Font = label.get_theme_font("font")
		var tw := f.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		tw = minf(tw, view_w - 90)
		UiKit.fit_width(label, 28, 18, view_w - 90)
		label.size = Vector2(tw, 40)
		size = Vector2(tw + 44, 64)
		down = pointer_down
		point = p
		var x := clampf(p.x - size.x / 2, 16, view_w - size.x - 16)
		position = Vector2(x, p.y - size.y - 18) if down else Vector2(x, p.y + 18)
		visible = true
		queue_redraw()

	func hide_now() -> void:
		visible = false

	func _process(delta: float) -> void:
		if visible:
			_t += delta
			var off := sin(_t * 4.0) * 4.0
			label.position.y = 12
			position.y = (point.y - size.y - 18 + off) if down else (point.y + 18 - off)

	func _draw() -> void:
		var sb := UiKit.box(UiKit.PRIMARY, 22, 0, Color.TRANSPARENT, 8, Vector2(0, 4))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var px := clampf(point.x - position.x, 24, size.x - 24)
		var tri: PackedVector2Array
		if down:
			tri = PackedVector2Array([Vector2(px - 14, size.y - 1), Vector2(px + 14, size.y - 1), Vector2(px, size.y + 16)])
		else:
			tri = PackedVector2Array([Vector2(px - 14, 1), Vector2(px + 14, 1), Vector2(px, -16)])
		draw_colored_polygon(tri, UiKit.PRIMARY)
