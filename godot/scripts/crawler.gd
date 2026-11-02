extends Interactable
## A crawler. Before any fight the player can read it: it sleeps by food, sniffs, twitches at noise.
## Ways past: go round (another route), distract it with a thrown tin (it runs to the sound), or a short
## fight with the wrench (three hits and it flees). It never bites through walls or ladders.
## States: sleep, patrol, alert (wind-up), lunge, recover, distracted, hit, flee, gone.

signal gone_away

@export var home := 0.0
@export var min_x := 0.0
@export var max_x := 100.0
@export var floor_y := 320.0
var hero: Node2D
var st := "sleep"
var t := 0.0
var hp := 3
var dir := -1
var bait_x := 0.0
var walk := 0.0
## Busy with a washer drum: ignores the hero walking right past (a tin is different: it still bites if bumped).
var deaf := false
@onready var body: SpriteActor = $Body

const NOTICE_SLEEP := 46.0
const NOTICE_AWAKE := 110.0
const REACH := 34.0

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(150, 50)
	cs.shape = r
	cs.position = Vector2(0, -20)
	add_child(cs)
	highlight = Rect2(-26, -24, 52, 24)
	reset()

func reset() -> void:
	position = Vector2(home, floor_y)
	deaf = false
	st = "sleep" if st != "gone" else "gone"
	hp = 3 if st != "gone" else 0
	visible = st != "gone"
	monitorable = visible

func is_threat() -> bool:
	return st in ["alert", "lunge", "recover"] or (st == "patrol" and _hero_dist() < 60.0)

func _hero_dist() -> float:
	if hero == null or absf(hero.global_position.y - floor_y) > 18.0:
		return INF
	return absf(hero.global_position.x - global_position.x)

func _near_for_hit() -> bool:
	return _hero_dist() <= 46.0

func title() -> String:
	var what := {"sleep": "спить біля їжі", "patrol": "нишпорить", "alert": "готується до стрибка!", "lunge": "кидається!", "recover": "відскочив", "distracted": "вовтузиться біля консерви", "hit": "оглушений", "flee": "тікає"}
	return "Кроулер · %s" % what.get(st, "")

func verb() -> String:
	if _near_for_hit():
		return "Вдарити"
	return "Кинути консерву" if Game.count("can") > 0 else "Вдарити"

func blocked() -> String:
	if st in ["flee", "gone"]:
		return "Він уже тікає."
	if not _near_for_hit() and Game.count("can") == 0:
		return "Задалеко для удару. Знайди, чим відволікти, або обійди іншим шляхом."
	return ""

func finish() -> void:
	if _near_for_hit():
		_take_hit()
	else:
		Game.take("can")
		bait_x = clampf(global_position.x + signf(global_position.x - hero.global_position.x) * 90.0, min_x, max_x)
		st = "distracted"
		deaf = false
		t = 7.0
		Game.note("Кроулера відволікли консервою — він шукає їжу, а не тебе.")
	super.finish()

func _take_hit() -> void:
	hp -= 1
	st = "hit"
	t = 0.45
	position.x += signf(global_position.x - hero.global_position.x) * 16.0
	body.tint = Color(1, 0.6, 0.55)
	if hp <= 0:
		st = "flee"
		Game.note("Кроулер утік після трьох ударів ключем.")

## A running washer drum: every crawler that hears it runs there and gnaws at the noise for a while.
func lure(x: float, secs: float) -> void:
	if st in ["gone", "flee", "hit"] or absf(x - global_position.x) > 420.0:
		return
	st = "distracted"
	bait_x = clampf(x, min_x, max_x)
	t = secs
	deaf = true

## Loud work nearby (a cart, a hammered door) wakes it up.
func noise(x: float) -> void:
	if st == "sleep" and absf(x - global_position.x) < 400.0:
		st = "patrol"
		dir = signf(x - global_position.x)

func _physics_process(delta: float) -> void:
	if st == "gone":
		return
	t -= delta
	var d := _hero_dist()
	var toward := signf(hero.global_position.x - global_position.x) if hero else 0.0
	match st:
		"sleep":
			body.frame = body.pose("sleep_breathe" if fmod(t, 2.4) < -1.2 else "sleep", 4)
			if d < NOTICE_SLEEP:
				_alert(toward)
		"patrol":
			_walk(dir * 24.0, delta)
			if position.x <= min_x or position.x >= max_x:
				dir = -dir
			if d < NOTICE_AWAKE:
				_alert(toward)
		"alert":
			body.face = int(toward) if toward != 0.0 else body.face
			body.frame = body.pose("alert", 5)
			body.position.x = 1.0 if int(t * 30.0) % 2 == 0 else -1.0
			if t <= 0.0:
				st = "lunge"
				t = 0.28
				dir = body.face
		"lunge":
			position.x = clampf(position.x + dir * 170.0 * delta, min_x, max_x)
			body.frame = body.pose("lunge", 5)
			if d < REACH and hero.has_method("hurt"):
				hero.hurt(20, global_position.x)
				st = "recover"
				t = 0.9
			elif t <= 0.0:
				st = "recover"
				t = 0.8
		"recover":
			body.frame = body.pose("land", 4)
			if t <= 0.0:
				st = "patrol" if d > NOTICE_AWAKE else "alert"
				t = 0.6
		"distracted":
			if absf(position.x - bait_x) > 3.0:
				_walk(signf(bait_x - position.x) * 60.0, delta)
			elif body.has_pose("eat"):
				body.frame = body.pose("eat", 4)
			else:
				body.frame = 4 if int(t * 3.0) % 2 == 0 else 5
			if t <= 0.0:
				st = "patrol"
				deaf = false
			elif d < 22.0 and not deaf:
				_alert(toward)
		"hit":
			body.frame = body.pose("hit", 5)
			if t <= 0.0:
				body.tint = Color.WHITE
				st = "flee" if hp <= 0 else "recover"
				t = 0.5
		"flee":
			_walk(signf(max_x - position.x + 0.1) * 110.0, delta)
			body.frame = body.pose("flee", body.frame)
			body.modulate.a = maxf(0.0, body.modulate.a - delta * 0.7)
			if position.x >= max_x - 1.0 or body.modulate.a <= 0.0:
				st = "gone"
				visible = false
				monitorable = false
				gone_away.emit()
	body.position.x = body.position.x if st == "alert" else 0.0

func _alert(toward: float) -> void:
	st = "alert"
	t = 0.55
	if toward != 0.0:
		body.face = int(toward)

func _walk(v: float, delta: float) -> void:
	position.x = clampf(position.x + v * delta, min_x, max_x)
	if v != 0.0:
		body.face = 1 if v > 0.0 else -1
	walk += delta * absf(v) / 12.0
	body.frame = floori(walk) % 4
