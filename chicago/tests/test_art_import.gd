extends TestCase
## Importing a validated art package makes the game use it instead of the placeholder.

func _frame() -> Image:
	var img := Image.create(96, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(36, 20, 24, 105), Color(0.4, 0.3, 0.2, 1))   # rows 20..124: feet on pivot y 124
	return img

func _package(dir: String, version: int, valid: bool = true) -> void:
	DirAccess.make_dir_recursive_absolute(dir.path_join("assets/characters"))
	for st in ["idle", "walk"]:
		for d in ["S", "E"]:
			for i in 2:
				_frame().save_png(dir.path_join("assets/characters/char_test_%s_%s_%02d.png" % [st, d, i]))
	var a := {"id": "char_test", "type": "character", "license": "generated for this project", "origin": "test", "version": version,
		"frame_size": [96, 128], "pivot": [48, 124], "directions": ["S", "E", "W"], "mirror": {"W": "E"},
		"states": {"idle": {"frames": 2, "fps": 6}, "walk": {"frames": 2, "fps": 12}},
		"files": "assets/characters/char_test_{state}_{dir}_{nn}.png"}
	if not valid:
		a.erase("license")
	var f := FileAccess.open(dir.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"package": "test_pkg", "version": 1, "assets": [a]}))
	f.close()

func _clean(path: String) -> void:
	var abs := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs):
		_rm(abs)

func _rm(d: String) -> void:
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	for sub in DirAccess.get_directories_at(d):
		_rm(d.path_join(sub))
	DirAccess.remove_absolute(d)

func test_import_then_use_sprites() -> void:
	_clean("user://art_pkg")
	_clean("user://art_dest")
	var src := ProjectSettings.globalize_path("user://art_pkg")
	_package(src, 1)
	var errs := ArtImporter.import_package(src, "user://art_dest")
	eq(errs.size(), 0, "imported: %s" % "; ".join(errs))
	ArtRegistry.use_manifest("user://art_dest/manifest.json")
	check(ArtRegistry.has("char_test"), "listed in the manifest")
	var f := SpriteFigure.make("char_test", Color.RED)
	check(f is SpriteFigure, "sprite figure used once art exists")
	check(not (SpriteFigure.make("char_nobody", Color.RED) is SpriteFigure), "placeholder kept for characters without art")
	eq(ArtRegistry.pick("char_test", "walk", "E"), ["walk_E", false])
	eq(ArtRegistry.pick("char_test", "walk", "W"), ["walk_E", true], "W drawn by mirroring E")
	check(ArtRegistry.pick("char_test", "idle", "SE")[0] in ["idle_E", "idle_S"], "a neighbouring drawn direction for SE")
	eq(ArtRegistry.pick("char_test", "idle", "N")[0] in ["idle_E", "idle_S", "idle_W"], true, "some drawn direction for N")
	eq(ArtRegistry.character_frames("char_test").get_frame_count("walk_S"), 2)
	f.free()

func test_invalid_package_imports_nothing() -> void:
	_clean("user://art_pkg_bad")
	_clean("user://art_dest_bad")
	var src := ProjectSettings.globalize_path("user://art_pkg_bad")
	_package(src, 1, false)
	var errs := ArtImporter.import_package(src, "user://art_dest_bad")
	check(not errs.is_empty() and errs[0].contains("nothing imported"), "refused")
	check(not FileAccess.file_exists("user://art_dest_bad/manifest.json"), "no manifest written")

func test_no_downgrade() -> void:
	_clean("user://art_pkg2")
	_clean("user://art_dest2")
	var src := ProjectSettings.globalize_path("user://art_pkg2")
	_package(src, 2)
	eq(ArtImporter.import_package(src, "user://art_dest2").size(), 0)
	_package(src, 1)
	var errs := ArtImporter.import_package(src, "user://art_dest2")
	check(errs.size() == 1 and errs[0].contains("not newer"), "older version skipped: %s" % "; ".join(errs))
