extends CanvasLayer
## Squad prototype interface (landscape): team cards with health, resources, the task card, a floating joystick,
## world-attached need bubbles ("Деталі 2/3"), the action button at the object, health bars over units, an arrow to
## the task when it is off-screen, short dialogue lines, the squad screen, the end card.
## Touches that begin on a button or panel never start the joystick, and opening or closing a window releases it.

signal action_pressed
signal ability_pressed

var world
var font: Font
var bold: Font
var root: Control
var overlay: Control          # world-attached drawing (bubbles, bars, arrow, joystick)
var blockers: Array[Control] = []
var modal: Control
# joystick
var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_vec := Vector2.ZERO
const JOY_R := 54.0
# widgets
var team_cards := {}
var res_labels := {}
var res_boxes := {}
var quest_title: Label
var quest_text: Label
var quest_card: PanelContainer
var dlg: PanelContainer
var dlg_face: TextureRect
var dlg_name: Label
var dlg_text: Label
var lines: Array = []
var line_t := 0.0
var toast: Label
var toast_t := 0.0
var action_btn: Button
var ability_btn: Button
var squad_btn: Button
var squad_panel: PanelContainer
var squad_box: VBoxContainer
var end_panel: PanelContainer
var end_text: Label
var fade: ColorRect
var ability_frac := 0.0

const C_GOLD := Color("#f6c445")
const C_PANEL := Color(0.08, 0.1, 0.12, 0.88)
const NAMES := {"mira": "МІРА", "einstein": "ЕЙНШТЕЙН", "yana": "ЯНА"}
const FACES := {"mira": "res://assets/portrait-mira.webp", "einstein": "res://assets/portrait-einstein.webp"}

func _ready() -> void:
	font = load("res://assets/DejaVuSans.ttf")
	bold = load("res://assets/DejaVuSans-Bold.ttf")
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

# ---------------------------------------------------------------- building blocks
func _style(bg := C_PANEL, border := Color(1, 1, 1, 0.12), radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(6)
	return s

func _label(size := 13, color := Color.WHITE, b := false) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", bold if b else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, bg := Color("#e9a53a"), size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color("#2b1a08"))
	b.add_theme_color_override("font_pressed_color", Color("#2b1a08"))
	b.add_theme_color_override("font_hover_color", Color("#2b1a08"))
	b.add_theme_color_override("font_disabled_color", Color(0.25, 0.22, 0.2))
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, _style(bg, bg.darkened(0.35), 10))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.15), bg.darkened(0.4), 10))
	b.add_theme_stylebox_override("disabled", _style(Color(0.55, 0.53, 0.5), Color(0.3, 0.3, 0.3), 10))
	blockers.append(b)
	return b

