class_name Player
extends CharacterBody2D
## Enzo on foot. Moves on the ground plane (core/iso.gd: equal ground speed in every direction), accelerates and
## stops smoothly, slides along walls. Origin = point between the feet (the y-sort key). The collider is a flat
## ellipse at the feet, so the head and shoulders may overlap walls behind, as in any isometric game.

const SPEED := 230.0       # screen px/s sideways (= 1.8 tiles/s); vertical is half (Iso.ground_velocity)
const RUN_MULT := 1.55
const ACCEL := 1500.0
const DECEL := 2200.0
const FOOT_RX := 15.0
const FOOT_RY := 7.5
const REACH := 84.0        # interaction reach, in "ground" px (the y difference counts double)

var figure: Figure
var facing := "S"
var controls_enabled := true
var hp := 100
var max_hp := 100

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16    # world, named NPCs, cars, gunmen
	var cs := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(Vector2(cos(a) * FOOT_RX, sin(a) * FOOT_RY))
	shape.points = pts
	cs.shape = shape
	add_child(cs)
	figure = Figure.new()
	figure.coat = Color("#6b4a2f")
	add_child(figure)

func _physics_process(delta: float) -> void:
	var want := Vector2.ZERO
	if controls_enabled:
		var dir := InputRouter.move_vector()
		var sp := SPEED * (RUN_MULT if Input.is_action_pressed("sprint") else 1.0)
		want = Iso.ground_velocity(dir, sp)
		if dir.length() > 0.1:
			facing = Iso.facing(dir)
	var rate := ACCEL if want.length() > 1.0 else DECEL
	velocity = velocity.move_toward(want, rate * delta)
	move_and_slide()
	figure.walking = velocity.length() > 12.0
	figure.set_facing(facing)

func set_facing(f: String) -> void:
	facing = f
	if figure:
		figure.set_facing(f)

## Distance that treats the 2:1 squash: a step up the screen is twice as far on the ground.
static func ground_dist(a: Vector2, b: Vector2) -> float:
	var d := b - a
	return Vector2(d.x, d.y * 2.0).length()

func grid_pos() -> Vector2:
	return Iso.to_grid(position)
