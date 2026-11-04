class_name District
extends Node2D
## A district or interior built from its data file (data/districts/*.json): ground, buildings (as IsoBlock slices with
## one collider per building), doors, interactables, props, spawn points, schedule spots and trigger areas.
## Everything that stands on the ground goes into `entities` (one y-sorted node: the player and cars are moved in
## there too), so depth is decided in one place. All positions in data are grid units; see core/iso.gd.

enum T { YARD, ROAD, SIDEWALK, RAIL, BUILDING, FLOOR }

var def: Dictionary
var id := ""
var size := Vector2i(1, 1)
var tiles := PackedByteArray()
var entities: Node2D
var ground: Node2D
var blocks_by_building := {}    # building id -> [IsoBlock]
var building_rects := {}        # building id -> Rect2 (grid)
var interactables: Array[Node] = []
var is_interior := false

func build(d: Dictionary) -> void:
	def = d
	id = String(d.get("id", ""))
	is_interior = d.get("kind", "exterior") == "interior"
	size = Vector2i(int(d.size[0]), int(d.size[1]))
	tiles.resize(size.x * size.y)
	tiles.fill(T.FLOOR if is_interior else T.YARD)
	if not is_interior:
		for r in d.get("roads", []):
			_fill(_rect(r), T.ROAD)
		for r in d.get("rail", []):
			_fill(_rect(r), T.RAIL)
	for b in d.get("buildings", []):
		_fill(_rect(b.rect), T.BUILDING)
	if not is_interior:
		_mark_sidewalks(int(d.get("sidewalk_width", 1)))
	ground = preload("res://world/ground.gd").new()
	ground.district = self
	ground.z_index = -10
	add_child(ground)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	_build_bounds()
	for b in d.get("buildings", []):
		_build_building(b)
	for dr in d.get("doors", []):
		_add_interactable({"id": dr.id, "kind": "door", "pos": [float(dr.cell[0]) + 0.5, float(dr.cell[1]) + 0.5],
			"target": dr.target, "verb": "HUD_ACT_EXIT" if is_interior else "HUD_ACT_ENTER"})
	for it in d.get("interactables", []):
		_add_interactable(it)
	for p in d.get("props", []):
		var prop := preload("res://world/iso_prop.gd").new()
		prop.kind = String(p.kind)
		prop.position = Iso.to_screen(_v(p.pos))
		entities.add_child(prop)
		if prop.blocks_movement():
			_add_round_collider(prop.position, prop.collider_radius())

func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))

