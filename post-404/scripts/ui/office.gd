extends Control
## Upgrades, rooms, decorations, rare equipment and postal routes.

const TABS := ["machines", "rooms", "decor", "equip", "routes"]
const CONVERT_COST := 3000
const CONVERT_LEVEL := 12

var tab := "machines"
var list: VBoxContainer
var header: HBoxContainer
var tab_buttons := {}


func setup(data: Dictionary) -> void:
	tab = data.get("tab", "machines")


func _ready() -> void:
	Audio.music("menu")
	var col := UI.screen_frame(self, I18n.t("office_title"))
	header = col.get_node("Header")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t in TABS:
		var b := UI.button(I18n.t("tab_" + t), "normal", 72)
		b.add_theme_font_size_override("font_size", 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tt: String = t
		b.pressed.connect(func(): _select(tt))
		tabs.add_child(b)
		tab_buttons[t] = b
	col.add_child(tabs)
	list = UI.scroll_column(col)
	_select(tab)


func _select(t: String) -> void:
	tab = t
	for k in tab_buttons:
		var b: Button = tab_buttons[k]
		b.add_theme_stylebox_override("normal", UI.style("ui_btn_accent" if k == t else "ui_btn"))
		b.add_theme_color_override("font_color", UI.INK if k == t else UI.PAPER)
	_refresh()


func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var money: Control = header.get_node("Money")
	(money.get_node("Coins/Value") as Label).text = UI.fmt(int(Game.profile["coins"]))
	(money.get_node("Shards/Value") as Label).text = str(int(Game.profile["shards"]))
	if tab == "routes":
		for id in Content.ROUTE_ORDER:
			list.add_child(_route_card(id))
		return
	for id in Upgrades.SHOP_TABS[tab]:
		list.add_child(_card(id))
	if tab == "equip":
		list.add_child(_converter_card())


func _card(id: String) -> Control:
	var d: Dictionary = Upgrades.DEFS[id]
	var p := Game.profile
	var lvl := Upgrades.level_of(p, id)
	var mx := int(d["max"])
	var state := Upgrades.can_buy(p, id)
	var card := UI.panel("ui_panel")
	var h := HBoxContainer.new()
	card.add_child(h)
	var icon := UI.image(d["icon"], 6)
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_row := HBoxContainer.new()
	var nm := UI.wrap(UI.label(I18n.pick(d["name"]), 30, UI.AMBER if lvl > 0 else UI.PAPER, 0, true))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nm)
	if mx > 1:
		name_row.add_child(UI.label(I18n.t("lvl", [lvl, mx]), 24, UI.MUTED))
	v.add_child(name_row)
	var desc := UI.wrap(UI.label(I18n.pick(d["desc"]), 24, UI.PAPER_DIM))
	v.add_child(desc)
	var b: Button
	match state:
		"max":
			b = UI.button(I18n.t("maxed") if mx > 1 else I18n.t("owned"), "normal", 72, "ic_check")
			b.disabled = true
		"level":
			b = UI.button(I18n.t("locked_level", int(d.get("level", 1))), "normal", 72, "ic_lock")
			b.disabled = true
		"requires":
			b = UI.button(I18n.t("need_room"), "normal", 72, "ic_lock")
			b.disabled = true
		_:
			var cost := Upgrades.cost(id, lvl)
			var sh := Upgrades.shard_cost(id)
			var txt := ""
			if cost > 0:
				txt = UI.fmt(cost)
			if sh > 0:
				txt += ("  +  " if txt != "" else "") + I18n.t("n_shards", sh)
			b = UI.button(txt, "accent" if state == "ok" else "normal", 72, "ic_coin" if cost > 0 else "ic_shard")
			b.disabled = state != "ok"
			b.pressed.connect(func(): _buy(id))
	b.add_theme_font_size_override("font_size", 26)
	v.add_child(b)
	return card


func _buy(id: String) -> void:
	if Upgrades.buy(Game.profile, id):
		Audio.play("levelup")
		Game.haptic(25)
		Game.notice.emit(I18n.t("bought", I18n.pick(Upgrades.DEFS[id]["name"])))
		Game.save_now()
		Game.profile_changed.emit()
		_refresh()


func _route_card(id: String) -> Control:
	var r: Dictionary = Content.ROUTES[id]
	var p := Game.profile
	var state := Economy.can_buy_route(p, id)
	var card := UI.panel("ui_panel")
	var h := HBoxContainer.new()
	card.add_child(h)
	h.add_child(UI.image("rt_" + id, 6))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var row := HBoxContainer.new()
	var nm := UI.wrap(UI.label(I18n.pick(r["name"]), 30, UI.AMBER if state == "max" else UI.PAPER, 0, true))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)
	row.add_child(UI.label(I18n.t("route_mult", str(r["mult"])), 24, UI.GREEN))
	v.add_child(row)
	v.add_child(UI.wrap(UI.label(I18n.pick(r["desc"]), 24, UI.PAPER_DIM)))
	var b: Button
	match state:
		"max":
			b = UI.button(I18n.t("owned"), "normal", 72, "ic_check")
			b.disabled = true
		"level":
			b = UI.button(I18n.t("locked_level", int(r.get("level", 1))), "normal", 72, "ic_lock")
			b.disabled = true
		_:
			var txt := UI.fmt(int(r["cost"]))
			if int(r["shards"]) > 0:
				txt += "  +  " + I18n.t("n_shards", int(r["shards"]))
			b = UI.button(txt, "accent" if state == "ok" else "normal", 72, "ic_coin")
			b.disabled = state != "ok"
			b.pressed.connect(func():
				if Economy.buy_route(Game.profile, id):
					Audio.play("levelup")
					Game.notice.emit(I18n.t("bought", I18n.pick(r["name"])))
					Game.save_now()
					_refresh())
	b.add_theme_font_size_override("font_size", 26)
	v.add_child(b)
	return card


func _converter_card() -> Control:
	var p := Game.profile
	var card := UI.panel("ui_panel")
	var h := HBoxContainer.new()
	card.add_child(h)
	h.add_child(UI.image("ic_shard", 8))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(I18n.pick({"uk": "Хроноконвертер", "en": "Chrono Converter"}), 30, UI.PAPER, 0, true))
	v.add_child(UI.wrap(UI.label(I18n.pick({"uk": "Переплавляє монети на уламки часу. Скільки завгодно разів.",
		"en": "Melts coins into time shards. As often as you like."}), 24, UI.PAPER_DIM)))
	var b: Button
	if int(p["level"]) < CONVERT_LEVEL:
		b = UI.button(I18n.t("locked_level", CONVERT_LEVEL), "normal", 72, "ic_lock")
		b.disabled = true
	else:
		b = UI.button("%s = %s" % [UI.fmt(CONVERT_COST), I18n.t("n_shards", 1)], "accent", 72, "ic_coin")
		b.disabled = int(p["coins"]) < CONVERT_COST
		b.pressed.connect(func():
			if int(Game.profile["coins"]) >= CONVERT_COST:
				Game.profile["coins"] = int(Game.profile["coins"]) - CONVERT_COST
				Game.profile["shards"] = int(Game.profile["shards"]) + 1
				Audio.play("coin")
				Game.save_now()
				_refresh())
	b.add_theme_font_size_override("font_size", 26)
	v.add_child(b)
	return card


func on_back() -> void:
	Game.goto("menu")
