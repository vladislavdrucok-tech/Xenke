extends Node
## The player's profile and everything that must survive a restart: settings, wallet, records, finishes,
## Google Play entitlements and the purchase-token ledger, the rewarded-ad ledger, interstitial counters,
## level progress, the run/attempt in progress and the last results screen.
## One save file, written atomically (temp file + rename, previous copy kept as .bak): every change that
## belongs together (a purchase and its ledger entry, a reward and the crystals it pays, a level win and its
## first-clear bonus) is made in memory first and written by one save.

signal lang_changed
signal wallet_changed
signal profile_changed

const I18N := preload("res://scripts/i18n.gd")
const CATALOG := preload("res://scripts/catalog.gd")
const SAVE_PATH := "user://deep_bounce.save"
const VERSION := "1.1.0"
const SAVE_VERSION := 4
const FIRST_CLEAR := [20, 25, 30, 35, 40]     # first-clear bonus per chapter (levels 1-10, 11-20, …)

var settings := {"lang": "en", "lang_set": false, "sound": true, "music": true, "vibration": true, "shake": 2, "reduced_fx": false}
var meta := {"crystals": 0, "best": 0, "tutorial": 0, "runs": 0, "broken": 0, "spent": 0, "last_finished": ""}
var cos := {"balls": ["classic"], "ball": "classic", "cannons": ["classic"], "cannon": "classic"}
var ent := {"no_ads": false, "products": []}   # permanent Google Play products confirmed for this profile
var purchases := {}     # purchaseToken -> {"pid", "state": pending|granted|revoked, "acked", "consumed", "t", "order"}
var rewards := {}       # "<kind>:<attempt id>" -> {"state": "earned"|"applied", "amount", "t"}
var ads := {"finished_total": 0, "since_runs": 0, "since_secs": 0.0, "shown": 0}
var levels := {"unlocked": 1, "stars": {}, "first": {}, "best_volleys": {}}
var support := {"count": 0, "thanks": 0}
var run: Dictionary = {}          # Sim.to_dict() of the run / level attempt in progress, or empty
var result: Dictionary = {}       # results screen of the last finished run / attempt until it is closed
var migrated_from := 0            # save version found on disk when it was older than SAVE_VERSION
var test_no_save := false         # tests: never touch the real save file

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music: AudioStreamPlayer
var _streams := {}
var _last_play := {}
var _muted_for_ad := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var found := load_game()
	if not found or not bool(settings.lang_set):
		settings.lang = I18N.detect(OS.get_locale())
	_setup_audio()

# ---------------------------------------------------------------- text

func t(key: String, args = {}) -> String:
	return I18N.text(settings.lang, key, args)

func tn(key: String, n: int, args := {}) -> String:
	return I18N.text_n(settings.lang, key, n, args)

func balls_text(n: int) -> String:
	return tn("balls_n", n)

func set_lang(code: String) -> void:
	settings.lang_set = true
	if settings.lang == code:
		save_game()
		return
	settings.lang = code
	save_game()
	lang_changed.emit()

# ---------------------------------------------------------------- wallet & finishes

func add_crystals(n: int) -> void:
	if n == 0:
		return
	meta.crystals += n
	wallet_changed.emit()

func owns(kind: String, id: String) -> bool:
	return cos["balls" if kind == "ball" else "cannons"].has(id)

func selected(kind: String) -> String:
	return cos["ball" if kind == "ball" else "cannon"]

func buy_with_crystals(kind: String, id: String) -> bool:
	## Spending and owning are written in the same save: the purchase is atomic.
	var sk: Dictionary = CATALOG.skin(kind, id)
	if sk.is_empty() or sk.how != "crystals" or owns(kind, id):
		return false
	var price: int = sk.cost
	if meta.crystals < price:
		return false
	var before_meta := meta.duplicate(true)
	var before_cos := cos.duplicate(true)
	meta.crystals -= price
	meta.spent += price
	cos["balls" if kind == "ball" else "cannons"].append(id)
	cos["ball" if kind == "ball" else "cannon"] = id
	if not save_game():
		meta = before_meta
		cos = before_cos
		return false
	wallet_changed.emit()
	profile_changed.emit()
	return true

