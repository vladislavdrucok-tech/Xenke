class_name WorldView
extends Control
## Draws the hotel cross-section for a ShiftSim: sky, floors, shaft, cabin, passengers,
## bubbles and effects. Taps on a floor are reported; dragging scrolls the view.

signal floor_tapped(f: int)

const FH := Defs.FLOOR_H
const ROOF_H := 96
const AMBER := Color("ffa82e")
const BRASS := Color("d8a040")
const BRASS_D := Color("8a5a22")
const BRASS_L := Color("ffe08a")

var sim: ShiftSim
var demo := false
var cam_y := -120.0
var manual_t := 0.0
var _press_pos := Vector2.ZERO
var _press_cam := 0.0
var _dragging := false
var _pressing := false
var vis := {}
var fx: Array = []
var doors: Array = []
var t := 0.0
var stars: Array = []
var neon_on := true
var _neon_t := 2.0
var taxi_x := -999.0
var _taxi_t := 6.0
var dark := 0.0
var shake := 0.0
var unlock_anim := 0.0
var highlight_floor := 0
var _cam_ready := false
var _off := Vector2.ZERO
var skin := "classic"
var gate_cols: Array = [BRASS, BRASS_D, BRASS_L]
var speech: Array = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var r := RandomNumberGenerator.new()
	r.seed = 1313
	for i in 90:
		stars.append([r.randf(), r.randf() * 0.8, r.randf() * TAU, r.randf_range(0.4, 1.0)])


func set_sim(s: ShiftSim) -> void:
	sim = s
	vis.clear()
	fx.clear()
	doors.clear()
	speech.clear()
	set_skin(Save.skin())
	_cam_ready = false


func set_skin(id: String) -> void:
	skin = id if Defs.SKINS.has(id) else "classic"
	var g: Array = Defs.SKINS[skin]["gate"]
	gate_cols = [Color(g[0]), Color(g[1]), Color(g[2])]


## A short speech bubble over a passenger (follows them; at most 3 at a time).
func say(pid: int, text: String, life := 2.4) -> void:
	if text == "":
		return
	for s in speech:
		if s.pid == pid:
			s.text = text
			s.t = 0.0
			s.life = life
			return
	if speech.size() >= 3:
		speech.pop_front()
	speech.append({"pid": pid, "text": text, "t": 0.0, "life": life})


# ------------------------------------------------------------------ coordinates

func bx() -> float:
	return floorf((size.x - Defs.BUILDING_W) / 2.0)


func feet_y(f: float) -> float:
	return -f * FH + 48.0


func floor_top(f: float) -> float:
	return -f * FH


func sy(wy: float) -> float:
	return roundf(wy - cam_y + size.y / 2.0)


func roof_offset() -> float:
	return unlock_anim * FH


func world_top() -> float:
	return floor_top(sim.floors) - ROOF_H - 40.0


func _cam_target() -> float:
	var target := feet_y(sim.pos) - 20.0
	var top := world_top()
	var bottom := 70.0
	var half := size.y / 2.0
	if bottom - top <= size.y:
		return bottom - half
	return clampf(target, top + half, bottom - half)


func _clamp_cam() -> void:
	var top := world_top()
	var bottom := 70.0
	var half := size.y / 2.0
	if bottom - top <= size.y:
		cam_y = bottom - half
	else:
		cam_y = clampf(cam_y, top + half, bottom - half)


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if demo or sim == null:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = true
			_press_pos = e.position
			_press_cam = cam_y
			_dragging = false
		else:
			if _pressing and not _dragging:
				_tap(e.position)
			_pressing = false
			_dragging = false
		accept_event()
	elif e is InputEventMouseMotion and _pressing:
		if not _dragging and e.position.distance_to(_press_pos) > 10.0:
			_dragging = true
		if _dragging:
			cam_y = _press_cam - (e.position.y - _press_pos.y)
			_clamp_cam()
			manual_t = 2.5
		accept_event()


