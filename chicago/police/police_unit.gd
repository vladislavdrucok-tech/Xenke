class_name PoliceUnit
extends CharacterBody2D
## A patrol car answering a call. It enters from the district edge named in data (never pops up in view), drives to
## the reported place, then follows Enzo while it can see him. TEMPORARY ART: black-and-white box with a red light.

const SPEED := 230.0     # screen px/s sideways (ground-even via Iso.ground_velocity)
var goal := Vector2.ZERO
var director: Node
var light_t := 0.0

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

func _physics_process(delta: float) -> void:
	light_t += delta
	var d := goal - position
	if Vector2(d.x, d.y * 2.0).length() > 40.0:
		velocity = Iso.ground_velocity(Vector2(d.x, d.y * 2.0).normalized(), SPEED)
		move_and_slide()
	queue_redraw()

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(-56, -6), Vector2(0, -34), Vector2(56, -6), Vector2(0, 22)])
	draw_colored_polygon(PackedVector2Array([Vector2(-56, 4), Vector2(0, 32), Vector2(56, 4), Vector2(56, -6), Vector2(0, 22), Vector2(-56, -6)]), Color("#111"))
	draw_colored_polygon(pts, Color("#1c1c22"))
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -14), Vector2(0, -26), Vector2(22, -14), Vector2(0, -2)]), Color("#e8e8e8"))
	var on := int(light_t * 4.0) % 2 == 0
	draw_circle(Vector2(0, -32), 6.0, Color("#ff3b30") if on else Color("#5a1a16"))
