extends TestCase
## Chapter 1 from the first step to the decision, through the real scene: doors, dialogues, the workbench, paying the
## bill, Marco, driving the car to the rail yard (really steered), the ambush, the ledger, the police, the choice,
## and the father's changed words after a save/load. Interactions go through world.interact(); walking between
## places is done by placing Enzo (walking itself is covered by test_world).

var world: Node
var log_lines: Array[String] = []

func _boot() -> void:
	world = load("res://world/world.tscn").instantiate()
	world.no_autosave = true
	tree.current_scene.add_child(world)
	await frames(3)

func _it(id: String) -> Node:
	for n in world.district.interactables:
		if is_instance_valid(n) and n.id == id:
			return n
	return null

func _stand_at(p: Vector2) -> void:
	world.player.position = p
	world.player.velocity = Vector2.ZERO
	await frames(6)

func _use(id: String) -> void:
	var it := _it(id)
	check(it != null, "interactable %s exists in %s" % [id, world.district.id])
	if it == null:
		return
	await _stand_at(it.position + Vector2(0, 24))
	world.interact()
	await frames(4)

## Talks to an NPC and answers with the given choice indices (in order); other lines are clicked through.
func _talk(npc: String, answers: Array = []) -> String:
	check(world.npcs.has(npc), "%s is here (%s, %s)" % [npc, world.district.id, WorldClock.clock_text()])
	if not world.npcs.has(npc):
		return ""
	await _stand_at(world.npcs[npc].position + Vector2(-36, 14))
	world.interact()
	var box: DialogueBox = world.hud.dialogue
	check(box.is_open(), "dialogue with %s opened" % npc)
	var id := box.dialogue_id
	var guard := 0
	while box.is_open() and guard < 30:
		guard += 1
		var vis: Array[int] = box.visible_choices()
		if vis.is_empty():
			box.advance()
		else:
			var pick: int = answers.pop_front() if not answers.is_empty() else vis[0]
			box.choose(pick)
	log_lines.append("talked %s: %s" % [npc, id])
	return id

func _door(id: String, expect: String) -> void:
	await _use(id)
	await frames(3)
	eq(world.district.id, expect, "through %s" % id)

## Steers the car by the stick towards a grid point, like a player on a phone.
func _drive_to(goal: Vector2, max_frames: int = 900) -> bool:
	var car: Vehicle = world._driving()
	InputRouter.bot_active = true
	for i in max_frames:
		var to := goal - car.grid_pos()
		if to.length() < 0.8:
			InputRouter.bot_vec = Vector2.ZERO
			await frames(30)
			InputRouter.bot_active = false
			return true
		var s := Iso.to_screen(to.normalized())
		InputRouter.bot_vec = s.normalized() * (0.55 if to.length() < 2.5 else 0.9)
		await frames(1)
	InputRouter.bot_active = false
	return false

