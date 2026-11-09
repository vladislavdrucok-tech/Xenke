extends RepairBase
## Horn works only from the edge of the button. Compare a press in the centre
## (silence) with a press at the edge (beep): under the button the contact
## plate is tilted. Lift its low end level, then press the centre: it beeps.

const BTN := Vector2(360, 380)
const BTN_W := 250.0
const BTN_H := 140.0
const PLATE := Vector2(360, 760)       # centre of the contact plate (cutaway)
const PLATE_L := 300.0
const TILT := 0.32

var press_t := 0.0
var press_at := Vector2.ZERO
var beep_t := 0.0
var plate := Gest.Turn.new(PLATE + Vector2(PLATE_L * 0.5, 0), TILT, 0.0, TILT)
var level := false
var cut := 0.0                   # cutaway reveal 0..1


func build() -> void:
	level = step == "verify" or step == "done"
	plate.angle = 0.0 if level else TILT
	cut = 1.0 if step != "diagnose" else 0.0
	targets.clear()
	targets.append(Gest.rect("button", Rect2(BTN - Vector2(BTN_W, BTN_H) * 0.5, Vector2(BTN_W, BTN_H)), 1))
	targets.append(Gest.circle("plate", _plate_low(), 70, 3))
	targets[1].enabled = step == "fix"
	focus = "plate" if step == "fix" else "button"


func _plate_low() -> Vector2:
	var pv := plate.pivot
	return pv + Vector2(-cos(plate.angle), sin(plate.angle)) * PLATE_L


func on_press(id: String, p: Vector2) -> void:
	match id:
		"button":
			press_t = 0.25
			press_at = p
			var off := absf(p.x - BTN.x) / (BTN_W * 0.5)
			var at_edge := off > 0.5
			var works := at_edge or level
			if works:
				beep_t = 0.5
				Sfx.play("beep")
				Sfx.buzz(20)
			else:
				Sfx.play("click", 0.8)
			match step:
				"diagnose":
					if at_edge:
						discover("edge_works", true, p + Vector2(0, -90))
					else:
						discover("center_dead", false, p + Vector2(0, -90))
					if has_found("edge_works") and has_found("center_dead"):
						await get_tree().create_timer(0.6).timeout
						if is_inside_tree() and step == "diagnose":
							var tw := create_tween()
							tw.tween_property(self, "cut", 1.0, 0.6)
							await tw.finished
							if discover("tilted", false, PLATE + Vector2(0, -110)):
								set_step("fix")
								targets[1].enabled = true
								focus = "plate"
				"verify":
					if not at_edge:
						label("У центрі — працює!", true, p + Vector2(0, -90))
						succeed()
					else:
						label("Тепер натисни в центрі", true, p + Vector2(0, -90))
				"fix":
					label("Спершу вирівняй контакт", false, p + Vector2(0, -90))
		"plate":
			plate.begin(p)


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	if id == "plate" and step == "fix":
		# lifting the low (left) end turns the plate toward level
		var want := clampf(atan2(p.y - plate.pivot.y, plate.pivot.x - p.x), 0.0, TILT)
		plate.angle = want
		if plate.angle <= 0.03:
			plate.angle = 0.0
			level = true
			Sfx.play("snap")
			Sfx.buzz(30)
			label("Рівно!", true, PLATE + Vector2(0, -110))
			set_step("verify")
			focus = "button"


func on_release(id: String, _p: Vector2) -> void:
	if id == "plate" and step == "fix" and not level:
		spring(plate, "angle", TILT, 0.25)


func tick(delta: float) -> void:
	press_t = maxf(0.0, press_t - delta)
	beep_t = maxf(0.0, beep_t - delta)
	targets[1].center = _plate_low()


func paint_back(ci: CanvasItem) -> void:
	# handlebar and switch housing
	Paint.fill(ci, Paint.capsule(Vector2(-60, 250), Vector2(780, 230), 34), Paint.STEEL.darkened(0.1), 0.45)
	Paint.fill(ci, Paint.capsule(Vector2(-60, 250), Vector2(130, 246), 44), Paint.RUBBER, 0.2)
	haze(ci, 0.12)


