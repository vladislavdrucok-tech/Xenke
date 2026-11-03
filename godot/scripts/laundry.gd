extends Node2D
## Mission 2.2 «Пральня на затопленій вулиці», the full run from docs/STORY_MISSIONS_UK.md (six stages):
##  1 Approach   the street before the laundry is flooded: find a hook, pull down the fire-escape ladder, cross the
##               balconies (lower the emergency bridge, climb a crate onto the roof gangway, jump down to the last
##               balcony), go down into the courtyard and follow Nazar's knocking to the laundry's side door.
##  2 Recon      the drain valve on the walkway works only once the water has somewhere to go: clear the courtyard
##               drain, patch the burst bypass pipe (clamp + rag), start the generator for the pump. Trying the valve
##               first tells what is missing; the goal shows the plan as a checklist.
##  3 Drain      water goes; talk to Nazar through the vent, support the beam with the jack, clear the rubble, free him.
##  4 Route      upper walkway (mend the hole with planks, time the water jet) or the machine hall with three crawlers
##               (sneak, throw a tin, fight, or start a washer drum to lure them away and slip past).
##  5 Delivery   straps from the locker, body onto the cart and strapped down, gate winch, Nazar pushes; debris on the
##               way and the noise wakes a crawler: the cart waits until the way is clear.
##  6 Return     the Station: tell Yana, take the body off the cart, set it on Mira's bench - assembly starts (2.3).
## World units: the ground is y = 320, walkways y = 222, the hero is 70 tall. Checkpoints: entrance, rescued, route,
## gate, station; flags, items and the journal are saved after every finished job.

const GROUND := 320.0
const DECK := 222.0
const ROOF := 180.0
const WATER_X0 := 760.0
const WATER_X1 := 1500.0
const FLOOD_X0 := -1460.0
const FLOOD_X1 := -760.0
const GAP_X0 := 1750.0
## 84 units: wider than a jump can cover (the hero crosses ~64 minus his width), still under the planks.
const GAP_X1 := 1834.0
const BR_X0 := -1330.0
const BR_X1 := -1240.0
const JET_X := 1962.0
const CART_HOME := 2300.0
const CART_SAFE := 2850.0
const WASHER_X := 1612.0
const STATION_X0 := 5000.0
const STATION_X1 := 5900.0
## M5 laundry equipment once it arrives: [prop, state, x, flip]. Placed clear of every interaction spot.
const LAUNDRY_DECO := [["washer", 1, 1690.0, false], ["rag_pile", 0, 1775.0, false], ["sink", 0, 1872.0, false],
		["washer_toppled", 0, 1985.0, true], ["laundry_basket", 0, 830.0, false]]
const SPAWN := {"start": -1930.0, "entrance": 640.0, "rescued": 1485.0, "route": 2245.0, "gate": 2425.0, "station": 5060.0}

var hero: CharacterBody2D
var hud: CanvasLayer
var camera: Camera2D
var water: Node2D
var flood: Node2D
var nazar: Npc
var yana: Npc
var mira: Npc
var props := {}
var crawlers: Array = []
var blockers := {}
var bridge: CollisionShape2D
var em_bridge: CollisionShape2D
var fire_ladder: Interactable
var fx: Node2D
var font: FontFile
var sparks: Array = []
var bubbles: Array = []
var drops: Array = []
var progress_of := {}
var knock_t := 0.0
var noise_t := 0.0
var jet_t := 0.0
var washer_t := 0.0
var pushing := false
var cart_wait_said := ""
var ended := false
var frame_ms: Array[float] = []
var cam_y := 250.0
var tex := {}
var layers: Array[Node2D] = []
var facade_layer: Node2D
var floor_band: Node2D
var inside := false
var last_safe := Vector2(-1930, GROUND)
var fade: ColorRect
var said := {}

# ======================================================================= setup
func _ready() -> void:
	_input_map()
	font = load("res://assets/PixelifySans.ttf")
	var demo := false
	for a in OS.get_cmdline_user_args():
		demo = demo or a.begins_with("--demo") or a == "--selftest"
	if demo:
		Game.reset()
	elif Game.load_save():
		_migrate()
	for n in ["bg_street.jpg", "bg_laundry.jpg", "bg_yard.jpg", "bg_court.jpg", "bg_station.jpg", "bg_workshop.jpg", "floor_bunker_0.png", "walkway_0.png", "ladder_0.png"]:
		tex[n] = Art.tex("res://assets/rest/" + n)
	_build_world()
	_build_hero()
	_build_depth()
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.restart_requested.connect(_restart)
	hud.light_toggled.connect(_apply_light)
	hero.message.connect(func(t): hud.show_hint(t, 3.0))
	hero.job_finished.connect(func(_i): Game.save())
	hero.died.connect(_on_died)
	Game.changed.connect(_refresh)
	Game.journal_added.connect(func(t): hud.show_hint("Журнал: " + t, 3.2))
	var fl := CanvasLayer.new()
	fl.layer = 10
	add_child(fl)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.03, 0.04, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.add_child(fade)
	_apply_flags()
	_apply_light()
	_respawn()
	_refresh()
	if Game.checkpoint == "start":
		hud.say([["einstein", "Сава казала: корпус фільтра лишився в старій пральні, за цим кварталом."], ["einstein", "Вулицю залило — течія під ногами. Треба обійти верхом, через будинок."]])
	else:
		hud.show_hint("Продовжуємо з контрольної точки.", 2.5)
	if OS.get_cmdline_user_args().has("--selftest"):
		_selftest()
	elif demo:
		_demo()

## A save from an older build lacks the flags of stages added later: whatever the player already got past implies them.
## Applied after every load, so it also repairs a half-migrated save.
func _migrate() -> void:
	if Game.loaded_version < 2 and Game.has("crawler2_gone"):
		Game.flags.erase("crawler2_gone")      # the yard crawler was #2, it is #3 now
		Game.flags["crawler3_gone"] = true
	var implies := {
		"entered": ["ladder_down", "em_bridge", "court"],
		"drained": ["entered", "plan_known", "drain_clear", "pipe_fixed", "power"],
		"rescued": ["drained", "talked", "supported", "rubble"],
		"route": ["rescued"],
		"gate": ["route", "loaded", "secured"],
		"delivered": ["gate", "debris"],
		"station": ["delivered"],
	}
	var changed := true
	while changed:
		changed = false
		for f in implies:
			if Game.has(f):
				for g in implies[f]:
					if not Game.has(g):
						Game.flags[g] = true
						changed = true
	if Game.loaded_version < 2 and Game.has("loaded") and not Game.has("secured"):
		Game.flags["secured"] = true             # there were no straps before; a loaded cart counts as strapped
	Game.loaded_version = 2
	Game.save()

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

## A walkway between x0 and x1 at height y: you stand on it, you can jump up through it, but not walk off a ladder into it.
func _deck(x0: float, x1: float, y := DECK) -> CollisionShape2D:
	return _body_rect(Vector2((x0 + x1) / 2.0, y + 4), Vector2(x1 - x0, 8), true)

func _prop(id: String, art: String, x: float, y := GROUND, zone_w := 50.0, zone_offset := 0.0, scale := 1.0) -> Prop:
	var p := Prop.new()
	p.id = id
	p.art = art
	p.art_scale = scale
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

func _ladder(x: float, gate := Callable()) -> Interactable:
	var l: Interactable = preload("res://scripts/ladder.gd").new()
	l.top = DECK
	l.bottom = GROUND
	l.position = Vector2(x, GROUND)
	l.z_index = -2
	l.gate = gate
	add_child(l)
	l.set_meta("ladder", true)
	return l

func _crawler(home: float, min_x: float, max_x: float) -> void:
	var c: Interactable = preload("res://scripts/crawler.gd").new()
	var b := SpriteActor.new()
	b.name = "Body"
	b.char_name = "crawler"
	b.height = 24.0
	c.add_child(b)
	c.home = home
	c.min_x = min_x
	c.max_x = max_x
	c.floor_y = GROUND
	c.z_index = 1
	add_child(c)
	crawlers.append(c)
	var idx := crawlers.size() - 1
	c.gone_away.connect(func():
		Game.set_flag("crawler%d_gone" % idx)
		Game.save())

func _npc(char_name: String, x: float, height := 68.0) -> Npc:
	var n := Npc.new()
	n.char_name = char_name
	n.height = height
	n.position = Vector2(x, GROUND)
	add_child(n)
	return n

