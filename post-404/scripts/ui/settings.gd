extends Control
## Settings: language, audio, controls, accessibility, progress.

var list: VBoxContainer
var confirm: PanelContainer


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var col := UI.screen_frame(self, I18n.t("set_title"), false)
	list = UI.scroll_column(col)
	# language
	var lang_row := HBoxContainer.new()
	var ll := UI.label(I18n.t("set_lang"), 30)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(ll)
	for code in I18n.LANGS:
		var b := UI.button(I18n.STRINGS["lang_name"][code], "accent" if I18n.lang == code else "normal", 80)
		b.add_theme_font_size_override("font_size", 26)
		var cc: String = code
		b.pressed.connect(func():
			Game.set_setting("lang", cc)
			_build())
		lang_row.add_child(b)
	list.add_child(_wrap_card(lang_row))
	list.add_child(_slider("set_music", "music"))
	list.add_child(_slider("set_sfx", "sfx"))
	list.add_child(_toggle("set_haptics", "haptics"))
	list.add_child(_toggle("set_buttons", "buttons"))
	list.add_child(_toggle("set_hints", "swipe_hints"))
	list.add_child(_toggle("set_motion", "reduce_motion"))
	# frame rate
	var fps_row := HBoxContainer.new()
	var fl := UI.label(I18n.t("set_fps"), 30)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_row.add_child(fl)
	for f in [30, 60]:
		var b := UI.button(str(f), "accent" if int(Game.setting("fps")) == f else "normal", 80)
		b.custom_minimum_size.x = 110
		var ff: int = f
		b.pressed.connect(func():
			Game.set_setting("fps", ff)
			_build())
		fps_row.add_child(b)
	list.add_child(_wrap_card(fps_row))
	var tut := UI.button(I18n.t("set_replay_tut"), "normal", 88)
	tut.pressed.connect(func(): Game.goto("shift", {"mode": "tutorial"}))
	list.add_child(tut)
	var reset := UI.button(I18n.t("set_reset"), "normal", 88)
	reset.add_theme_color_override("font_color", UI.RED)
	reset.pressed.connect(_ask_reset)
	list.add_child(reset)
	var credits := UI.wrap(UI.label(I18n.pick({
		"uk": "Time Post v%s · Godot 4.7 · Шрифт Pixelify Sans (SIL OFL 1.1). Уся графіка, звук і музика створені для цієї гри.",
		"en": "Time Post v%s · Godot 4.7 · Font Pixelify Sans (SIL OFL 1.1). All art, sound and music were made for this game."}) % ProjectSettings.get_setting("application/config/version"), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	list.add_child(credits)


func _wrap_card(c: Control) -> PanelContainer:
	var p := UI.panel("ui_panel")
	p.add_child(c)
	return p


func _slider(key: String, setting: String) -> Control:
	var v := VBoxContainer.new()
	v.add_child(UI.label(I18n.t(key), 30))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.setting(setting))
	s.custom_minimum_size = Vector2(0, 56)
	s.value_changed.connect(func(val):
		Game.set_setting(setting, val)
		Audio.play("blip"))
	v.add_child(s)
	return _wrap_card(v)


func _toggle(key: String, setting: String) -> Control:
	var h := HBoxContainer.new()
	var l := UI.wrap(UI.label(I18n.t(key), 30))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var on: bool = Game.setting(setting)
	var b := UI.button(I18n.t("on" if on else "off"), "accent" if on else "normal", 80)
	b.custom_minimum_size.x = 150
	b.pressed.connect(func():
		Game.set_setting(setting, not Game.setting(setting))
		_build())
	h.add_child(b)
	return _wrap_card(h)


func _ask_reset() -> void:
	confirm = UI.panel("ui_panel")
	var v := VBoxContainer.new()
	confirm.add_child(v)
	var t := UI.wrap(UI.label(I18n.t("set_reset_confirm"), 30, UI.PAPER, HORIZONTAL_ALIGNMENT_CENTER))
	t.custom_minimum_size = Vector2(560, 0)
	v.add_child(t)
	var h := HBoxContainer.new()
	var yes := UI.button(I18n.t("btn_yes"), "normal", 88)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.add_theme_color_override("font_color", UI.RED)
	yes.pressed.connect(func():
		Game.reset_progress()
		Game.goto("story", {"chapter": 0, "then": "tutorial"}))
	h.add_child(yes)
	var no := UI.button(I18n.t("btn_no"), "accent", 88)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(func():
		confirm.queue_free()
		confirm = null)
	h.add_child(no)
	v.add_child(h)
	add_child(confirm)
	confirm.reset_size()
	confirm.position = (get_viewport_rect().size - confirm.size) / 2
	UI.pop(confirm)


func on_back() -> void:
	if confirm:
		confirm.queue_free()
		confirm = null
		return
	Game.save_now()
	Game.goto("menu")
