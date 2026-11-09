extends RefCounted
## Theme and small widget builders shared by the HUD and the screens.

const ART := "res://assets/art/ui/"
const CREAM := Color("fff0c8")
const DARK := Color("3a1a0a")
const TEAL := Color("7fe3d6")

static var _theme: Theme
static var _fonts := {}

static func font(name := "Rubik-ExtraBold") -> Font:
	if not _fonts.has(name):
		_fonts[name] = load("res://assets/fonts/%s.ttf" % name)
	return _fonts[name]

static func sbt(file: String, margin: float, content := Vector4(26, 14, 26, 14)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(ART + file)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("Rubik-Bold")
	t.default_font_size = 30
	# primary: warm stone plate; "teal" variation: dark metal frame
	t.set_stylebox("normal", "Button", sbt("button_stone.png", 34))
	t.set_stylebox("hover", "Button", sbt("button_stone_hover.png", 34))
	t.set_stylebox("pressed", "Button", sbt("button_stone_dim.png", 34))
	t.set_stylebox("disabled", "Button", sbt("button_stone_dim.png", 34))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", font("Rubik-ExtraBold"))
	t.set_font_size("font_size", "Button", 34)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(0.9, 0.85, 0.75))
	t.set_color("font_disabled_color", "Button", Color(0.75, 0.68, 0.58, 0.8))
	t.set_color("font_outline_color", "Button", DARK)
	t.set_constant("outline_size", "Button", 9)
	t.set_type_variation("TealButton", "Button")
	t.set_stylebox("normal", "TealButton", sbt("button_teal.png", 26))
	t.set_stylebox("hover", "TealButton", sbt("button_teal_hover.png", 26))
	t.set_stylebox("pressed", "TealButton", sbt("button_teal.png", 26))
	t.set_stylebox("disabled", "TealButton", sbt("button_teal.png", 26))
	t.set_font_size("font_size", "TealButton", 28)
	t.set_color("font_disabled_color", "TealButton", Color(0.55, 0.7, 0.68, 0.7))
	t.set_type_variation("OnButton", "Button")
	var on := sbt("button_teal_hover.png", 26)
	t.set_stylebox("normal", "OnButton", on)
	t.set_stylebox("hover", "OnButton", on)
	t.set_stylebox("pressed", "OnButton", on)
	t.set_font_size("font_size", "OnButton", 28)
	t.set_color("font_color", "OnButton", Color.WHITE)
	t.set_color("font_outline_color", "Label", DARK)
	t.set_color("font_color", "Label", CREAM)
	t.set_constant("outline_size", "Label", 8)
	t.set_font("font", "Label", font("Rubik-Bold"))
	t.set_stylebox("panel", "PanelContainer", sbt("card.png", 40, Vector4(34, 30, 34, 30)))
	_theme = t
	return t

static func label(text: String, size := 30, color := CREAM, outline := 8, font_name := "Rubik-ExtraBold") -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font(font_name)
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = DARK
	ls.shadow_size = 1
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(1, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, cb: Callable, teal := false, min_size := Vector2(440, 96)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if teal:
		b.theme_type_variation = "TealButton"
	b.pressed.connect(func():
		G.sfx("click", -4.0)
		cb.call())
	b.focus_mode = Control.FOCUS_NONE
	return b

static func icon(file: String, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = size
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func dim(parent: Control, alpha := 0.62) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.01, 0.05, 0.06, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = -400
	c.offset_right = 400
	c.offset_top = -400
	c.offset_bottom = 400
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(c)
	return c
