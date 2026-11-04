class_name NPC
extends CharacterBody2D
## A named NPC on screen (tier A/B): walks to its scheduled spot, faces the player when talked to.
## Off screen (another district) a named NPC is only its schedule entry (tier C, actors/npc/schedule.gd);
## when the player arrives, world.gd places it at its spot at once, so the two never disagree.

const SPEED := 150.0

var npc_id := ""
var def := {}
var figure: Figure
var target := Vector2.ZERO
var has_target := false
var leaving := false           # walking to the exit before vanishing (its schedule moved it elsewhere)
var stuck_t := 0.0
signal left_district(npc: NPC)

func setup(id: String, d: Dictionary) -> void:
	npc_id = id
	def = d
	name = "NPC_" + id

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		pts.append(Vector2(cos(a) * 14.0, sin(a) * 7.0))
	shape.points = pts
	cs.shape = shape
	add_child(cs)
	figure = Figure.new()
	figure.coat = Color(String(def.get("color", "#555555")))
	figure.hat = figure.coat.darkened(0.5)
	add_child(figure)

func kind() -> String:
	return "npc"

func verb() -> String:
	return "HUD_ACT_TALK"

var district: District
var route := PackedVector2Array()  # grid waypoints round walls and furniture (District.path)

func walk_to(p: Vector2) -> void:
	target = p
	has_target = true
	stuck_t = 0.0
	route = district.path(Iso.to_grid(position), Iso.to_grid(p)) if district else PackedVector2Array()

func _physics_process(delta: float) -> void:
	if not has_target:
		velocity = Vector2.ZERO
		figure.walking = false
		return
	while route.size() > 1 and Iso.to_grid(position).distance_to(route[0]) < 0.35:
		route.remove_at(0)
	var aim := Iso.to_screen(route[0]) if route.size() > 1 else target
	var d := aim - position
	if route.size() <= 1 and Vector2(d.x, d.y * 2.0).length() < 6.0:
		has_target = false
		velocity = Vector2.ZERO
		figure.walking = false
		if leaving:
			left_district.emit(self)
		return
	var dir := Vector2(d.x, d.y * 2.0).normalized()
	velocity = Iso.ground_velocity(dir, SPEED)
	var before := position
	move_and_slide()
	figure.walking = true
	figure.set_facing(Iso.facing(dir))
	# Blocked for a while (a crowd, a parked car): arrive anyway rather than push forever.
	if position.distance_to(before) < SPEED * delta * 0.1:
		stuck_t += delta
		if stuck_t > 2.5:
			position = target
	else:
		stuck_t = 0.0

func face(p: Vector2) -> void:
	var d := p - position
	figure.set_facing(Iso.facing(Vector2(d.x, d.y * 2.0)))
