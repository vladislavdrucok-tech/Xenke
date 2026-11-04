class_name DataRegistry
extends RefCounted
## Read-only game definitions from res://data (validated JSON with stable string IDs). See docs/TECH_ARCHITECTURE.md.
## Every table is a JSON object {"<id>": {...}} or a file whose top level has "id". IDs are lowercase snake_case and
## never reused; a renamed thing keeps its ID. tools/lint_data.gd checks references between tables.

const TABLES := {
	"items": "res://data/items/items.json",
	"npcs": "res://data/npcs/npcs.json",
	"businesses": "res://data/businesses/businesses.json",
	"vehicles": "res://data/vehicles/vehicles.json",
	"weapons": "res://data/weapons/weapons.json",
	"quests": "res://data/quests/chapter1.json",
	"districts": "res://data/districts/registry.json",
	"factions": "res://data/factions.json",
}

static var _cache := {}
static var errors: Array[String] = []

static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("missing file: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var j := JSON.new()
	if j.parse(text) != OK:
		errors.append("%s:%d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data

## A whole table, e.g. table("npcs") -> {"salvatore": {...}, ...}. Never null.
static func table(name: String) -> Dictionary:
	if not _cache.has(name):
		var d: Variant = load_json(TABLES.get(name, ""))
		_cache[name] = d if typeof(d) == TYPE_DICTIONARY else {}
	return _cache[name]

static func get_def(table_name: String, id: String) -> Dictionary:
	var t := table(table_name)
	if not t.has(id):
		push_error("DataRegistry: unknown %s id '%s'" % [table_name, id])
		return {}
	return t[id]

static func has(table_name: String, id: String) -> bool:
	return table(table_name).has(id)

## District layout (world/district.gd reads it).
static func district(id: String) -> Dictionary:
	var key := "district:" + id
	if not _cache.has(key):
		var entry: Dictionary = table("districts").get(id, {})
		var d: Variant = load_json(entry.get("file", ""))
		_cache[key] = d if typeof(d) == TYPE_DICTIONARY else {}
	return _cache[key]

static func dialogue(id: String) -> Dictionary:
	var key := "dialogue:" + id
	if not _cache.has(key):
		var d: Variant = load_json("res://data/dialogue/%s.json" % id)
		_cache[key] = d if typeof(d) == TYPE_DICTIONARY else {}
	return _cache[key]

static func clear_cache() -> void:
	_cache.clear()
	errors.clear()
