extends Control
## Root of the game: top bar, screen host, bottom navigation, overlays, toasts, tutorial and events.

const Data = preload("res://scripts/data.gd")

const SCREENS := {
	"garage": "res://scripts/screens/garage.gd",
	"auctions": "res://scripts/screens/auction_select.gd",
	"auction": "res://scripts/screens/auction.gd",
	"storage": "res://scripts/screens/storage.gd",
	"upgrades": "res://scripts/screens/upgrades.gd",
	"collection": "res://scripts/screens/collection.gd",
}
const OVERLAYS := {
	"open_box": "res://scripts/overlays/open_box.gd",
	"item": "res://scripts/overlays/item_detail.gd",
	"repair": "res://scripts/overlays/repair.gd",
	"sell": "res://scripts/overlays/sell.gd",
	"popup": "res://scripts/overlays/popup.gd",
	"settings": "res://scripts/overlays/settings.gd",
}
const NAV := [["garage", "garage"], ["auctions", "gavel"], ["storage", "box"], ["upgrades", "up"],
	["collection", "book"]]

var content: Control
var top_bar: PanelContainer
var nav_bar: PanelContainer
var overlay_layer: Control
var toast_layer: Control
var screen = null
var screen_name := ""
var nav_buttons := {}
var nav_badges := {}
var money_label: Label
var money_icon: TextureRect
var level_label: Label
var xp_bar: ProgressBar
var day_label: Label
var _shown_money := 0
var _money_tween: Tween
var _toasts := 0
var _toast_nodes: Array = []
var _nav_pulse: Tween


func _ready() -> void:
	theme = _make_theme()
	add_child(UI.full(UI.color_rect(UI.C_BG)))
	var tile := TextureRect.new()
	tile.texture = UI.art("ui/bg_tile")
	tile.stretch_mode = TextureRect.STRETCH_TILE
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(tile))
	var root := UI.vbox(0)
	add_child(UI.full(root))
	_build_top_bar(root)
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content)
	_build_nav(root)
	overlay_layer = Control.new()
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(overlay_layer))
	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(toast_layer))

	Game.money_changed.connect(_on_money)
	Game.xp_changed.connect(_refresh_top)
	Game.level_up.connect(_on_level_up)
	Game.state_changed.connect(_refresh_badges)
	L.changed.connect(_on_lang)
	_shown_money = Game.money
	_refresh_top()
	_refresh_badges()

	var args := OS.get_cmdline_user_args()
	if args.has("--selftest") or args.has("--smoke") or args.has("--shots"):
		var t = load("res://scripts/tests.gd").new()
		t.main = self
		add_child(t)
		return
	show_screen("garage")
	if not Game.tutorial_done:
		call_deferred("_tutorial_step", 0)
	elif Game.pending_event:
		call_deferred("show_event")


func _make_theme() -> Theme:
	var th := Theme.new()
	var f = load(UI.FONT_PATH)
	if f is Font:
		th.default_font = f
	th.default_font_size = 16
	th.set_color("font_color", "Label", UI.C_TEXT)
	return th


# ------------------------------------------------------------------ top bar and navigation
func _build_top_bar(root: Control) -> void:
	top_bar = UI.panel("dark", 6)
	top_bar.custom_minimum_size = Vector2(0, 52)
	root.add_child(top_bar)
	var row := UI.hbox(6)
	top_bar.add_child(row)
	money_icon = UI.icon("coin", 2)
	row.add_child(money_icon)
	money_label = UI.shadow(UI.label("", 20, UI.C_GOLD))
	UI.fill(money_label)
	row.add_child(money_label)
	var lv := UI.vbox(1)
	lv.custom_minimum_size = Vector2(74, 0)
	var lvrow := UI.hbox(2)
	lvrow.add_child(UI.icon("star", 1))
	level_label = UI.label("", 13, UI.C_TEXT)
	lvrow.add_child(level_label)
	lv.add_child(lvrow)
	xp_bar = UI.bar(0.0, Color("a060dc"), 8)
	lv.add_child(xp_bar)
	row.add_child(UI.center(lv))
	var dayrow := UI.hbox(2)
	dayrow.add_child(UI.icon("calendar", 1))
	day_label = UI.label("", 13, UI.C_TEXT)
	dayrow.add_child(day_label)
	row.add_child(UI.center(dayrow))
	var gear := UI.icon_button("gear", "", "dark", 12, Vector2(44, 40))
	gear.pressed.connect(_on_gear)
	row.add_child(gear)


func _on_gear() -> void:
	Sfx.click()
	open_overlay("settings")


