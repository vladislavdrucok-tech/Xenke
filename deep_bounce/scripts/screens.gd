extends Control
## Menus and overlays. Every screen is built by a function, so a language switch, a price arriving from
## Google Play or an ad becoming ready simply rebuilds the open one (scroll positions are kept).
## Screens: menu, settings, language, shop (balls / cannons / Ad-Free), Ad-Free sheet, support, thanks,
## levels, level intro, pause, confirm, upgrade, second chance, results (endless, level won / lost), all clear.

const UK := preload("res://scripts/ui_kit.gd")
const CATALOG := preload("res://scripts/catalog.gd")
const PV := preload("res://scripts/previews.gd")
const I18N := preload("res://scripts/i18n.gd")

const CHAPTERS := ["ch_copper", "ch_crystal", "ch_flooded", "ch_obsidian", "ch_heart"]

var main: Node
var layer: Control
var current := ""
var _builder: Callable
var _stack: Array = []
var toast_label: Label
var toast_panel: PanelContainer
var toast_t := 0.0
var shop_tab := "ball"
var shop_focus := {"ball": "", "cannon": ""}
var _scroll_keep := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UK.theme()
	UK.set_lang(G.settings.lang)
	# short messages on a dark plate so they stay readable over any screen
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", UK.sbt("card.png", 40, Vector4(24, 14, 24, 14)))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.z_index = 10
	toast_panel.modulate.a = 0.0
	add_child(toast_panel)
	toast_label = UK.label("", 26, UK.CREAM, 6, "Rubik-Bold")
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(560, 0)
	toast_panel.add_child(toast_label)
	G.lang_changed.connect(func():
		UK.set_lang(G.settings.lang)
		rebuild())

func is_open() -> bool:
	return layer != null

func close() -> void:
	if layer:
		layer.queue_free()
		layer = null
	current = ""
	_builder = Callable()

func back() -> void:
	if _stack.is_empty():
		if main.mode == main.M_MENU:
			show_menu()
		elif current in ["settings", "confirm", "shop", "lang"] and main.mode == main.M_GAME and main.paused:
			show_pause()
		else:
			close()
		return
	var prev: Array = _stack.pop_back()
	_open(prev[0], prev[1], false)

func toast(text: String, secs := 2.4) -> void:
	toast_label.text = text
	toast_t = secs
	toast_panel.reset_size()
	await get_tree().process_frame
	toast_panel.reset_size()
	toast_panel.position = Vector2((size.x - toast_panel.size.x) * 0.5, 120)

func _process(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		toast_panel.modulate.a = clampf(toast_t * 3.0, 0.0, 1.0)
	else:
		toast_panel.modulate.a = 0.0

func rebuild() -> void:
	if layer and _builder.is_valid():
		_remember_scroll()
		_open(current, _builder, false)

func refresh_store() -> void:
	if current in ["shop", "support", "noads", "settings", "revive"] or (current in ["over", "won", "lost"] and not G.result.is_empty()):
		rebuild()

func refresh_ads() -> void:
	if current in ["revive", "settings"] or (current in ["over", "won", "lost"] and not G.result.is_empty()):
		rebuild()

func _remember_scroll() -> void:
	_scroll_keep.clear()
	if layer == null:
		return
	for sc in layer.find_children("*", "ScrollContainer", true, false):
		_scroll_keep[String(sc.name)] = sc.scroll_vertical

func _open(name: String, builder: Callable, push := true) -> void:
	if push and layer and current != "" and current != name:
		_stack.append([current, _builder])
	if layer:
		layer.queue_free()
	if name != current:
		_scroll_keep.clear()
	layer = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	move_child(toast_panel, -1)
	current = name
	_builder = builder
	builder.call(layer)
	if not _scroll_keep.is_empty():
		var keep := _scroll_keep.duplicate()
		await get_tree().process_frame
		if layer:
			for sc in layer.find_children("*", "ScrollContainer", true, false):
				if keep.has(String(sc.name)):
					sc.scroll_vertical = keep[String(sc.name)]

# ---------------------------------------------------------------- layout helpers

func _column(parent: Control, top := 0.0, sep := 18) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = top
	v.offset_left = 30
	v.offset_right = -30
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v

func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc

func _card(parent: Control, width := 620.0) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(v)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(pc)
	parent.add_child(cc)
	return v

func _scroll_page(parent: Control, key: String, top := 40.0, bottom := 40.0) -> VBoxContainer:
	## A full-height scrolling page (lists that may not fit on short screens or in long languages).
	var sc := ScrollContainer.new()
	sc.name = key
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = top
	sc.offset_bottom = -bottom
	sc.offset_left = 20
	sc.offset_right = -20
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(v)
	return v

func _gems_row(size := 36) -> HBoxContainer:
	var gems := HBoxContainer.new()
	gems.alignment = BoxContainer.ALIGNMENT_CENTER
	gems.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gems.add_child(UK.icon("res://assets/art/ui/gem_icon.png", Vector2(size * 1.1, size * 1.45)))
	gems.add_child(UK.label(str(G.meta.crystals), size))
	return gems

func _space(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _btn(text: String, cb: Callable, teal := false, sz := Vector2(460, 92)) -> CenterContainer:
	return _center(UK.button(text, cb, teal, sz))

# ---------------------------------------------------------------- main menu

func show_menu() -> void:
	_stack.clear()
	_open("menu", func(l: Control):
		UK.dim(l, 0.55)
		var v := _column(l, 60, 13)
		v.add_child(_center(UK.icon("res://assets/art/ui/logo.png", Vector2(440, 236))))
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 26)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var best := UK.label(G.t("best_depth", {"n": G.meta.best}), 26, UK.CREAM, 6, "Rubik-Bold")
		line.add_child(best)
		var st := HBoxContainer.new()
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.add_child(UK.icon(UK.ART + "star_on.png", Vector2(30, 30)))
		st.add_child(UK.label("%d/150" % G.level_stars_total(), 26, UK.CREAM, 6, "Rubik-Bold"))
		line.add_child(st)
		line.add_child(_gems_row(30))
		v.add_child(line)
		v.add_child(_space(4))
		var kind: String = main.saved_kind()
		if kind != "":
			var cap := G.t("continue")
			if kind == "endless":
				cap = G.t("continue_endless", {"n": int(G.run.get("depth", 0))})
			else:
				var lid := String(G.run.get("level", {}).get("id", ""))
				cap = G.t("continue_level", {"n": int(main.level_by_id(lid).get("n", 1))})
			v.add_child(_btn(cap, func(): main.menu_continue(), false, Vector2(560, 92)))
		v.add_child(_btn(G.t("endless"), func(): main.menu_endless(), kind != "", Vector2(560, 92)))
		v.add_child(_btn(G.t("levels"), func(): show_levels(), false, Vector2(560, 92)))
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 14)
		h.add_child(UK.button(G.t("shop"), func(): show_shop(), true, Vector2(273, 84)))
		h.add_child(UK.button(G.t("settings"), func(): show_settings(), true, Vector2(273, 84)))
		v.add_child(h)
		v.add_child(_btn(G.t("support"), func(): show_support(), true, Vector2(560, 80)))
		var ver := UK.label(G.t("version", {"v": G.VERSION}), 20, Color(0.75, 0.9, 0.88, 0.7), 4, "Rubik-Bold")
		ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ver))