func _build_world() -> void:
	_layer(-10, _draw_back)
	_layer(-5, _draw_floor)
	floor_band = _layer(-5, _draw_floor_band)
	_layer(-4, _draw_mid)
	facade_layer = _layer(-4, _draw_facade)
	_layer(-3, _draw_decks)
	# Ground and world edges (the Station is a separate room far to the right).
	_body_rect(Vector2(500, GROUND + 20), Vector2(5200, 40))
	_body_rect(Vector2(5450, GROUND + 20), Vector2(1100, 40))
	_body_rect(Vector2(-2032, 200), Vector2(10, 400))
	_body_rect(Vector2(3012, 200), Vector2(10, 400))
	_body_rect(Vector2(STATION_X0 - 8, 200), Vector2(10, 400))
	_body_rect(Vector2(STATION_X1 + 8, 200), Vector2(10, 400))
	# ---- 1. approach: balconies over the flooded street.
	_deck(-1640, BR_X0)
	em_bridge = _deck(BR_X0, BR_X1)
	_deck(BR_X1, -1030)
	_body_rect(Vector2(-1050, DECK - 12), Vector2(24, 24))          # a crate on the balcony: the step up to the roof
	_deck(-1010, -880, ROOF)
	_deck(-820, -660)
	_deco("crate", -1050, DECK, 0, -2)
	_deco("barrel", -1795, GROUND, 0)
	_deco("crate", -1990, GROUND, 1)
	fire_ladder = _ladder(-1610, func(): return "" if Game.has("ladder_down") else "Драбину підтягнуто вгору.")
	_ladder(-680)
	_prop("street_crate", "crate", -1860, GROUND, 40)
	_prop("scrap", "rubble", -1735, GROUND, 56, 0.0, 0.5)
	_prop("fire_ladder", "", -1610, GROUND, 40)
	_prop("em_bridge", "em_bridge", BR_X0 - 25.0 + 56.0, DECK + 23.0, 46, -70)
	flood = preload("res://scripts/water.gd").new()
	flood.x0 = FLOOD_X0
	flood.x1 = FLOOD_X1
	flood.bottom = GROUND
	flood.level = 268.0
	flood.z_index = 2
	add_child(flood)
	# ---- courtyard.
	_prop("rack", "drying_rack" if not Art.prop("drying_rack").is_empty() else "", -430, GROUND, 50)
	_prop("drain", "", 300, GROUND, 50)
	# ---- 2-3. laundry hall.
	_deco("pump", 905, DECK, 0, -2).name = "Pump"
	_deco("gauge", 1092, DECK - 22, 2, -2).name = "Gauge"
	get_node("Gauge").ground_shadow = false
	_deco("barrel", 1820, GROUND, 1)
	_deco("tap", 2010, GROUND, 0)
	_deco("pipe", JET_X, DECK - 44, 0, -4).name = "JetPipe"
	get_node("JetPipe").ground_shadow = false
	_deco("barrel", 2710, GROUND, 0)
	_deco("crate", 2930, GROUND, 1)
	if not Art.prop("winch").is_empty():
		_deco("winch", 2378, GROUND - 16.0, 0, -1).name = "Winch"
		get_node("Winch").ground_shadow = false
	var jack := _deco("jack", 1290, GROUND, 1, 0)
	jack.name = "Jack"
	jack.visible = false
	_prop("entrance", "laundry_door", 600, GROUND, 60, -22)
	blockers.entrance = _body_rect(Vector2(600, GROUND - 46), Vector2(10, 92))
	_prop("generator", "generator", 652, GROUND, 46)
	_ladder(700)
	_deck(680, 1200)
	_body_rect(Vector2(1203, DECK - 20), Vector2(4, 40))
	_prop("pipe", "pipe", 990, DECK - 28.0, 46).ground_shadow = false
	_prop("valve", "valve", 1060, DECK, 46)
	_prop("crate", "crate", 1150, DECK, 40)
	_ladder(1188, func(): return "Внизу ще глибоко. Спершу злий воду." if water.is_deep() else "")
	_prop("vent", "vent", 1232, GROUND - 12.0, 40).ground_shadow = false
	_prop("beam", "", 1290, GROUND, 50)
	_prop("rubble", "rubble", 1370, GROUND, 80, -10)
	blockers.rubble = _body_rect(Vector2(1372, GROUND - 28), Vector2(46, 56))
	_prop("door", "laundry_door", 1450, GROUND, 60, -22)
	blockers.door = _body_rect(Vector2(1450, GROUND - 46), Vector2(10, 92))
	# ---- 4. routes.
	_ladder(1550)
	_deck(1530, GAP_X0)
	_deck(GAP_X1, 2080)
	bridge = _deck(GAP_X0, GAP_X1)
	_prop("gap", "", 1735, DECK, 44)
	_ladder(2065)
	_prop("washer", "washer" if not Art.prop("washer").is_empty() else "", WASHER_X, GROUND, 44)
	# ---- 5. filter room, gate, yard.
	_prop("body", "filter_body", 2150, GROUND, 40)
	_prop("cabinet", "cabinet", 2205, GROUND, 40)
	_prop("cart", "cart", CART_HOME, GROUND, 84)
	_prop("gate", "cargo_gate", 2480, GROUND, 70, -105)
	blockers.gate = _body_rect(Vector2(2402, GROUND - 56), Vector2(10, 112))
	_prop("yard_crate", "crate", 2560, GROUND, 40)
	_prop("debris", "rubble", 2640, GROUND, 60, 0.0, 0.6)
	_prop("exit", "", 2960, GROUND, 50)
	# ---- 6. the Station.
	_deco("purifier", 5820, GROUND, 0, -1).name = "Purifier"
	_prop("station_cart", "cart", 5290, GROUND, 70)
	_prop("yana", "", 5140, GROUND, 50)
	_prop("bench", "workbench", 5660, GROUND, 80)
	var on_bench := _deco("filter_body", 5652, GROUND - 40.0, 0, 0)
	on_bench.name = "BenchBody"
	props.gate.z_index = 1
	props.beam.highlight = Rect2(-75, -80, 150, 22)
	props.gap.highlight = Rect2(15, -6, GAP_X1 - GAP_X0, 12)
	props.exit.highlight = Rect2(-14, -58, 28, 58)
	props.fire_ladder.highlight = Rect2(-13, -160, 26, 112)
	props.drain.highlight = Rect2(-22, -6, 44, 8)
	props.yana.highlight = Rect2(-14, -70, 28, 70)
	if props.rack.art == "":
		props.rack.highlight = Rect2(-20, -40, 40, 40)
	if props.washer.art == "":
		props.washer.highlight = Rect2(-20, -40, 40, 40)
	water = preload("res://scripts/water.gd").new()
	water.x0 = WATER_X0
	water.x1 = WATER_X1
	water.bottom = GROUND
	water.level = 266.0
	water.z_index = 2
	add_child(water)
	# Crawlers: three asleep by food in the machine hall, one in the yard.
	_crawler(1700.0, 1580.0, 2040.0)
	_crawler(1925.0, 1580.0, 2040.0)
	_crawler(1815.0, 1580.0, 2040.0)
	_crawler(2760.0, 2600.0, 2980.0)
	nazar = _npc("nazar", 1478)
	nazar.visible = false
	yana = _npc("yana", 5140, 64.0)
	mira = _npc("mira", 5760, 64.0)
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
	yana.look_at = hero
	mira.look_at = hero
	camera = Camera2D.new()
	camera.limit_top = -40
	camera.limit_bottom = 400
	add_child(camera)

# ======================================================================= world state from flags
func _set_blocker(key: String, on: bool) -> void:
	blockers[key].set_deferred("disabled", not on)

func _apply_flags() -> void:
	# Hidden until pulled down (the hero skips hidden things); its area stays on, so standing in it later just works.
	fire_ladder.visible = Game.has("ladder_down")
	props.street_crate.state = 1 if Game.has("street_crate") else 0
	props.scrap.state = 1 if Game.has("hook_found") else 0
	props.em_bridge.state = 1 if Game.has("em_bridge") else 0
	em_bridge.set_deferred("disabled", not Game.has("em_bridge"))
	props.entrance.state = 1 if Game.has("entered") else 0
	_set_blocker("entrance", not Game.has("entered"))
	props.generator.state = 1 if Game.has("power") else 0
	get_node("Pump").state = 1 if Game.has("power") else 0
	props.pipe.state = 1 if Game.has("pipe_fixed") else 0
	if Game.has("drained"):
		water.set_level(GROUND + 4.0, true)
	props.valve.state = 1 if Game.has("drained") else 0
	get_node("Gauge").state = 0 if Game.has("drained") else 2
	props.crate.state = 1 if Game.has("crate_open") else 0
	props.vent.state = 1 if Game.has("talked") else 0
	get_node("Jack").visible = Game.has("supported") and Art.prop("beam").is_empty()
	props.rubble.state = 1 if Game.has("rubble") else 0
	_set_blocker("rubble", not Game.has("rubble"))
	props.door.state = 1 if Game.has("rescued") else 0
	_set_blocker("door", not Game.has("rescued"))
	bridge.set_deferred("disabled", not Game.has("bridge"))
	props.body.visible = not (Game.has("body_taken") or Game.has("loaded"))
	props.cabinet.state = 1 if Game.has("cabinet") else 0
	props.cart.state = 1 if Game.has("loaded") else 0
	props.gate.state = 1 if Game.has("gate") else 0
	_set_blocker("gate", not Game.has("gate"))
	props.yard_crate.state = 1 if Game.has("yard_crate") else 0
	props.debris.state = 1 if Game.has("debris") else 0
	props.station_cart.state = 0 if Game.has("body_off_cart") else 1
	get_node("BenchBody").visible = Game.has("on_bench")
	get_node("Purifier").state = 1 if Game.has("on_bench") else 0
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
	# Once the gate is open the push resumes after a reload or a fall.
	if Game.has("loaded") and Game.has("secured") and Game.has("gate") and not Game.has("delivered"):
		pushing = true

func _respawn() -> void:
	var x: float = SPAWN.get(Game.checkpoint, SPAWN.start)
	hero.global_position = Vector2(x, GROUND - 1.0)
	hero.velocity = Vector2.ZERO
	hero.climb = {}
	hero.collision_mask = 1
	last_safe = hero.global_position
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

func _say_once(key: String, lines: Array) -> void:
	if not said.get(key, false):
		said[key] = true
		hud.say(lines)

# ======================================================================= the drainage plan
func _plan_missing() -> Array:
	var m := []
	if not Game.has("drain_clear"):
		m.append("drain")
	if not Game.has("pipe_fixed"):
		m.append("pipe")
	if not Game.has("power"):
		m.append("power")
	return m

func _plan_text() -> String:
	return "%s водостік у дворі\n%s обвідна труба (хомут + ганчірка)\n%s живлення помпи (генератор)" % [
		"[+]" if Game.has("drain_clear") else "[ ]", "[+]" if Game.has("pipe_fixed") else "[ ]", "[+]" if Game.has("power") else "[ ]"]

