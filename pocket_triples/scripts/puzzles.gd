class_name Puzzles
extends RefCounted
## Where puzzles come from: the 30 hand-picked levels, the tiers of "Another Puzzle" and the
## verified spare pool used when the on-device generator runs out of time.

const LEVEL_COUNT := 30
const LEVELS_PATH := "res://data/levels.json"
const FALLBACK_PATH := "res://data/fallback.json"

## "Another Puzzle" cycles through these so the endless mode keeps a rhythm of calm and tense boards.
const ENDLESS_TIERS := [
	{"items": [18, 24], "types": [4, 4], "score": [3.0, 6.0]},
	{"items": [21, 27], "types": [4, 5], "score": [6.0, 9.0]},
	{"items": [24, 30], "types": [5, 5], "score": [9.0, 12.5]},
	{"items": [21, 27], "types": [4, 5], "score": [6.0, 9.0]},
	{"items": [24, 30], "types": [4, 5], "score": [8.0, 11.5]},
]

static var _levels: Array = []
static var _fallback: Array = []


static func endless_tier(index: int) -> Dictionary:
	return ENDLESS_TIERS[posmod(index, ENDLESS_TIERS.size())]


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func normalize(p: Dictionary) -> Dictionary:
	var out := p.duplicate(true)
	out["stacks"] = Rules.layout_to_ints(p.get("stacks", []))
	var sol := []
	for v in p.get("solution", []):
		sol.append(int(v))
	out["solution"] = sol
	for k in ["seed", "attempt", "items", "types", "level", "min_peak", "critical", "tier"]:
		if out.has(k):
			out[k] = int(out[k])
	return out


static func levels() -> Array:
	if _levels.is_empty():
		for p in _load_json(LEVELS_PATH).get("levels", []):
			_levels.append(normalize(p))
	return _levels


static func level(n: int) -> Dictionary:
	var all := levels()
	if n < 1 or n > all.size():
		return {}
	return all[n - 1].duplicate(true)


static func fallback() -> Array:
	if _fallback.is_empty():
		for p in _load_json(FALLBACK_PATH).get("puzzles", []):
			_fallback.append(normalize(p))
	return _fallback


static func fallback_puzzle(index: int) -> Dictionary:
	var pool := fallback()
	if pool.is_empty():
		return level(LEVEL_COUNT)
	return pool[posmod(index, pool.size())].duplicate(true)