func confirm(text: String, yes: Callable) -> void:
	_open("confirm", func(l: Control):
		UK.dim(l, 0.7)
		var v := _card(l, 620)
		v.add_child(UK.wrap(text, 28, 540))
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 20)
		h.add_child(UK.button(G.t("yes"), yes, false, Vector2(250, 90)))
		h.add_child(UK.button(G.t("no"), func(): back(), true, Vector2(250, 90)))
		v.add_child(h))

# ---------------------------------------------------------------- settings

func show_settings() -> void:
	_open("settings", func(l: Control):
		UK.dim(l, 0.78)
		var v := _scroll_page(l, "settings_scroll", 30, 30)
		v.add_child(UK.title(G.t("settings"), 44, 660))
		var lang := HBoxContainer.new()
		var ll := UK.label(G.t("language"), 28, UK.CREAM, 6, "Rubik-Bold")
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lang.add_child(ll)
		lang.add_child(UK.button(I18N.native_name(G.settings.lang), func(): show_languages(), true, Vector2(330, 74)))
		v.add_child(lang)
		v.add_child(_toggle_row("sound", func(on): G.settings.sound = on))
		v.add_child(_toggle_row("music", func(on):
			G.settings.music = on
			G.apply_music()))
		v.add_child(_toggle_row("vibration", func(on):
			G.settings.vibration = on
			if on:
				G.vibrate(40)))
		v.add_child(_toggle_row("reduced_fx", func(on): G.settings.reduced_fx = on))
		v.add_child(UK.label(G.t("shake"), 28, UK.CREAM, 6, "Rubik-Bold"))
		var shake := HBoxContainer.new()
		shake.alignment = BoxContainer.ALIGNMENT_CENTER
		shake.add_theme_constant_override("separation", 8)
		for i in 4:
			var lv := i
			var b := UK.button(G.t("shake_%d" % i), func():
				G.settings.shake = lv
				G.save_game()
				main.preview_shake()
				rebuild(), true, Vector2(156, 70))
			if int(G.settings.shake) == i:
				b.theme_type_variation = "OnButton"
			shake.add_child(b)
		v.add_child(shake)
		v.add_child(_space(6))
		v.add_child(_btn(G.t("replay_tutorial"), func():
			G.meta.tutorial = 0
			G.save_game()
			main.tutorial_reset()
			toast(G.t("tutorial_reset")), true, Vector2(560, 80)))
		v.add_child(_btn(G.t("restore"), func(): _restore(), true, Vector2(560, 80)))
		if Ads.privacy_required and not G.is_ad_free():
			v.add_child(_btn(G.t("privacy_options"), func(): Ads.show_privacy_options(), true, Vector2(560, 80)))
		v.add_child(_btn(G.t("back"), func(): back(), false, Vector2(320, 88)))
		var ver := UK.label(G.t("version", {"v": G.VERSION}), 20, Color(0.75, 0.9, 0.88, 0.7), 4, "Rubik-Bold")
		ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ver))

