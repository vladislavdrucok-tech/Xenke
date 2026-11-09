extends Node2D
## The garage diorama in isometric 2D: fixed camera, warm lamp over the
## workbench, the moped in front, the car corner on the right. Everything the
## career changes (stand, lift, photo, sketches, sign, decor) is drawn here.

const DrawProxy := preload("res://scripts/draw_proxy.gd")
const T := Vector2(360, 400)
const R := Vector2(860, 650)
const L := Vector2(-140, 650)
const HW := 330.0
const GATE_U := Vector2(0.44, 0.72)
const GATE_H := 236.0
const BAY := Vector2(0.58, 0.34)          # car centre (u, v)
const SPOT := Vector2(0.62, 0.8)         # two-wheeler spot without the stand
const STAND := Vector2(0.27, 0.62)        # stand spot near the workbench

var back: Node2D
var gate_n: Node2D
var equip: Node2D
var veh: Node2D
var ppl: Node2D
var front: Node2D

var t := 0.0
var gate_open := 0.0          # 0 closed .. 1 open
var vehicle := ""             # moped | moto | car | wagon | ""
var veh_uv := Vector2(1.6, 0.76)
var veh_paint := Color("5f8f4e")
var veh_opts: Dictionary = {}
var veh_facing := -1.0        # two-wheelers: -1 front toward -u
var client_look: Dictionary = {}
var client_uv := Vector2(1.7, 0.86)
var client_alpha := 1.0
var client_wave := 0.0
var friend_look: Dictionary = {}
var friend_uv := Vector2(-1, -1)
var zones: Dictionary = {}    # id -> Vector2 (local) of tap zones on the vehicle
var pulse := ""               # zone id highlighted for the first tap
var pulse_ids: Array = []
var sign_drop := 1.0          # 0..1 animation of the sign hanging
var dust: Array = []


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	back = _proxy(_draw_static)
	back.show_behind_parent = true
	gate_n = _proxy(_draw_gate)
	equip = _proxy(_draw_equip)
	veh = _proxy(_draw_vehicle)
	ppl = _proxy(_draw_people)
	front = _proxy(_draw_front)
	for i in 26:
		dust.append(Vector2(Paint.h(i, 3), Paint.h(i, 8)))
	Game.changed.connect(refresh)


func _proxy(c: Callable) -> Node2D:
	var n := DrawProxy.new()
	n.painter = c
	n.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(n)
	return n


func refresh() -> void:
	back.queue_redraw()


func g(u: float, v: float, z := 0.0) -> Vector2:
	return T + (R - T) * u + (L - T) * v + Vector2(0, -z)


func _process(delta: float) -> void:
	t += delta
	gate_n.queue_redraw()
	equip.queue_redraw()
	veh.queue_redraw()
	ppl.queue_redraw()
	front.queue_redraw()
	queue_redraw()


func _draw() -> void:
	# lamp light and floating dust over the static layer (behind objects)
	var lamp := g(0.17, 0.48, 250)
	var flick := 0.96 + 0.04 * sin(t * 7.0) * sin(t * 2.3)
	Paint.glow_e(self, g(0.16, 0.48, 0) + Vector2(0, -10), 300, 150, Color(1.0, 0.82, 0.45, 0.26 * flick))
	for i in dust.size():
		var d: Vector2 = dust[i]
		var p := lamp + Vector2((d.x - 0.5) * 220.0 + sin(t * 0.3 + i) * 10.0, d.y * 220.0 + fmod(t * 6.0 + i * 13.0, 40.0))
		draw_circle(p, 1.4, Color(1, 0.92, 0.7, 0.25))


# ------------------------------------------------------------------ static

