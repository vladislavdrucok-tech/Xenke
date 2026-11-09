class_name Paint
extends RefCounted
## Gouache-like vector painting helpers for _draw():
## fills carry a brush-stroke texture and a light-to-shadow gradient,
## edges are slightly uneven, shadows and lamp light are soft.

const LIGHT := Vector2(-0.55, -0.83)
const WARM := Color("ffd27a")
const WARM_DEEP := Color("f0a94a")
const METAL := Color("7d8a99")
const METAL_DARK := Color("3d4756")
const STEEL := Color("aeb8c2")
const CHROME := Color("d9dfe4")
const RUBBER := Color("2c2b30")
const WOOD := Color("9b6a3f")
const WOOD_DARK := Color("6a4429")
const WALL := Color("c9b597")
const FLOOR := Color("8e897e")
const INK := Color("2b2420")
const PAPER := Color("efe3c8")
const OK := Color("7dba62")
const BAD := Color("e8743f")
const AMBER := Color("f5a524")
const WIRE := Color("3b3a40")
const COPPER := Color("c7783e")

static var _stroke_tex: ImageTexture
static var _soft_tex: GradientTexture2D
static var _grain_tex: ImageTexture
static var font_ui: Font
static var font_bold: Font
static var font_hand: Font


static func fonts() -> void:
	if font_ui == null:
		font_ui = load("res://assets/fonts/Rubik-Medium.ttf")
		font_bold = load("res://assets/fonts/Rubik-Bold.ttf")
		font_hand = load("res://assets/fonts/Neucha-Regular.ttf")


