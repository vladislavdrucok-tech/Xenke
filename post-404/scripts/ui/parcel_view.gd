class_name ParcelView
extends Node2D
## Draws one parcel: the box, its label (year, smudges, corrections) and the
## badges for special parcels. Pure drawing, no logic.

const LABEL := Rect2(8, 13, 18, 10)   # sticker area inside every box sprite

var p: Dictionary = {}
var k := 6.0                 # art pixel -> screen pixel
var show_year := true
var reveal := 0.0            # UV scanner progress for smudged digits
var urgent_left := -1.0      # 1..0 while the urgent bonus is still possible
var timer_left := -1.0       # record mode: 1..0 time for this parcel
var highlight := 0.0
var _t := 0.0
var _animated := false
var _font: Font
var _font_bold: Font


func setup(parcel: Dictionary, scale_k: float, p_show_year: bool = true) -> ParcelView:
	p = parcel
	k = scale_k
	show_year = p_show_year
	_font = UI.font()
	_font_bold = UI.font(true)
	_animated = p.get("hazard", false) or p.get("collectible", "") != "" or p.get("urgent", false)
	queue_redraw()
	return self


func _process(delta: float) -> void:
	_t += delta
	if _animated or urgent_left >= 0.0 or timer_left >= 0.0 or (reveal > 0.0 and reveal < 1.0):
		queue_redraw()


func box_texture() -> Texture2D:
	var b: String = p.get("box", "cardboard")
	if b == "hazard":
		return UI.frames("box_hazard", 4)[int(_t * 6.0) % 4]
	return UI.tex("box_" + b)


func size_px() -> Vector2:
	return Vector2(34, 30) * k


func _draw() -> void:
	if p.is_empty():
		return
	var tex := box_texture()
	var sz := tex.get_size() * k
	var o := -sz / 2
	# soft shadow
	draw_rect(Rect2(o.x + 2 * k, o.y + sz.y - 1 * k, sz.x - 4 * k, 2 * k), Color(0, 0, 0, 0.35))
	if p.get("hazard", false):
		var g := 0.25 + 0.15 * sin(_t * 6.0)
		draw_circle(Vector2.ZERO, sz.x * 0.62, Color(1.0, 0.54, 0.9, g * 0.5))
	if p.get("collectible", "") != "":
		draw_circle(Vector2.ZERO, sz.x * 0.6, Color(1.0, 0.9, 0.4, 0.18 + 0.08 * sin(_t * 4.0)))
	if highlight > 0.0:
		draw_rect(Rect2(o - Vector2(k, k), sz + Vector2(2 * k, 2 * k)), Color(1, 1, 1, highlight * 0.5))
	draw_texture_rect(tex, Rect2(o, sz), false)
	var lab := Rect2(o + LABEL.position * k, LABEL.size * k)
	if show_year:
		_draw_label(lab)
	_draw_badges(o, sz)


