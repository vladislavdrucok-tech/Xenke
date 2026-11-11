extends RefCounted
## Theme and small widget builders shared by the HUD and the screens.

const ART := "res://assets/art/ui/"
const CREAM := Color("fff0c8")
const DARK := Color("3a1a0a")
const TEAL := Color("7fe3d6")

static var _theme: Theme
static var _fonts := {}
static var _cjk := {}
static var _lang := ""

const CJK := {"ja": "NotoSansJP-Bold", "ko": "NotoSansKR-Bold", "zh_CN": "NotoSansSC-Bold"}

static func font(name := "Rubik-ExtraBold") -> Font:
	if not _fonts.has(name):
		_fonts[name] = load("res://assets/fonts/%s.ttf" % name)
		_apply_fallbacks(_fonts[name])
	return _fonts[name]

static func set_lang(code: String) -> void:
	## Rubik covers Latin (Polish, Turkish, Vietnamese-free Western sets) and Cyrillic; Japanese, Korean and
	## Chinese come from Noto Sans fallbacks. Han characters look different in each: the fallback of the
	## chosen language goes first.
	_lang = code
	for n in _fonts:
		_apply_fallbacks(_fonts[n])
	for n in ["Rubik-Bold", "Rubik-ExtraBold", "Fredoka-Bold"]:
		_apply_fallbacks(font(n))

static func _cjk_font(code: String) -> Font:
	if not _cjk.has(code):
		var path := "res://assets/fonts/%s.ttf" % CJK[code]
		_cjk[code] = load(path) if ResourceLoader.exists(path) else null
	return _cjk[code]

static func _apply_fallbacks(f: Font) -> void:
	if f == null or not (f is FontFile):
		return
	var order := ["zh_CN", "ja", "ko"]
	if _lang == "ja":
		order = ["ja", "zh_CN", "ko"]
	elif _lang == "ko":
		order = ["ko", "zh_CN", "ja"]
	var fb: Array[Font] = []
	for c in order:
		var cf := _cjk_font(c)
		if cf:
			fb.append(cf)
	f.fallbacks = fb

static func fit_button(b: Button, max_w: float, base := -1, min_size := 18) -> void:
	## Long translations (German, Polish …) shrink to the button instead of stretching it off screen;
	## past the minimum size the text wraps onto two lines.
	# a button outside the tree cannot see its theme yet: sizes come straight from the game theme
	var t := theme()
	var type := String(b.theme_type_variation) if b.theme_type_variation != &"" else "Button"
	var fs := base
	if fs < 0:
		fs = t.get_font_size("font_size", type) if t.has_font_size("font_size", type) else t.get_font_size("font_size", "Button")
	var f := t.get_font("font", "Button")
	var pad := 56.0
	var text := b.text
	while fs > min_size and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad + (40.0 if b.icon else 0.0) > max_w:
		fs -= 2
	b.add_theme_font_size_override("font_size", fs)
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > max_w:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func fit_label(l: Label, max_w: float, min_size := 16) -> void:
	## Single-line labels (titles, values) shrink to fit their width.
	var ls := l.label_settings
	if ls == null:
		return
	ls = ls.duplicate()
	while ls.font_size > min_size and ls.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x > max_w:
		ls.font_size -= 2
	l.label_settings = ls

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
	var on := sbt("button_on.png", 26)
	t.set_stylebox("normal", "OnButton", on)
	t.set_stylebox("hover", "OnButton", on)
	t.set_stylebox("pressed", "OnButton", on)
	t.set_font_size("font_size", "OnButton", 28)
	t.set_color("font_color", "OnButton", Color.WHITE)
	t.set_color("font_hover_color", "OnButton", Color.WHITE)
	t.set_color("font_outline_color", "OnButton", Color("06302f"))
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
	fit_button(b, min_size.x)
	return b

static func wrap(text: String, size := 24, width := 520.0, color := CREAM, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, color, 5, "Rubik-Bold")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = align
	return l

static func title(text: String, size := 44, width := 600.0) -> Label:
	var l := label(text, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(width, 0)
	fit_label(l, width)
	return l

static func stars(n: int, size := 34.0, of := 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", int(size * 0.12))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in of:
		h.add_child(icon(ART + ("star_on.png" if i < n else "star_off.png"), Vector2(size, size)))
	return h

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
