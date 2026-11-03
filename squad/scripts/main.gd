extends Node3D
## Afterfall — squad prototype (new direction: docs/NEW_DIRECTION_UK.md). A three-minute test episode near the Station:
## crawlers on the road drop components -> the researcher is pinned under a fallen scaffold, the components free him ->
## scrap and wood on the way, the armoured crawler -> back at the Station the water pump is repaired: it changes, the
## flooded underpass drains and the way to the laundry opens. Camera from above at an angle, free movement on the plane,
## a two-person squad, automatic basic attacks. Everything you see is prototype geometry (scripts/models.gd).
## It is a mechanics test placed near the Station; the canonical story order of Afterfall is not changed by it.

const SAVE_PATH := "user://squad_save.json"
const ABILITY_CD := 9.0
const MAX_LEVEL := 2
const UPGRADE := {"parts": 2, "wood": 2}
const FREE_NEED := {"parts": 3}
const REPAIR_NEED := {"parts": 4, "wood": 3}
const START := Vector3(-4, 0, 1)
const BOUNDS := Rect2(-14, -10, 62, 24)            # x, z, width, depth of the walkable land
const RES_NAMES := {"parts": "Деталі", "wood": "Дерево", "water": "Вода"}

var S := {}
var mira: Hero
var einstein: Hero
var heroes: Array = []
var enemies: Array = []
var nodes: Array = []          # gatherable: {id, kind, amount, pos, time, radius, full, empty, done, prog}
var spots: Array = []          # interactions with needs: {id, pos, radius, needs, title, action, flag}
var fades: Array = []          # [{meshes, pos, w}] things that turn see-through when a hero is behind them
var trail: Array[Vector3] = []
var camera: Camera3D
var cam_target := Vector3.ZERO
var hud
var fx: Array = []             # transient effects: {node, t, life, kind, ...}
var tokens: Array = []
var projectiles: Array = []
var scaffold: Spr
var pump: Node3D
var pool_water: MeshInstance3D
var pool_body: CollisionShape3D
var plants: Array = []
var ability_cd := 0.0
var calm_t := 0.0
var save_t := 0.0
var water_t := 0.0
var ended := false
var bot := false
var bot_vec := Vector2.ZERO
var frame_ms: Array[float] = []
var done_flash := {}
var font: Font

# ======================================================================= setup
func _ready() -> void:
	randomize()
	font = load("res://assets/PixelifySans.ttf")
	_keys()
	var args := OS.get_cmdline_user_args()
	bot = args.has("--selftest")
	for a in args:
		bot = bot or a.begins_with("--demo")
	if bot:
		_new_save()
	else:
		_load()
	_build_env()
	_build_ground()
	_build_station()
	_build_route()
	_build_squad()
	_build_enemies()
	hud = preload("res://scripts/hud.gd").new()
	hud.world = self
	add_child(hud)
	hud.action_pressed.connect(_on_action)
	hud.ability_pressed.connect(use_ability)
	_apply_save()
	_refresh()
	if not S.flags.get("intro", false):
		S.flags["intro"] = true
		hud.say([["mira", "Насос на Станції знову встав. Без деталей воду не очистимо."], ["mira", "На дорозі повзуни — у них у гніздах повно нашого брухту. Піду гляну."]])
	if args.has("--selftest"):
		_selftest()
	elif bot:
		_demo()

func _keys() -> void:
	var keys := {"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "ability": [KEY_SPACE], "act": [KEY_E]}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1c2420")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb0c4")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#3a4250")
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Evening sun: low, warm, from the left (as in the earlier versions).
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -62, 0)
	sun.light_color = Color("#ffc58a")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6
	sun.directional_shadow_max_distance = 30.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.5
	camera.far = 80.0
	add_child(camera)

## A solid obstacle (walls, buildings, rocks, trunks): physics layer 1, also blocks attacks (line of sight).
func solid(pos: Vector3, size: Vector3, rot := 0.0) -> CollisionShape3D:
	var sb := StaticBody3D.new()
	sb.position = pos + Vector3(0, size.y / 2.0, 0)
	sb.rotation_degrees.y = rot
	add_child(sb)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	sb.add_child(cs)
	return cs

