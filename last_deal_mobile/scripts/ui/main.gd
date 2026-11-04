extends Control
## Корінь UI: безпечні відступи, верхня панель, сторінки, нижня навігація, модальні вікна, ефекти.

var safe: MarginContainer
var money_label: Label
var day_label: Label
var cust_label: Label
var pages: Control
var shop_page: ShopPage
var inv_page: InventoryPage
var up_page: UpgradesPage
var nav_buttons := {}
var current_tab := "shop"
var overlay: Control
var fx_layer: Control
var coin_icon: TextureRect

var _shown_money := 0
var _money_tween: Tween


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	safe = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	var root := UIKit.vbox(10)
	safe.add_child(root)

	root.add_child(_build_top_bar())

	pages = Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	shop_page = ShopPage.new()
	inv_page = InventoryPage.new()
	up_page = UpgradesPage.new()
	for p in [shop_page, inv_page, up_page]:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		pages.add_child(p)
	shop_page.request_end_day.connect(_on_end_day)
	shop_page.fx_money.connect(_fx_text)
	inv_page.fx_money.connect(_fx_text)

	root.add_child(_build_nav())

	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_bind_session()
	Game.session_replaced.connect(_on_session_replaced)
	_shown_money = Game.session.money
	_set_tab("shop")
	_refresh_all()
	if not Game.settings.get("tutorial_done", false):
		_show_tutorial()
	elif Game.session.game_over:
		_show_game_over()


func _bind_session() -> void:
	var ses := Game.session
	if not ses.changed.is_connected(_refresh_top):
		ses.changed.connect(_refresh_top)
		ses.money_changed.connect(_on_money_changed)


func _on_session_replaced() -> void:
	_bind_session()
	_shown_money = Game.session.money
	shop_page.busy = false
	_set_tab("shop")
	_refresh_all()


# ------------------------------------------------------------------ безпечна зона
func _apply_safe_area() -> void:
	var m := {"left": 16, "right": 16, "top": 12, "bottom": 12}
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var sa := DisplayServer.get_display_safe_area()
		var vis := get_viewport_rect().size
		if win.x > 0 and win.y > 0 and sa.size.x > 0:
			var k := vis / win
			m["top"] = maxi(m["top"], int(sa.position.y * k.y) + 6)
			m["left"] = maxi(m["left"], int(sa.position.x * k.x) + 4)
			m["right"] = maxi(m["right"], int((win.x - sa.end.x) * k.x) + 4)
			m["bottom"] = maxi(m["bottom"], int((win.y - sa.end.y) * k.y) + 6)
	for side in m:
		safe.add_theme_constant_override("margin_" + side, m[side])


# ------------------------------------------------------------------ верхня панель
func _build_top_bar() -> Control:
	var p := UIKit.panel(UIKit.PANEL, UIKit.BORDER)
	var h := UIKit.hbox(10)
	p.add_child(h)
	coin_icon = UIKit.icon_rect("res://assets/icons/coin.png", 44)
	h.add_child(coin_icon)
	money_label = UIKit.pixel_label("", UIKit.FS_HUGE, UIKit.AMBER)
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(money_label)
	var v := UIKit.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	day_label = UIKit.label("", UIKit.FS, UIKit.TEXT)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(day_label)
	cust_label = UIKit.label("", UIKit.FS_SMALL, UIKit.MUTED)
	cust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(cust_label)
	var gear := Button.new()
	gear.icon = load("res://assets/icons/gear.png")
	gear.expand_icon = true
	gear.custom_minimum_size = Vector2(84, 84)
	gear.focus_mode = Control.FOCUS_NONE
	gear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gear.add_theme_constant_override("icon_max_width", 48)
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.pressed.connect(_show_settings)
	h.add_child(gear)
	return p


func _refresh_top() -> void:
	var ses := Game.session
	day_label.text = "День %d" % ses.day
	if ses.game_over:
		cust_label.text = "Банкрут"
	else:
		cust_label.text = "Клієнт %d/%d · оренда %d" % [ses.customer_number, ses.customers_today, Economy.rent_for_day(ses.day)]
	nav_buttons["inv"].text = "Склад (%d)" % ses.inventory.count()
	if _money_tween == null or not _money_tween.is_running():
		_shown_money = ses.money
		_set_money_text(_shown_money)


func _set_money_text(v: int) -> void:
	money_label.text = Economy.format_money(v)
	money_label.add_theme_color_override("font_color", UIKit.AMBER if v >= 0 else UIKit.RED)


