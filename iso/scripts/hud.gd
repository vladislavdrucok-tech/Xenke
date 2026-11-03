extends CanvasLayer
## Interface of the isometric yard (landscape): Mira's portrait with hearts top-left, resources top-right, the task
## under the portrait, a floating joystick (left half), the hand button bottom-right with the action's name, short
## hints over objects, a dialogue panel only while someone talks, small panels for the workbench and the storage.
## A touch that begins on a button or a panel never moves the hero; opening or closing a panel releases the stick.

signal act_pressed

var world
var font: Font
var root: Control
var overlay: Control
var blockers: Array[Control] = []
var modal: Control
var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_vec := Vector2.ZERO
const JOY_R := 46.0
var quest_title: Label
var quest_text: Label
var quest: PanelContainer
var res_box: HBoxContainer
var res_items := {}
var act_btn: Button
var act_label: Label
var dlg: PanelContainer
var dlg_face: TextureRect
var dlg_name: Label
var dlg_text: Label
var dlg_hint: Label
var lines: Array = []
var on_dialog_end: Callable
var panel: PanelContainer
var panel_box: VBoxContainer
var toast: Label
var toast_t := 0.0
var fade: ColorRect

const GOLD := Color("#f2c14e")
const INK := Color(0.08, 0.07, 0.06, 0.88)
const ITEM_NAMES := {"wood": "Дерево", "scrap": "Брухт", "water": "Вода", "kit": "Ремкомплект", "seeds": "Насіння", "cabbage": "Капуста"}
const FACES := {"mira": "res://assets/yard/face_mira.png", "einstein": "res://assets/yard/face_einstein.png",
	"pavlo": "res://assets/yard/face_pavlo.png", "keeper": "res://assets/yard/face_keeper.png"}
const NAMES := {"mira": "МІРА", "einstein": "ЕЙНШТЕЙН", "pavlo": "ПАВЛО", "keeper": "КОМІРНИК ГНАТ"}

func _ready() -> void:
	font = load("res://assets/PixelifySans.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)
	_build()
	get_viewport().size_changed.connect(layout)
	layout()

func _frame(bg := INK, border := Color("#7a5a2e"), w := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(w)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	return s

func _label(size := 12, color := Color("#f1e6cf")) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, size := 13) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color("#f6e7c1"))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.45))
	b.add_theme_stylebox_override("normal", _frame(Color("#5a3d22"), GOLD.darkened(0.2)))
	b.add_theme_stylebox_override("hover", _frame(Color("#6a4828"), GOLD))
	b.add_theme_stylebox_override("pressed", _frame(Color("#3c2814"), GOLD))
	b.add_theme_stylebox_override("disabled", _frame(Color(0.18, 0.15, 0.12, 0.9), Color(0.35, 0.3, 0.25)))
	blockers.append(b)
	return b