func _tap(p: Vector2) -> void:
	var wy := p.y - size.y / 2.0 + cam_y
	var f := int(floor(-wy / FH)) + 1
	var lx := p.x - bx()
	if f >= 1 and f <= sim.floors and lx >= 0.0 and lx <= Defs.BUILDING_W:
		floor_tapped.emit(f)


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	if sim == null:
		return
	t += delta
	if not _cam_ready and size.y > 0.0:
		cam_y = _cam_target()
		_cam_ready = true
	if manual_t > 0.0 and not _pressing:
		manual_t -= delta
	if manual_t <= 0.0 and not _pressing:
		cam_y = lerpf(cam_y, _cam_target(), 1.0 - exp(-delta * 4.0))
	_clamp_cam()
	unlock_anim = maxf(0.0, unlock_anim - delta * 0.6)
	shake = maxf(0.0, shake - delta * 3.0)
	var want_dark := 0.62 if sim.ev_id == "blackout" else 0.0
	dark = move_toward(dark, want_dark, delta * 1.5)
	_neon_t -= delta
	if _neon_t <= 0.0:
		neon_on = not neon_on
		_neon_t = randf_range(0.05, 0.15) if not neon_on else (randf_range(0.05, 0.2) if randf() < 0.3 else randf_range(2.0, 6.0))
	_taxi_t -= delta
	if _taxi_t <= 0.0 and taxi_x < -500.0:
		taxi_x = -60.0
		_taxi_t = randf_range(10.0, 22.0)
	if taxi_x > -500.0:
		taxi_x += delta * 70.0
		if taxi_x > size.x + 60.0:
			taxi_x = -999.0
	_update_vis(delta)
	_update_fx(delta)
	for sp in speech:
		sp.t += delta
	speech = speech.filter(func(sp): return sp.t < sp.life and vis.has(sp.pid))
	for d in doors:
		d[2] -= delta
	doors = doors.filter(func(d): return d[2] > 0.0)
	queue_redraw()


func rider_slots() -> Dictionary:
	var rs := sim.riders()
	var widths := []
	var total := 0.0
	for p in rs:
		var s := int(Defs.TYPES[p.type]["seats"])
		var w := 12.0 if s <= 1 else (22.0 if s == 2 else 26.0)
		widths.append(w)
		total += w
	var inner := 76.0
	var k := 1.0 if total <= inner else inner / total
	var out := {}
	var x := 12.0 + 6.0
	for i in rs.size():
		var w: float = widths[i] * k
		out[rs[i].id] = x + w / 2.0
		x += w
	return out


func _update_vis(delta: float) -> void:
	var slots := rider_slots()
	var alive := {}
	for p in sim.passengers:
		alive[p.id] = true
		var v: Dictionary = vis.get(p.id, {})
		if v.is_empty():
			v = {"x": p.x, "from": p.x, "state": p.state, "walk": 0.0, "face": -1.0, "moving": false,
				"act": -1.0, "act_cd": randf_range(1.5, 5.0), "phase": randf() * 9.0}
			vis[p.id] = v
		if v.state != p.state:
			v.from = v.x
			v.state = p.state
		var target: float = p.x
		match p.state:
			ShiftSim.P_BOARDING:
				target = lerpf(v.from, slots.get(p.id, 40.0), clampf(p.t / maxf(p.dur, 0.01), 0.0, 1.0))
			ShiftSim.P_RIDING:
				target = lerpf(v.x, slots.get(p.id, v.x), 1.0 - exp(-delta * 10.0))
			ShiftSim.P_EXITING:
				target = lerpf(v.from, float(Defs.LANDING_X), clampf(p.t / maxf(p.dur, 0.01), 0.0, 1.0))
		var dx: float = target - v.x
		v.moving = absf(dx) > 0.02
		if v.moving:
			v.walk += absf(dx)
			v.face = signf(dx)
		elif p.state == ShiftSim.P_WAITING:
			v.face = -1.0
		v.x = target
		# fidget: every few seconds a waiting or riding passenger plays its own little action
		if p.state == ShiftSim.P_WAITING or p.state == ShiftSim.P_RIDING:
			if v.act >= 0.0:
				v.act += delta
				if v.act >= 1.1:
					v.act = -1.0
			else:
				v.act_cd -= delta * (2.0 if p.pat / p.pmax < 0.6 else 1.0)
				if v.act_cd <= 0.0:
					v.act = 0.0
					v.act_cd = randf_range(3.0, 7.0)
	for id in vis.keys():
		if not alive.has(id):
			vis.erase(id)


func _update_fx(delta: float) -> void:
	for e in fx:
		e.t += delta
		e.x += e.vx * delta
		e.y += e.vy * delta
		e.vy += e.get("g", 0.0) * delta
	fx = fx.filter(func(e): return e.t < e.life)


# ------------------------------------------------------------------ effects API

