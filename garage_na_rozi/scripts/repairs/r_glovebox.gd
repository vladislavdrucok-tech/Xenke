extends RepairBase
## The glove box opens by itself. Close the lid: it drops open again. The
## hinges are whole; the latch sits outside its groove. Slide the latch into
## the groove, close the lid and let go: it stays shut.

const OPEN_R := Rect2(170, 330, 380, 210)
const HINGE_Y := 540.0
const TRACK := Vector2(360, 290)
const OFF := 84.0

var lid := 1.0                 # 1 open .. 0 shut
var lid_target := 1.0
var latch := Gest.Slide.new(Vector2(TRACK.x + OFF, TRACK.y), Vector2.LEFT, 0.0, OFF, 0.0)
var engaged := false
var shut_timer := -1.0
var held_shut := 0.0


func build() -> void:
	engaged = step == "verify" or step == "done"
	latch.value = OFF if engaged else 0.0
	lid = 1.0
	lid_target = 1.0
	targets.clear()
	targets.append(Gest.rect("lid", Rect2(OPEN_R.position.x - 20, OPEN_R.position.y, OPEN_R.size.x + 40, 520), 1))
	targets.append(Gest.circle("latch", latch.pos(), 60, 3))
	targets.append(Gest.circle("hinge_l", Vector2(OPEN_R.position.x + 20, HINGE_Y), 50, 2))
	targets.append(Gest.circle("hinge_r", Vector2(OPEN_R.end.x - 20, HINGE_Y), 50, 2))
	focus = "latch" if step == "fix" else "lid"


func on_press(id: String, p: Vector2) -> void:
	match id:
		"lid":
			_close_lid()
		"latch":
			if step == "fix":
				latch.begin(p)
			elif step == "diagnose":
				Sfx.play("tick")
				if discover("latch_off", false, latch.pos() + Vector2(0, -70)):
					set_step("fix")
					focus = "latch"
		"hinge_l", "hinge_r":
			Sfx.play("creak")
			discover("hinge_ok", true, Vector2(360, HINGE_Y + 80))


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	if id == "latch" and step == "fix":
		latch.update(p)
		if latch.value >= OFF - 6.0:
			latch.value = OFF
			engaged = true
			Sfx.play("snap")
			Sfx.buzz(30)
			label("Засувка в пазу", true, TRACK + Vector2(0, -60))
			set_step("verify")
			focus = "lid"


func on_release(id: String, _p: Vector2) -> void:
	if id == "latch" and step == "fix" and not engaged:
		spring(latch, "value", 0.0, 0.25)


func _close_lid() -> void:
	if lid_target == 0.0 and lid < 0.05 and engaged:
		return
	lid_target = 0.0
	Sfx.play("swish")
	shut_timer = 0.35


func tick(delta: float) -> void:
	lid = move_toward(lid, lid_target, delta * (4.0 if lid_target == 0.0 else 2.6))
	if shut_timer >= 0.0:
		shut_timer -= delta
		if shut_timer < 0.0:
			if engaged:
				Sfx.play("latch")
				held_shut = 0.0
			else:
				Sfx.play("click", 0.7)
				lid_target = 1.0
				await get_tree().create_timer(0.35).timeout
				if is_inside_tree():
					Sfx.play("thud")
					if step == "diagnose":
						discover("falls_open", false, Vector2(360, 760))
	if engaged and lid_target == 0.0 and lid < 0.02 and step == "verify":
		held_shut += delta
		if held_shut > 0.6:
			label("Кришка тримається", true, Vector2(360, 260))
			succeed()
	targets[1].center = latch.pos()


