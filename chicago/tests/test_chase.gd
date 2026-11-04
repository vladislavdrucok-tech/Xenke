extends TestCase

var world: Node

func _boot() -> void:
	WorldClock.set_total(12 * 60)
	world = load("res://world/world.tscn").instantiate()
	world.no_autosave = true
	tree.current_scene.add_child(world)
	await frames(3)
	for t in world.get_tree().get_nodes_in_group("traffic"):
		t.queue_free()   # chase tests are about the patrol, not the traffic
	await frames(1)

func _done() -> void:
	InputRouter.reset()
	world.queue_free()
	await frames(2)

func test_path_goes_round_buildings() -> void:
	await _boot()
	var p: PackedVector2Array = world.district.path(Vector2(9.0, 9.0), Vector2(9.0, 13.6))   # courtyard -> street, garage between
	check(p.size() > 2, "a route exists")
	for q in p:
		check(world.district.tile(Vector2i(q.floor())) != District.T.BUILDING, "route avoids buildings at %s" % q)
	var into: PackedVector2Array = world.district.path(Vector2(9.0, 9.0), Vector2(8.5, 11.0))
	check(into.is_empty() or world.district.tile(Vector2i(into[into.size() - 1].floor())) != District.T.BUILDING, "a route never ends inside a building")
	await _done()

func _spawn_patrol(at: Vector2, goal: Vector2) -> PoliceUnit:
	var c: Node = world.conflict
	GameState.wanted.level = 1
	c.police = PoliceUnit.new()
	c.police.director = c
	c.police.district = world.district
	c.police.rammed.connect(c._on_police_rammed)
	c.police.position = Iso.to_screen(at)
	c.police.goal = Iso.to_screen(goal)
	world.district.entities.add_child(c.police)
	return c.police

func test_patrol_routes_round_the_block() -> void:
	await _boot()
	# From the south street to the north street: the block (and a one-tile alley a car cannot use) is in between.
	world.player.position = Iso.to_screen(Vector2(1.5, 20.0))
	var goal := Vector2(11.5, 5.0)
	var pol := _spawn_patrol(Vector2(11.5, 15.0), goal)
	var guard := 0
	while guard < 1500 and is_instance_valid(pol) and pol.grid_pos().distance_to(goal) > 1.2:
		guard += 1
		world.conflict.unseen_t = 0.0   # keep the call active: this test is about routing, not losing them
		await frames(1)
	check(is_instance_valid(pol), "patrol still on the job")
	if not is_instance_valid(pol):
		await _done()
		return
	check(pol.grid_pos().distance_to(goal) <= 1.2, "patrol drove round the block (at %s after %d frames)" % [pol.grid_pos(), guard])

func test_car_route_avoids_alley_and_stops_short_of_courtyard() -> void:
	await _boot()
	var p: PackedVector2Array = world.district.path(Vector2(11.5, 15.0), Vector2(11.5, 9.0), true)
	check(not p.is_empty(), "some route")
	for q in p:
		check(not Rect2(11, 10, 1, 3).has_point(q), "no car through the alley (%s)" % q)
	check(p[p.size() - 1].distance_to(Vector2(11.5, 9.0)) > 0.5, "the courtyard is out of reach for a car")
	await _done()

func test_ramming_the_patrol_raises_wanted() -> void:
	await _boot()
	GameState.add_item("car_keys_monarch", 1)
	var car: Vehicle = world.vehicles.monarch_marco
	world.player.position = car.position + Vector2(0, 45)
	await frames(4)
	world.interact()
	eq(String(GameState.location.in_vehicle), "monarch_marco")
	var ahead: Vector2 = car.grid_pos() + car.forward() * 3.0
	var pol := _spawn_patrol(ahead, ahead)
	InputRouter.bot_active = true
	InputRouter.bot_vec = Iso.to_screen(car.forward()).normalized()
	await frames(120)
	InputRouter.reset()
	check(int(GameState.wanted.level) >= 2, "wanted rose after ramming (level %d)" % int(GameState.wanted.level))
	await _done()

func test_boxed_in_car_is_arrested_with_fine() -> void:
	await _boot()
	GameState.add_item("car_keys_monarch", 1)
	var car: Vehicle = world.vehicles.monarch_marco
	world.player.position = car.position + Vector2(0, 45)
	await frames(4)
	world.interact()
	var pol := _spawn_patrol(car.grid_pos() + Vector2(0, -1.2), car.grid_pos())
	var cash := GameState.ledger.balance
	await frames(240)   # standing still next to the patrol for 4 s
	eq(int(GameState.wanted.level), 0, "arrested: chase over")
	eq(cash - GameState.ledger.balance, 1000, "$10 fine")
	check(GameState.memory.knows("kowalski", "enzo_detained"), "the detective hears of it")
	await _done()
