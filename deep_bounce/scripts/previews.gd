extends RefCounted
## Large animated previews for the shop: a short test volley of a ball finish (normal, electric and heavy
## balls with their trails bouncing off the walls) and a cannon finish that turns, fires and recoils.
## Visual only: the look comes from the same textures and colours the game uses.

const World := preload("res://scripts/world.gd")
const ART := "res://assets/art/"

class BallPreview extends Control:
	var skin := "classic"
	var tex := {}
	var look: Dictionary
	var balls: Array = []
	var t := 0.0
	var next_shot := 0.0
	var shot_i := 0
	var stones: Array[Rect2] = []
	var stone_tex: Array = []
	var glow: Texture2D

	func setup(id: String) -> void:
		skin = id if World.BALL_LOOK.has(id) else "classic"
		look = World.BALL_LOOK[skin]
		for k in ["normal", "heavy", "electric"]:
			tex[k] = load(ART + "balls/%s_%s.png" % [skin, k])
		glow = load(ART + "fx/glow_warm.png")
		stone_tex = [load(ART + "stones/stone_1x1_v0.png"), load(ART + "stones/stone_2x1_v1.png"), load(ART + "stones/stone_1x1_v2.png")]
		balls.clear()
		t = 0.0
		next_shot = 0.25
		shot_i = 0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		queue_redraw()

	func _layout_stones() -> void:
		var w := size.x
		var h := size.y
		stones = [Rect2(w * 0.16, h * 0.56, 64, 64), Rect2(w * 0.5 - 4, h * 0.66, 128, 64), Rect2(w * 0.76, h * 0.48, 64, 64)]

	func _process(dt: float) -> void:
		if not is_visible_in_tree():
			return
		t += dt
		if stones.is_empty() or stones[0].position.x <= 0.0:
			_layout_stones()
		next_shot -= dt
		if next_shot <= 0.0:
			_shoot()
		var r := 13.5
		for b in balls:
			b.p += b.v * dt
			if b.p.x < r:
				b.p.x = r
				b.v.x = absf(b.v.x)
			elif b.p.x > size.x - r:
				b.p.x = size.x - r
				b.v.x = -absf(b.v.x)
			if b.p.y < r:
				b.p.y = r
				b.v.y = absf(b.v.y)
			for s in stones:
				var g := s.grow(r)
				if g.has_point(b.p):
					# bounce off the nearest side of the stone
					var dl: float = b.p.x - g.position.x
					var dr: float = g.end.x - b.p.x
					var du: float = b.p.y - g.position.y
					var dd: float = g.end.y - b.p.y
					var m := minf(minf(dl, dr), minf(du, dd))
					if m == du:
						b.p.y = g.position.y
						b.v.y = -absf(b.v.y)
					elif m == dd:
						b.p.y = g.end.y
						b.v.y = absf(b.v.y)
					elif m == dl:
						b.p.x = g.position.x
						b.v.x = -absf(b.v.x)
					else:
						b.p.x = g.end.x
						b.v.x = absf(b.v.x)
					b.flash = 1.0
			b.flash = maxf(0.0, b.flash - dt * 5.0)
			b.trail.push_front(b.p)
			if b.trail.size() > 14:
				b.trail.pop_back()
			b.life += dt
		balls = balls.filter(func(b): return b.p.y < size.y + 30.0 and b.life < 4.0)
		queue_redraw()

	func _shoot() -> void:
		# a series like the game's: normal, electric, normal, heavy …
		var kinds := ["normal", "electric", "normal", "heavy", "normal", "electric", "normal", "heavy"]
		var k: String = kinds[shot_i % kinds.size()]
		var ang := 1.05 + 0.12 * sin(float(shot_i / 8) * 1.7)
		var sp := 620.0
		balls.append({"k": k, "p": Vector2(size.x * 0.5, 18.0), "v": Vector2(cos(ang), sin(ang)) * sp, "trail": [], "life": 0.0, "flash": 0.0})
		shot_i += 1
		next_shot = 0.11 if shot_i % 8 != 0 else 1.3

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.1, 0.11, 0.85))
		for i in stones.size():
			draw_texture_rect(stone_tex[i], stones[i], false, Color(0.85, 0.85, 0.85))
		var cols := {"normal": Color(look.trail[0]), "heavy": Color(look.trail[1]), "electric": Color(look.trail[2])}
		var tl: float = look.len
		for b in balls:
			var col: Color = cols[b.k]
			var tr: Array = b.trail
			var d0 := 0.0
			for i in range(tr.size() - 1):
				var p0: Vector2 = tr[i]
				var p1: Vector2 = tr[i + 1]
				var L := p0.distance_to(p1)
				if L < 0.5:
					continue
				var f0 := maxf(0.0, 1.0 - d0 / tl)
				var f1 := maxf(0.0, 1.0 - (d0 + L) / tl)
				if f0 <= 0.0:
					break
				var n := (p1 - p0).orthogonal() / L
				var w0 := 1.0 + 6.0 * f0
				var w1 := 1.0 + 6.0 * f1
				var c0 := Color(col, 0.5 * f0 * f0)
				var c1 := Color(col, 0.5 * f1 * f1)
				draw_primitive(PackedVector2Array([p0 + n * w0, p1 + n * w1, p1 - n * w1, p0 - n * w0]), PackedColorArray([c0, c1, c1, c0]),
					PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
				d0 += L
		for b in balls:
			var s := 27.0
			var gc := Color(look.glow) if b.k == "normal" else (Color(0.5, 1, 0.95) if b.k == "electric" else Color(1, 0.8, 0.55))
			draw_texture_rect(glow, Rect2(b.p - Vector2(34, 34), Vector2(68, 68)), false, Color(gc, 0.35 + 0.4 * b.flash))
			draw_texture_rect(tex[b.k], Rect2(b.p - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		# the three kinds, large, along the bottom: how heavy and electric look on this finish
		var y := size.y - 44.0
		var x0 := size.x * 0.5 - 96.0
		for i in 3:
			var k: String = ["normal", "electric", "heavy"][i]
			draw_texture_rect(tex[k], Rect2(Vector2(x0 + i * 72.0, y - 26.0), Vector2(52, 52)), false)


class CannonPreview extends Control:
	var skin := "classic"
	var base: Sprite2D
	var barrel: Sprite2D
	var collar: Sprite2D
	var flash: Sprite2D
	var mat: ShaderMaterial
	var holder: Node2D
	var t := 0.0
	var recoil := 0.0
	var heat := 0.0
	var next_fire := 0.8
	var shots: Array = []
	var ball_tex: Texture2D
	const PIV := Vector2(0, 0)

	func setup(id: String) -> void:
		skin = id
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "cannon/meta.json"))
		if not meta.has(id):
			id = "classic"
		var m: Dictionary = meta[id]
		if holder:
			holder.queue_free()
		holder = Node2D.new()
		add_child(holder)
		var addm := CanvasItemMaterial.new()
		addm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		base = Sprite2D.new()
		base.centered = false
		base.texture = load(ART + "cannon/base_%s.png" % id)
		base.offset = -Vector2(m.base_pivot[0], m.base_pivot[1])
		holder.add_child(base)
		barrel = Sprite2D.new()
		barrel.centered = false
		barrel.texture = load(ART + "cannon/barrel_%s.png" % id)
		barrel.offset = -Vector2(m.barrel_pivot[0], m.barrel_pivot[1])
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/barrel.gdshader")
		mat.set_shader_parameter("normal_map", load(ART + "cannon/barrel_normal.png"))
		var glow_col := {"classic": Color(1, 0.84, 0.6), "ember": Color(1, 0.55, 0.25), "brass": Color(1, 0.93, 0.7), "crystal": Color(0.5, 1, 0.95),
			"bronze": Color(1, 0.72, 0.4), "crystal_engine": Color(0.45, 1, 0.92), "obsidian": Color(0.35, 1, 0.9)}
		mat.set_shader_parameter("heat_color", glow_col.get(id, Color(1, 0.84, 0.6)))
		barrel.material = mat
		holder.add_child(barrel)
		collar = Sprite2D.new()
		collar.texture = load(ART + "cannon/collar_%s.png" % id)
		holder.add_child(collar)
		flash = Sprite2D.new()
		flash.texture = load(ART + "fx/glow_warm.png")
		flash.material = addm
		flash.modulate = glow_col.get(id, Color(1, 0.84, 0.6))
		holder.add_child(flash)
		ball_tex = load(ART + "balls/%s_normal.png" % G.selected("ball"))
		t = 0.0

	func _process(dt: float) -> void:
		if holder == null or not is_visible_in_tree():
			return
		t += dt
		var k := minf(size.x / 360.0, size.y / 250.0)
		holder.scale = Vector2(k, k)
		holder.position = Vector2(size.x * 0.5, size.y * 0.34)
		# the barrel sweeps left and right like aiming, fires a short series, recoils
		var ang := PI * 0.5 + 0.85 * sin(t * 1.15)
		next_fire -= dt
		if next_fire <= 0.0:
			recoil = 1.0
			heat = 1.0
			var dir := Vector2(cos(ang), sin(ang))
			shots.append({"p": dir * 82.0, "v": dir * 420.0, "life": 0.0})
			next_fire = 0.16 if int(t * 10) % 14 < 5 else 0.9
		recoil = maxf(0.0, recoil - dt * 9.0)
		heat = maxf(0.0, heat - dt * 3.5)
		var d := Vector2(cos(ang), sin(ang))
		barrel.rotation = ang
		barrel.position = PIV - d * (7.0 * recoil) * 2.0
		mat.set_shader_parameter("rot", ang)
		mat.set_shader_parameter("heat", heat)
		flash.position = d * 82.0 * 2.0 - d * 14.0 * recoil
		flash.modulate.a = 0.2 + 0.8 * heat
		flash.scale = Vector2.ONE * (1.0 + 1.0 * heat)
		for s in shots:
			s.p += s.v * dt
			s.life += dt
		shots = shots.filter(func(s): return s.life < 0.8)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.1, 0.11, 0.85))
		if holder == null:
			return
		var k := holder.scale.x
		for s in shots:
			var p: Vector2 = holder.position + s.p * 2.0 * k
			var r := 13.5 * 2.0 * k
			draw_texture_rect(ball_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, 1.0 - s.life))
