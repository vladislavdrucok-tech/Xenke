extends Control
## In-game interface: title, depth and progress to the next upgrade (top left); speed and pause (top right,
## outside the field); the bottom panel with the ball series and crystals. Every small indicator explains
## itself on a tap. Tutorial hints appear next to the action.

const UK := preload("res://scripts/ui_kit.gd")

signal pause_pressed
signal speed_pressed

var main: Node
var logo: TextureRect
var depth_label: Label
var pips: Array[Control] = []
var progress_label: Label
var progress_btn: Button
var pause_btn: Button
var panel: NinePatchRect
var balls_btn: Button
var balls_label: Label
var gems_label: Label
var gem_icon: TextureRect
var chips: HBoxContainer
var heavy_chip: Control
var electric_chip: Control
var speed_btn: Button
var info: Control
var info_panel: PanelContainer
var info_box: VBoxContainer
var info_t := 0.0
var hint: PanelContainer
var hint_label: Label
var hint_arrow: Node2D
var hint_target := Vector2.ZERO
var hint_t := 0.0
var hand: Node2D
var hand_t := 0.0
var level_box: VBoxContainer
var stones_label: Label
var vol_label: Label
var vol_stars: HBoxContainer
var display_gems := -1
var gem_pop := 0.0
var _last := {}
var _sim: Sim

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UK.theme()
	logo = UK.icon("res://assets/art/ui/logo.png", Vector2(234, 125))
	logo.position = Vector2(16, 10)
	add_child(logo)
	depth_label = UK.label("", 32)
	depth_label.position = Vector2(36, 128)
	add_child(depth_label)
	# progress to the next upgrade choice: 4 marks + caption, tap for an explanation
	progress_btn = _flat_button(Vector2(30, 168), Vector2(200, 36))
	progress_btn.pressed.connect(func(): show_upgrade_info())
	add_child(progress_btn)
	var pip_box := HBoxContainer.new()
	pip_box.position = Vector2(8, 13)
	pip_box.add_theme_constant_override("separation", 5)
	pip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_btn.add_child(pip_box)
	for i in 4:
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(16, 9)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip_box.add_child(p)
		pips.append(p)
		if i < 3:
			pip_box.add_child(_sp(1))
	progress_label = UK.label("", 19, UK.TEAL, 5, "Rubik-Bold")
	progress_label.position = Vector2(92, 4)
	progress_btn.add_child(progress_label)
	# level mode: stones still to break (field, below the floor and queue), volleys and the stars still reachable
	level_box = VBoxContainer.new()
	level_box.position = Vector2(30, 200)
	level_box.add_theme_constant_override("separation", 0)
	level_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(level_box)
	stones_label = UK.label("", 22, UK.CREAM, 6, "Rubik-Bold")
	level_box.add_child(stones_label)
	var vh := HBoxContainer.new()
	vh.add_theme_constant_override("separation", 6)
	vh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vol_stars = HBoxContainer.new()
	vol_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vh.add_child(vol_stars)
	vol_label = UK.label("", 20, UK.TEAL, 5, "Rubik-Bold")
	vh.add_child(vol_label)
	level_box.add_child(vh)
	level_box.visible = false
	# top right, outside the field: speed, pause
	speed_btn = Button.new()
	speed_btn.theme_type_variation = "TealButton"
	speed_btn.icon = load("res://assets/art/ui/speed.png")
	speed_btn.expand_icon = true
	speed_btn.add_theme_constant_override("icon_max_width", 30)
	speed_btn.add_theme_constant_override("h_separation", 2)
	speed_btn.add_theme_font_size_override("font_size", 26)
	for st in ["normal", "hover", "pressed", "disabled"]:
		speed_btn.add_theme_stylebox_override(st, UK.sbt("button_teal_hover.png" if st == "hover" else "button_teal.png", 26, Vector4(10, 10, 12, 10)))
	speed_btn.focus_mode = Control.FOCUS_NONE
	speed_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	speed_btn.offset_left = -204
	speed_btn.offset_right = -110
	speed_btn.offset_top = 22
	speed_btn.offset_bottom = 96
	speed_btn.pressed.connect(func():
		G.sfx("click", -6.0)
		speed_pressed.emit())
	add_child(speed_btn)
	pause_btn = Button.new()
	pause_btn.theme_type_variation = "TealButton"
	pause_btn.icon = load("res://assets/art/ui/pause.png")
	pause_btn.expand_icon = true
	pause_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_btn.add_theme_constant_override("icon_max_width", 44)
	for st in ["normal", "hover", "pressed"]:
		pause_btn.add_theme_stylebox_override(st, UK.sbt("button_teal_hover.png" if st == "hover" else "button_teal.png", 26, Vector4(12, 12, 12, 12)))
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -96
	pause_btn.offset_right = -22
	pause_btn.offset_top = 22
	pause_btn.offset_bottom = 96
	pause_btn.pressed.connect(func():
		G.sfx("click", -4.0)
		pause_pressed.emit())
	add_child(pause_btn)
	# bottom panel
	panel = NinePatchRect.new()
	panel.texture = load("res://assets/art/ui/panel.png")
	panel.patch_margin_left = 40
	panel.patch_margin_right = 40
	panel.patch_margin_top = 40
	panel.patch_margin_bottom = 40
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 8
	panel.offset_right = -8
	panel.offset_top = -106
	panel.offset_bottom = -4
	add_child(panel)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -22
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	# left: the ball series (tap: what each ball of the volley does)
	balls_btn = _flat_button(Vector2.ZERO, Vector2(0, 96))
	balls_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balls_btn.pressed.connect(func(): show_series_info())
	row.add_child(balls_btn)
	var left := HBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balls_btn.add_child(left)
	left.add_child(_center(UK.icon("res://assets/art/ui/ball_icon.png", Vector2(52, 52))))
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", -2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(lines)
	balls_label = UK.label("", 38)
	lines.add_child(balls_label)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(chips)
	electric_chip = _chip("res://assets/art/balls/ball_electric.png")
	heavy_chip = _chip("res://assets/art/balls/ball_heavy.png")
	chips.add_child(electric_chip)
	chips.add_child(heavy_chip)
	var div := ColorRect.new()
	div.color = Color(0.25, 0.65, 0.63, 0.65)
	div.custom_minimum_size = Vector2(3, 56)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_center(div))
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.55
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 14)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	gem_icon = UK.icon("res://assets/art/ui/gem_icon.png", Vector2(50, 66))
	gem_icon.pivot_offset = Vector2(25, 33)
	right.add_child(_center(gem_icon))
	gems_label = UK.label("", 44)
	right.add_child(gems_label)
	# hint bubble
	hint = PanelContainer.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_stylebox_override("panel", UK.sbt("card.png", 40, Vector4(26, 16, 26, 16)))
	hint_label = UK.label("", 27, UK.CREAM, 6, "Rubik-Bold")
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(420, 0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_child(hint_label)
	hint.visible = false
	add_child(hint)
	hint_arrow = Node2D.new()
	hint_arrow.draw.connect(_draw_arrow)
	add_child(hint_arrow)
	hand = Node2D.new()
	hand.draw.connect(_draw_hand)
	hand.visible = false
	add_child(hand)
	# explanation card (a tap anywhere closes it)
	info = Control.new()
	info.set_anchors_preset(Control.PRESET_FULL_RECT)
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	info.visible = false
	info.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			hide_info())
	add_child(info)
	info_panel = PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UK.sbt("card.png", 40, Vector4(28, 22, 28, 22)))
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(info_panel)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 10)
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(info_box)

