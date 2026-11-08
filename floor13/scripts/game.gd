class_name Game
extends Control
## The shift screen: owns the ShiftSim, the hotel view, HUD, button panel and the
## cards shown before/after a shift and on pause.

signal go_menu
signal go_shop

enum { S_INTRO, S_PLAY, S_PAUSE, S_RESULT }

var sim: ShiftSim
var world: WorldView
var hud: Hud
var panel: FloorPanel
var overlay: Control
var tutorial: Node
var state := S_INTRO
var shift := 1
var _acc := 0.0
var _end_t := 0.0
var _last_tick := -1
var _new_floor := false
var _intro_shown_at := 0
var _greeted := {}
var task := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world = WorldView.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.offset_top = Hud.H
	world.offset_bottom = -FloorPanel.panel_height()
	world.floor_tapped.connect(_on_floor)
	add_child(world)
	panel = FloorPanel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -FloorPanel.panel_height()
	panel.pressed_floor.connect(_on_floor)
	add_child(panel)
	hud = Hud.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_bottom = Hud.H
	hud.pause_pressed.connect(pause)
	add_child(hud)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


# ------------------------------------------------------------------ shift lifecycle

func pick_rule(s: int, floors: int) -> Array:
	if s < 3:
		return ["none", 0]
	var last := String(Save.data.get("last_rule", ""))
	var ids := []
	var weights := []
	for id in Defs.RULES:
		if id == last:
			continue
		if id == "repair" and floors < 7:
			continue
		if id == "school" and not Defs.type_unlocked("kid", floors):
			continue
		if id == "moon" and floors < 13:
			continue
		ids.append(id)
		weights.append(2.0 if id == "none" else 1.0)
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	var pick: String = ids[0]
	for i in ids.size():
		r -= weights[i]
		if r <= 0.0:
			pick = ids[i]
			break
	var rf := 0
	if pick == "repair":
		rf = randi_range(2, mini(floors - 1, 12))
	return [pick, rf]


func start_shift(s: int, tutorial_mode := false) -> void:
	shift = s
	sim = ShiftSim.new()
	var floors := Defs.floors_for_shift(s)
	var rule := ["none", 0] if tutorial_mode else pick_rule(s, floors)
	var cfg := {"shift": s, "floors": floors, "upgrades": Save.data["upgrades"], "rule": rule[0],
		"rule_floor": rule[1], "tutorial": tutorial_mode}
	if tutorial_mode:
		cfg["floors"] = Defs.START_FLOORS
		cfg["duration"] = 9999.0
	sim.setup(cfg)
	world.set_sim(sim)
	panel.sim = sim
	hud.sim = sim
	_acc = 0.0
	_end_t = 0.0
	_last_tick = -1
	_new_floor = s > 1 and floors > Defs.floors_for_shift(s - 1) and not tutorial_mode
	_greeted.clear()
	task = {}
	if not tutorial_mode:
		var r := RandomNumberGenerator.new()
		r.randomize()
		task = Defs.make_task(s, floors, r)
	hud.task = task
	_clear_overlay()
	if tutorial != null:
		tutorial.queue_free()
		tutorial = null
	Sfx.music("shift")
	if tutorial_mode:
		state = S_PLAY
		tutorial = load("res://scripts/tutorial.gd").new()
		tutorial.game = self
		add_child(tutorial)
	else:
		Save.data["last_rule"] = rule[0]
		Save.mark()
		state = S_INTRO
		_show_intro()


func _begin_play() -> void:
	_clear_overlay()
	state = S_PLAY
	for t in Defs.types_new_at(sim.floors):
		Save.see_type(t)
	for t in Defs.TYPE_ORDER:
		if Defs.type_unlocked(t, sim.floors) and float(Defs.TYPES[t]["weight"]) > 0.0:
			Save.see_type(t)
	if _new_floor:
		world.unlock_anim = 1.0
		world.manual_t = 2.4
		world.cam_y = world.world_top() + world.size.y / 2.0
		for i in 10:
			world.steam(Vector2(110 + i * 24, world.floor_top(sim.floors) + 6))
		world.float_text(Vector2(230, world.floor_top(sim.floors) + 40), "НОВИЙ ПОВЕРХ!", Art.GREEN, 2.2)
		Sfx.play("unlock")
	else:
		Sfx.play("shift_start")


