extends Node2D
## The playing scene: hosts one district at a time, the player, cars, NPCs, camera, light and the HUD, and turns
## player actions into effects on GameState. It owns no saved state: everything persistent lives in GameState and is
## written back by sync_to_state() before every save.

const AUTOSAVE := "autosave"
const MANUAL := "slot1"
const INTERIOR_ZOOM := 1.3

var district: District
var player: Player
var camera: Camera2D
var hud: HUD
var light: CanvasModulate
var rain_fx: CPUParticles2D
var npcs := {}                 # npc_id -> NPC
var vehicles := {}             # instance id -> Vehicle
var focus: Node = null         # the interactable the action button would use
var _areas_inside: Array[String] = []
var _tick := 0.0
var _raining := false
var paused := false
var transitioning := false
var conflict: Node             # combat/conflict_director.gd
var ui_zoom := 1.0
var no_autosave := false       # tests

func _ready() -> void:
	add_to_group("save_sync")
	add_to_group("world")
	light = CanvasModulate.new()
	add_child(light)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	player = Player.new()
	player.name = "Player"
	hud = HUD.new()
	add_child(hud)
	hud.action_pressed.connect(interact)
	hud.attack_pressed.connect(_attack)
	hud.pause_toggled.connect(toggle_pause)
	hud.menu_save.connect(func(): _save_manual())
	hud.menu_load.connect(func(): _load_manual())
	hud.menu_quit.connect(_quit_to_menu)
	hud.dialogue.finished.connect(_on_dialogue_finished)
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 5
	add_child(fx_layer)
	rain_fx = _make_rain()
	fx_layer.add_child(rain_fx)
	conflict = preload("res://combat/conflict_director.gd").new()
	conflict.world = self
	add_child(conflict)
	EventBus.hour_changed.connect(_on_hour)
	EventBus.quest_changed.connect(_on_quest_changed)
	EventBus.game_event.connect(_on_game_event)
	get_viewport().size_changed.connect(_apply_zoom)
	GameState.set_flag("game_started", true)
	var loc: Dictionary = GameState.location
	load_district(String(loc.district), String(loc.spawn), loc.get("pos", null), String(loc.get("in_vehicle", "")))
	WorldClock.running = true

# ================================================================= districts
## Swaps the district. While it runs SaveService refuses to save (no half-built state on disk).
## `pos` (grid [x, y]) restores an exact saved spot; otherwise the spawn point is used. A blocked spot is moved to
## the nearest free one.
func load_district(id: String, spawn_id: String, pos: Variant = null, in_vehicle: String = "") -> void:
	var def := DataRegistry.district(id)
	if def.is_empty():
		push_error("World: unknown district " + id)
		return
	transitioning = true
	SaveService.transition_lock = true
	var from_id := district.id if district else ""
	EventBus.district_will_change.emit(from_id, id)
	if district:
		_store_vehicles()
		if player.get_parent():
			player.get_parent().remove_child(player)
		for v in vehicles.values():
			if v.get_parent():
				v.get_parent().remove_child(v)
			v.queue_free()
		district.queue_free()
		district.get_parent().remove_child(district)
	vehicles.clear()
	npcs.clear()
	district = District.new()
	district.name = "District_" + id
	add_child(district)
	move_child(district, 0)
	district.build(def)
	var g: Vector2
	if pos is Array and (pos as Array).size() == 2:
		g = Vector2(float(pos[0]), float(pos[1]))
	else:
		g = Iso.to_grid(district.spawn_screen(spawn_id))
	g = district.nearest_free(g)
	player.position = Iso.to_screen(g)
	player.velocity = Vector2.ZERO
	player.visible = true
	district.entities.add_child(player)
	player.set_facing(district.spawn_facing(spawn_id))
	_spawn_vehicles()
	_spawn_npcs(true)
	_spawn_pedestrians()
	GameState.location = {"district": id, "spawn": spawn_id, "pos": [g.x, g.y], "facing": player.facing, "in_vehicle": ""}
	if in_vehicle != "" and vehicles.has(in_vehicle):
		_enter_vehicle(vehicles[in_vehicle])
	_areas_inside = district.areas_at(g)
	camera.limit_left = -100000
	_apply_zoom()
	camera.position = player.position
	camera.reset_smoothing()
	_update_light()
	transitioning = false
	SaveService.transition_lock = false
	EventBus.district_loaded.emit(id)
	EventBus.emit_event("entered_district", {"district": id, "from": from_id})
	if from_id != "" and not no_autosave:
		autosave()

