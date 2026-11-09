extends RepairBase
## The wiper leaves a streak. A test sweep cleans the glass except one band;
## the arm presses well, the rubber is twisted. Run a finger along the rubber
## to straighten it; fresh water is sprayed; a second sweep leaves it clean.

const PIVOT := Vector2(200, 860)
const ARM := 500.0
const R_IN := 160.0
const BAND := Vector2(330.0, 372.0)
const REST := -0.15
const TOP := -1.85

var arm := Gest.Turn.new(PIVOT, REST, TOP, -0.08)
var sweep_lo := 0.0
var sweep_hi := 0.0
var cleaned := Vector2(0, 0)        # swept angle range shown as clean (lo, hi); empty if lo == hi
var bent := true
var stroke: Gest.Stroke
var drops: Array = []
var press_moved := 0.0
var mode := ""                      # sweep | stroke | tap
var spray := 0.0
var squeak_acc := 0.0


func build() -> void:
	bent = step == "diagnose" or step == "fix"
	arm.angle = REST
	cleaned = Vector2.ZERO
	for i in 260:
		var p := Vector2(60 + Paint.h(i, 41) * 600, 140 + Paint.h(i, 43) * 650)
		drops.append({"p": p, "r": 3.0 + Paint.h(i, 47) * 7.0, "rr": p.distance_to(PIVOT), "a": (p - PIVOT).angle()})
	targets.clear()
	targets.append(Gest.segment("blade", _at(R_IN + 20), _at(ARM), 42, 2))
	targets.append(Gest.circle("base", PIVOT + Vector2(cos(arm.angle), sin(arm.angle)) * 70, 60, 3))
	focus = "blade"


func _at(r: float, a := INF) -> Vector2:
	var aa := arm.angle if a == INF else a
	return PIVOT + Vector2(cos(aa), sin(aa)) * r


func _blade_pts() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(_at(lerpf(R_IN, ARM, i / 12.0)))
	return pts


func on_press(id: String, p: Vector2) -> void:
	press_moved = 0.0
	match id:
		"blade":
			if step == "fix":
				mode = "stroke"
				stroke = Gest.Stroke.new(_blade_pts(), 60.0, 10)
				stroke.feed(p)
			else:
				mode = "sweep"
				arm.begin(p)
				sweep_lo = arm.angle
				sweep_hi = arm.angle
		"base":
			mode = "tap"
			Sfx.play("tick")
			discover("arm_ok", true, PIVOT + Vector2(80, -60))


func on_drag(id: String, p: Vector2, prev: Vector2) -> void:
	press_moved += p.distance_to(prev)
	if id != "blade":
		return
	if mode == "stroke" and step == "fix":
		stroke.feed(p)
		if stroke.progress() >= 0.7:
			bent = false
			mode = ""
			Sfx.play("snap")
			Sfx.buzz(30)
			label("Гумка рівна", true, _at(350) + Vector2(0, -60))
			_spray()
	elif mode == "sweep":
		var d := arm.update(p)
		sweep_lo = minf(sweep_lo, arm.angle)
		sweep_hi = maxf(sweep_hi, arm.angle)
		_mark_clean()
		squeak_acc += absf(d)
		if squeak_acc > 0.5:
			squeak_acc = 0.0
			Sfx.play("wiper", 0.9 + randf() * 0.2)


func on_release(id: String, _p: Vector2) -> void:
	if id == "blade" and mode == "sweep":
		if press_moved < 14.0:
			_inspect_blade()
		elif sweep_hi - sweep_lo >= 0.9:
			if step == "diagnose":
				discover("streak", false, _at(BAND.x, -0.9) + Vector2(0, -40))
			elif step == "verify" and not bent:
				label("Скло чисте!", true, Vector2(360, 300))
				succeed()
		elif step == "verify" or step == "diagnose":
			label("Махни ширше", false, Vector2(360, 300))
	mode = ""


