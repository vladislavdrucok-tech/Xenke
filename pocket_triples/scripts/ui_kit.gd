class_name UiKit
extends RefCounted
## Colours, fonts, the theme and small constructors shared by the HUD and the panels.

const BG := Color("f7f0e1")
const INK := Color("4a3424")
const INK_SOFT := Color("7d6550")
const PRIMARY := Color("3f6f8f")
const PRIMARY_DARK := Color("2f566f")
const ACCENT := Color("ff8a5c")
const CARD := Color("fffaf0")
const CARD_EDGE := Color("e6d5b8")
const WELL := Color("efe3cb")
const WOOD := Color("c99a6b")
const WOOD_LIGHT := Color("e9d2ab")
const SLOT := Color("f7ecd6")
const WARN := Color("f0a030")
const DANGER := Color("e0503a")
const GOOD := Color("4caf6a")
const GOLD := Color("ffb52e")

## Per tile type: symbol colour, light tile body, darker lip.
const TYPE_COLORS := [
	[Color("ff6f59"), Color("ffe3dc"), Color("e98a77")],
	[Color("43b05c"), Color("dcf2e1"), Color("7cc28e")],
	[Color("3b8be6"), Color("dce9fb"), Color("7aa9e6")],
	[Color("f5b400"), Color("fff1c2"), Color("e3bd50")],
	[Color("9863e0"), Color("ece2fa"), Color("ad8ae0")],
]
const TYPE_KEYS := ["TYPE_STAR", "TYPE_LEAF", "TYPE_WAVE", "TYPE_BOLT", "TYPE_DIAMOND"]

static var _fonts := {}
static var _textures := {}


static func font(weight := 700) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base: FontFile = load("res://assets/fonts/Nunito.ttf")
	var fv := FontVariation.new()
	fv.base_font = base
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: weight}
	_fonts[weight] = fv
	return fv


static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://assets/art/%s.png" % name)
	return _textures[name]


static func box(bg: Color, radius := 24, border := 0, border_color := Color.TRANSPARENT,
		shadow := 0, shadow_offset := Vector2(0, 4), shadow_color := Color(0.3, 0.2, 0.1, 0.18)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_offset = shadow_offset
		sb.shadow_color = shadow_color
	return sb


static func _button_styles(t: Theme, type_name: String, base: Color, dark: Color, text: Color) -> void:
	var normal := box(base, 26, 0, Color.TRANSPARENT, 6, Vector2(0, 5))
	normal.border_width_bottom = 6
	normal.border_color = dark
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 10
	normal.content_margin_bottom = 14
	var hover := normal.duplicate()
	hover.bg_color = base.lightened(0.06)
	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.06)
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 14
	pressed.content_margin_bottom = 10
	pressed.shadow_size = 2
	var disabled := normal.duplicate()
	disabled.bg_color = base.lerp(BG, 0.55)
	disabled.border_color = dark.lerp(BG, 0.55)
	t.set_stylebox("normal", type_name, normal)
	t.set_stylebox("hover", type_name, hover)
	t.set_stylebox("pressed", type_name, pressed)
	t.set_stylebox("hover_pressed", type_name, pressed)
	t.set_stylebox("disabled", type_name, disabled)
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type_name, text)
	t.set_color("font_disabled_color", type_name, text.lerp(BG, 0.4))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(c, type_name, text)
	t.set_color("icon_disabled_color", type_name, text.lerp(BG, 0.4))


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 30
	t.set_color("font_color", "Label", INK)
	_button_styles(t, "Button", PRIMARY, PRIMARY_DARK, Color.WHITE)
	t.set_type_variation("SoftButton", "Button")
	_button_styles(t, "SoftButton", CARD, CARD_EDGE.darkened(0.12), INK)
	t.set_type_variation("AccentButton", "Button")
	_button_styles(t, "AccentButton", ACCENT, Color("d9663b"), Color.WHITE)
	t.set_type_variation("ChosenButton", "Button")
	_button_styles(t, "ChosenButton", GOOD, Color("37894f"), Color.WHITE)
	t.set_constant("h_separation", "Button", 12)
	t.set_constant("icon_max_width", "Button", 44)
	t.set_font("font", "Button", font(800))
	return t


static func label(text := "", size := 30, weight := 700, color := INK, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l


static func button(text := "", icon_name := "", variation := "", size := 30) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = tex("ic_" + icon_name)
		b.expand_icon = false
	if variation != "":
		b.theme_type_variation = variation
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, 92)
	b.clip_text = false
	return b


## Shrinks a label's or button's font until its text fits the given width.
static func fit_width(c: Control, max_size: int, min_size: int, width: float) -> void:
	var f: Font = c.get_theme_font("font")
	var s := max_size
	var extra := 0.0
	if c is Button and (c as Button).icon != null:
		extra = 44 + 12
	if c is Button:
		extra += 40
	while s > min_size:
		var w := 0.0
		for line in c.text.split("\n"):
			w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
		if w + extra <= width:
			break
		s -= 1
	c.add_theme_font_size_override("font_size", s)


static func text_width(c: Control) -> float:
	var f: Font = c.get_theme_font("font")
	var s: int = c.get_theme_font_size("font_size")
	var w := 0.0
	for line in c.text.split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
	return w
