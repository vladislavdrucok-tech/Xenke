extends TestCase

func test_chapter1_starts_with_homecoming() -> void:
	eq(GameState.quests.state("ch1_homecoming"), "active")
	eq(GameState.quests.state("ch1_shop_debt"), "not_started")

func test_homecoming_ordered_objectives() -> void:
	# Talking to father before reaching the shop does not count (ordered).
	EventBus.emit_event("dialogue_done", {"dialogue": "salvatore_homecoming"})
	check(not GameState.quests.objective_done("ch1_homecoming", "talk_father"), "out of order ignored")
	EventBus.emit_event("entered_district", {"district": "garage_interior"})
	EventBus.emit_event("entered_district", {"district": "garage_interior"})
	EventBus.emit_event("dialogue_done", {"dialogue": "salvatore_homecoming"})
	eq(GameState.quests.state("ch1_homecoming"), "completed")
	eq(GameState.quests.state("ch1_shop_debt"), "active", "next beat started")
	eq(GameState.get_flag("home"), true)

func test_shop_debt_full_beat() -> void:
	GameState.quests.states["ch1_homecoming"] = {"state": "completed", "obj": {}, "started_min": 0}
	GameState.quests.start("ch1_shop_debt")
	GameState.set_flag("debt_known", true)
	EventBus.emit_event("inventory_changed", {})   # any event re-checks state objectives
	check(GameState.quests.objective_done("ch1_shop_debt", "learn_debt"), "learn_debt by flag")
	WorldClock.set_total(9 * 60)
	GameState.businesses.record_job("bellini_garage", "a")
	GameState.businesses.record_job("bellini_garage", "b")
	check(GameState.quests.objective_done("ch1_shop_debt", "two_jobs"), "two jobs counted")
	GameState.pay(20000, "test:gift", "test")
	GameState.pay_debt("lakeside_parts", 2000, "debt:x")
	check(GameState.quests.objective_done("ch1_shop_debt", "pay_parts"), "debt paid")
	EventBus.emit_event("dialogue_done", {"dialogue": "marco_meet"})
	eq(GameState.quests.state("ch1_shop_debt"), "completed")
	eq(GameState.quests.state("ch1_first_job"), "active")

func test_effects_apply_once() -> void:
	var before := GameState.relationships.get_value("marco", "trust")
	var eff := [{"rel": {"npc": "marco", "axis": "trust", "delta": 5}}, {"money": {"cents": 100, "reason": "t"}}]
	var cash := GameState.ledger.balance
	GameState.apply_effects(eff, "test:k")
	GameState.apply_effects(eff, "test:k")
	eq(GameState.relationships.get_value("marco", "trust"), before + 5, "rel once")
	eq(GameState.ledger.balance, cash + 100, "money once")

func test_conditions_table() -> void:
	GameState.set_flag("x", true)
	check(Conditions.check({}, GameState), "empty is true")
	check(Conditions.check({"flag": {"x": true}}, GameState), "flag")
	check(not Conditions.check({"flag": {"y": true}}, GameState), "missing flag")
	check(Conditions.check({"not_flag": ["y"]}, GameState), "not_flag")
	check(Conditions.check({"quest": {"ch1_homecoming": "active"}}, GameState), "quest state")
	check(Conditions.check({"money_gte": 1250}, GameState), "money_gte")
	check(not Conditions.check({"money_gte": 1251}, GameState), "money_gte fail")
	check(Conditions.check({"rel": [{"npc": "salvatore", "axis": "affection", "gte": 50}]}, GameState), "rel gte")
	check(Conditions.check({"any": [{"flag": {"y": true}}, {"flag": {"x": true}}]}, GameState), "any")
	check(not Conditions.check({"item": {"ledger_book": 1}}, GameState), "item")
	WorldClock.set_total(23 * 60)
	check(Conditions.check({"hour_between": [22, 6]}, GameState), "hour wrap")

func test_failed_quest_retry_checkpoint() -> void:
	GameState.quests.states["ch1_first_job"] = {"state": "active", "obj": {"accept": 1}, "started_min": 0}
	GameState.quests.fail("ch1_first_job")
	eq(GameState.quests.state("ch1_first_job"), "failed")
	GameState.quests.retry("ch1_first_job")
	eq(GameState.quests.state("ch1_first_job"), "active")
	check(GameState.quests.objective_done("ch1_first_job", "accept"), "checkpoint kept")

func test_memory_witness_and_decay() -> void:
	EventBus.emit_event("shots_fired_street", {"witnesses": ["rosa"], "importance": 2})
	check(GameState.memory.knows("rosa", "shots_fired_street"), "witness remembers")
	check(not GameState.memory.knows("salvatore", "shots_fired_street"), "non-witness does not")
	GameState.memory.decay(WorldClock.total_minutes + 15 * 24 * 60)
	check(not GameState.memory.knows("rosa", "shots_fired_street"), "importance 2 fades after 14 days")
	GameState.memory.remember("marco", "enzo_kept_ledger", 0, 3)
	GameState.memory.decay(999999)
	check(GameState.memory.knows("marco", "enzo_kept_ledger"), "major memories stay")

func test_schedule() -> void:
	WorldClock.set_total(8 * 60)
	eq(Schedule.where(DataRegistry.get_def("npcs", "salvatore"), GameState).district, "garage_interior")
	eq(Schedule.where(DataRegistry.get_def("npcs", "marco"), GameState).district, "")
	WorldClock.set_total(12 * 60)
	eq(Schedule.where(DataRegistry.get_def("npcs", "marco"), GameState).spot, "club_corner")
	WorldClock.set_total(20 * 60)
	eq(Schedule.where(DataRegistry.get_def("npcs", "salvatore"), GameState).district, "apartment_interior")
	eq(Schedule.where(DataRegistry.get_def("npcs", "marco"), GameState).spot, "corner_table")
	check(not Schedule.present_in("trattoria_interior", GameState).has("valenti"), "Valenti only after the ambush")
	GameState.set_flag("ambush_happened", true)
	check(Schedule.present_in("trattoria_interior", GameState).has("valenti"), "Valenti appears after the ambush")
