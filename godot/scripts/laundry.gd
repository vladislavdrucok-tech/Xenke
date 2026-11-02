extends Node2D
## Mission 2.2 «Пральня на затопленій вулиці».
## Street -> rusty door -> flooded hall (valve on the upper walkway drains it) -> sagging beam over rubble
## (support it with the jack, then clear the rubble) -> jammed door, Nazar freed -> two routes to the filter body:
## the upper walkway with a hole (two planks) or the machine hall with crawlers -> body onto the cart -> cargo gate
## -> Nazar pushes the cart across the yard (noise wakes a crawler, the cart stops until it is dealt with) -> home.
## World units: the ground is y = 320, walkways are y = 222, the hero is 70 tall.
## Checkpoints: entrance, rescued, route, gate. Flags and items are saved after every finished job.

const GROUND := 320.0
const DECK := 222.0
const WATER_X0 := 760.0
const WATER_X1 := 1500.0
const GAP_X0 := 1750.0
## 84 units: wider than a jump can cover (the hero crosses ~64 minus his width), still under the planks.
const GAP_X1 := 1834.0
const CART_HOME := 2190.0
const CART_SAFE := 2650.0
## M5 laundry equipment once it arrives: [prop, state, x, flip]. Placed clear of every interaction spot.
const LAUNDRY_DECO := [["washer", 0, 1576.0, false], ["washer", 1, 1660.0, false], ["rag_pile", 0, 1775.0, false],
		["sink", 0, 1872.0, false], ["washer_toppled", 0, 1985.0, true], ["laundry_basket", 0, 830.0, false], ["drying_rack", 0, 1110.0, false]]
const SPAWN := {"start": -120.0, "entrance": 640.0, "rescued": 1485.0, "route": 2095.0, "gate": 2275.0}

var hero: CharacterBody2D
var hud: CanvasLayer
var camera: Camera2D
var water: Node2D
var nazar: Npc
var props := {}
var crawlers: Array = []
var blockers := {}
var bridge: CollisionShape2D
var fx: Node2D
var font: FontFile
var sparks: Array = []
var bubbles: Array = []
var progress_of := {}
var knock_t := 0.0
var noise_t := 0.0
var pushing := false
var cart_wait_said := false
var ended := false
var frame_ms: Array[float] = []
var cam_y := 250.0
var tex := {}
var layers: Array[Node2D] = []
var facade_layer: Node2D
var inside := false

# ======================================================================= setup
func _ready() -> void:
	_input_map()
	font = load("res://assets/PixelifySans.ttf")
	var demo := false
	for a in OS.get_cmdline_user_args():
		demo = demo or a.begins_with("--demo") or a == "--selftest"
	if demo:
		Game.reset()
	else:
		Game.load_save()
	for n in ["bg_street.jpg", "bg_laundry.jpg", "bg_yard.jpg", "floor_bunker_0.png", "walkway_0.png"]:
		tex[n] = load("res://assets/rest/" + n)
	_build_world()
	_build_hero()
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.restart_requested.connect(_restart)
	hero.message.connect(func(t): hud.show_hint(t, 3.0))
	hero.job_finished.connect(func(_i): Game.save())
	hero.died.connect(_on_died)
	Game.changed.connect(_refresh)
	Game.journal_added.connect(func(t): hud.show_hint("Журнал: " + t, 3.2))
	_apply_flags()
	_respawn()
	_refresh()
	if Game.checkpoint == "start":
		hud.say([["einstein", "Сава казав: корпус фільтра лишився в старій пральні. Чуєш? Хтось стукає всередині."], ["einstein", "Двері заіржавіли. Спробую ключем."]])
	else:
		hud.show_hint("Продовжуємо з контрольної точки.", 2.5)
	if OS.get_cmdline_user_args().has("--selftest"):
		_selftest()
	elif demo:
		_demo()

func _input_map() -> void:
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE, KEY_W, KEY_UP], "act": [KEY_E]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)

func _layer(z: int, painter: Callable) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	n.draw.connect(painter.bind(n))
	layers.append(n)
	return n

func _body_rect(center: Vector2, size: Vector2, one_way := false) -> CollisionShape2D:
	var sb := StaticBody2D.new()
	add_child(sb)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = center
	cs.one_way_collision = one_way
	sb.add_child(cs)
	return cs

func _prop(id: String, art: String, x: float, y := GROUND, zone_w := 50.0, zone_offset := 0.0) -> Prop:
	var p := Prop.new()
	p.id = id
	p.art = art
	p.zone_w = zone_w
	p.zone_offset = zone_offset
	p.mission = self
	p.position = Vector2(x, y)
	add_child(p)
	props[id] = p
	return p

func _deco(art: String, x: float, y := GROUND, state := 0, z := -1) -> Prop:
	var p := Prop.new()
	p.art = art
	p.state = state
	p.zone_w = 1.0
	p.monitorable = false
	p.position = Vector2(x, y)
	p.z_index = z
	add_child(p)
	return p

func _ladder(x: float, gate := Callable()) -> void:
	var l: Interactable = preload("res://scripts/ladder.gd").new()
	l.top = DECK
	l.bottom = GROUND
	l.position = Vector2(x, GROUND)
	l.z_index = -2
	l.gate = gate
	add_child(l)
	l.set_meta("ladder", true)

