extends RepairBase
## The top case does not lock. Press the lid: it springs back because the
## hook misses the lock. The lock cylinder turns fine; the hook is bent to one
## side. Slide it over the slot, press the lid again: click, it holds.

const BODY := Rect2(110, 470, 500, 330)
const SLOT := Vector2(360, 500)
const OFFSET := 74.0
const LOCK := Vector2(360, 600)

var lid := 0.0              # 0 open (raised) .. 1 shut
var lid_v := 0.0
var hook := Gest.Slide.new(Vector2(SLOT.x + OFFSET, 470), Vector2.LEFT, 0.0, OFFSET, 0.0)
var aligned := false
var latched := false
var key_turn := 0.0
var press_hold := false


func build() -> void:
	aligned = step == "verify" or step == "done"
	hook.value = OFFSET if aligned else 0.0
	lid = 0.0
	targets.clear()
	targets.append(Gest.rect("lid", Rect2(100, 230, 520, 200), 1))
	targets.append(Gest.circle("hook", _hook_pos() + Vector2(0, -10), 50, 3))
	targets[1].enabled = step != "verify"
	targets.append(Gest.circle("lock", LOCK, 60, 2))
	focus = "hook" if step == "fix" else "lid"


func _lid_y() -> float:
	return lerpf(-120.0, 0.0, lid)


func _hook_pos() -> Vector2:
	return hook.pos() + Vector2(0, _lid_y())


func on_press(id: String, p: Vector2) -> void:
	match id:
		"lid":
			if latched:
				return
			press_hold = true
			lid_v = 4.0
			Sfx.play("swish")
		"hook":
			if step == "fix":
				hook.begin(p)
			elif step == "diagnose":
				if lid < 0.5:
					Sfx.play("tick")
					if discover("hook_off", false, _hook_pos() + Vector2(0, -80)):
						set_step("fix")
						focus = "hook"
		"lock":
			key_turn = 1.0
			Sfx.play("click")
			discover("lock_ok", true, LOCK + Vector2(0, 90))


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	if id == "hook" and step == "fix":
		hook.update(p)
		if hook.value >= OFFSET - 6.0:
			hook.value = OFFSET
			aligned = true
			Sfx.play("snap")
			Sfx.buzz(30)
			label("Дужка над замком", true, SLOT + Vector2(0, -230))
			set_step("verify")
			targets[1].enabled = false
			focus = "lid"


func on_release(id: String, _p: Vector2) -> void:
	if id == "lid":
		press_hold = false
	if id == "hook" and step == "fix" and not aligned:
		spring(hook, "value", 0.0, 0.25)


func tick(delta: float) -> void:
	key_turn = maxf(0.0, key_turn - delta * 2.0)
	if latched:
		lid = 1.0
	elif press_hold or lid_v > 0.0:
		lid = minf(1.0, lid + lid_v * delta)
		if lid >= 1.0:
			lid_v = 0.0
			if aligned:
				latched = true
				Sfx.play("latch")
				Sfx.buzz(35)
				if step == "verify":
					label("Клац — тримає!", true, SLOT + Vector2(0, -60))
					succeed()
			else:
				Sfx.play("thud")
				if step == "diagnose":
					discover("pops", false, SLOT + Vector2(0, -230))
				press_hold = false
				lid_v = -6.0
	else:
		lid = maxf(0.0, lid + lid_v * delta)
		if lid <= 0.0:
			lid_v = 0.0
	targets[1].center = _hook_pos() + Vector2(0, -10)
	targets[0].rect = Rect2(100, 230 + _lid_y() + 120, 520, 200)


func paint_back(ci: CanvasItem) -> void:
	var paint_col := Color(order.get("paint", "#2f5e6e"))
	# rear rack and seat of the motorcycle
	Paint.shape(ci, Paint.rrect(Rect2(-80, 830, 880, 200), 60), Color("2a2523"), 81, 0.25)
	Paint.fill(ci, Paint.capsule(Vector2(60, 820), Vector2(660, 820), 12), Paint.CHROME.darkened(0.2), 0.4)
	Paint.shape(ci, PackedVector2Array([Vector2(-80, 900), Vector2(300, 880), Vector2(260, 1100), Vector2(-80, 1100)]), paint_col, 82, 0.3)
	haze(ci, 0.12)


