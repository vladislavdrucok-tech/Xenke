class_name DataLint
extends RefCounted
## Checks the data tables against each other, so a typo in JSON fails a test instead of a playthrough:
## localization keys exist, dialogue "next" targets exist, NPC dialogue rules and schedules point at real
## dialogues / districts / spots, doors lead to real districts and spawns, quests reference real quests and
## effects / conditions use known keys, money values are whole cents. Returns a list of problems (empty = OK).

static func run() -> Array[String]:
	var out: Array[String] = []
	var loc: Variant = DataRegistry.load_json("res://data/localization/uk.json")
	var keys: Dictionary = loc if typeof(loc) == TYPE_DICTIONARY else {}
	var districts := DataRegistry.table("districts")
	var npcs := DataRegistry.table("npcs")
	var quests := DataRegistry.table("quests")
	for e in DataRegistry.errors:
		out.append("load: " + e)
	# Dialogues
	for f in DirAccess.get_files_at("res://data/dialogue"):
		if not f.ends_with(".json"):
			continue
		var id := f.get_basename()
		var d := DataRegistry.dialogue(id)
		if String(d.get("id", "")) != id:
			out.append("dialogue %s: id field differs from file name" % id)
		if not d.get("nodes", {}).has(String(d.get("start", ""))):
			out.append("dialogue %s: start node missing" % id)
		for nid in d.get("nodes", {}):
			var n: Dictionary = d.nodes[nid]
			_key(out, keys, n.get("text", ""), "dialogue %s/%s" % [id, nid])
			if n.has("next") and not d.nodes.has(String(n.next)):
				out.append("dialogue %s/%s: next '%s' missing" % [id, nid, n.next])
			if not n.has("next") and not n.has("choices") and not n.get("end", false):
				out.append("dialogue %s/%s: dead end (no next/choices/end)" % [id, nid])
			_effects(out, n.get("effects", []), "dialogue %s/%s" % [id, nid])
			for c in n.get("choices", []):
				_key(out, keys, c.get("text", ""), "dialogue %s/%s choice" % [id, nid])
				if c.has("next") and not d.nodes.has(String(c.next)):
					out.append("dialogue %s/%s: choice next '%s' missing" % [id, nid, c.next])
				_effects(out, c.get("effects", []), "dialogue %s/%s choice" % [id, nid])
				_cond(out, c.get("if", {}), "dialogue %s/%s choice" % [id, nid])
	# NPCs
	for id in npcs:
		var n: Dictionary = npcs[id]
		_key(out, keys, n.get("name", ""), "npc " + id)
		for r in n.get("dialogue", []):
			if DataRegistry.dialogue(String(r.dialogue)).is_empty():
				out.append("npc %s: dialogue '%s' missing" % [id, r.dialogue])
			_cond(out, r.get("if", {}), "npc %s rule" % id)
		for s in n.get("schedule", []):
			var dist := String(s.get("district", ""))
			if dist == "":
				continue
			if not districts.has(dist):
				out.append("npc %s: schedule district '%s' missing" % [id, dist])
			elif not DataRegistry.district(dist).get("spots", {}).has(String(s.spot)):
				out.append("npc %s: spot '%s' not in %s" % [id, s.spot, dist])
	# Districts
	for id in districts:
		var d := DataRegistry.district(id)
		if d.is_empty():
			out.append("district %s: file missing" % id)
			continue
		_key(out, keys, districts[id].get("name", ""), "district " + id)
		for dr in d.get("doors", []):
			var t: Dictionary = dr.target
			if not districts.has(String(t.district)):
				out.append("district %s door %s: target district missing" % [id, dr.id])
			elif not DataRegistry.district(String(t.district)).get("spawns", {}).has(String(t.spawn)):
				out.append("district %s door %s: target spawn '%s' missing" % [id, dr.id, t.spawn])
		for b in d.get("buildings", []):
			if b.has("sign"):
				_key(out, keys, b.sign, "district %s building %s" % [id, b.id])
		for it in d.get("interactables", []):
			_key(out, keys, it.get("verb", "HUD_ACT_USE"), "district %s %s" % [id, it.id])
	# Quests
	for id in quests:
		if id == "_start":
			for q in quests[id].get("quests", []):
				if not quests.has(q):
					out.append("start quest '%s' missing" % q)
			continue
		var q: Dictionary = quests[id]
		_key(out, keys, q.get("title", ""), "quest " + id)
		for o in q.get("objectives", []):
			_key(out, keys, o.get("text", ""), "quest %s/%s" % [id, o.id])
			if not o.has("on") and not o.has("when"):
				out.append("quest %s/%s: neither 'on' nor 'when'" % [id, o.id])
			_cond(out, o.get("when", {}), "quest %s/%s" % [id, o.id])
		for k in ["on_start", "on_complete"]:
			_effects(out, q.get(k, []), "quest %s %s" % [id, k])
	# Money must be whole cents
	for t in ["businesses", "items", "vehicles"]:
		_cents(out, DataRegistry.table(t), t)
	return out

static func _key(out: Array[String], keys: Dictionary, k: Variant, where: String) -> void:
	if String(k) != "" and not keys.has(String(k)):
		out.append("%s: localization key '%s' missing" % [where, k])

static func _effects(out: Array[String], effects: Array, where: String) -> void:
	for e in effects:
		for k in e:
			if not k in GameState.EFFECT_KEYS:
				out.append("%s: unknown effect '%s'" % [where, k])
			if k == "start_quest" and not DataRegistry.table("quests").has(String(e[k])):
				out.append("%s: start_quest '%s' missing" % [where, e[k]])
			if k == "item" and not DataRegistry.has("items", String(e[k].id)):
				out.append("%s: item '%s' missing" % [where, e[k].id])

static func _cond(out: Array[String], c: Variant, where: String) -> void:
	if typeof(c) != TYPE_DICTIONARY:
		return
	for k in c:
		if not k in Conditions.KEYS:
			out.append("%s: unknown condition '%s'" % [where, k])
		elif k == "any":
			for sub in c[k]:
				_cond(out, sub, where)

static func _cents(out: Array[String], v: Variant, where: String) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v:
			if String(k).ends_with("_cents") and typeof(v[k]) == TYPE_FLOAT and v[k] != floorf(v[k]):
				out.append("%s.%s: money must be whole cents" % [where, k])
			_cents(out, v[k], where + "." + String(k))
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_cents(out, x, where)