func _apply_zoom() -> void:
	if district == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var z := vs.y / 720.0 * ui_zoom * (INTERIOR_ZOOM if district.is_interior else 1.0)
	camera.zoom = Vector2(z, z)
	var b := district.screen_bounds()
	var view := vs / z
	var margin := 160.0
	b = b.grow(margin)
	b.position.y -= 220.0   # room for building tops along the back edge
	b.size.y += 220.0
	if b.size.x < view.x:
		var cx := b.get_center().x
		b.position.x = cx - view.x / 2.0
		b.size.x = view.x
	if b.size.y < view.y:
		var cy := b.get_center().y
		b.position.y = cy - view.y / 2.0
		b.size.y = view.y
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.end.x)
	camera.limit_bottom = int(b.end.y)

func _spawn_vehicles() -> void:
	for vid in GameState.vehicles:
		var st: Dictionary = GameState.vehicles[vid]
		if String(st.get("district", "")) != district.id:
			continue
		var d: Dictionary = DataRegistry.get_def("vehicles", String(st.def)).duplicate()
		d["_id"] = String(st.def)
		var v := Vehicle.new()
		v.setup(vid, d, st)
		v.rain = _raining
		v.impact.connect(_on_vehicle_impact.bind(v))
		district.entities.add_child(v)
		vehicles[vid] = v

func _store_vehicles() -> void:
	for vid in vehicles:
		var v: Vehicle = vehicles[vid]
		var st: Dictionary = v.to_state(district.id)
		st["owner"] = GameState.vehicles.get(vid, {}).get("owner", "")
		GameState.vehicles[vid] = st

## Named NPCs scheduled here appear at their spots. `instant`: on district load (no walking in from nowhere).
func _spawn_npcs(instant: bool) -> void:
	var here := Schedule.present_in(district.id, GameState)
	for id in npcs.keys():
		if not here.has(id):
			var n: NPC = npcs[id]
			_send_away(n)
	for id in here:
		var spot: Variant = district.spot_screen(String(here[id]))
		if spot == null:
			continue
		if npcs.has(id):
			npcs[id].leaving = false
			npcs[id].walk_to(spot)
			continue
		var n := NPC.new()
		n.setup(id, DataRegistry.get_def("npcs", id))
		if instant:
			n.position = spot
		else:
			n.position = _entry_point()
			n.walk_to(spot)
		n.left_district.connect(_on_npc_left)
		district.entities.add_child(n)
		npcs[id] = n

func _entry_point() -> Vector2:
	for it in district.interactables:
		if it.kind == "door":
			return it.position
	return district.spawn_screen("")

func _send_away(n: NPC) -> void:
	n.leaving = true
	n.walk_to(_entry_point())

func _on_npc_left(n: NPC) -> void:
	npcs.erase(n.npc_id)
	n.queue_free()

func _spawn_pedestrians() -> void:
	var pop: Dictionary = district.def.get("population", {})
	var count := int(pop.get("pedestrians", 0))
	if _raining:
		count = count / 2
	var walk := district.tiles_of(District.T.SIDEWALK)
	if walk.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pop.get("seed", 1)) * 1000 + WorldClock.day()
	var coats := [Color("#5c5446"), Color("#3e4a52"), Color("#6a3e36"), Color("#4b5a3e"), Color("#7a6a52"), Color("#2f3238")]
	for i in count:
		var p := Pedestrian.new()
		p.setup(district, rng.randi(), walk[rng.randi() % walk.size()], coats[i % coats.size()])
		p.player = player
		district.entities.add_child(p)

# ================================================================= frame
func _process(delta: float) -> void:
	if transitioning or district == null:
		return
	var driving := _driving()
	var follow: Node2D = driving if driving else player
	camera.position = follow.position
	_tick += delta
	if _tick >= 0.2:
		_tick = 0.0
		_slow_update()
	_occlusion(delta)

