extends Node
## Game state for the trial scene: inventory, the repair recipe and the current step.
## (In the full game this would also be saved; the trial keeps it in memory.)

signal changed

## Recipe for the repair unit; the craft panel and the goal read it from here.
const REPAIR_COST := {"wood": 8, "scrap": 4, "cloth": 1}
const ITEM_NAMES := {"wood": "Деревина", "scrap": "Металобрухт", "cloth": "Тканина", "repair": "Ремонтний вузол", "water": "Чиста вода"}

var inv := {"wood": 12, "scrap": 6, "cloth": 2, "repair": 0, "water": 0}
## 0 broken, 1 unit fitted, 2 water running.
var filter_state := 0

func can_make_repair() -> bool:
	if inv.repair > 0 or filter_state > 0:
		return false
	for k in REPAIR_COST:
		if inv[k] < REPAIR_COST[k]:
			return false
	return true

## Spends the materials once; repeated taps do nothing.
func make_repair() -> bool:
	if not can_make_repair():
		return false
	for k in REPAIR_COST:
		inv[k] -= REPAIR_COST[k]
	inv.repair += 1
	changed.emit()
	return true

func goal() -> Dictionary:
	if filter_state == 0 and inv.repair == 0:
		return {"title": "Створи ремонтний вузол", "text": "Відкрий верстак Міри.", "x": 262.0, "need": REPAIR_COST}
	if filter_state == 0:
		return {"title": "Встанови вузол у фільтр", "text": "Полагодь фільтр ключем.", "x": 352.0, "need": {}}
	if filter_state == 1:
		return {"title": "Запусти воду", "text": "Відкрий кран на трубі.", "x": 348.0, "need": {}}
	return {"title": "Чиста вода тече!", "text": "Пробна сцена завершена.", "x": -1.0, "need": {}}
