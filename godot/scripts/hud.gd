extends CanvasLayer
## Mission interface: goal ribbon with direction and have/need, dialogue with portraits, one hint strip,
## health, journal (what changed in the world and why), touch controls, the mission-complete card.

signal restart_requested

var font: FontFile
var goal_title: Label
var goal_text: Label
var goal_dir: Label
var goal_needs: Label
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_face: TextureRect
var hint: Label
var act_label: Label
var hp_bar: ColorRect
var hp_back: ColorRect
var journal: PanelContainer
var journal_list: Label
var journal_scroll: ScrollContainer
var end_card: PanelContainer
var end_text: Label
var lines: Array = []
var line_t := 0.0
var hint_t := 0.0
var goal_panel: PanelContainer

const FACES := {"nazar": "", "einstein": "res://assets/portrait-einstein.webp", "sava": "", "mira": "res://assets/portrait-mira.webp"}
const NAMES := {"nazar": "НАЗАР", "einstein": "ЕЙНШТЕЙН", "sava": "САВА", "mira": "МІРА"}

func _ready() -> void:
	font = load("res://assets/PixelifySans.ttf")
	_build()
	get_viewport().size_changed.connect(layout)
	layout()

func _style(border := Color("#3b4a52")) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.125, 0.92)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5)
	return sb

