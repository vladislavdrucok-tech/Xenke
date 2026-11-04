class_name AssetValidator
extends RefCounted
## Validates an art package delivered for the game (docs/ASSET_MANIFEST_SCHEMA.md) BEFORE anything is imported.
## Fails loudly with every problem listed; never stretches, crops or "fixes" an image.
##
## Command line:  godot --headless --path chicago -s res://tools/validate_assets_cli.gd -- <package folder>
## From code:     AssetValidator.validate_package("/abs/path/to/package") -> Array[String] (empty = valid)

const ID_RE := "^[a-z]+(_[a-z0-9]+)+$"
const DIRS8 := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const MAGENTA := Color(1, 0, 1)

static func validate_package(dir: String) -> Array[String]:
	var errs: Array[String] = []
	var mpath := dir.path_join("manifest.json")
	if not FileAccess.file_exists(mpath):
		errs.append("manifest.json missing in " + dir)
		return errs
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(mpath)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		errs.append("manifest.json: invalid JSON (line %d: %s)" % [j.get_error_line(), j.get_error_message()])
		return errs
	var m: Dictionary = j.data
	for k in ["package", "version", "assets"]:
		if not m.has(k):
			errs.append("manifest: '%s' missing" % k)
	if typeof(m.get("assets")) != TYPE_ARRAY:
		return errs
	var re := RegEx.create_from_string(ID_RE)
	var seen := {}
	for a in m.assets:
		if typeof(a) != TYPE_DICTIONARY:
			errs.append("manifest: an asset entry is not an object")
			continue
		var id := String(a.get("id", ""))
		var where := "asset '%s'" % id
		if re.search(id) == null:
			errs.append("%s: id must match %s" % [where, ID_RE])
		if seen.has(id):
			errs.append("%s: duplicate id" % where)
		seen[id] = true
		for k in ["license", "origin", "version", "type"]:
			if not a.has(k) or str(a[k]).strip_edges() == "":
				errs.append("%s: '%s' missing (licensing / provenance must be documented)" % [where, k])
		match String(a.get("type", "")):
			"character":
				_character(dir, a, where, errs)
			"building", "prop":
				_building(dir, a, where, errs)
			"tile":
				_tile(dir, a, where, errs)
			"":
				pass
			_:
				errs.append("%s: unknown type '%s'" % [where, a.type])
	return errs

static func _load(dir: String, rel: String, where: String, errs: Array[String]) -> Image:
	var p := dir.path_join(rel)
	if not FileAccess.file_exists(p):
		errs.append("%s: file missing: %s" % [where, rel])
		return null
	if not rel.to_lower().ends_with(".png"):
		errs.append("%s: %s is not a PNG" % [where, rel])
		return null
	var img := Image.load_from_file(p)
	if img == null or img.is_empty():
		errs.append("%s: cannot read %s" % [where, rel])
		return null
	if not img.detect_alpha():
		errs.append("%s: %s has no transparency (real alpha required, no filled background)" % [where, rel])
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

## Corners must be transparent and no pixel may be the diagnostic magenta.
static func _clean(img: Image, rel: String, where: String, errs: Array[String]) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for c in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		if img.get_pixelv(c).a > 0.05:
			errs.append("%s: %s corner %s not transparent (background left in?)" % [where, rel, c])
			break
	var step := maxi(1, mini(w, h) / 64)
	for y in range(0, h, step):
		for x in range(0, w, step):
			var px := img.get_pixel(x, y)
			if px.a > 0.5 and px.r > 0.97 and px.g < 0.03 and px.b > 0.97:
				errs.append("%s: %s contains magenta #FF00FF at %d,%d (not allowed as transparency)" % [where, rel, x, y])
				return

