extends RepairBase
## The side window does not close fully. Hold the switch: the glass stops
## short. The motor pulls fine; the top seal is folded into the opening.
## Push the folded lip back into its channel; hold the switch: full travel.

const FRAME_TOP := 130.0
const GLASS_DOWN := 520.0
const STOP_SHORT := 196.0
const SWITCH := Vector2(190, 780)
const MOTOR := Vector2(520, 800)
const FLAP := Vector2(530, 150)

var glass_y := GLASS_DOWN
var holding := false
var seal := Gest.Slide.new(FLAP + Vector2(0, 46), Vector2.UP, 0.0, 46.0, 0.0)
var flat := false
var stopped_t := 0.0


func build() -> void:
	flat = step == "verify" or step == "done"
	seal.value = 46.0 if flat else 0.0
	glass_y = GLASS_DOWN - 120.0 if step == "fix" else GLASS_DOWN
	targets.clear()
	targets.append(Gest.circle("switch", SWITCH, 70, 3))
	targets.append(Gest.circle("seal", _flap_pos(), 62, 2))
	targets.append(Gest.circle("motor", MOTOR, 70, 1))
	focus = "seal" if step == "fix" else "switch"


func _flap_pos() -> Vector2:
	return seal.pos()


func _limit() -> float:
	return FRAME_TOP if flat else STOP_SHORT


func on_press(id: String, p: Vector2) -> void:
	match id:
		"switch":
			holding = true
			stopped_t = 0.0
		"seal":
			if step == "fix":
				seal.begin(p)
			elif step == "diagnose":
				Sfx.play("tick")
				if discover("seal_bent", false, _flap_pos() + Vector2(-60, -50)):
					set_step("fix")
					focus = "seal"
					_lower_glass()
		"motor":
			if step == "diagnose":
				Sfx.play("motor")
				discover("motor_ok", true, MOTOR + Vector2(0, -80))


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	if id == "seal" and step == "fix":
		seal.update(p)
		if seal.value >= 40.0:
			seal.value = 46.0
			flat = true
			Sfx.play("snap")
			Sfx.buzz(30)
			label("Ущільнювач рівно", true, FLAP + Vector2(-80, 80))
			set_step("verify")
			focus = "switch"


func on_release(id: String, _p: Vector2) -> void:
	if id == "switch":
		holding = false
		Sfx.stop_loop()
	if id == "seal" and step == "fix" and not flat:
		spring(seal, "value", 0.0, 0.25)


func _lower_glass() -> void:
	var tw := create_tween()
	Sfx.play("motor")
	tw.tween_property(self, "glass_y", GLASS_DOWN - 120.0, 0.8)


func tick(delta: float) -> void:
	if holding and step != "done":
		var lim := _limit()
		if glass_y > lim + 0.5:
			glass_y = maxf(lim, glass_y - 260.0 * delta)
			Sfx.loop("motor")
		else:
			Sfx.stop_loop()
			stopped_t += delta
			if stopped_t > 0.25 and stopped_t - delta <= 0.25:
				Sfx.play("thud")
			if stopped_t > 0.3:
				if step == "diagnose" and not flat:
					discover("gap", false, Vector2(360, 240))
				elif step == "verify" and flat:
					label("Повний хід — до кінця!", true, Vector2(360, 240))
					holding = false
					succeed()
	targets[1].center = _flap_pos()


func paint_back(ci: CanvasItem) -> void:
	# outside: blurred street through the window
	ci.draw_polygon(PackedVector2Array([Vector2(60, 100), Vector2(680, 100), Vector2(680, 540), Vector2(60, 540)]),
		PackedColorArray([Color("c8dbe6"), Color("d7e5ec"), Color("9fb78e"), Color("8faa80")]))
	Paint.glow(ci, Vector2(200, 260), 160, Color(1, 1, 0.95, 0.35))
	Paint.glow(ci, Vector2(560, 420), 120, Color(0.6, 0.75, 0.55, 0.4))
	# door trim panel
	var trim := Color("b9a789")
	Paint.shape(ci, PackedVector2Array([Vector2(-80, 530), Vector2(800, 530), Vector2(800, 1100), Vector2(-80, 1100)]), trim, 131, 0.28)
	Paint.strokes(ci, Rect2(0, 560, 720, 360), trim.lightened(0.25), 132, 20, 40, 3)
	# armrest
	Paint.fill(ci, Paint.rrect(Rect2(40, 720, 380, 110), 40), trim.darkened(0.25), 0.3)
	# motor cover with screws
	Paint.fill(ci, Paint.rrect(Rect2(MOTOR - Vector2(90, 60), Vector2(180, 120)), 20), trim.darkened(0.12), 0.25)
	for s in [Vector2(-66, -38), Vector2(66, -38), Vector2(-66, 38), Vector2(66, 38)]:
		Paint.screw(ci, MOTOR + s, 7)
	Paint.text(ci, MOTOR + Vector2(0, 8), "мотор", 20, Color(0.3, 0.24, 0.18, 0.7))


