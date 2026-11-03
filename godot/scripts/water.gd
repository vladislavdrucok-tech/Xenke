extends Node2D
## Standing water between x0 and x1. While it is deep the hero cannot wade in: invisible walls stand at
## both edges. drain() lowers it over a few seconds; once shallow the walls go and the floor is walkable.

@export var x0 := 0.0
@export var x1 := 100.0
@export var bottom := 320.0
@export var level := 270.0
@export var deep_limit := 304.0
## How far the water reaches below the floor line (a street flood covers the kerb and the drain under it).
@export var depth_below := 0.0
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
	var y1 := bottom + depth_below
	var deep := clampf((y1 - level) / 60.0, 0.4, 1.0)
	var top_c := Color(0.22, 0.45, 0.47, 0.96)
	var low_c := Color(0.05, 0.13, 0.17, 0.98).lerp(top_c, 1.0 - deep)
	# Plain water: a solid body, lighter at the top, darker in the depth, with a gently moving surface.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var step := 8.0
	var x := x0
	var surf := PackedVector2Array()
	while true:
		var y := level + sin(x * 0.07 + t * 1.8) * 1.0 + sin(x * 0.023 - t * 0.9) * 0.8
		surf.append(Vector2(x, y))
		if x >= x1:
			break
		x = minf(x + step, x1)
	for p in surf:
		pts.append(p)
		cols.append(top_c)
	pts.append(Vector2(x1, y1))
	cols.append(low_c)
	pts.append(Vector2(x0, y1))
	cols.append(low_c)
	draw_polygon(pts, cols)
	# The bright line of the surface, and a darker band just under it.
	draw_polyline(surf, Color(0.72, 0.9, 0.88, 0.95), 1.5)
	var under := PackedVector2Array()
	for p in surf:
		under.append(p + Vector2(0, 3))
	draw_polyline(under, Color(0.12, 0.28, 0.31, 0.6), 2.0)
	# A few glints drifting with the current.
	for i in 8:
		var gx := x0 + fmod(i * 97.0 + t * 14.0, maxf(1.0, x1 - x0 - 12.0))
		var gy := level + 6.0 + float(i % 3) * 6.0
		if gy < y1 - 2.0:
			draw_rect(Rect2(gx, gy, 6.0 + float(i % 2) * 4.0, 1), Color(0.75, 0.92, 0.92, 0.35))
	# Foam where the water meets a wall or the shore.
	for ex in [x0, x1 - 4.0]:
		draw_rect(Rect2(ex, level - 1.0 + sin(t * 3.0 + ex) * 0.6, 4, 2), Color(0.88, 0.97, 0.96, 0.8))
	# A swirl at the drain while it runs.
	if draining:
		for i in 6:
			var a := t * 4.0 + i
			draw_rect(Rect2(x1 - 30 + cos(a) * 10.0, level + 4 + sin(a) * 3.0, 3, 1), Color(0.85, 0.95, 0.95, 0.8))
