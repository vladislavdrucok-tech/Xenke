extends Node
## Ads backend on Android: the DeepBounceAds plugin (android_plugins/deepbounce-ads, Google Mobile Ads + UMP).

signal consent_finished(can: bool, privacy_required: bool, error: String)
signal privacy_form_closed(error: String)
signal ad_loaded(kind: String, unit: String)
signal ad_failed_to_load(kind: String, unit: String, code: int, msg: String)
signal ad_showed(kind: String, unit: String)
signal ad_failed_to_show(kind: String, unit: String, code: int, msg: String)
signal ad_dismissed(kind: String, unit: String)
signal user_earned_reward(kind: String, unit: String, type: String, amount: int)

var p: Object

func _ready() -> void:
	p = Engine.get_singleton("DeepBounceAds")
	p.connect("consent_finished", func(a, b, c): consent_finished.emit(bool(a), bool(b), String(c)))
	p.connect("privacy_form_closed", func(e): privacy_form_closed.emit(String(e)))
	p.connect("ad_loaded", func(k, u): ad_loaded.emit(String(k), String(u)))
	p.connect("ad_failed_to_load", func(k, u, c, m): ad_failed_to_load.emit(String(k), String(u), int(c), String(m)))
	p.connect("ad_showed", func(k, u): ad_showed.emit(String(k), String(u)))
	p.connect("ad_failed_to_show", func(k, u, c, m): ad_failed_to_show.emit(String(k), String(u), int(c), String(m)))
	p.connect("ad_dismissed", func(k, u): ad_dismissed.emit(String(k), String(u)))
	p.connect("user_earned_reward", func(k, u, t, a): user_earned_reward.emit(String(k), String(u), String(t), int(a)))

func start(test_mode: bool, debug_eea: bool, test_devices: String, rating: String) -> void:
	p.start(test_mode, debug_eea, test_devices, rating)

func can_request_ads() -> bool:
	return p.canRequestAds()

func is_privacy_required() -> bool:
	return p.isPrivacyOptionsRequired()

func show_privacy() -> void:
	p.showPrivacyOptionsForm()

func load_rewarded(unit: String) -> void:
	p.loadRewarded(unit)

func load_interstitial(unit: String) -> void:
	p.loadInterstitial(unit)

func show_rewarded(unit: String) -> void:
	p.showRewarded(unit)

func show_interstitial(unit: String) -> void:
	p.showInterstitial(unit)

func disable() -> void:
	p.disableAds()