static func stroke_tex() -> Texture2D:
	if _stroke_tex == null:
		var n := FastNoiseLite.new()
		n.seed = 7
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.045
		n.fractal_octaves = 3
		var img := n.get_seamless_image(128, 128, false, false, 0.1, true)
		img.convert(Image.FORMAT_RGBA8)
		var n2 := FastNoiseLite.new()
		n2.seed = 31
		n2.frequency = 0.35
		var fine := n2.get_seamless_image(128, 128, false, false, 0.1, true)
		fine.convert(Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var v := img.get_pixel(x, y).r * 0.75 + fine.get_pixel(x, y).r * 0.25
				var b := 0.84 + 0.16 * v
				img.set_pixel(x, y, Color(b, b, b, 1.0))
		_stroke_tex = ImageTexture.create_from_image(img)
	return _stroke_tex


static func grain_tex() -> Texture2D:
	if _grain_tex == null:
		var n := FastNoiseLite.new()
		n.seed = 99
		n.frequency = 0.5
		var img := n.get_seamless_image(128, 128, false, false, 0.1, true)
		_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex


static func soft_tex() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 128
		_soft_tex.height = 128
	return _soft_tex


# ------------------------------------------------------------------ math

static func h(i: int, s: int) -> float:
	var v := sin(float(i) * 12.9898 + float(s) * 78.233) * 43758.5453
	return v - floor(v)


static func centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / max(1, pts.size())


static func xf(pts: PackedVector2Array, t: Transform2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = t * pts[i]
	return out


static func offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + d
	return out


static func scaled(pts: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = c + (pts[i] - c) * k
	return out


# ------------------------------------------------------------------ shapes

static func ellipse(c: Vector2, rx: float, ry: float, n := 28, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


static func circle(c: Vector2, r: float, n := 28) -> PackedVector2Array:
	return ellipse(c, r, r, n)


static func arc_pts(c: Vector2, r: float, a0: float, a1: float, n := 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func rrect(r: Rect2, rad: float, n := 4) -> PackedVector2Array:
	rad = min(rad, min(r.size.x, r.size.y) * 0.5)
	var out := PackedVector2Array()
	var corners := [
		[r.position + Vector2(r.size.x - rad, rad), -PI / 2.0],
		[r.position + Vector2(r.size.x - rad, r.size.y - rad), 0.0],
		[r.position + Vector2(rad, r.size.y - rad), PI / 2.0],
		[r.position + Vector2(rad, rad), PI],
	]
	for c in corners:
		for i in n + 1:
			var a: float = c[1] + (PI / 2.0) * float(i) / float(n)
			out.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return out


static func rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A thick rounded stroke between two points, as a polygon.
static func capsule(a: Vector2, b: Vector2, r: float, n := 6) -> PackedVector2Array:
	var d := (b - a)
	if d.length() < 0.01:
		return circle(a, r, n * 2)
	var ang := d.angle()
	var out := PackedVector2Array()
	for i in n + 1:
		var t := ang + PI / 2.0 + PI * float(i) / float(n)
		out.append(a + Vector2(cos(t), sin(t)) * r)
	for i in n + 1:
		var t := ang - PI / 2.0 + PI * float(i) / float(n)
		out.append(b + Vector2(cos(t), sin(t)) * r)
	return out


## Thick polyline as one polygon (for wires, cables, rubber strips).
static func ribbon(pts: PackedVector2Array, w0: float, w1 := -1.0) -> PackedVector2Array:
	if w1 < 0.0:
		w1 = w0
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var t := float(i) / float(max(1, n - 1))
		var w := lerpf(w0, w1, t) * 0.5
		var d: Vector2
		if i == 0:
			d = pts[1] - pts[0]
		elif i == n - 1:
			d = pts[n - 1] - pts[n - 2]
		else:
			d = pts[i + 1] - pts[i - 1]
		var nrm := Vector2(-d.y, d.x).normalized()
		left.append(pts[i] + nrm * w)
		right.append(pts[i] - nrm * w)
	right.reverse()
	left.append_array(right)
	return left


static func bezier(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, n := 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var u := 1.0 - t
		out.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	return out


## Uneven brush edge: resample and nudge points along the normal.
static func rough(pts: PackedVector2Array, amp := 1.4, step := 16.0, s := 1) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	var k := 0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var seg := b - a
		var ln := seg.length()
		var cnt := int(max(1.0, floor(ln / step)))
		var nrm := Vector2(-seg.y, seg.x).normalized() if ln > 0.001 else Vector2.ZERO
		for j in cnt:
			var t := float(j) / float(cnt)
			var o := (h(k, s) - 0.5) * 2.0 * amp
			if j == 0:
				o *= 0.4
			out.append(a + seg * t + nrm * o)
			k += 1
	return out


# ------------------------------------------------------------------ painting

static func shade_colors(pts: PackedVector2Array, base: Color, amount := 0.22, light := LIGHT) -> PackedColorArray:
	var c := centroid(pts)
	var m := 0.001
	for p in pts:
		m = max(m, abs((p - c).dot(light)))
	var cols := PackedColorArray()
	cols.resize(pts.size())
	var lit := base * 1.08
	lit.a = base.a
	for i in pts.size():
		var t := (pts[i] - c).dot(light) / m
		var col: Color
		if t > 0.0:
			col = lit.lerp(Color(1.0, 0.93, 0.78, base.a), amount * t * 0.9)
		else:
			col = lit.lerp(Color(0.16, 0.2, 0.3, base.a), amount * -t)
		col.a = base.a
		cols[i] = col
	return cols


static func uvs(pts: PackedVector2Array, angle := 0.0, sx := 220.0, sy := 22.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		var p := pts[i].rotated(-angle)
		out[i] = Vector2(p.x / sx, p.y / sy)
	return out


## Main fill: gradient light, brush streak texture.
static func fill(ci: CanvasItem, pts: PackedVector2Array, base: Color, amount := 0.22, angle := 0.0, light := LIGHT) -> void:
	if pts.size() < 3:
		return
	ci.draw_polygon(pts, shade_colors(pts, base, amount, light), uvs(pts, angle), stroke_tex())


## Flat fill with the brush texture, no gradient.
static func flat(ci: CanvasItem, pts: PackedVector2Array, base: Color, angle := 0.0) -> void:
	if pts.size() < 3:
		return
	var c := base * 1.07
	c.a = base.a
	ci.draw_colored_polygon(pts, c, uvs(pts, angle), stroke_tex())


## Painted shape: rough edge, gradient fill, darker rim on the shadow side.
static func shape(ci: CanvasItem, pts: PackedVector2Array, base: Color, s := 1, amount := 0.24, rim := 0.0, angle := 0.0) -> void:
	var p := rough(pts, 1.2, 18.0, s)
	fill(ci, p, base, amount, angle)
	if rim > 0.0:
		var rc := base.darkened(0.45)
		rc.a = 0.75 * base.a
		outline(ci, p, rc, rim)


static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 2.0) -> void:
	var p := pts.duplicate()
	p.append(pts[0])
	ci.draw_polyline(p, col, w, true)


static func line(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 3.0) -> void:
	ci.draw_polyline(pts, col, w, true)


## Brushy line: a soft wide pass and a solid core.
static func brush(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 4.0) -> void:
	var soft := col
	soft.a *= 0.35
	ci.draw_polyline(pts, soft, w * 1.7, true)
	ci.draw_polyline(pts, col, w, true)


static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, alpha := 0.35) -> void:
	ci.draw_texture_rect(soft_tex(), Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, Color(0.08, 0.07, 0.12, alpha))


static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(soft_tex(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


static func glow_e(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_texture_rect(soft_tex(), Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, col)


## A few short light strokes, like dry-brush highlights or scuffs.
static func strokes(ci: CanvasItem, area: Rect2, col: Color, s: int, count: int, length := 18.0, w := 2.0, angle := -0.3) -> void:
	for i in count:
		var p := area.position + Vector2(h(i * 3 + 1, s) * area.size.x, h(i * 3 + 2, s) * area.size.y)
		var a := angle + (h(i * 3 + 3, s) - 0.5) * 0.6
		var l := length * (0.5 + h(i * 7, s))
		var d := Vector2(cos(a), sin(a)) * l
		var c := col
		c.a *= 0.5 + 0.5 * h(i * 5, s)
		ci.draw_line(p, p + d, c, w * (0.6 + 0.6 * h(i * 11, s)), true)


static func bolt(ci: CanvasItem, c: Vector2, r: float, col := STEEL, ang := 0.3) -> void:
	shadow(ci, c + Vector2(2, 3), r * 1.3, r * 1.1, 0.35)
	var hex := PackedVector2Array()
	for i in 6:
		var a := ang + TAU * float(i) / 6.0
		hex.append(c + Vector2(cos(a), sin(a)) * r)
	fill(ci, hex, col, 0.35)
	ci.draw_circle(c - Vector2(r, r) * 0.22, r * 0.28, Color(1, 1, 1, 0.35))


static func screw(ci: CanvasItem, c: Vector2, r: float, col := STEEL, ang := 0.6) -> void:
	shadow(ci, c + Vector2(1, 2), r * 1.2, r * 1.0, 0.3)
	fill(ci, circle(c, r, 16), col, 0.35)
	var d := Vector2(cos(ang), sin(ang)) * r * 0.7
	ci.draw_line(c - d, c + d, col.darkened(0.55), max(1.5, r * 0.25), true)


## Text helper in _draw (Rubik Medium unless a font is given).
static func text(ci: CanvasItem, pos: Vector2, s: String, size := 26, col := INK, align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0, f: Font = null) -> void:
	fonts()
	var fnt: Font = f if f != null else font_ui
	var w := width
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and w < 0.0:
		w = 900.0
		p.x -= 450.0
	ci.draw_string(fnt, p, s, align, w, size, col)


## Coin icon used in the interface and in drawings.
static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	shadow(ci, c + Vector2(2, 3), r * 1.2, r * 1.0, 0.3)
	ci.draw_circle(c, r, Color("c98a1c"))
	ci.draw_circle(c - Vector2(1, 1), r * 0.86, Color("f2c14e"))
	ci.draw_circle(c - Vector2(1, 1), r * 0.62, Color("e3a836"))
	ci.draw_arc(c - Vector2(1, 1), r * 0.62, PI * 1.05, PI * 1.6, 8, Color(1, 0.95, 0.7, 0.9), max(1.5, r * 0.14), true)


## A check mark or exclamation badge for the part feedback labels.
static func badge(ci: CanvasItem, c: Vector2, good: bool, r := 16.0) -> void:
	ci.draw_circle(c + Vector2(1, 2), r + 2, Color(0, 0, 0, 0.25))
	ci.draw_circle(c, r, OK if good else BAD)
	if good:
		ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, 0), c + Vector2(-r * 0.1, r * 0.38), c + Vector2(r * 0.5, -r * 0.4)]), Color.WHITE, r * 0.22, true)
	else:
		ci.draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.15), Color.WHITE, r * 0.24, true)
		ci.draw_circle(c + Vector2(0, r * 0.48), r * 0.13, Color.WHITE)
