extends Node
## Screenshot tour (run with a window, e.g. under xvfb-run): `godot --path chicago -- --shots=<dir>`.
## Starts a new game, walks the player through key places and saves PNGs, so visual changes can be reviewed
## without a device. Prints frame-time stats. Placeholder art is what it shows - not a final look.

var out_dir := "user://shots"
var world: Node

func _ready() -> void:
	call_deferred("_run")

func _shot(n: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	img.save_png(out_dir.path_join(n + ".png"))
	print("shot ", n)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _run() -> void:
	Loc.load_all()
	SaveService.base_dir = "user://shot_saves/"
	GameState.new_game()
	get_tree().change_scene_to_file("res://world/world.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	world = get_tree().current_scene
	world.no_autosave = true
	await _wait(0.6)
	await _shot("01_arrival")
	world.player.position = Iso.to_screen(Vector2(9.5, 13.6))
	await _wait(0.8)
	await _shot("02_garage_front")
	world.player.position = Iso.to_screen(Vector2(11.5, 9.6))
	await _wait(0.8)
	await _shot("03_behind_buildings_fade")
	world.load_district("garage_interior", "from_street")
	await _wait(0.8)
	await _shot("04_garage_interior")
	world.load_district("santa_lucia", "trattoria_front")
	WorldClock.set_total(21 * 60)
	world._update_light()
	await _wait(0.8)
	await _shot("05_night_street")
	WorldClock.set_total(16 * 60 + 30)
	await _wait(0.8)
	await _shot("06_rain")
	print("PERF street+rain: ", world.hud.perf_text())
	# Dialogue with the father (choices visible).
	world.load_district("garage_interior", "from_street")
	WorldClock.set_total(9 * 60)
	world._spawn_npcs(true)
	await _wait(0.4)
	world.hud.dialogue.open("salvatore_homecoming", "salvatore")
	world.hud.dialogue.advance()
	world.hud.dialogue.advance()
	await _wait(0.3)
	await _shot("07_dialogue_choices")
	world.hud.dialogue.close()
	# The rail-yard ambush at night with the touch UI.
	world.load_district("santa_lucia", "garage_front")
	WorldClock.set_total(21 * 60 + 30)
	world.hud.touch.visible = true
	world.hud.touch.layout()
	world.player.position = Iso.to_screen(Vector2(21.4, 18.6))
	await _wait(0.3)
	GameState.quests.start("ch1_ambush")
	world.conflict._crime("shots_fired_street", world.player.position, 900.0)
	await _wait(1.6)
	await _shot("08_ambush_telegraph_touch")
	print("PERF ambush: ", world.hud.perf_text())
	get_tree().quit()