func paint(ci: CanvasItem) -> void:
	# switch block housing
	var hb := Rect2(BTN - Vector2(200, 130), Vector2(400, 300))
	Paint.shadow(ci, BTN + Vector2(10, 170), 210, 30, 0.45)
	Paint.shape(ci, Paint.rrect(hb, 44), Color("3d3f46"), 61, 0.3, 2.0)
	# horn indicator lamp and sound waves
	var lamp := BTN + Vector2(150, -95)
	ci.draw_circle(lamp, 18, Color("ffd27a") if beep_t > 0.0 else Color("6a5a3a"))
	if beep_t > 0.0:
		Paint.glow(ci, lamp, 60, Color(1, 0.85, 0.4, 0.6))
		for i in 3:
			var r := 40.0 + i * 26.0 + (0.5 - beep_t) * 60.0
			ci.draw_arc(BTN + Vector2(240, -40), r, -0.7, 0.7, 12, Color(1, 0.95, 0.8, 0.8 - i * 0.2), 5, true)
		Paint.text(ci, BTN + Vector2(0, -160), "БІП!", 44, Color(1, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER, -1, Paint.font_bold)
	# the horn button: rubber, dips where pressed
	var dip := press_t * 30.0
	var br := Rect2(BTN - Vector2(BTN_W, BTN_H) * 0.5 + Vector2(0, dip * 0.3), Vector2(BTN_W, BTN_H))
	Paint.fill(ci, Paint.rrect(br.grow(8), 36), Color("26262b"), 0.2)
	Paint.fill(ci, Paint.rrect(br, 32), Color("4a4b52"), 0.3)
	Paint.text(ci, BTN + Vector2(0, 16 + dip * 0.3), "♪", 54, Color(0.85, 0.82, 0.75, 0.8))
	ci.draw_line(BTN + Vector2(-BTN_W * 0.25, -BTN_H * 0.5 + 6), BTN + Vector2(-BTN_W * 0.25, BTN_H * 0.5 - 6), Color(1, 1, 1, 0.06), 2, true)
	ci.draw_line(BTN + Vector2(BTN_W * 0.25, -BTN_H * 0.5 + 6), BTN + Vector2(BTN_W * 0.25, BTN_H * 0.5 - 6), Color(1, 1, 1, 0.06), 2, true)
	if press_t > 0.0:
		ci.draw_circle(press_at, 26, Color(1, 1, 1, 0.15))
	# cutaway: what is under the button
	if cut > 0.01:
		var cr := Rect2(PLATE - Vector2(250, 150), Vector2(500, 260))
		var a := cut
		ci.draw_colored_polygon(Paint.rrect(cr, 24), Color(0.13, 0.12, 0.14, 0.92 * a))
		Paint.outline(ci, Paint.rrect(cr, 24), Color(1, 0.86, 0.5, 0.6 * a), 3)
		Paint.text(ci, cr.position + Vector2(cr.size.x * 0.5, 34), "під кнопкою", 22, Color(1, 0.95, 0.85, 0.75 * a))
		# button stem
		ci.draw_rect(Rect2(PLATE + Vector2(-20, -100), Vector2(40, 70)), Color(0.55, 0.55, 0.6, a))
		# contact plate (copper), pivot at the right end
		var pv := plate.pivot
		var low := _plate_low()
		var col := Paint.COPPER
		col.a = a
		ci.draw_line(low, pv, col, 16, true)
		ci.draw_line(low + Vector2(0, -5), pv + Vector2(0, -5), Color(1, 0.85, 0.6, 0.5 * a), 4, true)
		ci.draw_circle(pv, 14, Color(0.6, 0.6, 0.65, a))
		# the fixed contact below the stem
		ci.draw_rect(Rect2(PLATE + Vector2(-40, 26), Vector2(80, 14)), Color(0.8, 0.6, 0.3, a))
		if step == "fix":
			var a2 := 0.45 + 0.35 * sin(t * 5.0)
			ci.draw_arc(low, 34, 0, TAU, 24, Color(1, 0.86, 0.4, a2), 4, true)
			ci.draw_line(low + Vector2(-50, 10), low + Vector2(-50, -50), Color(1, 0.86, 0.4, a2), 5, true)
			ci.draw_line(low + Vector2(-50, -50), low + Vector2(-62, -36), Color(1, 0.86, 0.4, a2), 5, true)
			ci.draw_line(low + Vector2(-50, -50), low + Vector2(-38, -36), Color(1, 0.86, 0.4, a2), 5, true)


func bot_actions() -> Array:
	match step:
		"diagnose":
			if not has_found("center_dead"):
				return [{"type": "tap", "at": BTN}]
			if not has_found("edge_works"):
				return [{"type": "tap", "at": BTN + Vector2(BTN_W * 0.4, 0)}, {"type": "wait", "frames": 120}]
			return [{"type": "wait", "frames": 30}]
		"fix":
			var low := _plate_low()
			var pv := plate.pivot
			var path := PackedVector2Array()
			for i in 12:
				var aa := lerpf(TILT, -0.04, i / 11.0)
				path.append(pv + Vector2(-cos(aa), sin(aa)) * PLATE_L)
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "tap", "at": BTN}]
	return []
