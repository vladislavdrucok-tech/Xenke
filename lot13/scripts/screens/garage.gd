extends Control
## The garage hub: a pixel-art scene that grows with upgrades, unopened boxes on the floor, items on shelves.

const Data = preload("res://scripts/data.gd")
const BOARD_Y := [178, 150, 122, 94, 66]
const BOX_SPOTS := [Vector2(72, 186), Vector2(100, 194), Vector2(44, 196), Vector2(126, 198), Vector2(86, 206)]

var main
var args: Dictionary = {}
var stage_area: Control
var stage: Control
var info: VBoxContainer
var cta: HBoxContainer
var _k := 2


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(UI.color_rect(UI.C_WALL)))
	var col := UI.vbox(0)
	add_child(UI.full(col))
	stage_area = Control.new()
	stage_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_area.clip_contents = true
	stage_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stage_area)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.flat(UI.C_FLOOR, Color("4e4954"), 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	cta = UI.hbox(8)
	bar.add_child(UI.margin(cta, 10, 6, 10, 8))
	info = UI.vbox(6)
	var info_m := UI.margin(info, 8, 6, 8, 0)
	info_m.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(info_m)
	stage_area.resized.connect(_layout_stage)
	Game.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	_build_stage()
	_build_info()
	_build_cta()


func _layout_stage() -> void:
	if stage == null:
		return
	var area := stage_area.size
	_k = 3 if area.x >= 540.0 and area.y >= 780.0 else 2
	stage.scale = Vector2(_k, _k)
	stage.position = Vector2(floorf((area.x - 180.0 * _k) * 0.5), area.y - 260.0 * _k)


func _add_tex(t: Texture2D, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.position = pos
	if t != null:
		r.size = t.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(r)
	return r


func _hotspot(rect: Rect2, cb: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	b.position = rect.position
	b.size = rect.size
	b.pressed.connect(cb)
	stage.add_child(b)


func _build_stage() -> void:
	if stage != null:
		stage.queue_free()
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(180, 260)
	stage_area.add_child(stage)
	_add_tex(UI.art("garage/garage_bg"), Vector2.ZERO)
	_hotspot(Rect2(64, 72, 57, 118), _go_auctions)
	_hotspot(Rect2(0, 40, 64, 150), _go_storage)
	_hotspot(Rect2(122, 118, 58, 72), _go_storage)
	_hotspot(Rect2(124, 16, 53, 45), show_trends)

	var shelf_lvl := Game.upgrade_level("shelves")
	var boards := mini(5, 2 + shelf_lvl)
	var board_tex := UI.art("garage/board_steel" if shelf_lvl >= 4 else "garage/board_wood")
	for i in range(boards):
		_add_tex(board_tex, Vector2(1, BOARD_Y[i]))
	for i in range(mini(boards * 3, Game.items.size())):
		var it: Dictionary = Game.items[i]
		var b := TextureButton.new()
		b.texture_normal = UI.item_tex(str(it["id"]))
		b.position = Vector2(5 + (i % 3) * 18, int(BOARD_Y[int(i / 3)]) - 17)
		b.pressed.connect(_open_item.bind(int(it["uid"])))
		stage.add_child(b)

	var truck := Game.upgrade_level("truck")
	if truck > 0:
		_add_tex(UI.art("garage/truck_%d" % truck), Vector2(68, 158))
	var sign_lvl := Game.upgrade_level("showroom")
	if sign_lvl > 0:
		var s := _add_tex(UI.art("garage/sign_%d" % sign_lvl), Vector2(64, 50))
		if sign_lvl >= 2:
			var tw := s.create_tween().set_loops()
			tw.tween_interval(randf_range(2.0, 4.0))
			tw.tween_property(s, "modulate:a", 0.55, 0.06)
			tw.tween_property(s, "modulate:a", 1.0, 0.06)
			tw.tween_property(s, "modulate:a", 0.7, 0.05)
			tw.tween_property(s, "modulate:a", 1.0, 0.08)
	var bench := Game.upgrade_level("bench")
	_add_tex(UI.art("garage/bench_%d" % bench), Vector2(120, 131))
	if bench >= 3:
		_add_tex(UI.art("garage/bench_lamp"), Vector2(122, 126))
	var cat := Game.upgrade_level("charm")
	if cat > 0:
		var c := _add_tex(UI.art("garage/cat_%d" % cat), Vector2(139, 132))
		c.pivot_offset = Vector2(8, 15)
		var tw2 := c.create_tween().set_loops()
		tw2.tween_interval(randf_range(1.5, 3.0))
		tw2.tween_property(c, "rotation", 0.12, 0.15)
		tw2.tween_property(c, "rotation", -0.12, 0.15)
		tw2.tween_property(c, "rotation", 0.0, 0.15)
	var scanner := Game.upgrade_level("scanner")
	if scanner > 0:
		_add_tex(UI.art("garage/scanner_%d" % scanner), Vector2(160, 133))

	var shown := mini(BOX_SPOTS.size(), Game.boxes.size())
	var order := range(shown)
	order.sort_custom(func(a, b): return BOX_SPOTS[a].y < BOX_SPOTS[b].y)
	for i in order:
		var bx: Dictionary = Game.boxes[i]
		var tb := TextureButton.new()
		tb.texture_normal = UI.box_tex(str(bx["kind"]))
		var spot: Vector2 = BOX_SPOTS[i]
		tb.position = spot
		tb.pressed.connect(_open_box.bind(int(bx["uid"])))
		stage.add_child(tb)
		var hop := tb.create_tween().set_loops()
		hop.tween_interval(randf_range(1.2, 3.5))
		hop.tween_property(tb, "position:y", spot.y - 4, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(tb, "position:y", spot.y, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if Game.boxes.size() > shown:
		var more := UI.outlined(UI.label("+%d" % (Game.boxes.size() - shown), 10, UI.C_GOLD), 3)
		more.position = Vector2(150, 214)
		stage.add_child(more)
	_layout_stage()


func _build_info() -> void:
	for c in info.get_children():
		c.queue_free()
	if not Game.event.is_empty() and not bool(Game.event.get("done", false)):
		var id := str(Game.event.get("id", ""))
		var b := UI.tile_button("dark")
		b.custom_minimum_size = Vector2(0, 40)
		var row := UI.hbox(6)
		row.add_child(UI.icon(str(Data.EVENT_ICONS.get(id, "calendar")), 2))
		var l := UI.label(L.t("event.%s.title" % id), 13, UI.C_GOLD)
		UI.fill(l)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		row.add_child(UI.label(L.t("garage.today"), 11, UI.C_DIM))
		b.add_child(UI.full(UI.margin(row, 8, 4, 8, 4)))
		b.pressed.connect(_reshow_event)
		info.add_child(b)
	var t := UI.tile_button("dark")
	t.custom_minimum_size = Vector2(0, 34)
	var tl := UI.label(trend_line(), 12, UI.C_TEXT)
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.add_child(UI.full(UI.margin(tl, 8, 2, 8, 2)))
	t.pressed.connect(show_trends)
	info.add_child(t)


func trend_line() -> String:
	var hot := []
	var cold := []
	for k in Game.trends.keys():
		var v := float(Game.trends[k])
		var s := "%s %+d%%" % [L.t("cat." + str(k)), roundi((v - 1.0) * 100.0)]
		if v >= 1.0:
			hot.append(s)
		else:
			cold.append(s)
	var line := L.t("garage.demand") + " " + ", ".join(PackedStringArray(hot))
	if not cold.is_empty():
		line += "  •  " + ", ".join(PackedStringArray(cold))
	return line


func _build_cta() -> void:
	for c in cta.get_children():
		c.queue_free()
	if not Game.boxes.is_empty():
		var ob := UI.icon_button("box", L.t("garage.open", {"n": Game.boxes.size()}), "green", 14, Vector2(0, 58), false)
		UI.fill(ob)
		ob.pressed.connect(_open_first_box)
		cta.add_child(ob)
		if Game.stats.get("boxes", 0) == 0:
			UI.pulse(ob, 0.05)
	var ab := UI.icon_button("gavel", L.t("garage.auction"), "gold", 16, Vector2(0, 58), false)
	UI.fill(ab)
	ab.pressed.connect(_go_auctions)
	cta.add_child(ab)


# ------------------------------------------------------------------ actions
func _go_auctions() -> void:
	Sfx.click()
	main.show_screen("auctions")


func _go_storage() -> void:
	Sfx.click()
	main.show_screen("storage")


func _open_item(uid: int) -> void:
	Sfx.click()
	main.open_overlay("item", {"uid": uid})


func _open_box(uid: int) -> void:
	Sfx.play("thud", 1.2, -4.0)
	main.open_overlay("open_box", {"uid": uid})


func _open_first_box() -> void:
	if Game.boxes.is_empty():
		return
	_open_box(int(Game.boxes[0]["uid"]))


func _reshow_event() -> void:
	Sfx.click()
	var e: Dictionary = Game.event
	var id := str(e.get("id", ""))
	var a := {}
	for k in e.keys():
		a[k] = e[k]
	if e.has("amount"):
		a["amount"] = UI.money(int(e["amount"]), L.t("num.sep"))
	if e.has("offer"):
		a["offer"] = UI.money(int(e["offer"]), L.t("num.sep"))
	if e.has("item"):
		a["item"] = L.t("item." + str(e["item"]))
	if e.has("cat"):
		a["cat"] = L.t("cat." + str(e["cat"]))
	var key := "event.%s.text" % id
	if id == "leak" and bool(e.get("protected", false)):
		key = "event.leak.safe"
	if id == "stranger" and not bool(e.get("done", false)) and Game.item_index(int(e.get("uid", -1))) >= 0:
		main.popup(L.t("event.%s.title" % id), L.t(key, a),
			[[L.t("event.stranger.yes"), "green", Callable(main, "_accept_stranger")], [L.t("event.stranger.no"), "dark", null]],
			{"icon": str(Data.EVENT_ICONS.get(id, "calendar"))})
		return
	main.popup(L.t("event.%s.title" % id), L.t(key, a), [[L.t("ok"), "gold", null]],
		{"icon": str(Data.EVENT_ICONS.get(id, "calendar"))})


func show_trends() -> void:
	Sfx.click()
	var lines := []
	var keys: Array = Game.trends.keys()
	keys.sort_custom(func(a, b): return float(Game.trends[a]) > float(Game.trends[b]))
	for k in keys:
		var v := float(Game.trends[k])
		lines.append("%s  %+d%%" % [L.t("cat." + str(k)), roundi((v - 1.0) * 100.0)])
	if str(Game.event.get("id", "")) == "collector":
		lines.append(L.t("trends.collector", {"cat": L.t("cat." + str(Game.event.get("cat", "")))}))
	lines.append("")
	lines.append(L.t("trends.note"))
	main.popup(L.t("trends.title"), "\n".join(PackedStringArray(lines)), [[L.t("ok"), "gold", null]], {"icon": "tag"})
