extends Node
## Autoload "Sfx": short sounds and phone vibration, both switchable in Settings.

const NAMES := ["pick", "land", "match", "win", "lose", "undo", "button", "warn", "nope"]
var sound_on := true
var vibration_on := true
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for n in NAMES:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not sound_on or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func buzz(ms: int) -> void:
	if vibration_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
