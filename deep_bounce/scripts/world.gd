extends Node2D
## Everything drawn in the mine: shaft, walls, arch, cannon, stones with numbers, balls, aim line, danger line.
## Coordinates are the simulation's (720 wide, floor at 1170). Visual only: no rule lives here.

const FX := preload("res://scripts/fx.gd")
const ART := "res://assets/art/"
const BALL_SIZE := 27.0

var sim: Sim
var fx: Node2D
var fx_add: Node2D

var tex := {}
var block_nodes := {}          # id -> Node2D
var label_settings := {}       # font size -> LabelSettings
var bg: Sprite2D
var walls: Array[Sprite2D] = []
var under_node: Node2D
var warn_font: Font
var cannon_base: Sprite2D
var barrel: Sprite2D
var collar: Sprite2D
var muzzle_glow: Sprite2D
var barrel_mat: ShaderMaterial
var skin := ""
var blocks_root: Node2D
var balls_node: Node2D
var glow_node: Node2D
var aim_node: Node2D
var over_node: Node2D
var count_label: Label

var aim_angle := PI * 0.5
var aim_pts := PackedVector2Array()
var aim_visible := false
var aim_alpha := 0.0
var recoil := 0.0
var heat := 0.0
var scroll := 0.0
var scroll_target := 0.0
var shake := 0.0
var shake_off := Vector2.ZERO
var danger := 0
var danger_t := 0.0
var t := 0.0

# ball rendering: positions before/after the last step, trails per ball index
var prev_pos := {}
var trails := {}
var interp := 1.0

func _ready() -> void:
	for f in ["bg/shaft", "walls/wall_left", "walls/wall_right", "cannon/arch", "cannon/barrel_normal",
			"balls/ball_normal", "balls/ball_heavy", "balls/ball_electric", "fx/glow_warm", "fx/glow_teal",
			"fx/glow_white", "fx/gem", "fx/sparkle", "fx/dust"]:
		tex[f] = load(ART + f + ".png")
	for w in [1, 2]:
		for h in [1, 2]:
			for v in 4:
				tex["stone_%dx%d_v%d" % [w, h, v]] = load(ART + "stones/stone_%dx%d_v%d.png" % [w, h, v])
			for s in [1, 2, 3]:
				tex["crack_%dx%d_s%d" % [w, h, s]] = load(ART + "stones/crack_%dx%d_s%d.png" % [w, h, s])
			tex["vein_%dx%d" % [w, h]] = load(ART + "stones/vein_%dx%d.png" % [w, h])
	_build_static()