func _build() -> void:
	# Portrait with hearts (top-left), like the concept.
	var pf := PanelContainer.new()
	pf.name = "Portrait"
	pf.add_theme_stylebox_override("panel", _frame(Color("#3a2614"), Color("#b98a3e"), 3))
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := TextureRect.new()
	face.texture = load(FACES.mira)
	face.custom_minimum_size = Vector2(44, 44)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pf.add_child(face)
	root.add_child(pf)
	# Task card.
	quest = PanelContainer.new()
	quest.add_theme_stylebox_override("panel", _frame(Color(0.08, 0.07, 0.06, 0.78), Color("#7a5a2e"), 1))
	quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 0)
	quest_title = _label(12, GOLD)
	quest_text = _label(10, Color("#e3d6bd"))
	quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qv.add_child(quest_title)
	qv.add_child(quest_text)
	quest.add_child(qv)
	root.add_child(quest)
	# Resources (top-right): framed counters with icons.
	res_box = HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 6)
	res_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(res_box)
	for k in ["wood", "scrap", "water", "kit", "seeds", "cabbage"]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _frame(Color(0.1, 0.08, 0.06, 0.85), Color("#8a6a3a"), 2))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(18, 18)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func(): icon(ic, k, Rect2(Vector2.ZERO, Vector2(18, 18))))
		var l := _label(13)
		h.add_child(ic)
		h.add_child(l)
		p.add_child(h)
		res_box.add_child(p)
		res_items[k] = {"panel": p, "label": l}
	# The hand button (bottom-right) and the name of the action over it.
	act_btn = Button.new()
	act_btn.focus_mode = Control.FOCUS_NONE
	var round := StyleBoxFlat.new()
	round.bg_color = Color(0.12, 0.1, 0.08, 0.85)
	round.border_color = Color("#e8dcc0")
	round.set_border_width_all(3)
	round.set_corner_radius_all(40)
	act_btn.add_theme_stylebox_override("normal", round)
	act_btn.add_theme_stylebox_override("hover", round)
	var pr := round.duplicate()
	pr.bg_color = Color(0.3, 0.24, 0.16, 0.95)
	act_btn.add_theme_stylebox_override("pressed", pr)
	var dis := round.duplicate()
	dis.border_color = Color(0.45, 0.42, 0.38)
	dis.bg_color = Color(0.1, 0.09, 0.08, 0.6)
	act_btn.add_theme_stylebox_override("disabled", dis)
	act_btn.pressed.connect(func(): act_pressed.emit())
	act_btn.draw.connect(func(): _draw_hand(act_btn))
	blockers.append(act_btn)
	root.add_child(act_btn)
	act_label = _label(12, GOLD)
	act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(act_label)
	# Dialogue: only while someone talks; a tap anywhere moves it on.
	dlg = PanelContainer.new()
	dlg.add_theme_stylebox_override("panel", _frame(Color(0.09, 0.07, 0.05, 0.94), Color("#b98a3e"), 3))
	dlg.visible = false
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	dlg_face = TextureRect.new()
	dlg_face.custom_minimum_size = Vector2(54, 54)
	dlg_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlg_name = _label(12, GOLD)
	dlg_text = _label(14)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_hint = _label(9, Color(0.8, 0.75, 0.65, 0.8))
	dlg_hint.text = "торкнись, щоб продовжити"
	dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(dlg_name)
	dv.add_child(dlg_text)
	dv.add_child(dlg_hint)
	dh.add_child(dlg_face)
	dh.add_child(dv)
	dlg.add_child(dh)
	dlg.gui_input.connect(func(e):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			next_line())
	root.add_child(dlg)
	blockers.append(dlg)
	# Workbench / storage panel.
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _frame(Color(0.09, 0.07, 0.05, 0.96), Color("#b98a3e"), 3))
	panel.visible = false
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	panel.add_child(panel_box)
	root.add_child(panel)
	blockers.append(panel)
	toast = _label(15, Color("#fff1c9"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)

func layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var pf: Control = root.get_node("Portrait")
	pf.position = Vector2(10, 8)
	pf.reset_size()
	quest.custom_minimum_size = Vector2(250, 0)
	quest.size = Vector2(250, 0)
	quest.reset_size()
	quest.position = Vector2(10, 74)
	res_box.reset_size()
	res_box.position = Vector2(vs.x - res_box.size.x - 10, 10)
	act_btn.size = Vector2(76, 76)
	act_btn.position = Vector2(vs.x - 92, vs.y - 92)
	act_label.reset_size()
	act_label.position = Vector2(vs.x - 54 - act_label.size.x / 2.0, vs.y - 116)
	dlg.custom_minimum_size = Vector2(minf(560.0, vs.x - 230.0), 0)
	# Wrapping labels need a width before they are measured, or the panel grows one word per line.
	dlg_text.custom_minimum_size = Vector2(dlg.custom_minimum_size.x - 90.0, 0)
	dlg_name.custom_minimum_size = Vector2(dlg.custom_minimum_size.x - 90.0, 0)
	quest_text.custom_minimum_size = Vector2(236, 0)
	dlg.size = Vector2(dlg.custom_minimum_size.x, 0)
	dlg.reset_size()
	dlg.position = Vector2((vs.x - dlg.size.x) / 2.0, vs.y - dlg.size.y - 10)
	panel.custom_minimum_size = Vector2(minf(400.0, vs.x - 40.0), 0)
	panel.reset_size()
	panel.position = (vs - panel.size) / 2.0

# ---------------------------------------------------------------- icons (drawn, until the icon sheet arrives)
static func icon(ci: CanvasItem, kind: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := r.size.x
	var ol := Color(0.1, 0.07, 0.04)
	match kind:
		"wood":
			ci.draw_rect(Rect2(c.x - s * 0.45, c.y - s * 0.22, s * 0.8, s * 0.44), Color("#8a5a32"))
			ci.draw_rect(Rect2(c.x - s * 0.45, c.y - s * 0.22, s * 0.8, s * 0.44), ol, false, 1.0)
			ci.draw_circle(Vector2(c.x + s * 0.35, c.y), s * 0.22, Color("#d9b27a"))
			ci.draw_arc(Vector2(c.x + s * 0.35, c.y), s * 0.22, 0, TAU, 12, ol, 1.0)
			ci.draw_circle(Vector2(c.x + s * 0.35, c.y), s * 0.08, Color("#a87a48"))
		"scrap":
			var pts := PackedVector2Array()
			for i in 16:
				var a := i * TAU / 16.0
				pts.append(c + Vector2(cos(a), sin(a)) * s * (0.46 if i % 2 == 0 else 0.34))
			ci.draw_colored_polygon(pts, Color("#9aa1a6"))
			pts.append(pts[0])
			ci.draw_polyline(pts, ol, 1.0)
			ci.draw_circle(c, s * 0.14, Color("#4a4f53"))
		"water":
			var pts2 := PackedVector2Array([c + Vector2(0, -s * 0.48)])
			for i in 9:
				var a := PI * i / 8.0
				pts2.append(c + Vector2(cos(a) * s * 0.32, s * 0.12 + sin(a) * s * 0.32))
			ci.draw_colored_polygon(pts2, Color("#3fa8e8"))
			pts2.append(pts2[0])
			ci.draw_polyline(pts2, Color("#0e3a5a"), 1.0)
			ci.draw_circle(c + Vector2(-s * 0.1, s * 0.12), s * 0.07, Color("#bfe8ff"))
		"kit":
			ci.draw_line(c + Vector2(-s * 0.32, s * 0.32), c + Vector2(s * 0.18, -s * 0.18), Color("#b8c0c6"), s * 0.18)
			ci.draw_circle(c + Vector2(s * 0.24, -s * 0.24), s * 0.2, Color("#b8c0c6"))
			ci.draw_circle(c + Vector2(s * 0.32, -s * 0.32), s * 0.09, Color(0.1, 0.08, 0.06))
		"seeds":
			ci.draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.4, s * 0.6, s * 0.8), Color("#d8c08a"))
			ci.draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.4, s * 0.6, s * 0.8), ol, false, 1.0)
			ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.14, Color("#6ab04a"))
		"cabbage":
			ci.draw_circle(c, s * 0.4, Color("#5f9a3e"))
			ci.draw_circle(c + Vector2(0, -s * 0.05), s * 0.26, Color("#8cc45a"))
			ci.draw_arc(c, s * 0.4, 0, TAU, 14, ol, 1.0)
		"heart":
			var hp := PackedVector2Array([c + Vector2(0, s * 0.4), c + Vector2(-s * 0.45, -s * 0.02), c + Vector2(-s * 0.4, -s * 0.3),
				c + Vector2(-s * 0.2, -s * 0.42), c + Vector2(0, -s * 0.25), c + Vector2(s * 0.2, -s * 0.42), c + Vector2(s * 0.4, -s * 0.3), c + Vector2(s * 0.45, -s * 0.02)])
			ci.draw_colored_polygon(hp, Color("#e2342c"))
			hp.append(hp[0])
			ci.draw_polyline(hp, Color("#4a0e0a"), 1.5)
			ci.draw_circle(c + Vector2(-s * 0.2, -s * 0.2), s * 0.07, Color("#ff9a8a"))

