extends Node
## UI construction helpers shared by every screen. Autoload "UI".
## Everything is built in code so the layout adapts to any portrait aspect ratio.

const FONT_PATH := "res://assets/fonts/pixelify_lot13.ttf"
const C_TEXT := Color("f2f0f5")
const C_DIM := Color("a89cc0")
const C_GOLD := Color("f8d448")
const C_GREEN := Color("8ad870")
const C_RED := Color("f07a80")
const C_BLUE := Color("86a6f0")
const C_DARK := Color("1a1626")
const C_BG := Color("16131f")
const C_WALL := Color("3e4a5c")
const C_FLOOR := Color("5a5560")

var _tex := {}
var _sb := {}


func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex[path] = t
	return t


func art(rel: String) -> Texture2D:
	return tex("res://assets/art/%s.png" % rel)


func icon_tex(icon_name: String) -> Texture2D:
	return art("icons/" + icon_name)


func item_tex(id: String) -> Texture2D:
	return art("items/" + id)


func box_tex(kind: String, opened: bool = false) -> Texture2D:
	return art("boxes/%s_%s" % [kind, "open" if opened else "closed"])


func portrait_tex(who: String) -> Texture2D:
	return art("portraits/" + who)


# ------------------------------------------------------------------ styleboxes
func sb(style: String, pad_h: int = 10, pad_top: int = 8, pad_bottom: int = 8) -> StyleBoxTexture:
	var key := "%s/%d/%d/%d" % [style, pad_h, pad_top, pad_bottom]
	if _sb.has(key):
		return _sb[key]
	var s := StyleBoxTexture.new()
	s.texture = art("ui/" + style)
	s.texture_margin_left = 8
	s.texture_margin_right = 8
	s.texture_margin_top = 8
	s.texture_margin_bottom = 8
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_top
	s.content_margin_bottom = pad_bottom
	_sb[key] = s
	return s


func flat(color: Color, border: Color = C_DARK, width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.border_width_left = width
	s.border_width_right = width
	s.border_width_top = width
	s.border_width_bottom = width
	return s


# ------------------------------------------------------------------ basic nodes
func label(text: String, size: int = 16, color: Color = C_TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func shadow(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.08, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func outlined(l: Label, width: int = 4) -> Label:
	l.add_theme_color_override("font_outline_color", C_DARK)
	l.add_theme_constant_override("outline_size", width)
	return l


func tex_rect(t: Texture2D, k: float = 2.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t != null:
		r.custom_minimum_size = t.get_size() * k
	return r


func icon(icon_name: String, k: float = 2.0) -> TextureRect:
	return tex_rect(icon_tex(icon_name), k)


func item_icon(id: String, k: float = 2.0) -> TextureRect:
	return tex_rect(item_tex(id), k)


func vbox(sep: int = 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func hbox(sep: int = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func grid(cols: int, sep: int = 6) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func margin(node: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node != null:
		m.add_child(node)
	return m


func panel(style: String = "panel", pad: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(style, pad, pad, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func spacer(h: int = 8, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func fill(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


func center(node: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(node)
	return c


func color_rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func bar(value: float, color: Color, h: int = 10) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.min_value = 0.0
	p.max_value = 1.0
	p.step = 0.001
	p.value = value
	p.custom_minimum_size = Vector2(0, h)
	p.add_theme_stylebox_override("background", flat(C_BG))
	p.add_theme_stylebox_override("fill", flat(color))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# ------------------------------------------------------------------ buttons
func style_button(b: Button, style: String, font_size: int = 16) -> void:
	var normal := sb("btn_" + style, 10, 5, 11)
	var pressed := sb("btn_%s_pressed" % style, 10, 9, 7)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", sb("btn_grey", 10, 5, 11))
	var fc := C_DARK if style == "gold" else C_TEXT
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color("9a9aae"))
	b.add_theme_font_size_override("font_size", font_size)


func button(text: String, style: String = "dark", font_size: int = 16, min_h: int = 48) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, min_h)
	b.clip_text = false
	style_button(b, style, font_size)
	return b


## A button with an icon above or beside its caption (children ignore the mouse so the button gets the tap).
func icon_button(icon_name: String, text: String, style: String = "dark", font_size: int = 12,
		min_size: Vector2 = Vector2(64, 64), vertical: bool = true, k: float = 2.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	style_button(b, style, font_size)
	var box: BoxContainer = vbox(0) if vertical else hbox(6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := icon(icon_name, k)
	box.add_child(center(ic))
	if text != "":
		var l := label(text, font_size, C_DARK if style == "gold" else C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		l.name = "Caption"
		box.add_child(l)
	var m := margin(box, 4, 2, 4, 6)
	full(m)
	b.add_child(m)
	return b


## Flat pressable area for custom content (tiles, cards).
func tile_button(style: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var s := sb(style, 6, 6, 6)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(k, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


# ------------------------------------------------------------------ text helpers
func money(n: int, sep: String = ",") -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = sep + out
	return ("-" if n < 0 else "") + "$" + out


func pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


# ------------------------------------------------------------------ animation helpers
func set_pivot_center(node: Control) -> void:
	var s := node.size
	if s == Vector2.ZERO:
		s = node.custom_minimum_size
	node.pivot_offset = s * 0.5


func pop(node: Control, from: float = 0.5, dur: float = 0.28, delay: float = 0.0) -> Tween:
	set_pivot_center(node)
	if not node.resized.is_connected(set_pivot_center.bind(node)):
		node.resized.connect(set_pivot_center.bind(node), CONNECT_ONE_SHOT)
	node.scale = Vector2(from, from)
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


func punch(node: Control, amount: float = 0.15, dur: float = 0.18) -> void:
	set_pivot_center(node)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * (1.0 + amount), dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, dur * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func shake(node: CanvasItem, strength: float = 6.0, dur: float = 0.3) -> void:
	var base: Vector2 = node.get("position")
	var tw := node.create_tween()
	var steps := 6
	for i in range(steps):
		var k := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * strength * k
		tw.tween_property(node, "position", base + off, dur / float(steps))
	tw.tween_property(node, "position", base, 0.04)


func fade_in(node: CanvasItem, dur: float = 0.2) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur)


func pulse(node: Control, amount: float = 0.06, period: float = 0.9) -> Tween:
	set_pivot_center(node)
	if not node.resized.is_connected(set_pivot_center.bind(node)):
		node.resized.connect(set_pivot_center.bind(node))
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2.ONE * (1.0 + amount), period * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE)
	return tw
