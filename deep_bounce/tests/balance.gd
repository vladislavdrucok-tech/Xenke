extends Node
## Pacing check: bots of three skill levels play full runs; prints depth, estimated play time and crystals.
##   godot --headless --path . res://tests/balance.tscn -- [--runs=N] [--skill=good|avg|weak|all]
## Time estimate per volley: 3.5 s aiming + real flight time with the game's speed-up (1x for 3.5 s,
## 2x until 8 s, 3x after) + 0.5 s shift; plus 3 s for each upgrade choice.

var runs := 6
var skills := ["weak", "avg", "good"]
var tune := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--skill=") and a.substr(8) != "all":
			skills = a.substr(8).split(",")
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
		s.set(k, tune[k])
	s.new_run(seed)
	s.record_events = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var time := 0.0
	var ups := {"balls": 0, "heavy": 0, "electric": 0}
	var guard := 0
	while s.phase != Sim.PH_OVER and guard < 400:
		guard += 1
		if s.phase == Sim.PH_UPGRADE:
			var o: String = s.upgrade_opts[rng.randi_range(0, s.upgrade_opts.size() - 1)]
			ups[o] += 1
			s.choose_upgrade(o)
			time += 3.0
			continue
		var ang := pick_angle(s, skill, rng)
		s.fire(ang)
		var ticks := 0
		while s.phase == Sim.PH_VOLLEY:
			s.step()
			ticks += 1
		time += 3.5 + volley_seconds(ticks) + 0.5
	return {"depth": s.depth, "time": time, "gems": s.run_gems, "picks": s.picks, "ups": ups}

func pick_angle(s: Sim, skill: String, rng: RandomNumberGenerator) -> float:
	var tries := 1
	match skill:
		"avg":
			tries = 3
		"good":
			tries = 8
	if tries == 1:
		return rng.randf_range(0.2, PI - 0.2)
	var best := 1.2
	var best_score := -1.0
	for i in tries:
		var a := 0.18 + (PI - 0.36) * (float(i) + rng.randf()) / tries
		var c := s.clone()
		c.fire(a)
		var n := 0
		while c.phase == Sim.PH_VOLLEY and n < 4000:
			c.step()
			n += 1
		var score: float = float(c.v_damage) + c.stats.destroyed * 3.0
		if score > best_score:
			best_score = score
			best = a
	return best