func _build_static() -> void:
	# shaft: repeats in both directions, scrolls slower than the stones (parallax)
	bg = Sprite2D.new()
	bg.texture = tex["bg/shaft"]
	bg.centered = false
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.region_enabled = true
	bg.scale = Vector2.ONE / 1.5
	bg.position = Vector2(-400, -500)
	bg.region_rect = Rect2(0, 0, 1520 * 1.5, 2600 * 1.5)
	add_child(bg)
	# walls: two copies per side, the outer one darker, for wide screens
	for side in [0, 1]:
		for k in 3:
			var w := Sprite2D.new()
			w.texture = tex["walls/wall_left" if side == 0 else "walls/wall_right"]
			w.centered = false
			w.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			w.region_enabled = true
			w.scale = Vector2(0.5, 0.5)
			var ww := 110.0
			if side == 0:
				w.position = Vector2(Sim.FIELD_X0 + 2 - ww * (k + 1), -500)
			else:
				w.position = Vector2(Sim.FIELD_X1 - 2 + ww * k, -500)
			w.set_meta("phase", k * 337.0)
			if k > 0:
				w.modulate = Color(0.62, 0.6, 0.6) if k == 1 else Color(0.42, 0.4, 0.4)
				w.z_index = -1
			walls.append(w)
			add_child(w)
	var arch := Sprite2D.new()
	arch.texture = tex["cannon/arch"]
	arch.centered = false
	arch.position = Vector2(200, -40)
	arch.scale = Vector2(0.5, 0.5)
	add_child(arch)
	# warm light from the cannon spilling into the shaft
	var spill := Sprite2D.new()
	spill.texture = tex["fx/glow_warm"]
	spill.position = Vector2(360, 230)
	spill.scale = Vector2(5.0, 2.6)
	spill.modulate = Color(1, 0.8, 0.55, 0.10)
	var addm := CanvasItemMaterial.new()
	addm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spill.material = addm
	add_child(spill)
	# below the floor: the shaft darkens (behind the stones, never over them)
	under_node = Node2D.new()
	under_node.draw.connect(_draw_under)
	add_child(under_node)
	blocks_root = Node2D.new()
	add_child(blocks_root)
	over_node = Node2D.new()
	over_node.draw.connect(_draw_over)
	add_child(over_node)
	glow_node = Node2D.new()
	glow_node.material = addm
	glow_node.draw.connect(_draw_glow)
	add_child(glow_node)
	balls_node = Node2D.new()
	balls_node.draw.connect(_draw_balls)
	add_child(balls_node)
	# cannon on top of the field
	cannon_base = Sprite2D.new()
	cannon_base.centered = false
	cannon_base.scale = Vector2(0.5, 0.5)
	add_child(cannon_base)
	barrel = Sprite2D.new()
	barrel.centered = false
	barrel.scale = Vector2(0.5, 0.5)
	barrel_mat = ShaderMaterial.new()
	barrel_mat.shader = load("res://shaders/barrel.gdshader")
	barrel_mat.set_shader_parameter("normal_map", tex["cannon/barrel_normal"])
	barrel.material = barrel_mat
	add_child(barrel)
	collar = Sprite2D.new()
	collar.scale = Vector2(0.5, 0.5)
	collar.position = Sim.PIVOT
	add_child(collar)
	muzzle_glow = Sprite2D.new()
	muzzle_glow.texture = tex["fx/glow_warm"]
	muzzle_glow.material = addm
	muzzle_glow.scale = Vector2(0.9, 0.9)
	add_child(muzzle_glow)
	count_label = Label.new()
	count_label.label_settings = _ls(28)
	count_label.position = Vector2(400, 150)
	count_label.size = Vector2(120, 40)
	add_child(count_label)
	aim_node = Node2D.new()
	aim_node.draw.connect(_draw_aim)
	add_child(aim_node)
	fx = FX.new()
	fx.world = self
	add_child(fx)
	fx_add = fx.add_layer
	warn_font = load("res://assets/fonts/Rubik-ExtraBold.ttf")
	set_skin(G.meta.skin)

func set_skin(id: String) -> void:
	if id == skin:
		return
	skin = id
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "cannon/meta.json"))
	var m: Dictionary = meta[id]
	cannon_base.texture = load(ART + "cannon/base_%s.png" % id)
	cannon_base.offset = -Vector2(m.base_pivot[0], m.base_pivot[1])
	cannon_base.position = Sim.PIVOT
	barrel.texture = load(ART + "cannon/barrel_%s.png" % id)
	barrel.offset = -Vector2(m.barrel_pivot[0], m.barrel_pivot[1])
	collar.texture = load(ART + "cannon/collar_%s.png" % id)
	var glow_col := {"classic": Color(1, 0.84, 0.6), "ember": Color(1, 0.55, 0.25), "brass": Color(1, 0.93, 0.7), "crystal": Color(0.5, 1, 0.95)}
	muzzle_glow.modulate = glow_col[id]
	barrel_mat.set_shader_parameter("heat_color", glow_col[id])

func _ls(size: int) -> LabelSettings:
	if label_settings.has(size):
		return label_settings[size]
	var l := LabelSettings.new()
	l.font = load("res://assets/fonts/Fredoka-Bold.ttf")
	l.font_size = size
	l.font_color = Color("fff0c8")
	l.outline_size = maxi(4, size / 12)
	l.outline_color = Color(0.36, 0.15, 0.05, 0.85)
	l.shadow_size = maxi(4, size / 9)
	l.shadow_color = Color(0.16, 0.05, 0.0, 0.6)
	l.shadow_offset = Vector2(2, 4)
	label_settings[size] = l
	return l

