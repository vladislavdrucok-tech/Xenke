extends SceneTree
## Prints difficulty distributions of random layouts so the level ladder can be tuned.
func _init():
	var combos = [[9,2],[9,3],[12,3],[15,3],[15,4],[18,3],[18,4],[21,4],[21,5],[24,4],[24,5],[27,5],[30,4],[30,5]]
	for cb in combos:
		var scores = []
		var unsolv = 0
		var t0 = Time.get_ticks_usec()
		var greedy = 0
		var peaks = {}
		var N = 300
		for s in N:
			var rng = RandomNumberGenerator.new()
			rng.seed = s * 7777 + cb[0] * 31 + cb[1]
			var lay = Generator.make_layout(rng, cb[0], cb[1])
			var m = Solver.analyze(lay)
			if not m.solvable:
				unsolv += 1
				continue
			scores.append(m.score)
			if m.greedy: greedy += 1
			peaks[m.min_peak] = peaks.get(m.min_peak, 0) + 1
		var dt = (Time.get_ticks_usec() - t0) / N
		scores.sort()
		var q = func(f): return scores[int(f * (scores.size() - 1))] if scores.size() > 0 else -1
		print("%2d items %d types: unsolv %3d/%d greedy %3d peaks %s score p10 %.2f p25 %.2f p50 %.2f p75 %.2f p90 %.2f max %.2f %d us" % [cb[0], cb[1], unsolv, N, greedy, peaks, q.call(0.1), q.call(0.25), q.call(0.5), q.call(0.75), q.call(0.9), q.call(1.0), dt])
	quit()