func paint(ci: CanvasItem) -> void:
	var body := Color(order.get("paint", "#86a9b8"))
	# glass pane
	var g := PackedVector2Array([Vector2(110, glass_y), Vector2(640, glass_y), Vector2(640, glass_y + 420), Vector2(110, glass_y + 420)])
	ci.draw_colored_polygon(g, Color(0.75, 0.88, 0.95, 0.35))
	ci.draw_line(Vector2(140, glass_y + 30), Vector2(260, glass_y + 6), Color(1, 1, 1, 0.45), 8, true)
	ci.draw_line(Vector2(110, glass_y), Vector2(640, glass_y), Color(1, 1, 1, 0.55), 4, true)
	# door frame around the window
	Paint.fill(ci, PackedVector2Array([Vector2(40, 80), Vector2(700, 80), Vector2(700, 112), Vector2(40, 112)]), body.darkened(0.15), 0.25)
	Paint.fill(ci, PackedVector2Array([Vector2(40, 80), Vector2(84, 80), Vector2(84, 540), Vector2(40, 540)]), body.darkened(0.2), 0.25)
	Paint.fill(ci, PackedVector2Array([Vector2(660, 80), Vector2(700, 80), Vector2(700, 540), Vector2(660, 540)]), body.darkened(0.25), 0.25)
	# top seal
	ci.draw_line(Vector2(84, FRAME_TOP - 10), Vector2(660, FRAME_TOP - 10), Color("1d1c20"), 20, true)
	var fp := _flap_pos()
	if not flat:
		var flap := PackedVector2Array([Vector2(fp.x - 70, FRAME_TOP - 6), Vector2(fp.x + 70, FRAME_TOP - 6), Vector2(fp.x + 56, fp.y + 22), Vector2(fp.x - 60, fp.y + 26)])
		Paint.fill(ci, flap, Color("2a292e") if not has_found("seal_bent") else Color("4a2b25"), 0.3)
		ci.draw_line(Vector2(fp.x - 60, fp.y + 24), Vector2(fp.x + 56, fp.y + 20), Color(1, 1, 1, 0.15), 3, true)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_line(fp + Vector2(100, 40), fp + Vector2(100, -10), Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_line(fp + Vector2(100, -10), fp + Vector2(88, 4), Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_line(fp + Vector2(100, -10), fp + Vector2(112, 4), Color(1, 0.86, 0.4, a2), 5, true)
	# the gap above the glass
	if glass_y <= STOP_SHORT + 1.0 and not flat:
		ci.draw_line(Vector2(140, FRAME_TOP + 6), Vector2(140, glass_y - 4), Color(Paint.BAD, 0.8), 3, true)
	# window switch
	Paint.shadow(ci, SWITCH + Vector2(6, 10), 60, 30, 0.4)
	Paint.fill(ci, Paint.rrect(Rect2(SWITCH - Vector2(56, 36), Vector2(112, 72)), 18), Color("2f2e33"), 0.3)
	Paint.fill(ci, Paint.rrect(Rect2(SWITCH - Vector2(40, 26), Vector2(80, 52)), 14), Color("f0e6cf") if holding else Color("d9cfb8"), 0.3)
	Paint.text(ci, SWITCH + Vector2(0, 12), "▲", 30, Paint.INK)


func bot_actions() -> Array:
	match step:
		"diagnose":
			if not has_found("gap"):
				return [{"type": "hold", "at": SWITCH, "frames": 120}]
			return [{"type": "tap", "at": _flap_pos()}, {"type": "wait", "frames": 60}]
		"fix":
			var a := _flap_pos()
			var path := PackedVector2Array()
			for i in 12:
				path.append(a + Vector2(0, -56.0 * i / 11.0))
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "hold", "at": SWITCH, "frames": 150}]
	return []
