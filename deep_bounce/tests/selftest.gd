extends Node
## Headless checks of the rules: godot --headless --path . res://tests/selftest.tscn
## Prints one line per check and "SELFTEST PASS"/"SELFTEST FAIL" at the end.

var fails := 0
var lines: PackedStringArray = []

func ok(cond: bool, name: String, info := "") -> void:
	var s := ("PASS  " if cond else "FAIL  ") + name + ("" if info == "" else "  (" + info + ")")
	print(s)
	lines.append(s)
	if not cond:
		fails += 1

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	test_determinism()
	test_snapshot_resume()
	test_generation()
	test_preview_matches_flight()
	test_corner_and_seam()
	test_simultaneous_break()
	test_heavy_levels()
	test_electric_levels()
	test_upgrade_limits()
	test_volleys_always_end()
	test_longest_volley()
	test_save_roundtrip()
	print("time %d ms" % (Time.get_ticks_msec() - t0))
	print("SELFTEST " + ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	var f := FileAccess.open("user://selftest.log", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
	get_tree().quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------- helpers

func run_volley(s: Sim, angle: float) -> int:
	s.fire(angle)
	var n := 0
	while s.phase == Sim.PH_VOLLEY and n < 100000:
		s.step()
		n += 1
	return n

func empty_sim() -> Sim:
	var s := Sim.new()
	s.new_run(7)
	s.blocks = {}
	s.grid = {}
	s.record_events = true
	s.events = []
	return s

func put(s: Sim, c: int, vr: int, w: int, h: int, hp: int) -> int:
	var id := s.next_id
	s._add_block({"c": c, "r": s.top + vr, "w": w, "h": h, "hp": hp, "g": w * h, "v": 0, "vein": false})
	return id

func launch(s: Sim, x: float, y: float, vx: float, vy: float, kind := Sim.K_NORMAL) -> Sim.Ball:
	if s.phase != Sim.PH_VOLLEY:
		s.phase = Sim.PH_VOLLEY
		s.v_tick = 1
		s.v_total = 0
		s.v_launched = 0
		s.v_balls = []
	var b := Sim.Ball.new()
	var l := sqrt(vx * vx + vy * vy)
	b.x = x; b.y = y; b.vx = vx / l * Sim.SPEED; b.vy = vy / l * Sim.SPEED; b.k = kind
	b.idx = s.v_total
	s.v_balls.append(b)
	s.v_total += 1
	s.v_launched += 1
	return b

func count_ev(s: Sim, t: String) -> int:
	var n := 0
	for e in s.events:
		if e.t == t:
			n += 1
	return n

# ---------------------------------------------------------------- tests

func test_determinism() -> void:
	var good := true
	for sd in [1, 42, 9001]:
		var a := Sim.new(); a.new_run(sd)
		var b := Sim.new(); b.new_run(sd)
		for v in 6:
			var ang := 0.4 + 0.37 * v
			run_volley(a, ang)
			run_volley(b, ang)
			if a.phase == Sim.PH_UPGRADE:
				a.choose_upgrade(a.upgrade_opts[0]); b.choose_upgrade(b.upgrade_opts[0])
			if a.phase == Sim.PH_OVER:
				break
		good = good and a.state_hash() == b.state_hash()
	ok(good, "same state + same angle -> same result (3 seeds x 6 volleys)")

func test_snapshot_resume() -> void:
	var good := true
	var info := ""
	for cut in [1, 37, 90, 210]:
		var a := Sim.new(); a.new_run(1234)
		a.balls = 16; a.heavy = 2; a.electric = 2
		run_volley(a, 1.1)
		a.fire(0.83)
		for i in cut:
			a.step()
		var saved := JSON.stringify(a.to_dict(), "", true, true)
		var b := Sim.new()
		b.from_dict(JSON.parse_string(saved))
		while a.phase == Sim.PH_VOLLEY:
			a.step()
		while b.phase == Sim.PH_VOLLEY:
			b.step()
		if a.state_hash() != b.state_hash():
			good = false
			info += "cut %d differs; " % cut
	ok(good, "volley interrupted at ticks 1/37/90/210, saved as JSON and resumed -> identical outcome", info)

func test_generation() -> void:
	var bad_overlap := 0
	var bad_open := 0
	var bad_reach := 0
	var bad_start := 0
	var max_start_hp := 0
	var N := 1500
	for sd in N:
		var s := Sim.new()
		s.new_run(sd * 7919 + 11)
		# simulate 8 shifts with no stone broken: the opening must stay passable
		for turn in 9:
			var occ := {}
			for b in s.blocks.values():
				for yy in b.h:
					for xx in b.w:
						var k: int = (b.r + yy) * Sim.COLS + b.c + xx
						if occ.has(k):
							bad_overlap += 1
						occ[k] = true
				if turn == 0:
					max_start_hp = maxi(max_start_hp, b.hp)
			if turn == 0:
				for b in s.blocks.values():
					if b.r < 4:
						bad_start += 1
			for r in range(s.top, s.gen_rows):
				var open := 0
				for c in Sim.COLS:
					if not occ.has(r * Sim.COLS + c):
						open += 1
				if r >= 4 and open < 2:
					bad_open += 1
			if not _reach_floor(s, occ):
				bad_reach += 1
			s.top += 1
			s.depth += 1
			s._ensure_rows()
	ok(bad_overlap == 0, "generation: no overlapping stones (%d seeds x 9 turns)" % N)
	ok(bad_open == 0, "generation: every row keeps >= 2 open cells", "%d bad rows" % bad_open)
	ok(bad_reach == 0, "generation: the floor is reachable from the top in the opening turns", "%d blocked boards" % bad_reach)
	ok(bad_start == 0 and max_start_hp <= 5, "opening board: 4 empty rows, strength <= 5", "max hp %d" % max_start_hp)

func _reach_floor(s: Sim, occ: Dictionary) -> bool:
	var last := s.top + Sim.VIS_ROWS - 1
	var stack: Array = []
	var seen := {}
	for c in Sim.COLS:
		var k := s.top * Sim.COLS + c
		if not occ.has(k):
			stack.append(k); seen[k] = true
	while not stack.is_empty():
		var k: int = stack.pop_back()
		var r := k / Sim.COLS
		var c := k % Sim.COLS
		if r == last:
			return true
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nr: int = r + d[1]
			var nc: int = c + d[0]
			if nc < 0 or nc >= Sim.COLS or nr < s.top or nr > last:
				continue
			var nk := nr * Sim.COLS + nc
			if occ.has(nk) or seen.has(nk):
				continue
			seen[nk] = true
			stack.append(nk)
	return false

func test_preview_matches_flight() -> void:
	var worst := 0.0
	var checked := 0
	for sd in 40:
		var s := Sim.new(); s.new_run(500 + sd)
		var ang := 0.25 + 2.6 * float(sd) / 39.0
		var pts := s.preview(ang)
		s.fire(ang)
		var first := Vector2.INF
		while s.phase == Sim.PH_VOLLEY and first == Vector2.INF:
			s.step()
			for e in s.events:
				if (e.t == "hit" or e.t == "wall") and first == Vector2.INF:
					first = Vector2(e.x, e.y)
			s.events.clear()
		if first != Vector2.INF and pts.size() >= 2:
			worst = maxf(worst, first.distance_to(pts[1]))
			checked += 1
	ok(worst < 0.5 and checked >= 35, "aim line: first contact equals the real first contact", "%d shots, max error %.4f px" % [checked, worst])

func test_corner_and_seam() -> void:
	# a lone stone: a ball aimed at its top-left corner leaves diagonally
	var s := empty_sim()
	put(s, 3, 4, 1, 1, 99)
	var rc: Rect2 = s.block_rect(s.blocks.values()[0])
	var c := rc.position
	launch(s, c.x - 40.0, c.y - 40.0, 1.0, 1.0)
	var b: Sim.Ball = s.v_balls[0]
	for i in 6:
		s.step()
	ok(b.vx < -0.5 * Sim.SPEED and b.vy < -0.5 * Sim.SPEED, "corner hit reflects diagonally", "v=(%.0f, %.0f)" % [b.vx, b.vy])
	# two touching stones: a ball falling on the seam bounces straight up
	s = empty_sim()
	put(s, 2, 4, 1, 1, 99)
	put(s, 3, 4, 1, 1, 99)
	var seam_x := Sim.FIELD_X0 + 3 * Sim.CELL
	launch(s, seam_x, Sim.DANGER_Y + 4 * Sim.CELL - 60.0, 0.0001, 1.0)
	b = s.v_balls[0]
	for i in 6:
		s.step()
	ok(b.vy < 0.0 and absf(b.vx) < 0.01 * Sim.SPEED, "seam between touching stones acts as a flat face", "v=(%.1f, %.1f)" % [b.vx, b.vy])
	# a stone against the wall: a ball sliding down the wall bounces straight up
	s = empty_sim()
	put(s, 0, 4, 1, 1, 99)
	launch(s, Sim.FIELD_X0 + Sim.BALL_R, Sim.DANGER_Y + 4 * Sim.CELL - 60.0, 0.0, 1.0)
	b = s.v_balls[0]
	for i in 6:
		s.step()
	ok(b.vy < 0.0 and absf(b.vx) < 0.01 * Sim.SPEED, "stone corner touching the wall acts as a flat face", "v=(%.1f, %.1f)" % [b.vx, b.vy])
	# fast diagonal into a thin gap: never inside a stone
	s = empty_sim()
	for col in 7:
		if col != 3:
			put(s, col, 5, 1, 1, 999)
	var inside := 0
	for i in 40:
		launch(s, 100.0 + i * 12.0, 300.0, 0.3 + 0.02 * i, 1.0)
	for t in 600:
		s.step()
		for bb in s.v_balls:
			if bb.st != 1:
				continue
			for blk in s.blocks.values():
				var r := s.block_rect(blk)
				var q := Vector2(clampf(bb.x, r.position.x, r.end.x), clampf(bb.y, r.position.y, r.end.y))
				if q.distance_to(Vector2(bb.x, bb.y)) < Sim.BALL_R - 0.5:
					inside += 1
		if s.phase != Sim.PH_VOLLEY:
			break
	ok(inside == 0, "no tunnelling: 40 balls over a row with one gap never overlap stone", "%d overlaps" % inside)

func test_simultaneous_break() -> void:
	var s := empty_sim()
	var id := put(s, 3, 4, 1, 1, 1)
	var rc := s.block_rect(s.blocks[id])
	# two balls reach the same stone in the same tick from both sides
	launch(s, rc.position.x - Sim.BALL_R - 5.0, rc.get_center().y, 1.0, 0.0001)
	launch(s, rc.end.x + Sim.BALL_R + 5.0, rc.get_center().y, -1.0, 0.0001)
	var gems0 := s.run_gems
	for i in 4:
		s.step()
	ok(count_ev(s, "break") == 1 and s.run_gems - gems0 == 1 and not s.blocks.has(id),
		"two balls breaking one stone in the same tick pay its crystals once", "breaks=%d gems=%d" % [count_ev(s, "break"), s.run_gems - gems0])
	# the second ball flies on through the space the stone left
	var b2: Sim.Ball = s.v_balls[1]
	ok(b2.vx < 0.0, "the later ball in that tick passes through the broken stone's place")

func test_heavy_levels() -> void:
	var good := true
	var info := ""
	for lvl in [1, 2, 3]:
		var s := empty_sim()
		s.heavy = lvl
		var kinds := []
		for i in 12:
			kinds.append(s.ball_kind(i))
		# positions 4, 8, 12 are heavy
		good = good and kinds[3] == Sim.K_HEAVY and kinds[7] == Sim.K_HEAVY and kinds[11] == Sim.K_HEAVY and kinds[0] == Sim.K_NORMAL and kinds[2] == Sim.K_NORMAL
		var id := put(s, 3, 4, 1, 1, 50)
		var rc := s.block_rect(s.blocks[id])
		launch(s, rc.get_center().x, rc.position.y - 40.0, 0.0001, 1.0, Sim.K_HEAVY)
		for i in 5:
			s.step()
		var hp: int = s.blocks[id].hp
		if hp != 50 - Sim.HEAVY_DMG[lvl]:
			good = false
		info += "L%d dmg %d; " % [lvl, 50 - hp]
	var s0 := empty_sim()
	ok(good and s0.ball_kind(3) == Sim.K_NORMAL, "heavy balls: positions 4/8/12, direct damage 2/3/4 by level, normal before the upgrade", info)

func test_electric_levels() -> void:
	var good := true
	var info := ""
	for lvl in [1, 2, 3]:
		var s := empty_sim()
		s.electric = lvl
		good = good and s.ball_kind(1) == Sim.K_ELECTRIC and s.ball_kind(5) == Sim.K_ELECTRIC and s.ball_kind(9) == Sim.K_ELECTRIC and s.ball_kind(0) == Sim.K_NORMAL
		# a ball trapped between a stone above and the floor: many direct hits
		var top_id := put(s, 3, 8, 1, 1, 100)
		var side_id := put(s, 4, 8, 1, 1, 100)
		var far_id := put(s, 0, 2, 1, 1, 100)
		var rc := s.block_rect(s.blocks[top_id])
		var b := launch(s, rc.get_center().x, rc.end.y + 30.0, 0.0001, 1.0, Sim.K_ELECTRIC)
		var zaps := 0
		var direct := 0
		for i in 400:
			s.step()
			for e in s.events:
				if e.t == "zap":
					zaps += 1
					if e.id != side_id:
						good = false
				if e.t == "hit" and e.k == Sim.K_ELECTRIC:
					direct += 1
			s.events.clear()
			if direct >= 8 or b.st != 1:
				break
		var side_hp: int = s.blocks[side_id].hp
		var far_hp: int = s.blocks[far_id].hp
		if zaps != direct / 4 or side_hp != 100 - Sim.ZAP_DMG[lvl] * zaps or far_hp != 100:
			good = false
		info += "L%d hits %d zaps %d side -%d; " % [lvl, direct, zaps, 100 - side_hp]
	ok(good, "electric: positions 2/6/10, every 4th direct hit zaps the nearest neighbour for 1/2/3, no chain", info)
	# nothing in range: no damage anywhere
	var s2 := empty_sim()
	s2.electric = 1
	var lone := put(s2, 3, 8, 1, 1, 100)
	var far := put(s2, 0, 1, 1, 1, 100)
	var rc2 := s2.block_rect(s2.blocks[lone])
	launch(s2, rc2.get_center().x, rc2.end.y + 30.0, 0.0001, 1.0, Sim.K_ELECTRIC)
	for i in 200:
		s2.step()
	ok(s2.blocks[far].hp == 100 and count_ev(s2, "fizzle") >= 1, "electric: a stone out of range is never touched")

func test_upgrade_limits() -> void:
	var s := Sim.new(); s.new_run(3)
	var seen_balls := 0
	var good := true
	for i in 30:
		s.phase = Sim.PH_AIM
		s.volleys = 3
		s.blocks = {}; s.grid = {}
		s._end_volley()  # volley 4: offer
		if s.phase == Sim.PH_UPGRADE:
			for o in s.upgrade_opts:
				if (o == "balls" and s.balls >= Sim.MAX_BALLS) or (o == "heavy" and s.heavy >= 3) or (o == "electric" and s.electric >= 3):
					good = false
			var pick: String = s.upgrade_opts[i % s.upgrade_opts.size()]
			good = good and s.choose_upgrade(pick)
			good = good and not s.choose_upgrade(pick)  # a second pick of the same offer is refused
		s.top = 0
	good = good and s.balls == Sim.MAX_BALLS and s.heavy == 3 and s.electric == 3
	ok(good, "upgrades: only available options are offered, limits 32 balls / level 3, one pick per offer", "balls %d heavy %d electric %d" % [s.balls, s.heavy, s.electric])
	var g0 := s.run_gems
	s.phase = Sim.PH_AIM; s.volleys = 3; s.blocks = {}; s.grid = {}
	s._end_volley()
	ok(s.phase == Sim.PH_AIM and s.run_gems - g0 == Sim.MAXED_BONUS and not s.choose_upgrade("balls"), "all upgrades maxed: the stage pays bonus crystals once")

func test_volleys_always_end() -> void:
	var worst := 0
	var good := true
	for sd in 25:
		var s := Sim.new(); s.new_run(77 + sd)
		s.balls = 32; s.heavy = 3; s.electric = 3
		for v in 6:
			if s.phase == Sim.PH_UPGRADE:
				s.choose_upgrade(s.upgrade_opts[0])
			if s.phase != Sim.PH_AIM:
				break
			var n := run_volley(s, 0.15 + fmod(sd * 0.61 + v * 1.17, 2.8))
			worst = maxi(worst, n)
			if n > Sim.VOLLEY_MAX_TICKS + 1:
				good = false
	ok(good, "every volley ends (25 seeds x 6 volleys, 32 balls)", "longest %d ticks = %.1f s" % [worst, worst / 60.0])

func test_longest_volley() -> void:
	var s := Sim.new(); s.new_run(4242)
	s.balls = 32; s.heavy = 3; s.electric = 3
	# dense field: every visible row below the opening filled with tough single stones and a few gaps
	s.blocks = {}; s.grid = {}
	for vr in range(3, 10):
		for c in 7:
			if (c + vr) % 4 != 0:
				put(s, c, vr, 1, 1, 400)
	var t0 := Time.get_ticks_usec()
	var n := run_volley(s, 1.2)
	var us := Time.get_ticks_usec() - t0
	ok(n <= Sim.VOLLEY_MAX_TICKS + 1, "longest volley: 32 balls, all upgrades, dense field ends", "%d ticks, %.2f ms sim per tick on this machine" % [n, us / 1000.0 / maxf(1.0, n)])

func test_save_roundtrip() -> void:
	var s := Sim.new(); s.new_run(99)
	run_volley(s, 1.0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict(), "", true, true))
	var s2 := Sim.new(); s2.from_dict(d)
	ok(s.state_hash() == s2.state_hash(), "run state survives a JSON save/load unchanged")