func test_chapter_one_start_to_finish() -> void:
	await _boot()
	# Beat 1 - homecoming.
	eq(world.district.id, "santa_lucia")
	await _door("garage_door", "garage_interior")
	eq(await _talk("salvatore", [0]), "salvatore_homecoming")
	eq(GameState.quests.state("ch1_homecoming"), "completed", "beat 1 done")
	# Beat 2 - the shop's debt: learn it, two repairs, pay the bill, meet Marco.
	eq(await _talk("salvatore", [0]), "salvatore_debt")
	check(GameState.quests.objective_done("ch1_shop_debt", "learn_debt"), "debt known")
	WorldClock.set_total(maxi(WorldClock.total_minutes, 8 * 60 + 5))
	await _use("workbench_job")
	await _use("workbench_job")
	check(GameState.quests.objective_done("ch1_shop_debt", "two_jobs"), "two repairs (cash %s)" % Ledger.dollars(GameState.ledger.balance))
	await _door("street_door", "santa_lucia")
	await _use("parts_counter")
	eq(GameState.total_debt(), 0, "bill paid")
	check(GameState.quests.objective_done("ch1_shop_debt", "pay_parts"), "objective pay_parts")
	WorldClock.set_total(maxi(WorldClock.total_minutes, 12 * 60))
	world._spawn_npcs(true)
	await frames(2)
	eq(await _talk("marco"), "marco_meet")
	eq(GameState.quests.state("ch1_shop_debt"), "completed", "beat 2 done")
	# Beat 3 - the first job: accept, take the car, drive it to the rail yard.
	eq(await _talk("marco", [0]), "marco_job")
	eq(GameState.item_count("car_keys_monarch"), 1, "keys")
	var car: Vehicle = world.vehicles.monarch_marco
	await _stand_at(car.position + Vector2(0, 45))
	world.interact()
	eq(String(GameState.location.in_vehicle), "monarch_marco", "driving")
	var cash_before := GameState.ledger.balance
	check(await _drive_to(Vector2(20.0, 14.9)), "drove along the street (at %s)" % car.grid_pos())
	check(await _drive_to(Vector2(22.0, 18.0)), "drove into the rail yard (at %s)" % car.grid_pos())
	await frames(15)
	eq(GameState.quests.state("ch1_first_job"), "completed", "beat 3 done")
	eq(GameState.ledger.balance - cash_before, 2500, "Marco paid $25")
	# Beat 4 - the ambush.
	eq(GameState.quests.state("ch1_ambush"), "active")
	check(world._exit_vehicle(), "got out of the car")
	await frames(4)
	world.conflict._crime("shots_fired_street", world.player.position, 900.0)
	InputRouter.bot_active = true
	var guard := 0
	while guard < 2400 and not GameState.quests.objective_done("ch1_ambush", "survive"):
		guard += 1
		for h in world.conflict.hostiles:
			if is_instance_valid(h) and h.alive() and world.conflict.can_see(world.player, h):
				world.conflict.player_attack()
				break
		if world.player.hp < 40:
			world.player.hp = 100   # the test checks progression, not aim; fairness has its own test
		await frames(1)
	InputRouter.bot_active = false
	check(GameState.quests.objective_done("ch1_ambush", "survive"), "survived")
	await _use("ledger_pickup")
	eq(GameState.item_count("ledger_book"), 1, "ledger")
	# Police may be on the way (shots were heard): hide in the garage until they give up.
	if GameState.get_flag("wanted_clear") != true:
		await _hide()
	eq(GameState.quests.state("ch1_ambush"), "completed", "beat 4 done")
	# Beat 5 - the decision: give the ledger to Marco for the Valenti family.
	if world.district.id != "santa_lucia":
		await _door("street_door", "santa_lucia")
	WorldClock.set_total(WorldClock.day() * 24 * 60 + 12 * 60)   # next day, noon: Marco on his corner
	world._spawn_npcs(true)
	await frames(2)
	eq(await _talk("marco", [0]), "marco_ledger")
	eq(GameState.get_flag("ch1_path"), "loyal")
	eq(GameState.quests.state("ch1_the_ledger"), "completed", "beat 5 done")
	eq(GameState.get_flag("chapter1_done"), true)
	# The decision persists and visibly alters the father's dialogue after save + load.
	world.sync_to_state()
	eq(SaveService.save("t1"), OK)
	world.queue_free()
	await frames(2)
	GameState.new_game()
	eq(SaveService.load_slot("t1"), OK)
	await _boot()
	await _door("garage_door", "garage_interior")
	eq(await _talk("salvatore"), "salvatore_after_loyal", "father reacts to the choice")
	check(GameState.relationships.get_value("salvatore", "trust") < 35, "and trusts Enzo less")
	check(GameState.ledger.is_consistent(), "ledger consistent at the end")
	print("     playthrough: ", ", ".join(log_lines), " | day %d %s | cash %s" % [WorldClock.day(), WorldClock.clock_text(), Ledger.dollars(GameState.ledger.balance)])
	InputRouter.reset()
	world.queue_free()
	await frames(2)

func _hide() -> void:
	await _stand_at(Iso.to_screen(Vector2(8.5, 13.6)))
	await _door("garage_door", "garage_interior")
	WorldClock.advance(20)
	await frames(3)
	eq(GameState.get_flag("wanted_clear"), true, "police lost while hiding")
