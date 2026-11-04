class_name Rules
extends RefCounted
## Sorting rules shared by the generator, the solver and the UI.
## Destinations are abstract; swipe directions map onto them (the mirror
## anomaly swaps the left/right mapping, nothing else ever changes it).

enum Dest { PAST, PRESENT, FUTURE, QUARANTINE }
enum Dir { LEFT, UP, RIGHT, DOWN }

const BASE_YEAR := 2038
const DEST_NAMES := ["past", "present", "future", "quarantine"]


static func make(present_year: int = BASE_YEAR, mirrored: bool = false) -> Dictionary:
	return {"present_year": present_year, "mirrored": mirrored}


static func dest_for_year(year: int, present_year: int) -> int:
	if year < present_year:
		return Dest.PAST
	if year > present_year:
		return Dest.FUTURE
	return Dest.PRESENT


static func dir_to_dest(dir: int, mirrored: bool) -> int:
	match dir:
		Dir.LEFT:
			return Dest.FUTURE if mirrored else Dest.PAST
		Dir.RIGHT:
			return Dest.PAST if mirrored else Dest.FUTURE
		Dir.UP:
			return Dest.PRESENT
		_:
			return Dest.QUARANTINE


static func dest_to_dir(dest: int, mirrored: bool) -> int:
	match dest:
		Dest.PAST:
			return Dir.RIGHT if mirrored else Dir.LEFT
		Dest.FUTURE:
			return Dir.LEFT if mirrored else Dir.RIGHT
		Dest.PRESENT:
			return Dir.UP
		_:
			return Dir.DOWN


## The correct destination of a parcel under the current rules.
## Uses the full (hidden) data of the parcel.
static func judge(p: Dictionary, rules: Dictionary) -> int:
	if p.get("hazard", false):
		return Dest.QUARANTINE
	var riddle: String = p.get("riddle", "")
	if riddle != "":
		return int(p.get("riddle_dest", Dest.PAST))
	return dest_for_year(int(p["year"]), int(rules["present_year"]))


## All destinations that are consistent with what the player can SEE on the
## parcel. A fair parcel yields exactly one destination.
static func deduce(p: Dictionary, rules: Dictionary) -> Array:
	if p.get("hazard", false):
		return [Dest.QUARANTINE]
	var riddle: String = p.get("riddle", "")
	if riddle != "":
		# Riddles describe eras relative to the real year 2038; they are only
		# fair while the calendar is not shifted.
		if int(rules["present_year"]) != BASE_YEAR:
			return [Dest.PAST, Dest.PRESENT, Dest.FUTURE]
		return [int(p.get("riddle_dest", Dest.PAST))]
	var shown: String = p.get("shown", str(p["year"]))
	return dests_for_pattern(shown, int(rules["present_year"]))


## Every destination reachable by some year that matches the pattern
## ("20?5" — '?' is any digit, first digit 1..9).
static func dests_for_pattern(pattern: String, present_year: int) -> Array:
	var out := []
	var years := expand_pattern(pattern)
	for y in years:
		var d := dest_for_year(y, present_year)
		if not out.has(d):
			out.append(d)
	return out


static func expand_pattern(pattern: String) -> Array:
	var results := [""]
	for i in pattern.length():
		var c := pattern[i]
		var next := []
		for r in results:
			if c == "?":
				for digit in 10:
					if i == 0 and digit == 0:
						continue
					next.append(r + str(digit))
			else:
				next.append(r + c)
		results = next
	var years := []
	for r in results:
		years.append(int(r))
	return years


static func is_fair(p: Dictionary, rules: Dictionary) -> bool:
	var d := deduce(p, rules)
	return d.size() == 1 and int(d[0]) == judge(p, rules)
