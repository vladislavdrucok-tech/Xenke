class_name Weather
extends RefCounted
## Deterministic weather from the campaign seed and the clock: the same save always has the same rain.
## Chapter 1 has one weather type (rain). Day 1 always rains 16:00-18:00 so the first evening shows it.
## Rain: darker light, wet roads (cars brake and steer worse), fewer pedestrians.

static func _h(a: int, b: int) -> int:
	var h := 2166136261
	for v in [a, b]:
		for i in 4:
			h = ((h ^ ((v >> (i * 8)) & 0xff)) * 16777619) & 0xffffffff
	return h

static func rain_window(seed_v: int, day: int) -> Vector2:
	if day == 1:
		return Vector2(16, 18)
	var h := _h(seed_v, day)
	if h % 3 != 0:
		return Vector2(-1, -1)
	var start := 10 + (h >> 8) % 9
	return Vector2(start, start + 2 + (h >> 16) % 3)

static func is_raining(seed_v: int, total_minutes: int) -> bool:
	var day := total_minutes / (24 * 60) + 1
	var w := rain_window(seed_v, day)
	var h := float(total_minutes % (24 * 60)) / 60.0
	return w.x >= 0.0 and h >= w.x and h < w.y
