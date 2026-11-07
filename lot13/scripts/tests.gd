extends Node
## Automated checks, run with a separate save file:
##   godot --headless --fixed-fps 60 --path lot13 -- --selftest   (game rules, data, saving, economy)
##   godot --headless --fixed-fps 60 --path lot13 -- --smoke      (every screen and overlay driven like a player)
## Prints "SELFTEST OK" / "SMOKE OK" and exits with code 0, or lists failures and exits with code 1.

const Data = preload("res://scripts/data.gd")

var main
var checks := 0
var failures := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--selftest"):
		call_deferred("_selftest")
	elif args.has("--shots"):
		var i: int = args.find("--shots")
		call_deferred("_shots", args[i + 1] if i + 1 < args.size() else "user://shots")
	else:
		call_deferred("_smoke")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _finish(tag: String) -> void:
	if FileAccess.file_exists(Game.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	if failures == 0:
		print("%s OK (%d checks)" % [tag, checks])
	else:
		print("%s FAILED: %d of %d checks" % [tag, failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


# ------------------------------------------------------------------ rules
func _selftest() -> void:
	Game.reset_state()
	check(Data.ITEMS.size() == 40, "40 items in the table")
	check(Data.ITEM_ORDER.size() == 40, "40 items in the order")
	var per := [0, 0, 0, 0, 0]
	for id in Data.ITEM_ORDER:
		var sid := str(id)
		check(Data.ITEMS.has(sid), "item listed " + sid)
		per[Data.rarity_of(sid)] += 1
		check(UI.item_tex(sid) != null, "item texture " + sid)
		check(L.has_key("item." + sid), "item name " + sid)
		check(L.has_key("cat." + str(Data.item(sid)["cat"])), "category name " + sid)
	for r in range(5):
		check(per[r] > 0, "rarity %d present" % r)
	for k in L.T["uk"].keys():
		check(L.T["en"].has(k), "english text for " + str(k))
	for k in L.T["en"].keys():
		check(L.T["uk"].has(k), "ukrainian text for " + str(k))
	for a in Data.AUCTIONS:
		check(L.has_key("auction." + str(a["id"])), "auction name " + str(a["id"]))
		for b in a["boxes"]:
			check(UI.box_tex(str(b)) != null and UI.box_tex(str(b), true) != null, "box art " + str(b))
	for id in Data.RIVALS.keys():
		check(UI.portrait_tex(str(id)) != null, "rival portrait " + str(id))
	for i in range(Data.BUYER_PORTRAITS):
		check(UI.portrait_tex("buyer_%d" % i) != null, "buyer portrait %d" % i)
	for id in Data.EVENTS.keys():
		check(L.has_key("event.%s.title" % id) and L.has_key("event.%s.text" % id), "event texts " + str(id))
	for g in Data.GOALS:
		check(L.has_key("goal." + str(g["id"])), "goal text " + str(g["id"]))

	# lots
	for tier in range(Data.AUCTIONS.size()):
		for i in range(40):
			var lot := Game.make_lot(tier)
			check(int(lot["count"]) >= 2 and int(lot["count"]) <= 6, "lot size tier %d" % tier)
			check(int(lot["value"]) > 0, "lot value tier %d" % tier)
			check(int(lot["low"]) <= int(lot["high"]), "estimate order tier %d" % tier)
			check(int(lot["start"]) >= 1, "start price tier %d" % tier)
			check((lot["items"] as Array).size() == int(lot["count"]), "lot contents tier %d" % tier)

	# money
	Game.money = 100
	check(not Game.spend(101), "cannot spend more than you have")
	check(Game.spend(40) and Game.money == 60, "spending")
	check(Game.nice_round(1234.0) == 1250, "nice rounding")
	check(Game.bid_step(100) >= 5, "bid step")

	# opening boxes and storage limits
	Game.reset_state()
	var lot2 := Game.make_lot(0)
	Game.add_box(lot2, 50)
	check(Game.boxes.size() == 1, "won box stored")
	var res := Game.open_box(int(Game.boxes[0]["uid"]))
	check(Game.boxes.is_empty(), "box removed after opening")
	check((res["items"] as Array).size() >= int(lot2["count"]), "all items revealed")
	check(Game.items.size() == mini(Game.capacity(), (res["items"] as Array).size()), "items on shelves")
	while Game.items.size() < Game.capacity():
		Game.items.append({"uid": Game._uid(), "id": "toy_car", "cond": 0.5, "paid": 1, "fixed": 0})
	var m0 := Game.money
	Game.add_box(Game.make_lot(1), 10)
	var res2 := Game.open_box(int(Game.boxes[0]["uid"]))
	var pawned := 0
	for it in res2["items"]:
		pawned += int(it["pawned"])
	check(pawned > 0 and Game.money == m0 + pawned, "overflow items go to the pawn shop")
	check(Game.items.size() == Game.capacity(), "storage never exceeds capacity")

	# repair
	var it0: Dictionary = Game.items[0]
	it0["cond"] = 0.3
	var uid := int(it0["uid"])
	check(Game.can_repair(it0), "broken item can be repaired")
	var cost := Game.repair_cost(it0)
	Game.money = 1000
	check(Game.pay_repair(uid) and Game.money == 1000 - cost, "repair is paid")
	Game.finish_repair(uid, 0.99, 3)
	check(float(Game.get_item(uid)["cond"]) <= Game.repair_cap() + 0.001, "repair limited by the workbench")
	check(float(Game.get_item(uid)["cond"]) > 0.3, "repair raises condition")

	# sale
	var before := Game.money
	var xp_before := Game.xp + Game.level * 100000
	Game.sell_item(uid, 123)
	check(Game.money == before + 123, "sale adds money")
	check(Game.item_index(uid) == -1, "sold item removed")
	check(Game.xp + Game.level * 100000 > xp_before, "sale gives reputation")
	var uid2 := int(Game.items[0]["uid"])
	var pp := Game.pawn_price(Game.items[0])
	var b2 := Game.money
	check(Game.pawn_item(uid2) == pp and Game.money == b2 + pp, "pawn shop pays instantly")

	# buyers per day
	var uid3 := int(Game.items[0]["uid"])
	var left := Game.buyers_left(uid3)
	Game.use_buyer(uid3)
	check(Game.buyers_left(uid3) == left - 1, "buyers per item are counted")

	# upgrades
	Game.money = 1000000
	var c1 := Game.upgrade_cost("shelves")
	check(Game.buy_upgrade("shelves"), "upgrade bought")
	check(Game.capacity() == 14, "shelves raise capacity")
	check(Game.upgrade_cost("shelves") > c1, "upgrade costs grow")
	for i in range(10):
		Game.buy_upgrade("truck")
	check(Game.upgrade_level("truck") == 3, "upgrade stops at max")
	check(Game.lots_per_auction() == 7, "truck adds lots")

	# levels
	var lv := Game.level
	Game.add_xp(Game.xp_needed(Game.level) * 3)
	check(Game.level > lv, "reputation levels up")

	# days and events
	var d0 := Game.day
	Game.end_day()
	check(Game.day == d0 + 1, "day advances")
	check(Game.trends.size() == 3, "daily demand rolled")
	for id in Data.EVENTS.keys():
		Game.apply_event(str(id))
		check(Game.event.is_empty() or str(Game.event["id"]) == str(id), "event " + str(id))
	Game.apply_event("stranger")
	if not Game.event.is_empty():
		var n_items := Game.items.size()
		check(Game.accept_stranger() and Game.items.size() == n_items - 1, "stranger buys the item")

	# never stuck without money
	var keep_items := Game.items.duplicate(true)
	Game.items = []
	Game.boxes = []
	Game.money = 3
	Game.end_day()
	check(Game.money >= 100 and str(Game.event.get("id", "")) == "lou_help", "Uncle Lou helps a broke player")
	Game.items = keep_items

	# goals
	Game.stats["boxes"] = 1
	var g: Dictionary = Data.goal("first_box")
	if not Game.goals_done.has("first_box"):
		check(Game.goal_ready(g), "goal becomes ready")
		check(Game.claim_goal("first_box") == int(g["reward"]), "goal reward")
		check(Game.claim_goal("first_box") == 0, "goal reward only once")

	# saving
	Game.money = 4321
	var n := Game.items.size()
	Game.save_now()
	Game.reset_state()
	check(Game.money == Game.START_MONEY, "reset clears money")
	check(Game.load_game(), "save file loads")
	check(Game.money == 4321 and Game.items.size() == n, "save round trip")
	check(Game.level > 1 and Game.upgrade_level("truck") == 3, "progress survives saving")

	_economy()
	_finish("SELFTEST")


## A bot plays 40 days with simple rules; checks nothing crashes and money/reputation grow.
func _economy() -> void:
	Game.reset_state()
	var rivals_won := 0
	for day in range(40):
		var tier := 0
		for t in range(Data.AUCTIONS.size() - 1, -1, -1):
			var a: Dictionary = Data.AUCTIONS[t]
			if Game.auction_unlocked(t) and Game.money >= Game.auction_fee(t) + int(a["range"][0]) * 2:
				tier = t
				break
		Game.spend(Game.auction_fee(tier))
		for i in range(Game.lots_per_auction()):
			var lot := Game.make_lot(tier)
			var center := (float(lot["low"]) + float(lot["high"])) * 0.5
			var mine := minf(float(Game.money), center)
			var top := 0.0
			for r in Game.pick_rivals(tier):
				var d: Dictionary = Data.RIVALS[r]
				top = maxf(top, float(lot["value"]) * randf_range(0.8, 1.15) * randf_range(float(d["mult"][0]), float(d["mult"][1]))
					* float(Data.auction(tier)["rival_k"]))
			if mine >= float(lot["start"]) and mine > top:
				var price := maxi(int(lot["start"]), mini(Game.money, roundi(top * 1.04)))
				if Game.spend(price):
					Game.add_box(lot, price)
			else:
				rivals_won += 1
		while not Game.boxes.is_empty():
			Game.open_box(int(Game.boxes[0]["uid"]))
		for it in Game.items.duplicate():
			var uid := int(it["uid"])
			if Game.can_repair(it) and Game.pay_repair(uid):
				Game.finish_repair(uid, float(it["cond"]) + 0.45, 1)
		for it in Game.items.duplicate():
			Game.sell_item(int(it["uid"]), roundi(Game.market_value(it) * randf_range(0.95, 1.2) * Game.buyer_mult()))
		for u in ["bench", "shelves", "scanner", "truck", "showroom", "charm"]:
			if Game.can_upgrade(u) and Game.money > Game.upgrade_cost(u) * 2:
				Game.buy_upgrade(u)
		Game.end_day()
	print("economy bot after 40 days: money=%d level=%d upgrades=%d found=%d" % [Game.money, Game.level, Game.garage_level(), Game.found.size()])
	check(Game.level >= 4, "bot reaches reputation 4 in 40 days")
	check(Game.garage_level() >= 4, "bot buys upgrades")
	check(Game.found.size() >= 15, "bot finds many different items")


# ------------------------------------------------------------------ user interface
func _smoke() -> void:
	Game.reset_state()
	Game.tutorial_done = true
	Game.money = 20000
	for id in ["garage", "auctions", "storage", "upgrades", "collection"]:
		main.show_screen(id)
		await frames(4)
		check(main.screen_name == id, "screen " + id)
	main.show_screen("collection", {"tab": "goals"})
	await frames(3)
	L.set_lang("en")
	await frames(3)
	L.set_lang("uk")
	await frames(3)
	main.open_overlay("settings")
	await frames(3)
	main.on_back()
	await frames(3)
	check(main.overlay_count() == 0, "back closes settings")

	# tutorial chain
	main.call("_tutorial_step", 0)
	for i in range(5):
		await frames(2)
		var top = main.top_overlay()
		check(top != null, "tutorial page %d" % i)
		if top != null:
			top.call("_press", 0)
	await frames(2)
	check(Game.tutorial_done and main.overlay_count() == 0, "tutorial completes")

	# a full auction, bidding on the first lot and passing the rest
	main.show_screen("auction", {"tier": 1})
	var scr = main.screen
	var guard := 0
	var bid_once := false
	while scr.phase != "summary" and guard < 4000:
		guard += 1
		await get_tree().process_frame
		if scr.phase == "bidding":
			if not bid_once and scr.leader != "you":
				scr.call("_on_bid")
				bid_once = true
			elif scr.leader != "you":
				scr.call("_on_pass")
	check(scr.phase == "summary", "auction reaches the summary")
	scr.call("_finish")
	await frames(4)
	check(main.screen_name == "garage", "back in the garage after the auction")
	while main.overlay_count() > 0:
		main.on_back()
		await frames(2)

	# opening a box
	Game.add_box(Game.make_lot(4), 100)
	var o = main.open_overlay("open_box", {"uid": int(Game.boxes[Game.boxes.size() - 1]["uid"])})
	await frames(5)
	for i in range(3):
		o.tap()
		await frames(3)
	guard = 0
	while o.phase != "summary" and guard < 600:
		guard += 1
		await frames(2)
		o.tap()
	check(o.phase == "summary", "box opening reaches the summary")
	o.call("_close")
	await frames(3)

	# item card, repair mini-game, selling
	check(not Game.items.is_empty(), "items after opening")
	var it: Dictionary = Game.items[0]
	it["cond"] = 0.2
	var uid := int(it["uid"])
	var card = main.open_overlay("item", {"uid": uid})
	await frames(3)
	var rep = main.open_overlay("repair", {"uid": uid})
	await frames(3)
	rep.call("_on_action")
	for i in range(3):
		await frames(17)
		rep.strike_now()
	await frames(2)
	check(rep.phase == "done", "repair finishes after three strikes")
	check(float(Game.get_item(uid)["cond"]) != 0.2, "repair changed the condition")
	rep.call("_close")
	await frames(2)
	var sell = main.open_overlay("sell", {"uid": uid})
	await frames(3)
	sell.ask(sell.max_price * 5)
	await frames(2)
	if sell.phase == "talk":
		sell.call("_accept")
	elif sell.phase == "left" and Game.buyers_left(uid) > 0:
		sell.call("_new_buyer")
		await frames(2)
		sell.call("_accept")
	await frames(3)
	check(Game.item_index(uid) == -1 or sell.phase == "left", "item sold through haggling")
	while main.overlay_count() > 0:
		main.on_back()
		await frames(2)
	check(not is_instance_valid(card) or card.is_queued_for_deletion(), "item card closes after the sale")

	# pawning from the item card
	if not Game.items.is_empty():
		var uid2 := int(Game.items[0]["uid"])
		var c2 = main.open_overlay("item", {"uid": uid2})
		await frames(3)
		c2.call("_do_pawn")
		await frames(3)
		check(Game.item_index(uid2) == -1, "pawned from the card")
		while main.overlay_count() > 0:
			main.on_back()
			await frames(2)

	# upgrades screen purchase
	main.show_screen("upgrades")
	await frames(3)
	var lvl := Game.upgrade_level("scanner")
	main.screen.call("_buy", "scanner", main.screen)
	await frames(3)
	check(Game.upgrade_level("scanner") == lvl + 1, "upgrade bought from the screen")

	# every event popup
	for id in Data.EVENTS.keys():
		Game.apply_event(str(id))
		if Game.event.is_empty():
			continue
		Game.pending_event = true
		main.show_event()
		await frames(2)
		check(main.overlay_count() > 0, "event popup " + str(id))
		while main.overlay_count() > 0:
			main.on_back()
			await frames(2)

	# level-up popup, goals claim, collection info
	Game.add_xp(5000)
	await frames(2)
	while main.overlay_count() > 0:
		main.on_back()
		await frames(2)
	main.show_screen("collection", {"tab": "book"})
	await frames(3)
	main.screen.call("_info", str(Game.found.keys()[0]) if not Game.found.is_empty() else "toy_car")
	await frames(2)
	while main.overlay_count() > 0:
		main.on_back()
		await frames(2)
	main.show_screen("garage")
	await frames(3)
	main.screen.call("show_trends")
	await frames(2)
	main.on_back()
	await frames(2)
	main.on_back()
	await frames(2)
	check(main.overlay_count() == 1, "quit question in the garage")
	main.on_back()
	await frames(2)
	_finish("SMOKE")


# ------------------------------------------------------------------ screenshots (needs a real renderer)
func shot(dir: String, shot_name: String) -> void:
	await frames(40)
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(shot_name + ".png"))
	print("shot saved: ", shot_name, " ", img.get_size())


func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.reset_state()
	Game.money = 1840
	Game.day = 6
	Game.level = 4
	Game.upgrades["shelves"] = 2
	Game.upgrades["bench"] = 3
	Game.upgrades["showroom"] = 2
	Game.upgrades["truck"] = 1
	Game.upgrades["charm"] = 1
	Game.upgrades["scanner"] = 2
	for id in ["toy_car", "pocket_watch", "vinyl_record", "gold_ring", "tin_robot", "typewriter", "desk_lamp", "skateboard"]:
		Game.items.append({"uid": Game._uid(), "id": id, "cond": randf_range(0.25, 0.9), "paid": 20, "fixed": 0})
		Game.found[id] = 0
	Game.add_box(Game.make_lot(1), 60)
	Game.add_box(Game.make_lot(2), 140)
	Game.apply_event("collector")
	Game.tutorial_done = true
	Game.money_changed.emit(Game.money)
	L.set_lang("uk")
	main.show_screen("garage")
	main.call("_tutorial_step", 1)
	await shot(dir, "00_tutorial")
	main.close_overlay(main.top_overlay())
	await shot(dir, "01_garage")
	main.show_screen("auction", {"tier": 2})
	var scr = main.screen
	var guard := 0
	while scr.phase != "bidding" and guard < 300:
		guard += 1
		await get_tree().process_frame
	scr.call("_on_bid")
	await frames(50)
	await shot(dir, "02_auction")
	main.show_screen("storage")
	await shot(dir, "03_storage")
	var lot := Game.make_lot(4)
	Game.add_box(lot, 900)
	var o = main.open_overlay("open_box", {"uid": int(Game.boxes[Game.boxes.size() - 1]["uid"])})
	await frames(10)
	for i in range(3):
		o.tap()
		await frames(8)
	await frames(30)
	await shot(dir, "04_open_box")
	main.close_overlay(o)
	await frames(2)
	var uid := int(Game.items[3]["uid"])
	Game.items[3]["cond"] = 0.3
	main.open_overlay("item", {"uid": uid})
	await shot(dir, "05_item")
	var rep = main.open_overlay("repair", {"uid": uid})
	await frames(5)
	rep.call("_on_action")
	await frames(20)
	rep.strike_now()
	await frames(10)
	await shot(dir, "06_repair")
	main.close_overlay(rep)
	await frames(2)
	main.open_overlay("sell", {"uid": uid})
	await shot(dir, "07_sell")
	while main.overlay_count() > 0:
		main.close_overlay(main.top_overlay())
		await frames(2)
	main.show_screen("upgrades")
	await shot(dir, "08_upgrades")
	main.show_screen("collection", {"tab": "book"})
	await shot(dir, "09_collection")
	main.show_screen("auctions")
	await shot(dir, "10_auctions")
	Game.add_xp(Game.xp_needed(Game.level))
	await shot(dir, "11_levelup")
	while main.overlay_count() > 0:
		main.close_overlay(main.top_overlay())
		await frames(2)
	L.set_lang("en")
	main.show_screen("garage")
	await shot(dir, "12_garage_en")
	_finish("SHOTS")