func _build_world() -> void:
	_layer(-10, _draw_back)
	_layer(-5, _draw_floor)
	_layer(-4, _draw_mid)
	facade_layer = _layer(-4, _draw_facade)
	_layer(-3, _draw_decks)
	# Ground, world edges.
	_body_rect(Vector2(1300, GROUND + 20), Vector2(3400, 40))
	_body_rect(Vector2(-232, 200), Vector2(10, 400))
	_body_rect(Vector2(2862, 200), Vector2(10, 400))
	# Walkways (one-way: you can only get up by a ladder; the jump is ~44 high).
	_body_rect(Vector2((680 + 1200) / 2.0, DECK + 4), Vector2(520, 8), true)
	_body_rect(Vector2(1203, DECK - 20), Vector2(4, 40))
	_body_rect(Vector2((1530 + GAP_X0) / 2.0, DECK + 4), Vector2(GAP_X0 - 1530, 8), true)
	_body_rect(Vector2((GAP_X1 + 2080) / 2.0, DECK + 4), Vector2(2080 - GAP_X1, 8), true)
	bridge = _body_rect(Vector2((GAP_X0 + GAP_X1) / 2.0, DECK + 4), Vector2(GAP_X1 - GAP_X0, 8), true)
	# Decoration that does nothing.
	_deco("pump", 905, DECK, 0, -2).name = "Pump"
	_deco("gauge", 1092, DECK - 22, 2, -2).name = "Gauge"
	_deco("tap", 1615, GROUND, 0)
	_deco("barrel", 1820, GROUND, 1)
	_deco("tap", 2010, GROUND, 0)
	_deco("pipe", 1980, DECK - 40, 1, -4)
	_deco("barrel", 2560, GROUND, 0)
	_deco("crate", 2470, GROUND, 1)
	# M7 wall winch that opens the gate (only once the art is there): rest / chain taut.
	if not Art.prop("winch").is_empty():
		_deco("winch", 2228, GROUND - 16.0, 0, -1).name = "Winch"
	var jack := _deco("jack", 1290, GROUND, 1, 0)
	jack.name = "Jack"
	jack.visible = false
	# Things to use.
	_prop("entrance", "laundry_door", 600, GROUND, 60, -22)
	blockers.entrance = _body_rect(Vector2(600, GROUND - 46), Vector2(10, 92))
	_ladder(700)
	_prop("valve", "valve", 1060, DECK, 46)
	_prop("crate", "crate", 1150, DECK, 40)
	_ladder(1188, func(): return "Внизу ще глибоко. Спершу злий воду." if water.is_deep() else "")
	_prop("beam", "", 1290, GROUND, 60)
	_prop("rubble", "rubble", 1370, GROUND, 80, -10)
	blockers.rubble = _body_rect(Vector2(1372, GROUND - 28), Vector2(46, 56))
	_prop("door", "laundry_door", 1450, GROUND, 60, -22)
	blockers.door = _body_rect(Vector2(1450, GROUND - 46), Vector2(10, 92))
	_ladder(1550)
	_prop("gap", "", 1735, DECK, 44)
	_ladder(2065)
	_prop("body", "filter_body", 2110, GROUND, 40)
	_prop("cart", "cart", CART_HOME, GROUND, 84)
	_prop("gate", "cargo_gate", 2330, GROUND, 70, -105)
	blockers.gate = _body_rect(Vector2(2252, GROUND - 56), Vector2(10, 112))
	_prop("yard_crate", "crate", 2415, GROUND, 40)
	_prop("exit", "", 2770, GROUND, 50)
	props.gate.z_index = 1
	props.beam.highlight = Rect2(-75, -80, 150, 22)
	props.gap.highlight = Rect2(15, -6, GAP_X1 - GAP_X0, 12)
	props.exit.highlight = Rect2(-14, -58, 28, 58)
	# Water in the hall.
	water = preload("res://scripts/water.gd").new()
	water.x0 = WATER_X0
	water.x1 = WATER_X1
	water.bottom = GROUND
	water.level = 266.0
	water.z_index = 2
	add_child(water)
	# Crawlers: two asleep by food in the machine hall, one in the yard by the barrels.
	for spec in [[1700.0, 1580.0, 2040.0], [1925.0, 1580.0, 2040.0], [2530.0, 2420.0, 2790.0]]:
		var c: Interactable = preload("res://scripts/crawler.gd").new()
		var b := SpriteActor.new()
		b.name = "Body"
		b.char_name = "crawler"
		b.height = 24.0
		c.add_child(b)
		c.home = spec[0]
		c.min_x = spec[1]
		c.max_x = spec[2]
		c.floor_y = GROUND
		c.z_index = 1
		add_child(c)
		crawlers.append(c)
		var idx := crawlers.size() - 1
		c.gone_away.connect(func():
			Game.set_flag("crawler%d_gone" % idx)
			Game.save())
	# Nazar.
	nazar = Npc.new()
	nazar.position = Vector2(1478, GROUND)
	nazar.visible = false
	nazar.z_index = 0
	add_child(nazar)
	fx = _layer(5, _draw_fx)

func _build_hero() -> void:
	hero = CharacterBody2D.new()
	hero.set_script(preload("res://scripts/hero.gd"))
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 50)
	shape.shape = r
	shape.position = Vector2(0, -25)
	hero.add_child(shape)
	var b := SpriteActor.new()
	b.name = "Body"
	b.char_name = "einstein"
	b.height = 70.0
	hero.add_child(b)
	var sensor := Area2D.new()
	sensor.name = "Sensor"
	var ss := CollisionShape2D.new()
	var sr := RectangleShape2D.new()
	sr.size = Vector2(4, 40)
	ss.shape = sr
	ss.position = Vector2(0, -20)
	sensor.add_child(ss)
	hero.add_child(sensor)
	hero.z_index = 1
	add_child(hero)
	for c in crawlers:
		c.hero = hero
	for n in get_children():
		if n.has_meta("ladder"):
			n.hero = hero
	nazar.look_at = hero
	camera = Camera2D.new()
	camera.limit_left = -230
	camera.limit_right = 2860
	camera.limit_top = -40
	camera.limit_bottom = 400
	add_child(camera)

# ======================================================================= world state from flags
func _set_blocker(key: String, on: bool) -> void:
	blockers[key].set_deferred("disabled", not on)

func _apply_flags() -> void:
	props.entrance.state = 1 if Game.has("entered") else 0
	_set_blocker("entrance", not Game.has("entered"))
	if Game.has("drained"):
		water.set_level(GROUND + 4.0, true)
	props.valve.state = 1 if Game.has("drained") else 0
	get_node("Pump").state = 1 if Game.has("drained") else 0
	get_node("Gauge").state = 0 if Game.has("drained") else 2
	props.crate.state = 1 if Game.has("crate_open") else 0
	get_node("Jack").visible = Game.has("supported") and Art.prop("beam").is_empty()
	props.rubble.state = 1 if Game.has("rubble") else 0
	_set_blocker("rubble", not Game.has("rubble"))
	props.door.state = 1 if Game.has("rescued") else 0
	_set_blocker("door", not Game.has("rescued"))
	bridge.set_deferred("disabled", not Game.has("bridge"))
	props.body.visible = not (Game.has("body_taken") or Game.has("loaded"))
	props.cart.state = 1 if Game.has("loaded") else 0
	props.gate.state = 1 if Game.has("gate") else 0
	_set_blocker("gate", not Game.has("gate"))
	props.yard_crate.state = 1 if Game.has("yard_crate") else 0
	for i in crawlers.size():
		if Game.has("crawler%d_gone" % i):
			crawlers[i].st = "gone"
			crawlers[i].reset()
	_place_nazar_and_cart()

