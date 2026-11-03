class_name Hero
extends Unit
## A squad member. The leader moves with the joystick; a companion follows the leader's trail (so it goes round the
## same obstacles), keeps its own slot when the leader stops, and never drags the squad towards an enemy.
## Basic attacks are automatic: the nearest enemy in reach and in line of sight.

var leader: Hero
var ranged := false
var level := 1
var base_hp := 100.0
var base_atk := 10.0
var role := ""
var ability_text := ""
var portrait := ""
var active := true            # in the squad (the researcher waits until he is freed)
var _pending := 0.0
var _target: Unit
var down_t := 0.0             # a knocked-out companion gets up after a while

func stats_for(lv: int) -> Dictionary:
	return {"hp": roundf(base_hp * (1.0 + 0.25 * (lv - 1))), "atk": roundf(base_atk * (1.0 + 0.35 * (lv - 1)))}

func apply_level(lv: int, full := false) -> void:
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	level = lv
	var s := stats_for(lv)
	max_hp = s.hp
	atk = s.atk
	hp = max_hp if full else max_hp * ratio

func tick(delta: float, move: Vector3) -> void:
	cd = maxf(0.0, cd - delta)
	if dead:
		if leader != null:
			down_t -= delta
			if down_t <= 0.0:
				revive(0.4)
		animate(delta)
		return
	if not active:
		moving = false
		work = 0.3
		animate(delta)
		return
	var dir := move
	if leader != null:
		dir = _follow_dir()
	step(dir.limit_length(1.35), delta)
	if swing > 0.0 and is_instance_valid(_target) and not _target.dead:
		face_dir = (_target.global_position - global_position).normalized()
	elif moving:
		face_dir = dir.normalized()
	_attack(delta)
	animate(delta)

func _follow_dir() -> Vector3:
	var target: Vector3 = world.follow_point(self)
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	var sep: Vector3 = world.separation(self)
	if d < 0.3:
		return sep
	if d > 14.0:
		global_position = target
		return Vector3.ZERO
	return to / d * clampf(d / 1.0, 0.0, 1.3) + sep

func _attack(delta: float) -> void:
	if _pending > 0.0:
		_pending -= delta
		if _pending <= 0.0 and is_instance_valid(_target) and not _target.dead:
			if ranged:
				world.shoot(self, _target)
			elif dist_to(_target) < attack_range + 0.8:
				_target.take_damage(atk, global_position)
	if cd > 0.0 or work > 0.0:
		return
	var t: Unit = world.nearest_enemy(self, attack_range)
	if t:
		cd = attack_cd
		swing = swing_len
		_pending = swing_len * 0.45
		_target = t

func die() -> void:
	super.die()
	down_t = 8.0

func revive(frac: float) -> void:
	dead = false
	hp = max_hp * frac
	shape.set_deferred("disabled", false)
