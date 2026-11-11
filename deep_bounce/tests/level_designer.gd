extends Node
## Builds the 50 levels and proves each one with the game's own physics.
##   godot --headless --path . res://tests/level_designer.tscn -- --levels=1-50 --out=user://levels_part.json
## For every level: a layout from the chapter's structures (seeded by the level id), then a beam search over
## real volleys (Sim, fixed step) looks for the shortest win. Stone strength is scaled until the shortest
## win lands in the level's target range of volleys. The winning route (directions and upgrade picks) is
## replayed from a fresh start and stored with the level: T3 = its volley count, T2 = a looser bound.

const LEVEL_VER := 1
var out_path := "user://levels_part.json"
var first := 1
var last := 50
var beam_w := 2
var n_angles := 26
var log_lines: PackedStringArray = []

# chapter: name, target volleys for the 3-star route at the first and the last level of the chapter
const CHAPTERS := [
	{"id": "copper", "t3": [4, 8]},
	{"id": "crystal", "t3": [7, 10]},
	{"id": "flooded", "t3": [8, 11]},
	{"id": "obsidian", "t3": [9, 12]},
	{"id": "heart", "t3": [10, 13]},
]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			var p := a.substr(9).split("-")
			first = int(p[0])
			last = int(p[1]) if p.size() > 1 else first
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--beam="):
			beam_w = int(a.substr(7))
		elif a.begins_with("--angles="):
			n_angles = int(a.substr(9))
	var levels: Array = []
	var t0 := Time.get_ticks_msec()
	for n in range(first, last + 1):
		var res := design(n)
		levels.append(res)
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"levels": levels}, " ", false))
		f.close()
	log_line("done %d levels in %.1f min" % [levels.size(), (Time.get_ticks_msec() - t0) / 60000.0])
	get_tree().quit()

func log_line(s: String) -> void:
	print(s)
	log_lines.append(s)

# ---------------------------------------------------------------- layouts

class Board:
	var occ := {}
	var stones: Array = []      # [c, r, w, h, weight, vein]
	func is_free(c: int, r: int, w: int, h: int) -> bool:
		if c < 0 or c + w > 7 or r < 0:
			return false
		for y in h:
			for x in w:
				if occ.has((r + y) * 7 + c + x):
					return false
		return true
	func put(c: int, r: int, w: int, h: int, weight: float, vein := false) -> bool:
		if not is_free(c, r, w, h):
			return false
		for y in h:
			for x in w:
				occ[(r + y) * 7 + c + x] = true
		stones.append([c, r, w, h, weight, vein])
		return true

func level_spec(n: int) -> Dictionary:
	## Starting parameters and structure of level n (1..50).
	var ch := (n - 1) / 10
	var k := (n - 1) % 10            # 0..9 inside the chapter
	var spec := {"n": n, "ch": ch, "k": k, "balls": 8, "heavy": 0, "electric": 0, "upgrades": [], "upgrade_every": 0,
		"hint": "", "start_row": 3, "rows": 10}
	match ch:
		0:
			spec.balls = [8, 8, 8, 9, 9, 10, 10, 10, 10, 12][k]
			spec.hint = ["aim", "strength", "walls", "gaps", "rising", "behind", "pocket", "upgrade", "heavy", "copper_final"][k]
			spec.start_row = [4, 4, 3, 3, 3, 3, 3, 3, 3, 2][k]
			spec.rows = [7, 8, 9, 9, 12, 11, 12, 13, 13, 14][k]
			if k >= 7:
				spec.upgrades = ["balls", "heavy"]
				spec.upgrade_every = 4
			if k == 8:
				spec.heavy = 1
		1:
			spec.balls = 12 + k / 3 * 2
			spec.heavy = 1 if k >= 4 else 0
			spec.upgrades = ["balls", "heavy"]
			spec.upgrade_every = 4
			spec.hint = "pockets" if k == 0 else ""
			spec.start_row = 3
			spec.rows = 13 + k / 2
		2:
			spec.balls = 14 + k / 3 * 2
			spec.heavy = 1
			spec.electric = 1 if k >= 2 else 0
			spec.upgrades = ["balls", "heavy", "electric"]
			spec.upgrade_every = 4
			spec.hint = "groups" if k == 0 else ("electric" if k == 2 else "")
			spec.start_row = 3
			spec.rows = 14 + k / 2
		3:
			spec.balls = 16 + k / 3 * 2
			spec.heavy = 1 + k / 5
			spec.electric = 1
			spec.upgrades = ["balls", "heavy", "electric"]
			spec.upgrade_every = 4
			spec.hint = "big" if k == 0 else ""
			spec.start_row = 3
			spec.rows = 15 + k / 2
		4:
			spec.balls = 18 + k / 3 * 2
			spec.heavy = 2
			spec.electric = 2 if k < 5 else 3
			spec.upgrades = ["balls", "heavy", "electric"]
			spec.upgrade_every = 4
			spec.hint = "combo" if k == 0 else ""
			spec.start_row = 2
			spec.rows = 16 + k / 2
	return spec