func _place_nazar_and_cart() -> void:
	pushing = false
	nazar.modulate.a = 1.0
	nazar.move_pose = -1
	nazar.target_x = NAN
	if Game.has("delivered"):
		props.cart.position.x = CART_SAFE
		nazar.position.x = CART_SAFE - 46.0
		nazar.visible = true
	elif Game.has("route"):
		props.cart.position.x = CART_HOME
		nazar.position.x = CART_HOME - 46.0
		nazar.visible = true
	else:
		props.cart.position.x = CART_HOME
		nazar.visible = false
	nazar.pose = 4

func _respawn() -> void:
	var x: float = SPAWN.get(Game.checkpoint, SPAWN.start)
	hero.global_position = Vector2(x, GROUND - 1.0)
	hero.velocity = Vector2.ZERO
	hero.climb = {}
	hero.collision_mask = 1
	cam_y = GROUND - 60.0

func _on_died() -> void:
	hud.say([["einstein", "Мене збили з ніг... Відходжу до останньої безпечної точки."]])
	hero.controls = false
	await get_tree().create_timer(1.0).timeout
	Game.hp = 100
	for c in crawlers:
		c.reset()
	_place_nazar_and_cart()
	_respawn()
	hero.controls = true
	Game.changed.emit()

func _restart() -> void:
	Game.reset()
	get_tree().reload_current_scene()

func _checkpoint(id: String) -> void:
	if Game.checkpoint != id:
		Game.reach_checkpoint(id)
		hud.show_hint("Контрольна точка збережена.", 2.2, "saved")

# ======================================================================= what each object does
## Called by every Prop: title, verb, why it is blocked, how long the job is and where the hero stands.
func info(id: String) -> Dictionary:
	match id:
		"entrance":
			if Game.has("entered"):
				return {"usable": false}
			return {"title": "Двері пральні · заіржавіли", "verb": "Відкрутити", "work": 1.7, "tool": "wrench", "spot": 578.0}
		"valve":
			if Game.has("drained"):
				return {"title": "Вентиль відводу · відкритий", "usable": false}
			return {"title": "Вентиль відводу стоку", "verb": "Крутити", "work": 2.9, "tool": "wrench", "spot": 1040.0}
		"crate":
			if Game.has("crate_open"):
				return {"usable": false}
			return {"title": "Ящик з інструментом", "verb": "Відкрити", "work": 1.0, "tool": "kneel", "spot": 1132.0}
		"beam":
			if Game.has("supported"):
				return {"usable": false}
			var why := "" if Game.count("jack") > 0 else "Балка просіла. Потрібен домкрат — пошукай у ящику на настилі."
			return {"title": "Просіла балка над завалом", "verb": "Поставити опору", "block": why, "work": 2.2, "tool": "kneel", "spot": 1272.0}
		"rubble":
			if Game.has("rubble"):
				return {"usable": false}
			var why2 := "" if Game.has("supported") else "Балка тримається на самому завалі. Спершу постав опору, інакше все впаде."
			return {"title": "Завал під балкою", "verb": "Розбирати", "block": why2, "work": 3.4, "tool": "wrench", "spot": 1336.0}
		"door":
			if Game.has("rescued"):
				return {"usable": false}
			return {"title": "Заклинені двері · за ними Назар", "verb": "Віджати", "work": 3.0, "tool": "wrench", "spot": 1430.0}
		"gap":
			if Game.has("bridge"):
				return {"usable": false}
			var why3 := "" if Game.count("planks") >= 2 else "Пролом широкий — не перестрибнеш. Потрібні 2 дошки (є %d)." % Game.count("planks")
			return {"title": "Пролом у настилі", "verb": "Закласти дошки", "block": why3, "work": 2.4, "tool": "kneel", "spot": 1742.0}
		"body":
			return {"title": "Корпус фільтра", "verb": "Підняти", "work": 1.2, "tool": "kneel", "spot": 2092.0}
		"cart":
			if Game.has("loaded"):
				return {"title": "Візок з корпусом", "usable": false}
			var why4 := "" if Game.count("filter_body") > 0 else "Візок порожній. Спершу візьми корпус фільтра."
			return {"title": "Вантажний візок", "verb": "Покласти корпус", "block": why4, "work": 1.4, "tool": "kneel", "spot": props.cart.position.x - 28.0}
		"gate":
			if Game.has("gate"):
				return {"usable": false}
			return {"title": "Вантажні ворота · ланцюговий ворот", "verb": "Крутити ворот", "work": 3.8, "tool": "wrench", "spot": 2206.0}
		"yard_crate":
			if Game.has("yard_crate"):
				return {"usable": false}
			return {"title": "Скриня біля воріт", "verb": "Обшукати", "work": 1.0, "tool": "kneel", "spot": 2398.0}
		"exit":
			if not Game.has("delivered"):
				return {"title": "Дорога на Станцію", "verb": "Йти", "block": "Спершу доведи візок з корпусом до безпечної точки."}
			return {"title": "Дорога на Станцію", "verb": "Повернутися"}
	return {}

func pulse(id: String, _n: int) -> void:
	var p: Node2D = props[id]
	var at := p.global_position + Vector2(0, -20)
	match id:
		"valve":
			at = p.global_position + Vector2(0, -34)
		"rubble":
			at = p.global_position + Vector2(-18, -30)
			p.position.x += 0.0
		"door":
			at = p.global_position + Vector2(-26, -50)
		"gate":
			at = p.global_position + Vector2(-82, -90)
		"entrance":
			at = p.global_position + Vector2(-26, -50)
	for i in 5:
		sparks.append({"p": at, "v": Vector2(randf_range(-40, 40), randf_range(-70, -10)), "t": 0.35})

