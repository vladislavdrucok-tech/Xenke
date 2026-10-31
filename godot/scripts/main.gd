extends Node2D
## Trial scene: Mira's workshop at the Station. Ties the hero, Mira, the objects and the interface together.
## World units match the web version: the ground is at y = 320, the hero is 70 tall.

const GROUND := 320.0
const MIRA_HOME := 166.0

@onready var player: CharacterBody2D = $Player
@onready var mira: Actor = $Mira
@onready var camera: Camera2D = $Camera
@onready var bench: Interactable = $Bench
@onready var filter: Interactable = $Filter
@onready var ui: CanvasLayer = $UI

var font: FontFile
var hint: Label
var goal_title: Label
var goal_text: Label
var goal_needs: HBoxContainer
var goal_dir: Label
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_face: TextureRect
var craft: PanelContainer
var craft_rows: VBoxContainer
var craft_btn: Button
var act_label: Label
var lines: Array = []
var line_t := 0.0
var hint_t := 0.0
var mira_joy := 0.0
var mira_walk := 0.0
var frame_ms: Array[float] = []

func _ready() -> void:
	_input_map()
	font = load("res://assets/PixelifySans.ttf")
	_build_ui()
	player.message.connect(show_hint)
	player.job_finished.connect(_on_job)
	State.changed.connect(_refresh_goal)
	_refresh_goal()
	get_viewport().size_changed.connect(_layout)
	_layout()
	say([["mira", "Фільтр стоїть уже тиждень. Верстак біля стіни — зроби на ньому ремонтний вузол."]])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo"):
			_demo()
			break

# ---------- input: keyboard on PC, touch buttons on phones ----------
func _input_map() -> void:
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE, KEY_W, KEY_UP], "act": [KEY_E]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)

# ---------- interface ----------
func _panel_style(border := Color("#3b4a52")) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.125, 0.92)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5)
	return sb

func _label(size := 10, color := Color("#e7eef0")) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_ui() -> void:
	# Goal ribbon: title, direction and have/need of the materials.
	var goal := PanelContainer.new()
	goal.name = "Goal"
	goal.add_theme_stylebox_override("panel", _panel_style(Color("#6b5a2a")))
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 1)
	var top := HBoxContainer.new()
	goal_title = _label(11, Color("#f2c14e"))
	goal_dir = _label(9, Color("#c9d6dc"))
	goal_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_dir.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(goal_title)
	top.add_child(goal_dir)
	goal_text = _label(9, Color("#cbd6db"))
	goal_needs = HBoxContainer.new()
	gv.add_child(top)
	gv.add_child(goal_text)
	gv.add_child(goal_needs)
	goal.add_child(gv)
	ui.add_child(goal)
	# Dialogue: portrait, name, line.
	dlg = PanelContainer.new()
	dlg.name = "Dialog"
	dlg.add_theme_stylebox_override("panel", _panel_style(Color("#6b5a2a")))
	var dh := HBoxContainer.new()
	dlg_face = TextureRect.new()
	dlg_face.custom_minimum_size = Vector2(26, 28)
	dlg_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlg_name = _label(9, Color("#f2c14e"))
	dlg_text = _label(10)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(dlg_name)
	dv.add_child(dlg_text)
	dh.add_child(dlg_face)
	dh.add_child(dv)
	dlg.add_child(dh)
	dlg.gui_input.connect(func(e): if e is InputEventScreenTouch and e.pressed or e is InputEventMouseButton and e.pressed: _next_line())
	ui.add_child(dlg)
	# One hint strip under the hero: the target's name, or a short message that replaces it for a moment.
	hint = _label(10)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hs := _panel_style()
	hs.set_content_margin_all(3)
	hint.add_theme_stylebox_override("normal", hs)
	ui.add_child(hint)
	# Touch controls: TouchScreenButton handles several fingers at once (walk + jump together).
	for spec in [["BtnLeft", "btn_left", "move_left"], ["BtnRight", "btn_right", "move_right"], ["BtnJump", "btn_jump", "jump"], ["BtnAct", "btn_action", "act"]]:
		var b := TouchScreenButton.new()
		b.name = spec[0]
		b.texture_normal = load("res://ui/%s.png" % spec[1])
		b.action = spec[2]
		b.passby_press = spec[2].begins_with("move")
		ui.add_child(b)
	act_label = _label(8, Color("#f2c14e"))
	act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	act_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(act_label)
	_build_craft()

