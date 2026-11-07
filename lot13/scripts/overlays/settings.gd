extends Control
## Settings: language, sound, music, vibration, tutorial replay, progress reset.

var main
var args: Dictionary = {}
var holder: CenterContainer
var panel: PanelContainer
var _first := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UI.full(UI.color_rect(Color(0.04, 0.03, 0.07, 0.75))))
	holder = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(holder))
	L.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if panel != null:
		panel.queue_free()
	panel = UI.panel("panel", 14)
	panel.custom_minimum_size = Vector2(316, 0)
	holder.add_child(panel)
	var v := UI.vbox(8)
	panel.add_child(v)
	var top := UI.hbox(6)
	top.add_child(UI.icon("gear", 1))
	var tl := UI.label(L.t("set.title"), 20, UI.C_GOLD)
	UI.fill(tl)
	top.add_child(tl)
	var x := UI.icon_button("close", "", "dark", 12, Vector2(40, 36), true, 1)
	x.pressed.connect(_close)
	top.add_child(x)
	v.add_child(top)

	v.add_child(UI.label(L.t("set.lang"), 13, UI.C_DIM))
	var lrow := UI.hbox(8)
	for code in ["uk", "en"]:
		var b := UI.button(L.t("lang." + code), "purple" if L.lang == code else "dark", 15, 48)
		UI.fill(b)
		b.pressed.connect(_set_lang.bind(code))
		lrow.add_child(b)
	v.add_child(lrow)

	v.add_child(_toggle("sound", "sound"))
	v.add_child(_toggle("music", "music"))
	v.add_child(_toggle("vibrate", "phone"))

	var tut := UI.icon_button("book", L.t("set.tutorial"), "blue", 14, Vector2(0, 48), false, 1)
	tut.pressed.connect(_tutorial)
	v.add_child(tut)
	var reset := UI.button(L.t("set.reset"), "red", 14, 44)
	reset.pressed.connect(_ask_reset)
	v.add_child(reset)
	v.add_child(UI.label(L.t("set.about"), 11, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	if _first:
		_first = false
		UI.pop(panel, 0.75, 0.22)


func _toggle(key: String, icon_name: String) -> Control:
	var on := bool(Game.settings.get(key, true))
	var b := UI.icon_button(icon_name, L.t("set." + key) + ": " + (L.t("set.on") if on else L.t("set.off")),
		"green" if on else "dark", 15, Vector2(0, 48), false, 1)
	b.pressed.connect(_flip.bind(key))
	return b


func _flip(key: String) -> void:
	Game.settings[key] = not bool(Game.settings.get(key, true))
	Game.request_save()
	if key == "music":
		Sfx.refresh()
	Sfx.click()
	if key == "vibrate":
		Game.buzz(40)
	refresh()


func _set_lang(code: String) -> void:
	Sfx.click()
	Game.settings["lang"] = code
	Game.request_save()
	L.set_lang(code)


func _tutorial() -> void:
	Sfx.click()
	main.close_overlay(self)
	main.call("_tutorial_step", 0)


func _ask_reset() -> void:
	Sfx.click()
	main.popup(L.t("set.reset_title"), L.t("set.reset_text"), [[L.t("set.reset_yes"), "red", _do_reset], [L.t("cancel"), "dark", null]])


func _do_reset() -> void:
	Game.new_game()
	main.close_overlay(self)
	main.show_screen("garage")
	main.call("_tutorial_step", 0)


func _close() -> void:
	main.close_overlay(self)
