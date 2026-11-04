class_name Achievements
extends RefCounted
## Long-term goals. check() grants the reward once and returns new ids.

## id: [stat getter key, target, shard reward, name uk/en, desc uk/en]
const DEFS := [
	["first_shift", "shifts", 1, 1, ["Перша зміна", "First Shift"], ["Відпрацюй першу зміну.", "Finish your first shift."]],
	["shifts_10", "shifts", 10, 1, ["Свій на пошті", "Regular"], ["10 змін.", "10 shifts."]],
	["shifts_50", "shifts", 50, 1, ["Ветеран конвеєра", "Belt Veteran"], ["50 змін.", "50 shifts."]],
	["shifts_200", "shifts", 200, 3, ["Легенда №404", "Legend of 404"], ["200 змін.", "200 shifts."]],
	["parcels_100", "parcels", 100, 1, ["Сотня", "A Hundred"], ["Відсортуй 100 посилок.", "Sort 100 parcels."]],
	["parcels_1000", "parcels", 1000, 1, ["Тисяча доріг", "A Thousand Roads"], ["1 000 посилок.", "1,000 parcels."]],
	["parcels_10000", "parcels", 10000, 3, ["Пошта всесвіту", "Post of the Universe"], ["10 000 посилок.", "10,000 parcels."]],
	["combo_20", "best_combo", 20, 1, ["Ритм", "Rhythm"], ["Серія з 20 правильних.", "A combo of 20."]],
	["combo_50", "best_combo", 50, 1, ["Потік", "Flow"], ["Серія з 50.", "A combo of 50."]],
	["combo_100", "best_combo", 100, 2, ["Машина часу", "Time Machine"], ["Серія зі 100.", "A combo of 100."]],
	["three_stars", "best_stars", 3, 1, ["Бездоганно", "Flawless"], ["Зміна на 3 зірки.", "A 3-star shift."]],
	["level_10", "level", 10, 1, ["Старший поштар", "Senior Clerk"], ["Досягни 10-го рівня.", "Reach level 10."]],
	["level_25", "level", 25, 2, ["Начальник часу", "Chief of Time"], ["Досягни 25-го рівня.", "Reach level 25."]],
	["collect_10", "collection", 10, 1, ["Колекціонер", "Collector"], ["10 різних предметів.", "10 different items."]],
	["collect_all", "collection", 26, 3, ["Архіваріус", "Archivist"], ["Уся колекція.", "The whole collection."]],
	["record_500", "record", 500, 1, ["Швидкі руки", "Quick Hands"], ["500 очок у рекорді.", "500 points in a record run."]],
	["record_2000", "record", 2000, 2, ["Блискавка", "Lightning"], ["2 000 очок у рекорді.", "2,000 points in a record run."]],
	["dailies_7", "dailies", 7, 2, ["Тиждень аномалій", "Week of Anomalies"], ["7 щоденних аномалій.", "7 daily anomalies."]],
	["hazards_50", "hazards", 50, 1, ["Сапер часу", "Time Sapper"], ["50 артефактів у карантин.", "50 artefacts quarantined."]],
	["boomerang_20", "boomerangs", 20, 1, ["Не повернеться", "No Return"], ["20 бумерангів з першого разу.", "20 boomerangs right first time."]],
	["friends", "friends", 30, 1, ["Пошта для друзів", "Mail for Friends"], ["30 посилок від друзів.", "30 parcels from friends."]],
	["robot_max", "robot", 4, 1, ["БІТ як новенький", "BIT Like New"], ["Повністю полагодь БІТа.", "Fully repair BIT."]],
	["routes_all", "routes", 5, 2, ["Усі дороги", "Every Road"], ["Відкрий усі маршрути.", "Open every route."]],
	["story_end", "ending", 1, 2, ["Посилка доставлена", "Parcel Delivered"], ["Пройди сюжет.", "Finish the story."]],
	["secret_end", "secret", 1, 3, ["Пошта всіх часів", "Post of All Times"], ["Таємна кінцівка.", "The secret ending."]],
	["rich", "coins_earned", 100000, 2, ["Скарбничка", "Piggy Bank"], ["Заробити 100 000 монет.", "Earn 100,000 coins."]],
]


static func value(profile: Dictionary, key: String) -> int:
	var st: Dictionary = profile.get("stats", {})
	match key:
		"shifts":
			return int(profile.get("shifts_done", 0))
		"best_stars":
			return int(profile.get("best_stars", 0))
		"level":
			return int(profile.get("level", 1))
		"record":
			return int(profile.get("record_best", 0))
		"collection":
			var n := 0
			for id in profile.get("collection", {}):
				if int(profile["collection"][id]) > 0:
					n += 1
			return n
		"friends":
			var t := 0
			var fr: Dictionary = profile.get("story", {}).get("friendship", {})
			for k in fr:
				t += int(fr[k])
			return t
		"robot":
			return Upgrades.level_of(profile, "robot")
		"routes":
			return (profile.get("routes", []) as Array).size()
		"ending":
			return 1 if str(profile.get("story", {}).get("ending", "")) != "" else 0
		"secret":
			return 1 if str(profile.get("story", {}).get("ending", "")) == "balance" else 0
		_:
			return int(st.get(key, 0))


static func earned(profile: Dictionary) -> Array:
	return profile.get("achievements", [])


static func check(profile: Dictionary) -> Array:
	if not profile.has("achievements"):
		profile["achievements"] = []
	var got: Array = profile["achievements"]
	var out := []
	for d in DEFS:
		if got.has(d[0]):
			continue
		if value(profile, d[1]) >= int(d[2]):
			got.append(d[0])
			profile["shards"] = int(profile.get("shards", 0)) + int(d[3])
			out.append(d[0])
	return out


static func def(id: String) -> Array:
	for d in DEFS:
		if d[0] == id:
			return d
	return []
