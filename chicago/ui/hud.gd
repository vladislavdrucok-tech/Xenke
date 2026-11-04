class_name HUD
extends CanvasLayer
## The in-game interface: clock and money (top left), the current objective (top right), toasts, the action hint,
## the dialogue box, the pause menu and (on touch screens) the touch controls. It only displays state and forwards
## presses; the world decides what they do.

signal action_pressed
signal attack_pressed
signal pause_toggled
signal menu_save
signal menu_load
signal menu_quit

var clock_label: Label
var money_label: Label
var quest_title: Label
var quest_text: Label
var toast_label: Label
var hint_label: Label
var status_label: Label
var dialogue: DialogueBox
var touch: TouchControls
var pause_panel: PanelContainer
var _toast_t := 0.0
var root: Control
var settings_panel: SettingsPanel
var perf_label: Label          # F3: frame time and counts (measurements, not targets)
var _frame_ms: Array[float] = []

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var tl := _panel(Vector2(16, 16))
	var v := VBoxContainer.new()
	tl.add_child(v)
	clock_label = _label(20, Color("#f1e6cf"))
	money_label = _label(20, Color("#c8e6a0"))
	status_label = _label(16, Color("#e8b0a0"))
	v.add_child(clock_label)
	v.add_child(money_label)
	v.add_child(status_label)
	var tr_panel := _panel(Vector2.ZERO)
	tr_panel.anchor_left = 1.0
	tr_panel.anchor_right = 1.0
	tr_panel.offset_left = -390.0
	tr_panel.offset_right = -16.0
	tr_panel.offset_top = 16.0
	tr_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var qv := VBoxContainer.new()
	tr_panel.add_child(qv)
	quest_title = _label(18, Color("#e7c27a"))
	quest_text = _label(18, Color("#f1e6cf"))
	quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_text.custom_minimum_size = Vector2(350, 0)
	qv.add_child(quest_title)
	qv.add_child(quest_text)
	toast_label = _label(22, Color("#fff4d6"))
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.position = Vector2(-300, 120)
	toast_label.size = Vector2(600, 40)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_label.add_theme_constant_override("outline_size", 6)
	root.add_child(toast_label)
	hint_label = _label(18, Color("#fff4d6"))
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(-200, -64)
	hint_label.size = Vector2(400, 30)
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("outline_size", 6)
	root.add_child(hint_label)
	touch = TouchControls.new()
	touch.visible = Settings.want_touch()
	touch.action_pressed.connect(func(): action_pressed.emit())
	touch.attack_pressed.connect(func(): attack_pressed.emit())
	touch.pause_pressed.connect(func(): pause_toggled.emit())
	root.add_child(touch)
	dialogue = DialogueBox.new()
	# Bottom centre, 760 px wide (or the screen width minus margins on narrow screens), growing upwards.
	dialogue.anchor_left = 0.5
	dialogue.anchor_right = 0.5
	dialogue.anchor_top = 1.0
	dialogue.anchor_bottom = 1.0
	dialogue.offset_left = -380.0
	dialogue.offset_right = 380.0
	dialogue.offset_bottom = -24.0
	dialogue.offset_top = -24.0
	dialogue.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialogue.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(dialogue)
	_build_pause()
	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.closed.connect(func():
		settings_panel.visible = false
		pause_panel.visible = true)
	settings_panel.changed.connect(apply_ui_scale)
	root.add_child(settings_panel)
	get_viewport().size_changed.connect(apply_ui_scale)
	apply_ui_scale.call_deferred()
	perf_label = _label(14, Color("#b8f0b0"))
	perf_label.position = Vector2(16, 120)
	perf_label.visible = OS.get_cmdline_user_args().has("--perf")
	root.add_child(perf_label)
	EventBus.toast.connect(func(k: String, args: Array): toast(Loc.t(k, args)))
	var lbl := _label(12, Color(1, 1, 1, 0.45))
	lbl.text = "UI_TEMP_ART"
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.position = Vector2(16, -26)
	root.add_child(lbl)