func pause() -> void:
	if state != S_PLAY:
		return
	state = S_PAUSE
	Sfx.set_motor(0.0)
	_show_pause()


func resume() -> void:
	if state != S_PAUSE:
		return
	_clear_overlay()
	state = S_PLAY


func on_back() -> void:
	match state:
		S_PLAY:
			pause()
		S_PAUSE:
			resume()
		_:
			go_menu.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == S_PLAY and (tutorial == null):
			pause()


func _process(delta: float) -> void:
	if sim == null:
		return
	if state == S_PLAY:
		_acc += minf(delta, 0.1)
		var steps := 0
		while _acc >= 1.0 / 60.0 and steps < 6:
			sim.step(1.0 / 60.0)
			_acc -= 1.0 / 60.0
			steps += 1
		_drain_events()
		Sfx.set_motor(absf(sim.vel) / maxf(sim.speed(), 0.1))
		if not sim.tutorial and not sim.over:
			var left := int(ceil(sim.duration - sim.time))
			if left <= 5 and left != _last_tick and left > 0:
				_last_tick = left
				Sfx.play("tick", 1.0 + (5 - left) * 0.05)
		if sim.over:
			_end_t += delta
			Sfx.set_motor(0.0)
			if _end_t > 1.3:
				_show_results()
	elif state != S_PAUSE:
		Sfx.set_motor(0.0)


func _on_floor(f: int) -> void:
	if state != S_PLAY or sim == null or sim.over:
		return
	if tutorial != null and not tutorial.allow_press(f):
		Sfx.play("deny")
		return
	var r := sim.press(f)
	if r != 0:
		Sfx.vibe(12)
	_drain_events()


# ------------------------------------------------------------------ sim events

func _drain_events() -> void:
	for e in sim.out:
		world.on_sim_event(e)
		if tutorial != null:
			tutorial.on_event(e)
		match e.t:
			"press":
				Sfx.play("press", 1.0 + (e.floor - 1) * 0.03)
			"unpress":
				Sfx.play("unpress")
			"deny":
				Sfx.play("deny")
				Sfx.vibe(40)
			"arrive":
				Sfx.play("ding", 1.0, -3.0, 0.0)
			"opened":
				Sfx.play("door_open", 1.0, -6.0)
			"closing":
				Sfx.play("door_close", 1.0, -6.0)
			"spawn":
				var p := _find(e.pid)
				if not p.is_empty():
					var first := not _greeted.has(p.type)
					if first or randf() < 0.3:
						_greeted[p.type] = true
						world.say(p.id, Defs.line(p.type, "hello"))
			"board":
				var p := _find(e.pid)
				if not p.is_empty() and randf() < 0.7:
					Sfx.play("v_" + String(p.type), 1.0, -4.0, 0.08)
			"deliver":
				Save.add_coins(e.coins)
				_fly_coins(world.passenger_pos(e.pid), 1 + mini(int(e.coins) / 12, 4))
				var dp := _find(e.pid)
				if not dp.is_empty():
					if e.good and randf() < 0.35:
						world.say(dp.id, Defs.line(dp.type, "thanks"), 1.8)
					if not sim.tutorial:
						if dp.type == "ghost":
							Save.add_record("ghosts", 1)
						elif dp.type == "robot" and dp.stops == 0:
							Save.add_record("robots_direct", 1)
						elif dp.type == "inspector" and e.frac >= 0.5 and not dp.grumpy:
							Save.add_record("inspectors", 1)
				if not sim.tutorial:
					_task_on_deliver(dp, e)
					_check_achievements()
				var pitch := 1.0 + minf(float(e.streak), 10.0) * 0.04
				Sfx.play("coins_big" if e.coins >= 30 else "coin", pitch)
				Sfx.vibe(10)
				if e.get("forgiven", false):
					Sfx.play("forgive")
				if e.streak > 0 and e.streak % 5 == 0:
					Sfx.play("streak", 1.0 + e.streak * 0.02)
					world.float_text(world.passenger_pos(e.pid) + Vector2(0, -16), "СЕРІЯ %d!" % e.streak, Color("ff9a3a"), 1.6)
			"complaint":
				var cp := _find(e.pid)
				if not cp.is_empty():
					world.say(cp.id, Defs.line(cp.type, "angry"), 2.0)
				Sfx.play("complaint")
				Sfx.play("heart_break", 1.0, -4.0)
				Sfx.vibe(70)
				hud.break_heart()
			"grumpy":
				world.say(e.pid, "Сам натисну!", 2.0)
				Sfx.play("complaint", 1.4, -6.0)
			"kid":
				world.say(e.pid, Defs.line("kid", "press"), 1.6)
				Sfx.play("kid")
				panel.ping(e.floor)
			"pickup":
				Save.add_coins(e.coins)
				_fly_coins(Vector2(160, world.feet_y(e.floor) - 6), 5)
				Save.add_record("pickups", 1)
				_check_achievements()
				Sfx.play("pickup")
			"vanish":
				Sfx.play("vanish")
			"event":
				var good: bool = Defs.EVENTS[e.id]["good"]
				Sfx.play("event_good" if good else "event_bad")
				if e.id == "prank":
					panel.ping(e.floor)
				if e.id == "party" or e.id == "coins":
					panel.ping(e.floor)
			"end":
				Sfx.play("shift_end")
			"fail":
				Sfx.play("fail")
	sim.out.clear()