# ---------------------------------------------------------------- stones

func block_target(b: Dictionary) -> Vector2:
	return sim.block_rect(b).get_center()

func sync_blocks(snap := false) -> void:
	var alive := {}
	for id in sim.blocks:
		var b: Dictionary = sim.blocks[id]
		alive[id] = true
		var n: Node2D = block_nodes.get(id)
		if n == null:
			n = _make_block(b)
			block_nodes[id] = n
			n.position = block_target(b)
		_update_block(n, b)
		n.set_meta("target", block_target(b))
		n.set_meta("future_target", 1.0 if sim.is_future(b) else 0.0)
		n.set_meta("warn", sim.will_cross_next(b))
		if snap:
			n.position = block_target(b)
			n.set_meta("future", n.get_meta("future_target"))
	for id in block_nodes.keys():
		if not alive.has(id):
			block_nodes[id].queue_free()
			block_nodes.erase(id)

func clear_blocks() -> void:
	for id in block_nodes:
		block_nodes[id].queue_free()
	block_nodes.clear()

func _make_block(b: Dictionary) -> Node2D:
	var n := Node2D.new()
	var key := "%dx%d" % [b.w, b.h]
	var spr := Sprite2D.new()
	spr.texture = tex["stone_%s_v%d" % [key, b.v]]
	spr.scale = Vector2(0.5, 0.5)
	n.add_child(spr)
	var cr := Sprite2D.new()
	cr.scale = Vector2(0.5, 0.5)
	cr.name = "crack"
	n.add_child(cr)
	if b.vein:
		var vn := Sprite2D.new()
		vn.texture = tex["vein_%s" % key]
		vn.scale = Vector2(0.5, 0.5)
		n.add_child(vn)
	var lab := Label.new()
	lab.name = "num"
	var fs := 62
	if b.w == 2 and b.h == 2:
		fs = 112
	elif b.w == 2 or b.h == 2:
		fs = 78
	lab.label_settings = _ls(fs)
	n.set_meta("fs", fs)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size = Vector2(b.w * Sim.CELL, fs * 1.4)
	lab.position = -lab.size * 0.5 + Vector2(0, -2)
	lab.pivot_offset = lab.size * 0.5
	n.add_child(lab)
	blocks_root.add_child(n)
	n.set_meta("hp", -1)
	n.set_meta("pulse", 0.0)
	n.set_meta("future", 1.0 if sim.is_future(b) else 0.0)
	n.set_meta("future_target", n.get_meta("future"))
	n.set_meta("warn", false)
	n.set_meta("size", sim.block_rect(b).size)
	n.set_meta("cells", Vector2i(b.w, b.h))
	n.set_meta("fs_now", fs)
	return n

func _update_block(n: Node2D, b: Dictionary) -> void:
	if int(n.get_meta("hp")) == int(b.hp):
		return
	var first := int(n.get_meta("hp")) < 0
	n.set_meta("hp", b.hp)
	var lab: Label = n.get_node("num")
	lab.text = str(b.hp)
	var stage := Sim.damage_stage(b.hp, b.mhp)
	var cr: Sprite2D = n.get_node("crack")
	cr.texture = null if stage == 0 else tex["crack_%dx%d_s%d" % [b.w, b.h, stage]]
	if not first:
		n.set_meta("pulse", 1.0)

func hit_block(id: int) -> void:
	var n: Node2D = block_nodes.get(id)
	if n:
		n.set_meta("pulse", 1.0)

func _process_blocks(dt: float) -> void:
	var k := 1.0 - exp(-dt * 11.0)
	for id in block_nodes:
		var n: Node2D = block_nodes[id]
		var tg: Vector2 = n.get_meta("target")
		n.position += (tg - n.position) * k
		var p: float = n.get_meta("pulse")
		if p > 0.0:
			p = maxf(0.0, p - dt * 6.0)
			n.set_meta("pulse", p)
		# future rock (still under the floor) is dimmed as a whole stone; it lights up when it becomes active
		var f: float = n.get_meta("future")
		f = move_toward(f, float(n.get_meta("future_target")), dt * 4.0)
		n.set_meta("future", f)
		var dim := 1.0 - 0.58 * f
		var sc := 1.0 - 0.035 * sin(p * PI)
		n.scale = Vector2(sc, sc)
		n.modulate = Color((1.0 + 0.35 * p) * dim, (1.0 + 0.3 * p) * dim, (1.0 + 0.25 * p) * (dim + 0.04 * f))
		_place_label(n, p, f)

