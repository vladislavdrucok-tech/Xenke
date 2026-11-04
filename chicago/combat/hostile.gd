class_name Hostile
extends CharacterBody2D
## An armed enemy (chapter 1: the gunmen at the rail yard). Fair by design:
##  - it must SEE Enzo (range + line of sight through buildings) before it acts;
##  - every shot is telegraphed: it aims for AIM_TIME with a visible red line, then fires;
##  - hit chance falls with distance, with Enzo's cover and while he is moving;
##  - it pauses between shots, may move to a cover point, and runs away when badly hurt.
## States: IDLE -> ALERT (reacts, "!") -> AIM -> SHOOT -> RECOVER -> ... ; HURT interrupts; FLEE; DEAD.

signal died(h: Hostile)
signal fled(h: Hostile)
signal fired(from: Vector2, to: Vector2, hit: bool)

enum S { IDLE, ALERT, AIM, RECOVER, FLEE, DEAD }

const SIGHT := 640.0         # ground px
const ALERT_TIME := 0.7
const AIM_TIME := 0.75
const RECOVER_TIME := 1.3
const SPEED := 120.0
const DAMAGE := 14

var state := S.IDLE
var t := 0.0
var hp := 60
var max_hp := 60
var target: Node2D             # the player (or the car he sits in)
var director: Node
var figure: Figure
var rng := RandomNumberGenerator.new()
var cover_points: Array[Vector2] = []
var move_to := Vector2.INF
var aim_at := Vector2.ZERO
var flash_t := 0.0
var alerted := false           # heard the fight: hunts for a line of sight instead of standing still
var hunt_t := 0.0

func _ready() -> void:
	add_to_group("hostile")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 16
	collision_mask = 1 | 2 | 8
	var cs := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		pts.append(Vector2(cos(a) * 14.0, sin(a) * 7.0))
	shape.points = pts
	cs.shape = shape
	add_child(cs)
	# A taller hit box for bullets (they are traced at chest height, see director._trace).
	figure = Figure.new()
	figure.coat = Color("#3a2f2a")
	figure.hat = Color("#151210")
	add_child(figure)

func alive() -> bool:
	return state != S.DEAD and state != S.FLEE

func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	t += delta
	flash_t = maxf(flash_t - delta, 0.0)
	var sees: bool = target != null and director.can_see(self, target)
	match state:
		S.IDLE:
			if sees:
				_go(S.ALERT)
			elif alerted and target:
				hunt_t -= delta
				if hunt_t <= 0.0 or move_to == Vector2.INF:
					hunt_t = 1.5
					# Step towards where Enzo was, a tile at a time, so it comes round corners.
					var to := Iso.to_grid(target.position) - Iso.to_grid(position)
					move_to = position + Iso.to_screen(to.limit_length(1.5))
		S.ALERT:
			if t >= ALERT_TIME:
				_go(S.AIM if sees else S.RECOVER)
		S.AIM:
			aim_at = target.position if target else aim_at
			if not sees:
				_go(S.RECOVER)
			elif t >= AIM_TIME:
				_shoot()
				_go(S.RECOVER)
		S.RECOVER:
			if t >= RECOVER_TIME:
				if sees:
					_go(S.AIM)
				else:
					# Lost sight: move to the next cover point that might see him.
					_pick_cover()
					_go(S.IDLE)
		S.FLEE:
			if t > 4.0:
				# Out of the fight whether or not the path out was clear.
				state = S.DEAD
				fled.emit(self)
				queue_free()
				return
	_move(delta)
	queue_redraw()

func hear() -> void:
	alerted = true

func _go(s: int) -> void:
	state = s
	t = 0.0

func _move(delta: float) -> void:
	if move_to == Vector2.INF or state in [S.AIM]:
		velocity = Vector2.ZERO
		figure.walking = false
		return
	var d := move_to - position
	if Vector2(d.x, d.y * 2.0).length() < 8.0:
		move_to = Vector2.INF
		velocity = Vector2.ZERO
		figure.walking = false
		if state == S.FLEE:
			fled.emit(self)
			queue_free()
		return
	var dir := Vector2(d.x, d.y * 2.0).normalized()
	velocity = Iso.ground_velocity(dir, SPEED * (1.6 if state == S.FLEE else 1.0))
	move_and_slide()
	figure.walking = true
	figure.set_facing(Iso.facing(dir))

func _pick_cover() -> void:
	if cover_points.is_empty():
		return
	move_to = cover_points[rng.randi() % cover_points.size()]

func _shoot() -> void:
	var dist := Player.ground_dist(position, aim_at)
	var chance := clampf(0.85 - dist / 900.0, 0.2, 0.85)
	chance *= float(director.player_cover_factor(position))
	if director.player_moving():
		chance *= 0.6
	var hit: bool = rng.randf() < chance and director.can_see(self, target)
	flash_t = 0.12
	fired.emit(position + Vector2(0, -70), aim_at + Vector2(0, -60), hit)
	director.on_hostile_shot(self, hit, DAMAGE)

func take_damage(n: int) -> void:
	if state == S.DEAD:
		return
	hp = maxi(hp - n, 0)
	figure.hurt_t = 0.25
	if hp == 0:
		state = S.DEAD
		collision_layer = 0
		figure.rotation = -PI / 2.0
		figure.position = Vector2(-40, -6)
		died.emit(self)
	elif hp < max_hp * 0.3 and state != S.FLEE:
		_go(S.FLEE)
		move_to = position + Iso.to_screen(Vector2(4, -3))
	elif state == S.IDLE:
		alerted = true
		_go(S.ALERT)

func _draw() -> void:
	if state == S.ALERT:
		draw_string(ThemeDB.fallback_font, Vector2(-5, -128), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#ffcc33"))
	if state == S.AIM:
		# The telegraph: a red sight line that grows more solid until the shot.
		var k := t / AIM_TIME
		draw_line(Vector2(0, -70), aim_at - position + Vector2(0, -60), Color(1, 0.2, 0.15, 0.15 + 0.5 * k), 1.5 + k)
	if flash_t > 0.0:
		draw_circle(Vector2(10, -72), 7.0, Color("#ffe08a"))
	if state != S.DEAD:
		var w := 36.0
		draw_rect(Rect2(-w / 2, -138, w, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, -138, w * hp / max_hp, 4), Color("#d0463a"))
