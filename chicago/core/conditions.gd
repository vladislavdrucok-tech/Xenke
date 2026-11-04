class_name Conditions
extends RefCounted
## Declarative conditions used by dialogue, quests, businesses and doors. A condition is a JSON object; all keys must
## hold (AND). An empty object is true. Keys:
##   "flag": {"name": value, ...}             flag equals value (missing flag = false / null)
##   "not_flag": ["name", ...]                flag is unset or false
##   "quest": {"quest_id": "active"|"completed"|"failed"|"not_started", ...}
##   "objective": {"quest_id/objective_id": true|false}
##   "rel": [{"npc": id, "axis": "trust", "gte": 20}]   also "lte"
##   "money_gte": cents          "money_lt": cents
##   "hour_between": [from, to]  (may wrap midnight)
##   "item": {"item_id": min_count}
##   "remembers": {"npc": id, "event": event}
##   "any": [cond, cond]  (OR)

static func check(c: Variant, gs: Node) -> bool:
	if typeof(c) != TYPE_DICTIONARY:
		return c == null
	for k in c:
		var v: Variant = c[k]
		match k:
			"flag":
				for f in v:
					if gs.get_flag(f) != v[f]:
						return false
			"not_flag":
				for f in v:
					var cur: Variant = gs.get_flag(f)
					if cur != null and cur != false:
						return false
			"quest":
				for q in v:
					if gs.quests.state(q) != v[q]:
						return false
			"objective":
				for key in v:
					var parts: PackedStringArray = String(key).split("/")
					if parts.size() != 2 or gs.quests.objective_done(parts[0], parts[1]) != bool(v[key]):
						return false
			"rel":
				for r in v:
					var cur := int(gs.relationships.get_value(r.npc, r.axis))
					if r.has("gte") and cur < int(r.gte):
						return false
					if r.has("lte") and cur > int(r.lte):
						return false
			"money_gte":
				if gs.ledger.balance < int(v):
					return false
			"money_lt":
				if gs.ledger.balance >= int(v):
					return false
			"hour_between":
				if not WorldClock.is_between(float(v[0]), float(v[1])):
					return false
			"item":
				for i in v:
					if gs.item_count(i) < int(v[i]):
						return false
			"remembers":
				if not gs.memory.knows(v.npc, v.event):
					return false
			"any":
				var ok := false
				for sub in v:
					if check(sub, gs):
						ok = true
						break
				if not ok:
					return false
			_:
				push_error("Conditions: unknown key '%s'" % k)
				return false
	return true

const KEYS := ["flag", "not_flag", "quest", "objective", "rel", "money_gte", "money_lt", "hour_between", "item", "remembers", "any"]
