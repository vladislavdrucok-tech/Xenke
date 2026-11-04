class_name InputRouter
extends RefCounted
## One place that turns keyboard and touch into gameplay intent, so actors never read devices directly.
## The touch joystick (ui/touch_controls.gd) writes touch_vec; bots and tests write bot_vec.

static var touch_vec := Vector2.ZERO
static var touch_active := false
static var bot_vec := Vector2.ZERO
static var bot_active := false

## Desired direction on screen (x right, y down), length 0..1.
static func move_vector() -> Vector2:
	if bot_active:
		return bot_vec.limit_length(1.0)
	var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_active and touch_vec.length() > k.length():
		return touch_vec.limit_length(1.0)
	return k

static func is_touch_steering() -> bool:
	return (touch_active and touch_vec.length() > 0.05) or bot_active

static func reset() -> void:
	touch_vec = Vector2.ZERO
	touch_active = false
	bot_vec = Vector2.ZERO
	bot_active = false