## Interface scale (settings): the HUD layer is scaled and its root sized to the view divided by the scale, so
## anchored panels stay in the corners. The world is not affected.
func apply_ui_scale() -> void:
	var sc := Settings.ui_scale
	scale = Vector2(sc, sc)
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2.ZERO
	root.size = get_viewport().get_visible_rect().size / sc
	touch.visible = Settings.want_touch()
	touch.layout()

func _panel(pos: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.72)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	return p

func _label(size: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.95)
	sb.border_color = Color("#b8893f")
	sb.set_border_width_all(2)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	pause_panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)
	var t := _label(26, Color("#e7c27a"))
	t.text = "UI_PAUSED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for pair in [["UI_RESUME", func(): pause_toggled.emit()], ["UI_SAVE", func(): menu_save.emit()],
			["UI_LOAD", func(): menu_load.emit()], ["UI_SETTINGS", func(): _open_settings()], ["UI_MAIN_MENU", func(): menu_quit.emit()]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(300, 60)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(pair[1])
		v.add_child(b)
	var h := _label(14, Color(1, 1, 1, 0.5))
	h.text = "UI_QUICKSAVE_HINT"
	v.add_child(h)
	root.add_child(pause_panel)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("debug_overlay"):
		perf_label.visible = not perf_label.visible
		get_viewport().set_input_as_handled()
		return
	# The world is paused with the tree; the HUD keeps running, so it is the one that hears "unpause".
	if pause_panel.visible and e.is_action_pressed("pause"):
		pause_toggled.emit()
		get_viewport().set_input_as_handled()

func _open_settings() -> void:
	pause_panel.visible = false
	settings_panel.visible = true
	settings_panel.position = (root.size - settings_panel.size) / 2.0

func show_pause(v: bool) -> void:
	if not v:
		settings_panel.visible = false
	pause_panel.visible = v
	if v:
		pause_panel.position = -pause_panel.size / 2.0

func toast(text: String, secs: float = 2.6) -> void:
	toast_label.text = text
	toast_label.visible = true
	_toast_t = secs

func set_action(verb_key: String, available: bool) -> void:
	if touch.visible:
		touch.set_verb(verb_key, available)
		hint_label.text = ""
	else:
		hint_label.text = Loc.t("HUD_KEY_HINT", [tr(verb_key)]) if available and verb_key != "" else ""

func refresh(status_extra: String = "") -> void:
	clock_label.text = Loc.t("HUD_DAY", [WorldClock.day(), WorldClock.clock_text()]) + " · " + tr(WorldClock.START_DAY_NAME_KEYS[WorldClock.weekday()])
	var debt := GameState.total_debt()
	money_label.text = Ledger.dollars(GameState.ledger.balance) + ("   " + Loc.t("HUD_DEBT", [Ledger.dollars(debt)]) if debt > 0 else "")
	status_label.text = status_extra
	status_label.visible = status_extra != ""
	var ids := GameState.quests.active_ids()
	if ids.is_empty():
		quest_title.text = ""
		quest_text.text = ""
		return
	var q := ids[ids.size() - 1]
	quest_title.text = tr(String(GameState.quests.defs[q].title))
	var o := GameState.quests.current_objective(q)
	var t := tr(String(o.get("text", "")))
	var need := int(o.get("count", 1))
	if need > 1:
		t += " (%d/%d)" % [int(GameState.quests.states[q].obj.get(o.id, 0)), need]
	quest_text.text = "• " + t

## Average / worst frame time over the last 120 frames, and what is alive. Printed by the screenshot tour too.
func perf_text() -> String:
	if _frame_ms.is_empty():
		return ""
	var s := 0.0
	var worst := 0.0
	for v in _frame_ms:
		s += v
		worst = maxf(worst, v)
	return "FPS %d | кадр %.1f мс сер., %.1f мс макс. | вузлів %d | фіз. тіл %d | %s" % [Engine.get_frames_per_second(),
		s / _frame_ms.size(), worst, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)), RenderingServer.get_video_adapter_name()]

func _process(delta: float) -> void:
	_frame_ms.append(delta * 1000.0)
	if _frame_ms.size() > 120:
		_frame_ms.pop_front()
	if perf_label.visible and Engine.get_process_frames() % 15 == 0:
		perf_label.text = perf_text()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_label.visible = false
