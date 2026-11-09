extends Control
## In-game interface: title and depth (top left), pause (top right), the bottom panel with balls,
## special-ball marks and crystals, the speed button, and short tutorial hints next to the action.

const UK := preload("res://scripts/ui_kit.gd")

signal pause_pressed
signal speed_pressed

var main: Node
var logo: TextureRect
var depth_label: Label
var pips: Array[Control] = []
var pause_btn: Button
var panel: NinePatchRect
var balls_label: Label
var gems_label: Label
var gem_icon: TextureRect
var chips: HBoxContainer
var heavy_chip: Control
var electric_chip: Control
var speed_btn: Button
var speed_label: Label
var hint: PanelContainer
var hint_label: Label
var hint_arrow: Node2D
var hint_target := Vector2.ZERO
var hint_t := 0.0
var hand: Node2D
var hand_t := 0.0
var display_gems := -1
var gem_pop := 0.0
var _last := {}

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
	var pip_box := HBoxContainer.new()
	pip_box.position = Vector2(38, 174)
	pip_box.add_theme_constant_override("separation", 8)
	pip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pip_box)
	for i in 4:
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(22, 8)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip_box.add_child(p)
		pips.append(p)
	pause_btn = Button.new()
	pause_btn.theme_type_variation = "TealButton"
	pause_btn.icon = load("res://assets/art/ui/pause.png")
	pause_btn.expand_icon = true
	pause_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_btn.custom_minimum_size = Vector2(74, 74)
	pause_btn.size = Vector2(74, 74)
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
	row.offset_left = 26
	row.offset_right = -26
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	left.add_child(UK.icon("res://assets/art/ui/ball_icon.png", Vector2(54, 54)))
	balls_label = UK.label("", 40)
	left.add_child(balls_label)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(chips)
	heavy_chip = _chip("res://assets/art/balls/ball_heavy.png")
	electric_chip = _chip("res://assets/art/balls/ball_electric.png")
	chips.add_child(electric_chip)
	chips.add_child(heavy_chip)
	var div := ColorRect.new()
	div.color = Color(0.25, 0.65, 0.63, 0.65)
	div.custom_minimum_size = Vector2(3, 56)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dc := CenterContainer.new()
	dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dc.add_child(div)
	row.add_child(dc)
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.62
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 14)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	gem_icon = UK.icon("res://assets/art/ui/gem_icon.png", Vector2(52, 68))
	gem_icon.pivot_offset = Vector2(26, 34)
	right.add_child(gem_icon)
	gems_label = UK.label("", 44)
	right.add_child(gems_label)
	# speed button above the panel, right side
	speed_btn = Button.new()
	speed_btn.theme_type_variation = "TealButton"
	speed_btn.icon = load("res://assets/art/ui/speed.png")
	speed_btn.expand_icon = true
	speed_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_btn.add_theme_constant_override("icon_max_width", 44)
	for st in ["normal", "hover", "pressed"]:
		speed_btn.add_theme_stylebox_override(st, UK.sbt("button_teal_hover.png" if st == "hover" else "button_teal.png", 26, Vector4(14, 10, 14, 10)))
	speed_btn.custom_minimum_size = Vector2(80, 70)
	speed_btn.focus_mode = Control.FOCUS_NONE
	speed_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_btn.offset_left = -104
	speed_btn.offset_right = -24
	speed_btn.offset_top = -190
	speed_btn.offset_bottom = -120
	speed_btn.pressed.connect(func(): speed_pressed.emit())
	speed_btn.visible = false
	add_child(speed_btn)
	speed_label = UK.label("", 24, UK.TEAL)
	speed_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.offset_left = -230
	speed_label.offset_right = -112
	speed_label.offset_top = -170
	speed_label.offset_bottom = -136
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(speed_label)
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

func _chip(tex: String) -> Control:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(UK.icon(tex, Vector2(30, 30)))
	var l := UK.label("", 22, UK.CREAM, 6)
	l.name = "lv"
	c.add_child(l)
	c.visible = false
	return c

func gem_target_global() -> Vector2:
	return gem_icon.get_global_rect().get_center()

func ball_icon_global() -> Vector2:
	return balls_label.get_global_rect().get_center()

func update_state(sim: Sim, flying_gems: int, speed: int, show_speed: bool) -> void:
	var lang := G.lang_index()
	var key := [sim.depth, sim.balls, sim.heavy, sim.electric, sim.volleys, lang, G.meta.crystals - flying_gems, speed, show_speed]
	if key == _last.get("k"):
		return
	_last["k"] = key
	depth_label.text = G.t("depth", [sim.depth])
	balls_label.text = G.balls_text(sim.balls)
	heavy_chip.visible = sim.heavy > 0
	electric_chip.visible = sim.electric > 0
	(heavy_chip.get_node("lv") as Label).text = str(sim.heavy)
	(electric_chip.get_node("lv") as Label).text = str(sim.electric)
	var shown := maxi(0, G.meta.crystals - flying_gems)
	if display_gems >= 0 and shown > display_gems:
		gem_pop = 1.0
	display_gems = shown
	gems_label.text = str(shown)
	var done := sim.volleys % Sim.UPGRADE_EVERY
	for i in 4:
		pips[i].color = Color(0.5, 0.95, 0.9, 0.95) if i < done else Color(0.1, 0.3, 0.3, 0.8)
	speed_btn.visible = show_speed
	speed_label.text = G.t("speed", [speed]) if speed > 1 else ""

func _process(dt: float) -> void:
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
