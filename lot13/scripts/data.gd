extends RefCounted
## Static game data: items, auction houses, upgrades, rivals, events, goals.
## Used through `const Data = preload("res://scripts/data.gd")`.

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_COLORS := [Color("b4b4c8"), Color("72c04c"), Color("4f9ae8"), Color("b070ec"), Color("f8c848")]

## r = rarity index, cat = category, v = base value in $ at 100% condition.
const ITEMS := {
	"rusty_wrench": {"r": 0, "cat": "tools", "v": 8},
	"worn_boot": {"r": 0, "cat": "clothing", "v": 6},
	"tin_kettle": {"r": 0, "cat": "home", "v": 12},
	"vhs_tape": {"r": 0, "cat": "media", "v": 5},
	"desk_lamp": {"r": 0, "cat": "home", "v": 15},
	"toy_car": {"r": 0, "cat": "toys", "v": 10},
	"book_stack": {"r": 0, "cat": "media", "v": 7},
	"claw_hammer": {"r": 0, "cat": "tools", "v": 9},
	"diner_mug": {"r": 0, "cat": "home", "v": 4},
	"sunglasses": {"r": 0, "cat": "clothing", "v": 11},
	"pocket_radio": {"r": 0, "cat": "electronics", "v": 18},
	"basketball": {"r": 0, "cat": "sports", "v": 14},
	"cassette_player": {"r": 1, "cat": "electronics", "v": 45},
	"skateboard": {"r": 1, "cat": "sports", "v": 55},
	"toolbox": {"r": 1, "cat": "tools", "v": 60},
	"vinyl_record": {"r": 1, "cat": "music", "v": 40},
	"leather_jacket": {"r": 1, "cat": "clothing", "v": 70},
	"film_camera": {"r": 1, "cat": "electronics", "v": 85},
	"tin_robot": {"r": 1, "cat": "toys", "v": 65},
	"brass_compass": {"r": 1, "cat": "antiques", "v": 50},
	"power_drill": {"r": 1, "cat": "tools", "v": 75},
	"retro_console": {"r": 1, "cat": "electronics", "v": 90},
	"electric_guitar": {"r": 2, "cat": "music", "v": 220},
	"typewriter": {"r": 2, "cat": "antiques", "v": 180},
	"pocket_watch": {"r": 2, "cat": "jewelry", "v": 250},
	"first_comic": {"r": 2, "cat": "collectibles", "v": 200},
	"brass_telescope": {"r": 2, "cat": "antiques", "v": 260},
	"gramophone": {"r": 2, "cat": "music", "v": 300},
	"signed_baseball": {"r": 2, "cat": "sports", "v": 240},
	"oil_painting": {"r": 2, "cat": "art", "v": 280},
	"silver_cutlery": {"r": 2, "cat": "home", "v": 210},
	"gold_ring": {"r": 3, "cat": "jewelry", "v": 800},
	"ceremonial_sword": {"r": 3, "cat": "antiques", "v": 950},
	"coin_album": {"r": 3, "cat": "collectibles", "v": 700},
	"music_box": {"r": 3, "cat": "art", "v": 1100},
	"meteorite_shard": {"r": 3, "cat": "collectibles", "v": 900},
	"treasure_map": {"r": 3, "cat": "antiques", "v": 750},
	"golden_idol": {"r": 4, "cat": "antiques", "v": 4000},
	"lost_crown": {"r": 4, "cat": "jewelry", "v": 6500},
	"classic_car_keys": {"r": 4, "cat": "collectibles", "v": 9000},
}

const ITEM_ORDER := [
	"rusty_wrench", "worn_boot", "tin_kettle", "vhs_tape", "desk_lamp", "toy_car", "book_stack", "claw_hammer",
	"diner_mug", "sunglasses", "pocket_radio", "basketball",
	"cassette_player", "skateboard", "toolbox", "vinyl_record", "leather_jacket", "film_camera", "tin_robot",
	"brass_compass", "power_drill", "retro_console",
	"electric_guitar", "typewriter", "pocket_watch", "first_comic", "brass_telescope", "gramophone",
	"signed_baseball", "oil_painting", "silver_cutlery",
	"gold_ring", "ceremonial_sword", "coin_album", "music_box", "meteorite_shard", "treasure_map",
	"golden_idol", "lost_crown", "classic_car_keys",
]

const CATEGORIES := ["tools", "home", "media", "toys", "clothing", "electronics", "sports", "music",
	"antiques", "jewelry", "art", "collectibles"]

