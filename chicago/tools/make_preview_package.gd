extends SceneTree
## Usage: godot --headless --path chicago -s res://tools/make_preview_package.gd, then run the game with
## `-- --art-manifest=user://preview_art/manifest.json` to see it. Never shipped (tools/ is excluded from exports).
## Dev only: a diagnostic char_enzo package (coloured silhouettes, arrow = facing) to check pivots in game.
func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("user://preview_pkg")
	DirAccess.make_dir_recursive_absolute(dir.path_join("assets/characters"))
	var dirs := ["N", "NE", "E", "SE", "S"]
	for st in ["idle", "walk"]:
		for d in dirs:
			for i in 2:
				var img := Image.create(96, 128, false, Image.FORMAT_RGBA8)
				img.fill(Color(0, 0, 0, 0))
				var lift := 3 if (st == "walk" and i == 1) else 0
				img.fill_rect(Rect2i(38, 40 - lift, 20, 85 + lift), Color(0.15, 0.55, 0.85, 1))   # body to row 124
				img.fill_rect(Rect2i(40, 18 - lift, 16, 20), Color(0.9, 0.75, 0.6, 1))           # head
				var v: Vector2 = {"N": Vector2(0, -1), "NE": Vector2(1, -0.5), "E": Vector2(1, 0), "SE": Vector2(1, 0.5), "S": Vector2(0, 1)}[d]
				for k in 12:
					var p := Vector2(48, 70) + v.normalized() * k
					img.fill_rect(Rect2i(int(p.x) - 1, int(p.y) - 1, 3, 3), Color(1, 0.9, 0.1, 1))
				img.save_png(dir.path_join("assets/characters/char_enzo_%s_%s_%02d.png" % [st, d, i]))
	var m := {"package": "preview", "version": 1, "assets": [{"id": "char_enzo", "type": "character",
		"license": "diagnostic placeholder, not game art", "origin": "make_preview.gd", "version": 1,
		"frame_size": [96, 128], "pivot": [48, 124], "directions": ["N", "NE", "E", "SE", "S", "SW", "W", "NW"],
		"mirror": {"SW": "SE", "W": "E", "NW": "NE"}, "states": {"idle": {"frames": 2, "fps": 4}, "walk": {"frames": 2, "fps": 8}},
		"files": "assets/characters/char_enzo_{state}_{dir}_{nn}.png"}]}
	var f := FileAccess.open(dir.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(m))
	f.close()
	var errs := ArtImporter.import_package(dir, "user://preview_art")
	print("import: ", errs)
	quit()
