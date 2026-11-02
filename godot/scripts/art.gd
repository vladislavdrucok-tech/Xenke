class_name Art
extends RefCounted
## Art that arrives after the 'Remaining' pack (blocks M, P, I, C), cut by tools/import_new.py into assets/new and
## data/new_art.json. Everything here is optional: when a picture is not there yet, callers get null / -1 and keep
## drawing what they drew before, so the game runs the same with or without the new files.

static var _data := {}
static var _loaded := false
static var _cache := {}

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists("res://data/new_art.json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/new_art.json"))
			if typeof(d) == TYPE_DICTIONARY:
				_data = d
	return _data

static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = t
	return t

## A prop from the new sheets: {states, w, h, anchor, ...} or {} when it has not arrived.
static func prop(name: String) -> Dictionary:
	return data().get("props", {}).get(name, {})

static func prop_tex(name: String, state := 0) -> Texture2D:
	return tex("res://assets/new/%s_%d.png" % [name, state]) if not prop(name).is_empty() else null

## Draws a new prop on `ci`, its base at `base` (bottom-centre, or the hinge for "hinge" props). Returns false if missing.
static func draw_prop(ci: CanvasItem, name: String, state: int, base: Vector2, flip := false) -> bool:
	var m := prop(name)
	var t := prop_tex(name, state)
	if t == null:
		return false
	var size := Vector2(m.w, m.h)
	var r := Rect2(base.x - size.x / 2.0, base.y - size.y, size.x, size.y)
	if m.get("anchor", "bottom") == "hinge":
		r.position.x = base.x
	if flip:
		r = Rect2(r.position.x + r.size.x, r.position.y, -r.size.x, r.size.y)
	ci.draw_texture_rect(t, r, false)
	return true

static func portrait(id: String) -> Texture2D:
	return tex("res://assets/new/portraits/%s.png" % id) if id in data().get("portraits", []) else null

static func icon(id: String) -> Texture2D:
	return tex("res://assets/new/icons/%s.png" % id) if id in data().get("icons", []) else null

## Extra frames for a character (M1 crawler, M2 Einstein, P3 Mira) or a whole new character (P2 Sava).
static func character(name: String) -> Dictionary:
	return data().get("chars", {}).get(name, {})
