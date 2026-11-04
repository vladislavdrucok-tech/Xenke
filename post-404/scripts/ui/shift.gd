extends Control
## The sorting room: conveyor, portals, swipes, feedback. Game rules live in
## ShiftSession; this script only renders and forwards input.

const SWIPE_TRIGGER := 64.0
const BIG_K := 6.0
const BELT_K := 3.0

var mode := "shift"
var session := ShiftSession.new()
var rng := RandomNumberGenerator.new()

# layout
var W := 720.0
var H := 1280.0
var col_x := 0.0          # left edge of the 720 px play column
var pad_pos := Vector2.ZERO
var belt_y := 0.0
var tube_pos := Vector2.ZERO
var hatch_pos := Vector2.ZERO
var left_portal_pos := Vector2.ZERO
var right_portal_pos := Vector2.ZERO
var swipe_zone := Rect2()

# nodes
var world: Node2D
var fx_layer: Node2D
var ui_layer: Control
var hud_layer: Control
var backdrop: Backdrop
var portal_past: TextureRect
var portal_future: TextureRect
var portal_frames := {}
var tube: TextureRect
var tube_frames: Array
var hatch: TextureRect
var pad: TextureRect
var belt: TextureRect
var belt_frames: Array
var today_year: Label
var today_caption: Label
var timer_label: Label
var score_label: Label
var coins_label: Label
var combo_label: Label
var hearts: HBoxContainer
var banner: PanelContainer
var banner_label: Label
var clue_card: PanelContainer
var clue_label: Label
var bit_sprite: TextureRect
var bit_bubble: PanelContainer
var bit_bubble_label: Label
var bit_frames := {}
var bit_state := "idle"
var bit_state_t := 0.0
var dir_buttons := {}
var dest_labels := {}
var hint_label: Label
var hand: TextureRect
var cat_btn: TextureButton
var overlay: Control

var current_view: ParcelView
var belt_views := {}       # parcel id -> ParcelView
var _anim_t := 0.0
var _touch_start := Vector2.ZERO
var _touch_id := -1
var _dragging := false
var _swipe_fired := false
var _scanner_started := false
var _mirrored_visual := false
var _shake := 0.0
var _last_combo_tier := 1.0
var _tutorial_step := 0
var _ended := false


func setup(data: Dictionary) -> void:
	mode = data.get("mode", "shift")


func _ready() -> void:
	rng.randomize()
	Game.last_mode = mode
	var seed_value := rng.randi()
	if mode == "daily":
		seed_value = Game.today_seed()
	session.setup(mode, Game.profile, seed_value)
	_build()
	session.parcel_ready.connect(_on_parcel_ready)
	session.parcel_sorted.connect(_on_sorted)
	session.queue_changed.connect(_sync_belt)
	session.event_started.connect(_on_event_started)
	session.event_ended.connect(_on_event_ended)
	session.tip_requested.connect(_on_tip)
	session.robot_action.connect(_on_robot_action)
	session.shift_over.connect(_on_shift_over)
	Game.app_paused.connect(_on_app_paused)
	_sync_belt()
	_refresh_hud()
	Audio.music("shift")
	Audio.hum(true)
	if mode == "daily":
		_show_banner(I18n.t("mut_" + session.daily_mutator), UI.CYAN, 3.0)
	if session.rules["mirrored"]:
		_apply_mirror(true, true)
	_update_today()


func _exit_tree() -> void:
	Audio.hum(false)


# ------------------------------------------------------------------- build

