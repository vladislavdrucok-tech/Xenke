extends Control
## Collection book of all 40 items (each find raises sale prices a little) and long-term goals.

const Data = preload("res://scripts/data.gd")

var main
var args: Dictionary = {}
var tab := "book"
var col: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab = str(args.get("tab", "goals" if Game.claimable_goals() > 0 else "book"))
	col = UI.vbox(6)
	add_child(UI.full(UI.margin(col, 8, 8, 8, 8)))
	refresh()


func refresh() -> void:
	for c in col.get_children():
		c.queue_free()
	var tabs := UI.hbox(6)
	var tb := UI.icon_button("book", L.t("coll.tab_book"), "purple" if tab == "book" else "dark", 14, Vector2(0, 48), false, 1)
	UI.fill(tb)
	tb.pressed.connect(_set_tab.bind("book"))
	tabs.add_child(tb)
	var n := Game.claimable_goals()
	var gl := L.t("coll.tab_goals") + (" (%d)" % n if n > 0 else "")
	var tg := UI.icon_button("trophy", gl, "purple" if tab == "goals" else "dark", 14, Vector2(0, 48), false, 1)
	UI.fill(tg)
	tg.pressed.connect(_set_tab.bind("goals"))
	tabs.add_child(tg)
	col.add_child(tabs)
	if tab == "book":
		_build_book()
	else:
		_build_goals()


func _set_tab(t: String) -> void:
	Sfx.click()
	tab = t
	refresh()


func _build_book() -> void:
	var head := UI.vbox(0)
	head.add_child(UI.shadow(UI.label(L.t("coll.found", {"n": Game.found.size(), "max": Data.ITEM_ORDER.size()}), 18, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)))
	head.add_child(UI.label(L.t("coll.bonus", {"n": roundi(Game.expertise_bonus() * 100.0)}), 12, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(head)
	var g := UI.grid(5, 4)
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for id in Data.ITEM_ORDER:
		var sid := str(id)
		var r: int = Data.rarity_of(sid)
		var b := UI.tile_button("slot_" + str(Data.RARITIES[r]))
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UI.fill(b)
		var ic := UI.item_icon(sid, 2)
		if not Game.found.has(sid):
			ic.modulate = Color(0, 0, 0, 0.55)
		var c := UI.center(ic)
		b.add_child(UI.full(c))
		b.pressed.connect(_info.bind(sid))
		g.add_child(b)
	col.add_child(g)


func _info(id: String) -> void:
	Sfx.click()
	var r: int = Data.rarity_of(id)
	var rname := L.t("rarity." + str(Data.RARITIES[r]))
	if not Game.found.has(id):
		main.toast(L.t("coll.unknown", {"r": rname}), Data.RARITY_COLORS[r], "lock")
		return
	var best := int(Game.found[id])
	var text := "%s • %s\n%s: %s" % [rname, L.t("cat." + str(Data.item(id)["cat"])), L.t("coll.base"),
		UI.money(Game.item_base(id), L.t("num.sep"))]
	if best > 0:
		text += "\n" + L.t("coll.best", {"price": UI.money(best, L.t("num.sep"))})
	else:
		text += "\n" + L.t("coll.not_sold")
	main.popup(L.t("item." + id), text, [[L.t("ok"), "gold", null]], {"item": id})


func _build_goals() -> void:
	var done := Game.goals_done.size()
	col.add_child(UI.label(L.t("goals.done", {"n": done, "max": Data.GOALS.size()}), 14, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var shown := 0
	for g in Data.GOALS:
		if Game.goals_done.has(str(g["id"])):
			continue
		if shown >= 6:
			break
		col.add_child(_goal_row(g))
		shown += 1
	if shown == 0:
		var e := UI.label(L.t("goals.all"), 16, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
		e.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(e)
	var st := UI.panel("dark", 8)
	var sv := UI.vbox(2)
	st.add_child(sv)
	var sep := L.t("num.sep")
	sv.add_child(UI.label(L.t("stats.line1", {"earned": UI.money(int(Game.stats["earned"]), sep), "best": UI.money(int(Game.stats["best_sale"]), sep)}), 12, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	sv.add_child(UI.label(L.t("stats.line2", {"boxes": int(Game.stats["boxes"]), "sold": int(Game.stats["sold"]), "repairs": int(Game.stats["repairs"])}), 12, UI.C_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	col.add_child(st)


func _goal_row(g: Dictionary) -> Control:
	var id := str(g["id"])
	var target := int(g["n"])
	var prog := mini(Game.goal_progress(g), target)
	var is_ready := Game.goal_ready(g)
	var p := UI.panel("card" if is_ready else "panel", 6)
	var row := UI.hbox(8)
	p.add_child(row)
	row.add_child(UI.center(UI.icon("trophy" if is_ready else "star", 1)))
	var info := UI.vbox(2)
	UI.fill(info)
	info.add_child(UI.label(L.t("goal." + id), 13, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	var brow := UI.hbox(6)
	var bar := UI.bar(float(prog) / float(maxi(1, target)), Color("a060dc"), 8)
	UI.fill(bar)
	brow.add_child(UI.center(bar))
	bar.custom_minimum_size = Vector2(90, 8)
	var sep := L.t("num.sep")
	var ptxt := "%s/%s" % [UI.money(prog, sep), UI.money(target, sep)] if str(g["kind"]) == "earned" else "%d/%d" % [prog, target]
	brow.add_child(UI.label(ptxt, 11, UI.C_DIM))
	info.add_child(brow)
	row.add_child(info)
	var reward := UI.money(int(g["reward"]), sep)
	if is_ready:
		var b := UI.button(L.t("goals.claim", {"price": reward}), "green", 12, 44)
		b.custom_minimum_size = Vector2(92, 44)
		b.pressed.connect(_claim.bind(id, p))
		row.add_child(UI.center(b))
	else:
		row.add_child(UI.label(reward, 13, UI.C_GOLD))
	return p


func _claim(id: String, from: Control) -> void:
	var r := Game.claim_goal(id)
	if r > 0:
		Sfx.play("cash")
		Game.buzz(40)
		main.coin_burst(from.global_position + from.size * 0.5, 8)
		main.toast(L.t("goals.claimed", {"price": UI.money(r, L.t("num.sep"))}), UI.C_GOLD, "trophy")
		refresh()
