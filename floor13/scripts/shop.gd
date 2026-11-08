class_name Shop
extends Control
## Upgrade shop between shifts.

signal back
signal play

var coins_label: Label
var list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("140e24")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_right = -8
	root.offset_top = 8
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var head := HBoxContainer.new()
	var tl := Art.title_label("ПОКРАЩЕННЯ", 16, Art.GOLD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var ci := TextureRect.new()
	ci.texture = Art.icon_texture("coin")
	ci.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ci)
	coins_label = Art.title_label("0", 8, Art.GOLD_L)
	head.add_child(coins_label)
	root.add_child(head)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	sc.add_child(list)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	var b := Art.button("МЕНЮ", "btn", "home")
	b.custom_minimum_size = Vector2(110, 40)
	b.pressed.connect(func(): back.emit())
	foot.add_child(b)
	var p := Art.button("ЗМІНА %d" % Save.shift(), "btn_gold", "play")
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.y = 40
	p.pressed.connect(func(): play.emit())
	foot.add_child(p)
	root.add_child(foot)
	_refresh()
	Sfx.music("menu")


func _refresh() -> void:
	coins_label.text = str(Save.coins())
	for c in list.get_children():
		c.queue_free()
	for id in Defs.UPGRADE_ORDER:
		list.add_child(_card(id))
	var t := Art.title_label("ОЗДОБЛЕННЯ КАБІНИ", 8, Art.CYAN)
	list.add_child(t)
	for id in Defs.SKIN_ORDER:
		list.add_child(_skin_card(id))


func _card(id: String) -> Control:
	var u: Dictionary = Defs.UPGRADES[id]
	var lvl := Save.level(id)
	var mx := Defs.upgrade_max(id)
	var cost := Defs.upgrade_cost(id, lvl)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Art.style("panel_light", 8))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	var ic := TextureRect.new()
	ic.texture = Art.icon_texture(Art.UPGRADE_ICONS.get(id, "gear"))
	ic.custom_minimum_size = Vector2(32, 32)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 1)
	var top := HBoxContainer.new()
	top.add_child(Art.title_label(String(u["name"]).to_upper(), 8, Art.GOLD))
	var pips := Label.new()
	pips.text = "  " + "■".repeat(lvl) + "□".repeat(mx - lvl)
	pips.add_theme_font_size_override("font_size", 8)
	pips.add_theme_font_override("font", Art.title())
	pips.add_theme_color_override("font_color", Art.CYAN)
	top.add_child(pips)
	vb.add_child(top)
	var fmt := String(u["fmt"])
	var now := fmt % Defs.upgrade_value(id, lvl)
	var line := String(u["desc"]) + ": " + now
	if lvl < mx:
		line += " → " + fmt % Defs.upgrade_value(id, lvl + 1)
	var d := Art.label(line, 16, Color("d8d0f0"))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	hb.add_child(vb)
	var b: Button
	if lvl >= mx:
		b = Art.button("МАКС", "btn_grey")
		b.disabled = true
	else:
		var can := Save.coins() >= cost
		b = Art.button(str(cost), "btn_green" if can else "btn_grey", "coin")
		b.disabled = not can
		b.pressed.connect(func(): _buy(id))
	b.custom_minimum_size = Vector2(84, 36)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(b)
	return pc


func _skin_card(id: String) -> Control:
	var d: Dictionary = Defs.SKINS[id]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Art.style("panel_light", 8))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	var pv := Control.new()
	pv.custom_minimum_size = Vector2(66, 35)
	var suffix := "" if id == "classic" else "_" + id
	for part in ["cabin_back", "cabin_front"]:
		var tr := TextureRect.new()
		tr.texture = Art.tex(part + suffix)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(66, 35)
		pv.add_child(tr)
	hb.add_child(pv)
	var name := Art.title_label(String(d["name"]).to_upper(), 8, Art.GOLD)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(name)
	var b: Button
	var locked := Defs.floors_for_shift(Save.shift()) < int(d["floors"])
	if Save.skin() == id:
		b = Art.button("ОБРАНО", "btn_grey", "check")
		b.disabled = true
	elif Save.owns_skin(id):
		b = Art.button("ОБРАТИ", "btn")
		b.pressed.connect(func():
			Save.wear_skin(id)
			Sfx.play("buy")
			_refresh())
	elif locked:
		b = Art.button("13-Й ПОВ.", "btn_grey", "lock")
		b.disabled = true
	else:
		var cost := int(d["cost"])
		var can := Save.coins() >= cost
		b = Art.button(str(cost), "btn_green" if can else "btn_grey", "coin")
		b.disabled = not can
		b.pressed.connect(func():
			if Save.buy_skin(id):
				Sfx.play("upgrade")
				Sfx.vibe(30)
				for a in Save.check_achievements():
					get_tree().call_group("app", "toast", "ДОСЯГНЕННЯ: " + String(a[1]).to_upper(), "+%d монет" % int(a[5]))
				_refresh())
	b.custom_minimum_size = Vector2(96, 34)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(b)
	return pc


func _buy(id: String) -> void:
	if Save.buy(id):
		Sfx.play("upgrade")
		Sfx.vibe(30)
		_refresh()


func on_back() -> void:
	back.emit()
