extends Node
## Ads backend for an Android build in which the DeepBounceAds plugin is missing: consent never allows ad
## requests, so rewarded buttons show "Video unavailable" and no interstitial is ever shown.
## (The simulated ads in ads_fake.gd are for desktop runs and tests only, never for Android.)

signal consent_finished(can: bool, privacy_required: bool, error: String)
signal privacy_form_closed(error: String)
signal ad_loaded(kind: String, unit: String)
signal ad_failed_to_load(kind: String, unit: String, code: int, msg: String)
signal ad_showed(kind: String, unit: String)
signal ad_failed_to_show(kind: String, unit: String, code: int, msg: String)
signal ad_dismissed(kind: String, unit: String)
signal user_earned_reward(kind: String, unit: String, type: String, amount: int)

func start(_t: bool, _e: bool, _d: String, _r: String) -> void:
	(func(): consent_finished.emit(false, false, "DeepBounceAds plugin missing")).call_deferred()

func can_request_ads() -> bool:
	return false

func is_privacy_required() -> bool:
	return false

func show_privacy() -> void:
	(func(): privacy_form_closed.emit("")).call_deferred()

func load_rewarded(unit: String) -> void:
	(func(): ad_failed_to_load.emit("rewarded", unit, 0, "no ads plugin")).call_deferred()

func load_interstitial(unit: String) -> void:
	(func(): ad_failed_to_load.emit("interstitial", unit, 0, "no ads plugin")).call_deferred()

func show_rewarded(unit: String) -> void:
	(func(): ad_failed_to_show.emit("rewarded", unit, 0, "no ads plugin")).call_deferred()

func show_interstitial(unit: String) -> void:
	(func(): ad_failed_to_show.emit("interstitial", unit, 0, "no ads plugin")).call_deferred()

func disable() -> void:
	pass
