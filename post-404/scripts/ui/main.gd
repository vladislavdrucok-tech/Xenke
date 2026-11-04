extends Control
## Root of the app: swaps screens with a short fade, shows toasts.

const SCREENS := {
	"menu": "res://scenes/menu.tscn",
	"shift": "res://scenes/shift.tscn",
	"results": "res://scenes/results.tscn",
	"office": "res://scenes/office.tscn",
	"collection": "res://scenes/collection.tscn",
	"letters": "res://scenes/letters.tscn",
	"settings": "res://scenes/settings.tscn",
	"story": "res://scenes/story.tscn",
	
}

var current: Control
var current_name := ""
var holder: Control
var fade: ColorRect
var toasts: VBoxContainer
var _switching := false


func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.main = self
	var bg := ColorRect.new()
	bg.color = UI.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	holder = Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(get_viewport_rect().size.x / 2 - 320, 140)
	toasts.custom_minimum_size = Vector2(640, 0)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)
	fade = ColorRect.new()
	fade.color = UI.INK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	Game.notice.connect(toast)
	get_viewport().size_changed.connect(_on_resize)
	var start := _start_screen()
	show_screen(start[0], start[1])
	for n in Game.pending_notices:
		toast(n)
	Game.pending_notices.clear()
	_auto_demo()


func _start_screen() -> Array:
	var p := Game.profile
	if not Story.is_done(p, "prologue"):
		return ["story", {"chapter": 0, "then": "tutorial"}]
	if not p.get("tutorial_done", false):
		return ["shift", {"mode": "tutorial"}]
	return ["menu", {}]


func _on_resize() -> void:
	toasts.position = Vector2(get_viewport_rect().size.x / 2 - 320, 140)


func show_screen(screen_name: String, data: Dictionary = {}) -> void:
	if _switching:
		return
	_switching = true
	if current:
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 1.0, 0.12)
		await tw.finished
		current.queue_free()
		current = null
	var scene: PackedScene = load(SCREENS[screen_name])
	var s: Control = scene.instantiate()
	if s.has_method("setup"):
		s.setup(data)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(s)
	current = s
	current_name = screen_name
	fade.color.a = 1.0
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.18)
	_switching = false


func back_pressed() -> void:
	if current and current.has_method("on_back"):
		current.on_back()
	elif current_name != "menu":
		show_screen("menu")


func toast(text: String) -> void:
	var p := UI.panel("ui_panel")
	var l := UI.wrap(UI.label(text, 28, UI.PAPER, HORIZONTAL_ALIGNMENT_CENTER))
	l.custom_minimum_size = Vector2(580, 0)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	UI.pop(p)
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


## Automated visual check: `godot --path . -- --shots=<dir>` walks through the
## screens and saves screenshots, then quits.
func _auto_demo() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
	if dir == "":
		return
	var demo: Node = load("res://tests/screenshot_tour.gd").new()
	add_child(demo)
	demo.run(dir)