func _draw_static(ci: CanvasItem) -> void:
	var top := Vector2(0, -HW)
	# walls
	var lw := PackedVector2Array([T, L, L + top, T + top])
	var rw := PackedVector2Array([T, R, R + top, T + top])
	Paint.fill(ci, lw, Color("d2bf9c"), 0.2, 0.46)
	Paint.fill(ci, rw, Color("bfae92"), 0.2, -0.46)
	# painted lower band (wainscot)
	var band := 105.0
	Paint.fill(ci, PackedVector2Array([T, L, L + Vector2(0, -band), T + Vector2(0, -band)]), Color("6f8b7c"), 0.2, 0.46)
	Paint.fill(ci, PackedVector2Array([T, R, R + Vector2(0, -band), T + Vector2(0, -band)]), Color("627d70"), 0.2, -0.46)
	ci.draw_line(T + Vector2(0, -band), L + Vector2(0, -band), Color("4f665a"), 3, true)
	ci.draw_line(T + Vector2(0, -band), R + Vector2(0, -band), Color("4a5f55"), 3, true)
	# dry-brush texture on plaster
	Paint.strokes(ci, Rect2(-100, 100, 450, 360), Color(1, 0.97, 0.88, 0.35), 5, 40, 40, 3, 0.46)
	Paint.strokes(ci, Rect2(370, 100, 400, 360), Color(1, 0.97, 0.88, 0.25), 6, 40, 40, 3, -0.46)
	# exposed bricks
	for j in 3:
		for i in 4 - j:
			var a := g(0.86 - j * 0.03 + i * 0.05, 0, 250 - j * 16)
			ci.draw_colored_polygon(PackedVector2Array([a, a + Vector2(22, 11), a + Vector2(22, 24), a + Vector2(0, 13)]), Color("a7604a").lerp(Color("8c4c3b"), Paint.h(i + j * 4, 2)))
	# corner shadow line and ceiling edge
	ci.draw_line(T, T + top, Color(0.2, 0.17, 0.15, 0.35), 4, true)
	ci.draw_line(L + top, T + top, Color("5b4a3c"), 6, true)
	ci.draw_line(T + top, R + top, Color("5b4a3c"), 6, true)
	# floor
	var fl := PackedVector2Array([T, R, Vector2(360, 900), L])
	ci.draw_polygon(fl, PackedColorArray([Color("a39d90"), Color("8a857a"), Color("77736b"), Color("958f82")]), Paint.uvs(fl, 0.46, 260, 30), Paint.stroke_tex())
	for i in range(1, 5):
		ci.draw_line(g(i / 5.0, 0), g(i / 5.0, 1), Color(0, 0, 0, 0.07), 2, true)
		ci.draw_line(g(0, i / 5.0), g(1, i / 5.0), Color(0, 0, 0, 0.07), 2, true)
	# oil stains
	Paint.shadow(ci, g(0.6, 0.38), 90, 36, 0.22)
	Paint.shadow(ci, g(0.3, 0.7), 40, 16, 0.15)
	# window with daylight
	_window(ci)
	# floor patch of daylight
	ci.draw_colored_polygon(PackedVector2Array([g(0.07, 0.02), g(0.24, 0.02), g(0.3, 0.32), g(0.12, 0.32)]), Color(0.85, 0.92, 1.0, 0.08))
	_workbench(ci)
	_board(ci)
	if Game.state.get("photo", false):
		_photo(ci)
	_shelf(ci)
	if Game.owns("decor_cabinet"):
		_cabinet(ci)


func _window(ci: CanvasItem) -> void:
	var a := g(0.07, 0, 140)
	var b := g(0.25, 0, 140)
	var c := g(0.25, 0, 265)
	var d := g(0.07, 0, 265)
	ci.draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color("cfe0ea"))
	ci.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, -45), a + Vector2(0, -45)]), Color("9fbf8a"))
	Paint.glow(ci, (a + c) * 0.5, 80, Color(1, 1, 1, 0.25))
	ci.draw_polyline(PackedVector2Array([a, b, c, d, a]), Color("e9e1d0"), 7, true)
	ci.draw_line((a + b) * 0.5, (c + d) * 0.5, Color("e9e1d0"), 5, true)
	ci.draw_line((a + d) * 0.5, (b + c) * 0.5, Color("e9e1d0"), 5, true)
	ci.draw_line(a + Vector2(0, 6), b + Vector2(0, 6), Color("7a6a58"), 5, true)


