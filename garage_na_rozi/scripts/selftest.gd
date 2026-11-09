extends Node
## Automated play: drives the real game with touch events.
##   --shots=<dir>   screenshot tour (needs a renderer, e.g. xvfb-run)
##   --selftest      full checks: career, no-tips career, interruptions, restore
## Run headless with --fixed-fps 60 so timing is deterministic and fast.

var main: Node
var out_dir := ""
var do_tests := false
var fails: Array = []
var passes := 0
var log_lines: Array = []
var slow := false             # no-tips mode: wait past double target time
var shot_n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.substr(8)
		if a == "--selftest":
			do_tests = true
	await get_tree().process_frame
	await get_tree().process_frame
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		await run_shots()
	if do_tests:
		await run_tests()
	_finish()


func _finish() -> void:
	var report := "\n".join(log_lines)
	print(report)
	print("RESULT: %d passed, %d failed" % [passes, fails.size()])
	for f in fails:
		print("FAIL: ", f)
	get_tree().quit(1 if fails.size() > 0 else 0)


func say(s: String) -> void:
	log_lines.append(s)
	print(s)


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		fails.append(what)
		say("  ✗ " + what)


# ------------------------------------------------------------------ input helpers

func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func secs(s: float) -> void:
	if s <= 0.0:
		return
	if s > 2.0:
		# one timer instead of thousands of frame awaits (deep resume chains)
		await get_tree().create_timer(s).timeout
		return
	await frames(int(s * 60.0))


