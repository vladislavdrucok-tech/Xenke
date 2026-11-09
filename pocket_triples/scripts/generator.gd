class_name Generator
extends RefCounted
## Seeded layout generator. A puzzle is only handed out after Solver.analyze() has found a line
## that empties all four stacks with a five-slot tray, and its difficulty falls into the wanted band.
## Same seed + same tier -> same puzzle on every device.

const MAX_HEIGHT := 9


static func _rng(seed: int, attempt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed * 1000003 + attempt * 7919 + 17) & 0x7fffffffffffffff
	return rng


static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## Random layout with `items` tiles (multiple of 3) of `types` kinds dealt into the four stacks.
static func make_layout(rng: RandomNumberGenerator, items: int, types: int, max_height := MAX_HEIGHT) -> Array:
	items = maxi(3, items - items % Rules.MATCH)
	types = clampi(types, 1, mini(Rules.TYPE_COUNT, items / Rules.MATCH))
	var triples := items / Rules.MATCH
	var per_type := []
	for t in types:
		per_type.append(1)
	for k in triples - types:
		per_type[rng.randi_range(0, types - 1)] += 1
	var palette := [0, 1, 2, 3, 4]
	_shuffle(rng, palette)
	var tiles := []
	for i in types:
		for c in per_type[i] * Rules.MATCH:
			tiles.append(palette[i])
	_shuffle(rng, tiles)
	# Stack heights: close to even, a little uneven so stacks read differently.
	var heights := []
	for i in Rules.STACKS:
		heights.append(items / Rules.STACKS)
	for k in items % Rules.STACKS:
		heights[rng.randi_range(0, Rules.STACKS - 1)] += 1
	var avg := float(items) / Rules.STACKS
	var lo := maxi(1, int(floor(avg)) - 2)
	var hi := mini(max_height, int(ceil(avg)) + 2)
	for k in 6:
		var a := rng.randi_range(0, Rules.STACKS - 1)
		var b := rng.randi_range(0, Rules.STACKS - 1)
		if a != b and heights[a] - 1 >= lo and heights[b] + 1 <= hi:
			heights[a] -= 1
			heights[b] += 1
	var layout := []
	var p := 0
	for i in Rules.STACKS:
		var col := []
		for j in heights[i]:
			col.append(tiles[p])
			p += 1
		layout.append(col)
	return layout


## tier: {"items": [min, max], "types": [min, max], "score": [lo, hi]}
## Tries seeded attempts until one is verified and in band, or until the time / attempt budget runs out.
static func generate(seed: int, tier: Dictionary, budget_usec := 1500000, max_attempts := 400) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var items_r: Array = tier.get("items", [21, 30])
	var types_r: Array = tier.get("types", [4, 5])
	var band: Array = tier.get("score", [0.0, 99.0])
	var best := {}
	var attempts := 0
	for a in max_attempts:
		if a > 0 and Time.get_ticks_usec() - t0 > budget_usec:
			break
		attempts += 1
		var rng := _rng(seed, a)
		var items := rng.randi_range(int(items_r[0]) / 3, int(items_r[1]) / 3) * 3
		var types := rng.randi_range(int(types_r[0]), int(types_r[1]))
		var layout := make_layout(rng, items, types)
		var m := Solver.analyze(layout)
		if not m["solvable"]:
			continue
		var score: float = m["score"]
		if score >= float(band[0]) and score <= float(band[1]):
			return {"ok": true, "attempts": attempts, "usec": Time.get_ticks_usec() - t0,
				"puzzle": make_puzzle(seed, a, layout, m)}
	return {"ok": false, "attempts": attempts, "usec": Time.get_ticks_usec() - t0}


static func make_puzzle(seed: int, attempt: int, layout: Array, m: Dictionary) -> Dictionary:
	return {
		"seed": seed,
		"attempt": attempt,
		"stacks": layout,
		"solution": m["solution"],
		"score": m["score"],
		"items": m["items"],
		"types": m["types"],
		"min_peak": m["min_peak"],
		"p_random": snappedf(m["p_random"], 0.0001),
		"p_careful": snappedf(m["p_careful"], 0.0001),
		"critical": m["critical"],
		"greedy": m["greedy"],
	}


## Rebuilds the layout of a stored puzzle from its seed (used by the tests to prove the seed is enough).
static func regenerate_layout(seed: int, attempt: int, tier: Dictionary) -> Array:
	var rng := _rng(seed, attempt)
	var items_r: Array = tier.get("items", [21, 30])
	var types_r: Array = tier.get("types", [4, 5])
	var items := rng.randi_range(int(items_r[0]) / 3, int(items_r[1]) / 3) * 3
	var types := rng.randi_range(int(types_r[0]), int(types_r[1]))
	return make_layout(rng, items, types)
