extends Node
## Sound effects pool, music with crossfade, the motor hum and haptics.

const NAMES := ["click", "press", "unpress", "deny", "ding", "door_open", "door_close", "coin", "coins_big",
	"complaint", "heart_break", "board", "event_good", "event_bad", "shift_start", "shift_end", "fail",
	"upgrade", "unlock", "kid", "streak", "tick", "pickup", "forgive", "vanish", "buy",
	"v_guest", "v_business", "v_granny", "v_kid", "v_cat", "v_rocker", "v_robot", "v_couple",
	"v_inspector", "v_bellhop", "v_ghost"]

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var motor: AudioStreamPlayer
var current_music := ""
var _motor_target := 0.0
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	add_child(music_a)
	add_child(music_b)
	motor = AudioStreamPlayer.new()
	add_child(motor)
	var m = load("res://assets/sfx/motor.wav")
	if m is AudioStreamWAV:
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = int(m.get_length() * m.mix_rate)
		motor.stream = m
		motor.volume_db = -80.0


func play(n: String, pitch := 1.0, vol_db := 0.0, vary := 0.04) -> void:
	if not Save.setting("sfx") or not streams.has(n):
		return
	var now := Time.get_ticks_msec()
	if _last_play.get(n, -1000) > now - 35:
		return  # avoid stacking the same sound in one frame
	_last_play[n] = now
	for p in pool:
		if not p.playing:
			p.stream = streams[n]
			p.pitch_scale = pitch * (1.0 + randf_range(-vary, vary))
			p.volume_db = vol_db
			p.play()
			return


func music(n: String) -> void:
	if n == current_music:
		_apply_music_volume()
		return
	current_music = n
	var path := "res://assets/music/%s.ogg" % n
	var old := music_a if music_a.playing else music_b
	var nw := music_b if old == music_a else music_a
	if ResourceLoader.exists(path) and n != "":
		var s = load(path)
		if s is AudioStreamOggVorbis:
			s.loop = true
		nw.stream = s
		nw.volume_db = -40.0
		nw.play()
		var tw := create_tween().set_parallel(true)
		tw.tween_property(nw, "volume_db", _music_db(), 1.2)
		if old.playing:
			tw.tween_property(old, "volume_db", -40.0, 1.0)
			tw.chain().tween_callback(old.stop)
	elif old.playing:
		old.stop()


func _music_db() -> float:
	return -12.0 if Save.setting("music") else -80.0


func _apply_music_volume() -> void:
	for p in [music_a, music_b]:
		if p.playing and p.stream and p.volume_db > -39.0:
			p.volume_db = _music_db()


func refresh_settings() -> void:
	_apply_music_volume()
	if not Save.setting("sfx"):
		set_motor(0.0)


## 0..1 — how fast the cabin moves; the hum fades in and out.
func set_motor(level: float) -> void:
	_motor_target = level if Save.setting("sfx") else 0.0


func _process(delta: float) -> void:
	if motor.stream == null:
		return
	var target_db := lerpf(-40.0, -14.0, clampf(_motor_target, 0.0, 1.0))
	if _motor_target <= 0.01:
		target_db = -80.0
	motor.volume_db = move_toward(motor.volume_db, target_db, delta * 90.0)
	motor.pitch_scale = 0.8 + 0.4 * clampf(_motor_target, 0.0, 1.0)
	if motor.volume_db > -70.0 and not motor.playing:
		motor.play()
	elif motor.volume_db <= -79.0 and motor.playing:
		motor.stop()


func vibe(ms: int = 20) -> void:
	if Save.setting("vibe") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
