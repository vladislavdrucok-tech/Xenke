class_name TrafficCar
extends Vehicle
## A civilian car driving a lane loop (district data "traffic"). Cheap tier-C behaviour: it steers straight at the
## next lane point, keeps its speed, and stops for anything in its lane ahead (Enzo on foot or in a car, other
## traffic, the police) instead of pushing through it. Not saved: traffic is regenerated on every district load.

const LOOK_AHEAD := 2.2        # tiles
const LANE_HALF := 0.55        # tiles to each side of the lane centre that count as "in my lane"

var points: Array[Vector2] = []
var cruise := 2.4
var blocked_t := 0.0
var world: Node

func _ready() -> void:
	super._ready()
	remove_from_group("interactable")    # nobody can drive off in a passer-by's car in chapter 1
	remove_from_group("vehicle")
	add_to_group("traffic")

var dist := 0.0               # tiles travelled along the loop
var _seg_len: Array[float] = []
var _total := 0.0

func start_on(loop: Array[Vector2], at_index: int, t: float) -> void:
	points = loop
	_seg_len.clear()
	_total = 0.0
	for k in points.size():
		var l := points[k].distance_to(points[(k + 1) % points.size()])
		_seg_len.append(l)
		_total += l
	dist = t * _seg_len[at_index]
	for k in at_index:
		dist += _seg_len[k]
	_place()

## Where `dist` is on the loop: the point, the segment's direction and how far to its end.
func _at(dd: float) -> Array:
	var d := fposmod(dd, _total)
	for k in points.size():
		if d <= _seg_len[k]:
			var a := points[k]
			var b := points[(k + 1) % points.size()]
			return [a.lerp(b, d / _seg_len[k]), (b - a).angle(), _seg_len[k] - d, k]
		d -= _seg_len[k]
	return [points[0], 0.0, 0.0, 0]

func _place() -> void:
	var here := _at(dist)
	position = Iso.to_screen(here[0])
	# Turn smoothly over the last 0.6 tiles of a segment instead of snapping at the corner.
	var h: float = here[1]
	if float(here[2]) < 0.6:
		var nxt: Array = _at(dist + float(here[2]) + 0.01)
		var k: float = 1.0 - float(here[2]) / 0.6
		h = h + wrapf(float(nxt[1]) - h, -PI, PI) * k * 0.5
	heading = h
	_update_shape()
	queue_redraw()

## Tier-C movement: exactly along the lane line (no drift onto sidewalks); speed eases up and down; it stops for
## anything ahead in its lane rather than pushing it.
func _physics_process(delta: float) -> void:
	if points.is_empty():
		return
	var here := _at(dist)
	var limit := cruise * (0.5 if float(here[2]) < 1.0 else 1.0)
	if _something_ahead(grid_pos()):
		speed = move_toward(speed, 0.0, float(def.get("brake", 6.0)) * delta)
		blocked_t += delta
	else:
		blocked_t = 0.0
		speed = move_toward(speed, limit, float(def.get("accel", 2.0)) * delta)
	dist += speed * delta
	_place()

func _something_ahead(g: Vector2) -> bool:
	var f := forward()
	var others: Array[Vector2] = []
	if world:
		var p: Node2D = world._driving() if world._driving() else world.player
		if p.visible or world._driving():
			others.append(Iso.to_grid(p.position))
		for v in world.vehicles.values():
			others.append(v.grid_pos())
		if world.conflict and world.conflict.police and is_instance_valid(world.conflict.police):
			others.append(Iso.to_grid(world.conflict.police.position))
	for t in get_tree().get_nodes_in_group("traffic"):
		if t != self and is_instance_valid(t) and not t.is_queued_for_deletion():
			others.append(t.grid_pos())
	var reach := LOOK_AHEAD + float(def.get("length", 1.4)) * 0.5
	for o in others:
		var d := o - g
		var along := d.dot(f)
		if along > 0.0 and along < reach and absf(d.cross(f)) < LANE_HALF:
			return true
	return false
