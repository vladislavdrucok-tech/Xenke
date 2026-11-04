class_name Story
extends RefCounted
## Story progress rules on top of StoryData. All functions take the profile.


static func chapter(idx: int) -> Dictionary:
	return StoryData.CHAPTERS[idx]


static func index_of(id: String) -> int:
	for i in StoryData.CHAPTERS.size():
		if StoryData.CHAPTERS[i]["id"] == id:
			return i
	return -1


static func is_done(profile: Dictionary, id: String) -> bool:
	return (profile["story"]["done"] as Array).has(id)


static func req_met(profile: Dictionary, req: Dictionary) -> bool:
	if int(profile.get("shifts_done", 0)) < int(req.get("shifts", 0)):
		return false
	if int(profile.get("level", 1)) < int(req.get("level", 0)):
		return false
	if req.has("upgrade"):
		var u: Array = req["upgrade"]
		if Upgrades.level_of(profile, u[0]) < int(u[1]):
			return false
	return true


## Index of the next chapter that can be played now, or -1.
static func next_available(profile: Dictionary) -> int:
	for i in StoryData.CHAPTERS.size():
		var c: Dictionary = StoryData.CHAPTERS[i]
		if is_done(profile, c["id"]):
			continue
		# Chapters are strictly sequential.
		return i if req_met(profile, c["req"]) else -1
	return -1


## The next chapter that is not yet playable (for "what's next" hints).
static func next_locked(profile: Dictionary) -> int:
	for i in StoryData.CHAPTERS.size():
		if not is_done(profile, StoryData.CHAPTERS[i]["id"]):
			return i
	return -1


static func option_available(profile: Dictionary, option: Dictionary) -> bool:
	var need: Dictionary = option.get("need", {})
	var vars: Dictionary = profile["story"]["vars"]
	for k in need:
		if int(vars.get(k, 0)) < int(need[k]):
			return false
	return true


static func _add_vars(profile: Dictionary, changes: Dictionary) -> void:
	var vars: Dictionary = profile["story"]["vars"]
	for k in changes:
		vars[k] = int(vars.get(k, 0)) + int(changes[k])


static func apply_choice(profile: Dictionary, option: Dictionary) -> void:
	_add_vars(profile, option.get("set", {}))
	if option.has("letter"):
		(profile["story"]["letters"] as Array).append({"from": option["letter"][0], "uk": option["letter"][1],
			"en": option["letter"][2], "read": false})
	if option.has("ending"):
		profile["story"]["ending"] = option["ending"]


## Marks the chapter as finished and hands out its rewards. Returns rewards.
static func complete(profile: Dictionary, idx: int) -> Dictionary:
	var c: Dictionary = StoryData.CHAPTERS[idx]
	if is_done(profile, c["id"]):
		return {}
	(profile["story"]["done"] as Array).append(c["id"])
	var met: Array = profile["story"]["met"]
	for m in c.get("met", []):
		if not met.has(m):
			met.append(m)
	_add_vars(profile, c.get("set", {}))
	var reward: Dictionary = c.get("reward", {})
	profile["coins"] = int(profile["coins"]) + int(reward.get("coins", 0))
	profile["shards"] = int(profile["shards"]) + int(reward.get("shards", 0))
	if reward.has("item"):
		var col: Dictionary = profile["collection"]
		col[reward["item"]] = int(col.get(reward["item"], 0)) + 1
	return reward


## Look of the city outside the window, driven by the player's decisions.
static func city_mood(profile: Dictionary) -> String:
	var ending: String = profile["story"].get("ending", "")
	if ending == "balance" or ending == "open":
		return "bright"
	if ending == "archive":
		return "neat"
	var vars: Dictionary = profile["story"]["vars"]
	if (profile["story"]["done"] as Array).size() < 3:
		return "grey"
	if int(vars.get("hope", 0)) > int(vars.get("trust", 0)):
		return "warm"
	if int(vars.get("trust", 0)) > int(vars.get("hope", 0)):
		return "neat"
	return "grey"


static func unread_letters(profile: Dictionary) -> int:
	var n := 0
	for l in profile["story"]["letters"]:
		if not l.get("read", false):
			n += 1
	return n