func passenger_pos(pid: int) -> Vector2:
	for p in sim.passengers:
		if p.id == pid:
			var v: Dictionary = vis.get(pid, {"x": p.x})
			var fy := feet_y(sim.pos) if (p.state == ShiftSim.P_RIDING or p.state == ShiftSim.P_BOARDING) else feet_y(p.floor)
			return Vector2(v.x, fy - 24.0)
	return Vector2(200, feet_y(1))


func float_text(pos: Vector2, text: String, col: Color, life := 1.3) -> void:
	fx.append({"kind": "text", "x": pos.x, "y": pos.y, "vx": 0.0, "vy": -18.0, "t": 0.0, "life": life, "text": text, "col": col})


func burst(pos: Vector2, n: int, kind := "coin") -> void:
	for i in n:
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		var sp := randf_range(30.0, 70.0)
		var cols := [Color("ff4fa0"), Color("4fd8ff"), Color("ffe14f"), Color("8aff6a"), Color("b06aff")]
		fx.append({"kind": kind, "x": pos.x, "y": pos.y, "vx": cos(a) * sp, "vy": sin(a) * sp, "g": 140.0,
			"t": 0.0, "life": randf_range(0.6, 1.0), "col": cols[i % cols.size()]})


func emote(pos: Vector2, icon: String, life := 1.0) -> void:
	fx.append({"kind": "icon", "x": pos.x, "y": pos.y - 10.0, "vx": 0.0, "vy": -10.0, "t": 0.0, "life": life, "icon": icon})


func steam(pos: Vector2) -> void:
	for i in 4:
		fx.append({"kind": "puff", "x": pos.x + randf_range(-5, 5), "y": pos.y - 4.0, "vx": randf_range(-6, 6),
			"vy": randf_range(-26, -14), "t": 0.0, "life": randf_range(0.5, 0.9)})


func open_door(f: int, x: float) -> void:
	doors.append([f, x, 0.45])


func on_sim_event(e: Dictionary) -> void:
	match e.t:
		"deliver":
			var pos := passenger_pos(e.pid)
			float_text(pos + Vector2(0, -6), "+%d" % e.coins, Art.GOLD_L)
			burst(pos, 4 if e.coins < 20 else 8)
			if e.good:
				emote(pos, "heart", 0.8)
			if e.get("forgiven", false):
				float_text(pos + Vector2(0, -18), "-1", Art.GREEN, 1.6)
		"complaint":
			var pos := passenger_pos(e.pid)
			emote(pos, "heart_broken", 1.3)
			steam(pos)
			shake = 0.6
		"grumpy":
			var pos := passenger_pos(e.pid)
			float_text(pos, "!!", Art.RED)
			steam(pos)
		"kid":
			var pos := passenger_pos(e.pid)
			float_text(pos, "%d!" % e.floor, Art.CYAN, 1.5)
		"door":
			open_door(e.floor, e.x)
		"pickup":
			var pos := Vector2(160, feet_y(e.floor) - 6)
			burst(pos, 12)
			float_text(pos + Vector2(0, -10), "+%d" % e.coins, Art.GOLD_L, 1.6)
		"vanish":
			var pos := passenger_pos(e.pid)
			burst(pos, 10, "spark")
			float_text(pos, "БУ!", Color("c8c0ff"))
		"event":
			if e.id == "party":
				burst(Vector2(220, feet_y(e.floor) - 30), 24, "confetti")


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if sim == null:
		return
	_off = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 2.0).round() if shake > 0.0 else Vector2.ZERO
	draw_set_transform(_off, 0.0, Vector2.ONE)
	_draw_sky()
	var ox := bx()
	_draw_building(ox)
	_draw_cabin(ox)
	_draw_floor_people(ox)
	if dark > 0.0:
		_draw_blackout(ox)
	_draw_bubbles(ox)
	_draw_speech(ox)
	_draw_fx(ox)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sky_colors() -> Array:
	var p := 0.0
	if not demo and sim.duration > 0.0:
		p = clampf(sim.time / sim.duration, 0.0, 1.0)
	var night_top := Color("0b0a1c")
	var night_bot := Color("2a1f5c")
	var dawn_top := Color("3a3a7a")
	var dawn_bot := Color("ff9a6a")
	var k := smoothstep(0.7, 1.0, p)
	return [night_top.lerp(dawn_top, k), night_bot.lerp(dawn_bot, k), 1.0 - k]


