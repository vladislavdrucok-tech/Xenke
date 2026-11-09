extends RepairBase
## Moped headlight flickers on bumps (and the wagon's headlight in the final).
## Diagnose: toggle the switch, wiggle the wire — only near the loose
## connector does the light go out. Fix: push the plug into the socket in one
## move. Verify: switch on, wiggle again — the light stays steady.

const SWITCH := Vector2(520, 212)
const LENS := Vector2(245, 375)
const SOCKET := Vector2(300, 662)
const GAP := 36.0
const PLUG_SEATED_X := 368.0
const CONN_ZONE := Vector2(352, 662)

var switch_on := true
var plug := Gest.Slide.new(Vector2(PLUG_SEATED_X + GAP, 662), Vector2.LEFT, 0.0, GAP, 0.0)
var seated := false
var disturbing := 0.0      # > 0 while the loose connector is being touched
var wig := Gest.Wiggle.new()
var verify_travel := 0.0
var last_wire_p := Vector2.INF
var flick := 0.0
var lever := 1.0           # 1 = up (on), 0 = down (off)
var spring_back := false
var wire_target: Gest.Target
var pig_target: Gest.Target
var paint_col := Color("5f8f4e")


func build() -> void:
	paint_col = Color(order.get("paint", "#5f8f4e"))
	seated = step == "verify" or step == "done"
	if seated:
		plug.value = GAP
	switch_on = step != "verify"
	lever = 1.0 if switch_on else 0.0
	targets.clear()
	targets.append(Gest.circle("switch", SWITCH, 66, 2))
	targets.append(Gest.circle("plug", _plug_pos(), 58, 3))
	wire_target = Gest.path("wire", _wire_pts(), 36, 0)
	targets.append(wire_target)
	pig_target = Gest.path("pigtail", _pig_pts(), 32, 1)
	targets.append(pig_target)
	focus = "plug" if step == "fix" else ("wire" if step == "verify" else "")


func _plug_pos() -> Vector2:
	return plug.pos()


func _wire_pts() -> PackedVector2Array:
	var e := _plug_pos() + Vector2(30, 0)
	return Paint.bezier(SWITCH + Vector2(0, 44), SWITCH + Vector2(60, 180), Vector2(640, 640), e, 22)


func _pig_pts() -> PackedVector2Array:
	return Paint.bezier(LENS + Vector2(5, 118), LENS + Vector2(-10, 200), Vector2(215, 640), SOCKET + Vector2(-38, 0), 16)


func light_on() -> bool:
	if not switch_on:
		return false
	if seated:
		return true
	if disturbing > 0.0:
		return flick > 0.85
	return true


func tutorial_line() -> String:
	match step:
		"diagnose":
			if has_found("wire_ok"):
				finger = [CONN_ZONE + Vector2(60, -30), CONN_ZONE + Vector2(90, 10)]
				return "Тут світло рівне. Спробуй ближче до фари."
			if has_found("switch_ok"):
				finger = [Gest.path_point(_wire_pts(), 0.35), Gest.path_point(_wire_pts(), 0.45)]
				return "Вимикач працює. Тепер поворуши дріт пальцем."
			finger = [SWITCH, Gest.path_point(_wire_pts(), 0.4)]
			return "Натисни вимикач або поворуши дріт"
		"fix":
			finger = [_plug_pos(), SOCKET + Vector2(60, 0)]
			return "Ось причина! Дотисни роз’єм у гніздо одним рухом."
		"verify":
			if not switch_on:
				finger = [SWITCH]
				return "Тепер перевір: увімкни фару"
			finger = [CONN_ZONE + Vector2(70, -20), CONN_ZONE + Vector2(100, 20)]
			return "…і знову поворуши дріт біля роз’єму"
	return ""


# ----------------------------------------------------------- input

func on_press(id: String, p: Vector2) -> void:
	wig.reset()
	wig.feed(p)
	last_wire_p = p
	match id:
		"switch":
			switch_on = not switch_on
			Sfx.play("click")
			Sfx.buzz(15)
			if step == "diagnose" and switch_on:
				discover("switch_ok", true, SWITCH + Vector2(0, -30))
			elif step == "diagnose":
				label("Фара вимкнулась — вимикач реагує", true, SWITCH + Vector2(0, -30))
			if step == "verify" and switch_on:
				progress()
				if tutorial:
					_announce()
		"plug":
			if step == "fix":
				plug.begin(p)
				spring_back = false
			elif step == "diagnose":
				_touch_near_connector(p)
		_:
			_wire_touch(p)


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	wig.feed(p)
	if id == "plug" and step == "fix":
		plug.update(p)
		if plug.value >= GAP - 5.0:
			_seat()
		return
	if id == "switch":
		return
	_wire_touch(p)


