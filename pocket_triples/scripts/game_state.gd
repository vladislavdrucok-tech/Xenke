class_name GameState
extends RefCounted
## Logical state of one puzzle: what is left in the four stacks and what sits in the five tray
## slots. Pure data, no nodes: the board animates towards this state, the save file stores it,
## the tests replay solutions through take().

var layout: Array = []            # initial stacks, bottom -> top (never changes)
var heights := PackedInt32Array() # tiles still in each stack
var tray: Array = []              # TRAY_SIZE slots, tile type or -1
var counts := PackedInt32Array()  # tiles of each type in the tray
var lost := false
var won := false


func setup(p_layout: Array) -> void:
	layout = Rules.layout_to_ints(p_layout)
	heights = PackedInt32Array()
	for s in layout:
		heights.append(s.size())
	tray = []
	for i in Rules.TRAY_SIZE:
		tray.append(-1)
	counts = PackedInt32Array()
	counts.resize(Rules.TYPE_COUNT)
	lost = false
	won = false


func is_over() -> bool:
	return lost or won


func can_take(stack: int) -> bool:
	return not is_over() and stack >= 0 and stack < heights.size() and heights[stack] > 0


func top_type(stack: int) -> int:
	if heights[stack] <= 0:
		return -1
	return layout[stack][heights[stack] - 1]


func tray_count() -> int:
	var n := 0
	for t in tray:
		if t >= 0:
			n += 1
	return n


func tiles_left() -> int:
	var n := 0
	for h in heights:
		n += h
	return n


## One move: the top tile of `stack` goes to the first free tray slot, then the shared rule decides
## whether a triple vanishes and whether the tray is full. Returns a description for the board.
func take(stack: int) -> Dictionary:
	if not can_take(stack):
		return {"ok": false}
	var t: int = layout[stack][heights[stack] - 1]
	heights[stack] -= 1
	var slot := tray.find(-1)
	tray[slot] = t
	var r := Rules.add_tile(counts, t)
	var cleared: Array = []
	if r & Rules.CLEARED:
		for s in Rules.TRAY_SIZE:
			if tray[s] == t:
				cleared.append(s)
				tray[s] = -1
	lost = (r & Rules.LOST) != 0
	won = not lost and tiles_left() == 0 and tray_count() == 0
	return {
		"ok": true, "stack": stack, "type": t, "slot": slot,
		"cleared": cleared, "lost": lost, "won": won,
	}


func snapshot() -> Dictionary:
	return {"h": Array(heights), "tray": tray.duplicate(), "lost": lost, "won": won}


func restore(snap: Dictionary) -> bool:
	var h: Array = snap.get("h", [])
	var tr_: Array = snap.get("tray", [])
	if h.size() != layout.size() or tr_.size() != Rules.TRAY_SIZE:
		return false
	var new_heights := PackedInt32Array()
	for i in h.size():
		var v := int(h[i])
		if v < 0 or v > layout[i].size():
			return false
		new_heights.append(v)
	var new_counts := PackedInt32Array()
	new_counts.resize(Rules.TYPE_COUNT)
	var new_tray := []
	for v in tr_:
		var t := int(v)
		if t < -1 or t >= Rules.TYPE_COUNT:
			return false
		new_tray.append(t)
		if t >= 0:
			new_counts[t] += 1
	# The tray must be exactly what the taken tiles leave behind (taken mod 3 of each type).
	var taken := PackedInt32Array()
	taken.resize(Rules.TYPE_COUNT)
	for i in layout.size():
		for j in range(new_heights[i], layout[i].size()):
			taken[layout[i][j]] += 1
	for t in Rules.TYPE_COUNT:
		if taken[t] % Rules.MATCH != new_counts[t]:
			return false
	heights = new_heights
	tray = new_tray
	counts = new_counts
	lost = bool(snap.get("lost", false))
	won = bool(snap.get("won", false))
	return true
