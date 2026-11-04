extends Control
## Main menu: shift modes, story, office, collection, letters, settings.

var bit_bubble: Label
var bit_sprite: TextureRect
var _bit_frames: Array
var _t := 0.0
var _quip_t := 4.0


func _ready() -> void:
	Audio.music("radio" if Upgrades.level_of(Game.profile, "radio") > 0 and Game.rng.randf() < 0.5 else "menu")
	Audio.hum(false)
	var bd := Backdrop.new("menu")
	add_child(bd)
	var m := UI.safe_margins(self)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28 + int(m["left"]))
	root.add_theme_constant_override("margin_right", 28 + int(m["right"]))
	root.add_theme_constant_override("margin_top", 70 + int(m["top"]))
	root.add_theme_constant_override("margin_bottom", 28 + int(m["bottom"]))
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)
	col.add_child(_top_bar())
	# Title
	var title := UI.outlined(UI.label(I18n.t("title"), 96, UI.AMBER, HORIZONTAL_ALIGNMENT_CENTER, true), 12)
	col.add_child(title)
	var sub := UI.outlined(UI.label(I18n.t("subtitle"), 34, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER), 8)
	col.add_child(sub)
	col.add_child(UI.expand_spacer())
	# BIT with a speech bubble
	if (Game.profile["story"]["met"] as Array).has("bit"):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var state := "idle" if Upgrades.level_of(Game.profile, "robot") > 0 else "broken"
		_bit_frames = UI.frames("bit_" + state, 4)
		bit_sprite = UI.image("bit_idle", 3)
		bit_sprite.texture = _bit_frames[0]
		bit_sprite.custom_minimum_size = Vector2(36, 40) * 3
		row.add_child(bit_sprite)
		var bubble := UI.panel("ui_panel_paper")
		bit_bubble = UI.wrap(UI.label(_quip(), 26, UI.INK))
		bit_bubble.custom_minimum_size = Vector2(420, 0)
		bubble.add_child(bit_bubble)
		bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bubble)
		col.add_child(row)
	var p := Game.profile
	var chapter := Story.next_available(p)
	if chapter >= 0:
		var sb := UI.button("%s  %s" % [I18n.t("btn_story"), I18n.line(StoryData.CHAPTERS[chapter]["title"], 0)], "cyan", 96, "ic_story")
		sb.pressed.connect(func(): Game.goto("story", {"chapter": chapter}))
		col.add_child(sb)
		_pulse(sb)
	var start := UI.button("%s  ·  %s" % [I18n.t("btn_shift"), I18n.t("shift_n", int(p["shifts_done"]) + 1)], "accent", 120, "ic_play")
	start.add_theme_font_size_override("font_size", 38)
	start.pressed.connect(func(): Game.goto("shift", {"mode": "shift"}))
	col.add_child(start)
	var row2 := HBoxContainer.new()
	var calm := UI.button(I18n.t("btn_calm"), "normal", 96)
	calm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calm.pressed.connect(func(): Game.goto("shift", {"mode": "calm"}))
	row2.add_child(calm)
	var rec := UI.button("%s\n%s" % [I18n.t("btn_record"), I18n.t("record_best", int(p.get("record_best", 0)))], "normal", 96)
	rec.add_theme_font_size_override("font_size", 26)
	rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec.pressed.connect(func(): Game.goto("shift", {"mode": "record"}))
	row2.add_child(rec)
	col.add_child(row2)
	col.add_child(_daily_button())
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	for item in [["btn_office", "ic_home", "office"], ["btn_collection", "ic_book", "collection"],
			["btn_mail", "ic_mail", "letters"], ["btn_settings", "ic_gear", "settings"]]:
		var b := UI.button("", "normal", 104, item[1])
		b.tooltip_text = I18n.t(item[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = I18n.t(item[0])
		b.add_theme_font_size_override("font_size", 20)
		var target: String = item[2]
		b.pressed.connect(func(): Game.goto(target))
		if target == "letters" and Story.unread_letters(p) > 0:
			b.add_theme_color_override("font_color", UI.AMBER)
			b.text = "%s (%d)" % [I18n.t(item[0]), Story.unread_letters(p)]
		if target == "office" and _affordable() > 0:
			b.add_theme_color_override("font_color", UI.GREEN)
		row3.add_child(b)
	col.add_child(row3)


func _top_bar() -> Control:
	var p := Game.profile
	var bar := HBoxContainer.new()
	var lvl := VBoxContainer.new()
	lvl.add_theme_constant_override("separation", 4)
	lvl.add_child(UI.outlined(UI.label(I18n.t("level_n", int(p["level"])), 28, UI.PAPER, 0, true), 6))
	var xpbar := ProgressBar.new()
	xpbar.show_percentage = false
	xpbar.custom_minimum_size = Vector2(200, 16)
	xpbar.max_value = Progression.xp_for_next(int(p["level"]))
	xpbar.value = int(p["xp"])
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = UI.INK
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = UI.AMBER
	xpbar.add_theme_stylebox_override("background", bgs)
	xpbar.add_theme_stylebox_override("fill", fgs)
	lvl.add_child(xpbar)
	bar.add_child(lvl)
	bar.add_child(UI.expand_spacer())
	var coins := UI.icon_value("ic_coin", UI.fmt(int(p["coins"])), 32, UI.GOLD)
	UI.outlined(coins.get_node("Value"), 6)
	bar.add_child(coins)
	var shards := UI.icon_value("ic_shard", str(int(p["shards"])), 32, UI.CYAN)
	UI.outlined(shards.get_node("Value"), 6)
	bar.add_child(shards)
	return bar


func _daily_button() -> Button:
	var p := Game.profile
	var lv := int(Progression.UNLOCKS["daily"])
	var b: Button
	if int(p["level"]) < lv:
		b = UI.button("%s — %s" % [I18n.t("btn_daily"), I18n.t("locked_level", lv)], "normal", 84, "ic_lock")
		b.disabled = true
		b.add_theme_font_size_override("font_size", 26)
		return b
	var daily: Dictionary = p.get("daily", {})
	var claimed: bool = daily.get("day", "") == Game.today_key() and daily.get("claimed", false)
	var info := I18n.t("daily_done", int(daily.get("best", 0))) if claimed else I18n.t("daily_new")
	b = UI.button("%s\n%s" % [I18n.t("btn_daily"), info], "normal", 96, "ic_calendar")
	b.add_theme_font_size_override("font_size", 26)
	if not claimed:
		b.add_theme_color_override("font_color", UI.CYAN)
	b.pressed.connect(func(): Game.goto("shift", {"mode": "daily"}))
	return b


func _affordable() -> int:
	var n := 0
	for id in Upgrades.DEFS:
		if Upgrades.can_buy(Game.profile, id) == "ok":
			n += 1
	return n


func _pulse(c: Control) -> void:
	c.pivot_offset = Vector2(310, 48)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "modulate", Color(1.15, 1.15, 1.15), 0.6)
	tw.tween_property(c, "modulate", Color.WHITE, 0.6)


func _quip() -> String:
	if Upgrades.level_of(Game.profile, "robot") == 0:
		return I18n.pick({"uk": "...пііп... (БІТ чекає на ремонт у «Відділенні»)", "en": "...beep... (BIT is waiting for repairs in the Office)"})
	return I18n.bit_line("idle", Game.rng)


func _process(delta: float) -> void:
	_t += delta
	if bit_sprite and not _bit_frames.is_empty():
		bit_sprite.texture = _bit_frames[int(_t * 3.0) % 4]
	_quip_t -= delta
	if _quip_t <= 0.0 and bit_bubble:
		_quip_t = 7.0
		bit_bubble.text = _quip()


func on_back() -> void:
	Game.save_now()
	get_tree().quit()