func _draw_label(lab: Rect2) -> void:
	var size := int(k * 6.4)
	var center := lab.get_center()
	if p.get("riddle", "") != "":
		_text_centered("?", center, int(k * 8), UI.MAGENTA.darkened(0.3), _font_bold)
		return
	var shown: String = p.get("shown", str(p.get("year", "")))
	var full := str(p.get("year", ""))
	# per-character layout so smudged digits can be drawn separately
	var widths := []
	var total := 0.0
	for i in shown.length():
		var w := _font_bold.get_string_size(full[i] if i < full.length() else shown[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(w)
		total += w
	var x := center.x - total / 2.0
	var base_y := center.y + size * 0.36
	var ink := Color("2a1f2f")
	if int(p.get("old_year", 0)) != 0:
		ink = Color("1d4f8a")     # the corrected year is written by hand, in blue
	for i in shown.length():
		var ch := shown[i]
		var w: float = widths[i]
		if ch == "?":
			var blot := Rect2(x - k * 0.3, center.y - size * 0.45, w + k * 0.6, size * 0.9)
			draw_rect(blot, Color("8a5a35", 0.85))
			draw_rect(blot.grow(-k * 0.6), Color("6e4628", 0.9))
			if reveal > 0.0 and i < full.length():
				_text_at(full[i], Vector2(x, base_y), size, Color(1.0, 0.55, 0.95, reveal), _font_bold)
			else:
				_text_at("?", Vector2(x + w * 0.1, base_y), size, Color("d3a066"), _font_bold)
		else:
			_text_at(ch, Vector2(x, base_y), size, ink, _font_bold)
		x += w
	var old := int(p.get("old_year", 0))
	if old != 0:
		var osz := int(k * 4.2)
		var pos := Vector2(lab.get_center().x, lab.position.y - k * 2.4)
		var tw := _font.get_string_size(str(old), HORIZONTAL_ALIGNMENT_LEFT, -1, osz).x
		draw_rect(Rect2(pos.x - tw / 2 - k, pos.y - osz * 0.7, tw + 2 * k, osz * 0.95), Color("fff6e0"))
		_text_centered(str(old), pos, osz, Color("6b5a55"), _font)
		draw_line(Vector2(pos.x - tw / 2 - k * 0.5, pos.y - osz * 0.2), Vector2(pos.x + tw / 2 + k * 0.5, pos.y - osz * 0.3), UI.RED, max(2.0, k * 0.6))


func _draw_badges(o: Vector2, sz: Vector2) -> void:
	var icon_k := k * 0.75
	if p.get("hazard", false):
		var t := UI.tex("ic_hazard")
		draw_texture_rect(t, Rect2(o + Vector2(-k, -k * 2), t.get_size() * icon_k * 1.3), false)
	if p.get("urgent", false):
		var t := UI.tex("ic_clock_small")
		var r := Rect2(o + Vector2(sz.x - k * 4, -k * 3), t.get_size() * icon_k * 1.3)
		if urgent_left > 0.0:
			draw_arc(r.get_center(), r.size.x * 0.75, -PI / 2, -PI / 2 + TAU * urgent_left, 24, UI.RED, max(2.0, k * 0.7))
		draw_texture_rect(t, r, false)
	var series: String = p.get("series", "")
	if series != "":
		var txt := "%s %d/%d" % [series, int(p["series_idx"]), int(p["series_len"])]
		var fs := int(k * 3.6)
		var tw := _font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(o + Vector2(-k * 1.5, sz.y - k * 4.5), Vector2(tw + k * 5.5, fs * 1.15))
		draw_rect(r, Color("1f6f8b"))
		draw_rect(r.grow(-k * 0.4), Color("2fb4c9"))
		var chain := UI.tex("ic_chain")
		draw_texture_rect(chain, Rect2(r.position + Vector2(k * 0.6, k * 0.5), chain.get_size() * icon_k * 0.55), false)
		_text_at(txt, r.position + Vector2(k * 4.6, fs * 0.92), fs, UI.INK, _font_bold)
	var sender: String = p.get("sender", "")
	if sender != "":
		var pt := UI.tex("pt_" + sender)
		var s := k * 2.2 * 4.0
		var r := Rect2(o + Vector2(sz.x - s * 0.7, sz.y - s * 0.75), Vector2(s, s))
		draw_rect(r.grow(k * 0.5), UI.INK)
		draw_texture_rect(pt, r, false)
	if p.get("collectible", "") != "":
		for i in 4:
			var a := _t * 1.6 + i * TAU / 4.0
			var pos := Vector2(cos(a) * sz.x * 0.55, sin(a) * sz.y * 0.5)
			var st := UI.tex("fx_star")
			var ss := k * (0.6 + 0.3 * sin(_t * 5.0 + i))
			draw_texture_rect(st, Rect2(pos - st.get_size() * ss / 2, st.get_size() * ss), false, Color(1, 0.95, 0.5))
	if timer_left >= 0.0:
		var bar := Rect2(o.x, o.y + sz.y + k * 1.5, sz.x, k * 1.6)
		draw_rect(bar, UI.INK)
		var col := UI.GREEN if timer_left > 0.5 else (UI.AMBER if timer_left > 0.25 else UI.RED)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(timer_left, 0.0, 1.0), bar.size.y)).grow(-2), col)


func _text_at(text: String, pos: Vector2, size: int, color: Color, f: Font) -> void:
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_centered(text: String, center: Vector2, size: int, color: Color, f: Font) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(center.x - w / 2.0, center.y + size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
