extends Node
## The single source of game time (autoload "WorldClock").
## Time is integer game minutes since the campaign start: day 1 = Monday, 3 March 1947, 00:00.
## One real second = MINUTES_PER_SECOND game minutes while running (a game day is 24 real minutes at the default).

const START_DAY_NAME_KEYS := ["DAY_MON", "DAY_TUE", "DAY_WED", "DAY_THU", "DAY_FRI", "DAY_SAT", "DAY_SUN"]
const MINUTES_PER_SECOND := 1.0

var total_minutes: int = 8 * 60       # starts at 08:00 of day 1
var running := false
var scale := 1.0                      # debug / tests may speed time up
var _acc := 0.0

func _process(delta: float) -> void:
	if not running:
		return
	_acc += delta * MINUTES_PER_SECOND * scale
	while _acc >= 1.0:
		_acc -= 1.0
		advance(1)

## Moves time forward by `minutes`, emitting each minute / hour / day boundary exactly once, in order.
func advance(minutes: int) -> void:
	for i in maxi(minutes, 0):
		var old_hour := hour()
		var old_day := day()
		total_minutes += 1
		EventBus.minute_passed.emit(total_minutes)
		if day() != old_day:
			EventBus.day_changed.emit(day())
		if hour() != old_hour:
			EventBus.hour_changed.emit(day(), hour())

## Jumps to the next occurrence of hh:00 (sleeping, waiting). Emits the boundaries passed on the way.
func advance_to_hour(h: int) -> void:
	var now := minute_of_day()
	var target := h * 60
	var d := target - now
	if d <= 0:
		d += 24 * 60
	advance(d)

func set_total(m: int) -> void:
	total_minutes = maxi(m, 0)
	_acc = 0.0

func day() -> int:
	return total_minutes / (24 * 60) + 1

func hour() -> int:
	return (total_minutes / 60) % 24

func minute() -> int:
	return total_minutes % 60

func minute_of_day() -> int:
	return total_minutes % (24 * 60)

func weekday() -> int:
	return (day() - 1) % 7

func is_between(from_h: float, to_h: float) -> bool:
	## Is the clock in [from, to)? Ranges may wrap midnight (22 -> 6).
	var h := minute_of_day() / 60.0
	if from_h <= to_h:
		return h >= from_h and h < to_h
	return h >= from_h or h < to_h

func clock_text() -> String:
	return "%02d:%02d" % [hour(), minute()]

## 0 = midnight dark, 1 = full day. Smooth dawn 5-7, dusk 18-20.
func daylight() -> float:
	var h := minute_of_day() / 60.0
	if h < 5.0 or h >= 20.0:
		return 0.0
	if h < 7.0:
		return (h - 5.0) / 2.0
	if h < 18.0:
		return 1.0
	return 1.0 - (h - 18.0) / 2.0
