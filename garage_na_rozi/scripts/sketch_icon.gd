extends Control
## A job-board card: the pencil sketch of the repaired part (or a blank card).

var order_id := ""
var done := false


func _draw() -> void:
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_colored_polygon(Paint.rrect(r.grow(2), 8), Color(0, 0, 0, 0.15))
	draw_colored_polygon(Paint.rrect(r, 8), Color("f6eedb") if done else Color("d8ccb4"))
	if done:
		Sketch.icon(self, size * 0.5, order_id, minf(size.x, size.y) / 110.0, Color(0.25, 0.2, 0.18))
	else:
		Paint.text(self, Vector2(size.x * 0.5, size.y * 0.5 + 12), "?", 34, Color(0.45, 0.38, 0.3))
	draw_circle(Vector2(size.x * 0.5, 8), 4, Color("c7443a"))
