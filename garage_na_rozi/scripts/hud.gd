extends Control
## Ukrainian interface built in code: top bar (coins, goal, pause), bottom
## card (orders, payments, instructions), speech bubbles and overlays
## (title, pause, settings, job board, purchases, hint, resume, credits).

signal action(name: String, arg: Variant)

const INK := Color("2b2420")
const PAPER := Color("f3e8d0")
const PAPER_DARK := Color("e3d3b0")
const ACCENT := Color("e9a03b")
const CoinIcon := preload("res://scripts/coin_icon.gd")

var th: Theme
var font_ui: Font
var font_bold: Font
var font_hand: Font

var top_bar: HBoxContainer
var pause_btn: Button
var coins_lbl: Label
var goal_lbl: Label
var goal_bar: ProgressBar
var goal_box: PanelContainer
var repair_box: PanelContainer
var repair_title: Label
var timer_lbl: Label
var steps_lbl: Label
var bottom: PanelContainer
var bottom_box: VBoxContainer
var bubble: PanelContainer
var bubble_lbl: Label
var bubble_target := Vector2.ZERO
var bubble_time := 0.0
var overlay: Control
var overlay_card: PanelContainer
var overlay_box: VBoxContainer
var overlay_kind := ""
var fader: ColorRect
var coach_lbl: Label
var hint_btn: Button
var toast: Label
var toast_time := 0.0
var shown_balance := 0.0
var target_balance := 0
var safe_top := 0.0
var safe_bottom := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font_ui = load("res://assets/fonts/Rubik-Medium.ttf")
	font_bold = load("res://assets/fonts/Rubik-Bold.ttf")
	font_hand = load("res://assets/fonts/Neucha-Regular.ttf")
	th = _make_theme()
	theme = th
	_build_top()
	_build_bottom()
	_build_bubble()
	_build_overlay()
	toast = Label.new()
	toast.add_theme_font_override("font", font_bold)
	toast.add_theme_font_size_override("font_size", 30)
	toast.add_theme_color_override("font_color", Color("fff6df"))
	toast.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.08, 0.9))
	toast.add_theme_constant_override("outline_size", 10)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(40, 200)
	toast.size = Vector2(640, 80)
	toast.modulate.a = 0.0
	add_child(toast)
	fader = ColorRect.new()
	fader.color = Color("231e1b")
	fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.modulate.a = 0.0
	add_child(fader)
	shown_balance = Game.balance()
	target_balance = Game.balance()
	_update_coins()
	Game.balance_changed.connect(func(v): target_balance = v)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var vs := get_viewport_rect().size
	if win.y > 0 and safe.size.y > 0:
		var k := vs.y / float(win.y)
		safe_top = maxf(0.0, safe.position.y * k)
		safe_bottom = maxf(0.0, (win.y - safe.end.y) * k)
	top_bar.offset_top = 14 + safe_top
	top_bar.offset_bottom = 14 + safe_top + 96
	bottom.offset_bottom = -14 - safe_bottom


# ------------------------------------------------------------------ theme

func _sb(bg: Color, border: Color, bw := 3, radius := 22, shadow := 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0.1, 0.07, 0.05, 0.35)
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing = true
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_ui
	t.default_font_size = 28
	t.set_stylebox("normal", "Button", _sb(PAPER, INK))
	t.set_stylebox("hover", "Button", _sb(PAPER, INK))
	t.set_stylebox("pressed", "Button", _sb(PAPER_DARK, INK, 3, 22, 1))
	t.set_stylebox("disabled", "Button", _sb(Color(0.85, 0.8, 0.72, 0.7), Color(0.4, 0.35, 0.3, 0.6), 3, 22, 0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.3, 0.26, 0.7))
	t.set_font_size("font_size", "Button", 30)
	t.set_font("font", "Button", font_bold)
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _sb(ACCENT, INK))
	t.set_stylebox("hover", "PrimaryButton", _sb(ACCENT, INK))
	t.set_stylebox("pressed", "PrimaryButton", _sb(ACCENT.darkened(0.15), INK, 3, 22, 1))
	t.set_type_variation("Card", "PanelContainer")
	var card := _sb(PAPER, Color("5a4632"), 3, 26, 8)
	card.content_margin_left = 26
	card.content_margin_right = 26
	card.content_margin_top = 20
	card.content_margin_bottom = 20
	t.set_stylebox("panel", "Card", card)
	t.set_stylebox("panel", "PanelContainer", card)
	var chip := _sb(Color(0.97, 0.92, 0.8, 0.94), Color("5a4632"), 3, 30, 4)
	chip.content_margin_left = 18
	chip.content_margin_right = 18
	chip.content_margin_top = 8
	chip.content_margin_bottom = 8
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", chip)
	t.set_color("font_color", "Label", INK)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.3, 0.22, 0.15, 0.25)
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("d9902c")
	fg.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fg)
	return t


