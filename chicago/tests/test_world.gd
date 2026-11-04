extends TestCase
## Integration tests on the real world scene (headless physics).

var world: Node

func _boot() -> void:
	world = load("res://world/world.tscn").instantiate()
	world.no_autosave = true
	tree.current_scene.add_child(world)
	await frames(3)

func _done() -> void:
	InputRouter.reset()
	world.queue_free()
	await frames(2)

func _it(id: String) -> Node:
	for n in world.district.interactables:
		if n.id == id:
			return n
	return null

func _drive(v: Vector2, n: int) -> void:
	InputRouter.bot_active = true
	InputRouter.bot_vec = v
	await frames(n)
	InputRouter.bot_vec = Vector2.ZERO
	await frames(20)
	InputRouter.bot_active = false

func test_district_builds_from_data() -> void:
	await _boot()
	eq(world.district.id, "santa_lucia")
	eq(world.district.blocks_by_building.size(), 8, "buildings")
	var slices := 0
	for b in world.district.blocks_by_building.values():
		slices += b.size()
	eq(slices, 4*3 + 4*3 + 9*2 + 3*5 + 3*4 + 4*3 + 3*4 + 5*3, "one slice per footprint cell")
	check(world.district.tiles_of(District.T.SIDEWALK).size() > 50, "sidewalks marked")
	check(world.district.is_free(Iso.to_grid(world.player.position)), "player spawned on free ground")
	check(not world.district.is_free(Vector2(16.5, 13.45)), "a lamp post blocks its spot")
	eq(world.vehicles.size(), 1, "Marco's car parked here")
	check(get_peds() >= 3, "pedestrians spawned")
	await _done()

func get_peds() -> int:
	return world.get_tree().get_nodes_in_group("pedestrian").size()

func test_player_moves_and_collides() -> void:
	await _boot()
	var p: Player = world.player
	var x0 := p.position.x
	await _drive(Vector2(1, 0), 60)
	check(p.position.x - x0 > 120.0, "moved right %.1f" % (p.position.x - x0))
	# Push into the garage's front wall from the sidewalk for two seconds.
	p.position = Iso.to_screen(Vector2(9.0, 13.5))
	await frames(2)
	await _drive(Vector2(0, -1), 120)
	var g := Iso.to_grid(p.position)
	check(not Rect2(7, 10, 4, 3).has_point(g), "stayed out of the garage footprint, at %s" % g)
	await _done()

func test_homecoming_through_the_real_scene() -> void:
	await _boot()
	world.player.position = _it("garage_door").position
	await frames(8)
	world.interact()
	await frames(4)
	eq(world.district.id, "garage_interior", "entered the garage")
	check(GameState.quests.objective_done("ch1_homecoming", "reach_shop"), "objective reach_shop")
	check(world.npcs.has("salvatore"), "father at work at 08:00")
	world.player.position = world.npcs.salvatore.position + Vector2(-40, 10)
	await frames(8)
	world.interact()
	check(world.hud.dialogue.is_open(), "dialogue opened")
	eq(world.hud.dialogue.dialogue_id, "salvatore_homecoming")
	var guard := 0
	while world.hud.dialogue.is_open() and guard < 20:
		guard += 1
		var ch: Array[int] = world.hud.dialogue.visible_choices()
		if ch.is_empty():
			world.hud.dialogue.advance()
		else:
			world.hud.dialogue.choose(ch[0])
	eq(GameState.quests.state("ch1_homecoming"), "completed")
	eq(GameState.quests.state("ch1_shop_debt"), "active")
	check(GameState.relationships.get_value("salvatore", "affection") > 55, "hug remembered")
	# Leave: back on the street in front of the garage.
	world.player.position = _it("street_door").position
	await frames(8)
	world.interact()
	await frames(4)
	eq(world.district.id, "santa_lucia")
	check(Player.ground_dist(world.player.position, world.district.spawn_screen("garage_front")) < 80.0, "came out at the garage door")
	await _done()

func test_workbench_jobs_limited_and_counted() -> void:
	GameState.location = {"district": "garage_interior", "spawn": "from_street", "pos": null, "in_vehicle": ""}
	GameState.businesses.acquire("bellini_garage")
	await _boot()
	WorldClock.set_total(9 * 60)
	var cash := GameState.ledger.balance
	var bench := _it("workbench_job")
	world.player.position = bench.position + Vector2(0, 30)
	await frames(8)
	for i in 3:
		world.interact()
	eq(GameState.ledger.balance - cash, 1200, "two jobs paid (level 0 allows 2 per day)")
	eq(WorldClock.hour(), 12, "each job takes 90 minutes")
	await _done()

func test_trattoria_closed_early() -> void:
	await _boot()
	WorldClock.set_total(7 * 60)
	world.player.position = _it("trattoria_door").position
	await frames(8)
	world.interact()
	await frames(4)
	eq(world.district.id, "santa_lucia", "closed at 07:00")
	WorldClock.set_total(12 * 60)
	world.interact()
	await frames(4)
	eq(world.district.id, "trattoria_interior", "open at noon")
	await _done()