## Workbench panel: result icon, materials with have/need, one Create button; fits a phone without scrolling.
func _build_craft() -> void:
	craft = PanelContainer.new()
	craft.name = "Craft"
	craft.visible = false
	craft.add_theme_stylebox_override("panel", _panel_style(Color("#f2c14e")))
	var v := VBoxContainer.new()
	var head := HBoxContainer.new()
	var t := _label(11, Color("#f2c14e"))
	t.text = "МАЙСТЕРНЯ УКРИТТЯ"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "×"
	close.add_theme_font_override("font", font)
	close.custom_minimum_size = Vector2(22, 18)
	close.pressed.connect(close_craft)
	head.add_child(t)
	head.add_child(close)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	var i: int = items.index.gear
	at.atlas = load("res://assets/items.webp")
	at.region = Rect2((i % int(items.cols)) * items.cell, floori(i / items.cols) * items.cell, items.cell, items.cell)
	icon.texture = at
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var mid := VBoxContainer.new()
	var name_l := _label(10, Color("#f2c14e"))
	name_l.text = "Ремонтний вузол"
	craft_rows = VBoxContainer.new()
	craft_rows.add_theme_constant_override("separation", 1)
	mid.add_child(name_l)
	mid.add_child(craft_rows)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_btn = Button.new()
	craft_btn.text = "Створити"
	craft_btn.add_theme_font_override("font", font)
	craft_btn.add_theme_font_size_override("font_size", 11)
	craft_btn.custom_minimum_size = Vector2(76, 30)
	craft_btn.pressed.connect(_craft_pressed)
	_gold_button(craft_btn)
	row.add_child(icon)
	row.add_child(mid)
	row.add_child(craft_btn)
	var desc := _label(8, Color("#cbd6db"))
	desc.text = "Деталь для фільтра води Станції. Встановлюється ключем."
	v.add_child(head)
	v.add_child(row)
	v.add_child(desc)
	craft.add_child(v)
	ui.add_child(craft)

## Gold Create button like the web version: dark text on gold, grey when the recipe is not ready.
func _gold_button(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#f2c14e") if st in ["normal", "focus"] else (Color("#ffd87a") if st == "hover" else (Color("#c9952f") if st == "pressed" else Color("#2c363b")))
		sb.border_color = Color("#6b4a14") if st != "disabled" else Color("#3b4a52")
		sb.set_border_width_all(1)
		sb.set_content_margin_all(4)
		b.add_theme_stylebox_override(st, sb)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, Color("#1a1208"))
	b.add_theme_color_override("font_disabled_color", Color("#7d8a90"))

func open_craft() -> void:
	_fill_craft()
	craft.visible = true
	player.controls = false
	player.cancel_job()
	_release_all()
	_layout()

func close_craft() -> void:
	craft.visible = false
	player.controls = true
	_release_all()

## Nothing stays pressed after a menu opens or closes.
func _release_all() -> void:
	for a in ["move_left", "move_right", "jump", "act"]:
		Input.action_release(a)

func _fill_craft() -> void:
	for c in craft_rows.get_children():
		c.queue_free()
	for k in State.REPAIR_COST:
		var have: int = State.inv[k]
		var need: int = State.REPAIR_COST[k]
		var l := _label(9, Color("#6ad04a") if have >= need else Color("#e2483c"))
		l.text = "%s   %d / %d  %s" % [State.ITEM_NAMES[k], have, need, "+" if have >= need else "×"]
		craft_rows.add_child(l)
	craft_btn.disabled = not State.can_make_repair()
	craft_btn.text = "Готово" if State.inv.repair > 0 or State.filter_state > 0 else "Створити"

func _craft_pressed() -> void:
	if State.make_repair():
		show_hint("Ремонтний вузол готовий. Встанови його у фільтр.")
		say([["mira", "Вузол готовий! Встанови його у фільтр. Знадобиться ключ."]])
	_fill_craft()

# ---------- story beats ----------
func _on_job(item: Interactable) -> void:
	if item == bench:
		open_craft()
	elif item == filter:
		if State.filter_state == 1:
			show_hint("Вузол встановлено.")
			say([["mira", "Тримається. Тепер відкривай кран!"]])
		elif State.filter_state == 2:
			show_hint("Чиста вода пішла!")
			mira_joy = 1.4
			say([["mira", "Вода… чиста! Ти справді це зробив."], ["einstein", "Ми це зробили."]])

