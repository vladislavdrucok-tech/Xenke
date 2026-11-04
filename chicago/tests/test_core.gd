extends TestCase

func test_iso_roundtrip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 100:
		var g := Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		near(Iso.to_grid(Iso.to_screen(g)).distance_to(g), 0.0, 0.0001, "roundtrip")
	eq(Iso.to_screen(Vector2(1, 0)), Vector2(64, 32), "x axis")
	eq(Iso.to_screen(Vector2(0, 1)), Vector2(-64, 32), "y axis")
	eq(Iso.tile_at(Iso.tile_center(Vector2i(5, 3))), Vector2i(5, 3), "tile centre")

func test_iso_ground_speed_is_even() -> void:
	# Equal screen-stick lengths must give equal ground speed in every direction.
	var base := Iso.to_grid(Iso.ground_velocity(Vector2(1, 0), 100.0)).length()
	for a in range(0, 360, 15):
		var d := Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a)))
		near(Iso.to_grid(Iso.ground_velocity(d, 100.0)).length(), base, 0.001, "dir %d" % a)

func test_iso_facing() -> void:
	eq(Iso.facing(Vector2(1, 0)), "E")
	eq(Iso.facing(Vector2(0, 1)), "S")
	eq(Iso.facing(Vector2(-1, 0)), "W")
	eq(Iso.facing(Vector2(0, -1)), "N")
	eq(Iso.facing(Vector2(1, 0.5)), "SE", "screen diagonal along a tile edge")

func test_localization_loaded() -> void:
	check(Loc.has_key("UI_NEW_GAME"), "UI_NEW_GAME missing")
	eq(Loc.t("UI_NEW_GAME"), "Нова гра")
	eq(Loc.t("HUD_DAY", [2, "08:00"]), "День 2, 08:00")

func test_font_has_ukrainian() -> void:
	var f: Font = load("res://art/fonts/LiberationSerif-Regular.ttf")
	var missing := ""
	for ch in "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя'’«»—$":
		if not f.has_char(ch.unicode_at(0)):
			missing += ch
	eq(missing, "", "glyphs missing from the UI font")

func test_clock_boundaries() -> void:
	WorldClock.set_total(8 * 60)
	var hours := [0]
	var days := [0]
	var h_cb := func(_d, _h): hours[0] += 1
	var d_cb := func(_d): days[0] += 1
	EventBus.hour_changed.connect(h_cb)
	EventBus.day_changed.connect(d_cb)
	WorldClock.advance(24 * 60 + 30)
	EventBus.hour_changed.disconnect(h_cb)
	EventBus.day_changed.disconnect(d_cb)
	eq(WorldClock.day(), 2)
	eq(WorldClock.clock_text(), "08:30")
	eq(hours[0], 24, "hour signals")
	eq(days[0], 1, "day signals")
	check(WorldClock.is_between(22, 6) == false, "08:30 is not night")
	WorldClock.set_total(23 * 60)
	check(WorldClock.is_between(22, 6), "23:00 is in a wrapping range")

func test_weather_deterministic() -> void:
	check(Weather.is_raining(1947, 16 * 60 + 30), "day 1 rains at 16:30")
	check(not Weather.is_raining(1947, 12 * 60), "day 1 dry at noon")
	for d in range(2, 30):
		eq(Weather.rain_window(1947, d), Weather.rain_window(1947, d), "same seed same weather")
