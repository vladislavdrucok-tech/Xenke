class_name FloorPanel
extends Control
## The elevator button panel: 13 brass buttons (1-5 bottom row). A button shows
## whether it is lit (the cabin will stop there), how many guests wait on that floor
## (left badge, coloured by patience) and how many riders go there (right badge).

signal pressed_floor(f: int)

const BW := 52
const BH := 38
const GX := 8
const GY := 6
const PAD := 10

var sim: ShiftSim
var flash := {}
var pulse := {}
var t := 0.0
var hint_floor := 0
var enabled := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


static func panel_height() -> int:
	return PAD * 2 + BH * 3 + GY * 2 + 4


func button_rect(f: int) -> Rect2:
	var idx := f - 1
	var row := idx / 5
	var col := idx % 5
	var grid_w := 5 * BW + 4 * GX
	var x0 := floorf((size.x - grid_w) / 2.0)
	if row == 2:
		x0 = floorf((size.x - (3 * BW + 2 * GX)) / 2.0)
	var y := size.y - PAD - (row + 1) * BH - row * GY
	return Rect2(x0 + col * (BW + GX), y, BW, BH)


func _gui_input(e: InputEvent) -> void:
	if not enabled or sim == null:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for f in range(1, Defs.MAX_FLOORS + 1):
			if button_rect(f).grow(3).has_point(e.position):
				flash[f] = 0.14
				pressed_floor.emit(f)
				break
		accept_event()


func ping(f: int) -> void:
	pulse[f] = 1.2


func _process(delta: float) -> void:
	t += delta
	for k in flash.keys():
		flash[k] -= delta
		if flash[k] <= 0.0:
			flash.erase(k)
	for k in pulse.keys():
		pulse[k] -= delta
		if pulse[k] <= 0.0:
			pulse.erase(k)
	queue_redraw()


func _draw() -> void:
	draw_style_box(Art.style("panel"), Rect2(Vector2.ZERO, size))
	if sim == null:
		return
	var tex := Art.tex("floor_buttons")
	var font := Art.title()
	for f in range(1, Defs.MAX_FLOORS + 1):
		var r := button_rect(f)
		var locked := f > sim.floors
		var closed := sim.closed.has(f)
		var lit := sim.stops.has(f)
		var frame := 0
		if locked:
			frame = 2
		elif closed:
			frame = 3
		elif flash.has(f):
			frame = 4 if not lit else 1
		elif lit:
			frame = 1
		draw_texture_rect_region(tex, r, Rect2(frame * 52, 0, 52, 38))
		var num := str(f)
		var fs := 16
		var w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var dy := 1.0 if frame == 4 else 0.0
		var pos := Vector2(roundf(r.position.x + (BW - w) / 2.0), r.position.y + 26 + dy)
		if locked:
			Art.draw_icon(self, "lock", r.position + Vector2(18, 10), Color(1, 1, 1, 0.55))
			continue
		var col := Art.WHITE if not lit else Art.INK
		if closed:
			col = Color(0.7, 0.7, 0.7)
		if f == 13 and not lit:
			col = Color("8affb0")
		draw_string(font, pos + Vector2(1, 1), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45))
		draw_string(font, pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if closed:
			Art.draw_icon(self, "wrench", r.position + Vector2(36, 1), Color.WHITE, 16)
			continue
		# cabin is here: green lamp at the bottom
		if sim.lift_floor() == f and absf(sim.vel) < 0.05:
			draw_rect(Rect2(r.position.x + 20, r.position.y + 31, 12, 2), Art.GREEN)
		# waiting guests badge (left)
		var q := sim.queue_on(f).size()
		if q > 0:
			var frac := sim.min_wait_frac(f)
			var bc := Art.patience_color(frac)
			if frac < 0.25 and int(t * 6.0) % 2 == 0:
				bc = Color.WHITE
			_badge(r.position + Vector2(-3, -4), str(q), bc, true)
		# riders going here (right)
		var d := sim.dest_count(f)
		if d > 0:
			_badge(r.position + Vector2(BW - 10, -4), str(d), Art.CYAN, false)
		if pulse.has(f):
			var a: float = pulse[f] / 1.2
			draw_rect(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), Color(0.4, 0.95, 1.0, a * 0.8), false, 2.0)
	if hint_floor > 0:
		var r := button_rect(hint_floor)
		var bob := roundf(absf(sin(t * 5.0)) * 4.0)
		var fpos := r.position + Vector2(BW / 2.0 - 4, BH / 2.0 + 2 + bob)
		draw_texture(Art.tex("finger"), fpos)
		draw_rect(Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)), Color(1, 0.9, 0.3, 0.5 + 0.4 * sin(t * 8.0)), false, 2.0)


func _badge(p: Vector2, text: String, col: Color, person: bool) -> void:
	var w := Art.digits_width(text) + (9 if person else 6)
	var r := Rect2(p.round(), Vector2(w, 11))
	draw_rect(Rect2(r.position + Vector2(1, 0), r.size - Vector2(2, 0)), Art.INK)
	draw_rect(Rect2(r.position + Vector2(0, 1), r.size - Vector2(0, 2)), Art.INK)
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), col)
	var x := r.position.x + 3
	if person:
		# tiny person glyph
		draw_rect(Rect2(x, r.position.y + 2, 2, 2), Art.INK)
		draw_rect(Rect2(x - 1, r.position.y + 5, 4, 2), Art.INK)
		draw_rect(Rect2(x, r.position.y + 7, 1, 2), Art.INK)
		draw_rect(Rect2(x + 1, r.position.y + 7, 1, 2), Art.INK)
		x += 4
	Art.draw_digits(self, text, Vector2(x, r.position.y + 2), Art.INK)