func build_layout(spec: Dictionary, rng: RandomNumberGenerator) -> Board:
	var b := Board.new()
	var ch: int = spec.ch
	var k: int = spec.k
	var r0: int = spec.start_row
	var rows: int = spec.rows
	if ch == 0:
		match k:
			0:  # aim: a short wall of soft stones straight below the cannon
				for c in [2, 3, 4]:
					b.put(c, r0 + 1, 1, 1, 0.6)
				b.put(3, r0 + 3, 1, 1, 0.8)
				b.put(1, r0 + 3, 1, 1, 0.8)
				b.put(5, r0 + 3, 1, 1, 0.8)
			1:  # strength: different numbers, weaker in front
				for c in 7:
					if c % 2 == 0:
						b.put(c, r0 + 1, 1, 1, 0.5 + 0.15 * c)
				for c in [1, 3, 5]:
					b.put(c, r0 + 3, 1, 1, 1.4)
			2:  # walls: stones in the corners under a central cap: bank shots off the walls
				b.put(2, r0, 2, 1, 1.0)
				b.put(4, r0, 1, 1, 1.0)
				for r in [r0 + 2, r0 + 3, r0 + 4]:
					b.put(0, r, 1, 1, 0.8)
					b.put(6, r, 1, 1, 0.8)
				b.put(3, r0 + 4, 1, 1, 1.0)
			3:  # gaps: a row with two holes, soft stones behind it
				for c in 7:
					if c != 1 and c != 5:
						b.put(c, r0 + 1, 1, 1, 1.2)
				for c in [0, 2, 3, 4, 6]:
					b.put(c, r0 + 4, 1, 1, 0.7)
			4:  # rising rows: rows keep coming from below
				for r in range(r0 + 1, rows, 2):
					for c in 7:
						if (c + r) % 3 != 0:
							b.put(c, r, 1, 1, 0.8)
			5:  # stones behind stones: shelves near the walls hide soft stones
				b.put(0, r0, 2, 1, 1.3)
				b.put(5, r0, 2, 1, 1.3)
				for c in [0, 1, 5, 6]:
					b.put(c, r0 + 2, 1, 1, 0.7)
				b.put(3, r0 + 1, 1, 2, 1.4)
				for c in [2, 4]:
					b.put(c, r0 + 4, 1, 1, 0.8)
				for r in range(r0 + 6, rows, 2):
					for c in [1, 3, 5]:
						b.put(c, r, 1, 1, 0.9)
			6:  # a pocket: a roof with a side entry, balls rattle inside
				for c in range(1, 6):
					b.put(c, r0 + 1, 1, 1, 1.2)
				b.put(5, r0 + 2, 1, 2, 1.2)
				for c in range(1, 5):
					b.put(c, r0 + 4, 1, 1, 0.8)
				for r in range(r0 + 6, rows, 2):
					for c in 7:
						if (c + r) % 2 == 0:
							b.put(c, r, 1, 1, 0.9)
			_:
				_scatter(b, rng, r0, rows, 0.45 + 0.04 * k, 0.15)
				_pocket(b, rng, r0 + 1, 1.2)
	elif ch == 1:
		# crystal vein: side pockets behind roofs, crystal veins inside
		var r := r0
		while r < rows - 2:
			_pocket(b, rng, r, 1.0 + 0.05 * k)
			r += 4
		_scatter(b, rng, r0, rows, 0.25, 0.2)
	elif ch == 2:
		# flooded tunnels: groups of different strength: a hard core with a soft shell
		var r := r0
		while r < rows - 2:
			_group(b, rng, r)
			r += 3 + rng.randi_range(0, 1)
		_scatter(b, rng, r0, rows, 0.2, 0.1)
	elif ch == 3:
		# obsidian depths: big blocks
		var r := r0
		while r < rows - 2:
			for i in 3:
				var w := 2 if rng.randf() < 0.7 else 1
				var h := 2 if rng.randf() < 0.6 else 1
				var c := rng.randi_range(0, 7 - w)
				b.put(c, r + rng.randi_range(0, 1), w, h, 1.0 + 0.6 * (w * h - 1) / 3.0)
			r += 3
		_scatter(b, rng, r0, rows, 0.3, 0.3)
	else:
		# heart of the mine: dense mixed rock, pockets and big blocks together
		var r := r0
		while r < rows - 3:
			if rng.randf() < 0.5:
				_pocket(b, rng, r, 1.2)
			else:
				_group(b, rng, r)
			r += 3
		_scatter(b, rng, r0, rows, 0.4, 0.35)
	return b

