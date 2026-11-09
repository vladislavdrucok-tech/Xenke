class_name Sketch
extends RefCounted
## Pencil sketches of repaired parts for the job board (one per repair).


static func icon(ci: CanvasItem, c: Vector2, id: String, k := 1.0, col := Color(0.22, 0.18, 0.15)) -> void:
	var w := maxf(1.0, 4.0 * k)
	var x := Transform2D(Vector2(k, 0), Vector2(0, k), c)
	ci.draw_set_transform_matrix(x)
	var kind := id
	match id:
		"f_light":
			kind = "m_headlight"
		"f_wiper":
			kind = "c_wiper"
		"f_dash":
			kind = "c_dash"
	var lw := w / k
	match kind:
		"m_headlight":
			ci.draw_rect(Rect2(-40, -14, 30, 28), col, false, lw)
			ci.draw_rect(Rect2(-6, -12, 26, 24), col, false, lw)
			ci.draw_polyline(PackedVector2Array([Vector2(20, 0), Vector2(36, -6), Vector2(44, -26)]), col, lw, true)
			ci.draw_polyline(PackedVector2Array([Vector2(-40, 0), Vector2(-46, 18), Vector2(-40, 36)]), col, lw, true)
			ci.draw_line(Vector2(-10, -24), Vector2(-2, -32), col, lw * 0.7)
		"m_mirror":
			ci.draw_arc(Vector2(0, -22), 20, 0, TAU, 20, col, lw, true)
			ci.draw_line(Vector2(0, -2), Vector2(4, 30), col, lw)
			ci.draw_arc(Vector2(2, 12), 9, 0, TAU, 14, col, lw, true)
			ci.draw_arc(Vector2(2, 12), 15, -0.6, 1.4, 8, col, lw * 0.6, true)
		"m_speedo":
			ci.draw_arc(Vector2(0, -6), 30, PI, TAU, 18, col, lw, true)
			ci.draw_line(Vector2(0, -6), Vector2(18, -28), col, lw)
			ci.draw_polyline(Paint.bezier(Vector2(0, 0), Vector2(0, 20), Vector2(-30, 24), Vector2(-36, 40), 10), col, lw, true)
		"m_fender":
			ci.draw_arc(Vector2(0, 30), 42, PI * 1.1, PI * 1.9, 16, col, lw, true)
			ci.draw_rect(Rect2(-10, -24, 20, 14), col, false, lw)
			ci.draw_line(Vector2(10, -18), Vector2(28, -4), col, lw)
		"b_turn":
			ci.draw_arc(Vector2(-24, 0), 12, 0, TAU, 14, col, lw, true)
			ci.draw_line(Vector2(-12, -6), Vector2(30, -18), col, lw * 0.6)
			ci.draw_line(Vector2(-12, 6), Vector2(30, 18), col, lw * 0.6)
			ci.draw_line(Vector2(36, -8), Vector2(36, 8), col, lw)
			ci.draw_line(Vector2(28, 0), Vector2(44, 0), col, lw)
		"b_horn":
			ci.draw_arc(Vector2(0, -8), 22, 0, TAU, 18, col, lw, true)
			ci.draw_line(Vector2(-26, 24), Vector2(26, 24), col, lw)
			ci.draw_line(Vector2(-10, 14), Vector2(-10, 24), col, lw * 0.6)
			ci.draw_line(Vector2(10, 14), Vector2(10, 24), col, lw * 0.6)
		"b_kickstand":
			ci.draw_line(Vector2(-30, -30), Vector2(-10, 34), col, lw * 1.3)
			var pts := PackedVector2Array()
			for i in 13:
				pts.append(Vector2(-18 + i * 3.5, -10 + (6 if i % 2 == 0 else -6)))
			ci.draw_polyline(pts, col, lw * 0.7, true)
			ci.draw_circle(Vector2(30, -10), 4, col)
		"b_case":
			ci.draw_rect(Rect2(-34, -10, 68, 34), col, false, lw)
			ci.draw_line(Vector2(-36, -16), Vector2(36, -16), col, lw)
			ci.draw_arc(Vector2(0, -12), 9, PI, TAU, 10, col, lw, true)
			ci.draw_rect(Rect2(-8, 0, 16, 8), col, false, lw * 0.7)
		"c_wiper":
			ci.draw_line(Vector2(-38, 26), Vector2(30, -26), col, lw)
			ci.draw_line(Vector2(-30, 30), Vector2(38, -22), col, lw * 1.5)
			ci.draw_circle(Vector2(-38, 26), 4, col)
		"c_glovebox":
			ci.draw_rect(Rect2(-36, -18, 72, 36), col, false, lw)
			ci.draw_rect(Rect2(-4, -26, 18, 10), col, false, lw)
			ci.draw_line(Vector2(-20, -21), Vector2(-6, -21), col, lw * 0.6)
		"c_dash":
			ci.draw_arc(Vector2(0, -8), 18, 0, TAU, 18, col, lw, true)
			ci.draw_rect(Rect2(-9, 10, 18, 14), col, false, lw)
			for i in 3:
				var a := -PI / 2 + (i - 1) * 0.7
				ci.draw_line(Vector2(cos(a), sin(a)) * 24 + Vector2(0, -8), Vector2(cos(a), sin(a)) * 32 + Vector2(0, -8), col, lw * 0.6)
		"c_window":
			ci.draw_polyline(PackedVector2Array([Vector2(-36, 28), Vector2(-36, -10), Vector2(-10, -30), Vector2(36, -30), Vector2(36, 28)]), col, lw, true)
			ci.draw_polyline(PackedVector2Array([Vector2(-30, -8), Vector2(-8, -24), Vector2(30, -24)]), col, lw * 0.6, true)
		_:
			ci.draw_circle(Vector2.ZERO, 20, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
