extends TestCase

func _mutate() -> void:
	GameState.set_flag("debt_known", true)
	GameState.pay(777, "test:m", "test")
	GameState.relationships.change("marco", "fear", 7)
	GameState.memory.remember("rosa", "e", 10, 2)
	GameState.add_item("spare_parts", 3)
	WorldClock.set_total(2 * 24 * 60 + 13 * 60 + 7)
	GameState.location = {"district": "garage_interior", "spawn": "from_street", "pos": [2.5, 4.25], "facing": "N", "in_vehicle": ""}

func test_roundtrip() -> void:
	_mutate()
	var before := JSON.stringify(GameState.to_dict(), "", true)
	eq(SaveService.save("t1"), OK, "save")
	GameState.new_game()
	eq(SaveService.load_slot("t1"), OK, "load")
	eq(JSON.stringify(GameState.to_dict(), "", true), before, "state identical after roundtrip")
	eq(WorldClock.clock_text(), "13:07")

func test_backup_used_when_main_corrupt() -> void:
	_mutate()
	SaveService.save("t1")
	GameState.pay(100, "test:second", "test")
	SaveService.save("t1")   # main = with $1 more, bak = first
	var f := FileAccess.open(SaveService.path("t1"), FileAccess.WRITE)
	f.store_string("{\"game\":\"chicago_bl\",\"save_version\":1,\"checksum\":\"00\"}\n{ truncated")
	f.close()
	GameState.new_game()
	eq(SaveService.load_slot("t1"), OK, "falls back")
	eq(SaveService.last_loaded_from, "backup")
	check(GameState.get_flag("debt_known") == true, "backup content")

func test_tmp_leftover_ignored_and_newer_version_refused() -> void:
	_mutate()
	SaveService.save("t1")
	var f := FileAccess.open(SaveService.path("t1", "tmp"), FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	eq(SaveService.load_slot("t1"), OK, "tmp ignored")
	var body := "{}"
	var g := FileAccess.open(SaveService.path("t1"), FileAccess.WRITE)
	g.store_string(JSON.stringify({"game": "chicago_bl", "save_version": 99, "checksum": SaveService.fnv1a(body)}) + "\n" + body)
	g.close()
	SaveService.delete_slot("t1")
	var h := FileAccess.open(SaveService.path("t1"), FileAccess.WRITE)
	h.store_string(JSON.stringify({"game": "chicago_bl", "save_version": 99, "checksum": SaveService.fnv1a(body)}) + "\n" + body)
	h.close()
	check(SaveService.load_slot("t1") != OK, "newer version refused")
	check(SaveService.last_error.contains("not supported"), "reason given: " + SaveService.last_error)

func test_v0_migration() -> void:
	var body := FileAccess.get_file_as_string("res://tests/fixtures/save_v0.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveService.base_dir))
	var f := FileAccess.open(SaveService.path("t1"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"game": "chicago_bl", "save_version": 0, "checksum": SaveService.fnv1a(body)}) + "\n" + body)
	f.close()
	eq(SaveService.load_slot("t1"), OK, "v0 loads: " + SaveService.last_error)
	eq(GameState.ledger.balance, 4250, "cash 42.5 dollars migrated to cents")
	check(GameState.ledger.is_consistent(), "ledger consistent")

func test_save_refused_during_transition() -> void:
	SaveService.transition_lock = true
	eq(SaveService.save("t1"), ERR_BUSY)
	SaveService.transition_lock = false
	check(not FileAccess.file_exists(SaveService.path("t1")), "nothing written")

func test_foreign_file_refused() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveService.base_dir))
	var f := FileAccess.open(SaveService.path("t1"), FileAccess.WRITE)
	f.store_string("{\"version\":1,\"inv\":{}}")   # an Afterfall-style save
	f.close()
	check(SaveService.load_slot("t1") != OK, "not our save")
