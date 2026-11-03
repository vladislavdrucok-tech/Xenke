extends CharacterBody2D
## The researcher in the missions: walk, jump, ladders, jobs on objects, health.
## One press of Use = one job: walk to the working spot, face the object, work in pulses; the result lands
## on the last pulse. Moving or pressing again cancels. Frames (A105): 0-3 walk, 4 idle, 5 wrench, 6 kneel, 7 knee up.

signal job_finished(item: Interactable)
signal message(text: String)
signal died

const WALK := 85.0
const JUMP := -235.0
const GRAVITY := 620.0
const CLIMB := 70.0

@onready var body: SpriteActor = $Body
@onready var sensor: Area2D = $Sensor

var target: Interactable
var job: Interactable
var job_t := 0.0
var walk_phase := 0.0
var land_t := 0.0
var hurt_t := 0.0
var climb: Dictionary = {}
var controls := true
var _was_on_floor := true
var _mask := 1

func _ready() -> void:
	_mask = collision_mask

func _physics_process(delta: float) -> void:
	hurt_t = maxf(0.0, hurt_t - delta)
	body.tint = Color(1, 0.55, 0.5) if hurt_t > 0.75 else Color.WHITE
	if not climb.is_empty():
		_climb(delta)
		_animate()
		return
	var dir := Input.get_axis("move_left", "move_right") if controls else 0.0
	if dir != 0.0 and job:
		cancel_job()
	velocity.y = minf(velocity.y + GRAVITY * delta, 320.0)
	if controls and Input.is_action_just_pressed("jump") and is_on_floor() and not job:
		velocity.y = JUMP
	velocity.x = dir * WALK
	if hurt_t > 0.9:
		velocity.x = _knock
	if job:
		_work(delta)
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		land_t = 0.12
	_was_on_floor = is_on_floor()
	land_t = maxf(0.0, land_t - delta)
	if velocity.x != 0.0 and hurt_t <= 0.9:
		body.face = 1 if velocity.x > 0.0 else -1
		walk_phase += delta * absf(velocity.x) * 4.0 / 72.0
	else:
		walk_phase = 0.0
	_pick_target()
	if controls and Input.is_action_just_pressed("act"):
		_press()
	_animate()

var _knock := 0.0

## Nearest usable thing whose area the hero stands in; a threat in reach goes first.
func _pick_target() -> void:
	var best: Interactable = null
	var bd := INF
	if job:
		best = job
	else:
		for a in sensor.get_overlapping_areas():
			if a is Interactable and a.monitorable and a.visible and (not a.has_method("usable") or a.usable()):
				var d := absf(a.global_position.x - global_position.x) - (1000.0 if a.has_method("is_threat") and a.is_threat() else 0.0)
				if d < bd:
					bd = d
					best = a
	if best != target:
		if is_instance_valid(target):
			target.highlighted = false
		target = best
		if target:
			target.highlighted = true

func _press() -> void:
	if job:
		cancel_job()
		return
	if not target:
		message.emit("Тут нічого використати. Підійди ближче до предмета.")
		return
	var why := target.blocked()
	if why != "":
		message.emit(why)
		return
	if target.has_method("prepare"):
		target.prepare()
	job = target
	job_t = 0.0

func cancel_job() -> void:
	if job:
		job.on_progress(0.0)
	job = null
	job_t = 0.0

func at_spot() -> bool:
	return job != null and (is_nan(job.spot_x) or absf(job.spot_x - global_position.x) <= 1.5)

func _work(delta: float) -> void:
	if not at_spot():
		var d := job.spot_x - global_position.x
		velocity.x = signf(d) * minf(absf(d) / delta, 80.0)
		body.face = 1 if d > 0.0 else -1
		walk_phase += delta * 5.0
		return
	body.face = 1 if job.global_position.x >= global_position.x - 2.0 else -1
	if job.work_time <= 0.0:
		_complete()
		return
	var before := job_t
	job_t += delta
	if floori(before / job.pulse) != floori(job_t / job.pulse):
		job.on_pulse(floori(job_t / job.pulse))
	job.on_progress(clampf(job_t / job.work_time, 0.0, 1.0))
	if job_t >= job.work_time:
		_complete()

func _complete() -> void:
	var done := job
	job = null
	job_t = 0.0
	done.finish()
	job_finished.emit(done)

# ---------- ladders: once started, climbing is automatic (no vertical stick on a phone) ----------
func start_climb(x: float, to_y: float) -> void:
	cancel_job()
	climb = {"x": x, "to": to_y}
	collision_mask = 0
	velocity = Vector2.ZERO
	global_position.x = x

func _climb(delta: float) -> void:
	var d: float = climb.to - global_position.y
	global_position.y += signf(d) * minf(absf(d), CLIMB * delta)
	walk_phase += delta * 5.0
	if absf(d) < 0.5:
		climb = {}
		collision_mask = _mask
		velocity = Vector2.ZERO

# ---------- health ----------
func hurt(dmg: int, from_x: float) -> void:
	if hurt_t > 0.0 or not climb.is_empty():
		return
	cancel_job()
	Game.hp = maxi(0, Game.hp - dmg)
	hurt_t = 1.1
	_knock = signf(global_position.x - from_x) * 140.0
	velocity.y = -120.0
	Game.changed.emit()
	if Game.hp <= 0:
		died.emit()

## Frames: the A105 sheet (0-3 walk, 4 idle, 5 wrench, 6 kneel, 7 knee up) plus, once M2 arrives,
## named moves; until then each move falls back to the closest A105 pose.
func _animate() -> void:
	var f := 4
	if not climb.is_empty():
		var a := floori(walk_phase) % 2 == 0
		if body.has_pose("climb_1"):
			f = body.pose("climb_1" if a else "climb_2", 7)
			body.face = 1
		else:
			f = 7 if a else 4
			body.face = 1 if a else -1
	elif hurt_t > 0.75 and body.has_pose("hurt"):
		f = body.pose("hurt", 4)
	elif job and at_spot() and job.work_time > 0.0:
		var phase := fmod(job_t, job.pulse) / job.pulse
		f = 6 if job.tool == "kneel" else (5 if phase < 0.55 else 4)
	elif not is_on_floor():
		if velocity.y < -150.0:
			f = body.pose("jump_up", 7)
		elif velocity.y < 60.0:
			f = body.pose("jump_up", 7) if not body.has_pose("fall") else (body.pose("jump_up", 7) if velocity.y < 0.0 else body.pose("fall", 6))
		else:
			f = body.pose("fall", 6)
	elif velocity.x != 0.0:
		f = floori(walk_phase) % 4
	elif land_t > 0.0:
		f = body.pose("land", 6)
	body.frame = f
	body.shadow = 1.0 if is_on_floor() or not climb.is_empty() else 0.35