func _sp(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc

func _flat_button(pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	return b

func _chip(tex: String) -> Control:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", 4)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(_center(UK.icon(tex, Vector2(24, 24))))
	var l := UK.label("", 20, UK.TEAL, 5, "Rubik-Bold")
	l.name = "lv"
	c.add_child(l)
	c.visible = false
	return c

func _ball_path(k: int) -> String:
	var kind := "normal"
	if k == Sim.K_HEAVY:
		kind = "heavy"
	elif k == Sim.K_ELECTRIC:
		kind = "electric"
	return "res://assets/art/balls/%s_%s.png" % [G.selected("ball"), kind]

func gem_target_global() -> Vector2:
	return gem_icon.get_global_rect().get_center()

func ball_icon_global() -> Vector2:
	return balls_label.get_global_rect().get_center()

func refresh() -> void:
	_last.clear()

func update_state(sim: Sim, flying_gems: int, speed: int, show_speed: bool) -> void:
	_sim = sim
	var lang: String = G.settings.lang
	var boost: bool = main != null and main.get("boost") == true
	var left := sim.remaining_targets() if sim.mode == "level" else 0
	var key := [sim.depth, sim.balls, sim.heavy, sim.electric, sim.volleys, lang, G.meta.crystals - flying_gems, speed, show_speed, boost, sim.mode, left, G.selected("ball")]
	if key == _last.get("k"):
		return
	_last["k"] = key
	var lv: Dictionary = main.level if main != null and sim.mode == "level" else {}
	if sim.mode == "level" and not lv.is_empty():
		depth_label.text = G.t("level_n", {"n": int(lv.n)})
		level_box.visible = true
		stones_label.text = G.tn("stones_left_n", left)
		# the volley being aimed or in flight counts: stars still possible if it wins the level
		var cur := sim.volleys + (0 if sim.phase == Sim.PH_WON or sim.phase == Sim.PH_OVER else 1)
		var reach := 1
		var limit := 0
		if cur <= int(lv.t3):
			reach = 3
			limit = int(lv.t3)
		elif cur <= int(lv.t2):
			reach = 2
			limit = int(lv.t2)
		if sim.revive_used:
			reach = mini(reach, 2)
			limit = int(lv.t2) if reach == 2 else 0
		for c in vol_stars.get_children():
			vol_stars.remove_child(c)
			c.queue_free()
		for i in 3:
			vol_stars.add_child(UK.icon(UK.ART + ("star_on.png" if i < reach else "star_off.png"), Vector2(22, 22)))
		vol_label.text = G.t("volley_of", {"n": cur, "m": limit}) if limit > 0 else G.t("volley_n", {"n": cur})
	else:
		depth_label.text = G.t("depth", {"n": sim.depth})
		level_box.visible = false
	UK.fit_label(depth_label, 330, 18)
	balls_label.text = G.balls_text(sim.balls)
	UK.fit_label(balls_label, 330, 20)
	heavy_chip.visible = sim.heavy > 0
	electric_chip.visible = sim.electric > 0
	chips.visible = sim.heavy > 0 or sim.electric > 0
	(heavy_chip.get_node("lv") as Label).text = G.t("lv_short", {"n": sim.heavy})
	(electric_chip.get_node("lv") as Label).text = G.t("lv_short", {"n": sim.electric})
	var shown := maxi(0, G.meta.crystals - flying_gems)
	if display_gems >= 0 and shown > display_gems:
		gem_pop = 1.0
	display_gems = shown
	gems_label.text = str(shown)
	var every := sim.upgrade_every
	progress_btn.visible = every > 0 and not sim.available_upgrades().is_empty()
	var done := sim.volleys % maxi(1, every)
	for i in 4:
		pips[i].color = Color(0.5, 0.95, 0.9, 0.95) if i < done else Color(0.1, 0.3, 0.3, 0.8)
	progress_label.text = G.t("upgrade_progress", {"n": done, "m": every})
	# speed: shown in its own button next to pause; active only while a volley flies
	speed_btn.disabled = not show_speed
	speed_btn.text = "×%d" % speed
	speed_btn.modulate = Color(1, 1, 1, 1.0 if show_speed else 0.45)
	speed_btn.theme_type_variation = "OnButton" if boost else "TealButton"

# ---------------------------------------------------------------- explanations on tap

func _open_info(anchor_bottom: float, anchor_top := -1.0) -> void:
	info.visible = true
	info_t = 0.0
	info_panel.reset_size()
	await get_tree().process_frame
	info_panel.reset_size()
	var sz := info_panel.size
	var x := (size.x - sz.x) * 0.5
	var y := anchor_bottom - sz.y if anchor_top < 0.0 else anchor_top
	info_panel.position = Vector2(x, clampf(y, 110, size.y - sz.y - 110))

func _clear_info() -> void:
	for c in info_box.get_children():
		info_box.remove_child(c)
		c.queue_free()
	info_panel.size = Vector2.ZERO
	info_box.size = Vector2.ZERO

func _line(text: String, size_px := 22, color := UK.CREAM, icon := "") -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		h.add_child(_center(UK.icon(icon, Vector2(30, 30))))
	var l := UK.label(text, size_px, color, 5, "Rubik-Bold")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540 if icon == "" else 500, 0)
	h.add_child(l)
	return h

func show_series_info() -> void:
	## The real series of the next volley, ball by ball, and what the special ones do.
	if _sim == null:
		return
	G.sfx("click", -6.0)
	_clear_info()
	info_box.add_child(_line(G.t("series_title", {"balls": G.balls_text(_sim.balls)}), 28))
	var grid := GridContainer.new()
	grid.columns = 16
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in _sim.balls:
		var k := _sim.ball_kind(i)
		grid.add_child(UK.icon(_ball_path(k), Vector2(30, 30)))
	info_box.add_child(_center(grid))
	info_box.add_child(_line(G.t("series_normal"), 21, UK.CREAM, _ball_path(Sim.K_NORMAL)))
	if _sim.electric > 0:
		info_box.add_child(_line(G.t("series_electric", {"n": _sim.electric, "m": Sim.ZAP_DMG[_sim.electric]}), 21, UK.CREAM, _ball_path(Sim.K_ELECTRIC)))
	if _sim.heavy > 0:
		info_box.add_child(_line(G.t("series_heavy", {"n": _sim.heavy, "m": Sim.HEAVY_DMG[_sim.heavy]}), 21, UK.CREAM, _ball_path(Sim.K_HEAVY)))
	if (_sim.electric == 0 or _sim.heavy == 0) and _sim.upgrade_every > 0:
		info_box.add_child(_line(G.t("series_locked"), 19, UK.TEAL))
	info_box.add_child(_line(G.t("tap_close"), 18, Color(0.7, 0.85, 0.83)))
	_open_info(size.y - 118)

func show_upgrade_info() -> void:
	if _sim == null:
		return
	G.sfx("click", -6.0)
	_clear_info()
	var every := maxi(1, _sim.upgrade_every)
	var done := _sim.volleys % every
	info_box.add_child(_line(G.t("upgrade_progress", {"n": done, "m": every}), 28))
	info_box.add_child(_line(G.tn("info_upgrade", every, {"done": done}), 22))
	info_box.add_child(_line(G.t("tap_close"), 18, Color(0.7, 0.85, 0.83)))
	_open_info(-1.0, 214)

func hide_info() -> void:
	info.visible = false

func _process(dt: float) -> void:
	if info.visible:
		info_t += dt
		info_panel.modulate.a = minf(1.0, info_t * 5.0)
		if info_t > 7.0:
			hide_info()
	gem_pop = maxf(0.0, gem_pop - dt * 4.0)
	var s := 1.0 + 0.25 * sin(gem_pop * PI)
	gem_icon.scale = Vector2(s, s)
	hint_t += dt
	if hint.visible:
		hint.modulate.a = minf(1.0, hint_t * 4.0)
		hint_arrow.queue_redraw()
	if hand.visible:
		hand_t += dt
		hand.queue_redraw()

# ---------------------------------------------------------------- hints

func show_hint(text: String, at: Vector2, target := Vector2.INF) -> void:
	hint_label.text = text
	hint.reset_size()
	hint.visible = true
	hint_t = 0.0
	await get_tree().process_frame
	var sz := hint.size
	hint.position = Vector2(clampf(at.x - sz.x * 0.5, 14, size.x - sz.x - 14), clampf(at.y - sz.y * 0.5, 190, size.y - 120 - sz.y))
	hint_target = target
	hint_arrow.visible = target != Vector2.INF

func hide_hint() -> void:
	hint.visible = false
	hint_arrow.visible = false
	hand.visible = false

func show_hand(on: bool) -> void:
	hand.visible = on
	hand_t = 0.0

func _draw_arrow() -> void:
	if not hint.visible or hint_target == Vector2.INF:
		return
	var r := Rect2(hint.position, hint.size)
	var from := Vector2(clampf(hint_target.x, r.position.x + 30, r.end.x - 30), r.position.y if hint_target.y < r.position.y else r.end.y)
	var bob := sin(hint_t * 6.0) * 6.0
	var to := hint_target + (from - hint_target).normalized() * (16.0 + bob)
	var col := Color(0.6, 1.0, 0.95, minf(1.0, hint_t * 4.0))
	hint_arrow.draw_line(from, to, col, 5.0, true)
	var d := (to - from).normalized()
	var n := d.orthogonal()
	hint_arrow.draw_colored_polygon(PackedVector2Array([to + d * 6, to - d * 16 + n * 11, to - d * 16 - n * 11]), col)

func _draw_hand() -> void:
	# a fingertip showing the swipe: press, drag down-left, release
	var k := fmod(hand_t, 2.2) / 2.2
	var start := Vector2(470, 860)
	var end_ := Vector2(330, 1010)
	var p := start
	var a := 1.0
	if k < 0.15:
		a = k / 0.15
	elif k < 0.75:
		p = start.lerp(end_, (k - 0.15) / 0.6)
	else:
		p = end_
		a = 1.0 - (k - 0.75) / 0.25
	if k > 0.15:
		hand.draw_line(start, p, Color(1, 0.95, 0.8, 0.35 * a), 6.0, true)
	hand.draw_circle(p, 30, Color(1, 0.95, 0.8, 0.25 * a))
	hand.draw_circle(p, 18, Color(1, 0.95, 0.8, 0.85 * a))
	hand.draw_arc(p, 18, 0, TAU, 24, Color(0.23, 0.1, 0.04, 0.8 * a), 3.0, true)