func say(new_lines: Array) -> void:
	lines = new_lines.duplicate()
	_show_line()

func _show_line() -> void:
	if lines.is_empty():
		dlg.visible = false
		return
	var l: Array = lines[0]
	dlg.visible = true
	dlg_name.text = "МІРА" if l[0] == "mira" else "ЕЙНШТЕЙН"
	dlg_text.text = l[1]
	dlg_face.texture = load("res://assets/portrait-%s.webp" % l[0])
	line_t = clampf(1.4 + l[1].length() * 0.035, 2.4, 5.5)

func _next_line() -> void:
	if not lines.is_empty():
		lines.pop_front()
	_show_line()

func show_hint(text: String) -> void:
	hint.text = text
	hint_t = 2.4

func _refresh_goal() -> void:
	var g := State.goal()
	goal_title.text = g.title
	goal_text.text = g.text
	for c in goal_needs.get_children():
		c.queue_free()
	for k in g.need:
		var l := _label(8, Color("#6ad04a") if State.inv[k] >= g.need[k] else Color("#e2483c"))
		l.text = "%s %d/%d  " % [State.ITEM_NAMES[k], State.inv[k], g.need[k]]
		goal_needs.add_child(l)

# ---------- per frame ----------
func _process(delta: float) -> void:
	frame_ms.append(delta * 1000.0)
	if frame_ms.size() > 600:
		frame_ms.pop_front()
	# Camera: follows the hero along the street, keeps the ground line in the lower quarter.
	# Same framing as the web version: about 560 world units across on a computer, screen px / 1.65 on a phone.
	var vs := get_viewport().get_visible_rect().size
	var px := float(DisplayServer.window_get_size().x)
	var want := minf(560.0, px / 1.65)
	camera.zoom = Vector2.ONE * (vs.x / want)
	camera.position = Vector2(player.position.x, GROUND - vs.y / camera.zoom.y * 0.26)
	# Hint strip: a fresh message wins for a moment, otherwise the target's name.
	hint_t = maxf(0.0, hint_t - delta)
	if hint_t <= 0.0:
		hint.text = player.target.title() if player.target else ""
	hint.visible = hint.text != ""
	act_label.text = player.target.verb() if player.target and not player.job else ("Стоп" if player.job else "Дія")
	var g := State.goal()
	goal_dir.text = "" if g.x < 0.0 else ("• поруч" if absf(g.x - player.position.x) < 24.0 else ("%s %d м" % [">" if g.x > player.position.x else "<", roundi(absf(g.x - player.position.x) / 10.0)]))
	if not lines.is_empty():
		line_t -= delta
		if line_t <= 0.0:
			_next_line()
	_update_mira(delta)
	_layout_hint()

## Mira waits by the shelter door; while the hero works she stops a few steps away, never on the object.
func _update_mira(delta: float) -> void:
	var tx := MIRA_HOME
	if player.job:
		tx = player.position.x - signf(player.job.global_position.x - player.position.x) * 58.0
	var d := tx - mira.position.x
	if absf(d) > 3.0:
		mira.position.x += signf(d) * minf(absf(d), 70.0 * delta)
		mira.face = 1 if d > 0.0 else -1
		mira_walk += delta * 70.0 * 4.0 / 56.0
		mira.frame = floori(mira_walk) % 4
	else:
		mira.face = 1 if player.position.x > mira.position.x else -1
		mira.frame = 12
	mira_joy = maxf(0.0, mira_joy - delta)
	mira.position.y = GROUND - (sin(mira_joy / 1.4 * PI) * 14.0 if mira_joy > 0.0 else 0.0)
	if mira_joy > 0.0:
		mira.frame = 21

