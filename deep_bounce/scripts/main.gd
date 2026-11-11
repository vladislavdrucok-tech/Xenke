extends Node
## Deep Bounce controller: layout (9:16 world fitted into the safe area), touch aiming, the fixed-step
## volley loop, turning simulation events into effects and sounds, saving, tutorial hints, screens.
## Two modes share one save slot: an endless run or a level attempt ("Continue" restores either).
## Monetization flows live here too: the second chance at the red line, doubled crystals on the results
## screen, interstitials after "Play Again" / "Next Level" / "Retry", Ad-Free and Google Play purchases.

const World := preload("res://scripts/world.gd")
const Hud := preload("res://scripts/hud.gd")
const Screens := preload("res://scripts/screens.gd")
const QA := preload("res://scripts/qa.gd")
const CATALOG := preload("res://scripts/catalog.gd")

enum { M_MENU, M_GAME }

var sim := Sim.new()
var level: Dictionary = {}       # definition of the level being played (level mode)
var levels: Array = []           # the 50 level definitions, res://data/levels.json
var world: Node2D
var ui_root: Control
var hud: Control
var screens: Control
var mode := M_MENU
var paused := false
var acc := 0.0
var volley_time := 0.0
var boost := false
var flying_gems := 0
var over_timer := -1.0
var won_timer := -1.0
var upgrade_timer := -1.0
var layout_scale := 1.0
var layout_origin := Vector2.ZERO
var save_timer := 0.0

# aiming
var touch_id := -1
var touch_start := Vector2.ZERO
var aiming := false
var aim_ok := false

# tutorial: 0 aim, 1 strength, 2 ricochet, 3 danger, 4..5 upgrade hint shown, 6 done
var tut_hint_step := -1
var tut_hit_seen := false

var qa: Node
var speed_override := 0      # QA: force a speed (1, 2, 4) to compare outcomes
var freeze := false          # QA screenshots: the volley stands still, the interface behaves as in flight
var perf_frames := 0
var perf_sum := 0.0
var perf_worst := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("082b30"))
	levels = load_levels()
	world = World.new()
	world.sim = sim
	add_child(world)
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)
	hud = Hud.new()
	hud.main = self
	ui_root.add_child(hud)
	hud.pause_pressed.connect(open_pause)
	hud.speed_pressed.connect(func():
		boost = not boost
		G.sfx("click", -6.0))
	screens = Screens.new()
	screens.main = self
	ui_root.add_child(screens)
	world.fx.crystal_arrived.connect(func(n):
		flying_gems = maxi(0, flying_gems - n)
		G.sfx("gem", -8.0, randf_range(0.95, 1.1), 40))
	get_viewport().size_changed.connect(_layout)
	G.lang_changed.connect(_on_lang)
	G.profile_changed.connect(_on_profile)
	Store.purchase_result.connect(_on_purchase_result)
	Store.restore_result.connect(_on_restore_result)
	Store.changed.connect(func(): screens.refresh_store())
	Ads.changed.connect(func(): screens.refresh_ads())
	Ads.reward_earned.connect(_on_reward_earned)
	Ads.rewarded_closed.connect(_on_rewarded_closed)
	_layout()
	# menu background: the saved run, or a fresh decorative field
	if G.has_run():
		sim.from_dict(G.run)
		level = level_by_id(sim.level_id) if sim.mode == "level" else {}
	else:
		sim.new_run(12345)
	world.set_theme(chapter_of(level))
	world.aim_angle = sim.aim
	world.sync_blocks(true)
	world.scroll = sim.depth * Sim.CELL
	world.scroll_target = world.scroll
	hud.visible = false
	Store.start()
	Ads.start()
	if G.migrated_from > 0:
		print("save migrated from format %d" % G.migrated_from)
	var qa_mode := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa"):
			qa_mode = true
	if not qa_mode and not G.result.is_empty():
		# the app closed on a results screen: it comes back with its buttons (a recorded reward is paid)
		_reopen_result()
	else:
		screens.show_menu()
	if qa_mode:
		qa = QA.new()
		qa.main = self
		add_child(qa)

