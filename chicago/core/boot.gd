extends Control
## Boot and main menu: loads localization, checks the data, then offers New game / Continue / Quit.
## Command line (after `--`): --newgame starts at once, --continue loads the autosave, --shots=<dir> runs the
## screenshot tour (tools/shot_tour.gd), --touch forces the touch UI.

const VERSION := "0.1.0-slice"

func _ready() -> void:
	Loc.load_all()
	WorldClock.running = false
	var args := OS.get_cmdline_user_args()
	if not DataRegistry.errors.is_empty():
		for e in DataRegistry.errors:
			push_error("DATA: " + e)
	if args.has("--newgame"):
		call_deferred("_new_game")
		return
	if args.has("--continue"):
		call_deferred("_continue")
		return
	for a in args:
		if a.begins_with("--shots="):
			var tour := preload("res://tools/shot_tour.gd").new()
			tour.out_dir = a.substr(8)
			get_tree().root.call_deferred("add_child", tour)
			return
	_build_menu()

func _build_menu() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1a1412")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var title := Label.new()
	title.text = "UI_TITLE"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#e7c27a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = "UI_SUBTITLE"
	sub.add_theme_font_size_override("font_size", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(Control.new())
	var cont := _button(v, "UI_CONTINUE", _continue)
	cont.disabled = not (SaveService.has_save("autosave") or SaveService.has_save("slot1"))
	_button(v, "UI_NEW_GAME", _new_game)
	_button(v, "UI_QUIT", func(): get_tree().quit())
	var ver := Label.new()
	ver.text = Loc.t("UI_VERSION", [VERSION]) + " · " + tr("UI_TEMP_ART")
	ver.add_theme_font_size_override("font_size", 14)
	ver.modulate = Color(1, 1, 1, 0.5)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)
	(cont if not cont.disabled else v.get_child(4)).call_deferred("grab_focus")

func _button(parent: Node, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(340, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file("res://world/world.tscn")

func _continue() -> void:
	var slot := "autosave"
	if SaveService.has_save("slot1") and not SaveService.has_save("autosave"):
		slot = "slot1"
	if SaveService.load_slot(slot) != OK:
		push_error("Continue failed: " + SaveService.last_error)
		GameState.new_game()
	get_tree().change_scene_to_file("res://world/world.tscn")
