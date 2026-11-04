class_name QuestSystem
extends RefCounted
## Quest state machine: NotStarted -> Active -> Completed | Failed (Failed may go back to Active via retry).
## Definitions: data/quests/chapter1.json. Objectives complete on matching game events (EventBus.game_event):
##   {"id": "talk_father", "on": {"event": "talked_to", "match": {"npc": "salvatore"}}, "count": 1}
## Objectives listed in "order" complete in sequence (only the first open one listens); otherwise any order.
## A quest completes when all its objectives are done; then its "on_complete" effects run once (GameState).
## Events are idempotent per quest: the same event can only advance an objective while that objective is open.

const NOT_STARTED := "not_started"
const ACTIVE := "active"
const COMPLETED := "completed"
const FAILED := "failed"

var defs := {}
var states := {}   # quest_id -> {state, obj: {objective_id: count}, started_min}
var gs: Node

func setup(game_state: Node, definitions: Dictionary) -> void:
	gs = game_state
	defs = definitions

func state(id: String) -> String:
	return String(states.get(id, {}).get("state", NOT_STARTED))

func objective_done(qid: String, oid: String) -> bool:
	var o := _obj_def(qid, oid)
	if o.is_empty():
		return false
	return int(states.get(qid, {}).get("obj", {}).get(oid, 0)) >= int(o.get("count", 1))

func start(id: String) -> bool:
	if not defs.has(id):
		push_error("QuestSystem: unknown quest " + id)
		return false
	var s := state(id)
	if s == ACTIVE or s == COMPLETED:
		return false
	if not Conditions.check(defs[id].get("requires", {}), gs):
		return false
	states[id] = {"state": ACTIVE, "obj": {}, "started_min": WorldClock.total_minutes}
	EventBus.quest_changed.emit(id, ACTIVE)
	gs.apply_effects(defs[id].get("on_start", []), "quest:%s:start" % id)
	# An objective may already be satisfied by world state (e.g. "have $5").
	_check_state_objectives(id)
	return true

func fail(id: String) -> void:
	if state(id) != ACTIVE:
		return
	states[id].state = FAILED
	EventBus.quest_changed.emit(id, FAILED)

## Retry policy: a failed quest restarts from its checkpoint objectives (kept) if "retry": "checkpoint".
func retry(id: String) -> void:
	if state(id) != FAILED:
		return
	if defs[id].get("retry", "restart") == "restart":
		states[id].obj = {}
	states[id].state = ACTIVE
	EventBus.quest_changed.emit(id, ACTIVE)

func active_ids() -> Array[String]:
	var out: Array[String] = []
	for id in defs:
		if state(id) == ACTIVE:
			out.append(id)
	return out

## The objective the HUD shows for a quest: the first one not yet done.
func current_objective(id: String) -> Dictionary:
	for o in defs.get(id, {}).get("objectives", []):
		if not objective_done(id, o.id):
			return o
	return {}

func on_event(ev: String, data: Dictionary) -> void:
	for id in active_ids():
		# Conditions first: a "when" objective that became true (a flag set by a dialogue) must not make the
		# next objective miss this very event.
		_check_state_objectives(id)
		if state(id) != ACTIVE:
			continue
		var q: Dictionary = defs[id]
		var ordered: bool = q.get("ordered", true)
		for o in q.get("objectives", []):
			if objective_done(id, o.id):
				continue
			var on: Dictionary = o.get("on", {})
			if on.get("event", "") == ev and _matches(on.get("match", {}), data) and Conditions.check(o.get("if", {}), gs):
				_advance(id, o)
			if ordered:
				break
		if state(id) == ACTIVE:
			_check_state_objectives(id)

func _matches(m: Dictionary, data: Dictionary) -> bool:
	for k in m:
		if not data.has(k) or data[k] != m[k]:
			return false
	return true

## Objectives with "when" (a condition) instead of an event complete as soon as the condition holds.
func _check_state_objectives(id: String) -> void:
	var ordered: bool = defs[id].get("ordered", true)
	for o in defs[id].get("objectives", []):
		if objective_done(id, o.id):
			continue
		if o.has("when") and Conditions.check(o.when, gs):
			_advance(id, o)
			if state(id) != ACTIVE:
				return
			continue
		if ordered:
			return

func _advance(id: String, o: Dictionary) -> void:
	var st: Dictionary = states[id]
	st.obj[o.id] = int(st.obj.get(o.id, 0)) + 1
	if objective_done(id, o.id):
		EventBus.objective_changed.emit(id, o.id, true)
		gs.apply_effects(o.get("on_done", []), "quest:%s:obj:%s" % [id, o.id])
	for x in defs[id].get("objectives", []):
		if not objective_done(id, x.id):
			return
	st.state = COMPLETED
	EventBus.quest_changed.emit(id, COMPLETED)
	gs.apply_effects(defs[id].get("on_complete", []), "quest:%s:complete" % id)

func _obj_def(qid: String, oid: String) -> Dictionary:
	for o in defs.get(qid, {}).get("objectives", []):
		if o.id == oid:
			return o
	return {}

func to_dict() -> Dictionary:
	return states.duplicate(true)

func from_dict(d: Dictionary) -> void:
	states.clear()
	for id in d:
		if not defs.has(id) or typeof(d[id]) != TYPE_DICTIONARY:
			continue   # quest removed from data: dropped, not a crash
		var s := String(d[id].get("state", NOT_STARTED))
		if not s in [NOT_STARTED, ACTIVE, COMPLETED, FAILED]:
			s = NOT_STARTED
		var obj := {}
		var src: Variant = d[id].get("obj", {})
		if typeof(src) == TYPE_DICTIONARY:
			for k in src:
				obj[String(k)] = int(src[k])
		states[String(id)] = {"state": s, "obj": obj, "started_min": int(d[id].get("started_min", 0))}
