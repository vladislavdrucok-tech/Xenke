class_name Models
extends RefCounted
## PROTOTYPE GEOMETRY. Every character and prop of the squad prototype is assembled here from simple shapes (boxes,
## capsules, cylinders, cones) in flat stylised colours, to test the camera, scale, readability and feel. It is not the
## final art: the real look needs modelled and animated characters (see docs/NEW_DIRECTION_UK.md).

static var _mats := {}
static var _meshes := {}

## Shared material by colour (props that never fade). `own` gives a fresh one (for things that fade or flash alone).
static func mat(c: Color, emis := 0.0, own := false) -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), emis]
	if not own and _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	if not own:
		_mats[key] = m
	return m

static func flat(c: Color) -> StandardMaterial3D:
	var key := "flat|%s" % c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

static func add(parent: Node3D, mesh: Mesh, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, emis)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func box(x: float, y: float, z: float) -> Mesh:
	var k := "b%.3f,%.3f,%.3f" % [x, y, z]
	if not _meshes.has(k):
		var m := BoxMesh.new()
		m.size = Vector3(x, y, z)
		_meshes[k] = m
	return _meshes[k]

static func ball(r: float) -> Mesh:
	var k := "s%.3f" % r
	if not _meshes.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 14
		m.rings = 7
		_meshes[k] = m
	return _meshes[k]

static func caps(r: float, h: float) -> Mesh:
	var k := "c%.3f,%.3f" % [r, h]
	if not _meshes.has(k):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 10
		m.rings = 3
		_meshes[k] = m
	return _meshes[k]

static func cyl(top: float, bottom: float, h: float, seg := 10) -> Mesh:
	var k := "y%.3f,%.3f,%.3f,%d" % [top, bottom, h, seg]
	if not _meshes.has(k):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_meshes[k] = m
	return _meshes[k]

