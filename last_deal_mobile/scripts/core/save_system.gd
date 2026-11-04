class_name SaveSystem
extends RefCounted
## Локальне збереження в user:// (на Android — внутрішня пам'ять застосунку).
## Пишемо спершу в тимчасовий файл, потім перейменовуємо — щоб збій під час запису
## не зіпсував попереднє збереження.

const SAVE_PATH := "user://last_deal_save.json"
const SETTINGS_PATH := "user://last_deal_settings.json"


static func write_json(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Не вдалося зберегти: %s" % path)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	var name_tmp := tmp.replace("user://", "")
	var name_final := path.replace("user://", "")
	if dir.file_exists(name_final):
		dir.remove(name_final)
	return dir.rename(name_tmp, name_final) == OK


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		# можливо, запис перервався після видалення старого файлу
		if FileAccess.file_exists(path + ".tmp"):
			path = path + ".tmp"
		else:
			return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	return {}


static func save_game(session: GameSession) -> bool:
	return write_json(SAVE_PATH, session.to_dict())


static func load_game(session: GameSession) -> bool:
	return session.from_dict(read_json(SAVE_PATH))


static func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for n in ["last_deal_save.json", "last_deal_save.json.tmp"]:
			if dir.file_exists(n):
				dir.remove(n)


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