func progress(id: String, p: float) -> void:
	if p <= 0.0:
		progress_of.erase(id)
	else:
		progress_of[id] = p

func done(id: String) -> void:
	progress_of.erase(id)
	match id:
		"entrance":
			Game.set_flag("entered")
			_apply_flags()
			Game.note("Відкрив заіржавілі двері пральні.")
			_checkpoint("entrance")
			hud.say([["einstein", "Зал затоплений. Вентиль стоку має бути нагорі, на настилі."]])
		"valve":
			Game.set_flag("drained")
			water.drain()
			props.valve.state = 1
			get_node("Pump").state = 1
			Game.note("Відкрив відвід — вода з залу пішла в стік, насос запрацював.")
			hud.say([["einstein", "Вода спадає. Тепер видно завал — і балку, що на ньому тримається."]])
		"crate":
			Game.set_flag("crate_open")
			props.crate.state = 1
			Game.give("jack")
			Game.give("planks", 2)
			Game.give("can")
			Game.note("У ящику знайшов домкрат, 2 дошки й консерву.")
			hud.show_hint("+ Домкрат  + Дошки ×2  + Консерва", 3.0, "jack")
		"beam":
			Game.take("jack")
			Game.set_flag("supported")
			get_node("Jack").visible = Art.prop("beam").is_empty()
			Game.note("Підпер балку домкратом — тепер завал можна розбирати безпечно.")
		"rubble":
			Game.set_flag("rubble")
			_apply_flags()
			Game.note("Розібрав завал під балкою — прохід до дверей вільний.")
			hud.say([["nazar", "Гей! Я тут, за дверима! Їх заклинило!"]])
		"door":
			Game.set_flag("rescued")
			_apply_flags()
			_free_nazar()
		"gap":
			Game.take("planks", 2)
			Game.set_flag("bridge")
			bridge.set_deferred("disabled", false)
			Game.note("Заклав пролом у верхньому настилі дошками — тихий шлях повз машинний зал.")
		"body":
			Game.set_flag("body_taken")
			Game.give("filter_body")
			props.body.visible = false
			hud.show_hint("+ Корпус фільтра (важкий — до візка донесеш)", 3.0, "filter_body")
		"cart":
			Game.take("filter_body")
			Game.set_flag("loaded")
			props.cart.state = 1
			Game.note("Корпус фільтра лежить на візку.")
			_maybe_push()
		"gate":
			Game.set_flag("gate")
			_apply_flags()
			Game.note("Відчинив вантажні ворота — короткий шлях до поселення.")
			_checkpoint("gate")
			_maybe_push()
		"yard_crate":
			Game.set_flag("yard_crate")
			props.yard_crate.state = 1
			Game.give("can")
			hud.show_hint("+ Консерва", 2.4, "can")
		"exit":
			_finish()
	Game.save()

func _free_nazar() -> void:
	Game.note("Відчинив заклинені двері — Назар вільний.")
	_checkpoint("rescued")
	nazar.visible = true
	nazar.position.x = 1478.0
	nazar.pose = 4
	hud.say([["nazar", "Думав, тут і лишусь. Я Назар, від Сави."], ["einstein", "Нам потрібен корпус фільтра. Він у дальньому кінці пральні."], ["nazar", "Машинним залом тихо не пройдеш — там кроулери біля їжі. Є ще верхній настил, але в ньому пролом."], ["nazar", "Я пройду підсобкою і чекатиму біля візка. Обирай свій шлях."]])
	await get_tree().create_timer(9.0).timeout
	if Game.has("route"):
		return
	nazar.go(1530.0, 50.0)
	await get_tree().create_timer(1.2).timeout
	var tw := create_tween()
	tw.tween_property(nazar, "modulate:a", 0.0, 0.6)
	await tw.finished
	if not Game.has("route"):
		nazar.visible = false

func _maybe_push() -> void:
	if Game.has("loaded") and Game.has("gate") and not Game.has("delivered") and not pushing:
		pushing = true
		hud.say([["nazar", "Ворота відчинені, корпус на місці. Штовхаю! Дивись уперед — візок гримить."]])

func _finish() -> void:
	if ended:
		return
	ended = true
	Game.set_flag("done")
	Game.save()
	var t := int(Game.play_time)
	var route := "верхній настил" if Game.has("bridge") else "машинний зал"
	var out := "МІСІЮ 2.2 ВИКОНАНО · Пральня на затопленій вулиці\nЧас: %d хв %02d с · шлях: %s · записів у журналі: %d\n\nЩо змінилося у світі:\n" % [t / 60, t % 60, route, Game.journal.size()]
	out += "• Зал пральні осушено, завал розібрано під опорою.\n"
	out += "• Назар вільний і лишився у вантажному дворі — тепер це точка обміну з поселенням.\n"
	out += "• Вантажні ворота відчинені: короткий шлях до поселення.\n"
	out += "• Корпус фільтра доставлено — Міра зможе збирати вузол (місія 2.3).\n"
	out += "\nПовністю — у Журналі. Почати знову: Журнал > Почати місію заново."
	hud.show_end(out)
	hero.controls = false

