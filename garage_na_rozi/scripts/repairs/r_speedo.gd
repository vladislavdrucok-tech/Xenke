extends RepairBase
## Speedometer stays at zero. On the stand, spin the front wheel: the needle
## does not move. The needle itself is free; the cable hangs loose from the
## hub drive. Bring the cable end to the drive socket, spin again: it rises.

const WHEEL := Vector2(300, 640)
const R_TIRE := 235.0
const SOCKET := Vector2(372, 668)
const GAUGE := Vector2(560, 190)
const CABLE_TOP := Vector2(640, -20)
const HANG := Vector2(560, 800)

var spin := 0.0          # wheel angle
var omega := 0.0         # angular speed rad/s
var needle := 0.0        # 0..1
var needle_kick := 0.0
var cable_end := HANG
var attached := false
var dragging_cable := false
var swing := 0.0
var spun_dist := 0.0


func build() -> void:
	attached = step == "verify" or step == "done"
	cable_end = SOCKET if attached else HANG
	targets.clear()
	targets.append(Gest.circle("cable", cable_end, 60, 3))
	targets.append(Gest.circle("gauge", GAUGE, 120, 2))
	targets.append(Gest.circle("hub", SOCKET + Vector2(-30, -10), 58, 2))
	var tire := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		tire.append(WHEEL + Vector2(cos(a), sin(a)) * (R_TIRE - 22))
	targets.append(Gest.path("tire", tire, 40, 0))
	focus = "cable" if step == "fix" else ("tire" if step == "verify" else "")


func _cable_pts() -> PackedVector2Array:
	var mid := (CABLE_TOP + cable_end) * 0.5 + Vector2(90 + sin(t * 2.0) * swing * 20.0, 40)
	return Paint.bezier(CABLE_TOP, CABLE_TOP + Vector2(10, 260), mid + Vector2(40, 120), cable_end, 24)


func on_press(id: String, p: Vector2) -> void:
	match id:
		"cable":
			if step == "fix":
				dragging_cable = true
			elif step == "diagnose":
				Sfx.play("tick")
				swing = 1.0
				if discover("cable_off", false, cable_end + Vector2(0, -70)):
					set_step("fix")
					focus = "cable"
		"hub":
			if step == "diagnose":
				label("Гніздо приводу порожнє", false, SOCKET + Vector2(0, -60))
				if discover("cable_off", false, cable_end + Vector2(0, -70)):
					set_step("fix")
					focus = "cable"
		"gauge":
			needle_kick = 0.6
			Sfx.play("tick")
			if step == "diagnose":
				discover("needle_ok", true, GAUGE + Vector2(0, 100))
		"tire":
			pass


func on_drag(id: String, p: Vector2, prev: Vector2) -> void:
	match id:
		"cable":
			if step == "fix" and dragging_cable:
				cable_end = p
				if p.distance_to(SOCKET) < 46.0:
					_attach()
		"tire":
			var d := Gest.angle_delta(WHEEL, prev, p)
			omega = clampf(omega + d * 22.0, -26.0, 26.0)
			spun_dist += absf(d)
			if spun_dist > 0.7:
				Sfx.loop("tick", 0.8 + absf(omega) * 0.05)


func on_release(id: String, _p: Vector2) -> void:
	if id == "cable" and step == "fix" and not attached:
		dragging_cable = false
		swing = 1.0
	Sfx.stop_loop()


func _attach() -> void:
	attached = true
	omega = 0.0
	spun_dist = 0.0
	dragging_cable = false
	cable_end = SOCKET
	Sfx.play("snap")
	Sfx.buzz(30)
	label("Трос на місці", true, SOCKET + Vector2(0, -70))
	set_step("verify")
	focus = "tire"


func tick(delta: float) -> void:
	spin += omega * delta
	omega = move_toward(omega, 0.0, delta * 4.0)
	swing = maxf(0.0, swing - delta * 0.8)
	if not dragging_cable and not attached:
		cable_end = cable_end.lerp(HANG + Vector2(sin(t * 2.0) * swing * 30.0, 0), delta * 4.0)
	var want := 0.0
	if attached:
		want = clampf(absf(omega) / 22.0, 0.0, 1.0)
	needle_kick = maxf(0.0, needle_kick - delta * 1.2)
	needle = move_toward(needle, maxf(want, needle_kick), delta * 1.5)
	if absf(omega) > 6.0 and spun_dist > 0.7:
		if step == "diagnose":
			discover("needle_zero", false, GAUGE + Vector2(0, 100))
		elif step == "verify" and needle > 0.35:
			label("Стрілка піднімається!", true, GAUGE + Vector2(0, 100))
			succeed()
	if absf(omega) < 1.0:
		spun_dist = 0.0
	targets[0].center = cable_end


func paint_back(ci: CanvasItem) -> void:
	# stand frame and floor
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-200, 900), Vector2(920, 900), Vector2(920, 1400), Vector2(-200, 1400)]), Color("2b2622"))
	Paint.fill(ci, Paint.rrect(Rect2(-60, 880, 840, 34), 8), Color("d9a62e"), 0.3)
	ci.draw_line(Vector2(120, 880), Vector2(260, 700), Color("c1922a"), 16, true)
	ci.draw_line(Vector2(480, 880), Vector2(340, 700), Color("c1922a"), 16, true)
	# fork legs
	Paint.fill(ci, Paint.capsule(Vector2(250, -40), Vector2(286, 640), 22), Paint.STEEL.darkened(0.1), 0.4)
	Paint.fill(ci, Paint.capsule(Vector2(380, -40), Vector2(318, 640), 22), Paint.STEEL.darkened(0.2), 0.4)
	haze(ci, 0.12)


