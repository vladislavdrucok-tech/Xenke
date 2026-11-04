class_name Economy
extends RefCounted
## Applies shift results and offline income to the profile.

const IDLE_CAP_HOURS := 8.0


## Mutates the profile with a finished shift. Returns what changed so the
## results screen can show it.
static func apply_summary(profile: Dictionary, s: Dictionary) -> Dictionary:
	var out := {"levels": [], "unlocks": [], "new_items": [], "record": false, "daily_reward": 0}
	profile["coins"] = int(profile.get("coins", 0)) + int(s["coins"])
	profile["shards"] = int(profile.get("shards", 0)) + int(s["shards"])
	var st: Dictionary = profile.get("stats", {})
	st["parcels"] = int(st.get("parcels", 0)) + int(s["sorted"])
	st["correct"] = int(st.get("correct", 0)) + int(s["correct"])
	st["best_combo"] = max(int(st.get("best_combo", 0)), int(s["best_combo"]))
	st["play_time"] = float(st.get("play_time", 0.0)) + float(s["duration"])
	st["coins_earned"] = int(st.get("coins_earned", 0)) + int(s["coins"])
	profile["stats"] = st
	if s["mode"] == "shift" or s["mode"] == "tutorial":
		profile["shifts_done"] = int(profile.get("shifts_done", 0)) + 1
		var best_stars: int = int(profile.get("best_stars", 0))
		profile["best_stars"] = max(best_stars, int(s["stars"]))
	if s["mode"] == "record":
		var best := int(profile.get("record_best", 0))
		if int(s["score"]) > best:
			profile["record_best"] = int(s["score"])
			out["record"] = true
	if s["mode"] == "calm":
		profile["calm_best"] = max(int(profile.get("calm_best", 0)), int(s["score"]))
	if s["mode"] == "daily":
		var daily: Dictionary = profile.get("daily", {})
		var day: String = s.get("day", "")
		if daily.get("day", "") != day:
			daily = {"day": day, "best": 0, "claimed": false}
		if int(s["score"]) > int(daily["best"]):
			daily["best"] = int(s["score"])
			out["record"] = true
		if not daily["claimed"]:
			daily["claimed"] = true
			var mult: float = Upgrades.stats(profile)["daily_mult"]
			var sh := int(round(3.0 * mult))
			profile["shards"] = int(profile["shards"]) + sh
			out["daily_reward"] = sh
		profile["daily"] = daily
	var col: Dictionary = profile.get("collection", {})
	out["bonus_shards"] = 0
	for id in s["found"]:
		if int(col.get(id, 0)) == 0 and not out["new_items"].has(id):
			out["new_items"].append(id)
		else:
			out["dup_coins"] = int(out.get("dup_coins", 0)) + 25   # duplicates are sold to the archive
		col[id] = int(col.get(id, 0)) + 1
	profile["coins"] = int(profile["coins"]) + int(out.get("dup_coins", 0))
	# Every third 3-star shift crystallises a time shard.
	if int(s.get("stars", 0)) >= 3:
		profile["star_shifts"] = int(profile.get("star_shifts", 0)) + 1
		if int(profile["star_shifts"]) % 3 == 0:
			out["bonus_shards"] += 1
	profile["shards"] = int(profile["shards"]) + int(out["bonus_shards"])
	profile["collection"] = col
	var story: Dictionary = profile.get("story", {})
	var fr: Dictionary = story.get("friendship", {})
	for k in s["friends"]:
		fr[k] = int(fr.get(k, 0)) + int(s["friends"][k])
	story["friendship"] = fr
	profile["story"] = story
	var seen: Array = profile.get("seen_tips", [])
	for t in s.get("seen_tips", []):
		if not seen.has(t):
			seen.append(t)
	profile["seen_tips"] = seen
	var old_level := int(profile.get("level", 1))
	out["levels"] = Progression.add_xp(profile, int(s["xp"]))
	out["unlocks"] = Progression.newly_unlocked(old_level, int(profile["level"]))
	return out


## Coins earned by the coffee machine while the game was closed.
static func idle_income(profile: Dictionary, now_unix: int) -> int:
	var last := int(profile.get("last_seen", 0))
	var rate := int(Upgrades.stats(profile)["coffee_rate"])
	if last <= 0 or rate <= 0 or now_unix <= last:
		return 0
	var hours := minf(float(now_unix - last) / 3600.0, IDLE_CAP_HOURS)
	return int(floor(hours * rate))


static func can_buy_route(profile: Dictionary, id: String) -> String:
	var r: Dictionary = Content.ROUTES[id]
	if (profile.get("routes", []) as Array).has(id):
		return "max"
	if int(profile.get("level", 1)) < int(r.get("level", 1)):
		return "level"
	if int(profile.get("coins", 0)) < int(r["cost"]):
		return "coins"
	if int(profile.get("shards", 0)) < int(r["shards"]):
		return "shards"
	return "ok"


static func buy_route(profile: Dictionary, id: String) -> bool:
	if can_buy_route(profile, id) != "ok":
		return false
	var r: Dictionary = Content.ROUTES[id]
	profile["coins"] = int(profile["coins"]) - int(r["cost"])
	profile["shards"] = int(profile["shards"]) - int(r["shards"])
	(profile["routes"] as Array).append(id)
	return true
