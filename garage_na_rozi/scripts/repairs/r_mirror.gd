extends RepairBase
## Moped mirror keeps dropping. Push it: it falls and shows only asphalt.
## The handlebar clamp holds; the hinge ring is loose. Turn the ring round
## until it tightens (the mirror rises with it), then push again: it holds.

const HINGE := Vector2(420, 470)
const CLAMP := Vector2(420, 722)
const ARM := 205.0
const UP_ANGLE := -2.05          # pointing up-left
const DROP := 1.25               # how far it falls (radians)

var droop := 0.0                 # 0 upright .. 1 fallen
var droop_v := 0.0
var wobble := 0.0
var ring := Gest.Turn.new(HINGE, 0.0)
var tightened := 0.0             # radians turned clockwise
var lift_drag := false


func build() -> void:
	targets.clear()
	targets.append(Gest.circle("mirror", _head(), 105, 1))
	targets.append(Gest.circle("ring", HINGE, 62, 3))
	targets.append(Gest.circle("clamp", CLAMP, 70, 2))
	if step == "diagnose":
		droop = 0.0
	elif step == "fix":
		droop = 1.0
	else:
		droop = 0.0
		tightened = 4.4
	focus = "ring" if step == "fix" else ("mirror" if step == "verify" else "")


func _angle() -> float:
	return UP_ANGLE + DROP * droop + sin(t * 30.0) * wobble * 0.08


func _head() -> Vector2:
	return HINGE + Vector2(cos(_angle()), sin(_angle())) * ARM


func on_press(id: String, p: Vector2) -> void:
	match id:
		"mirror":
			_push()
		"ring":
			ring.begin(p)
			if step == "diagnose":
				wobble = 1.0
				Sfx.play("rattle")
				if discover("ring_loose", false, HINGE + Vector2(0, -70)):
					set_step("fix")
					focus = "ring"
		"clamp":
			Sfx.play("tick")
			discover("clamp_ok", true, CLAMP + Vector2(0, -60))


func on_drag(id: String, p: Vector2, _prev: Vector2) -> void:
	if id == "ring" and step == "fix":
		var d := ring.update(p)
		if d > 0.0:
			tightened += d
			if int(tightened * 3.0) != int((tightened - d) * 3.0):
				Sfx.play("tick", 1.0 + tightened * 0.08)
			droop = clampf(1.0 - tightened / 4.0, 0.0, 1.0)
		elif d < -0.05:
			label("Крути за стрілкою", false, HINGE + Vector2(0, -80))
		if tightened >= 4.2:
			droop = 0.0
			Sfx.play("snap")
			Sfx.buzz(30)
			label("Затягнуто", true, HINGE + Vector2(0, -80))
			set_step("verify")
			focus = "mirror"


func _push() -> void:
	match step:
		"diagnose":
			if droop < 0.5:
				droop_v = 3.5
				Sfx.play("thud")
				discover("drops", false, _head() + Vector2(0, -90))
			else:
				# lifted back up — it slowly sags again
				droop = 0.0
				droop_v = 0.25
				label("Тримається лише мить…", false, _head() + Vector2(0, -90))
		"fix":
			label("Спершу затягни кільце шарніра", false, HINGE + Vector2(0, -80))
		"verify":
			wobble = 1.0
			Sfx.play("tick")
			label("Дзеркало тримається", true, _head() + Vector2(0, -90))
			succeed()


func tick(delta: float) -> void:
	wobble = maxf(0.0, wobble - delta * 1.5)
	if step == "diagnose" and droop_v != 0.0:
		droop = clampf(droop + droop_v * delta, 0.0, 1.0)
		if droop >= 1.0:
			droop_v = 0.0
	targets[0].center = _head()


func paint_back(ci: CanvasItem) -> void:
	# headlamp nacelle and front of the moped below, out of focus
	var paint_col := Color(order.get("paint", "#7fa7c1"))
	Paint.shape(ci, Paint.ellipse(Vector2(150, 980), 330, 220, 36), paint_col.darkened(0.15), 8, 0.3)
	Paint.strokes(ci, Rect2(0, 800, 400, 140), paint_col.lightened(0.3), 9, 10, 20, 2)
	# handlebar and grip
	Paint.fill(ci, Paint.capsule(Vector2(-40, 760), Vector2(760, 690), 20), Paint.STEEL, 0.45)
	ci.draw_line(Vector2(-40, 750), Vector2(760, 680), Color(1, 1, 1, 0.35), 4, true)
	Paint.fill(ci, Paint.capsule(Vector2(-40, 760), Vector2(140, 745), 27), Paint.RUBBER, 0.2)
	for i in 6:
		ci.draw_line(Vector2(10 + i * 22, 730), Vector2(12 + i * 22, 772), Color(1, 1, 1, 0.08), 3, true)
	haze(ci, 0.16)


