class_name Unit
extends CharacterBody3D
## A hero or an enemy on the plane: health, facing, procedural animation (walk, attack, work, hit, death), hit flash.
## Moves on X/Z only; walls are physics layer 1, units are layer 2 and do not push each other (the squad keeps
## its spacing by steering instead).

signal died(u: Unit)

var id := ""
var display_name := ""
var team := 0                 # 0 = heroes, 1 = enemies
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var attack_range := 1.5
var attack_cd := 0.8
var speed := 5.0
var world: Node
var rig: Node3D
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
var lunge := 0.0              # body thrust forward during an attack (enemies)
var _meshes: Array[MeshInstance3D] = []

static var _flash_mat: StandardMaterial3D

func setup(model: Node3D, radius: float) -> void:
	rig = model
	add_child(rig)
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
	for m in rig.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m)

func pos2() -> Vector3:
	return Vector3(global_position.x, 0, global_position.z)

func dist_to(o: Node3D) -> float:
	return Vector2(global_position.x - o.global_position.x, global_position.z - o.global_position.z).length()

func dist_to_point(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()

func step(dir: Vector3, delta: float) -> void:
	velocity = Vector3(dir.x, 0, dir.z) * speed
	move_and_slide()
	global_position.y = 0.0
	moving = dir.length() > 0.05

func take_damage(amount: float, from: Vector3) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.12
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

func _flash() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.albedo_color = Color(1, 1, 1, 0.75)
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _flash_mat

## Procedural animation from the state: legs and arms swing while walking, the attack arm sweeps, work hammers.
func animate(delta: float) -> void:
	swing = maxf(0.0, swing - delta)
	work = maxf(0.0, work - delta)
	var f := flash
	flash = maxf(0.0, flash - delta)
	if (f > 0.0) != (flash > 0.0) or f > 0.0:
		for m in _meshes:
			if is_instance_valid(m):
				m.material_overlay = _flash() if flash > 0.0 else null
	if dead:
		return
	if moving:
		walk_phase += delta * speed * 2.6
	var s := sin(walk_phase) if moving else 0.0
	var t := Time.get_ticks_msec() / 1000.0
	for leg in rig.get_children():
		if leg.name.begins_with("LegA"):
			leg.rotation.x = s * 0.7
		elif leg.name.begins_with("LegB"):
			leg.rotation.x = -s * 0.7
	var body := rig.get_node_or_null("Body")
	var arm_l := rig.get_node_or_null("Body/ArmL")
	var arm_r := rig.get_node_or_null("Body/ArmR")
	if arm_l:
		arm_l.rotation.x = -s * 0.6
	if arm_r:
		arm_r.rotation.x = s * 0.6
		if swing > 0.0:
			var k := 1.0 - swing / swing_len
			arm_r.rotation.x = lerpf(-2.6, 0.9, ease(k, 0.4))
		elif work > 0.0:
			arm_r.rotation.x = -1.4 + absf(sin(t * 9.0)) * 1.6
	rig.position.y = absf(sin(walk_phase)) * 0.06 if moving else 0.0
	if body:
		body.rotation.x = 0.25 if work > 0.0 else (0.12 if moving else 0.0)
		body.position.z = lunge * 0.4
	# Idle breathing, a little wobble while stunned.
	if not moving and swing <= 0.0 and work <= 0.0 and body:
		body.scale = Vector3(1, 1.0 + sin(t * 2.4 + global_position.x) * 0.02, 1)
	if stun > 0.0:
		rig.rotation.z = sin(t * 18.0) * 0.08
	else:
		rig.rotation.z = 0.0
	var want := atan2(face_dir.x, face_dir.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, want, minf(1.0, delta * 14.0))
