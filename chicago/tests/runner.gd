extends Node
## Headless test runner: `godot --headless --path chicago res://tests/runner.tscn [-- --only=<file part>]`.
## Runs every res://tests/test_*.gd, prints OK/FAIL per test and a summary, exits 1 on any failure.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	Loc.load_all()
	Settings.use_path("user://test_settings.cfg")
	Settings.load_and_apply()
	SaveService.base_dir = "user://test_saves/"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd" and (only == "" or f.contains(only)):
			files.append(f)
	files.sort()
	var passed := 0
	var failed := 0
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null:
			print("FAIL %s: cannot load" % f)
			failed += 1
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var n := String(m.name)
			if n.begins_with("test_") and not n in methods:
				methods.append(n)
		for m in methods:
			_reset()
			var t: TestCase = script.new()
			t.tree = get_tree()
			t.current = f.get_basename() + "." + m
			t.before_each()
			await t.call(m)
			if t.failures.is_empty():
				passed += 1
				print("OK   ", t.current)
			else:
				failed += 1
				for x in t.failures:
					print("FAIL ", x)
			_cleanup()
	print("TESTS: PASS %d FAIL %d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func _reset() -> void:
	get_tree().paused = false
	WorldClock.running = false
	WorldClock.scale = 1.0
	InputRouter.reset()
	GameState.new_game()
	for slot in ["t1", "autosave", "slot1"]:
		SaveService.delete_slot(slot)
	SaveService.transition_lock = false
	Settings.ui_scale = 1.0
	Settings.aim_assist = true
	Settings.touch_mode = "auto"
	Settings.reset_keys()
	ArtRegistry.use_manifest("res://art/manifest.json")

func _cleanup() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
