class_name Gest
extends RefCounted
## Shared gesture logic. Every repair builds its controls from these pieces:
## touch targets with a generous radius, sliding along an axis with a snap,
## turning around a pivot, wiggling back and forth, and stroking along a path.

const SLOP := 34.0   # extra pixels a finger may miss by


class Target:
	var id: String
	var kind := "circle"          # circle | segment | path | rect
	var center := Vector2.ZERO
	var radius := 60.0
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var pts := PackedVector2Array()
	var rect := Rect2()
	var enabled := true
	var priority := 0

	func distance(p: Vector2) -> float:
		match kind:
			"segment":
				return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) - radius
			"path":
				return Gest.path_closest(p, pts)["dist"] - radius
			"rect":
				if rect.has_point(p):
					return -1.0
				var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
				return q.distance_to(p)
			_:
				return center.distance_to(p) - radius


static func circle(id: String, c: Vector2, r: float, prio := 0) -> Target:
	var t := Target.new()
	t.id = id
	t.center = c
	t.radius = r
	t.priority = prio
	return t


static func segment(id: String, a: Vector2, b: Vector2, r: float, prio := 0) -> Target:
	var t := Target.new()
	t.id = id
	t.kind = "segment"
	t.a = a
	t.b = b
	t.radius = r
	t.priority = prio
	return t


static func path(id: String, pts: PackedVector2Array, r: float, prio := 0) -> Target:
	var t := Target.new()
	t.id = id
	t.kind = "path"
	t.pts = pts
	t.radius = r
	t.priority = prio
	return t


static func rect(id: String, r: Rect2, prio := 0) -> Target:
	var t := Target.new()
	t.id = id
	t.kind = "rect"
	t.rect = r
	t.priority = prio
	return t


## Pick the target under the finger: inside wins by priority, then nearest.
static func pick(targets: Array, p: Vector2, slop := SLOP) -> Target:
	var best: Target = null
	var best_score := INF
	for t in targets:
		if not t.enabled:
			continue
		var d: float = t.distance(p)
		if d > slop:
			continue
		# inside a target beats near one; among inside ones priority decides
		var score := d
		if d <= 0.0:
			score = -1000.0 - float(t.priority) * 10.0 + d * 0.001
		if score < best_score:
			best_score = score
			best = t
	return best


# ------------------------------------------------------------------ math

static func angle_delta(pivot: Vector2, prev: Vector2, cur: Vector2) -> float:
	var a0 := (prev - pivot).angle()
	var a1 := (cur - pivot).angle()
	return wrapf(a1 - a0, -PI, PI)


static func project(p: Vector2, origin: Vector2, dir: Vector2) -> float:
	return (p - origin).dot(dir.normalized())


## Closest point on a polyline: returns {t (0..1 along length), dist, point}
static func path_closest(p: Vector2, pts: PackedVector2Array) -> Dictionary:
	var total := 0.0
	var lens: Array = []
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		lens.append(l)
		total += l
	var best := {"t": 0.0, "dist": INF, "point": pts[0] if pts.size() > 0 else Vector2.ZERO}
	var acc := 0.0
	for i in pts.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		var d := q.distance_to(p)
		if d < best["dist"]:
			var along := acc + pts[i].distance_to(q)
			best = {"t": along / max(total, 0.001), "dist": d, "point": q}
		acc += lens[i]
	return best


static func path_point(pts: PackedVector2Array, t: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want := clampf(t, 0.0, 1.0) * total
	var acc := 0.0
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		if acc + l >= want:
			return pts[i].lerp(pts[i + 1], (want - acc) / max(l, 0.001))
		acc += l
	return pts[pts.size() - 1]


# ------------------------------------------------------------------ trackers

## Back-and-forth movement detector (wiggling a wire, shaking a fender).
class Wiggle:
	var last := Vector2.ZERO
	var dir := Vector2.ZERO
	var travel := 0.0        # total distance moved while held
	var reversals := 0
	var energy := 0.0        # decays over time; > 0.5 means "being wiggled"
	var has_last := false

	func reset() -> void:
		has_last = false
		travel = 0.0
		reversals = 0
		energy = 0.0
		dir = Vector2.ZERO

	func feed(p: Vector2) -> void:
		if not has_last:
			last = p
			has_last = true
			return
		var d := p - last
		if d.length() < 1.5:
			return
		travel += d.length()
		energy = minf(energy + d.length() / 60.0, 2.0)
		if dir != Vector2.ZERO and d.normalized().dot(dir) < -0.3:
			reversals += 1
			energy = minf(energy + 0.4, 2.0)
		dir = d.normalized()
		last = p

	func decay(delta: float) -> void:
		energy = maxf(0.0, energy - delta * 1.6)

	func active() -> bool:
		return energy > 0.35 or travel > 30.0


## Slide along an axis between lo and hi (in pixels from origin).
class Slide:
	var origin := Vector2.ZERO
	var dir := Vector2.RIGHT
	var lo := 0.0
	var hi := 100.0
	var value := 0.0
	var grab := 0.0

	func _init(o: Vector2, d: Vector2, a: float, b: float, v := 0.0) -> void:
		origin = o
		dir = d.normalized()
		lo = a
		hi = b
		value = v

	func begin(p: Vector2) -> void:
		grab = Gest.project(p, origin, dir) - value

	func update(p: Vector2) -> float:
		value = clampf(Gest.project(p, origin, dir) - grab, lo, hi)
		return value

	func pos() -> Vector2:
		return origin + dir * value

	func frac() -> float:
		return (value - lo) / max(hi - lo, 0.001)


## Turning around a pivot; accumulates angle, optional limits.
class Turn:
	var pivot := Vector2.ZERO
	var angle := 0.0
	var lo := -INF
	var hi := INF
	var prev := Vector2.ZERO
	var total := 0.0         # absolute turning done

	func _init(p: Vector2, a := 0.0, l := -INF, hh := INF) -> void:
		pivot = p
		angle = a
		lo = l
		hi = hh

	func begin(p: Vector2) -> void:
		prev = p

	func update(p: Vector2) -> float:
		if (p - pivot).length() < 12.0:
			return 0.0
		var d := Gest.angle_delta(pivot, prev, p)
		prev = p
		var na := clampf(angle + d, lo, hi)
		var applied := na - angle
		angle = na
		total += absf(applied)
		return applied


## Stroking along a path from start to end (smoothing a rubber strip).
class Stroke:
	var pts := PackedVector2Array()
	var tol := 70.0
	var reached := 0.0       # furthest progress 0..1
	var covered: Array = []  # bins touched
	var bins := 12

	func _init(p: PackedVector2Array, t := 70.0, b := 12) -> void:
		pts = p
		tol = t
		bins = b
		covered.resize(bins)
		covered.fill(false)

	func feed(p: Vector2) -> void:
		var c := Gest.path_closest(p, pts)
		if c["dist"] > tol:
			return
		var i := clampi(int(c["t"] * bins), 0, bins - 1)
		covered[i] = true
		reached = maxf(reached, c["t"])

	func progress() -> float:
		var n := 0
		for v in covered:
			if v:
				n += 1
		return float(n) / float(bins)
