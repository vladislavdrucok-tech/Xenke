extends Node
## Advertising (autoload "Ads"): Google UMP consent, rewarded ads for the second chance and for doubled crystals,
## interstitials after "Play Again" / "Next Level" / "Retry". Rules:
##  * Ad-Free owners: the SDK is never started, nothing is requested or shown;
##  * consent is requested on every start; an ad request is made only while UMP says ads may be requested;
##  * a rewarded ad is started by the player; its reward is recorded (G.mark_reward_earned) the moment the SDK
##    reports it, before it is applied, so a restart or a repeated callback cannot lose or double it;
##  * interstitial limits come from config/monetization.cfg [ads_caps] and count both modes together;
##  * while a full-screen ad is up the game is paused and muted.

signal changed
signal reward_earned(placement: String, attempt_id: String)
signal rewarded_closed(placement: String, attempt_id: String, earned: bool, error: String)
signal privacy_changed

const AndroidAds := preload("res://scripts/ads_android.gd")
const FakeAds := preload("res://scripts/ads_fake.gd")
const NoAds := preload("res://scripts/ads_none.gd")
const LOAD_TIMEOUT_MS := 30000

var backend: Node
var cfg := ConfigFile.new()
var started := false
var consent_done := false
var can_request := false
var privacy_required := false
var loaded := {}       # ad unit -> true
var loading := {}      # ad unit -> msec when the request was made
var failed := {}       # ad unit -> error code of the last attempt
var showing := ""      # placement on screen: "revive", "double", "interstitial"
var requests := 0      # ad requests made in this session (tests: Ad-Free must keep this at 0)
var _attempt := ""
var _earned := false
var _inter_cb := Callable()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cfg.load("res://config/monetization.cfg")
	if OS.get_name() == "Android":
		# on a phone only the real SDK is ever used; without its plugin no ad is requested or shown
		use_backend(AndroidAds.new() if Engine.has_singleton("DeepBounceAds") else NoAds.new())
		G.diag("[ads] DeepBounceAds plugin: " + ("found" if Engine.has_singleton("DeepBounceAds") else "MISSING"))
	else:
		use_backend(FakeAds.new())     # desktop and tests

func use_backend(b: Node) -> void:
	if backend:
		backend.queue_free()
	backend = b
	add_child(b)
	b.consent_finished.connect(_on_consent)
	b.privacy_form_closed.connect(_on_privacy_closed)
	b.ad_loaded.connect(_on_loaded)
	b.ad_failed_to_load.connect(_on_load_failed)
	b.ad_showed.connect(_on_showed)
	b.ad_failed_to_show.connect(_on_show_failed)
	b.ad_dismissed.connect(_on_dismissed)
	b.user_earned_reward.connect(_on_earned)
	started = false
	consent_done = false
	can_request = false
	privacy_required = false
	loaded = {}
	loading = {}
	failed = {}
	showing = ""
	requests = 0

func test_ads() -> bool:
	return bool(cfg.get_value("admob", "use_test_ads", true)) or String(cfg.get_value("admob", "real_app_id", "")) == ""

func unit(placement: String) -> String:
	var key: String = {"revive": "rewarded_revive", "double": "rewarded_double", "interstitial": "interstitial"}[placement]
	if test_ads():
		return String(cfg.get_value("admob", "test_" + key, ""))
	return String(cfg.get_value("admob", "real_" + key, ""))

func cap(name: String, default):
	return cfg.get_value("ads_caps", name, default)

# ---------------------------------------------------------------- start, consent, privacy

func start() -> void:
	if started or G.is_ad_free():
		return
	started = true
	backend.start(test_ads(), bool(cfg.get_value("admob", "debug_geography_eea", false)) and test_ads(),
		String(cfg.get_value("admob", "test_device_ids", "")), String(cfg.get_value("admob", "max_ad_content_rating", "PG")))

func _on_consent(can: bool, privacy: bool, error: String) -> void:
	consent_done = true
	can_request = can
	privacy_required = privacy
	if error != "":
		print("[ads] consent: ", error)
	G.diag("[ads] consent finished: can_request=%s privacy_required=%s %s" % [can, privacy, error])
	changed.emit()
	privacy_changed.emit()

func show_privacy_options() -> void:
	backend.show_privacy()

func _on_privacy_closed(_error: String) -> void:
	can_request = backend.can_request_ads()
	privacy_required = backend.is_privacy_required()
	if not can_request:
		loaded.clear()
	changed.emit()
	privacy_changed.emit()

func disable() -> void:
	## Ad-Free was bought: stop requesting and showing at once.
	backend.disable()
	loaded.clear()
	loading.clear()
	changed.emit()

