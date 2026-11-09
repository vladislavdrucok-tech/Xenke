extends Node2D
## Icon picture: the garage gate under its enamel sign, warm lamp light,
## and the old green moped in front. Drawn in a 512x512 frame.

var mode := "full"   # full | fg | bg


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _draw() -> void:
	if mode != "fg":
		_back()
	if mode != "bg":
		_front()


func _back() -> void:
	var r := Rect2(0, 0, 512, 512)
	draw_polygon(Paint.rect(r), PackedColorArray([Color("3f342c"), Color("3a3029"), Color("231d19"), Color("2a221d")]))
	# plaster wall with the gate
	var wall := PackedVector2Array([Vector2(0, 60), Vector2(512, 60), Vector2(512, 400), Vector2(0, 400)])
	Paint.fill(self, wall, Color("cdb795"), 0.25, 0.2)
	Paint.strokes(self, Rect2(0, 60, 512, 300), Color(1, 0.97, 0.88, 0.35), 3, 30, 40, 4, 0.1)
	Paint.glow(self, Vector2(120, 110), 220, Color(1, 0.82, 0.45, 0.45))
	# floor
	draw_polygon(PackedVector2Array([Vector2(0, 400), Vector2(512, 400), Vector2(512, 512), Vector2(0, 512)]), PackedColorArray([Color("8f887c"), Color("857e72"), Color("5f5a52"), Color("6a645b")]))


func _front() -> void:
	var s := 1.0 if mode == "full" else 0.78
	var c := Vector2(256, 256)
	draw_set_transform(c - c * s, 0.0, Vector2(s, s))
	# gate
	var g := Rect2(120, 180, 272, 220)
	Paint.fill(self, Paint.rect(g), Color("4e6b7c"), 0.25)
	for i in 12:
		var y := g.position.y + 10 + i * 18
		draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), Color("3b5261"), 3, true)
		draw_line(Vector2(g.position.x, y + 3), Vector2(g.end.x, y + 3), Color("6f8d9d"), 1.5, true)
	draw_rect(Rect2(110, 170, 292, 12), Color("3a3634"))
	draw_rect(Rect2(110, 170, 12, 230), Color("3a3634"))
	draw_rect(Rect2(390, 170, 12, 230), Color("3a3634"))
	# enamel sign
	var sr := Rect2(86, 70, 340, 86)
	Paint.shadow(self, sr.get_center() + Vector2(6, 46), 170, 24, 0.35)
	draw_colored_polygon(Paint.rrect(sr, 14), Color("f2ead7"))
	draw_colored_polygon(Paint.rrect(sr.grow(-8), 10), Color("23466e"))
	Paint.outline(self, Paint.rrect(sr.grow(-14), 8), Color("f2ead7"), 3)
	Paint.fonts()
	draw_string(Paint.font_hand, Vector2(sr.position.x, sr.position.y + 60), "Гараж на розі", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 46, Color("f2ead7"))
	# moped in front (side view)
	var mx := Transform2D(Vector2(1.55, 0), Vector2(0, 1.55), Vector2(250, 470))
	draw_set_transform_matrix(Transform2D(Vector2(s, 0), Vector2(0, s), c - c * s) * mx)
	Paint.shadow(self, Vector2(0, 4), 150, 22, 0.5)
	_wheel(Vector2(-74, -34))
	_wheel(Vector2(80, -34))
	var paint := Color("5f8f4e")
	draw_line(Vector2(-60, -60), Vector2(40, -46), Paint.METAL_DARK, 16, true)
	Paint.fill(self, PackedVector2Array([Vector2(-128, -78), Vector2(-112, -116), Vector2(-20, -122), Vector2(-6, -96), Vector2(-30, -58), Vector2(-110, -54)]), paint, 0.3)
	Paint.fill(self, Paint.rrect(Rect2(-104, -136, 88, 20), 9), Color("3b2f2a"), 0.3)
	Paint.fill(self, PackedVector2Array([Vector2(36, -150), Vector2(62, -150), Vector2(58, -96), Vector2(40, -52), Vector2(8, -48), Vector2(24, -100)]), paint, 0.32)
	draw_line(Vector2(56, -140), Vector2(80, -34), Paint.STEEL, 6, true)
	Paint.fill(self, Paint.arc_pts(Vector2(80, -34), 42, PI * 1.05, PI * 1.85, 10) + Paint.arc_pts(Vector2(80, -34), 36, PI * 1.85, PI * 1.05, 10), paint, 0.3)
	draw_line(Vector2(40, -160), Vector2(70, -158), Paint.STEEL, 5, true)
	Paint.fill(self, Paint.ellipse(Vector2(66, -152), 22, 15, 18), paint, 0.3)
	draw_circle(Vector2(84, -152), 11, Paint.CHROME)
	draw_circle(Vector2(84, -152), 8, Color("fff3c8"))
	Paint.glow(self, Vector2(96, -152), 50, Color(1, 0.9, 0.55, 0.7))
	Paint.strokes(self, Rect2(-120, -110, 170, 60), Color(0.95, 0.92, 0.8, 0.5), 47, 5, 6, 1.5)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _wheel(c: Vector2) -> void:
	Paint.fill(self, Paint.circle(c, 34, 26), Paint.RUBBER, 0.25)
	Paint.fill(self, Paint.circle(c, 21, 22), Paint.STEEL, 0.35)
	draw_circle(c, 7, Paint.METAL_DARK)
