extends Control
## Repair mini-game: a needle sweeps across a bar, tap STRIKE inside the green zone (gold = perfect).
## Three strikes; each one raises (or on a miss slightly lowers) the item's condition, up to the workbench limit.

const Data = preload("res://scripts/data.gd")
const STRIKES := 3

var main
var args: Dictionary = {}
var uid := -1
var item_id := ""
var phase := "ready"
var strike := 0
var needle := 0.0
var dir := 1.0
var speed := 1.0
var zone_c := 0.5
var good_w := 0.22
var perf_w := 0.07
var start_cond := 0.0
var cond := 0.0
var cap := 0.8
var perfects := 0

var panel: PanelContainer
var icon_rect: TextureRect
var cond_label: Label
var cond_bar: ProgressBar
var bar_ctrl: Control
var result_label: Label
var pips: Array = []
var action: Button
var close_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	uid = int(args.get("uid", -1))
	var it := Game.get_item(uid)
	if it.is_empty():
		call_deferred("_close")
		return
	item_id = str(it["id"])
	var r: int = Data.rarity_of(item_id)
	start_cond = float(it["cond"])
	cond = start_cond
	cap = Game.repair_cap()
	var lvl := Game.upgrade_level("bench")
	speed = (0.9 + 0.18 * r) * (1.0 - 0.07 * lvl)
	good_w = 0.22 + 0.03 * lvl
	perf_w = 0.07 + 0.01 * lvl
	_build()
	gui_input.connect(_on_input)
	set_process(false)
	if Game.hint_once("repair"):
		result_label.text = L.t("repair.howto")


