extends Control
## Collection of rare items found in golden parcels and story rewards.

var detail: PanelContainer


var tab := "items"
var body: VBoxContainer
var tab_buttons := {}


func setup(data: Dictionary) -> void:
	tab = data.get("tab", "items")


func _ready() -> void:
	var col := UI.screen_frame(self, I18n.t("col_title"), false)
	var tabs := HBoxContainer.new()
	for t in ["items", "achievements", "stats"]:
		var b := UI.button(I18n.t("tab_" + t), "normal", 72)
		b.add_theme_font_size_override("font_size", 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tt: String = t
		b.pressed.connect(func(): _select(tt))
		tabs.add_child(b)
		tab_buttons[t] = b
	col.add_child(tabs)
	body = UI.scroll_column(col)
	_select(tab)


func _select(t: String) -> void:
	tab = t
	for k in tab_buttons:
		var b: Button = tab_buttons[k]
		b.add_theme_stylebox_override("normal", UI.style("ui_btn_accent" if k == t else "ui_btn"))
		b.add_theme_color_override("font_color", UI.INK if k == t else UI.PAPER)
	for c in body.get_children():
		c.queue_free()
	match t:
		"items":
			_items()
		"achievements":
			_achievements()
		_:
			_stats()


func _items() -> void:
	var owned: Dictionary = Game.profile.get("collection", {})
	var found := 0
	for id in Content.COLLECTIBLE_ORDER:
		if int(owned.get(id, 0)) > 0:
			found += 1
	body.add_child(UI.label(I18n.t("col_found", [found, Content.COLLECTIBLE_ORDER.size()]), 30, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	var eras := [[0, "era_past"], [1, "era_present"], [2, "era_future"], [-1, "era_anomaly"]]
	for e in eras:
		body.add_child(UI.label(I18n.t(e[1]), 30, UI.DEST_COLORS[e[0]] if e[0] >= 0 else UI.MAGENTA, 0, true))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		body.add_child(grid)
		for id in Content.COLLECTIBLE_ORDER:
			var c: Dictionary = Content.COLLECTIBLES[id]
			if int(c["era"]) != int(e[0]):
				continue
			var n := int(owned.get(id, 0))
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(156, 150)
			b.icon = UI.tex_scaled("it_" + id if n > 0 else "it_unknown", 6)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.text = (I18n.t("col_count", n) if n > 1 else "") if n > 0 else "?"
			b.add_theme_font_size_override("font_size", 22)
			if int(c["rarity"]) >= 2 and n > 0:
				b.add_theme_stylebox_override("normal", UI.style("ui_btn_accent" if int(c["rarity"]) == 3 else "ui_btn_cyan"))
			var cid: String = id
			b.pressed.connect(func(): _show(cid))
			grid.add_child(b)


func _achievements() -> void:
	var got := Achievements.earned(Game.profile)
	body.add_child(UI.label(I18n.t("ach_count", [got.size(), Achievements.DEFS.size()]), 30, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	for d in Achievements.DEFS:
		var done := got.has(d[0])
		var card := UI.panel("ui_panel")
		var h := HBoxContainer.new()
		card.add_child(h)
		var ic := UI.image("ic_trophy" if done else "ic_lock", 6)
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UI.wrap(UI.label(I18n.pick(d[4]), 28, UI.GOLD if done else UI.PAPER, 0, true)))
		v.add_child(UI.wrap(UI.label(I18n.pick(d[5]), 24, UI.PAPER_DIM)))
		var cur := mini(Achievements.value(Game.profile, d[1]), int(d[2]))
		var info := "%s / %s · %s" % [UI.fmt(cur), UI.fmt(int(d[2])), I18n.t("ach_reward", int(d[3]))]
		v.add_child(UI.label(info, 22, UI.GREEN if done else UI.MUTED))
		if not done:
			card.modulate = Color(1, 1, 1, 0.8)
		body.add_child(card)


func _stats() -> void:
	var p := Game.profile
	var st: Dictionary = p.get("stats", {})
	var parcels := int(st.get("parcels", 0))
	var acc := float(st.get("correct", 0)) / float(parcels) * 100.0 if parcels > 0 else 0.0
	var t := int(float(st.get("play_time", 0.0)))
	var rows := [
		["st_level", str(int(p["level"]))],
		["st_shifts", UI.fmt(int(p.get("shifts_done", 0)))],
		["st_parcels", UI.fmt(parcels)],
		["st_accuracy", "%d%%" % int(round(acc))],
		["st_combo", str(int(st.get("best_combo", 0)))],
		["st_record", UI.fmt(int(p.get("record_best", 0)))],
		["st_calm", UI.fmt(int(p.get("calm_best", 0)))],
		["st_coins", UI.fmt(int(st.get("coins_earned", 0)))],
		["st_dailies", str(int(st.get("dailies", 0)))],
		["st_hazards", str(int(st.get("hazards", 0)))],
		["st_events", str(int(st.get("events", 0)))],
		["st_time", "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]],
	]
	var card := UI.panel("ui_panel")
	var v := VBoxContainer.new()
	card.add_child(v)
	for r in rows:
		var h := HBoxContainer.new()
		var n := UI.label(I18n.t(r[0]), 28, UI.MUTED)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(UI.label(r[1], 30, UI.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, true))
		v.add_child(h)
	body.add_child(card)


func _show(id: String) -> void:
	Audio.play("click")
	if detail:
		detail.queue_free()
	var c: Dictionary = Content.COLLECTIBLES[id]
	var n := int(Game.profile.get("collection", {}).get(id, 0))
	detail = UI.panel("ui_panel_paper")
	var v := VBoxContainer.new()
	detail.add_child(v)
	var h := HBoxContainer.new()
	h.add_child(UI.image("it_" + id if n > 0 else "it_unknown", 8))
	var t := UI.wrap(UI.label(I18n.pick(c["name"]) if n > 0 else I18n.t("col_unknown"), 34, UI.INK, 0, true))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	v.add_child(h)
	if n > 0:
		var d := UI.wrap(UI.label(I18n.pick(c["desc"]), 28, UI.INK))
		d.custom_minimum_size = Vector2(540, 0)
		v.add_child(d)
	var close := UI.button(I18n.t("btn_ok"), "accent", 80)
	close.pressed.connect(func():
		detail.queue_free()
		detail = null)
	v.add_child(close)
	add_child(detail)
	detail.reset_size()
	detail.position = (get_viewport_rect().size - detail.size) / 2
	UI.pop(detail)


func on_back() -> void:
	if detail:
		detail.queue_free()
		detail = null
		return
	Game.goto("menu")
