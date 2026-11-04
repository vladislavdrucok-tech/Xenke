extends Node2D
## TEMPORARY ART: the district's ground drawn once from its tile types (canvas items cache the drawing, so this costs
## nothing per frame). Interiors also get their two back walls (the front ones are cut away so the room is visible).

var district: District

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var d := district
	var col: Dictionary = d.def.get("colors", {})
	var c_yard := Color(String(col.get("yard", col.get("ground", "#5b5a48"))))
	var c_floor := Color(String(col.get("ground", "#5b5a48")))
	var c_road := Color(String(col.get("road", "#3a3b3d")))
	var c_walk := Color(String(col.get("sidewalk", "#8a8478")))
	var c_rail := Color("#4a4038")
	var c_line := Color(String(col.get("road_line", "#8d8a6a")))
	for y in d.size.y:
		for x in d.size.x:
			var t := Vector2i(x, y)
			var k := d.tile(t)
			var c := c_floor
			match k:
				District.T.YARD: c = c_yard
				District.T.ROAD: c = c_road
				District.T.SIDEWALK: c = c_walk
				District.T.RAIL: c = c_rail
				District.T.BUILDING: c = c_floor.darkened(0.35)
			# A small deterministic variation per tile breaks up the flat look.
			var v := float((x * 73856093) ^ (y * 19349663)) / 2147483647.0
			c = c.lightened(fposmod(v, 1.0) * 0.05)
			draw_colored_polygon(Iso.rect_corners(Rect2(Vector2(t), Vector2.ONE)), c)
			if k == District.T.SIDEWALK:
				var e := Iso.rect_corners(Rect2(Vector2(t), Vector2.ONE))
				draw_polyline(PackedVector2Array([e[0], e[1], e[2], e[3], e[0]]), c.darkened(0.12), 1.0)
			if k == District.T.RAIL and x % 2 == 0:
				draw_line(Iso.to_screen(Vector2(x + 0.5, y)), Iso.to_screen(Vector2(x + 0.5, y + 1)), Color("#2a2420"), 4.0)
	# Dashed centre lines along roads (between the two lanes of each 2-tile road).
	for r in d.def.get("roads", []):
		var rr := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var along_x := rr.size.x >= rr.size.y
		var n := int(rr.size.x if along_x else rr.size.y)
		for i in n:
			if i % 2 == 1:
				continue
			var a: Vector2
			var b: Vector2
			if along_x:
				a = Vector2(rr.position.x + i + 0.2, rr.position.y + rr.size.y / 2.0)
				b = a + Vector2(0.6, 0)
			else:
				a = Vector2(rr.position.x + rr.size.x / 2.0, rr.position.y + i + 0.2)
				b = a + Vector2(0, 0.6)
			draw_line(Iso.to_screen(a), Iso.to_screen(b), c_line, 2.0)
	if d.is_interior:
		var h := float(d.def.get("wall_height", 150))
		var wl := Color(String(col.get("wall", "#8a7a60")))
		var wd := Color(String(col.get("wall_dark", "#6a5a44")))
		var o := Iso.to_screen(Vector2.ZERO)
		var r_end := Iso.to_screen(Vector2(d.size.x, 0))
		var l_end := Iso.to_screen(Vector2(0, d.size.y))
		draw_colored_polygon(PackedVector2Array([o + Vector2(0, -h), r_end + Vector2(0, -h), r_end, o]), wd)
		draw_colored_polygon(PackedVector2Array([o + Vector2(0, -h), l_end + Vector2(0, -h), l_end, o]), wl)
		draw_line(o + Vector2(0, -h), o, Color(0, 0, 0, 0.35), 2.0)