## A soft dark oval on the ground under a character or prop (like the reference: always there, grounds the figure).
static func blob(parent: Node3D, w: float, d := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, d if d > 0.0 else w * 0.7)
	mi.mesh = q
	mi.material_override = blob_mat()
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = Vector3(0, 0.02, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static var _blob: StandardMaterial3D
static func blob_mat() -> StandardMaterial3D:
	if _blob == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.5))
		g.set_color(1, Color(0, 0, 0, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_blob = StandardMaterial3D.new()
		_blob.albedo_texture = t
		_blob.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _blob

# ======================================================================= characters
## A chibi figure (the reference's proportions: big head, short body), about 1.35 units tall, facing +Z.
## Pivots for the procedural animation: LegA/LegB (hips), ArmL/ArmR (shoulders), Body, Head.
static func human(look: Dictionary) -> Node3D:
	var rig := Node3D.new()
	var skin: Color = look.get("skin", Color("#efbf9a"))
	var jacket: Color = look.jacket
	var pants: Color = look.pants
	var boots := Color("#3b2a1f")
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegA" if side < 0 else "LegB"
		leg.position = Vector3(0.1 * side, 0.36, 0)
		rig.add_child(leg)
		add(leg, caps(0.085, 0.3), pants, Vector3(0, -0.14, 0))
		add(leg, box(0.15, 0.1, 0.22), boots, Vector3(0, -0.31, 0.03))
	var body := Node3D.new()
	body.name = "Body"
	rig.add_child(body)
	add(body, caps(0.2, 0.46), jacket, Vector3(0, 0.56, 0), Vector3.ZERO, Vector3(1.1, 1, 0.85))
	add(body, box(0.38, 0.06, 0.3), look.get("belt", Color("#4a3624")), Vector3(0, 0.41, 0))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.0, 0)
	body.add_child(head)
	add(head, ball(0.3), skin)
	for side in [-1, 1]:
		add(head, ball(0.045), Color("#1d1d22"), Vector3(0.1 * side, 0.02, 0.27))
		add(head, ball(0.016), Color.WHITE, Vector3(0.1 * side + 0.012, 0.04, 0.31))
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(0.27 * side, 0.74, 0)
		body.add_child(arm)
		add(arm, caps(0.07, 0.34), jacket, Vector3(0, -0.13, 0))
		add(arm, ball(0.075), skin, Vector3(0, -0.32, 0))
	var arm_r: Node3D = body.get_node("ArmR")
	match look.get("kind", ""):
		"mira":
			add(head, ball(0.32), Color("#7a3f22"), Vector3(0, 0.08, -0.05), Vector3.ZERO, Vector3(1, 0.85, 1))
			add(head, box(0.5, 0.12, 0.14), Color("#7a3f22"), Vector3(0, 0.2, 0.2), Vector3(-20, 0, 0))
			add(head, caps(0.08, 0.36), Color("#7a3f22"), Vector3(0, -0.02, -0.33), Vector3(35, 0, 0))
			add(head, box(0.56, 0.06, 0.08), Color("#2a8a8f"), Vector3(0, 0.18, 0.1))       # bandana
			add(arm_r, box(0.06, 0.38, 0.06), Color("#a5adb2"), Vector3(0, -0.42, 0.14), Vector3(70, 0, 0))
			add(arm_r, box(0.16, 0.08, 0.06), Color("#a5adb2"), Vector3(0, -0.47, 0.32), Vector3(70, 0, 0))
			add(body, box(0.3, 0.3, 0.14), Color("#6b4a2e"), Vector3(0, 0.6, -0.22))        # tool pack
		"einstein":
			for p in [Vector3(-0.22, 0.12, -0.05), Vector3(0.22, 0.12, -0.05), Vector3(0, 0.25, -0.1), Vector3(-0.14, 0.24, 0.08),
					Vector3(0.14, 0.24, 0.08), Vector3(0, 0.08, -0.25), Vector3(-0.26, -0.02, -0.12), Vector3(0.26, -0.02, -0.12)]:
				add(head, ball(0.14), Color("#eef0f2"), p)
			add(head, box(0.22, 0.06, 0.07), Color("#eef0f2"), Vector3(0, -0.09, 0.28))     # moustache
			add(body, box(0.36, 0.42, 0.2), Color("#8a5a2e"), Vector3(0, 0.62, -0.25))      # backpack
			add(body, cyl(0.07, 0.07, 0.36), Color("#5a3a1e"), Vector3(0, 0.88, -0.26), Vector3(0, 0, 90))
			add(arm_r, box(0.16, 0.1, 0.2), Color("#2b3338"), Vector3(0, -0.38, 0.1))
			add(arm_r, ball(0.05), Color("#5fe3ff"), Vector3(0, -0.36, 0.22), Vector3.ZERO, Vector3.ONE, 2.5)
	blob(rig, 0.8)
	return rig

## A crawler: a hairless mutant rat with blue armour plates, about knee-high (big = the armoured one).
static func crawler(big := false) -> Node3D:
	var rig := Node3D.new()
	var k := 1.9 if big else 1.0
	var skin := Color("#a3a68a") if not big else Color("#77735f")
	var plate := Color("#3f73a3") if not big else Color("#2c4a66")
	var body := Node3D.new()
	body.name = "Body"
	rig.add_child(body)
	add(body, caps(0.22 * k, 0.9 * k), skin, Vector3(0, 0.3 * k, 0), Vector3(90, 0, 0))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.36 * k, 0.48 * k)
	body.add_child(head)
	add(head, ball(0.2 * k), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.15))
	add(head, cyl(0.03 * k, 0.11 * k, 0.16 * k), Color("#d58f84"), Vector3(0, -0.02 * k, 0.24 * k), Vector3(90, 0, 0))
	for side in [-1, 1]:
		add(head, ball(0.045 * k), Color("#ff8a1e"), Vector3(0.09 * k * side, 0.06 * k, 0.16 * k), Vector3.ZERO, Vector3.ONE, 3.0)
		add(head, cyl(0.0, 0.07 * k, 0.12 * k), Color("#d58f84"), Vector3(0.13 * k * side, 0.17 * k, -0.02), Vector3(0, 0, -25 * side))
	for i in 3:
		add(body, box(0.34 * k, 0.08 * k, 0.24 * k), plate, Vector3(0, 0.5 * k, 0.24 * k - i * 0.25 * k), Vector3(-8 + i * 8, 0, 0))
		if big:
			add(body, cyl(0.0, 0.06 * k, 0.2 * k), Color("#c9c3a8"), Vector3(0, 0.62 * k, 0.24 * k - i * 0.25 * k))
	for i in 3:
		var r := 0.06 * k * (1.0 - i * 0.25)
		add(body, cyl(r * 0.8, r, 0.3 * k), Color("#c98a7a"), Vector3(0, 0.28 * k - i * 0.03 * k, -0.55 * k - i * 0.27 * k), Vector3(80 + i * 4, 0, 0))
	var n := 0
	for zz in [0.28, -0.25]:
		for side in [-1, 1]:
			var leg := Node3D.new()
			leg.name = ("LegA%d" if (n % 3 == 0) else "LegB%d") % n
			leg.position = Vector3(0.17 * k * side, 0.24 * k, zz * k)
			rig.add_child(leg)
			add(leg, caps(0.05 * k, 0.26 * k), skin, Vector3(0, -0.11 * k, 0.02))
			n += 1
	blob(rig, 0.9 * k, 1.3 * k)
	return rig

