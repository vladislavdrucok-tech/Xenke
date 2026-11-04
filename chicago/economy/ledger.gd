class_name Ledger
extends RefCounted
## Money of one owner (the player), in integer cents - never floats. Every change is a transaction with a stable ID
## and a reason; posting an ID that is already in the ledger does nothing, so a reward, a wage or a day's takings
## can never be paid twice (after a reload, a repeated dialogue, a replayed event).

const MAX_BALANCE := 100_000_000_00   # $100M: a sanity bound, not a design limit
const MAX_ENTRIES := 2000             # older entries are folded into one "carried" line (IDs kept)

var balance: int = 0
var entries: Array = []               # [{id, cents, reason, minute}]
var _ids := {}                        # every ID ever posted (survives folding)

## Posts a transaction. Returns false (and changes nothing) for a duplicate ID or when a payment would take the
## balance below zero; use can_afford() first for UI.
func post(id: String, cents: int, reason: String, minute: int = 0) -> bool:
	if id.is_empty() or _ids.has(id):
		return false
	if balance + cents < 0 or balance + cents > MAX_BALANCE:
		return false
	balance += cents
	_ids[id] = true
	entries.append({"id": id, "cents": cents, "reason": reason, "minute": minute})
	if entries.size() > MAX_ENTRIES:
		# Fold the oldest real entry into the single "carried" line at the front (IDs stay in _ids).
		if entries[0].get("reason", "") != "carried":
			entries.push_front({"id": "carried", "cents": 0, "reason": "carried", "minute": int(entries[0].minute)})
		var old: Dictionary = entries.pop_at(1)
		entries[0].cents = int(entries[0].cents) + int(old.cents)
	return true

func has_tx(id: String) -> bool:
	return _ids.has(id)

func can_afford(cents: int) -> bool:
	return cents <= balance

## Sum of entries whose reason starts with `prefix` (reports: "biz:repair_shop").
func total(prefix: String) -> int:
	var t := 0
	for e in entries:
		if String(e.reason).begins_with(prefix):
			t += int(e.cents)
	return t

## Sum of all entries must equal the balance; tests and save validation use it.
func is_consistent() -> bool:
	var t := 0
	for e in entries:
		t += int(e.cents)
	return t == balance

func to_dict() -> Dictionary:
	return {"balance": balance, "entries": entries.duplicate(true), "ids": _ids.keys()}

static func from_dict(d: Dictionary) -> Ledger:
	var l := Ledger.new()
	l.balance = int(d.get("balance", 0))
	for e in d.get("entries", []):
		if typeof(e) == TYPE_DICTIONARY and e.has("id") and e.has("cents"):
			l.entries.append({"id": String(e.id), "cents": int(e.cents), "reason": String(e.get("reason", "")),
				"minute": int(e.get("minute", 0))})
	for id in d.get("ids", []):
		l._ids[String(id)] = true
	for e in l.entries:
		l._ids[e.id] = true
	return l

static func dollars(cents: int) -> String:
	var neg := "-" if cents < 0 else ""
	var c := absi(cents)
	return "%s$%d.%02d" % [neg, c / 100, c % 100]
