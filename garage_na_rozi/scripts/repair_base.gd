class_name RepairBase
extends Node2D
## One close-up repair: diagnose -> fix -> verify -> done.
## The subclass paints its part and reacts to touches; this base keeps the
## active time, the found signs, hints, feedback labels and saving.

signal solved
signal step_changed(step: String)
signal hint_ready(on: bool)
signal coach(text: String)
signal started_timer

const W := 720.0
const H := 960.0
const DrawProxy := preload("res://scripts/draw_proxy.gd")

var order: Dictionary = {}
var variant := ""
var step := "diagnose"
var found: Array = []
var elapsed := 0.0
var started := false
var pauses: Dictionary = {}
var targets: Array = []
var active: Gest.Target = null
var touch_idx := -1
var press_pos := Vector2.ZERO
var last_pos := Vector2.ZERO
var labels: Array = []
var idle := 0.0
var hint_shown := false
var t := 0.0
var tutorial := false
var finger: Array = []        # tutorial finger path (local points), loops
var finger_t := 0.0
var save_accum := 0.0
var back: Node2D
var over: Node2D
var focus := ""
var highlight := ""
var held := false
var paint_seed := 3
var springs: Array = []


func setup(o: Dictionary, job: Dictionary, tut := false) -> void:
	order = o
	variant = "wagon" if o.get("final", false) else ""
	step = String(job.get("step", "diagnose"))
	found = (job.get("found", []) as Array).duplicate()
	elapsed = float(job.get("elapsed", 0.0))
	started = bool(job.get("started", false))
	tutorial = tut
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	back = DrawProxy.new()
	back.show_behind_parent = true
	back.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	back.painter = _draw_back
	add_child(back)
	over = DrawProxy.new()
	over.painter = _draw_over
	over.z_index = 5
	add_child(over)
	build()
	if step == "done":
		step = "verify"
	_announce()


# ----------------------------------------------------------- for subclasses

func build() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func paint_back(_ci: CanvasItem) -> void:
	pass


func paint(_ci: CanvasItem) -> void:
	pass


func on_press(_id: String, _p: Vector2) -> void:
	pass


func on_drag(_id: String, _p: Vector2, _prev: Vector2) -> void:
	pass


func on_release(_id: String, _p: Vector2) -> void:
	pass


## Coach lines for the first repair, per moment. Subclass may override.
func tutorial_line() -> String:
	return ""


## Solution moves for the current step (tests and demo): list of
## {type: tap|drag|hold|wait, at, path, frames}
func bot_actions() -> Array:
	return []


func zone_of(id: String) -> Vector2:
	for tg in targets:
		if tg.id == id:
			match tg.kind:
				"segment":
					return (tg.a + tg.b) * 0.5
				"path":
					return Gest.path_point(tg.pts, 0.5)
				"rect":
					return tg.rect.get_center()
				_:
					return tg.center
	return Vector2(W / 2, H / 2)


# ----------------------------------------------------------- state

func instruction() -> String:
	var s: Dictionary = order["steps"].get(step, {})
	return String(s.get("do", ""))


func hint_text() -> String:
	var s: Dictionary = order["steps"].get(step, {})
	return String(s.get("hint", ""))


func sign_text(id: String) -> String:
	return String(order["signs"].get(id, id))


func is_paused() -> bool:
	return not pauses.is_empty()


func set_paused(reason: String, on: bool) -> void:
	if on:
		pauses[reason] = true
		if touch_idx != -1:
			_cancel_touch()
	else:
		pauses.erase(reason)
	persist()


func persist() -> void:
	Game.update_job({"step": step, "found": found, "elapsed": snappedf(elapsed, 0.01), "started": started, "phase": "repair"})


func progress() -> void:
	idle = 0.0
	if hint_shown:
		hint_shown = false
		emit_signal("hint_ready", false)


func has_found(id: String) -> bool:
	return found.has(id)


## Mark a sign as found (healthy part or the cause). Returns true if new.
func discover(id: String, good: bool, at: Vector2) -> bool:
	if found.has(id):
		label(sign_text(id), good, at)
		return false
	found.append(id)
	label(sign_text(id), good, at)
	Sfx.play("ok" if good else "found")
	if not good:
		Sfx.buzz(40)
	progress()
	persist()
	if tutorial:
		_announce()
	return true