# ======================================================================= props
## A stylised pine: trunk and three stacked cones. Returns [node, fading meshes].
static func pine(parent: Node3D, pos: Vector3, h := 3.2, dead := false) -> Array:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var fades: Array = []
	var trunk := MeshInstance3D.new()
	trunk.mesh = cyl(0.12, 0.2, h * 0.35)
	trunk.position.y = h * 0.17
	trunk.material_override = mat(Color("#6b4a2f"), 0.0, true)
	n.add_child(trunk)
	fades.append(trunk)
	var green := Color("#3f8a3a") if not dead else Color("#6e6a5a")
	for i in 3:
		var c := MeshInstance3D.new()
		var r := (0.95 - i * 0.22) * h / 3.2
		c.mesh = cyl(0.0, r, h * 0.36)
		c.position.y = h * (0.42 + i * 0.19)
		c.material_override = mat(green.lightened(i * 0.07), 0.0, true)
		n.add_child(c)
		fades.append(c)
	blob(n, 1.4 * h / 3.2)
	return [n, fades]

static func rock(parent: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	add(n, ball(0.5 * s), Color("#8a8a84"), Vector3(0, 0.2 * s, 0), Vector3(0, pos.x * 40.0, 0), Vector3(1.3, 0.7, 1))
	add(n, ball(0.32 * s), Color("#9c9b93"), Vector3(0.35 * s, 0.14 * s, 0.1 * s))
	return n

## A fence of planks, like the reference's wooden fences, but patched with rusty sheet metal.
static func fence(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	var n := int(len / 0.42)
	var ang := rad_to_deg(atan2(d.x, d.z))
	for i in n:
		var p := a + d * ((i + 0.5) / n)
		var tall := 1.0 + 0.18 * sin(i * 2.3)
		var c := Color("#7a5236") if i % 5 != 3 else Color("#8a5a3a").darkened(0.1)
		if i % 9 == 4:
			c = Color("#9a5a2e")   # a rusty sheet
		add(parent, box(0.36, tall, 0.12), c, p + Vector3(0, tall / 2.0, 0), Vector3(0, ang + 90, sin(i * 1.7) * 4.0))
	for h in [0.35, 0.8]:
		var m := add(parent, box(0.06, 0.08, len), Color("#5c3d27"), (a + b) / 2.0 + Vector3(0, h, 0), Vector3(0, ang, 0))
		m.position += Vector3(cos(deg_to_rad(ang)), 0, -sin(deg_to_rad(ang))) * 0.09

static func crate(parent: Node3D, pos: Vector3, s := 0.6, rot := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	parent.add_child(n)
	add(n, box(s, s, s), Color("#8a6a3e"), Vector3(0, s / 2.0, 0))
	add(n, box(s + 0.02, 0.06, s + 0.02), Color("#5c4428"), Vector3(0, s * 0.85, 0))
	add(n, box(s + 0.02, 0.06, s + 0.02), Color("#5c4428"), Vector3(0, s * 0.15, 0))
	blob(n, s * 1.6)
	return n

static func barrel(parent: Node3D, pos: Vector3, c := Color("#3f73a3")) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	add(n, cyl(0.26, 0.26, 0.75, 12), c, Vector3(0, 0.375, 0))
	add(n, cyl(0.27, 0.27, 0.06, 12), c.darkened(0.3), Vector3(0, 0.2, 0))
	add(n, cyl(0.27, 0.27, 0.06, 12), c.darkened(0.3), Vector3(0, 0.6, 0))
	blob(n, 0.9)
	return n

## A rusted car wreck (obstacle).
static func wreck(parent: Node3D, pos: Vector3, rot := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	parent.add_child(n)
	add(n, box(1.3, 0.5, 2.6), Color("#9a5530"), Vector3(0, 0.45, 0))
	add(n, box(1.1, 0.45, 1.3), Color("#7a4426"), Vector3(0, 0.9, -0.15))
	add(n, box(1.0, 0.36, 0.05), Color("#2c3b44"), Vector3(0, 0.92, 0.52), Vector3(-25, 0, 0))
	for p in [Vector3(-0.62, 0.22, 0.8), Vector3(0.62, 0.22, 0.8), Vector3(-0.62, 0.22, -0.85), Vector3(0.62, 0.22, -0.85)]:
		add(n, cyl(0.24, 0.24, 0.16, 10), Color("#24272a"), p, Vector3(0, 0, 90))
	add(n, ball(0.25), Color("#4f8a3a"), Vector3(0.3, 1.1, -0.4), Vector3.ZERO, Vector3(1.4, 0.6, 1.2))   # moss on the roof
	blob(n, 2.4, 3.2)
	return n

## A broken concrete wall piece with rebar.
static func ruin(parent: Node3D, pos: Vector3, len := 3.0, rot := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	parent.add_child(n)
	var segs := int(len / 0.6)
	for i in segs:
		var h := 0.9 + 0.5 * absf(sin(i * 1.9 + pos.x))
		add(n, box(0.62, h, 0.4), Color("#a29d92").darkened(0.05 * (i % 3)), Vector3(-len / 2.0 + 0.3 + i * 0.6, h / 2.0, 0))
		if i % 3 == 1:
			add(n, cyl(0.025, 0.025, 0.5), Color("#8a4b2a"), Vector3(-len / 2.0 + 0.3 + i * 0.6, h + 0.2, 0), Vector3(0, 0, 18))
	add(n, box(len, 0.08, 0.42), Color("#5f7d3c"), Vector3(0, 0.05, 0.02))
	blob(n, len + 0.6, 1.2)
	return n

static func lamp_post(parent: Node3D, pos: Vector3, on := true) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	add(n, cyl(0.05, 0.07, 2.6), Color("#3b4248"), Vector3(0, 1.3, 0))
	add(n, box(0.5, 0.06, 0.06), Color("#3b4248"), Vector3(0.22, 2.55, 0))
	var bulb := add(n, ball(0.12), Color("#ffcf7a") if on else Color("#4a4a44"), Vector3(0.42, 2.45, 0), Vector3.ZERO, Vector3.ONE, 3.0 if on else 0.0)
	bulb.name = "Bulb"
	blob(n, 0.6)
	return n

## Pickup that flies from an enemy to the hero: a little blue gear (component) or a log.
static func token(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"parts":
			add(n, cyl(0.16, 0.16, 0.07, 8), Color("#4f9ad6"), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, 0.6)
			add(n, cyl(0.06, 0.06, 0.09, 8), Color("#d9e4ea"), Vector3.ZERO, Vector3(90, 0, 0))
		"wood":
			add(n, cyl(0.08, 0.08, 0.36, 8), Color("#8a5a32"), Vector3.ZERO, Vector3(0, 0, 90))
		_:
			add(n, ball(0.12), Color("#ffd35a"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.5)
	return n
