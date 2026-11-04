extends TestCase
## Regression tests for the issues found in the code review (see CHANGELOG 0.1.1).

var world: Node

func _boot() -> void:
	world = load("res://world/world.tscn").instantiate()
	world.no_autosave = true
	tree.current_scene.add_child(world)
	await frames(3)

func _done() -> void:
	InputRouter.reset()
	if is_instance_valid(world):
		world.queue_free()
	await frames(2)

func test_data_lint_clean() -> void:
	var problems := DataLint.run()
	eq(problems.size(), 0, "data problems: %s" % "; ".join(problems))

func test_paying_the_bill_early_does_not_softlock() -> void:
	GameState.businesses.acquire("bellini_garage")
	GameState.quests.states["ch1_homecoming"] = {"state": "completed", "obj": {}, "started_min": 0}
	GameState.quests.start("ch1_shop_debt")
	GameState.set_flag("debt_known", true)
	WorldClock.set_total(9 * 60)
	GameState.businesses.record_job("bellini_garage", "j1")
	GameState.pay(1000, "test:cash", "test")
	GameState.pay_debt("lakeside_parts", 2000, "debt:early")   # paid before the 2nd repair
	eq(GameState.total_debt(), 0)
	GameState.businesses.record_job("bellini_garage", "j2")
	check(GameState.quests.objective_done("ch1_shop_debt", "pay_parts"), "the early payment counts once its turn comes")

func test_partial_payment_is_not_paid() -> void:
	GameState.quests.states["ch1_homecoming"] = {"state": "completed", "obj": {}, "started_min": 0}
	GameState.quests.start("ch1_shop_debt")
	GameState.set_flag("debt_known", true)
	GameState.quests.states["ch1_shop_debt"].obj["two_jobs"] = 2
	GameState.pay_debt("lakeside_parts", 500, "debt:part")
	check(not GameState.quests.objective_done("ch1_shop_debt", "pay_parts"), "partial payment does not complete it")

func test_save_mid_chase_then_load_can_finish_ambush() -> void:
	GameState.quests.states["ch1_ambush"] = {"state": "active", "obj": {"survive": 1}, "started_min": 0}
	GameState.add_item("ledger_book", 1)
	GameState.set_flag("wanted_clear", false)
	GameState.wanted.level = 2
	eq(SaveService.save("t1"), OK)
	GameState.new_game()
	eq(SaveService.load_slot("t1"), OK)
	EventBus.emit_event("loaded", {})
	eq(GameState.quests.state("ch1_ambush"), "completed", "lose_police completes after a load (chase not resumed)")

func test_missing_dialogue_does_not_freeze_player() -> void:
	await _boot()
	var n := NPC.new()
	n.setup("ghost", {"dialogue": [{"if": {}, "dialogue": "no_such_dialogue"}]})
	world.district.entities.add_child(n)
	world._talk(n)
	check(world.player.controls_enabled, "controls still enabled")
	await _done()

func test_wrecked_story_car_is_towed_and_fixed() -> void:
	await _boot()
	var car: Vehicle = world.vehicles.monarch_marco
	car.position = Iso.to_screen(Vector2(22.5, 20.0))
	car.damage = 100
	car.fuel = 0
	GameState.pay(5000, "test:cash", "test")
	var cash := GameState.ledger.balance
	var bay: Node = null
	for it in world.district.interactables:
		if it.id == "repair_bay":
			bay = it
	world._use(bay)
	check(car.grid_pos().distance_to(Vector2(10.5, 14.6)) < 2.5, "towed to the bay (at %s)" % car.grid_pos())
	eq(car.damage, 0, "repaired")
	eq(car.fuel, 100, "refuelled")
	eq(cash - GameState.ledger.balance, 100 * 15 + 100 * 2, "repair + fuel paid once")
	await _done()

func test_player_cannot_walk_through_parked_car() -> void:
	await _boot()
	var car: Vehicle = world.vehicles.monarch_marco
	world.player.position = car.position + Iso.to_screen(Vector2(0, -1.2))
	await frames(3)
	InputRouter.bot_active = true
	InputRouter.bot_vec = Iso.to_screen(Vector2(0, 1)).normalized()   # straight at the car's side
	await frames(120)
	InputRouter.reset()
	check(not Geometry2D.is_point_in_polygon(world.player.grid_pos(), car.footprint()), "feet outside the car")
	await _done()