func _workbench(ci: CanvasItem) -> void:
	var v0 := 0.30
	var v1 := 0.66
	var dep := 0.12
	var hgt := 92.0
	# pegboard and tools on the wall above
	var pa := g(0, v0 + 0.02, 140)
	var pb := g(0, v1 - 0.02, 140)
	var pts := PackedVector2Array([pa, pb, pb + Vector2(0, -120), pa + Vector2(0, -120)])
	Paint.fill(ci, pts, Color("b08d5e"), 0.15, 0.46)
	for i in 9:
		for j in 4:
			var p := g(0, v0 + 0.04 + i * 0.035, 152 + j * 28)
			ci.draw_circle(p, 1.6, Color(0.25, 0.18, 0.1, 0.5))
	_tool_wrench(ci, g(0, v0 + 0.08, 230), 46)
	_tool_wrench(ci, g(0, v0 + 0.12, 224), 38)
	_tool_hammer(ci, g(0, v0 + 0.19, 238))
	_tool_screwdriver(ci, g(0, v0 + 0.26, 236), Color("c7443a"))
	_tool_screwdriver(ci, g(0, v0 + 0.29, 236), Color("e2b13c"))
	ci.draw_arc(g(0, v0 + 0.31, 205), 16, 0, TAU, 20, Color("2f2f33"), 5, true)
	# the bench: top, front face, legs
	var fa := g(dep, v0, 0)
	var fb := g(dep, v1, 0)
	Paint.shadow(ci, g(dep + 0.03, (v0 + v1) * 0.5), 210, 50, 0.35)
	for vv in [v0 + 0.02, v1 - 0.02]:
		ci.draw_line(g(dep - 0.01, vv, 0), g(dep - 0.01, vv, hgt - 10), Paint.WOOD_DARK, 9, true)
	var front := PackedVector2Array([g(dep, v0, hgt - 30), g(dep, v1, hgt - 30), g(dep, v1, hgt), g(dep, v0, hgt)])
	Paint.fill(ci, front, Paint.WOOD.darkened(0.12), 0.2, 0.46)
	var topp := PackedVector2Array([g(0, v0, hgt), g(0, v1, hgt), g(dep, v1, hgt), g(dep, v0, hgt)])
	Paint.fill(ci, topp, Color("b98756"), 0.18, 0.46)
	for i in 3:
		ci.draw_line(g(0.02 + i * 0.035, v0, hgt), g(0.02 + i * 0.035, v1, hgt), Color(0.35, 0.22, 0.12, 0.25), 2, true)
	# drawers
	for i in 2:
		var dv := v0 + 0.06 + i * 0.16
		var d0 := g(dep, dv, hgt - 26)
		var d1 := g(dep, dv + 0.1, hgt - 26)
		ci.draw_colored_polygon(PackedVector2Array([d0, d1, d1 + Vector2(0, 20), d0 + Vector2(0, 20)]), Paint.WOOD.darkened(0.25))
		ci.draw_line((d0 + d1) * 0.5 + Vector2(-6, 10), (d0 + d1) * 0.5 + Vector2(6, 10), Paint.CHROME, 3, true)
	# vice, radio, mug
	var vb := g(0.06, v0 + 0.07, hgt)
	Paint.fill(ci, Paint.rrect(Rect2(vb + Vector2(-16, -24), Vector2(32, 24)), 4), Color("4f6b8a"), 0.3)
	ci.draw_line(vb + Vector2(-20, -12), vb + Vector2(-40, -6), Paint.STEEL, 3, true)
	var rb := g(0.04, v1 - 0.08, hgt)
	Paint.fill(ci, Paint.rrect(Rect2(rb + Vector2(-26, -30), Vector2(52, 30)), 6), Color("8c3f33"), 0.3)
	ci.draw_circle(rb + Vector2(-10, -15), 8, Color("d8cdb5"))
	ci.draw_line(rb + Vector2(8, -22), rb + Vector2(18, -22), Color("d8cdb5"), 3)
	ci.draw_line(rb + Vector2(14, -30), rb + Vector2(26, -52), Paint.STEEL, 2, true)
	var mg := g(0.08, v0 + 0.2, hgt)
	ci.draw_colored_polygon(Paint.rrect(Rect2(mg + Vector2(-8, -18), Vector2(16, 18)), 3), Color("e6dfcf"))
	ci.draw_arc(mg + Vector2(9, -9), 5, -PI / 2, PI / 2, 8, Color("e6dfcf"), 3)
	# the lamp above the bench: cord, enamel shade, bulb
	var lp := g(0.17, 0.48, 250)
	ci.draw_line(g(0.17, 0.48, HW + 20) + Vector2(0, 0), lp, Color("2b2522"), 2, true)
	var shade := PackedVector2Array([lp + Vector2(-10, 0), lp + Vector2(10, 0), lp + Vector2(36, 34), lp + Vector2(-36, 34)])
	Paint.fill(ci, shade, Color("3f5e4c"), 0.35)
	ci.draw_colored_polygon(Paint.ellipse(lp + Vector2(0, 34), 36, 8, 18), Color("f8e3a8"))
	Paint.glow(ci, lp + Vector2(0, 40), 70, Color(1, 0.9, 0.6, 0.6))