## Ground with a tiling pixel texture (2 world units per 64-pixel tile, sharp pixels).
func _ground(size: Vector2, pos: Vector3, tex_name: String, tile := 2.0, tint := Color.WHITE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	mi.mesh = p
	var m := StandardMaterial3D.new()
	m.albedo_texture = Spr.tex("res://assets/ground/%s.png" % tex_name)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(size.x / tile, size.y / tile, 1)
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi

func _plane(size: Vector2, pos: Vector3, c: Color, rot := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	mi.mesh = p
	mi.material_override = Models.mat(c)
	mi.position = pos
	mi.rotation_degrees.y = rot
	add_child(mi)
	return mi

## A prop sprite that blocks movement (and fades when a hero is behind it, if `fade`).
func _sprop(name: String, pos: Vector3, st := 0, k := 1.0, block := Vector3.ZERO, fade := false) -> Spr:
	var s := Spr.prop(self, name, pos, st, k)
	if block != Vector3.ZERO:
		solid(pos, block)
	if fade:
		fades.append({"spr": s, "pos": pos, "w": maxf(0.8, s.sprite.texture.get_width() * s.px * 0.45), "a": 1.0})
	return s

func _build_ground() -> void:
	_ground(Vector2(110, 60), Vector3(17, 0, 2), "grass", 2.0)
	_ground(Vector2(56, 3.2), Vector3(16, 0.01, 0.5), "road", 2.0)
	_ground(Vector2(13, 9.5), Vector3(-5, 0.008, -2.5), "concrete", 2.0)
	for p in [Vector3(9, 0.006, 4.5), Vector3(24, 0.006, -4), Vector3(37, 0.006, 3.5), Vector3(-9, 0.006, 4.5)]:
		_ground(Vector2(4.5, 3.0), p, "mud", 2.0)
	# Grass tufts (one multimesh: cheap), muted moss colours.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Models.cyl(0.0, 0.1, 0.24, 4)
	var n := 420
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var p := Vector3(rng.randf_range(-14, 48), 0.1, rng.randf_range(-12, 16))
		if absf(p.z - 0.5) < 2.0 or (p.x < 2.0 and p.x > -12.0 and p.z > -8.0 and p.z < 3.0):
			p.z += 4.5 if p.z > 0.5 else -4.5
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), p))
		mm.set_instance_color(i, Color("#a08a3a") if rng.randf() < 0.06 else Color("#3f5a2c").lightened(rng.randf_range(-0.1, 0.18)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.roughness = 1.0
	mmi.material_override = gm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# North edge: a patched wooden fence with young trees behind; south edge: rubble and trees; rocks at the ends.
	Models.fence(self, Vector3(-13, 0, -9.5), Vector3(47, 0, -9.5))
	solid(Vector3(17, 0, -9.6), Vector3(62, 1.4, 0.4))
	for i in 20:
		_sprop("trees", Vector3(-13.0 + i * 3.1 + sin(i) * 0.8, 0, -11.0 - absf(sin(i * 2.1)) * 1.5), 0, 1.0 + 0.15 * sin(i * 1.3))
	for i in 15:
		var x := -12.0 + i * 4.1
		if absf(x - (-4.0)) < 3.5:
			continue
		_sprop("trees" if i % 3 != 1 else "stump", Vector3(x + sin(i * 3.0), 0, 13.6 + absf(sin(i)) * 1.2), 0, 1.0, Vector3.ZERO, true)
	for x in range(-12, 48, 3):
		if absf(x - (-4)) < 3:
			continue
		_sprop("rubble", Vector3(x + 0.5 * sin(x), 0, 11.8), 1 if x % 2 == 0 else 0, 0.55, Vector3.ZERO)
	solid(Vector3(-9.0, 0, 11.9), Vector3(6.5, 1.4, 0.8))
	solid(Vector3(22.5, 0, 11.9), Vector3(50, 1.4, 0.8))
	solid(Vector3(-15, 0, 2), Vector3(1, 3, 30))
	solid(Vector3(49, 0, 2), Vector3(1, 3, 30))
	solid(Vector3(-4.0, 0, 15.5), Vector3(8, 2, 1))
	for z in [-7.0, -3.0, 2.0, 7.0]:
		_sprop("rubble", Vector3(-14.2, 0, z), 0, 0.8)
		_sprop("rubble", Vector3(48.2, 0, z), 0, 0.8)

func _tree(p: Vector3, k := 1.0) -> void:
	_sprop("trees", p, 0, k, Vector3(0.6, 2.0, 0.6), true)

# ======================================================================= the Station
func _build_station() -> void:
	# The old metro entrance the settlement lives around, the workbench, crates and barrels, a lantern.
	_sprop("metro", Vector3(-9.0, 0, -6.2), 0, 1.0, Vector3(4.0, 3.0, 2.0), true)
	_sprop("bench", Vector3(-5.6, 0, -6.4), 0, 1.0, Vector3(1.8, 1.0, 0.8))
	_sprop("radio", Vector3(-5.2, 1.05, -6.35), 1, 1.0, Vector3.ZERO)
	_sprop("crate", Vector3(-11.6, 0, -3.0), 1, 1.0, Vector3(0.9, 0.7, 0.8))
	_sprop("crate", Vector3(-11.0, 0, -2.2), 0, 0.8)
	_sprop("barrel", Vector3(-6.2, 0, -3.4), 0, 1.0, Vector3(0.6, 0.8, 0.6))
	_sprop("barrel", Vector3(-5.6, 0, -2.9), 1, 1.0)
	_sprop("genset", Vector3(-12.0, 0, -0.6), 0, 1.0, Vector3(1.4, 1.0, 0.9))
	_sprop("lantern", Vector3(-7.0, 0, 2.8), 1, 1.6)
	_lamp(Vector3(-7.0, 1.2, 2.8), 4.0)
	_lamp(Vector3(-8.2, 2.6, -4.6), 6.0)
	# The water purifier (three states: broken -> working), the clean-water tank, garden beds.
	pump = Node3D.new()
	pump.position = Vector3(-2.0, 0, -5.0)
	add_child(pump)
	var pur := Spr.prop(pump, "purifier", Vector3.ZERO, 0, 1.7)
	pur.name = "Purifier"
	solid(pump.position, Vector3(2.4, 2.0, 1.2))
	var tank := Spr.prop(self, "tank", Vector3(1.4, 0, -4.8), 0, 1.0)
	tank.name = "Tank"
	solid(Vector3(1.4, 0, -4.8), Vector3(1.4, 1.2, 1.0))
	_sprop("pipe", Vector3(0.2, 0.55, -4.9), 0, 1.2)
	for i in 3:
		var b := Spr.prop(self, "bed", Vector3(-10.0 + i * 1.7, 0, 1.6), 0, 1.6)
		plants.append(b)
	solid(Vector3(-8.3, 0, 1.6), Vector3(5.0, 0.4, 0.8))
	# The flooded underpass to the south: water stands until the purifier's pump runs. The laundry beyond it.
	_plane(Vector2(5.0, 4.0), Vector3(-4.0, -0.1, 13.0), Color("#3b3a34"))
	pool_water = Models.add(self, Models.box(4.6, 0.1, 3.6), Color(0.16, 0.32, 0.36, 0.95), Vector3(-4.0, 0.06, 13.0), Vector3.ZERO, Vector3.ONE, 0.1)
	pool_body = solid(Vector3(-4.0, 0, 11.6), Vector3(4.4, 1.0, 0.6))
	_sprop("laundry_facade", Vector3(-4.6, 0, 17.6), 0, 0.55)
	_sprop("sign_station", Vector3(-1.4, 0, 11.4), 0, 0.9)
	spots.append({"id": "pump", "pos": pump.position + Vector3(0, 0, 1.6), "radius": 2.6, "needs": REPAIR_NEED, "title": "Очисник води", "action": "Полагодити", "flag": "pump_fixed", "anchor": pump.position + Vector3(0, 2.6, 0)})

func _lamp(p: Vector3, r: float) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = Color("#ffb86a")
	l.light_energy = 1.6
	l.omni_range = r
	add_child(l)

# ======================================================================= the road east
func _build_route() -> void:
	for p in [Vector3(4.5, 0, -3.5), Vector3(7.0, 0, 4.4), Vector3(14.5, 0, 4.0), Vector3(17.0, 0, -6.5), Vector3(25.5, 0, -2.0),
			Vector3(31.0, 0, 5.5), Vector3(34.0, 0, -6.0), Vector3(43.5, 0, 5.0)]:
		_tree(p, 1.1)
	_sprop("minecart", Vector3(10.5, 0, 6.5), 0, 1.4, Vector3(2.0, 1.2, 1.0))
	_sprop("washer", Vector3(29.0, 0, -5.8), 1, 1.4, Vector3(1.2, 1.2, 1.0))
	_sprop("cabinet", Vector3(21.0, 0, 6.5), 0, 1.0, Vector3(1.0, 1.6, 0.6))
	_sprop("crate", Vector3(22.2, 0, 6.6), 0, 1.0, Vector3(0.7, 0.7, 0.7))
	_sprop("rubble", Vector3(36.5, 0, 4.0), 0, 0.8, Vector3(1.2, 1.0, 0.9))
	for p in [Vector3(12.0, 0, -6.0), Vector3(39.5, 0, -5.5)]:
		_sprop("barrel", p, 1, 1.0, Vector3(0.6, 0.8, 0.6))
	_sprop("lantern", Vector3(18.5, 0, -2.6), 0, 1.5)
	_sprop("lantern", Vector3(33.0, 0, 3.0), 0, 1.5)
	_sprop("rag_pile", Vector3(27.0, 0, 2.0), 0, 1.4)
	_sprop("puddle", Vector3(15.0, 0.01, 1.4), 0, 2.0)
	_sprop("puddle", Vector3(33.0, 0.01, -0.6), 0, 2.4)
	# Gatherable: stumps with cut logs, scrap heaps.
	_node("wood_a", "wood", 2, Vector3(1.5, 0, 4.8))
	_node("wood_b", "wood", 2, Vector3(26.5, 0, 4.0))
	_node("wood_c", "wood", 2, Vector3(41.0, 0, -4.0))
	_node("wood_d", "wood", 2, Vector3(16.0, 0, 5.2))
	_node("scrap_a", "parts", 2, Vector3(23.5, 0, -5.0))
	_node("scrap_b", "parts", 2, Vector3(31.5, 0, -3.0))
	# The researcher, pinned under a sagging beam by a dead radio set.
	_sprop("radio", Vector3(20.6, 0, -5.4), 0, 1.6, Vector3(0.8, 0.8, 0.6))
	scaffold = Spr.prop(self, "beam", Vector3(19.0, 0, -3.0), 0, 0.85)
	spots.append({"id": "free", "pos": Vector3(19.0, 0, -2.2), "radius": 2.4, "needs": FREE_NEED, "title": "Балка", "action": "Підпорати й звільнити", "flag": "einstein", "anchor": Vector3(19.0, 2.2, -3.3)})

func _node(id: String, kind: String, amount: int, pos: Vector3) -> void:
	var full: Spr
	var empty: Spr
	if kind == "wood":
		full = Spr.prop(self, "stump", pos, 0, 1.0)
		empty = Spr.prop(self, "planks", pos + Vector3(0.3, 0, 0.2), 0, 1.4)
	else:
		full = Spr.prop(self, "rubble", pos, 0, 0.7)
		empty = Spr.prop(self, "rubble", pos, 1, 0.7)
	empty.visible = false
	var body := solid(pos, Vector3(1.1, 0.8, 0.8))
	nodes.append({"id": id, "kind": kind, "amount": amount, "pos": pos, "time": 1.8, "radius": 1.7, "full": full, "empty": empty, "done": false, "prog": 0.0, "body": body})

# ======================================================================= units
func _build_squad() -> void:
	mira = Hero.new()
	mira.id = "mira"
	mira.world = self
	mira.setup(Spr.character("mira", 2.1), 0.32)
	mira.base_hp = 160.0
	mira.base_atk = 16.0
	mira.attack_range = 1.5
	mira.attack_cd = 0.7
	mira.speed = 4.6
	mira.anim = {"walk": [0, 1, 2, 3], "idle": 4, "attack": 5, "work": 6, "down": 6}
	mira.role = "Механікиня · ближній бій розвідним ключем"
	mira.ability_text = "Лагодить механізми; б'є ключем того, хто поруч."
	add_child(mira)
	mira.global_position = START
	einstein = Hero.new()
	einstein.id = "einstein"
	einstein.world = self
	einstein.setup(Spr.character("einstein", 2.1), 0.32)
	einstein.base_hp = 100.0
	einstein.base_atk = 9.0
	einstein.attack_range = 5.5
	einstein.attack_cd = 1.0
	einstein.ranged = true
	einstein.speed = 4.6
	einstein.anim = {"walk": [0, 1, 2, 3], "idle": 4, "attack": 5, "work": 6, "hurt": einstein.spr.pose("hurt", 6), "down": 6}
	einstein.role = "Дослідник · дистанційна підтримка"
	einstein.ability_text = "Імпульс: хвиля з приладу б'є всіх поруч і оглушує на 2,5 с. Перезарядка 9 с."
	einstein.leader = mira
	einstein.active = false
	add_child(einstein)
	einstein.global_position = Vector3(19.2, 0, -3.6)
	einstein.face_dir = Vector3(1, 0, 0)
	heroes = [mira, einstein]
	for h in heroes:
		h.died.connect(_on_hero_down)
	mira.apply_level(1, true)
	einstein.apply_level(1, true)

func _enemy(id: String, pos: Vector3, big := false) -> Enemy:
	var e := Enemy.new()
	e.id = id
	e.world = self
	e.team = 1
	e.big = big
	e.setup(Spr.character("crawler", 0.75 if not big else 1.45, 1.1 if not big else 2.0), 0.45 if not big else 0.8)
	if big:
		e.tint = Color(0.62, 0.66, 0.78)
	e.make_telegraph()
	if big:
		e.max_hp = 260.0
		e.atk = 26.0
		e.speed = 2.6
		e.windup = 1.0
		e.recover = 1.4
		e.detect = 6.5
		e.leash = 9.0
		e.reward = {"parts": 3}
	else:
		e.max_hp = 46.0
		e.atk = 7.0
		e.speed = 3.4
		e.windup = 0.5
		e.recover = 0.9
		e.attack_range = 1.2
		e.reward = {"parts": 1}
	e.hp = e.max_hp
	e.home = pos
	add_child(e)
	e.global_position = pos
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	Spr.prop(self, "crawler_nest", pos + Vector3(0, 0, -0.6), 0, 1.5 if not big else 2.4)
	return e

func _build_enemies() -> void:
	_enemy("c1", Vector3(10.0, 0, -1.6))
	_enemy("c2", Vector3(12.0, 0, 1.6))
	_enemy("c3", Vector3(13.2, 0, -2.6))
	_enemy("c4", Vector3(35.5, 0, -2.0))
	_enemy("c5", Vector3(36.5, 0, 1.8))
	_enemy("boss", Vector3(39.0, 0, 0.0), true)

# ======================================================================= save
func _new_save() -> void:
	S = {"version": 1, "res": {"parts": 0, "wood": 0, "water": 0}, "flags": {}, "killed": {}, "harvested": {}, "levels": {"mira": 1, "einstein": 1}, "pos": [START.x, START.z], "time": 0.0}

func _load() -> void:
	_new_save()
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(d) == TYPE_DICTIONARY and int(d.get("version", 0)) == 1:
			for k in S:
				if d.has(k):
					S[k] = d[k]

func save() -> void:
	if bot and not OS.get_cmdline_user_args().has("--selftest"):
		pass
	S.pos = [mira.global_position.x, mira.global_position.z]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(S))

## Puts the world into the saved state: what was gathered, killed, opened and repaired stays that way.
func _apply_save() -> void:
	for n in nodes:
		if S.harvested.get(n.id, false):
			_set_node_done(n)
	for e in enemies:
		if S.killed.get(e.id, false):
			e.dead = true
			e.visible = false
			e.shape.disabled = true
	if S.flags.get("einstein", false):
		_free_visual(true)
	if S.flags.get("pump_fixed", false):
		_pump_visual(true)
	else:
		_pump_visual(false)
	mira.apply_level(int(S.levels.mira), true)
	einstein.apply_level(int(S.levels.einstein), true)
	var p: Array = S.pos
	mira.global_position = Vector3(p[0], 0, p[1])
	if einstein.active:
		einstein.global_position = mira.global_position + Vector3(-1.2, 0, 0.6)
	cam_target = mira.global_position
	_camera(1.0)

func _set_node_done(n: Dictionary) -> void:
	n.done = true
	n.full.visible = false
	n.empty.visible = true
	n.body.set_deferred("disabled", true)

# ======================================================================= economy
func give(res: Dictionary, at: Vector3) -> void:
	for k in res:
		S.res[k] = int(S.res.get(k, 0)) + int(res[k])
		float_text(at + Vector3(0, 1.8, 0), "+%d %s" % [res[k], RES_NAMES[k]], Color("#ffe27a"))
	_refresh()

func can_pay(cost: Dictionary) -> bool:
	for k in cost:
		if int(S.res.get(k, 0)) < int(cost[k]):
			return false
	return true

func missing_text(cost: Dictionary) -> String:
	var out := []
	for k in cost:
		var lack := int(cost[k]) - int(S.res.get(k, 0))
		if lack > 0:
			out.append("%s: ще %d" % [RES_NAMES[k], lack])
	return "Бракує — " + ", ".join(out) if not out.is_empty() else ""

## Pays once: the check and the spending happen together, so a double tap cannot spend twice.
func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for k in cost:
		S.res[k] = int(S.res[k]) - int(cost[k])
	return true

func upgrade(h: Hero) -> void:
	if h.level >= MAX_LEVEL or not pay(UPGRADE):
		return
	h.apply_level(h.level + 1)
	h.hp = h.max_hp
	S.levels[h.id] = h.level
	float_text(h.global_position + Vector3(0, 2.2, 0), "Рівень %d!" % h.level, Color("#7fe0ff"))
	_burst(h.global_position + Vector3(0, 1, 0), Color("#7fe0ff"), 14)
	save()
	_refresh()

func _refresh() -> void:
	hud.refresh(S.res, heroes)

# ======================================================================= queries for units
func nearest_enemy(from: Unit, rng: float) -> Unit:
	var best: Unit = null
	var bd := rng
	for e in enemies:
		if e.dead or not e.visible:
			continue
		var d := from.dist_to(e)
		if d <= bd and los(from.global_position, e.global_position):
			bd = d
			best = e
	return best

func nearest_hero(from: Unit, rng: float) -> Unit:
	var best: Unit = null
	var bd := rng
	for h in heroes:
		if h.dead or not h.active:
			continue
		var d := from.dist_to(h)
		if d <= bd and los(from.global_position, h.global_position):
			bd = d
			best = h
	return best

## Line of sight at chest height against walls and obstacles: no hits through walls.
func los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 0.7, 0), b + Vector3(0, 0.7, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Where a companion should be: on the leader's trail while walking, in its slot beside the leader when stopped.
func follow_point(h: Hero) -> Vector3:
	var l := h.leader
	if l.moving and trail.size() > 2:
		var want := 1.9
		var acc := 0.0
		for i in range(1, trail.size()):
			acc += trail[i].distance_to(trail[i - 1])
			if acc >= want:
				return trail[i]
		return trail[-1]
	var f := l.face_dir
	var side := Vector3(-f.z, 0, f.x)
	return l.global_position - f * 1.3 + side * 0.9

func separation(u: Unit) -> Vector3:
	var s := Vector3.ZERO
	for o in heroes + enemies:
		if o == u or o.dead or not o.visible:
			continue
		var d: Vector3 = u.global_position - o.global_position
		d.y = 0.0
		var l := d.length()
		if l < 0.9 and l > 0.001:
			s += d / l * (0.9 - l) * 2.0
	return s

func alert(e: Enemy) -> void:
	for o in enemies:
		if o != e and not o.dead and o.state == "idle" and o.dist_to(e) < 5.0:
			o.provoked(e.target)

func on_hit(u: Unit, amount: float) -> void:
	float_text(u.global_position + Vector3(0, 1.6 if u.team == 1 else 1.9, 0), "-%d" % roundi(amount), Color("#fff2c2") if u.team == 1 else Color("#ff6a5a"))
	_burst(u.global_position + Vector3(0, 0.6, 0), Color("#ffd35a") if u.team == 1 else Color("#ff6a5a"), 6)
	if u.team == 0:
		calm_t = 0.0
	elif u is Enemy:
		(u as Enemy).provoked(mira if not mira.dead else einstein)
		calm_t = 0.0

func shoot(from: Hero, t: Unit) -> void:
	var b := Node3D.new()
	Models.add(b, Models.ball(0.12), Color("#7fe8ff"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 3.0)
	add_child(b)
	b.global_position = from.global_position + Vector3(0, 0.8, 0) + from.face_dir * 0.4
	projectiles.append({"node": b, "target": t, "dmg": from.atk, "from": from.global_position})

func slam(e: Enemy, radius: float, dmg: float) -> void:
	_ring(e.global_position, radius, Color(1.0, 0.55, 0.3, 0.7), 0.4)
	for h in heroes:
		if h.active and not h.dead and h.dist_to(e) <= radius:
			h.take_damage(dmg, e.global_position)

func use_ability() -> void:
	if not einstein.active or einstein.dead or ability_cd > 0.0:
		return
	ability_cd = ABILITY_CD
	var c := einstein.global_position
	_ring(c, 4.2, Color(0.45, 0.9, 1.0, 0.75), 0.5)
	einstein.swing = 0.4
	for e in enemies:
		if not e.dead and e.visible and e.dist_to(einstein) <= 4.2:
			e.take_damage(18.0 + 6.0 * einstein.level, c)
			e.stun = 2.5
	if Engine.get_process_frames() > 0:
		float_text(c + Vector3(0, 2.4, 0), "Імпульс!", Color("#7fe8ff"))

func _on_enemy_died(u: Unit) -> void:
	var e := u as Enemy
	if S.killed.get(e.id, false):
		return
	S.killed[e.id] = true
	for k in e.reward:
		S.res[k] = int(S.res.get(k, 0)) + int(e.reward[k])
		for i in int(e.reward[k]):
			_token(k, e.global_position + Vector3(0, 0.6, 0), i * 0.12)
	if e.big:
		hud.say([["mira", "Панцирника більше нема. І деталей у нього в гнізді вистачить на насос."]])
	elif not S.flags.get("first_kill", false):
		S.flags["first_kill"] = true
		hud.say([["mira", "Ось чим вони ласують — деталі з нашого складу. Заберу назад."]])
	save()
	_refresh()

func _on_hero_down(u: Unit) -> void:
	if u == mira:
		_defeat()

func _defeat() -> void:
	hud.show_toast("Загін відступив на Станцію. Прогрес збережено.", 3.0)
	var tw := create_tween()
	tw.tween_property(hud.fade, "color:a", 1.0, 0.5)
	await tw.finished
	for e in enemies:
		e.reset_home()
	for h in heroes:
		if h.dead:
			h.revive(1.0)
		h.hp = h.max_hp
	mira.global_position = START
	if einstein.active:
		einstein.global_position = START + Vector3(-1.2, 0, 0.6)
	trail.clear()
	cam_target = START
	_camera(1.0)
	save()
	_refresh()
	var tw2 := create_tween()
	tw2.tween_property(hud.fade, "color:a", 0.0, 0.6)

# ======================================================================= interactions
func _on_action() -> void:
	var s := _spot_here()
	if s.is_empty() or S.flags.get(s.flag, false):
		return
	if not pay(s.needs):
		hud.show_toast(missing_text(s.needs), 2.0)
		return
	S.flags[s.flag] = true
	done_flash[s.id] = 2.0
	match s.id:
		"free":
			_free_visual(false)
			hud.say([["einstein", "Ох... Дякую. Я вже думав, що цей мотлох стане моїм пам'ятником."], ["mira", "Ти той дослідник з капсули? Тримайся за мною — у мене є робота для твого приладу."],
				["einstein", "Прилад дає імпульс. Повзунам він дуже не сподобається."]])
		"pump":
			_pump_visual(false)
			hud.say([["mira", "Тиск є! Чиста вода пішла в бак."], ["einstein", "І погляньте — перехід на південь осушився. Дорога до пральні відкрита."]])
	save()
	_refresh()

func _spot_here() -> Dictionary:
	for s in spots:
		if mira.dist_to_point(s.pos) <= s.radius:
			return s
	return {}

func _free_visual(instant: bool) -> void:
	einstein.active = true
	scaffold.set_state(1)
	if not instant:
		_burst(Vector3(19, 0.8, -3.3), Color("#c9b48a"), 16)
		einstein.global_position = Vector3(19.2, 0, -2.4)

func _pump_visual(instant: bool) -> void:
	var on: bool = S.flags.get("pump_fixed", false)
	var pur: Spr = pump.get_node("Purifier")
	var tank: Spr = get_node("Tank")
	pool_body.set_deferred("disabled", on)
	if not on:
		pur.set_state(0)
		tank.set_state(0)
		for b in plants:
			b.set_state(0)
		return
	if instant:
		pur.set_state(2)
		tank.set_state(1)
		pool_water.position.y = -0.3
		for b in plants:
			b.set_state(3)
		return
	pur.set_state(1)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(func(): pur.set_state(2))
	tw.tween_interval(0.8)
	tw.tween_callback(func(): tank.set_state(1))
	tw.parallel().tween_property(pool_water, "position:y", -0.3, 3.0)
	for i in plants.size():
		tw.tween_callback(func(): plants[i].set_state(2)).set_delay(0.3)
	tw.tween_interval(0.6)
	for i in plants.size():
		tw.tween_callback(func(): plants[i].set_state(3)).set_delay(0.2)
	_burst(pump.global_position + Vector3(0, 1.4, 0), Color("#7fe8ff"), 18)

## Gathering: standing still by a log pile or scrap heap, with no enemy close, works it; walking away stops.
func _gather(delta: float) -> void:
	for n in nodes:
		if n.done:
			continue
		var d := mira.dist_to_point(n.pos)
		if d < n.radius and not mira.moving and not mira.dead and not _danger(mira.global_position, 4.5):
			n.prog += delta / n.time
			mira.work = 0.15
			mira.face_dir = (n.pos - mira.global_position).normalized()
			if einstein.active and einstein.dist_to_point(n.pos) < n.radius + 1.0:
				einstein.work = 0.15
			if Engine.get_process_frames() % 12 == 0:
				_burst(n.pos + Vector3(0, 0.6, 0), Color("#d9b27a") if n.kind == "wood" else Color("#b9c2c8"), 3)
			if n.prog >= 1.0:
				_set_node_done(n)
				S.harvested[n.id] = true
				give({n.kind: n.amount}, n.pos)
				save()
			return
		else:
			n.prog = 0.0

func _danger(p: Vector3, r: float) -> bool:
	for e in enemies:
		if not e.dead and e.visible and e.state != "idle" and Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() < r:
			return true
	return false

# ======================================================================= the task
func quest() -> Array:
	var killed := 0
	for id in ["c1", "c2", "c3"]:
		if S.killed.get(id, false):
			killed += 1
	if not S.flags.get("einstein", false):
		if killed < 3 and int(S.res.parts) < 3:
			return ["Прожени повзунів %d/3" % killed, "Вони тягнуть деталі зі складу Станції. Б'єш автоматично, коли повзун поруч.", Vector3(11.5, 0, -0.5)]
		return ["Звільни дослідника", "Під риштованням біля щогли хтось кличе. Потрібні деталі, щоб підважити балку.", Vector3(19.0, 0, -2.4)]
	if not S.flags.get("pump_fixed", false):
		if can_pay(REPAIR_NEED):
			return ["Полагодь насос на Станції", "Деталей і дерева досить — повертайся.", pump.position + Vector3(0, 0, 1.6)]
		var lack := []
		if int(S.res.parts) < REPAIR_NEED.parts:
			lack.append("деталі %d/%d" % [S.res.parts, REPAIR_NEED.parts])
		if int(S.res.wood) < REPAIR_NEED.wood:
			lack.append("дерево %d/%d" % [S.res.wood, REPAIR_NEED.wood])
		var tgt := Vector3(39, 0, 0) if not S.killed.get("boss", false) else _nearest_node()
		return ["Збери на ремонт насоса", "Потрібно: " + ", ".join(lack) + ". Панцирник на сході стереже деталі; дерево — у штабелях.", tgt]
	if not ended:
		return ["Дорога до пральні відкрита", "Перехід на півдні осушено. Пройди туди.", Vector3(-4.0, 0, 12.6)]
	return ["Пробний фрагмент пройдено", "", Vector3(-4.0, 0, 12.6)]

func _nearest_node() -> Vector3:
	var best := Vector3(-2, 0, -3.4)
	var bd := INF
	for n in nodes:
		if not n.done:
			var d := mira.dist_to_point(n.pos)
			if d < bd:
				bd = d
				best = n.pos
	return best

# ======================================================================= per frame
func _process(delta: float) -> void:
	frame_ms.append(delta * 1000.0)
	if frame_ms.size() > 900:
		frame_ms.pop_front()
	S.time = float(S.get("time", 0.0)) + delta
	var v: Vector2 = bot_vec if bot else hud.joy_vec
	if not bot:
		var k := Input.get_vector("left", "right", "up", "down")
		if k.length() > 0.1:
			v = k
		if Input.is_action_just_pressed("ability"):
			use_ability()
		if Input.is_action_just_pressed("act") and hud.action_btn.visible:
			_on_action()
	if hud.modal != null or ended:
		v = Vector2.ZERO
	var move := Vector3(v.x, 0, v.y)
	mira.tick(delta, move)
	if mira.moving and (trail.is_empty() or trail[0].distance_to(mira.global_position) > 0.25):
		trail.push_front(mira.global_position)
		if trail.size() > 40:
			trail.pop_back()
	einstein.tick(delta, Vector3.ZERO)
	for e in enemies:
		e.tick(delta)
	_gather(delta)
	_projectiles(delta)
	_effects(delta)
	_camera(delta)
	_fade_occluders(delta)
	# Health comes back when nothing has hit the squad for a few seconds.
	calm_t += delta
	if calm_t > 4.0:
		for h in heroes:
			h.heal(h.max_hp * 0.08 * delta)
	ability_cd = maxf(0.0, ability_cd - delta)
	hud.set_ability(einstein.active, ability_cd / ABILITY_CD)
	# The action at an object.
	var s := _spot_here()
	var on: bool = not s.is_empty() and not S.flags.get(s.flag, false) and not mira.dead
	if on:
		var sp := camera.unproject_position(s.anchor)
		hud.set_action(s.action if can_pay(s.needs) else "Бракує деталей" if int(S.res.parts) < int(s.needs.get("parts", 0)) else "Бракує дерева", sp + Vector2(0, 8), true)
		hud.action_btn.disabled = not can_pay(s.needs)
	else:
		hud.set_action("", Vector2.ZERO, false)
	# Clean water trickles in once the pump runs.
	if S.flags.get("pump_fixed", false):
		water_t += delta
		if water_t > 3.0 and int(S.res.water) < 30:
			water_t = 0.0
			S.res.water = int(S.res.water) + 1
	for k in done_flash.keys():
		done_flash[k] -= delta
		if done_flash[k] <= 0.0:
			done_flash.erase(k)
	var q := quest()
	hud.set_quest(q[0], q[1])
	if S.flags.get("pump_fixed", false) and not ended and mira.global_position.z > 11.2 and absf(mira.global_position.x + 4.0) < 2.4:
		_finish()
	save_t += delta
	if save_t > 3.0 and calm_t > 2.0:
		save_t = 0.0
		save()
	if Engine.get_process_frames() % 6 == 0:
		_refresh()

func _camera(delta: float) -> void:
	var p := mira.global_position
	cam_target = cam_target.lerp(p, 1.0 - exp(-delta * 5.0))
	var t := cam_target
	t.x = clampf(t.x, BOUNDS.position.x + 7.0, BOUNDS.end.x - 7.0)
	t.z = clampf(t.z, BOUNDS.position.y + 3.0, BOUNDS.end.y - 4.0)
	camera.global_position = t + Vector3(0, 9.6, 7.0)
	camera.look_at(t + Vector3(0, 0.6, 0), Vector3.UP)

## Trees and buildings between the camera and a hero turn see-through, so nobody is lost behind them.
func _fade_occluders(delta: float) -> void:
	for f in fades:
		var want := 1.0
		for h in [mira, einstein]:
			if not h.active or h.dead:
				continue
			var dz: float = f.pos.z - h.global_position.z
			if absf(f.pos.x - h.global_position.x) < f.w and dz > -0.2 and dz < 2.8:
				want = 0.4
		var a := move_toward(float(f.a), want, delta * 3.0)
		if not is_equal_approx(a, f.a):
			f.a = a
			(f.spr as Spr).set_alpha(a)

func _projectiles(delta: float) -> void:
	for p in projectiles.duplicate():
		var n: Node3D = p.node
		var t: Unit = p.target
		if not is_instance_valid(t) or t.dead:
			n.queue_free()
			projectiles.erase(p)
			continue
		var to := t.global_position + Vector3(0, 0.5, 0) - n.global_position
		if to.length() < 0.35:
			t.take_damage(p.dmg, p.from)
			n.queue_free()
			projectiles.erase(p)
		else:
			n.global_position += to.normalized() * minf(to.length(), 13.0 * delta)

# ======================================================================= effects
func float_text(at: Vector3, text: String, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 44
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.7)
	l.modulate = c
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	add_child(l)
	l.global_position = at
	fx.append({"node": l, "t": 0.0, "life": 0.9, "kind": "text", "v": Vector3(0, 1.6, 0)})

func _burst(at: Vector3, c: Color, n: int) -> void:
	for i in n:
		var m := MeshInstance3D.new()
		m.mesh = Models.box(0.08, 0.08, 0.08)
		m.material_override = Models.mat(c, 1.2)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.global_position = at
		var a := randf() * TAU
		fx.append({"node": m, "t": 0.0, "life": 0.35, "kind": "spark", "v": Vector3(cos(a) * randf_range(1.5, 3.5), randf_range(1.0, 3.0), sin(a) * randf_range(1.5, 3.5))})

func _ring(at: Vector3, radius: float, c: Color, life: float) -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 6
	m.mesh = t
	m.material_override = Models.flat(c)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = at + Vector3(0, 0.1, 0)
	m.scale = Vector3(0.2, 0.2, 0.2)
	fx.append({"node": m, "t": 0.0, "life": life, "kind": "ring", "r": radius})

func _token(kind: String, at: Vector3, delay: float) -> void:
	var n := Models.token(kind)
	add_child(n)
	n.global_position = at
	fx.append({"node": n, "t": -delay, "life": 0.7, "kind": "token", "from": at})

func _effects(delta: float) -> void:
	for f in fx.duplicate():
		f.t += delta
		var n: Node3D = f.node
		var k: float = clampf(f.t / f.life, 0.0, 1.0)
		match f.kind:
			"text":
				n.global_position += f.v * delta
				(n as Label3D).modulate.a = 1.0 - k * k
			"spark":
				f.v.y -= 9.0 * delta
				n.global_position += f.v * delta
				n.scale = Vector3.ONE * (1.0 - k)
			"ring":
				n.scale = Vector3.ONE * lerpf(0.2, f.r, ease(k, 0.5))
			"token":
				if f.t > 0.0:
					var to: Vector3 = mira.global_position + Vector3(0, 1.0, 0)
					var p: Vector3 = (f.from as Vector3).lerp(to, k)
					p.y += sin(k * PI) * 1.4
					n.global_position = p
					n.rotation.y += delta * 8.0
		if f.t >= f.life:
			n.queue_free()
			fx.erase(f)

# ======================================================================= what the HUD draws over the world
func _on_screen(p: Vector3) -> bool:
	return not camera.is_position_behind(p)

func bubbles() -> Array:
	var out := []
	for s in spots:
		var done: bool = S.flags.get(s.flag, false)
		if done and not done_flash.has(s.id):
			continue
		if s.id == "free" and not S.flags.get("einstein", false) and mira.dist_to_point(s.pos) > 16.0:
			continue
		var needs := []
		for k in s.needs:
			needs.append({"kind": k, "have": int(S.res.get(k, 0)) if not done else int(s.needs[k]), "need": int(s.needs[k])})
		out.append({"p": camera.unproject_position(s.anchor), "needs": needs, "done": done, "title": s.title})
	return out

func bars() -> Array:
	var out := []
	for u in enemies:
		if u.dead or not u.visible or (u.hp >= u.max_hp and u.state == "idle"):
			continue
		out.append({"p": camera.unproject_position(u.global_position + Vector3(0, 1.3 if not u.big else 2.2, 0)), "frac": u.hp / u.max_hp, "color": Color("#e8543a"), "big": u.big})
	for h in heroes:
		if h.active and not h.dead:
			out.append({"p": camera.unproject_position(h.global_position + Vector3(0, 1.75, 0)), "frac": h.hp / h.max_hp, "color": Color("#5fd35a"), "big": false})
	return out

func progress_marks() -> Array:
	var out := []
	for n in nodes:
		if not n.done and n.prog > 0.0:
			out.append({"p": camera.unproject_position(n.pos + Vector3(0, 1.6, 0)), "frac": n.prog})
	return out

func offscreen_arrow() -> Dictionary:
	var q := quest()
	var t: Vector3 = q[2]
	var vs := get_viewport().get_visible_rect().size
	var sp := camera.unproject_position(t)
	var margin := 40.0
	if Rect2(Vector2(margin, margin), vs - Vector2(margin, margin) * 2.0).has_point(sp) and not camera.is_position_behind(t):
		return {}
	var c := vs / 2.0
	var d := (sp - c).normalized()
	var k := minf((vs.x / 2.0 - margin) / maxf(0.001, absf(d.x)), (vs.y / 2.0 - margin) / maxf(0.001, absf(d.y)))
	return {"p": c + d * k, "dir": d}

# ======================================================================= end
func _finish() -> void:
	ended = true
	S.flags["done"] = true
	save()
	var t := int(S.time)
	hud.show_end("ПРОБНИЙ ФРАГМЕНТ ПРОЙДЕНО\nЧас: %d хв %02d с\n\nЩо змінилося:\n• Дорогу від Станції очищено від повзунів.\n• Дослідник звільнений і йде із загоном.\n• Насос працює: у баку чиста вода, на грядках паростки.\n• Перехід на південь осушено — далі пральня (наступний етап).\n\nЦе тест механік. Уся геометрія — прототип, не фінальна графіка." % [t / 60, t % 60])

func restart() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()

# ======================================================================= automatic playthrough (screenshots + timing)
## `-- --demo=<folder> [--perf]`: plays the episode with a virtual stick, saves screenshots, prints stage times.
func _demo() -> void:
	var dir := "user://shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			dir = a.substr(7)
	DirAccess.make_dir_recursive_absolute(dir)
	var perf := OS.get_cmdline_user_args().has("--perf")
	var t0 := Time.get_ticks_msec()
	var stage := func(name: String):
		print("stage %-10s %5.1f s  parts %d wood %d  hp %d/%d" % [name, (Time.get_ticks_msec() - t0) / 1000.0, S.res.parts, S.res.wood, mira.hp, einstein.hp])
	await _wait(1.0)
	frame_ms.clear()
	await _shot(dir, "01-start", perf)
	await _go_to(Vector3(1.5, 0, 3.4))
	await _wait_gather()
	await _shot(dir, "02-wood", perf)
	await _go_to(Vector3(8.0, 0, 0.0))
	await _wait(0.5)
	await _shot(dir, "03-crawlers", perf)
	await _fight_until(func(): return S.killed.get("c1", false) and S.killed.get("c2", false) and S.killed.get("c3", false), Vector3(11, 0, 0))
	await _shot(dir, "04-drops", perf)
	stage.call("crawlers")
	_stats("рух+бій")
	await _go_to(Vector3(19.0, 0, -2.2))
	await _wait(0.4)
	await _shot(dir, "05-bubble", perf)
	_on_action()
	await _wait(1.2)
	await _shot(dir, "06-freed", perf)
	stage.call("freed")
	await _go_to(Vector3(23.5, 0, -3.6))
	await _wait_gather()
	await _go_to(Vector3(26.5, 0, 2.6))
	await _wait_gather()
	await _shot(dir, "07-squad", perf)
	await _go_to(Vector3(32.0, 0, 0.0))
	await _wait(0.3)
	await _fight_until(func(): return S.killed.get("boss", false), Vector3(36.5, 0, 0), true)
	await _shot(dir, "08-boss-down", perf)
	stage.call("boss")
	_stats("бій загоном")
	await _fight_until(func(): return S.killed.get("c4", false) and S.killed.get("c5", false), Vector3(36, 0, 0))
	await _go_to(Vector3(40.8, 0, -2.8))
	await _wait_gather()
	await _go_to(Vector3(31.5, 0, -1.6))
	await _wait_gather()
	hud.open_squad()
	await _wait(0.6)
	await _shot(dir, "09-squad-screen", perf)
	var b: Hero = mira
	upgrade(b)
	hud.close_modal()
	await _go_to(Vector3(16.0, 0, 3.8))
	await _wait_gather()
	await _go_to(Vector3(-2.0, 0, -3.2))
	await _wait(0.4)
	await _shot(dir, "10-pump-ready", perf)
	_on_action()
	await _wait(1.5)
	await _shot(dir, "11-repairing", perf)
	await _wait(2.0)
	await _shot(dir, "12-repaired", perf)
	stage.call("repaired")
	await _go_to(Vector3(-4.0, 0, 9.0))
	await _go_to(Vector3(-4.0, 0, 12.0))
	await _wait(1.0)
	await _shot(dir, "13-end", perf)
	stage.call("end")
	_stats("повернення")
	print("demo: %.1f s, flags %s, res %s, levels %s" % [(Time.get_ticks_msec() - t0) / 1000.0, str(S.flags.keys()), str(S.res), str(S.levels)])
	get_tree().quit()

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _shot(dir: String, n: String, perf: bool) -> void:
	await RenderingServer.frame_post_draw
	if not perf:
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])