static func _character(dir: String, a: Dictionary, where: String, errs: Array[String]) -> void:
	for k in ["frame_size", "pivot", "directions", "states", "files"]:
		if not a.has(k):
			errs.append("%s: '%s' missing" % [where, k])
			return
	var fs := Vector2i(int(a.frame_size[0]), int(a.frame_size[1]))
	var pivot := Vector2i(int(a.pivot[0]), int(a.pivot[1]))
	if pivot.x < 0 or pivot.y < 0 or pivot.x >= fs.x or pivot.y >= fs.y:
		errs.append("%s: pivot %s outside the frame %s" % [where, pivot, fs])
	for d in a.directions:
		if not String(d) in DIRS8:
			errs.append("%s: direction '%s' is not one of %s" % [where, d, DIRS8])
	var mirror: Dictionary = a.get("mirror", {})
	for state in a.states:
		var n := int(a.states[state].get("frames", 0))
		if n <= 0:
			errs.append("%s: state '%s' has no frames" % [where, state])
		for d in a.directions:
			if mirror.has(d) and mirror[d] != null:
				continue   # drawn by mirroring another direction
			for i in n:
				var rel := String(a.files).replace("{state}", state).replace("{dir}", String(d)).replace("{nn}", "%02d" % i)
				var img := _load(dir, rel, where, errs)
				if img == null:
					continue
				if img.get_size() != fs:
					errs.append("%s: %s is %s, frame_size is %s" % [where, rel, img.get_size(), fs])
					continue
				if img.get_used_rect().size == Vector2i.ZERO:
					errs.append("%s: %s is empty" % [where, rel])
					continue
				_clean(img, rel, where, errs)
				# Feet on the pivot: the lowest opaque row must be within 2 px of pivot.y.
				var used := img.get_used_rect()
				var bottom := used.position.y + used.size.y - 1
				if absi(bottom - pivot.y) > 2:
					errs.append("%s: %s lowest opaque row %d, pivot.y %d (feet must stand on the pivot)" % [where, rel, bottom, pivot.y])

static func _building(dir: String, a: Dictionary, where: String, errs: Array[String]) -> void:
	if not a.has("footprint") or not a.has("layers") or not a.has("pivot"):
		errs.append("%s: needs footprint, layers and pivot" % where)
		return
	var fx := int(a.footprint[0])
	var fy := int(a.footprint[1])
	var base: Dictionary = a.layers
	if not base.has("base"):
		errs.append("%s: layers.base missing" % where)
		return
	var img := _load(dir, String(base.base), where, errs)
	if img == null:
		return
	_clean(img, String(base.base), where, errs)
	var min_w := (fx + fy) * int(Iso.HALF_W)
	if img.get_width() < min_w:
		errs.append("%s: base is %d px wide, a %dx%d footprint needs at least %d" % [where, img.get_width(), fx, fy, min_w])
	var pv := Vector2i(int(a.pivot[0]), int(a.pivot[1]))
	if pv.x < 0 or pv.y < 0 or pv.x >= img.get_width() or pv.y >= img.get_height():
		errs.append("%s: pivot %s outside the image" % [where, pv])
	for k in base:
		if k != "base":
			var other := _load(dir, String(base[k]), where, errs)
			if other and other.get_size() != img.get_size():
				errs.append("%s: layer '%s' size %s differs from base %s" % [where, k, other.get_size(), img.get_size()])
	for d in a.get("doors", []):
		var c := Vector2i(int(d.cell[0]), int(d.cell[1]))
		var face := String(d.get("face", ""))
		var ok := (face == "+y" and c.y == fy and c.x >= 0 and c.x < fx) or (face == "+x" and c.x == fx and c.y >= 0 and c.y < fy)
		if not ok:
			errs.append("%s: door cell %s is not just outside the %s face of a %dx%d footprint" % [where, c, face, fx, fy])

static func _tile(dir: String, a: Dictionary, where: String, errs: Array[String]) -> void:
	for v in a.get("variants", []):
		var img := _load(dir, String(v), where, errs)
		if img and img.get_size() != Vector2i(int(Iso.TILE_W), int(Iso.TILE_H)):
			errs.append("%s: %s is %s, tiles are %dx%d" % [where, v, img.get_size(), int(Iso.TILE_W), int(Iso.TILE_H)])