# ======================================================================= what each object does
## Called by every Prop: title, verb, why it is blocked, how long the job is and where the hero stands.
func info(id: String) -> Dictionary:
	match id:
		"street_crate":
			if Game.has("street_crate"):
				return {"usable": false}
			return {"title": "Ящик біля машини", "verb": "Обшукати", "work": 1.0, "tool": "kneel", "spot": -1878.0}
		"scrap":
			if Game.has("hook_found"):
				return {"usable": false}
			return {"title": "Купа брухту", "verb": "Порпатися", "work": 1.6, "tool": "kneel", "spot": -1760.0}
		"fire_ladder":
			if Game.has("ladder_down"):
				return {"usable": false}
			var why := "" if Game.count("hook") > 0 else "Драбина піднята — рукою не дістати. Потрібне щось довге з гаком."
			return {"title": "Пожежна драбина · піднята", "verb": "Стягнути гаком", "block": why, "work": 1.4, "tool": "wrench", "spot": -1626.0}
		"em_bridge":
			if Game.has("em_bridge"):
				return {"usable": false}
			return {"title": "Аварійний місток · піднятий", "verb": "Опустити", "work": 2.4, "tool": "wrench", "spot": -1352.0}
		"rack":
			if Game.has("rag_taken"):
				return {"usable": false}
			return {"title": "Сушарка з ганчір'ям", "verb": "Зняти ганчірку", "work": 0.8, "tool": "kneel", "spot": -452.0}
		"drain":
			if Game.has("drain_clear"):
				return {"title": "Дворовий водостік · чистий", "usable": false}
			return {"title": "Дворовий водостік · забитий листям", "verb": "Прочистити", "work": 2.2, "tool": "kneel", "spot": 280.0}
		"entrance":
			if Game.has("entered"):
				return {"usable": false}
			return {"title": "Двері пральні · заіржавіли", "verb": "Відкрутити", "work": 1.7, "tool": "wrench", "spot": 578.0}
		"generator":
			if Game.has("power"):
				return {"title": "Генератор · працює", "usable": false}
			return {"title": "Генератор · не заводиться", "verb": "Смикати шнур", "work": 2.6, "tool": "wrench", "spot": 628.0}
		"pipe":
			if Game.has("pipe_fixed"):
				return {"title": "Обвідна труба · залатана", "usable": false}
			var need := []
			if Game.count("clamp") == 0:
				need.append("хомут")
			if Game.count("rag") == 0:
				need.append("ганчірка")
			var why2 := "" if need.is_empty() else "Пробоїна велика. Потрібні: %s." % ", ".join(need)
			return {"title": "Обвідна труба · пробита", "verb": "Залатати", "block": why2, "work": 2.4, "tool": "wrench", "spot": 972.0}
		"valve":
			if Game.has("drained"):
				return {"title": "Вентиль відводу · відкритий", "usable": false}
			if not _plan_missing().is_empty():
				return {"title": "Вентиль відводу стоку", "verb": "Оглянути", "work": 0.6, "tool": "", "spot": 1040.0}
			return {"title": "Вентиль відводу стоку", "verb": "Крутити", "work": 2.9, "tool": "wrench", "spot": 1040.0}
		"crate":
			if Game.has("crate_open"):
				return {"usable": false}
			return {"title": "Ящик з інструментом", "verb": "Відкрити", "work": 1.0, "tool": "kneel", "spot": 1132.0}
		"vent":
			if Game.has("talked") or not Game.has("drained"):
				return {"usable": false}
			return {"title": "Вентиляційна решітка · чути голос", "verb": "Відкрутити", "work": 1.5, "tool": "kneel", "spot": 1214.0}
		"beam":
			if Game.has("supported"):
				return {"usable": false}
			var why3 := "" if Game.count("jack") > 0 else "Балка просіла. Потрібен домкрат — пошукай у ящику на настилі."
			return {"title": "Просіла балка над завалом", "verb": "Поставити опору", "block": why3, "work": 2.2, "tool": "kneel", "spot": 1272.0}
		"rubble":
			if Game.has("rubble"):
				return {"usable": false}
			var why4 := "" if Game.has("supported") else "Балка тримається на самому завалі. Спершу постав опору, інакше все впаде."
			return {"title": "Завал під балкою", "verb": "Розбирати", "block": why4, "work": 3.4, "tool": "wrench", "spot": 1336.0}
		"door":
			if Game.has("rescued"):
				return {"usable": false}
			return {"title": "Заклинені двері · за ними Назар", "verb": "Віджати", "work": 3.0, "tool": "wrench", "spot": 1430.0}
		"gap":
			if Game.has("bridge"):
				return {"usable": false}
			var why5 := "" if Game.count("planks") >= 2 else "Пролом широкий — не перестрибнеш. Потрібні 2 дошки (є %d)." % Game.count("planks")
			return {"title": "Пролом у настилі", "verb": "Закласти дошки", "block": why5, "work": 2.4, "tool": "kneel", "spot": 1742.0}
		"washer":
			if not Game.has("rescued"):
				return {"usable": false}
			var why6 := ""
			if not Game.has("power"):
				why6 = "Без струму барабан не крутиться."
			elif washer_t > 0.0:
				why6 = "Барабан ще гуркоче."
			return {"title": "Пральна машина · барабан", "verb": "Увімкнути", "block": why6, "work": 0.0, "spot": WASHER_X - 18.0}
		"body":
			return {"title": "Корпус фільтра", "verb": "Підняти", "work": 1.2, "tool": "kneel", "spot": 2132.0}
		"cabinet":
			if Game.has("cabinet"):
				return {"usable": false}
			return {"title": "Шафа · дверцята прикипіли", "verb": "Відчинити", "work": 1.6, "tool": "wrench", "spot": 2186.0}
		"cart":
			if not Game.has("loaded"):
				var why7 := "" if Game.count("filter_body") > 0 else "Візок порожній. Спершу візьми корпус фільтра."
				return {"title": "Вантажний візок", "verb": "Покласти корпус", "block": why7, "work": 1.4, "tool": "kneel", "spot": props.cart.position.x - 28.0}
			if not Game.has("secured"):
				var why8 := "" if Game.count("straps") > 0 else "Корпус з'їде на першій вибоїні. Потрібні ремені — глянь у шафі."
				return {"title": "Візок з корпусом · не закріплений", "verb": "Закріпити", "block": why8, "work": 2.0, "tool": "kneel", "spot": props.cart.position.x - 28.0}
			return {"title": "Візок з корпусом", "usable": false}
		"gate":
			if Game.has("gate"):
				return {"usable": false}
			return {"title": "Вантажні ворота · ланцюговий ворот", "verb": "Крутити ворот", "work": 3.8, "tool": "wrench", "spot": 2356.0}
		"yard_crate":
			if Game.has("yard_crate"):
				return {"usable": false}
			return {"title": "Скриня біля воріт", "verb": "Обшукати", "work": 1.0, "tool": "kneel", "spot": 2542.0}
		"debris":
			if Game.has("debris"):
				return {"usable": false}
			return {"title": "Уламки на дорозі", "verb": "Розчистити", "work": 2.8, "tool": "wrench", "spot": 2612.0}
		"exit":
			if not Game.has("delivered"):
				return {"title": "Дорога на Станцію", "verb": "Йти", "block": "Спершу доведи візок з корпусом до безпечної точки."}
			return {"title": "Дорога на Станцію", "verb": "Повернутися"}
		"yana":
			if Game.has("yana_talk"):
				return {"usable": false}
			return {"title": "Яна", "verb": "Розповісти", "work": 0.0, "spot": 5106.0}
		"station_cart":
			if Game.has("body_off_cart"):
				return {"usable": false}
			var why9 := "" if Game.has("yana_talk") else "Спершу розкажи Яні, що сталося в пральні."
			return {"title": "Візок із корпусом", "verb": "Зняти корпус", "block": why9, "work": 1.5, "tool": "kneel", "spot": 5262.0}
		"bench":
			if Game.has("on_bench"):
				return {"usable": false}
			var why10 := "" if Game.count("filter_body") > 0 else "Корпус ще на візку."
			return {"title": "Верстак Міри", "verb": "Поставити корпус", "block": why10, "work": 1.8, "tool": "kneel", "spot": 5626.0}
	return {}

