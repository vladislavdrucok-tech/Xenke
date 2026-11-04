class_name UI
extends RefCounted
## Shared look: palette, fonts, pixel-perfect textures, buttons and panels.

const INK := Color("141224")
const INK2 := Color("1f1b33")
const INK3 := Color("2d2747")
const PAPER := Color("fff6e0")
const PAPER_DIM := Color("cdbca0")
const AMBER := Color("f5c056")
const CYAN := Color("7ff0f0")
const GREEN := Color("a6f0a0")
const MAGENTA := Color("ff8ae6")
const RED := Color("e0485a")
const GOLD := Color("ffe14d")
const MUTED := Color("9a92b8")

const DEST_COLORS := [Color("f5c056"), Color("a6f0a0"), Color("7ff0f0"), Color("ff8ae6")]
const PIX := 4   # art pixel -> screen pixel for most sprites

static var _tex_cache := {}
static var _theme: Theme
static var _font: FontFile
static var _font_bold: FontFile


static func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var t: Texture2D = load("res://assets/sprites/%s.png" % name)
	_tex_cache[name] = t
	return t


## Upscaled copy (nearest) so nine-patch borders keep chunky pixels.
static func tex_scaled(name: String, k: int) -> Texture2D:
	var key := "%s@%d" % [name, k]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := tex(name).get_image()
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


static func frames(name: String, count: int) -> Array:
	var key := "%s#%d" % [name, count]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var base := tex(name)
	var w := base.get_width() / count
	var out := []
	for i in count:
		var a := AtlasTexture.new()
		a.atlas = base
		a.region = Rect2(i * w, 0, w, base.get_height())
		out.append(a)
	_tex_cache[key] = out
	return out


static func font(bold: bool = false) -> FontFile:
	if bold:
		if _font_bold == null:
			_font_bold = load("res://assets/fonts/PixelifySans-700.ttf")
		return _font_bold
	if _font == null:
		_font = load("res://assets/fonts/PixelifySans-500.ttf")
	return _font


static func style(name: String, margin: int = 6, content: int = 14) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex_scaled(name, PIX)
	var m := margin * PIX / 2
	s.texture_margin_left = m
	s.texture_margin_right = m
	s.texture_margin_top = m
	s.texture_margin_bottom = m
	s.content_margin_left = content
	s.content_margin_right = content
	s.content_margin_top = content * 0.6
	s.content_margin_bottom = content * 0.6
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 30
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_focus_color", "Button", PAPER)
	t.set_stylebox("normal", "Button", style("ui_btn"))
	t.set_stylebox("hover", "Button", style("ui_btn"))
	t.set_stylebox("pressed", "Button", style("ui_btn_press"))
	t.set_stylebox("disabled", "Button", style("ui_btn_off"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", style("ui_panel", 6, 20))
	t.set_stylebox("panel", "Panel", style("ui_panel", 6, 20))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	# Sliders and checkboxes for settings
	var grab := tex_scaled("ic_coin", 3)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	var slider := StyleBoxFlat.new()
	slider.bg_color = INK3
	slider.content_margin_top = 6
	slider.content_margin_bottom = 6
	slider.corner_radius_top_left = 2
	t.set_stylebox("slider", "HSlider", slider)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK3
	t.set_stylebox("scroll", "VScrollBar", sb)
	var gb := StyleBoxFlat.new()
	gb.bg_color = Color("5d5480")
	t.set_stylebox("grabber", "VScrollBar", gb)
	t.set_stylebox("grabber_highlight", "VScrollBar", gb)
	t.set_stylebox("grabber_pressed", "VScrollBar", gb)
	_theme = t
	return t


static func label(text: String, size: int = 30, color: Color = PAPER, align: int = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(true))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func outlined(l: Label, px: int = 6) -> Label:
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_outline_color", INK)
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, kind: String = "normal", min_h: int = 96, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 32)
	if kind == "accent":
		b.add_theme_stylebox_override("normal", style("ui_btn_accent"))
		b.add_theme_stylebox_override("hover", style("ui_btn_accent"))
		b.add_theme_stylebox_override("pressed", style("ui_btn_accent_press"))
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK2)
		b.add_theme_font_override("font", font(true))
	elif kind == "cyan":
		b.add_theme_stylebox_override("normal", style("ui_btn_cyan"))
		b.add_theme_stylebox_override("hover", style("ui_btn_cyan"))
		b.add_theme_stylebox_override("pressed", style("ui_btn_press"))
	if icon_name != "":
		b.icon = tex_scaled(icon_name, 4)
		b.expand_icon = false
		b.add_theme_constant_override("h_separation", 14)
	b.pressed.connect(func(): Audio.play("click"))
	return b