func _label(size := 10, color := Color("#e7eef0")) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build() -> void:
	# Health: a thin bar under a heart.
	hp_back = ColorRect.new()
	hp_back.color = Color(0.08, 0.06, 0.06, 0.9)
	hp_back.size = Vector2(74, 8)
	add_child(hp_back)
	hp_bar = ColorRect.new()
	hp_bar.color = Color("#d8463a")
	hp_bar.size = Vector2(72, 6)
	add_child(hp_bar)
	var heart := _label(12, Color("#d8463a"))
	heart.name = "Heart"
	heart.text = "♥"
	add_child(heart)
	# Goal ribbon.
	goal_panel = PanelContainer.new()
	goal_panel.add_theme_stylebox_override("panel", _style(Color("#6b5a2a")))
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 1)
	var top := HBoxContainer.new()
	goal_title = _label(11, Color("#f2c14e"))
	goal_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	goal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_dir = _label(9, Color("#c9d6dc"))
	top.add_child(goal_title)
	top.add_child(goal_dir)
	goal_text = _label(9, Color("#cbd6db"))
	goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_needs = _label(9, Color("#6ad04a"))
	gv.add_child(top)
	gv.add_child(goal_text)
	gv.add_child(goal_needs)
	goal_panel.add_child(gv)
	add_child(goal_panel)
	# Journal button and panel.
	var jb := Button.new()
	jb.name = "JournalBtn"
	jb.text = "Журнал"
	jb.add_theme_font_override("font", font)
	jb.add_theme_font_size_override("font_size", 9)
	jb.focus_mode = Control.FOCUS_NONE
	jb.pressed.connect(func(): journal.visible = not journal.visible)
	add_child(jb)
	journal = PanelContainer.new()
	journal.visible = false
	journal.add_theme_stylebox_override("panel", _style(Color("#f2c14e")))
	var jv := VBoxContainer.new()
	var jt := _label(11, Color("#f2c14e"))
	jt.text = "ЖУРНАЛ · що змінилося"
	journal_list = _label(9)
	journal_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var restart := Button.new()
	restart.text = "Почати місію заново"
	restart.add_theme_font_override("font", font)
	restart.add_theme_font_size_override("font_size", 9)
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(func(): restart_requested.emit())
	jv.add_child(jt)
	journal_scroll = ScrollContainer.new()
	journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_scroll.add_child(journal_list)
	jv.add_child(journal_scroll)
	jv.add_child(restart)
	journal.add_child(jv)
	add_child(journal)
	# Dialogue.
	dlg = PanelContainer.new()
	dlg.visible = false
	dlg.add_theme_stylebox_override("panel", _style(Color("#6b5a2a")))
	var dh := HBoxContainer.new()
	dlg_face = TextureRect.new()
	dlg_face.custom_minimum_size = Vector2(26, 28)
	dlg_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlg_name = _label(9, Color("#f2c14e"))
	dlg_text = _label(10)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(dlg_name)
	dv.add_child(dlg_text)
	dh.add_child(dlg_face)
	dh.add_child(dv)
	dlg.add_child(dh)
	dlg.gui_input.connect(func(e): if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed: next_line())
	add_child(dlg)
	# One hint strip.
	hint = _label(10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hs := _style()
	hs.set_content_margin_all(3)
	hint.add_theme_stylebox_override("normal", hs)
	add_child(hint)
	# Touch controls (multi-touch: walk and jump at once).
	for spec in [["BtnLeft", "btn_left", "move_left"], ["BtnRight", "btn_right", "move_right"], ["BtnJump", "btn_jump", "jump"], ["BtnAct", "btn_action", "act"]]:
		var b := TouchScreenButton.new()
		b.name = spec[0]
		b.texture_normal = load("res://ui/%s.png" % spec[1])
		b.action = spec[2]
		b.passby_press = spec[2].begins_with("move")
		add_child(b)
	act_label = _label(8, Color("#f2c14e"))
	act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	act_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(act_label)
	# Mission-complete card.
	end_card = PanelContainer.new()
	end_card.visible = false
	end_card.add_theme_stylebox_override("panel", _style(Color("#f2c14e")))
	end_text = _label(10)
	end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_card.add_child(end_text)
	add_child(end_card)

func layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	hp_back.position = Vector2(20, 9)
	hp_bar.position = Vector2(21, 10)
	get_node("Heart").position = Vector2(6, 3)
	var jb: Button = get_node("JournalBtn")
	jb.position = Vector2(100, 4)
	jb.size = Vector2(54, 18)
	goal_panel.size = Vector2(minf(230.0, vs.x * 0.42), 0)
	goal_panel.position = Vector2(vs.x - goal_panel.size.x - 6, 6)
	dlg.size = Vector2(minf(250.0, vs.x - goal_panel.size.x - 24), 0)
	dlg.position = Vector2(6, 28)
	journal.size = Vector2(minf(300.0, vs.x - 20), 0)
	journal.position = Vector2(6, 28)
	end_card.size = Vector2(minf(340.0, vs.x - 20), 0)
	end_text.custom_minimum_size = Vector2(end_card.size.x - 12, 0)
	journal_list.custom_minimum_size = Vector2(journal.size.x - 22, 0)
	journal_scroll.custom_minimum_size = Vector2(journal.size.x - 12, maxf(60.0, vs.y - 140.0))
	dlg_text.custom_minimum_size = Vector2(dlg.size.x - 50, 0)
	goal_text.custom_minimum_size = Vector2(goal_panel.size.x - 12, 0)
	end_card.reset_size()
	end_card.position = Vector2((vs.x - end_card.size.x) / 2.0, maxf(6.0, (vs.y - end_card.size.y) / 2.0 - 20.0))
	var s := 0.46
	var l: TouchScreenButton = get_node("BtnLeft")
	var r: TouchScreenButton = get_node("BtnRight")
	var j: TouchScreenButton = get_node("BtnJump")
	var a: TouchScreenButton = get_node("BtnAct")
	for b in [l, r, j, a]:
		b.scale = Vector2(s, s)
	l.position = Vector2(8, vs.y - 96 * s - 8)
	r.position = Vector2(8 + 96 * s + 6, vs.y - 96 * s - 8)
	a.position = Vector2(vs.x - 120 * s - 8, vs.y - 120 * s - 8)
	j.position = Vector2(vs.x - 120 * s - 8 - 96 * s - 6, vs.y - 96 * s - 8)
	act_label.position = a.position + Vector2(3, 3)
	act_label.size = Vector2(120 * s - 6, 120 * s - 6)

func set_goal(title: String, text: String, needs: String, dir_text: String) -> void:
	goal_title.text = title
	goal_text.text = text
	goal_needs.text = needs
	goal_needs.visible = needs != ""
	goal_dir.text = dir_text

func set_hp(v: int) -> void:
	hp_bar.size.x = 72.0 * v / 100.0

func set_action(text: String) -> void:
	act_label.text = text

func show_hint(text: String, secs := 2.6) -> void:
	hint.text = text
	hint_t = secs

func set_target_hint(text: String) -> void:
	if hint_t <= 0.0:
		hint.text = text

func say(new_lines: Array) -> void:
	lines = new_lines.duplicate()
	_show_line()

func _show_line() -> void:
	if lines.is_empty():
		dlg.visible = false
		return
	var l: Array = lines[0]
	dlg.visible = not journal.visible
	dlg_name.text = NAMES.get(l[0], l[0])
	dlg_text.text = l[1]
	var face: String = FACES.get(l[0], "")
	dlg_face.visible = face != ""
	if face != "":
		dlg_face.texture = load(face)
	line_t = clampf(1.6 + l[1].length() * 0.04, 2.6, 6.0)

func next_line() -> void:
	if not lines.is_empty():
		lines.pop_front()
	_show_line()

func refresh_journal() -> void:
	var out := ""
	for j in Game.journal:
		out += "• " + j + "\n"
	journal_list.text = out if out != "" else "Поки що нічого."

func show_end(text: String) -> void:
	end_text.text = text
	end_card.visible = true
	lines.clear()
	dlg.visible = false
	journal.visible = false
	layout()

func _process(delta: float) -> void:
	hint_t = maxf(0.0, hint_t - delta)
	hint.visible = hint.text != "" and not journal.visible and not end_card.visible
	var vs := get_viewport().get_visible_rect().size
	hint.reset_size()
	hint.position = Vector2((vs.x - hint.size.x) / 2.0, vs.y - 52)
	if not lines.is_empty():
		line_t -= delta
		if line_t <= 0.0:
			next_line()
	if journal.visible:
		refresh_journal()
		dlg.visible = false