func _on_money_changed(new_value: int, delta: int) -> void:
	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()
	_money_tween = create_tween()
	_money_tween.tween_method(func(v: float): _set_money_text(int(round(v))), float(_shown_money), float(new_value), 0.45)
	_shown_money = new_value
	var pulse := create_tween()
	money_label.pivot_offset = Vector2(0, money_label.size.y / 2)
	pulse.tween_property(money_label, "scale", Vector2(1.12, 1.12), 0.08)
	pulse.tween_property(money_label, "scale", Vector2.ONE, 0.15)
	if delta > 0:
		_fx_coins(delta)


# ------------------------------------------------------------------ навігація
func _build_nav() -> Control:
	var h := UIKit.hbox(10)
	h.custom_minimum_size = Vector2(0, 96)
	var defs := [["shop", "Крамниця", "res://assets/icons/tab_shop.png"], ["inv", "Склад", "res://assets/icons/tab_bag.png"], ["up", "Розвиток", "res://assets/icons/tab_up.png"]]
	for d in defs:
		var b := UIKit.button(d[1], "neutral", UIKit.FS_SMALL + 2, 96)
		b.icon = load(d[2])
		b.expand_icon = false
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.pressed.connect(func():
			Sfx.play("click")
			_set_tab(d[0]))
		nav_buttons[d[0]] = b
		h.add_child(b)
	return h


func _set_tab(tab: String) -> void:
	current_tab = tab
	shop_page.visible = tab == "shop"
	inv_page.visible = tab == "inv"
	up_page.visible = tab == "up"
	for k in nav_buttons:
		UIKit.style_button(nav_buttons[k], "pink" if k == tab else "neutral")
	if tab == "inv":
		inv_page.refresh()
	elif tab == "up":
		up_page.refresh()
	else:
		shop_page.refresh()


func _refresh_all() -> void:
	_refresh_top()
	shop_page.refresh()
	if inv_page.visible:
		inv_page.refresh()
	if up_page.visible:
		up_page.refresh()


# ------------------------------------------------------------------ ефекти
func _fx_text(text: String, color: Color, from_global: Vector2) -> void:
	var l := UIKit.pixel_label(text, UIKit.FS_BIG, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	fx_layer.add_child(l)
	l.position = fx_layer.get_global_transform().affine_inverse() * from_global - Vector2(80, 20)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 120, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _fx_coins(amount: int) -> void:
	var n := clampi(amount / 40 + 3, 3, 10)
	var target := coin_icon.get_global_rect().get_center()
	var start := get_viewport_rect().size * Vector2(0.5, 0.55)
	var tex: Texture2D = load("res://assets/icons/coin.png")
	for i in n:
		var c := TextureRect.new()
		c.texture = tex
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.size = Vector2(36, 36)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = start + Vector2(randf_range(-120, 120), randf_range(-60, 60))
		fx_layer.add_child(c)
		var tw := c.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(c, "position", target - Vector2(18, 18), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)


# ------------------------------------------------------------------ модальні вікна
func _open_modal() -> Modal:
	for ch in overlay.get_children():
		if ch is Modal:
			ch.close()
	var m := Modal.new()
	overlay.add_child(m)
	return m


func has_modal() -> bool:
	for ch in overlay.get_children():
		if ch is Modal and not ch.is_queued_for_deletion():
			return true
	return false


func _on_end_day() -> void:
	var ses := Game.session
	if not ses.day_done() or has_modal():
		return
	var sum := ses.end_day()
	if sum.is_empty():
		return
	Sfx.play("day" if not sum["bankrupt"] else "deny")
	Game.save_now()
	_show_summary(sum)
	_refresh_all()


func _show_summary(sum: Dictionary) -> void:
	var m := _open_modal()
	m.dismiss_on_back = false
	m.title("День %d завершено" % int(sum["day"]))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 4)
	m.content.add_child(g)
	var net: int = sum["net"]
	var rows := [
		["Клієнтів", str(sum["customers"]), UIKit.TEXT],
		["Куплено", "%d за %s" % [sum["bought"], UIKit.money_text(int(sum["spent"]))], UIKit.TEXT],
		["Продано", "%d за %s" % [sum["sold"], UIKit.money_text(int(sum["revenue"]))], UIKit.TEXT],
		["Прибуток з продажів", ("+" if int(sum["profit"]) >= 0 else "") + UIKit.money_text(int(sum["profit"])), UIKit.GREEN if int(sum["profit"]) >= 0 else UIKit.RED],
		["Оренда", "−" + UIKit.money_text(int(sum["rent"])), UIKit.RED],
		["Зміна балансу", ("+" if net >= 0 else "") + UIKit.money_text(net), UIKit.GREEN if net >= 0 else UIKit.RED],
		["Баланс", UIKit.money_text(int(sum["end_money"])), UIKit.AMBER],
		["Товари на складі", UIKit.money_text(int(sum["inventory_value"])), UIKit.CYAN],
	]
	if int(sum["best_deal"]) > 0:
		rows.append(["Найкраща угода", "%s +%d" % [sum["best_deal_name"], int(sum["best_deal"])], UIKit.GREEN])
	for r in rows:
		var a := UIKit.label(r[0], UIKit.FS_SMALL + 2, UIKit.MUTED, true)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(a)
		var b := UIKit.label(r[1], UIKit.FS_SMALL + 2, r[2], true)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	var forced: Array = sum.get("forced", [])
	if forced.size() > 0:
		m.text("Не вистачало на оренду — довелося продати за півціни: " + ", ".join(forced.map(func(f): return "%s (%d)" % [f["name"], f["price"]])), UIKit.RED, UIKit.FS_SMALL)
	if sum["bankrupt"]:
		m.text("Грошей на оренду не вистачило. Крамницю «Last Deal» закрито за борги.", UIKit.RED)
		m.add_button("Почати нову гру", "pink", func():
			m.close()
			Game.new_game())
		return
	m.text("Завтра: оренда %s. %s" % [UIKit.money_text(int(sum["next_rent"])), sum["news"]], UIKit.CYAN, UIKit.FS_SMALL + 2)
	m.add_button("Наступний день ▶", "primary", func():
		m.close()
		_set_tab("shop"))


