extends SceneTree
## Автотести економіки та станів гри.
## Запуск: godot --headless --path last_deal_mobile -s res://tests/test_core.gd

var passed := 0
var failed := 0
var report: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	test_economy_basics()
	test_negotiation_rules()
	test_negotiation_fuzz()
	test_purchase_and_balance()
	test_double_actions()
	test_inspection()
	test_market()
	test_day_cycle()
	test_upgrades()
	test_save_load()
	test_bankruptcy()
	test_bot_simulation()
	print("")
	for r in report:
		print(r)
	print("TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_economy_basics() -> void:
	check(Economy.round5(12) == 10, "round5 12")
	check(Economy.round5(13) == 15, "round5 13")
	check(Economy.round5(1) == 5, "round5 min")
	check(Economy.rent_for_day(1) == 30, "rent day1")
	check(Economy.rent_for_day(2) > Economy.rent_for_day(1), "rent grows")
	check(Economy.rent_for_day(1000) == 200, "rent cap")
	check(Economy.format_money(1234567) == "1 234 567", "format money")
	check(Economy.format_money(-500) == "-500", "format negative")
	check(ItemDB.ITEMS.size() == 15, "15 items")
	for id in ItemDB.ids():
		check(ResourceLoader.exists(ItemDB.icon_path(id)), "icon exists " + id)
		for d in ItemDB.get_def(id)["defects"]:
			check(ItemDB.DEFECTS.has(d), "defect defined " + d)
	check(Economy.instance_value("watch", 1.0, []) == 600, "value new watch")
	check(Economy.instance_value("watch", 1.0, ["fake"]) < 100, "fake watch cheap")
	check(ItemDB.condition_label(0.95) == "Як новий", "cond label")
	check(ItemDB.condition_label(0.1) == "Зношений", "cond label low")


func _make_nego(type_id: String, ask: int, floor_ratio: float) -> Negotiation:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return Negotiation.new(Negotiation.create(type_id, ask, floor_ratio, false, rng), rng)


func test_negotiation_rules() -> void:
	var n := _make_nego("calm", 200, 0.75)
	var r := n.offer(200)
	check(r["result"] == "deal" and r["price"] == 200, "offer == ask -> deal")
	n = _make_nego("calm", 200, 0.75)
	r = n.offer(500)
	check(r["result"] == "deal" and r["price"] == 200, "overpay clamped to ask")
	n = _make_nego("calm", 200, 0.75)
	var p0: int = n.s["patience"]
	r = n.offer(20)
	check(r["result"] == "reject", "very low -> reject")
	check(n.s["patience"] == p0 - 2, "insult costs 2 patience")
	n = _make_nego("impatient", 200, 0.75)
	n.offer(10)
	check(n.s["status"] == "left", "impatient leaves after insult")
	n = _make_nego("calm", 200, 0.75)
	r = n.offer(160)
	check(r["result"] in ["counter", "deal"], "mid offer -> counter/deal")
	if r["result"] == "counter":
		check(r["price"] < 200 and r["price"] >= n.s["floor"], "counter in range")
	n = _make_nego("expert", 300, 0.88)
	r = n.offer(150)
	check(r["result"] == "reject", "expert rejects half")
	n = _make_nego("calm", 200, 0.75)
	n.decline()
	check(n.s["status"] == "declined", "decline")
	check(n.offer(300)["result"] == "closed", "closed after decline")


func test_negotiation_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad := 0
	var deals := 0
	for i in 3000:
		var t: String = CustomerDB.type_ids()[i % 5]
		var ask := Economy.round5(rng.randf_range(20, 1500))
		var fr := rng.randf_range(0.55, 0.9)
		var st := Negotiation.create(t, ask, fr, i % 3 == 0, rng)
		var n := Negotiation.new(st, rng)
		var fl: int = st["floor"]
		var rounds := 0
		while n.is_open() and rounds < 20:
			rounds += 1
			var o := int(rng.randf_range(0.2, 1.1) * ask)
			var r := n.offer(maxi(1, o))
			if r["result"] == "deal":
				deals += 1
				if r["price"] < fl or r["price"] > ask:
					bad += 1
			if int(n.s["ask"]) < fl:
				bad += 1
		check(not n.is_open(), "negotiation ends (patience) %d" % i)
		if n.is_open():
			break
	check(bad == 0, "deal price always within [floor, start ask] (bad=%d)" % bad)
	report.append("Negotiation fuzz: 3000 customers, %d deals" % deals)


func _session(seed_v: int) -> GameSession:
	var s := GameSession.new()
	s.new_game(seed_v)
	return s


func test_purchase_and_balance() -> void:
	var s := _session(1)
	check(s.money == 500, "start 500")
	check(s.next_customer(), "first customer")
	check(not s.next_customer(), "cannot call next while open")
	var ask := s.current_ask()
	if ask <= s.money:
		var before := s.money
		var r := s.buy()
		check(r["result"] == "deal", "buy deal")
		check(s.money == before - ask, "money reduced by ask")
		check(s.inventory.count() == 1, "item in inventory")
		check(int(s.inventory.items[0]["bought_price"]) == ask, "bought price recorded")
	# не можна купити дорожче за баланс
	var s2 := _session(2)
	s2.next_customer()
	s2.money = 3
	var r2 := s2.buy()
	check(r2["result"] == "no_money", "no money -> cannot buy")
	check(s2.money == 3, "money unchanged")
	# пропозиція обмежена балансом -> ніколи не мінус
	var neg := 0
	for seed_v in 200:
		var s3 := _session(1000 + seed_v)
		s3.money = 40 + seed_v
		s3.next_customer()
		var g := 0
		while s3.has_open_customer() and g < 10:
			g += 1
			s3.offer(s3.money + 1000)
		if s3.money < 0:
			neg += 1
	check(neg == 0, "balance never negative after purchase")


func test_double_actions() -> void:
	var s := _session(3)
	s.money = 100000
	s.next_customer()
	var m0 := s.money
	s.buy()
	var m1 := s.money
	var r := s.buy()
	check(r["result"] == "closed", "second buy rejected")
	check(s.money == m1 and m1 < m0, "money changed once")
	check(s.offer(10)["result"] == "closed", "offer after deal rejected")
	var uid: int = s.inventory.items[0]["uid"]
	var sold := s.sell(uid)
	check(not sold.is_empty(), "sell works")
	var m2 := s.money
	check(s.sell(uid).is_empty(), "second sell rejected")
	check(s.money == m2, "money unchanged after double sell")
	check(s.sell(-5).is_empty(), "sell unknown uid")


func test_inspection() -> void:
	var s := _session(4)
	s.upgrades["scanner"] = true
	s.next_customer()
	var r := s.inspect()
	check(not r.is_empty(), "inspect works")
	check(s.inspect().is_empty(), "inspect only once")
	var item: Dictionary = s.current["item"]
	check(s.current["found_defects"].size() == item["defects"].size(), "scanner finds all defects")
	var expected := s.sell_price(item)
	check(absi(int(s.current["est_low"]) - expected) <= 1, "scanner exact estimate")
	# хитрий клієнт знижує ціну, коли спіймали
	var caught_ok := true
	for seed_v in 300:
		var s2 := _session(5000 + seed_v)
		s2.upgrades["scanner"] = true
		s2.next_customer()
		if s2.current["type"] == "cunning" and s2.current["item"]["defects"].size() > 0:
			var a0 := s2.current_ask()
			s2.inspect()
			if s2.has_open_customer() and s2.current_ask() > a0:
				caught_ok = false
	check(caught_ok, "caught cunning never raises price")


func test_market() -> void:
	var s := _session(6)
	var changed_any := false
	var in_bounds := true
	for i in 200:
		var before := s.market.demand.duplicate()
		s.market.advance_day(s.rng)
		for id in ItemDB.ids():
			var d := s.market.get_demand(id)
			if absf(d - float(before[id])) > 0.0001:
				changed_any = true
			if d < Market.MIN_DEMAND - 0.001 or d > Market.MAX_DEMAND + 0.001:
				in_bounds = false
	check(changed_any, "demand changes")
	check(in_bounds, "demand within bounds")
	var avg := 0.0
	for id in ItemDB.ids():
		avg += s.market.get_demand(id)
	avg /= ItemDB.ids().size()
	check(avg > 0.8 and avg < 1.25, "demand mean-reverts (avg %.2f)" % avg)


func test_day_cycle() -> void:
	var s := _session(7)
	check(s.end_day().is_empty(), "cannot end day early")
	while s.next_customer():
		s.decline()
	check(s.day_done(), "day done after all customers")
	var m := s.money
	var sum := s.end_day()
	check(not sum.is_empty(), "end day works")
	check(s.day == 2, "day advanced")
	check(s.money == m - Economy.rent_for_day(1), "rent paid")
	check(sum["customers"] == Economy.BASE_CUSTOMERS, "customers counted")
	check(s.customer_number == 0, "customers reset")
	check(s.end_day().is_empty(), "no double end_day")


func test_upgrades() -> void:
	var s := _session(8)
	check(not s.buy_upgrade("neon"), "neon too expensive at start")
	s.money = 5000
	check(s.buy_upgrade("neon"), "buy neon")
	check(s.money == 5000 - int(Economy.UPGRADES["neon"]["cost"]), "neon cost")
	check(not s.buy_upgrade("neon"), "no double upgrade")
	check(s.customers_today == Economy.BASE_CUSTOMERS + 2, "neon adds customers today")
	check(not s.buy_upgrade("nonexistent"), "unknown upgrade")


func test_save_load() -> void:
	var s := _session(9)
	s.money = 3000
	s.next_customer()
	s.buy()
	s.next_customer()
	s.inspect()
	s.buy_upgrade("scanner")
	var json := JSON.stringify(s.to_dict())
	var s2 := GameSession.new()
	check(s2.from_dict(JSON.parse_string(json)), "load ok")
	check(JSON.stringify(s2.to_dict()) == json, "roundtrip identical")
	# продовження після завантаження детерміноване
	s.decline()
	s2.decline()
	s.next_customer()
	s2.next_customer()
	check(JSON.stringify(s.current) == JSON.stringify(s2.current), "rng continues after load")
	# файл
	SaveSystem.write_json("user://test_save.json", s.to_dict())
	var d := SaveSystem.read_json("user://test_save.json")
	var s3 := GameSession.new()
	check(s3.from_dict(d), "file load ok")
	check(s3.money == s.money and s3.day == s.day, "file data")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	check(not GameSession.new().from_dict({}), "empty save rejected")
	check(not GameSession.new().from_dict({"version": 999}), "wrong version rejected")
	var broken := s.to_dict()
	broken["current"] = {"nego": "oops"}
	broken["inventory"] = [{"id": "unknown"}, 5]
	var s4 := GameSession.new()
	check(s4.from_dict(JSON.parse_string(JSON.stringify(broken))), "broken parts tolerated")
	check(s4.current.is_empty() and s4.inventory.count() == 0, "broken parts dropped")


func test_bankruptcy() -> void:
	var s := _session(10)
	while s.next_customer():
		s.decline()
	s.money = 10
	var sum := s.end_day()
	check(sum["bankrupt"], "bankrupt when cannot pay rent")
	check(s.game_over, "game over flag")
	check(not s.next_customer(), "no customers after game over")
	# примусовий розпродаж рятує
	var s2 := _session(11)
	s2.money = 100000
	s2.next_customer()
	s2.buy()
	while s2.next_customer():
		s2.decline()
	var item: Dictionary = s2.inventory.items[0]
	s2.money = 0
	var half := int(s2.sell_price(item) * 0.5)
	var sum2 := s2.end_day()
	check(sum2["forced"].size() == 1, "forced sale happened")
	check(s2.money == half - Economy.rent_for_day(1), "forced sale at half price")
	check(s2.game_over == (s2.money < 0), "game over only if still negative")


## Простий «розумний» бот: оглядає, рахує ціль, торгується, продає.
func _bot_day(s: GameSession, smart: bool) -> void:
	while s.next_customer():
		if not smart:
			if s.rng.randf() < 0.5 and s.can_afford_ask():
				s.buy()
			else:
				s.decline()
			continue
		s.inspect()
		if not s.has_open_customer():
			continue
		var est := (int(s.current["est_low"]) + int(s.current["est_high"])) / 2.0
		var target := int(est * 0.86)
		var offer := mini(target, int(s.current_ask() * 0.62))
		var g := 0
		while s.has_open_customer() and g < 8:
			g += 1
			if s.current_ask() <= target and s.can_afford_ask():
				s.buy()
				break
			if offer > s.money or offer <= 0:
				s.decline()
				break
			s.offer(offer)
			offer = mini(target, int(offer * 1.12) + 5)
		if s.has_open_customer():
			s.decline()
	# продаж
	for it in s.inventory.items.duplicate():
		var held: int = s.day - int(it["bought_day"])
		if s.market.get_demand(it["id"]) >= 0.97 or held >= 2 or s.money < Economy.rent_for_day(s.day) + 50:
			s.sell(int(it["uid"]))
	for u in Economy.UPGRADE_ORDER:
		if s.money > int(Economy.UPGRADES[u]["cost"]) + 600:
			s.buy_upgrade(u)
	s.end_day()


func test_bot_simulation() -> void:
	var seeds := 40
	for smart in [true, false]:
		var bankrupt := 0
		var money10: Array = []
		var money30: Array = []
		var neg_after_buy := 0
		for i in seeds:
			var s := _session(20000 + i)
			s.money_changed.connect(func(v, d): if d < 0 and v < 0 and not s.day_done(): neg_after_buy += 1)
			for dd in 30:
				if s.game_over:
					break
				_bot_day(s, smart)
				if s.day == 11:
					money10.append(s.money)
			if s.game_over:
				bankrupt += 1
			money30.append(s.money)
		money10.sort()
		money30.sort()
		var label := "smart" if smart else "random"
		var m10: int = money10[money10.size() / 2] if money10.size() > 0 else 0
		report.append("Bot %s: bankrupt %d/%d, median money day10=%d, day30=%d (min %d, max %d)" % [
			label, bankrupt, seeds, m10, money30[seeds / 2], money30[0], money30[-1]])
		check(neg_after_buy == 0, "%s bot: no negative balance from purchases" % label)
		if smart:
			check(bankrupt <= 4, "smart bot rarely bankrupt (%d)" % bankrupt)
			check(m10 > 700, "smart bot grows by day 10 (%d)" % m10)