# ---------------------------------------------------------------- levels data

static func load_levels() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	if typeof(d) != TYPE_DICTIONARY:
		return []
	return d.get("levels", [])

func level_by_id(id: String) -> Dictionary:
	for l in levels:
		if l.id == id:
			return l
	return {}

func level_n(n: int) -> Dictionary:
	if n < 1 or n > levels.size():
		return {}
	return levels[n - 1]

static func chapter_of(lv: Dictionary) -> int:
	if lv.is_empty():
		return 0
	return clampi((int(lv.n) - 1) / 10, 0, 4)

# ---------------------------------------------------------------- layout

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var safe := Rect2(Vector2.ZERO, vp)
	var win := Vector2(DisplayServer.window_get_size())
	if OS.has_feature("mobile") and win.x > 0:
		var sa := DisplayServer.get_display_safe_area()
		var f := vp / win
		safe = Rect2(Vector2(sa.position) * f, Vector2(sa.size) * f).intersection(Rect2(Vector2.ZERO, vp))
		if safe.size.x < 100 or safe.size.y < 100:
			safe = Rect2(Vector2.ZERO, vp)
	var s := minf(safe.size.x / 720.0, safe.size.y / 1280.0)
	layout_scale = s
	layout_origin = Vector2(safe.position.x + (safe.size.x - 720.0 * s) * 0.5, safe.position.y)
	world.scale = Vector2(s, s)
	world.set_meta("base_pos", layout_origin)
	world.position = layout_origin
	ui_root.position = layout_origin
	ui_root.scale = Vector2(s, s)
	ui_root.size = Vector2(720.0, safe.size.y / s)
	_update_gem_target()

func _update_gem_target() -> void:
	await get_tree().process_frame
	var gp: Vector2 = hud.gem_target_global()
	world.fx.gem_target = (gp - layout_origin) / layout_scale

func to_world(p: Vector2) -> Vector2:
	return (p - layout_origin) / layout_scale

# ---------------------------------------------------------------- starting and continuing

func saved_kind() -> String:
	## "endless", "level" or "" (nothing to continue)
	if not G.has_run():
		return ""
	return String(G.run.get("mode", "endless"))

func menu_endless() -> void:
	if G.has_run():
		var q := "new_run_q" if saved_kind() == "endless" else "new_run_level_q"
		screens.confirm(G.t(q), func(): start_new_run())
	else:
		start_new_run()

func menu_level(n: int) -> void:
	## From the level list: the intro card first; a saved attempt of another level or a run is replaced.
	var lv := level_n(n)
	if lv.is_empty() or n > int(G.levels.unlocked):
		return
	if G.has_run() and not (saved_kind() == "level" and String(G.run.get("level", {}).get("id", "")) == lv.id):
		var q := "replace_run_q" if saved_kind() == "endless" else "replace_level_q"
		screens.confirm(G.t(q), func(): screens.show_level_intro(n))
	else:
		screens.show_level_intro(n)

func menu_continue() -> void:
	if not G.has_run():
		return
	sim.from_dict(G.run)
	level = level_by_id(sim.level_id) if sim.mode == "level" else {}
	if sim.mode == "level" and level.is_empty():
		# the level no longer exists in this version: nothing sensible to continue
		G.run = {}
		G.save_game()
		screens.show_menu()
		return
	_enter_game()
	if sim.phase == Sim.PH_VOLLEY:
		open_pause()
	elif sim.phase == Sim.PH_UPGRADE:
		screens.show_upgrade(sim.upgrade_opts)
	elif sim.phase == Sim.PH_OVER:
		_at_line()
	elif sim.phase == Sim.PH_WON:
		_finish()

func start_new_run(seed := -1) -> void:
	if seed < 0:
		seed = int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	sim.new_run(seed)
	sim.run_id = G.new_attempt_id()
	level = {}
	G.store_run(sim)
	_enter_game()

func start_level(n: int) -> void:
	var lv := level_n(n)
	if lv.is_empty():
		return
	level = lv
	sim.new_level(lv)
	sim.run_id = G.new_attempt_id()
	G.store_run(sim)
	_enter_game()

