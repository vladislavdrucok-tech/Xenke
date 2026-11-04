extends TestCase

func _keys(action: String) -> Array[int]:
	var out: Array[int] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append((e as InputEventKey).physical_keycode)
	return out

func test_rebind_persists_and_resets() -> void:
	check(KEY_E in _keys("interact"), "default E")
	Settings.rebind("interact", KEY_Q)
	eq(_keys("interact"), [KEY_Q] as Array[int], "only Q now")
	# Simulate a restart: forget in-memory state, load from file.
	Settings.keys = {}
	Settings.apply_keys()
	check(KEY_E in _keys("interact"), "defaults back in memory")
	Settings.load_and_apply()
	eq(_keys("interact"), [KEY_Q] as Array[int], "remap loaded from settings.cfg")
	Settings.reset_keys()
	check(KEY_E in _keys("interact"), "reset restores E")

func test_rebind_takes_key_from_other_action() -> void:
	Settings.rebind("vehicle", KEY_E)        # E was interact's default
	check(not KEY_E in _keys("interact"), "E no longer triggers interact")
	eq(_keys("vehicle"), [KEY_E] as Array[int])
	Settings.rebind("interact", KEY_G)
	check(KEY_G in _keys("interact"), "interact can be given a new key")

func test_arrows_kept_when_wasd_remapped() -> void:
	Settings.rebind("move_up", KEY_I)
	eq(_keys("move_up"), [KEY_I] as Array[int], "keyboard keys of the action replaced")

func test_ui_scale_keeps_panels_on_screen() -> void:
	var w = load("res://world/world.tscn").instantiate()
	w.no_autosave = true
	tree.current_scene.add_child(w)
	await frames(3)
	Settings.ui_scale = 1.5
	w.hud.apply_ui_scale()
	await frames(2)
	var vs: Vector2 = w.get_viewport().get_visible_rect().size
	near(w.hud.root.size.x * 1.5, vs.x, 1.0, "root covers the view after scaling")
	var tc: TouchControls = w.hud.touch
	tc.visible = true
	tc.layout()
	check((tc.act_btn.position.x + tc.act_btn.size.x) * 1.5 <= vs.x + 1.0, "action button inside the screen")
	Settings.ui_scale = 1.0
	w.hud.apply_ui_scale()
	w.queue_free()
	await frames(2)
