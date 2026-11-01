class_name Npc
extends Node2D
## A companion on the ground floor: walks to a point, looks at the hero, knocks, pushes a cart.
## Frames of the A166 sheet: 0-3 walk, 4 idle, 5 knock, 6 push, 7 crouch.

@export var char_name := "nazar"
@export var height := 68.0
var body: SpriteActor
var target_x := NAN
var speed := 62.0
## Frame shown while standing still.
var pose := 4
## Frame shown while moving (-1 = the walk cycle).
var move_pose := -1
var look_at: Node2D
var _walk := 0.0

func _ready() -> void:
	body = SpriteActor.new()
	body.char_name = char_name
	body.height = height
	add_child(body)

func go(x: float, spd := 62.0) -> void:
	target_x = x
	speed = spd

func arrived() -> bool:
	return is_nan(target_x) or absf(target_x - position.x) < 1.0

func _process(delta: float) -> void:
	if not arrived():
		var d := target_x - position.x
		position.x += signf(d) * minf(absf(d), speed * delta)
		body.face = 1 if d > 0.0 else -1
		_walk += delta * speed * 4.0 / 60.0
		body.frame = move_pose if move_pose >= 0 else floori(_walk) % 4
		body.position.y = -absf(sin(_walk * PI / 2.0)) * 1.0 if move_pose >= 0 else 0.0
	else:
		body.frame = pose
		body.position.y = 0.0
		if look_at and pose != 5:
			body.face = 1 if look_at.global_position.x > global_position.x else -1
