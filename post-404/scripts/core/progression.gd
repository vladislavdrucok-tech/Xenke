class_name Progression
extends RefCounted
## Player level, XP curve and the gradual unlock of mechanics.

## Mechanic -> postmaster level at which it starts to appear.
const UNLOCKS := {
	"present": 2,
	"collectibles": 3,
	"damaged": 3,
	"urgent": 4,
	"series": 5,
	"ev_golden": 5,
	"mystery": 6,
	"daily": 6,
	"hazard": 7,
	"ev_calendar": 8,
	"ev_cat": 8,
	"ev_mirror": 9,
	"paradox": 10,
	"ev_storm": 11,
	"ev_blackout": 12,
	"boomerang": 14,
}

const UNLOCK_ORDER := ["present", "collectibles", "damaged", "urgent", "series", "ev_golden", "mystery",
	"daily", "hazard", "ev_calendar", "ev_cat", "ev_mirror", "paradox", "ev_storm", "ev_blackout", "boomerang"]

const MAX_LEVEL := 60


static func xp_for_next(level: int) -> int:
	# Early levels are quick (one or two shifts), later ones slow down gently.
	return int(round(50.0 + 22.0 * pow(float(level - 1), 1.2)))


static func is_unlocked(mechanic: String, level: int) -> bool:
	return level >= int(UNLOCKS.get(mechanic, 999))


static func unlocked_set(level: int) -> Dictionary:
	var out := {}
	for k in UNLOCKS:
		if level >= int(UNLOCKS[k]):
			out[k] = true
	return out


## Adds XP to a profile-like dictionary {xp, level}; returns levels gained.
static func add_xp(state: Dictionary, amount: int) -> Array:
	var gained := []
	state["xp"] = int(state.get("xp", 0)) + amount
	while int(state["level"]) < MAX_LEVEL and int(state["xp"]) >= xp_for_next(int(state["level"])):
		state["xp"] = int(state["xp"]) - xp_for_next(int(state["level"]))
		state["level"] = int(state["level"]) + 1
		gained.append(int(state["level"]))
	if int(state["level"]) >= MAX_LEVEL:
		state["xp"] = min(int(state["xp"]), xp_for_next(MAX_LEVEL))
	return gained


static func newly_unlocked(old_level: int, new_level: int) -> Array:
	var out := []
	for k in UNLOCK_ORDER:
		var l := int(UNLOCKS[k])
		if l > old_level and l <= new_level:
			out.append(k)
	return out


## 0..1 difficulty for the generator: grows with level and with time spent in
## the current shift, but saturates so the game never becomes unfair.
static func difficulty(level: int, parcels_in_shift: int) -> float:
	var by_level := clampf(float(level - 1) / 20.0, 0.0, 0.7)
	var by_shift := clampf(float(parcels_in_shift) / 80.0, 0.0, 0.3)
	return clampf(by_level + by_shift, 0.0, 1.0)