func _scatter(b: Board, rng: RandomNumberGenerator, r0: int, rows: int, dens: float, big: float) -> void:
	for r in range(r0, rows):
		for c in 7:
			if rng.randf() > dens:
				continue
			var roll := rng.randf()
			if roll < big * 0.5 and b.put(c, r, 2, 2, 1.8):
				continue
			if roll < big and b.put(c, r, 2, 1, 1.4):
				continue
			b.put(c, r, 1, 1, rng.randf_range(0.6, 1.3), rng.randf() < 0.08)

func _pocket(b: Board, rng: RandomNumberGenerator, r: int, roof_w: float) -> void:
	## A roof of stones with one side entry and soft stones (some with crystal veins) inside.
	var left := rng.randf() < 0.5
	var a := 0 if left else 2
	var e := 4 if left else 6
	for c in range(a, e + 1):
		b.put(c, r, 1, 1, roof_w)
	var wall := e if left else a
	b.put(wall, r + 1, 1, 1, roof_w)
	for c in range(a, e + 1):
		if c != wall and rng.randf() < 0.75:
			b.put(c, r + 2, 1, 1, 0.6, rng.randf() < 0.35)

func _group(b: Board, rng: RandomNumberGenerator, r: int) -> void:
	## A strong core with a soft shell around it.
	var c := rng.randi_range(1, 4)
	b.put(c, r + 1, 2, 1, 2.2)
	for p in [[c - 1, r + 1], [c + 2, r + 1], [c, r], [c + 1, r], [c, r + 2], [c + 1, r + 2]]:
		if rng.randf() < 0.8:
			b.put(p[0], p[1], 1, 1, 0.55)

func to_level(spec: Dictionary, b: Board, scale: float, n_rows: int) -> Dictionary:
	var rows: Array = []
	for r in n_rows:
		rows.append([])
	var pat := 0
	for st in b.stones:
		var r: int = st[1]
		while rows.size() <= r + int(st[3]):
			rows.append([])
		var hp := maxi(1, int(round(float(st[4]) * scale * (1.0 + 0.6 * (int(st[2]) * int(st[3]) - 1)))))
		rows[r].append([st[0], st[2], st[3], hp, pat % 4, 1 if st[5] else 0])
		pat += 1
	var id := "L%02d" % spec.n
	return {"id": id, "ver": LEVEL_VER, "n": spec.n, "chapter": spec.ch, "seed": 7000 + spec.n * 13,
		"balls": spec.balls, "heavy": spec.heavy, "electric": spec.electric, "upgrades": spec.upgrades,
		"upgrade_every": spec.upgrade_every, "hint": spec.hint, "rows": rows}

# ---------------------------------------------------------------- solver

func angle_set() -> Array:
	var lo := asin(Sim.MIN_VY) + 0.01
	var a: Array = []
	for i in n_angles:
		a.append(lo + (PI - 2.0 * lo) * (float(i) + 0.5) / n_angles)
	return a

func run_volley(s: Sim) -> void:
	var guard := 0
	while s.phase == Sim.PH_VOLLEY and guard < 20000:
		s.step()
		guard += 1

func remaining_hp(s: Sim) -> int:
	var t := 0
	for b in s.blocks.values():
		t += maxi(0, b.hp)
	for row in s.level_queue:
		for st in row:
			t += int(st[3])
	return t