func _draw_sky() -> void:
	var cols := _sky_colors()
	var bands := 28
	var h := size.y / bands
	for i in bands:
		var c: Color = cols[0].lerp(cols[1], float(i) / (bands - 1))
		draw_rect(Rect2(0, floorf(i * h), size.x, ceilf(h) + 1), c)
	var star_a: float = cols[2]
	var par := -cam_y * 0.04
	for s in stars:
		var a: float = (0.5 + 0.5 * sin(t * 2.0 * s[3] + s[2])) * star_a * s[3]
		var p := Vector2(roundf(s[0] * size.x), roundf(fposmod(s[1] * size.y * 1.2 + par, size.y)))
		draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 0.96, 0.85, a))
		if s[3] > 0.93:
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(1, 0.96, 0.85, a * 0.4))
			draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), Color(1, 0.96, 0.85, a * 0.4))
	var moon_y := roundf(34.0 - (cam_y - _cam_target()) * 0.05) + roundf((1.0 - star_a) * 40.0)
	draw_texture(Art.tex("moon"), Vector2(size.x - 78, moon_y), Color(1, 1, 1, 0.4 + 0.6 * star_a))
	# distant skyline, anchored to the street with parallax
	var sk := Art.tex("skyline")
	var base := (0.0 - cam_y) * 0.55 + size.y / 2.0 - sk.get_height() + 30.0
	var x := -fposmod(t * 2.0, float(sk.get_width()))
	while x < size.x:
		draw_texture(sk, Vector2(roundf(x), roundf(base)))
		x += sk.get_width()


func _draw_building(ox: float) -> void:
	var floors_tex := Art.tex("floors")
	var shaft := Art.tex("shaft")
	var ro := roof_offset()
	var top := sim.floors
	# roof
	var roof_y := sy(floor_top(top) - ROOF_H + ro)
	draw_texture(Art.tex("roof"), Vector2(ox, roof_y))
	var neon := Art.tex("neon")
	var nreg := Rect2(0 if neon_on else 150, 0, 150, 48)
	draw_texture_rect_region(neon, Rect2(ox + 142, roof_y + 30, 150, 48), nreg)
	if neon_on:
		draw_rect(Rect2(ox + 140, roof_y + 28, 154, 52), Color(1, 0.3, 0.7, 0.05))
	# shaft above top floor up to the machine room
	draw_texture_rect_region(shaft, Rect2(ox + 8, roof_y + ROOF_H - 10, 96, 10), Rect2(0, 0, 96, 10))
	for f in range(1, top + 1):
		var y := sy(floor_top(f))
		if y > size.y or y + FH < 0:
			continue
		var a := 1.0
		if f == top and unlock_anim > 0.0:
			a = 1.0 - unlock_anim
		draw_texture_rect_region(shaft, Rect2(ox + 8, y, 96, FH), Rect2(0, 0, 96, FH), Color(1, 1, 1, a))
		draw_texture_rect_region(floors_tex, Rect2(ox, y, Defs.BUILDING_W, FH), Rect2(0, (f - 1) * FH, Defs.BUILDING_W, FH), Color(1, 1, 1, a))
		_draw_floor_overlay(f, ox, y)
	# street (tiled to the screen width)
	var gy := sy(0.0)
	var st := Art.tex("street")
	var x := ox - st.get_width() * ceilf(ox / st.get_width())
	while x < size.x:
		draw_texture(st, Vector2(x, gy))
		x += st.get_width()
	if gy + st.get_height() < size.y:
		draw_rect(Rect2(0, gy + st.get_height(), size.x, size.y - gy - st.get_height()), Color("1e1a2a"))
	if taxi_x > -500.0:
		var fr := int(t * 8.0) % 2
		draw_texture_rect_region(Art.tex("taxi"), Rect2(roundf(taxi_x), gy + 20, 44, 18), Rect2(fr * 44, 0, 44, 18))
	draw_texture(Art.tex("lamp"), Vector2(ox + 334, gy - 50))