func _build() -> void:
	# Team cards (top-left): portrait, name, level, health.
	var tv := HBoxContainer.new()
	tv.name = "Team"
	tv.add_theme_constant_override("separation", 6)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tv)
	for id in ["mira", "einstein"]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style())
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var face := TextureRect.new()
		face.texture = load(FACES[id])
		face.custom_minimum_size = Vector2(34, 34)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var name := _label(11, Color.WHITE, true)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(86, 8)
		bar.show_percentage = false
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.6)
		bg.set_corner_radius_all(3)
		var fg := StyleBoxFlat.new()
		fg.bg_color = Color("#5fd35a")
		fg.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		v.add_child(name)
		v.add_child(bar)
		h.add_child(face)
		h.add_child(v)
		card.add_child(h)
		tv.add_child(card)
		team_cards[id] = {"card": card, "name": name, "bar": bar, "fill": fg}
	# Resources (top-right).
	var rh := HBoxContainer.new()
	rh.name = "Res"
	rh.add_theme_constant_override("separation", 6)
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rh)
	for k in ["parts", "wood", "water"]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _style(Color(0.08, 0.1, 0.12, 0.8), Color(1, 1, 1, 0.1), 14))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(20, 20)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func(): draw_icon(ic, k, Rect2(Vector2.ZERO, Vector2(20, 20))))
		var l := _label(14, Color.WHITE, true)
		l.custom_minimum_size = Vector2(26, 0)
		h.add_child(ic)
		h.add_child(l)
		p.add_child(h)
		rh.add_child(p)
		res_labels[k] = l
		res_boxes[k] = p
	squad_btn = _button("Загін", Color("#8fc6e8"), 13)
	squad_btn.pressed.connect(open_squad)
	root.add_child(squad_btn)
	# Task card (under the team, yellow like a quest note).
	quest_card = PanelContainer.new()
	quest_card.add_theme_stylebox_override("panel", _style(Color("#f3d77a"), Color("#a7792a"), 8))
	quest_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 1)
	quest_title = _label(14, Color("#2b1a08"), true)
	quest_title.remove_theme_constant_override("outline_size")
	quest_text = _label(11, Color("#4a3410"))
	quest_text.remove_theme_constant_override("outline_size")
	quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qv.add_child(quest_title)
	qv.add_child(quest_text)
	quest_card.add_child(qv)
	root.add_child(quest_card)
	# Dialogue (bottom centre, does not take touches).
	dlg = PanelContainer.new()
	dlg.add_theme_stylebox_override("panel", _style(Color(0.07, 0.09, 0.11, 0.9), C_GOLD.darkened(0.3), 10))
	dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg.visible = false
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 8)
	dlg_face = TextureRect.new()
	dlg_face.custom_minimum_size = Vector2(40, 40)
	dlg_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlg_name = _label(11, C_GOLD, true)
	dlg_text = _label(13)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(dlg_name)
	dv.add_child(dlg_text)
	dh.add_child(dlg_face)
	dh.add_child(dv)
	dlg.add_child(dh)
	root.add_child(dlg)
	toast = _label(14, Color.WHITE, true)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast)
	# The action at an object ("Полагодити") and the researcher's ability.
	action_btn = _button("Дія", Color("#7fd46a"), 15)
	action_btn.visible = false
	action_btn.pressed.connect(func(): action_pressed.emit())
	root.add_child(action_btn)
	ability_btn = _button("Імпульс", Color("#7fd6f0"), 13)
	ability_btn.visible = false
	ability_btn.pressed.connect(func(): ability_pressed.emit())
	root.add_child(ability_btn)
	# Squad screen.
	squad_panel = PanelContainer.new()
	squad_panel.add_theme_stylebox_override("panel", _style(Color(0.09, 0.11, 0.13, 0.97), C_GOLD.darkened(0.2), 12))
	squad_panel.visible = false
	squad_box = VBoxContainer.new()
	squad_box.add_theme_constant_override("separation", 8)
	squad_panel.add_child(squad_box)
	root.add_child(squad_panel)
	blockers.append(squad_panel)
	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", _style(Color(0.09, 0.11, 0.13, 0.97), C_GOLD, 12))
	end_panel.visible = false
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	end_text = _label(13)
	end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var again := _button("Пройти ще раз", Color("#e9a53a"), 15)
	again.pressed.connect(func(): world.restart())
	ev.add_child(end_text)
	ev.add_child(again)
	end_panel.add_child(ev)
	root.add_child(end_panel)
	blockers.append(end_panel)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)

func layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var team: Control = root.get_node("Team")
	team.position = Vector2(10, 8)
	team.reset_size()
	var res: Control = root.get_node("Res")
	res.reset_size()
	squad_btn.size = Vector2(70, 34)
	squad_btn.position = Vector2(vs.x - 80, 8)
	res.position = Vector2(squad_btn.position.x - res.size.x - 8, 9)
	quest_card.custom_minimum_size = Vector2(260, 0)
	quest_card.size = Vector2(260, 0)
	quest_card.position = Vector2(10, 62)
	dlg.custom_minimum_size = Vector2(minf(440.0, vs.x - 320.0), 0)
	dlg.size = Vector2(dlg.custom_minimum_size.x, 0)
	dlg.reset_size()
	dlg.position = Vector2((vs.x - dlg.size.x) / 2.0, vs.y - dlg.size.y - 12)
	ability_btn.size = Vector2(86, 86)
	ability_btn.position = Vector2(vs.x - 104, vs.y - 104)
	squad_panel.custom_minimum_size = Vector2(minf(560.0, vs.x - 40.0), 0)
	squad_panel.reset_size()
	squad_panel.position = (vs - squad_panel.size) / 2.0
	end_panel.custom_minimum_size = Vector2(minf(460.0, vs.x - 40.0), 0)
	end_panel.reset_size()
	end_panel.position = (vs - end_panel.size) / 2.0

