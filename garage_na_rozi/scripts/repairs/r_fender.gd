extends RepairBase
## The front fender rattles on bumps. A light shake makes it bounce; the
## front bolt is tight, the clamp on the fork stays is open. Swing the clamp
## lever shut (click) and shake again: the fender no longer jumps.

const WHEEL := Vector2(330, 900)
const FENDER_C := Vector2(330, 900)
const BOLT := Vector2(140, 520)
const CLAMP := Vector2(560, 470)
const OPEN := -1.25
const SHUT := 0.0

var bounce := 0.0
var bounce_v := 0.0
var lever := Gest.Turn.new(CLAMP, OPEN, OPEN, SHUT)
var closed := false


func build() -> void:
	closed = step == "verify" or step == "done"
	lever.angle = SHUT if closed else OPEN
	targets.clear()
	targets.append(Gest.circle("clamp", CLAMP + Vector2(40, 0), 70, 3))
	targets.append(Gest.circle("bolt", BOLT, 60, 2))
	var arc := PackedVector2Array()
	for i in 17:
		var a := PI * 1.08 + PI * 0.84 * i / 16.0
		arc.append(FENDER_C + Vector2(cos(a), sin(a)) * 330)
	targets.append(Gest.path("fender", arc, 50, 1))
	focus = "clamp" if step == "fix" else ("fender" if step == "verify" else "")


func on_press(id: String, p: Vector2) -> void:
	match id:
		"fender":
			_shake()
		"bolt":
			Sfx.play("tick")
			discover("bolt_ok", true, BOLT + Vector2(0, -70))
		"clamp":
			lever.begin(p)
			if step == "diagnose":
				Sfx.play("rattle")
				bounce_v = 40.0
				if discover("clamp_open", false, CLAMP + Vector2(0, -90)):
					set_step("fix")
					focus = "clamp"


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	if id == "clamp" and step == "fix":
		lever.update(p)
		if lever.angle >= SHUT - 0.08:
			lever.angle = SHUT
			closed = true
			Sfx.play("latch")
			Sfx.buzz(35)
			label("Клац!", true, CLAMP + Vector2(0, -90))
			set_step("verify")
			focus = "fender"
	elif id == "fender":
		pass


func on_release(id: String, _p: Vector2) -> void:
	if id == "clamp" and step == "fix" and not closed:
		spring(lever, "angle", OPEN, 0.3)


func _shake() -> void:
	match step:
		"diagnose":
			bounce_v = 140.0
			Sfx.play("rattle")
			discover("rattle", false, Vector2(330, 520))
		"fix":
			bounce_v = 120.0
			Sfx.play("rattle")
		"verify":
			bounce_v = 12.0
			Sfx.play("thud")
			label("Крило стоїть", true, Vector2(330, 520))
			succeed()


func tick(delta: float) -> void:
	# a sprung bounce: loose fender jumps, a clamped one barely moves
	var k := 260.0 if not closed else 900.0
	var damp := 4.0 if not closed else 18.0
	bounce_v += (-bounce * k - bounce_v * damp) * delta
	bounce += bounce_v * delta
	if not closed and absf(bounce_v) > 50.0 and fmod(t, 0.12) < delta:
		Sfx.play("tick", 1.3, -10.0)


func paint_back(ci: CanvasItem) -> void:
	# fork legs and lower shield
	Paint.fill(ci, Paint.capsule(Vector2(520, -40), Vector2(590, 900), 26), Paint.STEEL.darkened(0.15), 0.4)
	ci.draw_line(Vector2(512, -30), Vector2(580, 890), Color(1, 1, 1, 0.22), 5, true)
	var paint_col := Color(order.get("paint", "#5f8f4e"))
	Paint.shape(ci, PackedVector2Array([Vector2(-60, -60), Vector2(420, -60), Vector2(360, 200), Vector2(-60, 260)]), paint_col.darkened(0.2), 4, 0.25)
	haze(ci, 0.14)


