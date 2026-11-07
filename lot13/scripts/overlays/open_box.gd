extends Control
## Box opening ceremony: tap the box three times, it bursts open and the items come out one by one.

const Data = preload("res://scripts/data.gd")
const CONFETTI := ["f8d448", "f28cba", "62d0e4", "72c04c", "a060dc"]

var main
var args: Dictionary = {}
var box: Dictionary = {}
var result: Dictionary = {}
var phase := "closed"
var taps := 0
var reveal_i := -1
var card_ready := false

var box_rect: TextureRect
var rays: TextureRect
var title_label: Label
var hint_label: Label
var card: Control
var flash: ColorRect
var summary: Control
var _hint_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var uid := int(args.get("uid", -1))
	var idx := Game.box_index(uid)
	if idx < 0:
		call_deferred("_close")
		return
	box = Game.boxes[idx].duplicate(true)
	add_child(UI.full(UI.color_rect(Color(0.04, 0.03, 0.07, 0.88))))

	rays = UI.tex_rect(UI.art("fx/rays"), 4)
	_center_at(rays, Vector2(256, 256), Vector2(0, -40))
	rays.pivot_offset = Vector2(128, 128)
	rays.visible = false
	add_child(rays)

	box_rect = UI.tex_rect(UI.box_tex(str(box["kind"])), 4)
	_center_at(box_rect, Vector2(128, 128), Vector2(0, -40))
	box_rect.pivot_offset = Vector2(64, 64)
	add_child(box_rect)

	title_label = UI.shadow(UI.label(L.t("open.title", {"box": L.t("box." + str(box["kind"]))}), 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 20
	title_label.offset_bottom = 80
	title_label.offset_left = 16
	title_label.offset_right = -16
	add_child(title_label)
	var paid := UI.label(L.t("open.paid", {"price": UI.money(int(box["paid"]), L.t("num.sep"))}), 13, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	paid.set_anchors_preset(Control.PRESET_TOP_WIDE)
	paid.offset_top = 76
	paid.offset_bottom = 96
	add_child(paid)

	hint_label = UI.shadow(UI.label(L.t("open.tap"), 16, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -110
	hint_label.offset_bottom = -60
	hint_label.offset_left = 16
	hint_label.offset_right = -16
	add_child(hint_label)
	_blink_hint()

	flash = UI.color_rect(Color(1, 1, 1, 0))
	add_child(UI.full(flash))
	gui_input.connect(_on_input)
	UI.pop(box_rect, 0.3, 0.35)
	Sfx.play("whoosh")


func _center_at(c: Control, sz: Vector2, off: Vector2) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = off.x - sz.x * 0.5
	c.offset_right = off.x + sz.x * 0.5
	c.offset_top = off.y - sz.y * 0.5
	c.offset_bottom = off.y + sz.y * 0.5
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _blink_hint() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	hint_label.modulate.a = 1.0
	_hint_tween = hint_label.create_tween().set_loops()
	_hint_tween.tween_property(hint_label, "modulate:a", 0.35, 0.6)
	_hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.6)


func _on_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	tap()


## One tap on the screen (also called by the automated tests).
func tap() -> void:
	match phase:
		"closed":
			_hit_box()
		"revealing":
			if card_ready:
				_next_item()


func _hit_box() -> void:
	taps += 1
	Sfx.play("thud", 0.9 + taps * 0.12)
	Game.buzz(20 + taps * 10)
	var tw := box_rect.create_tween()
	tw.tween_property(box_rect, "scale", Vector2(1.18, 0.82), 0.06)
	tw.tween_property(box_rect, "scale", Vector2(0.9, 1.12), 0.08)
	tw.tween_property(box_rect, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rt := box_rect.create_tween()
	var ang := 0.08 * taps
	rt.tween_property(box_rect, "rotation", ang, 0.05)
	rt.tween_property(box_rect, "rotation", -ang, 0.08)
	rt.tween_property(box_rect, "rotation", 0.0, 0.08)
	_particles(_box_center() + Vector2(0, 50), 10, [Color("b4b4c8"), Color("7c7c94")], 140.0, 0.6, 180.0)
	if taps >= 3:
		phase = "opening"
		var t2 := create_tween()
		t2.tween_interval(0.18)
		t2.tween_callback(_burst_open)


func _box_center() -> Vector2:
	return size * 0.5 + Vector2(0, -40)


func _burst_open() -> void:
	result = Game.open_box(int(box["uid"]))
	if result.is_empty():
		_close()
		return
	Sfx.play("open")
	Game.buzz(60)
	box_rect.texture = UI.box_tex(str(box["kind"]), true)
	UI.punch(box_rect, 0.25, 0.3)
	_flash(0.8)
	rays.visible = true
	rays.modulate = Color(1, 1, 1, 0)
	var tw := rays.create_tween()
	tw.tween_property(rays, "modulate:a", 1.0, 0.3)
	var spin := rays.create_tween().set_loops()
	spin.tween_property(rays, "rotation", TAU, 8.0).from(0.0)
	_particles(_box_center(), 30, [Color("f8d448"), Color("fff4b0"), Color("e8c08a")], 320.0, 1.0, 520.0)
	hint_label.text = L.t("open.next")
	var t2 := create_tween()
	t2.tween_interval(0.35)
	t2.tween_callback(_next_item)


func _next_item() -> void:
	card_ready = false
	phase = "revealing"
	if card != null and is_instance_valid(card):
		var old := card
		var tw := old.create_tween()
		tw.set_parallel(true)
		tw.tween_property(old, "position:y", old.position.y + 420.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(old, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(old.queue_free)
		card = null
	reveal_i += 1
	var list: Array = result["items"]
	if reveal_i >= list.size():
		_show_summary()
		return
	var it: Dictionary = list[reveal_i]
	var id := str(it["id"])
	var r: int = Data.rarity_of(id)
	var rarity := str(Data.RARITIES[r])
	card = _make_card(it, r, reveal_i == list.size() - 1 and bool(result.get("bonus", false)))
	add_child(card)
	move_child(card, flash.get_index())
	rays.modulate = Data.RARITY_COLORS[r]
	box_rect.modulate = Color(1, 1, 1, 0.35)
	card.scale = Vector2(0.15, 0.15)
	card.modulate.a = 0.0
	var tw2 := card.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(card, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(card, "modulate:a", 1.0, 0.15)
	tw2.chain().tween_callback(_card_shown)
	Sfx.play("reveal_" + rarity)
	if r >= 2:
		_particles(_box_center(), 18 + r * 10, [Data.RARITY_COLORS[r], Color.WHITE], 260.0, 1.0, 300.0)
	if r >= 3:
		_flash(0.6 if r == 3 else 0.9)
		_confetti()
		Game.buzz(80 if r == 3 else 150)
	if r == 4:
		UI.shake(card, 10.0, 0.5)
		main.toast(L.t("open.legendary"), UI.C_GOLD, "trophy")


func _card_shown() -> void:
	card_ready = true


func _make_card(it: Dictionary, r: int, bonus: bool) -> Control:
	var id := str(it["id"])
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb("slot_" + str(Data.RARITIES[r]), 14, 12, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := Vector2(270, 300)
	_center_at(p, sz, Vector2(0, -20))
	p.pivot_offset = sz * 0.5
	var v := UI.vbox(6)
	p.add_child(v)
	if bonus:
		v.add_child(UI.label(L.t("open.secret"), 14, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	var rl := UI.outlined(UI.label(L.t("rarity." + str(Data.RARITIES[r])).to_upper(), 16, Data.RARITY_COLORS[r], HORIZONTAL_ALIGNMENT_CENTER), 4)
	v.add_child(rl)
	var ic := UI.item_icon(id, 6)
	v.add_child(UI.center(ic))
	var nm := UI.shadow(UI.label(L.t("item." + id), 20, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(nm)
	var cond := float(it["cond"])
	var crow := UI.hbox(6)
	crow.add_child(UI.label(L.t(Game.cond_key(cond)) + " " + UI.pct(cond), 13, Game.cond_color(cond)))
	var cb := UI.bar(cond, Game.cond_color(cond), 10)
	UI.fill(cb)
	crow.add_child(UI.center(cb))
	cb.custom_minimum_size = Vector2(90, 10)
	v.add_child(crow)
	var value := Game.value_at(id, cond)
	v.add_child(UI.label(L.t("open.value", {"price": UI.money(value, L.t("num.sep"))}), 16, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if int(it.get("pawned", 0)) > 0:
		v.add_child(UI.label(L.t("open.pawned", {"price": UI.money(int(it["pawned"]), L.t("num.sep"))}), 12, UI.C_RED, HORIZONTAL_ALIGNMENT_CENTER, true))
	elif bool(it.get("new", false)):
		var nl := UI.outlined(UI.label(L.t("open.new"), 14, UI.C_GREEN, HORIZONTAL_ALIGNMENT_CENTER), 4)
		v.add_child(nl)
	return p


func _show_summary() -> void:
	phase = "summary"
	card_ready = false
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	hint_label.visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rays, "modulate:a", 0.25, 0.3)
	tw.tween_property(box_rect, "modulate:a", 0.0, 0.3)
	summary = UI.panel("panel", 14)
	_center_at(summary, Vector2(320, 340), Vector2(0, 10))
	add_child(summary)
	var v := UI.vbox(10)
	summary.add_child(v)
	v.add_child(UI.shadow(UI.label(L.t("open.done"), 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)))
	var g := UI.grid(4, 6)
	var total := 0
	var list: Array = result["items"]
	for it in list:
		var id := str(it["id"])
		var r: int = Data.rarity_of(id)
		var slot := UI.panel("slot_" + str(Data.RARITIES[r]), 4)
		slot.add_child(UI.center(UI.item_icon(id, 2)))
		g.add_child(slot)
		total += Game.value_at(id, float(it["cond"]))
	v.add_child(UI.center(g))
	var paid := int(result.get("paid", 0))
	var sep := L.t("num.sep")
	v.add_child(UI.label(L.t("open.total", {"value": UI.money(total, sep), "paid": UI.money(paid, sep)}), 14, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	var diff := total - paid
	v.add_child(UI.label(L.t("open.diff", {"price": ("+" if diff >= 0 else "") + UI.money(diff, sep)}), 16, UI.C_GREEN if diff >= 0 else UI.C_RED, HORIZONTAL_ALIGNMENT_CENTER))
	if diff < 0:
		v.add_child(UI.label(L.t("open.tip"), 12, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var row := UI.hbox(8)
	if not Game.boxes.is_empty():
		var nb := UI.button(L.t("open.another", {"n": Game.boxes.size()}), "green", 14, 52)
		UI.fill(nb)
		nb.pressed.connect(_open_next)
		row.add_child(nb)
	var ok := UI.button(L.t("open.great"), "gold", 16, 52)
	UI.fill(ok)
	ok.pressed.connect(_close)
	row.add_child(ok)
	v.add_child(row)
	UI.pop(summary, 0.6, 0.3)
	if Game.hint_once("after_open"):
		main.toast(L.t("hint.after_open"), UI.C_TEXT, "wrench")


func _open_next() -> void:
	Sfx.click()
	if Game.boxes.is_empty():
		_close()
		return
	var uid := int(Game.boxes[0]["uid"])
	main.close_overlay(self)
	main.open_overlay("open_box", {"uid": uid})


func _close() -> void:
	main.close_overlay(self)


func on_back() -> void:
	if phase == "summary" or phase == "closed":
		_close()
	elif phase == "revealing" and card_ready:
		_next_item()


# ------------------------------------------------------------------ effects
func _flash(alpha: float) -> void:
	flash.color = Color(1, 1, 1, alpha)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)


func _particles(pos: Vector2, amount: int, colors: Array, speed: float, life: float, gravity: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.texture = UI.art("fx/pixel")
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(colors.size()):
		offs.append(float(i) / float(maxi(1, colors.size() - 1)))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(life + 0.3)
	tw.tween_callback(p.queue_free)


func _confetti() -> void:
	var cols := []
	for c in CONFETTI:
		cols.append(Color(c))
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x * 0.5, -10)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x * 0.5, 4)
	p.amount = 60
	p.lifetime = 2.4
	p.one_shot = true
	p.explosiveness = 0.7
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 120)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.texture = UI.art("fx/pixel")
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray(cols)
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(2.8)
	tw.tween_callback(p.queue_free)
