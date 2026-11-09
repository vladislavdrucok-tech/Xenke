class_name Art
extends RefCounted
## Shared textures, fonts and small drawing / UI helpers.

const ICON_ORDER := ["coin", "heart", "heart_empty", "clock", "pause", "play", "lock", "wrench", "star", "star_empty",
	"sound", "sound_off", "music", "music_off", "vibe", "home", "retry", "gear", "cabin", "door",
	"coffee", "note", "tie", "book", "balloon", "bolt", "pile", "siren", "drop", "bulb", "ghost", "cat",
	"tophat", "briefcase", "granny", "express", "confetti", "moon", "gear_rust", "bag", "fullmoon",
	"trophy", "person", "check", "cross", "up", "down", "info", "heart_broken", "calendar"]
const DIGITS := "0123456789?+x!-"

const GOLD := Color("f2c14e")
const GOLD_L := Color("ffe08a")
const INK := Color("1a1020")
const WHITE := Color("f4f0e8")
const PINK := Color("ff6ad5")
const CYAN := Color("6af0ff")
const GREEN := Color("5ad85a")
const YELLOW := Color("ffd84a")
const RED := Color("ff4a4a")
const DIM := Color("8a80a0")

const EVENT_ICONS := {"jazz": "note", "rich": "pile", "party": "balloon", "turbo": "bolt", "coins": "coin",
	"drill": "siren", "sticky": "drop", "blackout": "bulb", "prank": "ghost", "lostcat": "cat",
	"inspector": "tophat"}
const RULE_ICONS := {"none": "star", "vip": "briefcase", "grannies": "granny", "repair": "wrench",
	"express": "express", "festival": "confetti", "quiet": "moon", "oldmotor": "gear_rust", "school": "bag",
	"moon": "fullmoon"}
const UPGRADE_ICONS := {"motor": "gear", "cabin": "cabin", "doors": "door", "coffee": "coffee", "jazz": "note",
	"tips": "tie", "hearts": "book"}

static var _tex := {}
static var _font_body: FontFile
static var _font_title: FontFile
static var _theme: Theme
static var _styles := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/sprites/%s.png" % name)
	return _tex[name]


static func _pixel_font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.multichannel_signed_distance_field = false
	return f


static func body() -> FontFile:
	if _font_body == null:
		_font_body = _pixel_font("res://assets/fonts/Tiny5.ttf")
		_font_body.fallbacks = [title()]
	return _font_body


static func title() -> FontFile:
	if _font_title == null:
		_font_title = _pixel_font("res://assets/fonts/PressStart2P.ttf")
	return _font_title


static func icon_rect(name: String) -> Rect2:
	var i := ICON_ORDER.find(name)
	if i < 0:
		i = 0
	return Rect2((i % 10) * 16, (i / 10) * 16, 16, 16)


static func draw_icon(ci: CanvasItem, name: String, pos: Vector2, mod := Color.WHITE, size := 16.0) -> void:
	ci.draw_texture_rect_region(tex("icons"), Rect2(pos.round(), Vector2(size, size)), icon_rect(name), mod)