func on_release(id: String, _p: Vector2) -> void:
	if id == "plug" and step == "fix" and not seated:
		spring_back = true
	disturbing = 0.0


func _near_connector(p: Vector2) -> bool:
	return p.distance_to(CONN_ZONE) < 125.0


func _touch_near_connector(p: Vector2) -> void:
	if not switch_on:
		label("Фара вимкнена — спершу натисни вимикач", false, SWITCH + Vector2(0, -30))
		return
	disturbing = 0.4
	if discover("loose", false, CONN_ZONE + Vector2(0, -40)):
		Sfx.play("flicker")
		_go_fix()


func _wire_touch(p: Vector2) -> void:
	match step:
		"diagnose":
			if _near_connector(p):
				if wig.travel > 10.0 or wig.reversals > 0:
					_touch_near_connector(p)
				elif switch_on:
					disturbing = 0.3
			elif wig.travel > 40.0 or wig.reversals > 0:
				if not switch_on:
					label("Фара вимкнена — спершу натисни вимикач", false, SWITCH + Vector2(0, -30))
				else:
					discover("wire_ok", true, p + Vector2(0, -20))
		"verify":
			if not switch_on:
				if wig.travel > 30.0:
					label("Спершу увімкни фару", false, SWITCH + Vector2(0, -30))
				return
			# count the distance wiggled with the light on, not the number of events
			var step_len := p.distance_to(last_wire_p) if last_wire_p != Vector2.INF else 0.0
			last_wire_p = p
			verify_travel += minf(step_len, 120.0)
			if (verify_travel > 160.0 and _near_connector(p)) or verify_travel > 300.0:
					label("Світло рівне", true, CONN_ZONE + Vector2(0, -50))
					succeed()


func _go_fix() -> void:
	set_step("fix")
	focus = "plug"
	# power off while the connector is worked on
	await get_tree().create_timer(0.6).timeout
	if step == "fix" and switch_on:
		switch_on = false
		Sfx.play("click")
		label("Вимикаємо фару, поки працюємо", true, SWITCH + Vector2(0, -30))


func _seat() -> void:
	if seated:
		return
	seated = true
	plug.value = GAP
	Sfx.play("snap")
	Sfx.buzz(35)
	label("Клац!", true, SOCKET + Vector2(40, -50))
	focus = "wire"
	set_step("verify")


func tick(delta: float) -> void:
	wig.decay(delta)
	disturbing = maxf(0.0, disturbing - delta)
	if wig.active() and active != null and active.id != "switch" and step == "diagnose" and not seated:
		if _near_connector(last_pos) and switch_on:
			disturbing = 0.25
	flick = randf()
	lever = move_toward(lever, 1.0 if switch_on else 0.0, delta * 8.0)
	if spring_back and not seated:
		plug.value = move_toward(plug.value, 0.0, delta * 90.0)
		if plug.value <= 0.0:
			spring_back = false
	# keep hit areas with the moving plug and wire
	targets[1].center = _plug_pos()
	wire_target.pts = _wire_pts()


# ----------------------------------------------------------- painting