func _tool_wrench(ci: CanvasItem, p: Vector2, ln: float) -> void:
	ci.draw_line(p, p + Vector2(-ln * 0.45, ln * 0.85), Paint.STEEL, 6, true)
	ci.draw_arc(p, 8, 0, TAU, 12, Paint.STEEL, 4, true)


func _tool_hammer(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_line(p, p + Vector2(-18, 52), Paint.WOOD, 6, true)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -10), p + Vector2(18, 4), p + Vector2(14, 14), p + Vector2(-20, 0)]), Paint.METAL_DARK)


func _tool_screwdriver(ci: CanvasItem, p: Vector2, c: Color) -> void:
	ci.draw_line(p, p + Vector2(-6, 22), c, 8, true)
	ci.draw_line(p + Vector2(-6, 22), p + Vector2(-12, 50), Paint.STEEL, 3, true)


func _board(ci: CanvasItem) -> void:
	# cork board with sketches of repaired parts
	var a := g(0, 0.05, 150)
	var b := g(0, 0.26, 150)
	var pts := PackedVector2Array([a, b, b + Vector2(0, -130), a + Vector2(0, -130)])
	Paint.shadow(ci, (a + b) * 0.5 + Vector2(6, -60), 130, 80, 0.25)
	Paint.fill(ci, pts, Color("b88a59"), 0.2, 0.46)
	ci.draw_polyline(PackedVector2Array([a, b, b + Vector2(0, -130), a + Vector2(0, -130), a]), Color("6b4a2c"), 5, true)
	Paint.text(ci, (a + b) * 0.5 + Vector2(0, -102), "ДОШКА РОБІТ", 14, Color(0.25, 0.16, 0.08, 0.8))
	var ids: Array = Game.order_ids + Game.FINAL
	var n := 0
	for id in ids:
		if not Game.is_done(id):
			continue
		var col := n % 5
		var row := n / 5
		var cpos := g(0, 0.065 + col * 0.04, 132 - row * 30)
		var card := PackedVector2Array([cpos, cpos + Vector2(-18, 9), cpos + Vector2(-18, -14), cpos + Vector2(0, -23)])
		ci.draw_colored_polygon(card, Color("f3ead6") if id.begins_with("f_") == false else Color("f6dcc8"))
		Sketch.icon(ci, cpos + Vector2(-9, -7), id, 0.24, Color(0.25, 0.2, 0.18, 0.85))
		ci.draw_circle(cpos + Vector2(-9, -19), 2.2, Color("c7443a"))
		n += 1