func score(s: Sim) -> float:
	var danger := 0.0
	for b in s.blocks.values():
		var y: float = s.block_rect(b).position.y
		if y < Sim.DANGER_Y + 3.0 * Sim.CELL:
			danger += (Sim.DANGER_Y + 3.0 * Sim.CELL - y) / Sim.CELL * float(b.hp + 3)
	return float(remaining_hp(s)) + 2.0 * float(s.remaining_targets()) + danger * 1.5

func solve(level: Dictionary, max_volleys: int) -> Dictionary:
	var start := Sim.new()
	start.record_events = false
	start.new_level(level)
	var beam: Array = [{"sim": start, "route": []}]
	var angles := angle_set()
	for depth in max_volleys:
		var cands: Array = []
		var seen := {}
		for node in beam:
			var base: Sim = node.sim
			for a in angles:
				var c := base.clone()
				c.fire(a)
				run_volley(c)
				if c.phase == Sim.PH_WON:
					var route: Array = node.route.duplicate()
					route.append({"a": a})
					return {"won": true, "volleys": route.size(), "route": route}
				if c.phase == Sim.PH_OVER:
					continue
				var branches: Array = []
				if c.phase == Sim.PH_UPGRADE:
					for o in c.upgrade_opts:
						var c2 := c.clone()
						c2.choose_upgrade(o)
						branches.append([c2, o])
				else:
					branches.append([c, ""])
				for br in branches:
					var s2: Sim = br[0]
					var key := remaining_hp(s2) * 1000 + s2.balls * 10 + s2.heavy * 3 + s2.electric
					if seen.has(key):
						continue
					seen[key] = true
					var route2: Array = node.route.duplicate()
					var step := {"a": a}
					if br[1] != "":
						step["up"] = br[1]
					route2.append(step)
					cands.append({"sim": s2, "route": route2, "score": score(s2)})
		if cands.is_empty():
			return {"won": false, "volleys": depth, "route": []}
		cands.sort_custom(func(x, y): return x.score < y.score)
		beam = cands.slice(0, beam_w)
	return {"won": false, "volleys": max_volleys, "route": []}

func replay(level: Dictionary, route: Array) -> Dictionary:
	## The stored route from a fresh start, exactly as a player would fire it.
	var s := Sim.new()
	s.record_events = false
	s.new_level(level)
	var ticks := 0
	for step in route:
		if s.phase != Sim.PH_AIM:
			return {"ok": false, "why": "phase %d before a shot" % s.phase}
		s.fire(float(step.a))
		var g := 0
		while s.phase == Sim.PH_VOLLEY and g < 20000:
			s.step()
			g += 1
		ticks += g
		if s.phase == Sim.PH_UPGRADE:
			if not step.has("up") or not s.choose_upgrade(String(step.up)):
				return {"ok": false, "why": "upgrade"}
	return {"ok": s.phase == Sim.PH_WON, "volleys": s.volleys, "ticks": ticks, "gems": s.run_gems, "why": "phase %d" % s.phase}

func ordinary_player(level: Dictionary, attempts: int, cap: int) -> Dictionary:
	var wins := 0
	var vols: Array = []
	for i in attempts:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + i * 7
		var s := Sim.new()
		s.record_events = false
		s.new_level(level)
		var guard := 0
		while guard < cap and s.phase != Sim.PH_WON and s.phase != Sim.PH_OVER:
			guard += 1
			if s.phase == Sim.PH_UPGRADE:
				s.choose_upgrade(s.upgrade_opts[rng.randi_range(0, s.upgrade_opts.size() - 1)])
				continue
			var best_a := 1.2
			var best_v := -1.0
			for k in 3:
				var a := rng.randf_range(0.2, PI - 0.2)
				var c := s.clone()
				c.fire(a)
				run_volley(c)
				var v := float(remaining_hp(s) - remaining_hp(c)) + (1000.0 if c.phase == Sim.PH_WON else 0.0) - (500.0 if c.phase == Sim.PH_OVER else 0.0)
				if v > best_v:
					best_v = v
					best_a = a
			s.fire(best_a)
			run_volley(s)
		if s.phase == Sim.PH_WON:
			wins += 1
			vols.append(s.volleys)
	vols.sort()
	return {"wins": wins, "median": vols[vols.size() / 2] if not vols.is_empty() else 0, "attempts": attempts}