## Places the interface for the current screen: goal top-right, dialogue top-centre, buttons in the corners.
func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var goal: Control = ui.get_node("Goal")
	goal.size = Vector2(minf(220.0, vs.x * 0.42), 0)
	goal.position = Vector2(vs.x - goal.size.x - 6, 6)
	dlg.size = Vector2(minf(250.0, vs.x - goal.size.x - 24), 0)
	dlg.position = Vector2(6, 6)
	var s := 0.46
	var l: TouchScreenButton = ui.get_node("BtnLeft")
	var r: TouchScreenButton = ui.get_node("BtnRight")
	var j: TouchScreenButton = ui.get_node("BtnJump")
	var a: TouchScreenButton = ui.get_node("BtnAct")
	for b in [l, r, j, a]:
		b.scale = Vector2(s, s)
	l.position = Vector2(8, vs.y - 96 * s - 8)
	r.position = Vector2(8 + 96 * s + 6, vs.y - 96 * s - 8)
	a.position = Vector2(vs.x - 120 * s - 8, vs.y - 120 * s - 8)
	j.position = Vector2(vs.x - 120 * s - 8 - 96 * s - 6, vs.y - 96 * s - 8)
	act_label.position = a.position + Vector2(4, 4)
	act_label.size = Vector2(120 * s - 8, 120 * s - 8)
	craft.size = Vector2(minf(330.0, vs.x - 20), 0)
	craft.position = Vector2((vs.x - craft.size.x) / 2.0, maxf(8.0, vs.y * 0.18))

func _layout_hint() -> void:
	var vs := get_viewport().get_visible_rect().size
	hint.size = Vector2.ZERO
	hint.reset_size()
	hint.position = Vector2((vs.x - hint.size.x) / 2.0, vs.y - 22 - 30)

# ---------- automatic playthrough for screenshots and frame times: run with `-- --demo=<folder>` ----------
func _demo() -> void:
	var dir := "user://shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			dir = a.substr(7)
	DirAccess.make_dir_recursive_absolute(dir)
	var perf := OS.get_cmdline_user_args().has("--perf")
	var shot := func(n: String):
		await RenderingServer.frame_post_draw
		if perf:
			return
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])
	var hold := func(action: String, secs: float):
		Input.action_press(action)
		await get_tree().create_timer(secs).timeout
		Input.action_release(action)
	var tap := func(action: String):
		Input.action_press(action)
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release(action)
	var stats := func(label: String):
		var f := frame_ms.duplicate()
		f.sort()
		if f.is_empty():
			return
		print("%-12s frames %d  median %.1f  p95 %.1f  max %.1f ms  fps %d" % [label, f.size(), f[f.size() / 2], f[int(f.size() * 0.95)], f[-1], Engine.get_frames_per_second()])
		frame_ms.clear()
	await get_tree().create_timer(1.5).timeout
	frame_ms.clear()
	await shot.call("1-start")
	# Walk to the filter first: it needs a part.
	while player.position.x < 350.0:
		Input.action_press("move_right")
		await get_tree().physics_frame
	Input.action_release("move_right")
	await stats.call("walking")
	await shot.call("2-filter-broken")
	await tap.call("act")
	await get_tree().create_timer(0.3).timeout
	await shot.call("3-no-part")
	# Back to the workbench, craft the unit.
	while player.position.x > 266.0:
		Input.action_press("move_left")
		await get_tree().physics_frame
	Input.action_release("move_left")
	await tap.call("act")
	await get_tree().create_timer(0.5).timeout
	frame_ms.clear()
	await shot.call("4-craft")
	_craft_pressed()
	await get_tree().create_timer(0.3).timeout
	await stats.call("craft open")
	await shot.call("5-crafted")
	close_craft()
	# Fit the unit: the hero walks to his spot, pushes the wrench in pulses.
	while player.position.x < 330.0:
		Input.action_press("move_right")
		await get_tree().physics_frame
	Input.action_release("move_right")
	frame_ms.clear()
	await tap.call("act")
	await get_tree().create_timer(1.2).timeout
	await shot.call("6-fixing")
	await get_tree().create_timer(1.4).timeout
	await stats.call("repairing")
	await shot.call("7-fixed")
	await tap.call("act")
	await get_tree().create_timer(0.7).timeout
	await shot.call("8-tap")
	await get_tree().create_timer(1.3).timeout
	await shot.call("9-water")
	await get_tree().create_timer(1.6).timeout
	await shot.call("10-water2")
	print("result: filter_state=%d repair=%d wood=%d scrap=%d cloth=%d" % [State.filter_state, State.inv.repair, State.inv.wood, State.inv.scrap, State.inv.cloth])
	get_tree().quit()