func _build_nav(root: Control) -> void:
	nav_bar = UI.panel("dark", 4)
	nav_bar.custom_minimum_size = Vector2(0, 76)
	root.add_child(nav_bar)
	var row := UI.hbox(4)
	nav_bar.add_child(row)
	for entry in NAV:
		var id: String = entry[0]
		var b := UI.icon_button(entry[1], L.t("nav." + id), "dark", 11, Vector2(60, 64))
		UI.fill(b)
		b.pressed.connect(_on_nav.bind(id))
		row.add_child(b)
		nav_buttons[id] = b
		var badge := UI.label("", 11, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		badge.add_theme_stylebox_override("normal", UI.flat(Color("d8434b"), UI.C_DARK, 2))
		badge.custom_minimum_size = Vector2(20, 18)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -24
		badge.offset_top = 2
		badge.offset_right = -4
		badge.offset_bottom = 20
		badge.visible = false
		b.add_child(badge)
		nav_badges[id] = badge


func _on_nav(id: String) -> void:
	Sfx.click()
	if id == screen_name:
		return
	show_screen(id)


func _update_nav() -> void:
	for id in nav_buttons.keys():
		var b: Button = nav_buttons[id]
		var active: bool = id == screen_name or (id == "auctions" and screen_name == "auction")
		UI.style_button(b, "purple" if active else "dark", 11)


func _refresh_top() -> void:
	money_label.text = UI.money(_shown_money, L.t("num.sep"))
	level_label.text = L.t("top.level", {"n": Game.level})
	xp_bar.value = float(Game.xp) / float(maxi(1, Game.xp_needed(Game.level)))
	day_label.text = L.t("top.day", {"n": Game.day})


func _refresh_badges() -> void:
	_set_badge("storage", Game.boxes.size())
	_set_badge("collection", Game.claimable_goals())
	_refresh_top()


func _set_badge(id: String, n: int) -> void:
	if not nav_badges.has(id):
		return
	var b: Label = nav_badges[id]
	b.visible = n > 0
	b.text = str(n)


func _on_money(value: int) -> void:
	if _money_tween != null and _money_tween.is_valid():
		_money_tween.kill()
	var from := _shown_money
	_money_tween = create_tween()
	_money_tween.tween_method(_set_shown_money, from, value, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if value > from:
		UI.punch(money_icon, 0.3)


func _set_shown_money(v) -> void:
	_shown_money = int(v)
	money_label.text = UI.money(_shown_money, L.t("num.sep"))


func _on_lang() -> void:
	for entry in NAV:
		var b: Button = nav_buttons[entry[0]]
		var cap := b.find_child("Caption", true, false)
		if cap is Label:
			cap.text = L.t("nav." + str(entry[0]))
	_refresh_top()
	if screen_name != "" and screen_name != "auction":
		show_screen(screen_name)


func pulse_nav(id: String) -> void:
	if _nav_pulse != null and _nav_pulse.is_valid():
		_nav_pulse.kill()
	if nav_buttons.has(id):
		_nav_pulse = UI.pulse(nav_buttons[id], 0.08)


# ------------------------------------------------------------------ screens and overlays
func show_screen(id: String, args: Dictionary = {}) -> void:
	if not SCREENS.has(id):
		return
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	var s = load(SCREENS[id]).new()
	s.main = self
	s.args = args
	screen = s
	screen_name = id
	content.add_child(UI.full(s))
	nav_bar.visible = id != "auction"
	_update_nav()
	Sfx.music("auction" if id == "auction" else "garage")
	UI.fade_in(s, 0.15)
	if id == "auctions" and _nav_pulse != null and _nav_pulse.is_valid():
		_nav_pulse.kill()
		nav_buttons["auctions"].scale = Vector2.ONE


func refresh_screen() -> void:
	if screen != null and is_instance_valid(screen) and screen.has_method("refresh"):
		screen.call("refresh")


func open_overlay(id: String, args: Dictionary = {}) -> Control:
	var o = load(OVERLAYS[id]).new()
	o.main = self
	o.args = args
	overlay_layer.add_child(UI.full(o))
	return o


func close_overlay(o: Control) -> void:
	if o != null and is_instance_valid(o):
		o.queue_free()
	refresh_screen()


func top_overlay() -> Control:
	for i in range(overlay_layer.get_child_count() - 1, -1, -1):
		var c := overlay_layer.get_child(i)
		if c is Control and not c.is_queued_for_deletion():
			return c as Control
	return null


func overlay_count() -> int:
	var n := 0
	for c in overlay_layer.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


## buttons: Array of [text, style, Callable or null]. extra: portrait, icon, item.
func popup(title: String, text: String, buttons: Array = [], extra: Dictionary = {}) -> Control:
	var a := {"title": title, "text": text, "buttons": buttons}
	a.merge(extra, true)
	return open_overlay("popup", a)


func toast(text: String, color: Color = Color("f2f0f5"), icon_name: String = "") -> void:
	var p := UI.panel("dark", 8)
	var row := UI.hbox(6)
	if icon_name != "":
		row.add_child(UI.icon(icon_name, 1))
	var l := UI.label(text, 14, color, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	p.add_child(row)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var y := 58.0
	for t in _toast_nodes:
		if is_instance_valid(t):
			y = maxf(y, t.offset_top + maxf(t.size.y, 44.0) + 6.0)
	p.offset_top = y
	toast_layer.add_child(p)
	_toast_nodes.append(p)
	_toasts += 1
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.9)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_toast_done.bind(p))


func _toast_done(p: Control) -> void:
	_toasts = maxi(0, _toasts - 1)
	_toast_nodes.erase(p)
	if is_instance_valid(p):
		p.queue_free()


## Rising text at a global position (money gained, PERFECT!, etc.).
func float_text(text: String, global_pos: Vector2, color: Color = Color("f8d448"), font_size: int = 20) -> void:
	var l := UI.outlined(UI.label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER), 5)
	l.custom_minimum_size = Vector2(200, 30)
	toast_layer.add_child(l)
	l.position = global_pos - toast_layer.global_position - Vector2(100, 15)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