# ---------------------------------------------------------------- icons drawn in code (prototype)
static func draw_icon(ci: CanvasItem, kind: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := r.size.x
	match kind:
		"parts":
			var pts := PackedVector2Array()
			for i in 16:
				var a := i * TAU / 16.0
				var rr := s * (0.47 if i % 2 == 0 else 0.36)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, Color("#5aa3dd"))
			ci.draw_circle(c, s * 0.14, Color("#dce8ef"))
		"wood":
			ci.draw_rect(Rect2(c.x - s * 0.45, c.y - s * 0.2, s * 0.9, s * 0.4), Color("#8a5a32"))
			ci.draw_circle(Vector2(c.x + s * 0.45, c.y), s * 0.2, Color("#d9b27a"))
			ci.draw_circle(Vector2(c.x + s * 0.45, c.y), s * 0.08, Color("#8a5a32"))
		"water":
			var pts2 := PackedVector2Array([c + Vector2(0, -s * 0.48)])
			for i in 9:
				var a := PI * i / 8.0
				pts2.append(c + Vector2(cos(a) * s * 0.32, s * 0.12 + sin(a) * s * 0.32))
			ci.draw_colored_polygon(pts2, Color("#5fc6f0"))
		"check":
			ci.draw_circle(c, s * 0.5, Color("#5fd35a"))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.25, 0), c + Vector2(-s * 0.05, s * 0.2), c + Vector2(s * 0.28, -s * 0.2)]), Color.WHITE, s * 0.12)

# ---------------------------------------------------------------- touch: floating joystick
func _over_ui(p: Vector2) -> bool:
	for c in blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			var vs := get_viewport().get_visible_rect().size
			if joy_index == -1 and modal == null and not _over_ui(e.position) and e.position.y > vs.y * 0.22:
				joy_index = e.index
				joy_origin = e.position
				joy_pos = e.position
				joy_vec = Vector2.ZERO
		elif e.index == joy_index:
			release_joy()
	elif e is InputEventScreenDrag and e.index == joy_index:
		var d: Vector2 = e.position - joy_origin
		if d.length() > JOY_R:
			joy_origin += d - d.normalized() * JOY_R     # the base follows the thumb
			d = d.normalized() * JOY_R
		joy_pos = joy_origin + d
		joy_vec = d / JOY_R
		if joy_vec.length() < 0.12:
			joy_vec = Vector2.ZERO

func release_joy() -> void:
	joy_index = -1
	joy_vec = Vector2.ZERO

func open_modal(p: Control) -> void:
	modal = p
	p.visible = true
	release_joy()
	layout()

func close_modal() -> void:
	if modal:
		modal.visible = false
	modal = null
	release_joy()

# ---------------------------------------------------------------- content
func set_quest(title: String, text: String) -> void:
	quest_title.text = title
	quest_text.text = text
	quest_text.visible = text != ""
	quest_card.reset_size()

func refresh(res: Dictionary, heroes: Array) -> void:
	for k in res_labels:
		res_labels[k].text = str(int(res.get(k, 0)))
	res_boxes["water"].visible = res.get("water", 0) > 0
	for h in heroes:
		var c: Dictionary = team_cards[h.id]
		c.card.visible = h.active
		c.name.text = "%s · рів. %d" % [NAMES[h.id], h.level]
		c.bar.max_value = h.max_hp
		c.bar.value = h.hp
		c.fill.bg_color = Color("#5fd35a") if h.hp > h.max_hp * 0.35 else Color("#e8543a")
	root.get_node("Res").reset_size()
	layout()

