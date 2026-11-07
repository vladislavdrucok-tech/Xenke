class_name MainMenu
extends Control
## Title screen with the hotel running by itself in the background.

signal play
signal open_shop
signal open_records
signal open_settings
signal open_tutorial

var world: WorldView
var demo: ShiftSim
var _think := 0.0
var logo: TextureRect
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	demo = ShiftSim.new()
	demo.setup({"shift": 6, "floors": clampi(Defs.floors_for_shift(Save.shift()), 5, 13), "tutorial": true,
		"auto_spawn": true, "upgrades": {"motor": 2, "cabin": 2}})
	demo.duration = 1e9
	world = WorldView.new()
	world.demo = true
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.set_sim(demo)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.08, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 8)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vb)
	logo = TextureRect.new()
	logo.texture = Art.tex("logo")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	logo.custom_minimum_size = Vector2(240, 96)
	vb.add_child(logo)
	var sub := Art.label("Нічний ліфтер у дивному готелі", 16, Color("c8c0e8"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	vb.add_child(spacer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.custom_minimum_size.x = 250
	vb.add_child(col)
	var label := "ГРАТИ: ЗМІНА %d" % Save.shift() if Save.data["tutorial_done"] else "ПОЧАТИ ГРУ"
	var b := Art.button(label, "btn_gold", "play")
	b.custom_minimum_size.y = 46
	b.pressed.connect(func(): play.emit())
	col.add_child(b)
	var s := Art.button("ПОКРАЩЕННЯ", "btn", "gear")
	s.custom_minimum_size.y = 38
	s.pressed.connect(func(): open_shop.emit())
	col.add_child(s)
	var r := Art.button("РЕКОРДИ", "btn", "trophy")
	r.custom_minimum_size.y = 38
	r.pressed.connect(func(): open_records.emit())
	col.add_child(r)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var tut := Art.button("НАВЧАННЯ", "btn", "info")
	tut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut.custom_minimum_size.y = 38
	tut.pressed.connect(func(): open_tutorial.emit())
	hb.add_child(tut)
	var st := Art.button("", "btn", "gear")
	st.custom_minimum_size = Vector2(46, 38)
	st.pressed.connect(func(): open_settings.emit())
	st.tooltip_text = "Налаштування"
	hb.add_child(st)
	col.add_child(hb)
	var coins := HBoxContainer.new()
	coins.alignment = BoxContainer.ALIGNMENT_CENTER
	var ci := TextureRect.new()
	ci.texture = Art.icon_texture("coin")
	ci.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	coins.add_child(ci)
	coins.add_child(Art.title_label(str(Save.coins()), 8, Art.GOLD_L))
	vb.add_child(coins)
	var ver := Art.label("v" + Defs.VERSION + " · офлайн · одним пальцем", 16, Color(1, 1, 1, 0.35))
	ver.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ver.position.y -= 22
	add_child(ver)
	Sfx.music("menu")


func _process(delta: float) -> void:
	t += delta
	demo.step(delta)
	demo.out.clear()
	_think -= delta
	if _think <= 0.0:
		_think = 0.6
		_bot()
	if logo:
		logo.modulate = Color(1, 1, 1, 1) if fmod(t, 5.0) > 0.12 else Color(1, 1, 1, 0.7)


func _bot() -> void:
	demo.bot_step(1)


func on_back() -> void:
	Save.flush()
	get_tree().quit()