func paint(ci: CanvasItem) -> void:
	# wheel: tire, rim, spokes
	Paint.shadow(ci, WHEEL + Vector2(10, 260), 230, 30, 0.45)
	Paint.fill(ci, Paint.circle(WHEEL, R_TIRE, 48), Paint.RUBBER, 0.25)
	for i in 24:
		var a := spin + TAU * i / 24.0
		var p0 := WHEEL + Vector2(cos(a), sin(a)) * (R_TIRE - 6)
		ci.draw_line(p0, p0 + Vector2(cos(a), sin(a)) * -14, Color(1, 1, 1, 0.07), 6, true)
	ci.draw_arc(WHEEL, R_TIRE - 46, 0, TAU, 48, Paint.CHROME, 12, true)
	for i in 18:
		var a := spin + TAU * i / 18.0
		ci.draw_line(WHEEL + Vector2(cos(a), sin(a)) * 46, WHEEL + Vector2(cos(a + 0.3), sin(a + 0.3)) * (R_TIRE - 50), Color(0.82, 0.85, 0.88, 0.9), 3, true)
	ci.draw_arc(WHEEL, R_TIRE - 10, PI * 1.1, PI * 1.45, 16, Color(1, 1, 1, 0.12), 6, true)
	# hub with speedometer drive
	Paint.fill(ci, Paint.circle(WHEEL, 58, 28), Paint.STEEL, 0.4)
	ci.draw_circle(WHEEL, 18, Paint.METAL_DARK)
	Paint.fill(ci, Paint.rrect(Rect2(SOCKET - Vector2(38, 24), Vector2(60, 48)), 10), Color("5a5f68"), 0.35)
	ci.draw_circle(SOCKET, 13, Color("1d1d20") if not attached else Paint.STEEL)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(SOCKET, 30, 0, TAU, 28, Color(1, 0.86, 0.4, a2), 4, true)
	# speedometer gauge
	Paint.shadow(ci, GAUGE + Vector2(8, 14), 130, 125, 0.4)
	Paint.fill(ci, Paint.circle(GAUGE, 128, 40), Paint.CHROME, 0.4)
	Paint.fill(ci, Paint.circle(GAUGE, 112, 40), Color("f1e8d4"), 0.15)
	for i in 7:
		var a := PI * 0.8 + (PI * 1.4) * i / 6.0
		ci.draw_line(GAUGE + Vector2(cos(a), sin(a)) * 92, GAUGE + Vector2(cos(a), sin(a)) * 106, Paint.INK, 4, true)
		Paint.text(ci, GAUGE + Vector2(cos(a), sin(a)) * 72 + Vector2(0, 8), str(i * 10), 20, Paint.INK)
	Paint.text(ci, GAUGE + Vector2(0, 50), "км/год", 18, Color(0.3, 0.25, 0.2))
	var na := PI * 0.8 + PI * 1.4 * needle
	ci.draw_line(GAUGE, GAUGE + Vector2(cos(na), sin(na)) * 96, Color("c7443a"), 6, true)
	ci.draw_circle(GAUGE, 12, Paint.METAL_DARK)
	# the cable
	var cp := _cable_pts()
	ci.draw_polyline(Paint.offset(cp, Vector2(6, 8)), Color(0, 0, 0, 0.3), 18, true)
	ci.draw_polyline(cp, Color("26252a"), 16, true)
	ci.draw_polyline(Paint.offset(cp, Vector2(-2, -3)), Color(1, 1, 1, 0.12), 4, true)
	Paint.fill(ci, Paint.capsule(cable_end + Vector2(18, -26), cable_end, 13), Paint.STEEL, 0.4)
	ci.draw_circle(cable_end, 7, Color("8a6a2a"))
	if step == "fix" and not dragging_cable:
		var ax := cable_end.lerp(SOCKET, 0.25 + fmod(t, 1.0) * 0.4)
		ci.draw_circle(ax, 6, Color(1, 0.86, 0.4, 0.8))
	if step == "diagnose" or step == "verify":
		# swipe hint on the tire
		var a3 := 0.45 + 0.3 * sin(t * 4.0)
		ci.draw_arc(WHEEL, R_TIRE + 22, PI * 0.25, PI * 0.75, 20, Color(1, 0.86, 0.4, a3 * 0.6), 4, true)


func bot_actions() -> Array:
	var swipe := PackedVector2Array()
	for i in 14:
		var a := PI * 0.75 - i * 0.07
		swipe.append(WHEEL + Vector2(cos(a), sin(a)) * (R_TIRE - 22))
	match step:
		"diagnose":
			if not has_found("needle_zero"):
				return [{"type": "drag", "path": swipe}, {"type": "wait", "frames": 20}]
			return [{"type": "tap", "at": cable_end}]
		"fix":
			var path := PackedVector2Array()
			for i in 12:
				path.append(cable_end.lerp(SOCKET, i / 11.0))
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "drag", "path": swipe}, {"type": "wait", "frames": 30}]
	return []
