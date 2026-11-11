extends RefCounted
## What can be owned: ball and cannon finishes, the Ad-Free pack and support contributions.
## Cosmetics change look and effects only: radius, speed and damage always come from the game's upgrades.
## Product IDs are the Google Play Console IDs; base prices are the USD starting points for the Console,
## the price shown to the player always comes from Google Play (ProductDetails.formatted_price).

const BALLS := [
	{"id": "classic", "how": "free"},
	{"id": "copper", "how": "crystals", "cost": 300},
	{"id": "teal", "how": "crystals", "cost": 600},
	{"id": "amber", "how": "play", "product": "db_ball_amber"},
	{"id": "frost", "how": "play", "product": "db_ball_frost"},
	{"id": "obsidian", "how": "play", "product": "db_ball_obsidian"},
]

const CANNONS := [
	{"id": "classic", "how": "free"},
	{"id": "ember", "how": "crystals", "cost": 150},
	{"id": "brass", "how": "crystals", "cost": 320},
	{"id": "crystal", "how": "crystals", "cost": 600},
	{"id": "bronze", "how": "play", "product": "db_cannon_bronze"},
	{"id": "crystal_engine", "how": "play", "product": "db_cannon_crystal"},
	{"id": "obsidian", "how": "play", "product": "db_cannon_obsidian"},
]

# type: "permanent" = one-time, acknowledged, restorable; "consumable" = repeatable support, consumed after recording
const PRODUCTS := [
	{"id": "db_no_ads", "type": "permanent", "usd": "3.99", "grants": "no_ads"},
	{"id": "db_ball_amber", "type": "permanent", "usd": "0.99", "grants": "ball:amber"},
	{"id": "db_ball_frost", "type": "permanent", "usd": "1.99", "grants": "ball:frost"},
	{"id": "db_ball_obsidian", "type": "permanent", "usd": "1.99", "grants": "ball:obsidian"},
	{"id": "db_cannon_bronze", "type": "permanent", "usd": "1.99", "grants": "cannon:bronze"},
	{"id": "db_cannon_crystal", "type": "permanent", "usd": "2.99", "grants": "cannon:crystal_engine"},
	{"id": "db_cannon_obsidian", "type": "permanent", "usd": "2.99", "grants": "cannon:obsidian"},
	{"id": "db_support_small", "type": "consumable", "usd": "0.99", "grants": "support"},
	{"id": "db_support_medium", "type": "consumable", "usd": "2.99", "grants": "support"},
	{"id": "db_support_large", "type": "consumable", "usd": "4.99", "grants": "support"},
	{"id": "db_support_extra", "type": "consumable", "usd": "9.99", "grants": "support"},
]

const SUPPORT := ["db_support_small", "db_support_medium", "db_support_large", "db_support_extra"]

static func product(pid: String) -> Dictionary:
	for p in PRODUCTS:
		if p.id == pid:
			return p
	return {}

static func product_ids() -> Array:
	var a: Array = []
	for p in PRODUCTS:
		a.append(p.id)
	return a

static func skins(kind: String) -> Array:
	return BALLS if kind == "ball" else CANNONS

static func skin(kind: String, id: String) -> Dictionary:
	for s in skins(kind):
		if s.id == id:
			return s
	return {}

static func skin_for_product(pid: String) -> Array:
	## [kind, id] of the finish a product unlocks, or [] for Ad-Free / support.
	var g: String = product(pid).get("grants", "")
	if g.begins_with("ball:"):
		return ["ball", g.substr(5)]
	if g.begins_with("cannon:"):
		return ["cannon", g.substr(7)]
	return []
