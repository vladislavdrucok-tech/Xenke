class_name Market
extends RefCounted
## Ринковий попит на кожен тип товару. Щодня змінюється: випадкове блукання
## з поверненням до середнього + рідкісні події («хайп», «обвал») для категорій.

const MIN_DEMAND := 0.55
const MAX_DEMAND := 1.75

var demand := {}      # id -> float
var prev := {}        # id -> float (вчорашній попит, для стрілок тренду)
var news := ""        # новина дня


func init_random(rng: RandomNumberGenerator) -> void:
	demand.clear()
	prev.clear()
	for id in ItemDB.ids():
		var d := 1.0 + rng.randf_range(-0.12, 0.12)
		demand[id] = d
		prev[id] = d
	news = "Ринок спокійний. Вдалої торгівлі!"


func get_demand(id: String) -> float:
	return float(demand.get(id, 1.0))


## Тренд: +1 росте, -1 падає, 0 стабільно.
func trend(id: String) -> int:
	var diff := get_demand(id) - float(prev.get(id, 1.0))
	if diff > 0.03:
		return 1
	if diff < -0.03:
		return -1
	return 0


func advance_day(rng: RandomNumberGenerator) -> void:
	for id in ItemDB.ids():
		var d := get_demand(id)
		prev[id] = d
		var vol: float = float(ItemDB.get_def(id).get("volatility", 0.1))
		d += rng.randfn(0.0, vol * 0.45) + (1.0 - d) * 0.22
		demand[id] = clampf(d, MIN_DEMAND, MAX_DEMAND)
	news = "Ринок без великих змін."
	var roll := rng.randf()
	if roll < 0.30:
		var cats := ItemDB.CATEGORY_NAMES.keys()
		var cat: String = cats[rng.randi_range(0, cats.size() - 1)]
		var boom := rng.randf() < 0.55
		var mult := 1.35 if boom else 0.72
		for id in ItemDB.ids():
			if ItemDB.get_def(id).get("cat", "") == cat:
				demand[id] = clampf(get_demand(id) * mult, MIN_DEMAND, MAX_DEMAND)
		var cname: String = ItemDB.CATEGORY_NAMES[cat]
		if boom:
			news = "Хайп! Категорія «%s» різко подорожчала." % cname
		else:
			news = "Обвал: категорія «%s» дешевшає." % cname


func to_dict() -> Dictionary:
	return {"demand": demand.duplicate(), "prev": prev.duplicate(), "news": news}


func from_dict(d: Dictionary) -> void:
	demand.clear()
	prev.clear()
	var dd: Dictionary = d.get("demand", {})
	var pp: Dictionary = d.get("prev", {})
	for id in ItemDB.ids():
		demand[id] = clampf(float(dd.get(id, 1.0)), MIN_DEMAND, MAX_DEMAND)
		prev[id] = clampf(float(pp.get(id, demand[id])), MIN_DEMAND, MAX_DEMAND)
	news = str(d.get("news", ""))