func _toggle_row(key: String, setter: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := UK.label(G.t(key), 28, UK.CREAM, 6, "Rubik-Bold")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	var on: bool = G.settings[key]
	var b := UK.button(G.t("on") if on else G.t("off"), func():
		setter.call(not on)
		G.save_game()
		rebuild(), true, Vector2(190, 70))
	if on:
		b.theme_type_variation = "OnButton"
	h.add_child(b)
	return h

func show_languages() -> void:
	_open("lang", func(l: Control):
		UK.dim(l, 0.8)
		var v := _scroll_page(l, "lang_scroll", 30, 30)
		v.add_child(UK.title(G.t("language"), 44, 660))
		for code in I18N.codes():
			var c: String = code
			var b := UK.button(I18N.native_name(c), func():
				G.set_lang(c)
				back(), true, Vector2(560, 76))
			# each name in its own script: the right fallback order is already in place for CJK
			if G.settings.lang == c:
				b.theme_type_variation = "OnButton"
			v.add_child(_center(b))
		v.add_child(_btn(G.t("back"), func(): back(), false, Vector2(320, 88))))

func _restore() -> void:
	toast(G.t("restoring"))
	Store.restore()

# ---------------------------------------------------------------- shop

func show_shop(tab := "") -> void:
	if tab != "":
		shop_tab = tab
	_open("shop", func(l: Control):
		UK.dim(l, 0.84)
		var root := VBoxContainer.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.offset_left = 20
		root.offset_right = -20
		root.offset_top = 24
		root.offset_bottom = -20
		root.add_theme_constant_override("separation", 10)
		l.add_child(root)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		var tl := UK.label(G.t("shop"), 42)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UK.fit_label(tl, 420)
		top.add_child(tl)
		top.add_child(_gems_row(32))
		root.add_child(top)
		var tabs := HBoxContainer.new()
		tabs.alignment = BoxContainer.ALIGNMENT_CENTER
		tabs.add_theme_constant_override("separation", 8)
		for t in [["ball", "tab_balls"], ["cannon", "tab_cannons"], ["noads", "tab_noads"]]:
			var id: String = t[0]
			var b := UK.button(G.t(t[1]), func():
				shop_tab = id
				rebuild(), true, Vector2(218, 70))
			if shop_tab == id:
				b.theme_type_variation = "OnButton"
			tabs.add_child(b)
		root.add_child(tabs)
		if shop_tab == "noads":
			var sc := ScrollContainer.new()
			sc.name = "noads_scroll"
			sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			root.add_child(sc)
			var inner := VBoxContainer.new()
			inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inner.add_theme_constant_override("separation", 12)
			sc.add_child(inner)
			_noads_body(inner)
		else:
			_skin_tab(root, shop_tab)
		var bottom := HBoxContainer.new()
		bottom.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom.add_theme_constant_override("separation", 12)
		bottom.add_child(UK.button(G.t("restore"), func(): _restore(), true, Vector2(330, 80)))
		bottom.add_child(UK.button(G.t("back"), func():
			main.apply_skins()
			back(), false, Vector2(300, 80)))
		root.add_child(bottom))

func _skin_tab(root: VBoxContainer, kind: String) -> void:
	var list: Array = CATALOG.skins(kind)
	var focus: String = shop_focus[kind]
	if focus == "":
		focus = G.selected(kind)
	shop_focus[kind] = focus
	var sk: Dictionary = CATALOG.skin(kind, focus)
	# the large preview of the item in focus, its name, how to get it, its action
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UK.sbt("card.png", 40, Vector4(20, 18, 20, 18)))
	root.add_child(pc)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pc.add_child(pv)
	var prev: Control
	if kind == "ball":
		var bp := PV.BallPreview.new()
		bp.setup(focus)
		prev = bp
	else:
		var cp := PV.CannonPreview.new()
		cp.setup(focus)
		prev = cp
	prev.custom_minimum_size = Vector2(620, 250)
	pv.add_child(prev)
	var nm := UK.title(G.t("%s_%s" % [kind, focus]), 34, 620)
	pv.add_child(nm)
	pv.add_child(UK.wrap(G.t("%s_%s_d" % [kind, focus]), 22, 620, Color(0.86, 0.95, 0.92)))
	pv.add_child(UK.wrap(_how_text(kind, sk), 21, 620, UK.TEAL))
	var act := HBoxContainer.new()
	act.alignment = BoxContainer.ALIGNMENT_CENTER
	act.add_theme_constant_override("separation", 10)
	_skin_actions(act, kind, sk)
	pv.add_child(act)
	# the list: tap an item to see it; buying needs the button above
	var sc := ScrollContainer.new()
	sc.name = "shop_%s_scroll" % kind
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	for item in list:
		grid.add_child(_skin_card(kind, item, item.id == focus))

func _how_text(kind: String, sk: Dictionary) -> String:
	if G.owns(kind, sk.id):
		return G.t("owned_hint")
	match sk.how:
		"free":
			return G.t("how_free")
		"crystals":
			return G.t("how_crystals", {"n": sk.cost})
		_:
			return G.t("how_play")

