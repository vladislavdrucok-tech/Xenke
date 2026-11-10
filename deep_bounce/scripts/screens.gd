extends Control
## Menus and overlays: main menu, settings, cosmetics, pause, confirmation, upgrade choice, run summary.
## Every screen is built by a function, so a language switch simply rebuilds the open one.

const UK := preload("res://scripts/ui_kit.gd")

var main: Node
var layer: Control
var current := ""
var _builder: Callable
var _stack: Array = []
var toast_label: Label
var toast_t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UK.theme()
	toast_label = UK.label("", 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -320
	toast_label.offset_right = 320
	toast_label.offset_top = 210
	toast_label.offset_bottom = 300
	toast_label.z_index = 10
	add_child(toast_label)
	G.lang_changed.connect(func():
		if _builder.is_valid():
			_open(current, _builder, false))

func is_open() -> bool:
	return layer != null

func close() -> void:
	if layer:
		layer.queue_free()
		layer = null
	current = ""
	_builder = Callable()

func back() -> void:
	if _stack.is_empty():
		if current in ["settings", "cosmetics"] and main.mode == main.M_MENU:
			show_menu()
		elif current in ["settings", "confirm"] and main.mode == main.M_GAME:
			show_pause()
		else:
			close()
		return
	var prev: Array = _stack.pop_back()
	_open(prev[0], prev[1], false)

func toast(text: String, secs := 2.2) -> void:
	toast_label.text = text
	toast_t = secs

func _process(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		toast_label.modulate.a = clampf(toast_t * 3.0, 0.0, 1.0)
	else:
		toast_label.modulate.a = 0.0

func _open(name: String, builder: Callable, push := true) -> void:
	if push and layer and current != "" and current != name:
		_stack.append([current, _builder])
	if layer:
		layer.queue_free()
	layer = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	move_child(toast_label, -1)
	current = name
	_builder = builder
	builder.call(layer)

func _column(parent: Control, top := 0.0, sep := 18) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = top
	v.offset_left = 40
	v.offset_right = -40
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v

func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc

func _card(parent: Control, width := 600.0) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(v)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(pc)
	parent.add_child(cc)
	return v

# ---------------------------------------------------------------- main menu

func show_menu() -> void:
	_stack.clear()
	_open("menu", func(l: Control):
		UK.dim(l, 0.55)
		var v := _column(l, 170, 18)
		var logo := UK.icon("res://assets/art/ui/logo.png", Vector2(500, 268))
		v.add_child(_center(logo))
		var best := UK.label(G.t("best_depth", [G.meta.best]), 32)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(best)
		var gems := HBoxContainer.new()
		gems.alignment = BoxContainer.ALIGNMENT_CENTER
		gems.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gems.add_child(UK.icon("res://assets/art/ui/gem_icon.png", Vector2(40, 52)))
		gems.add_child(UK.label(str(G.meta.crystals), 36))
		v.add_child(gems)
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 20)
		v.add_child(sp)
		v.add_child(_center(UK.button(G.t("play"), func(): main.menu_play())))
		var cont := UK.button(G.t("continue"), func(): main.menu_continue())
		cont.disabled = not G.has_run()
		v.add_child(_center(cont))
		v.add_child(_center(UK.button(G.t("cosmetics"), func(): show_cosmetics(), true)))
		v.add_child(_center(UK.button(G.t("settings"), func(): show_settings(), true)))
		var ver := UK.label(G.t("version", [G.VERSION]) + "  ·  " + G.t("offline"), 20, Color(0.75, 0.9, 0.88, 0.7), 4, "Rubik-Bold")
		ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ver))

func confirm(text: String, yes: Callable) -> void:
	_open("confirm", func(l: Control):
		UK.dim(l, 0.7)
		var v := _card(l, 600)
		var msg := UK.label(text, 30, UK.CREAM, 6, "Rubik-Bold")
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.custom_minimum_size = Vector2(520, 0)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(msg)
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 20)
		h.add_child(UK.button(G.t("yes"), yes, false, Vector2(230, 90)))
		h.add_child(UK.button(G.t("no"), func(): back(), true, Vector2(230, 90)))
		v.add_child(h))

# ---------------------------------------------------------------- settings

