class_name Prop
extends Interactable
## An object from the art pack with visible states (godot/assets/rest/<art>_<state>.png, all on one canvas).
## Origin = middle of the object's base on the ground. What it does is decided by the mission:
## mission.info(id) -> {title, verb, block, work, tool, spot, usable}; mission.done(id) when the job is finished.

@export var id := ""
@export var art := ""
@export var state := 0:
	set(v):
		state = v
		queue_redraw()
## Width of the interaction area in world units (centred on the object unless zone_offset moves it).
@export var zone_w := 50.0
@export var zone_offset := 0.0
var mission: Node
var art_scale := 1.0
var flip := false
## A soft shadow where the object meets the floor (off for things on a wall).
var ground_shadow := true
var pulse_fx: Callable

static var _meta := {}
var _tex: Array[Texture2D] = []
var _size := Vector2(40, 40)

func _ready() -> void:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/rest_props.json"))
	if art != "" and _meta.has(art):
		var m: Dictionary = _meta[art]
		for i in int(m.states):
			_tex.append(Art.tex("res://assets/rest/%s_%d.png" % [art, i]))
		_size = Vector2(m.w, m.h) * art_scale
	elif art != "" and not Art.prop(art).is_empty():
		# A prop from the new sheets (M, C): same layout, other folder.
		var m := Art.prop(art)
		for i in int(m.states):
			_tex.append(Art.prop_tex(art, i))
		_size = Vector2(m.w, m.h) * art_scale
	highlight = Rect2(-_size.x / 2.0, -_size.y, _size.x, _size.y)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(zone_w, 60)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(zone_offset, -30)
	add_child(cs)

func size() -> Vector2:
	return _size

func _info() -> Dictionary:
	return mission.info(id) if mission else {}

func usable() -> bool:
	return _info().get("usable", true)

func title() -> String:
	return _info().get("title", title_text)

func verb() -> String:
	return _info().get("verb", verb_text)

func blocked() -> String:
	return _info().get("block", "")

## Work time, tool and working spot can change with the object's state, so they are read when a job starts.
func prepare() -> void:
	var i := _info()
	work_time = i.get("work", 0.0)
	tool = i.get("tool", "")
	spot_x = i.get("spot", NAN)

func on_pulse(n: int) -> void:
	if mission and mission.has_method("pulse"):
		mission.pulse(id, n)

func on_progress(p: float) -> void:
	if mission and mission.has_method("progress"):
		mission.progress(id, p)

func finish() -> void:
	if mission:
		mission.done(id)
	super.finish()

func _process(delta: float) -> void:
	super._process(delta)

func _draw() -> void:
	if state < _tex.size() and _tex[state]:
		var t := _tex[state]
		var r := Rect2(-_size.x / 2.0, -_size.y, _size.x, _size.y)
		if ground_shadow:
			draw_texture_rect(Art.shadow_tex(), Rect2(-_size.x * 0.55, -3.0, _size.x * 1.1, 7.0), false)
		if flip:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture_rect(t, r, false)
		draw_set_transform(Vector2.ZERO)
	super._draw()
