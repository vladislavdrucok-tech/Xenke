extends Node
## Simulated ads for desktop runs and tests (same signals as ads_android.gd). Configurable: consent result,
## fill / network, and what the player does with a shown ad.

signal consent_finished(can: bool, privacy_required: bool, error: String)
signal privacy_form_closed(error: String)
signal ad_loaded(kind: String, unit: String)
signal ad_failed_to_load(kind: String, unit: String, code: int, msg: String)
signal ad_showed(kind: String, unit: String)
signal ad_failed_to_show(kind: String, unit: String, code: int, msg: String)
signal ad_dismissed(kind: String, unit: String)
signal user_earned_reward(kind: String, unit: String, type: String, amount: int)

var consent_can := true
var privacy_required := true
var network_ok := true
var fill := true
var outcome := "reward"        # "reward", "close" (closed before the reward), "fail" (cannot show), "double_cb"
var delay := 0.05
var started := 0
var loads := 0
var shows := 0
var _ready_units := {}

func _later(f: Callable, t := -1.0) -> void:
	get_tree().create_timer(delay if t < 0.0 else t).timeout.connect(f)

func start(_test_mode: bool, _eea: bool, _devices: String, _rating: String) -> void:
	started += 1
	_later(func(): consent_finished.emit(consent_can, privacy_required, ""))

func can_request_ads() -> bool:
	return consent_can

func is_privacy_required() -> bool:
	return privacy_required

func show_privacy() -> void:
	_later(func(): privacy_form_closed.emit(""))

func _load(kind: String, unit: String) -> void:
	loads += 1
	_later(func():
		if not network_ok:
			ad_failed_to_load.emit(kind, unit, 2, "Network error")
		elif not fill:
			ad_failed_to_load.emit(kind, unit, 3, "No fill")
		else:
			_ready_units[unit] = true
			ad_loaded.emit(kind, unit))

func load_rewarded(unit: String) -> void:
	_load("rewarded", unit)

func load_interstitial(unit: String) -> void:
	_load("interstitial", unit)

func _show(kind: String, unit: String) -> void:
	shows += 1
	if not _ready_units.has(unit) or outcome == "fail":
		_later(func(): ad_failed_to_show.emit(kind, unit, 1, "fail"))
		return
	_ready_units.erase(unit)
	_later(func():
		ad_showed.emit(kind, unit)
		if kind == "rewarded" and (outcome == "reward" or outcome == "double_cb"):
			user_earned_reward.emit(kind, unit, "coins", 1)
			if outcome == "double_cb":
				user_earned_reward.emit(kind, unit, "coins", 1)
		_later(func(): ad_dismissed.emit(kind, unit)))

func show_rewarded(unit: String) -> void:
	_show("rewarded", unit)

func show_interstitial(unit: String) -> void:
	_show("interstitial", unit)

func disable() -> void:
	_ready_units.clear()