func _skin_actions(box: HBoxContainer, kind: String, sk: Dictionary) -> void:
	var id: String = sk.id
	if G.selected(kind) == id:
		var b := UK.button(G.t("selected"), func(): pass, true, Vector2(360, 84))
		b.theme_type_variation = "OnButton"
		box.add_child(b)
	elif G.owns(kind, id):
		box.add_child(UK.button(G.t("select"), func():
			G.select_skin(kind, id)
			main.apply_skins()
			G.sfx("upgrade", -6.0)
			rebuild(), false, Vector2(360, 84)))
	elif sk.how == "crystals":
		var cost: int = sk.cost
		var b := UK.button(G.t("buy_crystals", {"n": cost}), func():
			if G.buy_with_crystals(kind, id):
				G.sfx("buy")
				main.apply_skins()
				toast(G.t("bought"))
			else:
				G.sfx("deny")
				toast(G.t("not_enough"))
			rebuild(), false, Vector2(360, 84))
		b.icon = load("res://assets/art/ui/gem_icon.png")
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 28)
		if G.meta.crystals < cost:
			b.modulate = Color(0.8, 0.8, 0.8)
		box.add_child(b)
	elif sk.how == "play":
		_store_buttons(box, String(sk.product), Vector2(380, 84))

func _skin_card(kind: String, item: Dictionary, focused: bool) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(206, 172)
	b.theme_type_variation = "TealButton"
	var sb := UK.sbt("button_on.png" if focused else "card.png", 26 if focused else 40, Vector4(8, 8, 8, 8))
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func():
		G.sfx("click", -6.0)
		shop_focus[kind] = item.id
		rebuild())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 8
	v.offset_bottom = -6
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tex := "res://assets/art/balls/icon_%s.png" % item.id if kind == "ball" else "res://assets/art/cannon/icon_%s.png" % item.id
	var ic := UK.icon(tex, Vector2(140, 88))
	if not G.owns(kind, item.id):
		ic.modulate = Color(0.75, 0.75, 0.75)
	v.add_child(_center(ic))
	var nm := UK.label(G.t("%s_%s" % [kind, item.id]), 19, UK.CREAM, 5, "Rubik-Bold")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size = Vector2(190, 0)
	UK.fit_label(nm, 190, 14)
	v.add_child(nm)
	var state := ""
	var col := UK.TEAL
	if G.selected(kind) == item.id:
		state = G.t("selected")
		col = Color("ffd36b")
	elif G.owns(kind, item.id):
		state = G.t("owned")
	elif item.how == "crystals":
		state = G.t("cost_crystals", {"n": item.cost})
	else:
		var p := Store.price(String(item.product))
		state = p if p != "" else G.t("google_play")
	var sl := UK.label(state, 18, col, 5, "Rubik-Bold")
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.custom_minimum_size = Vector2(190, 0)
	UK.fit_label(sl, 190, 13)
	v.add_child(sl)
	return b

func _store_buttons(box: Container, pid: String, sz: Vector2, label_key := "buy_price") -> void:
	## A Google Play item: its price exactly as Google Play formats it, or why it cannot be bought now.
	if Store.owned(pid):
		var o := UK.button(G.t("owned"), func(): pass, true, sz)
		o.theme_type_variation = "OnButton"
		box.add_child(o)
		return
	var st := Store.state(pid)
	var price := Store.price(pid)
	if st == "busy":
		var b := UK.button(G.t("opening_play"), func(): pass, true, sz)
		b.disabled = true
		box.add_child(b)
	elif st == "pending":
		var b := UK.button(G.t("pending_short"), func(): Store.restore(), true, sz)
		box.add_child(b)
	elif not Store.is_ready() or st == "missing" or price == "":
		var b := UK.button(G.t("unavailable"), func(): pass, true, Vector2(sz.x - 120, sz.y))
		b.disabled = true
		box.add_child(b)
		box.add_child(UK.button(G.t("retry"), func():
			Store.refresh_details()
			toast(G.t("connecting_play")), false, Vector2(170, sz.y)))
	else:
		box.add_child(UK.button(G.t(label_key, {"price": price}), func():
			if Store.buy(pid):
				rebuild(), false, sz))

# ---------------------------------------------------------------- Ad-Free