func paint_back(ci: CanvasItem) -> void:
	var wagon := variant == "wagon"
	if wagon:
		# car front: painted body panel, grille, bumper
		Paint.shape(ci, Paint.rrect(Rect2(-60, 220, 860, 360), 60), paint_col, 11, 0.28)
		Paint.strokes(ci, Rect2(0, 240, 700, 300), paint_col.lightened(0.35), 12, 22, 30, 3)
		Paint.shape(ci, Paint.rrect(Rect2(400, 300, 380, 150), 18), Color("2f3136"), 12, 0.2)
		for i in 6:
			ci.draw_line(Vector2(410, 320 + i * 22), Vector2(760, 320 + i * 22), Color("5b6068"), 4, true)
		Paint.shape(ci, Paint.rrect(Rect2(-60, 560, 860, 90), 30), Paint.STEEL.darkened(0.1), 13, 0.3)
		# dashboard strip with the light switch, seen through the open door
		Paint.shape(ci, Paint.rrect(Rect2(380, 110, 400, 170), 26), Color("3a3532"), 14, 0.22)
	else:
		# handlebar with grip
		Paint.fill(ci, Paint.capsule(Vector2(-40, 236), Vector2(760, 190), 18), Paint.STEEL, 0.45)
		ci.draw_line(Vector2(-40, 228), Vector2(760, 182), Color(1, 1, 1, 0.35), 4, true)
		Paint.fill(ci, Paint.capsule(Vector2(610, 200), Vector2(760, 190), 24), Paint.RUBBER, 0.2)
		for i in 6:
			var x := 625.0 + i * 22.0
			ci.draw_line(Vector2(x, 180), Vector2(x - 2, 218), Color(1, 1, 1, 0.08), 3, true)
		# fork leg behind the wiring
		Paint.fill(ci, Paint.capsule(Vector2(440, 470), Vector2(480, 1000), 26), Paint.STEEL.darkened(0.15), 0.4)
		ci.draw_line(Vector2(432, 480), Vector2(470, 990), Color(1, 1, 1, 0.25), 5, true)
		# nacelle body, green paint with scuffs
		var body := Paint.ellipse(Vector2(250, 390), 215, 170, 40)
		Paint.shadow(ci, Vector2(270, 560), 230, 50, 0.35)
		Paint.shape(ci, body, paint_col, 5, 0.32, 3.0)
		Paint.strokes(ci, Rect2(80, 270, 330, 230), paint_col.lightened(0.4), 21, 16, 20, 2.5)
		Paint.strokes(ci, Rect2(100, 430, 300, 100), Color(0.95, 0.9, 0.75, 0.6), 4, 6, 10, 2)
		ci.draw_arc(Vector2(250, 390), 200, PI * 1.1, PI * 1.45, 18, paint_col.lightened(0.45), 6, true)
	haze(ci, 0.18)