func _draw_floor_overlay(f: int, ox: float, y: float) -> void:
	var num := str(f)
	var w := Art.digits_width(num)
	Art.draw_digits(self, num, Vector2(ox + 118 - w / 2, y + 8), Art.GOLD if f != 13 else Color("8affb0"))
	var q := sim.queue_on(f)
	if q.size() > 0:
		var frac := sim.min_wait_frac(f)
		var col := AMBER
		if frac < 0.3 and int(t * 4.0) % 2 == 0:
			col = Art.RED
		draw_rect(Rect2(ox + 115, y + 22, 7, 5), col)
		draw_rect(Rect2(ox + 116, y + 23, 2, 1), Color(1, 1, 1, 0.6))
	if highlight_floor == f:
		var a := 0.25 + 0.2 * sin(t * 6.0)
		draw_rect(Rect2(ox + 104, y + 3, Defs.BUILDING_W - 112, 43), Color(1, 0.9, 0.4, a * 0.4))
	if sim.closed.has(f):
		draw_rect(Rect2(ox + 104, y + 3, Defs.BUILDING_W - 112, 43), Color(0.05, 0.03, 0.08, 0.55))
		for i in 12:
			var sx := ox + 104 + i * 22
			draw_rect(Rect2(sx, y + 24, 11, 5), Color("e8c84a"))
			draw_rect(Rect2(sx + 11, y + 24, 11, 5), Color("2a2430"))
		Art.draw_icon(self, "wrench", Vector2(ox + 220, y + 18))
	if sim.coin_pile_floor == f and sim.coin_pile_amount > 0:
		var bob := roundf(sin(t * 5.0) * 1.5)
		draw_texture(Art.tex("coin_pile"), Vector2(ox + 150, y + 37 + bob))
		if int(t * 3.0) % 2 == 0:
			draw_rect(Rect2(ox + 158 + randi() % 6, y + 34, 1, 1), Color.WHITE)
	if sim.ev_id == "party" and sim.ev_floor == f:
		for i in 3:
			var bxp := ox + 196 + i * 9
			var byp := y + 6 + roundf(sin(t * 3.0 + i) * 2.0)
			var cols := [Color("ff4fa0"), Color("4fd8ff"), Color("ffe14f")]
			draw_rect(Rect2(bxp, byp, 6, 7), cols[i])
			draw_rect(Rect2(bxp + 1, byp + 1, 2, 2), Color(1, 1, 1, 0.5))
			draw_line(Vector2(bxp + 3, byp + 7), Vector2(bxp + 3, byp + 14), Color(1, 1, 1, 0.5))
	for d in doors:
		if d[0] == f:
			draw_texture(Art.tex("door_open"), Vector2(ox + d[1] - 8, y + 16), Color(1, 1, 1, clampf(d[2] / 0.15, 0.0, 1.0)))
	if f == 13 and randf() < 0.01:
		draw_rect(Rect2(ox + 104, y + 3, Defs.BUILDING_W - 112, 43), Color(0, 0, 0, 0.35))


func _draw_cabin(ox: float) -> void:
	var cx := ox + 12
	var top := sy(feet_y(sim.pos) - 43.0)
	var roof_bottom := sy(floor_top(sim.floors) + roof_offset() - 14.0)
	if top > roof_bottom:
		draw_rect(Rect2(ox + 55, roof_bottom, 2, top - roof_bottom), Color("4a4458"))
		draw_rect(Rect2(ox + 55, roof_bottom, 1, top - roof_bottom), Color("7a7488"))
	# warm light spilling around the cabin
	var glow := Color(1.0, 0.85, 0.5, 0.06) if sim.ev_id != "blackout" else Color(1.0, 0.2, 0.2, 0.08)
	draw_rect(Rect2(cx - 3, top - 2, 94, 50), glow)
	var sfx := "" if skin == "classic" else "_" + skin
	draw_texture(Art.tex("cabin_back" + sfx), Vector2(cx, top))
	# riders
	var feet := top + 43
	for p in sim.riders():
		_draw_person(p, ox, feet)
	# boarding passengers walk in behind the gate too
	_draw_gate(cx + 3, top + 6, 82, 38, sim.door)
	draw_texture(Art.tex("cabin_front" + sfx), Vector2(cx, top))
	var num := str(sim.lift_floor())
	var w := Art.digits_width(num)
	var col := AMBER if sim.ev_id != "blackout" else Art.RED
	Art.draw_digits(self, num, Vector2(cx + 44 - w / 2, top - 0), col)
	# direction arrow next to the indicator
	if absf(sim.vel) > 0.05:
		var ay := top + 2
		var axp := cx + 56
		if sim.vel > 0:
			draw_rect(Rect2(axp + 1, ay, 1, 1), col)
			draw_rect(Rect2(axp, ay + 1, 3, 1), col)
		else:
			draw_rect(Rect2(axp, ay, 3, 1), col)
			draw_rect(Rect2(axp + 1, ay + 1, 1, 1), col)
	if sim.ev_id == "blackout":
		draw_rect(Rect2(cx + 3, top + 6, 82, 38), Color(0.6, 0.0, 0.0, 0.18))