func _noads_body(v: VBoxContainer) -> void:
	v.add_child(UK.title(G.t("noads_title"), 38, 640))
	if G.is_ad_free():
		v.add_child(UK.wrap(G.t("noads_active"), 26, 620, Color("ffd36b")))
	v.add_child(UK.wrap(G.t("noads_includes"), 24, 620, UK.TEAL, HORIZONTAL_ALIGNMENT_LEFT))
	for k in ["noads_inc_1", "noads_inc_2", "noads_inc_3", "noads_inc_4"]:
		v.add_child(UK.wrap("•  " + G.t(k), 22, 620, UK.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UK.wrap(G.t("noads_not"), 21, 620, Color(0.8, 0.88, 0.86), HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UK.wrap(G.t("noads_restore_hint"), 19, 620, Color(0.7, 0.85, 0.83), HORIZONTAL_ALIGNMENT_LEFT))
	var act := HBoxContainer.new()
	act.alignment = BoxContainer.ALIGNMENT_CENTER
	act.add_theme_constant_override("separation", 10)
	_store_buttons(act, "db_no_ads", Vector2(420, 88))
	v.add_child(act)

func show_noads() -> void:
	## Opened from the second-chance screen: buying keeps the run, back returns to the same choice.
	_open("noads", func(l: Control):
		UK.dim(l, 0.82)
		var v := _card(l, 680)
		_noads_body(v)
		v.add_child(_btn(G.t("back"), func(): back(), true, Vector2(320, 84))))

# ---------------------------------------------------------------- support the creator

func show_support() -> void:
	_open("support", func(l: Control):
		UK.dim(l, 0.82)
		var v := _scroll_page(l, "support_scroll", 60, 30)
		v.add_child(UK.title(G.t("support"), 42, 660))
		v.add_child(_center(UK.icon("res://assets/art/ui/gem_icon.png", Vector2(84, 112))))
		v.add_child(_center(UK.wrap(G.t("support_text"), 26, 620)))
		if int(G.support.count) > 0:
			v.add_child(_center(UK.wrap(G.tn("support_count", int(G.support.count)), 22, 620, Color("ffd36b"))))
		v.add_child(_space(6))
		for pid in CATALOG.SUPPORT:
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10)
			var nl := UK.label(G.t(pid), 26, UK.CREAM, 6, "Rubik-Bold")
			nl.custom_minimum_size = Vector2(220, 0)
			UK.fit_label(nl, 220, 16)
			row.add_child(nl)
			_store_buttons(row, pid, Vector2(360, 84), "give_price")
			v.add_child(row)
		v.add_child(_center(UK.wrap(G.t("support_note"), 19, 620, Color(0.75, 0.88, 0.86))))
		v.add_child(_btn(G.t("back"), func(): back(), false, Vector2(320, 88))))

func show_thanks() -> void:
	_open("thanks", func(l: Control):
		UK.dim(l, 0.8)
		var v := _card(l, 620)
		v.add_child(_center(UK.icon("res://assets/art/ui/gem_icon.png", Vector2(84, 112))))
		v.add_child(UK.title(G.t("thanks_title"), 40, 560))
		v.add_child(UK.wrap(G.t("thanks_text"), 25, 540))
		v.add_child(_btn(G.t("close"), func(): back(), false, Vector2(320, 88))))

# ---------------------------------------------------------------- levels

func show_levels() -> void:
	_stack.clear()
	_open("levels", func(l: Control):
		UK.dim(l, 0.82)
		var root := VBoxContainer.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.offset_left = 20
		root.offset_right = -20
		root.offset_top = 24
		root.offset_bottom = -20
		root.add_theme_constant_override("separation", 10)
		l.add_child(root)
		var top := HBoxContainer.new()
		var tl := UK.label(G.t("levels"), 42)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UK.fit_label(tl, 380)
		top.add_child(tl)
		var st := HBoxContainer.new()
		st.add_child(UK.icon(UK.ART + "star_on.png", Vector2(36, 36)))
		st.add_child(UK.label("%d/150" % G.level_stars_total(), 30))
		top.add_child(st)
		root.add_child(top)
		var sc := ScrollContainer.new()
		sc.name = "levels_scroll"
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		root.add_child(sc)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 12)
		sc.add_child(v)
		var unlocked := int(G.levels.unlocked)
		var cur_chapter := clampi((unlocked - 1) / 10, 0, 4)
		var anchor: Control = null
		for ch in 5:
			var first := ch * 10 + 1
			var open := first <= unlocked
			var hdr := PanelContainer.new()
			hdr.add_theme_stylebox_override("panel", UK.sbt("card.png", 40, Vector4(22, 14, 22, 14)))
			var hv := VBoxContainer.new()
			hdr.add_child(hv)
			var hh := HBoxContainer.new()
			var cl := UK.label(G.t("chapter_n", {"n": ch + 1}) + " · " + G.t(CHAPTERS[ch]), 28)
			cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UK.fit_label(cl, 470, 16)
			hh.add_child(cl)
			var cs := 0
			for i in 10:
				cs += int(G.levels.stars.get("L%02d" % (first + i), 0))
			var cst := HBoxContainer.new()
			cst.add_child(UK.icon(UK.ART + "star_on.png", Vector2(26, 26)))
			cst.add_child(UK.label("%d/30" % cs, 24, UK.CREAM, 6, "Rubik-Bold"))
			hh.add_child(cst)
			hv.add_child(hh)
			if not open:
				hv.add_child(UK.wrap(G.t("chapter_locked", {"n": first}), 20, 600, Color(0.7, 0.82, 0.8), HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(hdr)
			if ch == cur_chapter:
				anchor = hdr
			var grid := GridContainer.new()
			grid.columns = 5
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			for i in 10:
				grid.add_child(_level_button(first + i, unlocked))
			v.add_child(_center(grid))
			if open:
				hdr.modulate = Color.WHITE
			else:
				hdr.modulate = Color(0.75, 0.75, 0.75)
		root.add_child(_btn(G.t("back"), func():
			main.mode = main.M_MENU
			show_menu(), false, Vector2(320, 84)))
		if anchor != null and not _scroll_keep.has("levels_scroll"):
			_scroll_to(sc, anchor))

func _scroll_to(sc: ScrollContainer, c: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sc) and is_instance_valid(c):
		sc.scroll_vertical = int(c.position.y)

func _level_button(n: int, unlocked: int) -> Control:
	var id := "L%02d" % n
	var stars := int(G.levels.stars.get(id, 0))
	var locked := n > unlocked
	var is_current := n == unlocked and stars == 0
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(116, 124)
	b.theme_type_variation = "OnButton" if is_current else "TealButton"
	b.disabled = locked
	b.pressed.connect(func():
		G.sfx("click", -4.0)
		main.menu_level(n))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if locked:
		v.add_child(_center(UK.icon(UK.ART + "lock.png", Vector2(44, 44))))
		b.modulate = Color(0.7, 0.7, 0.7)
	else:
		var nl := UK.label(str(n), 40)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		v.add_child(UK.stars(stars, 26))
	return b

func level_rules(lv: Dictionary, v: VBoxContainer) -> void:
	## Goal, balls, upgrades and the volleys for each star: shown before the start and in the pause.
	var stones := 0
	for row in lv.rows:
		stones += row.size()
	v.add_child(UK.wrap(G.tn("goal_stones", stones), 26, 600, UK.CREAM))
	var bl := G.balls_text(int(lv.balls))
	var ups: Array = lv.get("upgrades", [])
	var extra: Array = []
	if int(lv.get("heavy", 0)) > 0:
		extra.append(G.t("start_heavy", {"n": int(lv.heavy)}))
	if int(lv.get("electric", 0)) > 0:
		extra.append(G.t("start_electric", {"n": int(lv.electric)}))
	var line := G.t("start_balls", {"balls": bl})
	if not extra.is_empty():
		line += "  ·  " + "  ·  ".join(extra)
	v.add_child(UK.wrap(line, 22, 600, UK.TEAL))
	if ups.is_empty() or int(lv.get("upgrade_every", 0)) <= 0:
		v.add_child(UK.wrap(G.t("no_upgrades"), 21, 600, Color(0.82, 0.92, 0.9)))
	else:
		var names: Array = []
		for u in ups:
			names.append(G.t("up_" + String(u)))
		v.add_child(UK.wrap(G.tn("upgrades_every", int(lv.upgrade_every), {"list": ", ".join(names)}), 21, 600, Color(0.82, 0.92, 0.9)))
	for s in [3, 2, 1]:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		h.add_child(UK.stars(s, 28))
		var txt := G.t("star_clear")
		if s == 3:
			txt = G.tn("star_volleys", int(lv.t3))
		elif s == 2:
			txt = G.tn("star_volleys", int(lv.t2))
		var tl := UK.label(txt, 22, UK.CREAM, 5, "Rubik-Bold")
		tl.custom_minimum_size = Vector2(400, 0)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(tl)
		v.add_child(h)
	v.add_child(UK.wrap(G.t("star_revive_note"), 18, 600, Color(0.72, 0.85, 0.83)))

func show_level_intro(n: int) -> void:
	var lv: Dictionary = main.level_n(n)
	if lv.is_empty():
		return
	_open("intro", func(l: Control):
		UK.dim(l, 0.74)
		var v := _card(l, 660)
		v.add_child(UK.title(G.t("level_n", {"n": n}), 46, 600))
		var ch := clampi((n - 1) / 10, 0, 4)
		v.add_child(UK.title(G.t(CHAPTERS[ch]), 26, 600))
		var best := int(G.levels.stars.get(lv.id, 0))
		if best > 0:
			var bh := HBoxContainer.new()
			bh.alignment = BoxContainer.ALIGNMENT_CENTER
			bh.add_theme_constant_override("separation", 10)
			bh.add_child(UK.label(G.t("best_result"), 22, UK.TEAL, 5, "Rubik-Bold"))
			bh.add_child(UK.stars(best, 28))
			v.add_child(bh)
		if String(lv.get("hint", "")) != "":
			v.add_child(UK.wrap(G.t(String(lv.hint)), 21, 600, Color("ffd36b")))
		level_rules(lv, v)
		v.add_child(_btn(G.t("start"), func(): main.start_level(n), false, Vector2(440, 92)))
		v.add_child(_btn(G.t("back"), func():
			if _stack.is_empty():
				show_levels()
			else:
				back(), true, Vector2(320, 80))))

# ---------------------------------------------------------------- in-run overlays

func show_pause() -> void:
	_stack.clear()
	_open("pause", func(l: Control):
		UK.dim(l, 0.66)
		var s: Sim = main.sim
		var v := _card(l, 640)
		v.add_child(UK.title(G.t("paused"), 46, 580))
		if s.mode == "level":
			var lv: Dictionary = main.level
			v.add_child(UK.title(G.t("level_n", {"n": int(lv.get("n", 1))}) + " · " + G.t(CHAPTERS[main.chapter_of(lv)]), 24, 580))
			v.add_child(UK.wrap(G.t("pause_level_state", {"stones": s.remaining_targets(), "volleys": s.volleys}), 22, 580, UK.TEAL))
			var rules := VBoxContainer.new()
			for st in [3, 2]:
				var h := HBoxContainer.new()
				h.alignment = BoxContainer.ALIGNMENT_CENTER
				h.add_theme_constant_override("separation", 10)
				h.add_child(UK.stars(st, 24))
				h.add_child(UK.label(G.tn("star_volleys", int(lv.t3 if st == 3 else lv.t2)), 20, UK.CREAM, 5, "Rubik-Bold"))
				rules.add_child(h)
			v.add_child(rules)
			if s.revive_used:
				v.add_child(UK.wrap(G.t("star_revive_used"), 18, 580, Color(0.75, 0.88, 0.86)))
		else:
			var d := UK.label(G.t("depth", {"n": s.depth}) + "   ·   " + G.balls_text(s.balls), 26, UK.TEAL, 6, "Rubik-Bold")
			d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(d)
		v.add_child(_btn(G.t("resume"), func(): main.resume_from_pause()))
		if s.mode == "level":
			v.add_child(_btn(G.t("restart_level"), func(): confirm(G.t("restart_level_q"), func(): main.retry_level_now()), true))
		var h2 := HBoxContainer.new()
		h2.alignment = BoxContainer.ALIGNMENT_CENTER
		h2.add_theme_constant_override("separation", 12)
		h2.add_child(UK.button(G.t("shop"), func(): show_shop(), true, Vector2(224, 84)))
		h2.add_child(UK.button(G.t("settings"), func(): show_settings(), true, Vector2(224, 84)))
		v.add_child(h2)
		if s.mode == "endless":
			v.add_child(_btn(G.t("end_run"), func(): confirm(G.t("end_run_q"), func(): main.end_run_now()), true))
		v.add_child(_btn(G.t("main_menu"), func(): main.to_menu(), true)))

func show_upgrade(opts: Array) -> void:
	_stack.clear()
	_open("upgrade", func(l: Control):
		UK.dim(l, 0.6)
		var v := _column(l, 0, 16)
		v.add_child(UK.title(G.t("choose_upgrade"), 44, 640))
		if int(G.meta.tutorial) >= 4 and int(G.meta.tutorial) < 6:
			v.add_child(_center(UK.wrap(G.t("tut_upgrade"), 24, 620, UK.TEAL)))
		for id in opts:
			v.add_child(_center(_upgrade_card(id))))

func _upgrade_card(id: String) -> Control:
	var s: Sim = main.sim
	var b := Button.new()
	b.theme_type_variation = "TealButton"
	b.custom_minimum_size = Vector2(640, 196)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UK.sbt("card.png", 40))
	b.add_theme_stylebox_override("hover", UK.sbt("card.png", 40))
	b.add_theme_stylebox_override("pressed", UK.sbt("button_teal_hover.png", 26))
	b.pressed.connect(func():
		G.sfx("upgrade")
		main.pick_upgrade(id))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.offset_right = -22
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(_center(UK.icon("res://assets/art/ui/up_%s.png" % id, Vector2(120, 120))))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var lvl := ""
	var desc := ""
	match id:
		"balls":
			var to := mini(Sim.MAX_BALLS, s.balls + Sim.BALLS_STEP)
			lvl = "%d → %d" % [s.balls, to]
			desc = G.t("up_balls_d", {"n": s.balls, "m": to})
		"heavy":
			lvl = G.t("level_to", {"n": s.heavy, "m": s.heavy + 1})
			desc = G.t("up_heavy_d", {"n": Sim.HEAVY_DMG[s.heavy + 1]})
		"electric":
			lvl = G.t("level_to", {"n": s.electric, "m": s.electric + 1})
			desc = G.t("up_electric_d", {"n": Sim.ZAP_DMG[s.electric + 1]})
	var nm := UK.label(G.t("up_" + id), 31)
	UK.fit_label(nm, 440, 18)
	v.add_child(nm)
	v.add_child(UK.label(lvl, 23, UK.TEAL, 6))
	var dl := UK.label(desc, 20, Color(0.9, 0.95, 0.92), 4, "Rubik-Bold")
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(440, 0)
	v.add_child(dl)
	return b

# ---------------------------------------------------------------- second chance

func show_revive() -> void:
	_stack.clear()
	_open("revive", func(l: Control):
		UK.dim(l, 0.62)
		var s: Sim = main.sim
		var v := _card(l, 660)
		v.add_child(UK.title(G.t("revive_title"), 40, 600))
		v.add_child(UK.wrap(G.t("revive_text_level" if s.mode == "level" else "revive_text"), 23, 600))
		if s.mode == "level":
			v.add_child(UK.wrap(G.t("revive_stars_note"), 19, 600, Color(0.75, 0.88, 0.86)))
		v.add_child(_space(4))
		v.add_child(_ad_button("revive", "revive_ad", "revive_free", func(): main.revive_with_ad()))
		v.add_child(_btn(G.t("end_run_btn") if s.mode == "endless" else G.t("end_attempt"), func(): main.decline_revive(), true, Vector2(460, 84)))
		if not G.is_ad_free():
			var link := UK.button(G.t("noads_link"), func(): show_noads(), true, Vector2(460, 66))
			link.add_theme_font_size_override("font_size", 22)
			v.add_child(_center(link)))

func _ad_button(placement: String, key_ad: String, key_free: String, cb: Callable, sz := Vector2(520, 92)) -> Control:
	## The button that starts a rewarded video: active only when the video is ready.
	## Ad-Free owners get the same action without a video.
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	if G.is_ad_free():
		box.add_child(UK.button(G.t(key_free), cb, false, sz))
		return box
	var st := Ads.status(placement)
	if st == "ready":
		var b := UK.button(G.t(key_ad), cb, false, sz)
		b.icon = load("res://assets/art/ui/video.png")
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 40)
		box.add_child(b)
	elif st == "loading":
		var b := UK.button(G.t("ad_loading"), func(): pass, false, sz)
		b.disabled = true
		box.add_child(b)
	else:
		var b := UK.button(G.t("ad_unavailable"), func(): pass, false, Vector2(sz.x - 170, sz.y))
		b.disabled = true
		box.add_child(b)
		box.add_child(UK.button(G.t("retry"), func():
			Ads.load_ad(placement)
			rebuild(), true, Vector2(160, sz.y)))
	return box