func _inspect_blade() -> void:
	match step:
		"diagnose":
			Sfx.play("tick")
			if discover("rubber_bent", false, _at(BAND.x) + Vector2(0, -70)):
				set_step("fix")
		"fix":
			pass
		"verify":
			label("Махни двірником", true, _at(300) + Vector2(0, -60))


func _mark_clean() -> void:
	if cleaned.x == cleaned.y:
		cleaned = Vector2(sweep_lo, sweep_hi)
	else:
		cleaned = Vector2(minf(cleaned.x, sweep_lo), maxf(cleaned.y, sweep_hi))


func _spray() -> void:
	spray = 1.0
	Sfx.play("swish")
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	cleaned = Vector2.ZERO
	label("Бризнули води — перевір", true, Vector2(360, 260))
	set_step("verify")


func tick(delta: float) -> void:
	spray = maxf(0.0, spray - delta * 1.2)
	if mode != "sweep" and step != "done":
		arm.angle = move_toward(arm.angle, REST, delta * 0.8)
	targets[0].a = _at(R_IN + 20)
	targets[0].b = _at(ARM)
	targets[1].center = PIVOT + Vector2(cos(arm.angle), sin(arm.angle)) * 70


func _is_clean(d: Dictionary) -> bool:
	if cleaned.x == cleaned.y:
		return false
	var rr: float = d["rr"]
	var a: float = d["a"]
	if rr < R_IN or rr > ARM:
		return false
	if a < cleaned.x - 0.03 or a > cleaned.y + 0.03:
		return false
	if bent and rr > BAND.x and rr < BAND.y:
		return false
	return true


func paint_back(ci: CanvasItem) -> void:
	var wagon := variant == "wagon"
	var body := Color(order.get("paint", "#d8c7a0"))
	# roof, pillars, hood
	Paint.shape(ci, PackedVector2Array([Vector2(-80, -80), Vector2(800, -80), Vector2(800, 130), Vector2(-80, 130)]), body.darkened(0.1), 101, 0.25)
	Paint.shape(ci, PackedVector2Array([Vector2(-80, 100), Vector2(80, 120), Vector2(10, 830), Vector2(-80, 840)]), body.darkened(0.2), 102, 0.25)
	Paint.shape(ci, PackedVector2Array([Vector2(800, 100), Vector2(640, 120), Vector2(710, 830), Vector2(800, 840)]), body.darkened(0.25), 103, 0.25)
	Paint.shape(ci, PackedVector2Array([Vector2(-80, 820), Vector2(800, 820), Vector2(800, 1100), Vector2(-80, 1100)]), body, 104, 0.3)
	Paint.strokes(ci, Rect2(0, 860, 720, 120), body.lightened(0.35), 105, 14, 30, 3)
	if wagon:
		Paint.text(ci, Vector2(360, 1000), "до моря!", 36, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER, -1, Paint.font_hand)
	# cowl grille where the wiper sits
	Paint.fill(ci, Paint.rrect(Rect2(40, 830, 640, 40), 10), Color("2a2a2e"), 0.2)