func _slow_update() -> void:
	focus = _find_focus()
	if focus == null:
		hud.set_action("", false)
	else:
		hud.set_action(focus.verb(), true)
	var g: Vector2 = (_driving().grid_pos() if _driving() else player.grid_pos())
	var now := district.areas_at(g)
	for a in now:
		if not a in _areas_inside:
			EventBus.emit_event("area_reached", {"area": a, "district": district.id, "in_vehicle": GameState.location.get("in_vehicle", "")})
	_areas_inside = now
	var r := Weather.is_raining(GameState.seed_value, WorldClock.total_minutes)
	if r != _raining:
		_raining = r
		if r and not district.is_interior:
			EventBus.toast.emit("TOAST_RAIN", [])
		for v in vehicles.values():
			v.rain = r
	rain_fx.emitting = _raining and not district.is_interior
	_update_light()
	var extra := ""
	var dv := _driving()
	if dv:
		extra = Loc.t("HUD_CAR_CONDITION", [dv.condition()]) + "  " + Loc.t("HUD_FUEL", [dv.fuel])
	if int(GameState.wanted.level) > 0:
		extra += ("  " if extra != "" else "") + Loc.t("HUD_WANTED", [int(GameState.wanted.level)])
	if conflict and conflict.has_method("status_text"):
		var ct: String = conflict.status_text()
		if ct != "":
			extra += ("  " if extra != "" else "") + ct
	hud.refresh(extra)

func _update_light() -> void:
	var dl := WorldClock.daylight()
	var night := Color(0.32, 0.36, 0.56)
	var c := night.lerp(Color.WHITE, dl)
	if district and district.is_interior:
		c = Color(0.82, 0.78, 0.7).lerp(Color.WHITE, dl)
	elif _raining:
		c = c * Color(0.78, 0.8, 0.86)
	light.color = c
	var lit := dl < 0.55
	if district:
		for n in district.entities.get_children():
			if n.has_method("set_lit"):
				n.set_lit(lit)
		for bid in district.blocks_by_building:
			var on := lit and (hash(bid) % 3 != 0)
			for b in district.blocks_by_building[bid]:
				if b.is_lit != on:
					b.is_lit = on
					b.queue_redraw()

## A building that stands between the camera and the player fades so Enzo is never lost behind it.
func _occlusion(delta: float) -> void:
	if district.is_interior:
		return
	var who: Node2D = _driving() if _driving() else player
	var body := Rect2(who.position + Vector2(-18, -110), Vector2(36, 110))
	for bid in district.blocks_by_building:
		var want := 1.0
		for b in district.blocks_by_building[bid]:
			if b.position.y > who.position.y:
				var top: Vector2 = b.position + Vector2(-64, -b.height - 32)
				if Rect2(top, Vector2(128, b.height + 64)).intersects(body):
					want = 0.42
					break
		for b in district.blocks_by_building[bid]:
			if not is_equal_approx(b.fade, want):
				b.fade = move_toward(b.fade, want, delta * 4.0)
				b.queue_redraw()

func _make_rain() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 220
	p.lifetime = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 10)
	p.position = Vector2(640, -20)
	p.direction = Vector2(-0.25, 1)
	p.spread = 3.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 900.0
	p.initial_velocity_max = 1100.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.7, 0.78, 0.9, 0.45)
	p.emitting = false
	return p

# ================================================================= input
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		toggle_pause()
		return
	if paused:
		return
	if hud.dialogue.is_open():
		if e.is_action_pressed("interact") or e.is_action_pressed("ui_next") or e.is_action_pressed("ui_accept"):
			hud.dialogue.advance()
		return
	if e.is_action_pressed("interact") or e.is_action_pressed("vehicle"):
		interact()
	elif e.is_action_pressed("attack"):
		_attack()
	elif e.is_action_pressed("reload"):
		if conflict.has_method("reload"):
			conflict.reload()
	elif e.is_action_pressed("quicksave"):
		_save_manual()
	elif e.is_action_pressed("quickload"):
		_load_manual()

func toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	hud.show_pause(paused)
	hud.touch.release()

func _attack() -> void:
	if conflict and not hud.dialogue.is_open() and not _driving():
		conflict.player_attack()

func _driving() -> Vehicle:
	var id := String(GameState.location.get("in_vehicle", ""))
	return vehicles.get(id, null)

func _find_focus() -> Node:
	var dv := _driving()
	if dv:
		return dv
	var best: Node = null
	var best_d := Player.REACH
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n) or not n.is_inside_tree() or not district.is_ancestor_of(n):
			continue
		var reach := Player.REACH * (1.6 if n is Vehicle else 1.0)
		var d := Player.ground_dist(player.position, n.position)
		if d < reach and d < best_d + (0.0 if best == null else 0.0):
			if d < best_d or best == null:
				best = n
				best_d = d
	return best

func interact() -> void:
	if paused or transitioning:
		return
	if hud.dialogue.is_open():
		hud.dialogue.advance()
		return
	var f := _find_focus()
	if f == null:
		return
	if f is Vehicle:
		if _driving():
			_exit_vehicle()
		else:
			_enter_vehicle(f)
		return
	if f is NPC:
		_talk(f)
		return
	if f is Interactable:
		_use(f)