func select_skin(kind: String, id: String) -> void:
	if owns(kind, id):
		cos["ball" if kind == "ball" else "cannon"] = id
		save_game()
		profile_changed.emit()

func grant_permanent(pid: String) -> void:
	## Called inside a purchase transaction (the caller saves).
	if not ent.products.has(pid):
		ent.products.append(pid)
	var p: Dictionary = CATALOG.product(pid)
	if p.get("grants", "") == "no_ads":
		ent.no_ads = true
	var sk: Array = CATALOG.skin_for_product(pid)
	if not sk.is_empty():
		var list: Array = cos["balls" if sk[0] == "ball" else "cannons"]
		if not list.has(sk[1]):
			list.append(sk[1])

func revoke_permanent(pid: String) -> void:
	## A refund or chargeback confirmed by Google Play.
	ent.products.erase(pid)
	var p: Dictionary = CATALOG.product(pid)
	if p.get("grants", "") == "no_ads":
		ent.no_ads = false
	var sk: Array = CATALOG.skin_for_product(pid)
	if not sk.is_empty():
		var key := "balls" if sk[0] == "ball" else "cannons"
		cos[key].erase(sk[1])
		var sel := "ball" if sk[0] == "ball" else "cannon"
		if cos[sel] == sk[1]:
			cos[sel] = "classic"

func is_ad_free() -> bool:
	return bool(ent.no_ads)

# ---------------------------------------------------------------- rewards (rewarded ads and their Ad-Free equivalents)

func reward_state(kind: String, attempt_id: String) -> String:
	return String(rewards.get("%s:%s" % [kind, attempt_id], {}).get("state", ""))

func mark_reward_earned(kind: String, attempt_id: String, amount := 0) -> bool:
	## The SDK confirmed the reward (or an Ad-Free owner pressed the button): recorded before it is applied,
	## so a restart in between still applies it, and a repeated callback changes nothing.
	var key := "%s:%s" % [kind, attempt_id]
	if rewards.has(key):
		return false
	if kind == "double" and amount <= 0 and String(result.get("id", "")) == attempt_id:
		amount = int(result.get("gems", 0))     # the same amount as the run paid: base crystals and level bonus
	rewards[key] = {"state": "earned", "amount": amount, "t": int(Time.get_unix_time_from_system())}
	return save_game()

func apply_reward_mark(kind: String, attempt_id: String) -> void:
	## The reward has been applied; the caller writes it in the same save as its effect.
	var key := "%s:%s" % [kind, attempt_id]
	if rewards.has(key):
		rewards[key].state = "applied"

func apply_double(attempt_id: String) -> int:
	## Pays the doubled crystals of a finished run/attempt once. Returns the crystals added now (0 if already).
	var key := "double:%s" % attempt_id
	var r: Dictionary = rewards.get(key, {})
	if r.is_empty() or r.state == "applied":
		return 0
	var amount: int = r.amount
	r.state = "applied"
	meta.crystals += amount
	if result.get("id", "") == attempt_id:
		result.doubled = true
	save_game()
	wallet_changed.emit()
	return amount

# ---------------------------------------------------------------- runs, attempts, results

func has_run() -> bool:
	return not run.is_empty()

func new_attempt_id() -> String:
	var c := Crypto.new()
	return "%d-%s" % [int(Time.get_unix_time_from_system()), c.generate_random_bytes(6).hex_encode()]

func store_run(sim: Sim) -> void:
	## Moves the run's found crystals into the wallet and writes run + wallet together.
	add_crystals(sim.claim())
	run = sim.to_dict()
	save_game()

