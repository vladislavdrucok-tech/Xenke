class_name Panels
extends CanvasLayer
## Every screen that sits over the board: main menu, level choice, settings, statistics, pause,
## win, tray full, restart confirmation and "preparing a puzzle". Buttons only report what was
## pressed through `action`; the game decides what happens.

signal action(id: String, arg: Variant)

var overlays := {}
var order: Array = []
var widgets := {}
var card_w := 640.0
var tray_top := 980.0


func _ready() -> void:
	layer = 5


func _overlay(name: String, opaque := false) -> Control:
	var o := Control.new()
	o.name = name
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = UiKit.BG if opaque else Color(0.2, 0.13, 0.07, 0.42)
	o.add_child(dim)
	if opaque:
		var paper := TextureRect.new()
		paper.texture = UiKit.tex("paper")
		paper.stretch_mode = TextureRect.STRETCH_TILE
		paper.set_anchors_preset(Control.PRESET_FULL_RECT)
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		o.add_child(paper)
	add_child(o)
	overlays[name] = o
	return o


func _card(o: Control, opaque := false) -> VBoxContainer:
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	var sb: StyleBox = UiKit.box(UiKit.CARD, 36, 3, UiKit.CARD_EDGE, 18, Vector2(0, 8)) if not opaque else StyleBoxEmpty.new()
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 32
	sb.content_margin_bottom = 32
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(card_w, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	return v


func _title(v: Container, key: String, color := UiKit.INK, size := 46) -> Label:
	var l := UiKit.label("", size, 900, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(card_w - 72, 0)
	Loc.bind(l, key)
	v.add_child(l)
	return l


func _text(v: Container, key: String, args := {}, size := 28, color := UiKit.INK_SOFT) -> Label:
	var l := UiKit.label("", size, 700, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(card_w - 72, 0)
	Loc.bind(l, key, args)
	v.add_child(l)
	return l


func _btn(v: Container, key: String, id: String, icon := "", variation := "", arg: Variant = null) -> Button:
	var b := UiKit.button("", icon, variation, 32)
	b.set_meta("fit_kind", "half" if v is HBoxContainer else "full")
	Loc.bind(b, key)
	b.pressed.connect(func():
		Sfx.play("button")
		action.emit(id, arg))
	v.add_child(b)
	return b


func _gap(v: Container, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(c)


func build() -> void:
	# main menu
	var o := _overlay("menu", true)
	var v := _card(o, true)
	var logo := TextureRect.new()
	logo.texture = UiKit.tex("logo")
	logo.custom_minimum_size = Vector2(360, 230)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(logo)
	var title := UiKit.label("", 78, 900, UiKit.INK)
	Loc.bind(title, "APP_TITLE")
	v.add_child(title)
	widgets["menu_title"] = title
	_text(v, "TAGLINE", {}, 30)
	_gap(v, 18)
	widgets["menu_play"] = _btn(v, "PLAY", "play", "play")
	var cont := UiKit.label("", 26, 700, UiKit.INK_SOFT)
	v.add_child(cont)
	widgets["menu_continue"] = cont
	widgets["menu_levels"] = _btn(v, "LEVELS", "levels", "levels", "SoftButton")
	widgets["menu_endless"] = _btn(v, "ANOTHER_PUZZLE", "endless", "next", "SoftButton")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for spec in [["STATS", "stats", "stats"], ["SETTINGS", "settings", "gear"]]:
		var b := _btn(row, spec[0], spec[1], spec[2], "SoftButton")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		widgets["menu_" + spec[1]] = b
	_gap(v, 6)
	widgets["menu_solved"] = _text(v, "SOLVED_COUNT", {"n": 0}, 28)

	# level choice
	o = _overlay("levels", true)
	v = _card(o, true)
	_title(v, "CHOOSE_LEVEL")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	var level_buttons := []
	for n in Puzzles.LEVEL_COUNT:
		var b := UiKit.button(str(n + 1), "", "", 36)
		b.custom_minimum_size = Vector2(108, 108)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 26)
		var level := n + 1
		b.pressed.connect(func():
			Sfx.play("button")
			action.emit("pick_level", level))
		grid.add_child(b)
		level_buttons.append(b)
	widgets["level_buttons"] = level_buttons
	_gap(v, 8)
	_btn(v, "BACK", "back", "", "SoftButton")

	# settings
	o = _overlay("settings")
	v = _card(o)
	_title(v, "SETTINGS")
	_text(v, "LANGUAGE", {}, 28, UiKit.INK)
	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 16)
	v.add_child(langs)
	for spec in [["LANG_UK", "uk"], ["LANG_EN", "en"]]:
		var b := _btn(langs, spec[0], "lang", "", "SoftButton", spec[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		widgets["lang_" + spec[1]] = b
	for spec in [["SOUND", "sound", "sound"], ["VIBRATION", "vibration", "vibration"]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 16)
		v.add_child(r)
		var l := UiKit.label("", 30, 800, UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Loc.bind(l, spec[0])
		r.add_child(l)
		var b := _btn(r, "ON", "toggle_" + spec[1], spec[2], "ChosenButton")
		b.custom_minimum_size = Vector2(220, 88)
		b.set_meta("fit_kind", "toggle")
		widgets["toggle_" + spec[1]] = b
	_gap(v, 4)
	_text(v, "HOW_TO_TITLE", {}, 30, UiKit.INK)
	_text(v, "HOW_TO_TEXT", {}, 25)
	_btn(v, "BACK", "back", "", "")

	# statistics
	o = _overlay("stats")
	v = _card(o)
	_title(v, "STATS")
	var stat_rows := {}
	for key in ["PUZZLES_SOLVED", "STAT_LEVELS", "STAT_EXTRA", "STAT_CLEAN", "STAT_TRIPLES"]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		v.add_child(r)
		var l := UiKit.label("", 28, 700, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Loc.bind(l, key)
		r.add_child(l)
		var val := UiKit.label("0", 34, 900, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		val.custom_minimum_size = Vector2(130, 0)
		r.add_child(val)
		stat_rows[key] = val
	widgets["stat_rows"] = stat_rows
	_btn(v, "BACK", "back", "", "")

	# pause
	o = _overlay("pause")
	v = _card(o)
	_title(v, "PAUSED")
	widgets["pause_name"] = _text(v, "LEVEL_N", {"n": 1}, 30)
	_btn(v, "RESUME", "resume", "play", "")
	_btn(v, "RESTART", "restart", "restart", "SoftButton")
	widgets["pause_next"] = _btn(v, "NEXT_PUZZLE", "next", "next", "SoftButton")
	_btn(v, "LEVELS", "levels", "levels", "SoftButton")
	_btn(v, "SETTINGS", "settings", "gear", "SoftButton")
	_btn(v, "MAIN_MENU", "menu", "home", "SoftButton")

	# win
	o = _overlay("win")
	(o.get_node("Dim") as ColorRect).color = Color(0.2, 0.13, 0.07, 0.3)
	v = _card(o)
	_title(v, "WIN_TITLE", UiKit.GOOD.darkened(0.15), 50)
	widgets["win_name"] = _text(v, "LEVEL_N", {"n": 1}, 30, UiKit.INK)
	widgets["win_time"] = _text(v, "TIME_N", {"t": "0:00"}, 28)
	widgets["win_undo"] = _text(v, "UNDOS_N", {"n": 0}, 28)
	widgets["win_unlock"] = _text(v, "LEVEL_UNLOCKED", {"n": 2}, 28, UiKit.PRIMARY)
	widgets["win_all"] = _text(v, "ALL_LEVELS_DONE", {}, 28, UiKit.PRIMARY)
	widgets["win_solved"] = _text(v, "SOLVED_COUNT", {"n": 1}, 28)
	_gap(v, 4)
	widgets["win_next"] = _btn(v, "NEXT_PUZZLE", "next", "next", "AccentButton")
	widgets["win_replay"] = _btn(v, "REPLAY", "replay", "restart", "SoftButton")
	widgets["win_levels"] = _btn(v, "LEVELS", "levels", "levels", "SoftButton")

	# tray full: the card stays above the tray so the full tray is still in sight
	o = _overlay("lose")
	var dim: ColorRect = o.get_node("Dim")
	dim.set_anchors_preset(Control.PRESET_TOP_WIDE)
	dim.color = Color(0.2, 0.13, 0.07, 0.3)
	widgets["lose_dim"] = dim
	v = _card(o)
	_title(v, "LOSE_TITLE", UiKit.DANGER, 50)
	_text(v, "LOSE_REASON", {}, 28)
	_btn(v, "UNDO", "undo", "undo", "AccentButton")
	_btn(v, "RESTART", "restart_now", "restart", "SoftButton")
	widgets["lose_next"] = _btn(v, "NEXT_PUZZLE", "next", "next", "SoftButton")

	# restart confirmation
	o = _overlay("confirm")
	v = _card(o)
	_title(v, "CONFIRM_RESTART_TITLE")
	_text(v, "CONFIRM_RESTART_TEXT", {}, 28)
	_btn(v, "YES_RESTART", "restart_now", "restart", "AccentButton")
	_btn(v, "KEEP_PLAYING", "back", "play", "SoftButton")

	# waiting for the generator (normally never seen: the next puzzle is prepared in advance)
	o = _overlay("preparing")
	v = _card(o)
	_title(v, "PREPARING", UiKit.INK, 36)


func layout(view: Vector2, p_tray_top: float) -> void:
	card_w = minf(640.0, view.x - 40.0)
	tray_top = p_tray_top
	for name in overlays:
		var center: Control = overlays[name].get_node("Center")
		var card: Control = center.get_node("Card")
		card.custom_minimum_size.x = card_w
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.offset_bottom = 0
		if name == "lose" or name == "win":
			# keep the tray visible under these cards
			center.offset_bottom = -(view.y - tray_top) - 10
	var dim: ColorRect = widgets["lose_dim"]
	dim.offset_bottom = tray_top - 30


## Width a panel button may take, so long texts shrink instead of stretching the card.
func fit_width_for(b: Button) -> float:
	var inner := card_w - 72.0
	match b.get_meta("fit_kind", "full"):
		"half":
			return (inner - 16.0) / 2.0
		"toggle":
			return 220.0
	return inner


func is_open(name: String) -> bool:
	return overlays.has(name) and overlays[name].visible


func any_open() -> bool:
	return not order.is_empty()


func top() -> String:
	return order.back() if not order.is_empty() else ""


func open(name: String) -> void:
	if not overlays.has(name):
		return
	var o: Control = overlays[name]
	order.erase(name)
	order.append(name)
	move_child(o, -1)
	o.visible = true
	var card: Control = o.get_node("Center/Card")
	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.94, 0.94)
	o.modulate.a = 0.0
	var tw := o.create_tween().set_parallel(true)
	tw.tween_property(o, "modulate:a", 1.0, 0.16)
	tw.tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close(name: String) -> void:
	if not overlays.has(name):
		return
	overlays[name].visible = false
	order.erase(name)


func close_all() -> void:
	for n in order.duplicate():
		close(n)
