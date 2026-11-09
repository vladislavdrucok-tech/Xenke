extends RepairBase
## Half of the instrument panel is dark. Switch the backlight on: the right
## dial stays dark. Behind the panel the left bulb glows; the right one is
## burnt. Carry the new bulb from the tray onto the dark socket; switch on:
## both dials are lit.

const DIAL_L := Vector2(220, 230)
const DIAL_R := Vector2(500, 230)
const KNOB := Vector2(360, 420)
const BULB_L := Vector2(220, 680)
const BULB_R := Vector2(500, 680)
const TRAY := Vector2(590, 880)

var lights := false
var replaced := false
var new_bulb := TRAY
var dragging := false
var old_bulb := Vector2(-999, -999)
var old_v := Vector2.ZERO
var verify_on := false


func build() -> void:
	replaced = step == "verify" or step == "done"
	lights = step == "diagnose"
	lights = false
	new_bulb = BULB_R if replaced else TRAY
	targets.clear()
	targets.append(Gest.circle("knob", KNOB, 70, 3))
	targets.append(Gest.circle("bulb_l", BULB_L, 60, 2))
	targets.append(Gest.circle("bulb_r", BULB_R, 60, 2))
	targets.append(Gest.circle("new", new_bulb, 60, 4))
	targets[3].enabled = step == "fix"
	focus = "new" if step == "fix" else ("knob" if step == "verify" else "")


func on_press(id: String, p: Vector2) -> void:
	match id:
		"knob":
			lights = not lights
			Sfx.play("click")
			if lights and step == "diagnose":
				await get_tree().create_timer(0.4).timeout
				if is_inside_tree() and lights and step == "diagnose":
					discover("right_dark", false, DIAL_R + Vector2(0, 130))
			if lights and step == "verify":
				verify_on = true
		"bulb_l":
			Sfx.play("tick")
			if step == "diagnose":
				discover("left_ok", true, BULB_L + Vector2(0, -70))
		"bulb_r":
			Sfx.play("tick")
			if step == "diagnose":
				if discover("dead_bulb", false, BULB_R + Vector2(0, -70)):
					set_step("fix")
					focus = "new"
					targets[3].enabled = true
					if lights:
						await get_tree().create_timer(0.5).timeout
						if is_inside_tree():
							lights = false
							Sfx.play("click")
							label("Вимикаємо підсвічування", true, KNOB + Vector2(0, -80))
		"new":
			if step == "fix":
				dragging = true


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	if id == "new" and step == "fix" and dragging:
		new_bulb = p
		if p.distance_to(BULB_R) < 48.0:
			_swap()


func on_release(id: String, _p: Vector2) -> void:
	if id == "new" and step == "fix" and not replaced:
		dragging = false


func _swap() -> void:
	replaced = true
	dragging = false
	new_bulb = BULB_R
	old_bulb = BULB_R + Vector2(0, -10)
	old_v = Vector2(160, -420)
	targets[3].enabled = false
	Sfx.play("snap")
	Sfx.buzz(30)
	label("Нова лампочка на місці", true, BULB_R + Vector2(0, -80))
	set_step("verify")
	focus = "knob"


func tick(delta: float) -> void:
	if not dragging and step == "fix" and not replaced:
		new_bulb = new_bulb.lerp(TRAY, delta * 6.0)
	if old_bulb.x > -900:
		old_v.y += 1400.0 * delta
		old_bulb += old_v * delta
		if old_bulb.y > TRAY.y and old_v.y > 0:
			old_bulb = Vector2(-999, -999)
	targets[3].center = new_bulb
	if step == "verify" and verify_on and lights:
		verify_on = false
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree() and lights and step == "verify":
			label("Обидві шкали світяться", true, Vector2(360, 120))
			succeed()


func paint_back(ci: CanvasItem) -> void:
	var wagon := variant == "wagon"
	var dash := Color("3a3532") if not wagon else Color("43302b")
	Paint.shape(ci, PackedVector2Array([Vector2(-80, 60), Vector2(800, 40), Vector2(800, 500), Vector2(-80, 520)]), dash, 121, 0.25)
	Paint.strokes(ci, Rect2(0, 60, 720, 420), dash.lightened(0.3), 122, 18, 40, 3)
	# behind-the-panel cutaway
	var cr := Rect2(30, 540, 660, 280)
	ci.draw_colored_polygon(Paint.rrect(cr, 24), Color("181614"))
	Paint.outline(ci, Paint.rrect(cr, 24), Color(1, 0.86, 0.5, 0.45), 3)
	Paint.text(ci, cr.position + Vector2(cr.size.x * 0.5, 34), "за панеллю", 22, Color(1, 0.95, 0.85, 0.7))
	for b in [BULB_L, BULB_R]:
		ci.draw_polyline(Paint.bezier(b + Vector2(0, 40), b + Vector2(0, 100), b + Vector2(60, 90), b + Vector2(80, 140), 10), Color("5a3a2a"), 5, true)
		Paint.fill(ci, Paint.rrect(Rect2(b + Vector2(-26, 16), Vector2(52, 34)), 6), Color("2c2c30"), 0.2)
	# parts tray
	Paint.fill(ci, Paint.rrect(Rect2(TRAY - Vector2(90, 40), Vector2(180, 80)), 14), Color("7a6a55"), 0.3)
	Paint.text(ci, TRAY + Vector2(0, 66), "нова лампочка", 20, Color(1, 0.95, 0.85, 0.7))