static func image(name: String, scale: float = PIX) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = r.texture.get_size() * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel(kind: String = "ui_panel") -> PanelContainer:
	var p := PanelContainer.new()
	if kind != "ui_panel":
		p.add_theme_stylebox_override("panel", style(kind, 6, 20))
	return p


static func spacer(h: int = 0, w: int = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand_spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func icon_value(icon_name: String, text: String, size: int = 30, color: Color = PAPER) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := image(icon_name, 4)
	h.add_child(i)
	var l := label(text, size, color)
	l.name = "Value"
	h.add_child(l)
	return h


## Safe content rectangle (display cut-outs, status/navigation bars).
static func safe_margins(node: Control) -> Dictionary:
	var vp := node.get_viewport_rect().size
	var out := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not OS.has_feature("mobile"):
		return out
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0 or win.y <= 0:
		return out
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := vp / win
	out["top"] = max(0.0, safe.position.y * k.y)
	out["left"] = max(0.0, safe.position.x * k.x)
	out["bottom"] = max(0.0, (win.y - safe.end.y) * k.y)
	out["right"] = max(0.0, (win.x - safe.end.x) * k.x)
	return out


static func fmt(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func pop(node: CanvasItem, scale_from: float = 0.85) -> void:
	if not is_instance_valid(node):
		return
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2
	node.scale = Vector2.ONE * scale_from
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.12)


## Standard screen: office backdrop (dimmed), safe margins, a header with a
## back button and the currencies. Returns the content column.
static func screen_frame(parent: Control, title: String, show_money: bool = true, backdrop_kind: String = "office") -> VBoxContainer:
	var bd := Backdrop.new(backdrop_kind)
	parent.add_child(bd)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dim)
	var m := safe_margins(parent)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 20 + int(m["left"]))
	root.add_theme_constant_override("margin_right", 20 + int(m["right"]))
	root.add_theme_constant_override("margin_top", 20 + int(m["top"]))
	root.add_theme_constant_override("margin_bottom", 20 + int(m["bottom"]))
	parent.add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)
	var head := HBoxContainer.new()
	var back := button("", "normal", 80, "arrow_left")
	back.custom_minimum_size = Vector2(96, 80)
	back.pressed.connect(func():
		if parent.has_method("on_back"):
			parent.on_back()
		else:
			Game.goto("menu"))
	head.add_child(back)
	var t := outlined(label(title, 40, AMBER, 0, true), 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if show_money:
		var money := VBoxContainer.new()
		money.add_theme_constant_override("separation", 0)
		var c := icon_value("ic_coin", fmt(int(Game.profile["coins"])), 30, GOLD)
		c.name = "Coins"
		c.alignment = BoxContainer.ALIGNMENT_END
		money.add_child(c)
		var s := icon_value("ic_shard", str(int(Game.profile["shards"])), 26, CYAN)
		s.name = "Shards"
		s.alignment = BoxContainer.ALIGNMENT_END
		money.add_child(s)
		money.name = "Money"
		head.add_child(money)
	head.name = "Header"
	col.add_child(head)
	return col


static func scroll_column(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	sc.add_child(v)
	return v
