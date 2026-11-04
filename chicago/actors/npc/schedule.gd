class_name Schedule
extends RefCounted
## Where a named NPC is at a given time, from its data entry (data/npcs/npcs.json "schedule").
## Each entry: {"from": h, "to": h, "district": id ("" = off the map), "spot": spot id, "if": condition}.
## Hours may wrap midnight. The first entry that matches the current hour and whose condition holds wins.
## This is the coarse tier-C state: it costs nothing to evaluate for every NPC once an hour.

static func where(def: Dictionary, gs: Node) -> Dictionary:
	for e in def.get("schedule", []):
		if WorldClock.is_between(float(e.from), float(e.to)) and Conditions.check(e.get("if", {}), gs):
			return {"district": String(e.get("district", "")), "spot": String(e.get("spot", ""))}
	return {"district": "", "spot": ""}

## Named NPCs (tier A) currently scheduled into `district_id`, as {npc_id: spot_id}.
static func present_in(district_id: String, gs: Node) -> Dictionary:
	var out := {}
	var npcs := DataRegistry.table("npcs")
	for id in npcs:
		var d: Dictionary = npcs[id]
		if d.get("tier", "") != "A":
			continue
		var w := where(d, gs)
		if w.district == district_id and w.district != "":
			out[id] = w.spot
	return out
