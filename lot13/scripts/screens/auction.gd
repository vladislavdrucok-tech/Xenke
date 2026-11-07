extends Control
## A live auction: several lots, rival bidders with personalities, a resetting countdown, lot hints.

const Data = preload("res://scripts/data.gd")
const BID_TIME := 3.2
const START_TIME := 4.0

var main
var args: Dictionary = {}

var tier := 0
var lots: Array = []
var lot_i := -1
var lot: Dictionary = {}
var price := 0
var leader := ""
var countdown := 0.0
var phase := "intro"
var rivals: Array = []
var won: Array = []
var spent := 0
var _call := 0
var _glow_tw: Tween

var stage_area: Control
var stage: Control
var box_rect: TextureRect
var glow_rect: TextureRect
var gavel_rect: TextureRect
var bubble: PanelContainer
var bubble_label: Label
var header_label: Label
var leave_button: Button
var hint_grid: GridContainer
var rival_row: HBoxContainer
var rival_cards := {}
var price_label: Label
var leader_label: Label
var timer_bar: ProgressBar
var timer_fill: StyleBoxFlat
var bid_button: Button
var pass_button: Button
var summary_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier = int(args.get("tier", 0))
	_build()
	for i in range(Game.lots_per_auction()):
		lots.append(Game.make_lot(tier))
	for id in Game.pick_rivals(tier):
		rivals.append({"id": str(id), "max": 0, "out": false, "think": 1.0})
	_build_rivals()
	set_process(false)
	call_deferred("_next_lot")
	if Game.hint_once("auction"):
		main.toast(L.t("hint.auction"), UI.C_TEXT, "gavel")