func _photo(ci: CanvasItem) -> void:
	var a := g(0.31, 0, 170)
	var b := g(0.4, 0, 170)
	var pts := PackedVector2Array([a, b, b + Vector2(0, -66), a + Vector2(0, -66)])
	Paint.shadow(ci, (a + b) * 0.5 + Vector2(4, -30), 50, 40, 0.3)
	ci.draw_colored_polygon(pts, Color("6b4a2c"))
	var inner := PackedVector2Array([a + Vector2(5, -6), b + Vector2(-4, -4), b + Vector2(-4, -60), a + Vector2(5, -62)])
	ci.draw_colored_polygon(inner, Color("e8d9b5"))
	# two little figures and a moped in the photo
	var c := (a + b) * 0.5 + Vector2(0, -26)
	ci.draw_circle(c + Vector2(-10, -14), 5, Color("e8b48f"))
	ci.draw_colored_polygon(Paint.rrect(Rect2(c + Vector2(-15, -9), Vector2(10, 18)), 3), Color("3f6f8f"))
	ci.draw_circle(c + Vector2(8, -18), 5, Color("c98e68"))
	ci.draw_colored_polygon(Paint.rrect(Rect2(c + Vector2(3, -13), Vector2(10, 20)), 3), Color("2f2f33"))
	ci.draw_circle(c + Vector2(-14, 14), 5, Color("2c2b30"))
	ci.draw_circle(c + Vector2(14, 10), 5, Color("2c2b30"))
	ci.draw_line(c + Vector2(-14, 12), c + Vector2(14, 8), Color("5f8f4e"), 4)


func _shelf(ci: CanvasItem) -> void:
	# tires stacked in the back corner
	for i in 3:
		var c := g(0.05, 0.045, 14 + i * 22)
		Paint.fill(ci, Paint.ellipse(c, 34, 15, 20), Paint.RUBBER, 0.25)
		ci.draw_colored_polygon(Paint.ellipse(c + Vector2(0, -4), 15, 6, 14), Color("4a4850"))


func _cabinet(ci: CanvasItem) -> void:
	# red tool cabinet against the right wall (decor)
	var u0 := 0.18
	var u1 := 0.30
	var d := 0.08
	var hh := 130.0
	Paint.shadow(ci, g((u0 + u1) * 0.5, d + 0.03), 80, 26, 0.35)
	var col := Color("b23b2e")
	Paint.fill(ci, PackedVector2Array([g(u0, d, 0), g(u1, d, 0), g(u1, d, hh), g(u0, d, hh)]), col, 0.2, -0.46)
	Paint.fill(ci, PackedVector2Array([g(u1, 0, 0), g(u1, d, 0), g(u1, d, hh), g(u1, 0, hh)]), col.darkened(0.3), 0.2)
	Paint.fill(ci, PackedVector2Array([g(u0, 0, hh), g(u1, 0, hh), g(u1, d, hh), g(u0, d, hh)]), col.lightened(0.15), 0.15)
	for i in 5:
		var z := 18.0 + i * 22.0
		ci.draw_line(g(u0 + 0.01, d, z), g(u1 - 0.01, d, z), col.darkened(0.4), 2, true)
		ci.draw_line(g((u0 + u1) * 0.5 - 0.015, d, z + 10), g((u0 + u1) * 0.5 + 0.015, d, z + 10), Paint.CHROME, 3, true)


# ------------------------------------------------------------------ gate

func _draw_gate(ci: CanvasItem) -> void:
	var u0 := GATE_U.x
	var u1 := GATE_U.y
	var a := g(u0, 0, 0)
	var b := g(u1, 0, 0)
	var top := Vector2(0, -GATE_H)
	# opening: the street outside
	ci.draw_colored_polygon(PackedVector2Array([a, b, b + top, a + top]), Color("d9e4e8"))
	ci.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, -40), a + Vector2(0, -40)]), Color("9a9a94"))
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(0, -40), b + Vector2(0, -40), b + Vector2(0, -150), a + Vector2(0, -120)]), Color("b9c9a6"))
	Paint.glow(ci, (a + b) * 0.5 + Vector2(0, -120), 140, Color(1, 1, 0.95, 0.4))
	# roll-up door
	var col := Color("4e6b7c")
	if Game.state.get("gate_new_color", false):
		col = Color("a8443a")
	var hcur := GATE_H * (1.0 - gate_open)
	if hcur > 2.0:
		var dp := PackedVector2Array([a + top, b + top, b + top + Vector2(0, hcur), a + top + Vector2(0, hcur)])
		Paint.fill(ci, dp, col, 0.22, -0.46)
		var ribs := int(hcur / 16.0)
		for i in ribs:
			var y := -GATE_H + 12.0 + i * 16.0
			ci.draw_line(a + Vector2(0, y), b + Vector2(0, y), col.darkened(0.3), 2, true)
			ci.draw_line(a + Vector2(0, y + 2), b + Vector2(0, y + 2), col.lightened(0.18), 1, true)
		var hb := (a + b) * 0.5 + top + Vector2(0, hcur - 14)
		ci.draw_line(hb + Vector2(-14, -7), hb + Vector2(14, 7), Paint.CHROME, 4, true)
	# frame
	ci.draw_line(a, a + top, Color("3a3634"), 8, true)
	ci.draw_line(b, b + top, Color("3a3634"), 8, true)
	ci.draw_line(a + top, b + top, Color("3a3634"), 10, true)
	# enamel sign above the gate
	if Game.state.get("sign", false):
		_sign(ci)


