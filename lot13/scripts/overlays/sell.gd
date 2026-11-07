extends Control
## Selling with haggling: a buyer makes an offer; accept it or ask for more. Each refusal costs patience.

const Data = preload("res://scripts/data.gd")

var main
var args: Dictionary = {}
var uid := -1
var item_id := ""
var market := 0
var max_price := 0
var offer := 0
var patience := 3
var patience_max := 3
var phase := "talk"

var panel: PanelContainer
var face_rect: TextureRect
var name_label: Label
var bubble_label: Label
var hearts_box: HBoxContainer
var buttons_box: VBoxContainer
var market_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	uid = int(args.get("uid", -1))
	var it := Game.get_item(uid)
	if it.is_empty():
		call_deferred("_close")
		return
	item_id = str(it["id"])
	_build()
	_new_buyer()
	if Game.hint_once("sell"):
		main.toast(L.t("hint.sell"), UI.C_TEXT, "tag")


func _m(v: int) -> String:
	return UI.money(v, L.t("num.sep"))


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
	var top := UI.hbox(10)
	face_rect = UI.tex_rect(UI.portrait_tex("buyer_0"), 3)
	face_rect.pivot_offset = face_rect.custom_minimum_size * 0.5
	top.add_child(face_rect)
	var tv := UI.vbox(4)
	UI.fill(tv)
	name_label = UI.shadow(UI.label("", 17, UI.C_GOLD))
	tv.add_child(name_label)
	hearts_box = UI.hbox(2)
	tv.add_child(hearts_box)
	tv.add_child(UI.label(L.t("sell.patience"), 11, UI.C_DIM))
	top.add_child(tv)
	v.add_child(top)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.sb("bubble", 10, 8, 8))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_label = UI.label("", 15, UI.C_DARK, HORIZONTAL_ALIGNMENT_LEFT, true)
	bubble_label.custom_minimum_size = Vector2(270, 44)
	bubble.add_child(bubble_label)
	v.add_child(bubble)
	var irow := UI.hbox(8)
	irow.add_child(UI.item_icon(item_id, 2))
	var iv := UI.vbox(0)
	UI.fill(iv)
	iv.add_child(UI.label(L.t("item." + item_id), 14, UI.C_TEXT))
	market_label = UI.label("", 12, UI.C_DIM)
	iv.add_child(market_label)
	irow.add_child(iv)
	v.add_child(irow)
	buttons_box = UI.vbox(8)
	v.add_child(buttons_box)
	UI.pop(panel, 0.75, 0.22)


func _new_buyer() -> void:
	var it := Game.get_item(uid)
	if it.is_empty():
		_close()
		return
	if Game.buyers_left(uid) <= 0:
		phase = "left"
		_say(L.t("sell.nobody"))
		_refresh_buttons()
		return
	Game.use_buyer(uid)
	market = Game.market_value(it)
	max_price = maxi(1, roundi(float(market) * randf_range(0.9, 1.35) * Game.buyer_mult()))
	offer = maxi(1, Game.nice_round(float(max_price) * randf_range(0.55, 0.8)))
	if offer >= max_price:
		offer = maxi(1, max_price - 1)
	patience_max = Game.buyer_patience()
	patience = patience_max
	face_rect.texture = UI.portrait_tex("buyer_%d" % (randi() % Data.BUYER_PORTRAITS))
	face_rect.modulate = Color.WHITE
	var names := L.t("buyer.names").split(",")
	name_label.text = names[randi() % names.size()].strip_edges()
	market_label.text = L.t("sell.market", {"price": _m(market)})
	phase = "talk"
	_draw_hearts()
	_say(L.t("sell.hello%d" % (randi() % 3), {"item": L.t("item." + item_id), "price": _m(offer)}))
	UI.pop(face_rect, 0.4, 0.3)
	Sfx.play("step")
	_refresh_buttons()


func _draw_hearts() -> void:
	for h in hearts_box.get_children():
		h.queue_free()
	for i in range(patience_max):
		var ic := UI.icon("heart", 1)
		if i >= patience:
			ic.modulate = Color(0.25, 0.22, 0.32, 1)
		hearts_box.add_child(ic)


