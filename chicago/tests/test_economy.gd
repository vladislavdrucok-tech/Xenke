extends TestCase

func test_ledger_idempotent_and_bounded() -> void:
	var l := Ledger.new()
	check(l.post("a", 500, "test"), "first post")
	check(not l.post("a", 500, "test"), "duplicate id refused")
	eq(l.balance, 500)
	check(not l.post("b", -600, "test"), "overdraft refused")
	eq(l.balance, 500, "balance unchanged after refusal")
	check(l.post("c", -500, "test"), "exact spend")
	eq(l.balance, 0)
	check(l.is_consistent(), "entries sum to balance")

func test_ledger_random_consistency_and_roundtrip() -> void:
	var l := Ledger.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 3000:
		l.post("t%d" % rng.randi_range(0, 2500), rng.randi_range(-900, 1000), "r")
	check(l.is_consistent(), "random posts consistent")
	var l2 := Ledger.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	eq(l2.balance, l.balance, "roundtrip balance")
	check(l2.is_consistent(), "roundtrip consistent")
	check(not l2.post("t5", 1, "r") or not l.has_tx("t5"), "ids survive roundtrip")

func test_dollars_format() -> void:
	eq(Ledger.dollars(1250), "$12.50")
	eq(Ledger.dollars(-5), "-$0.05")
	eq(Ledger.dollars(0), "$0.00")

func test_repair_job_pays_once_per_id() -> void:
	WorldClock.set_total(9 * 60)
	var start := GameState.ledger.balance
	check(GameState.businesses.record_job("bellini_garage", "d1_1"), "job 1")
	check(not GameState.businesses.record_job("bellini_garage", "d1_1"), "same job id again refused")
	eq(GameState.ledger.balance - start, 350, "paid once")

func test_day_settlement_once_even_after_reload() -> void:
	WorldClock.set_total(9 * 60)
	var b0 := GameState.ledger.balance
	WorldClock.advance(24 * 60)                 # crosses into day 2 -> day 1 settled
	var after := GameState.ledger.balance
	eq(after - b0, 400 - 150, "walk-in minus running cost for day 1")
	var snap := GameState.to_dict()
	GameState.from_dict(JSON.parse_string(JSON.stringify(snap)))
	GameState.businesses.settle_day(1)          # replay: must not pay again
	eq(GameState.ledger.balance, after, "no duplicate payout after reload")

func test_upgrade_requires_debt_quest() -> void:
	GameState.pay(10000, "test:gift", "test")
	check(not GameState.businesses.upgrade("bellini_garage"), "locked before quest")
	GameState.quests.states["ch1_shop_debt"] = {"state": "completed", "obj": {}, "started_min": 0}
	check(GameState.businesses.upgrade("bellini_garage"), "unlocked after quest")
	eq(int(GameState.businesses.st("bellini_garage").level), 1)
	check(not GameState.businesses.upgrade("bellini_garage"), "no level 2")

func test_pay_debt() -> void:
	eq(GameState.total_debt(), 18000, "start debt")
	GameState.pay(20000, "test:gift", "test")
	var paid := GameState.pay_debt("lakeside_parts", 99999, "debt:test")
	eq(paid, 18000)
	eq(GameState.total_debt(), 0)
	eq(GameState.pay_debt("lakeside_parts", 100, "debt:test2"), 0, "nothing left to pay")
