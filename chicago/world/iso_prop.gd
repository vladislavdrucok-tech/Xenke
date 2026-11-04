extends Node2D
## TEMPORARY ART: small street props drawn with shapes. Origin = foot point. Lamps glow at night.

var kind := "lamp"
var lit := false

func blocks_movement() -> bool:
	return kind in ["lamp", "hydrant", "tree", "crates", "call_box"]

func collider_radius() -> float:
	return {"lamp": 7.0, "hydrant": 9.0, "tree": 14.0, "crates": 34.0, "call_box": 12.0}.get(kind, 8.0)

func set_lit(v: bool) -> void:
	if v != lit:
		lit = v
		queue_redraw()

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	match kind:
		"lamp":
			_ellipse(Vector2.ZERO, 8, 4, Color(0, 0, 0, 0.35))
			draw_rect(Rect2(-2, -92, 4, 92), Color("#2b2b2e"))
			draw_rect(Rect2(-7, -104, 14, 14), Color("#f6d68a") if lit else Color("#5a5a52"))
			if lit:
				_ellipse(Vector2(0, -97), 36, 30, Color(1.0, 0.85, 0.5, 0.16))
				_ellipse(Vector2(0, 0), 60, 30, Color(1.0, 0.85, 0.5, 0.10))
		"lamp_hanging":
			draw_line(Vector2(0, -150), Vector2(0, -118), Color("#222"), 1.0)
			_ellipse(Vector2(0, -112), 9, 6, Color("#f6d68a"))
			_ellipse(Vector2(0, -112), 40, 26, Color(1.0, 0.85, 0.5, 0.10))
		"hydrant":
			_ellipse(Vector2.ZERO, 9, 4, Color(0, 0, 0, 0.35))
			draw_rect(Rect2(-6, -22, 12, 22), Color("#9b2f24"))
			_ellipse(Vector2(0, -22), 7, 4, Color("#b8432f"))
		"tree":
			_ellipse(Vector2.ZERO, 22, 10, Color(0, 0, 0, 0.3))
			draw_rect(Rect2(-4, -46, 8, 46), Color("#4a3426"))
			_ellipse(Vector2(0, -70), 34, 30, Color("#3f5a32"))
			_ellipse(Vector2(-8, -80), 22, 18, Color("#4f6e3c"))
		"crates":
			for i in 3:
				var o := Vector2(-22 + i * 20, -i * 6)
				draw_colored_polygon(PackedVector2Array([o + Vector2(-16, -22), o + Vector2(16, -22), o + Vector2(16, 0), o + Vector2(-16, 0)]), Color("#7a5a36").darkened(i * 0.08))
				draw_rect(Rect2(o + Vector2(-16, -22), Vector2(32, 22)), Color("#4a3420"), false, 1.0)
		"call_box":
			_ellipse(Vector2.ZERO, 10, 5, Color(0, 0, 0, 0.35))
			draw_rect(Rect2(-3, -40, 6, 40), Color("#283a5c"))
			draw_rect(Rect2(-9, -64, 18, 26), Color("#2f4d7a"))
		"streetcar_stop":
			draw_rect(Rect2(-2, -70, 4, 70), Color("#3a3a3a"))
			draw_rect(Rect2(-14, -84, 28, 16), Color("#d8c27a"))
		_:
			_ellipse(Vector2.ZERO, 10, 5, Color(1, 0, 1))
