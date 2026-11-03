class_name Enemy
extends Unit
## A crawler. It sleeps or sniffs around its home, notices a hero in sight, chases, winds up (a red mark on the ground
## shows where it will strike), strikes, recovers. Too far from home it gives up, walks back and heals.
## The armoured one (big) slams the ground around itself instead: the red ring is the danger zone - step out of it.

var home := Vector3.ZERO
var detect := 6.0
var leash := 10.0
var big := false
var state := "idle"
var st := 0.0
var target: Unit
var windup := 0.5
var recover := 0.8
var slam_radius := 2.4
var reward := {}
var telegraph: MeshInstance3D
var wander := Vector3.ZERO

func make_telegraph() -> void:
	telegraph = MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 1.0
	m.bottom_radius = 1.0
	m.height = 0.02
	m.radial_segments = 32
	telegraph.mesh = m
	telegraph.material_override = Models.flat(Color(1.0, 0.18, 0.12, 0.38))
	telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	telegraph.visible = false
	add_child(telegraph)

func reset_home() -> void:
	if dead:
		return
	global_position = home
	hp = max_hp
	state = "idle"
	target = null
	stun = 0.0
	telegraph.visible = false

func tick(delta: float) -> void:
	cd = maxf(0.0, cd - delta)
	lunge = move_toward(lunge, 0.0, delta * 4.0)
	if dead:
		animate(delta)
		return
	if stun > 0.0:
		stun -= delta
		telegraph.visible = false
		if state == "windup":
			state = "chase"
		step(Vector3.ZERO, delta)
		animate(delta)
		return
	var dir := Vector3.ZERO
	st -= delta
	match state:
		"idle":
			if st <= 0.0:
				st = randf_range(1.5, 3.5)
				wander = home + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
			var to := wander - global_position
			to.y = 0.0
			if to.length() > 0.3:
				dir = to.normalized() * 0.3
			var h: Unit = world.nearest_hero(self, detect)
			if h:
				_engage(h)
		"chase":
			if target == null or target.dead or global_position.distance_to(home) > leash:
				state = "return"
			else:
				var closer: Unit = world.nearest_hero(self, detect)
				if closer and closer != target and dist_to(closer) < dist_to(target) - 1.0:
					target = closer
				var to := target.global_position - global_position
				to.y = 0.0
				var reach := attack_range if not big else slam_radius * 0.7
				if to.length() <= reach and world.los(global_position, target.global_position):
					_start_windup(to)
				else:
					dir = to.normalized()
		"windup":
			var k := 1.0 - st / windup
			if big:
				telegraph.scale = Vector3.ONE * slam_radius * (0.35 + 0.65 * k)
			telegraph.material_override = Models.flat(Color(1.0, 0.18, 0.12, 0.25 + 0.3 * k))
			if st <= 0.0:
				telegraph.visible = false
				_strike()
				state = "recover"
				st = recover
		"recover":
			if st <= 0.0:
				state = "chase"
		"return":
			var to := home - global_position
			to.y = 0.0
			hp = minf(max_hp, hp + delta * max_hp * 0.4)
			if to.length() < 0.5:
				state = "idle"
				hp = max_hp
			else:
				dir = to.normalized()
	step(dir, delta)
	if moving:
		face_dir = dir.normalized()
	animate(delta)

func _engage(h: Unit) -> void:
	if state in ["idle", "return"]:
		target = h
		state = "chase"
		world.alert(self)

func _start_windup(to: Vector3) -> void:
	state = "windup"
	st = windup
	face_dir = to.normalized()
	telegraph.visible = true
	if big:
		telegraph.position = Vector3(0, 0.03, 0)
		telegraph.scale = Vector3.ONE * slam_radius * 0.35
	else:
		telegraph.position = face_dir * attack_range * 0.6 + Vector3(0, 0.03, 0)
		telegraph.scale = Vector3.ONE * 0.55

func _strike() -> void:
	swing = 0.25
	lunge = 1.0
	if big:
		world.slam(self, slam_radius, atk)
	elif target and not target.dead and dist_to(target) <= attack_range + 0.6 and world.los(global_position, target.global_position):
		target.take_damage(atk, global_position)

## Hit while asleep or wandering: it turns on whoever hit it.
func provoked(by: Unit) -> void:
	if state in ["idle", "return"] and by:
		_engage(by)

func die() -> void:
	super.die()
	telegraph.visible = false
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(spr.sprite, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(spr.shadow, "transparency", 1.0, 0.5)
	tw.tween_callback(func(): visible = false)

## Crawler frames: six walking phases, asleep by its nest, rearing up before a strike, lunging, hit, fleeing.
func pick_frame() -> int:
	if dead or flash > 0.04:
		return spr.pose("hit", 5)
	if state == "windup":
		return spr.pose("alert", 5)
	if swing > 0.0:
		return spr.pose("lunge", 5)
	if stun > 0.0:
		return spr.pose("land", 4)
	if moving:
		return floori(walk_phase) % 6
	if state == "idle":
		return spr.pose("sleep_breathe", 4) if fmod(Time.get_ticks_msec() / 1000.0 + home.x, 2.4) < 1.2 else spr.pose("sleep", 4)
	return spr.pose("land", 0)