func _task_on_deliver(p: Dictionary, e: Dictionary) -> void:
	if task.is_empty() or task.done:
		return
	match task.kind:
		"deliver":
			task.progress += 1
		"streak":
			task.progress = maxi(task.progress, int(e.streak))
		"coins":
			task.progress = sim.coins
		"type":
			if not p.is_empty() and p.type == task.type:
				task.progress += 1
		"express":
			if not p.is_empty() and p.stops == 0:
				task.progress += 1
	if task.kind != "clean" and task.progress >= task.goal:
		_task_done()


func _task_done() -> void:
	task.done = true
	task.progress = task.goal
	Save.add_coins(task.reward)
	hud.bump_coins()
	Sfx.play("unlock")
	get_tree().call_group("app", "toast", "ЗАВДАННЯ ВИКОНАНО!", "%s  +%d монет" % [task.text, task.reward])


func _check_achievements() -> void:
	for a in Save.check_achievements():
		get_tree().call_group("app", "toast", "ДОСЯГНЕННЯ: " + String(a[1]).to_upper(), "+%d монет" % int(a[5]))


## Coins fly from a point of the hotel (building coordinates) to the HUD counter.
func _fly_coins(world_pos: Vector2, n: int) -> void:
	var start := world.position + Vector2(world.bx() + world_pos.x, world.sy(world_pos.y))
	var target := Vector2(size.x - 44.0 - 46.0, 8.0)
	for i in n:
		var c := TextureRect.new()
		c.texture = Art.icon_texture("coin")
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = start + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		add_child(c)
		var mid := c.position.lerp(target, 0.4) + Vector2(randf_range(-40, 40), randf_range(-30, 10))
		var tw := c.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(c, "position", mid, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(c, "position", target, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func():
			hud.bump_coins()
			c.queue_free())


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s


func _find(pid: int) -> Dictionary:
	for p in sim.passengers:
		if p.id == pid:
			return p
	return {}


# ------------------------------------------------------------------ cards

func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _card(dim := 0.55) -> VBoxContainer:
	_clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.07, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(minf(size.x - 24.0, 340.0), 0)
	center.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pc.add_child(box)
	pc.scale = Vector2(0.9, 0.9)
	pc.pivot_offset = pc.custom_minimum_size / 2.0
	pc.modulate.a = 0.0
	var tw := pc.create_tween().set_parallel(true)
	tw.tween_property(pc, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pc, "modulate:a", 1.0, 0.15)
	return box


func _row(box: Container, icon: String, title: String, text: String, title_col := Art.GOLD) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var ic := TextureRect.new()
	ic.texture = Art.icon_texture(icon)
	ic.custom_minimum_size = Vector2(16, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Art.title_label(title, 8, title_col)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(t)
	if text != "":
		var l := Art.label(text, 16, Art.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	hb.add_child(vb)
	box.add_child(hb)


func _portrait_row(box: Container, type_id: String) -> void:
	var td: Dictionary = Defs.TYPES[type_id]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var tr := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = Art.tex("passengers")
	at.region = Rect2(6 * 24, Defs.TYPE_ORDER.find(type_id) * 28, 24, 28)
	tr.texture = at
	tr.custom_minimum_size = Vector2(48, 56)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(tr)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(Art.title_label("НОВИЙ ГІСТЬ: " + String(td["name"]).to_upper(), 8, Art.CYAN))
	var l := Art.label(String(td["rule"]), 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	hb.add_child(vb)
	box.add_child(hb)


func _title(box: Container, text: String, col := Art.GOLD, size := 16) -> void:
	var l := Art.title_label(text, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)


func _show_intro() -> void:
	var box := _card(0.45)
	_title(box, "ЗМІНА %d" % shift)
	var sub := Art.label("Ніч 22:00 — 06:00  ·  поверхів: %d" % sim.floors, 16, Art.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(HSeparator.new())
	if _new_floor:
		_row(box, "up", "НОВИЙ ПОВЕРХ: %d" % sim.floors, Defs.FLOOR_NAMES[sim.floors] + (" — тут водяться привиди…" if sim.floors == 13 else ""), Art.GREEN)
	for t in Defs.types_new_at(sim.floors):
		if not (Save.data["seen_types"] as Array).has(t):
			_portrait_row(box, t)
	if shift >= 3:
		var rd: Dictionary = Defs.RULES[sim.rule_id]
		var desc := String(rd["desc"])
		if desc.find("%d") != -1:
			desc = desc % sim.rule_floor
		_row(box, Art.RULE_ICONS.get(sim.rule_id, "star"), "ПРАВИЛО НОЧІ: " + String(rd["name"]).to_upper(), desc, Art.PINK)
	elif shift == 2:
		_row(box, "siren", "ВИПАДКОВІ ПОДІЇ", "Від сьогодні вночі трапляються дива. Читай табличку зверху.", Art.PINK)
	if not task.is_empty():
		_row(box, "check", "ЗАВДАННЯ НОЧІ: +%d МОНЕТ" % task.reward, task.text, Art.GREEN)
	_row(box, "heart", "СКАРГИ: %d" % sim.hearts, "Гість, що не дочекався, пише скаргу. Усі серця втрачено — зміну провалено.", Art.RED)
	var b := Art.button("ПОЧАТИ ЗМІНУ", "btn_gold", "play", 8)
	b.custom_minimum_size.y = 40
	b.pressed.connect(_begin_play)
	box.add_child(b)
	var m := Art.button("МЕНЮ", "btn", "home")
	m.custom_minimum_size.y = 32
	m.pressed.connect(func(): go_menu.emit())
	box.add_child(m)


func _show_pause() -> void:
	var box := _card(0.6)
	_title(box, "ПАУЗА")
	var b := Art.button("ПРОДОВЖИТИ", "btn_gold", "play")
	b.custom_minimum_size.y = 40
	b.pressed.connect(resume)
	box.add_child(b)
	for key in ["sfx", "music", "vibe"]:
		box.add_child(_toggle(key))
	var r := Art.button("ПОЧАТИ ЗМІНУ ЗАНОВО", "btn", "retry")
	r.custom_minimum_size.y = 34
	r.pressed.connect(func(): start_shift(shift, sim.tutorial))
	box.add_child(r)
	var m := Art.button("У МЕНЮ", "btn", "home")
	m.custom_minimum_size.y = 34
	m.pressed.connect(func(): go_menu.emit())
	box.add_child(m)


static func toggle_text(key: String) -> String:
	var names := {"sfx": "ЗВУКИ", "music": "МУЗИКА", "vibe": "ВІБРАЦІЯ"}
	return "%s: %s" % [names[key], "ТАК" if Save.setting(key) else "НІ"]


static func toggle_icon(key: String) -> String:
	var on := Save.setting(key)
	match key:
		"sfx":
			return "sound" if on else "sound_off"
		"music":
			return "music" if on else "music_off"
	return "vibe"


func _toggle(key: String) -> Button:
	var b := Art.button(toggle_text(key), "btn", toggle_icon(key))
	b.custom_minimum_size.y = 34
	b.pressed.connect(func():
		Save.set_setting(key, not Save.setting(key))
		Sfx.refresh_settings()
		b.text = toggle_text(key)
		b.icon = Art.icon_texture(toggle_icon(key)))
	return b


func _show_results() -> void:
	if state == S_RESULT:
		return
	state = S_RESULT
	var ok := not sim.failed
	var stars := 0
	if ok and sim.delivered > 0:
		stars = 3 - mini(sim.complaints, 2)
	# records and progress
	if not task.is_empty() and task.kind == "clean" and not task.done and ok and sim.complaints == 0 and sim.delivered >= 8:
		_task_done()
	var new_records := []
	if Save.best("best_coins", sim.coins):
		new_records.append("монети за зміну")
	if Save.best("best_streak", sim.best_streak):
		new_records.append("серія")
	Save.add_record("total_delivered", sim.delivered)
	var unlocked_floor := 0
	if ok:
		Save.add_record("shifts_done", 1)
		if sim.complaints == 0:
			Save.add_record("perfect_shifts", 1)
		if Save.best("best_shift", shift):
			new_records.append("найдовша кар'єра")
		if shift >= Save.shift():
			Save.data["shift"] = shift + 1
			if Defs.floors_for_shift(shift + 1) > sim.floors:
				unlocked_floor = Defs.floors_for_shift(shift + 1)
	_check_achievements()
	Save.flush()
	var box := _card(0.55)
	_title(box, "ЗМІНУ ЗАВЕРШЕНО!" if ok else "ЗМІНУ ПРОВАЛЕНО", Art.GOLD if ok else Art.RED, 8 if size.x < 380 else 16)
	var sb := HBoxContainer.new()
	sb.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var st := TextureRect.new()
		st.texture = Art.icon_texture("star" if i < stars else "star_empty")
		st.custom_minimum_size = Vector2(32, 32)
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sb.add_child(st)
		st.scale = Vector2.ZERO
		st.pivot_offset = Vector2(16, 16)
		var tw := st.create_tween()
		tw.tween_interval(0.25 + i * 0.25)
		tw.tween_property(st, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i < stars:
			tw.tween_callback(func(): Sfx.play("coin", 1.0 + i * 0.15))
	box.add_child(sb)
	if not ok:
		var l := Art.label("Забагато скарг. Монети залишаються в тебе — спробуй ще раз або купи покращення.", 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	_row(box, "person", "ДОВЕЗЕНО: %d" % sim.delivered, "", Art.WHITE)
	_row(box, "coin", "ЗАРОБЛЕНО: %d" % sim.coins, "", Art.GOLD_L)
	_row(box, "bolt", "НАЙКРАЩА СЕРІЯ: %d" % sim.best_streak, "", Color("ff9a3a"))
	_row(box, "heart_broken", "СКАРГИ: %d / %d" % [sim.complaints, sim.hearts], "", Art.RED)
	if not new_records.is_empty():
		_row(box, "trophy", "НОВИЙ РЕКОРД!", _cap(", ".join(new_records)), Art.GOLD)
	if not task.is_empty():
		_row(box, "check" if task.done else "cross", ("ЗАВДАННЯ ВИКОНАНО: +%d" % task.reward) if task.done else "ЗАВДАННЯ НЕ ВИКОНАНО",
			task.text, Art.GREEN if task.done else Art.DIM)
	if unlocked_floor > 0:
		_row(box, "up", "НАСТУПНОЇ НОЧІ: %d-Й ПОВЕРХ" % unlocked_floor, Defs.FLOOR_NAMES[unlocked_floor], Art.GREEN)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var shop := Art.button("ПОКРАЩЕННЯ", "btn", "gear")
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.custom_minimum_size.y = 38
	shop.pressed.connect(func(): go_shop.emit())
	hb.add_child(shop)
	var next := Art.button("ДАЛІ" if ok else "ЩЕ РАЗ", "btn_gold", "play" if ok else "retry")
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.custom_minimum_size.y = 38
	next.pressed.connect(func(): start_shift(Save.shift() if ok else shift))
	hb.add_child(next)
	box.add_child(hb)
	var m := Art.button("МЕНЮ", "btn", "home")
	m.custom_minimum_size.y = 32
	m.pressed.connect(func(): go_menu.emit())
	box.add_child(m)