func _draw_hand(b: Button) -> void:
	var c := b.size / 2.0
	var col := Color("#efe3c8") if not b.disabled else Color(0.5, 0.47, 0.42)
	b.draw_rect(Rect2(c.x - 13, c.y - 4, 26, 22), col)
	for i in 4:
		b.draw_rect(Rect2(c.x - 13 + i * 7, c.y - 20 + absf(i - 1.5) * 3.0, 5, 20), col)
	b.draw_rect(Rect2(c.x - 22, c.y + 1, 10, 6), col)
	b.draw_rect(Rect2(c.x - 13, c.y + 18, 26, 4), col.darkened(0.25))

# ---------------------------------------------------------------- joystick
func _over_ui(p: Vector2) -> bool:
	for c in blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			if dlg.visible and not _over_ui(e.position):
				next_line()
				return
			var vs := get_viewport().get_visible_rect().size
			if joy_index == -1 and modal == null and not dlg.visible and not _over_ui(e.position) and e.position.x < vs.x * 0.62 and e.position.y > vs.y * 0.28:
				joy_index = e.index
				joy_origin = e.position
				joy_pos = e.position
				joy_vec = Vector2.ZERO
		elif e.index == joy_index:
			release_joy()
	elif e is InputEventScreenDrag and e.index == joy_index:
		var d: Vector2 = e.position - joy_origin
		if d.length() > JOY_R:
			joy_origin += d - d.normalized() * JOY_R
			d = d.normalized() * JOY_R
		joy_pos = joy_origin + d
		joy_vec = d / JOY_R
		if joy_vec.length() < 0.15:
			joy_vec = Vector2.ZERO

