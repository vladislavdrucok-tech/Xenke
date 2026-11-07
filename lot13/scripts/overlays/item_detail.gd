extends Control
## Item card: condition, value now and after repair, demand, and the actions repair / sell / pawn.

const Data = preload("res://scripts/data.gd")

var main
var args: Dictionary = {}
var uid := -1
var panel: PanelContainer
var holder: CenterContainer
var _first := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	uid = int(args.get("uid", -1))
	add_child(UI.full(UI.color_rect(Color(0.04, 0.03, 0.07, 0.75))))
	holder = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(holder))
	gui_input.connect(_on_input)
	Game.state_changed.connect(refresh)
	refresh()


func _on_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if panel != null and not panel.get_global_rect().has_point(mb.global_position):
			_close()


func refresh() -> void:
	var it := Game.get_item(uid)
	if it.is_empty():
		_close()
		return
	if panel != null:
		panel.queue_free()
	var id := str(it["id"])
	var r: int = Data.rarity_of(id)
	var cond := float(it["cond"])
	var sep := L.t("num.sep")
	panel = UI.panel("panel", 14)
	panel.custom_minimum_size = Vector2(316, 0)
	holder.add_child(panel)
	var v := UI.vbox(8)
	panel.add_child(v)

	var top := UI.hbox(6)
	var rl := UI.label(L.t("rarity." + str(Data.RARITIES[r])), 13, Data.RARITY_COLORS[r])
	UI.fill(rl)
	top.add_child(rl)
	top.add_child(UI.label(L.t("cat." + str(Data.item(id)["cat"])), 12, UI.C_DIM))
	var x := UI.icon_button("close", "", "dark", 12, Vector2(40, 36), true, 1)
	x.pressed.connect(_close)
	top.add_child(x)
	v.add_child(top)

	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, 104)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if r >= 2:
		var rays := UI.tex_rect(UI.art("fx/rays"), 2)
		rays.modulate = Data.RARITY_COLORS[r]
		rays.pivot_offset = Vector2(64, 64)
		pic.add_child(UI.full(UI.center(rays)))
		var spin := rays.create_tween().set_loops()
		spin.tween_property(rays, "rotation", TAU, 10.0).from(0.0)
	pic.add_child(UI.full(UI.center(UI.item_icon(id, 5))))
	v.add_child(pic)
	v.add_child(UI.shadow(UI.label(L.t("item." + id), 20, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)))

	var crow := UI.hbox(6)
	crow.add_child(UI.label(L.t("item.cond", {"state": L.t(Game.cond_key(cond)), "pct": UI.pct(cond)}), 13, Game.cond_color(cond)))
	var cb := UI.bar(cond, Game.cond_color(cond), 10)
	UI.fill(cb)
	crow.add_child(UI.center(cb))
	cb.custom_minimum_size = Vector2(80, 10)
	v.add_child(crow)

	var value := Game.market_value(it)
	v.add_child(UI.label(L.t("item.value", {"price": UI.money(value, sep)}), 18, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if Game.can_repair(it):
		var after := Game.value_at(id, Game.repair_cap())
		v.add_child(UI.label(L.t("item.after", {"price": UI.money(after, sep), "pct": UI.pct(Game.repair_cap())}), 13, UI.C_GREEN, HORIZONTAL_ALIGNMENT_CENTER, true))
	var trend := Game.trend_of(id)
	if absf(trend - 1.0) > 0.01:
		v.add_child(UI.label(L.t("item.demand", {"pct": "%+d%%" % roundi((trend - 1.0) * 100.0)}), 12, UI.C_GREEN if trend > 1.0 else UI.C_RED, HORIZONTAL_ALIGNMENT_CENTER))
	var cost := int(it.get("paid", 0)) + int(it.get("fixed", 0))
	v.add_child(UI.label(L.t("item.cost", {"price": UI.money(cost, sep)}), 12, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var rb: Button
	if Game.can_repair(it):
		var rc := Game.repair_cost(it)
		rb = UI.icon_button("wrench", L.t("item.repair", {"price": UI.money(rc, sep)}), "blue", 15, Vector2(0, 52), false, 1)
		rb.disabled = rc > Game.money
		rb.pressed.connect(_repair)
	else:
		rb = UI.icon_button("check", L.t("item.maxed", {"pct": UI.pct(Game.repair_cap())}), "dark", 13, Vector2(0, 52), false, 1)
		rb.disabled = true
	v.add_child(rb)
	var left := Game.buyers_left(uid)
	var sb: Button
	if left > 0:
		sb = UI.icon_button("tag", L.t("item.sell", {"n": left}), "green", 15, Vector2(0, 52), false, 1)
		sb.pressed.connect(_sell)
	else:
		sb = UI.icon_button("tag", L.t("item.no_buyers"), "dark", 13, Vector2(0, 52), false, 1)
		sb.disabled = true
	v.add_child(sb)
	var pb := UI.button(L.t("item.pawn", {"price": UI.money(Game.pawn_price(it), sep)}), "dark", 13, 44)
	pb.pressed.connect(_pawn)
	v.add_child(pb)
	if _first:
		_first = false
		UI.pop(panel, 0.75, 0.22)


func _repair() -> void:
	Sfx.click()
	main.open_overlay("repair", {"uid": uid})


func _sell() -> void:
	Sfx.click()
	main.open_overlay("sell", {"uid": uid})


func _pawn() -> void:
	Sfx.click()
	var it := Game.get_item(uid)
	if it.is_empty():
		return
	main.popup(L.t("pawn.title"), L.t("pawn.text", {"item": L.t("item." + str(it["id"])),
		"price": UI.money(Game.pawn_price(it), L.t("num.sep"))}),
		[[L.t("pawn.yes"), "red", _do_pawn], [L.t("cancel"), "dark", null]])


func _do_pawn() -> void:
	var p := Game.pawn_item(uid)
	if p > 0:
		Sfx.play("coin")
		main.toast(L.t("pawn.done", {"price": UI.money(p, L.t("num.sep"))}), UI.C_GOLD, "coin")


func _close() -> void:
	main.close_overlay(self)
