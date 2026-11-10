extends RefCounted
class_name Sim
## Deep Bounce rules and physics. Pure data, no nodes: the same state and the same aim angle always give
## the same result. Fixed step of 1/60 s; balls travel in straight segments between contacts (swept circle
## against walls and rectangles with rounded Minkowski corners), so nothing tunnels through stone.

const COLS := 7
const CELL := 92.0
const FIELD_X0 := 38.0
const FIELD_X1 := FIELD_X0 + COLS * CELL            # 682
const DANGER_Y := 250.0                             # the line under the cannon
const VIS_ROWS := 10
const FLOOR_Y := DANGER_Y + VIS_ROWS * CELL         # 1170
const BUFFER_ROWS := 4                              # rows already generated below the floor
const GAP := 3.0                                    # inset of a block rect inside its cells
const BALL_R := 11.0
const SPEED := 1380.0
const DT := 1.0 / 60.0
const PIVOT := Vector2(360.0, 120.0)                # barrel hinge inside the arch
const BARREL := 84.0                                # hinge to muzzle: balls leave the barrel tip
const RETURN_Y := DANGER_Y - 6.0                    # a ball moving up at or above this line is back home
const CEILING_Y := 60.0                             # no ball may ever be above this (top of the arch)
const FIRE_EVERY := 4                               # ticks between two balls of a volley
const MIN_VY := 0.12                                # minimum |vy|/speed (~7 degrees), no endless horizontal loops
const BALL_MAX_TICKS := 60 * 20                     # a ball flying longer is recalled to the cannon
const VOLLEY_MAX_TICKS := 60 * 60                   # hard cap: a volley always ends
const START_BALLS := 8
const MAX_BALLS := 32
const BALLS_STEP := 2
const UPGRADE_EVERY := 4
const MAX_LEVEL := 3
const HEAVY_DMG := [1, 2, 3, 4]
const ZAP_DMG := [0, 1, 2, 3]
const ZAP_RADIUS := 120.0
const MAXED_BONUS := 15
const EPS := 1e-9

enum { PH_AIM, PH_VOLLEY, PH_UPGRADE, PH_OVER }
enum { K_NORMAL, K_HEAVY, K_ELECTRIC }
enum { H_NONE, H_WALL, H_FLOOR, H_BLOCK, H_RETURN }

class Ball:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var k := 0          # kind
	var hits := 0       # direct hits of this ball (electric counter)
	var life := 0       # ticks in flight
	var st := 1         # 1 flying, 2 returned, 3 recalled
	var idx := 0        # position in the volley, 0-based

# --- run state (everything below is saved) ---
var seed := 1
var depth := 0
var volleys := 0
var balls := START_BALLS
var heavy := 0
var electric := 0
var phase := PH_AIM
var blocks := {}            # id -> Dictionary {id,c,r,w,h,hp,mhp,v,g,vein}
var grid := {}              # r*COLS+c (absolute row) -> id
var next_id := 1
var gen_rows := 0           # absolute index of the next row to generate
var top := 0                # absolute row index shown at visible row 0
var run_gems := 0           # crystals found in this run
var unclaimed := 0          # crystals not yet moved to the wallet (the wallet lives in the save)
var upgrade_opts: Array = []
var picks := 0
var gen := 2                # layout generator: 1 = random rows (release 1.0), 2 = groups, side passages, pockets
var band_kind := -1         # last band template of generator 2 (open and compact bands alternate)
var stats := {"destroyed": 0, "zaps": 0, "best_volley": 0, "bonus": 0}
var aim := PI * 0.5

# --- current volley ---
var v_tick := 0
var v_total := 0
var v_launched := 0
var v_balls: Array = []
var v_damage := 0
var v_hits := 0             # direct ball-to-stone hits in this volley (layout evaluation)
var v_angle := PI * 0.5

# difficulty curve (tuned with tests/balance.gd)
var hp_a := 2.0
var hp_b := 0.3
var hp_c := 0.65
var hp_d := 0.02             # slow extra growth with depth squared: long runs do end
var open_soft := 0.8        # the first rows are this much softer, easing out over `open_len` m
var open_len := 12.0
var start_empty := 5        # visible rows without stones at the start of a run
var open_top := 0.45        # opening board: strength factor of its top row ...
var open_bottom := 1.3      # ... and of its bottom row (those stones have many turns before the line)
var open_dens := 1.3        # opening bands are this much denser
var band_k := 0.14          # rubber band strength (0 = off)
var band_target := 5.0      # rows in use the rubber band aims at
var band_min := 0.7
var band_max := 1.7
var dens0 := 0.42
var dens_k := 0.005
var dens_max := 0.66

var events: Array = []      # consumed by the view: hits, breaks, zaps, returns
var record_events := true

# cast result (members instead of out-params: no allocations in the hot loop)
var _ht := 1.0
var _hnx := 0.0
var _hny := 0.0
var _hkind := H_NONE
var _hid := 0

# ---------------------------------------------------------------- setup

func new_run(run_seed: int) -> void:
	seed = run_seed & 0x7FFFFFFF
	depth = 0
	volleys = 0
	balls = START_BALLS
	heavy = 0
	electric = 0
	phase = PH_AIM
	blocks = {}
	grid = {}
	next_id = 1
	top = 0
	gen_rows = start_empty  # the upper rows start empty: room to learn the ricochet and time before the line
	band_kind = -1
	run_gems = 0
	unclaimed = 0
	upgrade_opts = []
	picks = 0
	stats = {"destroyed": 0, "zaps": 0, "best_volley": 0, "bonus": 0}
	aim = PI * 0.5
	v_balls = []
	events = []
	_ensure_rows(true)