func paint(ci: CanvasItem) -> void:
	var on := light_on()
	var wagon := variant == "wagon"
	# light glow
	if on:
		Paint.glow(ci, LENS, 330, Color(1.0, 0.86, 0.5, 0.55))
		Paint.glow(ci, LENS, 170, Color(1.0, 0.95, 0.75, 0.6))
	# lens
	if wagon:
		var rr := Rect2(LENS - Vector2(140, 80), Vector2(280, 160))
		Paint.shape(ci, Paint.rrect(rr.grow(14), 30), Paint.CHROME, 31, 0.4)
		Paint.fill(ci, Paint.rrect(rr, 24), Color("fff3cf") if on else Color("3b4656"), 0.25 if on else 0.4)
		for i in 4:
			ci.draw_line(rr.position + Vector2(30 + i * 60, 10), rr.position + Vector2(10 + i * 60, 150), Color(1, 1, 1, 0.12 if on else 0.08), 3, true)
	else:
		Paint.shadow(ci, LENS + Vector2(8, 14), 130, 125, 0.4)
		Paint.fill(ci, Paint.circle(LENS, 120, 40), Paint.CHROME, 0.45)
		ci.draw_arc(LENS, 112, PI * 1.05, PI * 1.6, 20, Color(1, 1, 1, 0.8), 5, true)
		var glass := Color("fff6d6") if on else Color("37424f")
		Paint.fill(ci, Paint.circle(LENS, 98, 40), glass, 0.25 if on else 0.45)
		for r in [30.0, 55.0, 78.0]:
			ci.draw_arc(LENS, r, 0, TAU, 36, Color(1, 1, 1, 0.18 if on else 0.08), 2.0, true)
	if not on:
		ci.draw_line(LENS + Vector2(-60, -40), LENS + Vector2(-10, -80), Color(1, 1, 1, 0.35), 8, true)
		ci.draw_line(LENS + Vector2(-50, -10), LENS + Vector2(-30, -26), Color(1, 1, 1, 0.25), 6, true)
	# switch block
	var sw := Rect2(SWITCH - Vector2(60, 44), Vector2(120, 88))
	Paint.shadow(ci, SWITCH + Vector2(6, 46), 70, 18, 0.4)
	Paint.shape(ci, Paint.rrect(sw, 16), Color("45474f"), 41, 0.3, 2.0)
	var lever_y := lerpf(18.0, -18.0, lever)
	Paint.fill(ci, Paint.rrect(Rect2(SWITCH + Vector2(-16, -26), Vector2(32, 52)), 8), Color("2a2b30"), 0.2)
	Paint.fill(ci, Paint.rrect(Rect2(SWITCH + Vector2(-13, lever_y - 14), Vector2(26, 28)), 7), Color("e9e2d2"), 0.35)
	# small lamp icon on the block
	var ic := SWITCH + Vector2(38, -22)
	ci.draw_circle(ic, 9, Paint.AMBER if switch_on else Color("6b6b70"))
	for k in 3:
		ci.draw_line(ic + Vector2(12, -6 + k * 6), ic + Vector2(20, -8 + k * 8), Paint.AMBER if switch_on else Color("6b6b70"), 2, true)
	# wires: pigtail from the lamp to the socket, main wire from switch to plug
	var pig := _pig_pts()
	_wire(ci, pig, Color("2f2e34"))
	var wpts := _wire_pts()
	_wire(ci, wpts, Color("3a3940"))
	# socket
	Paint.shadow(ci, SOCKET + Vector2(4, 30), 50, 12, 0.4)
	var sock := Rect2(SOCKET - Vector2(38, 25), Vector2(76, 50))
	Paint.shape(ci, Paint.rrect(sock, 8), Color("8b8f94"), 51, 0.35, 2.0)
	ci.draw_rect(Rect2(SOCKET + Vector2(26, -14), Vector2(12, 28)), Color("2a2a2e"))
	# plug
	var pp := _plug_pos()
	var plug_r := Rect2(pp - Vector2(30, 23), Vector2(60, 46))
	if not seated:
		# copper pins visible in the gap
		for k in 3:
			var y := pp.y - 12 + k * 12
			ci.draw_line(Vector2(pp.x - 30, y), Vector2(pp.x - 50, y), Paint.COPPER, 4, true)
	var plug_col := Color("b9bcc0")
	Paint.shadow(ci, pp + Vector2(4, 30), 40, 12, 0.4)
	Paint.shape(ci, Paint.rrect(plug_r, 8), plug_col, 52, 0.35, 2.5)
	ci.draw_line(pp + Vector2(-10, -16), pp + Vector2(-10, 16), Color(0, 0, 0, 0.25), 3, true)
	ci.draw_line(pp + Vector2(4, -16), pp + Vector2(4, 16), Color(0, 0, 0, 0.25), 3, true)
	if step == "fix":
		# ghost target and arrow
		var a := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(SOCKET + Vector2(68, 0), 34, 0, TAU, 32, Color(1, 0.86, 0.4, a), 3, true)
		var ax := pp.x - 46.0 - fmod(t * 30.0, 20.0)
		ci.draw_line(Vector2(pp.x - 36, pp.y + 40), Vector2(ax - 10, pp.y + 40), Color(1, 0.86, 0.4, 0.9), 4, true)
		ci.draw_line(Vector2(ax - 10, pp.y + 40), Vector2(ax + 2, pp.y + 31), Color(1, 0.86, 0.4, 0.9), 4, true)
		ci.draw_line(Vector2(ax - 10, pp.y + 40), Vector2(ax + 2, pp.y + 49), Color(1, 0.86, 0.4, 0.9), 4, true)
	if step == "verify" and switch_on:
		Paint.glow(ci, CONN_ZONE, 90, Color(0.6, 1.0, 0.6, 0.12))


func _wire(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var shadow := Paint.offset(pts, Vector2(5, 8))
	ci.draw_polyline(shadow, Color(0, 0, 0, 0.3), 16, true)
	ci.draw_polyline(pts, col, 14, true)
	ci.draw_polyline(Paint.offset(pts, Vector2(-2, -3)), Color(1, 1, 1, 0.16), 4, true)


# ----------------------------------------------------------- bot

func bot_actions() -> Array:
	var w := _wire_pts()
	match step:
		"diagnose":
			if not switch_on:
				return [{"type": "tap", "at": SWITCH}]
			var near := CONN_ZONE + Vector2(60, -40)
			return [{"type": "drag", "path": PackedVector2Array([near, near + Vector2(30, 10), near + Vector2(-10, -5), near + Vector2(35, 12), near])}]
		"fix":
			var a := _plug_pos()
			return [{"type": "drag", "path": PackedVector2Array([a, a + Vector2(-15, 0), a + Vector2(-30, 0), a + Vector2(-45, 0)])}]
		"verify":
			if not switch_on:
				return [{"type": "tap", "at": SWITCH}]
			var p0 := Gest.path_point(w, 0.85)
			var path := PackedVector2Array()
			for i in 50:
				path.append(p0 + Vector2(sin(i * 0.9) * 26.0, cos(i * 0.7) * 8.0))
			return [{"type": "drag", "path": path}]
	return []