func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _fill(r: Rect2i, t: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				tiles[y * size.x + x] = t

func tile(t: Vector2i) -> int:
	if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return -1
	return tiles[t.y * size.x + t.x]

func _mark_sidewalks(w: int) -> void:
	var marks: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if tile(Vector2i(x, y)) != T.YARD:
				continue
			for dy in range(-w, w + 1):
				for dx in range(-w, w + 1):
					if tile(Vector2i(x + dx, y + dy)) == T.ROAD:
						marks.append(Vector2i(x, y))
	for m in marks:
		tiles[m.y * size.x + m.x] = T.SIDEWALK

func tiles_of(t: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if tile(Vector2i(x, y)) == t:
				out.append(Vector2i(x, y))
	return out

# ------------------------------------------------------------------ physics
func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	var c := Iso.rect_corners(Rect2(Vector2.ZERO, Vector2(size)))
	for i in 4:
		var s := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = c[i]
		seg.b = c[(i + 1) % 4]
		s.shape = seg
		body.add_child(s)
	add_child(body)

func _build_building(b: Dictionary) -> void:
	var r := _rect(b.rect)
	building_rects[String(b.id)] = Rect2(r)
	var body := StaticBody2D.new()
	body.name = "Body_" + String(b.id)
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	poly.points = Iso.rect_corners(Rect2(r))
	shape.shape = poly
	body.add_child(shape)
	add_child(body)
	var list: Array = []
	var sign_cell := Vector2i(r.position.x + r.size.x / 2, r.end.y - 1)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var blk := IsoBlock.new()
			blk.building_id = String(b.id)
			blk.windows = 1 if int(b.get("windows", 0)) > 0 else 0
			blk.setup(Vector2i(x, y), float(b.get("height", 100)), Color(String(b.get("wall", "#8b5a3c"))),
				Color(String(b.get("roof", "#4a3a33"))), x == r.end.x - 1, y == r.end.y - 1)
			if b.has("awning") and y == r.end.y - 1:
				blk.awning = Color(String(b.awning))
			if Vector2i(x, y) == sign_cell:
				blk.sign_key = String(b.get("sign", ""))
			entities.add_child(blk)
			list.append(blk)
	blocks_by_building[String(b.id)] = list
	if b.has("sign"):
		# The sign hangs on the left (+y) wall, centred. Its node stands on the wall's foot line (so it sorts just in
		# front of the wall) and draws itself `lift` px up.
		var plate := preload("res://world/iso_sign.gd").new()
		plate.text_key = String(b.sign)
		plate.position = Iso.to_screen(Vector2(r.position.x + r.size.x / 2.0, r.end.y)) + Vector2(0, 0.5)
		plate.lift = minf(float(b.get("height", 100)) * 0.6, 84.0)
		entities.add_child(plate)

func _add_round_collider(at: Vector2, r: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var s := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	poly.points = pts
	s.shape = poly
	body.position = at
	body.add_child(s)
	add_child(body)

func _add_interactable(it: Dictionary) -> void:
	var n := preload("res://world/interactable.gd").new()
	n.def = it
	n.id = String(it.id)
	n.kind = String(it.kind)
	n.verb_key = String(it.get("verb", "HUD_ACT_USE"))
	n.position = Iso.to_screen(_v(it.pos))
	entities.add_child(n)
	interactables.append(n)

# ------------------------------------------------------------------ queries
func spawn_screen(spawn_id: String) -> Vector2:
	var s: Dictionary = def.get("spawns", {}).get(spawn_id, {})
	if s.is_empty():
		var first: Dictionary = def.get("spawns", {}).values()[0] if not def.get("spawns", {}).is_empty() else {"pos": [1.5, 1.5]}
		s = first
	return Iso.to_screen(_v(s.pos))

func spawn_facing(spawn_id: String) -> String:
	return String(def.get("spawns", {}).get(spawn_id, {}).get("facing", "S"))

func spot_screen(spot_id: String) -> Variant:
	var s: Variant = def.get("spots", {}).get(spot_id, null)
	if s == null:
		return null
	return Iso.to_screen(_v(s))

func areas_at(g: Vector2) -> Array[String]:
	var out: Array[String] = []
	var areas: Dictionary = def.get("areas", {})
	for a in areas:
		var r: Array = areas[a].rect
		if Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).has_point(g):
			out.append(String(a))
	return out

## Is a body of grid radius `r` free to stand at grid point g (inside the district, not inside a building)?
func is_free(g: Vector2, r: float = 0.18) -> bool:
	if g.x - r < 0.0 or g.y - r < 0.0 or g.x + r > size.x or g.y + r > size.y:
		return false
	for id_b in building_rects:
		var br: Rect2 = building_rects[id_b]
		if br.grow(r).has_point(g):
			return false
	return true

## The nearest free grid point to g, searching rings outwards (deterministic). Falls back to the first spawn.
func nearest_free(g: Vector2, r: float = 0.18) -> Vector2:
	if is_free(g, r):
		return g
	for ring in range(1, 24):
		var step := 0.25 * ring
		for i in 16:
			var a := TAU * i / 16.0
			var p := g + Vector2(cos(a), sin(a)) * step
			if is_free(p, r):
				return p
	return Iso.to_grid(spawn_screen(""))

func screen_bounds() -> Rect2:
	var c := Iso.rect_corners(Rect2(Vector2.ZERO, Vector2(size)))
	var r := Rect2(c[0], Vector2.ZERO)
	for p in c:
		r = r.expand(p)
	return r
