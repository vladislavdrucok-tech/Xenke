extends RepairBase
## The side stand swings loose. Lift it: it drops back down. The pivot holds;
## the return spring hangs by one end. Hook the free end onto the frame pin,
## then lift the stand: the spring pulls it home and holds it.

const PIVOT := Vector2(300, 330)
const PIN := Vector2(520, 250)
const LEG := 420.0
const DOWN := 1.75               # angle pointing down-left (deployed)
const UP := 0.12                 # stowed along the frame

var leg := Gest.Turn.new(PIVOT, DOWN, UP, 2.1)
var leg_v := 0.0
var hooked := false
var hook_end := Vector2.ZERO
var dragging_hook := false
var lifted_once := false


func build() -> void:
	hooked = step == "verify" or step == "done"
	leg.angle = DOWN
	hook_end = PIN if hooked else _hang()
	targets.clear()
	targets.append(Gest.circle("leg", _foot().lerp(PIVOT, 0.35), 80, 1))
	targets.append(Gest.circle("pivot", PIVOT, 50, 2))
	targets.append(Gest.circle("hook", hook_end, 60, 3))
	focus = "hook" if step == "fix" else ("leg" if step == "verify" else "")


func _foot() -> Vector2:
	return PIVOT + Vector2(cos(leg.angle), sin(leg.angle)) * LEG


func _anchor() -> Vector2:
	# where the spring is fixed on the stand
	return PIVOT + Vector2(cos(leg.angle), sin(leg.angle)) * 90


func _hang() -> Vector2:
	return _anchor() + Vector2(40, 120)


func on_press(id: String, p: Vector2) -> void:
	match id:
		"leg":
			leg.begin(p)
			leg_v = 0.0
		"pivot":
			Sfx.play("tick")
			discover("pivot_ok", true, PIVOT + Vector2(0, -60))
		"hook":
			if step == "fix":
				dragging_hook = true
			elif step == "diagnose":
				Sfx.play("spring")
				if discover("spring_free", false, hook_end + Vector2(0, -70)):
					set_step("fix")
					focus = "hook"


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	match id:
		"leg":
			if step == "fix":
				return
			leg.update(p)
		"hook":
			if step == "fix" and dragging_hook:
				hook_end = p
				if p.distance_to(PIN) < 44.0:
					hooked = true
					dragging_hook = false
					hook_end = PIN
					Sfx.play("spring")
					Sfx.buzz(30)
					label("Зачепилась!", true, PIN + Vector2(0, -60))
					set_step("verify")
					focus = "leg"


func on_release(id: String, _p: Vector2) -> void:
	if id == "leg":
		var lifted := leg.angle < DOWN - 0.6
		if not hooked:
			leg_v = 0.0
			if lifted:
				lifted_once = true
				Sfx.play("thud")
				if step == "diagnose":
					discover("falls", false, PIVOT + Vector2(-60, 160))
		else:
			if lifted and step == "verify":
				Sfx.play("spring")
				var tw := create_tween()
				tw.tween_property(leg, "angle", UP, 0.25).set_trans(Tween.TRANS_BACK)
				Sfx.play("latch")
				label("Пружина тримає!", true, PIVOT + Vector2(80, -70))
				succeed()
	if id == "hook" and step == "fix" and not hooked:
		dragging_hook = false


func tick(delta: float) -> void:
	var holding := active != null and active.id == "leg"
	if not holding and not (hooked and step == "done"):
		# gravity swings the loose stand back down like a pendulum
		var target := DOWN
		leg_v += (target - leg.angle) * 30.0 * delta - leg_v * 2.2 * delta
		leg.angle = clampf(leg.angle + leg_v * delta, UP, 2.1)
	if not dragging_hook and not hooked:
		hook_end = hook_end.lerp(_hang(), delta * 6.0)
	elif hooked and not dragging_hook:
		hook_end = PIN
	targets[0].center = _foot().lerp(PIVOT, 0.35)
	targets[2].center = hook_end


