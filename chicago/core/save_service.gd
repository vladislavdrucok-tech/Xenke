extends Node
## Saving and loading (autoload "SaveService"). Format: docs/TECH_ARCHITECTURE.md §Saves.
## File: line 1 = header JSON {"game": "chicago_bl", "save_version": N, "saved_unix": t, "checksum": fnv1a(rest)},
## the rest = the payload JSON (pretty-printed for QA). The checksum covers the payload text exactly as written.
## Write is atomic: write <slot>.tmp, close, read it back and verify, then <slot>.json -> <slot>.bak, .tmp -> .json.
## Load tries .json, then .bak; a broken or foreign file is never applied half-way. Older versions are migrated step
## by step (MIGRATIONS); a save from a newer version of the game is refused rather than guessed at.

const GAME_ID := "chicago_bl"
const SAVE_VERSION := 1
const AUTOSAVE_SLOT := "autosave"

var base_dir := "user://saves/"
## Set by the world while a district is being swapped: a save then would capture a half-built state.
var transition_lock := false
var last_error := ""
var last_loaded_from := ""   # "main" | "backup" (tests and the menu read it)

## Versions that have a step to the next one (see _migrate()).
const MIGRATABLE := [0]

func _notification(what: int) -> void:
	# Android: the app can be killed at any time after it goes to the background.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.get_flag("game_started") == true and not transition_lock:
			# The world writes the live position, cars and combat state first. Saving mid-fight is safe here:
			# encounters restart from their checkpoint on load and chases never resume.
			var worlds := get_tree().get_nodes_in_group("world")
			if worlds.is_empty():
				save(AUTOSAVE_SLOT)
			else:
				worlds[0].autosave(true)

func path(slot: String, ext: String = "json") -> String:
	return base_dir.path_join("%s.%s" % [slot, ext])

## Unix time stored in a slot's header (0 if none / unreadable). The menu continues from the newest slot.
func saved_time(slot: String) -> int:
	for ext in ["json", "bak"]:
		if FileAccess.file_exists(path(slot, ext)):
			var t := FileAccess.get_file_as_string(path(slot, ext))
			var nl := t.find("\n")
			var h: Variant = JSON.parse_string(t.substr(0, nl)) if nl > 0 else null
			if typeof(h) == TYPE_DICTIONARY:
				return int(h.get("saved_unix", 0))
	return 0

func newest_slot() -> String:
	var best := ""
	var best_t := -1
	for s in ["autosave", "slot1"]:
		if has_save(s) and saved_time(s) > best_t:
			best = s
			best_t = saved_time(s)
	return best

func has_save(slot: String) -> bool:
	return FileAccess.file_exists(path(slot)) or FileAccess.file_exists(path(slot, "bak"))

static func fnv1a(s: String) -> String:
	# 32-bit FNV-1a: detects truncation / hand edits, not an anti-cheat measure.
	var h := 2166136261
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xffffffff
	return "%08x" % h

func save(slot: String) -> Error:
	if transition_lock:
		last_error = "busy: district transition"
		return ERR_BUSY
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var body := JSON.stringify(GameState.to_dict(), "\t", true)
	var head := {"game": GAME_ID, "save_version": SAVE_VERSION, "saved_unix": int(Time.get_unix_time_from_system()),
		"checksum": fnv1a(body)}
	var text := JSON.stringify(head) + "\n" + body
	var tmp := path(slot, "tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "open tmp: %s" % error_string(FileAccess.get_open_error())
		return FAILED
	f.store_string(text)
	f.flush()
	var werr := f.get_error()
	f.close()
	if werr != OK or FileAccess.get_file_as_string(tmp) != text:
		last_error = "tmp verify failed"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return ERR_FILE_CORRUPT
	var main := ProjectSettings.globalize_path(path(slot))
	var bak := ProjectSettings.globalize_path(path(slot, "bak"))
	if FileAccess.file_exists(path(slot)):
		# Keep the backup good: a corrupt main file replaces nothing, it is simply overwritten.
		var keep_err := last_error
		var main_ok := not _parse(FileAccess.get_file_as_string(path(slot))).is_empty()
		last_error = keep_err
		if main_ok:
			if FileAccess.file_exists(path(slot, "bak")):
				DirAccess.remove_absolute(bak)
			var e1 := DirAccess.rename_absolute(main, bak)
			if e1 != OK:
				last_error = "rotate backup: %s" % error_string(e1)
				return e1
		else:
			DirAccess.remove_absolute(main)
	var e2 := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), main)
	if e2 != OK:
		last_error = "replace: %s" % error_string(e2)
		return e2
	last_error = ""
	return OK