## Walks the leader to a point with the virtual stick, steering round obstacles it bumps into.
func _go_to(p: Vector3) -> void:
	var t := 0.0
	var stuck := 0.0
	var last := mira.global_position
	var side := 1.0
	while mira.dist_to_point(p) > 0.35 and t < 30.0:
		var to := p - mira.global_position
		to.y = 0.0
		var d := to.normalized()
		if stuck > 0.4:
			d = (d + Vector3(-d.z, 0, d.x) * side * 1.5).normalized()
		bot_vec = Vector2(d.x, d.z) * clampf(to.length() / 0.8, 0.35, 1.0)
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if mira.global_position.distance_to(last) < 0.02:
			stuck += 1.0 / 60.0
			if stuck > 1.6:
				side = -side
				stuck = 0.0
		else:
			stuck = maxf(0.0, stuck - 1.0 / 60.0)
		last = mira.global_position
	bot_vec = Vector2.ZERO
	await get_tree().physics_frame
	if t >= 30.0:
		print("demo: could not reach ", p, " at ", mira.global_position)

func _wait_gather() -> void:
	var near := ""
	for n in nodes:
		if not n.done and mira.dist_to_point(n.pos) < n.radius:
			near = n.id
	print("gather at %s: %s" % [mira.global_position, near if near != "" else "nothing in reach"])
	var t := 0.0
	while t < 5.0:
		var busy := false
		for n in nodes:
			if not n.done and mira.dist_to_point(n.pos) < n.radius:
				busy = true
		if not busy:
			break
		await get_tree().physics_frame
		t += 1.0 / 60.0
	await _wait(0.3)