## Auction houses. weights = chance per rarity; items = [min, max] per lot; boxes = container pool.
const AUCTIONS := [
	{"id": "flea", "rep": 1, "fee": 0, "weights": [66.0, 28.0, 5.3, 0.6, 0.1], "items": [3, 4],
		"boxes": ["cardboard", "cardboard", "cardboard", "crate"], "rivals": ["tony", "kim", "rose", "byte"], "count": 2, "range": [30, 250]},
	{"id": "storage", "rep": 3, "fee": 25, "weights": [50.0, 36.0, 11.5, 2.3, 0.2], "items": [3, 5],
		"boxes": ["cardboard", "crate", "crate", "suitcase"], "rivals": ["tony", "kim", "rose", "byte", "max"], "count": 3, "range": [80, 700]},
	{"id": "estate", "rep": 6, "fee": 100, "weights": [30.0, 40.0, 22.0, 7.2, 0.8], "items": [3, 5],
		"boxes": ["crate", "suitcase", "suitcase", "locker"], "rivals": ["rose", "max", "byte", "gold", "tony"], "count": 3, "range": [250, 2000]},
	{"id": "antique", "rep": 10, "fee": 300, "weights": [14.0, 34.0, 34.0, 15.5, 2.5], "items": [4, 6],
		"boxes": ["suitcase", "locker", "trunk", "trunk"], "rivals": ["rose", "max", "gold", "tony"], "count": 3, "range": [700, 6000]},
	{"id": "midnight", "rep": 15, "fee": 800, "weights": [5.0, 24.0, 40.0, 25.0, 6.0], "items": [4, 6],
		"boxes": ["locker", "trunk", "trunk", "golden"], "rivals": ["max", "gold", "rose", "tony"], "count": 3, "range": [2000, 20000]},
]

## Upgrades: base cost grows x2.6 per level. vals are shown to the player and used by the game.
const UPGRADES := [
	{"id": "shelves", "icon": "shelf", "base": 100, "max": 4, "vals": [10, 14, 20, 28, 40]},
	{"id": "bench", "icon": "wrench", "base": 120, "max": 4, "vals": [85, 90, 95, 98, 100]},
	{"id": "scanner", "icon": "magnifier", "base": 180, "max": 4, "vals": [0, 1, 2, 3, 4]},
	{"id": "showroom", "icon": "sign", "base": 250, "max": 4, "vals": [0, 8, 16, 25, 35]},
	{"id": "truck", "icon": "truck", "base": 400, "max": 3, "vals": [4, 5, 6, 7]},
	{"id": "charm", "icon": "cat", "base": 500, "max": 4, "vals": [0, 15, 30, 50, 75]},
]

## Rival bidders. aggr = chance to bid when thinking; mult = valuation range; likes = categories they overpay for.
const RIVALS := {
	"tony": {"aggr": 0.85, "mult": [0.78, 0.98], "likes": ["tools", "sports", "electronics"], "style": "fast"},
	"rose": {"aggr": 0.55, "mult": [0.72, 0.92], "likes": ["antiques", "jewelry", "art", "home"], "style": "normal"},
	"max": {"aggr": 0.70, "mult": [0.76, 0.95], "likes": ["collectibles", "music", "electronics"], "style": "sniper"},
	"byte": {"aggr": 0.65, "mult": [0.74, 0.92], "likes": ["electronics", "toys", "media"], "style": "normal"},
	"gold": {"aggr": 0.70, "mult": [0.80, 1.00], "likes": ["jewelry", "art", "antiques", "collectibles"], "style": "normal"},
	"kim": {"aggr": 0.50, "mult": [0.62, 0.82], "likes": ["home", "clothing", "media"], "style": "cautious"},
}

## Daily events (weight). Most are gentle; negative ones are small.
const EVENTS := {
	"collector": 14, "rain": 10, "bidding_war": 9, "free_entry": 8, "found_cash": 10, "leak": 6,
	"tv": 7, "ticket": 6, "lucky": 7, "stranger": 9, "sale_day": 9,
}

const EVENT_ICONS := {"collector": "trophy", "rain": "rain", "bidding_war": "gavel", "free_entry": "tag",
	"found_cash": "coin", "leak": "rain", "tv": "star", "ticket": "calendar", "lucky": "cat",
	"stranger": "hand", "sale_day": "tag"}

## Long-term goals for the endless mode: kind, target, reward $.
const GOALS := [
	{"id": "first_box", "kind": "boxes", "n": 1, "reward": 50},
	{"id": "boxes_10", "kind": "boxes", "n": 10, "reward": 150},
	{"id": "sell_10", "kind": "sold", "n": 10, "reward": 150},
	{"id": "repair_10", "kind": "repairs", "n": 10, "reward": 200},
	{"id": "earn_2k", "kind": "earned", "n": 2000, "reward": 300},
	{"id": "rep_5", "kind": "level", "n": 5, "reward": 400},
	{"id": "find_rare", "kind": "rare", "n": 1, "reward": 250},
	{"id": "collect_20", "kind": "found", "n": 20, "reward": 600},
	{"id": "earn_25k", "kind": "earned", "n": 25000, "reward": 2000},
	{"id": "find_epic", "kind": "epic", "n": 1, "reward": 1000},
	{"id": "rep_12", "kind": "level", "n": 12, "reward": 3000},
	{"id": "find_legend", "kind": "legendary", "n": 1, "reward": 5000},
	{"id": "collect_40", "kind": "found", "n": 40, "reward": 20000},
	{"id": "earn_250k", "kind": "earned", "n": 250000, "reward": 25000},
]

const BUYER_PORTRAITS := 12


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, ITEMS["rusty_wrench"])


static func rarity_of(id: String) -> int:
	return int(item(id)["r"])


static func auction(tier: int) -> Dictionary:
	return AUCTIONS[clampi(tier, 0, AUCTIONS.size() - 1)]


static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return UPGRADES[0]


static func goal(id: String) -> Dictionary:
	for g in GOALS:
		if g["id"] == id:
			return g
	return GOALS[0]