func test_ledger_folding_is_bounded() -> void:
	var l := Ledger.new()
	for i in 2600:
		l.post("x%d" % i, 1, "r")
	check(l.entries.size() <= Ledger.MAX_ENTRIES + 1, "entries bounded (%d)" % l.entries.size())
	check(l.is_consistent(), "still consistent")
	check(not l.post("x5", 1, "r"), "folded ids still refused")

func test_no_walkin_income_on_sunday() -> void:
	GameState.businesses.acquire("bellini_garage")
	WorldClock.set_total(6 * 24 * 60 + 9 * 60)   # day 7 = Sunday
	var b := GameState.ledger.balance
	GameState.businesses.settle_day(7)
	eq(GameState.ledger.balance - b, -200, "Sunday: running cost only")

func test_corrupt_main_does_not_replace_good_backup() -> void:
	GameState.set_flag("marker", 1)
	SaveService.save("t1")
	SaveService.save("t1")            # now .bak is a good copy too
	var f := FileAccess.open(SaveService.path("t1"), FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	GameState.set_flag("marker", 2)
	SaveService.save("t1")            # must not rotate the garbage into .bak
	var bak := SaveService._parse(FileAccess.get_file_as_string(SaveService.path("t1", "bak")))
	check(not bak.is_empty(), "backup still a valid save")

func test_continue_picks_newest_slot() -> void:
	SaveService.save("autosave")
	await tree.create_timer(1.1).timeout
	SaveService.save("slot1")
	eq(SaveService.newest_slot(), "slot1")

func test_shop_is_acquired_in_the_story_once() -> void:
	check(not GameState.businesses.is_owned("bellini_garage"), "not owned at the start")
	GameState.quests.states["ch1_homecoming"] = {"state": "completed", "obj": {}, "started_min": 0}
	GameState.quests.start("ch1_shop_debt")
	GameState.apply_effects(DataRegistry.dialogue("salvatore_debt").nodes.d.effects, "dlg:salvatore_debt:d")
	check(GameState.businesses.is_owned("bellini_garage"), "owned after the talk")
	var n := GameState.ledger.entries.size()
	GameState.apply_effects(DataRegistry.dialogue("salvatore_debt").nodes.d.effects, "dlg:salvatore_debt:d")
	eq(GameState.ledger.entries.size(), n, "talking again acquires nothing")

func test_factions_saved() -> void:
	GameState.apply_effects([{"faction": {"id": "valenti_family", "axis": "suspicion", "delta": 30}}], "t:f")
	SaveService.save("t1")
	GameState.new_game()
	SaveService.load_slot("t1")
	eq(int(GameState.factions.valenti_family.suspicion), 30)

## Headless has no real window (size 0), so events are pushed in viewport coordinates (push_input(e, true)).
func test_touch_buttons_by_index_and_no_ghost_attack() -> void:
	await _boot()
	var tc: TouchControls = world.hud.touch
	tc.visible = true
	tc.layout()
	var acts := [0]
	var atks := [0]
	tc.action_pressed.connect(func(): acts[0] += 1)
	world.hud.attack_pressed.connect(func(): atks[0] += 1)
	var stick := InputEventScreenTouch.new()
	stick.index = 0
	stick.pressed = true
	stick.position = Vector2(200, 500)
	world.get_viewport().push_input(stick, true)
	var ghost := InputEventMouseButton.new()   # what Android emulates for that touch
	ghost.device = InputEvent.DEVICE_ID_EMULATION
	ghost.button_index = MOUSE_BUTTON_LEFT
	ghost.pressed = true
	ghost.position = Vector2(200, 500)
	world.get_viewport().push_input(ghost, true)
	await frames(2)
	check(tc.joy_index == 0, "stick held by finger 0")
	eq(atks[0], 0, "a stick touch is not an attack")
	var btn := InputEventScreenTouch.new()
	btn.index = 1
	btn.pressed = true
	btn.position = tc.act_btn.position + tc.act_btn.size / 2.0
	world.get_viewport().push_input(btn, true)
	await frames(2)
	eq(acts[0], 1, "second finger pressed the action button once")
	check(tc.joy_index == 0, "and did not steal the stick")
	await _done()

func test_one_tap_one_dialogue_line() -> void:
	await _boot()
	var box: DialogueBox = world.hud.dialogue
	box.open("salvatore_homecoming", "salvatore")
	await frames(2)
	var tap := InputEventMouseButton.new()
	tap.device = InputEvent.DEVICE_ID_EMULATION
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = box.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = tap.position
	world.get_viewport().push_input(touch, true)
	world.get_viewport().push_input(tap, true)
	await frames(2)
	eq(box.node_id, "b", "advanced exactly one line")
	box.close()
	await _done()