## Reads and validates a slot without applying it. Returns the (migrated) payload, or {} on failure.
func read(slot: String) -> Dictionary:
	for which in ["json", "bak"]:
		var p := path(slot, which)
		if not FileAccess.file_exists(p):
			continue
		var payload := _parse(FileAccess.get_file_as_string(p))
		if not payload.is_empty():
			last_loaded_from = "main" if which == "json" else "backup"
			return payload
	return {}

func load_slot(slot: String) -> Error:
	var payload := read(slot)
	if payload.is_empty():
		if last_error.is_empty():
			last_error = "no save"
		return ERR_FILE_NOT_FOUND if last_error == "no save" else ERR_FILE_CORRUPT
	GameState.from_dict(payload)
	return OK

func delete_slot(slot: String) -> void:
	for ext in ["json", "bak", "tmp"]:
		if FileAccess.file_exists(path(slot, ext)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot, ext)))

func _parse(text: String) -> Dictionary:
	var nl := text.find("\n")
	var j := JSON.new()
	if nl < 0 or j.parse(text.substr(0, nl)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		last_error = "not a save file"
		return {}
	var env: Dictionary = j.data
	var body := text.substr(nl + 1)
	if env.get("game", "") != GAME_ID:
		last_error = "not a save of this game"
		return {}
	if fnv1a(body) != String(env.get("checksum", "")):
		last_error = "checksum mismatch"
		return {}
	var jb := JSON.new()
	if jb.parse(body) != OK or typeof(jb.data) != TYPE_DICTIONARY:
		last_error = "payload not json"
		return {}
	var version := int(env.get("save_version", -1))
	if version > SAVE_VERSION or version < 0:
		last_error = "save version %d not supported (game is %d)" % [version, SAVE_VERSION]
		return {}
	var payload: Dictionary = jb.data
	while version < SAVE_VERSION:
		if not version in MIGRATABLE:
			last_error = "no migration from %d" % version
			return {}
		payload = _migrate(version, payload)
		version += 1
	if not _valid(payload):
		last_error = "payload invalid"
		return {}
	last_error = ""
	return payload

func _valid(p: Dictionary) -> bool:
	for k in ["time", "ledger", "quests", "location"]:
		if not p.has(k):
			return false
	if typeof(p.ledger) != TYPE_DICTIONARY or typeof(p.quests) != TYPE_DICTIONARY or typeof(p.location) != TYPE_DICTIONARY:
		return false
	var l := Ledger.from_dict(p.ledger)
	return l.is_consistent()

func _migrate(from_version: int, p: Dictionary) -> Dictionary:
	match from_version:
		0:
			return _migrate_v0_to_v1(p)
	return p

## v0 was the pre-release test format: money as "cash" in whole dollars and no ledger. Kept as the template for
## future migrations and covered by tests/fixtures/save_v0.json.
func _migrate_v0_to_v1(p: Dictionary) -> Dictionary:
	var out := p.duplicate(true)
	if not out.has("ledger"):
		var cents := int(round(float(out.get("cash", 0)) * 100.0))
		out["ledger"] = {"balance": cents, "entries": [{"id": "migrated:v0:cash", "cents": cents, "reason": "migration", "minute": 0}],
			"ids": ["migrated:v0:cash"]}
	out.erase("cash")
	if not out.has("quests"):
		out["quests"] = {}
	if not out.has("location"):
		out["location"] = {"district": "santa_lucia", "spawn": "station_arrival"}
	return out
