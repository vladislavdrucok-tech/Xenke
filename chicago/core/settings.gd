class_name Settings
extends RefCounted
## Player settings (user://settings.cfg, separate from saves): interface scale, aim assist, touch UI mode and
## remapped keys. Defaults: the InputMap from project.godot. Applied at boot and whenever a value changes.

const PATH := "user://settings.cfg"
const REMAPPABLE := ["move_up", "move_down", "move_left", "move_right", "interact", "vehicle", "sprint", "reload", "pause"]
const UI_SCALES := [0.8, 0.9, 1.0, 1.15, 1.3, 1.5]

static var ui_scale := 1.0
static var aim_assist := true
static var touch_mode := "auto"        # auto | on | off
static var keys := {}                  # action -> physical keycode (only remapped actions)
static var _defaults := {}             # action -> [events] captured before any remap
static var path := PATH                # tests point this elsewhere

static func load_and_apply() -> void:
	_capture_defaults()
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		ui_scale = clampf(float(cf.get_value("ui", "scale", 1.0)), UI_SCALES[0], UI_SCALES[-1])
		aim_assist = bool(cf.get_value("gameplay", "aim_assist", true))
		var tm := String(cf.get_value("ui", "touch", "auto"))
		touch_mode = tm if tm in ["auto", "on", "off"] else "auto"
		keys = {}
		if cf.has_section("keys"):
			for a in cf.get_section_keys("keys"):
				if a in REMAPPABLE:
					keys[a] = int(cf.get_value("keys", a))
	apply_keys()

static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ui", "scale", ui_scale)
	cf.set_value("ui", "touch", touch_mode)
	cf.set_value("gameplay", "aim_assist", aim_assist)
	for a in keys:
		cf.set_value("keys", a, keys[a])
	cf.save(path)

static func _capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for a in REMAPPABLE:
		_defaults[a] = InputMap.action_get_events(a).duplicate()

## Rebinding replaces the action's keyboard keys with one key (gamepad / mouse events are kept). A key already used
## by another remappable action is taken from it (that action falls back to its other default keys).
static func rebind(action: String, physical_keycode: int) -> void:
	_capture_defaults()
	for other in keys.keys():
		if other != action and int(keys[other]) == physical_keycode:
			keys.erase(other)
	keys[action] = physical_keycode
	apply_keys()
	save()

static func reset_keys() -> void:
	keys = {}
	apply_keys()
	save()

static func apply_keys() -> void:
	_capture_defaults()
	for a in REMAPPABLE:
		InputMap.action_erase_events(a)
		for e in _defaults[a]:
			if keys.has(a) and e is InputEventKey:
				continue
			# A default key now owned by another action's remap is dropped here too.
			if e is InputEventKey and _taken_by_other(a, (e as InputEventKey).physical_keycode):
				continue
			InputMap.action_add_event(a, e)
		if keys.has(a):
			var k := InputEventKey.new()
			k.physical_keycode = int(keys[a])
			InputMap.action_add_event(a, k)

static func _taken_by_other(action: String, code: int) -> bool:
	for other in keys:
		if other != action and int(keys[other]) == code:
			return true
	return false

static func key_name(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string((e as InputEventKey).physical_keycode)
	return "—"

## Should the touch interface be shown? "auto" = on mobile devices with a touchscreen.
static func want_touch() -> bool:
	if OS.get_cmdline_user_args().has("--touch") or touch_mode == "on":
		return true
	if touch_mode == "off":
		return false
	return DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")