func release_joy() -> void:
	joy_index = -1
	joy_vec = Vector2.ZERO

# ---------------------------------------------------------------- content
func set_quest(title: String, text: String) -> void:
	quest_title.text = title
	quest_text.text = text
	quest_text.visible = text != ""
	quest.reset_size()

func refresh(inv: Dictionary) -> void:
	for k in res_items:
		var n := int(inv.get(k, 0))
		res_items[k].label.text = str(n)
		res_items[k].panel.visible = n > 0 or k in ["wood", "scrap", "water"]
	res_box.reset_size()
	layout()

func set_action(text: String, enabled: bool) -> void:
	act_label.text = text
	act_label.visible = text != "" and modal == null and not dlg.visible
	act_btn.disabled = not enabled or modal != null or dlg.visible
	act_btn.queue_redraw()
	act_label.reset_size()
	var vs := get_viewport().get_visible_rect().size
	act_label.position = Vector2(vs.x - 54 - act_label.size.x / 2.0, vs.y - 116)

func toast_msg(text: String, secs := 2.2) -> void:
	toast.text = text
	toast_t = secs

func say(new_lines: Array, then := Callable()) -> void:
	lines = new_lines.duplicate()
	on_dialog_end = then
	release_joy()
	_show_line()

func _show_line() -> void:
	if lines.is_empty():
		dlg.visible = false
		if on_dialog_end.is_valid():
			var f := on_dialog_end
			on_dialog_end = Callable()
			f.call()
		return
	var l: Array = lines[0]
	dlg.visible = true
	dlg_name.text = NAMES.get(l[0], l[0])
	dlg_text.text = l[1]
	dlg_face.texture = load(FACES[l[0]]) if FACES.has(l[0]) else null
	layout()

func next_line() -> void:
	if not lines.is_empty():
		lines.pop_front()
	_show_line()

## A small panel: title, rows of [icon, text, colour], buttons [text, enabled, callback].
func open_panel(title: String, rows: Array, buttons: Array) -> void:
	for c in panel_box.get_children():
		panel_box.remove_child(c)       # out of the layout now, so the panel shrinks to the new content
		c.queue_free()
	var t := _label(15, GOLD)
	t.text = title
	panel_box.add_child(t)
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		if r[0] != "":
			var ic := Control.new()
			ic.custom_minimum_size = Vector2(20, 20)
			var k: String = r[0]
			ic.draw.connect(func(): icon(ic, k, Rect2(Vector2.ZERO, Vector2(20, 20))))
			h.add_child(ic)
		var l := _label(13, r[2] if r.size() > 2 else Color("#f1e6cf"))
		l.text = r[1]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(320, 0)
		h.add_child(l)
		panel_box.add_child(h)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	for b in buttons:
		var btn := _button(b[0], 13)
		btn.disabled = not b[1]
		var cb: Callable = b[2]
		btn.pressed.connect(func(): cb.call())
		bh.add_child(btn)
	var close := _button("Закрити", 13)
	close.pressed.connect(close_panel)
	bh.add_child(close)
	panel_box.add_child(bh)
	modal = panel
	panel.visible = true
	release_joy()
	panel.size = Vector2.ZERO
	panel.reset_size()
	layout()

func close_panel() -> void:
	panel.visible = false
	modal = null
	release_joy()

func _process(delta: float) -> void:
	toast_t = maxf(0.0, toast_t - delta)
	toast.visible = toast_t > 0.0
	toast.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
	var vs := get_viewport().get_visible_rect().size
	toast.reset_size()
	toast.position = Vector2((vs.x - toast.size.x) / 2.0, vs.y * 0.24)
	overlay.queue_redraw()