# ---------------------------------------------------------------- results

func _double_row(v: VBoxContainer) -> void:
	var r := G.result
	if int(r.gems) <= 0:
		return
	if bool(r.doubled):
		var b := UK.button(G.t("doubled", {"n": int(r.gems)}), func(): pass, true, Vector2(520, 84))
		b.disabled = true
		v.add_child(_center(b))
		return
	v.add_child(_ad_button("double", "double_ad", "double_free", func(): main.double_with_ad()))

func _gem_stat(title: String, value: String, size := 34) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(540, 0)
	var t := UK.label(title, 24, Color(0.85, 0.95, 0.92), 6, "Rubik-Bold")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(t)
	h.add_child(UK.icon("res://assets/art/ui/gem_icon.png", Vector2(30, 40)))
	h.add_child(UK.label(value, size))
	return h

func _stat(title: String, value: String, size: int) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(540, 0)
	var t := UK.label(title, 24, Color(0.85, 0.95, 0.92), 6, "Rubik-Bold")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(t)
	h.add_child(UK.label(value, size))
	return h

func show_gameover() -> void:
	_stack.clear()
	_open("over", func(l: Control):
		UK.dim(l, 0.7)
		var r := G.result
		var v := _card(l, 640)
		v.add_child(UK.title(G.t("run_over"), 48, 580))
		if r.record:
			v.add_child(UK.title(G.t("new_record"), 32, 580))
		v.add_child(_stat(G.t("depth_reached"), G.t("meters", {"n": r.depth}), 42))
		v.add_child(_stat(G.t("record"), G.t("meters", {"n": G.meta.best}), 28))
		var gems := int(r.gems) * (2 if bool(r.doubled) else 1)
		v.add_child(_gem_stat(G.t("crystals_earned"), "+%d" % gems))
		v.add_child(_stat(G.t("stones_broken"), str(r.broken), 26))
		v.add_child(_space(4))
		_double_row(v)
		v.add_child(_btn(G.t("play_again"), func(): main.play_again()))
		v.add_child(_btn(G.t("menu"), func(): main.result_to_menu(), true)))