func until(cond: Callable, max_frames := 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## Events go in as window pixels; the stretch transform maps them back.
func to_win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func touch(pos: Vector2, pressed: bool, idx := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = to_win(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func tap(pos: Vector2) -> void:
	touch(pos, true)
	await frames(3)
	touch(pos, false)
	await frames(3)


func drag(path: PackedVector2Array, per := 1) -> void:
	if path.is_empty():
		return
	touch(path[0], true)
	await frames(2)
	var prev := path[0]
	for i in range(1, path.size()):
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = to_win(path[i])
		ev.relative = to_win(path[i]) - to_win(prev)
		prev = path[i]
		Input.parse_input_event(ev)
		await frames(per)
	await frames(2)
	touch(path[path.size() - 1], false)
	await frames(3)


func hold(pos: Vector2, frames_n: int) -> void:
	touch(pos, true)
	await frames(frames_n)
	touch(pos, false)
	await frames(3)


func find_button(act: String, arg: Variant = null) -> Button:
	var found: Button = null
	for b in _all_buttons(main.hud):
		if b.name.begins_with("btn_" + act) and b.is_visible_in_tree() and not b.disabled:
			found = b
			break
	return found


func _all_buttons(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_all_buttons(c))
	return out


## Press a visible interface button by a real tap at its centre.
func press(act: String) -> bool:
	var ok := await until(func(): return find_button(act) != null, 600)
	if not ok:
		say("  (no button %s)" % act)
		return false
	var b := find_button(act)
	await tap(b.get_global_rect().get_center())
	return true


func shot(name: String) -> void:
	if out_dir == "":
		return
	await frames(2)
	var img := get_viewport().get_texture().get_image()
	shot_n += 1
	img.save_png("%s/%02d_%s.png" % [out_dir, shot_n, name])


func repair_to_screen(p: Vector2) -> Vector2:
	return main.repair.get_global_transform() * p


func garage_to_screen(p: Vector2) -> Vector2:
	return main.garage.get_global_transform() * p


## Solve the open repair with real gestures from the repair's own solution.
func solve_repair(snap_name := "") -> bool:
	var r: RepairBase = main.repair
	if r == null:
		return false
	var guard := 0
	var shots_taken := {}
	while is_instance_valid(r) and main.repair == r and r.step != "done" and guard < 40:
		guard += 1
		await until(func(): return r.pauses.is_empty() or (r.pauses.size() == 1 and r.pauses.has("tutorial")), 400)
		if snap_name != "" and not shots_taken.has(r.step):
			shots_taken[r.step] = true
			await shot("%s_%s" % [snap_name, r.step])
		if slow:
			var tgt := float(r.order["target"])
			if r.started and r.step == "verify" and r.elapsed < tgt * 2.0 + 1.0:
				await secs(tgt * 2.0 + 1.5 - r.elapsed)
			if not is_instance_valid(r) or main.repair != r:
				say("  (repair closed by itself while waiting)")
				return false
		var acts := r.bot_actions()
		if OS.get_cmdline_user_args().has("--verbose"):
			say("    step=%s el=%.1f acts=%s found=%s" % [r.step, r.elapsed, acts.map(func(x): return x["type"]), r.found])
		if acts.is_empty():
			await frames(10)
			continue
		for a in acts:
			if main.repair != r or r.step == "done":
				break
			match a["type"]:
				"tap":
					await tap(repair_to_screen(a["at"]))
				"drag":
					var pts := PackedVector2Array()
					var src: PackedVector2Array = a["path"]
					var sparse := OS.get_cmdline_user_args().has("--sparse")
					for k in src.size():
						# --sparse: a slow phone delivers only every third touch sample
						if sparse and k % 3 != 0 and k != src.size() - 1:
							continue
						pts.append(repair_to_screen(src[k]))
					await drag(pts, int(a.get("per", 1)))
				"hold":
					await hold(repair_to_screen(a["at"]), int(a.get("frames", 60)))
				"wait":
					await frames(int(a.get("frames", 30)))
		await frames(4)
	if snap_name != "":
		await shot("%s_done" % snap_name)
	return not is_instance_valid(r) or r.step == "done"


# ------------------------------------------------------------------ flows

func wait_idle() -> void:
	await until(func(): return not main.busy, 1800)
	await frames(3)


## From the garage with a client waiting: open, repair, collect payment.
func do_order(snap := "") -> Dictionary:
	await wait_idle()
	var job = Game.current()
	if job == null:
		return {}
	var o: Dictionary = Game.order(job["order"])
	# tap the vehicle zone like a player
	var zp: Vector2 = garage_to_screen(main.garage.zone_pos(o["zone"]))
	await tap(zp)
	await until(func(): return main.repair != null and not main.busy, 600)
	if main.repair == null:
		await press("inspect")
		await until(func(): return main.repair != null and not main.busy, 600)
	var ok := await solve_repair(snap)
	check(ok, "repair solved: " + o["id"])
	await until(func(): return Game.pending_result() != null and not main.busy, 1200)
	var res = Game.pending_result()
	if snap != "":
		await shot(snap + "_paid")
	await press("next")
	await wait_idle()
	return res if res != null else {}


func run_shots() -> void:
	var what := "all"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--what="):
			what = a.substr(7)
	if what == "all" or what == "start":
		await fresh_profile()
		await shot("title")
		await press("start")
		await until(func(): return Game.current() != null and not main.busy, 1200)
		await shot("arrival")
		await do_order("headlight")
		await shot("garage_after_first")
	if what == "all" or what == "garage":
		await garage_states()
	if what == "all" or what == "repairs":
		await fresh_profile()
		main.hud.close_overlay()
		Game.state["tutorial"] = {"first_repair": true, "tap_zone": true}
		var ids: Array = Game.order_ids + Game.FINAL
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--ids="):
				ids = a.substr(6).split(",")
		for id in ids:
			await repair_once(id, id)


func set_stage(done_ids: Array, owned: Array, extra := {}) -> void:
	Game.reset_progress()
	Game.state["started"] = true
	Game.state["tutorial"] = {"first_repair": true, "tap_zone": true}
	for id in done_ids:
		Game.state["done"][id] = 1
		Game.state["records"][id] = 30.0 + randf() * 20.0
	for it in owned:
		Game.state["owned"][it] = true
	for k in extra.keys():
		Game.state[k] = extra[k]
	Game.save()
	await restart_game()
	main.hud.close_overlay()
	main.garage_idle()
	await frames(10)


func garage_states() -> void:
	var moped := ["m_headlight", "m_mirror"]
	await set_stage(moped, [], {"balance": 200})
	await shot("g1_buy_stand")
	await set_stage(moped, ["stand"], {"balance": 0})
	Game.open_job("m_speedo", "career")
	main.restore_scene()
	main.garage_idle()
	await frames(10)
	await shot("g2_moped_on_stand")
	var all_moped := ["m_headlight", "m_mirror", "m_speedo", "m_fender"]
	await set_stage(all_moped + ["b_turn"], ["stand"], {"balance": 300, "photo": true})
	Game.open_job("b_horn", "career")
	main.restore_scene()
	main.garage_idle()
	await frames(10)
	await shot("g3_moto_photo")
	var moto := ["b_turn", "b_horn", "b_kickstand", "b_case"]
	await set_stage(all_moped + moto, ["stand"], {"balance": 400, "photo": true})
	await shot("g4_buy_lift")
	await set_stage(all_moped + moto + ["c_wiper"], ["stand", "lift"], {"balance": 300, "photo": true})
	Game.open_job("c_glovebox", "career")
	main.restore_scene()
	main.garage_idle()
	await frames(10)
	await shot("g5_car_on_lift")
	var car := ["c_wiper", "c_glovebox", "c_dash", "c_window"]
	await set_stage(all_moped + moto + car, ["stand", "lift"], {"balance": 600, "photo": true, "final_arrived": true})
	main.restore_scene()
	main.garage_idle()
	await frames(10)
	await shot("g6_final_wagon")
	check(main.hud.bottom.size.y < 700.0, "final card fits its content (%d px)" % int(main.hud.bottom.size.y))
	await set_stage(all_moped + moto + car + Game.FINAL, ["stand", "lift", "decor_lamp", "decor_cabinet", "decor_gate"], {"balance": 1240, "photo": true, "sign": true, "free_play": true, "gate_new_color": true, "final_done": Game.FINAL.duplicate()})
	await shot("g7_free_play_decor")
	main.hud.open_board(true, true)
	await shot("g8_board")
	main.hud.open_shop()
	await shot("g9_shop")
	main.hud.open_settings("")
	await shot("g10_settings")
	main.hud.open_credits()
	await shot("g11_credits")
	main.hud.close_overlay()


func restart_game() -> void:
	## Simulates closing and reopening the app: a fresh scene reads the save.
	Game.save()
	var old: Node = main
	old.queue_free()
	await frames(3)
	Game.load_game()
	var m: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(m)
	main = m
	await frames(5)


func fresh_profile() -> void:
	Game.reset_progress()
	Game.state["tutorial"] = {}
	Game.save()
	await restart_game()


func place_for(id: String) -> void:
	if main.hud.is_overlay():
		main.hud.close_overlay()
	var o := Game.order(id)
	main._place_vehicle(o)
	main._place_client(o)


## Solve one repair opened directly for an order id (no career rules).
func repair_once(id: String, snap := "") -> Dictionary:
	if Game.current() != null:
		Game.cancel_job()
	Game.state["last_result"] = null
	var kind := "final" if id.begins_with("f_") else "free"
	Game.open_job(id, kind)
	place_for(id)
	main.mode = "garage"
	main.inspect()
	await until(func(): return main.repair != null and not main.busy, 600)
	if main.repair == null:
		say("  (repair %s did not open; busy=%s mode=%s)" % [id, main.busy, main.mode])
	var ok := await solve_repair(snap)
	if not ok and main.repair != null:
		say("  (%s stuck at step %s found %s paused %s)" % [id, main.repair.step, main.repair.found, main.repair.pauses])
	await until(func(): return Game.pending_result() != null and not main.busy, 900)
	var res = Game.pending_result()
	Game.dismiss_result()
	main.garage.vehicle = ""
	main.garage.client_look = {}
	main.hud.clear_bottom()
	return {"ok": ok, "res": res}


func test_each_repair() -> void:
	say("-- every repair, solved by gestures --")
	await fresh_profile()
	Game.state["tutorial"] = {"first_repair": true, "tap_zone": true}
	var ids: Array = Game.order_ids + Game.FINAL
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			ids = a.substr(6).split(",")
		if a == "--slow":
			slow = true
	for id in ids:
		var r := await repair_once(id)
		var res = r["res"]
		check(r["ok"] and res != null, "repair %s solves" % id)
		if res != null:
			check(int(res["base"]) == 100, "%s base pay 100" % id)
			say("  %s ok, %.1fs, tip %d" % [id, float(res["elapsed"]), int(res["tip"])])


## The career from a clean profile using only the interface and real touches.
func play_career(no_tips: bool) -> void:
	slow = no_tips
	await fresh_profile()
	check(Game.balance() == 0, "start balance 0")
	await press("start")
	var guard := 0
	var bought := {}
	var orders_done: Array = []
	while guard < 60:
		guard += 1
		await wait_idle()
		if main.hud.is_overlay("credits"):
			break
		if Game.pending_result() != null:
			await press("next")
			continue
		var job = Game.current()
		if job != null:
			var res := await do_order()
			if not res.is_empty():
				orders_done.append(res["order"])
				if no_tips:
					check(int(res["tip"]) == 0, "no tip for slow %s" % res["order"])
			continue
		if Game.state.get("final_arrived", false) and not Game.final_complete():
			var st := ""
			for s2 in Game.FINAL:
				if not Game.final_done_list().has(s2):
					st = s2
					break
			var zp: Vector2 = garage_to_screen(main.garage.zone_pos(Game.order(st)["zone"]))
			await tap(zp)
			await until(func(): return main.repair != null and not main.busy, 600)
			if main.repair == null:
				await press("final_stage")
				await until(func(): return main.repair != null and not main.busy, 600)
			var ok := await solve_repair()
			check(ok, "final stage %s solved" % st)
			await until(func(): return Game.pending_result() != null and not main.busy, 900)
			var r2 = Game.pending_result()
			if r2 != null:
				orders_done.append(r2["order"])
				if no_tips:
					check(int(r2["tip"]) == 0, "no tip for slow %s" % r2["order"])
			if Game.final_complete():
				await press("next")
				await until(func(): return main.hud.is_overlay("credits"), 3000)
				break
			await press("next")
			continue
		var gl := Game.goal()
		if gl["item"] != "" and Game.can_buy(gl["item"]):
			var item: String = gl["item"]
			var before := Game.balance()
			# tap the floor outline like a player, then confirm
			var spot := "stand_spot" if item == "stand" else "lift_spot"
			await tap(garage_to_screen(main.garage.zone_pos(spot)))
			if not main.hud.is_overlay("buy"):
				await press("buy_ask")
			# a fast double tap on «Купити» must charge once
			var b := find_button("buy_do")
			if b:
				var c := b.get_global_rect().get_center()
				touch(c, true)
				await frames(1)
				touch(c, false)
				await frames(1)
				touch(c, true)
				await frames(1)
				touch(c, false)
				await frames(5)
			check(Game.owns(item), "bought " + item)
			check(Game.balance() == before - Game.price(item), "charged once for " + item)
			bought[item] = true
			continue
		if find_button("call") != null:
			await press("call")
			await until(func(): return Game.current() != null or Game.state.get("final_arrived", false), 900)
			continue
		say("  stuck: goal=%s balance=%d" % [gl["text"], Game.balance()])
		break
	check(bought.has("stand") and bought.has("lift"), "stand and lift bought")
	var distinct := {}
	for id in orders_done:
		distinct[id] = true
	check(distinct.size() == 15, "15 distinct jobs done (12 + 3 final), got %d" % distinct.size())
	check(Game.state["sign"], "sign received")
	check(main.hud.is_overlay("credits"), "credits shown")
	if no_tips:
		check(Game.balance() == 15 * 100 - 600, "no-tips balance %d == 900" % Game.balance())
	await shot("credits")
	await press("credits_done")
	await wait_idle()
	check(Game.state["free_play"], "free play after credits")
	await press("call")
	await until(func(): return Game.current() != null and not main.busy, 900)
	var job2 = Game.current()
	check(job2 != null and job2["kind"] == "free", "free-play client arrives")
	var before2 := Game.balance()
	var rf := await do_order()
	check(not rf.is_empty() and Game.balance() >= before2 + 100, "free-play order paid")
	slow = false


func test_interruptions() -> void:
	say("-- pause, background, restart --")
	await fresh_profile()
	Game.state["tutorial"] = {"first_repair": true, "tap_zone": true}
	# open a repair and start the clock
	Game.open_job("m_mirror", "career")
	place_for("m_mirror")
	main.mode = "garage"
	main.inspect()
	await until(func(): return main.repair != null and not main.busy, 600)
	var r: RepairBase = main.repair
	await tap(repair_to_screen(r.zone_of("clamp")))
	await secs(1.0)
	check(r.started and r.elapsed > 0.5, "clock runs after first touch")
	# pause menu
	await press("pause")
	var e0 := r.elapsed
	await secs(3.0)
	check(absf(r.elapsed - e0) < 0.01, "pause stops the clock")
	await press("resume")
	await secs(1.0)
	check(r.elapsed > e0 + 0.5, "clock resumes after pause")
	# hint card
	r.idle = 13.0
	await frames(3)
	await press("hint")
	var e1 := r.elapsed
	await secs(2.0)
	check(absf(r.elapsed - e1) < 0.01, "hint stops the clock")
	await press("hint_close")
	# background (minimize / lock)
	var saves := Game.save_count
	main.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var e2 := r.elapsed
	await secs(3.0)
	check(absf(r.elapsed - e2) < 0.01, "background stops the clock")
	check(Game.save_count > saves, "saved on minimize")
	var saved = Game._read_json(Game.save_path)
	check(saved != null and saved["current"] != null and absf(float(saved["current"]["elapsed"]) - e2) < 0.05, "active time saved on minimize")
	main.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await frames(3)
	check(main.hud.is_overlay("continue"), "«Продовжити» shown after return")
	await secs(1.0)
	check(absf(r.elapsed - e2) < 0.01, "clock waits for «Продовжити»")
	await press("continue_bg")
	await secs(1.0)
	check(r.elapsed > e2 + 0.5, "clock runs after «Продовжити»")
	# find the cause, then restart the app in the middle of the order
	await tap(repair_to_screen(r.zone_of("ring")))
	await frames(5)
	check(r.step == "fix", "cause found -> fix step")
	var el := r.elapsed
	await restart_game()
	check(Game.current() != null and Game.current()["step"] == "fix", "step survives restart")
	check(Game.current()["found"].has("ring_loose"), "found signs survive restart")
	check(absf(float(Game.current()["elapsed"]) - el) < 0.2, "active time survives restart")
	await press("start")
	await until(func(): return main.repair != null and not main.busy, 600)
	check(main.repair != null and main.repair.step == "fix", "repair reopens at the saved step")
	var bal := Game.balance()
	var ok := await solve_repair()
	check(ok, "repair finishes after restart")
	await until(func(): return Game.pending_result() != null and not main.busy, 900)
	var paid := Game.balance() - bal
	check(paid >= 100, "paid after restart")
	# restart right after payment: no double payment
	await restart_game()
	check(Game.balance() == bal + paid, "balance kept after restart following payment")
	check(Game.pending_result() != null, "payment card returns after restart")
	await press("start")
	await wait_idle()
	await press("next")
	await wait_idle()
	check(Game.balance() == bal + paid, "no double payment")
	# double completion of the same job uid is ignored
	Game.open_job("m_headlight", "career")
	var uid := int(Game.current()["uid"])
	var b0 := Game.balance()
	Game.complete_job(uid, 10.0)
	Game.complete_job(uid, 10.0)
	check(Game.balance() == b0 + 130, "one job uid pays once")
	Game.dismiss_result()
	# long repair still gets base pay
	Game.open_job("m_fender", "career")
	var uid2 := int(Game.current()["uid"])
	var b1 := Game.balance()
	var rl := Game.complete_job(uid2, 600.0)
	check(int(rl["base"]) == 100 and int(rl["tip"]) == 0 and Game.balance() == b1 + 100, "long repair: base 100, tip 0")
	check(Game.tip_for(45, 45) == 30 and Game.tip_for(67.5, 45) == 15 and Game.tip_for(90, 45) == 0, "tips fall linearly to zero at double time")
	Game.dismiss_result()
	# purchase survives restart
	Game.state["balance"] = 500
	Game.save()
	await restart_game()
	var b2 := Game.balance()
	Game.buy("stand")
	Game.buy("stand")
	check(Game.balance() == b2 - 200, "stand charged once")
	await restart_game()
	check(Game.owns("stand") and Game.balance() == b2 - 200, "purchase and balance survive restart")
	# restart in the middle of the final
	for id in Game.order_ids:
		Game.state["done"][id] = 1
	Game.state["owned"]["lift"] = true
	Game.state["final_arrived"] = true
	Game.state["final_done"] = ["f_light"]
	Game.state["current"] = null
	Game.state["last_result"] = null
	Game.save()
	await restart_game()
	await press("start")
	await wait_idle()
	check(find_button("final_stage") != null, "final card after restart")
	await press("final_stage")
	await until(func(): return main.repair != null and not main.busy, 600)
	var fr: RepairBase = main.repair
	var acts := fr.bot_actions()
	if acts.size() > 0 and acts[0]["type"] == "drag":
		var pts := PackedVector2Array()
		for p in acts[0]["path"]:
			pts.append(repair_to_screen(p))
		await drag(pts)
	await secs(0.5)
	var fstep: String = fr.step
	var fid: String = Game.current()["order"]
	await restart_game()
	check(Game.current() != null and Game.current()["order"] == fid and Game.current()["step"] == fstep, "final stage step survives restart")
	await press("start")
	await until(func(): return main.repair != null and not main.busy, 600)
	ok = await solve_repair()
	check(ok, "final stage finishes after restart")
	await until(func(): return Game.pending_result() != null and not main.busy, 900)
	await press("next")
	await wait_idle()
	# finish the last stage and the finale
	await press("final_stage")
	await until(func(): return main.repair != null and not main.busy, 600)
	ok = await solve_repair()
	await until(func(): return Game.pending_result() != null and not main.busy, 900)
	check(Game.state["sign"], "sign after the third stage")
	var best := float(Game.state["records"].get("f_light", 0.0))
	await restart_game()
	check(Game.state["sign"] and Game.state["credits_pending"], "sign kept after restart; finale resumes")
	check(float(Game.state["records"].get("f_light", 0.0)) == best, "records kept after restart")
	await press("start")
	await wait_idle()
	await press("next")
	await until(func(): return main.hud.is_overlay("credits"), 3000)
	check(main.hud.is_overlay("credits"), "credits after restart")
	await press("credits_done")
	await wait_idle()
	var money := Game.balance()
	await restart_game()
	check(Game.state["sign"] and Game.state["free_play"] and Game.balance() == money, "sign, money, free play persist")


func test_free_queue() -> void:
	say("-- free play queue --")
	for id in Game.order_ids:
		Game.state["done"][id] = 1
	Game.state["free_queue"] = []
	Game.state["last_free"] = ""
	var prev := ""
	var prev_v := ""
	var alternations := 0
	var repeats := 0
	for i in 40:
		var id := Game.next_free_order()
		if id == prev:
			repeats += 1
		if prev_v != "" and Game.order(id)["vehicle"] != prev_v:
			alternations += 1
		prev = id
		prev_v = Game.order(id)["vehicle"]
		Game.state["last_free"] = id
	check(repeats == 0, "no breakdown twice in a row")
	check(alternations == 39, "vehicles alternate (%d/39)" % alternations)


func run_tests() -> void:
	say("== selftest ==")
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	if only == "" or only == "repairs":
		await test_each_repair()
	if only == "" or only == "career":
		say("-- full career with tips --")
		await play_career(false)
	if only == "" or only == "slow":
		say("-- full career without tips --")
		await play_career(true)
	if only == "" or only == "interrupt":
		await test_interruptions()
	if only == "" or only == "queue":
		await test_free_queue()