func _draw_gate(x0: float, y0: float, w: float, h: float, door: float) -> void:
	var half := w / 2.0
	var hw := lerpf(half, 5.0, door)
	var n := 6
	for side in 2:
		var pts := []
		for i in n + 1:
			var px := x0 + i * hw / n if side == 0 else x0 + w - i * hw / n
			pts.append(roundf(px))
		var a0 := pts[0] as float
		var a1 := pts[n] as float
		var l := minf(a0, a1)
		var r := maxf(a0, a1)
		draw_rect(Rect2(l, y0, r - l + 1, 1), gate_cols[0])
		draw_rect(Rect2(l, y0 + h - 1, r - l + 1, 1), gate_cols[1])
		var sp := hw / n
		if sp > 2.5:
			for i in n:
				var xa: float = pts[i]
				var xb: float = pts[i + 1]
				var ym := y0 + h / 2.0
				draw_line(Vector2(xa, y0 + 2), Vector2(xb, ym), gate_cols[1])
				draw_line(Vector2(xb, y0 + 2), Vector2(xa, ym), gate_cols[1])
				draw_line(Vector2(xa, ym), Vector2(xb, y0 + h - 2), gate_cols[1])
				draw_line(Vector2(xb, ym), Vector2(xa, y0 + h - 2), gate_cols[1])
		for i in n + 1:
			var px: float = pts[i]
			draw_rect(Rect2(px, y0, 1, h), gate_cols[0] if i % 2 == 0 else gate_cols[2])


func _draw_floor_people(ox: float) -> void:
	var list := []
	for p in sim.passengers:
		match p.state:
			ShiftSim.P_WALK_IN, ShiftSim.P_WAITING, ShiftSim.P_WALK_OUT, ShiftSim.P_LEAVING:
				list.append(p)
	list.sort_custom(func(a, b): return a.x > b.x)
	for p in list:
		var y := sy(feet_y(p.floor))
		if y < -40 or y > size.y + 40:
			continue
		_draw_person(p, ox, y)


const IDLE_SEQ := [0, 0, 1, 2, 2, 1, 0, 0, 3]


func _frame_for(p: Dictionary, v: Dictionary) -> int:
	var A: Dictionary = Art.people()["anims"]
	var moving: bool = v.get("moving", false)
	var walk := int(A["walk"][0]) + int(v.get("walk", 0.0) / 3.0) % int(A["walk"][1])
	var angry := int(A["angry"][0]) + int(t * 3.0 + p.id) % 2
	var happy := int(A["happy"][0]) + int(t * 5.0 + p.id) % 2
	match p.state:
		ShiftSim.P_EXITING:
			return angry if p.grumpy else happy
		ShiftSim.P_LEAVING:
			return walk if moving else angry
		ShiftSim.P_WALK_OUT:
			return walk if moving else happy
	if moving:
		return walk
	var frac: float = p.pat / p.pmax
	if (p.state == ShiftSim.P_WAITING and frac < 0.25) or (p.state == ShiftSim.P_RIDING and p.grumpy):
		return angry
	if float(v.get("act", -1.0)) >= 0.0:
		return int(A["wait"][0]) + mini(int(v.act / 1.1 * 4.0), 3)
	return int(A["idle"][0]) + IDLE_SEQ[int(t * 3.0 + v.get("phase", 0.0)) % IDLE_SEQ.size()]


func _draw_person(p: Dictionary, ox: float, feet: float) -> void:
	var v: Dictionary = vis.get(p.id, {"x": p.x, "walk": 0.0, "face": -1.0})
	var row := Defs.TYPE_ORDER.find(p.type)
	var fr := _frame_for(p, v)
	var x := roundf(ox + v.x)
	var mod := Color.WHITE
	if p.state == ShiftSim.P_LEAVING:
		mod = Color(1.0, 0.75, 0.75)
	var reg := Rect2(fr * 32, row * 32, 32, 32)
	var sw := 12.0 if p.type != "couple" and p.type != "bellhop" else 22.0
	var sa := 0.28 if p.type != "ghost" else 0.14
	draw_rect(Rect2(x - sw / 2.0, feet, sw, 1), Color(0, 0, 0, sa))
	draw_rect(Rect2(x - sw / 2.0 + 2, feet + 1, sw - 4, 1), Color(0, 0, 0, sa * 0.6))
	if v.face < 0.0:
		draw_set_transform(Vector2(x + 16, feet - 30) + _off, 0.0, Vector2(-1, 1))
	else:
		draw_set_transform(Vector2(x - 16, feet - 30) + _off, 0.0, Vector2.ONE)
	draw_texture_rect_region(Art.tex("passengers"), Rect2(0, 0, 32, 32), reg, mod)
	draw_set_transform(_off, 0.0, Vector2.ONE)