func _sign(ci: CanvasItem) -> void:
	var drop := 1.0 - sign_drop
	var a := g(GATE_U.x + 0.01, 0, GATE_H + 74 + drop * 60)
	var b := g(GATE_U.y - 0.01, 0, GATE_H + 74 + drop * 60)
	var sh := Vector2(0, 58)
	var pts := PackedVector2Array([a, b, b + sh, a + sh])
	Paint.shadow(ci, (a + b) * 0.5 + Vector2(6, 40), 120, 30, 0.3)
	ci.draw_colored_polygon(pts, Color("f2ead7"))
	var inner := PackedVector2Array([a + Vector2(6, 6), b + Vector2(-6, 6), b + sh + Vector2(-6, -6), a + sh + Vector2(6, -6)])
	ci.draw_colored_polygon(inner, Color("23466e"))
	ci.draw_polyline(PackedVector2Array([a + Vector2(10, 10), b + Vector2(-10, 10), b + sh + Vector2(-10, -10), a + sh + Vector2(10, -10), a + Vector2(10, 10)]), Color("f2ead7"), 2, true)
	# lettering along the wall direction
	Paint.fonts()
	var mid := (a + b) * 0.5 + sh * 0.5
	ci.draw_set_transform(mid, (b - a).angle(), Vector2.ONE)
	ci.draw_string(Paint.font_hand, Vector2(-120, 10), "Гараж на розі", HORIZONTAL_ALIGNMENT_CENTER, 240, 30, Color("f2ead7"))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	ci.draw_circle(a + Vector2(14, 14), 3, Paint.CHROME)
	ci.draw_circle(b + Vector2(-14, 14), 3, Paint.CHROME)


# ------------------------------------------------------------------ equipment

func _dashed(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := int(a.distance_to(b) / 16.0)
		for k in n:
			if k % 2 == 0:
				ci.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 3, true)