func show_settings() -> void:
	_open("settings", func(l: Control):
		UK.dim(l, 0.72)
		var v := _card(l, 640)
		var title := UK.label(G.t("settings"), 44)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		v.add_child(_row(G.t("language"), [["English", G.settings.lang == "en", func(): G.set_lang("en")],
			["Українська", G.settings.lang == "uk", func(): G.set_lang("uk")]]))
		v.add_child(_toggle_row("sound", func(on): G.settings.sound = on))
		v.add_child(_toggle_row("music", func(on):
			G.settings.music = on
			G.apply_music()))
		v.add_child(_toggle_row("vibration", func(on):
			G.settings.vibration = on
			if on:
				G.vibrate(40)))
		v.add_child(_toggle_row("reduced_fx", func(on): G.settings.reduced_fx = on))
		var shake_opts: Array = []
		for i in 4:
			var lv := i
			shake_opts.append([G.t("shake_%d" % i), int(G.settings.shake) == i, func():
				G.settings.shake = lv
				G.save_game()
				main.preview_shake()
				show_settings()])
		var sh_title := UK.label(G.t("shake"), 28, UK.CREAM, 6, "Rubik-Bold")
		v.add_child(sh_title)
		v.add_child(_buttons_line(shake_opts, Vector2(128, 70), 22))
		v.add_child(_center(UK.button(G.t("replay_tutorial"), func():
			G.meta.tutorial = 0
			G.save_game()
			main.tutorial_reset()
			toast(G.t("tutorial_reset")), true, Vector2(460, 84))))
		v.add_child(_center(UK.button(G.t("back"), func(): back(), false, Vector2(300, 90)))))

func _row(title: String, opts: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UK.label(title, 28, UK.CREAM, 6, "Rubik-Bold"))
	v.add_child(_buttons_line(opts, Vector2(262, 72), 26))
	return v