func _draw_blackout(ox: float) -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.0, 0.06, dark))
	# emergency lamps on each floor
	for f in range(1, sim.floors + 1):
		var y := sy(floor_top(f))
		if y < -FH or y > size.y:
			continue
		var a := dark * (0.5 + 0.5 * sin(t * 4.0 + f))
		draw_rect(Rect2(ox + 114, y + 4, 4, 2), Color(1, 0.2, 0.2, a))
	var top := sy(feet_y(sim.pos) - 43.0)
	draw_rect(Rect2(ox + 15, top + 6, 82, 38), Color(1.0, 0.4, 0.3, dark * 0.25))


func _bubble(cx: float, bottom: float, text: String, border: Color, fill: Color, ink: Color, alpha := 1.0) -> void:
	var w := Art.digits_width(text) + 6
	var h := 11
	var x := roundf(cx - w / 2.0)
	var y := roundf(bottom - h - 2)
	var o := Color(Art.INK, alpha)
	draw_rect(Rect2(x, y - 1, w, h + 2), o)
	draw_rect(Rect2(x - 1, y, w + 2, h), o)
	draw_rect(Rect2(x, y, w, h), Color(border, alpha))
	draw_rect(Rect2(x + 1, y + 1, w - 2, h - 2), Color(fill, alpha))
	draw_rect(Rect2(roundf(cx) - 1, y + h, 3, 1), o)
	draw_rect(Rect2(roundf(cx), y + h + 1, 1, 1), o)
	draw_rect(Rect2(roundf(cx), y + h, 1, 1), Color(border, alpha))
	Art.draw_digits(self, text, Vector2(x + 3, y + 2), Color(ink, alpha))


func _draw_bubbles(ox: float) -> void:
	for p in sim.passengers:
		if p.state != ShiftSim.P_WAITING and p.state != ShiftSim.P_WALK_IN:
			continue
		var feet := sy(feet_y(p.floor))
		if feet < -10 or feet > size.y + 40:
			continue
		var v: Dictionary = vis.get(p.id, {"x": p.x})
		var frac: float = p.pat / p.pmax
		var cx: float = ox + v.x
		var bottom := feet - Art.person_top(p.type) - 2.0
		if frac < 0.25:
			cx += roundf(sin(t * 30.0 + p.id) * 1.0)
		var border := Art.patience_color(frac)
		if frac < 0.25 and int(t * 6.0) % 2 == 0:
			border = Color.WHITE
		var fill := Art.WHITE
		var ink := Art.INK
		var alpha := 1.0
		if p.vip or p.type == "inspector":
			fill = Art.GOLD_L
		if p.type == "ghost":
			fill = Color("d8d0ff")
			alpha = 0.85
		if p.party:
			fill = Color("ffd0ec")
		_bubble(cx, bottom, str(p.dest), border, fill, ink, alpha)
		# patience bar under the bubble
		var bw := 10.0
		var bxp := roundf(cx - bw / 2.0)
		draw_rect(Rect2(bxp - 1, bottom + 1, bw + 2, 3), Color(Art.INK, 0.8))
		draw_rect(Rect2(bxp, bottom + 2, roundf(bw * clampf(frac, 0.0, 1.0)), 1), Art.patience_color(frac))
	# riders: a destination display above the cabin, one tag over each rider
	var top := sy(feet_y(sim.pos) - 43.0)
	var i := 0
	var shown := 0
	for p in sim.riders():
		if p.state != ShiftSim.P_EXITING:
			shown += 1
	if shown > 0:
		var bh := 21.0 if shown > 1 else 12.0
		var br := Rect2(ox + 14, top - bh - 1, 84, bh)
		draw_rect(br.grow(1), Color(gate_cols[1], 0.9))
		draw_rect(br, Color(0.05, 0.03, 0.08, 0.92))
		draw_rect(Rect2(br.position.x + 40, br.end.y + 1, 4, 1), gate_cols[1])
	for p in sim.riders():
		if p.state == ShiftSim.P_EXITING:
			continue
		var v: Dictionary = vis.get(p.id, {"x": 40.0})
		var frac: float = p.pat / p.pmax
		var text := str(p.dest)
		var w := Art.digits_width(text) + 4
		var x := roundf(ox + v.x - w / 2.0)
		var y := top - 11 - (i % 2) * 9 if shown > 1 else top - 11
		var col := Art.patience_color(frac)
		if p.grumpy and int(t * 5.0) % 2 == 0:
			col = Color.WHITE
		draw_rect(Rect2(x, y, w, 9), Color(Art.INK, 0.9))
		draw_rect(Rect2(x, y + 8, w, 1), col)
		Art.draw_digits(self, text, Vector2(x + 2, y + 1), col)
		i += 1