func paint(ci: CanvasItem) -> void:
	var ly := _lid_y()
	# case body
	Paint.shadow(ci, BODY.get_center() + Vector2(10, 180), 270, 30, 0.45)
	Paint.shape(ci, Paint.rrect(BODY, 40), Color("3b3d44"), 91, 0.3, 2.0)
	Paint.strokes(ci, Rect2(BODY.position + Vector2(30, 40), Vector2(440, 240)), Color(1, 1, 1, 0.08), 92, 12, 40, 3)
	# lock cylinder and the slot for the hook
	Paint.fill(ci, Paint.rrect(Rect2(SLOT - Vector2(46, 16), Vector2(92, 44)), 10), Color("23242a"), 0.2)
	ci.draw_rect(Rect2(SLOT + Vector2(-16, -4), Vector2(32, 18)), Color("0f0f12"))
	Paint.fill(ci, Paint.circle(LOCK, 34, 24), Paint.CHROME, 0.4)
	var ka := key_turn * 1.2
	ci.draw_line(LOCK - Vector2(cos(ka), sin(ka)) * 18, LOCK + Vector2(cos(ka), sin(ka)) * 18, Paint.METAL_DARK, 6, true)
	# lid, moves down when pressed
	var lr := Rect2(BODY.position.x - 10, BODY.position.y - 110 + ly, BODY.size.x + 20, 120)
	Paint.shadow(ci, Vector2(360, BODY.position.y + ly + 14), 260, 18, 0.35)
	Paint.shape(ci, Paint.rrect(lr, 36), Color("4b4e57"), 93, 0.32, 2.0)
	ci.draw_line(lr.position + Vector2(30, 20), lr.position + Vector2(lr.size.x - 30, 20), Color(1, 1, 1, 0.12), 5, true)
	# the hook under the lid's front edge
	var hp := _hook_pos()
	Paint.fill(ci, Paint.rrect(Rect2(hp + Vector2(-26, -24), Vector2(52, 20)), 6), Color("5b5f68"), 0.3)
	ci.draw_arc(hp + Vector2(0, 8), 16, 0, PI, 12, Paint.CHROME, 7, true)
	ci.draw_line(hp + Vector2(-16, -6), hp + Vector2(-16, 8), Paint.CHROME, 7, true)
	ci.draw_line(hp + Vector2(16, -6), hp + Vector2(16, 8), Paint.CHROME, 7, true)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		ci.draw_arc(SLOT + Vector2(0, ly), 30, 0, TAU, 24, Color(1, 0.86, 0.4, a2), 4, true)
		ci.draw_line(hp + Vector2(-34, 40), hp + Vector2(-70, 40), Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_line(hp + Vector2(-70, 40), hp + Vector2(-58, 30), Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_line(hp + Vector2(-70, 40), hp + Vector2(-58, 50), Color(1, 0.86, 0.4, a2), 5, true)
	if not aligned and lid > 0.7:
		# the miss: hook lands beside the slot
		ci.draw_line(SLOT + Vector2(30, -10), hp + Vector2(0, 10), Color(Paint.BAD, 0.7), 3, true)


func bot_actions() -> Array:
	match step:
		"diagnose":
			if not has_found("pops"):
				return [{"type": "hold", "at": Vector2(360, 330), "frames": 40}, {"type": "wait", "frames": 50}]
			return [{"type": "tap", "at": _hook_pos()}]
		"fix":
			var a := _hook_pos()
			var path := PackedVector2Array()
			for i in 12:
				path.append(a + Vector2(-(OFFSET + 10) * i / 11.0, 0))
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "hold", "at": Vector2(360, 330), "frames": 40}, {"type": "wait", "frames": 20}]
	return []