func paint(ci: CanvasItem) -> void:
	# glass: dirty tint, then the clean swept sector
	var glass := PackedVector2Array([Vector2(90, 130), Vector2(630, 130), Vector2(700, 820), Vector2(20, 820)])
	ci.draw_polygon(glass, PackedColorArray([Color("8f9b8c"), Color("8a958a"), Color("7d8a80"), Color("838f85")]))
	if cleaned.x != cleaned.y:
		var sector := PackedVector2Array()
		for i in 25:
			var a := lerpf(cleaned.x, cleaned.y, i / 24.0)
			sector.append(PIVOT + Vector2(cos(a), sin(a)) * ARM)
		for i in 25:
			var a := lerpf(cleaned.y, cleaned.x, i / 24.0)
			sector.append(PIVOT + Vector2(cos(a), sin(a)) * R_IN)
		ci.draw_colored_polygon(sector, Color("b9d3e2"))
		if bent:
			var band := PackedVector2Array()
			for i in 25:
				var a := lerpf(cleaned.x, cleaned.y, i / 24.0)
				band.append(PIVOT + Vector2(cos(a), sin(a)) * BAND.y)
			for i in 25:
				var a := lerpf(cleaned.y, cleaned.x, i / 24.0)
				band.append(PIVOT + Vector2(cos(a), sin(a)) * BAND.x)
			ci.draw_colored_polygon(band, Color("86927f"))
	# drops and dust
	for d in drops:
		if _is_clean(d):
			continue
		ci.draw_circle(d["p"], d["r"], Color(0.95, 0.97, 1.0, 0.35))
		ci.draw_circle(d["p"] + Vector2(-1, -1), d["r"] * 0.4, Color(1, 1, 1, 0.5))
	# reflections
	ci.draw_line(Vector2(120, 200), Vector2(260, 160), Color(1, 1, 1, 0.25), 10, true)
	ci.draw_line(Vector2(520, 700), Vector2(640, 620), Color(1, 1, 1, 0.12), 14, true)
	if spray > 0.0:
		for i in 40:
			var p := Vector2(Paint.h(i, 71) * 720, 820 - Paint.h(i, 73) * 680 * (1.0 - spray))
			ci.draw_circle(p, 5, Color(0.85, 0.95, 1.0, 0.6 * spray))
	# wiper arm and blade
	var tip := _at(ARM)
	Paint.shadow(ci, (PIVOT + tip) * 0.5 + Vector2(10, 14), ARM * 0.5, 22, 0.25)
	ci.draw_line(PIVOT, _at(ARM - 30), Color("222326"), 12, true)
	ci.draw_line(PIVOT + Vector2(-2, -3), _at(ARM - 30) + Vector2(-2, -3), Color(1, 1, 1, 0.12), 3, true)
	var bp := _blade_pts()
	var nrm := Vector2(cos(arm.angle + PI / 2), sin(arm.angle + PI / 2))
	for i in bp.size() - 1:
		var r0 := lerpf(R_IN, ARM, i / 12.0)
		var twisted := bent and r0 >= BAND.x - 20 and r0 <= BAND.y + 10
		var off := nrm * (9.0 if twisted and i % 2 == 0 else (-5.0 if twisted else 0.0))
		var col := Color("1b1b1e")
		if twisted and has_found("rubber_bent"):
			col = Color("6a2e22")
		ci.draw_line(bp[i] + nrm * 10 + off, bp[i + 1] + nrm * 10 + off, col, 9, true)
	ci.draw_circle(PIVOT, 22, Color("2a2a2e"))
	ci.draw_circle(PIVOT, 9, Paint.STEEL)
	if step == "fix" and stroke != null:
		var pr := stroke.progress()
		ci.draw_line(_at(R_IN), _at(lerpf(R_IN, ARM, pr)), Color(Paint.OK, 0.6), 4, true)
	if step == "fix":
		var a2 := 0.45 + 0.35 * sin(t * 5.0)
		var g0 := _at(R_IN) + nrm * 40
		var g1 := _at(lerpf(R_IN, ARM, fmod(t * 0.6, 1.0))) + nrm * 40
		ci.draw_line(g0, g1, Color(1, 0.86, 0.4, a2), 5, true)
		ci.draw_circle(g1, 8, Color(1, 0.86, 0.4, a2))


func bot_actions() -> Array:
	var sweep := PackedVector2Array()
	for i in 30:
		sweep.append(_at(420, lerpf(REST, -1.7, i / 29.0)))
	match step:
		"diagnose":
			if not has_found("streak"):
				return [{"type": "drag", "path": sweep}, {"type": "wait", "frames": 10}]
			return [{"type": "tap", "at": _at(350)}]
		"fix":
			var path := PackedVector2Array()
			for i in 20:
				path.append(_at(lerpf(R_IN + 10, ARM - 10, i / 19.0)))
			return [{"type": "drag", "path": path}, {"type": "wait", "frames": 50}]
		"verify":
			return [{"type": "drag", "path": sweep}, {"type": "wait", "frames": 10}]
	return []