func paint_back(ci: CanvasItem) -> void:
	var wagon := variant == "wagon"
	var dash := Color("8a7a66") if not wagon else Color("6b5a4c")
	# dashboard shapes
	Paint.shape(ci, PackedVector2Array([Vector2(-80, 120), Vector2(800, 80), Vector2(800, 640), Vector2(-80, 660)]), dash, 111, 0.28)
	Paint.shape(ci, PackedVector2Array([Vector2(-80, 40), Vector2(800, 0), Vector2(800, 140), Vector2(-80, 170)]), dash.darkened(0.25), 112, 0.25)
	Paint.strokes(ci, Rect2(0, 160, 720, 420), dash.lightened(0.25), 113, 22, 40, 3)
	# seat and floor below, out of focus
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-80, 640), Vector2(800, 620), Vector2(800, 1100), Vector2(-80, 1100)]), Color("2f2a27"))
	# latch track on the frame above the opening
	Paint.fill(ci, Paint.rrect(Rect2(TRACK - Vector2(60, 16), Vector2(180, 32)), 10), Color("3a3532"), 0.2)
	ci.draw_rect(Rect2(TRACK + Vector2(-14, -8), Vector2(28, 16)), Color("141210"))
	Paint.text(ci, TRACK + Vector2(0, -26), "паз", 18, Color(1, 0.95, 0.85, 0.55))
	# the opening (dark cavity with maps)
	ci.draw_colored_polygon(Paint.rrect(OPEN_R, 18), Color("1c1916"))
	ci.draw_colored_polygon(PackedVector2Array([OPEN_R.position + Vector2(40, 120), OPEN_R.position + Vector2(200, 100), OPEN_R.position + Vector2(210, 200), OPEN_R.position + Vector2(50, 210)]), Color("c9b98e"))
	ci.draw_colored_polygon(Paint.rrect(Rect2(OPEN_R.position + Vector2(230, 120), Vector2(110, 80)), 20), Color("7a4a3a"))


func paint(ci: CanvasItem) -> void:
	var wagon := variant == "wagon"
	var dash := Color("8a7a66") if not wagon else Color("6b5a4c")
	# lid: closed it fills the opening; open it swings down toward the viewer
	var k := lid
	var top_y := lerpf(OPEN_R.position.y, HINGE_Y + 230, k)
	var widen := 34.0 * k
	var poly := PackedVector2Array([
		Vector2(OPEN_R.position.x - widen, top_y),
		Vector2(OPEN_R.end.x + widen, top_y),
		Vector2(OPEN_R.end.x, HINGE_Y),
		Vector2(OPEN_R.position.x, HINGE_Y)])
	if k < 0.5:
		poly = PackedVector2Array([Vector2(OPEN_R.position.x, top_y), Vector2(OPEN_R.end.x, top_y), Vector2(OPEN_R.end.x, HINGE_Y), Vector2(OPEN_R.position.x, HINGE_Y)])
	Paint.shadow(ci, Vector2(360, HINGE_Y + 30 + 200 * k), 220, 30, 0.3)
	var face := dash.lightened(0.08) if k < 0.5 else dash.darkened(0.25)
	Paint.fill(ci, poly, face, 0.3)
	Paint.outline(ci, poly, dash.darkened(0.45), 3)
	if k < 0.5:
		var hc := Vector2(360, lerpf(top_y, HINGE_Y, 0.3))
		Paint.fill(ci, Paint.rrect(Rect2(hc - Vector2(50, 12), Vector2(100, 24)), 10), Color("4a423a"), 0.2)
	# hinges
	for x in [OPEN_R.position.x + 20, OPEN_R.end.x - 20]:
		ci.draw_rect(Rect2(Vector2(x - 16, HINGE_Y - 8), Vector2(32, 16)), Paint.STEEL)
	# latch slider
	var lp := latch.pos()
	Paint.shadow(ci, lp + Vector2(4, 10), 34, 10, 0.35)
	Paint.fill(ci, Paint.rrect(Rect2(lp - Vector2(26, 18), Vector2(52, 36)), 8), Paint.CHROME, 0.4)
	ci.draw_line(lp + Vector2(-8, -10), lp + Vector2(-8, 10), Color(0, 0, 0, 0.3), 3, true)
	ci.draw_line(lp + Vector2(6, -10), lp + Vector2(6, 10), Color(0, 0, 0, 0.3), 3, true)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(TRACK, 26, 0, TAU, 24, Color(1, 0.86, 0.4, a2), 4, true)
		ci.draw_line(lp + Vector2(-34, 40), lp + Vector2(-80, 40), Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_line(lp + Vector2(-80, 40), lp + Vector2(-68, 30), Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_line(lp + Vector2(-80, 40), lp + Vector2(-68, 50), Color(1, 0.86, 0.4, a2), 5, true)


func bot_actions() -> Array:
	match step:
		"diagnose":
			if not has_found("falls_open"):
				return [{"type": "tap", "at": Vector2(360, 620)}, {"type": "wait", "frames": 80}]
			return [{"type": "tap", "at": latch.pos()}]
		"fix":
			var a := latch.pos()
			var path := PackedVector2Array()
			for i in 12:
				path.append(a + Vector2(-(OFF + 10) * i / 11.0, 0))
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "tap", "at": Vector2(360, 620)}, {"type": "wait", "frames": 80}]
	return []
