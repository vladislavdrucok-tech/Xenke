extends Node2D
## Afterfall — the Station yard in the isometric 2D view (docs/ISO_DIRECTION_UK.md).
## The yard is put together from separate layers: the ground and everything the hero is always in front of (one
## picture), objects the hero can walk behind (cut pieces, sorted with the characters by the line where they stand),
## characters, effects, interface. Interactions: storage (take / put), workbench (craft a repair kit), the water
## purifier (inspect, repair, it then makes water), the garden bed (sow, water, grow, harvest), Pavlo and the
## storekeeper (talk), the shelter (rest and save). The full chain: materials -> kit -> repair -> water -> watered bed.
## TEMPORARY ART: pieces of the owner's concept (iso/tools/build_yard.py) until the PNGs in docs/ISO_ART_LIST_UK.md come.

const SAVE_PATH := "user://iso_save.json"
const SPEED := 150.0
const ACCEL := 900.0          # px/s²: about a sixth of a second to full speed
const DECEL := 1400.0         # and a tenth to stop
## The ground is seen at a slant: going up or down the screen covers more ground per pixel, so it is slower.
const Y_FACTOR := 0.7
const TANK_MAX := 6
const KIT := {"scrap": 3, "wood": 2}
const START := Vector2(640, 560)

var D: Dictionary
var S := {}
var walk_poly: PackedVector2Array
var obstacles: Array[PackedVector2Array] = []
var sorted: Node2D
var occluders := {}
var mira: Actor
var einstein: Actor
var trail: Array[Vector2] = []
var camera: Camera2D
var hud
var job := {}                 # a job in progress: {id, t, len, done: Callable}
var drops: CPUParticles2D
var splash: CPUParticles2D
var fx: Array = []
var bot := false
var bot_vec := Vector2.ZERO
var hp := 100.0
var frame_ms: Array[float] = []
var font: Font
var water_t := 0.0
var ended := false

# ======================================================================= setup
func _ready() -> void:
	font = load("res://assets/PixelifySans.ttf")
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/yard.json"))
	walk_poly = _poly(D.walk)
	for k in D.obstacles:
		obstacles.append(_poly(D.obstacles[k]))
	var args := OS.get_cmdline_user_args()
	bot = args.has("--selftest") or args.has("--walktest") or args.has("--stroll")
	for a in args:
		bot = bot or a.begins_with("--demo")
	_keys()
	if bot:
		_new_save()
	else:
		_load()
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/yard/background.png")
	bg.centered = false
	bg.z_index = -10
	add_child(bg)
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	add_child(sorted)
	for name in D.occluders:
		var o: Dictionary = D.occluders[name]
		var s := Sprite2D.new()
		s.texture = load(o.tex)
		s.centered = false
		s.position = Vector2(o.x, o.base)
		s.offset = Vector2(0, float(o.y) - float(o.base))
		sorted.add_child(s)
		occluders[name] = {"sprite": s, "rect": Rect2(o.x, o.y, s.texture.get_width(), s.texture.get_height()), "base": float(o.base), "a": 1.0}
	mira = _actor("mira", true)
	einstein = _actor("einstein", false)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(D.size[0])
	camera.limit_bottom = int(D.size[1])
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	_build_fx()
	hud = preload("res://scripts/hud.gd").new()
	hud.world = self
	add_child(hud)
	hud.act_pressed.connect(_act)
	_apply_save()
	_refresh()
	_zoom()
	camera.reset_smoothing()
	get_viewport().size_changed.connect(_zoom)
	if not S.flags.get("intro", false):
		S.flags["intro"] = true
		hud.say([["mira", "Ось і наш двір. Очисник води знову мовчить — без нього грядки засохнуть."],
			["einstein", "Тоді почнімо з нього. Подивимося, що там зламалося."]])
	if args.has("--selftest"):
		_selftest()
	elif args.has("--walktest"):
		_walktest()
	elif args.has("--stroll"):
		_stroll()
	elif bot:
		_demo()

