extends Control
## End-of-shift summary with rewards, unlocks and the next step.

var summary: Dictionary = {}
var out: Dictionary = {}


func setup(data: Dictionary) -> void:
	summary = data.get("summary", {})
	out = data.get("out", {})


func _ready() -> void:
	Audio.music("menu")
	var mode: String = summary.get("mode", "shift")
	var title_key := "res_done"
	if mode == "record":
		title_key = "res_record_over"
	elif mode == "calm":
		title_key = "res_calm"
	elif not summary.get("completed", false):
		title_key = "res_failed"
	var col := UI.screen_frame(self, I18n.t(title_key), true)
	var body := UI.scroll_column(col)
	var card := UI.panel("ui_panel")
	body.add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	if mode == "shift" or mode == "daily" or mode == "tutorial":
		var stars := HBoxContainer.new()
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in 3:
			var st := UI.image("ic_star" if i < int(summary.get("stars", 0)) else "ic_star_empty", 12)
			stars.add_child(st)
			if i < int(summary.get("stars", 0)):
				st.modulate.a = 0.0
				var tw := st.create_tween()
				tw.tween_interval(0.25 + i * 0.25)
				tw.tween_callback(func(): Audio.play("coin", 1.0 + i * 0.15))
				tw.tween_property(st, "modulate:a", 1.0, 0.15)
		v.add_child(stars)
	if not summary.get("completed", false) and mode == "shift":
		v.add_child(UI.wrap(UI.label(I18n.t("res_failed_hint"), 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)))
	if out.get("record", false):
		var rec := UI.outlined(UI.label(I18n.t("res_new_record"), 44, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true), 8)
		v.add_child(rec)
		UI.pop(rec, 1.6)
	_row(v, I18n.t("res_sorted"), "%d" % int(summary.get("sorted", 0)))
	_row(v, I18n.t("res_accuracy"), "%d%%" % int(round(float(summary.get("accuracy", 0.0)) * 100.0)))
	_row(v, I18n.t("res_combo"), "%d" % int(summary.get("best_combo", 0)))
	_row(v, I18n.t("res_score"), UI.fmt(int(summary.get("score", 0))))
	if int(summary.get("series_done", 0)) > 0:
		_row(v, I18n.t("res_series"), "%d" % int(summary["series_done"]))
	var coin_text := "+%s" % UI.fmt(int(summary.get("coins", 0)))
	if int(summary.get("bonus", 0)) > 0:
		coin_text += "  (%s +%d)" % [I18n.t("res_bonus"), int(summary["bonus"])]
	_row(v, I18n.t("res_coins"), coin_text, UI.GOLD, "ic_coin")
	_row(v, I18n.t("res_xp"), "+%d" % int(summary.get("xp", 0)), UI.AMBER, "ic_xp")
	var shards := int(summary.get("shards", 0)) + int(out.get("bonus_shards", 0)) + int(out.get("daily_reward", 0))
	if shards > 0:
		_row(v, I18n.t("res_shards"), "+%d" % shards, UI.CYAN, "ic_shard")
	for lv in out.get("levels", []):
		var l := UI.outlined(UI.label(I18n.t("res_level_up", int(lv)), 38, UI.GREEN, HORIZONTAL_ALIGNMENT_CENTER, true), 6)
		v.add_child(l)
		Audio.play("levelup")
	if not (out.get("unlocks", []) as Array).is_empty():
		var u := UI.panel("ui_panel")
		var uv := VBoxContainer.new()
		u.add_child(uv)
		uv.add_child(UI.label(I18n.t("res_unlocked"), 30, UI.AMBER, 0, true))
		for k in out["unlocks"]:
			uv.add_child(UI.wrap(UI.label("• " + I18n.t("unlock_" + k), 28, UI.PAPER)))
		body.add_child(u)
	if not (out.get("new_items", []) as Array).is_empty():
		var it := UI.panel("ui_panel")
		var iv := VBoxContainer.new()
		it.add_child(iv)
		iv.add_child(UI.label(I18n.t("res_found"), 30, UI.GOLD, 0, true))
		for id in out["new_items"]:
			var h := HBoxContainer.new()
			h.add_child(UI.image("it_" + id, 5))
			h.add_child(UI.wrap(UI.label(I18n.pick(Content.COLLECTIBLES[id]["name"]), 28)))
			iv.add_child(h)
		body.add_child(it)
	# next steps
	var chapter := Story.next_available(Game.profile)
	if chapter >= 0 and mode != "tutorial":
		var sb := UI.button("%s  %s" % [I18n.t("btn_story"), I18n.line(StoryData.CHAPTERS[chapter]["title"], 0)], "cyan", 96, "ic_story")
		sb.pressed.connect(func(): Game.goto("story", {"chapter": chapter}))
		col.add_child(sb)
	var again := UI.button(I18n.t("btn_again") if mode != "tutorial" else I18n.t("btn_continue"), "accent", 110, "ic_play")
	again.pressed.connect(func():
		if mode == "tutorial":
			Game.goto("menu")
		elif mode == "daily":
			Game.goto("shift", {"mode": "daily"})
		else:
			Game.goto("shift", {"mode": mode}))
	col.add_child(again)
	var row := HBoxContainer.new()
	var office := UI.button(I18n.t("btn_office"), "normal", 90, "ic_home")
	office.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	office.pressed.connect(func(): Game.goto("office"))
	row.add_child(office)
	var menu := UI.button(I18n.t("btn_menu"), "normal", 90)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func(): Game.goto("menu"))
	row.add_child(menu)
	col.add_child(row)


func _row(parent: Control, name: String, value: String, color: Color = UI.PAPER, icon: String = "") -> void:
	var h := HBoxContainer.new()
	if icon != "":
		h.add_child(UI.image(icon, 4))
	var n := UI.label(name, 30, UI.MUTED)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(UI.label(value, 32, color, HORIZONTAL_ALIGNMENT_RIGHT, true))
	parent.add_child(h)


func on_back() -> void:
	Game.goto("menu")