func _talk(n: NPC) -> void:
	n.face(player.position)
	var d: Dictionary = n.def
	for rule in d.get("dialogue", []):
		if Conditions.check(rule.get("if", {}), GameState):
			hud.dialogue.open(String(rule.dialogue), n.npc_id)
			player.controls_enabled = false
			return

func _on_dialogue_finished(_id: String) -> void:
	player.controls_enabled = true

func _use(it: Interactable) -> void:
	var d: Dictionary = it.def
	match it.kind:
		"door":
			var t: Dictionary = d.target
			var biz := _business_for_target(String(t.district))
			if biz != "" and not GameState.businesses.is_open(biz) and String(t.district) != "garage_interior":
				var h: Array = DataRegistry.get_def("businesses", biz).get("hours", [0, 24])
				EventBus.toast.emit("HUD_CLOSED", ["%02d:00-%02d:00" % [int(h[0]), int(h[1])]])
				return
			call_deferred("load_district", String(t.district), String(t.spawn))
		"repair_job":
			_repair_job(it)
		"pay_debt":
			var lender := String(d.lender)
			var owed := int(GameState.debts.get(lender, 0))
			if owed <= 0:
				return
			var paid := GameState.pay_debt(lender, owed, "debt:%s:%d" % [lender, WorldClock.total_minutes])
			if paid > 0:
				EventBus.toast.emit("TOAST_DEBT_PAID", [Ledger.dollars(paid)])
			else:
				EventBus.toast.emit("TOAST_NOT_ENOUGH_MONEY", [])
		"sleep":
			WorldClock.advance_to_hour(7)
			EventBus.toast.emit("TOAST_SLEPT", [])
			EventBus.emit_event("slept", {})
			if not no_autosave:
				autosave()
		"business_panel":
			var bz := String(d.business)
			var cost := GameState.businesses.upgrade_cost(bz)
			if cost < 0:
				EventBus.toast.emit("BIZ_PANEL", [tr(DataRegistry.get_def("businesses", bz).name), int(GameState.businesses.st(bz).level), int(GameState.businesses.st(bz).jobs_today)])
			elif GameState.businesses.upgrade(bz):
				EventBus.toast.emit("TOAST_UPGRADED", [])
			elif not Conditions.check(DataRegistry.get_def("businesses", bz).levels[int(GameState.businesses.st(bz).level) + 1].get("requires", {}), GameState):
				EventBus.toast.emit("BIZ_UPGRADE_LOCKED", [])
			else:
				EventBus.toast.emit("BIZ_UPGRADE_COST", [Ledger.dollars(cost)])
		"repair_vehicle":
			_repair_nearby_vehicle(it)
		"pickup":
			if conflict.has_method("pickup"):
				conflict.pickup(it)

func _business_for_target(district_id: String) -> String:
	var b := DataRegistry.table("businesses")
	for id in b:
		if String(b[id].get("interior", "")) == district_id:
			return id
	return ""

func _repair_job(it: Interactable) -> void:
	var biz := String(it.def.business)
	if not GameState.businesses.is_open(biz):
		EventBus.toast.emit("TOAST_SHOP_CLOSED", [])
		return
	var lv := GameState.businesses.level_def(biz)
	if int(GameState.businesses.st(biz).jobs_today) >= int(lv.get("jobs_per_day", 2)):
		EventBus.toast.emit("TOAST_NO_MORE_JOBS", [])
		return
	var job_id := "d%d_%d" % [WorldClock.day(), int(GameState.businesses.st(biz).jobs_today) + 1]
	WorldClock.advance(int(it.def.get("minutes", 60)))
	if GameState.businesses.record_job(biz, job_id):
		EventBus.toast.emit("TOAST_JOB_DONE", [Ledger.dollars(int(lv.get("job_pay_cents", 0)))])

func _repair_nearby_vehicle(it: Interactable) -> void:
	for v in vehicles.values():
		if Player.ground_dist(v.position, it.position) < 3.5 * Iso.TILE_H * 2.0 and v.damage > 0:
			var cost: int = v.repair_cost()
			if GameState.pay(-cost, "veh:%s:repair:%d" % [v.instance_id, WorldClock.total_minutes], "veh:repair"):
				v.repair()
				WorldClock.advance(30)
				EventBus.toast.emit("TOAST_CAR_REPAIRED", [Ledger.dollars(cost)])
				EventBus.emit_event("vehicle_repaired", {"vehicle": v.instance_id, "cost": cost})
			else:
				EventBus.toast.emit("TOAST_NOT_ENOUGH_MONEY", [])
			return

