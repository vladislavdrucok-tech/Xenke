class_name Figure
extends Node2D
## TEMPORARY ART: a code-drawn 1940s figure (hat, coat, legs) that faces 8 ways and steps while walking.
## Replaced by animated sprite sheets (docs/ART_SPEC.md, tickets C1-C3). Origin = the point between the feet.

var coat := Color("#6b4a2f")
var hat := Color("#2e2620")
var skin := Color("#d9b08c")
var facing := "S"
var walking := false
var phase := 0.0
var height := 112.0
var hurt_t := 0.0

func _process(delta: float) -> void:
	if walking:
		phase += delta * 9.0
		queue_redraw()
	elif phase != 0.0:
		phase = 0.0
		queue_redraw()
	if hurt_t > 0.0:
		hurt_t -= delta
		queue_redraw()

func set_facing(f: String) -> void:
	if f != facing:
		facing = f
		queue_redraw()

func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	var s := height / 112.0
	_ell(Vector2.ZERO, 18 * s, 8 * s, Color(0, 0, 0, 0.32))
	var step := sin(phase) * 5.0 * s if walking else 0.0
	var bob := absf(sin(phase)) * 2.0 * s if walking else 0.0
	var dx := {"E": 1.0, "W": -1.0, "NE": 0.7, "SE": 0.7, "NW": -0.7, "SW": -0.7}.get(facing, 0.0) as float
	var back := facing in ["N", "NE", "NW"]
	var trousers := coat.darkened(0.45)
	# Legs
	draw_rect(Rect2(Vector2(-8 * s + step * dx * 0.3, -44 * s), Vector2(7 * s, 44 * s - absf(step) * 0.3)), trousers)
	draw_rect(Rect2(Vector2(1 * s - step * dx * 0.3, -44 * s), Vector2(7 * s, 44 * s - absf(step) * 0.3)), trousers)
	# Coat (body)
	var tint := Color(1, 0.6, 0.6) if hurt_t > 0.0 else Color.WHITE
	draw_colored_polygon(PackedVector2Array([Vector2(-14 * s, -88 * s - bob), Vector2(14 * s, -88 * s - bob),
		Vector2(16 * s, -40 * s), Vector2(-16 * s, -40 * s)]), coat * tint)
	# Arms swing opposite to the legs
	draw_rect(Rect2(Vector2(-19 * s, -86 * s - bob + step * 0.4), Vector2(5 * s, 34 * s)), coat.darkened(0.15))
	draw_rect(Rect2(Vector2(14 * s, -86 * s - bob - step * 0.4), Vector2(5 * s, 34 * s)), coat.darkened(0.15))
	# Head + hat
	_ell(Vector2(dx * 2 * s, -98 * s - bob), 9 * s, 10 * s, skin.darkened(0.25) if back else skin)
	_ell(Vector2(dx * 2 * s, -106 * s - bob), 15 * s, 4 * s, hat)
	draw_rect(Rect2(Vector2(-8 * s + dx * 2 * s, -116 * s - bob), Vector2(16 * s, 10 * s)), hat)
	# Facing cue: a lighter collar on the front side
	if not back:
		draw_colored_polygon(PackedVector2Array([Vector2(-5 * s + dx * 4 * s, -88 * s - bob), Vector2(5 * s + dx * 4 * s, -88 * s - bob),
			Vector2(dx * 4 * s, -78 * s - bob)]), Color("#e8dcc4"))