func pulse(id: String, _n: int) -> void:
	var p: Node2D = props[id]
	var at := p.global_position + Vector2(0, -20)
	match id:
		"valve":
			at = p.global_position + Vector2(0, -34)
		"rubble":
			at = p.global_position + Vector2(-18, -30)
		"door", "entrance":
			at = p.global_position + Vector2(-26, -50)
		"gate":
			at = p.global_position + Vector2(-110, -40)
		"em_bridge":
			at = p.global_position + Vector2(-46, -16)
		"generator":
			at = p.global_position + Vector2(-10, -26)
		"pipe":
			at = p.global_position + Vector2(0, -6)
		"fire_ladder":
			at = Vector2(-1610, GROUND - 160)
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
		"street_crate":
			Game.set_flag("street_crate")
			props.street_crate.state = 1
			Game.give("can")
			hud.show_hint("+ Консерва. Гака тут немає.", 2.6, "can")
		"scrap":
			Game.set_flag("hook_found")
			props.scrap.state = 1
			Game.give("hook")
			Game.note("У брухті знайшов загнутий прут — ним можна зачепити драбину.")
			hud.show_hint("+ Гак", 2.4, "hook")
		"fire_ladder":
			Game.set_flag("ladder_down")
			_apply_flags()
			Game.note("Стягнув пожежну драбину будинку — шлях на балкони відкритий.")
		"em_bridge":
			Game.set_flag("em_bridge")
			_apply_flags()
			Game.note("Опустив аварійний місток між балконами.")
		"rack":
			Game.set_flag("rag_taken")
			Game.give("rag")
			hud.show_hint("+ Ганчірка", 2.2, "rag")
		"drain":
			Game.set_flag("drain_clear")
			Game.note("Прочистив дворовий водостік — є куди відводити воду з пральні.")
		"entrance":
			Game.set_flag("entered")
			_apply_flags()
			Game.note("Відкрив заіржавілі двері пральні.")
			_checkpoint("entrance")
			hud.say([["einstein", "Зал затоплений. Стік керують з верхнього настилу — туди веде драбина."]])
		"generator":
			Game.set_flag("power")
			_apply_flags()
			Game.note("Завів генератор — помпа на настилі отримала живлення.")
			_plan_progress()
		"pipe":
			Game.take("clamp")
			Game.take("rag")
			Game.set_flag("pipe_fixed")
			props.pipe.state = 1
			Game.note("Залатав обвідну трубу хомутом і ганчіркою.")
			_plan_progress()
		"valve":
			var missing := _plan_missing()
			if not missing.is_empty():
				Game.set_flag("plan_known")
				Game.note("План осушення: прочистити водостік у дворі, залатати обвідну трубу, дати живлення помпі.")
				var lines := [["einstein", "Відкрити зараз — вода нікуди не піде."]]
				if "drain" in missing:
					lines.append(["einstein", "Відвід веде у дворовий водостік, а я бачив — він забитий листям."])
				if "pipe" in missing:
					lines.append(["einstein", "Обвідна труба на настилі пробита — вода хлюпатиме назад у зал. Хомут і ганчірка її втримають."])
				if "power" in missing:
					lines.append(["einstein", "Самопливом не піде — потрібна помпа. Живлення дає генератор біля входу."])
				hud.say(lines)
				return
			Game.set_flag("drained")
			water.drain()
			props.valve.state = 1
			Game.note("Відкрив відвід — помпа жене воду в дворовий стік, зал осушується.")
			hud.say([["einstein", "Вода спадає. Видно завал і просілу балку. А стукіт... тепер чути голос — з вентиляції внизу."]])
		"crate":
			Game.set_flag("crate_open")
			props.crate.state = 1
			Game.give("jack")
			Game.give("planks", 2)
			Game.give("can")
			Game.give("clamp")
			Game.note("У ящику знайшов домкрат, 2 дошки, хомут і консерву.")
			hud.show_hint("+ Домкрат  + Дошки ×2  + Хомут  + Консерва", 3.0, "jack")
			_plan_progress()
		"vent":
			Game.set_flag("talked")
			props.vent.state = 1
			Game.note("Поговорив з Назаром через вентиляцію: двері заклинило завалом, балка тримається на ньому.")
			hud.say([["einstein", "Є тут хтось?"], ["nazar", "Нарешті! Я Назар, від Сави. Два дні тут сиджу."],
				["nazar", "Двері підперло завалом, а над ним балка — вона просіла, коли пішла вода."],
				["nazar", "Не чіпай завал, поки не підіпреш балку! Домкрат має бути в ящику на настилі."],
				["einstein", "Тримайся. Зараз буду."]])
		"beam":
			Game.take("jack")
			Game.set_flag("supported")
			get_node("Jack").visible = Art.prop("beam").is_empty()
			Game.note("Підпер балку домкратом — тепер завал можна розбирати безпечно.")
		"rubble":
			Game.set_flag("rubble")
			_apply_flags()
			Game.note("Розібрав завал під балкою — прохід до дверей вільний.")
			hud.say([["nazar", "Чую тебе! Двері заклинило — тисни ключем знизу!"]])
		"door":
			Game.set_flag("rescued")
			_apply_flags()
			_free_nazar()
		"gap":
			Game.take("planks", 2)
			Game.set_flag("bridge")
			bridge.set_deferred("disabled", false)
			Game.note("Заклав пролом у верхньому настилі дошками — тихий шлях повз машинний зал.")
		"washer":
			washer_t = 14.0
			for c in crawlers:
				c.lure(WASHER_X + 30.0, 10.0)
			Game.note("Запустив барабан пральної машини — кроулери кинулися на гуркіт.")
			hud.show_hint("Барабан гуркоче: кроулери біжать на звук. Є кілька секунд!", 3.0)
		"body":
			Game.set_flag("body_taken")
			Game.give("filter_body")
			props.body.visible = false
			hud.show_hint("+ Корпус фільтра (важкий — до візка донесеш)", 3.0, "filter_body")
		"cabinet":
			Game.set_flag("cabinet")
			props.cabinet.state = 1
			Game.give("straps")
			hud.show_hint("+ Ремені", 2.4, "straps")
		"cart":
			if not Game.has("loaded"):
				Game.take("filter_body")
				Game.set_flag("loaded")
				props.cart.state = 1
				Game.note("Корпус фільтра лежить на візку.")
				if Game.count("straps") == 0:
					hud.say([["nazar", "Так не повеземо — з'їде. У шафі були ремені."]])
			else:
				Game.take("straps")
				Game.set_flag("secured")
				Game.note("Закріпив корпус на візку ременями.")
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
		"debris":
			Game.set_flag("debris")
			props.debris.state = 1
			Game.note("Розчистив уламки на дорозі візка.")
		"exit":
			_go_station()
		"yana":
			Game.set_flag("yana_talk")
			hud.say([["yana", "Повернувся! А Назар?"], ["einstein", "Живий. Сидів замкнений у пральні. Лишився у вантажному дворі — каже, Сава зробить там обмін."],
				["yana", "Двір через ворота — це ж півгодини замість півдня дороги. Я запишу."],
				["yana", "Корпус хлопці вже прикотили. Міра в майстерні — неси їй."]])
		"station_cart":
			Game.set_flag("body_off_cart")
			props.station_cart.state = 0
			Game.give("filter_body")
			hud.show_hint("+ Корпус фільтра", 2.2, "filter_body")
		"bench":
			Game.take("filter_body")
			Game.set_flag("on_bench")
			_apply_flags()
			Game.note("Корпус фільтра на верстаці Міри — можна збирати вузол.")
			hud.say([["mira", "Ціла! Трохи іржі, але різьба жива."], ["mira", "Тільки кріплення старі — не підійдуть. Доведеться робити перехідник."],
				["einstein", "Тоді завтра — верстак і лещата."]])
			await get_tree().create_timer(7.0).timeout
			_finish()
	Game.save()

func _plan_progress() -> void:
	if Game.has("plan_known") and not Game.has("drained") and _plan_missing().is_empty():
		hud.say([["einstein", "Водостік чистий, труба тримає, помпа живиться. Тепер — вентиль."]])

func _free_nazar() -> void:
	Game.note("Відчинив заклинені двері — Назар вільний.")
	_checkpoint("rescued")
	nazar.visible = true
	nazar.position.x = 1478.0
	nazar.pose = 4
	hud.say([["nazar", "Дякую. Думав, тут і лишусь."], ["einstein", "Нам потрібен корпус фільтра. Він у дальньому кінці пральні."],
		["nazar", "Машинним залом тихо не пройдеш — там кроулери біля їжі. Барабани на машинах ще крутяться, якщо є струм — вони біжать на гуркіт."],
		["nazar", "Або верхній настил, але в ньому пролом, і з труби б'є вода."], ["nazar", "Я пройду підсобкою і чекатиму біля візка. Обирай свій шлях."]])
	await get_tree().create_timer(11.0).timeout
	if Game.has("route"):
		return
	nazar.go(1531.0, 50.0)
	await get_tree().create_timer(1.2).timeout
	var tw := create_tween()
	tw.tween_property(nazar, "modulate:a", 0.0, 0.6)
	await tw.finished
	if not Game.has("route"):
		nazar.visible = false

func _maybe_push() -> void:
	if Game.has("loaded") and Game.has("secured") and Game.has("gate") and not Game.has("delivered") and not pushing:
		pushing = true
		hud.say([["nazar", "Ворота відчинені, корпус прив'язаний. Штовхаю! Дивись уперед — візок гримить."]])

func _go_station() -> void:
	hero.controls = false
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	await tw.finished
	Game.set_flag("station")
	Game.note("Повернувся на Станцію коротким шляхом через вантажний двір.")
	Game.reach_checkpoint("station")
	_respawn()
	cam_y = GROUND - 60.0
	_camera(1.0)
	await get_tree().create_timer(0.2).timeout
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.6)
	hero.controls = true
	hud.say([["mira", "Ейнштейне! Сюди, до майстерні!"]])

func _finish() -> void:
	if ended:
		return
	ended = true
	Game.set_flag("done")
	Game.save()
	var t := int(Game.play_time)
	var route := "верхній настил" if Game.has("bridge") else "машинний зал"
	var out := "МІСІЮ 2.2 ВИКОНАНО · Пральня на затопленій вулиці\nЧас: %d хв %02d с · шлях: %s · записів у журналі: %d\n\nЩо змінилося у світі:\n" % [t / 60, t % 60, route, Game.journal.size()]
	out += "• Зал пральні осушено: водостік, труба й помпа працюють.\n"
	out += "• Назар вільний і лишився у вантажному дворі — тепер це точка обміну з поселенням.\n"
	out += "• Вантажні ворота відчинені: короткий шлях до поселення.\n"
	out += "• Корпус фільтра на верстаці Міри — далі складання вузла (місія 2.3).\n"
	out += "\nПовністю — у Журналі. Почати знову: Журнал > Почати місію заново."
	hud.show_end(out)
	hero.controls = false

# ======================================================================= goals
func _goal() -> Array:
	if not Game.has("ladder_down"):
		if Game.count("hook") == 0:
			return ["Знайди спосіб піднятися", "Вулицю залило, течія збиває з ніг. Пожежна драбина будинку піднята — пошукай щось довге з гаком.", "", -1735.0]
		return ["Стягни пожежну драбину", "Зачепи драбину гаком.", "Гак 1/1", -1610.0]
	if not Game.has("em_bridge") and not Game.has("court"):
		return ["Пройди балконами", "Між балконами — аварійний місток. Його можна опустити.", "", BR_X0]
	if not Game.has("court"):
		return ["Пройди балконами у двір", "З ящика — на дах, з даху — стрибок на останній балкон. Внизу течія.", "", -680.0]
	if not Game.has("entered"):
		return ["Знайди вхід до пральні", "Стукіт іде з пральні праворуч. Бічні двері з двору заіржавіли.", "", 600.0]
	if not Game.has("drained"):
		if not Game.has("plan_known"):
			return ["Знайди керування стоком", "Зал затоплено. Вентиль відводу — на верхньому настилі.", "", 1060.0]
		var m := _plan_missing()
		if m.is_empty():
			return ["Відкрий вентиль відводу", "Усе готово до осушення.", _plan_text(), 1060.0]
		var gx: float = {"drain": 300.0, "pipe": 990.0, "power": 652.0}[m[0]]
		if m[0] == "pipe" and Game.count("clamp") == 0:
			gx = 1150.0
		elif m[0] == "pipe" and Game.count("rag") == 0:
			gx = -430.0
		return ["Підготуй осушення", "Вода має куди йти, лише коли все це готово:", _plan_text(), gx]
	if not Game.has("talked"):
		return ["Знайди, звідки голос", "Голос чути з вентиляційної решітки біля завалу.", "", 1232.0]
	if not Game.has("supported"):
		if Game.count("jack") == 0:
			return ["Укріпи балку над завалом", "Назар казав: домкрат у ящику з інструментом на настилі.", "Домкрат 0/1", 1150.0]
		return ["Укріпи балку над завалом", "Підстав домкрат під балку, поки не розбираєш завал.", "Домкрат 1/1", 1290.0]
	if not Game.has("rubble"):
		return ["Розбери завал", "Балка на опорі — можна розбирати.", "", 1370.0]
	if not Game.has("rescued"):
		return ["Відчини двері до Назара", "Двері заклинило. Віджми їх ключем.", "", 1450.0]
	if not Game.has("route"):
		return ["Дістанься корпусу фільтра", "Верхній настил: пролом (2 дошки) і струмінь з труби. Машинний зал: три кроулери — консерва, бійка або барабан пральної машини.", "Дошки %d/2 · Консерви %d" % [Game.count("planks"), Game.count("can")], 2150.0]
	if not Game.has("loaded"):
		if Game.count("filter_body") == 0:
			return ["Візьми корпус фільтра", "Корпус лежить біля візка.", "", 2150.0]
		return ["Поклади корпус на візок", "Назар чекає біля візка.", "", props.cart.position.x]
	if not Game.has("secured"):
		if Game.count("straps") == 0:
			return ["Знайди, чим закріпити корпус", "Назар каже: у шафі були ремені.", "", 2205.0]
		return ["Закріпи корпус ременями", "", "Ремені 1/1", props.cart.position.x]
	if not Game.has("gate"):
		return ["Відчини вантажні ворота", "Ворот із ланцюгом — ліворуч від воріт.", "", 2356.0]
	if not Game.has("delivered"):
		var t := "Назар штовхає. Візок стане перед уламками чи кроулером — розчисти шлях."
		return ["Проведи візок до безпечної точки", t, "Консерви %d" % Game.count("can"), props.cart.position.x + 60.0]
	if not Game.has("station"):
		return ["Повертайся на Станцію", "Корпус у дворі, Назар на місці. Дорога — праворуч.", "", 2960.0]
	if not Game.has("yana_talk"):
		return ["Розкажи Яні", "Яна чекає новин про Назара.", "", 5140.0]
	if not Game.has("body_off_cart"):
		return ["Зніми корпус з візка", "Візок прикотили з двору коротким шляхом.", "", 5290.0]
	return ["Віднеси корпус Мірі", "Верстак у майстерні.", "", 5660.0]

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
	_areas()
	_water_hazard()
	_jet(delta)
	_nazar_knock(delta)
	_cart(delta)
	_pump_and_fx(delta)
	_depth(delta)
	washer_t = maxf(0.0, washer_t - delta)
	var winch := get_node_or_null("Winch")
	if winch:
		winch.state = 1 if Game.has("gate") or progress_of.has("gate") else 0
	var now_inside := hero.global_position.x > 612.0 and hero.global_position.x < 2400.0
	if now_inside != inside:
		inside = now_inside
		facade_layer.queue_redraw()

