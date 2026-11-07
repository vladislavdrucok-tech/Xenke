extends Node
## Sound effects and music. Autoload "Sfx". Streams are loaded once; a small pool of players is reused.

const NAMES := ["click", "tick", "coin", "cash", "bid", "outbid", "gavel", "thud", "open", "whoosh",
	"reveal_common", "reveal_uncommon", "reveal_rare", "reveal_epic", "reveal_legendary", "hit_good",
	"hit_perfect", "miss", "upgrade", "levelup", "event", "error", "deal", "angry", "step"]
const MUSIC := ["garage", "auction"]

var streams := {}
var players: Array = []
var music_player: AudioStreamPlayer
var current_music := ""
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		_load("res://assets/sfx/%s.wav" % n, n)
	for m in MUSIC:
		_load("res://assets/sfx/music_%s.wav" % m, "music_" + m)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -7.0
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)


func _load(path: String, key: String) -> void:
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStream:
			streams[key] = s


func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not bool(Game.settings.get("sound", true)):
		return
	var s = streams.get(sound)
	if s == null or players.is_empty():
		return
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


func click() -> void:
	play("click", randf_range(0.94, 1.06), -2.0)


func music(track: String) -> void:
	current_music = track
	if music_player == null:
		return
	if track == "" or not bool(Game.settings.get("music", true)):
		music_player.stop()
		return
	var s = streams.get("music_" + track)
	if s == null:
		return
	if music_player.stream == s and music_player.playing:
		return
	music_player.stream = s
	music_player.play()


func refresh() -> void:
	var t := current_music
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	music(t)


func _on_music_finished() -> void:
	if current_music != "" and bool(Game.settings.get("music", true)):
		music_player.play()
