extends TestCase
## Combat, police and the chapter's decision on the real world scene.

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

func _start_ambush() -> void:
	WorldClock.set_total(21 * 60)
	world.player.position = Iso.to_screen(Vector2(20.6, 18.5))
	await frames(2)
	GameState.quests.start("ch1_ambush")
	await frames(2)

func test_ambush_spawns_and_arms_enzo() -> void:
	await _boot()
	await _start_ambush()
	eq(world.conflict.hostiles.size(), 2, "two gunmen")
	eq(world.conflict.weapon, "m1911", "pistol from the glovebox")
	eq(world.conflict.mag, 7)
	eq(GameState.item_count("pistol_ammo"), 14, "spare ammo")
	check(world.conflict.is_unsafe_to_save(), "no autosave mid-fight")
	await _done()

func test_enemy_telegraphs_before_first_hit() -> void:
	await _boot()
	await _start_ambush()
	# Alert (0.7 s) + aim (0.75 s) must pass before any damage: 80 physics frames = 1.33 s.
	await frames(80)
	eq(world.player.hp, 100, "no damage before the telegraph ends")
	await _done()

func test_fight_to_ledger_with_reload() -> void:
	await _boot()
	await _start_ambush()
	InputRouter.bot_active = true   # aim assist targets the nearest visible enemy
	var guard := 0
	var reloaded := false
	world.conflict._crime("shots_fired_street", world.player.position, 900.0)   # the fight starts: they hear it
	while guard < 2400 and GameState.quests.objective_done("ch1_ambush", "survive") == false:
		guard += 1
		if world.conflict.mag == 0 and world.conflict.reload_t <= 0.0:
			reloaded = true
		var any_visible := false
		for h in world.conflict.hostiles:
			if is_instance_valid(h) and h.alive() and world.conflict.can_see(world.player, h):
				any_visible = true
		if any_visible:
			world.conflict.player_attack()
		world.player.hp = 100   # this test checks our weapons, not survival
		await frames(1)
	var dbg := ""
	for h in world.conflict.hostiles:
		if is_instance_valid(h):
			dbg += "[%s hp%d st%d see%s d%.0f] " % [Iso.to_grid(h.position), h.hp, h.state, world.conflict.can_see(world.player, h), Player.ground_dist(h.position, world.player.position)]
	check(GameState.quests.objective_done("ch1_ambush", "survive"), "gunmen dealt with (%d frames) mag %d res %d %s" % [guard, world.conflict.mag, world.conflict._reserve(), dbg])
	check(reloaded, "had to reload at least once")
	var pick: Node = null
	for it in world.district.interactables:
		if it.id == "ledger_pickup":
			pick = it
	check(pick != null, "the ledger dropped")
	if pick:
		world.player.position = pick.position + Vector2(0, 20)
		await frames(6)
		world.interact()
		eq(GameState.item_count("ledger_book"), 1, "ledger taken")
		world.interact()
		eq(GameState.item_count("ledger_book"), 1, "only once")
	check(GameState.quests.objective_done("ch1_ambush", "take_ledger"), "objective take_ledger")
	await _done()

func test_shots_heard_bring_police_from_the_edge_and_hiding_loses_them() -> void:
	await _boot()
	WorldClock.set_total(12 * 60)
	world.conflict.weapon = "m1911"
	world.conflict.mag = 3
	InputRouter.bot_active = true
	world.player.position = Iso.to_screen(Vector2(9.5, 13.6))
	await frames(3)
	world.conflict.player_attack()
	check(world.conflict.dispatch_at > 0, "someone heard and called")
	eq(int(GameState.wanted.level), 1)
	check(world.conflict.police == null, "no patrol yet (dispatch delay)")
	WorldClock.advance(16)
	await frames(2)
	check(world.conflict.police != null, "patrol arrived")
	if world.conflict.police:
		check(Player.ground_dist(world.conflict.police.position, world.player.position) > 600.0, "it came from the district edge, not out of thin air")
	# Hide in the garage: the search fails a few minutes later.
	world.load_district("garage_interior", "from_street")
	await frames(2)
	WorldClock.advance(6)
	await frames(2)
	eq(int(GameState.wanted.level), 0, "lost the police indoors")
	eq(GameState.get_flag("wanted_clear"), true)
	await _done()

func test_cover_reduces_enemy_accuracy() -> void:
	await _boot()
	await _start_ambush()
	var crate := Iso.to_screen(Vector2(22.6, 20.8))
	world.player.position = crate + Iso.to_screen(Vector2(-0.4, 0))   # crate between Enzo and the east
	var shooter := crate + Iso.to_screen(Vector2(4, 0))
	near(world.conflict.player_cover_factor(shooter), 0.25, 0.001, "covered from the far side")
	near(world.conflict.player_cover_factor(world.player.position + Iso.to_screen(Vector2(-4, 0))), 1.0, 0.001, "exposed from behind")
	await _done()

func test_neighbours_hear_and_rosa_reacts_next_day() -> void:
	await _boot()
	WorldClock.set_total(12 * 60)
	world.conflict.weapon = "m1911"
	world.conflict.mag = 1
	InputRouter.bot_active = true
	world.player.position = Iso.to_screen(Vector2(9.5, 13.6))
	await frames(3)
	world.conflict.player_attack()
	check(not GameState.memory.knows("rosa", "shots_fired_street"), "Rosa is inside and did not see it")
	WorldClock.advance(24 * 60)
	check(GameState.memory.knows("rosa", "shots_fired_street"), "next day the neighbours told her")
	eq(GameState.memory.recall("rosa", "shots_fired_street").how, "told")
	await _done()

func test_ledger_choice_persists_and_changes_father() -> void:
	await _boot()
	for q in ["ch1_homecoming", "ch1_shop_debt", "ch1_first_job", "ch1_ambush"]:
		GameState.quests.states[q] = {"state": "completed", "obj": {}, "started_min": 0}
	GameState.quests.start("ch1_the_ledger")
	GameState.add_item("ledger_book", 1)
	var cash := GameState.ledger.balance
	var box: DialogueBox = world.hud.dialogue
	box.open("marco_ledger", "marco")
	box.choose(0)        # give it to the Valenti family
	box.advance()
	eq(GameState.get_flag("ch1_path"), "loyal")
	eq(GameState.ledger.balance - cash, 5000, "paid $50")
	eq(GameState.quests.state("ch1_the_ledger"), "completed")
	eq(GameState.get_flag("chapter1_done"), true)
	# Talking again cannot repeat the deal (the ledger is gone, the choice is hidden) or pay twice.
	box.open("marco_ledger", "marco")
	eq(box.visible_choices(), [2] as Array[int], "only 'still thinking' remains")
	box.close()
	eq(GameState.ledger.balance - cash, 5000, "no second payment")
	# Save, load: the father now talks about it.
	world.sync_to_state()
	SaveService.save("t1")
	GameState.new_game()
	SaveService.load_slot("t1")
	var rule := ""
	for r in DataRegistry.get_def("npcs", "salvatore").dialogue:
		if Conditions.check(r.get("if", {}), GameState):
			rule = r.dialogue
			break
	eq(rule, "salvatore_after_loyal", "father's dialogue changed after reload")
	check(GameState.memory.knows("marco", "enzo_returned_ledger"), "Marco remembers")
	await _done()
