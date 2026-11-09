extends Node
## Sound effects, music loop and vibration, all bundled in the game.

const NAMES := ["pop", "click", "snap", "ok", "found", "success", "coin", "cash", "tip", "buy",
	"whoosh", "photo", "flicker", "tick", "spring", "rattle", "wiper", "beep", "thud", "creak",
	"motor", "latch", "swish", "bell", "engine", "car", "gate", "fanfare"]

var streams: Dictionary = {}
var players: Array = []
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var loop_player: AudioStreamPlayer
var played: Array = []        # recent sound names (tests)
var buzzes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -12.0
	add_child(music)
	var m: AudioStreamWAV = load("res://assets/sfx/music.wav")
	if m:
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = int(m.get_length() * m.mix_rate)
		music.stream = m
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -18.0
	add_child(ambience)
	var a: AudioStreamWAV = load("res://assets/sfx/ambience.wav")
	if a:
		a.loop_mode = AudioStreamWAV.LOOP_FORWARD
		a.loop_begin = 0
		a.loop_end = int(a.get_length() * a.mix_rate)
		ambience.stream = a
	loop_player = AudioStreamPlayer.new()
	add_child(loop_player)
	Game.changed.connect(_apply)
	_apply()


func _apply() -> void:
	var sound := Game.setting("sound")
	var want_music := sound and Game.setting("music")
	if want_music and not music.playing and music.stream:
		music.play()
	elif not want_music and music.playing:
		music.stop()
	if sound and not ambience.playing and ambience.stream:
		ambience.play()
	elif not sound and ambience.playing:
		ambience.stop()
	if not sound:
		loop_player.stop()


func play(name: String, pitch := 1.0, vol := 0.0) -> void:
	played.append(name)
	if played.size() > 40:
		played.pop_front()
	if not Game.setting("sound") or not streams.has(name):
		return
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.pitch_scale = pitch
			p.volume_db = vol
			p.play()
			return
	var p0: AudioStreamPlayer = players[0]
	p0.stream = streams[name]
	p0.pitch_scale = pitch
	p0.volume_db = vol
	p0.play()


## A held sound (window motor, wheel spin); stop with stop_loop().
func loop(name: String, pitch := 1.0) -> void:
	if not Game.setting("sound") or not streams.has(name):
		return
	if loop_player.playing and loop_player.stream == streams[name]:
		loop_player.pitch_scale = pitch
		return
	loop_player.stream = streams[name]
	loop_player.pitch_scale = pitch
	loop_player.play()


func stop_loop() -> void:
	loop_player.stop()


func buzz(ms: int) -> void:
	buzzes += 1
	if Game.setting("vibration"):
		Input.vibrate_handheld(ms)
