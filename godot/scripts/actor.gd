@tool
class_name Actor
extends Node2D
## A character drawn from one of the game's pose atlases (hero-*.webp + data/heroes.json).
## Each frame has its own anchor (middle of the boots) and foot line, so the origin of this node
## is always the point where the feet touch the ground, whatever the pose.

## Key in heroes.json and the atlas name: hero-<id>.webp.
@export var hero_id := "einstein":
	set(v):
		hero_id = v
		_load()
## Walking height on screen, in world units (the hero is 70).
@export var height := 70.0
## Frame index in the 27-frame layout (0-3 walk, 12 idle, 13 wind-up, 14 strike, 15 jump, 19 kneel, 21-23 jump phases).
@export var frame := 12:
	set(v):
		frame = v
		queue_redraw()
## 1 = facing right, -1 = facing left.
@export var face := 1:
	set(v):
		face = v
		queue_redraw()
## Item drawn in the hand ("" for none), taken from held.webp.
var held := ""
var held_angle := 0.0

static var _cache := {}
var _tex: Texture2D
var _frames: Array = []
var _unit := 200.0
var _held_tex: Texture2D
var _held_layout := {}

func _ready() -> void:
	_load()

func _load() -> void:
	if not _cache.has("heroes"):
		_cache["heroes"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes.json"))
		_cache["held"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/held.json"))
	var d: Dictionary = _cache["heroes"].get(hero_id, {})
	if d.is_empty():
		return
	_frames = d["frames"]
	_unit = d["unit"]
	_tex = load("res://assets/hero-%s.webp" % hero_id)
	_held_tex = load("res://assets/held.webp")
	_held_layout = _cache["held"]
	queue_redraw()

func _draw() -> void:
	if _tex == null or frame >= _frames.size():
		return
	var f: Dictionary = _frames[frame]
	var k := height / _unit
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face * k, k))
	var foot: float = f.get("foot", f["h"])
	draw_texture_rect_region(_tex, Rect2(-f["anchor"], -foot, f["w"], f["h"]), Rect2(f["x"], f["y"], f["w"], f["h"]))
	if held != "" and _held_layout.has(held) and f.has("hand"):
		var L: Dictionary = _held_layout[held]
		var hand := Vector2(-f["anchor"] + f["hand"][0], -foot + f["hand"][1])
		var sc: float = L["len"] / L["h"] / k
		draw_set_transform(Vector2(hand.x * face * k, hand.y * k), held_angle * face, Vector2(face * k * sc, k * sc))
		draw_texture_rect_region(_held_tex, Rect2(-L["gx"], -L["gy"], L["w"], L["h"]), Rect2(L["x"], L["y"], L["w"], L["h"]))
	draw_set_transform(Vector2.ZERO)
