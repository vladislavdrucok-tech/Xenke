class_name Solver
extends RefCounted
## Exhaustive solver. The tray is fully determined by which tiles were taken (each type leaves
## "taken mod 3" tiles behind), so the four stack heights identify a state: at most 10^4 states
## for 30 tiles. Every move goes through Rules.add_tile(), the same rule the game uses.
##
## Besides the winning line it measures how hard the puzzle feels:
##   p_random  - chance that random tapping wins (low = the order matters)
##   min_peak  - fewest tray slots the best line still has to keep busy (4 = only one slot spare)
##   traps     - reachable positions that look alive but can no longer be won
##   dfs_fails - dead branches a plain left-to-right search walks into before the first win
##   greedy    - whether "take matches first" play without look-ahead wins

const UNSEEN := 0
const WIN := 1
const DEAD := 2
const NO_MOVE := 255

var _layout: Array = []
var _n := 0
var _stride := PackedInt32Array()
var _h := PackedInt32Array()
var _counts := PackedInt32Array()
var _state := PackedByteArray()
var _peak := PackedByteArray()
var _move := PackedByteArray()
var _prob := PackedFloat32Array()
var _smart := PackedFloat32Array()
var _reachable := 0
var _traps := 0
var _losing_moves := 0


static func analyze(layout: Array) -> Dictionary:
	var s := Solver.new()
	return s._run(Rules.layout_to_ints(layout))


func _run(layout: Array) -> Dictionary:
	_layout = layout
	_n = layout.size()
	_stride = PackedInt32Array()
	var size := 1
	_h = PackedInt32Array()
	for i in _n:
		_stride.append(size)
		size *= layout[i].size() + 1
		_h.append(layout[i].size())
	_counts = PackedInt32Array()
	_counts.resize(Rules.TYPE_COUNT)
	_state = PackedByteArray()
	_state.resize(size)
	_peak = PackedByteArray()
	_peak.resize(size)
	_move = PackedByteArray()
	_move.resize(size)
	_prob = PackedFloat32Array()
	_prob.resize(size)
	_smart = PackedFloat32Array()
	_smart.resize(size)
	_reachable = 0
	_traps = 0
	_losing_moves = 0
	var start := size - 1
	if Rules.validate_layout(layout) != "":
		return {"solvable": false, "error": Rules.validate_layout(layout)}
	_visit(start)
	var solvable := _state[start] == WIN
	var solution := []
	var safe_first := 0
	var critical := 0
	if solvable:
		# Follow the line that keeps the tray emptiest.
		_h = PackedInt32Array()
		for i in _n:
			_h.append(layout[i].size())
		var key := start
		var c := PackedInt32Array()
		c.resize(Rules.TYPE_COUNT)
		while key != 0:
			if _is_critical(key, c):
				critical += 1
			var m := _move[key]
			solution.append(m)
			Rules.add_tile(c, _layout[m][_h[m] - 1])
			_h[m] -= 1
			key -= _stride[m]
	# How many first moves keep the puzzle winnable.
	var h0 := PackedInt32Array()
	for i in _n:
		h0.append(layout[i].size())
	var c0 := PackedInt32Array()
	c0.resize(Rules.TYPE_COUNT)
	for i in _n:
		if h0[i] == 0:
			continue
		var t: int = layout[i][h0[i] - 1]
		var c := c0.duplicate()
		var r := Rules.add_tile(c, t)
		if (r & Rules.LOST) == 0 and _state[start - _stride[i]] == WIN:
			safe_first += 1
	var result := {
		"solvable": solvable,
		"solution": solution,
		"states": _reachable,
		"traps": _traps,
		"losing_moves": _losing_moves,
		"p_random": float(_prob[start]),
		"p_careful": float(_smart[start]),
		"critical": critical,
		"min_peak": int(_peak[start]) if solvable else 99,
		"safe_first": safe_first,
		"dfs_fails": _dfs_fail_count(),
		"greedy": greedy_wins(layout),
		"items": Rules.tile_total(layout),
		"types": Rules.types_used(layout),
	}
	result["score"] = difficulty(result)
	return result


