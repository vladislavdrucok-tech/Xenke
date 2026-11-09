class_name Art
extends RefCounted
## Vehicles and people for the garage diorama.
## Two-wheelers are painted as side views and skewed onto the iso floor;
## cars are built from iso boxes so their faces take the lamp light.

const U := Vector2(0.894, 0.447)    # iso axis toward the back-right wall's right end
const V := Vector2(-0.894, 0.447)   # iso axis toward the viewer's left
const Z := Vector2(0, -1)


## Transform for a side-view drawing standing on the floor at `at`,
## running along iso axis `axis` (front of the vehicle toward +x local).
static func side_xf(at: Vector2, axis: Vector2, k := 1.0) -> Transform2D:
	return Transform2D(axis * k, Vector2(0, k), at)


# ------------------------------------------------------------------ moped

static func moped(ci: CanvasItem, at: Vector2, axis: Vector2, paint: Color, opts := {}) -> void:
	var k: float = opts.get("scale", 1.0)
	var on_stand: bool = opts.get("stand", false)
	var lift := -22.0 if on_stand else 0.0
	var light: bool = opts.get("light", false)
	var spin: float = opts.get("spin", 0.0)
	Paint.shadow(ci, at + Vector2(0, 4), 150 * k, 40 * k, 0.42)
	var x := side_xf(at, axis, k)
	ci.draw_set_transform_matrix(x)
	var rw := Vector2(-74, -34 + lift)
	var fw := Vector2(80, -34 + lift)
	if on_stand:
		_stand_back(ci, lift)
	_wheel(ci, rw, 34, spin)
	_wheel(ci, fw, 34, spin)
	# rear body over the engine, step-through frame, leg shield
	var dark := paint.darkened(0.25)
	Paint.fill(ci, Paint.capsule(Vector2(-60, -60 + lift), Vector2(40, -46 + lift), 9), Paint.METAL_DARK, 0.3)
	Paint.fill(ci, PackedVector2Array([Vector2(-128, -78 + lift), Vector2(-112, -116 + lift), Vector2(-20, -122 + lift), Vector2(-6, -96 + lift), Vector2(-30, -58 + lift), Vector2(-110, -54 + lift)]), paint, 0.3)
	Paint.strokes(ci, Rect2(-115, -116 + lift, 90, 50), paint.lightened(0.45), 41, 6, 12, 2)
	# engine
	Paint.fill(ci, Paint.rrect(Rect2(-60, -64 + lift, 46, 30), 8), Paint.METAL, 0.35)
	# seat
	Paint.fill(ci, Paint.rrect(Rect2(-104, -136 + lift, 88, 20), 9), Color("3b2f2a"), 0.3)
	# leg shield & front column
	Paint.fill(ci, PackedVector2Array([Vector2(36, -150 + lift), Vector2(62, -150 + lift), Vector2(58, -96 + lift), Vector2(40, -52 + lift), Vector2(8, -48 + lift), Vector2(24, -100 + lift)]), paint, 0.32)
	Paint.strokes(ci, Rect2(14, -140 + lift, 40, 80), paint.lightened(0.45), 43, 5, 10, 2)
	# floorboard
	Paint.fill(ci, Paint.rrect(Rect2(-20, -52 + lift, 54, 10), 4), Color("2f2d30"), 0.2)
	# fork & fender
	ci.draw_line(Vector2(56, -140 + lift), fw, Paint.STEEL, 6, true)
	Paint.fill(ci, Paint.arc_pts(fw, 42, PI * 1.05, PI * 1.85, 10) + Paint.arc_pts(fw, 36, PI * 1.85, PI * 1.05, 10), dark if opts.get("fender_loose", false) else paint, 0.3)
	# handlebar, mirror, headlight nacelle
	ci.draw_line(Vector2(40, -160 + lift), Vector2(70, -158 + lift), Paint.STEEL, 5, true)
	var mirror_drop: float = opts.get("mirror_drop", 0.0)
	var mb := Vector2(46, -162 + lift)
	var mt := mb + Vector2(-6, -30).rotated(mirror_drop)
	ci.draw_line(mb, mt, Paint.STEEL, 3, true)
	Paint.fill(ci, Paint.ellipse(mt + Vector2(0, -6).rotated(mirror_drop), 9, 12, 12, mirror_drop), Paint.CHROME, 0.35)
	Paint.fill(ci, Paint.ellipse(Vector2(66, -152 + lift), 22, 15, 18), paint, 0.3)
	var lc := Vector2(84, -152 + lift)
	ci.draw_circle(lc, 11, Paint.CHROME)
	ci.draw_circle(lc, 8, Color("fff3c8") if light else Color("495463"))
	# rear rack & tail lamp
	ci.draw_line(Vector2(-130, -112 + lift), Vector2(-96, -112 + lift), Paint.STEEL, 3, true)
	ci.draw_circle(Vector2(-130, -96 + lift), 5, Color("b33a2d"))
	# kickstand
	if not on_stand:
		ci.draw_line(Vector2(-30, -40), Vector2(-44, -2), Paint.METAL_DARK, 4, true)
	# scuffs on the green paint
	Paint.strokes(ci, Rect2(-120, -110 + lift, 170, 60), Color(0.95, 0.92, 0.8, 0.55), 47, 5, 6, 1.5)
	if on_stand:
		_stand_front(ci, lift)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if light:
		var lw := x * Vector2(96, -152 + lift)
		Paint.glow(ci, lw, 70 * k, Color(1, 0.9, 0.55, 0.55))