## Coins fly from a point to the money counter.
func coin_burst(global_from: Vector2, count: int = 6) -> void:
	var target := money_icon.global_position + money_icon.size * 0.5
	var t := UI.art("fx/coin")
	for i in range(count):
		var c := UI.tex_rect(t, 2)
		c.size = c.custom_minimum_size
		toast_layer.add_child(c)
		var start := global_from - toast_layer.global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		c.position = start
		var mid := start + Vector2(randf_range(-40, 40), randf_range(-70, -30))
		var tw := c.create_tween()
		tw.tween_property(c, "position", mid, 0.22 + i * 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position", target - toast_layer.global_position - c.size * 0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)
	var tw2 := create_tween()
	tw2.tween_interval(0.5)
	tw2.tween_callback(Sfx.play.bind("coin", 1.0, -4.0))


# ------------------------------------------------------------------ level ups, events, tutorial
func _on_level_up(lvl: int) -> void:
	Sfx.play("levelup")
	Game.buzz(60)
	var text := L.t("levelup.text", {"n": lvl})
	for a in Data.AUCTIONS:
		if int(a["rep"]) == lvl:
			text += "\n\n" + L.t("levelup.unlock", {"name": L.t("auction." + str(a["id"]))})
	popup(L.t("levelup.title"), text, [[L.t("ok"), "gold", null]], {"icon": "trophy"})


func show_event() -> void:
	if not Game.pending_event or Game.event.is_empty():
		return
	Game.pending_event = false
	Game.request_save()
	var e: Dictionary = Game.event
	var id := str(e.get("id", ""))
	var args := {}
	for k in e.keys():
		args[k] = e[k]
	if e.has("amount"):
		args["amount"] = UI.money(int(e["amount"]), L.t("num.sep"))
	if e.has("offer"):
		args["offer"] = UI.money(int(e["offer"]), L.t("num.sep"))
	if e.has("item"):
		args["item"] = L.t("item." + str(e["item"]))
	if e.has("cat"):
		args["cat"] = L.t("cat." + str(e["cat"]))
	var text_key := "event.%s.text" % id
	if id == "leak" and bool(e.get("protected", false)):
		text_key = "event.leak.safe"
	var buttons := [[L.t("ok"), "gold", null]]
	if id == "stranger":
		buttons = [[L.t("event.stranger.yes"), "green", _accept_stranger], [L.t("event.stranger.no"), "dark", null]]
	Sfx.play("event")
	popup(L.t("event.%s.title" % id), L.t(text_key, args), buttons, {"icon": Data.EVENT_ICONS.get(id, "calendar")})


func _accept_stranger() -> void:
	var offer := int(Game.event.get("offer", 0))
	if Game.accept_stranger():
		Sfx.play("cash")
		toast(L.t("sell.sold", {"price": UI.money(offer, L.t("num.sep"))}), UI.C_GOLD, "coin")
		refresh_screen()


func _tutorial_step(i: int) -> void:
	if i >= 5:
		Game.tutorial_done = true
		Game.request_save()
		pulse_nav("auctions")
		return
	var btn := L.t("next") if i < 4 else L.t("tut.start")
	popup(L.t("lou.name"), L.t("tut.%d" % i), [[btn, "gold", _tutorial_step.bind(i + 1)]], {"portrait": "lou"})


# ------------------------------------------------------------------ back button
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		on_back()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		on_back()
		get_viewport().set_input_as_handled()


func on_back() -> void:
	var o := top_overlay()
	if o != null:
		if o.has_method("on_back"):
			o.call("on_back")
		else:
			close_overlay(o)
		return
	if screen != null and is_instance_valid(screen) and screen.has_method("on_back") and bool(screen.call("on_back")):
		return
	if screen_name != "garage":
		show_screen("garage")
		return
	popup(L.t("quit.title"), L.t("quit.text"), [[L.t("quit.yes"), "red", _quit], [L.t("cancel"), "dark", null]])


func _quit() -> void:
	Game.save_now()
	get_tree().quit()
