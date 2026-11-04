class_name ArtRegistry
extends RefCounted
## Real art, when it exists. Imported packages are listed in res://art/manifest.json (tools/art_importer.gd writes
## it). Anything not listed keeps its TEMPORARY code-drawn placeholder, so art can arrive piece by piece.
## Characters become SpriteFrames with animations "<state>_<DIR>"; a direction without frames uses a mirrored one
## ("mirror": {"W": "E"}) or the nearest drawn direction.

static var manifest_path := "res://art/manifest.json"
static var _manifest := {}
static var _loaded := false
static var _frames_cache := {}

## Godot 4.3: a static var assigned from another script does not stick, so paths are set through these.
static func use_manifest(path: String) -> void:
	manifest_path = path
	reload()

static func reload() -> void:
	_loaded = true
	_manifest = {}
	_frames_cache = {}
	if not FileAccess.file_exists(manifest_path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(d) == TYPE_DICTIONARY:
		for a in d.get("assets", []):
			if typeof(a) == TYPE_DICTIONARY and a.has("id"):
				_manifest[String(a.id)] = a

static func entry(id: String) -> Dictionary:
	if not _loaded:
		reload()
	return _manifest.get(id, {})

static func has(id: String) -> bool:
	return not entry(id).is_empty()

static func texture(path: String) -> Texture2D:
	if path.begins_with("res://"):
		return load(path) as Texture2D
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img else null

## SpriteFrames for a character, or null if it has no art yet.
static func character_frames(id: String) -> SpriteFrames:
	var a := entry(id)
	if a.is_empty() or a.get("type", "") != "character":
		return null
	if _frames_cache.has(id):
		return _frames_cache[id]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var mirror: Dictionary = a.get("mirror", {})
	for state in a.states:
		var fps := float(a.states[state].get("fps", 10))
		for d in a.directions:
			if mirror.has(d) and mirror[d] != null:
				continue
			var anim := "%s_%s" % [state, d]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, fps)
			sf.set_animation_loop(anim, state in ["idle", "walk", "run"])
			for i in int(a.states[state].frames):
				var rel := String(a.files).replace("{state}", state).replace("{dir}", String(d)).replace("{nn}", "%02d" % i)
				var tex := texture(rel)
				if tex:
					sf.add_frame(anim, tex)
	_frames_cache[id] = sf
	return sf

## Which drawn animation to use for a state facing `dir`, and whether to flip it. ["", false] if none.
static func pick(id: String, state: String, dir: String) -> Array:
	var a := entry(id)
	var sf := character_frames(id)
	if sf == null:
		return ["", false]
	if sf.has_animation("%s_%s" % [state, dir]):
		return ["%s_%s" % [state, dir], false]
	var mirror: Dictionary = a.get("mirror", {})
	if mirror.has(dir) and mirror[dir] != null and sf.has_animation("%s_%s" % [state, mirror[dir]]):
		return ["%s_%s" % [state, mirror[dir]], true]
	# Nearest drawn direction around the compass.
	var i := Iso.DIRS.find(dir)
	for step in [1, -1, 2, -2, 3, -3, 4]:
		var d2: String = Iso.DIRS[posmod(i + step, 8)]
		if sf.has_animation("%s_%s" % [state, d2]):
			return ["%s_%s" % [state, d2], false]
	if state != "idle":
		return pick(id, "idle", dir)
	return ["", false]