func _camera(delta: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var px := float(DisplayServer.window_get_size().x)
	var want := minf(560.0, px / 1.65)
	camera.zoom = Vector2.ONE * (vs.x / want)
	var h := vs.y / camera.zoom.y
	var up := clampf((GROUND - hero.global_position.y) / (GROUND - DECK), 0.0, 1.4)
	var target := GROUND - h * 0.26 - up * (GROUND - DECK) * 0.62
	cam_y = lerpf(cam_y, target, minf(1.0, delta * 4.0))
	camera.position = Vector2(hero.global_position.x, cam_y)
	var station := hero.global_position.x > 4000.0
	camera.limit_left = int(STATION_X0) if station else -2040
	camera.limit_right = int(STATION_X1) if station else 3010

## Area flags that come from where the hero is: reaching the courtyard, the far end of the hall.
func _areas() -> void:
	var p := hero.global_position
	var grounded: bool = hero.is_on_floor() and hero.climb.is_empty()
	if not Game.has("court") and grounded and p.x > -720.0 and p.x < 590.0 and p.y > GROUND - 4.0:
		Game.set_flag("court")
		Game.note("Спустився балконами у внутрішній двір пральні.")
		Game.save()
		hud.say([["einstein", "Стукіт — звідти, з пральні. Бічні двері з двору."]])
	if Game.has("rescued") and not Game.has("route") and p.x > 2085.0 and p.x < 2400.0 and grounded:
		Game.set_flag("route")
		Game.note("Пройшов до корпусу фільтра (%s)." % ("верхнім настилом" if Game.has("bridge") else "через машинний зал"))
		_checkpoint("route")
		nazar.visible = true
		nazar.position.x = CART_HOME - 46.0
		nazar.modulate.a = 0.0
		nazar.target_x = NAN
		create_tween().tween_property(nazar, "modulate:a", 1.0, 0.5)
		hud.say([["nazar", "Ти пройшов! Корпус ось, візок поруч. Поклади його — і прив'яжемо."]])
	if Game.has("plan_known") and not Game.has("drained") and p.x < 590.0 and p.x > -700.0 and not Game.has("drain_clear"):
		_say_once("drain_seen", [["einstein", "Ось він, дворовий водостік. Листя й мул — треба прочистити."]])

## Deep water (the flooded street before the balconies, the hall before draining): the current knocks you down and
## you climb back where you last stood on dry ground.
func _water_hazard() -> void:
	var p := hero.global_position
	var grounded: bool = hero.is_on_floor() and hero.climb.is_empty()
	var in_water := false
	for w in [flood, water]:
		if w.is_deep() and p.x > w.x0 and p.x < w.x1 and p.y > w.level + 6.0:
			in_water = true
	if in_water:
		Game.hp = maxi(10, Game.hp - 10)
		hero.global_position = last_safe
		hero.velocity = Vector2.ZERO
		hud.show_hint("Течія збила з ніг — назад, на сухе. (-10 здоров'я)", 3.0)
		Game.changed.emit()
	elif grounded and hero.hurt_t <= 0.0:
		last_safe = p

## The burst pipe over the upper walkway: a jet every few seconds, a short warning (drips) before it.
func _jet(delta: float) -> void:
	jet_t = fmod(jet_t + delta, 3.4)
	var active := jet_t > 2.0 and jet_t < 3.3
	var p := hero.global_position
	if active and absf(p.x - JET_X) < 16.0 and absf(p.y - DECK) < 4.0 and hero.climb.is_empty():
		hero.hurt(10, JET_X + 30.0)
		_say_once("jet", [["einstein", "Ух! Струмінь б'є щокілька секунд — краплі попереджають. Проскочу між ударами."]])

func _nazar_knock(delta: float) -> void:
	if Game.has("rescued"):
		return
	knock_t -= delta
	var x := hero.global_position.x
	if knock_t <= 0.0:
		knock_t = 2.4
		if x > 612.0 and x < 1700.0:
			bubbles.append({"p": Vector2(1450 + randf_range(-6, 6), GROUND - 100), "text": "тук-тук!" if absf(x - 1450.0) < 420.0 else "тук...", "t": 1.3})
		elif x > -1100.0 and x <= 612.0:
			bubbles.append({"p": Vector2(560 + randf_range(-6, 6), GROUND - 150), "text": "тук... тук...", "t": 1.3})
	var door: Prop = props.door
	door.position.x = 1450.0 + (randf_range(-0.6, 0.6) if knock_t > 2.1 and x > 612.0 else 0.0)

func _cart(delta: float) -> void:
	if not pushing:
		return
	var cart: Prop = props.cart
	var front := cart.position.x + 33.0
	var why := ""
	if not Game.has("debris") and front > 2640.0 - 40.0:
		why = "debris"
	for c in crawlers:
		if c.st in ["gone", "flee", "distracted"] or not c.visible:
			continue
		if c.global_position.x > front - 20.0 and c.global_position.x - front < 120.0:
			why = "crawler"
	noise_t -= delta
	if noise_t <= 0.0:
		noise_t = 1.0
		for c in crawlers:
			c.noise(front)
	var behind := hero.global_position.x < cart.position.x - 160.0
	if why != "" or behind:
		nazar.target_x = NAN
		nazar.pose = 6
		if why != "" and cart_wait_said != why:
			cart_wait_said = why
			if why == "crawler":
				hud.say([["nazar", "Стоп! Попереду кроулер. Прожени його або відволічи — я тримаю візок."]])
			else:
				hud.say([["nazar", "Уламки! Через них візок не перекотиш — розбери, я притримаю."]])
		return
	cart_wait_said = ""
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
		hud.say([["nazar", "Звідси до поселення рукою подати. Візок наші заберуть. Я лишуся тут — скажу Саві, що двір тепер наш."], ["einstein", "Повертаюсь на Станцію. Міра чекає корпус."]])

func _pump_and_fx(delta: float) -> void:
	var pump: Prop = get_node("Pump")
	pump.position.x = 905.0 + (randf_range(-0.4, 0.4) if pump.state == 1 else 0.0)
	props.generator.position.x = 652.0 + (randf_range(-0.3, 0.3) if Game.has("power") else 0.0)
	if props.washer.art != "":
		props.washer.position.x = WASHER_X + (randf_range(-0.8, 0.8) if washer_t > 4.0 else 0.0)
	for s in sparks:
		s.t -= delta
		s.v.y += 260.0 * delta
		s.p += s.v * delta
	sparks = sparks.filter(func(s): return s.t > 0.0)
	for b in bubbles:
		b.t -= delta
		b.p.y -= 8.0 * delta
	bubbles = bubbles.filter(func(b): return b.t > 0.0)
	# Water from the burst bypass pipe, and the jet's warning drips.
	if not Game.has("pipe_fixed") and randf() < 0.5:
		drops.append({"p": Vector2(990 + randf_range(-3, 3), DECK - 34), "v": Vector2(randf_range(-12, 30), randf_range(-20, 10)), "t": 0.8})
	if jet_t > 1.4 and jet_t < 2.0 and randf() < 0.35:
		drops.append({"p": Vector2(JET_X + randf_range(-4, 4), DECK - 40), "v": Vector2(0, 20), "t": 0.9})
	for d in drops:
		d.t -= delta
		d.v.y += 300.0 * delta
		d.p += d.v * delta
	drops = drops.filter(func(d): return d.t > 0.0)
	fx.queue_redraw()

# ======================================================================= light and depth
## The level is flat pictures; this gives it room: an ambient tone per area (sunset street, dim laundry, warm Station),
## lamps and windows that light the normal-mapped pictures from where they hang, the sun outside, a soft light that
## goes with the hero, shadows where walls meet the floor and under the walkways, light shafts with dust from the
## laundry windows, and a dark foreground (pipes, chains, leaves) that slides past faster than the camera.
const AMBIENT := {"out": Color(0.78, 0.72, 0.78), "in": Color(0.46, 0.5, 0.58), "station": Color(0.7, 0.66, 0.66)}
var ambient: CanvasModulate
var sun: DirectionalLight2D
var hero_light: PointLight2D
var lamps: Array[PointLight2D] = []
var rays: Node2D
var front: Node2D
var area := "out"
var light_tex: Texture2D

func _light_tex() -> Texture2D:
	if light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		light_tex = gt
	return light_tex

func _lamp(pos: Vector2, color: Color, energy: float, radius: float, height := 50.0, flicker := true) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex()
	l.texture_scale = radius / 128.0
	l.color = color
	l.energy = energy
	l.height = height
	l.position = pos
	l.set_meta("energy", energy)
	l.set_meta("flicker", flicker)
	add_child(l)
	lamps.append(l)
	return l

func _build_depth() -> void:
	ambient = CanvasModulate.new()
	ambient.color = AMBIENT.out
	add_child(ambient)
	sun = DirectionalLight2D.new()
	sun.color = Color(1.0, 0.78, 0.56)
	sun.energy = 0.55
	sun.height = 0.3
	sun.rotation_degrees = -35.0          # low evening sun from the left
	add_child(sun)
	hero_light = PointLight2D.new()
	hero_light.texture = _light_tex()
	hero_light.texture_scale = 150.0 / 128.0
	hero_light.color = Color(1.0, 0.86, 0.68)
	hero_light.energy = 0.38
	hero_light.height = 26.0
	hero_light.position = Vector2(-26, -52)
	hero.add_child(hero_light)
	# Laundry: one lamp per wall tile (where the picture has it), cold light from the windows.
	for k in 4:
		var x := 600.0 + 450.0 * k
		_lamp(Vector2(x + 75, 142), Color(1.0, 0.72, 0.42), 1.05, 200.0, 22.0)
		_lamp(Vector2(x + 205, 105), Color(0.62, 0.78, 1.0), 0.45, 260.0, 55.0, false)
	# The machine hall is darker; the generator and the pump glow a little once running.
	_lamp(Vector2(652, GROUND - 30), Color(1.0, 0.55, 0.25), 0.0, 70.0, 20.0).name = "GenGlow"
	# Station: the yard lamps and the workshop lamps, warm.
	for p in [Vector2(5027, 134), Vector2(5414, 134), Vector2(5480, 62), Vector2(5755, 60)]:
		_lamp(p, Color(1.0, 0.74, 0.46), 1.0, 200.0, 22.0)
	_lamp(Vector2(5880, 150), Color(0.9, 0.82, 0.75), 0.5, 220.0, 80.0, false)
	# Exterior: lit windows of the street and the yard pictures.
	for p in [Vector2(-1960, 210), Vector2(-1740, 160), Vector2(-260, 200), Vector2(2560, 230), Vector2(2760, 230)]:
		_lamp(p, Color(1.0, 0.7, 0.4), 0.55, 150.0, 22.0)
	rays = _layer(4, _draw_rays)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	rays.material = add
	var dust := CPUParticles2D.new()
	dust.amount = 40
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(900, 120)
	dust.position = Vector2(1500, 190)
	dust.direction = Vector2(0.3, 1)
	dust.spread = 60.0
	dust.gravity = Vector2(0, 2)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 4.0
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.3
	dust.color = Color(1.0, 0.92, 0.75, 0.35)
	dust.z_index = 4
	dust.material = add
	add_child(dust)
	front = _layer(7, _draw_front)
	var flat := CanvasItemMaterial.new()
	flat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	front.material = flat
	layers.erase(front)
	layers.erase(rays)
	layers.erase(floor_band)
	# The back of every scene a touch cooler and darker than what stands in front of it.
	layers[0].self_modulate = Color(0.86, 0.88, 0.95)

## Volumetric light on or off (the journal has the switch): without it the scene keeps its tone and contact shadows,
## but no lamp passes, shafts or dust, which is the cheap way for weak phones.
func _apply_light() -> void:
	var on := Game.fancy_light
	sun.visible = on
	hero_light.visible = on
	rays.visible = on
	for c in get_children():
		if c is CPUParticles2D:
			c.emitting = on
			c.visible = on
	for l in lamps:
		l.set_meta("off", not on)
		l.visible = on

func _depth(delta: float) -> void:
	var x := hero.global_position.x
	area = "station" if x > 4000.0 else ("in" if x > 612.0 and x < 2400.0 else "out")
	ambient.color = ambient.color.lerp(AMBIENT[area], minf(1.0, delta * 2.5))
	sun.energy = lerpf(sun.energy, 0.55 if area == "out" else 0.0, minf(1.0, delta * 2.5))
	var t := Time.get_ticks_msec() / 1000.0
	for i in lamps.size():
		var l := lamps[i]
		if l.get_meta("off", false):
			continue
		var e: float = l.get_meta("energy")
		if l.get_meta("flicker"):
			e *= 0.92 + 0.08 * sin(t * 7.0 + i * 1.7) * sin(t * 2.3 + i)
		l.energy = e
		l.visible = absf(l.position.x - x) < 480.0      # only lights near the screen cost anything
	var glow: PointLight2D = get_node("GenGlow")
	glow.energy = (0.6 + 0.1 * sin(t * 30.0)) if Game.has("power") else 0.0
	glow.visible = absf(652.0 - x) < 480.0 and Game.fancy_light
	front.queue_redraw()
	floor_band.queue_redraw()
	if Engine.get_process_frames() % 3 == 0:
		rays.queue_redraw()

## Light shafts from the laundry windows, falling to the right (the sun is low on the left).
func _draw_rays(n: Node2D) -> void:
	var cx := hero.global_position.x
	if cx < 200.0 or cx > 2800.0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for k in 4:
		var x := 600.0 + 450.0 * k
		for i in 3:
			var wx: float = [70.0, 150.0, 260.0][i]
			var ww: float = [62.0, 90.0, 90.0][i]
			var a := 0.07 + 0.025 * sin(t * 0.6 + k * 1.3 + i)
			var top := 112.0
			var pts := PackedVector2Array([Vector2(x + wx, top), Vector2(x + wx + ww, top), Vector2(x + wx + ww + 110, GROUND), Vector2(x + wx + 60, GROUND)])
			var cols := PackedColorArray([Color(1, 0.95, 0.85, a), Color(1, 0.95, 0.85, a), Color(1, 0.9, 0.8, 0.0), Color(1, 0.9, 0.8, 0.0)])
			n.draw_polygon(pts, cols)

## Dark things close to the camera that slide past faster than the scene (parallax 1.35): pipes and hanging chains in
## the laundry, foliage and posts outside, columns at the Station. Drawn as silhouettes with a faint warm rim.
const FRONT := [
	["barrel", -1880.0], ["post", -1520.0], ["crate", -1180.0], ["barrel", -760.0], ["crate", -380.0], ["post", -60.0], ["barrel", 300.0],
	["pipe", 760.0], ["chain", 1010.0], ["pipe", 1260.0], ["chain", 1530.0], ["pipe", 1720.0], ["chain", 1900.0], ["pipe", 2180.0],
	["crate", 2520.0], ["post", 2700.0], ["barrel", 2900.0],
	["pipe", 5380.0], ["chain", 5520.0], ["pipe", 5900.0]]

func _draw_front(n: Node2D) -> void:
	var cam := camera.get_screen_center_position()
	var dark := Color(0.035, 0.045, 0.055, 0.88)
	var rim := Color(0.45, 0.33, 0.22, 0.55)
	for e in FRONT:
		var wx: float = e[1]
		if absf(wx - cam.x) > 700.0:
			continue
		var x: float = cam.x + (wx - cam.x) * 1.35
		match e[0]:
			"pipe":
				n.draw_rect(Rect2(x - 9, -60, 18, 500), dark)
				n.draw_rect(Rect2(x - 9, -60, 2, 500), rim)
				for y in [60.0, 190.0, 300.0]:
					n.draw_rect(Rect2(x - 12, y, 24, 8), dark)
					n.draw_rect(Rect2(x - 12, y, 24, 1), rim)
			"chain":
				for i in 14:
					var y := -20.0 + i * 11.0
					n.draw_rect(Rect2(x - 3 + (i % 2) * 1.0, y, 6 - (i % 2) * 2.0, 9), dark)
				n.draw_rect(Rect2(x - 8, 134, 16, 10), dark)
			"post":
				n.draw_rect(Rect2(x - 4, 90, 8, 260), dark)
				n.draw_rect(Rect2(x - 4, 90, 1, 260), rim)
				n.draw_rect(Rect2(x - 4, 90, 26, 5), dark)
				n.draw_circle(Vector2(x + 20, 100), 5.0, Color(1.0, 0.75, 0.4, 0.5))
			"barrel", "crate":
				# A real prop, big and dark, standing below the walk line close to the camera.
				var t: Texture2D = Art.tex("res://assets/rest/%s_0.png" % e[0])
				var sz := Vector2(t.get_width(), t.get_height()) / 3.0 * 2.1
				n.draw_texture_rect(t, Rect2(x - sz.x / 2.0, GROUND + 58 - sz.y, sz.x, sz.y), false, Color(0.07, 0.075, 0.085, 0.95))

# ======================================================================= drawing
func _tile(n: CanvasItem, t: Texture2D, x0: float, x1: float, top: float, w: float, h: float) -> void:
	var x := x0
	while x < x1 - 0.5:
		var seg := minf(w, x1 - x)
		n.draw_texture_rect_region(t, Rect2(x, top, seg, h), Rect2(0, 0, t.get_width() * seg / w, t.get_height()))
		x += seg

## Draws `t` over [x0, x1] fading in over its first `soft` units, so two pictures meet without a hard seam.
func _soft_left(n: CanvasItem, t: Texture2D, x0: float, top: float, w: float, h: float, soft: float) -> void:
	var k := t.get_width() / w
	var steps := 12
	for i in steps:
		var a := (i + 1.0) / steps
		var sx := soft * i / steps
		n.draw_texture_rect_region(t, Rect2(x0 + sx, top, soft / steps, h), Rect2(sx * k, 0, soft / steps * k, t.get_height()), Color(1, 1, 1, a))
	n.draw_texture_rect_region(t, Rect2(x0 + soft, top, w - soft, h), Rect2(soft * k, 0, (w - soft) * k, t.get_height()))

func _draw_back(n: Node2D) -> void:
	n.draw_rect(Rect2(-2060, -200, 5100, 700), Color("#141c22"))
	# Street (its pavement top sits at 77.5% of the picture), the courtyard (72.5%), the yard.
	n.draw_texture_rect(tex["bg_street.jpg"], Rect2(-2040, GROUND - 372, 1440, 480), false)
	_soft_left(n, tex["bg_court.jpg"], -720, GROUND - 348, 1440, 480, 70)
	n.draw_texture_rect(tex["bg_yard.jpg"], Rect2(2400, GROUND - 372, 1440, 480), false)
	# The laundry: tiled wall, darker in the machine hall.
	_tile(n, tex["bg_laundry.jpg"], 600, 2400, GROUND - 300, 450, 300)
	n.draw_rect(Rect2(600, -200, 1800, GROUND - 300 + 200), Color("#10161a"))
	n.draw_rect(Rect2(1540, GROUND - 300, 520, 300), Color(0.02, 0.04, 0.05, 0.35))
	# The Station: metro yard and Mira's workshop.
	n.draw_rect(Rect2(STATION_X0 - 40, -200, STATION_X1 - STATION_X0 + 80, 700), Color("#141c22"))
	n.draw_texture_rect(tex["bg_station.jpg"], Rect2(STATION_X0, GROUND - 300, 450, 300), false)
	n.draw_texture_rect(tex["bg_workshop.jpg"], Rect2(STATION_X0 + 450, GROUND - 300, 450, 300), false)

## Things standing on the floor in front of the walls: nests, the service door, laundry equipment, puddles, the drain.
func _draw_mid(n: Node2D) -> void:
	for x in [1712.0, 1938.0, 1828.0, 2775.0]:
		if not Art.draw_prop(n, "crawler_nest", 0, Vector2(x + 6.0, GROUND + 1.0)):
			n.draw_rect(Rect2(x - 8, GROUND - 3, 16, 3), Color("#4d3a26"))
			n.draw_rect(Rect2(x - 3, GROUND - 5, 6, 2), Color("#7a5a3a"))
	if not Art.draw_prop(n, "service_door", 0, Vector2(1531, GROUND)):
		n.draw_rect(Rect2(1518, GROUND - 62, 26, 62), Color("#07090b"))
		n.draw_rect(Rect2(1516, GROUND - 64, 30, 3), Color("#3b4a52"))
	for spec in LAUNDRY_DECO:
		Art.draw_prop(n, spec[0], spec[1], Vector2(spec[2], GROUND + 1.0), spec[3])
	if Game.has("drained"):
		for x in [820.0, 1010.0, 1240.0, 1480.0]:
			Art.draw_prop(n, "puddle", 0, Vector2(x, GROUND + 2.0))
	# The courtyard drain: a grate, choked with leaves and silt until cleared.
	var d := Vector2(300, GROUND)
	n.draw_rect(Rect2(d.x - 20, d.y - 3, 40, 4), Color("#1c2226"))
	for i in 7:
		n.draw_rect(Rect2(d.x - 18 + i * 6, d.y - 3, 2, 4), Color("#5b646a"))
	if not Game.has("drain_clear"):
		for i in 9:
			n.draw_rect(Rect2(d.x - 18 + (i * 37) % 36, d.y - 5 + (i % 3), 5, 3), [Color("#6b5a2a"), Color("#4f6b2a"), Color("#7a4a26")][i % 3])
	elif Game.has("drained"):
		Art.draw_prop(n, "puddle", 0, Vector2(d.x + 30, GROUND + 2.0))
	# The fire-escape ladder, pulled up until the hook brings it down.
	if not Game.has("ladder_down"):
		n.draw_texture_rect(tex["ladder_0.png"], Rect2(-1623, GROUND - 162, 26, 112), false)

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
	_tile(n, tex["floor_bunker_0.png"], 600, 2402, GROUND - 4, 420, 73.3)
	_tile(n, tex["floor_bunker_0.png"], STATION_X0, STATION_X1, GROUND - 4, 420, 73.3)
	# Where wall meets floor, and under each walkway: soft shadow, so the room has a back and a front.
	for span in [[600.0, 2400.0], [STATION_X0, STATION_X1]]:
		_shade(n, span[0], span[1], GROUND - 4.0, 46.0, 0.5)
	for span in [[680.0, 1205.0], [1530.0, 2080.0], [-1640.0, -1030.0], [-820.0, -660.0]]:
		_shade(n, span[0], span[1], DECK + 60.0, 60.0, 0.32)
	# The front edge of the floor falls into shadow towards the bottom of the screen.
	for span in [[600.0, 2402.0], [STATION_X0, STATION_X1]]:
		n.draw_polygon(PackedVector2Array([Vector2(span[0], GROUND + 20), Vector2(span[1], GROUND + 20), Vector2(span[1], GROUND + 72), Vector2(span[0], GROUND + 72)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55)]))

