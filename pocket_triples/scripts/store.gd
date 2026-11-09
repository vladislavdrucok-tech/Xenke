extends Node
## Autoload "Store": settings, progress and the puzzles in progress, written to user://save.json
## after every move. Writes go to a temporary file first and are then renamed over the old one,
## with the previous good copy kept as save.bak, so a kill mid-write never loses the save.

const VERSION := 1
var path := "user://save.json"
var data: Dictionary = {}
var first_launch := false
var writes := 0


func _ready() -> void:
	load_data()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"settings": {"lang": "", "sound": true, "vibration": true},
		"progress": {
			"unlocked": 1,
			"solved_levels": [],
			"solved_total": 0,
			"endless_solved": 0,
			"clean_solves": 0,
			"triples": 0,
			"tutorial_done": false,
			"endless_index": 0,
			"fallback_index": 0,
			"install_seed": 0,
			"wins_recorded": [],
		},
		"active": "level",
		"level_run": {},
		"endless_run": {},
	}


func _merge(base: Dictionary, loaded: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in loaded:
		if out.has(k) and out[k] is Dictionary and loaded[k] is Dictionary and k in ["settings", "progress"]:
			out[k] = _merge(out[k], loaded[k])
		elif out.has(k) and typeof(out[k]) == typeof(loaded[k]):
			out[k] = loaded[k]
		elif out.has(k) and (typeof(out[k]) in [TYPE_INT, TYPE_FLOAT]) and (typeof(loaded[k]) in [TYPE_INT, TYPE_FLOAT]):
			out[k] = loaded[k]
	return out


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary and parsed.has("progress"):
		return parsed
	return {}


func load_data() -> void:
	var loaded := _read(path)
	if loaded.is_empty():
		loaded = _read(path + ".bak")
	first_launch = loaded.is_empty()
	data = _merge(defaults(), loaded)
	var p: Dictionary = data["progress"]
	for k in ["unlocked", "solved_total", "endless_solved", "clean_solves", "triples", "endless_index", "fallback_index", "install_seed"]:
		p[k] = int(p[k])
	p["unlocked"] = clampi(p["unlocked"], 1, Puzzles.LEVEL_COUNT)
	var lv := []
	for v in p["solved_levels"]:
		if int(v) >= 1 and int(v) <= Puzzles.LEVEL_COUNT and not lv.has(int(v)):
			lv.append(int(v))
	p["solved_levels"] = lv
	if p["install_seed"] == 0:
		p["install_seed"] = (randi() & 0x3fffffff) | 1


func settings() -> Dictionary:
	return data["settings"]


func progress() -> Dictionary:
	return data["progress"]


func write() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot open %s" % tmp)
		return false
	f.store_string(JSON.stringify(data))
	f.flush()
	f.close()
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(abs_path, abs_path + ".bak")
	var err := DirAccess.rename_absolute(abs_tmp, abs_path)
	if err != OK:
		push_warning("save: rename failed (%d)" % err)
		return false
	writes += 1
	return true


## For the tests: forget everything (memory and disk).
func wipe() -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	data = defaults()
	first_launch = true
