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
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()

static var _data := {}
var _tex: Texture2D
var _frames: Array = []
var _unit := 210.0
var _wrench: Texture2D

func _ready() -> void:
	_load()

func _load() -> void:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/rest_chars.json"))
	if not _data.has(char_name):
		return
	_frames = _data[char_name].frames
	_unit = _data[char_name].unit
	_tex = load("res://assets/rest/%s.png" % char_name)
	_wrench = load("res://assets/rest/wrench_0.png")
	queue_redraw()

func frame_count() -> int:
	return _frames.size()

func _draw() -> void:
	if _tex == null or frame >= _frames.size():
		return
	var f: Dictionary = _frames[frame]
	var k := height / _unit
	var sx := face * (-1 if art_faces_left else 1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx * k, k))
	draw_texture_rect_region(_tex, Rect2(-f.anchor, -f.foot, f.w, f.h), Rect2(f.x, f.y, f.w, f.h), tint)
	if held == "wrench" and _wrench:
		var hand := Vector2(-f.anchor + f.hand[0], -f.foot + f.hand[1])
		draw_set_transform(Vector2(hand.x * sx * k, hand.y * k), held_angle * sx, Vector2(sx * 0.22, 0.22))
		draw_texture(_wrench, -Vector2(_wrench.get_width() * 0.15, _wrench.get_height() * 0.5))
	draw_set_transform(Vector2.ZERO)
