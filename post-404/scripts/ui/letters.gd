extends Control
## Mailbox with letters from the characters, and the story chapter list.

var tab := "letters"
var list: VBoxContainer
var tab_buttons := {}


func setup(data: Dictionary) -> void:
	tab = data.get("tab", "letters")


func _ready() -> void:
	var col := UI.screen_frame(self, I18n.t("mail_title"), false)
	var tabs := HBoxContainer.new()
	for t in ["letters", "chapters"]:
		var b := UI.button(I18n.t("mail_title" if t == "letters" else "chapters_title"), "normal", 76)
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
	for c in list.get_children():
		c.queue_free()
	if t == "letters":
		_letters()
	else:
		_chapters()


func _letters() -> void:
	var letters: Array = Game.profile["story"]["letters"]
	if letters.is_empty():
		list.add_child(UI.wrap(UI.label(I18n.t("mail_empty"), 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)))
		return
	for i in range(letters.size() - 1, -1, -1):
		var l: Dictionary = letters[i]
		var card := UI.panel("ui_panel_paper")
		var h := HBoxContainer.new()
		card.add_child(h)
		h.add_child(UI.image("pt_" + str(l["from"]), 3))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var who := UI.label(I18n.pick(Content.CHARACTERS[l["from"]]), 28, Color("6b4430"), 0, true)
		if not l.get("read", false):
			who.text += "  •  " + I18n.t("new_letter")
			who.add_theme_color_override("font_color", UI.RED)
		v.add_child(who)
		var txt := UI.wrap(UI.label(I18n.pick(l), 26, UI.INK))
		txt.custom_minimum_size = Vector2(460, 0)
		v.add_child(txt)
		list.add_child(card)
		l["read"] = true
	Game.mark_dirty()


func _chapters() -> void:
	var p := Game.profile
	var ending: String = p["story"].get("ending", "")
	if ending != "":
		list.add_child(UI.outlined(UI.label(I18n.t("ending_got", I18n.line(StoryData.ENDINGS[ending], 0)), 32, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true), 6))
	for i in StoryData.CHAPTERS.size():
		var c: Dictionary = StoryData.CHAPTERS[i]
		var done := Story.is_done(p, c["id"])
		var avail := Story.next_available(p) == i
		var card := UI.panel("ui_panel")
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(UI.wrap(UI.label(I18n.line(c["title"], 0), 30, UI.AMBER if done else (UI.CYAN if avail else UI.MUTED), 0, true)))
		if done or avail:
			var b := UI.button(I18n.t("btn_continue") if avail else I18n.pick({"uk": "Переглянути", "en": "Replay"}), "cyan" if avail else "normal", 72, "ic_story")
			var idx := i
			b.pressed.connect(func(): Game.goto("story", {"chapter": idx, "replay": done}))
			v.add_child(b)
		elif Story.next_locked(p) == i:
			var req: Dictionary = c["req"]
			var txt := I18n.t("chapter_req", [int(req.get("shifts", 0)), int(req.get("level", 1))])
			if req.has("upgrade"):
				txt += "\n" + I18n.t("chapter_req_robot", int(req["upgrade"][1]))
			v.add_child(UI.wrap(UI.label(txt, 24, UI.PAPER_DIM)))
		list.add_child(card)


func on_back() -> void:
	Game.save_now()
	Game.goto("menu")