## Stands near the fight and lets the automatic attacks work; uses the ability when it is ready, steps in if no target.
func _fight_until(cond: Callable, around: Vector3, ability := false) -> void:
	var t := 0.0
	while not cond.call() and t < 45.0:
		var e: Unit = null
		var bd := INF
		for o in enemies:
			if not o.dead and o.visible and mira.dist_to(o) < bd and o.global_position.distance_to(around) < 9.0:
				bd = mira.dist_to(o)
				e = o
		if e and bd > mira.attack_range + (0.6 if not (e as Enemy).big else 1.0):
			var to := e.global_position - mira.global_position
			to.y = 0.0
			bot_vec = Vector2(to.x, to.z).normalized()
		else:
			bot_vec = Vector2.ZERO
		if ability and einstein.active and ability_cd <= 0.0 and e and einstein.dist_to(e) < 4.0:
			use_ability()
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if mira.dead:
			await _wait(2.5)
	bot_vec = Vector2.ZERO
	await _wait(0.8)

func _stats(label: String) -> void:
	var f := frame_ms.duplicate()
	f.sort()
	if f.is_empty():
		return
	print("%-14s frames %d  median %.1f  p95 %.1f  max %.1f ms" % [label, f.size(), f[f.size() / 2], f[int(f.size() * 0.95)], f[-1]])
	frame_ms.clear()

