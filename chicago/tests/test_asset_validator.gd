extends TestCase
## The art-package validator accepts a correct package and reports every problem of a broken one.

func _frame(size: Vector2i, feet_y: int, magenta := false, fill_bg := false) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.3, 0.2, 1) if fill_bg else Color(0, 0, 0, 0))
	for y in range(20, feet_y + 1):
		for x in range(36, 60):
			img.set_pixel(x, y, Color(1, 0, 1, 1) if magenta else Color(0.4, 0.3, 0.2, 1))
	return img

func _write_pkg(dir: String, manifest: Dictionary, images: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for rel in images:
		DirAccess.make_dir_recursive_absolute(dir.path_join(String(rel).get_base_dir()))
		(images[rel] as Image).save_png(dir.path_join(rel))
	var f := FileAccess.open(dir.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest))
	f.close()

func _char(id: String) -> Dictionary:
	return {"id": id, "type": "character", "license": "generated for this project", "origin": "test", "version": 1,
		"frame_size": [96, 128], "pivot": [48, 124], "directions": ["S", "N"], "states": {"idle": {"frames": 2}},
		"files": "assets/characters/%s_{state}_{dir}_{nn}.png" % id}

func test_valid_package_passes() -> void:
	var dir := ProjectSettings.globalize_path("user://test_pkg_ok")
	var imgs := {}
	for d in ["S", "N"]:
		for i in 2:
			imgs["assets/characters/char_test_idle_%s_%02d.png" % [d, i]] = _frame(Vector2i(96, 128), 124)
	var tile := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	tile.fill(Color(0, 0, 0, 0))
	tile.fill_rect(Rect2i(40, 20, 48, 24), Color(0.3, 0.3, 0.3, 1))
	imgs["assets/ground/tile_road_01.png"] = tile
	_write_pkg(dir, {"package": "t", "version": 1, "assets": [_char("char_test"),
		{"id": "tile_road", "type": "tile", "license": "generated", "origin": "test", "version": 1, "variants": ["assets/ground/tile_road_01.png"]}]}, imgs)
	var errs := AssetValidator.validate_package(dir)
	eq(errs.size(), 0, "valid package: %s" % "; ".join(errs))

func test_broken_package_reports_each_problem() -> void:
	var dir := ProjectSettings.globalize_path("user://test_pkg_bad")
	var imgs := {}
	imgs["assets/characters/char_bad_idle_S_00.png"] = _frame(Vector2i(96, 128), 110)            # feet 14 px above pivot
	imgs["assets/characters/char_bad_idle_S_01.png"] = _frame(Vector2i(100, 128), 124)           # wrong size
	imgs["assets/characters/char_bad_idle_N_00.png"] = _frame(Vector2i(96, 128), 124, true)      # magenta
	imgs["assets/characters/char_bad_idle_N_01.png"] = _frame(Vector2i(96, 128), 124, false, true) # filled background
	var a := _char("char_bad")
	a.erase("license")
	var dup := _char("char_bad")
	dup["files"] = "assets/characters/missing_{state}_{dir}_{nn}.png"
	_write_pkg(dir, {"package": "t", "version": 1, "assets": [a, dup, {"id": "Bad-ID", "type": "character", "license": "x", "origin": "x", "version": 1}]}, imgs)
	var errs := AssetValidator.validate_package(dir)
	var all := "\n".join(errs)
	for expect in ["'license' missing", "feet must stand on the pivot", "frame_size", "magenta", "not transparent",
			"duplicate id", "file missing", "id must match"]:
		check(all.contains(expect), "reports: %s\n%s" % [expect, all])