func _draw_overlay() -> void:
	if world == null:
		return
	# Hearts (next to the portrait) and the hero's health as hearts.
	var hp: float = world.hp
	for i in 5:
		var full := clampf(hp / 20.0 - i, 0.0, 1.0)
		var r := Rect2(66 + i * 22, 12, 20, 20)
		icon(overlay, "heart", r)
		if full < 1.0:
			overlay.draw_rect(Rect2(r.position.x + r.size.x * full, r.position.y, r.size.x * (1.0 - full), r.size.y), Color(0.08, 0.06, 0.05, 0.75))
	# Hints over objects (screen positions from the world).
	for h in world.hints():
		_bubble(h)
	# Work progress ring over the hero.
	var pr: Dictionary = world.progress()
	if not pr.is_empty():
		overlay.draw_arc(pr.p, 14, 0, TAU, 32, Color(0, 0, 0, 0.6), 6)
		overlay.draw_arc(pr.p, 14, -PI / 2.0, -PI / 2.0 + TAU * pr.frac, 32, GOLD, 4)
	# Joystick: a resting ghost bottom-left, the live one where the thumb is.
	var vs := get_viewport().get_visible_rect().size
	var base := joy_origin if joy_index != -1 else Vector2(84, vs.y - 84)
	var knob := joy_pos if joy_index != -1 else base
	overlay.draw_circle(base, JOY_R + 10, Color(0.1, 0.08, 0.06, 0.35))
	overlay.draw_arc(base, JOY_R + 10, 0, TAU, 40, Color(0.95, 0.9, 0.8, 0.55), 2.5)
	for a in [0.0, PI / 2.0, PI, PI * 1.5]:
		var d := Vector2(cos(a), sin(a))
		var tip := base + d * (JOY_R + 2)
		overlay.draw_colored_polygon(PackedVector2Array([tip, tip - d * 8 + Vector2(-d.y, d.x) * 6, tip - d * 8 - Vector2(-d.y, d.x) * 6]), Color(0.95, 0.9, 0.8, 0.5))
	overlay.draw_circle(knob, 20, Color(0.92, 0.86, 0.75, 0.75))
	overlay.draw_arc(knob, 20, 0, TAU, 24, Color(0.4, 0.33, 0.25, 0.8), 2)

## A bubble over an object: an icon with "have/need" (like the concept's wrench 3/3) or a speech mark for a talker.
func _bubble(h: Dictionary) -> void:
	var p: Vector2 = h.p
	var kind: String = h.kind
	if kind == "talk":
		var r := Rect2(p.x - 15, p.y - 26, 30, 20)
		overlay.draw_rect(r, Color("#f4efe4"))
		overlay.draw_rect(r, Color(0.2, 0.18, 0.15), false, 1.5)
		overlay.draw_colored_polygon(PackedVector2Array([Vector2(p.x - 5, r.end.y), Vector2(p.x + 4, r.end.y), Vector2(p.x - 6, r.end.y + 7)]), Color("#f4efe4"))
		for i in 3:
			overlay.draw_rect(Rect2(p.x - 8 + i * 6, p.y - 18, 3, 3), Color(0.2, 0.18, 0.15))
		return
	var items: Array = h.items
	var widths := []
	var w := 10.0
	for it in items:
		var tw: float = 26.0 + font.get_string_size(it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		widths.append(tw)
		w += tw + 6.0
	var r2 := Rect2(p.x - w / 2.0, p.y - 34, w, 26)
	var all_ok := true
	for it in items:
		all_ok = all_ok and it.ok
	var edge := Color("#e8f0e0") if all_ok else Color("#e8dcc0")
	overlay.draw_rect(r2, Color(0.1, 0.12, 0.1, 0.9))
	overlay.draw_rect(r2, edge, false, 2)
	overlay.draw_colored_polygon(PackedVector2Array([Vector2(p.x - 6, r2.end.y), Vector2(p.x + 6, r2.end.y), Vector2(p.x, r2.end.y + 7)]), edge)
	var x := r2.position.x + 6
	for k in items.size():
		var it: Dictionary = items[k]
		icon(overlay, it.icon, Rect2(x, r2.position.y + 4, 18, 18))
		overlay.draw_string(font, Vector2(x + 22, r2.position.y + 19), it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#8ee07a") if it.ok else Color("#ffd08a"))
		x += widths[k] + 6.0
