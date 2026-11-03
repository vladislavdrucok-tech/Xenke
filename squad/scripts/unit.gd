class_name Unit
extends CharacterBody3D
## A hero or an enemy on the plane: health, facing, frames from its pixel-art sheet (walk, idle, attack, work, hurt,
## down), a flash and knock-back when hit. Moves on X/Z only; walls are physics layer 1, units are layer 2 and do not
## push each other (the squad keeps its spacing by steering).

signal died(u: Unit)

var id := ""
var team := 0                 # 0 = heroes, 1 = enemies
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var attack_range := 1.5
var attack_cd := 0.8
var speed := 5.0
var world: Node
var spr: Spr
var shape: CollisionShape3D
var cd := 0.0
var swing := 0.0              # attack animation time left
var swing_len := 0.3
var work := 0.0               # >0 while working on an object (kept alive by the world each frame)
var stun := 0.0
var flash := 0.0
var walk_phase := 0.0
var moving := false
var dead := false
var face_dir := Vector3(0, 0, 1)
var lunge := 0.0
var tint := Color.WHITE
## Frame map for this sheet: walk (Array), idle, attack, work, hurt, down (ints).
var anim := {"walk": [0, 1, 2, 3], "idle": 4, "attack": 5, "work": 6, "hurt": 6, "down": 6}

func setup(s: Spr, radius: float) -> void:
	spr = s
	add_child(spr)
	shape = CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = 1.2
	shape.shape = sh
	shape.position.y = 0.6
	add_child(shape)
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0

func dist_to(o: Node3D) -> float:
	return Vector2(global_position.x - o.global_position.x, global_position.z - o.global_position.z).length()

func dist_to_point(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()

func step(dir: Vector3, _delta: float) -> void:
	velocity = Vector3(dir.x, 0, dir.z) * speed
	move_and_slide()
	global_position.y = 0.0
	moving = dir.length() > 0.05

func take_damage(amount: float, from: Vector3) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.16
	var push := global_position - from
	push.y = 0.0
	if push.length() > 0.01:
		move_and_collide(push.normalized() * (0.18 if team == 1 else 0.08))
		global_position.y = 0.0
	world.on_hit(self, amount)
	if hp <= 0.0:
		hp = 0.0
		die()

func die() -> void:
	dead = true
	shape.set_deferred("disabled", true)
	died.emit(self)

func heal(amount: float) -> void:
	if not dead:
		hp = minf(max_hp, hp + amount)

## Which frame to show now; subclasses can override for their own states.
func pick_frame() -> int:
	if dead:
		return int(anim.down)
	if flash > 0.04 and anim.has("hurt"):
		return int(anim.hurt)
	if swing > 0.0:
		return int(anim.attack)
	if work > 0.0:
		return int(anim.work) if fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3 else int(anim.idle)
	if moving:
		var w: Array = anim.walk
		return int(w[floori(walk_phase) % w.size()])
	return int(anim.idle)

func animate(delta: float) -> void:
	swing = maxf(0.0, swing - delta)
	work = maxf(0.0, work - delta)
	flash = maxf(0.0, flash - delta)
	if moving:
		walk_phase += delta * speed * 1.5
	var face_right := spr.right if absf(face_dir.x) <= 0.15 else face_dir.x > 0.0
	spr.show_frame(pick_frame(), face_right)
	# Hit flash (bright), stun wobble, a small bob while walking, a thrust forward when striking.
	var c := tint
	if flash > 0.0:
		c = Color(2.2, 2.0, 2.0) if team == 0 else Color(2.4, 1.3, 1.2)
	if dead and team == 0:
		c = Color(0.55, 0.55, 0.6)
	spr.sprite.modulate = Color(c.r, c.g, c.b, spr.sprite.modulate.a)
	var bob := absf(sin(walk_phase * PI)) * 0.04 if moving else 0.0
	var t := Time.get_ticks_msec() / 1000.0
	var wob := sin(t * 20.0) * 0.05 if stun > 0.0 else 0.0
	spr.sprite.position = Vector3(face_dir.x * lunge * 0.35 + wob, bob, face_dir.z * lunge * 0.35)
