extends Control
## List of auction houses. Higher houses unlock with reputation level and cost an entry fee.

const Data = preload("res://scripts/data.gd")
const TIER_BOX := ["cardboard", "crate", "suitcase", "trunk", "golden"]

var main
var args: Dictionary = {}
var col: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	col = UI.vbox(6)
	add_child(UI.full(UI.margin(col, 10, 8, 10, 8)))
	refresh()


func refresh() -> void:
	for c in col.get_children():
		c.queue_free()
	var head := UI.hbox(8)
	head.add_child(UI.icon("gavel", 2))
	var tv := UI.vbox(0)
	tv.add_child(UI.shadow(UI.label(L.t("auctions.title"), 20, UI.C_GOLD)))
	tv.add_child(UI.label(L.t("auctions.sub", {"n": Game.lots_per_auction()}), 12, UI.C_DIM))
	UI.fill(tv)
	head.add_child(tv)
	col.add_child(head)
	if str(Game.event.get("id", "")) == "free_entry":
		var fe := UI.panel("dark", 6)
		fe.add_child(UI.label(L.t("auctions.free_today"), 13, UI.C_GREEN, HORIZONTAL_ALIGNMENT_CENTER, true))
		col.add_child(fe)
	for i in range(Data.AUCTIONS.size()):
		col.add_child(_card(i))


func _card(i: int) -> Control:
	var a: Dictionary = Data.AUCTIONS[i]
	var unlocked := Game.auction_unlocked(i)
	var p := UI.panel("card" if unlocked else "slot", 8)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(8)
	p.add_child(row)
	var ic := UI.tex_rect(UI.box_tex(TIER_BOX[i]), 2)
	if not unlocked:
		ic.modulate = Color(0.35, 0.33, 0.45, 1)
	row.add_child(UI.center(ic))
	var info := UI.vbox(2)
	UI.fill(info)
	info.add_child(_line(L.t("auction." + str(a["id"])), 16, UI.C_GOLD if unlocked else UI.C_DIM))
	var rng_v: Array = a["range"]
	var sep := L.t("num.sep")
	info.add_child(_line(L.t("auctions.worth", {"low": UI.money(int(rng_v[0]), sep), "high": UI.money(int(rng_v[1]), sep)}), 12, UI.C_TEXT))
	var fee := Game.auction_fee(i)
	var fee_text := L.t("auctions.free") if fee == 0 else UI.money(fee, sep)
	info.add_child(_line(L.t("auctions.meta", {"n": Game.rival_count(i), "fee": fee_text}), 12, UI.C_DIM))
	row.add_child(info)
	if unlocked:
		var go := UI.button(L.t("auctions.go"), "green", 16, 52)
		go.custom_minimum_size = Vector2(72, 52)
		go.pressed.connect(_enter.bind(i))
		row.add_child(UI.center(go))
	else:
		var lock := UI.vbox(0)
		lock.add_child(UI.center(UI.icon("lock", 2)))
		lock.add_child(UI.label(L.t("top.level", {"n": int(a["rep"])}), 12, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		lock.custom_minimum_size = Vector2(72, 0)
		row.add_child(UI.center(lock))
	return p


## A one-line label that never pushes the buttons off the screen.
func _line(text: String, size_px: int, color: Color) -> Label:
	var l := UI.label(text, size_px, color)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(40, 0)
	return l


func _enter(i: int) -> void:
	var fee := Game.auction_fee(i)
	if fee > Game.money:
		Sfx.play("error")
		main.toast(L.t("auctions.no_fee"), UI.C_RED, "coin")
		return
	if fee > 0:
		Game.spend(fee)
	Sfx.play("gavel", 1.2, -6.0)
	main.show_screen("auction", {"tier": i})
