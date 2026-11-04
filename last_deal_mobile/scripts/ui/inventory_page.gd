class_name InventoryPage
extends VBoxContainer
## Склад і продаж на ринку.

signal fx_money(text: String, color: Color, from_global: Vector2)

var header: Label
var news: Label
var list: VBoxContainer
var scroll: ScrollContainer
var sell_all: Button
var _selling := {}   # uid -> true, поки йде анімація (захист від подвійного натискання)


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var hp := UIKit.panel()
	add_child(hp)
	var hv := UIKit.vbox(4)
	hp.add_child(hv)
	header = UIKit.label("", UIKit.FS, UIKit.AMBER, true)
	hv.add_child(header)
	news = UIKit.label("", UIKit.FS_SMALL, UIKit.CYAN, true)
	hv.add_child(news)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = UIKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	sell_all = UIKit.button("Продати все з прибутком", "primary", UIKit.FS, 88)
	sell_all.pressed.connect(_on_sell_profitable)
	add_child(sell_all)


func refresh() -> void:
	var ses := Game.session
	var inv := ses.inventory
	header.text = "Склад: %d / %d · ринкова вартість %s" % [inv.count(), Inventory.MAX_ITEMS, UIKit.money_text(inv.total_market_value(ses.market))]
	news.text = "Новини ринку: " + ses.market.news
	for ch in list.get_children():
		list.remove_child(ch)
		ch.queue_free()
	if inv.count() == 0:
		var el := UIKit.label("Склад порожній. Купуйте речі в клієнтів дешевше, ніж за них дасть ринок.", UIKit.FS, UIKit.MUTED, true)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(el)
	var items: Array = inv.items.duplicate()
	items.sort_custom(func(a, b): return (ses.sell_price(a) - int(a["bought_price"])) > (ses.sell_price(b) - int(b["bought_price"])))
	var profitable := 0
	for it in items:
		list.add_child(_row(it))
		if ses.sell_price(it) > int(it["bought_price"]):
			profitable += 1
	sell_all.disabled = profitable == 0 or ses.game_over
	sell_all.text = "Продати все з прибутком (%d)" % profitable if profitable > 0 else "Немає товарів із прибутком"


func _row(it: Dictionary) -> Control:
	var ses := Game.session
	var p := UIKit.panel(UIKit.PANEL_2)
	var h := UIKit.hbox(12)
	p.add_child(h)
	var icon := UIKit.icon_rect(ItemDB.icon_path(it["id"]), 84)
	h.add_child(icon)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label(ItemDB.item_name(it["id"]), UIKit.FS, UIKit.TEXT))
	var cond := ItemDB.condition_label(float(it["condition"]))
	var defs: Array = it.get("defects", [])
	var dtxt := "без дефектів" if defs.is_empty() else ", ".join(defs.map(func(d): return ItemDB.defect_name(d)))
	v.add_child(UIKit.label("%s · %s" % [cond, dtxt], UIKit.FS_SMALL, UIKit.MUTED, true))
	var price := ses.sell_price(it)
	var profit := price - int(it["bought_price"])
	var tr := ses.market.trend(it["id"])
	var arrow := " ▲" if tr > 0 else (" ▼" if tr < 0 else "")
	var pl := UIKit.label("Куплено: %s · Попит %d%%%s" % [UIKit.money_text(int(it["bought_price"])), int(round(ses.market.get_demand(it["id"]) * 100)), arrow], UIKit.FS_SMALL,
		UIKit.GREEN if tr > 0 else (UIKit.RED if tr < 0 else UIKit.MUTED), true)
	v.add_child(pl)
	var b := UIKit.button("Продати\n%s" % UIKit.money_text(price), "primary" if profit >= 0 else "danger", UIKit.FS_SMALL + 2, 96)
	b.custom_minimum_size.x = 190
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	var pr := UIKit.label(("+" if profit >= 0 else "") + Economy.format_money(profit), UIKit.FS_SMALL, UIKit.GREEN if profit >= 0 else UIKit.RED)
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bv := UIKit.vbox(2)
	bv.add_child(b)
	bv.add_child(pr)
	h.add_child(bv)
	var uid: int = int(it["uid"])
	b.pressed.connect(_on_sell.bind(uid, b))
	return p


func _on_sell(uid: int, b: Button) -> void:
	if _selling.has(uid):
		return
	_selling[uid] = true
	b.disabled = true
	var r := Game.session.sell(uid)
	if r.is_empty():
		_selling.erase(uid)
		refresh()
		return
	Sfx.play("coin")
	Game.vibrate(20)
	fx_money.emit("+" + UIKit.money_text(int(r["price"])), UIKit.GREEN, b.get_global_rect().get_center())
	_selling.erase(uid)
	refresh()


func _on_sell_profitable() -> void:
	var ses := Game.session
	var total := 0
	for it in ses.inventory.items.duplicate():
		if ses.sell_price(it) > int(it["bought_price"]):
			var r := ses.sell(int(it["uid"]))
			if not r.is_empty():
				total += int(r["price"])
	if total > 0:
		Sfx.play("coin")
		Game.vibrate(30)
		fx_money.emit("+" + UIKit.money_text(total), UIKit.GREEN, sell_all.get_global_rect().get_center())
	refresh()