func _build() -> void:
	W = get_viewport_rect().size.x
	H = get_viewport_rect().size.y
	var m := UI.safe_margins(self)
	var top: float = m["top"]
	var bottom: float = H - float(m["bottom"])
	col_x = max(0.0, (W - 720.0) / 2.0)
	var cw := minf(W, 720.0)
	var buttons_on: bool = Game.setting("buttons")
	var buttons_h := 150.0 if buttons_on else 0.0
	var hud_bottom := top + 112.0
	tube_pos = Vector2(col_x + cw / 2, hud_bottom + 128)       # centre of the tube sprite
	var buttons_top := bottom - buttons_h - 16.0
	hatch_pos = Vector2(col_x + cw / 2, buttons_top - 60)
	belt_y = hatch_pos.y - 44 - 70
	var mid_top := tube_pos.y + 128
	pad_pos = Vector2(col_x + cw / 2, (mid_top + belt_y) / 2 + 30)
	left_portal_pos = Vector2(col_x + 24 * UI.PIX + 4, pad_pos.y - 40)
	right_portal_pos = Vector2(col_x + cw - 24 * UI.PIX - 4, pad_pos.y - 40)
	swipe_zone = Rect2(0, hud_bottom, W, buttons_top - hud_bottom)

	backdrop = Backdrop.new("shift")
	backdrop.floor_y = belt_y + 40
	add_child(backdrop)
	ui_layer = Control.new()
	ui_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)
	world = Node2D.new()
	add_child(world)
	fx_layer = Node2D.new()
	add_child(fx_layer)
	hud_layer = Control.new()
	hud_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_layer)

	# Present: pneumatic tube from the ceiling
	tube_frames = UI.frames("tube_present", 4)
	tube = _sprite_rect(tube_frames[0], Vector2(40, 64) * UI.PIX, tube_pos)
	tube.position.y = hud_bottom - 20
	# portals
	portal_frames["past"] = UI.frames("portal_past", 4)
	portal_frames["future"] = UI.frames("portal_future", 4)
	portal_past = _sprite_rect(portal_frames["past"][0], Vector2(48, 88) * UI.PIX, left_portal_pos)
	portal_future = _sprite_rect(portal_frames["future"][0], Vector2(48, 88) * UI.PIX, right_portal_pos)
	# conveyor
	belt_frames = UI.frames("belt", 4)
	belt = TextureRect.new()
	belt.texture = belt_frames[0]
	belt.stretch_mode = TextureRect.STRETCH_TILE
	belt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	belt.size = Vector2(W / UI.PIX + 1, 14)
	belt.scale = Vector2.ONE * UI.PIX
	belt.position = Vector2(0, belt_y)
	belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(belt)
	# pad
	pad = _sprite_rect(UI.tex("pad"), Vector2(80, 16) * UI.PIX, pad_pos + Vector2(0, 100))
	# quarantine hatch
	hatch = _sprite_rect(UI.tex("hatch"), Vector2(64, 22) * UI.PIX, hatch_pos)
	var hazard_on := Progression.is_unlocked("hazard", int(Game.profile["level"]))
	hatch.modulate = Color.WHITE if hazard_on else Color(0.5, 0.5, 0.6, 0.6)

	# destination labels
	_dest_label(Rules.Dest.PAST, Vector2(0, 0))
	_dest_label(Rules.Dest.FUTURE, Vector2(0, 0))
	_dest_label(Rules.Dest.PRESENT, Vector2(0, 0))
	_dest_label(Rules.Dest.QUARANTINE, Vector2(0, 0))
	_place_dest_labels()
	if not _present_allowed():
		tube.modulate = Color(0.5, 0.5, 0.6, 0.6)
		dest_labels[Rules.Dest.PRESENT].modulate.a = 0.4
	if not hazard_on:
		dest_labels[Rules.Dest.QUARANTINE].modulate.a = 0.4

	_build_hud(top)
	_build_bit()
	_build_buttons(bottom - buttons_h, buttons_h, buttons_on)
	# riddle card
	clue_card = UI.panel("ui_panel_paper")
	clue_label = UI.wrap(UI.label("", 26, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	clue_label.custom_minimum_size = Vector2(320, 0)
	clue_card.add_child(clue_label)
	clue_card.visible = false
	clue_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(clue_card)
	# event banner
	banner = UI.panel("ui_panel")
	banner_label = UI.outlined(UI.label("", 30, UI.AMBER, HORIZONTAL_ALIGNMENT_CENTER, true), 4)
	banner_label.custom_minimum_size = Vector2(600, 0)
	UI.wrap(banner_label)
	banner.add_child(banner_label)
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(banner)
	# tutorial hint
	hint_label = UI.wrap(UI.outlined(UI.label("", 34, UI.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true), 8))
	hint_label.size = Vector2(min(W, 700.0), 120)
	hint_label.position = Vector2((W - hint_label.size.x) / 2, tube_pos.y + 70)
	hint_label.visible = false
	hud_layer.add_child(hint_label)
	hand = UI.image("hand", 6)
	hand.visible = false
	hud_layer.add_child(hand)
	# cat (event)
	cat_btn = TextureButton.new()
	cat_btn.texture_normal = UI.frames("cat", 4)[0]
	cat_btn.ignore_texture_size = true
	cat_btn.stretch_mode = TextureButton.STRETCH_SCALE
	cat_btn.size = Vector2(24, 16) * 5
	cat_btn.visible = false
	cat_btn.pressed.connect(_on_cat)
	add_child(cat_btn)


func _sprite_rect(t: Texture2D, sz: Vector2, center: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = sz
	r.position = center - sz / 2
	r.pivot_offset = sz / 2
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(r)
	return r


func _present_allowed() -> bool:
	return session.gen.unlocked.has("present")


func _hazard_allowed() -> bool:
	return session.gen.unlocked.has("hazard")


func _dest_label(dest: int, _pos: Vector2) -> void:
	var names := ["dir_past", "dir_present", "dir_future", "dir_quarantine"]
	var l := UI.outlined(UI.label(I18n.t(names[dest]), 26, UI.DEST_COLORS[dest], HORIZONTAL_ALIGNMENT_CENTER, true), 6)
	l.size = Vector2(200, 36)
	hud_layer.add_child(l)
	dest_labels[dest] = l


func _place_dest_labels() -> void:
	var lp: Vector2 = right_portal_pos if _mirrored_visual else left_portal_pos
	var fp: Vector2 = left_portal_pos if _mirrored_visual else right_portal_pos
	dest_labels[Rules.Dest.PAST].position = lp + Vector2(-100, 44 * UI.PIX - 4)
	dest_labels[Rules.Dest.FUTURE].position = fp + Vector2(-100, 44 * UI.PIX - 4)
	dest_labels[Rules.Dest.PRESENT].position = Vector2(tube_pos.x + 80, tube_pos.y + 40)
	dest_labels[Rules.Dest.PRESENT].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dest_labels[Rules.Dest.QUARANTINE].position = hatch_pos + Vector2(-100, 40)


func _build_hud(top: float) -> void:
	var bar := Control.new()
	bar.position = Vector2(col_x, top)
	bar.size = Vector2(minf(W, 720.0), 112)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(bar)
	var shade := ColorRect.new()
	shade.color = Color(UI.INK, 0.72)
	shade.position = Vector2(-col_x, -top)
	shade.size = Vector2(W, top + 112)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(shade)
	# TODAY board in the middle
	var board := UI.image("today_board", 3)
	board.position = Vector2(bar.size.x / 2 - 126, 10)
	board.size = Vector2(252, 90)
	bar.add_child(board)
	today_caption = UI.label(I18n.t("today"), 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	today_caption.position = board.position + Vector2(0, 8)
	today_caption.size = Vector2(252, 22)
	bar.add_child(today_caption)
	today_year = UI.outlined(UI.label("2038", 50, UI.GREEN, HORIZONTAL_ALIGNMENT_CENTER, true), 4)
	today_year.position = board.position + Vector2(0, 28)
	today_year.size = Vector2(252, 56)
	bar.add_child(today_year)
	# left: timer / score and reliability
	var left := VBoxContainer.new()
	left.position = Vector2(16, 8)
	left.size = Vector2(210, 100)
	left.add_theme_constant_override("separation", 2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(left)
	timer_label = UI.outlined(UI.label("", 40, UI.PAPER, 0, true), 6)
	left.add_child(timer_label)
	hearts = HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 4)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(hearts)
	score_label = UI.outlined(UI.label("", 24, UI.MUTED, 0), 4)
	left.add_child(score_label)
	# right: coins and pause
	var right := VBoxContainer.new()
	right.position = Vector2(bar.size.x - 226, 8)
	right.size = Vector2(210, 100)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_theme_constant_override("separation", 4)
	bar.add_child(right)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.image("ic_coin", 4))
	coins_label = UI.outlined(UI.label("0", 34, UI.GOLD, 0, true), 6)
	row.add_child(coins_label)
	right.add_child(row)
	var pause := UI.button("", "normal", 56, "ic_pause")
	pause.custom_minimum_size = Vector2(72, 56)
	pause.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause.pressed.connect(_open_pause)
	right.add_child(pause)
	# combo
	combo_label = UI.outlined(UI.label("", 36, UI.AMBER, HORIZONTAL_ALIGNMENT_CENTER, true), 6)
	combo_label.size = Vector2(220, 50)
	combo_label.position = Vector2(col_x + minf(W, 720.0) - 230, belt_y + 64)
	combo_label.pivot_offset = combo_label.size / 2
	hud_layer.add_child(combo_label)


func _build_bit() -> void:
	var lvl := Upgrades.level_of(Game.profile, "robot")
	var met: bool = (Game.profile["story"]["met"] as Array).has("bit")
	for s in ["idle", "talk", "happy", "sad", "broken"]:
		bit_frames[s] = UI.frames("bit_" + s, 4)
	bit_state = "idle" if lvl > 0 else "broken"
	bit_sprite = UI.image("bit_idle", 3)
	bit_sprite.texture = bit_frames[bit_state][0]
	bit_sprite.custom_minimum_size = Vector2(36, 40) * 3
	bit_sprite.size = Vector2(36, 40) * 3
	bit_sprite.position = Vector2(col_x + 12, belt_y + 50)
	bit_sprite.visible = met
	hud_layer.add_child(bit_sprite)
	bit_bubble = UI.panel("ui_panel_paper")
	bit_bubble_label = UI.wrap(UI.label("", 24, UI.INK))
	bit_bubble_label.custom_minimum_size = Vector2(300, 0)
	bit_bubble.add_child(bit_bubble_label)
	bit_bubble.position = Vector2(col_x + 120, belt_y + 70)
	bit_bubble.visible = false
	bit_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(bit_bubble)


func _build_buttons(y: float, h: float, on: bool) -> void:
	if not on:
		return
	var box := HBoxContainer.new()
	box.position = Vector2(col_x + 12, y)
	box.size = Vector2(minf(W, 720.0) - 24, h - 8)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	for dir in [Rules.Dir.LEFT, Rules.Dir.UP, Rules.Dir.DOWN, Rules.Dir.RIGHT]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, h - 8)
		b.icon = UI.tex_scaled(["arrow_left", "arrow_up", "arrow_right", "arrow_down"][dir], 5)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_font_override("font", UI.font(true))
		var d: int = dir
		b.button_down.connect(func(): _try_sort(d))
		box.add_child(b)
		dir_buttons[dir] = b
	_refresh_buttons()


func _refresh_buttons() -> void:
	var names := ["dir_past", "dir_present", "dir_future", "dir_quarantine"]
	for dir in dir_buttons:
		var b: Button = dir_buttons[dir]
		var dest := Rules.dir_to_dest(dir, session.rules["mirrored"])
		b.text = I18n.t(names[dest])
		b.add_theme_color_override("font_color", UI.DEST_COLORS[dest])
		var allowed := _dest_allowed(dest)
		b.disabled = not allowed
		b.modulate.a = 1.0 if allowed else 0.45


func _dest_allowed(dest: int) -> bool:
	if dest == Rules.Dest.PRESENT:
		return _present_allowed()
	if dest == Rules.Dest.QUARANTINE:
		return _hazard_allowed()
	return true


# ---------------------------------------------------------------- frame loop

func _process(delta: float) -> void:
	session.update(delta)
	_anim_t += delta
	var fi := int(_anim_t * 8.0) % 4
	portal_past.texture = portal_frames["past"][fi]
	portal_future.texture = portal_frames["future"][fi]
	tube.texture = tube_frames[int(_anim_t * 6.0) % 4]
	var belt_speed := 10.0 if session.current.is_empty() else 3.0
	belt.texture = belt_frames[int(_anim_t * belt_speed) % 4]
	bit_state_t -= delta
	if bit_state_t <= 0.0 and bit_state in ["happy", "sad", "talk"]:
		bit_state = "idle" if Upgrades.level_of(Game.profile, "robot") > 0 else "broken"
	bit_sprite.texture = bit_frames[bit_state][int(_anim_t * 4.0) % 4]
	if current_view and not session.current.is_empty():
		var p := session.current
		if p.get("urgent", false):
			current_view.urgent_left = clampf(1.0 - session.parcel_time / session.urgent_window(), 0.0, 1.0)
		if mode == "record":
			current_view.timer_left = clampf(1.0 - session.parcel_time / session.record_limit(), 0.0, 1.0)
		if p.get("damaged", false) and not _scanner_started:
			var delay: float = session.stats["scanner_delay"]
			if session.parcel_time >= delay:
				_scanner_started = true
				var tw := current_view.create_tween()
				tw.tween_property(current_view, "reveal", 1.0, 0.35)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		world.position = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 14.0 * _shake
		ui_layer.position = world.position
		if _shake <= 0.0:
			world.position = Vector2.ZERO
			ui_layer.position = Vector2.ZERO
	if session.events.is_active("cat") and cat_btn.visible:
		cat_btn.texture_normal = UI.frames("cat", 4)[int(_anim_t * 8.0) % 4]
		cat_btn.position.x -= delta * 90.0
		if cat_btn.position.x < -150:
			cat_btn.visible = false
	_refresh_hud()


func _refresh_hud() -> void:
	match mode:
		"shift", "daily":
			var t := int(ceil(session.time_left))
			timer_label.text = "%d:%02d" % [t / 60, t % 60]
			timer_label.add_theme_color_override("font_color", UI.RED if session.time_left < 10.0 else UI.PAPER)
			score_label.text = "%s %s" % [UI.fmt(session.score), I18n.t("res_score").to_lower()]
		"calm":
			timer_label.text = UI.fmt(session.score)
			score_label.text = I18n.t("btn_calm")
		"record":
			timer_label.text = UI.fmt(session.score)
			score_label.text = I18n.t("record_best", int(Game.profile.get("record_best", 0)))
		"tutorial":
			timer_label.text = "%d/8" % session.sorted_count
			score_label.text = ""
	coins_label.text = UI.fmt(session.coins)
	var want := session.max_reliability if (mode == "shift" or mode == "record") else 0
	if hearts.get_child_count() != want:
		for c in hearts.get_children():
			c.queue_free()
		for i in want:
			hearts.add_child(UI.image("ic_heart", 4))
	for i in hearts.get_child_count():
		var hc: TextureRect = hearts.get_child(i)
		hc.texture = UI.tex("ic_heart" if i < session.reliability else "ic_heart_empty")
	if session.combo >= 2:
		var m := session.combo_mult()
		if m > 1.0:
			combo_label.text = "x%s · %d" % [_mult_text(m), session.combo]
		else:
			combo_label.text = "%s %d" % [I18n.t("combo"), session.combo]
		combo_label.visible = true
	else:
		combo_label.visible = false


func _mult_text(m: float) -> String:
	return str(int(m)) if is_equal_approx(m, round(m)) else ("%.1f" % m)


func _update_today() -> void:
	var y := int(session.rules["present_year"])
	today_year.text = str(y)
	today_year.add_theme_color_override("font_color", UI.GREEN if y == Rules.BASE_YEAR else UI.MAGENTA)


# ------------------------------------------------------------------- belt

func _belt_slot(i: int) -> Vector2:
	return Vector2(col_x + minf(W, 720.0) / 2 + 150 + i * 120, belt_y + 4)


func _sync_belt() -> void:
	var preview_n: int = int(session.stats.get("preview", 0))
	var ids := {}
	for i in session.queue.size():
		var p: Dictionary = session.queue[i]
		ids[p["id"]] = true
		var v: ParcelView = belt_views.get(p["id"])
		var target := _belt_slot(i)
		var show := i < preview_n
		if v == null:
			v = ParcelView.new().setup(p, BELT_K, show)
			v.position = Vector2(W + 80, target.y)
			world.add_child(v)
			belt_views[p["id"]] = v
		else:
			v.show_year = show
			v.queue_redraw()
		var tw := v.create_tween()
		tw.tween_property(v, "position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var cur_id = session.current.get("id", -1)
	for id in belt_views.keys():
		if not ids.has(id) and id != cur_id:
			var v: ParcelView = belt_views[id]
			belt_views.erase(id)
			var tw := v.create_tween()
			tw.tween_property(v, "modulate:a", 0.0, 0.2)
			tw.tween_callback(v.queue_free)


func _on_parcel_ready(p: Dictionary) -> void:
	_scanner_started = false
	var v: ParcelView = belt_views.get(p["id"])
	belt_views.erase(p["id"])
	if v == null:
		v = ParcelView.new().setup(p, BELT_K, true)
		v.position = _belt_slot(0)
		world.add_child(v)
	v.show_year = true
	current_view = v
	var target := pad_pos
	var tw := v.create_tween().set_parallel(true)
	tw.tween_property(v, "position", target, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "k", BIG_K, 0.22)
	tw.tween_method(func(_x): v.queue_redraw(), 0.0, 1.0, 0.22)
	Audio.play("lift", 1.0, -6.0)
	# riddle text
	if p.get("riddle", "") != "":
		clue_label.text = I18n.pick(Content.RIDDLES[p["riddle"]])
		clue_card.visible = true
		clue_card.reset_size()
		clue_card.position = Vector2(pad_pos.x - clue_card.size.x / 2, pad_pos.y + 120)
		UI.pop(clue_card)
	else:
		clue_card.visible = false
	_tutorial_hint(p)


func _tutorial_hint(p: Dictionary) -> void:
	if mode != "tutorial":
		hint_label.visible = false
		hand.visible = false
		return
	var tip: String = p.get("tip", "")
	if tip == "" and session.sorted_count == 3:
		tip = "tut_free"
	if tip == "":
		hint_label.visible = session.sorted_count < 3
		hand.visible = false
		return
	hint_label.text = I18n.t(tip)
	hint_label.visible = true
	UI.pop(hint_label)
	if tip in ["tut_past", "tut_future"] and Game.setting("swipe_hints"):
		hand.visible = true
		var dir := -1.0 if tip == "tut_past" else 1.0
		var start := pad_pos + Vector2(-30, 40)
		hand.position = start
		var tw := hand.create_tween().set_loops(4)
		tw.tween_property(hand, "position", start + Vector2(dir * 200, 0), 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(hand, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func(): hand.position = start)
		tw.tween_property(hand, "modulate:a", 1.0, 0.15)
	else:
		hand.visible = false


# ------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if overlay != null or session.paused or session.over:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and swipe_zone.has_point(event.position):
			_touch_id = event.index
			_touch_start = event.position
			_dragging = true
			_swipe_fired = false
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			_dragging = false
			if not _swipe_fired and current_view:
				var tw := current_view.create_tween().set_parallel(true)
				tw.tween_property(current_view, "position", pad_pos, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(current_view, "rotation", 0.0, 0.15)
	elif event is InputEventScreenDrag and _dragging and event.index == _touch_id and not _swipe_fired:
		var d: Vector2 = event.position - _touch_start
		if current_view and not session.current.is_empty():
			current_view.position = pad_pos + d.limit_length(56.0)
			current_view.rotation = clampf(d.x / 900.0, -0.12, 0.12)
		if d.length() >= SWIPE_TRIGGER:
			_swipe_fired = true
			var dir: int
			if abs(d.x) > abs(d.y):
				dir = Rules.Dir.RIGHT if d.x > 0 else Rules.Dir.LEFT
			else:
				dir = Rules.Dir.DOWN if d.y > 0 else Rules.Dir.UP
			_try_sort(dir)


func _unhandled_input(event: InputEvent) -> void:
	if overlay != null:
		return
	if event.is_action_pressed("ui_left"):
		_try_sort(Rules.Dir.LEFT)
	elif event.is_action_pressed("ui_right"):
		_try_sort(Rules.Dir.RIGHT)
	elif event.is_action_pressed("ui_up"):
		_try_sort(Rules.Dir.UP)
	elif event.is_action_pressed("ui_down"):
		_try_sort(Rules.Dir.DOWN)
	elif event.is_action_pressed("ui_cancel"):
		_open_pause()


func _try_sort(dir: int) -> void:
	if overlay != null or session.paused or session.over or session.current.is_empty():
		return
	var dest := Rules.dir_to_dest(dir, session.rules["mirrored"])
	if not _dest_allowed(dest):
		# Directions that are not open yet are ignored, never punished.
		if current_view:
			var tw := current_view.create_tween()
			tw.tween_property(current_view, "position", pad_pos + Vector2(8, 0), 0.04)
			tw.tween_property(current_view, "position", pad_pos - Vector2(8, 0), 0.06)
			tw.tween_property(current_view, "position", pad_pos, 0.04)
		Audio.play("blip", 0.7)
		return
	session.sort(dir)


# --------------------------------------------------------------- feedback

func _dest_point(dest: int) -> Vector2:
	match dest:
		Rules.Dest.PAST:
			return right_portal_pos if session.rules["mirrored"] else left_portal_pos
		Rules.Dest.FUTURE:
			return left_portal_pos if session.rules["mirrored"] else right_portal_pos
		Rules.Dest.PRESENT:
			return tube_pos + Vector2(0, 90)
		_:
			return hatch_pos


func _dest_node(dest: int) -> Control:
	match dest:
		Rules.Dest.PAST:
			return portal_past
		Rules.Dest.FUTURE:
			return portal_future
		Rules.Dest.PRESENT:
			return tube
		_:
			return hatch


func _on_sorted(r: Dictionary) -> void:
	var v := current_view
	current_view = null
	clue_card.visible = false
	var dest: int = r["dest"]
	var correct: int = r["correct"]
	var fly_to := _dest_point(dest) if dest >= 0 else pad_pos + Vector2(0, 400)
	if v:
		var tw := v.create_tween().set_parallel(true)
		var dur := 0.2
		if dest == Rules.Dest.QUARANTINE:
			tw.tween_property(v, "position", fly_to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tw.tween_property(v, "position", fly_to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(v, "rotation", (0.6 if fly_to.x > pad_pos.x else -0.6), dur)
		tw.tween_property(v, "scale", Vector2.ONE * 0.25, dur)
		tw.tween_property(v, "modulate:a", 0.0, dur).set_delay(dur * 0.6)
		tw.chain().tween_callback(v.queue_free)
	var sfx_by_dest := {Rules.Dest.PAST: "portal", Rules.Dest.FUTURE: "portal", Rules.Dest.PRESENT: "tube", Rules.Dest.QUARANTINE: "quarantine"}
	if dest >= 0:
		Audio.play(sfx_by_dest[dest], 0.9 if dest == Rules.Dest.PAST else 1.1, -3.0)
	Audio.play("swipe", rng.randf_range(0.9, 1.1), -6.0)
	if r["ok"]:
		Audio.play("stamp", rng.randf_range(0.95, 1.05))
		Audio.play("ok", 1.0 + minf(session.combo, 30) * 0.01)
		_flash_dest(dest, UI.DEST_COLORS[dest])
		_burst(fly_to, UI.DEST_COLORS[dest], 8)
		_float_text("+%d" % int(r["coins"]), fly_to + Vector2(0, -60), UI.GOLD)
		Game.haptic(12)
		var tier := session.combo_mult()
		if tier > _last_combo_tier:
			Audio.play("combo")
			UI.pop(combo_label, 1.4)
			_float_text("x%s!" % _mult_text(tier), pad_pos + Vector2(0, -150), UI.AMBER, 52)
		_last_combo_tier = tier
		if r["urgent_hit"]:
			_float_text(I18n.t("fb_urgent"), pad_pos + Vector2(0, -110), UI.RED, 30)
		if r["series_complete"]:
			Audio.play("levelup", 1.2)
			_float_text(I18n.t("fb_series", int(r["coins"])), pad_pos + Vector2(0, -190), UI.CYAN, 34)
		if r["collectible"] != "":
			Audio.play("levelup")
			var nm := I18n.pick(Content.COLLECTIBLES[r["collectible"]]["name"])
			_float_text(I18n.t("fb_found", nm), pad_pos + Vector2(0, -230), UI.GOLD, 34)
		if int(r["shard"]) > 0:
			_float_text(I18n.t("fb_shard"), hatch_pos + Vector2(0, -80), UI.CYAN, 30)
		if r.get("repaired", false):
			_float_text(I18n.t("fb_repair"), Vector2(col_x + 200, 150), UI.RED, 28)
		if r["robot"]:
			_bit_say(I18n.t("fb_robot"), "happy")
		elif rng.randf() < 0.07:
			_bit_say(I18n.bit_line("ok", rng), "happy")
	else:
		Audio.play("error")
		Game.haptic(45)
		if not Game.setting("reduce_motion"):
			_shake = 1.0
		_flash_pad(false)
		_flash_dest(correct, Color.WHITE)
		var names := ["dir_past", "dir_present", "dir_future", "dir_quarantine"]
		var key := "fb_timeout" if r["timeout"] else "fb_wrong"
		_float_text(I18n.t(key, I18n.t(names[correct])), pad_pos + Vector2(0, -140), UI.RED, 32)
		if r["shield"]:
			_float_text(I18n.t("fb_shield"), pad_pos + Vector2(0, -190), UI.CYAN, 30)
		elif not r["life_lost"] and mode == "shift":
			_float_text(I18n.t("fb_free"), pad_pos + Vector2(0, -190), UI.MAGENTA, 26)
		_bit_say(I18n.bit_line("err", rng), "sad")
		_last_combo_tier = session.combo_mult()
	if mode == "tutorial":
		hint_label.visible = false
		hand.visible = false


func _flash_dest(dest: int, col: Color) -> void:
	var n := _dest_node(dest)
	var tw := n.create_tween()
	n.modulate = col.lightened(0.4) * 1.6
	tw.tween_property(n, "modulate", Color.WHITE, 0.35)
	var s := n.scale
	n.scale = s * 1.06
	n.create_tween().tween_property(n, "scale", Vector2.ONE, 0.2)


func _flash_pad(ok: bool) -> void:
	pad.texture = UI.tex("pad_ok" if ok else "pad_bad")
	var tw := pad.create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func(): pad.texture = UI.tex("pad"))


func _burst(pos: Vector2, col: Color, n: int) -> void:
	if Game.setting("reduce_motion"):
		return
	for i in n:
		var s := Sprite2D.new()
		s.texture = UI.tex("fx_spark" if i % 2 == 0 else "fx_star")
		s.modulate = col
		s.position = pos
		s.scale = Vector2.ONE * rng.randf_range(2.0, 3.5)
		fx_layer.add_child(s)
		var a := rng.randf() * TAU
		var dist := rng.randf_range(50, 120)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", pos + Vector2(cos(a), sin(a)) * dist, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(s.queue_free)


func _float_text(text: String, pos: Vector2, col: Color, size: int = 36) -> void:
	var l := UI.outlined(UI.label(text, size, col, HORIZONTAL_ALIGNMENT_CENTER, true), 6)
	l.size = Vector2(520, size * 1.4)
	l.position = pos - Vector2(260, size * 0.7)
	l.position.x = clampf(l.position.x, 0.0, W - 520.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _bit_say(text: String, state: String = "talk") -> void:
	if not bit_sprite.visible or Upgrades.level_of(Game.profile, "robot") == 0:
		return
	bit_state = state
	bit_state_t = 1.6
	bit_bubble_label.text = text
	bit_bubble.visible = true
	bit_bubble.reset_size()
	UI.pop(bit_bubble)
	var tw := bit_bubble.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(bit_bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): bit_bubble.visible = false)


func _show_banner(text: String, col: Color, dur: float) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", col)
	banner.visible = true
	banner.reset_size()
	banner.position = Vector2((W - banner.size.x) / 2, tube_pos.y + 140)
	UI.pop(banner)
	var tw := banner.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): banner.visible = false)


# ------------------------------------------------------------------- events

func _on_event_started(ev: Dictionary) -> void:
	Audio.play("event")
	var id: String = ev["id"]
	match id:
		"golden":
			_show_banner(I18n.t("ev_golden"), UI.GOLD, 2.0)
			coins_label.add_theme_color_override("font_color", Color("fff08a"))
		"calendar":
			_show_banner(I18n.t("ev_calendar", int(ev["data"]["present_year"])), UI.MAGENTA, 2.4)
			_update_today()
			UI.pop(today_year, 1.6)
		"mirror":
			_show_banner(I18n.t("ev_mirror"), UI.CYAN, 2.4)
			_apply_mirror(true)
		"cat":
			_show_banner(I18n.t("ev_cat"), UI.AMBER, 1.8)
			cat_btn.visible = true
			cat_btn.position = Vector2(W + 20, belt_y - 64)
			Audio.play("meow")
		"storm":
			_show_banner(I18n.t("ev_storm"), UI.MAGENTA, 2.0)
			var tw := backdrop.create_tween().set_loops(6)
			tw.tween_property(backdrop, "modulate", Color(1.2, 0.9, 1.3), 0.4)
			tw.tween_property(backdrop, "modulate", Color.WHITE, 0.4)
	_refresh_buttons()


func _on_event_ended(id: String) -> void:
	match id:
		"golden":
			coins_label.add_theme_color_override("font_color", UI.GOLD)
		"calendar":
			_update_today()
			_show_banner(I18n.t("ev_end"), UI.GREEN, 1.4)
		"mirror":
			_apply_mirror(false)
			_show_banner(I18n.t("ev_end"), UI.GREEN, 1.4)
		"cat":
			cat_btn.visible = false
	_refresh_buttons()


func _apply_mirror(on: bool, instant: bool = false) -> void:
	_mirrored_visual = on
	var past_target := (right_portal_pos if on else left_portal_pos) - portal_past.size / 2
	var fut_target := (left_portal_pos if on else right_portal_pos) - portal_future.size / 2
	if instant:
		portal_past.position = past_target
		portal_future.position = fut_target
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(portal_past, "position", past_target, 0.5).set_trans(Tween.TRANS_BACK)
		tw.tween_property(portal_future, "position", fut_target, 0.5).set_trans(Tween.TRANS_BACK)
	_place_dest_labels()
	_refresh_buttons()


func _on_cat() -> void:
	var n := session.tap_cat()
	if n > 0:
		Audio.play("meow", 1.2)
		_float_text(I18n.t("fb_cat"), cat_btn.position + Vector2(40, -40), UI.CYAN, 30)
		cat_btn.visible = false


func _on_robot_action(_kind: String, coins: int) -> void:
	_float_text("+%d" % coins, bit_sprite.position + Vector2(54, -10), UI.GOLD, 26)


# --------------------------------------------------------------- overlays

func _on_tip(mech: String) -> void:
	session.paused = true
	var seen: Array = Game.profile["seen_tips"]
	if not seen.has(mech):
		seen.append(mech)
		Game.mark_dirty()
	var col := VBoxContainer.new()
	var head := HBoxContainer.new()
	var pt := UI.image("pt_bit", 3)
	head.add_child(pt)
	var title := UI.wrap(UI.label(I18n.t("mech_" + mech), 36, UI.AMBER, 0, true))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	col.add_child(head)
	var body := UI.wrap(UI.label(I18n.t("tip_" + mech), 30))
	body.custom_minimum_size = Vector2(560, 0)
	col.add_child(body)
	var ok := UI.button(I18n.t("btn_ok"), "accent", 96)
	col.add_child(ok)
	_open_overlay(col)
	Audio.play("bell")
	ok.pressed.connect(func():
		_close_overlay()
		session.paused = false)


func _open_pause() -> void:
	if overlay != null or session.over:
		return
	session.paused = true
	var col := VBoxContainer.new()
	col.add_child(UI.label(I18n.t("paused"), 44, UI.AMBER, HORIZONTAL_ALIGNMENT_CENTER, true))
	var resume := UI.button(I18n.t("btn_resume"), "accent", 100)
	resume.pressed.connect(func():
		_close_overlay()
		session.paused = false)
	col.add_child(resume)
	var buttons_toggle := UI.button("%s: %s" % [I18n.t("set_buttons"), I18n.t("on" if Game.setting("buttons") else "off")], "normal", 84)
	buttons_toggle.pressed.connect(func():
		Game.set_setting("buttons", not Game.setting("buttons"))
		buttons_toggle.text = "%s: %s" % [I18n.t("set_buttons"), I18n.t("on" if Game.setting("buttons") else "off")])
	col.add_child(buttons_toggle)
	var end := UI.button(I18n.t("btn_end_shift"), "normal", 90)
	end.pressed.connect(func():
		_close_overlay()
		session.paused = false
		session.finish(mode == "calm" or mode == "tutorial"))
	col.add_child(end)
	_open_overlay(col)


func _open_overlay(content: Control) -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(UI.INK, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var p := UI.panel("ui_panel")
	p.add_child(content)
	content.custom_minimum_size = Vector2(min(W - 80, 600), 0)
	overlay.add_child(p)
	p.reset_size()
	p.position = (get_viewport_rect().size - p.size) / 2
	p.resized.connect(func(): p.position = (get_viewport_rect().size - p.size) / 2)
	UI.pop(p)
	# Wrapped labels know their height only after a layout pass.
	await get_tree().process_frame
	if is_instance_valid(p):
		p.reset_size()
		p.position = (get_viewport_rect().size - p.size) / 2


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _on_app_paused() -> void:
	if not session.over and overlay == null:
		_open_pause()


func on_back() -> void:
	if overlay != null and not session.paused:
		return
	if overlay != null:
		_close_overlay()
		session.paused = false
	else:
		_open_pause()


func _on_shift_over(summary: Dictionary) -> void:
	if _ended:
		return
	_ended = true
	Audio.hum(false)
	Audio.play("bell" if summary["completed"] else "fail")
	var out := Game.finish_shift(summary)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(func(): Game.goto("results", {"summary": summary, "out": out}))


func _refresh_queue_for_test() -> void:
	session._refresh_queue()
	_update_today()