func _enter_game() -> void:
	mode = M_GAME
	paused = false
	boost = false
	acc = 0.0
	volley_time = 0.0
	flying_gems = 0
	over_timer = -1.0
	won_timer = -1.0
	upgrade_timer = -1.0
	world.fx.clear()
	world.clear_blocks()
	world.set_theme(chapter_of(level))
	world.sync_blocks(true)
	world.aim_angle = sim.aim
	world.scroll = sim.depth * Sim.CELL
	world.scroll_target = world.scroll
	world.prev_pos.clear()
	world.trails.clear()
	world.set_skin(G.selected("cannon"))
	world.set_ball_skin(G.selected("ball"), true)
	world.danger = sim.danger_level()
	hud.visible = true
	hud.hide_hint()
	screens.close()
	tut_hint_step = -1
	_update_gem_target()
	G.sfx("start", -4.0)
	if sim.danger_level() >= 1:
		Ads.load_ad("revive")

func to_menu() -> void:
	if mode == M_GAME and sim.phase != Sim.PH_OVER and sim.phase != Sim.PH_WON:
		G.store_run(sim)
	mode = M_MENU
	paused = false
	hud.visible = false
	hud.hide_hint()
	world.aim_visible = false
	screens.show_menu()

func open_pause() -> void:
	if mode != M_GAME or sim.phase == Sim.PH_OVER or sim.phase == Sim.PH_WON or over_timer >= 0.0 or won_timer >= 0.0:
		return
	if Ads.showing != "":
		return
	paused = true
	_cancel_aim()
	hud.hide_info()
	G.store_run(sim)
	screens.show_pause()

func resume_from_pause() -> void:
	screens.close()
	paused = false
	world.set_skin(G.selected("cannon"))
	world.set_ball_skin(G.selected("ball"))
	if sim.phase == Sim.PH_UPGRADE:
		paused = true
		screens.show_upgrade(sim.upgrade_opts)

func end_run_now() -> void:
	## "End run" from the pause screen: the depth reached counts, no second chance.
	screens.close()
	if sim.phase == Sim.PH_VOLLEY:
		sim.recall_all()
		_consume_events()
	sim.phase = Sim.PH_OVER
	_finish()

func retry_level_now() -> void:
	## "Restart level" from the pause screen: the attempt ends without a result, the level starts again.
	screens.close()
	start_level(int(level.get("n", 1)))

func pick_upgrade(id: String) -> void:
	if sim.choose_upgrade(id):
		if int(G.meta.tutorial) >= 4:
			G.meta.tutorial = 6
		_consume_events()
		G.store_run(sim)
		screens.close()
		paused = false
		world.fx.float_text(Vector2(360, 700), G.t("up_" + id), Color("7fe3d6"), 40)

func apply_skins() -> void:
	## A finish chosen in the shop: at once in the menu, from the next volley in a run.
	world.set_skin(G.selected("cannon"))
	world.set_ball_skin(G.selected("ball"), mode == M_MENU)

func preview_shake() -> void:
	world.add_shake(0.8)

func tutorial_reset() -> void:
	tut_hint_step = -1
	tut_hit_seen = false

# ---------------------------------------------------------------- the red line: second chance

func _at_line() -> void:
	## A stone crossed the red line. The game stands still with everything saved; the player may continue
	## once (a rewarded video, or free with Ad-Free) or end the run.
	paused = true
	hud.hide_hint()
	world.aim_visible = false
	G.store_run(sim)
	var id := sim.run_id
	if G.reward_state("revive", id) == "earned":
		# the reward was confirmed before the app closed: it is applied now
		_apply_revive()
		return
	if sim.revive_used or not can_offer_revive():
		_finish()
		return
	Ads.load_ad("revive")
	screens.show_revive()

func can_offer_revive() -> bool:
	return not sim.revive_used and (G.is_ad_free() or Ads.status("revive") != "off")

func revive_with_ad() -> void:
	if G.is_ad_free():
		if G.mark_reward_earned("revive", sim.run_id):
			_apply_revive()
		return
	if not Ads.show_rewarded("revive", sim.run_id):
		Ads.load_ad("revive")
		screens.toast(G.t("ad_not_ready"))
		screens.refresh_ads()

