extends Control
## Storage: unopened boxes and every item on the shelves, as a paged grid of big tiles.

const Data = preload("res://scripts/data.gd")
const TILE_H := 126

var main
var args: Dictionary = {}
var page := 0
var filter := "all"
var col: VBoxContainer
var grid_holder: Control
var _rows := 3


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter = str(args.get("filter", "all"))
	col = UI.vbox(6)
	add_child(UI.full(UI.margin(col, 8, 8, 8, 8)))
	Game.state_changed.connect(refresh)
	resized.connect(_on_resized)
	refresh()


func _on_resized() -> void:
	var rows := _calc_rows()
	if rows != _rows:
		refresh()


func _calc_rows() -> int:
	var h := size.y
	if h <= 0.0:
		return 3
	var reserved := 52.0 + 52.0 + 40.0 + (50.0 if not Game.boxes.is_empty() else 0.0)
	return clampi(int((h - reserved) / float(TILE_H + 6)), 2, 6)


func _list() -> Array:
	var out := []
	for it in Game.items:
		if filter == "repair" and not Game.can_repair(it):
			continue
		out.append(it)
	out.sort_custom(func(a, b): return Game.market_value(a) > Game.market_value(b))
	return out


func refresh() -> void:
	_rows = _calc_rows()
	for c in col.get_children():
		c.queue_free()
	var head := UI.hbox(8)
	head.add_child(UI.icon("shelf", 2))
	var tv := UI.vbox(0)
	tv.add_child(UI.shadow(UI.label(L.t("storage.title"), 20, UI.C_GOLD)))
	var full := Game.items.size() >= Game.capacity()
	tv.add_child(UI.label(L.t("storage.slots", {"n": Game.items.size(), "max": Game.capacity()}), 12,
		UI.C_RED if full else UI.C_DIM))
	UI.fill(tv)
	head.add_child(tv)
	var fa := UI.button(L.t("storage.all"), "purple" if filter == "all" else "dark", 12, 40)
	fa.pressed.connect(_set_filter.bind("all"))
	head.add_child(fa)
	var fr := UI.button(L.t("storage.repair"), "purple" if filter == "repair" else "dark", 12, 40)
	fr.pressed.connect(_set_filter.bind("repair"))
	head.add_child(fr)
	col.add_child(head)

	if not Game.boxes.is_empty():
		var bp := UI.panel("card", 6)
		var brow := UI.hbox(8)
		bp.add_child(brow)
		brow.add_child(UI.tex_rect(UI.box_tex(str(Game.boxes[0]["kind"])), 1))
		var bl := UI.label(L.t("storage.boxes", {"n": Game.boxes.size()}), 14, UI.C_TEXT)
		UI.fill(bl)
		brow.add_child(bl)
		var ob := UI.button(L.t("storage.open"), "green", 14, 40)
		ob.pressed.connect(_open_box)
		brow.add_child(ob)
		col.add_child(bp)

	var list := _list()
	var per := _rows * 3
	var pages := maxi(1, int(ceil(float(list.size()) / float(per))))
	page = clampi(page, 0, pages - 1)
	if list.is_empty():
		var e := UI.vbox(10)
		e.size_flags_vertical = Control.SIZE_EXPAND_FILL
		e.alignment = BoxContainer.ALIGNMENT_CENTER
		e.add_child(UI.center(UI.icon("box", 4)))
		var msg := L.t("storage.empty") if filter == "all" else L.t("storage.none_repair")
		e.add_child(UI.label(msg, 15, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
		if filter == "all":
			var go := UI.button(L.t("garage.auction"), "gold", 16, 52)
			go.pressed.connect(_go_auction)
			e.add_child(UI.center(go))
		col.add_child(e)
		return
	var g := UI.grid(3, 6)
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in range(page * per, mini(list.size(), (page + 1) * per)):
		g.add_child(_tile(list[i]))
	col.add_child(g)
	if pages > 1:
		var nav := UI.hbox(8)
		nav.alignment = BoxContainer.ALIGNMENT_CENTER
		var prev := UI.icon_button("back", "", "dark", 12, Vector2(64, 44))
		prev.disabled = page <= 0
		prev.pressed.connect(_page.bind(-1))
		nav.add_child(prev)
		nav.add_child(UI.label("%d / %d" % [page + 1, pages], 16, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var next := UI.icon_button("back", "", "dark", 12, Vector2(64, 44))
		next.disabled = page >= pages - 1
		next.pressed.connect(_page.bind(1))
		_flip_icon(next)
		nav.add_child(next)
		col.add_child(nav)


func _flip_icon(b: Button) -> void:
	for n in b.find_children("*", "TextureRect", true, false):
		n.set("flip_h", true)


func _tile(it: Dictionary) -> Control:
	var id := str(it["id"])
	var r: int = Data.rarity_of(id)
	var b := UI.tile_button("slot_" + str(Data.RARITIES[r]))
	b.custom_minimum_size = Vector2(0, TILE_H)
	UI.fill(b)
	var v := UI.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := UI.item_icon(id, 3)
	v.add_child(UI.center(ic))
	var name_l := UI.label(L.t("item." + id), 11, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.clip_text = true
	v.add_child(name_l)
	var cond := float(it["cond"])
	v.add_child(UI.bar(cond, Game.cond_color(cond), 8))
	var vrow := UI.hbox(2)
	vrow.alignment = BoxContainer.ALIGNMENT_CENTER
	vrow.add_child(UI.label(UI.money(Game.market_value(it), L.t("num.sep")), 13, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if Game.can_repair(it):
		vrow.add_child(UI.icon("wrench", 1))
	v.add_child(vrow)
	b.add_child(UI.full(UI.margin(v, 6, 6, 6, 6)))
	b.pressed.connect(_open_item.bind(int(it["uid"])))
	return b


func _set_filter(f: String) -> void:
	Sfx.click()
	filter = f
	page = 0
	refresh()


func _page(d: int) -> void:
	Sfx.click()
	page += d
	refresh()


func _open_item(uid: int) -> void:
	Sfx.click()
	main.open_overlay("item", {"uid": uid})


func _open_box() -> void:
	if Game.boxes.is_empty():
		return
	Sfx.play("thud", 1.2, -4.0)
	main.open_overlay("open_box", {"uid": int(Game.boxes[0]["uid"])})


func _go_auction() -> void:
	Sfx.click()
	main.show_screen("auctions")
