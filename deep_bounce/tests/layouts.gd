extends Node
## Layout quality with real volleys: generator 1 (release 1.0) against generator 2 (groups, side passages,
## pockets). A bot plays each seed down to 8/16/24/29 m; on each board 24 directions are fired.
##   godot --headless --path . res://tests/layouts.tscn -- [--seeds=N]
## Per board: hits per ball (direct ball-to-stone hits / balls) averaged over directions, the best direction,
## and the share of "useful" directions (>= 3 hits per ball). Problem boards are listed with seed and details.

const S29 := preload("res://scripts/qa_s29.gd")
var seeds := 12
var out: PackedStringArray = []

func p(s: String) -> void:
	print(s)
	out.append(s)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
	p("## The reported board (29 m, 16 balls, heavy 1, electric 2)")
	var s := Sim.new()
	S29.new().build(s)
	var r := evaluate(s, true)
	p("hits/ball mean %.2f, best %.2f, useful %.0f%%" % [r.mean, r.best, r.useful * 100.0])
	for g in [1, 2]:
		p("")
		p("## Generator %d" % g)
		# 1) fresh rock: the field exactly as generated, nothing broken yet
		var fresh := {}
		var problems: Array = []
		for i in seeds:
			var sd := 7000 + i * 31
			for dep in [10, 20, 30]:
				var st := fresh_board(g, sd, dep)
				var ev := evaluate(st, false)
				if not fresh.has(dep):
					fresh[dep] = [[], [], []]
				fresh[dep][0].append(ev.mean)
				fresh[dep][1].append(ev.best)
				fresh[dep][2].append(ev.useful)
				if ev.best < 2.0 or ev.useful == 0.0:
					problems.append([sd, st, ev])
		for dep in [10, 20, 30]:
			p("  fresh rock %d m (%d balls): hits/ball mean %.2f, best direction %.2f, useful directions %.0f%%" % [dep, fresh_balls(dep), avg(fresh[dep][0]), avg(fresh[dep][1]), avg(fresh[dep][2]) * 100.0])
		p("  problem boards (best < 2 hits/ball or no direction with >= 3): %d of %d" % [problems.size(), seeds * 3])
		for pr in problems.slice(0, 5):
			var st: Sim = pr[1]
			var ev: Dictionary = pr[2]
			p("    seed %d, %d m, %d balls, heavy %d, electric %d: best %.2f; by direction %s" % [pr[0], st.depth, st.balls, st.heavy, st.electric, ev.best, ev.sample])
		# 2) real play: the shots an average player takes (best of 3 directions)
		var depths: Array = []
		var shot_hpb: Array = []
		for i in seeds:
			var res := play_run(g, 7000 + i * 31)
			depths.append(res.depth)
			shot_hpb.append(res.hpb)
		p("  played (best of 3 directions): depth %.1f m, hits per ball in the chosen shots %.2f" % [avg(depths), avg(shot_hpb)])
	var f := FileAccess.open("user://layouts.txt", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	get_tree().quit()

func avg(a: Array) -> float:
	var t := 0.0
	for x in a:
		t += float(x)
	return t / maxf(1.0, a.size())

func evaluate(s: Sim, verbose: bool) -> Dictionary:
	var hpb: Array = []
	var sample := ""
	for i in 24:
		var ang := 0.2 + (PI - 0.4) * float(i) / 23.0
		var c := s.clone()
		c.phase = Sim.PH_AIM
		c.fire(ang)
		var n := 0
		while c.phase == Sim.PH_VOLLEY and n < 5000:
			c.step()
			n += 1
		var h := float(c.v_hits) / float(c.v_total)
		hpb.append(h)
		if i % 5 == 0:
			sample += "%.0f°:%.1f " % [rad_to_deg(ang), h]
		if verbose:
			p("  %5.1f°  hits/ball %.2f  damage %d  broken %d  flight %.1f s" % [rad_to_deg(ang), h, c.v_damage, c.stats.destroyed - s.stats.destroyed, n / 60.0])
	var useful := 0
	for h in hpb:
		if h >= 3.0:
			useful += 1
	return {"mean": avg(hpb), "best": hpb.max(), "useful": float(useful) / hpb.size(), "sample": sample}

func fresh_balls(dep: int) -> int:
	return mini(32, 8 + 2 * (dep / 4) / 2 * 2 / 2)

func fresh_board(g: int, sd: int, dep: int) -> Sim:
	## Rock as the generator delivers it: shift the field `dep` times without breaking anything,
	## with the balls and upgrades a player typically has at that depth.
	var s := Sim.new()
	s.gen = g
	s.new_run(sd)
	s.record_events = false
	var picks := dep / 4
	s.balls = mini(32, 8 + 2 * (picks / 2 + picks % 2))
	s.heavy = mini(3, picks / 4)
	s.electric = mini(3, (picks + 2) / 4)
	for i in dep:
		s.top += 1
		s.depth += 1
		s._ensure_rows()
	# keep only rock that is below the red line (as in a live run)
	for id in s.blocks.keys():
		if s.blocks[id].r < s.top:
			var b: Dictionary = s.blocks[id]
			for yy in b.h:
				for xx in b.w:
					s.grid.erase((b.r + yy) * Sim.COLS + b.c + xx)
			s.blocks.erase(id)
	return s

func play_run(g: int, sd: int) -> Dictionary:
	var s := Sim.new()
	s.gen = g
	s.new_run(sd)
	s.record_events = false
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var hp_sum := 0.0
	var shots := 0
	var guard := 0
	while s.phase != Sim.PH_OVER and guard < 300:
		guard += 1
		if s.phase == Sim.PH_UPGRADE:
			s.choose_upgrade(s.upgrade_opts[rng.randi_range(0, s.upgrade_opts.size() - 1)])
			continue
		var best := 1.2
		var bs := -1.0
		for i in 3:
			var a := 0.2 + (PI - 0.4) * (float(i) + rng.randf()) / 3.0
			var c := s.clone()
			c.fire(a)
			while c.phase == Sim.PH_VOLLEY:
				c.step()
			if c.v_damage > bs:
				bs = c.v_damage
				best = a
		s.fire(best)
		while s.phase == Sim.PH_VOLLEY:
			s.step()
		hp_sum += float(s.v_hits) / float(s.balls)
		shots += 1
	return {"depth": s.depth, "hpb": hp_sum / maxf(1.0, shots)}

func play_to_depths(g: int, sd: int, depths: Array) -> Array:
	var s := Sim.new()
	s.gen = g
	s.new_run(sd)
	s.record_events = false
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var res: Array = []
	var guard := 0
	while s.phase != Sim.PH_OVER and guard < 200 and res.size() < depths.size():
		guard += 1
		if s.phase == Sim.PH_UPGRADE:
			s.choose_upgrade(s.upgrade_opts[rng.randi_range(0, s.upgrade_opts.size() - 1)])
			continue
		if depths.has(s.depth) and (res.is_empty() or res[-1].depth != s.depth):
			res.append(s.clone())
		# an average player: best of 3 directions
		var best := 1.2
		var bs := -1.0
		for i in 3:
			var a := 0.2 + (PI - 0.4) * (float(i) + rng.randf()) / 3.0
			var c := s.clone()
			c.fire(a)
			while c.phase == Sim.PH_VOLLEY:
				c.step()
			if c.v_damage > bs:
				bs = c.v_damage
				best = a
		s.fire(best)
		while s.phase == Sim.PH_VOLLEY:
			s.step()
	return res
