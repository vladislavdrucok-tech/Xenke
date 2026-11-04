extends Node
## The campaign's persistent model (autoload "GameState"): flags, money, quests, relationships, memories, businesses,
## inventory, location, vehicles. It holds the systems (plain objects with their own rules) and the one effect
## language that dialogue / quests / scripts use to change them. Scenes read it; they never own saved state.

const START_DISTRICT := "santa_lucia"
const START_SPAWN := "station_arrival"
const START_CASH := 1250       # $12.50 - what Enzo has in his pocket coming home

var flags := {}
var ledger := Ledger.new()
var quests := QuestSystem.new()
var relationships := Relationships.new()
var memory := NPCMemory.new()
var businesses := BusinessSystem.new()
var inventory := {}            # item_id -> count
var debts := {}                # lender_id -> cents owed (positive)
var once := {}                 # effect keys already applied (dialogue choices, one-off rewards)
var location := {"district": START_DISTRICT, "spawn": START_SPAWN, "pos": null, "facing": "S", "in_vehicle": ""}
var vehicles := {}             # vehicle instance id -> {def, district, pos, heading, damage, fuel}
var wanted := {"level": 0, "heat": 0.0, "last_seen_min": 0}
var profile_id := ""
var seed_value := 0
var playtime_s := 0.0

func _ready() -> void:
	EventBus.game_event.connect(_on_game_event)
	EventBus.day_changed.connect(_on_day_changed)
	new_game()

func new_game(seed_in: int = 1947) -> void:
	flags = {}
	ledger = Ledger.new()
	quests = QuestSystem.new()
	quests.setup(self, DataRegistry.table("quests"))
	relationships = Relationships.new()
	memory = NPCMemory.new()
	businesses = BusinessSystem.new()
	businesses.setup(self, DataRegistry.table("businesses"))
	inventory = {}
	debts = {}
	once = {}
	location = {"district": START_DISTRICT, "spawn": START_SPAWN, "pos": null, "facing": "S", "in_vehicle": ""}
	vehicles = {}
	wanted = {"level": 0, "heat": 0.0, "last_seen_min": 0}
	profile_id = "p%d" % (Time.get_unix_time_from_system() as int)
	seed_value = seed_in
	playtime_s = 0.0
	WorldClock.set_total(8 * 60)
	ledger.post("start:pocket", START_CASH, "start", 0)
	for id in DataRegistry.table("vehicles"):
		var v: Dictionary = DataRegistry.table("vehicles")[id]
		if v.has("start"):
			vehicles[v.start.instance] = {"def": id, "district": v.start.district, "pos": v.start.pos,
				"heading": float(v.start.get("heading", 0.0)), "damage": 0, "fuel": int(v.get("fuel_max", 100)), "owner": v.start.get("owner", "")}
	for npc in DataRegistry.table("npcs"):
		var start: Dictionary = DataRegistry.table("npcs")[npc].get("relationship_start", {})
		for axis in start:
			relationships.change(npc, axis, int(start[axis]))
	for d in DataRegistry.table("quests").get("_start", {}).get("debts", []):
		add_debt(d.lender, int(d.cents), "start:debt:" + d.lender)
	for q in DataRegistry.table("quests").get("_start", {}).get("quests", []):
		quests.start(q)

func _process(delta: float) -> void:
	if WorldClock.running:
		playtime_s += delta

# ------------------------------------------------------------------ queries
func get_flag(f: String) -> Variant:
	return flags.get(f, null)

func set_flag(f: String, v: Variant) -> void:
	if flags.get(f, null) == v:
		return
	flags[f] = v
	EventBus.flag_changed.emit(f, v)

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, n: int) -> void:
	var c := maxi(item_count(id) + n, 0)
	if c == 0:
		inventory.erase(id)
	else:
		inventory[id] = c
	EventBus.emit_event("inventory_changed", {"item": id, "count": c})

func total_debt() -> int:
	var t := 0
	for k in debts:
		t += int(debts[k])
	return t

func add_debt(lender: String, cents: int, tx: String) -> void:
	if once.has(tx):
		return
	once[tx] = true
	debts[lender] = int(debts.get(lender, 0)) + cents

## Pays up to `cents` of a debt from the ledger. Returns what was paid.
func pay_debt(lender: String, cents: int, tx: String) -> int:
	var amount := mini(mini(cents, int(debts.get(lender, 0))), ledger.balance)
	if amount <= 0:
		return 0
	if not ledger.post(tx, -amount, "debt:" + lender, WorldClock.total_minutes):
		return 0
	debts[lender] = int(debts[lender]) - amount
	if int(debts[lender]) <= 0:
		debts.erase(lender)
	EventBus.money_changed.emit(ledger.balance)
	EventBus.emit_event("debt_paid", {"lender": lender, "cents": amount, "left": int(debts.get(lender, 0))})
	return amount

## Money from a story reward or a price; tx makes it pay once. Returns false if not affordable / duplicate.
func pay(cents: int, tx: String, reason: String) -> bool:
	var ok := ledger.post(tx, cents, reason, WorldClock.total_minutes)
	if ok:
		EventBus.money_changed.emit(ledger.balance)
	return ok

