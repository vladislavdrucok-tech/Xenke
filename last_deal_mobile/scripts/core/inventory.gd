class_name Inventory
extends RefCounted
## Склад гравця: список екземплярів предметів (словники).

const MAX_ITEMS := 40

var items: Array = []


func count() -> int:
	return items.size()


func is_full() -> bool:
	return items.size() >= MAX_ITEMS


func add(item: Dictionary) -> bool:
	if is_full():
		return false
	for it in items:
		if int(it["uid"]) == int(item["uid"]):
			return false  # захист від повторного додавання
	items.append(item)
	return true


func find(uid: int) -> Dictionary:
	for it in items:
		if int(it["uid"]) == uid:
			return it
	return {}


func remove(uid: int) -> Dictionary:
	for i in items.size():
		if int(items[i]["uid"]) == uid:
			var it: Dictionary = items[i]
			items.remove_at(i)
			return it
	return {}


func total_market_value(market: Market) -> int:
	var t := 0
	for it in items:
		t += Economy.market_price(it, market.get_demand(it["id"]))
	return t


func to_array() -> Array:
	return items.duplicate(true)


func from_array(a: Array) -> void:
	items.clear()
	for it in a:
		if it is Dictionary and ItemDB.ITEMS.has(str(it.get("id", ""))):
			var d: Dictionary = it.duplicate(true)
			d["uid"] = int(d.get("uid", 0))
			d["value"] = int(d.get("value", 5))
			d["bought_price"] = int(d.get("bought_price", 0))
			d["bought_day"] = int(d.get("bought_day", 0))
			d["condition"] = float(d.get("condition", 0.5))
			if not d.get("defects") is Array:
				d["defects"] = []
			items.append(d)