func _bulb(ci: CanvasItem, c: Vector2, glow: bool, dead: bool) -> void:
	if glow:
		Paint.glow(ci, c, 70, Color(1, 0.85, 0.45, 0.55))
	Paint.fill(ci, Paint.circle(c, 22, 20), Color("fff2c4") if glow else (Color("4a4440") if dead else Color("d9d6cc")), 0.3)
	ci.draw_arc(c, 22, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.5), 3, true)
	ci.draw_line(c + Vector2(-8, 4), c + Vector2(0, -6), Color("6a4a2a") if not dead else Color("1a1614"), 2, true)
	ci.draw_line(c + Vector2(0, -6), c + Vector2(8, 4), Color("6a4a2a") if not dead else Color("1a1614"), 2, true)
	if dead:
		ci.draw_circle(c + Vector2(0, -8), 9, Color(0.1, 0.08, 0.07, 0.6))
	ci.draw_rect(Rect2(c + Vector2(-12, 18), Vector2(24, 14)), Paint.STEEL)


func _dial(ci: CanvasItem, c: Vector2, lit: bool, kind: int) -> void:
	Paint.shadow(ci, c + Vector2(6, 12), 120, 115, 0.4)
	Paint.fill(ci, Paint.circle(c, 118, 40), Paint.CHROME.darkened(0.3), 0.4)
	var face := Color("2a2622")
	ci.draw_circle(c, 104, face)
	if lit:
		Paint.glow(ci, c, 130, Color(1.0, 0.75, 0.35, 0.35))
		ci.draw_circle(c, 100, Color(0.32, 0.24, 0.14))
	var mark := Color("ffcf7a") if lit else Color(0.4, 0.38, 0.35)
	for i in 9:
		var a := PI * 0.75 + PI * 1.5 * i / 8.0
		ci.draw_line(c + Vector2(cos(a), sin(a)) * 80, c + Vector2(cos(a), sin(a)) * 96, mark, 4, true)
	if kind == 0:
		Paint.text(ci, c + Vector2(0, 48), "км/год", 18, mark)
	else:
		Paint.text(ci, c + Vector2(-40, 10), "П", 24, mark)
		Paint.text(ci, c + Vector2(40, 10), "Б", 24, mark)
		Paint.text(ci, c + Vector2(0, 50), "паливо", 18, mark)
	var na := PI * 0.75 + PI * 1.5 * (0.2 if kind == 0 else 0.62)
	ci.draw_line(c, c + Vector2(cos(na), sin(na)) * 86, Color("e8573a") if lit else Color(0.5, 0.3, 0.25), 5, true)
	ci.draw_circle(c, 10, Paint.METAL_DARK)


func paint(ci: CanvasItem) -> void:
	_dial(ci, DIAL_L, lights, 0)
	_dial(ci, DIAL_R, lights and replaced, 1)
	# backlight knob
	Paint.shadow(ci, KNOB + Vector2(6, 10), 60, 50, 0.4)
	Paint.fill(ci, Paint.circle(KNOB, 50, 28), Color("54504a"), 0.4)
	Paint.fill(ci, Paint.circle(KNOB, 36, 24), Color("6b665f"), 0.4)
	var ka := 0.8 if lights else -0.8
	ci.draw_line(KNOB, KNOB + Vector2(sin(ka), -cos(ka)) * 30, Color("f0e6cf"), 6, true)
	ci.draw_circle(KNOB + Vector2(70, -40), 9, Paint.AMBER if lights else Color(0.4, 0.38, 0.35))
	# bulbs behind the panel
	_bulb(ci, BULB_L, lights, false)
	if not replaced:
		_bulb(ci, BULB_R, false, true)
	if old_bulb.x > -900:
		_bulb(ci, old_bulb, false, true)
	_bulb(ci, new_bulb, lights and replaced, false)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(BULB_R, 40, 0, TAU, 24, Color(1, 0.86, 0.4, a2), 4, true)
		if not dragging:
			var ax := new_bulb.lerp(BULB_R, 0.2 + fmod(t, 1.0) * 0.4)
			ci.draw_circle(ax, 6, Color(1, 0.86, 0.4, 0.8))


func bot_actions() -> Array:
	match step:
		"diagnose":
			if not lights and not has_found("right_dark"):
				return [{"type": "tap", "at": KNOB}, {"type": "wait", "frames": 40}]
			return [{"type": "tap", "at": BULB_R}, {"type": "wait", "frames": 40}]
		"fix":
			var path := PackedVector2Array()
			for i in 14:
				path.append(new_bulb.lerp(BULB_R, i / 13.0))
			return [{"type": "drag", "path": path}]
		"verify":
			if not lights:
				return [{"type": "tap", "at": KNOB}, {"type": "wait", "frames": 50}]
			return [{"type": "tap", "at": KNOB}, {"type": "wait", "frames": 10}, {"type": "tap", "at": KNOB}, {"type": "wait", "frames": 50}]
	return []
