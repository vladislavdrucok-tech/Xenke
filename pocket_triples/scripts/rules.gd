class_name Rules
extends RefCounted
## The one rule of Pocket Triples. The game (GameState) and the solver both call add_tile(),
## so a move means exactly the same thing during play, during generation and in the tests.

const STACKS := 4
const TRAY_SIZE := 5
const MATCH := 3
const TYPE_COUNT := 5

## add_tile() result bits.
const CLEARED := 1
const LOST := 2

## Puts one tile of type t into the tray (counts = tiles of each type now in the tray).
## Order of the rule: add the tile, remove the triple if one formed, only then look at the tray.
## A fifth tile that completes a triple therefore never loses.
static func add_tile(counts: PackedInt32Array, t: int) -> int:
	var result := 0
	counts[t] += 1
	if counts[t] >= MATCH:
		counts[t] -= MATCH
		result |= CLEARED
	var total := 0
	for c in counts:
		total += c
	if total >= TRAY_SIZE:
		result |= LOST
	return result


## A layout is an Array of STACKS arrays of tile types, each listed bottom -> top.
static func validate_layout(layout: Array) -> String:
	if layout.size() != STACKS:
		return "layout must have %d stacks" % STACKS
	var per_type := PackedInt32Array()
	per_type.resize(TYPE_COUNT)
	var total := 0
	for s in layout:
		if not (s is Array):
			return "stack is not an array"
		for t in s:
			if typeof(t) != TYPE_INT and typeof(t) != TYPE_FLOAT:
				return "tile is not a number"
			var ti := int(t)
			if ti < 0 or ti >= TYPE_COUNT:
				return "tile type out of range"
			per_type[ti] += 1
			total += 1
	if total == 0:
		return "empty layout"
	for c in per_type:
		if c % MATCH != 0:
			return "a tile type count is not a multiple of three"
	return ""


static func layout_to_ints(layout: Array) -> Array:
	var out := []
	for s in layout:
		var col := []
		for t in s:
			col.append(int(t))
		out.append(col)
	return out


static func tile_total(layout: Array) -> int:
	var n := 0
	for s in layout:
		n += s.size()
	return n


static func types_used(layout: Array) -> int:
	var seen := {}
	for s in layout:
		for t in s:
			seen[int(t)] = true
	return seen.size()