func useful_directions(level: Dictionary) -> int:
	## How many of the first-volley directions break or damage something.
	var s := Sim.new()
	s.record_events = false
	s.new_level(level)
	var hp0 := remaining_hp(s)
	var n := 0
	for a in angle_set():
		var c := s.clone()
		c.fire(a)
		run_volley(c)
		if remaining_hp(c) < hp0 - c.balls / 2:
			n += 1
	return n

# ordinary player: share of 8 attempts it must win, and the volleys its wins should take (1-3 minutes)
const ORDINARY := [
	{"wins": 7, "vol": [5, 10]},
	{"wins": 6, "vol": [9, 12]},
	{"wins": 6, "vol": [10, 13]},
	{"wins": 5, "vol": [11, 14]},
	{"wins": 5, "vol": [12, 15]},
]

func design(n: int) -> Dictionary:
	## Strength is set by an ordinary player (best of 3 random directions, 8 fixed attempts): the strongest
	## scale it still wins often enough, within the chapter's volley range. Then the beam search finds the
	## shortest win at that scale: T3. T2 lies between T3 and the ordinary player's median.
	var spec := level_spec(n)
	var ch: int = spec.ch
	var k: int = spec.k
	var need: int = ORDINARY[ch].wins
	var vol_hi := int(round(lerpf(ORDINARY[ch].vol[0], ORDINARY[ch].vol[1], k / 9.0)))
	var t0 := Time.get_ticks_msec()
	var best: Dictionary = {}
	for attempt in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = Sim.mix(4242, n * 31 + attempt)
		var board := build_layout(spec, rng)
		var n_rows: int = spec.rows
		var lo := 0.3
		var hi := 120.0
		var good: Dictionary = {}
		var scale := 2.0 + 0.6 * n
		for it in 10:
			var level := to_level(spec, board, scale, n_rows)
			var avg := ordinary_player(level, 8, vol_hi * 3 + 12)
			var passes: bool = avg.wins >= need and int(avg.median) <= vol_hi + 1
			log_line("  L%02d try %d it %d scale %.2f -> ordinary %d/8, median %d" % [n, attempt, it, scale, avg.wins, avg.median])
			if passes:
				if good.is_empty() or scale > float(good.scale):
					good = {"level": level, "avg": avg, "scale": scale}
				lo = scale
			else:
				hi = scale
			if hi < 120.0:
				scale = (lo + hi) * 0.5
			else:
				scale *= 1.8
			if hi - lo < 0.06 * lo:
				break
		if good.is_empty():
			continue
		var res := solve(good.level, int(good.avg.median) + 4)
		log_line("  L%02d try %d solver at scale %.2f -> %s in %d" % [n, attempt, good.scale, "won" if res.won else "no win", res.volleys])
		if res.won:
			best = {"level": good.level, "res": res, "scale": good.scale, "avg": good.avg}
			break
	if best.is_empty():
		log_line("L%02d: NO WINNING ROUTE" % n)
		return {}
	var level: Dictionary = best.level
	var rp := replay(level, best.res.route)
	var t3: int = best.res.volleys
	var avg: Dictionary = best.avg
	var med: int = int(avg.median)
	var t2: int = clampi(int(ceil((t3 + med) * 0.5)), t3 + 1, maxi(t3 + 1, med))
	level["t3"] = t3
	level["t2"] = t2
	var flight_s: float = float(rp.get("ticks", 0)) / 60.0
	var per_volley := flight_s / maxf(1.0, t3)
	level["proof"] = {"route": best.res.route, "replay_ok": rp.ok, "volleys": rp.get("volleys", -1), "flight_s": snappedf(flight_s, 0.1),
		"est_minutes": snappedf(t3 * (5.0 + per_volley * 0.8) / 60.0, 0.1), "useful_first": useful_directions(level), "angles": n_angles,
		"scale": snappedf(best.scale, 0.01), "design_s": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 1),
		"ordinary": avg, "est_minutes_ordinary": snappedf(med * (7.0 + per_volley * 0.8) / 60.0, 0.1)}
	var stones := 0
	for row in level.rows:
		stones += row.size()
	log_line("L%02d: %d stones, %d balls, T3=%d T2=%d, replay %s, 3-star route %.1f min, ordinary player wins %d/8, median %d volleys (~%.1f min), useful first directions %d/%d" % [
		n, stones, level.balls, t3, t2, "OK" if rp.ok else "FAILED " + String(rp.why), level.proof.est_minutes, avg.wins, med, level.proof.est_minutes_ordinary, level.proof.useful_first, n_angles])
	return level