func _visit(key: int) -> void:
	_reachable += 1
	if key == 0:
		_state[0] = WIN
		_peak[0] = 0
		_prob[0] = 1.0
		_smart[0] = 1.0
		_move[0] = NO_MOVE
		return
	var best_peak := 255
	var best_move := NO_MOVE
	var psum := 0.0
	var ssum := 0.0
	var moves := 0
	var safe_moves := 0
	for i in _n:
		var hi := _h[i]
		if hi == 0:
			continue
		moves += 1
		var t: int = _layout[i][hi - 1]
		var old := _counts[t]
		var r := Rules.add_tile(_counts, t)
		if r & Rules.LOST:
			_counts[t] = old
			_losing_moves += 1
			continue
		var occ := 0
		for c in _counts:
			occ += c
		var nk := key - _stride[i]
		if _state[nk] == UNSEEN:
			_h[i] = hi - 1
			_visit(nk)
			_h[i] = hi
		_counts[t] = old
		psum += _prob[nk]
		ssum += _smart[nk]
		safe_moves += 1
		if _state[nk] == WIN:
			var p := maxi(occ, _peak[nk])
			if p < best_peak:
				best_peak = p
				best_move = i
	_prob[key] = psum / float(moves) if moves > 0 else 0.0
	_smart[key] = ssum / float(safe_moves) if safe_moves > 0 else 0.0
	if best_move != NO_MOVE:
		_state[key] = WIN
		_peak[key] = best_peak
		_move[key] = best_move
	else:
		_state[key] = DEAD
		_peak[key] = 255
		_move[key] = NO_MOVE
		_traps += 1


## A position where a move that does not lose at once still walks into a dead end:
## the player has to think, not just avoid filling the tray.
func _is_critical(key: int, c: PackedInt32Array) -> bool:
	for i in _n:
		var hi := _h[i]
		if hi == 0:
			continue
		var t: int = _layout[i][hi - 1]
		var cc := c.duplicate()
		if Rules.add_tile(cc, t) & Rules.LOST:
			continue
		if _state[key - _stride[i]] == DEAD:
			return true
	return false


## Dead branches met by a plain left-to-right depth-first search before its first win.
func _dfs_fail_count() -> int:
	var h := PackedInt32Array()
	for i in _n:
		h.append(_layout[i].size())
	var c := PackedInt32Array()
	c.resize(Rules.TYPE_COUNT)
	var dead := PackedByteArray()
	dead.resize(_state.size())
	var fails := [0]
	_dfs(_state.size() - 1, h, c, dead, fails)
	return fails[0]


func _dfs(key: int, h: PackedInt32Array, c: PackedInt32Array, dead: PackedByteArray, fails: Array) -> bool:
	if key == 0:
		return true
	for i in _n:
		var hi := h[i]
		if hi == 0:
			continue
		var t: int = _layout[i][hi - 1]
		var old := c[t]
		var r := Rules.add_tile(c, t)
		if r & Rules.LOST:
			c[t] = old
			fails[0] += 1
			continue
		var nk := key - _stride[i]
		var ok := false
		if dead[nk] == 0:
			h[i] = hi - 1
			ok = _dfs(nk, h, c, dead, fails)
			h[i] = hi
		c[t] = old
		if ok:
			return true
	dead[key] = 1
	fails[0] += 1
	return false


## A player who never looks ahead: finish a triple if possible, else make a pair, else start a
## new type, preferring a stack whose next tile already matches the tray. Returns true on a win.
static func greedy_wins(layout: Array) -> bool:
	var gs := GameState.new()
	gs.setup(layout)
	while not gs.is_over():
		var best := -1
		var best_v := -1000
		for i in gs.heights.size():
			if gs.heights[i] == 0:
				continue
			var t := gs.top_type(i)
			var c := gs.counts.duplicate()
			var r := Rules.add_tile(c, t)
			var v := 0
			if r & Rules.CLEARED:
				v = 30
			elif r & Rules.LOST:
				v = -100
			elif gs.counts[t] == 1:
				v = 20
			else:
				v = 10
			if gs.heights[i] >= 2:
				var below: int = gs.layout[i][gs.heights[i] - 2]
				if c[below] > 0:
					v += 3
			if v > best_v:
				best_v = v
				best = i
		if best < 0:
			return false
		gs.take(best)
	return gs.won


## One number for "how hard does this feel". Tile count alone is deliberately not part of it:
## it counts the luck a careful player (never taps a tile that fills the tray at once) needs,
## the decisions on the winning line where a harmless-looking tap is already lost, whether
## pair-first play without look-ahead fails, and how much the tray must hold on the best line.
static func difficulty(m: Dictionary) -> float:
	if not m.get("solvable", false):
		return 99.0
	var p: float = maxf(m["p_careful"], 0.000001)
	var luck := -log(p) / log(2.0)
	var s := luck * 1.0
	s += float(m["critical"]) * 0.35
	if int(m["min_peak"]) >= 4:
		s += 1.0
	if not m["greedy"]:
		s += 2.0
	if int(m["safe_first"]) <= 1 and int(m["critical"]) > 0:
		s += 0.5
	s += log(1.0 + float(m["dfs_fails"])) / log(2.0) * 0.15
	return snappedf(s, 0.01)