func _draw_equip(ci: CanvasItem) -> void:
	var pul := 0.55 + 0.35 * sin(t * 3.0)
	# stand spot
	if not Game.owns("stand"):
		var c := STAND
		var pts := PackedVector2Array([g(c.x - 0.18, c.y - 0.06), g(c.x + 0.18, c.y - 0.06), g(c.x + 0.18, c.y + 0.06), g(c.x - 0.18, c.y + 0.06)])
		ci.draw_colored_polygon(pts, Color(1, 0.95, 0.8, 0.08))
		_dashed(ci, pts, Color(1, 0.95, 0.8, pul))
		_floor_text(ci, g(c.x, c.y), "СТІЙКА · %d" % Game.price("stand"), Color(1, 0.95, 0.8, 0.75))
	elif vehicle == "" or vehicle == "car" or vehicle == "wagon":
		Art._stand_front_iso(ci, g(STAND.x, STAND.y), Art.U * -1.0)
	# lift corner
	var bc := BAY
	var bay := PackedVector2Array([g(GATE_U.x - 0.02, 0.04), g(GATE_U.y + 0.04, 0.04), g(GATE_U.y + 0.04, 0.66), g(GATE_U.x - 0.02, 0.66)])
	if Game.owns("lift"):
		ci.draw_colored_polygon(bay, Color(0.2, 0.2, 0.22, 0.25))
		_stripes(ci, g(GATE_U.x - 0.02, 0.66), g(GATE_U.y + 0.04, 0.66))
		# lift base plates and the far post
		_post(ci, g(GATE_U.x - 0.03, bc.y), -1)
	else:
		_dashed(ci, bay, Color(1, 0.95, 0.8, pul * 0.6 if Game.item_unlocked("lift") else 0.18))
		if Game.career_stage() >= 2:
			_floor_text(ci, g(BAY.x - 0.06, BAY.y + 0.14), "ПІДЙОМНИК · %d" % Game.price("lift"), Color(1, 0.95, 0.8, 0.7 if Game.item_unlocked("lift") else 0.3))
		# boxes in the empty corner
		_crate(ci, g(GATE_U.y - 0.02, 0.1), 46, Color("a07a4a"))
		_crate(ci, g(GATE_U.y - 0.03, 0.2), 34, Color("8e6a3f"))
	if Game.owns("decor_lamp"):
		var lp := g(bc.x, bc.y, 300)
		ci.draw_line(g(bc.x, bc.y, HW + 60), lp, Color("2b2522"), 2, true)
		Paint.fill(ci, PackedVector2Array([lp + Vector2(-8, 0), lp + Vector2(8, 0), lp + Vector2(44, 30), lp + Vector2(-44, 30)]), Color("e9e2d0"), 0.3)
		ci.draw_colored_polygon(Paint.ellipse(lp + Vector2(0, 30), 44, 9, 18), Color("2f5f8a"))
		ci.draw_arc(lp + Vector2(0, 30), 44, 0, PI, 18, Color("23466e"), 3, true)
		Paint.glow(ci, lp + Vector2(0, 40), 90, Color(1, 0.92, 0.65, 0.55))
		Paint.glow_e(ci, g(bc.x, bc.y), 220, 100, Color(1, 0.86, 0.5, 0.16))