func available() -> bool:
	return started and not G.is_ad_free() and can_request

# ---------------------------------------------------------------- loading

func load_ad(placement: String) -> void:
	if not available():
		return
	var u := unit(placement)
	if u == "" or loaded.has(u) or loading.has(u):
		return
	if not backend.can_request_ads():   # checked right before every request
		can_request = false
		changed.emit()
		return
	loading[u] = Time.get_ticks_msec()
	failed.erase(u)
	requests += 1
	if placement == "interstitial":
		backend.load_interstitial(u)
	else:
		backend.load_rewarded(u)
	changed.emit()

func status(placement: String) -> String:
	## "off" (Ad-Free), "ready", "loading", "unavailable"
	if G.is_ad_free():
		return "off"
	var u := unit(placement)
	if loaded.has(u):
		return "ready"
	if loading.has(u):
		return "loading"
	if not started or not consent_done:
		return "loading"
	return "unavailable"

func is_ready(placement: String) -> bool:
	return loaded.has(unit(placement))

func _process(_dt: float) -> void:
	if loading.is_empty():
		return
	var now := Time.get_ticks_msec()
	for u in loading.keys():
		if now - int(loading[u]) > LOAD_TIMEOUT_MS:
			loading.erase(u)
			failed[u] = -2
			changed.emit()

func _on_loaded(_kind: String, u: String) -> void:
	G.diag("[ads] loaded " + u)
	loading.erase(u)
	failed.erase(u)
	if G.is_ad_free():
		return
	loaded[u] = true
	changed.emit()

func _on_load_failed(_kind: String, u: String, code: int, msg: String) -> void:
	loading.erase(u)
	loaded.erase(u)
	failed[u] = code
	G.diag("[ads] load failed %s %d %s" % [u, code, msg])
	changed.emit()

# ---------------------------------------------------------------- rewarded

func show_rewarded(placement: String, attempt_id: String) -> bool:
	if showing != "" or G.is_ad_free() or not is_ready(placement):
		return false
	showing = placement
	_attempt = attempt_id
	_earned = false
	loaded.erase(unit(placement))
	G.mute_for_ad(true)
	backend.show_rewarded(unit(placement))
	changed.emit()
	return true

func _on_earned(_kind: String, _u: String, _type: String, _amount: int) -> void:
	if showing != "revive" and showing != "double":
		return
	if _earned:
		return   # a repeated callback
	_earned = true
	G.mark_reward_earned(showing, _attempt, 0)
	reward_earned.emit(showing, _attempt)

func _on_showed(_kind: String, _u: String) -> void:
	G.mute_for_ad(true)

func _on_show_failed(kind: String, _u: String, code: int, msg: String) -> void:
	G.mute_for_ad(false)
	G.diag("[ads] show failed %s %d %s" % [kind, code, msg])
	_finish(false, "show_failed")

func _on_dismissed(_kind: String, _u: String) -> void:
	G.mute_for_ad(false)
	_finish(true, "")

func _finish(was_shown: bool, error: String) -> void:
	var p := showing
	showing = ""
	if p == "interstitial":
		if was_shown:
			G.interstitial_shown()
		var cb := _inter_cb
		_inter_cb = Callable()
		changed.emit()
		if cb.is_valid():
			cb.call()
		return
	if p == "":
		return
	changed.emit()
	rewarded_closed.emit(p, _attempt, _earned, "" if _earned else (error if error != "" else "no_reward"))

# ---------------------------------------------------------------- interstitial

func interstitial_due(rewarded_seen: bool) -> bool:
	if G.is_ad_free():
		return false
	if rewarded_seen and bool(cap("skip_after_rewarded", true)):
		return false
	if int(G.ads.finished_total) <= int(cap("free_runs", 3)):
		return false
	return int(G.ads.since_runs) >= int(cap("min_runs_between", 3)) and float(G.ads.since_secs) >= float(cap("min_active_seconds_between", 180.0))

func preload_interstitial(rewarded_seen: bool) -> void:
	if interstitial_due(rewarded_seen):
		load_ad("interstitial")

func show_interstitial_then(rewarded_seen: bool, next: Callable) -> void:
	## After "Play Again" / "Next Level" / "Retry": an interstitial if one is due and ready, then `next`.
	## No ad ready, an error, Ad-Free: `next` right away.
	if showing != "" or not interstitial_due(rewarded_seen) or not is_ready("interstitial"):
		next.call()
		return
	showing = "interstitial"
	_inter_cb = next
	loaded.erase(unit("interstitial"))
	G.mute_for_ad(true)
	backend.show_interstitial(unit("interstitial"))
	changed.emit()