static func _stand_back(ci: CanvasItem, lift: float) -> void:
	Paint.fill(ci, Paint.rrect(Rect2(-150, -8, 280, 10), 4), Color("c79a2a"), 0.25)


static func _stand_front(ci: CanvasItem, lift: float) -> void:
	# yellow repair stand frame under the vehicle
	var c := Color("d9a62e")
	ci.draw_line(Vector2(-90, 0), Vector2(-74, -34 + lift), c.darkened(0.2), 7, true)
	ci.draw_line(Vector2(-58, 0), Vector2(-74, -34 + lift), c, 7, true)
	ci.draw_line(Vector2(70, 0), Vector2(80, -60 + lift), c, 7, true)
	ci.draw_line(Vector2(100, 0), Vector2(80, -60 + lift), c.darkened(0.2), 7, true)
	Paint.fill(ci, Paint.rrect(Rect2(-110, -6, 230, 10), 4), c, 0.3)


## The empty repair stand on the floor.
static func _stand_front_iso(ci: CanvasItem, at: Vector2, axis: Vector2) -> void:
	Paint.shadow(ci, at + Vector2(0, 4), 120, 30, 0.3)
	ci.draw_set_transform_matrix(side_xf(at, axis, 1.0))
	_stand_back(ci, -22.0)
	_stand_front(ci, -22.0)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _wheel(ci: CanvasItem, c: Vector2, r: float, spin := 0.0) -> void:
	Paint.fill(ci, Paint.circle(c, r, 26), Paint.RUBBER, 0.25)
	ci.draw_arc(c, r - 4, PI * 1.1, PI * 1.5, 10, Color(1, 1, 1, 0.12), 3, true)
	Paint.fill(ci, Paint.circle(c, r * 0.62, 22), Paint.STEEL, 0.35)
	ci.draw_circle(c, r * 0.22, Paint.METAL_DARK)
	for i in 6:
		var a := spin + TAU * i / 6.0
		ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.22, c + Vector2(cos(a), sin(a)) * r * 0.6, Color(0.35, 0.38, 0.44, 0.8), 2, true)


# ------------------------------------------------------------------ motorcycle

