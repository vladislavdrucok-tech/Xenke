class_name BusinessSystem
extends RefCounted
## Businesses that exist in the world (data/businesses/businesses.json). Chapter 1: the Bellini repair shop.
## Each day at closing time the day is settled: income from the jobs done that day plus walk-in trade if the shop
## was open and staffed, minus wages and running costs. Settlement uses transaction ID "biz:<id>:day:<n>", so a day
## is paid once even if the game is reloaded, and a saved "settled_day" stops it from being re-run.

var gs: Node
var defs := {}
var states := {}  # id -> {owned, level, settled_day, jobs_today, jobs_total, staff: [npc ids]}

func setup(game_state: Node, definitions: Dictionary) -> void:
	gs = game_state
	defs = definitions

func st(id: String) -> Dictionary:
	if not states.has(id):
		var d: Dictionary = defs.get(id, {})
		states[id] = {"owned": bool(d.get("owned_at_start", false)), "level": 0, "settled_day": 0, "jobs_today": 0,
			"jobs_total": 0, "staff": (d.get("staff_at_start", []) as Array).duplicate()}
	return states[id]

func is_owned(id: String) -> bool:
	return bool(st(id).owned)

func is_open(id: String) -> bool:
	var d: Dictionary = defs.get(id, {})
	if not is_owned(id) and not bool(d.get("npc_owned", false)):
		return false
	var h: Array = d.get("hours", [8, 18])
	if is_closed_day(id, WorldClock.weekday()):
		return false
	return WorldClock.is_between(float(h[0]), float(h[1]))

## JSON numbers are floats and Array.has() compares types strictly (6 is not 6.0), so compare as ints.
func is_closed_day(id: String, weekday: int) -> bool:
	for w in defs.get(id, {}).get("closed_weekdays", []):
		if int(w) == weekday:
			return true
	return false

func level_def(id: String) -> Dictionary:
	var lv: Array = defs.get(id, {}).get("levels", [{}])
	return lv[clampi(int(st(id).level), 0, lv.size() - 1)]

## A job done by the player (a car repaired). Pays on the spot, counted for the day. `job_id` must be unique.
func record_job(id: String, job_id: String) -> bool:
	if not is_owned(id):
		return false
	var pay := int(level_def(id).get("job_pay_cents", 0))
	if not gs.ledger.post("biz:%s:job:%s" % [id, job_id], pay, "biz:%s:job" % id, WorldClock.total_minutes):
		return false
	st(id).jobs_today = int(st(id).jobs_today) + 1
	st(id).jobs_total = int(st(id).jobs_total) + 1
	EventBus.emit_event("business_job_done", {"business": id, "job": job_id, "pay": pay})
	EventBus.money_changed.emit(gs.ledger.balance)
	return true

## Settles every owned business for `day` (called at the next day boundary and on load for days missed).
func settle_day(day: int) -> void:
	for id in defs:
		var s := st(id)
		if not is_owned(id) or int(s.settled_day) >= day:
			continue
		var lv := level_def(id)
		var weekday := (day - 1) % 7
		var staffed: bool = not (s.staff as Array).is_empty() and not is_closed_day(id, weekday)
		var walkin := int(lv.get("walkin_cents", 0)) if staffed else 0
		var cost := int(lv.get("daily_cost_cents", 0)) + int(lv.get("wage_cents", 0)) * (s.staff as Array).size()
		var net := walkin - cost
		var tx := "biz:%s:day:%d" % [id, day]
		if not gs.ledger.post(tx, net, "biz:%s:day" % id, WorldClock.total_minutes):
			# Cannot pay: costs become debt to the supplier instead of a negative balance.
			if not gs.ledger.has_tx(tx):
				gs.add_debt("supplier_" + id, -net, tx + ":debt")
		s.settled_day = day
		s.jobs_today = 0
		EventBus.emit_event("business_settled", {"business": id, "day": day, "net": net})
	EventBus.money_changed.emit(gs.ledger.balance)

func upgrade_cost(id: String) -> int:
	var lv: Array = defs.get(id, {}).get("levels", [])
	var next := int(st(id).level) + 1
	if next >= lv.size():
		return -1
	return int(lv[next].get("upgrade_cents", 0))

func upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or not is_owned(id):
		return false
	var next := int(st(id).level) + 1
	if not Conditions.check(defs[id].levels[next].get("requires", {}), gs):
		return false
	if not gs.ledger.post("biz:%s:upgrade:%d" % [id, next], -cost, "biz:%s:upgrade" % id, WorldClock.total_minutes):
		return false
	st(id).level = next
	EventBus.emit_event("business_upgraded", {"business": id, "level": next})
	EventBus.money_changed.emit(gs.ledger.balance)
	return true

func acquire(id: String) -> bool:
	if is_owned(id):
		return false
	var price := int(defs.get(id, {}).get("price_cents", 0))
	if not gs.ledger.post("biz:%s:buy" % id, -price, "biz:%s:buy" % id, WorldClock.total_minutes):
		return false
	st(id).owned = true
	EventBus.emit_event("business_acquired", {"business": id})
	return true

func to_dict() -> Dictionary:
	return states.duplicate(true)

func from_dict(d: Dictionary) -> void:
	states.clear()
	for id in d:
		if not defs.has(id) or typeof(d[id]) != TYPE_DICTIONARY:
			continue
		var s := st(String(id))
		s.owned = bool(d[id].get("owned", s.owned))
		s.level = clampi(int(d[id].get("level", 0)), 0, (defs[id].get("levels", [{}]) as Array).size() - 1)
		s.settled_day = int(d[id].get("settled_day", 0))
		s.jobs_today = int(d[id].get("jobs_today", 0))
		s.jobs_total = int(d[id].get("jobs_total", 0))
		var staff: Variant = d[id].get("staff", s.staff)
		s.staff = staff if typeof(staff) == TYPE_ARRAY else []
