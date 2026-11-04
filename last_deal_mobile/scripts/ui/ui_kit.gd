class_name UIKit
extends RefCounted
## Палітра, тема та фабрики елементів інтерфейсу (великі сенсорні кнопки).

const BG := Color("#120d1c")
const PANEL := Color("#231936")
const PANEL_2 := Color("#2c2044")
const BORDER := Color("#4a3566")
const TEXT := Color("#f2e9ff")
const MUTED := Color("#a99cc4")
const PINK := Color("#ff3fa4")
const CYAN := Color("#3ff0ff")
const AMBER := Color("#ffb347")
const GREEN := Color("#5dff9e")
const RED := Color("#ff5d6e")
const VIOLET := Color("#8f6bff")

const FS_SMALL := 23
const FS := 27
const FS_BIG := 36
const FS_HUGE := 48

const BTN_H := 92

static var _theme: Theme
static var _font: Font
static var _bold: Font
static var _pixel: Font


static func font() -> Font:
	if _font == null:
		var main: FontFile = load("res://assets/fonts/Exo2-600.ttf")
		main.fallbacks = [load("res://assets/fonts/DejaVuSans-Bold.ttf")]
		_font = main
	return _font


static func bold() -> Font:
	if _bold == null:
		var f: FontFile = load("res://assets/fonts/Exo2-700.ttf")
		f.fallbacks = [load("res://assets/fonts/DejaVuSans-Bold.ttf")]
		_bold = f
	return _bold


## Піксельний шрифт для заголовків, цін і балансу.
static func pixel() -> Font:
	if _pixel == null:
		var f: FontFile = load("res://assets/fonts/Tiny5.ttf")
		f.fallbacks = [bold()]
		_pixel = f
	return _pixel


## Звільняє статичні ресурси (щоб не було попереджень про витоки при виході).
static func release() -> void:
	_theme = null
	_font = null
	_bold = null
	_pixel = null


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FS
	t.set_font("font", "Button", bold())
	t.set_font("font", "CheckButton", bold())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_stylebox("panel", "PanelContainer", panel_box())
	var normal := button_box(PANEL_2, BORDER)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", button_box(PANEL_2.darkened(0.3), BORDER, true))
	t.set_stylebox("disabled", "Button", button_box(Color("#1c1528"), Color("#2c2240")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# смуга прокрутки — широка, зручна пальцем
	var grab := StyleBoxFlat.new()
	grab.bg_color = BORDER
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", sb)
	_theme = t
	return t


static func panel_box(bg: Color = PANEL, border: Color = BORDER, bw: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func button_box(bg: Color, border: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.border_width_bottom = 3 if pressed else 7
	s.set_corner_radius_all(6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6 + (4 if pressed else 0)
	s.content_margin_bottom = 6
	return s


## Кольорова кнопка. kind: "primary" | "danger" | "accent" | "warn" | "neutral" | "pink"
static func button(text: String, kind: String = "neutral", font_size: int = FS, height: int = BTN_H) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	style_button(b, kind)
	return b


static func style_button(b: Button, kind: String) -> void:
	var c := PANEL_2
	var border := BORDER
	var fc := TEXT
	match kind:
		"primary":
			c = Color("#1f6b46")
			border = GREEN
		"danger":
			c = Color("#6b1f33")
			border = RED
		"accent":
			c = Color("#174e5e")
			border = CYAN
		"warn":
			c = Color("#6b4417")
			border = AMBER
		"pink":
			c = Color("#5e1745")
			border = PINK
	b.add_theme_stylebox_override("normal", button_box(c, border))
	b.add_theme_stylebox_override("hover", button_box(c, border))
	b.add_theme_stylebox_override("pressed", button_box(c.darkened(0.35), border, true))
	b.add_theme_stylebox_override("disabled", button_box(Color("#1c1528"), Color("#3a2e50")))
	b.add_theme_color_override("font_color", fc)


static func pixel_label(text: String, size: int = FS_BIG, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", pixel())
	return l


static func label(text: String, size: int = FS, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 10
	return l


static func panel(bg: Color = PANEL, border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(bg, border))
	return p


static func tex(path: String) -> Texture2D:
	return load(path)


static func icon_rect(path: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func money_text(v: int) -> String:
	return Economy.format_money(v) + " кр"


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v