func show_level_won() -> void:
	var r := G.result
	if bool(r.get("all_clear", false)) and not bool(r.get("all_clear_seen", false)):
		show_all_clear()
		return
	_stack.clear()
	_open("won", func(l: Control):
		UK.dim(l, 0.68)
		var n := int(r.level_n)
		var v := _card(l, 640)
		v.add_child(UK.title(G.t("level_done", {"n": n}), 44, 580))
		v.add_child(UK.stars(int(r.stars), 76))
		v.add_child(_stat(G.t("volleys_used"), str(r.volleys), 34))
		var lv: Dictionary = main.level_n(n)
		if int(r.stars) < 3 and not lv.is_empty():
			var need := int(lv.t2) if int(r.stars) == 1 else int(lv.t3)
			if bool(r.revived):
				v.add_child(UK.wrap(G.t("star_revive_used"), 19, 580, Color(0.75, 0.88, 0.86)))
			else:
				v.add_child(UK.wrap(G.tn("next_star_hint", need), 20, 580, UK.TEAL))
		var mult := 2 if bool(r.doubled) else 1
		v.add_child(_gem_stat(G.t("crystals_earned"), "+%d" % (int(r.gems) * mult)))
		if bool(r.first):
			v.add_child(UK.wrap(G.t("first_clear_bonus", {"n": int(r.bonus)}), 21, 580, Color("ffd36b")))
		_double_row(v)
		if n < main.levels.size():
			v.add_child(_btn(G.t("next_level"), func(): main.next_level()))
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		h.add_child(UK.button(G.t("retry"), func(): main.retry_level(), true, Vector2(250, 84)))
		h.add_child(UK.button(G.t("level_select"), func(): main.result_to_levels(), true, Vector2(290, 84)))
		v.add_child(h))

