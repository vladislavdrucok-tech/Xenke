class_name IsoBlock
extends Node2D
## TEMPORARY ART: one 1x1-tile slice of a building / furniture prism, drawn with polygons until the art set arrives.
## A building is split into one slice per footprint cell so that y-sorting by the slice centre is right from every
## side (docs/TECH_ARCHITECTURE.md §Depth). Origin = the cell's ground centre; the parent y-sorts by it.
## A slice draws its roof, and its two visible walls only where the building ends (+x = right wall, +y = left wall).

var cell := Vector2i.ZERO
var height := 100.0
var wall := Color("#8b5a3c")
var roof := Color("#4a3a33")
var face_x := false        # +x edge is outside: draw the right-hand (SE-facing) wall
var face_y := false        # +y edge is outside: draw the left-hand (SW-facing) wall
var windows := 0           # windows on this slice's walls
var sign_key := ""         # a sign painted on this slice's left wall
var awning := Color(0, 0, 0, 0)
var is_lit := false        # windows glow at night
var building_id := ""
var fade := 1.0            # 1 opaque; lowered when it hides the player

func setup(c: Vector2i, h: float, wall_c: Color, roof_c: Color, fx: bool, fy: bool) -> void:
	cell = c
	height = h
	wall = wall_c
	roof = roof_c
	face_x = fx
	face_y = fy
	position = Iso.tile_center(c)
	queue_redraw()

func _local(g: Vector2, up: float = 0.0) -> Vector2:
	return Iso.to_screen(g) - position + Vector2(0, -up)

func _draw() -> void:
	var a := Vector2(cell)
	var top := a
	var right := a + Vector2(1, 0)
	var bottom := a + Vector2(1, 1)
	var left := a + Vector2(0, 1)
	var m := Color(1, 1, 1, fade)
	if face_x:
		# Right wall: the edge right -> bottom, lit less (light from the upper left).
		var pts := PackedVector2Array([_local(right, height), _local(bottom, height), _local(bottom), _local(right)])
		draw_colored_polygon(pts, wall.darkened(0.28) * m)
		_windows(right, bottom, wall.darkened(0.28))
	if face_y:
		var pts2 := PackedVector2Array([_local(left, height), _local(bottom, height), _local(bottom), _local(left)])
		draw_colored_polygon(pts2, wall * m)
		_windows(left, bottom, wall)
		if awning.a > 0.0:
			var h2 := minf(height * 0.42, 56.0)
			draw_colored_polygon(PackedVector2Array([_local(left, h2 + 14), _local(bottom, h2 + 14),
				_local(bottom + Vector2(0, 0.35), h2), _local(left + Vector2(0, 0.35), h2)]), awning * m)
	var roof_pts := PackedVector2Array([_local(top, height), _local(right, height), _local(bottom, height), _local(left, height)])
	draw_colored_polygon(roof_pts, roof * m)
	# A thin dark line where walls meet the roof keeps the volume readable.
	var edge := Color(0.08, 0.06, 0.05, 0.55 * fade)
	if face_x:
		draw_line(_local(right, height), _local(bottom, height), edge, 1.0)
		draw_line(_local(bottom, height), _local(bottom), edge, 1.0)
	if face_y:
		draw_line(_local(left, height), _local(bottom, height), edge, 1.0)

func _windows(from_g: Vector2, to_g: Vector2, base: Color) -> void:
	if windows <= 0 or height < 60.0:
		return
	var floors := int(height / 64.0)
	var glow := Color("#f2c46d") if is_lit else base.darkened(0.55)
	glow.a = fade
	for f in floors:
		var y0 := 30.0 + f * 64.0
		for w in windows:
			var t0 := (w + 0.3) / float(windows)
			var t1 := (w + 0.7) / float(windows)
			var p0 := from_g.lerp(to_g, t0)
			var p1 := from_g.lerp(to_g, t1)
			draw_colored_polygon(PackedVector2Array([_local(p0, y0 + 26), _local(p1, y0 + 26), _local(p1, y0), _local(p0, y0)]), glow)
