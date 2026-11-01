extends Node2D
## Standing water between x0 and x1. While it is deep the hero cannot wade in: invisible walls stand at
## both edges. drain() lowers it over a few seconds; once shallow the walls go and the floor is walkable.

@export var x0 := 0.0
@export var x1 := 100.0
@export var bottom := 320.0
@export var level := 270.0
@export var deep_limit := 304.0
var _target := level
var _walls: Array[CollisionShape2D] = []
var draining := false

func _ready() -> void:
	_target = level
	var sb := StaticBody2D.new()
	add_child(sb)
	for x in [x0, x1]:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(6, 60)
		cs.shape = r
		cs.position = Vector2(x, bottom - 30)
		sb.add_child(cs)
		_walls.append(cs)
	_apply()

func set_level(y: float, instant := false) -> void:
	_target = y
	if instant:
		level = y
		_apply()

func drain() -> void:
	draining = true
	_target = bottom + 4.0

func is_deep() -> bool:
	return level < deep_limit

func _apply() -> void:
	for w in _walls:
		w.set_deferred("disabled", not is_deep())

func _process(delta: float) -> void:
	if absf(level - _target) > 0.05:
		level = move_toward(level, _target, 10.0 * delta)
		_apply()
	else:
		draining = false
	queue_redraw()

func _draw() -> void:
	if level >= bottom:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var r := Rect2(x0, level, x1 - x0, bottom - level)
	draw_rect(r, Color(0.16, 0.34, 0.36, 0.78))
	draw_rect(Rect2(x0, level, x1 - x0, 2), Color(0.55, 0.78, 0.76, 0.85))
	for i in 10:
		var x := x0 + fmod(i * 73.0 + t * 18.0, x1 - x0)
		draw_rect(Rect2(x, level + 1, 8, 1), Color(0.8, 0.95, 0.95, 0.6))
	# A swirl at the drain while it runs.
	if draining:
		for i in 6:
			var a := t * 4.0 + i
			draw_rect(Rect2(x1 - 30 + cos(a) * 10.0, level + 4 + sin(a) * 3.0, 3, 1), Color(0.85, 0.95, 0.95, 0.8))