func finish_run(sim: Sim, level: Dictionary = {}) -> Dictionary:
	## Ends a run or level attempt once: wallet, record, level stars and first-clear bonus, interstitial
	## counters, results screen. Idempotent by attempt id (a repeated call returns the stored result).
	if sim.run_id != "" and meta.last_finished == sim.run_id and result.get("id", "") == sim.run_id:
		return result
	add_crystals(sim.claim())
	var res := {"id": sim.run_id, "mode": sim.mode, "won": sim.phase == Sim.PH_WON, "depth": sim.depth,
		"record": false, "gems": sim.run_gems, "bonus": 0, "broken": int(sim.stats.destroyed), "volleys": sim.volleys,
		"stars": 0, "first": false, "level_id": sim.level_id, "level_n": int(level.get("n", 0)), "doubled": false,
		"revived": sim.revive_used, "rewarded_seen": sim.rewarded_seen}
	if sim.mode == "endless":
		res.record = sim.depth > meta.best
		meta.best = maxi(meta.best, sim.depth)
	elif res.won:
		var n: int = res.level_n
		var stars := 1
		if sim.volleys <= int(level.get("t2", 0)):
			stars = 2
		if sim.volleys <= int(level.get("t3", 0)):
			stars = 3
		if sim.revive_used:
			stars = mini(stars, 2)
		res.stars = stars
		var id := sim.level_id
		levels.stars[id] = maxi(int(levels.stars.get(id, 0)), stars)
		if not levels.best_volleys.has(id) or sim.volleys < int(levels.best_volleys[id]):
			levels.best_volleys[id] = sim.volleys
		levels.unlocked = maxi(int(levels.unlocked), mini(50, n + 1))
		if not levels.first.has(id):
			# first clear: the flag and the bonus are written together
			var bonus: int = FIRST_CLEAR[clampi((n - 1) / 10, 0, 4)]
			levels.first[id] = sim.run_id
			res.bonus = bonus
			res.first = true
			res.gems += bonus
			meta.crystals += bonus
			if n == 50:
				res["all_clear"] = true
	meta.runs += 1
	meta.broken += int(sim.stats.destroyed)
	meta.last_finished = sim.run_id
	ads.finished_total = int(ads.finished_total) + 1
	ads.since_runs = int(ads.since_runs) + 1
	run = {}
	result = res
	save_game()
	wallet_changed.emit()
	return res

func close_result() -> void:
	result = {}
	save_game()

func level_stars_total() -> int:
	var t := 0
	for k in levels.stars:
		t += int(levels.stars[k])
	return t

func levels_done() -> int:
	return levels.first.size()

# ---------------------------------------------------------------- interstitial counters

func add_active_time(dt: float) -> void:
	ads.since_secs = float(ads.since_secs) + dt

func interstitial_shown() -> void:
	ads.since_runs = 0
	ads.since_secs = 0.0
	ads.shown = int(ads.shown) + 1
	save_game()

# ---------------------------------------------------------------- save

func save_game() -> bool:
	if test_no_save:
		return true
	var data := {"v": SAVE_VERSION, "settings": settings, "meta": meta, "cos": cos, "ent": ent, "purchases": purchases,
		"rewards": rewards, "ads": ads, "levels": levels, "support": support, "run": run, "result": result}
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
		var data = JSON.parse_string(FileAccess.get_file_as_string(p))
		if typeof(data) != TYPE_DICTIONARY or not data.has("meta"):
			continue
		apply_data(migrate(data))
		return true
	return false

func reset_defaults() -> void:
	settings = {"lang": "en", "lang_set": false, "sound": true, "music": true, "vibration": true, "shake": 2, "reduced_fx": false}
	meta = {"crystals": 0, "best": 0, "tutorial": 0, "runs": 0, "broken": 0, "spent": 0, "last_finished": ""}
	cos = {"balls": ["classic"], "ball": "classic", "cannons": ["classic"], "cannon": "classic"}
	ent = {"no_ads": false, "products": []}
	purchases = {}
	rewards = {}
	ads = {"finished_total": 0, "since_runs": 0, "since_secs": 0.0, "shown": 0}
	levels = {"unlocked": 1, "stars": {}, "first": {}, "best_volleys": {}}
	support = {"count": 0, "thanks": 0}
	run = {}
	result = {}