static func moto(ci: CanvasItem, at: Vector2, axis: Vector2, paint: Color, opts := {}) -> void:
	var k: float = opts.get("scale", 1.0)
	var on_stand: bool = opts.get("stand", false)
	var lift := -22.0 if on_stand else 0.0
	var light: bool = opts.get("light", false)
	Paint.shadow(ci, at + Vector2(0, 4), 170 * k, 44 * k, 0.42)
	var x := side_xf(at, axis, k)
	ci.draw_set_transform_matrix(x)
	var rw := Vector2(-88, -40 + lift)
	var fw := Vector2(92, -40 + lift)
	if on_stand:
		_stand_back(ci, lift)
	_wheel(ci, rw, 40)
	_wheel(ci, fw, 40)
	# frame
	ci.draw_line(rw, Vector2(-20, -110 + lift), Paint.METAL_DARK, 7, true)
	ci.draw_line(Vector2(-20, -110 + lift), Vector2(62, -130 + lift), Paint.METAL_DARK, 7, true)
	ci.draw_line(Vector2(62, -130 + lift), fw, Paint.STEEL, 7, true)
	# engine block and exhaust
	Paint.fill(ci, Paint.rrect(Rect2(-40, -96 + lift, 74, 52), 10), Paint.METAL, 0.4)
	for i in 4:
		ci.draw_line(Vector2(-32 + i * 16, -94 + lift), Vector2(-32 + i * 16, -50 + lift), Color(0, 0, 0, 0.2), 2, true)
	Paint.fill(ci, Paint.capsule(Vector2(10, -48 + lift), Vector2(-120, -58 + lift), 8), Paint.CHROME, 0.4)
	# tank
	Paint.fill(ci, PackedVector2Array([Vector2(-14, -118 + lift), Vector2(10, -142 + lift), Vector2(58, -138 + lift), Vector2(66, -118 + lift), Vector2(30, -104 + lift), Vector2(-10, -106 + lift)]), paint, 0.35)
	ci.draw_line(Vector2(6, -134 + lift), Vector2(48, -132 + lift), paint.lightened(0.5), 3, true)
	# seat
	Paint.fill(ci, Paint.rrect(Rect2(-100, -128 + lift, 92, 18), 8), Color("2a2523"), 0.25)
	# rear fender + top case
	Paint.fill(ci, Paint.arc_pts(rw, 48, PI * 1.1, PI * 1.8, 10) + Paint.arc_pts(rw, 42, PI * 1.8, PI * 1.1, 10), paint, 0.3)
	var case_open: bool = opts.get("case_open", false)
	Paint.fill(ci, Paint.rrect(Rect2(-150, -176 + lift, 70, 46), 10), Color("3b3d43"), 0.3)
	Paint.fill(ci, Paint.rrect(Rect2(-152, (-188 if case_open else -180) + lift, 74, 14), 6), Color("4a4d55"), 0.3)
	# headlight, turn signals, handlebar
	ci.draw_line(Vector2(54, -160 + lift), Vector2(84, -152 + lift), Paint.STEEL, 5, true)
	ci.draw_circle(Vector2(96, -128 + lift), 16, Paint.CHROME)
	ci.draw_circle(Vector2(97, -128 + lift), 12, Color("fff3c8") if light else Color("4a5564"))
	var turn_angle: float = opts.get("turn_angle", 0.0)
	var tp := Vector2(84, -114 + lift)
	ci.draw_line(Vector2(78, -116 + lift), tp, Paint.METAL_DARK, 3, true)
	Paint.fill(ci, Paint.ellipse(tp + Vector2(8, 0).rotated(turn_angle), 8, 6, 10, turn_angle), Paint.AMBER, 0.3)
	# kickstand
	if not on_stand:
		var ks: float = opts.get("kickstand", 0.0)
		ci.draw_line(Vector2(-16, -46), Vector2(-16, -46) + Vector2(-10, 44).rotated(ks), Paint.METAL_DARK, 4, true)
	if on_stand:
		_stand_front(ci, lift)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if light:
		Paint.glow(ci, x * Vector2(110, -128 + lift), 80 * k, Color(1, 0.9, 0.55, 0.5))


# ------------------------------------------------------------------ cars (iso boxes)

class Iso:
	var o := Vector2.ZERO
	var fwd := Art.V
	var side := Art.U
	var k := 70.0   # px per meter

	func p(x: float, y: float, z: float) -> Vector2:
		return o + fwd * x * k + side * y * k + Vector2(0, -z * k)


static func _face(ci: CanvasItem, pts: Array, col: Color, amount := 0.18) -> void:
	var pp := PackedVector2Array(pts)
	Paint.fill(ci, pp, col, amount)


