extends Control
## Story scene player: portraits, typewriter text, choices.

var chapter_idx := 0
var then_screen := "menu"
var replay := false
var lines: Array = []
var pos := 0
var portrait: TextureRect
var name_label: Label
var text_label: Label
var choice_box: VBoxContainer
var title_label: Label
var tap_hint: Label
var _typing := 0.0
var _full_len := 0
var _waiting_choice := false
var _finished := false


func setup(data: Dictionary) -> void:
	chapter_idx = int(data.get("chapter", 0))
	then_screen = data.get("then", "menu")
	replay = data.get("replay", false)


func _ready() -> void:
	Audio.music("menu")
	var c: Dictionary = StoryData.CHAPTERS[chapter_idx]
	lines = (c["lines"] as Array).duplicate()
	var bd := Backdrop.new("menu")
	add_child(bd)
	var dim := ColorRect.new()
	dim.color = Color(UI.INK, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var m := UI.safe_margins(self)
	var vp := get_viewport_rect().size
	title_label = UI.wrap(UI.outlined(UI.label(I18n.line(c["title"], 0), 40, UI.AMBER, HORIZONTAL_ALIGNMENT_CENTER, true), 8))
	title_label.position = Vector2(20, 40 + float(m["top"]))
	title_label.size = Vector2(vp.x - 40, 100)
	add_child(title_label)
	var skip := UI.button(I18n.t("btn_skip"), "normal", 64)
	skip.position = Vector2(vp.x - 210, vp.y - 90 - float(m["bottom"]))
	skip.size = Vector2(190, 64)
	skip.add_theme_font_size_override("font_size", 24)
	skip.pressed.connect(_skip_all)
	add_child(skip)
	portrait = UI.image("pt_bit", 7)
	portrait.size = Vector2(44, 44) * 7
	portrait.position = Vector2((vp.x - portrait.size.x) / 2, vp.y * 0.22)
	add_child(portrait)
	var box := UI.panel("ui_panel_paper")
	box.position = Vector2(20, vp.y * 0.22 + portrait.size.y + 10)
	box.custom_minimum_size = Vector2(vp.x - 40, 300)
	box.size = box.custom_minimum_size
	add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	name_label = UI.label("", 32, Color("6b4430"), 0, true)
	v.add_child(name_label)
	text_label = UI.wrap(UI.label("", 32, UI.INK))
	text_label.custom_minimum_size = Vector2(vp.x - 100, 180)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(text_label)
	tap_hint = UI.label("▼", 24, Color("6b4430"), HORIZONTAL_ALIGNMENT_RIGHT)
	tap_hint.text = "..."
	v.add_child(tap_hint)
	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(20, box.position.y + 320)
	choice_box.size = Vector2(vp.x - 40, 300)
	add_child(choice_box)
	_show_line()


func _speaker_of(line) -> String:
	return line[0] if line is Array else ""


func _show_line() -> void:
	for ch in choice_box.get_children():
		ch.queue_free()
	if pos >= lines.size():
		_finish()
		return
	var line = lines[pos]
	if line is Dictionary:
		_show_choice(line)
		return
	var speaker: String = line[0]
	if speaker == "":
		name_label.text = ""
		portrait.visible = false
		text_label.add_theme_color_override("font_color", Color("4a2f27"))
	else:
		name_label.text = I18n.pick(Content.CHARACTERS[speaker])
		name_label.add_theme_color_override("font_color", Content.CHARACTERS[speaker]["color"].darkened(0.55))
		portrait.texture = UI.tex("pt_" + speaker)
		portrait.visible = true
		text_label.add_theme_color_override("font_color", UI.INK)
		UI.pop(portrait, 0.95)
	text_label.text = I18n.line(line)
	text_label.visible_characters = 0
	_full_len = text_label.get_total_character_count()
	_typing = 0.0
	tap_hint.visible = false


func _show_choice(line: Dictionary) -> void:
	_waiting_choice = true
	tap_hint.visible = false
	for o in line["choice"]:
		var opt: Dictionary = o
		var ok := Story.option_available(Game.profile, opt) or replay
		var b := UI.button(I18n.pick(opt), "accent" if ok else "normal", 96)
		b.add_theme_font_size_override("font_size", 28)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not ok:
			b.disabled = true
			b.text += "\n(" + I18n.t("option_locked") + ")"
			b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): _choose(opt))
		choice_box.add_child(b)
		UI.pop(b)


func _choose(opt: Dictionary) -> void:
	_waiting_choice = false
	if not replay:
		Story.apply_choice(Game.profile, opt)
		Game.mark_dirty()
	var follow: Array = opt.get("then", [])
	pos += 1
	for i in follow.size():
		lines.insert(pos + i, follow[i])
	_show_line()


func _process(delta: float) -> void:
	if text_label.visible_characters < _full_len and _full_len > 0:
		_typing += delta * 55.0
		var n := int(_typing)
		if n != text_label.visible_characters:
			text_label.visible_characters = min(n, _full_len)
			if n % 3 == 0:
				Audio.play("blip", 1.0 + (n % 5) * 0.04, -8.0)
		if text_label.visible_characters >= _full_len:
			tap_hint.visible = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()


func _advance() -> void:
	if _waiting_choice or _finished:
		return
	if text_label.visible_characters < _full_len:
		text_label.visible_characters = _full_len
		tap_hint.visible = true
		return
	pos += 1
	_show_line()


func _skip_all() -> void:
	# Skipping still stops at choices: decisions are never made for the player.
	while pos < lines.size() and lines[pos] is Array:
		pos += 1
	_show_line()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if not replay:
		var reward := Story.complete(Game.profile, chapter_idx)
		Game.save_now()
		if int(reward.get("coins", 0)) > 0:
			Game.notice.emit("+%s %s" % [UI.fmt(int(reward["coins"])), I18n.t("res_coins").to_lower()])
		if int(reward.get("shards", 0)) > 0:
			Game.notice.emit("+%d %s" % [int(reward["shards"]), I18n.t("res_shards").to_lower()])
		if reward.has("item"):
			Game.notice.emit(I18n.t("fb_found", I18n.pick(Content.COLLECTIBLES[reward["item"]]["name"])))
		if Story.unread_letters(Game.profile) > 0:
			Game.notice.emit(I18n.t("new_letter"))
	if then_screen == "tutorial":
		Game.goto("shift", {"mode": "tutorial"})
	else:
		Game.goto(then_screen)


func on_back() -> void:
	_skip_all()
