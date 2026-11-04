class_name ShopPage
extends VBoxContainer
## Головний екран: сцена крамниці, діалог клієнта, інформація про предмет, дії.

signal request_end_day
signal fx_money(text: String, color: Color, from_global: Vector2)

var view: ShopView
var name_label: Label
var type_label: Label
var hearts: HBoxContainer
var line_label: Label
var item_name_label: Label
var item_info_label: Label
var ask_label: Label
var est_label: Label
var actions: Control
var grid: GridContainer
var btn_inspect: Button
var btn_haggle: Button
var btn_buy: Button
var btn_decline: Button
var offer_box: VBoxContainer
var offer_label: Label
var offer_steps: Array[Button] = []
var btn_offer: Button
var btn_offer_back: Button
var next_box: VBoxContainer
var next_info: Label
var btn_next: Button

var offer := 0
var busy := false          # блокування на час анімацій (захист від подвійних натискань)
var _shown_uid := -1


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	view = ShopView.new()
	view.custom_minimum_size = Vector2(0, 380)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(view)

	# --- діалог
	var dp := UIKit.panel(UIKit.PANEL, UIKit.BORDER)
	dp.custom_minimum_size = Vector2(0, 150)
	add_child(dp)
	var dv := UIKit.vbox(6)
	dp.add_child(dv)
	var top := UIKit.hbox(10)
	dv.add_child(top)
	name_label = UIKit.label("", UIKit.FS, UIKit.TEXT)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	type_label = UIKit.label("", UIKit.FS_SMALL, UIKit.CYAN)
	top.add_child(type_label)
	hearts = UIKit.hbox(4)
	top.add_child(hearts)
	line_label = UIKit.label("", UIKit.FS, UIKit.TEXT, true)
	line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(line_label)

	# --- предмет
	var ip := UIKit.panel(UIKit.PANEL_2, UIKit.BORDER)
	ip.custom_minimum_size = Vector2(0, 150)
	add_child(ip)
	var ih := UIKit.hbox(12)
	ip.add_child(ih)
	var iv := UIKit.vbox(4)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(iv)
	item_name_label = UIKit.label("", UIKit.FS, UIKit.AMBER)
	iv.add_child(item_name_label)
	item_info_label = UIKit.label("", UIKit.FS_SMALL, UIKit.MUTED, true)
	iv.add_child(item_info_label)
	est_label = UIKit.label("", UIKit.FS_SMALL, UIKit.CYAN, true)
	iv.add_child(est_label)
	var pv := UIKit.vbox(0)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	ih.add_child(pv)
	var pl := UIKit.label("Ціна", UIKit.FS_SMALL, UIKit.MUTED)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(pl)
	ask_label = UIKit.pixel_label("", UIKit.FS_BIG + 4, UIKit.GREEN)
	ask_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(ask_label)

	# --- дії
	actions = Control.new()
	actions.custom_minimum_size = Vector2(0, UIKit.BTN_H * 2 + 12)
	add_child(actions)

	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	actions.add_child(grid)
	btn_inspect = UIKit.button("Перевірити", "accent")
	btn_haggle = UIKit.button("Торгуватися", "warn")
	btn_buy = UIKit.button("Купити", "primary")
	btn_decline = UIKit.button("Відмовитися", "danger")
	for b in [btn_inspect, btn_haggle, btn_buy, btn_decline]:
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	btn_inspect.pressed.connect(_on_inspect)
	btn_haggle.pressed.connect(_on_haggle)
	btn_buy.pressed.connect(_on_buy)
	btn_decline.pressed.connect(_on_decline)

	offer_box = UIKit.vbox(12)
	offer_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	actions.add_child(offer_box)
	var row1 := UIKit.hbox(8)
	row1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	offer_box.add_child(row1)
	for i in 4:
		var b := UIKit.button("", "neutral", UIKit.FS_SMALL + 2)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		offer_steps.append(b)
		b.pressed.connect(_on_step.bind(i))
		if i == 2:
			offer_label = UIKit.pixel_label("", UIKit.FS_BIG + 4, UIKit.AMBER)
			offer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			offer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			offer_label.custom_minimum_size = Vector2(150, 0)
			offer_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			row1.add_child(offer_label)
		row1.add_child(b)
	var row2 := UIKit.hbox(12)
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	offer_box.add_child(row2)
	btn_offer_back = UIKit.button("Назад", "neutral")
	btn_offer_back.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_offer_back.size_flags_stretch_ratio = 0.6
	btn_offer_back.pressed.connect(_on_offer_back)
	row2.add_child(btn_offer_back)
	btn_offer = UIKit.button("Запропонувати", "warn")
	btn_offer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_offer.pressed.connect(_on_offer)
	row2.add_child(btn_offer)

	next_box = UIKit.vbox(10)
	next_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	next_box.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(next_box)
	next_info = UIKit.label("", UIKit.FS_SMALL, UIKit.MUTED, true)
	next_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_box.add_child(next_info)
	btn_next = UIKit.button("", "pink", UIKit.FS_BIG, 110)
	btn_next.pressed.connect(_on_next)
	next_box.add_child(btn_next)

	_show_mode("grid")
	refresh(false)