func _build() -> void:
	add_child(UI.full(UI.color_rect(Color(0.04, 0.03, 0.07, 0.8))))
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(c))
	panel = UI.panel("panel", 14)
	panel.custom_minimum_size = Vector2(320, 0)
	c.add_child(panel)
	var v := UI.vbox(8)
	panel.add_child(v)
	var top := UI.hbox(6)
	top.add_child(UI.icon("wrench", 1))
	var tl := UI.label(L.t("repair.title"), 18, UI.C_GOLD)
	UI.fill(tl)
	top.add_child(tl)
	close_btn = UI.icon_button("close", "", "dark", 12, Vector2(40, 36), true, 1)
	close_btn.pressed.connect(_close)
	top.add_child(close_btn)
	v.add_child(top)

	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, 112)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := UI.panel("dark", 4)
	mat.set_anchors_preset(Control.PRESET_CENTER)
	mat.offset_left = -70
	mat.offset_right = 70
	mat.offset_top = -52
	mat.offset_bottom = 52
	pic.add_child(mat)
	icon_rect = UI.item_icon(item_id, 5)
	icon_rect.pivot_offset = icon_rect.custom_minimum_size * 0.5
	pic.add_child(UI.full(UI.center(icon_rect)))
	v.add_child(pic)
	v.add_child(UI.label(L.t("item." + item_id), 16, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))

	cond_label = UI.label("", 14, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(cond_label)
	cond_bar = UI.bar(cond, Game.cond_color(cond), 12)
	v.add_child(cond_bar)
	_update_cond()

	bar_ctrl = Control.new()
	bar_ctrl.custom_minimum_size = Vector2(0, 48)
	bar_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	bar_ctrl.draw.connect(_draw_bar)
	v.add_child(UI.margin(bar_ctrl, 4, 6, 4, 6))

	var prow := UI.hbox(8)
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(STRIKES):
		var pip := UI.color_rect(Color("3a3350"))
		pip.custom_minimum_size = Vector2(28, 10)
		prow.add_child(pip)
		pips.append(pip)
	v.add_child(prow)

	result_label = UI.outlined(UI.label(L.t("repair.ready", {"pct": UI.pct(cap)}), 15, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true), 3)
	result_label.custom_minimum_size = Vector2(280, 44)
	v.add_child(result_label)

	var it := Game.get_item(uid)
	action = UI.button(L.t("repair.start", {"price": UI.money(Game.repair_cost(it), L.t("num.sep"))}), "gold", 18, 62)
	action.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	action.pressed.connect(_on_action)
	v.add_child(action)
	UI.pop(panel, 0.75, 0.22)


func _update_cond() -> void:
	cond_label.text = L.t("repair.cond", {"now": UI.pct(cond), "max": UI.pct(cap)})
	cond_label.add_theme_color_override("font_color", Game.cond_color(cond))
	var tw := cond_bar.create_tween()
	tw.tween_property(cond_bar, "value", cond, 0.25)
	cond_bar.add_theme_stylebox_override("fill", UI.flat(Game.cond_color(cond)))


func _on_action() -> void:
	match phase:
		"ready":
			if not Game.pay_repair(uid):
				Sfx.play("error")
				main.toast(L.t("repair.no_money"), UI.C_RED, "coin")
				return
			Sfx.play("coin", 0.8)
			phase = "playing"
			close_btn.disabled = true
			action.text = L.t("repair.strike")
			result_label.text = L.t("repair.howto")
			_new_zone()
			needle = 0.0
			dir = 1.0
			set_process(true)
		"playing":
			strike_now()
		"done":
			Sfx.click()
			_close()


func _on_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and phase == "playing":
		strike_now()


func _new_zone() -> void:
	var half := good_w * 0.5
	zone_c = randf_range(half + 0.04, 1.0 - half - 0.04)
	bar_ctrl.queue_redraw()


func _process(delta: float) -> void:
	needle += dir * speed * delta
	if needle >= 1.0:
		needle = 1.0
		dir = -1.0
	elif needle <= 0.0:
		needle = 0.0
		dir = 1.0
	bar_ctrl.queue_redraw()


func _draw_bar() -> void:
	var w := bar_ctrl.size.x
	var h := bar_ctrl.size.y
	var inner := w - 8.0
	bar_ctrl.draw_rect(Rect2(0, 0, w, h), Color("1a1626"))
	bar_ctrl.draw_rect(Rect2(4, 4, inner, h - 8), Color("6a2836"))
	var gx := 4.0 + (zone_c - good_w * 0.5) * inner
	bar_ctrl.draw_rect(Rect2(gx, 4, good_w * inner, h - 8), Color("3f9a3f"))
	bar_ctrl.draw_rect(Rect2(gx, 4, good_w * inner, 3), Color("72c04c"))
	var px := 4.0 + (zone_c - perf_w * 0.5) * inner
	bar_ctrl.draw_rect(Rect2(px, 4, perf_w * inner, h - 8), Color("f8c848"))
	bar_ctrl.draw_rect(Rect2(px, 4, perf_w * inner, 3), Color("fff4b0"))
	for i in range(1, 10):
		bar_ctrl.draw_rect(Rect2(4.0 + inner * i / 10.0, h - 8, 2, 4), Color(0, 0, 0, 0.35))
	if phase == "playing" or phase == "done":
		var nx := 4.0 + needle * inner
		bar_ctrl.draw_rect(Rect2(nx - 4, 0, 8, h), Color("1a1626"))
		bar_ctrl.draw_rect(Rect2(nx - 2, 2, 4, h - 4), Color("f2f0f5"))


## One strike (button, tap, or automated test).
func strike_now() -> void:
	if phase != "playing":
		return
	var d := absf(needle - zone_c)
	var gain := 0.0
	var text := ""
	var color: Color = UI.C_TEXT
	var pip_color := Color("e05a60")
	var at := icon_rect.global_position + icon_rect.size * 0.5
	if d <= perf_w * 0.5:
		gain = 0.24
		perfects += 1
		text = L.t("repair.perfect")
		color = UI.C_GOLD
		pip_color = Color("f8c848")
		Sfx.play("hit_perfect")
		Game.buzz(35)
		_sparks(Color("f8d448"), 26)
	elif d <= good_w * 0.5:
		gain = 0.13
		text = L.t("repair.good")
		color = UI.C_GREEN
		pip_color = Color("72c04c")
		Sfx.play("hit_good")
		Game.buzz(20)
		_sparks(Color("dfe6ee"), 14)
	else:
		gain = -0.04
		text = L.t("repair.miss")
		color = UI.C_RED
		Sfx.play("miss")
		Game.buzz(70)
		UI.shake(panel, 6.0, 0.25)
	cond = clampf(cond + gain, 0.05, maxf(cap, start_cond))
	UI.punch(icon_rect, 0.2 if gain > 0.0 else 0.08)
	main.float_text(text, at + Vector2(0, -50), color, 24)
	result_label.text = text
	result_label.add_theme_color_override("font_color", color)
	var pip: ColorRect = pips[strike]
	pip.color = pip_color
	_update_cond()
	strike += 1
	if strike >= STRIKES:
		_finish()
	else:
		speed *= 1.1
		_new_zone()


func _finish() -> void:
	phase = "done"
	set_process(false)
	bar_ctrl.queue_redraw()
	var before := Game.value_at(item_id, start_cond)
	var after := Game.value_at(item_id, cond)
	Game.finish_repair(uid, cond, perfects)
	var sep := L.t("num.sep")
	result_label.text = L.t("repair.result", {"from": UI.pct(start_cond), "to": UI.pct(cond),
		"v1": UI.money(before, sep), "v2": UI.money(after, sep)})
	result_label.add_theme_color_override("font_color", UI.C_GREEN if cond > start_cond else UI.C_RED)
	Sfx.play("deal" if cond > start_cond else "error")
	action.text = L.t("repair.done")
	UI.style_button(action, "green", 18)
	action.disabled = true
	var tw := action.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(_enable_action)
	close_btn.disabled = false
	if perfects == STRIKES:
		main.toast(L.t("repair.flawless"), UI.C_GOLD, "star")


func _enable_action() -> void:
	action.disabled = false


func _sparks(col: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = icon_rect.global_position - global_position + icon_rect.size * 0.5
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.texture = UI.art("fx/pixel")
	p.color = col
	add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(p.queue_free)


func _close() -> void:
	main.close_overlay(self)


func on_back() -> void:
	if phase != "playing":
		_close()