func say(new_lines: Array) -> void:
	lines.append_array(new_lines)
	if not dlg.visible:
		_show_line()

func _show_line() -> void:
	if lines.is_empty():
		dlg.visible = false
		return
	var l: Array = lines[0]
	dlg.visible = true
	dlg_name.text = NAMES.get(l[0], l[0])
	dlg_text.text = l[1]
	dlg_face.texture = load(FACES[l[0]]) if FACES.has(l[0]) else null
	dlg_face.visible = dlg_face.texture != null
	line_t = clampf(1.4 + l[1].length() * 0.045, 2.4, 5.5)
	layout()

func show_toast(text: String, secs := 2.0) -> void:
	toast.text = text
	toast_t = secs

func set_ability(visible_: bool, frac: float) -> void:
	ability_btn.visible = visible_
	ability_frac = frac
	ability_btn.disabled = frac > 0.0
	ability_btn.text = "Імпульс" if frac <= 0.0 else "%d" % ceili(frac * world.ABILITY_CD)

## The action button sits under the object's bubble while the leader is in its zone.
func set_action(text: String, at: Vector2, on: bool) -> void:
	action_btn.visible = on and modal == null
	if on:
		action_btn.text = text
		action_btn.reset_size()
		action_btn.size = Vector2(maxf(120.0, action_btn.size.x + 10.0), 40)
		action_btn.position = at - Vector2(action_btn.size.x / 2.0, 0)

func open_squad() -> void:
	for c in squad_box.get_children():
		c.queue_free()
	var title := _label(16, C_GOLD, true)
	title.text = "Загін"
	squad_box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	squad_box.add_child(row)
	for h in world.heroes:
		if not h.active:
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color(0.13, 0.16, 0.19), Color(1, 1, 1, 0.1), 10))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		var top := HBoxContainer.new()
		var face := TextureRect.new()
		face.texture = load(FACES[h.id])
		face.custom_minimum_size = Vector2(54, 54)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var nv := VBoxContainer.new()
		var n := _label(14, Color.WHITE, true)
		n.text = "%s · рівень %d" % [NAMES[h.id], h.level]
		var r := _label(11, Color("#b9c6cc"))
		r.text = h.role
		nv.add_child(n)
		nv.add_child(r)
		top.add_child(face)
		top.add_child(nv)
		v.add_child(top)
		var now: Dictionary = h.stats_for(h.level)
		var nxt: Dictionary = h.stats_for(h.level + 1)
		var st := _label(12)
		var up: bool = h.level < world.MAX_LEVEL
		st.text = "Здоров'я: %d%s\nАтака: %d%s\nДосяжність: %s" % [now.hp, (" → %d" % nxt.hp) if up else "", now.atk, (" → %d" % nxt.atk) if up else "",
			"далека (%.0f м)" % h.attack_range if h.ranged else "ближня"]
		v.add_child(st)
		var ab := _label(11, Color("#9fe0f5"))
		ab.text = h.ability_text
		ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ab.custom_minimum_size = Vector2(200, 0)
		v.add_child(ab)
		if up:
			var cost: Dictionary = world.UPGRADE
			var have: bool = world.can_pay(cost)
			var b := _button("Покращити: %d деталей, %d дерева" % [cost.parts, cost.wood], Color("#e9a53a"), 12)
			b.disabled = not have
			b.pressed.connect(func():
				world.upgrade(h)
				open_squad())
			v.add_child(b)
			if not have:
				var why := _label(11, Color("#ff9a8a"))
				why.text = world.missing_text(cost)
				v.add_child(why)
		else:
			var mx := _label(11, Color("#9ad08a"))
			mx.text = "Максимальний рівень у пробній версії"
			v.add_child(mx)
		card.add_child(v)
		row.add_child(card)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	var close := _button("Закрити", Color("#8fc6e8"), 14)
	close.pressed.connect(close_modal)
	var reset := _button("Почати епізод заново", Color("#c9c3b8"), 11)
	reset.pressed.connect(func(): world.restart())
	bottom.add_child(close)
	bottom.add_child(reset)
	squad_box.add_child(bottom)
	squad_panel.reset_size()
	open_modal(squad_panel)

