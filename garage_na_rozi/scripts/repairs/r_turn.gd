extends RepairBase
## Motorcycle turn signal shines sideways. Switch it on: the light spot on the
## wall misses the chalk mark. The bulb and wiring are fine; the housing is
## turned on its stalk. Turn the housing until the spot sits on the mark,
## then switch on again.

const PIVOT := Vector2(170, 560)
const MARK := Vector2(560, 330)
const SWITCH := Vector2(360, 860)
const WALL_X := 560.0

var housing := Gest.Turn.new(PIVOT, 0.25, -0.9, 0.9)
var blinking := false
var blink_t := 0.0
var aligned := false
var verify_ready := false


func build() -> void:
	aligned = step == "verify" or step == "done"
	housing.angle = _aim_angle() if aligned else 0.25
	blinking = false
	targets.clear()
	targets.append(Gest.circle("switch", SWITCH, 80, 3))
	targets.append(Gest.circle("housing", PIVOT + Vector2(cos(housing.angle), sin(housing.angle)) * 80, 75, 2))
	targets.append(Gest.segment("wire", Vector2(-20, 640), PIVOT + Vector2(-10, 20), 32, 1))
	focus = "housing" if step == "fix" else ("switch" if step == "verify" else "")


func _aim_angle() -> float:
	return (MARK - (PIVOT + Vector2(0, 0))).angle()


func _lens() -> Vector2:
	return PIVOT + Vector2(cos(housing.angle), sin(housing.angle)) * 118


func _spot() -> Vector2:
	var a := housing.angle
	var dir := Vector2(cos(a), sin(a))
	var tt := (WALL_X - PIVOT.x) / maxf(dir.x, 0.1)
	return PIVOT + dir * tt


func light_on() -> bool:
	return blinking and fmod(blink_t, 0.7) < 0.42


func on_press(id: String, p: Vector2) -> void:
	match id:
		"switch":
			blinking = not blinking
			blink_t = 0.0
			Sfx.play("click")
			if blinking:
				if step == "diagnose":
					await get_tree().create_timer(0.5).timeout
					if is_inside_tree() and blinking and step == "diagnose":
						discover("aim_off", false, _spot() + Vector2(0, -80))
				elif step == "verify":
					verify_ready = true
		"housing":
			housing.begin(p)
			if step == "diagnose":
				Sfx.play("tick")
				if discover("housing_turned", false, _lens() + Vector2(0, -80)):
					set_step("fix")
					focus = "housing"
					blinking = true
		"wire":
			Sfx.play("tick")
			if step == "diagnose":
				discover("bulb_ok", true, Vector2(120, 600))


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	if id == "housing" and step == "fix":
		housing.update(p)
		if absf(_spot().y - MARK.y) < 16.0:
			housing.angle = _aim_angle()
			aligned = true
			blinking = false
			Sfx.play("snap")
			Sfx.buzz(30)
			label("Точно на мітці", true, MARK + Vector2(0, -90))
			set_step("verify")
			focus = "switch"


func tick(delta: float) -> void:
	blink_t += delta
	if blinking and fmod(blink_t, 0.7) < delta:
		Sfx.play("tick", 0.8, -6.0)
	targets[1].center = PIVOT + Vector2(cos(housing.angle), sin(housing.angle)) * 80
	if step == "verify" and verify_ready and blinking and blink_t > 0.6:
		label("Світло на мітці", true, MARK + Vector2(0, -90))
		succeed()