## Chalk lettering lying on the floor along the u axis.
func _floor_text(ci: CanvasItem, at: Vector2, txt: String, col: Color) -> void:
	Paint.fonts()
	ci.draw_set_transform_matrix(Transform2D(Art.U, Art.V * 0.8, at))
	ci.draw_string(Paint.font_bold, Vector2(-110, 8), txt, HORIZONTAL_ALIGNMENT_CENTER, 220, 20, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _stripes(ci: CanvasItem, a: Vector2, b: Vector2) -> void:
	var n := 14
	for i in n:
		var p := a.lerp(b, float(i) / n)
		var q := a.lerp(b, float(i + 1) / n)
		ci.draw_colored_polygon(PackedVector2Array([p, q, q + Vector2(-8, 4), p + Vector2(-8, 4)]), Color("e0b22c") if i % 2 == 0 else Color("2b2a2e"))


func _post(ci: CanvasItem, base: Vector2, side: int) -> void:
	var col := Color("d9a62e")
	Paint.fill(ci, Paint.rrect(Rect2(base + Vector2(-9, -170), Vector2(18, 170)), 4), col, 0.3)
	ci.draw_line(base + Vector2(-4, -165), base + Vector2(-4, -6), Color(1, 1, 1, 0.3), 3, true)
	ci.draw_colored_polygon(Paint.ellipse(base, 22, 9, 14), Color("8a6a2a"))
	ci.draw_line(base + Vector2(0, -40), base + Vector2(side * -46, -40 + side * -2), Paint.METAL_DARK, 6, true)


func _crate(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	var u := Art.U * s
	var v := Art.V * s * 0.8
	var z := Vector2(0, -s * 0.8)
	Paint.fill(ci, PackedVector2Array([p, p + u, p + u + z, p + z]), col.darkened(0.2), 0.2)
	Paint.fill(ci, PackedVector2Array([p, p + v, p + v + z, p + z]), col, 0.2)
	Paint.fill(ci, PackedVector2Array([p + z, p + u + z, p + u + v + z, p + v + z]), col.lightened(0.15), 0.15)


# ------------------------------------------------------------------ vehicle & people

func vehicle_origin() -> Vector2:
	return g(veh_uv.x, veh_uv.y)


func _draw_vehicle(ci: CanvasItem) -> void:
	zones.clear()
	if vehicle == "":
		return
	var at := vehicle_origin()
	var opts := veh_opts.duplicate()
	match vehicle:
		"moped", "moto":
			var axis := Art.U * veh_facing
			opts["stand"] = Game.owns("stand") and veh_uv.distance_to(STAND) < 0.05
			if vehicle == "moped":
				Art.moped(ci, at, axis, veh_paint, opts)
			else:
				Art.moto(ci, at, axis, veh_paint, opts)
			var x := Art.side_xf(at, axis, 1.0)
			var lift := -22.0 if opts["stand"] else 0.0
			zones["front"] = x * Vector2(84, -150 + lift)
			zones["mirror"] = x * Vector2(46, -186 + lift)
			zones["wheel"] = x * Vector2(80, -34 + lift)
			zones["fender"] = x * Vector2(80, -70 + lift)
			zones["turn"] = x * Vector2(88, -114 + lift)
			zones["horn"] = x * Vector2(66, -160 + lift)
			zones["kickstand"] = x * Vector2(-20, -24 + lift)
			zones["case"] = x * Vector2(-115, -160 + lift)
		"car", "wagon":
			opts["wagon"] = vehicle == "wagon"
			if Game.owns("lift") and vehicle == "car":
				opts["lifted"] = 0.0
			Art.car(ci, at, veh_paint, opts)
			var iso := Art.Iso.new()
			iso.o = at
			iso.k = 62.0
			zones["front"] = iso.p(2.05, 0.62, 0.66)
			zones["windshield"] = iso.p(0.5, 0.0, 1.25)
			zones["door"] = iso.p(0.4, 0.86, 0.75)
			zones["window"] = iso.p(0.3, 0.78, 1.3)
	if Game.owns("lift") and (vehicle == "car" or vehicle == "wagon") and veh_uv.distance_to(BAY) < 0.05:
		_post(ci, g(GATE_U.y + 0.05, BAY.y), 1)


func _draw_people(ci: CanvasItem) -> void:
	var list: Array = []
	if not client_look.is_empty():
		list.append([client_uv, client_look, client_wave, 1.0])
	if not friend_look.is_empty() and friend_uv.x > -0.5:
		list.append([friend_uv, friend_look, 0.0, -1.0])
	list.sort_custom(func(a, b): return a[0].x + a[0].y < b[0].x + b[0].y)
	for e in list:
		Art.person(ci, g(e[0].x, e[0].y), e[1], t + e[0].x * 3.0, 1.0, e[2], e[3])
	ppl.modulate.a = client_alpha


func _draw_front(ci: CanvasItem) -> void:
	for id in pulse_ids:
		var p: Vector2 = zone_pos(id)
		if p == Vector2.INF:
			continue
		var r := 34.0 + sin(t * 4.0) * 6.0
		ci.draw_arc(p, r, 0, TAU, 40, Color(1, 0.86, 0.4, 0.95), 4.0, true)
		ci.draw_arc(p, r + 12.0, 0, TAU, 40, Color(1, 0.86, 0.4, 0.35), 3.0, true)


func zone_pos(id: String) -> Vector2:
	if zones.has(id):
		return zones[id]
	match id:
		"stand_spot":
			return g(STAND.x, STAND.y)
		"lift_spot":
			return g(BAY.x, BAY.y)
		"board":
			return g(0, 0.155, 215)
		"photo":
			return g(0.355, 0, 205)
		"gate":
			return g((GATE_U.x + GATE_U.y) * 0.5, 0, 120)
		"cabinet_spot":
			return g(0.24, 0.04, 60)
		"lamp_spot":
			return g(BAY.x, BAY.y, 280)
	return Vector2.INF


## What is under the finger (local coordinates).
func pick(p: Vector2, allowed: Array) -> String:
	var best := ""
	var bd := INF
	for id in allowed:
		var z := zone_pos(id)
		if z == Vector2.INF:
			continue
		var r := 70.0
		if id == "board" or id == "lift_spot":
			r = 110.0
		var d := z.distance_to(p)
		if d < r and d < bd:
			bd = d
			best = id
	return best
