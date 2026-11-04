extends TestCase

var world: Node

func _boot(hour: int = 12) -> void:
	WorldClock.set_total(hour * 60)
	world = load("res://world/world.tscn").instantiate()
	world.no_autosave = true
	tree.current_scene.add_child(world)
	await frames(3)

func _done() -> void:
	InputRouter.reset()
	world.queue_free()
	await frames(2)

func _cars() -> Array:
	return world.get_tree().get_nodes_in_group("traffic").filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())

func test_traffic_drives_the_loop_and_less_at_night() -> void:
	await _boot(12)
	var cars := _cars()
	check(cars.size() >= 3, "day traffic (%d cars)" % cars.size())
	var starts := []
	for c in cars:
		starts.append(c.grid_pos())
	await frames(240)
	var moved := 0
	for i in cars.size():
		if cars[i].grid_pos().distance_to(starts[i]) > 2.0:
			moved += 1
		var r: int = world.district.tile(Vector2i(cars[i].grid_pos().floor()))
		check(r == District.T.ROAD, "car %d stays on the road (tile %d at %s)" % [i, r, cars[i].grid_pos()])
	check(moved >= cars.size() - 1, "cars drive (%d of %d moved)" % [moved, cars.size()])
	await _done()
	await _boot(23)
	check(_cars().size() <= 2, "fewer cars at night")
	await _done()

func test_traffic_stops_for_enzo_on_the_road() -> void:
	await _boot(12)
	var cars := _cars()
	check(not cars.is_empty(), "has traffic")
	if cars.is_empty():
		await _done()
		return
	var car: TrafficCar = cars[0]
	await frames(30)
	# Stand in its lane 1.5 tiles ahead.
	var ahead: Vector2 = car.grid_pos() + car.forward() * 1.9
	world.player.position = Iso.to_screen(ahead)
	await frames(90)
	near(car.speed, 0.0, 0.05, "stopped in front of Enzo")
	check(car.grid_pos().distance_to(Iso.to_grid(world.player.position)) > 0.8, "did not drive into him")
	# Step aside: it drives on.
	world.player.position = Iso.to_screen(Vector2(9.0, 13.5))
	await frames(90)
	check(car.speed > 0.5, "drives on once the lane is clear")
	await _done()

func test_traffic_not_saved() -> void:
	await _boot(12)
	world.sync_to_state()
	for k in GameState.vehicles:
		check(not String(k).begins_with("traffic"), "traffic is not in the save")
	await _done()