static func car(ci: CanvasItem, at: Vector2, paint: Color, opts := {}) -> void:
	var wagon: bool = opts.get("wagon", false)
	var lifted: float = opts.get("lifted", 0.0)
	var light: bool = opts.get("light", false)
	var k: float = opts.get("k", 62.0)
	var iso := Iso.new()
	iso.o = at + Vector2(0, -lifted)
	iso.k = k
	Paint.shadow(ci, at + Vector2(0, 6), 3.0 * k, 1.5 * k, 0.45)
	var L := 2.05
	var Wd := 0.86
	var z0 := 0.32
	var z1 := 0.98
	var top := paint * Color(1.12, 1.1, 1.06)
	var front := paint * Color(0.96, 0.95, 0.94)
	var sidec := paint * Color(0.78, 0.8, 0.86)
	top.a = 1
	front.a = 1
	sidec.a = 1
	# hidden-side wheels peeking under the body
	for xw in [-1.3, 1.3]:
		_iso_wheel(ci, iso, xw, -Wd + 0.05, z0, 0.34, true)
	# lower body: right side (+side), front (+fwd), top
	_face(ci, [iso.p(-L, Wd, z0), iso.p(L, Wd, z0), iso.p(L, Wd, z1), iso.p(-L, Wd, z1)], sidec)
	_face(ci, [iso.p(L, -Wd, z0), iso.p(L, Wd, z0), iso.p(L, Wd, z1), iso.p(L, -Wd, z1)], front)
	_face(ci, [iso.p(-L, -Wd, z1), iso.p(L, -Wd, z1), iso.p(L, Wd, z1), iso.p(-L, Wd, z1)], top, 0.12)
	# bumpers
	_face(ci, [iso.p(L + 0.06, -Wd, z0 + 0.05), iso.p(L + 0.06, Wd, z0 + 0.05), iso.p(L + 0.06, Wd, z0 + 0.2), iso.p(L + 0.06, -Wd, z0 + 0.2)], Paint.CHROME, 0.3)
	# grille and headlights on the front face
	_face(ci, [iso.p(L, -0.4, 0.5), iso.p(L, 0.4, 0.5), iso.p(L, 0.4, 0.78), iso.p(L, -0.4, 0.78)], Color("2e3035"), 0.1)
	for yy in [-0.62, 0.62]:
		var hc := iso.p(L, yy, 0.66)
		Paint.fill(ci, Paint.ellipse(hc, 0.15 * k, 0.12 * k, 16), Paint.CHROME, 0.3)
		ci.draw_colored_polygon(Paint.ellipse(hc, 0.11 * k, 0.09 * k, 16), Color("fff3c8") if light else Color("56606e"))
		if light:
			Paint.glow(ci, hc, 0.6 * k, Color(1, 0.9, 0.55, 0.5))
	# side details: door seams, handle, sill
	ci.draw_line(iso.p(-0.2, Wd, z0 + 0.05), iso.p(-0.2, Wd, z1), Color(0, 0, 0, 0.25), 2, true)
	ci.draw_line(iso.p(0.95, Wd, z0 + 0.05), iso.p(0.95, Wd, z1), Color(0, 0, 0, 0.25), 2, true)
	ci.draw_line(iso.p(0.55, Wd, 0.86), iso.p(0.75, Wd, 0.86), Paint.CHROME, 3, true)
	Paint.strokes(ci, Rect2(iso.p(-L, Wd, z1) + Vector2(10, 5), Vector2(3.2 * k, 0.5 * k)), paint.lightened(0.4), 61, 6, 14, 2, 0.45)
	# cabin
	var cx0 := -1.1 if not wagon else -1.95
	var cx1 := 0.75
	var tx0 := -0.95 if not wagon else -1.95
	var tx1 := 0.2
	var cw := 0.78
	var z2 := 1.52
	var glass := Color("8fb1c4")
	if opts.get("streak", false):
		glass = Color("8aa6b4")
	# right side of cabin
	_face(ci, [iso.p(cx0, cw, z1), iso.p(cx1, cw, z1), iso.p(tx1, cw, z2), iso.p(tx0, cw, z2)], sidec)
	# side windows
	var win_gap: float = opts.get("window_gap", 0.0)
	_face(ci, [iso.p(cx0 + 0.12, cw, z1 + 0.08), iso.p(-0.15, cw, z1 + 0.08), iso.p(-0.15, cw, z2 - 0.06), iso.p(tx0 + 0.1, cw, z2 - 0.06)], glass * Color(0.85, 0.88, 0.95), 0.2)
	_face(ci, [iso.p(-0.05, cw, z1 + 0.08), iso.p(cx1 - 0.12, cw, z1 + 0.08), iso.p(tx1 - 0.04, cw, z2 - 0.06 - win_gap), iso.p(-0.05, cw, z2 - 0.06 - win_gap)], glass * Color(0.85, 0.88, 0.95), 0.2)
	# windshield (front slope) and roof
	_face(ci, [iso.p(cx1, -cw, z1), iso.p(cx1, cw, z1), iso.p(tx1, cw, z2), iso.p(tx1, -cw, z2)], glass, 0.25)
	if opts.get("streak", false):
		ci.draw_line(iso.p(cx1 - 0.15, -0.2, z1 + 0.15), iso.p(tx1 + 0.1, 0.1, z2 - 0.1), Color(0.55, 0.5, 0.42, 0.7), 6, true)
	ci.draw_line(iso.p(cx1 - 0.02, -0.5, z1 + 0.04), iso.p(cx1 - 0.25, -0.1, z1 + 0.28), Color("222326"), 3, true)
	ci.draw_line(iso.p(cx1 - 0.02, 0.2, z1 + 0.04), iso.p(cx1 - 0.25, 0.6, z1 + 0.28), Color("222326"), 3, true)
	_face(ci, [iso.p(tx0, -cw, z2), iso.p(tx1, -cw, z2), iso.p(tx1, cw, z2), iso.p(tx0, cw, z2)], top, 0.1)
	# reflections on the glass
	ci.draw_line(iso.p(cx1 - 0.1, 0.5, z1 + 0.1), iso.p(tx1 + 0.08, 0.2, z2 - 0.1), Color(1, 1, 1, 0.3), 4, true)
	# family in the wagon windows
	var faces: Array = opts.get("faces", [])
	for i in faces.size():
		var hp := iso.p(-0.5 - i * 0.55, cw, z1 + 0.25)
		ci.draw_circle(hp + Vector2(0, -8), 0.15 * k, Color(faces[i]))
		ci.draw_circle(hp + Vector2(-2, -18), 0.12 * k, Color("4a3324"))
	if wagon and opts.get("luggage", true):
		# roof rack with luggage for the trip
		var rk := [iso.p(tx0 + 0.2, -0.6, z2 + 0.06), iso.p(tx1 - 0.15, -0.6, z2 + 0.06), iso.p(tx1 - 0.15, 0.6, z2 + 0.06), iso.p(tx0 + 0.2, 0.6, z2 + 0.06)]
		ci.draw_polyline(PackedVector2Array(rk + [rk[0]]), Color("2f2f33"), 3, true)
		_box(ci, iso, -1.6, -0.1, -0.5, 0.45, z2 + 0.06, z2 + 0.4, Color("c9a15a"))
		_box(ci, iso, -0.8, -0.3, -0.4, 0.5, z2 + 0.06, z2 + 0.32, Color("5f7f9a"))
	# near-side wheels
	for xw in [-1.3, 1.3]:
		_iso_wheel(ci, iso, xw, Wd + 0.02, z0, 0.34, false)