# ======================================================================= goals
func _goal() -> Array:
	if not Game.has("entered"):
		return ["Знайди вхід до пральні", "Стукіт чути з будівлі праворуч. Двері заіржавіли — є ключ.", "", 600.0]
	if not Game.has("drained"):
		return ["Знайди керування стоком", "Зал затоплено. Вентиль відводу — на верхньому настилі, туди веде драбина.", "", 1060.0]
	if not Game.has("supported"):
		if Game.count("jack") == 0:
			return ["Укріпи балку над завалом", "Балка просіла. Домкрат має бути в ящику з інструментом на настилі.", "Домкрат 0/1", 1150.0]
		return ["Укріпи балку над завалом", "Підстав домкрат під балку, поки не розбираєш завал.", "Домкрат 1/1", 1290.0]
	if not Game.has("rubble"):
		return ["Розбери завал", "Балка на опорі — можна розбирати.", "", 1370.0]
	if not Game.has("rescued"):
		return ["Відчини двері до Назара", "Двері заклинило. Віджми їх ключем.", "", 1450.0]
	if not Game.has("route"):
		return ["Дістанься корпусу фільтра", "Два шляхи: верхній настил (закласти пролом 2 дошками) або машинний зал з кроулерами (обійти, відволікти консервою або прогнати).", "Дошки %d/2 · Консерви %d" % [Game.count("planks"), Game.count("can")], 2110.0]
	if not Game.has("loaded"):
		if Game.count("filter_body") == 0:
			return ["Візьми корпус фільтра", "Корпус лежить біля візка.", "", 2110.0]
		return ["Поклади корпус на візок", "Назар чекає біля візка.", "", props.cart.position.x]
	if not Game.has("gate"):
		return ["Відчини вантажні ворота", "Ворот із ланцюгом — ліворуч від воріт.", "", 2206.0]
	if not Game.has("delivered"):
		return ["Проведи візок до безпечної точки", "Назар штовхає. Якщо попереду кроулер — візок стане, прожени або відволічи його.", "Консерви %d" % Game.count("can"), props.cart.position.x + 60.0]
	return ["Повертайся на Станцію", "Корпус у дворі, Назар на місці. Дорога — праворуч.", "", 2770.0]

func _refresh() -> void:
	hud.set_hp(Game.hp)
	# Flags change what the level layers show (beam, planks, puddles): redraw them.
	for l in layers:
		if l != fx:
			l.queue_redraw()

# ======================================================================= per frame
func _process(delta: float) -> void:
	frame_ms.append(delta * 1000.0)
	if frame_ms.size() > 900:
		frame_ms.pop_front()
	_camera(delta)
	# Interface.
	var g := _goal()
	var gx: float = g[3]
	var dx := gx - hero.global_position.x
	hud.set_goal(g[0], g[1], g[2], "• поруч" if absf(dx) < 26.0 else "%s %d м" % [">" if dx > 0.0 else "<", roundi(absf(dx) / 10.0)])
	hud.set_action("Стоп" if hero.job else (hero.target.verb() if hero.target else "Дія"))
	hud.set_target_hint(hero.target.title() if hero.target else "")
	# The wrench in the hand while working with it.
	var working: bool = hero.job != null and hero.at_spot() and hero.job.tool == "wrench"
	hero.body.held = "wrench" if working else ""
	if working:
		hero.body.held_angle = -0.6 + 0.9 * fmod(hero.job_t, hero.job.pulse) / hero.job.pulse
	_route_check()
	_nazar_knock(delta)
	_cart(delta)
	_pump_and_fx(delta)
	var winch := get_node_or_null("Winch")
	if winch:
		winch.state = 1 if Game.has("gate") or progress_of.has("gate") else 0
	var now_inside := hero.global_position.x > 612.0 and hero.global_position.x < 2260.0
	if now_inside != inside:
		inside = now_inside
		facade_layer.queue_redraw()

