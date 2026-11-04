class_name Loc
extends RefCounted
## Localization. Strings live in data/localization/<locale>.json as {"KEY": "text"} (UPPER_SNAKE keys, grouped by
## prefix: UI_, HUD_, DLG_, Q_, NPC_, ITEM_, BIZ_, DAY_). They are loaded into Godot's TranslationServer at boot,
## so Label / Button text set to a key is translated by Godot itself, and code uses tr() / Loc.t().
## JSON instead of CSV: Godot's CSV importer would hide the source file in exported builds.

const LOCALES := ["uk"]
const DEFAULT := "uk"

static var loaded := {}   # locale -> key count

static func load_all() -> void:
	for loc in LOCALES:
		load_locale(loc)
	TranslationServer.set_locale(DEFAULT)

static func load_locale(loc: String) -> int:
	if loaded.has(loc):
		return loaded[loc]
	var d: Variant = DataRegistry.load_json("res://data/localization/%s.json" % loc)
	if typeof(d) != TYPE_DICTIONARY:
		push_error("Loc: cannot load locale " + loc)
		return 0
	var t := Translation.new()
	t.locale = loc
	for k in d:
		t.add_message(StringName(k), StringName(String(d[k])))
	TranslationServer.add_translation(t)
	loaded[loc] = (d as Dictionary).size()
	return loaded[loc]

## Translated text with optional %s / %d arguments. A missing key returns the key itself (visible in QA).
static func t(key: String, args: Array = []) -> String:
	var s := String(TranslationServer.translate(StringName(key)))
	if not args.is_empty():
		s = s % args
	return s

static func has_key(key: String) -> bool:
	return String(TranslationServer.translate(StringName(key))) != key