func test_car_needs_keys_then_drives_crashes_repairs_exits() -> void:
	await _boot()
	var car: Vehicle = world.vehicles.monarch_marco
	world.player.position = car.position + Vector2(0, 45)
	await frames(8)
	world.interact()
	eq(String(GameState.location.in_vehicle), "", "no keys: cannot drive Marco's car")
	GameState.add_item("car_keys_monarch", 1)
	var f: Node = world._find_focus()
	check(f == car, "focus is the car, got %s at dist %.1f" % [f, Player.ground_dist(world.player.position, car.position)])
	world.interact()
	eq(String(GameState.location.in_vehicle), "monarch_marco", "entered")
	check(not world.player.visible, "player hidden while driving")
	var g0 := car.grid_pos()
	await _drive(Vector2(1, 0.5).normalized(), 90)   # along the road (+x grid)
	check(car.grid_pos().x - g0.x > 2.0, "drove %.2f tiles" % (car.grid_pos().x - g0.x))
	# Line up facing the garage wall (-y grid = screen up-right) and drive into it.
	car.position = Iso.to_screen(Vector2(9.0, 15.6))
	car.heading = -PI / 2.0
	car.speed = 0.0
	await frames(2)
	await _drive(Vector2(1, -0.5).normalized(), 140)
	check(car.damage > 0, "impact damaged the car (damage %d)" % car.damage)
	var ok: bool = world._exit_vehicle()
	await frames(4)
	check(ok, "exited")
	check(world.player.visible, "player visible again")
	check(world.district.is_free(Iso.to_grid(world.player.position)), "player on free ground after exit")
	check(not Geometry2D.is_point_in_polygon(Iso.to_grid(world.player.position), car.footprint()), "not inside the car")
	# Drive it back to the garage bay and repair it.
	car.position = Iso.to_screen(Vector2(10.6, 14.6))
	world.player.position = _it("repair_bay").position
	await frames(8)
	GameState.pay(5000, "test:cash", "test")
	var cash := GameState.ledger.balance
	var cost: int = car.repair_cost() + (100 - car.fuel) * 2
	world._use(_it("repair_bay"))
	eq(car.damage, 0, "repaired")
	eq(cash - GameState.ledger.balance, cost, "paid once")
	await _done()

func test_world_save_load_keeps_place_and_car() -> void:
	await _boot()
	GameState.add_item("car_keys_monarch", 1)
	var car: Vehicle = world.vehicles.monarch_marco
	car.position = Iso.to_screen(Vector2(15.0, 14.7))
	car.heading = 1.0
	car.damage = 33
	world.player.position = Iso.to_screen(Vector2(15.5, 13.5))
	await frames(2)
	world.sync_to_state()
	eq(SaveService.save("t1"), OK)
	GameState.new_game()
	eq(SaveService.load_slot("t1"), OK)
	world.queue_free()
	await frames(2)
	await _boot()
	near(Iso.to_grid(world.player.position).x, 15.5, 0.05, "player x")
	near(world.vehicles.monarch_marco.grid_pos().x, 15.0, 0.05, "car x")
	eq(world.vehicles.monarch_marco.damage, 33, "car damage")
	near(world.vehicles.monarch_marco.heading, 1.0, 0.001, "car heading")
	await _done()

func test_night_is_darker_and_lamps_light() -> void:
	await _boot()
	WorldClock.set_total(12 * 60)
	world._update_light()
	var day: Color = world.light.color
	WorldClock.set_total(23 * 60)
	world._update_light()
	check(world.light.color.get_luminance() < day.get_luminance() * 0.7, "night darker")
	var lit := 0
	for n in world.district.entities.get_children():
		if "lit" in n and n.lit:
			lit += 1
	check(lit >= 4, "street lamps on at night (%d)" % lit)
	await _done()

func test_npc_walks_round_furniture() -> void:
	GameState.location = {"district": "garage_interior", "spawn": "from_street", "pos": null, "in_vehicle": ""}
	await _boot()
	var n := NPC.new()
	n.setup("pedestrian", DataRegistry.get_def("npcs", "pedestrian"))
	n.district = world.district
	n.position = Iso.to_screen(Vector2(3.5, 5.5))
	world.district.entities.add_child(n)
	await frames(2)
	var goal := Iso.to_screen(Vector2(8.5, 3.5))     # the customer's car on the lift is in between
	n.walk_to(goal)
	var max_stuck := 0.0
	for i in 600:
		max_stuck = maxf(max_stuck, n.stuck_t)
		if not n.has_target:
			break
		await frames(1)
	check(not n.has_target, "arrived")
	check(max_stuck < 1.0, "walked round, never stuck long enough to be teleported (%.2f s)" % max_stuck)
	await _done()