func _camera(delta: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var px := float(DisplayServer.window_get_size().x)
	var want := minf(560.0, px / 1.65)
	camera.zoom = Vector2.ONE * (vs.x / want)
	var h := vs.y / camera.zoom.y
	var up := clampf((GROUND - hero.global_position.y) / (GROUND - DECK), 0.0, 1.0)
	var target := GROUND - h * 0.26 - up * (GROUND - DECK) * 0.62
	cam_y = lerpf(cam_y, target, minf(1.0, delta * 4.0))
	camera.position = Vector2(hero.global_position.x, cam_y)

func _route_check() -> void:
	if Game.has("rescued") and not Game.has("route") and hero.global_position.x > 2075.0 and hero.is_on_floor() and hero.climb.is_empty():
		Game.set_flag("route")
		Game.note("Пройшов до корпусу фільтра (%s)." % ("верхнім настилом" if Game.has("bridge") else "через машинний зал"))
		_checkpoint("route")
		nazar.visible = true
		nazar.position.x = CART_HOME - 46.0
		nazar.modulate.a = 0.0
		nazar.target_x = NAN
		create_tween().tween_property(nazar, "modulate:a", 1.0, 0.5)
		hud.say([["nazar", "Ти пройшов! Корпус ось, візок поруч. Поклади — я повезу."]])

func _nazar_knock(delta: float) -> void:
	if not Game.has("entered") or Game.has("rescued"):
		return
	knock_t -= delta
	var near := absf(hero.global_position.x - 1450.0) < 420.0
	if knock_t <= 0.0:
		knock_t = 2.4
		bubbles.append({"p": Vector2(1450 + randf_range(-6, 6), GROUND - 100), "text": "тук-тук!" if near else "тук...", "t": 1.3})
		if not near and not Game.has("drained"):
			pass
	var door: Prop = props.door
	door.position.x = 1450.0 + (randf_range(-0.6, 0.6) if knock_t > 2.1 else 0.0)

func _cart(delta: float) -> void:
	if not pushing:
		return
	var cart: Prop = props.cart
	var front := cart.position.x + 33.0
	var danger := false
	for c in crawlers:
		if c.st in ["gone", "flee", "distracted"] or not c.visible:
			continue
		if c.global_position.x > front - 20.0 and c.global_position.x - front < 120.0:
			danger = true
	noise_t -= delta
	if noise_t <= 0.0:
		noise_t = 1.0
		for c in crawlers:
			c.noise(front)
	var behind := hero.global_position.x < cart.position.x - 160.0
	if danger or behind:
		nazar.target_x = NAN
		nazar.pose = 6
		if danger and not cart_wait_said:
			cart_wait_said = true
			hud.say([["nazar", "Стоп! Попереду кроулер. Прожени його або відволічи — я тримаю візок."]])
		return
	cart_wait_said = false
	cart.position.x = minf(CART_SAFE, cart.position.x + 30.0 * delta)
	cart.position.y = GROUND - (1.0 if int(cart.position.x / 6.0) % 2 == 0 else 0.0)
	nazar.position.x = cart.position.x - 46.0
	nazar.pose = 6
	nazar.body.face = 1
	if cart.position.x >= CART_SAFE:
		pushing = false
		cart.position.y = GROUND
		nazar.move_pose = -1
		nazar.pose = 4
		Game.set_flag("delivered")
		Game.note("Корпус фільтра доставлено у вантажний двір — звідси до поселення коротка дорога.")
		Game.save()
		hud.say([["nazar", "Звідси до поселення рукою подати. Я лишуся тут — скажу Саві, що двір тепер наш."], ["einstein", "Повертаюсь на Станцію. Міра чекає корпус."]])

func _pump_and_fx(delta: float) -> void:
	var pump: Prop = get_node("Pump")
	pump.position.x = 905.0 + (randf_range(-0.4, 0.4) if pump.state == 1 else 0.0)
	for s in sparks:
		s.t -= delta
		s.v.y += 260.0 * delta
		s.p += s.v * delta
	sparks = sparks.filter(func(s): return s.t > 0.0)
	for b in bubbles:
		b.t -= delta
		b.p.y -= 8.0 * delta
	bubbles = bubbles.filter(func(b): return b.t > 0.0)
	fx.queue_redraw()

# ======================================================================= drawing
func _tile(n: CanvasItem, t: Texture2D, x0: float, x1: float, top: float, w: float, h: float) -> void:
	var x := x0
	while x < x1 - 0.5:
		var seg := minf(w, x1 - x)
		n.draw_texture_rect_region(t, Rect2(x, top, seg, h), Rect2(0, 0, t.get_width() * seg / w, t.get_height()))
		x += seg

func _draw_back(n: Node2D) -> void:
	# Street and yard pictures carry their own pavement (its top sits at 77.5% of the height).
	n.draw_rect(Rect2(-240, -200, 3200, 700), Color("#141c22"))
	n.draw_texture_rect(tex["bg_street.jpg"], Rect2(-840, GROUND - 372, 1440, 480), false)
	n.draw_texture_rect(tex["bg_yard.jpg"], Rect2(2250, GROUND - 372, 1440, 480), false)
	# The laundry: tiled wall, darker in the machine hall.
	_tile(n, tex["bg_laundry.jpg"], 600, 2250, GROUND - 300, 450, 300)
	n.draw_rect(Rect2(600, -200, 1650, GROUND - 300 + 200), Color("#10161a"))
	n.draw_rect(Rect2(1540, GROUND - 300, 520, 300), Color(0.02, 0.04, 0.05, 0.35))

## Things standing on the floor in front of the walls: nests, the service door, laundry equipment, puddles, the facade.
func _draw_mid(n: Node2D) -> void:
	# Food scraps the crawlers sleep by (M5 nest when it arrives).
	for x in [1712.0, 1938.0, 2545.0]:
		if not Art.draw_prop(n, "crawler_nest", 0, Vector2(x + 6.0, GROUND + 1.0)):
			n.draw_rect(Rect2(x - 8, GROUND - 3, 16, 3), Color("#4d3a26"))
			n.draw_rect(Rect2(x - 3, GROUND - 5, 6, 2), Color("#7a5a3a"))
	# Nazar's service passage (M7 door when it arrives).
	if not Art.draw_prop(n, "service_door", 0, Vector2(1531, GROUND)):
		n.draw_rect(Rect2(1518, GROUND - 62, 26, 62), Color("#07090b"))
		n.draw_rect(Rect2(1516, GROUND - 64, 30, 3), Color("#3b4a52"))
	# Laundry equipment (M5): only once the sheet arrives; the hall is plain wall until then.
	for spec in LAUNDRY_DECO:
		Art.draw_prop(n, spec[0], spec[1], Vector2(spec[2], GROUND + 1.0), spec[3])
	# Puddles left after the water drained (M7).
	if Game.has("drained"):
		for x in [820.0, 1010.0, 1240.0, 1480.0]:
			Art.draw_prop(n, "puddle", 0, Vector2(x, GROUND + 2.0))


## The laundry's front (M6), its doorway around the entrance door. Once the hero is inside, the part of the front that
## stands over the hall fades, so the front reads as a wall he walked through, not one he walks in front of.
func _draw_facade(n: Node2D) -> void:
	var fa := Art.prop("laundry_facade")
	var t := Art.prop_tex("laundry_facade")
	if t == null:
		return
	var w: float = fa.w
	var h: float = fa.h
	var left := 600.0 - float(fa.get("door_x", 0.0)) - w / 2.0
	var split := 600.0 - left
	var k := t.get_width() / w
	n.draw_texture_rect_region(t, Rect2(left, GROUND - h, split, h), Rect2(0, 0, split * k, t.get_height()))
	n.draw_texture_rect_region(t, Rect2(600.0, GROUND - h, w - split, h), Rect2(split * k, 0, (w - split) * k, t.get_height()), Color(1, 1, 1, 0.22 if inside else 1.0))

func _draw_floor(n: Node2D) -> void:
	_tile(n, tex["floor_bunker_0.png"], 600, 2252, GROUND - 4, 420, 73.3)

func _draw_decks(n: Node2D) -> void:
	var w: Texture2D = tex["walkway_0.png"]
	var top := DECK - 21.0
	_tile(n, w, 680, 1205, top, 300, 54.6)
	var hole := Art.prop("walkway_hole")
	if not hole.is_empty():
		# M4, cut in two: its broken ends sit at the edges of the gap, the walkway A159 continues beyond them,
		# and the planks strip is repeated across the gap (the art's own gap is only ~39 units, a jump would clear it).
		var lw: float = hole.left_w
		var rw: float = hole.right_w
		var hh: float = hole.h
		_tile(n, w, 1530, GAP_X0 - lw, top, 300, 54.6)
		_tile(n, w, GAP_X1 + rw, 2080, top, 300, 54.6)
		n.draw_texture_rect(Art.tex("res://assets/new/walkway_hole_left.png"), Rect2(GAP_X0 - lw, top, lw, hh), false)
		n.draw_texture_rect(Art.tex("res://assets/new/walkway_hole_right.png"), Rect2(GAP_X1, top, rw, hh), false)
		if Game.has("bridge"):
			_tile(n, Art.tex("res://assets/new/walkway_hole_planks.png"), GAP_X0 - 6.0, GAP_X1 + 6.0, top + float(hole.planks_y), hole.planks_w, hole.planks_h)
	else:
		_tile(n, w, 1530, GAP_X0, top, 300, 54.6)
		_tile(n, w, GAP_X1, 2080, top, 300, 54.6)
	# The hole: broken ends, and planks once it is mended.
	if not hole.is_empty():
		pass
	elif Game.has("bridge"):
		for i in 6:
			n.draw_rect(Rect2(GAP_X0 - 2 + i * 15.5, DECK - 1, 14, 4), Color("#8a6236") if i % 2 == 0 else Color("#7a5530"))
			n.draw_rect(Rect2(GAP_X0 - 2 + i * 15.5, DECK + 3, 14, 1), Color("#3d2a18"))
	else:
		n.draw_line(Vector2(GAP_X0, DECK), Vector2(GAP_X0 + 8, DECK + 12), Color("#5a4636"), 2.0)
		n.draw_line(Vector2(GAP_X1, DECK), Vector2(GAP_X1 - 6, DECK + 14), Color("#5a4636"), 2.0)
	# The beam over the rubble: sags until the jack holds it. M3 brings its own picture (the jack is drawn in state 2).
	if Art.draw_prop(n, "beam", 1 if Game.has("supported") else 0, Vector2(1320, GROUND)):
		return
	var sag := 0.0 if Game.has("supported") else 8.0
	var a := Vector2(1215, GROUND - 70)
	var b := Vector2(1425, GROUND - 70)
	var pts := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * sag))
	n.draw_polyline(pts, Color("#2a201c"), 10.0)
	n.draw_polyline(pts, Color("#6e4a34"), 6.0)
	n.draw_polyline(pts, Color("#8c6446"), 1.5)
	for k in [0.0, 1.0]:
		var e: Vector2 = a.lerp(b, k)
		n.draw_rect(Rect2(e.x - 4, e.y - 4, 8, 8), Color("#4a3a30"))
	if Game.has("supported"):
		n.draw_rect(Rect2(1287, GROUND - 66, 6, 38), Color("#59606a"))

