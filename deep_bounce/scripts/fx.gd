extends Node2D
## Decorative effects only (never touch the rules): debris, dust, impact flashes, sparks, electric arcs,
## crystals flying to the counter, balls flying home. Short lives so the field clears quickly.

signal crystal_arrived(n: int)

var world: Node2D
var add_layer: Node2D
var parts: Array = []        # normal blend
var glows: Array = []        # additive
var arcs: Array = []
var sparks: Array = []
var gems: Array = []
var homers: Array = []
var floaters: Array = []
var debris_tex: Array = []
var gem_target := Vector2(560, 1230)
var t := 0.0
var font: Font

func _ready() -> void:
	for i in 6:
		debris_tex.append(load("res://assets/art/fx/debris_%d.png" % i))
	add_layer = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_layer.material = m
	add_layer.draw.connect(_draw_add)
	add_child(add_layer)
	font = load("res://assets/fonts/Rubik-ExtraBold.ttf")

func clear() -> void:
	parts.clear(); glows.clear(); arcs.clear(); sparks.clear(); gems.clear(); homers.clear(); floaters.clear()

# ---------------------------------------------------------------- spawners

func impact(p: Vector2, strong := false, teal := false) -> void:
	glows.append({"tex": "fx/glow_teal" if teal else "fx/glow_white", "p": p, "life": 0.0, "max": 0.16, "s": 70.0 if strong else 46.0, "a": 0.9})
	for i in (6 if strong else 3):
		var ang := randf() * TAU
		var sp := randf_range(160, 420)
		sparks.append({"p": p, "v": Vector2(cos(ang), sin(ang)) * sp, "life": 0.0, "max": randf_range(0.09, 0.18), "teal": teal})

func break_stone(c: Vector2, w: int, h: int, gems_n: int) -> void:
	var size := Vector2(w, h) * 92.0
	var n := 5 + 2 * (w * h)
	for i in n:
		var p := c + Vector2(randf_range(-0.4, 0.4) * size.x, randf_range(-0.4, 0.4) * size.y)
		var v := (p - c).normalized() * randf_range(120, 330) + Vector2(0, -randf_range(60, 200))
		var s := randf_range(16.0, 30.0) * (1.25 if w * h > 1 else 1.0)
		parts.append({"tex": debris_tex[randi() % debris_tex.size()], "p": p, "v": v, "r": randf() * TAU, "rv": randf_range(-9, 9),
			"life": 0.0, "max": randf_range(0.45, 0.7), "s": s, "g": 1300.0, "a": 1.0})
	for i in 2 + w * h:
		var p2 := c + Vector2(randf_range(-0.3, 0.3) * size.x, randf_range(-0.3, 0.3) * size.y)
		parts.append({"tex": "fx/dust", "p": p2, "v": Vector2(randf_range(-40, 40), randf_range(-50, 10)), "r": randf() * TAU, "rv": randf_range(-1, 1),
			"life": 0.0, "max": randf_range(0.35, 0.55), "s": randf_range(40, 70) * sqrt(w * h), "g": 0.0, "a": 0.32, "grow": 1.2})
	glows.append({"tex": "fx/glow_white", "p": c, "life": 0.0, "max": 0.22, "s": 150.0 * sqrt(w * h), "a": 0.75})
	for i in gems_n:
		var ang := randf_range(-PI * 0.85, -PI * 0.15)
		gems.append({"p": c + Vector2(randf_range(-20, 20), randf_range(-14, 14)), "v": Vector2(cos(ang), sin(ang)) * randf_range(180, 360),
			"life": 0.0, "delay": 0.32 + i * 0.05, "r": randf_range(-0.4, 0.4)})

func zap(a: Vector2, b: Vector2) -> void:
	arcs.append({"a": a, "b": b, "life": 0.0, "max": 0.22})
	glows.append({"tex": "fx/glow_teal", "p": b, "life": 0.0, "max": 0.25, "s": 110.0, "a": 0.9})

func fizzle(p: Vector2) -> void:
	glows.append({"tex": "fx/glow_teal", "p": p, "life": 0.0, "max": 0.15, "s": 60.0, "a": 0.6})

func home(p: Vector2, target: Vector2, kind: int, slow := false) -> void:
	homers.append({"a": p, "b": target, "life": 0.0, "max": 0.42 if slow else 0.22, "k": kind})

func float_text(p: Vector2, text: String, col := Color("fff0c8"), size := 30) -> void:
	floaters.append({"p": p, "text": text, "life": 0.0, "max": 1.4, "col": col, "size": size})

# ---------------------------------------------------------------- update

