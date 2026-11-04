extends Node
## Global signals between systems that must not know each other (autoload "EventBus").
## Rule: systems emit facts ("this happened"), never commands to other systems.

## A gameplay fact: id like "talked_to", "entered_district", "repair_done", "crime_witnessed"; data is free-form.
## Quests, NPC memory and police listen to this one stream (see quests/quest_system.gd).
signal game_event(id: String, data: Dictionary)

signal minute_passed(total_minutes: int)
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)

signal money_changed(balance_cents: int)
signal flag_changed(flag: String, value: Variant)
signal relationship_changed(npc_id: String, axis: String, value: int)
signal quest_changed(quest_id: String, state: String)
signal objective_changed(quest_id: String, objective_id: String, done: bool)

signal district_will_change(from_id: String, to_id: String)
signal district_loaded(district_id: String)

signal toast(text_key: String, args: Array)
signal dialogue_requested(dialogue_id: String, speaker_id: String)
signal dialogue_finished(dialogue_id: String)
signal wanted_changed(level: int)

func emit_event(id: String, data: Dictionary = {}) -> void:
	game_event.emit(id, data)
