extends Node
## The 50 levels as shipped: data checks and every stored 3-star route replayed through the game's own
## physics from the level's fixed start (the same code the game runs, frame for frame).
##   godot --headless --path . res://tests/levels_test.tscn
## Writes user://levels_test.log and tests/level_report.json-like lines to stdout.

var fails := 0
var lines: PackedStringArray = []

func ok(cond: bool, name: String, info := "") -> void:
	var s := ("PASS  " if cond else "FAIL  ") + name + ("" if info == "" else "  (" + info + ")")
	print(s)
	lines.append(s)
	if not cond:
		fails += 1

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/level_routes.json"))
	var levels: Array = data.levels
	ok(levels.size() == 50, "50 levels", str(levels.size()))
	var ids := {}
	var by_id := {}
	for l in routes.levels:
		by_id[l.id] = l
	var total_min := 0.0
	for lv in levels:
		var n := int(lv.n)
		var id := String(lv.id)
		ids[id] = true
		var stones := 0
		for row in lv.rows:
			stones += row.size()
		var ch := (n - 1) / 10
		var good_data: bool = id == "L%02d" % n and int(lv.ver) >= 1 and int(lv.t3) <= int(lv.t2) and int(lv.t3) >= 1 and stones > 0 \
			and int(lv.chapter) == ch and int(lv.balls) > 0
		# same start on every retry
		var a := Sim.new()
		a.record_events = false
		a.new_level(lv)
		var b := Sim.new()
		b.record_events = false
		b.new_level(lv)
		var same := a.state_hash() == b.state_hash()
		# the stored route, fired exactly as a player would
		var r: Dictionary = by_id.get(id, {})
		var s := Sim.new()
		s.record_events = false
		s.new_level(lv)
		var start_hash := s.state_hash()
		var ticks := 0
		var why := ""
		for step in r.get("route", []):
			if s.phase != Sim.PH_AIM:
				why = "phase %d before a shot" % s.phase
				break
			s.fire(float(step.a))
			var g := 0
			while s.phase == Sim.PH_VOLLEY and g < 30000:
				s.step()
				g += 1
			ticks += g
			if s.phase == Sim.PH_UPGRADE:
				if not step.has("up") or not s.choose_upgrade(String(step.up)):
					why = "upgrade"
					break
		var won := s.phase == Sim.PH_WON
		var mins := (s.volleys * 5.0 + ticks / 60.0 * 0.8) / 60.0
		total_min += mins
		ok(good_data and same and won and s.volleys == int(lv.t3),
			"%s (%s, %d stones, %d balls): start state %s, route %d volleys -> %s, T3=%d T2=%d, ~%.1f min" % [id, ["Copper Mine", "Crystal Vein", "Flooded Tunnels", "Obsidian Depths", "Heart of the Mine"][ch],
			stones, int(lv.balls), "%x" % start_hash, s.volleys, "WON" if won else "NOT WON " + why, int(lv.t3), int(lv.t2), mins])
	ok(ids.size() == 50, "level ids are unique")
	print("LEVELS %s, 3-star routes take %.0f min in total" % ["PASS" if fails == 0 else "FAIL (%d)" % fails, total_min])
	var f := FileAccess.open("user://levels_test.log", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
	get_tree().quit(1 if fails > 0 else 0)