func paint(ci: CanvasItem) -> void:
	var paint_col := Color(order.get("paint", "#5f8f4e"))
	var b := Vector2(0, -bounce * 0.6)
	# tire under the fender
	Paint.fill(ci, Paint.circle(WHEEL, 300, 56), Paint.RUBBER, 0.25)
	ci.draw_arc(WHEEL, 250, 0, TAU, 48, Paint.CHROME, 10, true)
	for i in 14:
		var a := PI + PI * i / 13.0
		ci.draw_line(WHEEL + Vector2(cos(a), sin(a)) * 286, WHEEL + Vector2(cos(a), sin(a)) * 300, Color(1, 1, 1, 0.06), 10, true)
	# fender arc (with scuffs)
	var outer := Paint.arc_pts(FENDER_C + b, 362, PI * 1.05, PI * 1.95, 30)
	var inner := Paint.arc_pts(FENDER_C + b, 316, PI * 1.95, PI * 1.05, 30)
	var fender := outer + inner
	Paint.shadow(ci, FENDER_C + b + Vector2(0, -300), 340, 60, 0.3)
	Paint.fill(ci, fender, paint_col, 0.35)
	ci.draw_arc(FENDER_C + b, 352, PI * 1.15, PI * 1.5, 24, paint_col.lightened(0.45), 6, true)
	ci.draw_arc(FENDER_C + b, 322, PI * 1.08, PI * 1.92, 30, paint_col.darkened(0.35), 4, true)
	Paint.strokes(ci, Rect2(80, 560, 500, 60), Color(0.95, 0.92, 0.8, 0.6), 13, 10, 10, 2)
	# front bolt
	Paint.bolt(ci, BOLT + b * 0.3, 18)
	# stay from fender to the clamp
	var stay_a := FENDER_C + b + Vector2(cos(PI * 1.72), sin(PI * 1.72)) * 330
	ci.draw_line(stay_a, CLAMP, Paint.STEEL, 10, true)
	ci.draw_line(stay_a + Vector2(-2, -3), CLAMP + Vector2(-2, -3), Color(1, 1, 1, 0.3), 3, true)
	# clamp band on the fork with its lever
	var gap := 0.0 if closed else 10.0
	Paint.fill(ci, Paint.rrect(Rect2(CLAMP - Vector2(40, 34 + gap), Vector2(80, 26)), 8), Color("5c626c"), 0.35)
	Paint.fill(ci, Paint.rrect(Rect2(CLAMP - Vector2(40, -8 - gap), Vector2(80, 26)), 8), Color("5c626c"), 0.35)
	var la := lever.angle
	var tip := CLAMP + Vector2(cos(la), sin(la)) * 110
	Paint.shadow(ci, tip + Vector2(6, 10), 40, 14, 0.35)
	Paint.fill(ci, Paint.capsule(CLAMP, tip, 14), Paint.CHROME, 0.4)
	ci.draw_circle(CLAMP, 16, Paint.METAL_DARK)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(CLAMP, 120, OPEN + 0.1, SHUT, 20, Color(1, 0.86, 0.4, a2), 5, true)
		var end := CLAMP + Vector2(cos(SHUT), sin(SHUT)) * 120
		ci.draw_line(end, end + Vector2(-12, -14), Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_line(end, end + Vector2(12, -14), Color(1, 0.86, 0.4, a2), 5, true)
	if not closed and absf(bounce) > 4.0:
		for i in 3:
			var p := Vector2(250 + i * 70, 500 - absf(bounce) * 0.4)
			ci.draw_line(p, p + Vector2(-10, -18), Color(1, 0.95, 0.8, 0.7), 3, true)
			ci.draw_line(p + Vector2(8, 0), p + Vector2(18, -16), Color(1, 0.95, 0.8, 0.7), 3, true)


func bot_actions() -> Array:
	match step:
		"diagnose":
			if not has_found("rattle"):
				return [{"type": "tap", "at": Vector2(330, 570)}, {"type": "wait", "frames": 20}]
			return [{"type": "tap", "at": CLAMP + Vector2(60, -40)}]
		"fix":
			var path := PackedVector2Array()
			for i in 16:
				var a := lerpf(OPEN, SHUT + 0.1, i / 15.0)
				path.append(CLAMP + Vector2(cos(a), sin(a)) * 95)
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "tap", "at": Vector2(330, 570)}]
	return []
