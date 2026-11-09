class_name TileView
extends Node2D
## One drawn tile: rounded body tinted in its type colour, a darker lip at the bottom, a soft
## shadow and the symbol, so the type reads by colour and by shape. Drawn around its position.

var type := 0
var size := Vector2(120, 100):
	set(v):
		size = v
		queue_redraw()
var top := false:          # the reachable top tile of a stack
	set(v):
		top = v
		queue_redraw()
var dim := false:          # buried tiles: visible, but clearly not reachable yet
	set(v):
		dim = v
		queue_redraw()
var glow := 0.0:           # 0..1 pulsing ring around reachable tiles
	set(v):
		glow = v
		queue_redraw()
var danger := 0.0:         # red tint when the tray is full
	set(v):
		danger = v
		queue_redraw()

static var _styles := {}


static func _style(t: int, kind: String, r: int, lip: int) -> StyleBoxFlat:
	var key := "%d/%s/%d/%d" % [t, kind, r, lip]
	if _styles.has(key):
		return _styles[key]
	var c: Array = UiKit.TYPE_COLORS[t]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(r)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	match kind:
		"shadow":
			sb.bg_color = Color(0.35, 0.22, 0.1, 0.0)
			sb.shadow_color = Color(0.35, 0.22, 0.1, 0.22)
			sb.shadow_size = maxi(3, lip)
			sb.shadow_offset = Vector2(0, lip * 0.7)
		"body":
			sb.bg_color = c[1]
			sb.border_color = c[2]
			sb.set_border_width_all(2)
			sb.border_width_bottom = lip
		"ring":
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = UiKit.GOLD
			sb.set_border_width_all(maxi(3, lip - 1))
			sb.draw_center = false
	_styles[key] = sb
	return sb


func _draw() -> void:
	var m := minf(size.x, size.y)
	var r := int(clampf(m * 0.2, 8, 26))
	var lip := int(clampf(m * 0.07, 4, 9))
	var rect := Rect2(-size / 2, size)
	draw_style_box(_style(type, "shadow", r, lip), rect)
	if top and glow > 0.0:
		var g := rect.grow(4.0 + 3.0 * glow)
		var ring := _style(type, "ring", r + 4, lip)
		draw_style_box(ring, g)
	var body := _style(type, "body", r, lip)
	draw_style_box(body, rect)
	if dim:
		draw_style_box(_overlay(r, "dim"), rect)
	var sym: Texture2D = UiKit.tex("sym_%d" % type)
	var s := m * (0.62 if dim else 0.7)
	var sym_rect := Rect2(Vector2(-s / 2, -s / 2 - lip * 0.45), Vector2(s, s))
	draw_texture_rect(sym, sym_rect, false, Color(1, 1, 1, 0.82) if dim else Color.WHITE)
	if danger > 0.0:
		var red := _overlay(r, "danger")
		red.bg_color = Color(UiKit.DANGER, 0.35 * danger)
		draw_style_box(red, rect)


static func _overlay(r: int, kind: String) -> StyleBoxFlat:
	var key := "%s/%d" % [kind, r]
	if not _styles.has(key):
		_styles[key] = UiKit.box(Color(0.42, 0.33, 0.24, 0.17) if kind == "dim" else Color(UiKit.DANGER, 0.35), r)
	return _styles[key]