func _say(text: String) -> void:
	bubble_label.text = text
	UI.punch(bubble_label, 0.05)


func _ask_price(k: float) -> int:
	var a := Game.nice_round(float(offer) * k)
	if a <= offer:
		a = offer + maxi(1, Game.bid_step(offer))
	return a


func _refresh_buttons() -> void:
	for b in buttons_box.get_children():
		b.queue_free()
	match phase:
		"talk":
			var deal := UI.button(L.t("sell.deal", {"price": _m(offer)}), "green", 18, 56)
			deal.pressed.connect(_accept)
			buttons_box.add_child(deal)
			var row := UI.hbox(8)
			var a1 := _ask_price(1.15)
			var a2 := _ask_price(1.4)
			var b1 := UI.button(L.t("sell.ask", {"price": _m(a1)}), "blue", 15, 50)
			UI.fill(b1)
			b1.pressed.connect(ask.bind(a1))
			row.add_child(b1)
			var b2 := UI.button(L.t("sell.ask", {"price": _m(a2)}), "purple", 15, 50)
			UI.fill(b2)
			b2.pressed.connect(ask.bind(a2))
			row.add_child(b2)
			buttons_box.add_child(row)
			var no := UI.button(L.t("sell.no"), "dark", 14, 44)
			no.pressed.connect(_decline)
			buttons_box.add_child(no)
		"left":
			var left := Game.buyers_left(uid)
			if left > 0 and not Game.get_item(uid).is_empty():
				var nb := UI.button(L.t("sell.next", {"n": left}), "gold", 16, 52)
				nb.pressed.connect(_new_buyer)
				buttons_box.add_child(nb)
			var cl := UI.button(L.t("close"), "dark", 14, 44)
			cl.pressed.connect(_close)
			buttons_box.add_child(cl)
		"done":
			var ok := UI.button(L.t("open.great"), "gold", 18, 56)
			ok.pressed.connect(_close)
			buttons_box.add_child(ok)


func _accept() -> void:
	if phase != "talk":
		return
	_sold(offer)


## Ask the buyer for a price (button or automated test).
func ask(price: int) -> void:
	if phase != "talk":
		return
	Sfx.click()
	if price <= max_price:
		var chance := 1.0 if float(price) <= float(max_price) * 0.9 else 0.55
		if randf() < chance:
			_sold(price)
			return
	patience -= 2 if float(price) > float(max_price) * 1.35 else 1
	_draw_hearts()
	if patience <= 0:
		phase = "left"
		_say(L.t("sell.leave%d" % (randi() % 2)))
		Sfx.play("angry")
		Game.buzz(60)
		UI.shake(face_rect, 6.0, 0.3)
		face_rect.modulate = Color(0.6, 0.6, 0.7, 1)
		_refresh_buttons()
		return
	var step := roundi(float(max_price - offer) * randf_range(0.35, 0.65))
	var new_offer := mini(max_price, Game.nice_round(float(offer + step)))
	if new_offer <= offer:
		new_offer = mini(max_price, offer + maxi(1, Game.bid_step(offer)))
	if new_offer <= offer:
		_say(L.t("sell.final", {"price": _m(offer)}))
	else:
		offer = new_offer
		_say(L.t("sell.counter%d" % (randi() % 3), {"price": _m(offer)}))
	Sfx.play("tick", 0.8)
	_refresh_buttons()


func _decline() -> void:
	Sfx.click()
	phase = "left"
	_say(L.t("sell.bye"))
	_refresh_buttons()


func _sold(price: int) -> void:
	var profit := Game.sell_item(uid, price)
	phase = "done"
	Sfx.play("cash")
	Game.buzz(50)
	var at := face_rect.global_position + face_rect.size * 0.5
	main.coin_burst(at, 7)
	main.float_text("+" + _m(price), at + Vector2(0, -40), UI.C_GOLD, 24)
	var key := "sell.result_profit" if profit >= 0 else "sell.result_loss"
	_say(L.t("sell.agree", {"price": _m(price)}) + "\n" + L.t(key, {"price": _m(absi(profit))}))
	_refresh_buttons()


func _close() -> void:
	main.close_overlay(self)


func on_back() -> void:
	if phase == "talk":
		_decline()
	else:
		_close()