func _process(dt: float) -> void:
	t += dt
	for arr in [parts, glows, arcs, sparks, homers, floaters]:
		var i: int = arr.size() - 1
		while i >= 0:
			var q: Dictionary = arr[i]
			q.life += dt
			if q.life >= q.max:
				arr.remove_at(i)
			i -= 1
	for q in parts:
		q.v.y += q.g * dt
		q.p += q.v * dt
		q.r += q.rv * dt
	for q in sparks:
		q.p += q.v * dt
		q.v *= 0.9
	var arrived := 0
	var i2 := gems.size() - 1
	while i2 >= 0:
		var g: Dictionary = gems[i2]
		g.life += dt
		if g.life < g.delay:
			g.v.y += 900.0 * dt
			g.v *= 0.96
			g.p += g.v * dt
		else:
			var to: Vector2 = gem_target - g.p
			var d := to.length()
			var sp: float = 900.0 + 1600.0 * (g.life - g.delay)
			if d < sp * dt + 8.0:
				gems.remove_at(i2)
				arrived += 1
			else:
				g.p += to / d * sp * dt
		i2 -= 1
	if arrived > 0:
		crystal_arrived.emit(arrived)
	queue_redraw()
	add_layer.queue_redraw()

func _draw() -> void:
	var tex: Dictionary = world.tex
	for q in parts:
		var k: float = q.life / q.max
		var tx: Texture2D = tex[q.tex] if q.tex is String else q.tex
		var s: float = q.s * (1.0 + q.get("grow", 0.0) * k)
		var a: float = q.a * (1.0 - k * k)
		draw_set_transform(q.p, q.r, Vector2.ONE)
		draw_texture_rect(tx, Rect2(-s * 0.5, -s * 0.5, s, s), false, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for h in homers:
		var k2: float = h.life / h.max
		var p: Vector2 = h.a.lerp(h.b, k2 * k2 * (3.0 - 2.0 * k2))
		var key := "balls/ball_normal"
		if h.k == Sim.K_HEAVY:
			key = "balls/ball_heavy"
		elif h.k == Sim.K_ELECTRIC:
			key = "balls/ball_electric"
		var s2 := 27.0 * (1.0 - 0.5 * k2)
		draw_texture_rect(tex[key], Rect2(p - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), false, Color(1, 1, 1, 1.0 - k2 * 0.6))
	for g in gems:
		var gs := 40.0
		var pulse := 1.0 + 0.12 * sin(t * 18.0 + g.r * 10.0)
		draw_set_transform(g.p, g.r, Vector2(pulse, pulse))
		draw_texture_rect(tex["fx/gem"], Rect2(-gs * 0.36, -gs * 0.5, gs * 0.72, gs), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for f in floaters:
		var k3: float = f.life / f.max
		var col: Color = f.col
		col.a = 1.0 - k3 * k3
		var pos: Vector2 = f.p + Vector2(0, -50.0 * k3)
		var w := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size).x
		draw_string_outline(font, pos - Vector2(w * 0.5, 0), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size, 8, Color(0.16, 0.06, 0.02, col.a))
		draw_string(font, pos - Vector2(w * 0.5, 0), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size, col)

func _draw_add() -> void:
	var tex: Dictionary = world.tex
	for q in glows:
		var k: float = q.life / q.max
		var s: float = q.s * (0.7 + 0.5 * k)
		add_layer.draw_texture_rect(tex[q.tex], Rect2(q.p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, q.a * (1.0 - k)))
	for q in sparks:
		var k2: float = q.life / q.max
		var col := Color(0.5, 1.0, 0.95, 1.0 - k2) if q.teal else Color(1.0, 0.85, 0.45, 1.0 - k2)
		add_layer.draw_line(q.p, q.p - q.v.normalized() * 12.0, col, 2.5, true)
	for q in arcs:
		var k3: float = q.life / q.max
		var a: Vector2 = q.a
		var b: Vector2 = q.b
		var pts := PackedVector2Array()
		var n := 9
		var nrm := (b - a).orthogonal().normalized()
		for i in n + 1:
			var f := float(i) / n
			var off := 0.0 if (i == 0 or i == n) else randf_range(-14, 14)
			pts.append(a.lerp(b, f) + nrm * off)
		add_layer.draw_polyline(pts, Color(0.35, 1.0, 0.95, 0.9 * (1.0 - k3)), 5.0, true)
		add_layer.draw_polyline(pts, Color(0.9, 1.0, 1.0, 1.0 - k3), 2.0, true)
	for g in gems:
		add_layer.draw_texture_rect(tex["fx/glow_teal"], Rect2(g.p - Vector2(24, 24), Vector2(48, 48)), false, Color(1, 1, 1, 0.5))
		if fmod(t * 3.0 + g.r, 1.0) < 0.25:
			add_layer.draw_texture_rect(tex["fx/sparkle"], Rect2(g.p + Vector2(-4, -22), Vector2(20, 20)), false, Color(1, 1, 1, 0.9))
