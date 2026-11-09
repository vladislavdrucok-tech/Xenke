extends SceneTree
## Builds data/levels.json (the 30 levels) and data/fallback.json (verified spare puzzles for
## "Another Puzzle" when the on-device generator runs out of budget).
## Run: godot --headless --path . --script tools/build_levels.gd
## Deterministic: the same seeds give the same files.

# level: [tiles, types, target difficulty, greedy rule]  greedy rule: 1 = greedy must win,
# 0 = either, -1 = greedy must fail (the level needs planning a few moves ahead)
const LADDER := [
	[9, 2, 0.0, 1], [9, 3, 0.5, 1], [12, 3, 1.0, 1], [12, 3, 1.5, 1], [12, 3, 2.0, 1],
	[15, 3, 2.5, 1], [15, 4, 3.0, 1], [15, 4, 3.5, 0], [18, 3, 3.5, 0], [18, 4, 4.0, 0],
	[18, 4, 4.5, 0], [18, 4, 5.0, 0], [21, 4, 5.5, 0], [21, 4, 6.0, 0], [21, 5, 6.5, 0],
	[21, 5, 7.0, -1], [24, 4, 7.0, -1], [24, 5, 7.5, -1], [24, 5, 8.0, -1], [24, 5, 8.5, -1],
	[24, 5, 9.0, -1], [27, 5, 9.0, -1], [27, 5, 9.5, -1], [27, 5, 10.0, -1], [27, 5, 10.5, -1],
	[30, 5, 10.5, -1], [30, 5, 11.0, -1], [30, 5, 11.5, -1], [30, 5, 12.0, -1], [30, 5, 12.5, -1],
]
const CANDIDATES := 2500
const FALLBACK_COUNT := 150


func _init() -> void:
	var levels := []
	var used := {}
	for li in LADDER.size():
		var spec: Array = LADDER[li]
		var best := {}
		var best_d := 1e9
		for j in CANDIDATES:
			var seed := (li + 1) * 100000 + j
			var rng := Generator._rng(seed, 0)
			var layout := Generator.make_layout(rng, spec[0], spec[1])
			if used.has(str(layout)):
				continue
			var m := Solver.analyze(layout)
			if not m["solvable"] or int(m["types"]) != spec[1]:
				continue
			if spec[3] == 1 and not m["greedy"]:
				continue
			if spec[3] == -1 and (m["greedy"] or int(m["critical"]) < 2):
				continue
			var d: float = absf(float(m["score"]) - float(spec[2]))
			if li == 0:
				# First level: a calm, readable layout (every type visible near the top).
				d += absf(float(m["p_careful"]) - 1.0)
			if d < best_d:
				best_d = d
				best = Generator.make_puzzle(seed, 0, layout, m)
				best["critical"] = m["critical"]
			if best_d < 0.04:
				break
		best["level"] = li + 1
		used[str(best["stacks"])] = true
		levels.append(best)
		print("L%02d tiles %2d types %d target %5.2f got %5.2f greedy %s critical %d peak %d p_careful %.4f seed %d" % [
			li + 1, best["items"], best["types"], spec[2], best["score"], best["greedy"], best["critical"],
			best["min_peak"], best["p_careful"] if best.has("p_careful") else 0.0, best["seed"]])
	_write("res://data/levels.json", {"version": 1, "tray": Rules.TRAY_SIZE, "levels": levels})

	var pool := []
	var k := 0
	var seed := 900000
	while pool.size() < FALLBACK_COUNT:
		var tier: Dictionary = Puzzles.endless_tier(k)
		var r := Generator.generate(seed, tier, 60000000, 3000)
		if r["ok"]:
			var p: Dictionary = r["puzzle"]
			p["tier"] = k % Puzzles.ENDLESS_TIERS.size()
			pool.append(p)
			k += 1
		seed += 1
	_write("res://data/fallback.json", {"version": 1, "puzzles": pool})
	print("fallback puzzles: ", pool.size())
	quit()


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false))
	f.close()
	print("wrote ", path)