func _draw_fx(n: Node2D) -> void:
	for s in sparks:
		n.draw_rect(Rect2(s.p, Vector2(1.5, 1.5)), Color(1.0, 0.85, 0.4, clampf(s.t / 0.35, 0.0, 1.0)))
	for b in bubbles:
		n.draw_string(font, b.p, b.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color(1, 0.92, 0.7, clampf(b.t, 0.0, 1.0)))
	# Progress of the current job: a thin bar over the object.
	for id in progress_of:
		var p: Node2D = props[id]
		var at := Vector2(hero.job.spot_x if hero.job and not is_nan(hero.job.spot_x) else p.global_position.x, hero.global_position.y - 80)
		n.draw_rect(Rect2(at.x - 16, at.y, 32, 4), Color(0.05, 0.07, 0.08, 0.85))
		n.draw_rect(Rect2(at.x - 15, at.y + 1, 30 * progress_of[id], 2), Color("#f2c14e"))
	# A tin rolling where a distracted crawler gnaws it (M7).
	for c in crawlers:
		if c.st == "distracted":
			Art.draw_prop(n, "can_crushed", 0, Vector2(c.bait_x + 8.0, GROUND))
	# The way home sign (M7 sign when it arrives).
	var e := Vector2(2770, GROUND)
	if Art.draw_prop(n, "sign_station", 0, e):
		pass
	else:
		_code_sign(n, e)
	# The safe point for the cart.
	if Game.has("gate") and not Game.has("delivered"):
		n.draw_rect(Rect2(CART_SAFE - 30, GROUND - 2, 60, 2), Color(0.95, 0.76, 0.3, 0.6 + 0.3 * sin(Time.get_ticks_msec() / 200.0)))

func _code_sign(n: Node2D, e: Vector2) -> void:
	n.draw_rect(Rect2(e.x - 1, e.y - 56, 3, 56), Color("#5a4636"))
	n.draw_rect(Rect2(e.x - 24, e.y - 58, 48, 13), Color("#2a3236"))
	n.draw_string(font, Vector2(e.x - 24, e.y - 48), "СТАНЦІЯ >", HORIZONTAL_ALIGNMENT_CENTER, 48, 8, Color("#f2c14e"))

