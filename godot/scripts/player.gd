extends CharacterBody2D
## Einstein: walking, jumping and working with objects.
## One press of Use = one job: walk to the working spot, face the object, push the wrench in pulses,
## the result lands on the last pulse. Moving away or pressing again cancels.

signal job_finished(item: Interactable)
signal message(text: String)

const WALK := 85.0
const JUMP := -230.0
const GRAVITY := 620.0

@onready var body: Actor = $Body
@onready var sensor: Area2D = $Sensor

var target: Interactable
var job: Interactable
var job_t := 0.0
var walk_phase := 0.0
var land_t := 0.0
var _was_on_floor := true
## Input can be switched off (craft panel open, cut-scene).
var controls := true

func _physics_process(delta: float) -> void:
	var dir := 0.0
	if controls:
		dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0 and job:
		cancel_job()
	# Gravity, jump, horizontal movement.
	velocity.y = minf(velocity.y + GRAVITY * delta, 300.0)
	if controls and Input.is_action_just_pressed("jump") and is_on_floor() and not job:
		velocity.y = JUMP
	velocity.x = dir * WALK
	if job:
		_work(delta)
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		land_t = 0.1
	_was_on_floor = is_on_floor()
	land_t = maxf(0.0, land_t - delta)
	if velocity.x != 0.0:
		body.face = 1 if velocity.x > 0.0 else -1
		walk_phase += delta * absf(velocity.x) * 4.0 / (2.0 * 36.0)
	else:
		walk_phase = 0.0
	_pick_target()
	if controls and Input.is_action_just_pressed("act"):
		_press()
	_animate()

## The nearest usable object whose area the hero stands in gets the gold brackets.
func _pick_target() -> void:
	var best: Interactable = null
	var bd := INF
	if not job:
		for a in sensor.get_overlapping_areas():
			if a is Interactable and a.monitorable:
				var d := absf(a.global_position.x - global_position.x)
				if d < bd:
					bd = d
					best = a
	else:
		best = job
	if best != target:
		if target:
			target.highlighted = false
		target = best
		if target:
			target.highlighted = true

func _press() -> void:
	if job:
		cancel_job()
		return
	if not target:
		message.emit("Підійди ближче до предмета.")
		return
	var why := target.blocked()
	if why != "":
		message.emit(why)
		return
	job = target
	job_t = 0.0

func cancel_job() -> void:
	if job:
		job.on_progress(0.0)
	job = null
	job_t = 0.0

func _work(delta: float) -> void:
	# Walk to the working spot first and face the object; work only starts there.
	if not is_nan(job.spot_x) and absf(job.spot_x - global_position.x) > 1.5:
		var d := job.spot_x - global_position.x
		velocity.x = signf(d) * minf(absf(d) / delta, 80.0)
		body.face = 1 if d > 0.0 else -1
		walk_phase += delta * 5.0
		return
	body.face = 1 if job.global_position.x >= global_position.x - 4.0 else -1
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

## Pose from the 27-frame sheet; the wrench sits in the fist and swings with the push.
func _animate() -> void:
	var f := 12
	body.held = ""
	if job and (is_nan(job.spot_x) or absf(job.spot_x - global_position.x) <= 1.5) and job.work_time > 0.0:
		var phase := fmod(job_t, job.pulse) / job.pulse
		if job.tool == "kneel":
			f = 19
		else:
			f = 14 if phase < 0.55 else 12
			body.held = "wrench"
			body.held_angle = 1.5 - sin(phase * PI) * 1.1
	elif not is_on_floor():
		f = 21 if velocity.y < -90.0 else (22 if velocity.y > 90.0 else 15)
	elif velocity.x != 0.0:
		f = floori(walk_phase) % 4
	elif land_t > 0.0:
		f = 23
	body.frame = f