func show_level_lost() -> void:
	_stack.clear()
	_open("lost", func(l: Control):
		UK.dim(l, 0.7)
		var r := G.result
		var s: Sim = main.sim
		var v := _card(l, 640)
		v.add_child(UK.title(G.t("level_failed", {"n": int(r.level_n)}), 44, 580))
		v.add_child(UK.wrap(G.t("level_failed_text"), 22, 580))
		v.add_child(_stat(G.t("stones_left"), str(s.remaining_targets()), 34))
		var mult := 2 if bool(r.doubled) else 1
		v.add_child(_gem_stat(G.t("crystals_earned"), "+%d" % (int(r.gems) * mult)))
		_double_row(v)
		v.add_child(_btn(G.t("retry"), func(): main.retry_level()))
		v.add_child(_btn(G.t("level_select"), func(): main.result_to_levels(), true)))

func show_all_clear() -> void:
	_stack.clear()
	_open("allclear", func(l: Control):
		UK.dim(l, 0.72)
		var v := _card(l, 660)
		v.add_child(_center(UK.icon("res://assets/art/ui/logo.png", Vector2(380, 204))))
		v.add_child(UK.title(G.t("all_clear_title"), 40, 600))
		v.add_child(UK.wrap(G.t("all_clear_text", {"n": G.level_stars_total()}), 24, 600))
		v.add_child(_btn(G.t("continue"), func():
			G.result["all_clear_seen"] = true
			G.save_game()
			show_level_won())))