func s() -> GameSession:
	return Game.session


func _show_mode(mode: String) -> void:
	grid.visible = mode == "grid"
	offer_box.visible = mode == "offer"
	next_box.visible = mode == "next"


## Оновлює весь екран зі стану сесії. animate — чи анімувати появу клієнта.
func refresh(animate: bool = false) -> void:
	var ses := s()
	var c := ses.current
	view.shop_closed = ses.day_done()
	if c.is_empty():
		_shown_uid = -1
		view.clear_customer()
		name_label.text = "Крамниця «Last Deal»"
		type_label.text = ""
		_set_hearts(0, 0)
		if ses.game_over:
			line_label.text = "Крамницю закрито через борги."
		elif ses.day_done():
			line_label.text = "Клієнтів на сьогодні більше немає. Продайте товари на складі й зачиніть крамницю."
		else:
			line_label.text = "Неон світить, двері відчинені. Хто зайде першим?"
		item_name_label.text = "—"
		item_info_label.text = "Новини: " + ses.market.news
		est_label.text = ""
		ask_label.text = ""
		_update_next_box()
		_show_mode("next")
		return
	var item: Dictionary = c["item"]
	var uid: int = item["uid"]
	if uid != _shown_uid:
		_shown_uid = uid
		view.show_customer(int(c["sprite"]), item["id"], animate)
	var t := CustomerDB.get_type(c["type"])
	name_label.text = c["name"]
	type_label.text = t["name"]
	type_label.add_theme_color_override("font_color", Color(t["color"]))
	var n: Dictionary = c["nego"]
	_set_hearts(int(n["patience"]), int(n["max_patience"]))
	line_label.text = "«" + str(c.get("line", "")) + "»"
	item_name_label.text = ItemDB.item_name(item["id"])
	var info := ""
	var demand := ses.market.get_demand(item["id"])
	var ref := Economy.round5(float(ItemDB.get_def(item["id"])["base"]) * demand * Economy.RETAIL_MARKUP)
	if c.get("inspected", false):
		info = "Стан: %s" % ItemDB.condition_label(item["condition"])
		var found: Array = c.get("found_defects", [])
		if found.is_empty():
			info += " · дефектів не знайдено"
		else:
			var names: Array = found.map(func(d): return ItemDB.defect_name(d))
			info += " · " + ", ".join(names)
		if int(c["est_low"]) == int(c["est_high"]):
			est_label.text = "Ринок дасть: %s" % UIKit.money_text(int(c["est_low"]))
		else:
			est_label.text = "Оцінка: %s – %s" % [Economy.format_money(int(c["est_low"])), UIKit.money_text(int(c["est_high"]))]
		var margin := (int(c["est_low"]) + int(c["est_high"])) / 2 - int(c["nego"]["ask"])
		est_label.text += " · %s %s" % ["вигода ≈" if margin >= 0 else "збиток ≈", Economy.format_money(absi(margin))]
	else:
		info = "Стан зі слів клієнта: %s" % ItemDB.condition_label(c["claimed_condition"])
		if item["id"] == "mystery":
			est_label.text = "Що це й скільки коштує — невідомо. Перевірте!"
		else:
			est_label.text = "Новий у продажу: ~%s · не перевірено" % UIKit.money_text(ref)
	item_info_label.text = info
	ask_label.text = UIKit.money_text(int(n["ask"]))
	ask_label.add_theme_color_override("font_color", UIKit.GREEN if ses.money >= int(n["ask"]) else UIKit.RED)

	if n["status"] == "open":
		if not offer_box.visible:
			_show_mode("grid")
		btn_inspect.disabled = c.get("inspected", false) or busy
		btn_inspect.text = "Перевірено" if c.get("inspected", false) else "Перевірити"
		var full := ses.inventory.is_full()
		btn_buy.disabled = busy or full or ses.money < int(n["ask"])
		if full:
			btn_buy.text = "Склад\nповний"
		else:
			btn_buy.text = "Купити" if ses.money >= int(n["ask"]) else "Не вистачає\nкоштів"
		btn_haggle.disabled = busy or full or ses.money <= 0
		btn_decline.disabled = busy
		if offer_box.visible:
			_update_offer()
	else:
		_update_next_box()
		_show_mode("next")