# ======================================================================= automatic playthrough
## `-- --demo=<folder> [--perf] [--route=low]`: plays the whole mission, saves screenshots, prints frame times.
func _demo() -> void:
	var dir := "user://shots"
	var low := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			dir = a.substr(7)
		if a == "--route=low":
			low = true
	DirAccess.make_dir_recursive_absolute(dir)
	var perf := OS.get_cmdline_user_args().has("--perf")
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(1.0).timeout
	frame_ms.clear()
	await _shot(dir, "01-street", perf)
	await _tap("jump")
	await _wait(0.18)
	await _shot(dir, "01b-jump", perf)
	await _wait(0.5)
	await _go(578)
	await _use(0.9)
	await _shot(dir, "02-door", perf)
	await _wait_job()
	await _wait(0.8)
	await _shot(dir, "03-flooded", perf)
	await _go(700)
	await _use()
	await _wait(0.6)
	await _shot(dir, "03b-ladder", perf)
	await _wait(1.2)
	await _go(1040)
	await _use(1.2)
	await _shot(dir, "04-valve", perf)
	await _wait_job()
	await _wait(1.5)
	await _shot(dir, "05-draining", perf)
	await _go(1132)
	await _use()
	await _wait_job()
	await _wait(3.5)
	await _shot(dir, "06-drained", perf)
	await _go(1188)
	await _climb()
	await _go(1335)
	await _use()
	await _wait(0.6)
	await _shot(dir, "07-no-support", perf)
	await _go(1272)
	await _use()
	await _wait_job()
	await _go(1336)
	await _use(1.4)
	await _shot(dir, "08-rubble", perf)
	await _wait_job()
	await _go(1430)
	await _use(1.0)
	await _shot(dir, "09-door", perf)
	await _wait_job()
	await _wait(1.0)
	await _shot(dir, "10-nazar", perf)
	_stats("до порятунку")
	if low:
		await _go(1640)
		await _wait(0.3)
		await _shot(dir, "11-hall", perf)
		await _go(1650)
		await _use()
		await _wait(0.8)
		await _shot(dir, "12-can", perf)
		await _go(1800)
		await _fight(crawlers[1])
		await _shot(dir, "13-fight", perf)
		await _go(2090)
	else:
		await _go(1550)
		await _climb()
		await _go(1742)
		await _shot(dir, "11-gap", perf)
		await _use()
		await _wait_job()
		await _wait(0.4)
		await _shot(dir, "12-bridge", perf)
		await _go(2065)
		await _climb()
		await _go(2090)
	_stats("маршрут")
	await _wait(0.6)
	await _go(2092)
	await _use()
	await _wait_job()
	await _go(props.cart.position.x - 20.0)
	await _use()
	await _wait_job()
	await _shot(dir, "14-loaded", perf)
	await _go(2206)
	await _use(2.0)
	await _shot(dir, "15-gate", perf)
	await _wait_job()
	await _wait(1.0)
	await _shot(dir, "16-gate-open", perf)
	# Walk ahead of the cart; deal with the yard crawler when the cart stops.
	await _go(2398)
	await _use()
	await _wait_job()
	var guard := 0
	var shot_stop := false
	while not Game.has("delivered") and guard < 120:
		guard += 1
		var c: Interactable = crawlers[2]
		var front: float = props.cart.position.x + 33.0
		var close: bool = c.visible and c.st not in ["gone", "flee", "distracted"] and c.global_position.x - front < 150.0
		if close:
			if not shot_stop:
				shot_stop = true
				await _shot(dir, "17-cart-stopped", perf)
			await _fight(c)
			await _shot(dir, "18-yard-fight", perf)
		else:
			await _go(minf(front + 60.0, 2700.0))
			await _wait(0.4)
	await _wait(0.5)
	await _shot(dir, "19-delivered", perf)
	_stats("візок")
	hud.journal.visible = true
	await _wait(0.2)
	await _shot(dir, "19b-journal", perf)
	hud.journal.visible = false
	await _go(2770)
	await _use()
	await _wait(0.6)
	await _shot(dir, "20-end", perf)
	print("demo: %.1f s real, game clock %.1f s, hp %d, route %s, flags %s" % [(Time.get_ticks_msec() - t0) / 1000.0, Game.play_time, Game.hp, "low" if low else "upper", str(Game.flags.keys())])
	print("journal: ", " | ".join(Game.journal))
	get_tree().quit()

func _shot(dir: String, n: String, perf: bool) -> void:
	await RenderingServer.frame_post_draw
	if not perf:
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _go(x: float) -> void:
	var t := 0.0
	while absf(hero.global_position.x - x) > 2.5 and t < 25.0:
		var right := x > hero.global_position.x
		Input.action_press("move_right" if right else "move_left")
		Input.action_release("move_left" if right else "move_right")
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if absf(hero.global_position.x - x) < 6.0:
			Input.action_release("move_left")
			Input.action_release("move_right")
			await get_tree().physics_frame
	Input.action_release("move_left")
	Input.action_release("move_right")
	await get_tree().physics_frame
	if t >= 25.0:
		print("demo: could not reach x=%d (at %d)" % [x, hero.global_position.x])

func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)

func _use(then := 0.0) -> void:
	await _tap("act")
	if then > 0.0:
		await _wait(then)

func _wait_job() -> void:
	var t := 0.0
	while hero.job and t < 10.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0

func _climb() -> void:
	await _use()
	await get_tree().physics_frame
	var t := 0.0
	while not hero.climb.is_empty() and t < 5.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	await _wait(0.1)

func _fight(c: Interactable) -> void:
	var t := 0.0
	while c.st not in ["gone", "flee", "distracted"] and t < 25.0:
		var d: float = absf(c.global_position.x - hero.global_position.x)
		if Game.count("can") > 0 and d > 50.0 and d < 70.0:
			await _use(0.4)
		elif d > 40.0:
			var side := -1.0 if hero.global_position.x < c.global_position.x else 1.0
			await _go(c.global_position.x + side * (60.0 if Game.count("can") > 0 else 32.0))
		else:
			await _use(0.35)
		t += 0.4
	await _wait(0.4)

func _stats(label: String) -> void:
	var f := frame_ms.duplicate()
	f.sort()
	if f.is_empty():
		return
	print("%-14s frames %d  median %.1f  p95 %.1f  max %.1f ms  fps %d" % [label, f.size(), f[f.size() / 2], f[int(f.size() * 0.95)], f[-1], Engine.get_frames_per_second()])
	frame_ms.clear()

## `-- --selftest`: save/load round trip, death -> respawn at the last checkpoint, no item handed out twice.
func _selftest() -> void:
	var fails: Array[String] = []
	var check := func(name: String, cond: bool):
		print("%s %s" % ["OK  " if cond else "FAIL", name])
		if not cond:
			fails.append(name)
	await _wait(0.5)
	for f in ["entered", "drained", "crate_open", "supported", "rubble", "rescued"]:
		Game.set_flag(f)
	Game.give("planks", 2)
	Game.give("can")
	Game.reach_checkpoint("rescued")
	Game.flags = {}
	Game.inv = {}
	check.call("load_save()", Game.load_save())
	check.call("flags restored", Game.has("rescued") and Game.has("drained"))
	check.call("items restored", Game.count("planks") == 2 and Game.count("can") == 1 and Game.count("wrench") == 1)
	_apply_flags()
	await _wait(0.3)
	check.call("water drained after load", not water.is_deep())
	check.call("door open after load", props.door.state == 1)
	check.call("crate stays empty", not props.crate.usable())
	hero.global_position = Vector2(1900, GROUND - 1)
	await _wait(0.3)
	hero.hurt(200, 1950)
	await _wait(1.6)
	check.call("respawn at rescued checkpoint", absf(hero.global_position.x - SPAWN.rescued) < 3.0)
	check.call("hp back to 100", Game.hp == 100)
	check.call("controls back", hero.controls)
	check.call("crawlers reset asleep", crawlers[0].st == "sleep" and crawlers[0].position.x == crawlers[0].home)
	print("selftest: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	Game.reset()
	get_tree().quit(0 if fails.is_empty() else 1)
