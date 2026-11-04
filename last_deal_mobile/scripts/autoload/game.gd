extends Node
## Глобальний доступ до поточної гри: сесія, налаштування, автозбереження.

signal session_replaced

var session := GameSession.new()
var settings := {"sound": true, "vibration": true, "tutorial_done": false}
var loaded_from_save := false
var _save_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--ld-test" in OS.get_cmdline_user_args():
		session.new_game(1)  # тести не чіпають справжнє збереження
		return
	_load_settings()
	if SaveSystem.load_game(session):
		loaded_from_save = true
	else:
		session.new_game()
		save_now()
	_connect_session()


func _connect_session() -> void:
	if not session.changed.is_connected(_on_changed):
		session.changed.connect(_on_changed)
		session.money_changed.connect(func(_v, _d): _on_changed())


func _on_changed() -> void:
	# кілька змін за кадр -> одне збереження наприкінці кадру
	if not _save_pending:
		_save_pending = true
		call_deferred("_flush_save")


func _flush_save() -> void:
	_save_pending = false
	save_now()


func save_now() -> void:
	SaveSystem.save_game(session)


func new_game() -> void:
	SaveSystem.delete_save()
	session = GameSession.new()
	session.new_game()
	_connect_session()
	save_now()
	session_replaced.emit()


func set_setting(key: String, value) -> void:
	settings[key] = value
	SaveSystem.write_json(SaveSystem.SETTINGS_PATH, settings)


func _load_settings() -> void:
	var d := SaveSystem.read_json(SaveSystem.SETTINGS_PATH)
	for k in settings:
		if d.has(k):
			settings[k] = bool(d[k])


func vibrate(ms: int = 25) -> void:
	if settings.get("vibration", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_now()
