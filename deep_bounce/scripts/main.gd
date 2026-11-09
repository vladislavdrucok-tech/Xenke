extends Node
## Deep Bounce controller: layout (9:16 world fitted into the safe area), touch aiming, the fixed-step
## volley loop, turning simulation events into effects and sounds, saving, tutorial hints, screens.

const World := preload("res://scripts/world.gd")
const Hud := preload("res://scripts/hud.gd")
const Screens := preload("res://scripts/screens.gd")
const QA := preload("res://scripts/qa.gd")

enum { M_MENU, M_GAME }

var sim := Sim.new()
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
var upgrade_timer := -1.0
var layout_scale := 1.0
var layout_origin := Vector2.ZERO

# aiming
var touch_id := -1
var touch_start := Vector2.ZERO
var aiming := false
var aim_ok := false

# tutorial: 0 aim, 1 strength, 2 ricochet, 3 danger, 4..5 upgrade hint shown, 6 done
var tut_hint_step := -1
var tut_hit_seen := false

var qa: Node

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("082b30"))
	world = World.new()
	add_child(world)
	world.sim = sim
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
	_layout()
	# menu background: the saved run, or a fresh decorative field
	if G.has_run():
		sim.from_dict(G.run)
	else:
		sim.new_run(12345)
	world.aim_angle = sim.aim
	world.sync_blocks(true)
	world.scroll = sim.depth * Sim.CELL
	world.scroll_target = world.scroll
	hud.visible = false
	screens.show_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa"):
			qa = QA.new()
			qa.main = self
			add_child(qa)
			break

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
	# the panel hides the stones below the floor; on tall screens the gap shows upcoming rows in fog
	_update_gem_target()

func _update_gem_target() -> void:
	await get_tree().process_frame
	var gp: Vector2 = hud.gem_target_global()
	world.fx.gem_target = (gp - layout_origin) / layout_scale

func to_world(p: Vector2) -> Vector2:
	return (p - layout_origin) / layout_scale

# ---------------------------------------------------------------- run flow

func menu_play() -> void:
	if G.has_run():
		screens.confirm(G.t("new_run_q"), func(): start_new_run())
	else:
		start_new_run()

func menu_continue() -> void:
	if not G.has_run():
		return
	sim.from_dict(G.run)
	_enter_game()
	if sim.phase == Sim.PH_VOLLEY:
		open_pause()
	elif sim.phase == Sim.PH_UPGRADE:
		screens.show_upgrade(sim.upgrade_opts)
	elif sim.phase == Sim.PH_OVER:
		_game_over()

func start_new_run(seed := -1) -> void:
	if seed < 0:
		seed = int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	sim.new_run(seed)
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
	upgrade_timer = -1.0
	world.fx.clear()
	world.clear_blocks()
	world.sync_blocks(true)
	world.aim_angle = sim.aim
	world.scroll = sim.depth * Sim.CELL
	world.scroll_target = world.scroll
	world.prev_pos.clear()
	world.trails.clear()
	world.set_skin(G.meta.skin)
	world.danger = sim.danger_level()
	hud.visible = true
	hud.hide_hint()
	screens.close()
	tut_hint_step = -1
	_update_gem_target()
	G.sfx("start", -4.0)

func to_menu() -> void:
	if mode == M_GAME and sim.phase != Sim.PH_OVER:
		G.store_run(sim)
	mode = M_MENU
	paused = false
	hud.visible = false
	hud.hide_hint()
	world.aim_visible = false
	screens.show_menu()

func open_pause() -> void:
	if mode != M_GAME or sim.phase == Sim.PH_OVER or over_timer >= 0.0:
		return
	paused = true
	_cancel_aim()
	G.store_run(sim)
	screens.show_pause()

func resume_from_pause() -> void:
	screens.close()
	paused = false
	if sim.phase == Sim.PH_UPGRADE:
		screens.show_upgrade(sim.upgrade_opts)

func end_run_now() -> void:
	screens.close()
	if sim.phase == Sim.PH_VOLLEY:
		# the balls in flight are recalled; the run ends at the depth reached
		sim.recall_all()
		_consume_events()
	sim.phase = Sim.PH_OVER
	_game_over()

func pick_upgrade(id: String) -> void:
	if sim.choose_upgrade(id):
		if int(G.meta.tutorial) >= 4:
			G.meta.tutorial = 6
		_consume_events()
		G.store_run(sim)
		screens.close()
		paused = false
		world.fx.float_text(Vector2(360, 700), G.t("up_" + id), Color("7fe3d6"), 40)

func apply_skin() -> void:
	world.set_skin(G.meta.skin)

func preview_shake() -> void:
	world.add_shake(0.8)

func tutorial_reset() -> void:
	tut_hint_step = -1
	tut_hit_seen = false

func _game_over() -> void:
	paused = true
	hud.hide_hint()
	world.aim_visible = false
	var gems := sim.run_gems
	var broken := int(sim.stats.destroyed)
	var depth := sim.depth
	var record := G.finish_run(sim)
	screens.show_gameover({"record": record, "depth": depth, "gems": gems, "broken": broken})

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if mode != M_GAME or paused or screens.is_open():
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
	if not sim.fire(angle):
		return
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
	if over_timer >= 0.0:
		over_timer -= dt
		if over_timer < 0.0:
			_game_over()
	if upgrade_timer >= 0.0:
		upgrade_timer -= dt
		if upgrade_timer < 0.0 and sim.phase == Sim.PH_UPGRADE:
			paused = true
			screens.show_upgrade(sim.upgrade_opts)
	var speed := 1
	if sim.phase == Sim.PH_VOLLEY and not paused:
		volley_time += dt
		speed = 1
		if volley_time > 3.5:
			speed = 2
		if volley_time > 8.0:
			speed = 3
		if boost:
			speed = 4
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
	hud.update_state(sim, flying_gems, speed, sim.phase == Sim.PH_VOLLEY and volley_time > 2.0)
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
			"bonus":
				G.add_crystals(sim.claim())
				world.fx.float_text(Vector2(360, 640), G.t("maxed_bonus", [e.g]), Color("7fe3d6"), 30)
				G.sfx("upgrade", -4.0)
	world.sync_blocks()

func _on_volley_end() -> void:
	world.scroll_target = sim.depth * Sim.CELL
	world.sync_blocks()
	world.danger = sim.danger_level()
	G.sfx("shift", -6.0)
	boost = false
	if world.danger == 2 and sim.phase != Sim.PH_OVER:
		G.sfx("danger", -4.0)
		G.vibrate(60)
	if sim.phase == Sim.PH_UPGRADE:
		upgrade_timer = 0.45
	if sim.phase != Sim.PH_OVER:
		G.store_run(sim)

# ---------------------------------------------------------------- tutorial

func _tutorial() -> void:
	var step := int(G.meta.tutorial)
	if step >= 6 or paused or screens.is_open():
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
	hud.update_state(sim, flying_gems, 1, false)
	if tut_hint_step >= 0:
		var s := tut_hint_step
		tut_hint_step = -2
		if s == 0:
			hud.show_hint(G.t("tut_aim"), Vector2(360, 760))

# ---------------------------------------------------------------- lifecycle

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode == M_GAME and sim.phase != Sim.PH_OVER and over_timer < 0.0:
			G.store_run(sim)   # full snapshot, balls in flight included
			if not paused and what != NOTIFICATION_WM_CLOSE_REQUEST:
				open_pause()
		elif mode == M_MENU:
			G.save_game()