# ------------------------------------------------------------------ effects
## Applies a list of declarative effects. `key` identifies this application: the same key never applies twice
## (a repeated dialogue choice, a replayed quest completion), unless an effect list says {"repeatable": true}.
## Effects: {"set_flag": {name: value}}, {"rel": {"npc", "axis", "delta"}}, {"money": {"cents", "reason"}},
##   {"item": {"id", "n"}}, {"start_quest": id}, {"fail_quest": id}, {"event": {"id", "data"}},
##   {"remember": {"npc", "event", "importance", "how"}}, {"debt": {"lender", "cents"}},
##   {"pay_debt": {"lender", "cents"}}, {"toast": key}, {"business_job": business_id}, {"advance_hours": n}
func apply_effects(effects: Array, key: String) -> void:
	if effects.is_empty():
		return
	var repeatable := false
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and e.get("repeatable", false):
			repeatable = true
	if not repeatable:
		if once.has(key):
			return
		once[key] = true
	var i := 0
	for e in effects:
		i += 1
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var sub := "%s#%d" % [key, i]
		for k in e:
			var v: Variant = e[k]
			match k:
				"repeatable":
					pass
				"set_flag":
					for f in v:
						set_flag(f, v[f])
				"rel":
					var nv := relationships.change(v.npc, v.axis, int(v.delta))
					EventBus.relationship_changed.emit(v.npc, v.axis, nv)
				"money":
					pay(int(v.cents), sub if not repeatable else "%s@%d" % [sub, WorldClock.total_minutes], String(v.get("reason", key)))
				"item":
					add_item(v.id, int(v.get("n", 1)))
				"start_quest":
					quests.start(v)
				"fail_quest":
					quests.fail(v)
				"event":
					EventBus.emit_event(v.id, v.get("data", {}))
				"remember":
					memory.remember(v.npc, v.event, WorldClock.total_minutes, int(v.get("importance", 2)), String(v.get("how", "seen")))
				"debt":
					add_debt(v.lender, int(v.cents), sub)
				"pay_debt":
					pay_debt(v.lender, int(v.get("cents", 1 << 30)), sub)
				"toast":
					EventBus.toast.emit(String(v), [])
				"business_job":
					businesses.record_job(String(v), sub)
				"advance_hours":
					WorldClock.advance(int(v) * 60)
				_:
					push_error("GameState: unknown effect '%s' in %s" % [k, key])

const EFFECT_KEYS := ["repeatable", "set_flag", "rel", "money", "item", "start_quest", "fail_quest", "event", "remember",
	"debt", "pay_debt", "toast", "business_job", "advance_hours"]

# ------------------------------------------------------------------ world reactions
func _on_game_event(id: String, data: Dictionary) -> void:
	quests.on_event(id, data)
	# Witnessed memories: whoever the event lists as witnesses remembers it (world code decides who could see).
	for w in data.get("witnesses", []):
		memory.remember(w, id, WorldClock.total_minutes, int(data.get("importance", 1)), "seen", {})

func _on_day_changed(day: int) -> void:
	businesses.settle_day(day - 1)
	memory.decay(WorldClock.total_minutes)

# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	return {
		"profile_id": profile_id, "seed": seed_value, "playtime_s": playtime_s,
		"time": WorldClock.total_minutes,
		"flags": flags.duplicate(true), "ledger": ledger.to_dict(), "quests": quests.to_dict(),
		"relationships": relationships.to_dict(), "memory": memory.to_dict(), "businesses": businesses.to_dict(),
		"inventory": inventory.duplicate(), "debts": debts.duplicate(), "once": once.keys(),
		"location": location.duplicate(true), "vehicles": vehicles.duplicate(true), "wanted": wanted.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	new_game(int(d.get("seed", 1947)))
	# new_game() posted start entries and started quests; the save replaces all of that.
	profile_id = String(d.get("profile_id", profile_id))
	playtime_s = float(d.get("playtime_s", 0.0))
	WorldClock.set_total(int(d.get("time", 8 * 60)))
	flags = _dict(d.get("flags"))
	ledger = Ledger.from_dict(_dict(d.get("ledger")))
	quests = QuestSystem.new()
	quests.setup(self, DataRegistry.table("quests"))
	quests.from_dict(_dict(d.get("quests")))
	relationships.from_dict(_dict(d.get("relationships")))
	memory.from_dict(_dict(d.get("memory")))
	businesses = BusinessSystem.new()
	businesses.setup(self, DataRegistry.table("businesses"))
	businesses.from_dict(_dict(d.get("businesses")))
	inventory = {}
	var inv := _dict(d.get("inventory"))
	for k in inv:
		if DataRegistry.has("items", k) and int(inv[k]) > 0:
			inventory[k] = int(inv[k])
	debts = {}
	var db := _dict(d.get("debts"))
	for k in db:
		if int(db[k]) > 0:
			debts[String(k)] = int(db[k])
	once = {}
	for k in d.get("once", []):
		once[String(k)] = true
	var loc := _dict(d.get("location"))
	if DataRegistry.table("districts").has(String(loc.get("district", ""))):
		location = {"district": String(loc.district), "spawn": String(loc.get("spawn", "")), "pos": loc.get("pos", null),
			"facing": String(loc.get("facing", "S")), "in_vehicle": String(loc.get("in_vehicle", ""))}
	var vs := _dict(d.get("vehicles"))
	for k in vs:
		if typeof(vs[k]) == TYPE_DICTIONARY and DataRegistry.has("vehicles", String(vs[k].get("def", ""))):
			vehicles[String(k)] = vs[k]
	wanted = {"level": 0, "heat": 0.0, "last_seen_min": 0}   # chases never resume on load (safe resume policy)
	EventBus.money_changed.emit(ledger.balance)

func _dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}