## The floor seen from slightly above: a strip from the foot of the wall (back) to where everyone walks (front), its
## tile seams converging towards the middle of the screen, so the wall stands behind the floor instead of on it.
const BAND_BACK := 20.0
func _draw_floor_band(n: Node2D) -> void:
	var cam := camera.get_screen_center_position()
	for span in [[600.0, 2402.0], [STATION_X0, STATION_X1]]:
		var x0: float = maxf(span[0], cam.x - 420.0)
		var x1: float = minf(span[1], cam.x + 420.0)
		if x1 <= x0:
			continue
		var yb := GROUND - BAND_BACK
		var yf := GROUND - 3.0
		var k := 0.84            # how much narrower the back edge is: the perspective
		var bx0 := cam.x + (x0 - cam.x) * k
		var bx1 := cam.x + (x1 - cam.x) * k
		# Fill: the strip, darker at the back.
		n.draw_polygon(PackedVector2Array([Vector2(x0, yb), Vector2(x1, yb), Vector2(x1, yf), Vector2(x0, yf)]),
			PackedColorArray([Color(0.11, 0.12, 0.13), Color(0.11, 0.12, 0.13), Color(0.27, 0.26, 0.24), Color(0.27, 0.26, 0.24)]))
		# Seams running into the depth, every 30 units of the front edge.
		var sx := floorf(x0 / 30.0) * 30.0
		while sx <= x1:
			if sx >= x0:
				n.draw_line(Vector2(cam.x + (sx - cam.x) * k, yb), Vector2(sx, yf), Color(0, 0, 0, 0.35), 1.0)
			sx += 30.0
		# Seams across, closer together at the back.
		for f in [0.18, 0.42, 0.72]:
			var y: float = yb + (yf - yb) * f
			n.draw_line(Vector2(x0, y), Vector2(x1, y), Color(0, 0, 0, 0.22), 1.0)
		# Wet sheen near the front, the dark corner at the back, the lit front lip.
		n.draw_polygon(PackedVector2Array([Vector2(x0, yb), Vector2(x1, yb), Vector2(x1, yb + 5), Vector2(x0, yb + 5)]),
			PackedColorArray([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		n.draw_line(Vector2(x0, yf), Vector2(x1, yf), Color(0.55, 0.5, 0.42, 0.55), 1.0)
		if bx1 > bx0:
			pass

## A shadow band whose bottom edge (y_bottom) is darkest, fading upwards over h.
func _shade(n: CanvasItem, x0: float, x1: float, y_bottom: float, h: float, a: float) -> void:
	n.draw_polygon(PackedVector2Array([Vector2(x0, y_bottom - h), Vector2(x1, y_bottom - h), Vector2(x1, y_bottom), Vector2(x0, y_bottom)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, a), Color(0, 0, 0, a)]))

func _draw_decks(n: Node2D) -> void:
	var w: Texture2D = tex["walkway_0.png"]
	var top := DECK - 21.0
	# Balconies over the flooded street, the roof gangway.
	_tile(n, w, -1640, BR_X0, top, 300, 54.6)
	_tile(n, w, BR_X1, -1030, top, 300, 54.6)
	_tile(n, w, -1010, -880, ROOF - 21.0, 300, 54.6)
	_tile(n, w, -820, -660, top, 300, 54.6)
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
		if Game.has("bridge"):
			for i in 6:
				n.draw_rect(Rect2(GAP_X0 - 2 + i * 15.5, DECK - 1, 14, 4), Color("#8a6236") if i % 2 == 0 else Color("#7a5530"))
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

func _draw_fx(n: Node2D) -> void:
	for s in sparks:
		n.draw_rect(Rect2(s.p, Vector2(1.5, 1.5)), Color(1.0, 0.85, 0.4, clampf(s.t / 0.35, 0.0, 1.0)))
	for d in drops:
		n.draw_rect(Rect2(d.p, Vector2(1.5, 2.5)), Color(0.7, 0.9, 0.95, clampf(d.t, 0.0, 0.9)))
	# The jet: a column of water from the pipe to the walkway while it strikes.
	if jet_t > 2.0 and jet_t < 3.3:
		var tt := Time.get_ticks_msec() / 60.0
		n.draw_rect(Rect2(JET_X - 4, DECK - 42, 8, 42), Color(0.55, 0.8, 0.88, 0.75))
		for i in 6:
			n.draw_rect(Rect2(JET_X - 6 + fmod(tt + i * 3.0, 12.0), DECK - 40 + i * 7, 2, 4), Color(0.9, 0.97, 1.0, 0.85))
		n.draw_rect(Rect2(JET_X - 12, DECK - 3, 24, 3), Color(0.8, 0.93, 0.97, 0.7))
	for b in bubbles:
		n.draw_string(font, b.p, b.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color(1, 0.92, 0.7, clampf(b.t, 0.0, 1.0)))
	# Progress of the current job: a thin bar over the hero.
	for id in progress_of:
		var at := Vector2(hero.global_position.x, hero.global_position.y - 80)
		n.draw_rect(Rect2(at.x - 16, at.y, 32, 4), Color(0.05, 0.07, 0.08, 0.85))
		n.draw_rect(Rect2(at.x - 15, at.y + 1, 30 * progress_of[id], 2), Color("#f2c14e"))
	# A tin rolling where a distracted crawler gnaws it (M7).
	for c in crawlers:
		if c.st == "distracted" and washer_t <= 4.0:
			Art.draw_prop(n, "can_crushed", 0, Vector2(c.bait_x + 8.0, GROUND))
	var e := Vector2(2960, GROUND)
	if not Art.draw_prop(n, "sign_station", 0, e):
		_code_sign(n, e)
	if Game.has("gate") and not Game.has("delivered"):
		n.draw_rect(Rect2(CART_SAFE - 30, GROUND - 2, 60, 2), Color(0.95, 0.76, 0.3, 0.6 + 0.3 * sin(Time.get_ticks_msec() / 200.0)))
	# The courtyard rack without its M5 picture: a frame with rags.
	if props.rack.art == "":
		var r := Vector2(-430, GROUND)
		n.draw_rect(Rect2(r.x - 18, r.y - 38, 2, 38), Color("#5a4636"))
		n.draw_rect(Rect2(r.x + 16, r.y - 38, 2, 38), Color("#5a4636"))
		n.draw_rect(Rect2(r.x - 18, r.y - 38, 36, 2), Color("#5a4636"))
		if not Game.has("rag_taken"):
			n.draw_rect(Rect2(r.x - 8, r.y - 36, 12, 16), Color("#c9c2a8"))

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
	if OS.get_cmdline_user_args().has("--flat"):
		Game.fancy_light = false
		_apply_light()
	var t0 := Time.get_ticks_msec()
	var stage := func(name: String):
		print("stage %-12s at %5.1f s (game clock %5.1f)" % [name, (Time.get_ticks_msec() - t0) / 1000.0, Game.play_time])
	await _wait(1.0)
	frame_ms.clear()
	await _shot(dir, "01-street", perf)
	# 1. Approach.
	await _go(-1878)
	await _job()
	await _go(-1760)
	await _job()
	await _go(-1626)
	await _use(0.7)
	await _shot(dir, "02-hook", perf)
	await _wait_job()
	await _go(-1610)
	await _climb()
	await _go(-1352)
	await _use(1.2)
	await _shot(dir, "03-em-bridge", perf)
	await _wait_job()
	await _wait(0.4)
	await _go(-1078)
	await _hop(1, 0.3)
	await _go(-1048)
	await _hop(1, 0.55)
	await _go(-990)
	await _shot(dir, "04-roof", perf)
	await _go(-905)
	await _leap(1)
	await _wait(0.6)
	await _go(-680)
	await _climb()
	await _shot(dir, "05-court", perf)
	stage.call("approach")
	await _go(-452)
	await _job()
	await _go(578)
	await _job()
	await _shot(dir, "06-entered", perf)
	_stats("підхід")
	# 2. Recon: try the valve first, then the plan.
	await _go(700)
	await _climb()
	await _go(1040)
	await _job()
	await _wait(1.0)
	await _shot(dir, "07-plan", perf)
	await _go(1132)
	await _job()
	await _go(972)
	await _job()
	await _shot(dir, "08-pipe", perf)
	await _go(700)
	await _climb()
	await _go(628)
	await _job()
	await _go(280)
	await _job()
	await _shot(dir, "09-drain", perf)
	await _go(700)
	await _climb()
	await _go(1040)
	await _job()
	await _wait(1.5)
	await _shot(dir, "10-draining", perf)
	stage.call("recon")
	await _wait(4.0)
	_stats("розвідка")
	# 3. Drain: Nazar, beam, rubble, door.
	await _go(1188)
	await _climb()
	await _go(1214)
	await _job()
	await _shot(dir, "11-vent", perf)
	await _wait(2.0)
	await _go(1272)
	await _job()
	await _go(1336)
	await _use(1.4)
	await _shot(dir, "12-rubble", perf)
	await _wait_job()
	await _go(1430)
	await _job()
	await _wait(1.0)
	await _shot(dir, "13-nazar", perf)
	stage.call("rescue")
	# 4. Route.
	if low:
		await _go(1570)
		await _wait(0.3)
		await _go(WASHER_X - 18.0)
		await _use(0.5)
		await _wait(1.6)
		await _shot(dir, "14-washer", perf)
		await _go(2090)
		await _shot(dir, "15-past", perf)
	else:
		await _go(1550)
		await _climb()
		await _go(1742)
		await _job()
		await _shot(dir, "14-bridge", perf)
		# Wait for the jet to stop, then pass.
		await _go(1930)
		while not (jet_t > 0.1 and jet_t < 0.4):
			await get_tree().physics_frame
		await _shot(dir, "15-jet-wait", perf)
		await _go(2065)
		await _climb()
		await _go(2090)
	stage.call("route")
	_stats("маршрут")
	await _wait(0.6)
	# 5. Delivery.
	await _go(2132)
	await _job()
	await _go(props.cart.position.x - 28.0)
	await _job()
	await _go(2186)
	await _job()
	await _go(props.cart.position.x - 28.0)
	await _job()
	await _shot(dir, "16-secured", perf)
	await _go(2356)
	await _use(2.0)
	await _shot(dir, "17-gate", perf)
	await _wait_job()
	await _wait(1.0)
	await _go(2542)
	await _job()
	var guard := 0
	var shot_stop := false
	while not Game.has("delivered") and guard < 160:
		guard += 1
		var c: Interactable = crawlers[3]
		var front: float = props.cart.position.x + 33.0
		var close: bool = c.visible and c.st not in ["gone", "flee", "distracted"] and c.global_position.x - front < 150.0
		if not Game.has("debris") and front > 2560.0:
			await _go(2612)
			await _use(1.2)
			await _shot(dir, "18-debris", perf)
			await _wait_job()
		elif close:
			if not shot_stop:
				shot_stop = true
				await _shot(dir, "19-cart-stopped", perf)
			await _fight(c)
		else:
			await _go(minf(front + 50.0, 2900.0))
			await _wait(0.4)
	await _wait(0.5)
	await _shot(dir, "20-delivered", perf)
	stage.call("delivery")
	_stats("візок")
	# 6. Return.
	await _go(2960)
	await _use(1.6)
	await _shot(dir, "21-station", perf)
	await _go(5120)
	await _use(0.8)
	await _wait(1.0)
	await _shot(dir, "22-yana", perf)
	await _go(5262)
	await _job()
	await _go(5626)
	await _job()
	await _wait(1.0)
	await _shot(dir, "23-bench", perf)
	await _wait(7.0)
	await _shot(dir, "24-end", perf)
	stage.call("return")
	print("demo: %.1f s real, game clock %.1f s, hp %d, route %s, flags %d" % [(Time.get_ticks_msec() - t0) / 1000.0, Game.play_time, Game.hp, "low" if low else "upper", Game.flags.size()])
	print("missing flags: ", ", ".join(["ladder_down", "em_bridge", "court", "entered", "plan_known", "drain_clear", "pipe_fixed", "power", "drained", "talked", "supported", "rubble", "rescued", "route", "loaded", "secured", "gate", "debris", "delivered", "station", "yana_talk", "body_off_cart", "on_bench", "done"].filter(func(f): return not Game.has(f))))
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
		print("demo: could not reach x=%d (at %d, y %d)" % [x, hero.global_position.x, hero.global_position.y])

## A jump holding the direction for `hold` seconds (onto the crate, then onto the roof).
func _hop(dir: int, hold: float) -> void:
	Input.action_press("move_right" if dir > 0 else "move_left")
	await _tap("jump")
	await _wait(hold)
	Input.action_release("move_right")
	Input.action_release("move_left")
	await _wait(0.6)

## A running jump off an edge.
func _leap(dir: int) -> void:
	var a := "move_right" if dir > 0 else "move_left"
	Input.action_press(a)
	await _wait(0.2)
	await _tap("jump")
	await _wait(0.9)
	Input.action_release(a)

func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)

func _use(then := 0.0) -> void:
	await _tap("act")
	if then > 0.0:
		await _wait(then)

func _job() -> void:
	await _use()
	await _wait_job()
	await _wait(0.2)

func _wait_job() -> void:
	var t := 0.0
	while hero.job and t < 10.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0

func _climb() -> void:
	if OS.get_cmdline_user_args().has("--debug"):
		var ov := []
		for a in hero.sensor.get_overlapping_areas():
			ov.append("%s vis=%s mon=%s" % [a.title(), a.visible, a.monitorable])
		print("climb at %d target=%s overlaps=%s" % [hero.global_position.x, hero.target.title() if hero.target else "-", ov])
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

## `-- --selftest`: save/load round trip, death -> respawn at the last checkpoint, no item handed out twice,
## falling into the flood puts the hero back on dry ground.
func _selftest() -> void:
	var fails: Array[String] = []
	var check := func(name: String, cond: bool):
		print("%s %s" % ["OK  " if cond else "FAIL", name])
		if not cond:
			fails.append(name)
	await _wait(0.5)
	# The flood.
	hero.global_position = Vector2(-1620, GROUND - 1)
	await _wait(0.3)
	hero.global_position = Vector2(-1100, GROUND - 1)
	await _wait(0.2)
	check.call("flood sends the hero back to dry ground", hero.global_position.x < FLOOD_X0)
	for f in ["ladder_down", "em_bridge", "court", "entered", "plan_known", "drain_clear", "pipe_fixed", "power", "drained", "crate_open", "talked", "supported", "rubble", "rescued"]:
		Game.set_flag(f)
	Game.give("planks", 2)
	Game.give("can")
	Game.reach_checkpoint("rescued")
	Game.flags = {}
	Game.inv = {}
	check.call("load_save()", Game.load_save())
	check.call("flags restored", Game.has("rescued") and Game.has("drained") and Game.has("power"))
	check.call("items restored", Game.count("planks") == 2 and Game.count("can") == 1 and Game.count("wrench") == 1)
	_apply_flags()
	await _wait(0.3)
	check.call("water drained after load", not water.is_deep())
	check.call("door open after load", props.door.state == 1)
	check.call("crate stays empty", not props.crate.usable())
	check.call("ladder stays down", fire_ladder.visible)
	hero.global_position = Vector2(1900, GROUND - 1)
	await _wait(0.3)
	hero.hurt(200, 1950)
	await _wait(1.6)
	check.call("respawn at rescued checkpoint", absf(hero.global_position.x - SPAWN.rescued) < 3.0)
	check.call("hp back to 100", Game.hp == 100)
	check.call("controls back", hero.controls)
	check.call("crawlers reset asleep", crawlers[0].st == "sleep" and crawlers[0].position.x == crawlers[0].home)
	# An old save (build 0.3): rescued, no approach flags, the yard crawler under its old number.
	Game.flags = {"entered": true, "drained": true, "crate_open": true, "supported": true, "rubble": true, "rescued": true, "crawler2_gone": true}
	Game.loaded_version = 1
	_migrate()
	check.call("old save: approach and plan flags implied", Game.has("ladder_down") and Game.has("court") and Game.has("power") and Game.has("talked"))
	check.call("old save: yard crawler renumbered", Game.has("crawler3_gone") and not Game.has("crawler2_gone"))
	check.call("old save: goal is the route, not the street", _goal()[0] == "Дістанься корпусу фільтра")
	print("selftest: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	Game.reset()
	get_tree().quit(0 if fails.is_empty() else 1)