func _place_label(n: Node2D, p: float, f: float) -> void:
	## The number stays whole and readable: on an active stone that reaches below the floor it sits in the
	## part above the floor and shrinks to fit there; long numbers shrink to the stone's width.
	var lab: Label = n.get_node("num")
	var sz: Vector2 = n.get_meta("size")
	var top := n.position.y - sz.y * 0.5
	var bottom := top + sz.y
	var vis_bottom := bottom
	if f < 0.5:
		vis_bottom = minf(bottom, Sim.FLOOR_Y)
	var vis_h := maxf(30.0, vis_bottom - top)
	var cy := (top + vis_bottom) * 0.5 - n.position.y
	var digits := maxi(1, lab.text.length())
	var base_fs: int = n.get_meta("fs")
	var fs := mini(base_fs, int((sz.x - 18.0) / (0.62 * digits)))
	fs = mini(fs, int(vis_h * 0.82))
	fs = maxi(20, fs - fs % 4)
	if int(n.get_meta("fs_now")) != fs:
		n.set_meta("fs_now", fs)
		lab.label_settings = _ls(fs)
	lab.position = Vector2(-lab.size.x * 0.5, cy - lab.size.y * 0.5 - 2.0)
	var ls := 1.0 + 0.16 * sin(p * PI)
	lab.scale = Vector2(ls, ls)
	lab.modulate.a = 1.0 - 0.35 * f

# ---------------------------------------------------------------- per frame

func _process(dt: float) -> void:
	t += dt
	if sim == null:
		return
	_process_blocks(dt)
	scroll += (scroll_target - scroll) * (1.0 - exp(-dt * 7.0))
	bg.region_rect.position.y = scroll * 0.35 * 1.5
	for w in walls:
		w.region_rect = Rect2(0, scroll * 2.0 + float(w.get_meta("phase")), 220, 3600)
	# cannon
	recoil = maxf(0.0, recoil - dt * 9.0)
	heat = maxf(0.0, heat - dt * 3.5)
	var dir := Vector2(cos(aim_angle), sin(aim_angle))
	barrel.rotation = aim_angle
	barrel.position = Sim.PIVOT - dir * (7.0 * recoil)
	barrel_mat.set_shader_parameter("rot", aim_angle)
	barrel_mat.set_shader_parameter("heat", heat)
	muzzle_glow.position = Sim.muzzle(aim_angle) - dir * (7.0 * recoil)
	muzzle_glow.modulate.a = 0.25 + 0.75 * heat
	muzzle_glow.scale = Vector2.ONE * (0.6 + 0.6 * heat)
	# shake
	shake = maxf(0.0, shake - dt * 3.2)
	var amp := shake * shake * 10.0 * G.shake_scale()
	shake_off = Vector2(sin(t * 71.0), cos(t * 57.0)) * amp
	position = get_meta("base_pos", Vector2.ZERO) + shake_off * scale.x
	aim_alpha = move_toward(aim_alpha, 1.0 if aim_visible else 0.0, dt * 8.0)
	danger_t += dt
	balls_node.queue_redraw()
	glow_node.queue_redraw()
	aim_node.queue_redraw()
	over_node.queue_redraw()

func add_shake(a: float) -> void:
	shake = minf(1.0, shake + a)

func fire_flash() -> void:
	recoil = 1.0
	heat = 1.0

func set_count(n: int) -> void:
	count_label.text = "×%d" % n if n > 0 else ""
	var m := Sim.muzzle(aim_angle)
	count_label.position = Vector2(clampf(m.x + 18, 60, 600), clampf(m.y - 6, 120, 210))

