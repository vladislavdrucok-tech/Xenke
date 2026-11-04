extends Control
## Collection of rare items found in golden parcels and story rewards.

var detail: PanelContainer


func _ready() -> void:
	var col := UI.screen_frame(self, I18n.t("col_title"), false)
	var owned: Dictionary = Game.profile.get("collection", {})
	var found := 0
	for id in Content.COLLECTIBLE_ORDER:
		if int(owned.get(id, 0)) > 0:
			found += 1
	col.add_child(UI.label(I18n.t("col_found", [found, Content.COLLECTIBLE_ORDER.size()]), 30, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	var body := UI.scroll_column(col)
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