func decline_revive() -> void:
	_finish()

func _apply_revive() -> void:
	if sim.phase != Sim.PH_OVER or sim.revive_used:
		G.apply_reward_mark("revive", sim.run_id)
		G.save_game()
		return
	if not G.is_ad_free():
		sim.rewarded_seen = true
	sim.revive()
	_consume_events()
	G.apply_reward_mark("revive", sim.run_id)
	G.store_run(sim)          # revive used, stones removed, reward applied: one save
	world.sync_blocks()
	world.danger = sim.danger_level()
	screens.close()
	paused = false
	world.fx.float_text(Vector2(360, 520), G.t("revived"), Color("7fe3d6"), 40)
	G.sfx("upgrade", -3.0)
	if sim.phase == Sim.PH_UPGRADE:
		paused = true
		screens.show_upgrade(sim.upgrade_opts)

# ---------------------------------------------------------------- results

func _finish() -> void:
	## Ends the run / attempt once and shows its results.
	paused = true
	hud.hide_hint()
	world.aim_visible = false
	G.finish_run(sim, level)
	_show_result()

func _show_result() -> void:
	var r := G.result
	if r.is_empty():
		screens.show_menu()
		return
	Ads.preload_interstitial(bool(r.get("rewarded_seen", false)))
	if int(r.gems) > 0 and not bool(r.doubled):
		Ads.load_ad("double")
	if r.mode == "endless":
		screens.show_gameover()
	elif r.won:
		screens.show_level_won()
	else:
		screens.show_level_lost()

func _reopen_result() -> void:
	var r := G.result
	if G.reward_state("double", String(r.id)) == "earned":
		G.apply_double(String(r.id))
	if r.mode == "level":
		level = level_by_id(String(r.level_id))
	mode = M_GAME
	paused = true
	hud.visible = false
	_show_result()

func double_with_ad() -> void:
	var r := G.result
	if r.is_empty() or bool(r.doubled) or int(r.gems) <= 0:
		return
	if G.is_ad_free():
		if G.mark_reward_earned("double", String(r.id), int(r.gems)):
			_apply_double()
		return
	if not Ads.show_rewarded("double", String(r.id)):
		Ads.load_ad("double")
		screens.toast(G.t("ad_not_ready"))
		screens.refresh_ads()

func _apply_double() -> void:
	var r := G.result
	if not G.is_ad_free():
		r["rewarded_seen"] = true
	var paid := G.apply_double(String(r.id))
	if paid > 0:
		G.sfx("upgrade", -3.0)
		screens.toast(G.t("doubled_toast", {"n": paid}))
	screens.rebuild()

func _on_reward_earned(placement: String, attempt: String) -> void:
	## The SDK confirmed the reward (already recorded by Ads): applied once.
	if placement == "revive" and attempt == sim.run_id:
		_apply_revive()
	elif placement == "double" and attempt == String(G.result.get("id", "")):
		_apply_double()

func _on_rewarded_closed(placement: String, attempt: String, earned: bool, error: String) -> void:
	if earned:
		return
	# closed early or could not be shown: back to the same choice
	screens.toast(G.t("ad_no_reward") if error == "no_reward" else G.t("ad_failed"))
	Ads.load_ad(placement)
	screens.rebuild()

func play_again() -> void:
	var seen := bool(G.result.get("rewarded_seen", false))
	screens.close()
	G.close_result()
	Ads.show_interstitial_then(seen, func(): start_new_run())

func next_level() -> void:
	var n := int(G.result.get("level_n", level.get("n", 1)))
	var seen := bool(G.result.get("rewarded_seen", false))
	screens.close()
	G.close_result()
	Ads.show_interstitial_then(seen, func(): screens.show_level_intro(mini(levels.size(), n + 1)))

func retry_level() -> void:
	var n := int(G.result.get("level_n", level.get("n", 1)))
	var seen := bool(G.result.get("rewarded_seen", false))
	screens.close()
	G.close_result()
	Ads.show_interstitial_then(seen, func(): start_level(n))