func _set_hearts(p: int, maxp: int) -> void:
	for ch in hearts.get_children():
		ch.queue_free()
	for i in maxp:
		var h := UIKit.icon_rect("res://assets/icons/heart_full.png" if i < p else "res://assets/icons/heart_empty.png", 30)
		hearts.add_child(h)


func _update_next_box() -> void:
	var ses := s()
	btn_next.disabled = busy
	if ses.game_over:
		next_info.text = "Гру завершено."
		btn_next.text = "Нова гра"
	elif ses.has_open_customer():
		return
	elif ses.customers_left() > 0:
		next_info.text = "Сьогодні ще прийде клієнтів: %d" % ses.customers_left()
		btn_next.text = "Покликати клієнта"
	else:
		next_info.text = "Оренда сьогодні: %s. Баланс: %s" % [UIKit.money_text(Economy.rent_for_day(ses.day)), UIKit.money_text(ses.money)]
		btn_next.text = "Зачинити крамницю"


# ----------------------------------------------------------------- дії
func _lock(t: float) -> void:
	busy = true
	refresh()
	await get_tree().create_timer(t).timeout
	busy = false
	refresh()


func _on_inspect() -> void:
	if busy:
		return
	var r := s().inspect()
	if r.is_empty():
		return
	Sfx.play("inspect")
	view.react("inspect")
	Game.vibrate(15)
	refresh()


func _on_haggle() -> void:
	if busy or not s().has_open_customer():
		return
	Sfx.play("click")
	var ask := s().current_ask()
	offer = mini(Economy.round5(ask * 0.75), s().money)
	offer = maxi(offer, 5)
	_show_mode("offer")
	_update_offer()


func _steps() -> Array:
	var ask := s().current_ask()
	var small := maxi(5, Economy.round5(ask * 0.03))
	var big := maxi(10, Economy.round5(ask * 0.12))
	if big <= small:
		big = small * 2
	return [-big, -small, small, big]


func _update_offer() -> void:
	var st := _steps()
	for i in 4:
		var v: int = st[i]
		offer_steps[i].text = ("+" if v > 0 else "−") + str(absi(v))
		offer_steps[i].disabled = busy or (v < 0 and offer + v < 5) or (v > 0 and (offer >= s().money or offer >= s().current_ask()))
	offer_label.text = Economy.format_money(offer)
	btn_offer.text = "Запропонувати %s" % UIKit.money_text(offer)
	btn_offer.disabled = busy or offer <= 0 or offer > s().money
	btn_offer_back.disabled = busy


func _on_step(i: int) -> void:
	var st := _steps()
	offer = clampi(offer + int(st[i]), 5, mini(s().money, s().current_ask()))
	Sfx.play("click")
	_update_offer()


func _on_offer_back() -> void:
	Sfx.play("click")
	_show_mode("grid")
	refresh()


func _on_offer() -> void:
	if busy or not s().has_open_customer():
		return
	var money_before := s().money
	var r := s().offer(offer)
	match r.get("result", ""):
		"deal":
			_after_deal(money_before)
		"counter":
			view.react("counter")
			Sfx.play("counter")
			offer = mini(offer, s().money)
			_lock(0.35)
		"reject":
			Sfx.play("deny")
			view.react("reject")
			view.shake()
			Game.vibrate(40)
			_lock(0.35)
		"leave":
			view.react("leave")
			Sfx.play("leave")
			_show_mode("next")
			view.hide_customer(false)
			_lock(0.7)
		_:
			refresh()


func _on_buy() -> void:
	if busy:
		return
	var money_before := s().money
	var r := s().buy()
	if r.get("result", "") == "deal":
		_after_deal(money_before)
	else:
		Sfx.play("deny")
		refresh()


func _after_deal(money_before: int) -> void:
	view.react("deal")
	Sfx.play("buy")
	Game.vibrate(30)
	var spent := money_before - s().money
	fx_money.emit("−" + UIKit.money_text(spent), UIKit.RED, view.item_global_pos())
	_show_mode("next")
	view.hide_customer(true)
	_lock(0.7)


func _on_decline() -> void:
	if busy:
		return
	s().decline()
	Sfx.play("leave")
	_show_mode("next")
	view.hide_customer(false)
	_lock(0.6)


func _on_next() -> void:
	if busy:
		return
	var ses := s()
	if ses.game_over:
		Game.new_game()
		return
	if ses.customers_left() > 0 and not ses.has_open_customer():
		if ses.next_customer():
			Sfx.play("bell")
			_show_mode("grid")
			busy = true
			refresh(true)
			await get_tree().create_timer(0.6).timeout
			busy = false
			refresh()
	elif ses.day_done():
		Sfx.play("click")
		request_end_day.emit()