func lbl(text: String, size := 28, col := INK, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if f != null:
		l.add_theme_font_override("font", f)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func btn(text: String, act: String, arg: Variant = null, primary := false, min_h := 92) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.pressed.connect(func():
		Sfx.play("pop")
		emit_signal("action", act, arg))
	b.name = "btn_" + act
	return b


func _ign(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ------------------------------------------------------------------ top bar

func _build_top() -> void:
	top_bar = HBoxContainer.new()
	_ign(top_bar)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 16
	top_bar.offset_right = -16
	top_bar.offset_top = 14
	top_bar.offset_bottom = 110
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.name = "btn_pause"
	pause_btn.custom_minimum_size = Vector2(92, 92)
	pause_btn.add_theme_font_size_override("font_size", 34)
	pause_btn.pressed.connect(func():
		Sfx.play("pop")
		emit_signal("action", "pause", null))
	top_bar.add_child(pause_btn)
	# goal chip
	goal_box = PanelContainer.new()
	goal_box.theme_type_variation = "Chip"
	goal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ign(goal_box)
	var gv := VBoxContainer.new()
	_ign(gv)
	gv.add_theme_constant_override("separation", 4)
	goal_lbl = lbl("", 22)
	goal_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	goal_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size = Vector2(0, 14)
	_ign(goal_bar)
	gv.add_child(goal_lbl)
	gv.add_child(goal_bar)
	goal_box.add_child(gv)
	top_bar.add_child(goal_box)
	# repair title chip (replaces goal during repairs)
	repair_box = PanelContainer.new()
	repair_box.theme_type_variation = "Chip"
	repair_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ign(repair_box)
	var rv := VBoxContainer.new()
	_ign(rv)
	rv.add_theme_constant_override("separation", 0)
	repair_title = lbl("", 24, INK, font_bold)
	repair_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	repair_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	steps_lbl = lbl("", 20, Color(0.35, 0.28, 0.22))
	steps_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rv.add_child(repair_title)
	rv.add_child(steps_lbl)
	repair_box.add_child(rv)
	repair_box.visible = false
	top_bar.add_child(repair_box)
	# coins / timer chip
	var cb := PanelContainer.new()
	cb.theme_type_variation = "Chip"
	_ign(cb)
	var ch := HBoxContainer.new()
	_ign(ch)
	ch.add_theme_constant_override("separation", 8)
	var ic := CoinIcon.new()
	ic.custom_minimum_size = Vector2(40, 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ign(ic)
	ch.add_child(ic)
	coins_lbl = lbl("0", 34, INK, font_bold)
	coins_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	coins_lbl.custom_minimum_size = Vector2(70, 0)
	ch.add_child(coins_lbl)
	timer_lbl = lbl("", 26, INK, font_bold)
	timer_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_lbl.visible = false
	ch.add_child(timer_lbl)
	cb.add_child(ch)
	top_bar.add_child(cb)


func set_goal(text: String, frac: float) -> void:
	goal_lbl.text = text
	goal_bar.value = clampf(frac, 0.0, 1.0) * 100.0
	goal_bar.visible = frac >= 0.0


func repair_mode(on: bool, title := "") -> void:
	goal_box.visible = not on
	repair_box.visible = on
	repair_title.text = title
	timer_lbl.visible = on
	coins_lbl.visible = not on
	if on:
		clear_bottom()


func set_steps(step: String) -> void:
	var names := {"diagnose": "Огляд", "fix": "Ремонт", "verify": "Перевірка", "done": "Готово"}
	var order := ["diagnose", "fix", "verify"]
	var parts: Array = []
	for s in order:
		if s == step:
			parts.append("● " + names[s])
		elif order.find(s) < order.find(step) or step == "done":
			parts.append("✓ " + names[s])
		else:
			parts.append("○ " + names[s])
	steps_lbl.text = "   ".join(parts)


func set_timer(elapsed: float, target: float, started: bool) -> void:
	if not started:
		timer_lbl.text = "0:00"
		timer_lbl.add_theme_color_override("font_color", INK)
		return
	timer_lbl.text = fmt_time(elapsed)
	var col := INK
	if elapsed > target * 2.0:
		col = Color("8a7a6a")
	elif elapsed > target:
		col = Color("b5602a")
	else:
		col = Color("3f7a32")
	timer_lbl.add_theme_color_override("font_color", col)


static func fmt_time(s: float) -> String:
	var n := int(floor(s))
	return "%d:%02d" % [n / 60, n % 60]


func _update_coins() -> void:
	coins_lbl.text = str(int(round(shown_balance)))


func _process(delta: float) -> void:
	# keep the bottom card exactly as tall as its content
	if bottom.visible:
		var want := bottom.get_combined_minimum_size().y
		if absf(bottom.size.y - want) > 1.0:
			bottom.offset_top = bottom.offset_bottom - want
	if absf(shown_balance - target_balance) > 0.5:
		var prev := int(shown_balance)
		shown_balance = move_toward(shown_balance, target_balance, maxf(60.0, absf(target_balance - shown_balance) * 3.0) * delta)
		if int(shown_balance) / 10 != prev / 10:
			Sfx.play("tick", 1.6, -12.0)
		_update_coins()
	elif int(shown_balance) != target_balance:
		shown_balance = target_balance
		_update_coins()
	if bubble.visible:
		bubble_time -= delta
		_place_bubble()
		if bubble_time <= 0.0:
			bubble.visible = false
	if toast_time > 0.0:
		toast_time -= delta
		toast.modulate.a = clampf(toast_time * 2.0, 0.0, 1.0)


func snap_balance() -> void:
	shown_balance = Game.balance()
	target_balance = Game.balance()
	_update_coins()


# ------------------------------------------------------------------ bottom card

func _build_bottom() -> void:
	bottom = PanelContainer.new()
	bottom.theme_type_variation = "Card"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 14
	bottom.offset_right = -14
	bottom.offset_bottom = -14
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom)
	bottom_box = VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 12)
	_ign(bottom_box)
	bottom.add_child(bottom_box)
	bottom.visible = false


func clear_bottom() -> void:
	for c in bottom_box.get_children():
		bottom_box.remove_child(c)
		c.queue_free()
	bottom.visible = false
	coach_lbl = null
	hint_btn = null


func _show_bottom() -> void:
	bottom.visible = true
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 14
	bottom.offset_right = -14
	bottom.offset_bottom = -14 - safe_bottom
	bottom.offset_top = bottom.offset_bottom
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_refit_later()


## Wrapped labels measure their height only once their width is known, so the
## card is shrunk to its real height again after layout.
func _refit_later() -> void:
	await get_tree().process_frame
	if not is_instance_valid(bottom) or not bottom.visible:
		return
	bottom.offset_top = bottom.offset_bottom
	await get_tree().process_frame
	if is_instance_valid(bottom) and bottom.visible:
		bottom.offset_top = bottom.offset_bottom


func _row(children: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	_ign(h)
	h.add_theme_constant_override("separation", 12)
	for c in children:
		if c is Button:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(c)
	return h


## Garage idle: goal text and actions.
func panel_idle(text: String, buttons: Array) -> void:
	clear_bottom()
	if text != "":
		bottom_box.add_child(lbl(text, 26))
	for b in buttons:
		if b is Array:
			bottom_box.add_child(_row(b))
		else:
			bottom_box.add_child(b)
	_show_bottom()


## An order card: who, what, payment, how to start.
func panel_order(client: String, complaint: String, title: String, extra: String, buttons: Array) -> void:
	clear_bottom()
	var head := lbl(client + " · " + title, 24, Color(0.4, 0.3, 0.22), font_bold)
	bottom_box.add_child(head)
	bottom_box.add_child(lbl("«" + complaint + "»", 30, INK, font_hand))
	var pay := HBoxContainer.new()
	_ign(pay)
	pay.add_theme_constant_override("separation", 8)
	var ic := CoinIcon.new()
	ic.custom_minimum_size = Vector2(30, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ign(ic)
	pay.add_child(ic)
	var pl := lbl("Оплата %d · чайові до %d за швидкість" % [Game.data["base_pay"], Game.data["tip_max"]], 22, Color(0.3, 0.25, 0.2))
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pay.add_child(pl)
	bottom_box.add_child(pay)
	if extra != "":
		bottom_box.add_child(lbl(extra, 22, Color(0.45, 0.32, 0.2)))
	for b in buttons:
		if b is Array:
			bottom_box.add_child(_row(b))
		else:
			bottom_box.add_child(b)
	_show_bottom()


## Payment card after a repair: base pay and tips shown separately.
func panel_result(res: Dictionary, thanks: String, button_text: String) -> void:
	clear_bottom()
	bottom_box.add_child(lbl("«" + thanks + "»", 30, INK, font_hand))
	var grid := GridContainer.new()
	grid.columns = 2
	_ign(grid)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	var tgt := float(res["target"])
	var el := float(res["elapsed"])
	grid.add_child(lbl("Оплата за ремонт", 26))
	grid.add_child(_right(lbl("+%d" % int(res["base"]), 28, INK, font_bold)))
	var tip_note := "вчасно!" if el <= tgt else ("пізніше за ціль" if int(res["tip"]) > 0 else "без чайових — довгий ремонт")
	grid.add_child(lbl("Чайові · %s (%s, ціль %s)" % [tip_note, fmt_time(el), fmt_time(tgt)], 22, Color(0.35, 0.28, 0.22)))
	grid.add_child(_right(lbl("+%d" % int(res["tip"]), 28, Color("3f7a32") if int(res["tip"]) > 0 else Color(0.45, 0.4, 0.35), font_bold)))
	grid.add_child(lbl("Разом", 26, INK, font_bold))
	grid.add_child(_right(lbl("+%d" % (int(res["base"]) + int(res["tip"])), 32, INK, font_bold)))
	for c in grid.get_children():
		if c is Label and c.get_index() % 2 == 0:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_box.add_child(grid)
	if bool(res.get("record", false)):
		bottom_box.add_child(lbl("Новий рекорд на дошці робіт!", 24, Color("b5602a"), font_bold))
	bottom_box.add_child(btn(button_text, "next", null, true))
	_show_bottom()


func _right(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## During a repair: the current instruction and the hint button.
func panel_repair(text: String) -> void:
	if coach_lbl == null:
		clear_bottom()
		coach_lbl = lbl(text, 28)
		coach_lbl.custom_minimum_size = Vector2(0, 70)
		coach_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint_btn = btn("Підказка", "hint", null, false, 80)
		hint_btn.visible = false
		var row := HBoxContainer.new()
		_ign(row)
		row.add_theme_constant_override("separation", 12)
		coach_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(coach_lbl)
		hint_btn.custom_minimum_size = Vector2(190, 80)
		row.add_child(hint_btn)
		bottom_box.add_child(row)
		_show_bottom()
	coach_lbl.text = text
	_show_bottom()


func set_hint_button(on: bool) -> void:
	if hint_btn:
		hint_btn.visible = on
		if on:
			var tw := create_tween()
			hint_btn.scale = Vector2(0.9, 0.9)
			hint_btn.pivot_offset = hint_btn.size * 0.5
			tw.tween_property(hint_btn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		_show_bottom()


# ------------------------------------------------------------------ bubble & toast

func _build_bubble() -> void:
	bubble = PanelContainer.new()
	var sb := _sb(Color("fffaf0"), INK, 3, 26, 6)
	bubble.add_theme_stylebox_override("panel", sb)
	_ign(bubble)
	bubble_lbl = lbl("", 28, INK, font_hand)
	bubble_lbl.custom_minimum_size = Vector2(0, 0)
	bubble.add_child(bubble_lbl)
	bubble.visible = false
	add_child(bubble)


func say(text: String, at: Vector2, secs := 3.5) -> void:
	bubble_lbl.text = text
	bubble_lbl.custom_minimum_size = Vector2(minf(520.0, 40.0 + text.length() * 13.0), 0)
	bubble.reset_size()
	bubble_target = at
	bubble_time = secs
	bubble.visible = true
	_place_bubble()


func hide_bubble() -> void:
	bubble.visible = false


func _place_bubble() -> void:
	var s := bubble.get_combined_minimum_size()
	var vs := get_viewport_rect().size
	var p := bubble_target - Vector2(s.x * 0.5, s.y + 20)
	p.x = clampf(p.x, 12, vs.x - s.x - 12)
	p.y = clampf(p.y, 130 + safe_top, vs.y - s.y - 12)
	bubble.position = p
	bubble.size = s


func flash(text: String, secs := 2.2) -> void:
	toast.text = text
	toast.position = Vector2(30, 140 + safe_top)
	toast.size = Vector2(get_viewport_rect().size.x - 60, 80)
	toast_time = secs
	toast.modulate.a = 1.0


# ------------------------------------------------------------------ overlays

func _build_overlay() -> void:
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0.1, 0.08, 0.07, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ign(cc)
	overlay.add_child(cc)
	overlay_card = PanelContainer.new()
	overlay_card.theme_type_variation = "Card"
	overlay_card.custom_minimum_size = Vector2(620, 0)
	cc.add_child(overlay_card)
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 14)
	_ign(overlay_box)
	overlay_card.add_child(overlay_box)


func _open(kind: String, dim := 0.55) -> void:
	for c in overlay_box.get_children():
		overlay_box.remove_child(c)
		c.queue_free()
	overlay_kind = kind
	(overlay as ColorRect).color = Color(0.1, 0.08, 0.07, dim)
	overlay.visible = true
	overlay_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay_card, "modulate:a", 1.0, 0.18)


func close_overlay() -> void:
	overlay.visible = false
	overlay_kind = ""


func is_overlay(kind := "") -> bool:
	return overlay.visible and (kind == "" or overlay_kind == kind)


func _title_lbl(text: String, size := 48) -> Label:
	var l := lbl(text, size, INK, font_hand)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func open_title(has_progress: bool) -> void:
	_open("title", 0.25)
	overlay_card.custom_minimum_size = Vector2(600, 0)
	var t := _title_lbl("Гараж на розі", 72)
	overlay_box.add_child(t)
	var sub := lbl("Маленька майстерня. Великі руки.", 24, Color(0.4, 0.3, 0.22))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(sub)
	if has_progress:
		overlay_box.add_child(btn("Продовжити", "start", null, true, 104))
	else:
		overlay_box.add_child(btn("Почати", "start", null, true, 104))
	overlay_box.add_child(btn("Налаштування", "settings", "title"))


func open_pause(in_repair: bool) -> void:
	_open("pause")
	overlay_box.add_child(_title_lbl("Пауза"))
	if in_repair:
		overlay_box.add_child(lbl("Відлік часу зупинено.", 24, Color(0.4, 0.3, 0.22)))
	overlay_box.add_child(btn("Продовжити", "resume", null, true, 100))
	if in_repair:
		overlay_box.add_child(btn("Повернутися в гараж", "to_garage"))
	else:
		overlay_box.add_child(btn("Дошка робіт", "board"))
	overlay_box.add_child(btn("Налаштування", "settings", "pause"))


func open_settings(back_to: String) -> void:
	_open("settings")
	overlay_box.add_child(_title_lbl("Налаштування"))
	overlay_box.add_child(btn(("Звук: увімкнено" if Game.setting("sound") else "Звук: вимкнено"), "toggle", "sound"))
	overlay_box.add_child(btn(("Музика: увімкнено" if Game.setting("music") else "Музика: вимкнено"), "toggle", "music"))
	overlay_box.add_child(btn(("Вібрація: увімкнено" if Game.setting("vibration") else "Вібрація: вимкнено"), "toggle", "vibration"))
	overlay_box.add_child(btn("Готово", "settings_done", back_to, true))
	if Game.has_progress():
		var r := btn("Почати кар’єру заново", "reset_ask", back_to, false, 76)
		r.add_theme_font_size_override("font_size", 22)
		overlay_box.add_child(r)


func open_reset_confirm(back_to: String) -> void:
	_open("reset")
	overlay_box.add_child(_title_lbl("Почати заново?"))
	overlay_box.add_child(lbl("Гроші, покупки, вивіска й рекорди буде стерто.", 26))
	overlay_box.add_child(_row([btn("Скасувати", "settings", back_to, true), btn("Стерти", "reset_do", null)]))


func open_hint(text: String) -> void:
	_open("hint", 0.35)
	overlay_box.add_child(_title_lbl("Підказка", 40))
	overlay_box.add_child(lbl(text, 30))
	overlay_box.add_child(lbl("Відлік часу стоїть, поки відкрита підказка.", 20, Color(0.45, 0.35, 0.25)))
	overlay_box.add_child(btn("Зрозуміло", "hint_close", null, true))


func open_continue() -> void:
	_open("continue", 0.6)
	overlay_box.add_child(_title_lbl("Ремонт на паузі", 44))
	overlay_box.add_child(lbl("Ти повернувся до майстерні. Відлік продовжиться, коли натиснеш «Продовжити».", 26))
	overlay_box.add_child(btn("Продовжити", "continue_bg", null, true, 104))


func open_buy(item: String) -> void:
	_open("buy")
	overlay_box.add_child(_title_lbl(Game.item_name(item), 40))
	overlay_box.add_child(lbl(Game.data["items"][item]["about"], 26))
	var price := Game.price(item)
	var have := Game.balance()
	if not Game.item_unlocked(item):
		var why := "Відкриється після чотирьох ремонтів мотоцикла." if item == "lift" else "Відкриється після фіналу."
		overlay_box.add_child(lbl(why, 26, Color("b5602a")))
		overlay_box.add_child(btn("Добре", "close", null, true))
		return
	if Game.owns(item):
		overlay_box.add_child(lbl("Уже в гаражі.", 26))
		overlay_box.add_child(btn("Добре", "close", null, true))
		return
	overlay_box.add_child(lbl("Ціна: %d · у тебе: %d" % [price, have], 28, INK, font_bold))
	if have >= price:
		overlay_box.add_child(_row([btn("Пізніше", "close"), btn("Купити · %d" % price, "buy_do", item, true)]))
	else:
		overlay_box.add_child(lbl("Бракує %d монет." % (price - have), 26, Color("b5602a")))
		overlay_box.add_child(btn("Добре", "close", null, true))


func open_shop() -> void:
	_open("shop")
	overlay_box.add_child(_title_lbl("Покращення гаража", 40))
	for item in Game.DECOR:
		var row := HBoxContainer.new()
		_ign(row)
		row.add_theme_constant_override("separation", 12)
		var l := lbl(Game.item_name(item), 26)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if Game.owns(item):
			if item == "decor_gate":
				var b := btn("Змінити колір", "gate_toggle", null, false, 76)
				row.add_child(b)
			else:
				row.add_child(lbl("✓ є", 26, Color("3f7a32"), font_bold))
		else:
			var b2 := btn("%d" % Game.price(item), "buy_do", item, true, 76)
			b2.disabled = not Game.can_buy(item)
			b2.custom_minimum_size = Vector2(130, 76)
			row.add_child(b2)
		overlay_box.add_child(row)
	overlay_box.add_child(btn("Закрити", "close", null, false))


func open_board(free_play: bool, can_take: bool) -> void:
	_open("board")
	overlay_card.custom_minimum_size = Vector2(660, 0)
	overlay_box.add_child(_title_lbl("Дошка робіт", 42))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, minf(760.0, get_viewport_rect().size.y - 420.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ign(list)
	sc.add_child(list)
	var ids: Array = Game.order_ids + Game.FINAL
	for id in ids:
		var o: Dictionary = Game.order(id)
		var row := HBoxContainer.new()
		_ign(row)
		row.add_theme_constant_override("separation", 10)
		var sk := preload("res://scripts/sketch_icon.gd").new()
		sk.order_id = id
		sk.done = Game.is_done(id)
		sk.custom_minimum_size = Vector2(64, 64)
		_ign(sk)
		row.add_child(sk)
		var col := VBoxContainer.new()
		_ign(col)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		var veh: String = {"moped": "Мопед", "moto": "Мотоцикл", "car": "Авто", "wagon": "Універсал"}[o["vehicle"]]
		col.add_child(lbl("%s · %s" % [veh, o["title"]] if Game.is_done(id) else "%s · ???" % veh, 22, INK, font_bold))
		var best := float(Game.state["records"].get(id, 0.0))
		var line := "Ціль %s" % fmt_time(float(o["target"]))
		if best > 0.0:
			line = "Рекорд %s · ціль %s" % [fmt_time(best), fmt_time(float(o["target"]))]
		col.add_child(lbl(line, 20, Color(0.4, 0.32, 0.25)))
		row.add_child(col)
		if free_play and can_take and Game.is_done(id) and not id.begins_with("f_"):
			var b := btn("Взяти", "take", id, false, 64)
			b.custom_minimum_size = Vector2(120, 64)
			b.add_theme_font_size_override("font_size", 24)
			row.add_child(b)
		list.add_child(row)
	overlay_box.add_child(sc)
	if free_play:
		var q: Array = Game.peek_free_queue()
		var names: Array = []
		for id in q:
			names.append(Game.order(id)["title"])
		overlay_box.add_child(lbl("Черга клієнтів: " + ", ".join(names), 20, Color(0.4, 0.32, 0.25)))
	overlay_box.add_child(btn("Закрити", "close", null, true))


func open_info(title: String, text: String, button := "Добре", act := "close") -> void:
	_open("info")
	overlay_box.add_child(_title_lbl(title, 40))
	overlay_box.add_child(lbl(text, 26))
	overlay_box.add_child(btn(button, act, null, true))


func open_credits() -> void:
	_open("credits", 0.72)
	overlay_card.custom_minimum_size = Vector2(620, 0)
	overlay_box.add_child(_title_lbl("Гараж на розі", 64))
	var lines := [
		"Остап із родиною поїхав до моря,",
		"а над воротами тепер висить емальована вивіска.",
		"",
		"Майстер — ти",
		"Ідея та завдання — власник проєкту",
		"Гра, малюнки, звуки — створено з Claude",
		"Рушій — Godot Engine (MIT)",
		"Шрифти — Rubik і Neucha (SIL OFL)",
		"",
		"Дякуємо, що зазирнули в гараж!",
	]
	for s in lines:
		var l := lbl(s, 26 if s != "" else 10, INK if not s.begins_with("Майстер") else Color("b5602a"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_box.add_child(l)
	overlay_box.add_child(btn("Відкрити майстерню", "credits_done", null, true, 104))


func fade(to: float, secs := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fader, "modulate:a", to, secs)
	await tw.finished
