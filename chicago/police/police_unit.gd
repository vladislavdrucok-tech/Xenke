class_name PoliceUnit
extends CharacterBody2D
## A patrol car answering a call. It enters from the district edge named in data (never pops up in view), routes
## round buildings over the district's tile grid (District.path, re-planned once a second) to the reported place,
## then follows Enzo while it can see him: faster when he is in a car. Ramming it is a crime of its own.
## TEMPORARY ART: black-and-white box with a flashing red light.

const PATROL_TILES_S := 2.6
const PURSUIT_TILES_S := 4.6     # a little slower than the Monarch flat out: escaping is possible, not trivial
const TILE_PX := 90.5            # screen px per tile along the horizontal ground axis

signal rammed(strength: float)

var goal := Vector2.ZERO
var director: Node
var district: District
var pursuing := false
var light_t := 0.0
var _route := PackedVector2Array()
var _replan_t := 0.0
var _stuck_t := 0.0
var _avoid := {}                  # tiles found blocked while driving (cleared on each successful stretch)

func _ready() -> void:
	add_to_group("police")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 32
	collision_mask = 1 | 2 | 8
	var cs := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([Vector2(-50, 0), Vector2(0, -25), Vector2(50, 0), Vector2(0, 25)])
	cs.shape = shape
	add_child(cs)

func grid_pos() -> Vector2:
	return Iso.to_grid(position)

## Tiles under other cars (parked or in traffic, not Enzo's own car - that is the target).
func _car_tiles() -> Dictionary:
	var out := {}
	for v in get_tree().get_nodes_in_group("vehicle") + get_tree().get_nodes_in_group("traffic"):
		if not is_instance_valid(v) or v.is_queued_for_deletion() or v.driver != null:
			continue
		for c in v.footprint():
			out[Vector2i(c.floor())] = true
		out[Vector2i(v.grid_pos().floor())] = true
	return out

func _physics_process(delta: float) -> void:
	light_t += delta
	_replan_t -= delta
	var g := grid_pos()
	var gg := Iso.to_grid(goal)
	if g.distance_to(gg) < 0.6:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if district and (_replan_t <= 0.0 or _route.is_empty()):
		_replan_t = 1.0
		var avoid := _car_tiles()
		avoid.merge(_avoid)
		_route = district.path(g, gg, true, avoid)
	var aim := gg
	while _route.size() > 1 and g.distance_to(_route[0]) < 0.45:
		_route.remove_at(0)
	if not _route.is_empty():
		aim = _route[0]
	var dir_g := (aim - g).normalized()
	var tiles_s := PURSUIT_TILES_S if pursuing else PATROL_TILES_S
	velocity = Iso.to_screen(dir_g * tiles_s)
	var before_v := velocity.length()
	var before_p := position
	move_and_slide()
	# Stuck against something the map does not know about: mark the tile ahead and re-plan around it.
	if position.distance_to(before_p) < velocity.length() * delta * 0.2:
		_stuck_t += delta
		if _stuck_t > 0.5:
			_stuck_t = 0.0
			_avoid[Vector2i((g + dir_g * 0.8).floor())] = true
			_replan_t = 0.0
	else:
		_stuck_t = 0.0
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is Vehicle and (c.get_collider() as Vehicle).driver != null:
			rammed.emit(before_v / TILE_PX)
	queue_redraw()

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(-56, -6), Vector2(0, -34), Vector2(56, -6), Vector2(0, 22)])
	draw_colored_polygon(PackedVector2Array([Vector2(-56, 4), Vector2(0, 32), Vector2(56, 4), Vector2(56, -6), Vector2(0, 22), Vector2(-56, -6)]), Color("#111"))
	draw_colored_polygon(pts, Color("#1c1c22"))
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -14), Vector2(0, -26), Vector2(22, -14), Vector2(0, -2)]), Color("#e8e8e8"))
	var on := int(light_t * 4.0) % 2 == 0
	draw_circle(Vector2(0, -32), 6.0, Color("#ff3b30") if on else Color("#5a1a16"))