func show_end(text: String) -> void:
	end_text.text = text
	open_modal(end_panel)

# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	toast_t = maxf(0.0, toast_t - delta)
	toast.visible = toast_t > 0.0
	var vs := get_viewport().get_visible_rect().size
	toast.reset_size()
	toast.position = Vector2((vs.x - toast.size.x) / 2.0, vs.y * 0.3)
	toast.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
	if dlg.visible:
		line_t -= delta
		if line_t <= 0.0:
			lines.pop_front()
			_show_line()
	overlay.queue_redraw()

## World-attached things, drawn in screen space from the world's list: bubbles, health bars, progress, arrow, joystick.
func _draw_overlay() -> void:
	if world == null:
		return
	for b in world.bubbles():
		_draw_bubble(b)
	for u in world.bars():
		var p: Vector2 = u.p
		var w := 34.0 if not u.big else 60.0
		overlay.draw_rect(Rect2(p.x - w / 2.0 - 1, p.y - 1, w + 2, 6), Color(0, 0, 0, 0.7))
		overlay.draw_rect(Rect2(p.x - w / 2.0, p.y, w * u.frac, 4), u.color)
	for g in world.progress_marks():
		var c: Vector2 = g.p
		overlay.draw_arc(c, 15, 0, TAU, 32, Color(0, 0, 0, 0.55), 6)
		overlay.draw_arc(c, 15, -PI / 2.0, -PI / 2.0 + TAU * g.frac, 32, C_GOLD, 4)
	var arrow: Dictionary = world.offscreen_arrow()
	if not arrow.is_empty():
		var a: Vector2 = arrow.p
		var d: Vector2 = arrow.dir
		var n := Vector2(-d.y, d.x)
		overlay.draw_colored_polygon(PackedVector2Array([a + d * 16, a - d * 8 + n * 11, a - d * 8 - n * 11]), C_GOLD)
		overlay.draw_polyline(PackedVector2Array([a + d * 16, a - d * 8 + n * 11, a - d * 8 - n * 11, a + d * 16]), Color(0.2, 0.12, 0.02), 2)
	if joy_index != -1:
		overlay.draw_circle(joy_origin, JOY_R + 6, Color(1, 1, 1, 0.12))
		overlay.draw_arc(joy_origin, JOY_R + 6, 0, TAU, 40, Color(1, 1, 1, 0.35), 2)
		overlay.draw_circle(joy_pos, 22, Color(1, 1, 1, 0.55))
	if ability_btn.visible and ability_frac > 0.0:
		var r := ability_btn.get_global_rect()
		overlay.draw_rect(r, Color(0, 0, 0, 0.0))

func _draw_bubble(b: Dictionary) -> void:
	var p: Vector2 = b.p
	var needs: Array = b.needs
	var w := 16.0 + needs.size() * 64.0
	var h := 30.0
	var r := Rect2(p.x - w / 2.0, p.y - h - 10, w, h)
	var bg := Color("#fbf4e2") if not b.done else Color("#e4f5dc")
	overlay.draw_rect(r, bg)
	overlay.draw_rect(r, Color(0.35, 0.25, 0.12), false, 1.5)
	overlay.draw_colored_polygon(PackedVector2Array([Vector2(p.x - 7, r.end.y), Vector2(p.x + 7, r.end.y), Vector2(p.x, r.end.y + 9)]), bg)
	var x := r.position.x + 8
	for n in needs:
		draw_icon(overlay, n.kind, Rect2(x, r.position.y + 5, 20, 20))
		var ok: bool = n.have >= n.need
		overlay.draw_string(bold, Vector2(x + 23, r.position.y + 21), "%d/%d" % [mini(n.have, n.need), n.need], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color("#2f7a2a") if ok else Color("#b5361f"))
		x += 64
	if b.done:
		draw_icon(overlay, "check", Rect2(p.x - 13, r.position.y - 30, 26, 26))
	if b.has("title"):
		overlay.draw_string(bold, Vector2(r.position.x, r.position.y - 6), b.title, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color.WHITE)