func _draw_speech(ox: float) -> void:
	var font := Art.body()
	var taken: Array = []
	for sp in speech:
		var p := {}
		for q in sim.passengers:
			if q.id == sp.pid:
				p = q
				break
		if p.is_empty():
			continue
		var v: Dictionary = vis.get(p.id, {"x": p.x})
		var in_cab: bool = p.state == ShiftSim.P_RIDING or p.state == ShiftSim.P_BOARDING or p.state == ShiftSim.P_EXITING
		var feet := sy(feet_y(sim.pos) if in_cab else feet_y(p.floor))
		var bottom := feet - (66.0 if in_cab else 46.0)
		if p.state == ShiftSim.P_WALK_OUT or p.state == ShiftSim.P_LEAVING:
			bottom = feet - 32.0
		var text: String = sp.text
		var w := ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 6.0
		var cx: float = ox + v.x
		var x := roundf(clampf(cx - w / 2.0, ox + 2.0, ox + Defs.BUILDING_W - w - 2.0))
		var y := roundf(bottom - 10.0)
		var guard := 0
		while guard < 4 and taken.any(func(r): return r.intersects(Rect2(x - 1, y - 1, w + 2, 12))):
			y -= 12.0
			guard += 1
		taken.append(Rect2(x - 1, y - 1, w + 2, 12))
		var a := clampf((sp.life - sp.t) / 0.3, 0.0, 1.0) * clampf(sp.t / 0.12, 0.0, 1.0)
		draw_rect(Rect2(x, y - 1, w, 11), Color(Art.INK, a))
		draw_rect(Rect2(x - 1, y, w + 2, 9), Color(Art.INK, a))
		draw_rect(Rect2(x, y, w, 9), Color(1, 1, 1, a))
		var tx := roundf(clampf(cx, x + 3.0, x + w - 4.0))
		draw_rect(Rect2(tx - 1, y + 9, 3, 2), Color(Art.INK, a))
		draw_rect(Rect2(tx, y + 9, 1, 1), Color(1, 1, 1, a))
		draw_string(font, Vector2(x + 3, y + 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Art.INK, a))


func _draw_fx(ox: float) -> void:
	var font := Art.title()
	for e in fx:
		var p := Vector2(roundf(ox + e.x), sy(e.y))
		var k: float = 1.0 - e.t / e.life
		match e.kind:
			"text":
				var s: String = e.text
				var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				var pos := Vector2(roundf(clampf(p.x - w / 2.0, ox + 4.0, ox + Defs.BUILDING_W - w - 4.0)), p.y)
				draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(Art.INK, k))
				draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(e.col, minf(1.0, k * 2.0)))
			"coin":
				Art.draw_icon(self, "coin", p - Vector2(4, 4), Color(1, 1, 1, minf(1.0, k * 2.0)), 8)
			"confetti":
				draw_rect(Rect2(p, Vector2(2, 2)), Color(e.col, k))
			"spark":
				draw_rect(Rect2(p, Vector2(1, 1)), Color(0.85, 0.8, 1.0, k))
			"puff":
				var r := 2.0 + (1.0 - k) * 3.0
				draw_rect(Rect2(p - Vector2(r / 2, r / 2), Vector2(r, r)), Color(0.85, 0.85, 0.9, k * 0.7))
			"icon":
				Art.draw_icon(self, e.icon, p - Vector2(8, 8), Color(1, 1, 1, minf(1.0, k * 2.0)))
