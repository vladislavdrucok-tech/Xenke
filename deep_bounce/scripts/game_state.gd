extends Node
## Global state: settings, wallet, record, cosmetics, the saved run. One save file written atomically
## (temp file + rename, previous copy kept as .bak), so a purchase or a finished volley is either fully
## stored or not at all. Also: text lookup, sound, vibration.

signal lang_changed
signal wallet_changed

const I18N := preload("res://scripts/i18n.gd")
const SAVE_PATH := "user://deep_bounce.save"
const VERSION := "1.0.1"

const SKINS := ["classic", "ember", "brass", "crystal"]
const SKIN_PRICE := {"classic": 0, "ember": 150, "brass": 320, "crystal": 600}

const SAVE_VERSION := 2
var settings := {"lang": "en", "sound": true, "music": true, "vibration": true, "shake": 2, "reduced_fx": false}
var migrated_from := 0       # save version found on disk when it was older than SAVE_VERSION
var meta := {"crystals": 0, "best": 0, "owned": ["classic"], "skin": "classic", "tutorial": 0, "runs": 0,
	"broken": 0, "spent": 0}
var run: Dictionary = {}          # Sim.to_dict() of the run in progress, or empty

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music: AudioStreamPlayer
var _streams := {}
var _last_play := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fresh := not load_game()
	if fresh:
		var os_lang := OS.get_locale_language()
		settings.lang = "uk" if os_lang == "uk" else "en"
	_setup_audio()

# ---------------------------------------------------------------- text

func lang_index() -> int:
	return 1 if settings.lang == "uk" else 0

func t(key: String, args: Array = []) -> String:
	var row: Array = I18N.S.get(key, [key, key])
	var s: String = row[lang_index()]
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s

func balls_text(n: int) -> String:
	return I18N.balls_text(n, lang_index())

func set_lang(l: String) -> void:
	if settings.lang == l:
		return
	settings.lang = l
	save_game()
	lang_changed.emit()

# ---------------------------------------------------------------- wallet & cosmetics

func add_crystals(n: int) -> void:
	if n == 0:
		return
	meta.crystals += n
	wallet_changed.emit()

func buy_skin(id: String) -> bool:
	## Spending and owning are written in the same save: the purchase is atomic.
	if not SKIN_PRICE.has(id) or meta.owned.has(id):
		return false
	var price: int = SKIN_PRICE[id]
	if meta.crystals < price:
		return false
	var before := meta.duplicate(true)
	meta.crystals -= price
	meta.spent += price
	meta.owned.append(id)
	meta.skin = id
	if not save_game():
		meta = before
		return false
	wallet_changed.emit()
	return true

func select_skin(id: String) -> void:
	if meta.owned.has(id):
		meta.skin = id
		save_game()

# ---------------------------------------------------------------- save

func has_run() -> bool:
	return not run.is_empty()

func save_game() -> bool:
	var data := {"v": SAVE_VERSION, "settings": settings, "meta": meta, "run": run}
	var text := JSON.stringify(data, "", true, true)
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak")
	var err := DirAccess.rename_absolute(tmp, SAVE_PATH)
	if err != OK:
		# some file systems refuse to rename over an existing file
		DirAccess.remove_absolute(SAVE_PATH)
		err = DirAccess.rename_absolute(tmp, SAVE_PATH)
	return err == OK

func load_game() -> bool:
	for p in [SAVE_PATH, SAVE_PATH + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var data = JSON.parse_string(f.get_as_text())
		if typeof(data) != TYPE_DICTIONARY or not data.has("meta"):
			continue
		data = migrate(data)
		var s: Dictionary = data.get("settings", {})
		for k in settings.keys():
			if s.has(k):
				settings[k] = s[k]
		settings.shake = int(settings.shake)
		settings.reduced_fx = bool(settings.reduced_fx)
		var m: Dictionary = data.meta
		for k in meta.keys():
			if m.has(k):
				meta[k] = m[k]
		for k in ["crystals", "best", "tutorial", "runs", "broken", "spent"]:
			meta[k] = int(meta[k])
		var owned: Array = []
		for o in meta.owned:
			owned.append(String(o))
		if not owned.has("classic"):
			owned.append("classic")
		meta.owned = owned
		meta.skin = String(meta.skin)
		if not meta.owned.has(meta.skin):
			meta.skin = "classic"
		var r = data.get("run", {})
		run = r if typeof(r) == TYPE_DICTIONARY else {}
		return true
	return false

static func migrate(data: Dictionary) -> Dictionary:
	## Older saves keep everything (run with its exact stones, record, purchases, language) and get the
	## fields that newer versions added.
	var v := int(data.get("v", 1))
	if v < 2:
		var st: Dictionary = data.get("settings", {})
		if not st.has("reduced_fx"):
			st["reduced_fx"] = false
		data["settings"] = st
		var r = data.get("run", {})
		if typeof(r) == TYPE_DICTIONARY and not r.is_empty() and not r.has("gen"):
			# the stones already in the run stay exactly as saved; rows generated from now on use the
			# layout generator with groups, side passages and pockets
			r["gen"] = 2
			data["run"] = r
		data["v"] = 2
		G.migrated_from = v
	return data

func store_run(sim: Sim) -> void:
	## Moves the run's found crystals into the wallet and writes run + wallet together.
	add_crystals(sim.claim())
	run = sim.to_dict()
	save_game()

func finish_run(sim: Sim) -> bool:
	add_crystals(sim.claim())
	var record: bool = sim.depth > meta.best
	meta.best = maxi(meta.best, sim.depth)
	meta.runs += 1
	meta.broken += int(sim.stats.destroyed)
	run = {}
	save_game()
	return record

# ---------------------------------------------------------------- feedback

func _setup_audio() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	var dir := DirAccess.open("res://assets/audio")
	if dir:
		for f in dir.get_files():
			var name := f.replace(".import", "")
			if name.ends_with(".wav") or name.ends_with(".ogg"):
				var st = load("res://assets/audio/" + name)
				if st:
					_streams[name.get_basename()] = st
	if _streams.has("music"):
		var ms = _streams.music
		if ms is AudioStreamOggVorbis:
			ms.loop = true
		_music.stream = ms
		_music.volume_db = -9.0
	apply_music()

func apply_music() -> void:
	if _music == null or _music.stream == null:
		return
	if settings.music and not _music.playing:
		_music.play()
	elif not settings.music and _music.playing:
		_music.stop()

func sfx(name: String, vol_db := 0.0, pitch := 1.0, min_gap_ms := 25) -> void:
	if not settings.sound or not _streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, -100000)) < min_gap_ms:
		return
	_last_play[name] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()

func vibrate(ms: int) -> void:
	if settings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func shake_scale() -> float:
	return [0.0, 0.45, 1.0, 1.7][clampi(int(settings.shake), 0, 3)]
