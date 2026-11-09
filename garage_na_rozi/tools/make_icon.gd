extends SceneTree
## Renders the app icon in the game's painted style.
## Run with a renderer: xvfb-run godot --path . -s tools/make_icon.gd

const IconArt := preload("res://tools/icon_art.gd")


func _initialize() -> void:
	var jobs := [
		["res://icon.png", 512, "full"],
		["res://assets/icon/icon_192.png", 192, "full"],
		["res://assets/icon/adaptive_fg.png", 432, "fg"],
		["res://assets/icon/adaptive_bg.png", 432, "bg"],
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icon"))
	for j in jobs:
		var vp := SubViewport.new()
		vp.size = Vector2i(j[1], j[1])
		vp.transparent_bg = j[2] == "fg"
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var art: Node2D = IconArt.new()
		art.mode = j[2]
		art.scale = Vector2.ONE * (float(j[1]) / 512.0)
		vp.add_child(art)
		for i in 4:
			await process_frame
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(j[0]))
		print("saved ", j[0])
		vp.queue_free()
	quit()
