extends Node
## Global game state: the profile, saving, settings, screen navigation and
## app lifecycle (pause on background, save on quit).

signal profile_changed
signal app_paused
signal notice(text: String)

var profile: Dictionary = {}
var load_status := "new"
var save_path := SaveSystem.DEFAULT_PATH
var main: Node = null           # set by main.gd
var pending_results: Dictionary = {}
var pending_notices: Array = []
var last_mode := "shift"
var rng := RandomNumberGenerator.new()
var _dirty := false
var _autosave_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--save="):
			save_path = a.substr(7)
	var r := SaveSystem.load_profile(save_path)
	profile = r["profile"]
	load_status = r["status"]
	if load_status == "backup":
		pending_notices.append(I18n.t("save_recovered"))
	elif load_status == "reset":
		pending_notices.append(I18n.t("save_reset"))
	var lang: String = profile["settings"].get("lang", "")
	if lang == "":
		profile["settings"]["lang"] = I18n.lang
	else:
		I18n.set_lang(lang)
	apply_settings()
	var idle := Economy.idle_income(profile, int(Time.get_unix_time_from_system()))
	if idle > 0:
		profile["coins"] = int(profile["coins"]) + idle
		pending_notices.append(I18n.t("idle_income", idle))
	profile["last_seen"] = int(Time.get_unix_time_from_system())
	save_now()


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _dirty and _autosave_timer > 5.0:
		save_now()


func mark_dirty() -> void:
	_dirty = true
	profile_changed.emit()


func save_now() -> void:
	profile["last_seen"] = int(Time.get_unix_time_from_system())
	SaveSystem.save_profile(profile, save_path)
	_dirty = false
	_autosave_timer = 0.0


func apply_settings() -> void:
	var s: Dictionary = profile["settings"]
	Audio.set_volumes(float(s["music"]), float(s["sfx"]))
	Engine.max_fps = int(s.get("fps", 60))


func setting(key: String):
	return profile["settings"].get(key)


func set_setting(key: String, value) -> void:
	profile["settings"][key] = value
	if key == "lang":
		I18n.set_lang(value)
	apply_settings()
	mark_dirty()


func haptic(ms: int = 18) -> void:
	if bool(profile["settings"].get("haptics", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func goto(screen: String, data: Dictionary = {}) -> void:
	if main:
		main.show_screen(screen, data)


func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


func today_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


## Applies a finished shift to the profile and saves immediately.
func finish_shift(summary: Dictionary) -> Dictionary:
	if summary["mode"] == "daily":
		summary["day"] = today_key()
	var out := Economy.apply_summary(profile, summary)
	if summary["mode"] == "tutorial":
		profile["tutorial_done"] = true
	save_now()
	profile_changed.emit()
	return out


func reset_progress() -> void:
	var settings: Dictionary = profile["settings"].duplicate()
	profile = SaveSystem.default_profile()
	profile["settings"] = settings
	save_now()
	profile_changed.emit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			app_paused.emit()
			if not profile.is_empty():
				save_now()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			if not profile.is_empty():
				save_now()
			if what == NOTIFICATION_WM_GO_BACK_REQUEST and main:
				main.back_pressed()