# ================================================================= vehicles
func _enter_vehicle(v: Vehicle) -> void:
	var veh_owner := String(GameState.vehicles.get(v.instance_id, {}).get("owner", ""))
	if veh_owner == "marco" and GameState.item_count("car_keys_monarch") <= 0:
		EventBus.toast.emit("TOAST_NO_KEYS", [])
		return
	if v.condition() <= 0:
		EventBus.toast.emit("TOAST_CAR_BROKEN", [])
	v.driver = player
	player.visible = false
	player.controls_enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	GameState.location.in_vehicle = v.instance_id
	EventBus.emit_event("vehicle_entered", {"vehicle": v.instance_id})

## Leaves the car on the driver's side if free, else any free side, else the nearest free ground.
func _exit_vehicle() -> bool:
	var v := _driving()
	if v == null:
		return false
	var g := v.grid_pos()
	var side := Vector2(-sin(v.heading), cos(v.heading))
	var fwd := v.forward()
	var w := float(v.def.get("width", 0.7)) * 0.5 + 0.35
	var l := float(v.def.get("length", 1.5)) * 0.5 + 0.35
	var spot := Vector2.INF
	for off in [-side * w, side * w, -fwd * l, fwd * l]:
		var p: Vector2 = g + off
		if district.is_free(p) and _clear_of_vehicles(p, v):
			spot = p
			break
	if spot == Vector2.INF:
		var p2 := district.nearest_free(g + side * w)
		if Iso.to_grid(Iso.to_screen(p2)).distance_to(g) > 3.0:
			EventBus.toast.emit("TOAST_EXIT_BLOCKED", [])
			return false
		spot = p2
	v.driver = null
	v.speed = 0.0
	player.position = Iso.to_screen(spot)
	player.velocity = Vector2.ZERO
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.controls_enabled = true
	player.collision_layer = 2
	GameState.location.in_vehicle = ""
	_store_vehicles()
	EventBus.emit_event("vehicle_exited", {"vehicle": v.instance_id})
	return true

func _clear_of_vehicles(g: Vector2, except: Vehicle) -> bool:
	for o in vehicles.values():
		if o != except and Geometry2D.is_point_in_polygon(g, o.footprint()):
			return false
	return true

func _on_vehicle_impact(strength: float, v: Vehicle) -> void:
	EventBus.emit_event("vehicle_impact", {"vehicle": v.instance_id, "strength": strength, "condition": v.condition()})

# ================================================================= world reactions
func _on_hour(_day: int, _hour: int) -> void:
	if district and not transitioning:
		_spawn_npcs(false)

func _on_quest_changed(id: String, state: String) -> void:
	if state == QuestSystem.COMPLETED:
		EventBus.toast.emit("HUD_QUEST_DONE", [tr(String(GameState.quests.defs[id].title))])
		if GameState.quests.defs[id].get("checkpoint", false) and not no_autosave:
			call_deferred("autosave")

func _on_game_event(id: String, _data: Dictionary) -> void:
	if id == "dialogue_done" or id == "business_job_done" or id == "debt_paid":
		_tick = 1.0   # refresh the HUD now

# ================================================================= saving
func sync_to_state() -> void:
	if district == null or transitioning:
		return
	_store_vehicles()
	var dv := _driving()
	var g: Vector2 = dv.grid_pos() if dv else player.grid_pos()
	GameState.location = {"district": district.id, "spawn": GameState.location.get("spawn", ""), "pos": [snappedf(g.x, 0.001), snappedf(g.y, 0.001)],
		"facing": player.facing, "in_vehicle": dv.instance_id if dv else ""}

func autosave() -> void:
	if conflict and conflict.has_method("is_unsafe_to_save") and conflict.is_unsafe_to_save():
		return
	sync_to_state()
	SaveService.save(AUTOSAVE)

func _save_manual() -> void:
	sync_to_state()
	var e := SaveService.save(MANUAL)
	hud.toast(tr("UI_SAVED") if e == OK else Loc.t("UI_SAVE_FAILED", [SaveService.last_error]))

func _load_manual() -> void:
	if not SaveService.has_save(MANUAL):
		return
	get_tree().paused = false
	var e := SaveService.load_slot(MANUAL)
	if e != OK:
		hud.toast(Loc.t("UI_LOAD_FAILED", [SaveService.last_error]))
		return
	get_tree().reload_current_scene()

func _quit_to_menu() -> void:
	autosave()
	get_tree().paused = false
	WorldClock.running = false
	get_tree().change_scene_to_file("res://core/boot.tscn")
