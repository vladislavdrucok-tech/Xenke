class_name InfoScreen
extends Control
## Records + guest gallery, or settings (mode "records" / "settings").

signal back
signal replay_tutorial

var mode := "records"
var _reset_armed := false
var box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("140e24")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_right = -10
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.add_child(Art.title_label("РЕКОРДИ" if mode == "records" else "НАЛАШТУВАННЯ", 16, Art.GOLD))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	sc.add_child(box)
	if mode == "records":
		_records()
	else:
		_settings()
	var b := Art.button("НАЗАД", "btn", "home")
	b.custom_minimum_size.y = 40
	b.pressed.connect(func(): back.emit())
	root.add_child(b)


func _stat(icon: String, title: String, value: String) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Art.style("panel_light", 8))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var ic := TextureRect.new()
	ic.texture = Art.icon_texture(icon)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	hb.add_child(ic)
	var l := Art.label(title, 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	hb.add_child(Art.title_label(value, 8, Art.GOLD_L))
	pc.add_child(hb)
	box.add_child(pc)


func _records() -> void:
	_stat("calendar", "Найдовша кар'єра (змін)", str(Save.record("best_shift")))
	_stat("coin", "Найбільше монет за зміну", str(Save.record("best_coins")))
	_stat("bolt", "Найдовша серія", str(Save.record("best_streak")))
	_stat("person", "Усього довезено гостей", str(Save.record("total_delivered")))
	_stat("pile", "Усього зароблено монет", str(Save.record("total_coins")))
	_stat("check", "Успішних змін", str(Save.record("shifts_done")))
	_stat("star", "Змін без жодної скарги", str(Save.record("perfect_shifts")))
	box.add_child(Art.title_label("ГОСТІ ГОТЕЛЮ", 8, Art.CYAN))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var seen: Array = Save.data["seen_types"]
	for t in Defs.TYPE_ORDER:
		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(76, 0)
		var tr := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = Art.tex("passengers")
		at.region = Rect2(0, Defs.TYPE_ORDER.find(t) * 28, 24, 28)
		tr.texture = at
		tr.custom_minimum_size = Vector2(48, 56)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var known := seen.has(t)
		if not known:
			tr.modulate = Color(0, 0, 0, 0.8)
		vb.add_child(tr)
		var l := Art.label(String(Defs.TYPES[t]["name"]) if known else "???", 16, Art.WHITE if known else Art.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
		if known:
			vb.tooltip_text = String(Defs.TYPES[t]["rule"])
		grid.add_child(vb)
	box.add_child(grid)


func _settings() -> void:
	for key in ["sfx", "music", "vibe"]:
		var b := Art.button(Game.toggle_text(key), "btn", Game.toggle_icon(key))
		b.custom_minimum_size.y = 40
		b.pressed.connect(func():
			Save.set_setting(key, not Save.setting(key))
			Sfx.refresh_settings()
			b.text = Game.toggle_text(key)
			b.icon = Art.icon_texture(Game.toggle_icon(key)))
		box.add_child(b)
	var t := Art.button("ПРОЙТИ НАВЧАННЯ ЗНОВУ", "btn", "info")
	t.custom_minimum_size.y = 40
	t.pressed.connect(func(): replay_tutorial.emit())
	box.add_child(t)
	var r := Art.button("СКИНУТИ ПРОГРЕС", "btn_grey", "cross")
	r.custom_minimum_size.y = 40
	r.pressed.connect(func():
		if not _reset_armed:
			_reset_armed = true
			r.text = "ТОЧНО? НАТИСНИ ЩЕ РАЗ"
			return
		Save.reset_progress()
		r.text = "ПРОГРЕС СКИНУТО"
		r.disabled = true)
	box.add_child(r)
	var about := Art.label("FLOOR 13: NIGHT SHIFT v%s\nГра працює без інтернету. Прогрес зберігається автоматично на телефоні.\nШрифти: Press Start 2P, Tiny5 (SIL OFL)." % Defs.VERSION, 16, Art.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)


func on_back() -> void:
	back.emit()
