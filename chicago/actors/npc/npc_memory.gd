class_name NPCMemory
extends RefCounted
## What NPCs know about Enzo's actions. An NPC only remembers an event if it witnessed it or was told
## (`how` = "seen" | "told" | "story"). Importance: 1 minor (forgotten after 3 days), 2 notable (14 days),
## 3 major (never forgotten - story decisions). Memories are records, not counters: they keep who/when/how.

const RETAIN_DAYS := {1: 3, 2: 14, 3: -1}

var by_npc := {}   # npc_id -> [{event, minute, importance, how, data}]

func remember(npc: String, event: String, minute: int, importance: int = 1, how: String = "seen", data: Dictionary = {}) -> void:
	if not by_npc.has(npc):
		by_npc[npc] = []
	for m in by_npc[npc]:
		if m.event == event and int(m.minute) == minute:
			return   # the same event delivered twice (replayed signal) is one memory
	by_npc[npc].append({"event": event, "minute": minute, "importance": clampi(importance, 1, 3), "how": how, "data": data})

func knows(npc: String, event: String) -> bool:
	for m in by_npc.get(npc, []):
		if m.event == event:
			return true
	return false

func recall(npc: String, event: String) -> Dictionary:
	for m in by_npc.get(npc, []):
		if m.event == event:
			return m
	return {}

## Drops what has faded by `now_minute`. Called once a game day.
func decay(now_minute: int) -> void:
	for npc in by_npc:
		var kept := []
		for m in by_npc[npc]:
			var days: int = RETAIN_DAYS.get(int(m.importance), 3)
			if days < 0 or now_minute - int(m.minute) <= days * 24 * 60:
				kept.append(m)
		by_npc[npc] = kept

func to_dict() -> Dictionary:
	return by_npc.duplicate(true)

func from_dict(d: Dictionary) -> void:
	by_npc.clear()
	for npc in d:
		var list := []
		for m in d[npc]:
			if typeof(m) == TYPE_DICTIONARY and m.has("event"):
				list.append({"event": String(m.event), "minute": int(m.get("minute", 0)),
					"importance": clampi(int(m.get("importance", 1)), 1, 3), "how": String(m.get("how", "seen")),
					"data": m.get("data", {}) if typeof(m.get("data", {})) == TYPE_DICTIONARY else {}})
		by_npc[String(npc)] = list