func _show_game_over() -> void:
	var m := _open_modal()
	m.dismiss_on_back = false
	m.title("Банкрутство", UIKit.RED)
	m.text("Крамницю закрито за борги. Протрималися днів: %d." % int(Game.session.stats_total.get("days", 0)))
	m.add_button("Почати нову гру", "pink", func():
		m.close()
		Game.new_game())


func _show_settings() -> void:
	Sfx.play("click")
	var m := _open_modal()
	m.title("Налаштування")
	_toggle_button(m, "Звук", "sound", func(_on): Sfx.play("click"))
	_toggle_button(m, "Вібрація", "vibration", func(_on): Game.vibrate(30))
	m.add_button("Як грати", "accent", func():
		m.close()
		_show_tutorial())
	m.add_button("Почати нову гру", "danger", func():
		_confirm("Почати заново? Увесь прогрес буде втрачено.", func():
			Game.new_game()))
	m.add_button("Закрити", "neutral", m.close)
	var ver := UIKit.label("LAST DEAL v%s · прогрес зберігається автоматично" % ProjectSettings.get_setting("application/config/version", "0.1"), UIKit.FS_SMALL - 2, UIKit.MUTED, true)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.content.add_child(ver)


func _toggle_button(m: Modal, title: String, key: String, after: Callable) -> void:
	var b := UIKit.button("", "neutral")
	var upd := func():
		var on: bool = Game.settings.get(key, true)
		b.text = "%s: %s" % [title, "увімкнено" if on else "вимкнено"]
		UIKit.style_button(b, "primary" if on else "neutral")
	upd.call()
	b.pressed.connect(func():
		var on: bool = not Game.settings.get(key, true)
		Game.set_setting(key, on)
		upd.call()
		after.call(on))
	m.content.add_child(b)


func _confirm(text: String, on_yes: Callable) -> void:
	var m := _open_modal()
	m.title("Підтвердження", UIKit.AMBER)
	m.text(text)
	var h := UIKit.hbox(12)
	m.content.add_child(h)
	var no := UIKit.button("Ні", "neutral")
	no.pressed.connect(m.close)
	h.add_child(no)
	var yes := UIKit.button("Так", "danger")
	yes.pressed.connect(func():
		m.close()
		on_yes.call())
	h.add_child(yes)


func _show_tutorial() -> void:
	var m := _open_modal()
	m.title("LAST DEAL: як грати")
	var lines := [
		"1. Клієнти приносять уживані речі й називають ціну.",
		"2. «Перевірити» — огляд стану й пошук прихованих дефектів. Хитрі клієнти брешуть!",
		"3. «Торгуватися» — запропонуйте свою ціну. Терпіння клієнта — сердечка.",
		"4. Куплене продавайте на вкладці «Склад» за ринковою ціною. Попит змінюється щодня.",
		"5. Увечері сплачуєте оренду. Не вистачить грошей — банкрутство.",
	]
	for l in lines:
		m.text(l, UIKit.TEXT, UIKit.FS_SMALL + 2)
	m.add_button("Зрозуміло!", "primary", func():
		Game.set_setting("tutorial_done", true)
		m.close())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_PREDELETE:
		UIKit.release()


func _on_back() -> void:
	for ch in overlay.get_children():
		if ch is Modal and not ch.is_queued_for_deletion():
			if ch.dismiss_on_back:
				ch.close()
			return
	if current_tab != "shop":
		_set_tab("shop")
		return
	_confirm("Вийти з гри? Прогрес збережено.", func():
		Game.save_now()
		get_tree().quit())