func _poly(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in a:
		p.append(Vector2(v[0], v[1]))
	return p

func _keys() -> void:
	var keys := {"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "act": [KEY_E, KEY_SPACE]}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)

func _actor(name: String, faces_right: bool) -> Actor:
	var a := Actor.new()
	var c: Dictionary = D.chars[name]
	a.setup(load(c.tex), faces_right, float(c.get("hip", c.h * 0.72)), float(c.get("split", c.w / 2.0)))
	a.stepped.connect(_dust)
	sorted.add_child(a)
	return a

func _zoom() -> void:
	# About 1250 image pixels across: the hero is a fifth of the screen tall, the yard reads around them.
	var vs := get_viewport().get_visible_rect().size
	camera.zoom = Vector2.ONE * (vs.x / 1250.0)

func _build_fx() -> void:
	# Water from the purifier's spout into the stone basin (on once repaired).
	drops = CPUParticles2D.new()
	drops.position = Vector2(1104, 598)
	drops.amount = 40
	drops.lifetime = 0.5
	drops.direction = Vector2(0.15, 1)
	drops.spread = 8.0
	drops.gravity = Vector2(0, 500)
	drops.initial_velocity_min = 30.0
	drops.initial_velocity_max = 50.0
	drops.scale_amount_min = 1.5
	drops.scale_amount_max = 2.5
	drops.color = Color(0.6, 0.88, 1.0, 0.9)
	drops.z_index = 5
	drops.emitting = false
	add_child(drops)
	splash = CPUParticles2D.new()
	splash.amount = 36
	splash.lifetime = 0.8
	splash.one_shot = true
	splash.explosiveness = 0.8
	splash.direction = Vector2(0, 1)
	splash.spread = 50.0
	splash.gravity = Vector2(0, 260)
	splash.initial_velocity_min = 40.0
	splash.initial_velocity_max = 90.0
	splash.scale_amount_min = 1.5
	splash.scale_amount_max = 3.0
	splash.color = Color(0.55, 0.85, 1.0, 0.9)
	splash.z_index = 5
	splash.emitting = false
	add_child(splash)

# ======================================================================= save
func _new_save() -> void:
	S = {"version": 1, "inv": {"wood": 0, "scrap": 0, "water": 0, "kit": 0, "seeds": 0, "cabbage": 0},
		"store": {"wood": 4, "scrap": 0, "cabbage": 0}, "flags": {}, "bed": 0, "grow": 0.0, "tank": 0,
		"pos": [START.x, START.y], "time": 0.0}

func _load() -> void:
	_new_save()
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(d) == TYPE_DICTIONARY and int(d.get("version", 0)) == 1:
			for k in S:
				if d.has(k):
					S[k] = d[k]

func save() -> void:
	S.pos = [mira.position.x, mira.position.y]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(S))

func _apply_save() -> void:
	mira.position = Vector2(S.pos[0], S.pos[1])
	if not can_stand(mira.position):
		mira.position = START
	einstein.position = mira.position + Vector2(-46, 18)
	if not can_stand(einstein.position):
		einstein.position = mira.position
	camera.position = mira.position
	_show_purifier()
	_show_bed()

func _show_purifier() -> void:
	var on: bool = S.flags.get("repaired", false)
	var s: Sprite2D = occluders.purifier.sprite
	s.texture = load("res://assets/yard/purifier.png" if on else "res://assets/yard/purifier_broken.png")
	drops.emitting = on

func _show_bed() -> void:
	var s: Sprite2D = occluders.bed.sprite
	s.texture = load("res://assets/yard/bed_%d.png" % int(S.bed))

func inv(k: String) -> int:
	return int(S.inv.get(k, 0))

func add(k: String, n: int, at := Vector2.ZERO) -> void:
	S.inv[k] = inv(k) + n
	if at != Vector2.ZERO and n != 0:
		_float(at, ("+%d " if n > 0 else "%d ") % n + hud.ITEM_NAMES[k], Color("#ffe27a") if n > 0 else Color("#ffb08a"))
	_refresh()

func _refresh() -> void:
	hud.refresh(S.inv)

# ======================================================================= movement and depth
func can_stand(p: Vector2) -> bool:
	for o in [Vector2.ZERO, Vector2(-12, 0), Vector2(12, 0), Vector2(0, -5), Vector2(0, 5)]:
		var q: Vector2 = p + o
		if not Geometry2D.is_point_in_polygon(q, walk_poly):
			return false
		for ob in obstacles:
			if Geometry2D.is_point_in_polygon(q, ob):
				return false
	return true

## Moves an actor, sliding along edges: full step, else along x, else along y.
## Moves an actor towards the stick's direction with acceleration, sliding along edges (full step, else along x,
## else along y); what a wall stops is taken out of the velocity, so nothing pushes into it.
func _move(a: Actor, v: Vector2, delta: float) -> void:
	var want := Vector2(v.x, v.y * Y_FACTOR) * SPEED
	if v.length() > 0.05:
		a.dir = v
	var rate := ACCEL if want.length() > 1.0 else DECEL
	a.vel = a.vel.move_toward(want, rate * delta)
	var step := a.vel * delta
	if step.length() < 0.0001:
		return
	if can_stand(a.position + step):
		a.position += step
	elif can_stand(a.position + Vector2(step.x, 0)):
		a.position += Vector2(step.x, 0)
		a.vel.y = 0.0
	elif can_stand(a.position + Vector2(0, step.y)):
		a.position += Vector2(0, step.y)
		a.vel.x = 0.0
	else:
		a.vel = Vector2.ZERO

var _following := false
func _follow(delta: float) -> void:
	var target := mira.position
	if mira.moving and trail.size() > 6:
		target = trail[mini(trail.size() - 1, 9)]
	else:
		# Stopped: a free place beside and a little in front of the leader, never on top of her.
		var back := -1.0 if mira.facing_right else 1.0
		for o in [Vector2(56 * back, 18), Vector2(-56 * back, 18), Vector2(56 * back, -14), Vector2(0, 40), Vector2(-56 * back, -14)]:
			if can_stand(mira.position + o):
				target = mira.position + o
				break
	var to := target - einstein.position
	if to.length() > 260.0:
		einstein.position = target if can_stand(target) else mira.position
		einstein.vel = Vector2.ZERO
		return
	# Sets off only when clearly behind and stops once close: no shuffling on the spot.
	if to.length() > 34.0:
		_following = true
	elif to.length() < 10.0:
		_following = false
	var v := Vector2.ZERO
	if _following:
		v = Vector2(to.x, to.y / Y_FACTOR).normalized() * clampf(to.length() / 60.0, 0.35, 1.15)
	# Never through the leader: when she comes back his way, he steps aside.
	var d := einstein.position - mira.position
	if d.length() < 50.0:
		var away := d.normalized() if d.length() > 0.5 else Vector2(-1, 0.4).normalized()
		var side := Vector2(-mira.vel.y, mira.vel.x).normalized() if mira.vel.length() > 10.0 else away
		if side.dot(away) < 0.0:
			side = -side
		v = (v * 0.3 + (away + side) * 0.6 * (1.0 - d.length() / 50.0) * 2.0).limit_length(1.2)
	_move(einstein, v, delta)
	if not einstein.moving:
		einstein.dir = Vector2(1 if mira.position.x > einstein.position.x else -1, 0)

## Objects between the camera and a character (the character's feet above the object's base line, sprites
## overlapping) fade, so nobody is lost behind the purifier, the stall or the crates.
func _fade(delta: float) -> void:
	for name in occluders:
		var o: Dictionary = occluders[name]
		var want := 1.0
		for a in [mira, einstein]:
			if a.position.y < o.base - 4.0 and a.rect().grow(-10).intersects(o.rect):
				want = 0.45
		o.a = move_toward(o.a, want, delta * 4.0)
		(o.sprite as Sprite2D).modulate.a = o.a

# ======================================================================= interactions
## What each spot offers now: verb (action button), enabled, the bubble over it.
func info(id: String) -> Dictionary:
	match id:
		"scrap":
			if S.flags.get("scrap", false):
				return {}
			return {"verb": "Розібрати ящики", "ok": true, "work": 2.0, "bubble": {"icon": "scrap", "text": "+3"}}
		"storage":
			return {"verb": "Склад", "ok": true, "talk": true}
		"workbench":
			var items := []
			for k in KIT:
				items.append({"icon": k, "text": "%d/%d" % [mini(inv(k), int(KIT[k])), KIT[k]], "ok": inv(k) >= int(KIT[k])})
			return {"verb": "Верстак", "ok": true, "bubble": {"items": items}}
		"purifier":
			if S.flags.get("repaired", false):
				return {}
			if not S.flags.get("inspected", false):
				return {"verb": "Оглянути", "ok": true, "bubble": {"icon": "kit", "text": "?"}}
			return {"verb": "Полагодити", "ok": inv("kit") > 0, "work": 2.6, "bubble": {"icon": "kit", "text": "%d/1" % mini(inv("kit"), 1), "ok": inv("kit") > 0}}
		"basin":
			if not S.flags.get("repaired", false):
				return {}
			return {"verb": "Набрати воду", "ok": int(S.tank) > 0, "work": 0.8, "bubble": {"icon": "water", "text": "%d/%d" % [int(S.tank), TANK_MAX], "ok": int(S.tank) > 0}}
		"bed":
			match int(S.bed):
				0:
					return {"verb": "Посадити", "ok": inv("seeds") > 0, "work": 1.6, "bubble": {"icon": "seeds", "text": "%d/1" % mini(inv("seeds"), 1), "ok": inv("seeds") > 0}}
				1:
					return {"verb": "Полити", "ok": inv("water") >= 2, "work": 1.6, "bubble": {"icon": "water", "text": "%d/2" % mini(inv("water"), 2), "ok": inv("water") >= 2}}
				2, 3:
					return {"verb": "Росте...", "ok": false, "bubble": {"icon": "cabbage", "text": "%d с" % ceili(float(S.grow))}}
				4:
					return {"verb": "Зібрати", "ok": true, "work": 1.4, "bubble": {"icon": "cabbage", "text": "+4", "ok": true}}
		"pavlo":
			return {"verb": "Говорити", "ok": true, "talk": true}
		"shelter":
			return {"verb": "Відпочити", "ok": true}
	return {}

func _spot_here() -> String:
	var best := ""
	var bd := 58.0
	for id in D.spots:
		var p := Vector2(D.spots[id][0], D.spots[id][1])
		var d := mira.position.distance_to(p)
		if d < bd and not info(id).is_empty():
			bd = d
			best = id
	return best

func _act() -> void:
	if not job.is_empty() or hud.modal != null or hud.dlg.visible:
		return
	var id := _spot_here()
	if id == "":
		return
	var i: Dictionary = info(id)
	if not i.get("ok", false):
		hud.toast_msg(_why(id), 2.4)
		return
	mira.dir = Vector2(D.spots[id][0], D.spots[id][1]).direction_to(_look_at(id))
	if i.has("work"):
		job = {"id": id, "t": 0.0, "len": float(i.work)}
		return
	_done(id)

func _look_at(id: String) -> Vector2:
	return {"scrap": Vector2(1110, 470), "storage": Vector2(400, 680), "workbench": Vector2(1020, 340), "purifier": Vector2(900, 560),
		"basin": Vector2(1110, 620), "bed": Vector2(940, 710), "pavlo": Vector2(1290, 620), "shelter": Vector2(470, 400)}.get(id, mira.position + Vector2(1, 0))

func _why(id: String) -> String:
	match id:
		"purifier":
			return "Потрібен ремкомплект. Його роблять на верстаті в майстерні."
		"basin":
			return "Бак ще наповнюється."
		"bed":
			if int(S.bed) == 0:
				return "Немає насіння. Павло в теплиці має запас."
			if int(S.bed) == 1:
				return "Потрібно 2 води. Набери в чаші біля очисника."
			return "Ще росте."
	return ""

func _done(id: String) -> void:
	var now: Dictionary = info(id)
	if now.is_empty() or not now.get("ok", false):
		return        # already done, or no longer possible (a second tap, a stale job)
	var at := mira.position + Vector2(0, -130)
	match id:
		"scrap":
			S.flags["scrap"] = true
			add("scrap", 3, at)
			if not S.flags.get("inspected", false):
				hud.toast_msg("Брухт знадобиться для ремонту.", 2.0)
		"storage":
			_storage()
		"workbench":
			_workbench()
		"purifier":
			if not S.flags.get("inspected", false):
				S.flags["inspected"] = true
				hud.say([["einstein", "Фільтр ціліший, ніж здавалося. Тріснула муфта й зірвало клапан."],
					["mira", "Ремкомплект зроблю на верстаті: три шматки брухту й дві дошки."],
					["mira", "Брухт — у ящиках біля майстерні, дерево — на складі в Гната."]])
			else:
				add("kit", -1, at)
				S.flags["repaired"] = true
				S.tank = 2
				_show_purifier()
				splash.position = Vector2(1110, 630)
				splash.restart()
				_burst(Vector2(940, 520), Color("#7fe8ff"))
				hud.say([["mira", "Тримає! Вода йде через фільтр — чиста."], ["einstein", "Бак біля чаші наповнюватиметься сам. Тепер грядка."]])
		"basin":
			var n := mini(int(S.tank), 3)
			S.tank = int(S.tank) - n
			add("water", n, at)
		"bed":
			match int(S.bed):
				0:
					add("seeds", -1, at)
					S.bed = 1
				1:
					add("water", -2, at)
					S.bed = 2
					S.grow = 12.0
					splash.position = Vector2(950, 712)
					splash.restart()
					hud.toast_msg("Грядку полито — зараз проростатиме.", 2.4)
				4:
					S.bed = 0
					S.flags["harvest"] = true
					add("cabbage", 4, at)
					_finish()
			_show_bed()
		"pavlo":
			if not S.flags.get("seeds", false):
				S.flags["seeds"] = true
				hud.say([["pavlo", "Насіння маю — капуста, витривала. Але без чистої води воно не зійде."],
					["pavlo", "Тримай пакетик. Посадиш на грядці біля очисника."]], func(): add("seeds", 1, mira.position + Vector2(0, -130)))
			elif not S.flags.get("repaired", false):
				hud.say([["pavlo", "Очисник спершу. Ржава вода спалить коріння."]])
			else:
				hud.say([["pavlo", "Чуєш, як дзюрчить? Тепер у нас справжній город буде."]])
		"shelter":
			hp = 100.0
			save()
			hud.toast_msg("Відпочили в укритті. Прогрес збережено.", 2.4)
	save()
	_refresh()

func can_pay(cost: Dictionary) -> bool:
	for k in cost:
		if inv(k) < int(cost[k]):
			return false
	return true

func _workbench() -> void:
	var rows := [["kit", "Ремкомплект: муфта, клапан, хомути", Color("#f2c14e")]]
	for k in KIT:
		var ok := inv(k) >= int(KIT[k])
		rows.append([k, "%s: %d / %d" % [hud.ITEM_NAMES[k], inv(k), KIT[k]], Color("#8ee07a") if ok else Color("#ff9a7a")])
	if not can_pay(KIT):
		var lack := []
		for k in KIT:
			if inv(k) < int(KIT[k]):
				lack.append("%s ще %d" % [hud.ITEM_NAMES[k], int(KIT[k]) - inv(k)])
		rows.append(["", "Бракує: " + ", ".join(lack), Color("#ffb08a")])
	hud.open_panel("Верстак", rows, [["Створити", can_pay(KIT), func(): _craft()]])

## Paying and making happen in one step, so a double tap cannot spend twice.
func _craft() -> void:
	if not can_pay(KIT):
		return
	for k in KIT:
		S.inv[k] = inv(k) - int(KIT[k])
	hud.close_panel()
	job = {"id": "craft", "t": 0.0, "len": 1.6}

func _storage() -> void:
	var rows := [["", "На складі — у загоні", Color("#f2c14e")]]
	for k in ["wood", "scrap", "cabbage"]:
		rows.append([k, "%s:  %d  —  %d" % [hud.ITEM_NAMES[k], int(S.store.get(k, 0)), inv(k)]])
	var take := mini(int(S.store.wood), 2)
	var put_any := inv("wood") + inv("scrap") + inv("cabbage") > 0
	hud.open_panel("Склад Станції", rows, [
		["Забрати дерево (%d)" % take, take > 0, func():
			S.store.wood = int(S.store.wood) - take
			add("wood", take, mira.position + Vector2(0, -130))
			save()
			_storage()],
		["Покласти все", put_any, func():
			for k in ["wood", "scrap", "cabbage"]:
				S.store[k] = int(S.store.get(k, 0)) + inv(k)
				S.inv[k] = 0
			_refresh()
			save()
			_storage()]])

# ======================================================================= the task
func quest() -> Array:
	if not S.flags.get("inspected", false):
		return ["Огляньте водоочисник", "Він стоїть посеред двору, біля грядок."]
	if not S.flags.get("repaired", false):
		if inv("kit") > 0:
			return ["Полагодь водоочисник", "Ремкомплект є — до очисника."]
		var t := "Брухт %d/3 (ящики біля майстерні), дерево %d/2 (склад). Потім — верстат." % [mini(inv("scrap"), 3), mini(inv("wood"), 2)]
		return ["Зроби ремкомплект", t]
	if int(S.bed) == 0 and inv("seeds") == 0 and not S.flags.get("harvest", false):
		return ["Візьми насіння в Павла", "Павло в теплиці праворуч."]
	if int(S.bed) == 0 and not S.flags.get("harvest", false):
		return ["Посади насіння", "Грядка перед очисником."]
	if int(S.bed) == 1:
		return ["Полий грядку", "Вода %d/2 — набери в чаші біля очисника." % mini(inv("water"), 2)]
	if int(S.bed) in [2, 3]:
		return ["Грядка росте", "Ще %d с." % ceili(float(S.grow))]
	if int(S.bed) == 4:
		return ["Збери врожай", ""]
	return ["Двір оживає", "Віднеси врожай на склад, коли захочеш."]

# ======================================================================= per frame
func _process(delta: float) -> void:
	frame_ms.append(delta * 1000.0)
	if frame_ms.size() > 900:
		frame_ms.pop_front()
	S.time = float(S.time) + delta
	var v: Vector2 = bot_vec if bot else hud.joy_vec
	if not bot:
		var k := Input.get_vector("left", "right", "up", "down")
		if k.length() > 0.1:
			v = k
		if Input.is_action_just_pressed("act"):
			_act()
	if hud.modal != null or hud.dlg.visible or ended:
		v = Vector2.ZERO
	# Moving cancels a job.
	if v.length() > 0.1 and not job.is_empty():
		job = {}
	_move(mira, v.limit_length(1.0), delta)
	if mira.moving and (trail.is_empty() or trail[0].distance_to(mira.position) > 8.0):
		trail.push_front(mira.position)
		if trail.size() > 30:
			trail.pop_back()
	_follow(delta)
	_job(delta)
	mira.animate(delta)
	einstein.animate(delta)
	_fade(delta)
	_effects(delta)
	camera.position = mira.position + Vector2(0, -40)
	# The purifier makes water once repaired; the bed grows once watered.
	if S.flags.get("repaired", false) and int(S.tank) < TANK_MAX:
		water_t += delta
		if water_t > 2.5:
			water_t = 0.0
			S.tank = int(S.tank) + 1
	if int(S.bed) in [2, 3]:
		S.grow = maxf(0.0, float(S.grow) - delta)
		var st := 2 if float(S.grow) > 6.0 else (3 if float(S.grow) > 0.0 else 4)
		if st != int(S.bed):
			S.bed = st
			_show_bed()
			save()
	var id := _spot_here()
	if id != "" and job.is_empty():
		var i: Dictionary = info(id)
		hud.set_action(i.verb, i.ok)
	else:
		hud.set_action("Стоп" if not job.is_empty() else "", false)
	var q: Array = quest()
	hud.set_quest(q[0], q[1])

func _job(delta: float) -> void:
	if job.is_empty():
		return
	job.t += delta
	mira.working = 0.2
	if job.t >= job.len:
		var id: String = job.id
		job = {}
		if id == "craft":
			add("kit", 1, mira.position + Vector2(0, -130))
			_burst(mira.position + Vector2(0, -60), Color("#ffd35a"))
			save()
		else:
			_done(id)

# ======================================================================= what the HUD draws over the world
func _screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p

func hints() -> Array:
	var out := []
	var anchors := {"scrap": Vector2(1104, 430), "workbench": Vector2(1018, 300), "purifier": Vector2(958, 476), "basin": Vector2(1112, 586),
		"bed": Vector2(948, 650), "storage": Vector2(462, 600), "pavlo": Vector2(1290, 580)}
	var here := _spot_here()
	# The workshop master (the workbench) always shows his talk mark; a repaired purifier shows what it has made.
	out.append({"p": _screen(Vector2(1130, 262)), "kind": "talk"})
	if S.flags.get("repaired", false):
		out.append({"p": _screen(anchors.purifier), "kind": "need", "items": [{"icon": "water", "text": "%d/%d" % [int(S.tank), TANK_MAX], "ok": true}]})
	for id in anchors:
		var i: Dictionary = info(id)
		if i.is_empty() or id == "basin":
			continue
		var p := _screen(anchors[id])
		if i.get("talk", false):
			if id == "pavlo" or id == here:
				out.append({"p": p, "kind": "talk"})
			continue
		if i.has("bubble") and (id == here or id in ["purifier", "bed"] or (id == "scrap" and S.flags.get("inspected", false))):
			var b: Dictionary = i.bubble
			var items: Array = b.get("items", [{"icon": b.get("icon", ""), "text": b.get("text", ""), "ok": b.get("ok", false)}])
			out.append({"p": p, "kind": "need", "items": items})
	return out

func progress() -> Dictionary:
	if job.is_empty():
		return {}
	return {"p": _screen(mira.position + Vector2(0, -150)), "frac": clampf(job.t / job.len, 0.0, 1.0)}

func _float(at: Vector2, text: String, c: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	l.position = at - Vector2(40, 0)
	l.z_index = 20
	add_child(l)
	fx.append({"node": l, "t": 0.0, "life": 1.1})

## A small puff of dust where a foot lands.
func _dust(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at + Vector2(0, -2)
	p.amount = 5
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2(0, -6)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.72, 0.62, 0.5, 0.45)
	p.z_index = 1
	add_child(p)
	p.emitting = true
	fx.append({"node": p, "t": 0.0, "life": 0.6})

func _burst(at: Vector2, c: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 24
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = c
	p.z_index = 20
	add_child(p)
	p.emitting = true
	fx.append({"node": p, "t": 0.0, "life": 1.0})

func _effects(delta: float) -> void:
	for f in fx.duplicate():
		f.t += delta
		var n: Node = f.node
		if n is Label:
			(n as Label).position.y -= 40.0 * delta
			(n as Label).modulate.a = 1.0 - pow(f.t / f.life, 2.0)
		if f.t >= f.life:
			n.queue_free()
			fx.erase(f)

func _finish() -> void:
	if ended:
		return
	ended = true
	var t := int(S.time)
	hud.say([["pavlo", "Перший урожай з чистої води! Віднеси на склад — Гнат запише."],
		["mira", "Двір оживає. Далі — майстерня й теплиця."]], func():
			ended = false
			hud.toast_msg("Пробний цикл пройдено за %d хв %02d с" % [t / 60, t % 60], 4.0))

# ======================================================================= automatic playthrough
func _demo() -> void:
	var dir := "user://shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			dir = a.substr(7)
	DirAccess.make_dir_recursive_absolute(dir)
	var t0 := Time.get_ticks_msec()
	await _wait(0.8)
	await _shot(dir, "01-start")
	await _talk()
	frame_ms.clear()
	await _go([Vector2(790, 640)])
	await _shot(dir, "02-purifier")
	await _use()
	await _talk()
	await _go([Vector2(740, 560), Vector2(800, 500), Vector2(1000, 510), Vector2(1104, 528)])
	await _use(2.4)
	await _go([Vector2(1000, 510), Vector2(800, 500), Vector2(620, 560), Vector2(590, 690), Vector2(450, 738)])
	await _use(0.5)
	await _shot(dir, "03-storage")
	_storage_take()
	hud.close_panel()
	await _go([Vector2(590, 690), Vector2(600, 560), Vector2(760, 480), Vector2(1000, 420), Vector2(1010, 394)])
	await _use(0.5)
	await _shot(dir, "05-craft")
	_craft()
	await _wait(2.0)
	await _go([Vector2(1000, 420), Vector2(800, 500), Vector2(740, 560), Vector2(790, 640)])
	await _shot(dir, "06-repair-ready")
	await _use(1.2)
	await _shot(dir, "07-repairing")
	await _wait(1.8)
	await _talk()
	await _shot(dir, "08-repaired")
	await _go([Vector2(740, 560), Vector2(800, 500), Vector2(1135, 520), Vector2(1150, 600)])
	await _use(0.4)
	await _talk()
	await _wait(0.4)
	await _go([Vector2(1140, 660), Vector2(1124, 676)])
	await _use(1.2)
	await _shot(dir, "09-water")
	await _go([Vector2(1140, 600), Vector2(1135, 520), Vector2(800, 500), Vector2(740, 560), Vector2(780, 660), Vector2(796, 762)])
	await _use(2.0)
	await _shot(dir, "10-sown")
	await _use(2.0)
	await _shot(dir, "11-watered")
	await _go([Vector2(780, 660), Vector2(600, 690)])
	await _wait(0.6)
	await _shot(dir, "12-behind-stall")
	await _go([Vector2(780, 660), Vector2(796, 762)])
	while int(S.bed) != 4:
		await _wait(0.5)
	await _shot(dir, "13-grown")
	await _use(1.8)
	await _talk()
	await _shot(dir, "14-harvest")
	_stats("усе")
	print("demo: %.1f s, flags %s, inv %s, bed %d" % [(Time.get_ticks_msec() - t0) / 1000.0, str(S.flags.keys()), str(S.inv), int(S.bed)])
	get_tree().quit()

## `-- --walktest=<folder>`: walking frames around Mira (right, then up-left), to look at the gait.
func _walktest() -> void:
	var dir := "user://walk"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--walktest="):
			dir = a.substr(11)
	DirAccess.make_dir_recursive_absolute(dir)
	hud.lines.clear()
	hud.next_line()
	await _wait(0.5)
	var n := 0
	for leg in [[Vector2(1, 0), 1.4], [Vector2(-0.6, -0.8), 1.2], [Vector2.ZERO, 0.5]]:
		bot_vec = leg[0]
		var t := 0.0
		while t < leg[1]:
			await _wait(0.07)
			t += 0.07
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var sp := _screen(mira.position)
			var z := camera.zoom.x
			var r := Rect2i(int(sp.x - 70 * z), int(sp.y - 130 * z), int(140 * z), int(150 * z))
			img.get_region(r).save_png("%s/w%03d.png" % [dir, n])
			n += 1
	get_tree().quit()

## `-- --stroll`: a short walk round the yard (for a video of the movement).
func _stroll() -> void:
	hud.lines.clear()
	hud.next_line()
	await _wait(0.6)
	for leg in [[Vector2(1, 0), 1.6], [Vector2.ZERO, 0.6], [Vector2(0.7, 0.7), 1.2], [Vector2(-1, 0), 1.8], [Vector2.ZERO, 0.5],
			[Vector2(0, -1), 1.2], [Vector2(-0.5, 0.3), 0.6], [Vector2(0.4, 0), 0.8], [Vector2.ZERO, 1.0]]:
		bot_vec = leg[0]
		await _wait(leg[1])
	get_tree().quit()

func _storage_take() -> void:
	var take := mini(int(S.store.wood), 2)
	S.store.wood = int(S.store.wood) - take
	add("wood", take, mira.position + Vector2(0, -130))

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _shot(dir: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	if not OS.get_cmdline_user_args().has("--perf"):
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])

func _talk() -> void:
	await _wait(0.6)
	while hud.dlg.visible:
		await _shot_maybe()
		hud.next_line()
		await _wait(0.5)

var _talk_shot := false
func _shot_maybe() -> void:
	if not _talk_shot:
		_talk_shot = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--demo="):
				await _shot(a.substr(7), "00-dialogue")

func _go(points: Array) -> void:
	for p in points:
		var t := 0.0
		while mira.position.distance_to(p) > 8.0 and t < 12.0:
			var d: Vector2 = p - mira.position
			bot_vec = d.normalized() * clampf(d.length() / 30.0, 0.3, 1.0)
			await get_tree().process_frame
			t += get_process_delta_time()
		if t >= 12.0:
			print("demo: could not reach ", p, " at ", mira.position)
	bot_vec = Vector2.ZERO
	await get_tree().process_frame

func _use(then := 0.0) -> void:
	_act()
	await _wait(then if then > 0.0 else 0.2)
	while not job.is_empty():
		await get_tree().process_frame

func _stats(label: String) -> void:
	var f := frame_ms.duplicate()
	f.sort()
	if f.is_empty():
		return
	print("%-6s frames %d  median %.1f  p95 %.1f  max %.1f ms" % [label, f.size(), f[f.size() / 2], f[int(f.size() * 0.95)], f[-1]])

## `-- --selftest`: crafting and repair spend once, the chain works, progress survives a reload.
func _selftest() -> void:
	var fails := []
	var check := func(name: String, ok: bool):
		print("%s %s" % ["OK  " if ok else "FAIL", name])
		if not ok:
			fails.append(name)
	await _wait(0.3)
	hud.lines.clear()
	hud.next_line()
	S.inv.scrap = 3
	S.inv.wood = 2
	_craft()
	_craft()
	await _wait(1.9)
	check.call("craft spends once, makes one kit", inv("kit") == 1 and inv("scrap") == 0 and inv("wood") == 0)
	S.flags["inspected"] = true
	mira.position = Vector2(D.spots.purifier[0], D.spots.purifier[1])
	_done("purifier")
	_done("purifier")
	check.call("repair uses the kit once", inv("kit") == 0 and S.flags.get("repaired", false))
	hud.lines.clear()
	hud.next_line()
	S.tank = 3
	_done("basin")
	check.call("water from the basin", inv("water") == 3 and int(S.tank) == 0)
	S.inv.seeds = 1
	S.bed = 0
	_done("bed")
	_done("bed")
	check.call("sow then water", int(S.bed) == 2 and inv("water") == 1 and inv("seeds") == 0)
	_done("scrap")
	_done("scrap")
	check.call("scrap crates give once", inv("scrap") == 3)
	check.call("walking area blocks the purifier", not can_stand(Vector2(950, 600)) and can_stand(START))
	save()
	var keep: Dictionary = S.duplicate(true)
	_new_save()
	_load()
	check.call("save restored", S.flags.get("repaired", false) and int(S.bed) == 2 and inv("scrap") == 3)
	print("selftest: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().quit(0 if fails.is_empty() else 1)