# ---------------------------------------------------------------- drawing

func ball_pos(b: Sim.Ball) -> Vector2:
	var cur := Vector2(b.x, b.y)
	var pv: Vector2 = prev_pos.get(b.idx, cur)
	return pv.lerp(cur, interp)

func remember_positions() -> void:
	prev_pos.clear()
	if sim.phase != Sim.PH_VOLLEY:
		return
	for b in sim.v_balls:
		if b.st == 1:
			prev_pos[b.idx] = Vector2(b.x, b.y)

func _draw_balls() -> void:
	if sim == null or sim.phase != Sim.PH_VOLLEY:
		trails.clear()
		return
	var half := BALL_SIZE * 0.5
	for b in sim.v_balls:
		if b.st != 1:
			trails.erase(b.idx)
			continue
		var p := ball_pos(b)
		var tr: Array = trails.get(b.idx, [])
		if tr.is_empty() or tr[0].distance_to(p) > 1.0:
			tr.push_front(p)
			if tr.size() > 7:
				tr.pop_back()
		trails[b.idx] = tr
		var col := Color(1.0, 0.94, 0.8)
		if b.k == Sim.K_ELECTRIC:
			col = Color(0.55, 1.0, 0.95)
		elif b.k == Sim.K_HEAVY:
			col = Color(1.0, 0.78, 0.5)
		# short trail: at most 70 units behind the ball, however far it moved between frames
		var left := 70.0
		for i in range(tr.size() - 1):
			var p0: Vector2 = tr[i]
			var p1: Vector2 = tr[i + 1]
			var L := p0.distance_to(p1)
			if L <= 0.01:
				continue
			if L > left:
				p1 = p0.lerp(p1, left / L)
				L = left
			var f := 1.0 - (70.0 - left) / 70.0
			balls_node.draw_line(p0, p1, Color(col.r, col.g, col.b, 0.42 * f), 14.0 * f + 2.0, true)
			left -= L
			if left <= 0.0:
				break
	for b in sim.v_balls:
		if b.st != 1:
			continue
		var p := ball_pos(b)
		var key := "balls/ball_normal"
		if b.k == Sim.K_HEAVY:
			key = "balls/ball_heavy"
		elif b.k == Sim.K_ELECTRIC:
			key = "balls/ball_electric"
		balls_node.draw_texture_rect(tex[key], Rect2(p - Vector2(half, half), Vector2(BALL_SIZE, BALL_SIZE)), false)

func _draw_glow() -> void:
	if sim == null or sim.phase != Sim.PH_VOLLEY:
		return
	for b in sim.v_balls:
		if b.st != 1:
			continue
		var p := ball_pos(b)
		var key := "fx/glow_teal" if b.k == Sim.K_ELECTRIC else "fx/glow_warm"
		var s := 70.0
		glow_node.draw_texture_rect(tex[key], Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 0.8))

func _draw_aim() -> void:
	if aim_alpha <= 0.01 or aim_pts.size() < 2:
		return
	var a := aim_alpha
	var col := Color(1.0, 0.95, 0.8, 0.9 * a)
	# dotted line to the first contact, shorter fainter dots after the rebound
	for seg in range(aim_pts.size() - 1):
		var p0 := aim_pts[seg]
		var p1 := aim_pts[seg + 1]
		var L := p0.distance_to(p1)
		var step := 22.0
		var n := int(L / step)
		var phase := fmod(t * 60.0, step)
		for i in n + 1:
			var d := minf(L, i * step + (phase if seg == 0 else 0.0))
			var q := p0.lerp(p1, d / maxf(L, 0.001))
			var r := 4.6 if seg == 0 else 3.6
			var aa := col.a * (1.0 if seg == 0 else 0.75 * (1.0 - d / maxf(L, 1.0)))
			aim_node.draw_circle(q, r + 1.6, Color(0.1, 0.04, 0.0, aa * 0.45))
			aim_node.draw_circle(q, r, Color(col.r, col.g, col.b, aa))
	# ghost ball at the first contact
	var hp := aim_pts[1]
	aim_node.draw_arc(hp, Sim.BALL_R, 0, TAU, 28, Color(1, 0.95, 0.8, 0.95 * a), 3.0, true)
	aim_node.draw_arc(hp, Sim.BALL_R + 3, 0, TAU, 28, Color(0.1, 0.04, 0.0, 0.4 * a), 2.0, true)