func result_to_levels() -> void:
	G.close_result()
	mode = M_MENU
	hud.visible = false
	screens.show_levels()

func result_to_menu() -> void:
	G.close_result()
	mode = M_MENU
	hud.visible = false
	screens.show_menu()

# ---------------------------------------------------------------- purchases

func _on_purchase_result(pid: String, status: String) -> void:
	var p: Dictionary = CATALOG.product(pid)
	match status:
		"granted":
			G.sfx("buy")
			if p.get("grants", "") == "no_ads":
				Ads.disable()
				screens.toast(G.t("noads_active"))
			elif p.get("type", "") == "consumable":
				screens.show_thanks()
				return
			else:
				var sk: Array = CATALOG.skin_for_product(pid)
				if not sk.is_empty():
					G.select_skin(sk[0], sk[1])
					apply_skins()
				screens.toast(G.t("bought"))
		"pending":
			screens.toast(G.t("purchase_pending"), 4.0)
		"cancelled":
			pass
		"already_owned":
			screens.toast(G.t("already_owned"))
		"unavailable":
			screens.toast(G.t("store_unavailable"))
		_:
			screens.toast(G.t("purchase_error"))
	screens.rebuild()

func _on_restore_result(status: String, count: int) -> void:
	match status:
		"ok":
			screens.toast(G.tn("restored_n", count))
		"none":
			screens.toast(G.t("restored_none"))
		_:
			screens.toast(G.t("restore_error"))
	screens.rebuild()

func _on_profile() -> void:
	if G.is_ad_free():
		Ads.disable()
	apply_skins()

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if mode != M_GAME or paused or screens.is_open() or Ads.showing != "":
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id < 0:
			touch_id = event.index
			touch_start = to_world(event.position)
			aiming = sim.phase == Sim.PH_AIM
			aim_ok = false
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			if aiming and aim_ok and sim.phase == Sim.PH_AIM:
				_fire(world.aim_angle)
			_cancel_aim()
	elif event is InputEventScreenDrag and event.index == touch_id and aiming:
		_update_aim(to_world(event.position))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		open_pause()

func _update_aim(p: Vector2) -> void:
	var d := p - touch_start
	if d.length() < 22.0 or d.y < -0.18 * d.length():
		aim_ok = false
		world.aim_visible = false
		return
	var ang := atan2(d.y, d.x)
	if d.y < 0.0:
		ang = 0.0 if d.x > 0.0 else PI
	ang = Sim.clamp_aim(ang)
	aim_ok = true
	world.aim_angle = ang
	world.aim_pts = sim.preview(ang)
	world.aim_visible = true

func _cancel_aim() -> void:
	aiming = false
	aim_ok = false
	touch_id = -1
	world.aim_visible = false

func _fire(angle: float) -> void:
	world.apply_pending()
	if not sim.fire(angle):
		return
	hud.hide_info()
	volley_time = 0.0
	boost = false
	G.store_run(sim)      # checkpoint: the volley can be replayed exactly from here
	hud.hide_hint()
	if int(G.meta.tutorial) in [0, 2, 3]:
		G.meta.tutorial = int(G.meta.tutorial) + 1
	tut_hint_step = -1

# ---------------------------------------------------------------- loop

