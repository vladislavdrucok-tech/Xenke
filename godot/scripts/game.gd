extends Node
## Mission state for the campaign: flags, inventory, health, the last checkpoint and the journal.
## Saved to user://afterfall_save.json at every checkpoint and after each finished job, so a reload
## resumes where the player was and never hands out an item twice.

signal changed
signal journal_added(text: String)

const SAVE_PATH := "user://afterfall_save.json"
const ITEM_NAMES := {"wrench": "Розвідний ключ", "jack": "Домкрат", "planks": "Дошки", "can": "Консерва", "filter_body": "Корпус фільтра",
		"hook": "Гак", "clamp": "Хомут", "rag": "Ганчірка", "straps": "Ремені"}

var flags := {}
var inv := {"wrench": 1}
var hp := 100
var checkpoint := "start"
var journal: Array[String] = []
var started_ms := 0
var play_time := 0.0
## Version of the save that was loaded (1 = the short laundry of builds 0.2-0.3, 2 = the six-stage one).
var loaded_version := 2

func _ready() -> void:
	started_ms = Time.get_ticks_msec()
	load_settings()

func _process(delta: float) -> void:
	play_time += delta

## Volumetric light (normal maps, lamps, light shafts). Kept apart from the mission save so a restart keeps it.
var fancy_light := true

func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load("user://settings.cfg") == OK:
		fancy_light = c.get_value("video", "fancy_light", true)

func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("video", "fancy_light", fancy_light)
	c.save("user://settings.cfg")

func has(flag: String) -> bool:
	return flags.get(flag, false)

func set_flag(flag: String, value := true) -> void:
	flags[flag] = value
	changed.emit()

func give(item: String, n := 1) -> void:
	inv[item] = inv.get(item, 0) + n
	changed.emit()

func take(item: String, n := 1) -> bool:
	if inv.get(item, 0) < n:
		return false
	inv[item] -= n
	changed.emit()
	return true

func count(item: String) -> int:
	return inv.get(item, 0)

## A line in the journal that says what changed in the world and why.
func note(text: String) -> void:
	if journal.has(text):
		return
	journal.append(text)
	journal_added.emit(text)

func reach_checkpoint(id: String) -> void:
	checkpoint = id
	save()

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 2, "flags": flags, "inv": inv, "hp": hp, "checkpoint": checkpoint, "journal": journal, "time": play_time}))

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or not int(d.get("version", 0)) in [1, 2]:
		return false
	loaded_version = int(d.version)
	flags = d.get("flags", {})
	inv = {}
	for k in d.get("inv", {}):
		inv[k] = int(d.inv[k])
	hp = int(d.get("hp", 100))
	checkpoint = d.get("checkpoint", "start")
	journal.assign(d.get("journal", []))
	play_time = float(d.get("time", 0.0))
	return true

func reset() -> void:
	flags = {}
	inv = {"wrench": 1}
	hp = 100
	checkpoint = "start"
	journal.clear()
	play_time = 0.0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	changed.emit()
