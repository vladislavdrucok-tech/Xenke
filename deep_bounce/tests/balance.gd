extends Node
## Pacing check: bots of three skill levels play full runs; prints depth, estimated play time and crystals.
##   godot --headless --path . res://tests/balance.tscn -- [--runs=N] [--skill=good|avg|weak|all]
## Time estimate per volley: 3.5 s aiming + real flight time with the game's speed-up (1x for 3.5 s,
## 2x until 8 s, 3x after) + 0.5 s shift; plus 3 s for each upgrade choice.

var runs := 6
var skills := ["weak", "avg", "good"]
var tune := {}
var no_upgrades := false
var fate := {}       # size class -> [broken before the danger rows, reached the danger rows]
var occ := {}        # depth bucket -> [turns, sum of active stones, sum of occupied rows, turns with < 5 stones]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--skill=") and a.substr(8) != "all":
			skills = a.substr(8).split(",")
		elif a == "--noup":
			no_upgrades = true
		elif a.begins_with("--set="):
			for kv in a.substr(6).split(","):
				var p := kv.split(":")
				tune[p[0]] = float(p[1])
	var report: PackedStringArray = []
	for skill in skills:
		var depths: Array = []
		var times: Array = []
		var gems: Array = []
		var picks: Array = []
		for r in runs:
			var res := play(skill, 1000 + r * 17)
			depths.append(res.depth)
			times.append(res.time)
			gems.append(res.gems)
			picks.append(res.picks)
			print("%s run %d: depth %d m, %.1f min, %d crystals, %s" % [skill, r, res.depth, res.time / 60.0, res.gems, res.ups])
		var line := "%s: depth avg %.1f (min %d max %d), time avg %.1f min (min %.1f max %.1f), crystals avg %.1f/run" % [
			skill, avg(depths), depths.min(), depths.max(), avg(times) / 60.0, times.min() / 60.0, times.max() / 60.0, avg(gems)]
		print(line)
		report.append(line)
		for cls in ["1x1", "2 cells", "2x2"]:
			if fate.has(cls):
				var tot: int = fate[cls][0] + fate[cls][1]
				var fl := "  %s: broken before the danger rows %d%% (%d of %d)" % [cls, 100 * fate[cls][0] / maxi(1, tot), fate[cls][0], tot]
				print(fl)
				report.append(fl)
		fate = {}
		var keys := occ.keys()
		keys.sort()
		for k in keys:
			var o: Array = occ[k]
			var ol := "  field at %d-%s m: %.1f stones, %.1f rows in use, nearly empty (< 5 stones) in %d%% of turns" % [k * 10, str(k * 10 + 9) if k < 4 else "…", float(o[1]) / o[0], float(o[2]) / o[0], 100 * o[3] / o[0]]
			print(ol)
			report.append(ol)
		occ = {}
	var f := FileAccess.open("user://balance.txt", FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	get_tree().quit()

func avg(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / maxf(1.0, a.size())

func volley_seconds(ticks: int) -> float:
	var sim_s := ticks / 60.0
	var real := 0.0
	var seg1 := minf(sim_s, 3.5)
	real += seg1
	sim_s -= seg1
	var seg2 := minf(sim_s, (8.0 - 3.5) * 2.0)
	real += seg2 / 2.0
	sim_s -= seg2
	real += maxf(0.0, sim_s) / 3.0
	return real

func play(skill: String, seed: int) -> Dictionary:
	var s := Sim.new()
	for k in tune:
		s.set(k, int(tune[k]) if k == "start_empty" else tune[k])
	s.new_run(seed)
	s.record_events = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var time := 0.0
	var ups := {"balls": 0, "heavy": 0, "electric": 0}
	var seen_fate := {}
	var guard := 0
	while s.phase != Sim.PH_OVER and guard < 400:
		guard += 1
		if s.phase == Sim.PH_UPGRADE and no_upgrades:
			s.upgrade_opts = []
			s.phase = Sim.PH_AIM
			continue
		if s.phase == Sim.PH_UPGRADE:
			var o: String = s.upgrade_opts[rng.randi_range(0, s.upgrade_opts.size() - 1)]
			ups[o] += 1
			s.choose_upgrade(o)
			time += 3.0
			continue
		# how full is the field the player looks at before this shot
		var stones := 0
		var top_row := 99
		for b0 in s.blocks.values():
			if not s.is_future(b0):
				stones += 1
				top_row = mini(top_row, b0.r - s.top)
		var rows_used := 0 if stones == 0 else Sim.VIS_ROWS - top_row
		var bucket := mini(4, s.depth / 10)
		if not occ.has(bucket):
			occ[bucket] = [0, 0, 0, 0]
		occ[bucket][0] += 1
		occ[bucket][1] += stones
		occ[bucket][2] += rows_used
		if stones < 5:
			occ[bucket][3] += 1
		var ang := pick_angle(s, skill, rng)
		var before := {}
		for id in s.blocks:
			before[id] = s.blocks[id]
		s.fire(ang)
		var ticks := 0
		while s.phase == Sim.PH_VOLLEY:
			s.step()
			ticks += 1
		# fate of stones: broken before reaching the two rows under the red line, or not
		for id in before:
			var b: Dictionary = before[id]
			var cls := "1x1" if b.w * b.h == 1 else ("2 cells" if b.w * b.h == 2 else "2x2")
			if not fate.has(cls):
				fate[cls] = [0, 0]
			if seen_fate.has(id):
				continue
			if not s.blocks.has(id):
				fate[cls][0] += 1
				seen_fate[id] = true
			elif s.blocks[id].r - s.top <= 1:
				fate[cls][1] += 1
				seen_fate[id] = true
		time += 3.5 + volley_seconds(ticks) + 0.5
	var killers := ""
	for b in s.blocks.values():
		if s.crosses_line(b, 0):
			killers += "[%dx%d col %d hp %d/%d] " % [b.w, b.h, b.c, b.hp, b.mhp]
	var n_active := 0
	for b in s.blocks.values():
		if not s.is_future(b):
			n_active += 1
	ups["killers"] = killers
	ups["stones_at_end"] = n_active
	return {"depth": s.depth, "time": time, "gems": s.run_gems, "picks": s.picks, "ups": ups}

func aim_at(s: Sim, b: Dictionary) -> float:
	## Direct shot at a stone: the aim line shows the first contact, so a person can do this.
	var c := s.block_rect(b).get_center()
	var ang := PI * 0.5
	for k in 3:
		ang = (c - Sim.muzzle(ang)).angle()
	return Sim.clamp_aim(ang)

func threats(s: Sim, max_row: int) -> Array:
	## Active stones in the rows closest to the red line, highest first.
	var list: Array = []
	for b in s.blocks.values():
		if not s.is_future(b) and b.r - s.top <= max_row:
			list.append(b)
	list.sort_custom(func(x, y): return x.r < y.r or (x.r == y.r and x.id < y.id))
	return list

func pick_angle(s: Sim, skill: String, rng: RandomNumberGenerator) -> float:
	## weak: a beginner. Random direction, but shoots straight at a stone that is about to cross the line.
	## avg: best of 3 random directions and a direct shot at the highest stone (if it is in the upper rows).
	## good: best of 8 random directions and direct shots at the two highest stones.
	if skill == "weak":
		var th := threats(s, 1)
		if not th.is_empty():
			return Sim.clamp_aim(aim_at(s, th[0]) + rng.randf_range(-0.05, 0.05))
		return rng.randf_range(0.2, PI - 0.2)
	var tries := 3 if skill == "avg" else 8
	var cands: Array = []
	for i in tries:
		cands.append(0.18 + (PI - 0.36) * (float(i) + rng.randf()) / tries)
	var th2 := threats(s, 3)
	for i in mini(th2.size(), 1 if skill == "avg" else 2):
		cands.append(aim_at(s, th2[i]))
	var best := 1.2
	var best_score := -1e9
	for a in cands:
		var c := s.clone()
		c.fire(a)
		var n := 0
		while c.phase == Sim.PH_VOLLEY and n < 4000:
			c.step()
			n += 1
		var score: float = float(c.v_damage) + c.stats.destroyed * 3.0
		# a person watches the red line: never pick a shot that ends the run if another one does not,
		# and prefer shots that leave fewer stones about to cross
		if c.phase == Sim.PH_OVER:
			score -= 1000.0
		else:
			for b in c.blocks.values():
				if c.will_cross_next(b):
					score -= 25.0
		if score > best_score:
			best_score = score
			best = a
	return best