func set_step(s: String) -> void:
	step = s
	highlight = ""
	progress()
	persist()
	emit_signal("step_changed", step)
	_announce()


func succeed() -> void:
	if step == "done":
		return
	step = "done"
	highlight = ""
	persist()
	Sfx.play("success")
	Sfx.buzz(60)
	emit_signal("step_changed", step)
	emit_signal("solved")


## A part that was let go mid-gesture eases back to its start; grabbing it
## again stops the motion so the gesture can begin anew on the same part.
func spring(obj: Object, prop: String, to: Variant, secs := 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(obj, prop, to, secs)
	springs.append(tw)


func stop_springs() -> void:
	for tw in springs:
		if tw and tw.is_valid():
			tw.kill()
	springs.clear()


func label(txt: String, good: bool, at: Vector2) -> void:
	for l in labels:
		if l["text"] == txt:
			l["age"] = 0.0
			l["pos"] = at
			return
	labels.append({"text": txt, "good": good, "pos": at, "age": 0.0})


func show_hint() -> void:
	# The requested hint: highlight the part for the current step.
	highlight = focus
	progress()


func _announce() -> void:
	if tutorial:
		var line := tutorial_line()
		if line != "":
			emit_signal("coach", line)
			return
	emit_signal("coach", instruction())


# ----------------------------------------------------------- loop

func _process(delta: float) -> void:
	t += delta
	finger_t += delta
	var running := started and step != "done" and pauses.is_empty()
	if running:
		elapsed += delta
		save_accum += delta
		if save_accum >= 3.0:
			save_accum = 0.0
			persist()
	if pauses.is_empty() and step != "done":
		idle += delta
		if idle > 12.0 and not hint_shown:
			hint_shown = true
			emit_signal("hint_ready", true)
	for l in labels:
		l["age"] += delta
	labels = labels.filter(func(l): return l["age"] < 3.2)
	tick(delta)
	queue_redraw()
	over.queue_redraw()


func _draw() -> void:
	paint(self)


func _draw_back(ci: CanvasItem) -> void:
	paint_bg(ci)
	paint_back(ci)


## Shared close-up background: dark warm garage, out-of-focus lamps.
func paint_bg(ci: CanvasItem) -> void:
	var top := Color("3d342d")
	var bottom := Color("231e1b")
	ci.draw_polygon(PackedVector2Array([Vector2(-200, -400), Vector2(W + 200, -400), Vector2(W + 200, H + 400), Vector2(-200, H + 400)]),
		PackedColorArray([top, top, bottom, bottom]))
	Paint.glow(ci, Vector2(120, 60), 260, Color(1.0, 0.8, 0.45, 0.22))
	Paint.glow(ci, Vector2(640, 220), 180, Color(0.55, 0.65, 0.85, 0.10))
	for i in 7:
		var p := Vector2(Paint.h(i, 17) * W, Paint.h(i, 23) * H * 0.5)
		Paint.glow(ci, p, 30 + Paint.h(i, 5) * 50, Color(1.0, 0.85, 0.55, 0.06 + Paint.h(i, 9) * 0.06))


## Dim everything drawn so far, so the working part keeps the most contrast.
func haze(ci: CanvasItem, a := 0.32) -> void:
	ci.draw_rect(Rect2(-200, -400, W + 400, H + 800), Color(0.12, 0.1, 0.12, a))


func _draw_over(ci: CanvasItem) -> void:
	# hint highlight ring
	if highlight != "":
		var p := zone_of(highlight)
		var r := 80.0 + sin(t * 5.0) * 8.0
		ci.draw_arc(p, r, 0, TAU, 48, Color(1, 0.86, 0.4, 0.9), 5.0, true)
		ci.draw_arc(p, r + 10, 0, TAU, 48, Color(1, 0.86, 0.4, 0.3), 3.0, true)
	# tutorial finger
	if tutorial and finger.size() > 0 and step != "done":
		_draw_finger(ci)
	# feedback labels: newest at its spot, older ones are pushed clear of it
	Paint.fonts()
	var placed: Array = []
	var order_l := labels.duplicate()
	order_l.sort_custom(func(a, b): return a["age"] < b["age"])
	for l in order_l:
		var a: float = clampf(3.2 - l["age"], 0.0, 1.0) * clampf(l["age"] * 6.0, 0.0, 1.0)
		var pos: Vector2 = l["pos"] + Vector2(0, -60 - minf(l["age"], 0.6) * 10.0)
		var txt: String = l["text"]
		var fs := 28
		var tw := Paint.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw := tw + 70.0
		var bx := clampf(pos.x - bw / 2.0, 8.0, W - bw - 8.0)
		var r := Rect2(bx, pos.y - 26, bw, 52)
		var guard := 0
		var moved := true
		while moved and guard < 8:
			moved = false
			guard += 1
			for q in placed:
				if (q as Rect2).grow(4).intersects(r):
					r.position.y = (q as Rect2).position.y - 58
					moved = true
		r.position.y = maxf(r.position.y, -40.0)
		placed.append(r)
		var bg := Color(0.98, 0.95, 0.86, 0.95 * a)
		ci.draw_colored_polygon(Paint.rrect(r, 24), bg)
		var edge := (Paint.OK if l["good"] else Paint.BAD)
		edge.a = a
		Paint.outline(ci, Paint.rrect(r, 24), edge, 3.0)
		Paint.badge(ci, Vector2(r.position.x + 28, r.position.y + 26), l["good"], 15.0)
		ci.draw_string(Paint.font_bold, Vector2(r.position.x + 50, r.position.y + 36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.17, 0.13, 0.1, a))


func _draw_finger(ci: CanvasItem) -> void:
	var n := finger.size()
	var period := 1.6 * n
	var tt := fmod(finger_t, period) / 1.6
	var i := int(tt)
	var f := tt - float(i)
	var a: Vector2 = finger[i % n]
	var b: Vector2 = finger[(i + 1) % n] if n > 1 else a
	var p := a.lerp(b, smoothstep(0.2, 0.9, f)) if n > 1 else a + Vector2(0, sin(finger_t * 6.0) * 8.0)
	var press := 0.85 if f < 0.2 or n == 1 else 1.0
	# hand: a simple painted finger pointing up-left
	var base := p + Vector2(26, 40) * press
	ci.draw_circle(p + Vector2(3, 6), 22, Color(0, 0, 0, 0.18))
	ci.draw_colored_polygon(Paint.capsule(p, base, 15), Color(0.98, 0.88, 0.78, 0.95))
	ci.draw_colored_polygon(Paint.capsule(base, base + Vector2(30, 46), 30), Color(0.98, 0.88, 0.78, 0.95))
	ci.draw_arc(p, 30 + sin(finger_t * 6.0) * 4.0, 0, TAU, 32, Color(1, 1, 1, 0.55), 3.0, true)


# ----------------------------------------------------------- input

func _unhandled_input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or step == "done":
		return
	if not pauses.is_empty() and not (pauses.size() == 1 and pauses.has("tutorial")):
		return
	if ev is InputEventScreenTouch:
		var p := to_local(ev.position)
		if ev.pressed:
			if touch_idx != -1:
				return
			var tg := Gest.pick(targets, p)
			if tg == null:
				return
			stop_springs()
			active = tg
			touch_idx = ev.index
			press_pos = p
			last_pos = p
			held = true
			if not started:
				started = true
				emit_signal("started_timer")
				persist()
			on_press(tg.id, p)
			get_viewport().set_input_as_handled()
		elif ev.index == touch_idx:
			var id := active.id if active != null else ""
			active = null
			touch_idx = -1
			held = false
			if id != "":
				on_release(id, p)
			get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		if ev.index == touch_idx and active != null:
			var p2 := to_local(ev.position)
			on_drag(active.id, p2, last_pos)
			last_pos = p2
			get_viewport().set_input_as_handled()


func _cancel_touch() -> void:
	var id := active.id if active != null else ""
	active = null
	touch_idx = -1
	held = false
	if id != "":
		on_release(id, last_pos)