static func _box(ci: CanvasItem, iso: Iso, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col: Color) -> void:
	_face(ci, [iso.p(x0, y1, z0), iso.p(x1, y1, z0), iso.p(x1, y1, z1), iso.p(x0, y1, z1)], col * Color(0.8, 0.82, 0.88))
	_face(ci, [iso.p(x1, y0, z0), iso.p(x1, y1, z0), iso.p(x1, y1, z1), iso.p(x1, y0, z1)], col * Color(0.95, 0.95, 0.95))
	_face(ci, [iso.p(x0, y0, z1), iso.p(x1, y0, z1), iso.p(x1, y1, z1), iso.p(x0, y1, z1)], col * Color(1.1, 1.08, 1.04), 0.1)


static func _iso_wheel(ci: CanvasItem, iso: Iso, x: float, y: float, zc: float, r: float, hidden: bool) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(iso.p(x + cos(a) * r, y, zc + sin(a) * r))
	ci.draw_colored_polygon(pts, Color("1f1e22") if hidden else Paint.RUBBER)
	if not hidden:
		var hub := PackedVector2Array()
		for i in 18:
			var a := TAU * i / 18.0
			hub.append(iso.p(x + cos(a) * r * 0.55, y + 0.01, zc + sin(a) * r * 0.55))
		Paint.fill(ci, hub, Paint.STEEL, 0.35)


# ------------------------------------------------------------------ people

