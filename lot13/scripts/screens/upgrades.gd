extends Control
## Garage upgrades: shelves, workbench, scanner, showroom, truck and the lucky cat.

const Data = preload("res://scripts/data.gd")

var main
var args: Dictionary = {}
var col: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	col = UI.vbox(6)
	add_child(UI.full(UI.margin(col, 8, 8, 8, 8)))
	Game.money_changed.connect(_on_money)
	refresh()


func _on_money(_v: int) -> void:
	refresh()


func refresh() -> void:
	for c in col.get_children():
		c.queue_free()
	var head := UI.hbox(8)
	head.add_child(UI.icon("up", 2))
	var tv := UI.vbox(0)
	tv.add_child(UI.shadow(UI.label(L.t("upgrades.title"), 20, UI.C_GOLD)))
	tv.add_child(UI.label(L.t("upgrades.level", {"n": Game.garage_level()}), 12, UI.C_DIM))
	UI.fill(tv)
	head.add_child(tv)
	col.add_child(head)
	for u in Data.UPGRADES:
		col.add_child(_row(u))


func _fmt(id: String, lvl: int) -> String:
	var u: Dictionary = Data.upgrade(id)
	var vals: Array = u["vals"]
	var v := int(vals[clampi(lvl, 0, vals.size() - 1)])
	match id:
		"bench":
			return "%d%%" % v
		"showroom", "charm":
			return "+%d%%" % v
	return str(v)


## One line: what the upgrade does now and after the next level.
func _effect_line(id: String, lvl: int, maxed: bool) -> String:
	if id == "scanner":
		if maxed:
			return L.t("up.scanner.fx%d" % lvl)
		return L.t("upgrades.next", {"fx": L.t("up.scanner.fx%d" % (lvl + 1))})
	var desc := L.t("up.%s.desc" % id)
	if maxed:
		return "%s: %s" % [desc, _fmt(id, lvl)]
	return "%s: %s » %s" % [desc, _fmt(id, lvl), _fmt(id, lvl + 1)]


func _row(u: Dictionary) -> Control:
	var id := str(u["id"])
	var lvl := Game.upgrade_level(id)
	var maxed := not Game.can_upgrade(id)
	var p := UI.panel("card", 6)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(8)
	p.add_child(row)
	row.add_child(UI.center(UI.icon(str(u["icon"]), 2)))
	var info := UI.vbox(3)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.fill(info)
	var top := UI.hbox(6)
	top.add_child(UI.label(L.t("up.%s.name" % id), 15, UI.C_GOLD))
	var pips := UI.hbox(3)
	for i in range(int(u["max"])):
		var pip := UI.color_rect(Color("72c04c") if i < lvl else Color("221d2e"))
		pip.custom_minimum_size = Vector2(9, 9)
		pips.add_child(UI.center(pip))
	top.add_child(pips)
	info.add_child(top)
	info.add_child(UI.label(_effect_line(id, lvl, maxed), 11, UI.C_TEXT if maxed else UI.C_GREEN, HORIZONTAL_ALIGNMENT_LEFT, true))
	row.add_child(info)
	var b: Button
	if maxed:
		b = UI.button(L.t("upgrades.max"), "dark", 14, 48)
		b.disabled = true
	else:
		var cost := Game.upgrade_cost(id)
		b = UI.button(UI.money(cost, L.t("num.sep")), "gold", 14, 48)
		b.disabled = cost > Game.money
		b.pressed.connect(_buy.bind(id, p))
	b.custom_minimum_size = Vector2(84, 48)
	row.add_child(UI.center(b))
	return p


func _buy(id: String, row: Control) -> void:
	if Game.buy_upgrade(id):
		Sfx.play("upgrade")
		Game.buzz(40)
		main.toast(L.t("upgrades.done", {"name": L.t("up.%s.name" % id)}), UI.C_GREEN, "up")
		main.float_text(L.t("upgrades.up"), row.global_position + Vector2(row.size.x * 0.5, 10), UI.C_GREEN, 22)
		refresh()
	else:
		Sfx.play("error")
