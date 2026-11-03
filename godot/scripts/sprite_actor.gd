@tool
class_name SpriteActor
extends Node2D
## A character from the 'Remaining' pack (godot/assets/rest/<name>.png + data/rest_chars.json).
## The node's origin is where the feet touch the ground; every frame keeps the same scale.

@export var char_name := "einstein":
	set(v):
		char_name = v
		_load()
## Walking height in world units (the hero is 70).
@export var height := 70.0
@export var frame := 4:
	set(v):
		if v != frame:
			frame = v
			queue_redraw()
## 1 = facing right, -1 = left. Crawlers are drawn facing left in the art, so they set `art_faces_left`.
@export var face := 1:
	set(v):
		if v != face:
			face = v
			queue_redraw()
@export var art_faces_left := false
## Item drawn in the hand ("" = none).
var held := ""
var held_angle := 0.0:
	set(v):
		held_angle = v
		queue_redraw()
## Contact shadow under the feet (0 = none); the hero fades it while in the air.
var shadow := 1.0:
	set(v):
		if not is_equal_approx(v, shadow):
			shadow = v
			queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()

static var _data := {}
static var _new := {}
var _tex: Texture2D
var _tex_extra: Texture2D
var _frames: Array = []
## Named extra frames (M1 crawler, M2 Einstein, P3 Mira) or a whole new sheet (P2 Sava): name -> frame index.
var _names := {}
var _unit := 210.0
var _wrench: Texture2D

func _ready() -> void:
	_load()

func _load() -> void:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/rest_chars.json"))
		if FileAccess.file_exists("res://data/new_art.json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/new_art.json"))
			_new = d.get("chars", {}) if typeof(d) == TYPE_DICTIONARY else {}
	_names = {}
	_tex_extra = null
	var extra: Dictionary = _new.get(char_name, {})
	if _data.has(char_name):
		_frames = _data[char_name].frames.duplicate()
		_unit = _data[char_name].unit
		_tex = Art.tex("res://assets/rest/%s.png" % char_name)
	elif extra.has("atlas") and ResourceLoader.exists(extra.atlas):
		_frames = extra.frames.duplicate()
		_unit = extra.unit
		_tex = Art.tex(extra.atlas)
		_names = extra.names
	else:
		return
	if extra.has("extra") and ResourceLoader.exists(extra.extra):
		_tex_extra = Art.tex(extra.extra)
		var base := _frames.size()
		for f in extra.frames:
			var g: Dictionary = f.duplicate()
			g["extra"] = true
			_frames.append(g)
		for n in extra.names:
			_names[n] = base + int(extra.names[n])
	_wrench = Art.tex("res://assets/rest/wrench_0.png")
	queue_redraw()

## Index of a named frame ("jump_up", "climb_1", "sleep"...), or `fallback` when that picture has not arrived yet.
func pose(name: String, fallback: int) -> int:
	return _names.get(name, fallback)

func has_pose(name: String) -> bool:
	return _names.has(name)

func frame_count() -> int:
	return _frames.size()

func _draw() -> void:
	if _tex == null or frame >= _frames.size():
		return
	var f: Dictionary = _frames[frame]
	var k := height / _unit
	if shadow > 0.0:
		var sw: float = clampf(f.w * k * 0.62, height * 0.35, height * 1.4)
		draw_texture_rect(Art.shadow_tex(), Rect2(-sw / 2.0, -3.0, sw, 6.0), false, Color(1, 1, 1, shadow))
	var sx := face * (-1 if art_faces_left else 1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx * k, k))
	var t: Texture2D = _tex_extra if f.get("extra", false) else _tex
	draw_texture_rect_region(t, Rect2(-f.anchor, -f.foot, f.w, f.h), Rect2(f.x, f.y, f.w, f.h), tint)
	if held == "wrench" and _wrench:
		var hand := Vector2(-f.anchor + f.hand[0], -f.foot + f.hand[1])
		draw_set_transform(Vector2(hand.x * sx * k, hand.y * k), held_angle * sx, Vector2(sx * 0.22, 0.22))
		draw_texture(_wrench, -Vector2(_wrench.get_width() * 0.15, _wrench.get_height() * 0.5))
	draw_set_transform(Vector2.ZERO)