static func icon_texture(name: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex("icons")
	a.region = icon_rect(name)
	return a


## Draws a number with the 5x7 pixel digits. Returns the width in pixels.
static func draw_digits(ci: CanvasItem, text: String, pos: Vector2, col: Color, scale := 1) -> int:
	var x := 0
	var t := tex("digits")
	for ch in text:
		var i := DIGITS.find(ch)
		if i < 0:
			x += 3 * scale
			continue
		ci.draw_texture_rect_region(t, Rect2(pos.x + x, pos.y, 5 * scale, 7 * scale), Rect2(i * 5, 0, 5, 7), col)
		x += 6 * scale
	return x - scale


static func digits_width(text: String, scale := 1) -> int:
	return text.length() * 6 * scale - scale


static func style(name: String, margin := 6) -> StyleBoxTexture:
	var key := "%s_%d" % [name, margin]
	if not _styles.has(key):
		var s := StyleBoxTexture.new()
		s.texture = tex("ui_" + name)
		s.texture_margin_left = 6
		s.texture_margin_right = 6
		s.texture_margin_top = 6
		s.texture_margin_bottom = 6
		s.content_margin_left = margin
		s.content_margin_right = margin
		s.content_margin_top = margin * 0.6
		s.content_margin_bottom = margin * 0.6
		_styles[key] = s
	return _styles[key]


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = body()
		_theme.default_font_size = 16
		_theme.set_color("font_color", "Label", WHITE)
		_theme.set_color("font_outline_color", "Label", INK)
		_theme.set_constant("outline_size", "Label", 0)
		_theme.set_constant("line_spacing", "Label", 1)
		for st in ["normal", "hover", "focus"]:
			_theme.set_stylebox(st, "Button", style("btn", 10))
		_theme.set_stylebox("pressed", "Button", style("btn_pressed", 10))
		_theme.set_stylebox("disabled", "Button", style("btn_grey", 10))
		_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		_theme.set_font("font", "Button", title())
		_theme.set_font_size("font_size", "Button", 8)
		_theme.set_color("font_color", "Button", WHITE)
		_theme.set_color("font_hover_color", "Button", WHITE)
		_theme.set_color("font_pressed_color", "Button", GOLD_L)
		_theme.set_color("font_focus_color", "Button", WHITE)
		_theme.set_color("font_disabled_color", "Button", DIM)
		_theme.set_constant("h_separation", "Button", 6)
		_theme.set_stylebox("panel", "PanelContainer", style("panel", 10))
		_theme.set_stylebox("panel", "Panel", style("panel", 10))
	return _theme


static func label(text: String, size := 16, col := WHITE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	return l


static func title_label(text: String, size := 8, col := GOLD) -> Label:
	var l := label(text, size, col, title())
	l.add_theme_constant_override("outline_size", 0)
	return l


static func button(text: String, kind := "btn", icon := "", font_size := 8) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	if kind != "btn":
		for st in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(st, style(kind, 10))
		b.add_theme_stylebox_override("pressed", style(kind + "_pressed", 10))
		if kind == "btn_gold":
			b.add_theme_color_override("font_color", INK)
			b.add_theme_color_override("font_hover_color", INK)
			b.add_theme_color_override("font_pressed_color", INK)
			b.add_theme_color_override("font_focus_color", INK)
	if icon != "":
		b.icon = icon_texture(icon)
	b.pressed.connect(func(): Sfx.play("click"); Sfx.vibe(10))
	return b


static func patience_color(frac: float) -> Color:
	if frac > 0.6:
		return GREEN
	if frac > 0.3:
		return YELLOW
	return RED


## Safe-area insets (camera cutouts, gesture bar) in viewport pixels: [top, bottom].
static func safe_insets() -> Vector2:
	var fake := OS.get_environment("F13_INSETS")   # dev: "top,bottom" to preview a phone with a cutout
	if fake != "":
		var parts := fake.split(",")
		return Vector2(float(parts[0]), float(parts[1]) if parts.size() > 1 else 0.0)
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Vector2.ZERO
	var ws := Vector2(DisplayServer.window_get_size())
	var sa := DisplayServer.get_display_safe_area()
	var vs := tree.root.get_visible_rect().size
	if ws.y <= 0.0 or sa.size.y <= 0:
		return Vector2.ZERO
	var k := vs.y / ws.y
	var top := maxf(0.0, float(sa.position.y)) * k
	var bottom := maxf(0.0, ws.y - float(sa.position.y + sa.size.y)) * k
	return Vector2(ceilf(minf(top, 60.0)), ceilf(minf(bottom, 60.0)))


static var _people := {}


## Sprite-sheet layout of the passengers (written by tools/art_people.py).
static func people() -> Dictionary:
	if _people.is_empty():
		_people = {"cell": [32, 32], "feet": 30, "top": {},
			"anims": {"idle": [0, 4], "walk": [4, 6], "wait": [10, 4], "angry": [14, 2], "happy": [16, 2]}}
		var f := FileAccess.open("res://assets/sprites/passengers.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				_people.merge(d, true)
	return _people


static func person_top(type_id: String) -> float:
	return float(people()["top"].get(type_id, 26))