func _process(dt: float) -> void:
	if mode != M_GAME:
		return
	if Ads.showing != "":
		return       # a full-screen ad is up: the game stands still
	if not paused and not screens.is_open() and (sim.phase == Sim.PH_AIM or sim.phase == Sim.PH_VOLLEY):
		G.add_active_time(dt)
		save_timer += dt
		if save_timer > 20.0 and sim.phase == Sim.PH_AIM:
			save_timer = 0.0
			G.save_game()
	if over_timer >= 0.0:
		over_timer -= dt
		if over_timer < 0.0:
			_at_line()
	if won_timer >= 0.0:
		won_timer -= dt
		if won_timer < 0.0:
			_finish()
	if upgrade_timer >= 0.0:
		upgrade_timer -= dt
		if upgrade_timer < 0.0 and sim.phase == Sim.PH_UPGRADE:
			paused = true
			screens.show_upgrade(sim.upgrade_opts)
	var speed := 1
	if freeze and sim.phase == Sim.PH_VOLLEY:
		hud.update_state(sim, flying_gems, 2, true)
		return
	if sim.phase == Sim.PH_VOLLEY and not paused:
		perf_frames += 1
		perf_sum += dt
		perf_worst = maxf(perf_worst, dt)
		volley_time += dt
		speed = 1
		if volley_time > 3.5:
			speed = 2
		if volley_time > 8.0:
			speed = 3
		if boost:
			speed = 4
		if speed_override > 0:
			speed = speed_override
		acc += dt * speed
		var steps := 0
		while acc >= Sim.DT and steps < 16 and sim.phase == Sim.PH_VOLLEY:
			world.remember_positions()
			sim.step()
			_consume_events()
			acc -= Sim.DT
			steps += 1
		if steps >= 16:
			acc = 0.0
		world.interp = clampf(acc / Sim.DT, 0.0, 1.0)
		world.set_count(sim.v_total - sim.v_launched)
	else:
		acc = 0.0
		world.set_count(0)
	hud.update_state(sim, flying_gems, speed, sim.phase == Sim.PH_VOLLEY and not paused)
	_tutorial()

func _consume_events() -> void:
	if sim.events.is_empty():
		return
	var evs := sim.events
	sim.events = []
	var muzzle := Sim.muzzle(world.aim_angle)
	for e in evs:
		match e.t:
			"shot":
				world.fire_flash()
				G.sfx("shot", -7.0, randf_range(0.96, 1.05), 45)
			"wall":
				G.sfx("tick", -16.0, randf_range(0.9, 1.2), 35)
			"hit":
				var p := Vector2(e.x, e.y)
				world.hit_block(e.id)
				var heavy: bool = e.k == Sim.K_HEAVY
				world.fx.impact(p, heavy, e.k == Sim.K_ELECTRIC)
				if heavy:
					world.add_shake(0.12)
					G.sfx("hit_heavy", -5.0, randf_range(0.9, 1.05), 40)
				elif e.k >= 0:
					G.sfx("hit", -9.0, randf_range(0.85, 1.25), 28)
				if not tut_hit_seen and int(G.meta.tutorial) == 1:
					tut_hit_seen = true
					_hint_strength(e.id)
			"break":
				world.fx.break_stone(Vector2(e.x, e.y), e.w, e.h, e.g)
				flying_gems += int(e.g)
				G.add_crystals(sim.claim())
				world.add_shake(0.22 * sqrt(float(e.w * e.h)))
				G.sfx("break", -3.0, randf_range(0.9, 1.08), 50)
				G.vibrate(22)
			"cleared":
				# removed by the second chance: crumbles without crystals
				world.fx.break_stone(Vector2(e.x, e.y), e.w, e.h, 0)
			"zap":
				world.fx.zap(Vector2(e.x, e.y), Vector2(e.x2, e.y2))
				G.sfx("zap", -5.0, randf_range(0.95, 1.1), 50)
			"fizzle":
				world.fx.fizzle(Vector2(e.x, e.y))
			"ret":
				world.fx.home(Vector2(e.x, e.y), muzzle, sim.ball_kind(e.i))
			"recall":
				world.fx.home(Vector2(e.x, e.y), muzzle, sim.ball_kind(e.i), true)
			"end":
				_on_volley_end()
			"over":
				over_timer = 1.1
				G.sfx("gameover", -2.0)
				G.vibrate(220)
				world.add_shake(1.0)
				Ads.load_ad("revive")
			"won":
				won_timer = 0.9
				G.sfx("upgrade", -2.0)
				G.vibrate(60)
			"bonus":
				G.add_crystals(sim.claim())
				world.fx.float_text(Vector2(360, 640), G.t("maxed_bonus", {"n": e.g}), Color("7fe3d6"), 30)
				G.sfx("upgrade", -4.0)
	world.sync_blocks()