static func mix(a: int, b: int) -> int:
	var h := ((a & 0xFFFFFFFF) * 374761393 + (b & 0xFFFFFFFF) * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0x7FFFFFFF

# ---------------------------------------------------------------- generation

func _ensure_rows(opening := false) -> void:
	while gen_rows < top + VIS_ROWS + BUFFER_ROWS:
		_gen_chunk()
	_activate(opening)

func difficulty_power() -> float:
	## Damage one volley can deal per ball-hit: every 4th ball is heavy (1 + level), every 4th direct hit of
	## every 4th ball sparks `level` more.
	return float(balls) * (1.0 + 0.25 * heavy + 0.0625 * electric)

func field_rows_in_use() -> int:
	## Rows between the highest stone already in play and the floor (0 = empty field, 10 = under the red line).
	var top_row := VIS_ROWS
	for b in blocks.values():
		var vr: int = b.r - top
		if vr < VIS_ROWS and b.hp > 0:
			top_row = mini(top_row, maxi(0, vr))
	return VIS_ROWS - top_row

func _gen_chunk() -> void:
	if gen >= 2:
		_gen_band()
	else:
		_gen_rows_v1()

func _carve(best: Array, r0: int, rng: RandomNumberGenerator) -> void:
	# last resort: open a shaft under a cell that is still reachable from the top
	var open_cols: Array = []
	for c in COLS:
		if _reachable_cell(c, r0 - 1):
			open_cols.append(c)
	if open_cols.is_empty():
		return
	var col: int = open_cols[rng.randi_range(0, open_cols.size() - 1)]
	for spec in best.duplicate():
		if spec.c <= col and spec.c + spec.w > col:
			best.erase(spec)

func _gen_rows_v1() -> void:
	var r0 := gen_rows
	var best: Array = []
	var passable := false
	var rng := RandomNumberGenerator.new()
	for attempt in 12:
		rng.seed = mix(seed, r0 * 16 + attempt)
		best = _layout_chunk(rng, r0)
		if _chunk_reachable(best, r0, r0 + 1):
			passable = true
			break
	if not passable:
		_carve(best, r0, rng)
	for spec in best:
		_add_block(spec)
	gen_rows += 2

# ---------------------------------------------------------------- generator 2: bands of 4 rows

enum { B_OPEN, B_SHELF, B_PILLARS, B_CLUSTER, B_STAIRS, B_SCATTER }
const BAND := 4

func _gen_band() -> void:
	var r0 := gen_rows
	var best: Array = []
	var kind := B_OPEN
	var passable := false
	var rng := RandomNumberGenerator.new()
	for attempt in 12:
		rng.seed = mix(seed ^ 0x5bd1e995, r0 * 16 + attempt)
		kind = _pick_band(rng, r0)
		best = _layout_band(rng, r0, kind)
		if _chunk_reachable(best, r0, r0 + BAND - 1):
			passable = true
			break
	if not passable:
		_carve(best, r0, rng)
	for spec in best:
		_add_block(spec)
	band_kind = kind
	gen_rows += BAND

func _pick_band(rng: RandomNumberGenerator, r0: int) -> int:
	var opening := r0 < 14
	if not opening and band_kind != B_OPEN and band_kind >= 0 and rng.randf() < 0.12:
		return B_OPEN          # breathing room after a compact band
	var w: Array
	if opening:
		w = [[B_SHELF, 3.0], [B_CLUSTER, 3.0], [B_STAIRS, 2.0], [B_PILLARS, 1.0], [B_SCATTER, 1.5]]
	else:
		w = [[B_SHELF, 3.5], [B_PILLARS, 1.2], [B_CLUSTER, 2.2], [B_STAIRS, 1.5], [B_SCATTER, 3.0], [B_OPEN, 0.3]]
	var total := 0.0
	for e in w:
		if e[0] == B_OPEN and band_kind == B_OPEN:
			continue
		total += e[1]
	var x := rng.randf() * total
	for e in w:
		if e[0] == B_OPEN and band_kind == B_OPEN:
			continue
		x -= e[1]
		if x <= 0.0:
			return e[0]
	return B_SHELF

func _grid4() -> Array:
	var g: Array = []
	for rr in BAND:
		g.append([false, false, false, false, false, false, false])
	return g

func _put(occ: Array, keep: Array, specs: Array, r0: int, c: int, rr: int, w: int, h: int, role := "") -> bool:
	if c < 0 or c + w > COLS or rr < 0 or rr + h > BAND:
		return false
	for yy in h:
		for xx in w:
			if occ[rr + yy][c + xx] or keep[rr + yy][c + xx]:
				return false
	for yy in h:
		for xx in w:
			occ[rr + yy][c + xx] = true
	specs.append({"c": c, "r": r0 + rr, "w": w, "h": h, "role": role})
	return true

func _scatter4(occ: Array, keep: Array, specs: Array, r0: int, rng: RandomNumberGenerator, d: float, big := 0.3) -> void:
	for rr in BAND:
		for c in COLS:
			if occ[rr][c] or keep[rr][c] or rng.randf() > d:
				continue
			var roll := rng.randf()
			if roll < big * 0.4 and _put(occ, keep, specs, r0, c, rr, 2, 2):
				continue
			if roll < big * 0.7 and _put(occ, keep, specs, r0, c, rr, 2, 1):
				continue
			if roll < big and _put(occ, keep, specs, r0, c, rr, 1, 2):
				continue
			_put(occ, keep, specs, r0, c, rr, 1, 1)

func _layout_band(rng: RandomNumberGenerator, r0: int, kind: int) -> Array:
	## Four rows built around a purpose: a shelf with a pocket behind a side passage, pillars with a
	## corridor, a compact group with open lanes, a ramp along a wall, or an open breathing band.
	## Passages are whole free cells (98 px between stone faces, the ball is 22 px wide).
	var occ := _grid4()
	var keep := _grid4()
	var specs: Array = []
	var d := clampf(dens0 + dens_k * float(r0), dens0, dens_max)
	if r0 < 14:
		d *= open_dens
	match kind:
		B_SHELF:
			# a chamber: a roof of stones with one or two entry holes (often next to a wall, a side passage),
			# an empty cavity behind it and a floor whose openings are shifted sideways from the entries,
			# so a ball that gets in rattles between roof and floor instead of falling straight through
			# compact chamber: 4-5 columns, against a wall or free-standing; the rest of the band is rock
			var span_w := rng.randi_range(4, 5)
			var span_a := 0
			var place := rng.randf()
			if place < 0.35:
				span_a = 0
			elif place < 0.7:
				span_a = COLS - span_w
			else:
				span_a = rng.randi_range(1, COLS - span_w - 1)
			var span_b := span_a + span_w - 1
			var srow := 0 if rng.randf() < 0.7 else 1
			var holes: Array = []
			var h1 := span_a if rng.randf() < 0.5 else span_b
			if rng.randf() < 0.4:
				h1 = rng.randi_range(span_a, span_b)
			holes.append(h1)
			if span_b - span_a >= 4 and rng.randf() < 0.6:
				var h2 := span_b if h1 <= (span_a + span_b) / 2 else span_a
				holes.append(h2)
			for h in holes:
				keep[srow][h] = true
			var cav_bottom := 3 if rng.randf() < 0.35 else 2     # cavity of 1 or 2 rows
			if srow == 1:
				cav_bottom = 3
			for rr in range(srow + 1, cav_bottom):
				for c in range(span_a, span_b + 1):
					keep[rr][c] = true
			# floor openings away from the entries
			var far: Array = []
			for c in range(span_a, span_b + 1):
				var ok := true
				for h in holes:
					if absi(c - h) < 2:
						ok = false
				if ok:
					far.append(c)
			if not far.is_empty():
				keep[cav_bottom][far[rng.randi_range(0, far.size() - 1)]] = true
			var c := span_a
			while c <= span_b:
				if c + 1 <= span_b and rng.randf() < 0.5 and _put(occ, keep, specs, r0, c, srow, 2, 1, "roof"):
					c += 2
				else:
					_put(occ, keep, specs, r0, c, srow, 1, 1, "roof")
					c += 1
			for c2 in range(span_a, span_b + 1):
				if rng.randf() < 0.82:
					if not (rng.randf() < 0.3 and _put(occ, keep, specs, r0, c2, cav_bottom, 2, 1, "floor")):
						_put(occ, keep, specs, r0, c2, cav_bottom, 1, 1, "floor")
			# a bumper inside a tall cavity now and then
			if cav_bottom - srow >= 3 and rng.randf() < 0.4:
				var bc := rng.randi_range(span_a + 1, span_b - 1)
				keep[srow + 1][bc] = false
				_put(occ, keep, specs, r0, bc, srow + 1, 1, 1)
			# the rest of the band: ordinary rock, big stones welcome
			_scatter4(occ, keep, specs, r0, rng, d * 1.4, 0.5)
		B_PILLARS:
			# staggered pillars: balls zig-zag between them
			var cols := [rng.randi_range(0, 1), 3, COLS - 1 - rng.randi_range(0, 1)]
			for i in cols.size():
				var col: int = cols[i]
				var start := 0 if i % 2 == 0 else 1
				if rng.randf() < 0.3 and col + 1 < COLS and i != 1:
					_put(occ, keep, specs, r0, col if col <= 1 else col - 1, start, 2, 2)
				else:
					_put(occ, keep, specs, r0, col, start, 1, 2)
				if rng.randf() < 0.6:
					_put(occ, keep, specs, r0, col, start + 2 if start + 2 < BAND else 0, 1, 1)
			_scatter4(occ, keep, specs, r0, rng, d * 1.05, 0.35)
		B_CLUSTER:
			var cx := rng.randi_range(2, 3)
			var ry := rng.randi_range(0, 2)
			_put(occ, keep, specs, r0, cx, ry, 2, 2)
			var around := [[cx - 1, ry], [cx - 1, ry + 1], [cx + 2, ry], [cx + 2, ry + 1], [cx, ry - 1], [cx + 1, ry - 1], [cx, ry + 2], [cx + 1, ry + 2]]
			var want := rng.randi_range(4, 6)
			for i in 12:
				if want <= 0:
					break
				var pick: Array = around[rng.randi_range(0, around.size() - 1)]
				if _put(occ, keep, specs, r0, pick[0], pick[1], 1, 1):
					want -= 1
			_scatter4(occ, keep, specs, r0, rng, d * 1.0, 0.35)
		B_STAIRS:
			var dir := 1 if rng.randf() < 0.5 else -1
			var wall := 0 if dir == 1 else COLS - 1
			keep[0][wall] = true
			for i in BAND:
				var col := wall + dir * (i + 1)
				if i < 3 and rng.randf() < 0.45:
					var cc := col if dir == 1 else col - 1
					if not _put(occ, keep, specs, r0, cc, i, 2, 1, "roof"):
						_put(occ, keep, specs, r0, col, i, 1, 1, "roof")
				else:
					_put(occ, keep, specs, r0, col, i, 1, 1, "roof")
			# the pocket under the ramp has a floor of soft stones
			for i in range(1, 3):
				if rng.randf() < 0.75:
					_put(occ, keep, specs, r0, wall + dir * i, 3, 1, 1, "floor")
			_scatter4(occ, keep, specs, r0, rng, d * 1.0, 0.3)
		B_SCATTER:
			_scatter4(occ, keep, specs, r0, rng, d * 1.1, 0.45)
		_:
			var n := rng.randi_range(5, 7)
			for i in 16:
				if n <= 0:
					break
				var col := clampi(int(round(3.0 + rng.randfn(0.0, 1.6))), 0, COLS - 1)
				if _put(occ, keep, specs, r0, col, rng.randi_range(0, 3), 1, 1):
					n -= 1
	# every row keeps at least two open cells
	for rr in BAND:
		var guard := 0
		while _row_open(occ, rr) < 2 and guard < 10:
			guard += 1
			var cand: Array = []
			for sp in specs:
				if sp.r <= r0 + rr and sp.r + sp.h > r0 + rr:
					cand.append(sp)
			if cand.is_empty():
				break
			var victim: Dictionary = cand[rng.randi_range(0, cand.size() - 1)]
			for yy in victim.h:
				for xx in victim.w:
					occ[victim.r - r0 + yy][victim.c + xx] = false
			specs.erase(victim)
	for sp in specs:
		var area: int = sp.w * sp.h
		var q := _roll_q(rng, area)
		if sp.role == "floor":
			q *= 0.8
		sp["q"] = q
		sp["vein"] = rng.randf() < (0.35 if sp.role == "floor" else 0.08)
		sp["g"] = (1 if area == 1 else (2 if area == 2 else 3)) + (3 if sp.vein else 0)
		sp["v"] = rng.randi_range(0, 3)
	return specs

func _layout_chunk(rng: RandomNumberGenerator, r0: int) -> Array:
	# Returns block specs for rows r0 and r0+1. Multi-cell stones: 2x2, 2x1, 1x2, 1x1.
	var d := clampf(dens0 + dens_k * float(r0), dens0, dens_max)
	if r0 < 10:
		d = 0.38
	var occ := [[false, false, false, false, false, false, false], [false, false, false, false, false, false, false]]
	var specs: Array = []
	for rr in 2:
		for c in COLS:
			if occ[rr][c]:
				continue
			if rng.randf() > d:
				continue
			var roll := rng.randf()
			var can22: bool = rr == 0 and c + 1 < COLS and not occ[0][c + 1] and not occ[1][c] and not occ[1][c + 1]
			var can21: bool = c + 1 < COLS and not occ[rr][c + 1]
			var can12: bool = rr == 0 and not occ[1][c]
			var w := 1
			var h := 1
			if roll < 0.24 and can22:
				w = 2; h = 2
			elif roll < 0.42 and can21:
				w = 2
			elif roll < 0.58 and can12:
				h = 2
			for yy in h:
				for xx in w:
					occ[rr + yy][c + xx] = true
			specs.append({"c": c, "r": r0 + rr, "w": w, "h": h})
	# every row keeps at least two open cells
	for rr in 2:
		var guard := 0
		while _row_open(occ, rr) < 2 and guard < 10:
			guard += 1
			var cand: Array = []
			for s in specs:
				if s.r <= r0 + rr and s.r + s.h > r0 + rr:
					cand.append(s)
			if cand.is_empty():
				break
			var victim: Dictionary = cand[rng.randi_range(0, cand.size() - 1)]
			for yy in victim.h:
				for xx in victim.w:
					occ[victim.r - r0 + yy][victim.c + xx] = false
			specs.erase(victim)
	# strength, look, crystals
	for s in specs:
		var area: int = s.w * s.h
		s["q"] = _roll_q(rng, area)
		s["vein"] = rng.randf() < 0.13
		s["g"] = (1 if area == 1 else (2 if area == 2 else 3)) + (3 if s.vein else 0)
		s["v"] = rng.randi_range(0, 3)
	return specs

func _row_open(occ: Array, rr: int) -> int:
	var n := 0
	for c in COLS:
		if not occ[rr][c]:
			n += 1
	return n

func _roll_q(rng: RandomNumberGenerator, area: int) -> float:
	## Relative weight of a stone inside its row (size and luck). The actual strength is set by
	## _activate() when the stone enters the field.
	var mult := 1.0
	if area == 2:
		mult = 1.7
	elif area >= 4:
		mult = 2.7
	var q := mult * rng.randf_range(0.6, 1.3)
	if rng.randf() < 0.09:
		q *= 1.5
	return snappedf(q, 0.001)

func strength_base() -> float:
	## What a stone of weight 1 is worth for rock entering the field right now. One row arrives per volley,
	## so a row is sized against what one volley can do: it grows with depth and with the player's current
	## power. There are no "free" rows; the opening is only softened. A gentle rubber band keeps the field
	## populated: a nearly empty field gets tougher rock, a field close to the red line softer rock.
	var d := float(depth)
	var base := hp_a + hp_b * d + hp_d * d * d + hp_c * difficulty_power()
	base *= lerpf(open_soft, 1.0, clampf(d / open_len, 0.0, 1.0))
	if band_k > 0.0:
		base *= clampf(1.0 + band_k * (band_target - float(field_rows_in_use())), band_min, band_max)
	return base

func _activate(opening := false) -> void:
	## Stones that have just risen above the floor get their strength (once).
	## The opening board is not rubber-banded, and its upper rows (the first to reach the red line) are softer.
	var base := -1.0
	var ids := blocks.keys()
	ids.sort()
	for id in ids:
		var b: Dictionary = blocks[id]
		if b.hp > 0 or b.q <= 0.0 or is_future(b):
			continue
		if base < 0.0:
			if opening:
				var keep := band_k
				band_k = 0.0
				base = strength_base()
				band_k = keep
			else:
				base = strength_base()
		var k := 1.0
		var q: float = b.q
		if opening:
			# the opening board: its upper rows reach the red line first, so they are the softest (eased in,
			# not linear), and no stone of the board is an outlier
			var t := clampf(float(b.r - top - start_empty) / float(maxi(1, VIS_ROWS - 1 - start_empty)), 0.0, 1.0)
			k = lerpf(open_top, open_bottom, t * t * (3.0 - 2.0 * t))
			var area: int = b.w * b.h
			q = minf(q, (1.0 if area == 1 else (1.7 if area == 2 else 2.3)) * 1.3)
		b.hp = maxi(1, int(round(q * base * k)))
		b.mhp = b.hp

func _chunk_reachable(specs: Array, r0: int, last: int) -> bool:
	# Flood fill from the open space above the field through empty cells of everything generated so far
	# plus this chunk. The chunk's lowest row must keep at least one cell reachable from the top.
	var occ := {}
	for key in grid:
		occ[key] = true
	for s in specs:
		for yy in s.h:
			for xx in s.w:
				occ[(s.r + yy) * COLS + s.c + xx] = true
	var seen := {}
	var stack: Array = []
	for c in COLS:
		var k := top * COLS + c
		if not occ.has(k):
			stack.append(k)
			seen[k] = true
	while not stack.is_empty():
		var k: int = stack.pop_back()
		var r := k / COLS
		var c := k % COLS
		if r == last:
			return true
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nr: int = r + d[1]
			var nc: int = c + d[0]
			if nc < 0 or nc >= COLS or nr < top or nr > last:
				continue
			var nk := nr * COLS + nc
			if occ.has(nk) or seen.has(nk):
				continue
			seen[nk] = true
			stack.append(nk)
	return false

func _reachable_cell(col: int, row: int) -> bool:
	if row < top:
		return true
	var seen := {}
	var stack: Array = []
	for c in COLS:
		var k := top * COLS + c
		if not grid.has(k):
			stack.append(k)
			seen[k] = true
	while not stack.is_empty():
		var k: int = stack.pop_back()
		var r := k / COLS
		var c := k % COLS
		if r == row and c == col:
			return true
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nr: int = r + d[1]
			var nc: int = c + d[0]
			if nc < 0 or nc >= COLS or nr < top or nr > row:
				continue
			var nk := nr * COLS + nc
			if grid.has(nk) or seen.has(nk):
				continue
			seen[nk] = true
			stack.append(nk)
	return false

func _add_block(s: Dictionary) -> void:
	var id := next_id
	next_id += 1
	var v: int = s.v
	# a stone never repeats the pattern of the stone to its left or above it
	var left := _block_at(s.c - 1, s.r)
	var up := _block_at(s.c, s.r - 1)
	for i in 4:
		var vv := (v + i) % 4
		if (left.is_empty() or left.v != vv) and (up.is_empty() or up.v != vv):
			v = vv
			break
	# generated rock carries a weight q and gets its strength on entering the field; an explicit hp is final
	var hp0: int = s.get("hp", 0)
	var b := {"id": id, "c": s.c, "r": s.r, "w": s.w, "h": s.h, "hp": hp0, "mhp": hp0, "v": v, "g": s.g, "vein": s.vein,
		"q": 0.0 if hp0 > 0 else float(roundi(float(s.get("q", 1.0)) * 1000.0)) / 1000.0}
	blocks[id] = b
	for yy in s.h:
		for xx in s.w:
			grid[(s.r + yy) * COLS + s.c + xx] = id

func _block_at(c: int, r: int) -> Dictionary:
	if c < 0 or c >= COLS:
		return {}
	var id: int = grid.get(r * COLS + c, 0)
	return blocks.get(id, {})

func block_rect(b: Dictionary) -> Rect2:
	var x0: float = FIELD_X0 + b.c * CELL + GAP
	var y0: float = DANGER_Y + (b.r - top) * CELL + GAP
	return Rect2(x0, y0, b.w * CELL - 2.0 * GAP, b.h * CELL - 2.0 * GAP)

func visible_row(b: Dictionary) -> int:
	return b.r - top

func crosses_line(b: Dictionary, shifts := 0) -> bool:
	## The one rule for the red line: after `shifts` more upward shifts, is the top of this stone's collider
	## above the line? The game-over check (shifts = 0, after the shift) and the warning (shifts = 1) both use it.
	return block_rect(b).position.y - shifts * CELL < DANGER_Y

func will_cross_next(b: Dictionary) -> bool:
	return crosses_line(b, 1)

func is_future(b: Dictionary) -> bool:
	## Generated rock still below the floor: not reachable by balls yet.
	return block_rect(b).position.y >= FLOOR_Y

static func damage_stage(hp: int, mhp: int) -> int:
	## Crack stage from the share of strength left: >80 % intact, 51-80 % light, 26-50 % medium, <=25 % heavy.
	if mhp < 2:
		return 0
	var ratio := float(hp) / float(mhp)
	if ratio <= 0.25:
		return 3
	if ratio <= 0.5:
		return 2
	if ratio <= 0.8:
		return 1
	return 0

func danger_level() -> int:
	# 0 calm, 1 a stone will cross the line in two shifts, 2 the next shift ends the run unless it breaks
	var lvl := 0
	for b in blocks.values():
		if crosses_line(b, 1):
			return 2
		if crosses_line(b, 2):
			lvl = 1
	return lvl

# ---------------------------------------------------------------- aiming

static func muzzle(angle: float) -> Vector2:
	return Vector2(PIVOT.x + cos(angle) * BARREL, PIVOT.y + sin(angle) * BARREL)

static func clamp_aim(angle: float) -> float:
	var lo := asin(MIN_VY) + 0.001
	return clampf(angle, lo, PI - lo)

func preview(angle: float, tail := 150.0) -> PackedVector2Array:
	## The same cast and the same bounce rule as a real ball: start, first contact, short line after it.
	angle = clamp_aim(angle)
	var pts := PackedVector2Array()
	var m := muzzle(angle)
	var px := m.x
	var py := m.y
	var vx := cos(angle)
	var vy := sin(angle)
	pts.append(Vector2(px, py))
	var L := 2400.0
	_cast(px, py, vx * L, vy * L, false)
	if _hkind == H_NONE:
		pts.append(Vector2(px + vx * L, py + vy * L))
		return pts
	px += vx * L * _ht
	py += vy * L * _ht
	pts.append(Vector2(px, py))
	var nv := _reflect(vx, vy, _hnx, _hny)
	vx = nv.x
	vy = nv.y
	_cast(px, py, vx * tail, vy * tail, false)
	var t := _ht if _hkind != H_NONE else 1.0
	pts.append(Vector2(px + vx * tail * t, py + vy * tail * t))
	return pts

func preview_target() -> int:
	return _hid if _hkind == H_BLOCK else 0

# ---------------------------------------------------------------- volley

func fire(angle: float) -> bool:
	if phase != PH_AIM:
		return false
	angle = clamp_aim(angle)
	aim = angle
	v_angle = angle
	v_tick = 0
	v_total = balls
	v_launched = 0
	v_balls = []
	v_damage = 0
	v_hits = 0
	phase = PH_VOLLEY
	return true

func ball_kind(i: int) -> int:
	var n := i + 1
	if heavy > 0 and n % 4 == 0:
		return K_HEAVY
	if electric > 0 and n % 4 == 2:
		return K_ELECTRIC
	return K_NORMAL

func flying_count() -> int:
	var n := 0
	for b in v_balls:
		if b.st == 1:
			n += 1
	return n

func waiting_count() -> int:
	return v_total - v_launched if phase == PH_VOLLEY else balls

func step() -> void:
	if phase != PH_VOLLEY:
		return
	if v_launched < v_total and v_tick % FIRE_EVERY == 0:
		var b := Ball.new()
		b.idx = v_launched
		b.k = ball_kind(v_launched)
		var m := muzzle(v_angle)
		b.x = m.x
		b.y = m.y
		b.vx = cos(v_angle) * SPEED
		b.vy = sin(v_angle) * SPEED
		v_balls.append(b)
		v_launched += 1
		_ev({"t": "shot", "i": b.idx, "k": b.k})
	var flying := 0
	for b in v_balls:
		if b.st == 1:
			_move(b)
			if b.st == 1 and b.y < CEILING_Y:
				# safety net: whatever happened, a ball above the cannon goes home
				b.st = 2
				_ev({"t": "ret", "i": b.idx, "x": b.x, "y": CEILING_Y})
			if b.st == 1:
				b.life += 1
				if b.life >= BALL_MAX_TICKS:
					_recall(b)
				else:
					flying += 1
	v_tick += 1
	if v_tick >= VOLLEY_MAX_TICKS:
		for b in v_balls:
			if b.st == 1:
				_recall(b)
		flying = 0
		v_launched = v_total
	if v_launched >= v_total and flying == 0:
		_end_volley()

func recall_all() -> void:
	## Player request: everything still in flight goes home now; balls not yet fired stay in the cannon.
	if phase != PH_VOLLEY:
		return
	for b in v_balls:
		if b.st == 1:
			_recall(b)
	v_launched = v_total
	_end_volley()

func _recall(b: Ball) -> void:
	b.st = 3
	_ev({"t": "recall", "i": b.idx, "x": b.x, "y": b.y})

func _move(b: Ball) -> void:
	var rem := 1.0
	var it := 0
	while rem > 1e-7 and it < 12:
		it += 1
		var dx := b.vx * DT * rem
		var dy := b.vy * DT * rem
		_cast(b.x, b.y, dx, dy, true)
		if _hkind == H_NONE:
			b.x += dx
			b.y += dy
			break
		b.x += dx * _ht
		b.y += dy * _ht
		rem *= (1.0 - _ht)
		if _hkind == H_RETURN:
			b.st = 2
			_ev({"t": "ret", "i": b.idx, "x": b.x, "y": b.y})
			return
		var kind := _hkind
		var hid := _hid
		var nv := _reflect(b.vx / SPEED, b.vy / SPEED, _hnx, _hny)
		b.vx = nv.x * SPEED
		b.vy = nv.y * SPEED
		if kind == H_BLOCK:
			_hit_block(b, hid)
		elif record_events:
			_ev({"t": "wall", "x": b.x, "y": b.y, "f": kind == H_FLOOR})
	_unstick(b)

func _reflect(vx: float, vy: float, nx: float, ny: float) -> Vector2:
	var d := vx * nx + vy * ny
	var rx := vx - 2.0 * d * nx
	var ry := vy - 2.0 * d * ny
	var l := sqrt(rx * rx + ry * ry)
	rx /= l
	ry /= l
	if absf(ry) < MIN_VY:
		var sy := -1.0
		if ry > 0.0:
			sy = 1.0
		elif ry == 0.0 and ny > 0.0:
			sy = 1.0
		var ax := rx
		var ay := sy * MIN_VY
		var sx := 1.0 if rx >= 0.0 else -1.0
		ax = sx * sqrt(1.0 - MIN_VY * MIN_VY)
		if ax * nx + ay * ny > 0.0:
			rx = ax
			ry = ay
	return Vector2(rx, ry)

func _unstick(b: Ball) -> void:
	# Safety net for float drift: a ball never rests inside a wall or a stone.
	if b.x < FIELD_X0 + BALL_R:
		b.x = FIELD_X0 + BALL_R
		b.vx = absf(b.vx)
	elif b.x > FIELD_X1 - BALL_R:
		b.x = FIELD_X1 - BALL_R
		b.vx = -absf(b.vx)
	if b.y > FLOOR_Y - BALL_R:
		b.y = FLOOR_Y - BALL_R
		b.vy = -absf(b.vy)
	var c := int(floor((b.x - FIELD_X0) / CELL))
	var r := int(floor((b.y - DANGER_Y) / CELL)) + top
	for rr in range(r - 1, r + 2):
		for cc in range(c - 1, c + 2):
			if cc < 0 or cc >= COLS:
				continue
			var id: int = grid.get(rr * COLS + cc, 0)
			if id == 0:
				continue
			var rc := block_rect(blocks[id])
			var qx := clampf(b.x, rc.position.x, rc.end.x)
			var qy := clampf(b.y, rc.position.y, rc.end.y)
			var ddx := b.x - qx
			var ddy := b.y - qy
			var d2 := ddx * ddx + ddy * ddy
			if d2 >= (BALL_R - 0.05) * (BALL_R - 0.05):
				continue
			var nx := 0.0
			var ny := 0.0
			if d2 > 1e-12:
				var d := sqrt(d2)
				nx = ddx / d
				ny = ddy / d
				b.x = qx + nx * BALL_R
				b.y = qy + ny * BALL_R
			else:
				# centre inside the rect: leave through the nearest side
				var dl := b.x - rc.position.x
				var dr := rc.end.x - b.x
				var du := b.y - rc.position.y
				var dd := rc.end.y - b.y
				var m := minf(minf(dl, dr), minf(du, dd))
				if m == du:
					ny = -1.0; b.y = rc.position.y - BALL_R
				elif m == dd:
					ny = 1.0; b.y = rc.end.y + BALL_R
				elif m == dl:
					nx = -1.0; b.x = rc.position.x - BALL_R
				else:
					nx = 1.0; b.x = rc.end.x + BALL_R
			if b.vx * nx + b.vy * ny < 0.0:
				var nv := _reflect(b.vx / SPEED, b.vy / SPEED, nx, ny)
				b.vx = nv.x * SPEED
				b.vy = nv.y * SPEED

# ---------------------------------------------------------------- casting

func _cast(px: float, py: float, dx: float, dy: float, with_return: bool) -> void:
	_ht = 1.0
	_hkind = H_NONE
	_hid = 0
	var t := 0.0
	if dx < 0.0:
		t = (FIELD_X0 + BALL_R - px) / dx
		if t < _ht:
			_set_hit(maxf(t, 0.0), 1.0, 0.0, H_WALL, 0)
	elif dx > 0.0:
		t = (FIELD_X1 - BALL_R - px) / dx
		if t < _ht:
			_set_hit(maxf(t, 0.0), -1.0, 0.0, H_WALL, 0)
	if dy > 0.0:
		t = (FLOOR_Y - BALL_R - py) / dy
		if t < _ht:
			_set_hit(maxf(t, 0.0), 0.0, -1.0, H_FLOOR, 0)
	elif dy < 0.0 and with_return:
		# A ball moving up at or above the return line is home. It can already be above the line when it
		# turns upwards: the top face of a stone in the top row is touched at DANGER_Y + GAP - BALL_R, which
		# lies above RETURN_Y. Without this such a ball left the screen and flew until the flight limit.
		if py <= RETURN_Y:
			_set_hit(0.0, 0.0, 0.0, H_RETURN, 0)
			return
		t = (RETURN_Y - py) / dy
		if t < _ht:
			_set_hit(maxf(t, 0.0), 0.0, 0.0, H_RETURN, 0)
	# stones
	var minx := minf(px, px + dx) - BALL_R - 1.0
	var maxx := maxf(px, px + dx) + BALL_R + 1.0
	var miny := minf(py, py + dy) - BALL_R - 1.0
	var maxy := maxf(py, py + dy) + BALL_R + 1.0
	if maxy < DANGER_Y:
		return
	var c0 := maxi(0, int(floor((minx - FIELD_X0) / CELL)))
	var c1 := mini(COLS - 1, int(floor((maxx - FIELD_X0) / CELL)))
	var r0 := maxi(top, int(floor((miny - DANGER_Y) / CELL)) + top)
	var r1 := mini(top + VIS_ROWS - 1, int(floor((maxy - DANGER_Y) / CELL)) + top)
	var seen := []
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var id: int = grid.get(r * COLS + c, 0)
			if id == 0 or seen.has(id):
				continue
			seen.append(id)
			_ray_block(px, py, dx, dy, blocks[id])

func _set_hit(t: float, nx: float, ny: float, kind: int, id: int) -> void:
	_ht = t
	_hnx = nx
	_hny = ny
	_hkind = kind
	_hid = id

func _ray_block(px: float, py: float, dx: float, dy: float, b: Dictionary) -> void:
	var bc: int = b.c
	var br: int = b.r
	var bw: int = b.w
	var bh: int = b.h
	var x0: float = FIELD_X0 + bc * CELL + GAP
	var y0: float = DANGER_Y + (br - top) * CELL + GAP
	var x1: float = x0 + bw * CELL - 2.0 * GAP
	var y1: float = y0 + bh * CELL - 2.0 * GAP
	var R := BALL_R
	var ex0 := x0 - R
	var ex1 := x1 + R
	var ey0 := y0 - R
	var ey1 := y1 + R
	var qx := px + dx
	var qy := py + dy
	if maxf(px, qx) < ex0 or minf(px, qx) > ex1 or maxf(py, qy) < ey0 or minf(py, qy) > ey1:
		return
	var best := _ht
	var found := false
	var bnx := 0.0
	var bny := 0.0
	var corner := false
	var t := 0.0
	# flat faces (the ball approaches the face)
	if dx > 0.0 and px <= ex0 + 0.5:
		t = (ex0 - px) / dx
		if t >= -0.02 and t < best:
			var yy := py + dy * t
			if yy >= y0 and yy <= y1:
				best = maxf(t, 0.0); bnx = -1.0; bny = 0.0; found = true; corner = false
	elif dx < 0.0 and px >= ex1 - 0.5:
		t = (ex1 - px) / dx
		if t >= -0.02 and t < best:
			var yy := py + dy * t
			if yy >= y0 and yy <= y1:
				best = maxf(t, 0.0); bnx = 1.0; bny = 0.0; found = true; corner = false
	if dy > 0.0 and py <= ey0 + 0.5:
		t = (ey0 - py) / dy
		if t >= -0.02 and t < best:
			var xx := px + dx * t
			if xx >= x0 and xx <= x1:
				best = maxf(t, 0.0); bnx = 0.0; bny = -1.0; found = true; corner = false
	elif dy < 0.0 and py >= ey1 - 0.5:
		t = (ey1 - py) / dy
		if t >= -0.02 and t < best:
			var xx := px + dx * t
			if xx >= x0 and xx <= x1:
				best = maxf(t, 0.0); bnx = 0.0; bny = 1.0; found = true; corner = false
	# rounded corners of the Minkowski sum
	var a := dx * dx + dy * dy
	if a > 1e-12:
		for ci in 4:
			var cx := x0 if (ci & 1) == 0 else x1
			var cy := y0 if (ci & 2) == 0 else y1
			var fx := px - cx
			var fy := py - cy
			var bb := fx * dx + fy * dy
			if bb >= 0.0:
				continue
			var cc := fx * fx + fy * fy - R * R
			var disc := bb * bb - a * cc
			if disc < 0.0:
				continue
			t = (-bb - sqrt(disc)) / a
			if t < -0.02 or t >= best:
				continue
			var hx := px + dx * t
			var hy := py + dy * t
			if (hx >= x0 and hx <= x1) or (hy >= y0 and hy <= y1):
				continue  # that contact belongs to a flat face
			best = maxf(t, 0.0)
			bnx = (hx - cx) / R
			bny = (hy - cy) / R
			var nl := sqrt(bnx * bnx + bny * bny)
			bnx /= nl
			bny /= nl
			found = true
			corner = true
			var n := _seam_normal(b, ci, bnx, bny, dx, dy)
			bnx = n.x
			bny = n.y
	if found:
		_set_hit(best, bnx, bny, H_BLOCK, b.id)

func _seam_normal(b: Dictionary, ci: int, nx: float, ny: float, dx: float, dy: float) -> Vector2:
	# A corner that touches a neighbouring stone or a wall is not a real corner: the face continues.
	var sx := 1 if (ci & 1) == 1 else -1
	var sy := 1 if (ci & 2) == 2 else -1
	if absf(ny) >= absf(nx):
		var col: int = b.c + b.w if sx > 0 else b.c - 1
		var row: int = b.r if sy < 0 else b.r + b.h - 1
		var cont := false
		if col < 0 or col >= COLS:
			cont = true
		else:
			var o := _block_at(col, row)
			if not o.is_empty():
				cont = (o.r == b.r) if sy < 0 else (o.r + o.h == b.r + b.h)
		if cont and dy * sy < 0.0:
			return Vector2(0.0, float(sy))
	else:
		var col2: int = b.c + b.w - 1 if sx > 0 else b.c
		var row2: int = b.r - 1 if sy < 0 else b.r + b.h
		var o2 := _block_at(col2, row2)
		if not o2.is_empty():
			var cont2: bool = (o2.c + o2.w == b.c + b.w) if sx > 0 else (o2.c == b.c)
			if cont2 and dx * sx < 0.0:
				return Vector2(float(sx), 0.0)
	return Vector2(nx, ny)

# ---------------------------------------------------------------- damage

func _hit_block(ball: Ball, id: int) -> void:
	var b: Dictionary = blocks.get(id, {})
	if b.is_empty():
		return
	var dmg := 1
	v_hits += 1
	if ball.k == K_HEAVY:
		dmg = HEAVY_DMG[heavy]
	_damage(b, dmg, ball.k, ball.x, ball.y)
	if ball.k == K_ELECTRIC:
		ball.hits += 1
		if ball.hits % 4 == 0:
			_zap(b, ball.x, ball.y)

func _damage(b: Dictionary, dmg: int, kind: int, x: float, y: float) -> void:
	var dealt: int = mini(dmg, b.hp)
	b.hp -= dmg
	v_damage += dealt
	_ev({"t": "hit", "id": b.id, "x": x, "y": y, "d": dmg, "k": kind, "hp": maxi(b.hp, 0)})
	if b.hp <= 0:
		_destroy(b)

func _destroy(b: Dictionary) -> void:
	if not blocks.has(b.id):
		return  # crystals are paid exactly once
	blocks.erase(b.id)
	for yy in b.h:
		for xx in b.w:
			var k: int = (b.r + yy) * COLS + b.c + xx
			if grid.get(k, 0) == b.id:
				grid.erase(k)
	run_gems += b.g
	unclaimed += b.g
	stats.destroyed += 1
	var rc := block_rect(b)
	_ev({"t": "break", "id": b.id, "x": rc.get_center().x, "y": rc.get_center().y, "w": b.w, "h": b.h, "g": b.g, "v": b.v})

func _zap(src: Dictionary, x: float, y: float) -> void:
	var src_rc := block_rect(src)
	var best_id := 0
	var best_d := ZAP_RADIUS
	var ids := blocks.keys()
	ids.sort()
	for id in ids:
		if id == src.id:
			continue
		var o: Dictionary = blocks[id]
		var vr: int = o.r - top
		if vr >= VIS_ROWS or vr + o.h <= 0:
			continue
		var rc := block_rect(o)
		var gx := maxf(0.0, maxf(rc.position.x - src_rc.end.x, src_rc.position.x - rc.end.x))
		var gy := maxf(0.0, maxf(rc.position.y - src_rc.end.y, src_rc.position.y - rc.end.y))
		var d := sqrt(gx * gx + gy * gy)
		if d < best_d:
			best_d = d
			best_id = id
	stats.zaps += 1
	if best_id == 0:
		_ev({"t": "fizzle", "x": x, "y": y})
		return
	var tgt: Dictionary = blocks[best_id]
	var c := block_rect(tgt).get_center()
	_ev({"t": "zap", "x": x, "y": y, "x2": c.x, "y2": c.y, "id": best_id})
	_damage(tgt, ZAP_DMG[electric], -1, c.x, c.y)  # electric damage ends here: no chain

func _ev(e: Dictionary) -> void:
	if record_events:
		events.append(e)

# ---------------------------------------------------------------- turn flow

func _end_volley() -> void:
	stats.best_volley = maxi(stats.best_volley, v_damage)
	_ev({"t": "end", "dmg": v_damage})
	v_balls = []
	volleys += 1
	top += 1
	depth += 1
	_ensure_rows()
	for b in blocks.values():
		if crosses_line(b, 0):
			phase = PH_OVER
			_ev({"t": "over"})
			return
	if volleys % UPGRADE_EVERY == 0:
		_offer_upgrades()
	else:
		phase = PH_AIM

func available_upgrades() -> Array:
	var opts: Array = []
	if balls < MAX_BALLS:
		opts.append("balls")
	if heavy < MAX_LEVEL:
		opts.append("heavy")
	if electric < MAX_LEVEL:
		opts.append("electric")
	return opts

func _offer_upgrades() -> void:
	var opts := available_upgrades()
	if opts.is_empty():
		run_gems += MAXED_BONUS
		unclaimed += MAXED_BONUS
		stats.bonus += MAXED_BONUS
		_ev({"t": "bonus", "g": MAXED_BONUS})
		phase = PH_AIM
		return
	upgrade_opts = opts
	phase = PH_UPGRADE

func choose_upgrade(id: String) -> bool:
	if phase != PH_UPGRADE or not upgrade_opts.has(id):
		return false
	match id:
		"balls":
			balls = mini(MAX_BALLS, balls + BALLS_STEP)
		"heavy":
			heavy = mini(MAX_LEVEL, heavy + 1)
		"electric":
			electric = mini(MAX_LEVEL, electric + 1)
	picks += 1
	upgrade_opts = []
	phase = PH_AIM
	_ev({"t": "upgrade", "id": id})
	return true

func claim() -> int:
	var g := unclaimed
	unclaimed = 0
	return g

# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	var bl: Array = []
	var ids := blocks.keys()
	ids.sort()
	for id in ids:
		var b: Dictionary = blocks[id]
		bl.append([b.id, b.c, b.r, b.w, b.h, b.hp, b.mhp, b.v, b.g, 1 if b.vein else 0, roundi(b.q * 1000.0)])
	var d := {
		"seed": seed, "depth": depth, "volleys": volleys, "balls": balls, "heavy": heavy, "electric": electric,
		"phase": phase, "next_id": next_id, "gen_rows": gen_rows, "top": top, "run_gems": run_gems,
		"unclaimed": unclaimed, "upgrade_opts": upgrade_opts.duplicate(), "picks": picks, "stats": stats.duplicate(), "gen": gen, "band_kind": band_kind,
		"aim": snappedf(aim, 0.0001), "blocks": bl,
	}
	if phase == PH_VOLLEY:
		# positions, velocities and the angle are stored as the exact bytes of the doubles: text numbers do not
		# survive JSON bit for bit, and one bit is enough to change a later bounce
		var bs: Array = []
		var exact := PackedFloat64Array([v_angle])
		for b in v_balls:
			bs.append([b.k, b.hits, b.life, b.st, b.idx])
			exact.append_array(PackedFloat64Array([b.x, b.y, b.vx, b.vy]))
		d["volley"] = {"tick": v_tick, "total": v_total, "launched": v_launched, "dmg": v_damage, "hits": v_hits,
			"balls": bs, "bits": exact.to_byte_array().hex_encode()}
	return d

func from_dict(d: Dictionary) -> void:
	seed = int(d.seed)
	depth = int(d.depth)
	volleys = int(d.volleys)
	balls = int(d.balls)
	heavy = int(d.heavy)
	electric = int(d.electric)
	phase = int(d.phase)
	next_id = int(d.next_id)
	gen_rows = int(d.gen_rows)
	top = int(d.top)
	run_gems = int(d.run_gems)
	unclaimed = int(d.get("unclaimed", 0))
	upgrade_opts = []
	for o in d.get("upgrade_opts", []):
		upgrade_opts.append(String(o))
	picks = int(d.get("picks", 0))
	gen = int(d.get("gen", 2))
	band_kind = int(d.get("band_kind", -1))
	var st: Dictionary = d.get("stats", {})
	stats = {"destroyed": int(st.get("destroyed", 0)), "zaps": int(st.get("zaps", 0)),
		"best_volley": int(st.get("best_volley", 0)), "bonus": int(st.get("bonus", 0))}
	aim = float(d.get("aim", PI * 0.5))
	blocks = {}
	grid = {}
	for a in d.blocks:
		var b := {"id": int(a[0]), "c": int(a[1]), "r": int(a[2]), "w": int(a[3]), "h": int(a[4]), "hp": int(a[5]),
			"mhp": int(a[6]), "v": int(a[7]), "g": int(a[8]), "vein": int(a[9]) == 1,
			"q": float(int(a[10])) / 1000.0 if a.size() > 10 else 0.0}   # saves before 1.0.2: every stone already has its strength
		blocks[b.id] = b
		for yy in b.h:
			for xx in b.w:
				grid[(b.r + yy) * COLS + b.c + xx] = b.id
	v_balls = []
	events = []
	if phase == PH_VOLLEY and d.has("volley"):
		var v: Dictionary = d.volley
		v_tick = int(v.tick)
		v_total = int(v.total)
		v_launched = int(v.launched)
		v_damage = int(v.get("dmg", 0))
		v_hits = int(v.get("hits", 0))
		if v.has("bits"):
			var exact: PackedFloat64Array = String(v.bits).hex_decode().to_float64_array()
			v_angle = exact[0]
			var i := 1
			for a in v.balls:
				var b := Ball.new()
				b.x = exact[i]; b.y = exact[i + 1]; b.vx = exact[i + 2]; b.vy = exact[i + 3]
				i += 4
				b.k = int(a[0]); b.hits = int(a[1]); b.life = int(a[2]); b.st = int(a[3]); b.idx = int(a[4])
				v_balls.append(b)
		else:
			# volley saved by 1.0 / 1.0.1: numbers as text
			v_angle = float(v.angle)
			for a in v.balls:
				var b := Ball.new()
				b.x = float(a[0]); b.y = float(a[1]); b.vx = float(a[2]); b.vy = float(a[3])
				b.k = int(a[4]); b.hits = int(a[5]); b.life = int(a[6]); b.st = int(a[7]); b.idx = int(a[8])
				v_balls.append(b)
	elif phase == PH_VOLLEY:
		phase = PH_AIM

func clone() -> Sim:
	var s := Sim.new()
	s.from_dict(to_dict())
	s.record_events = false
	return s

func state_hash() -> int:
	return hash(JSON.stringify(to_dict(), "", true, true))
