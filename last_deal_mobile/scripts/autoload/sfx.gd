extends Node
## Прості звуки, синтезовані в коді (жодних сторонніх аудіофайлів).

const RATE := 22050
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	_streams["click"] = _make([[660.0, 0.035, "square"]], 0.25)
	_streams["coin"] = _make([[988.0, 0.06, "square"], [1319.0, 0.16, "square"]], 0.22)
	_streams["buy"] = _make([[180.0, 0.05, "noise"], [1568.0, 0.08, "sine"], [2093.0, 0.22, "sine"]], 0.35)
	_streams["deny"] = _make([[150.0, 0.12, "square"], [110.0, 0.16, "square"]], 0.22)
	_streams["bell"] = _make([[1175.0, 0.12, "sine"], [880.0, 0.35, "sine"]], 0.4)
	_streams["counter"] = _make([[520.0, 0.07, "triangle"], [620.0, 0.09, "triangle"]], 0.3)
	_streams["inspect"] = _make([[420.0, 0.04, "triangle"], [840.0, 0.04, "triangle"], [630.0, 0.06, "triangle"]], 0.3)
	_streams["day"] = _make([[523.0, 0.1, "triangle"], [659.0, 0.1, "triangle"], [784.0, 0.1, "triangle"], [1047.0, 0.3, "triangle"]], 0.35)
	_streams["upgrade"] = _make([[392.0, 0.08, "square"], [523.0, 0.08, "square"], [784.0, 0.25, "square"]], 0.2)
	_streams["leave"] = _make([[330.0, 0.1, "triangle"], [247.0, 0.2, "triangle"]], 0.3)


func play(name: String) -> void:
	if not Game.settings.get("sound", true):
		return
	var s: AudioStream = _streams.get(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.play()


## notes: [[частота, тривалість, форма], ...] — граються послідовно.
func _make(notes: Array, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var seed_v := 12345
	for n in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var shape: String = n[2]
		var count := int(dur * RATE)
		for i in count:
			var t := float(i) / RATE
			var ph := fmod(t * freq, 1.0)
			var v := 0.0
			match shape:
				"square":
					v = 1.0 if ph < 0.5 else -1.0
				"triangle":
					v = 4.0 * absf(ph - 0.5) - 1.0
				"noise":
					seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
					v = float(seed_v % 2000) / 1000.0 - 1.0
				_:
					v = sin(t * freq * TAU)
			var env := minf(1.0, float(i) / 120.0) * pow(1.0 - float(i) / count, 1.5)
			var sample := int(clampf(v * env * vol, -1.0, 1.0) * 32767.0)
			data.append(sample & 0xff)
			data.append((sample >> 8) & 0xff)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
