class_name SaveSystem
extends RefCounted
## Versioned JSON save with an atomic write and a backup copy.
## load_profile() never crashes: a damaged main file falls back to the backup,
## a damaged backup falls back to a fresh profile (status says what happened).

const VERSION := 2
const DEFAULT_PATH := "user://post404_save.json"


static func default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"coins": 0, "shards": 0, "xp": 0, "level": 1,
		"shifts_done": 0, "best_stars": 0, "star_shifts": 0, "record_best": 0, "calm_best": 0,
		"upgrades": {}, "routes": ["town"], "collection": {},
		"seen_tips": [], "tutorial_done": false,
		"daily": {"day": "", "best": 0, "claimed": false},
		"story": {"done": [], "vars": {"hope": 0, "trust": 0, "memory": 0}, "met": [], "friendship": {},
			"letters": [], "ending": "", "pending": ""},
		"stats": {"parcels": 0, "correct": 0, "best_combo": 0, "play_time": 0.0, "coins_earned": 0},
		"settings": {"lang": "", "music": 0.7, "sfx": 0.9, "haptics": true, "buttons": true,
			"reduce_motion": false, "fps": 60, "swipe_hints": true},
		"last_seen": 0,
	}


## Fills missing keys from the default (recursively) and upgrades old versions.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	if v < 2:
		# v1 stored routes as a dictionary {id: true}.
		var r = data.get("routes", ["town"])
		if r is Dictionary:
			data["routes"] = r.keys()
	var out := _merge(default_profile(), data)
	out["version"] = VERSION
	if not (out["routes"] as Array).has("town"):
		(out["routes"] as Array).push_front("town")
	out["level"] = clampi(int(out["level"]), 1, Progression.MAX_LEVEL)
	out["coins"] = max(0, int(out["coins"]))
	out["shards"] = max(0, int(out["shards"]))
	return out


static func _merge(base: Dictionary, data: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in data:
		if out.has(k) and out[k] is Dictionary and data[k] is Dictionary and not (k in ["upgrades", "collection", "friendship"]):
			out[k] = _merge(out[k], data[k])
		elif out.has(k) and typeof(out[k]) != typeof(data[k]) and not (_is_number(out[k]) and _is_number(data[k])):
			continue  # wrong type in file: keep the default
		else:
			out[k] = data[k]
	return out


static func _is_number(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func save_profile(profile: Dictionary, path: String = DEFAULT_PATH) -> bool:
	profile["version"] = VERSION
	var text := JSON.stringify(profile, "", false)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	# Keep the previous good save as a backup, then move the new one in place.
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	return err == OK


## Returns {"profile": Dictionary, "status": "ok"|"new"|"backup"|"reset"}.
static func load_profile(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return {"profile": default_profile(), "status": "new"}
	var main = _read(path)
	if main is Dictionary:
		return {"profile": migrate(main), "status": "ok"}
	var bak = _read(path + ".bak")
	if bak is Dictionary:
		return {"profile": migrate(bak), "status": "backup"}
	return {"profile": default_profile(), "status": "reset"}


static func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var d = json.data
	if not (d is Dictionary) or not d.has("coins"):
		return null
	return d
