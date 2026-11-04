class_name Relationships
extends RefCounted
## How each named NPC feels about Enzo, on clamped axes from -100 to 100. Thresholds (docs/GAME_DESIGN.md):
##   >= 60 close, >= 25 friendly, > -25 neutral, > -60 cold, otherwise hostile.

const AXES := ["trust", "affection", "fear", "loyalty"]
const MIN := -100
const MAX := 100

var values := {}   # npc_id -> {axis: int}

func get_value(npc: String, axis: String) -> int:
	return int(values.get(npc, {}).get(axis, 0))

func change(npc: String, axis: String, delta: int) -> int:
	assert(axis in AXES, "unknown relationship axis " + axis)
	if not values.has(npc):
		values[npc] = {}
	var v := clampi(get_value(npc, axis) + delta, MIN, MAX)
	values[npc][axis] = v
	return v

static func tier(v: int) -> String:
	if v >= 60:
		return "close"
	if v >= 25:
		return "friendly"
	if v > -25:
		return "neutral"
	if v > -60:
		return "cold"
	return "hostile"

func to_dict() -> Dictionary:
	return values.duplicate(true)

func from_dict(d: Dictionary) -> void:
	values.clear()
	for npc in d:
		if typeof(d[npc]) != TYPE_DICTIONARY:
			continue
		values[String(npc)] = {}
		for axis in d[npc]:
			if String(axis) in AXES:
				values[String(npc)][String(axis)] = clampi(int(d[npc][axis]), MIN, MAX)