func paint_back(ci: CanvasItem) -> void:
	var paint_col := Color(order.get("paint", "#2f5e6e"))
	# floor and the bike's lower frame, exhaust and engine out of focus
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-200, 820), Vector2(920, 760), Vector2(920, 1400), Vector2(-200, 1400)]), Color("4a443e"))
	Paint.fill(ci, Paint.rrect(Rect2(380, 120, 400, 260), 40), Paint.METAL.darkened(0.2), 0.35)
	Paint.fill(ci, Paint.capsule(Vector2(-60, 470), Vector2(780, 520), 26), Paint.CHROME.darkened(0.25), 0.4)
	Paint.fill(ci, Paint.capsule(Vector2(-60, 120), Vector2(760, 300), 26), Paint.METAL_DARK, 0.35)
	Paint.shape(ci, PackedVector2Array([Vector2(-60, -60), Vector2(500, -60), Vector2(460, 90), Vector2(-60, 120)]), paint_col, 71, 0.3)
	haze(ci, 0.14)


func paint(ci: CanvasItem) -> void:
	var foot := _foot()
	# frame pin
	Paint.shadow(ci, PIN + Vector2(4, 8), 26, 14, 0.4)
	ci.draw_circle(PIN, 16, Paint.STEEL)
	ci.draw_circle(PIN, 7, Paint.METAL_DARK)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(PIN, 32, 0, TAU, 24, Color(1, 0.86, 0.4, a2), 4, true)
	# the stand leg
	Paint.shadow(ci, foot + Vector2(10, 14), 60, 16, 0.4)
	Paint.fill(ci, Paint.capsule(PIVOT, foot, 20), Color("2c2d33"), 0.35)
	ci.draw_line(PIVOT + Vector2(-6, -6), foot + Vector2(-6, -6), Color(1, 1, 1, 0.12), 5, true)
	Paint.fill(ci, Paint.ellipse(foot, 38, 16, 18, leg.angle), Color("1f2024"), 0.3)
	Paint.bolt(ci, PIVOT, 24)
	# the spring from the stand anchor to the hook end
	var a := _anchor()
	var e := hook_end
	var pts := PackedVector2Array()
	var n := 22
	var d := e - a
	var nrm := d.orthogonal().normalized()
	var coil := 12.0 if d.length() < 260 else 8.0
	for i in n + 1:
		var tt := float(i) / n
		var off := 0.0 if i == 0 or i == n else (coil if i % 2 == 0 else -coil)
		pts.append(a + d * tt + nrm * off)
	ci.draw_polyline(Paint.offset(pts, Vector2(4, 6)), Color(0, 0, 0, 0.3), 6, true)
	ci.draw_polyline(pts, Color("b9bfc6"), 5, true)
	ci.draw_arc(e + Vector2(0, -8), 10, 0, PI * 1.5, 10, Color("b9bfc6"), 5, true)
	ci.draw_circle(a, 9, Paint.METAL_DARK)
	if step == "verify":
		var a3 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(PIVOT, 200, DOWN - 0.9, DOWN - 0.2, 20, Color(1, 0.86, 0.4, a3), 5, true)


func bot_actions() -> Array:
	var lift := PackedVector2Array()
	var a0 := leg.angle
	for i in 16:
		var aa := lerpf(a0, UP + 0.1, i / 15.0)
		lift.append(PIVOT + Vector2(cos(aa), sin(aa)) * (LEG * 0.65))
	match step:
		"diagnose":
			if not has_found("falls"):
				return [{"type": "drag", "path": lift}, {"type": "wait", "frames": 30}]
			return [{"type": "tap", "at": hook_end}]
		"fix":
			var path := PackedVector2Array()
			for i in 12:
				path.append(hook_end.lerp(PIN, i / 11.0))
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "drag", "path": lift}, {"type": "wait", "frames": 20}]
	return []
