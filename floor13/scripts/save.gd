extends Node
## Progress and settings, saved as JSON in user://. Writes are debounced and also
## forced when the app goes to the background, so nothing is lost on Android.

const PATH := "user://floor13_save.json"
const SAVE_VERSION := 1

var data: Dictionary = {}
var _dirty := false
var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func defaults() -> Dictionary:
	var up := {}
	for id in Defs.UPGRADE_ORDER:
		up[id] = 0
	return {
		"version": SAVE_VERSION,
		"coins": 0,
		"shift": 1,
		"upgrades": up,
		"tutorial_done": false,
		"seen_types": [],
		"skin": "classic",
		"skins": ["classic"],
		"last_rule": "",
		"records": {
			"best_shift": 0, "best_coins": 0, "best_streak": 0, "total_delivered": 0,
			"total_coins": 0, "shifts_done": 0, "perfect_shifts": 0, "ghosts": 0, "robots_direct": 0,
			"inspectors": 0, "pickups": 0,
		},
		"achievements": [],
		"settings": {"sfx": true, "music": true, "vibe": true},
	}


func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("save file unreadable, starting fresh")
		return
	_merge(data, parsed)
	_validate()


func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in dst.keys():
		if not src.has(k):
			continue
		var dv = dst[k]
		var sv = src[k]
		if typeof(dv) == TYPE_DICTIONARY and typeof(sv) == TYPE_DICTIONARY:
			_merge(dv, sv)
		elif typeof(dv) == TYPE_INT and (typeof(sv) == TYPE_FLOAT or typeof(sv) == TYPE_INT):
			dst[k] = int(sv)
		elif typeof(dv) == typeof(sv):
			dst[k] = sv


func _validate() -> void:
	data["coins"] = maxi(0, int(data["coins"]))
	data["shift"] = clampi(int(data["shift"]), 1, 9999)
	for id in Defs.UPGRADE_ORDER:
		data["upgrades"][id] = clampi(int(data["upgrades"].get(id, 0)), 0, Defs.upgrade_max(id))
	var seen := []
	for t in data["seen_types"]:
		if Defs.TYPES.has(String(t)) and not seen.has(String(t)):
			seen.append(String(t))
	data["seen_types"] = seen
	var owned := ["classic"]
	for k in data["skins"]:
		if Defs.SKINS.has(String(k)) and not owned.has(String(k)):
			owned.append(String(k))
	data["skins"] = owned
	var ach := []
	for a in data["achievements"]:
		if not ach.has(String(a)):
			ach.append(String(a))
	data["achievements"] = ach
	if not owned.has(String(data["skin"])):
		data["skin"] = "classic"


func _process(delta: float) -> void:
	if _dirty:
		_timer -= delta
		if _timer <= 0.0:
			flush()


## Marks data as changed; it is written within a second.
func mark() -> void:
	if not _dirty:
		_timer = 1.0
	_dirty = true


func flush() -> void:
	_dirty = false
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("cannot write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir:
		if dir.file_exists(PATH.get_file()):
			dir.remove(PATH.get_file())
		dir.rename(tmp.get_file(), PATH.get_file())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			flush()


# ------------------------------------------------------------------ helpers

func coins() -> int:
	return int(data["coins"])


func add_coins(n: int) -> void:
	data["coins"] = coins() + n
	data["records"]["total_coins"] = int(data["records"]["total_coins"]) + maxi(0, n)
	mark()


func level(id: String) -> int:
	return int(data["upgrades"].get(id, 0))


func buy(id: String) -> bool:
	var cost := Defs.upgrade_cost(id, level(id))
	if cost < 0 or cost > coins():
		return false
	data["coins"] = coins() - cost
	data["upgrades"][id] = level(id) + 1
	flush()
	return true


func skin() -> String:
	return String(data["skin"])


func owns_skin(id: String) -> bool:
	return (data["skins"] as Array).has(id)


func buy_skin(id: String) -> bool:
	var cost := int(Defs.SKINS[id]["cost"])
	if owns_skin(id) or cost > coins():
		return false
	data["coins"] = coins() - cost
	(data["skins"] as Array).append(id)
	data["skin"] = id
	flush()
	return true


func wear_skin(id: String) -> void:
	if owns_skin(id):
		data["skin"] = id
		mark()


func setting(key: String) -> bool:
	return bool(data["settings"].get(key, true))


func set_setting(key: String, v: bool) -> void:
	data["settings"][key] = v
	mark()


func shift() -> int:
	return int(data["shift"])


func record(key: String) -> int:
	return int(data["records"].get(key, 0))


## Updates a "best" record; returns true if it is a new record.
func best(key: String, v: int) -> bool:
	if v > record(key):
		data["records"][key] = v
		mark()
		return true
	return false


func add_record(key: String, v: int) -> void:
	data["records"][key] = record(key) + v
	mark()


func see_type(t: String) -> bool:
	var seen: Array = data["seen_types"]
	if seen.has(t):
		return false
	seen.append(t)
	mark()
	return true


func progress(key: String) -> int:
	if key == "skins_owned":
		return (data["skins"] as Array).size()
	return record(key)


func has_achievement(id: String) -> bool:
	return (data["achievements"] as Array).has(id)


## Unlocks finished achievements, pays their rewards; returns the new ones.
func check_achievements() -> Array:
	var out := []
	for a in Defs.ACHIEVEMENTS:
		if has_achievement(a[0]):
			continue
		if progress(a[3]) >= int(a[4]):
			(data["achievements"] as Array).append(a[0])
			data["coins"] = coins() + int(a[5])
			out.append(a)
	if not out.is_empty():
		mark()
	return out


func reset_progress() -> void:
	var keep: Dictionary = data["settings"].duplicate()
	data = defaults()
	data["settings"] = keep
	flush()