func _buttons_line(opts: Array, sz: Vector2, fs: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	for o in opts:
		var cb: Callable = o[2]
		var b := UK.button(o[0], cb, true, sz)
		b.add_theme_font_size_override("font_size", fs)
		if o[1]:
			b.theme_type_variation = "OnButton"
		h.add_child(b)
	return h

func _toggle_row(key: String, setter: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := UK.label(G.t(key), 30, UK.CREAM, 6, "Rubik-Bold")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var on: bool = G.settings[key]
	var b := UK.button(G.t("on") if on else G.t("off"), func():
		setter.call(not on)
		G.save_game()
		show_settings(), true, Vector2(170, 70))
	if on:
		b.theme_type_variation = "OnButton"
	h.add_child(b)
	return h

func show_settings_stacked() -> void:
	show_settings()

# ---------------------------------------------------------------- cosmetics

func show_cosmetics() -> void:
	_open("cosmetics", func(l: Control):
		UK.dim(l, 0.78)
		var v := _column(l, 0, 14)
		var title := UK.label(G.t("cosmetics"), 46)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var gems := HBoxContainer.new()
		gems.alignment = BoxContainer.ALIGNMENT_CENTER
		gems.add_child(UK.icon("res://assets/art/ui/gem_icon.png", Vector2(40, 52)))
		gems.add_child(UK.label(str(G.meta.crystals), 38))
		v.add_child(gems)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		for id in G.SKINS:
			grid.add_child(_skin_card(id))
		v.add_child(_center(grid))
		var hint := UK.label(G.t("cos_hint"), 22, Color(0.75, 0.92, 0.9), 4, "Rubik-Bold")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
		v.add_child(_center(UK.button(G.t("back"), func(): back(), false, Vector2(300, 90)))))

func _skin_card(id: String) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(316, 0)
	pc.add_theme_stylebox_override("panel", UK.sbt("card.png", 40, Vector4(18, 16, 18, 18)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var prev := UK.icon("res://assets/art/cannon/preview_%s.png" % id, Vector2(270, 180))
	var owned: bool = G.meta.owned.has(id)
	if not owned:
		prev.modulate = Color(0.78, 0.78, 0.78)
	v.add_child(_center(prev))
	var name := UK.label(G.t("skin_" + id), 26)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	var d := UK.label(G.t("skin_%s_d" % id), 18, Color(0.85, 0.93, 0.9), 4, "Rubik-Bold")
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(270, 46)
	v.add_child(d)
	var b: Button
	if G.meta.skin == id:
		b = UK.button(G.t("selected"), func(): pass, true, Vector2(260, 68))
		b.theme_type_variation = "OnButton"
	elif owned:
		b = UK.button(G.t("select"), func():
			G.select_skin(id)
			main.apply_skin()
			show_cosmetics(), true, Vector2(260, 68))
	else:
		var price: int = G.SKIN_PRICE[id]
		b = UK.button("%s  %d" % [G.t("buy"), price], func():
			if G.buy_skin(id):
				G.sfx("buy")
				main.apply_skin()
				toast(G.t("bought"))
			else:
				G.sfx("deny")
				toast(G.t("not_enough"))
			show_cosmetics(), false, Vector2(260, 68))
		b.icon = load("res://assets/art/ui/gem_icon.png")
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 26)
		if G.meta.crystals < price:
			b.modulate = Color(0.8, 0.8, 0.8)
	b.add_theme_font_size_override("font_size", 26)
	v.add_child(_center(b))
	return pc

# ---------------------------------------------------------------- in-run overlays

func show_pause() -> void:
	_stack.clear()
	_open("pause", func(l: Control):
		UK.dim(l, 0.66)
		var v := _card(l, 560)
		var title := UK.label(G.t("paused"), 48)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var d := UK.label(G.t("depth", [main.sim.depth]) + "   ·   " + G.balls_text(main.sim.balls), 26, UK.TEAL, 6, "Rubik-Bold")
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(d)
		v.add_child(_center(UK.button(G.t("resume"), func(): main.resume_from_pause())))
		v.add_child(_center(UK.button(G.t("settings"), func(): show_settings(), true)))
		v.add_child(_center(UK.button(G.t("end_run"), func(): confirm(G.t("end_run_q"), func(): main.end_run_now()), true)))
		v.add_child(_center(UK.button(G.t("main_menu"), func(): main.to_menu(), true))))

func show_upgrade(opts: Array) -> void:
	_stack.clear()
	_open("upgrade", func(l: Control):
		UK.dim(l, 0.6)
		var v := _column(l, 0, 16)
		var title := UK.label(G.t("choose_upgrade"), 44)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		if int(G.meta.tutorial) >= 4 and int(G.meta.tutorial) < 6:
			var tip := UK.label(G.t("tut_upgrade"), 24, UK.TEAL, 6, "Rubik-Bold")
			tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(tip)
		for id in opts:
			v.add_child(_center(_upgrade_card(id))))

func _upgrade_card(id: String) -> Control:
	var s: Sim = main.sim
	var b := Button.new()
	b.theme_type_variation = "TealButton"
	b.custom_minimum_size = Vector2(620, 196)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UK.sbt("card.png", 40))
	b.add_theme_stylebox_override("hover", UK.sbt("card.png", 40))
	b.add_theme_stylebox_override("pressed", UK.sbt("button_teal_hover.png", 26))
	b.pressed.connect(func():
		G.sfx("upgrade")
		main.pick_upgrade(id))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.offset_right = -22
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := UK.icon("res://assets/art/ui/up_%s.png" % id, Vector2(120, 120))
	h.add_child(_center(ic))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name := ""
	var lvl := ""
	var desc := ""
	match id:
		"balls":
			name = G.t("up_balls")
			lvl = "%d → %d" % [s.balls, mini(Sim.MAX_BALLS, s.balls + Sim.BALLS_STEP)]
			desc = G.t("up_balls_d", [s.balls, mini(Sim.MAX_BALLS, s.balls + Sim.BALLS_STEP)])
		"heavy":
			name = G.t("up_heavy")
			lvl = G.t("level_to", [s.heavy, s.heavy + 1])
			desc = G.t("up_heavy_d", [Sim.HEAVY_DMG[s.heavy + 1]])
		"electric":
			name = G.t("up_electric")
			lvl = G.t("level_to", [s.electric, s.electric + 1])
			desc = G.t("up_electric_d", [Sim.ZAP_DMG[s.electric + 1]])
	v.add_child(UK.label(name, 31))
	v.add_child(UK.label(lvl, 23, UK.TEAL, 6))
	var dl := UK.label(desc, 21, Color(0.9, 0.95, 0.92), 4, "Rubik-Bold")
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(420, 0)
	v.add_child(dl)
	return b

func show_gameover(data: Dictionary) -> void:
	_stack.clear()
	_open("over", func(l: Control):
		UK.dim(l, 0.7)
		var v := _card(l, 600)
		var title := UK.label(G.t("run_over"), 50)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		if data.record:
			var rec := UK.label(G.t("new_record"), 34, Color("ffd36b"))
			rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(rec)
		v.add_child(_stat(G.t("depth_reached"), G.t("meters", [data.depth]), 44))
		v.add_child(_stat(G.t("record"), G.t("meters", [G.meta.best]), 30))
		v.add_child(_stat(G.t("crystals_earned"), "+%d" % data.gems, 34, true))
		v.add_child(_stat(G.t("stones_broken"), str(data.broken), 28))
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 8)
		v.add_child(sp)
		v.add_child(_center(UK.button(G.t("play_again"), func(): main.start_new_run())))
		v.add_child(_center(UK.button(G.t("menu"), func(): main.to_menu(), true))))

func _stat(title: String, value: String, size: int, gem := false) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(500, 0)
	var t := UK.label(title, 26, Color(0.85, 0.95, 0.92), 6, "Rubik-Bold")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if gem:
		h.add_child(UK.icon("res://assets/art/ui/gem_icon.png", Vector2(30, 40)))
	h.add_child(UK.label(value, size))
	return h