func _on_volley_end() -> void:
	# one line per volley in the log (logcat tag "godot"): how smooth the volley ran on this device
	if perf_frames > 0:
		print("volley %d: %d balls, %d frames, avg %.1f ms, worst %.1f ms" % [sim.volleys, sim.v_total, perf_frames, perf_sum / perf_frames * 1000.0, perf_worst * 1000.0])
	perf_frames = 0
	perf_sum = 0.0
	perf_worst = 0.0
	world.apply_pending()
	world.scroll_target = sim.depth * Sim.CELL
	world.sync_blocks()
	world.danger = sim.danger_level()
	G.sfx("shift", -6.0)
	boost = false
	if world.danger == 2 and sim.phase != Sim.PH_OVER:
		G.sfx("danger", -4.0)
		G.vibrate(60)
	if world.danger >= 1 and not sim.revive_used:
		Ads.load_ad("revive")      # ready before it may be needed
	if sim.phase == Sim.PH_UPGRADE:
		upgrade_timer = 0.45
	if sim.phase != Sim.PH_OVER and sim.phase != Sim.PH_WON:
		G.store_run(sim)

# ---------------------------------------------------------------- tutorial

func _tutorial() -> void:
	var step := int(G.meta.tutorial)
	if paused or screens.is_open():
		if hud.hint.visible:
			hud.hide_hint()
			tut_hint_step = -1   # shown again once the screen closes
		return
	if step >= 6:
		return
	if sim.phase == Sim.PH_AIM:
		var want := -1
		if step == 0:
			want = 0
		elif step == 2:
			want = 2
		elif step == 3 and (sim.danger_level() >= 1 or sim.volleys >= 3):
			want = 3
		elif step == 1:
			# the volley ended without a hit; fall through to the ricochet hint next time
			G.meta.tutorial = 2
		if want != tut_hint_step:
			tut_hint_step = want
			match want:
				0:
					hud.show_hint(G.t("tut_aim"), Vector2(360, 760))
					hud.show_hand(true)
				2:
					hud.show_hint(G.t("tut_ricochet"), Vector2(360, 330), Vector2(Sim.FIELD_X0 + 10, 420))
				3:
					hud.show_hint(G.t("tut_danger"), Vector2(360, 330), Vector2(200, Sim.DANGER_Y))
				-1:
					hud.hide_hint()
		if aiming and aim_ok and hud.hand.visible:
			hud.show_hand(false)

func _hint_strength(id: int) -> void:
	var b: Dictionary = sim.blocks.get(id, {})
	if b.is_empty():
		return
	var c := sim.block_rect(b).get_center()
	hud.show_hint(G.t("tut_strength"), Vector2(360, clampf(c.y - 170, 300, 900)), c + Vector2(0, -30))
	G.meta.tutorial = 2
	get_tree().create_timer(3.2).timeout.connect(func():
		if tut_hint_step == -1:
			hud.hide_hint())

func _on_lang() -> void:
	hud.refresh()
	hud.update_state(sim, flying_gems, 1, false)
	if tut_hint_step >= 0:
		var s := tut_hint_step
		tut_hint_step = -2
		if s == 0:
			hud.show_hint(G.t("tut_aim"), Vector2(360, 760))

# ---------------------------------------------------------------- lifecycle

func _go_back() -> void:
	## Android back button: never lose a run by accident.
	if Ads.showing != "":
		return
	if screens.is_open():
		match screens.current:
			"menu":
				G.save_game()
				get_tree().quit()
			"pause":
				resume_from_pause()
			"upgrade", "over", "won", "lost", "revive", "allclear":
				pass
			_:
				screens.back()
	elif mode == M_GAME:
		open_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Ads.showing != "" or Store.flow_pid != "":
			# our own ad or the Google Play window took the focus: the state is already saved
			G.save_game()
			return
		if mode == M_GAME and sim.phase != Sim.PH_OVER and sim.phase != Sim.PH_WON and over_timer < 0.0 and won_timer < 0.0:
			G.store_run(sim)   # full snapshot, balls in flight included
			if not paused and what != NOTIFICATION_WM_CLOSE_REQUEST:
				open_pause()
		else:
			G.save_game()