# ------------------------------------------------------------------ layout
func _build() -> void:
	var col := UI.vbox(0)
	add_child(UI.full(col))
	var head := UI.panel("dark", 6)
	var hrow := UI.hbox(6)
	head.add_child(hrow)
	header_label = UI.label("", 14, UI.C_GOLD)
	UI.fill(header_label)
	hrow.add_child(header_label)
	leave_button = UI.button(L.t("auction.leave"), "red", 12, 36)
	leave_button.pressed.connect(_ask_leave)
	hrow.add_child(leave_button)
	col.add_child(head)

	stage_area = Control.new()
	stage_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_area.clip_contents = true
	stage_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_area.custom_minimum_size = Vector2(0, 150)
	col.add_child(stage_area)
	stage_area.add_child(UI.full(UI.color_rect(Color("2a1830"))))
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(180, 150)
	stage.scale = Vector2(2, 2)
	stage_area.add_child(stage)
	_stage_tex(UI.art("auction/stage"), Vector2.ZERO)
	_stage_tex(UI.art("auction/podium"), Vector2(134, 92))
	_stage_tex(UI.portrait_tex("auctioneer"), Vector2(142, 68))
	gavel_rect = _stage_tex(UI.icon_tex("gavel"), Vector2(126, 74))
	gavel_rect.pivot_offset = Vector2(14, 14)
	glow_rect = _stage_tex(UI.art("fx/glow"), Vector2(58, 58))
	glow_rect.scale = Vector2(2, 2)
	glow_rect.pivot_offset = Vector2(16, 16)
	glow_rect.position = Vector2(74, 74)
	glow_rect.visible = false
	box_rect = _stage_tex(UI.box_tex("cardboard"), Vector2(74, 74))
	stage_area.resized.connect(_layout_stage)

	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.sb("bubble", 8, 6, 6))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_label = UI.label("", 13, UI.C_DARK, HORIZONTAL_ALIGNMENT_LEFT, true)
	bubble_label.custom_minimum_size = Vector2(190, 0)
	bubble.add_child(bubble_label)
	bubble.position = Vector2(8, 8)
	stage_area.add_child(bubble)

	var hp := UI.panel("panel", 6)
	hint_grid = UI.grid(2, 4)
	hp.add_child(hint_grid)
	col.add_child(UI.margin(hp, 6, 4, 6, 2))

	rival_row = UI.hbox(6)
	rival_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(UI.margin(rival_row, 6, 2, 6, 2))

	var bp := UI.panel("dark", 8)
	var bcol := UI.vbox(6)
	bp.add_child(bcol)
	var prow := UI.hbox(6)
	price_label = UI.shadow(UI.label("", 28, UI.C_GOLD))
	UI.fill(price_label)
	prow.add_child(price_label)
	leader_label = UI.label("", 14, UI.C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	prow.add_child(leader_label)
	bcol.add_child(prow)
	timer_bar = UI.bar(0.0, Color("72c04c"), 10)
	timer_fill = UI.flat(Color("72c04c"))
	timer_bar.add_theme_stylebox_override("fill", timer_fill)
	bcol.add_child(timer_bar)
	var brow := UI.hbox(8)
	pass_button = UI.button(L.t("auction.pass_btn"), "dark", 15, 62)
	pass_button.custom_minimum_size = Vector2(104, 62)
	pass_button.pressed.connect(_on_pass)
	brow.add_child(pass_button)
	bid_button = UI.button("", "gold", 20, 62)
	bid_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	UI.fill(bid_button)
	bid_button.pressed.connect(_on_bid)
	brow.add_child(bid_button)
	bcol.add_child(brow)
	col.add_child(bp)


func _stage_tex(t: Texture2D, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.position = pos
	if t != null:
		r.size = t.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(r)
	return r


func _layout_stage() -> void:
	var area := stage_area.size
	stage.position = Vector2(floorf((area.x - 360.0) * 0.5), area.y - 300.0)


func _build_rivals() -> void:
	for r in rivals:
		var id := str(r["id"])
		var p := UI.panel("card", 4)
		p.custom_minimum_size = Vector2(100, 0)
		var v := UI.vbox(0)
		p.add_child(v)
		var status := UI.label("", 13, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(status)
		var face := UI.tex_rect(UI.portrait_tex(id), 2)
		v.add_child(UI.center(face))
		v.add_child(UI.label(L.t("rival." + id), 11, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		rival_row.add_child(p)
		rival_cards[id] = {"panel": p, "status": status, "face": face}


# ------------------------------------------------------------------ lot flow
func _next_lot() -> void:
	lot_i += 1
	if lot_i >= lots.size():
		_show_summary()
		return
	lot = lots[lot_i]
	price = int(lot["start"])
	leader = ""
	_call = 0
	for r in rivals:
		r["out"] = false
		r["max"] = _rival_max(str(r["id"]))
		r["think"] = randf_range(0.9, 2.2)
		_rival_status(str(r["id"]), "", UI.C_DIM)
		var card: Dictionary = rival_cards[str(r["id"])]
		card["face"].modulate = Color.WHITE
	header_label.text = L.t("auction.header", {"name": L.t("auction." + str(Data.auction(tier)["id"])),
		"n": lot_i + 1, "total": lots.size()})
	_fill_hints(false)
	price_label.text = L.t("auction.start", {"price": _m(price)})
	leader_label.text = L.t("auction.no_bids")
	leader_label.add_theme_color_override("font_color", UI.C_DIM)
	timer_bar.value = 1.0
	# the box arrives on the pedestal
	var many := int(lot["count"]) >= 4
	var k := 1.5 if many else 1.0
	box_rect.texture = UI.box_tex(str(lot["kind"]))
	box_rect.scale = Vector2(k, k)
	box_rect.modulate = Color.WHITE
	var target := Vector2(90.0 - 16.0 * k, 106.0 - 32.0 * k)
	box_rect.position = Vector2(200, target.y)
	glow_rect.visible = false
	phase = "intro"
	_update_buttons()
	Sfx.play("whoosh")
	var tw := create_tween()
	tw.tween_property(box_rect, "position", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_after_intro)
	_say(L.t("auction.call.open", {"n": lot_i + 1, "box": L.t("box." + str(lot["kind"])), "price": _m(price)}))


func _after_intro() -> void:
	if Game.upgrade_level("scanner") >= 2 or bool(lot.get("golden", false)):
		var best := int(lot["best"])
		glow_rect.modulate = Data.RARITY_COLORS[best] * Color(1, 1, 1, 0.75)
		glow_rect.visible = best >= 1 or bool(lot.get("golden", false))
		if _glow_tw != null and _glow_tw.is_valid():
			_glow_tw.kill()
		_glow_tw = glow_rect.create_tween().set_loops()
		_glow_tw.tween_property(glow_rect, "scale", Vector2(2.4, 2.4), 0.6).set_trans(Tween.TRANS_SINE)
		_glow_tw.tween_property(glow_rect, "scale", Vector2(2.0, 2.0), 0.6).set_trans(Tween.TRANS_SINE)
	phase = "bidding"
	countdown = START_TIME
	_update_buttons()
	set_process(true)


func _rival_max(id: String) -> int:
	var d: Dictionary = Data.RIVALS[id]
	var m: Array = d["mult"]
	var v := float(lot["value"]) * randf_range(0.8, 1.15) * randf_range(float(m[0]), float(m[1]))
	var likes: Array = d["likes"]
	if likes.has(str(lot["theme"])):
		v *= 1.2
	if bool(lot.get("golden", false)):
		v *= 1.08
	v *= Game.rival_bonus() * float(Data.auction(tier).get("rival_k", 1.0))
	return int(v)


func _process(delta: float) -> void:
	if phase != "bidding":
		return
	countdown -= delta
	var total := BID_TIME if leader != "" else START_TIME
	var frac := clampf(countdown / total, 0.0, 1.0)
	timer_bar.value = frac
	timer_fill.bg_color = Color("72c04c") if frac > 0.6 else (Color("f8d448") if frac > 0.3 else Color("e05a60"))
	if leader != "":
		if countdown < 2.1 and _call == 0:
			_call = 1
			_say(L.t("auction.call.once", {"price": _m(price)}))
			Sfx.play("tick")
		elif countdown < 1.05 and _call == 1:
			_call = 2
			_say(L.t("auction.call.twice", {"price": _m(price)}))
			Sfx.play("tick", 1.2)
	for r in rivals:
		r["think"] = float(r["think"]) - delta
		if float(r["think"]) <= 0.0:
			_rival_think(r)
	if countdown <= 0.0:
		_resolve()


func next_bid() -> int:
	return price if leader == "" else price + Game.bid_step(price)


func _rival_think(r: Dictionary) -> void:
	var id := str(r["id"])
	var d: Dictionary = Data.RIVALS[id]
	var style := str(d["style"])
	r["think"] = randf_range(0.45, 1.3) * (0.6 if style == "fast" else 1.0)
	if bool(r["out"]) or leader == id:
		return
	var nb := next_bid()
	if nb > int(r["max"]):
		r["out"] = true
		_rival_status(id, L.t("auction.pass"), UI.C_DIM)
		var card: Dictionary = rival_cards[id]
		card["face"].modulate = Color(0.55, 0.55, 0.65, 1)
		return
	if style == "sniper" and leader != "" and countdown > 1.4:
		return
	if style == "cautious" and randf() < 0.3 and countdown > 1.0:
		return
	if randf() < float(d["aggr"]) or countdown < 1.2:
		_place_bid(id, nb)


func _place_bid(who: String, amount: int) -> void:
	var prev := leader
	price = amount
	leader = who
	countdown = BID_TIME
	_call = 0
	price_label.text = _m(price)
	UI.punch(price_label, 0.18)
	if who == "you":
		Sfx.play("bid")
		Game.buzz(15)
		leader_label.text = L.t("auction.you_lead")
		leader_label.add_theme_color_override("font_color", UI.C_GREEN)
		_say(L.t("auction.call.you", {"price": _m(price)}))
	else:
		Sfx.play("bid", 0.85)
		if prev == "you":
			Sfx.play("outbid", 1.0, -3.0)
			Game.buzz(40)
			UI.shake(price_label, 4.0, 0.25)
		leader_label.text = L.t("auction.leads", {"name": L.t("rival." + who)})
		leader_label.add_theme_color_override("font_color", UI.C_RED)
		_rival_status(who, _m(price), UI.C_GOLD)
		var card: Dictionary = rival_cards[who]
		UI.punch(card["panel"], 0.1)
		_say(L.t("auction.call.bid", {"price": _m(price), "name": L.t("rival." + who)}))
	for r in rivals:
		if str(r["id"]) != who:
			r["think"] = maxf(float(r["think"]), randf_range(0.5, 1.4))
	_update_buttons()


func _on_bid() -> void:
	if phase != "bidding" or leader == "you":
		return
	var nb := next_bid()
	if nb > Game.money:
		Sfx.play("error")
		main.toast(L.t("auction.no_money"), UI.C_RED, "coin")
		return
	_place_bid("you", nb)


func _on_pass() -> void:
	if phase != "bidding" or leader == "you":
		return
	Sfx.click()
	_simulate_rest()
	_resolve()


func _simulate_rest() -> void:
	for i in range(300):
		var nb := next_bid()
		var cands := []
		for r in rivals:
			if bool(r["out"]):
				continue
			if int(r["max"]) < nb:
				r["out"] = true
				continue
			if str(r["id"]) != leader:
				cands.append(r)
		if cands.is_empty():
			break
		var pick: Dictionary = cands[randi() % cands.size()]
		price = nb
		leader = str(pick["id"])
	if leader != "" and leader != "you":
		price_label.text = _m(price)
		_rival_status(leader, _m(price), UI.C_GOLD)


func _resolve() -> void:
	phase = "sold"
	set_process(false)
	timer_bar.value = 0.0
	_update_buttons()
	var tw := create_tween()
	if leader == "":
		_say(L.t("auction.call.none"))
		Sfx.play("error", 0.8, -6.0)
		tw.tween_property(box_rect, "modulate:a", 0.0, 0.5)
	else:
		Sfx.play("gavel")
		Game.buzz(50)
		var gt := gavel_rect.create_tween()
		gt.tween_property(gavel_rect, "rotation", -0.7, 0.08)
		gt.tween_property(gavel_rect, "rotation", 0.25, 0.08)
		gt.tween_property(gavel_rect, "rotation", 0.0, 0.15)
		if leader == "you":
			if Game.spend(price):
				Game.add_box(lot, price)
				Game.add_xp(3)
				won.append({"kind": str(lot["kind"]), "price": price})
				spent += price
				_say(L.t("auction.call.sold_you", {"price": _m(price)}))
				main.float_text("-" + _m(price), price_label.global_position + Vector2(60, 0), UI.C_RED, 18)
				tw.tween_property(box_rect, "position:y", 200.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.5)
			else:
				_say(L.t("auction.call.none"))
		else:
			_say(L.t("auction.call.sold", {"price": _m(price), "name": L.t("rival." + leader)}))
			tw.tween_property(box_rect, "position:x", -80.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.5)
	_fill_hints(true)
	tw.tween_interval(1.6)
	tw.tween_callback(_next_lot)


# ------------------------------------------------------------------ hints and texts
func _hint(icon_name: String, text: String, color: Color = Color("f2f0f5"), item_id: String = "") -> void:
	var row := UI.hbox(4)
	if item_id != "":
		row.add_child(UI.item_icon(item_id, 1))
	else:
		row.add_child(UI.icon(icon_name, 1))
	var l := UI.label(text, 12, color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI.fill(l)
	row.add_child(l)
	UI.fill(row)
	hint_grid.add_child(row)


func _fill_hints(reveal: bool) -> void:
	for c in hint_grid.get_children():
		c.queue_free()
	var n := int(lot["count"])
	var weight_key := "weight.light" if n <= 2 else ("weight.medium" if n <= 4 else "weight.heavy")
	var scanner := Game.upgrade_level("scanner")
	_hint("box", L.t("box." + str(lot["kind"])))
	_hint("hand", L.t(weight_key))
	var lot_theme := str(lot["theme"])
	_hint("tag", L.t("hint.label", {"cat": L.t("cat." + lot_theme) if lot_theme != "" else L.t("cat.mixed")}))
	_hint("magnifier", L.t("hint.count", {"n": str(n) if scanner >= 1 else "?"}))
	if reveal:
		_hint("coin", L.t("hint.real", {"value": _m(int(lot["value"]))}), UI.C_GOLD)
	else:
		_hint("coin", L.t("hint.estimate", {"low": _m(int(lot["low"])), "high": _m(int(lot["high"]))}), UI.C_GOLD)
	if scanner >= 4 and str(lot["peek"]) != "":
		var pid := str(lot["peek"])
		_hint("", L.t("item." + pid), Data.RARITY_COLORS[Data.rarity_of(pid)], pid)
	elif scanner >= 2:
		var best := int(lot["best"])
		_hint("sparkle", L.t("hint.glint", {"r": L.t("rarity." + str(Data.RARITIES[best]))}), Data.RARITY_COLORS[best])
	else:
		_hint("sparkle", L.t("hint.glint", {"r": "?"}), UI.C_DIM)


func _say(text: String) -> void:
	bubble_label.text = text
	UI.pop(bubble, 0.85, 0.18)


func _rival_status(id: String, text: String, color: Color) -> void:
	if not rival_cards.has(id):
		return
	var card: Dictionary = rival_cards[id]
	var l: Label = card["status"]
	l.text = text if text != "" else "—"
	l.add_theme_color_override("font_color", color)


func _update_buttons() -> void:
	var nb := next_bid()
	pass_button.disabled = phase != "bidding" or leader == "you"
	leave_button.disabled = phase == "bidding" and leader == "you"
	if phase != "bidding" and phase != "intro":
		bid_button.disabled = true
		bid_button.text = L.t("auction.wait")
	elif leader == "you":
		bid_button.disabled = true
		bid_button.text = L.t("auction.leading")
	elif nb > Game.money:
		bid_button.disabled = true
		bid_button.text = L.t("auction.no_money_short")
	else:
		bid_button.disabled = phase != "bidding"
		bid_button.text = L.t("auction.bid", {"price": _m(nb)})


func _m(v: int) -> String:
	return UI.money(v, L.t("num.sep"))


# ------------------------------------------------------------------ leaving and summary
func _ask_leave() -> void:
	if phase == "summary":
		_finish()
		return
	if phase == "bidding" and leader == "you":
		return
	Sfx.click()
	main.popup(L.t("auction.leave_title"), L.t("auction.leave_text"),
		[[L.t("auction.leave"), "red", _leave_now], [L.t("cancel"), "dark", null]])


func _leave_now() -> void:
	set_process(false)
	phase = "summary"
	_show_summary()


func on_back() -> bool:
	_ask_leave()
	return true


func _show_summary() -> void:
	phase = "summary"
	set_process(false)
	if summary_layer != null:
		return
	summary_layer = Control.new()
	add_child(UI.full(summary_layer))
	summary_layer.add_child(UI.full(UI.color_rect(Color(0.04, 0.03, 0.07, 0.8))))
	var p := UI.panel("panel", 14)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.shadow(UI.label(L.t("auction.over"), 22, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)))
	if won.is_empty():
		v.add_child(UI.label(L.t("auction.won_none"), 15, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		v.add_child(UI.label(L.t("auction.won", {"n": won.size(), "price": _m(spent)}), 15, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
		var row := UI.hbox(4)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for w in won:
			row.add_child(UI.tex_rect(UI.box_tex(str(w["kind"])), 1.0 if won.size() > 5 else 2.0))
		v.add_child(row)
		v.add_child(UI.label(L.t("auction.go_open"), 13, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var b := UI.button(L.t("auction.home"), "gold", 18, 56)
	b.pressed.connect(_finish)
	v.add_child(b)
	p.custom_minimum_size = Vector2(300, 0)
	var c := UI.full(CenterContainer.new())
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(p)
	summary_layer.add_child(c)
	UI.pop(p, 0.6, 0.3)
	Sfx.play("deal" if not won.is_empty() else "click")


func _finish() -> void:
	Sfx.click()
	Game.end_day()
	main.show_screen("garage")
	if Game.pending_event:
		main.call_deferred("show_event")