func apply_data(data: Dictionary) -> void:
	reset_defaults()
	var s: Dictionary = data.get("settings", {})
	for k in settings.keys():
		if s.has(k):
			settings[k] = s[k]
	settings.shake = int(settings.shake)
	settings.reduced_fx = bool(settings.reduced_fx)
	settings.lang_set = bool(settings.lang_set)
	if not I18N.codes().has(String(settings.lang)):
		settings.lang = "en"
	var m: Dictionary = data.meta
	for k in meta.keys():
		if m.has(k):
			meta[k] = m[k]
	for k in ["crystals", "best", "tutorial", "runs", "broken", "spent"]:
		meta[k] = int(meta[k])
	meta.last_finished = String(meta.last_finished)
	var c: Dictionary = data.get("cos", {})
	for k in cos.keys():
		if c.has(k):
			cos[k] = c[k]
	for key in ["balls", "cannons"]:
		var list: Array = []
		for o in cos[key]:
			list.append(String(o))
		if not list.has("classic"):
			list.append("classic")
		cos[key] = list
	if not cos.balls.has(String(cos.ball)):
		cos.ball = "classic"
	if not cos.cannons.has(String(cos.cannon)):
		cos.cannon = "classic"
	var e: Dictionary = data.get("ent", {})
	ent = {"no_ads": bool(e.get("no_ads", false)), "products": Array(e.get("products", [])).duplicate()}
	purchases = data.get("purchases", {})
	rewards = data.get("rewards", {})
	var a: Dictionary = data.get("ads", {})
	for k in ads.keys():
		if a.has(k):
			ads[k] = a[k]
	var lv: Dictionary = data.get("levels", {})
	for k in levels.keys():
		if lv.has(k):
			levels[k] = lv[k]
	levels.unlocked = int(levels.unlocked)
	var sp: Dictionary = data.get("support", {})
	for k in support.keys():
		if sp.has(k):
			support[k] = int(sp[k])
	var r = data.get("run", {})
	run = r if typeof(r) == TYPE_DICTIONARY else {}
	var rs = data.get("result", {})
	result = rs if typeof(rs) == TYPE_DICTIONARY else {}

static func migrate(data: Dictionary) -> Dictionary:
	## Older saves keep everything: the run with its exact stones (it becomes an endless run), the record,
	## bought cannon finishes and the selected one, the crystal balance, the language chosen in 1.0.
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
	if int(data.get("v", 2)) < 3:
		# format 3 (1.0.2): stones carry a weight and get their strength on entering the field; balls in
		# flight are stored bit for bit. Sim.from_dict reads the older shapes as they are.
		if G.migrated_from == 0:
			G.migrated_from = int(data.get("v", 2))
		data["v"] = 3
	if int(data.get("v", 3)) < 4:
		# format 4 (1.1): modes, ball finishes, Google Play entitlements and ledgers, levels, 12 languages
		if G.migrated_from == 0:
			G.migrated_from = 3
		var m: Dictionary = data.get("meta", {})
		var owned: Array = []
		for o in m.get("owned", ["classic"]):
			owned.append(String(o))
		if not owned.has("classic"):
			owned.append("classic")
		var sel := String(m.get("skin", "classic"))
		data["cos"] = {"balls": ["classic"], "ball": "classic", "cannons": owned, "cannon": sel if owned.has(sel) else "classic"}
		m.erase("owned")
		m.erase("skin")
		m["last_finished"] = ""
		data["meta"] = m
		var st: Dictionary = data.get("settings", {})
		# 1.0 offered English and Ukrainian: a saved choice of either is kept as the player's choice
		st["lang_set"] = String(st.get("lang", "")) in ["en", "uk"]
		data["settings"] = st
		var r = data.get("run", {})
		if typeof(r) == TYPE_DICTIONARY and not r.is_empty():
			r["mode"] = "endless"
			if String(r.get("run_id", "")) == "":
				r["run_id"] = "migrated-%d" % int(r.get("seed", 0))
			data["run"] = r
		data["v"] = 4
	return data

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

func mute_for_ad(on: bool) -> void:
	## A full-screen ad is on top: the game's sound stops and comes back afterwards.
	_muted_for_ad = on
	AudioServer.set_bus_mute(0, on)

func sfx(name: String, vol_db := 0.0, pitch := 1.0, min_gap_ms := 25) -> void:
	if not settings.sound or not _streams.has(name) or _muted_for_ad:
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
