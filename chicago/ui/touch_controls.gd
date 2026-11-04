class_name TouchControls
extends Control
## Android controls: a floating joystick (a touch that starts in the left part of the screen, away from buttons),
## the context action button (its label is the current verb), the car button and pause. Each touch is tracked by its
## index, so a second finger never steals the stick, and a touch that starts on a button never moves the hero.
## Sizes follow the safe area (display cutouts) and stay at least 72 px for comfortable thumbs.

signal action_pressed
signal attack_pressed
signal pause_pressed

const JOY_R := 78.0
const DEADZONE := 0.15

var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var act_btn: Button
var atk_btn: Button
var pause_btn: Button
var safe := Rect2()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	act_btn = _btn("HUD_ACT_USE", 120)
	act_btn.pressed.connect(func(): action_pressed.emit())
	atk_btn = _btn("HUD_ACT_ATTACK", 96)
	atk_btn.pressed.connect(func(): attack_pressed.emit())
	pause_btn = _btn("II", 72)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	get_viewport().size_changed.connect(layout)
	layout()

func _btn(text: String, s: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(s, s)
	b.size = Vector2(s, s)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.modulate = Color(1, 1, 1, 0.85)
	add_child(b)
	return b

static func safe_rect(vp_size: Vector2, screen_safe: Rect2i, screen_size: Vector2i) -> Rect2:
	## Converts the display safe area (device pixels) into viewport coordinates. Empty / unknown -> the whole view.
	if screen_safe.size.x <= 0 or screen_size.x <= 0:
		return Rect2(Vector2.ZERO, vp_size)
	var k := vp_size / Vector2(screen_size)
	return Rect2(Vector2(screen_safe.position) * k, Vector2(screen_safe.size) * k)

func layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	safe = safe_rect(vs, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var m := 18.0
	act_btn.position = Vector2(safe.end.x - act_btn.size.x - m, safe.end.y - act_btn.size.y - m)
	atk_btn.position = act_btn.position + Vector2(-atk_btn.size.x - 16.0, act_btn.size.y - atk_btn.size.y)
	pause_btn.position = Vector2(safe.end.x - pause_btn.size.x - m, safe.position.y + m + 56.0)

func set_verb(key: String, enabled: bool) -> void:
	act_btn.text = tr(key) if key != "" else tr("HUD_ACT_USE")
	act_btn.disabled = not enabled

func _over_button(p: Vector2) -> bool:
	for b in [act_btn, atk_btn, pause_btn]:
		if b.visible and Rect2(b.position, b.size).grow(8.0).has_point(p):
			return true
	return false

func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var vs := get_viewport().get_visible_rect().size
			if joy_index == -1 and e.position.x < vs.x * 0.55 and e.position.y > vs.y * 0.22 and not _over_button(e.position):
				joy_index = e.index
				joy_origin = e.position
				joy_pos = e.position
				InputRouter.touch_active = true
				InputRouter.touch_vec = Vector2.ZERO
				queue_redraw()
		elif e.index == joy_index:
			release()
	elif e is InputEventScreenDrag and e.index == joy_index:
		var d: Vector2 = e.position - joy_origin
		if d.length() > JOY_R:
			joy_origin += d - d.normalized() * JOY_R   # the base follows a thumb that slides too far
			d = e.position - joy_origin
		joy_pos = e.position
		var v := d / JOY_R
		InputRouter.touch_vec = Vector2.ZERO if v.length() < DEADZONE else v
		queue_redraw()

func release() -> void:
	joy_index = -1
	InputRouter.touch_vec = Vector2.ZERO
	InputRouter.touch_active = false
	queue_redraw()

func _draw() -> void:
	if joy_index == -1:
		return
	draw_circle(joy_origin, JOY_R, Color(1, 1, 1, 0.12))
	draw_arc(joy_origin, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(joy_pos, 30.0, Color(1, 1, 1, 0.4))