## `-- --selftest`: payments happen once, saved progress comes back, nothing is handed out twice.
func _selftest() -> void:
	var fails := []
	var check := func(name: String, ok: bool):
		print("%s %s" % ["OK  " if ok else "FAIL", name])
		if not ok:
			fails.append(name)
	await _wait(0.3)
	S.res.parts = 3
	mira.global_position = Vector3(19.0, 0, -2.4)
	await _wait(0.2)
	_on_action()
	_on_action()
	check.call("freeing costs 3 parts once", int(S.res.parts) == 0 and einstein.active)
	var e: Enemy = enemies[0]
	e.take_damage(999, mira.global_position)
	await _wait(0.1)
	check.call("crawler reward given", int(S.res.parts) == 1)
	_on_enemy_died(e)
	check.call("reward not given twice", int(S.res.parts) == 1)
	S.res.parts = 4
	S.res.wood = 3
	mira.global_position = pump.position + Vector3(0, 0, 1.6)
	await _wait(0.2)
	_on_action()
	_on_action()
	check.call("repair spends once", int(S.res.parts) == 0 and int(S.res.wood) == 0 and S.flags.get("pump_fixed", false))
	await _wait(3.5)
	check.call("underpass open", pool_body.disabled)
	save()
	var keep: Dictionary = S.duplicate(true)
	_new_save()
	_load()
	check.call("save restored", S.flags.get("pump_fixed", false) and S.killed.get("c1", false) and S.flags.get("einstein", false))
	S = keep
	mira.take_damage(9999, Vector3.ZERO)
	await _wait(1.6)
	check.call("defeat returns to the Station alive", not mira.dead and mira.global_position.distance_to(START) < 0.5)
	print("selftest: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().quit(0 if fails.is_empty() else 1)