func paint(ci: CanvasItem) -> void:
	var a := _angle()
	var head := _head()
	# stalk from clamp to hinge
	Paint.shadow(ci, CLAMP + Vector2(8, 40), 80, 20, 0.35)
	Paint.fill(ci, Paint.capsule(CLAMP + Vector2(0, -20), HINGE, 11), Paint.CHROME, 0.4)
	# clamp block with two bolts
	Paint.shape(ci, Paint.rrect(Rect2(CLAMP - Vector2(52, 36), Vector2(104, 72)), 14), Color("4a4d55"), 21, 0.3, 2.0)
	Paint.bolt(ci, CLAMP + Vector2(-26, 0), 12)
	Paint.bolt(ci, CLAMP + Vector2(26, 0), 12)
	# arm to the mirror head
	Paint.fill(ci, Paint.capsule(HINGE, head, 9), Paint.CHROME, 0.4)
	# mirror head with what it reflects
	var rot := a + PI / 2.0
	var shell := Paint.ellipse(head, 110, 76, 36, rot)
	Paint.shadow(ci, head + Vector2(10, 18), 115, 85, 0.4)
	Paint.fill(ci, shell, Color("2d2f35"), 0.3)
	var glass := Paint.ellipse(head, 96, 63, 36, rot)
	var view := 1.0 - droop
	var sky := Color("a9c7dc").lerp(Color("6f6d6a"), droop)
	ci.draw_polygon(glass, _glass_cols(glass, head, rot, view))
	ci.draw_line(head + Vector2(-50, -20).rotated(rot), head + Vector2(-10, -45).rotated(rot), Color(1, 1, 1, 0.45), 6, true)
	if droop > 0.6:
		Paint.text(ci, head + Vector2(0, 8), "асфальт", 20, Color(1, 1, 1, 0.55 * droop))
	# hinge ring (knurled)
	var loose := step == "diagnose"
	var off := Vector2(sin(t * 40.0), 0) * wobble * 3.0 if loose else Vector2.ZERO
	Paint.shadow(ci, HINGE + Vector2(6, 10), 56, 48, 0.4)
	Paint.fill(ci, Paint.circle(HINGE + off, 46, 32), Paint.STEEL, 0.4)
	for i in 16:
		var aa := ring.angle + TAU * i / 16.0
		ci.draw_line(HINGE + off + Vector2(cos(aa), sin(aa)) * 34, HINGE + off + Vector2(cos(aa), sin(aa)) * 46, Paint.METAL_DARK, 3, true)
	ci.draw_circle(HINGE + off, 22, Paint.CHROME)
	if loose and has_found("ring_loose") or step == "fix":
		ci.draw_arc(HINGE, 54, 0, TAU, 32, Color(Paint.BAD, 0.5), 3, true)
	if step == "fix":
		# direction arrow and progress arc
		var pr := clampf(tightened / 4.2, 0.0, 1.0)
		ci.draw_arc(HINGE, 78, -PI / 2, -PI / 2 + TAU * pr, 40, Color(Paint.OK, 0.95), 7, true)
		var aa0 := -PI / 2 + t * 1.5
		ci.draw_arc(HINGE, 96, aa0, aa0 + 1.2, 16, Color(1, 0.86, 0.4, 0.85), 5, true)
		var tip := HINGE + Vector2(cos(aa0 + 1.2), sin(aa0 + 1.2)) * 96
		var tang := Vector2(-sin(aa0 + 1.2), cos(aa0 + 1.2))
		ci.draw_line(tip, tip - tang * 16 + tang.orthogonal() * 10, Color(1, 0.86, 0.4, 0.85), 5, true)
		ci.draw_line(tip, tip - tang * 16 - tang.orthogonal() * 10, Color(1, 0.86, 0.4, 0.85), 5, true)


func _glass_cols(pts: PackedVector2Array, c: Vector2, rot: float, view: float) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in pts:
		var local := (p - c).rotated(-rot)
		var up := clampf(0.5 - local.y / 130.0, 0.0, 1.0)
		var sky := Color("b8d4e6").lerp(Color("e9f1f4"), up)
		var road := Color("5f5d5a").lerp(Color("7a7672"), up)
		var horizon := lerpf(0.9, -0.2, view)
		cols.append(sky if up > horizon else road)
	return cols


func bot_actions() -> Array:
	match step:
		"diagnose":
			if not has_found("drops"):
				return [{"type": "tap", "at": _head()}]
			return [{"type": "tap", "at": HINGE}]
		"fix":
			var path := PackedVector2Array()
			for i in 70:
				var aa := -PI / 2 + i * 0.09
				path.append(HINGE + Vector2(cos(aa), sin(aa)) * 58)
			return [{"type": "drag", "path": path}]
		"verify":
			return [{"type": "tap", "at": _head()}]
	return []