func _draw_under() -> void:
	# the shaft below the floor is darker: there the rock is not reachable yet
	var y0 := Sim.FLOOR_Y
	for i in 12:
		var a := 0.30 + 0.05 * i
		under_node.draw_rect(Rect2(-400, y0 + i * 40.0, 1520, 40.0), Color(0.008, 0.05, 0.055, a))
	under_node.draw_rect(Rect2(-400, y0 + 480.0, 1520, 600.0), Color(0.008, 0.05, 0.055, 0.88))
	under_node.draw_line(Vector2(Sim.FIELD_X0, y0), Vector2(Sim.FIELD_X1, y0), Color(0.45, 0.85, 0.82, 0.22), 2.0)

func _draw_over() -> void:
	# the red line under the cannon: a stone whose collider crosses it after a shift ends the run
	var reduced: bool = G.settings.get("reduced_fx", false)
	var y := Sim.DANGER_Y
	var pulse := 0.5 + 0.5 * sin(danger_t * 7.0)
	if reduced:
		pulse = 0.6
	var col := Color(0.95, 0.36, 0.24, 0.55)
	if danger == 1:
		col = Color(1.0, 0.33, 0.22, 0.7)
	elif danger == 2:
		col = Color(1.0, 0.22, 0.16, 0.7 + 0.3 * pulse)
	var x := Sim.FIELD_X0 + 4
	over_node.draw_rect(Rect2(Sim.FIELD_X0, y - 5, Sim.FIELD_X1 - Sim.FIELD_X0, 10), Color(col.r, col.g, col.b, col.a * 0.2))
	while x < Sim.FIELD_X1 - 4:
		var x2 := minf(x + 18.0, Sim.FIELD_X1 - 4)
		over_node.draw_line(Vector2(x, y), Vector2(x2, y), col, 3.0, true)
		x += 30.0
	for sx in [Sim.FIELD_X0 + 10, Sim.FIELD_X1 - 10]:
		var dirx := 1.0 if sx < 360 else -1.0
		over_node.draw_colored_polygon(PackedVector2Array([Vector2(sx, y - 9), Vector2(sx + dirx * 14, y), Vector2(sx, y + 9)]), col)
	# stones that the next shift pushes over the line
	for id in block_nodes:
		var n: Node2D = block_nodes[id]
		if not n.get_meta("warn"):
			continue
		var sz: Vector2 = n.get_meta("size")
		var r := Rect2(n.position - sz * 0.5, sz).grow(3.0)
		var a := 0.95 if reduced else 0.55 + 0.45 * pulse
		var w := 5.0 if reduced else 4.0 + 3.0 * pulse
		over_node.draw_rect(r.grow(w * 0.5 + 2.0), Color(0.25, 0.02, 0.0, 0.45 * a), false, 3.0)
		over_node.draw_rect(r, Color(1.0, 0.25, 0.16, a), false, w)
		# warning sign at the top right corner of the stone
		var c := Vector2(r.end.x - 4.0, r.position.y + 4.0)
		var tri := PackedVector2Array([c + Vector2(0, -19), c + Vector2(18, 13), c + Vector2(-18, 13)])
		over_node.draw_colored_polygon(tri, Color(0.2, 0.03, 0.0, 0.9))
		var tri2 := PackedVector2Array([c + Vector2(0, -14), c + Vector2(13, 10), c + Vector2(-13, 10)])
		over_node.draw_colored_polygon(tri2, Color(1.0, 0.82, 0.25) if reduced else Color(1.0, 0.82, 0.25).lerp(Color(1, 0.35, 0.2), pulse * 0.5))
		over_node.draw_string(warn_font, c + Vector2(-4.5, 8.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.25, 0.05, 0.0))