func paint_back(ci: CanvasItem) -> void:
	# whitewashed wall with the chalk mark, floor below
	ci.draw_polygon(PackedVector2Array([Vector2(WALL_X - 40, -400), Vector2(920, -400), Vector2(920, 760), Vector2(WALL_X - 40, 700)]),
		PackedColorArray([Color("cbb99b"), Color("bfae90"), Color("a89880"), Color("b4a38a")]), Paint.uvs(PackedVector2Array([Vector2(WALL_X - 40, -400), Vector2(920, -400), Vector2(920, 760), Vector2(WALL_X - 40, 700)]), 1.4), Paint.stroke_tex())
	Paint.strokes(ci, Rect2(WALL_X, 0, 160, 600), Color(1, 0.97, 0.9, 0.3), 31, 14, 30, 3, 1.4)
	# chalk cross mark
	ci.draw_line(MARK + Vector2(-34, 0), MARK + Vector2(34, 0), Color(1, 1, 1, 0.9), 6, true)
	ci.draw_line(MARK + Vector2(0, -34), MARK + Vector2(0, 34), Color(1, 1, 1, 0.9), 6, true)
	ci.draw_arc(MARK, 24, 0, TAU, 24, Color(1, 1, 1, 0.75), 4, true)
	Paint.text(ci, MARK + Vector2(0, 70), "мітка", 22, Color(1, 1, 1, 0.75))
	# motorcycle front: fork and headlight bucket, out of focus
	var paint_col := Color(order.get("paint", "#8e2f2c"))
	Paint.fill(ci, Paint.capsule(Vector2(-80, 300), Vector2(60, 1000), 30), Paint.STEEL.darkened(0.2), 0.4)
	Paint.shape(ci, Paint.circle(Vector2(-10, 380), 140, 36), Paint.CHROME.darkened(0.2), 32, 0.4)
	Paint.shape(ci, Paint.circle(Vector2(-10, 380), 110, 36), paint_col, 33, 0.3)
	# handlebar switch housing at the bottom
	Paint.shape(ci, Paint.rrect(Rect2(SWITCH - Vector2(150, 80), Vector2(300, 160)), 30), Color("3c3e45"), 34, 0.3, 2.0)
	haze(ci, 0.14)


func paint(ci: CanvasItem) -> void:
	var on := light_on()
	var lens := _lens()
	var spot := _spot()
	# beam and spot on the wall
	if on:
		var dir := (spot - lens).normalized()
		var n := dir.orthogonal()
		ci.draw_colored_polygon(PackedVector2Array([lens + n * 18, lens - n * 18, spot - n * 60, spot + n * 60]), Color(1, 0.7, 0.2, 0.18))
		Paint.glow(ci, spot, 90, Color(1, 0.72, 0.25, 0.55))
		Paint.glow(ci, lens, 90, Color(1, 0.7, 0.2, 0.6))
	# stalk
	Paint.fill(ci, Paint.capsule(PIVOT + Vector2(-60, 40), PIVOT, 12), Paint.METAL_DARK, 0.35)
	ci.draw_line(Vector2(-20, 640), PIVOT + Vector2(-10, 20), Color("2a292e"), 9, true)
	# housing rotated on the stalk
	var a := housing.angle
	var xf := Transform2D(a, PIVOT)
	var body := Paint.xf(PackedVector2Array([Vector2(10, -32), Vector2(96, -42), Vector2(122, -30), Vector2(122, 30), Vector2(96, 42), Vector2(10, 32)]), xf)
	Paint.shadow(ci, PIVOT + Vector2(70, 50), 90, 20, 0.35)
	Paint.fill(ci, body, Color("2f3036"), 0.3)
	var lens_pts := Paint.xf(Paint.ellipse(Vector2(118, 0), 12, 40, 18), xf)
	ci.draw_colored_polygon(lens_pts, Color("ffd27a") if on else Color("d08a2c"))
	ci.draw_circle(PIVOT, 16, Paint.CHROME)
	# switch button
	var sw_col := Color("e9e2d2")
	Paint.fill(ci, Paint.rrect(Rect2(SWITCH - Vector2(70, 38), Vector2(140, 76)), 18), sw_col if not blinking else Color("f4d27a"), 0.3)
	Paint.text(ci, SWITCH + Vector2(0, 12), "⇦  ⇨", 34, Paint.INK)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(PIVOT, 150, a - 0.5, a + 0.5, 20, Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_circle(Vector2(WALL_X - 10, MARK.y), 6, Color(1, 0.86, 0.4, a2))


func bot_actions() -> Array:
	match step:
		"diagnose":
			if not blinking:
				return [{"type": "tap", "at": SWITCH}, {"type": "wait", "frames": 50}]
			return [{"type": "tap", "at": PIVOT + Vector2(cos(housing.angle), sin(housing.angle)) * 80}]
		"fix":
			var path := PackedVector2Array()
			var a0 := housing.angle
			var a1 := _aim_angle()
			for i in 20:
				var aa := lerpf(a0, a1 - 0.02, i / 19.0)
				path.append(PIVOT + Vector2(cos(aa), sin(aa)) * 85)
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "tap", "at": SWITCH}, {"type": "wait", "frames": 50}]
	return []