static func person(ci: CanvasItem, feet: Vector2, look: Dictionary, t := 0.0, k := 1.0, wave := 0.0, facing := 1.0) -> void:
	var skin := Color(look.get("skin", "#e8b48f"))
	var hair := Color(look.get("hair", "#4a3324"))
	var jacket := Color(look.get("jacket", "#3f6f8f"))
	var pants := Color(look.get("pants", "#3b3f4a"))
	var bob := sin(t * 2.2) * 1.5
	Paint.shadow(ci, feet + Vector2(0, 2), 34 * k, 10 * k, 0.4)
	var x := Transform2D(Vector2(k * facing, 0), Vector2(0, k), feet)
	ci.draw_set_transform_matrix(x)
	# legs and shoes
	Paint.fill(ci, Paint.rrect(Rect2(-16, -66, 14, 64), 6), pants, 0.25)
	Paint.fill(ci, Paint.rrect(Rect2(2, -66, 14, 64), 6), pants.darkened(0.1), 0.25)
	ci.draw_colored_polygon(Paint.rrect(Rect2(-19, -8, 20, 9), 4), Color("2a2220"))
	ci.draw_colored_polygon(Paint.rrect(Rect2(0, -8, 22, 9), 4), Color("2a2220"))
	# body
	var body := PackedVector2Array([Vector2(-22, -66), Vector2(22, -66), Vector2(20, -124 + bob), Vector2(-20, -124 + bob)])
	Paint.fill(ci, Paint.rrect(Rect2(-23, -126 + bob, 46, 64), 12), jacket, 0.3)
	ci.draw_line(Vector2(0, -120 + bob), Vector2(0, -70), jacket.darkened(0.3), 2, true)
	if look.has("scarf"):
		Paint.fill(ci, Paint.rrect(Rect2(-16, -130 + bob, 32, 12), 6), Color(look["scarf"]), 0.2)
	# arms
	var sw := sin(t * 2.2) * 0.05
	Paint.fill(ci, Paint.capsule(Vector2(-21, -118 + bob), Vector2(-26, -76 + bob), 6).duplicate(), jacket.darkened(0.12), 0.25)
	if wave > 0.0:
		var a := -2.2 + sin(t * 9.0) * 0.35
		var hand := Vector2(21, -118 + bob) + Vector2(cos(a), sin(a)) * 40
		Paint.fill(ci, Paint.capsule(Vector2(21, -118 + bob), hand, 6), jacket.darkened(0.12), 0.25)
		ci.draw_circle(hand, 6, skin)
	else:
		Paint.fill(ci, Paint.capsule(Vector2(21, -118 + bob), Vector2(26 + sw * 40, -76 + bob), 6), jacket.darkened(0.12), 0.25)
		ci.draw_circle(Vector2(26, -74 + bob), 6, skin)
	ci.draw_circle(Vector2(-26, -74 + bob), 6, skin)
	# head
	var hc := Vector2(0, -146 + bob)
	ci.draw_colored_polygon(Paint.rrect(Rect2(-6, -134 + bob, 12, 10), 3), skin.darkened(0.1))
	if look.get("long_hair", false):
		Paint.fill(ci, Paint.rrect(Rect2(-19, -162 + bob, 38, 46), 16), hair, 0.25)
	Paint.fill(ci, Paint.circle(hc, 17, 20), skin, 0.25)
	ci.draw_circle(hc + Vector2(6, -2), 2.2, Color("2a2220"))
	ci.draw_circle(hc + Vector2(-5, -2), 2.2, Color("2a2220"))
	ci.draw_arc(hc + Vector2(1, 5), 6, 0.3, PI - 0.3, 8, Color("8a4a3a"), 2, true)
	ci.draw_circle(hc + Vector2(10, 5), 3.5, Color(0.95, 0.5, 0.45, 0.35))
	if look.get("beard", false):
		Paint.fill(ci, Paint.arc_pts(hc + Vector2(0, 2), 17, 0.15, PI - 0.15, 10), hair, 0.2)
	if look.get("moustache", false):
		ci.draw_line(hc + Vector2(-6, 4), hc + Vector2(8, 4), hair, 4, true)
	# hair / cap
	if look.has("cap"):
		var cap := Color(look["cap"])
		Paint.fill(ci, Paint.arc_pts(hc + Vector2(0, -4), 18, PI, TAU, 12), cap, 0.25)
		Paint.fill(ci, Paint.rrect(Rect2(4, -152 + bob, 22, 6), 3), cap.darkened(0.2), 0.2)
	else:
		Paint.fill(ci, Paint.arc_pts(hc + Vector2(0, -3), 18, PI * 0.95, TAU + 0.05, 12), hair, 0.25)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
