extends Node
## Sound effects pool and looping music on separate buses.

const SFX := ["swipe", "stamp", "ok", "combo", "coin", "levelup", "bell", "error", "portal", "tube",
	"quarantine", "click", "blip", "tick", "lift", "event", "meow", "fail"]
const POOL := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _hum: AudioStreamPlayer
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in SFX:
		var s = load("res://assets/audio/%s.wav" % n)
		if s:
			_streams[n] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_hum = AudioStreamPlayer.new()
	_hum.bus = "SFX"
	_hum.volume_db = -14.0
	# Looping is set in the .import files (edit/loop_mode = Forward).
	_hum.stream = load("res://assets/audio/belt_loop.wav")
	add_child(_hum)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func set_volumes(music: float, sfx: float) -> void:
	_set_bus("Music", music)
	_set_bus("SFX", sfx)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.01)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.01, 1.0)))


func play(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(sfx_name):
		return
	# The same sound twice within 30 ms is merged (keeps the mix clean).
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sfx_name, -1000)) < 30:
		return
	_last_play[sfx_name] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	if track == "":
		_music.stop()
		return
	var s = load("res://assets/audio/music_%s.wav" % track)
	if s:
		_music.stream = s
		_music.volume_db = -4.0
		_music.play()


func hum(on: bool) -> void:
	if on and not _hum.playing and _hum.stream:
		_hum.play()
	elif not on:
		_hum.stop()
