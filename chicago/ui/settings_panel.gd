class_name SettingsPanel
extends PanelContainer
## Settings screen (from the main menu and the pause menu): interface scale, aim assist, touch controls, keys.
## To remap: press an action's button, then the new key (Esc cancels).

signal closed
signal changed

var _waiting := ""
var _rows := {}
var scale_label: Label
var aim_btn: Button
var touch_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.97)
	sb.border_color = Color("#b8893f")
	sb.set_border_width_all(2)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := Label.new()
	title.text = "UI_SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#e7c27a"))
	v.add_child(title)
	var sr := _row(v, "UI_UI_SCALE")
	var minus := _btn(sr, "−", 56)
	scale_label = Label.new()
	scale_label.custom_minimum_size = Vector2(70, 0)
	scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sr.add_child(scale_label)
	var plus := _btn(sr, "+", 56)
	minus.pressed.connect(_step_scale.bind(-1))
	plus.pressed.connect(_step_scale.bind(1))
	aim_btn = _btn(_row(v, "UI_AIM_ASSIST"), "", 160)
	aim_btn.pressed.connect(func():
		Settings.aim_assist = not Settings.aim_assist
		_commit())
	touch_btn = _btn(_row(v, "UI_TOUCH_CONTROLS"), "", 160)
	touch_btn.pressed.connect(func():
		Settings.touch_mode = {"auto": "on", "on": "off", "off": "auto"}[Settings.touch_mode]
		_commit())
	var kt := Label.new()
	kt.text = "UI_KEYS"
	kt.add_theme_color_override("font_color", Color("#e7c27a"))
	v.add_child(kt)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	v.add_child(grid)
	for a in Settings.REMAPPABLE:
		var l := Label.new()
		l.text = "ACTION_" + a.to_upper()
		l.custom_minimum_size = Vector2(240, 0)
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 40)
		b.pressed.connect(_listen.bind(a))
		grid.add_child(b)
		_rows[a] = b
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	v.add_child(bottom)
	_btn(bottom, "UI_RESET_KEYS", 220).pressed.connect(func():
		Settings.reset_keys()
		_refresh())
	_btn(bottom, "UI_BACK", 160).pressed.connect(func():
		_waiting = ""
		closed.emit())
	_refresh()

func _row(parent: Node, key: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = key
	l.custom_minimum_size = Vector2(260, 0)
	h.add_child(l)
	parent.add_child(h)
	return h

func _btn(parent: Node, text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 48)
	parent.add_child(b)
	return b

func _step_scale(d: int) -> void:
	var i: int = Settings.UI_SCALES.find(Settings.ui_scale)
	if i < 0:
		i = Settings.UI_SCALES.find(1.0)
	Settings.ui_scale = Settings.UI_SCALES[clampi(i + d, 0, Settings.UI_SCALES.size() - 1)]
	_commit()

func _commit() -> void:
	Settings.save()
	_refresh()
	changed.emit()

func _refresh() -> void:
	scale_label.text = "%d%%" % roundi(Settings.ui_scale * 100.0)
	aim_btn.text = tr("UI_ON") if Settings.aim_assist else tr("UI_OFF")
	touch_btn.text = tr({"auto": "UI_AUTO", "on": "UI_ON", "off": "UI_OFF"}[Settings.touch_mode])
	for a in _rows:
		_rows[a].text = tr("UI_PRESS_KEY") if a == _waiting else Settings.key_name(a)

func _listen(action: String) -> void:
	_waiting = action
	_refresh()

func _input(e: InputEvent) -> void:
	if _waiting == "" or not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var code: int = e.physical_keycode
		if code != KEY_ESCAPE or _waiting == "pause":
			Settings.rebind(_waiting, code)
		_waiting = ""
		_refresh()
		get_viewport().set_input_as_handled()
