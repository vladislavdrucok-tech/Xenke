extends Node
## Purchases, ads and rewards against the simulated Google Play and AdMob backends.
##   godot --headless --path . res://tests/monetization_test.tscn
## The real save file is never touched (G.test_no_save); a "restart" re-reads the profile from its JSON.

const CATALOG := preload("res://scripts/catalog.gd")
const FakeBilling := preload("res://scripts/billing_fake.gd")
const FakeAds := preload("res://scripts/ads_fake.gd")

var fails := 0
var lines: PackedStringArray = []
var results: Array = []      # purchase_result signals: [pid, status]
var restores: Array = []

func ok(cond: bool, name: String, info := "") -> void:
	var s := ("PASS  " if cond else "FAIL  ") + name + ("" if info == "" else "  (" + info + ")")
	print(s)
	lines.append(s)
	if not cond:
		fails += 1

func wait(t := 0.3) -> void:
	await get_tree().create_timer(t).timeout

func fresh_profile() -> void:
	G.test_no_save = true
	G.apply_data(G.migrate({"v": 4, "settings": {"lang": "en"}, "meta": {"crystals": 0}, "cos": {}, "ent": {}, "purchases": {},
		"rewards": {}, "ads": {}, "levels": {}, "support": {}, "run": {}, "result": {}}))

func restart_profile() -> void:
	## Process restart: the profile is rebuilt from its saved JSON.
	var data := JSON.parse_string(JSON.stringify({"v": 4, "settings": G.settings, "meta": G.meta, "cos": G.cos, "ent": G.ent,
		"purchases": G.purchases, "rewards": G.rewards, "ads": G.ads, "levels": G.levels, "support": G.support, "run": G.run,
		"result": G.result}))
	G.apply_data(data)

func _ready() -> void:
	Store.purchase_result.connect(func(pid, st): results.append([pid, st]))
	Store.restore_result.connect(func(st, n): restores.append([st, n]))
	await billing_tests()
	await ads_tests()
	await reward_tests()
	print("MONETIZATION " + ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	var f := FileAccess.open("user://monetization_test.log", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
	get_tree().quit(1 if fails > 0 else 0)

func new_store(fake: Node = null) -> Node:
	var b: Node = fake if fake else FakeBilling.new()
	Store.use_backend(b)
	Store.license_key = ""
	results.clear()
	restores.clear()
	return b

func last_status(pid: String) -> String:
	for i in range(results.size() - 1, -1, -1):
		if results[i][0] == pid:
			return results[i][1]
	return ""

# ---------------------------------------------------------------- billing

func billing_tests() -> void:
	fresh_profile()
	var fake: Node = new_store()
	Store.start()
	await wait()
	ok(Store.is_ready() and Store.price("db_no_ads") == "US$3.99", "connect and read prices from ProductDetails", Store.price("db_no_ads"))
	# unavailable product
	fake.unlisted["db_ball_frost"] = true
	Store.refresh_details()
	await wait()
	ok(Store.state("db_ball_frost") == "missing" and Store.price("db_ball_frost") == "", "a product Google Play does not return is shown as unavailable")
	ok(not Store.buy("db_ball_frost") or true, "buying an unavailable product")
	await wait()
	ok(last_status("db_ball_frost") == "unavailable" and not G.owns("ball", "frost"), "it reports 'unavailable' and grants nothing", last_status("db_ball_frost"))
	fake.unlisted.clear()
	Store.refresh_details()
	await wait()
	# a permanent skin, with a double tap
	var d0: int = fake.calls.details
	var started := Store.buy("db_ball_amber")
	var second := Store.buy("db_ball_amber")
	await wait(0.4)
	ok(started and not second and fake.calls.launch == 1, "double tap opens one Google Play window", "launches %d" % fake.calls.launch)
	ok(fake.calls.details > d0, "fresh product details are requested before the purchase window")
	await wait(0.3)
	ok(G.owns("ball", "amber") and last_status("db_ball_amber") == "granted", "PURCHASED grants the ball")
	var tok := ""
	for t in G.purchases:
		if G.purchases[t].pid == "db_ball_amber":
			tok = t
	ok(tok != "" and G.purchases[tok].acked and fake.account[tok].is_acknowledged, "permanent purchase acknowledged after delivery")
	# the same purchase reported again (repeated callback, restart): no second grant
	var n_before: int = G.cos.balls.size()
	Store._handle(fake.account[tok].duplicate(true), true)
	Store._handle(fake.account[tok].duplicate(true), false)
	ok(G.cos.balls.size() == n_before and fake.calls.ack == 1, "repeated events for one purchaseToken change nothing", "acks %d" % fake.calls.ack)
	# buying it again: already owned
	Store.buy("db_ball_amber")
	await wait()
	ok(last_status("db_ball_amber") == "already_owned", "buying an owned item says it is already owned")
	# cancel
	fake.next["db_cannon_bronze"] = "cancel"
	Store.buy("db_cannon_bronze")
	await wait(0.5)
	ok(last_status("db_cannon_bronze") == "cancelled" and not G.owns("cannon", "bronze") and Store.state("db_cannon_bronze") == "", "cancelled in the Google Play window: nothing granted, button free again")
	# error
	fake.next["db_cannon_bronze"] = "error"
	Store.buy("db_cannon_bronze")
	await wait(0.5)
	ok(last_status("db_cannon_bronze") == "error" and not G.owns("cannon", "bronze"), "an error in the purchase flow grants nothing")
	# pending, then completed while the app was in the background
	fake.next["db_cannon_obsidian"] = "pending"
	Store.buy("db_cannon_obsidian")
	await wait(0.5)
	ok(last_status("db_cannon_obsidian") == "pending" and Store.state("db_cannon_obsidian") == "pending" and not G.owns("cannon", "obsidian"), "PENDING shows waiting and grants nothing")
	fake.approve_pending()
	Store._notification(NOTIFICATION_APPLICATION_RESUMED)
	await wait(0.4)
	ok(G.owns("cannon", "obsidian") and Store.state("db_cannon_obsidian") == "", "the pending purchase is granted when the app comes back after payment")
	# pending that gets cancelled
	fake.next["db_cannon_bronze"] = "pending"
	Store.buy("db_cannon_bronze")
	await wait(0.4)
	fake.cancel_pending()
	Store._notification(NOTIFICATION_APPLICATION_RESUMED)
	await wait(0.4)
	ok(not G.owns("cannon", "bronze") and Store.state("db_cannon_bronze") == "", "a pending purchase cancelled in Google Play leaves nothing and frees the button")
	# interrupted acknowledgement: retried on the next start
	fake.fail_ack_once = true
	Store.buy("db_cannon_crystal")
	await wait(0.6)
	var tok2 := ""
	for t in G.purchases:
		if G.purchases[t].pid == "db_cannon_crystal":
			tok2 = t
	ok(G.owns("cannon", "crystal_engine") and tok2 != "" and not G.purchases[tok2].acked, "acknowledge failed: the item is delivered, the acknowledgement stays open")
	restart_profile()
	Store.conn = Store.Conn.OFF
	Store.start()
	await wait(0.6)
	ok(G.purchases[tok2].acked and fake.account[tok2].is_acknowledged, "the open acknowledgement is completed on the next start")
	# two support contributions of the same amount; one consume fails once
	var support0: int = G.support.count
	Store.buy("db_support_small")
	await wait(0.5)
	fake.fail_consume_once = true
	Store.buy("db_support_small")
	await wait(0.5)
	ok(int(G.support.count) == support0 + 2, "two contributions of the same amount are both recorded", "count %d" % G.support.count)
	var open := 0
	for t in fake.account:
		if fake.account[t].product_ids.has("db_support_small"):
			open += 1
	ok(open == 1, "the contribution whose consume failed is still open in Google Play", "open %d" % open)
	Store.restore()
	await wait(0.6)
	open = 0
	for t in fake.account:
		if fake.account[t].product_ids.has("db_support_small"):
			open += 1
	ok(open == 0 and int(G.support.count) == support0 + 2, "it is consumed on the next query without being recorded twice")
	# Ad-Free
	Store.buy("db_no_ads")
	await wait(0.6)
	ok(G.is_ad_free(), "Ad-Free purchase sets the entitlement")
	# reinstall: empty profile, same Google account
	var owned_before: Array = G.ent.products.duplicate()
	fresh_profile()
	ok(not G.is_ad_free() and not G.owns("ball", "amber"), "a reinstall starts with an empty profile")
	Store.conn = Store.Conn.OFF
	restores.clear()
	Store.restore()
	await wait(0.8)
	var all_back := true
	for pid in owned_before:
		all_back = all_back and G.ent.products.has(pid)
	ok(all_back and G.is_ad_free() and G.owns("ball", "amber") and G.owns("cannon", "obsidian") and G.owns("cannon", "crystal_engine"),
		"Restore Purchases brings back every permanent item for the same Google account", str(G.ent.products))
	ok(not restores.is_empty() and restores[-1][0] == "ok", "restore reports success", str(restores))
	ok(int(G.support.count) == 0, "support contributions are not 'restored' (they were already used)")
	# network error: the local entitlement stays (no confirmed absence)
	fake.network_ok = false
	Store.restore()
	await wait(0.4)
	ok(G.owns("ball", "amber") and G.is_ad_free() and restores[-1][0] == "error", "a network error keeps the local items and is reported as an error")
	fake.network_ok = true
	# refund confirmed by Google Play
	fake.refund("db_ball_amber")
	G.cos.ball = "amber"
	Store.restore()
	await wait(0.5)
	ok(not G.owns("ball", "amber") and G.cos.ball == "classic" and G.owns("cannon", "obsidian"), "a refund confirmed by Google Play removes only that item and resets the selection")
	# billing unavailable on the device
	var f2: Node = new_store()
	f2.available = false
	Store.start()
	await wait(0.3)
	ok(Store.conn == Store.Conn.UNAVAILABLE, "no Google Play billing on the device: shown as unavailable")
	Store.buy("db_ball_frost")
	await wait(0.3)
	ok(last_status("db_ball_frost") == "unavailable" or last_status("db_ball_frost") == "error", "buying then reports the problem instead of hanging", last_status("db_ball_frost"))
	# signature verification with a real RSA key pair
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var pem := key.save_to_string(true)
	var b64 := pem.replace("-----BEGIN PUBLIC KEY-----", "").replace("-----END PUBLIC KEY-----", "").replace("\n", "").strip_edges()
	var js := '{"orderId":"GPA.1","productId":"db_no_ads","purchaseToken":"abc","purchaseState":0}'
	var sig := Marshalls.raw_to_base64(crypto.sign(HashingContext.HASH_SHA256, js.sha256_buffer(), key))
	ok(Store.verify_signature(js, sig, b64) and not Store.verify_signature(js.replace("db_no_ads", "db_ball_obsidian"), sig, b64),
		"purchase signature check: genuine passes, edited JSON fails")
	var f3: Node = new_store()
	Store.license_key = b64
	fresh_profile()
	Store.start()
	await wait(0.3)
	Store.buy("db_ball_obsidian")       # the fake signs nothing: must be rejected with a key configured
	await wait(0.5)
	ok(not G.owns("ball", "obsidian"), "with a licence key, a purchase without a valid signature grants nothing")
	Store.license_key = ""
	new_store()

# ---------------------------------------------------------------- ads

func ads_tests() -> void:
	fresh_profile()
	var fake: Node = FakeAds.new()
	Ads.use_backend(fake)
	Ads.start()
	await wait(0.2)
	ok(Ads.consent_done and Ads.can_request and Ads.privacy_required, "UMP consent result read at start (privacy entry required)")
	Ads.load_ad("revive")
	ok(Ads.status("revive") == "loading", "rewarded loading shows as loading")
	await wait(0.2)
	ok(Ads.status("revive") == "ready", "the button becomes active when the ad is ready")
	var earned: Array = []
	var closed: Array = []
	Ads.reward_earned.connect(func(p, a): earned.append([p, a]))
	Ads.rewarded_closed.connect(func(p, a, e, err): closed.append([p, a, e, err]))
	ok(Ads.show_rewarded("revive", "run-A"), "the player starts the rewarded ad")
	await wait(0.3)
	ok(earned.size() == 1 and G.reward_state("revive", "run-A") == "earned" and closed.size() == 1 and closed[0][2], "the reward is recorded when the SDK reports it, then the ad closes")
	# repeated reward callback
	fake.outcome = "double_cb"
	Ads.load_ad("double")
	await wait(0.2)
	Ads.show_rewarded("double", "run-B")
	await wait(0.3)
	var n_b := 0
	for e in earned:
		if e[1] == "run-B":
			n_b += 1
	ok(n_b == 1, "a repeated reward callback is ignored")
	# closed before the reward
	fake.outcome = "close"
	Ads.load_ad("double")
	await wait(0.2)
	Ads.show_rewarded("double", "run-C")
	await wait(0.3)
	ok(G.reward_state("double", "run-C") == "" and closed[-1][2] == false, "closing the video early gives no reward and returns to the choice")
	# failure to show
	fake.outcome = "fail"
	Ads.load_ad("revive")
	await wait(0.2)
	Ads.show_rewarded("revive", "run-D")
	await wait(0.3)
	ok(closed[-1][3] == "show_failed" and G.reward_state("revive", "run-D") == "", "an ad that fails to show returns control with an error")
	# no network
	fake.outcome = "reward"
	fake.network_ok = false
	Ads.load_ad("revive")
	await wait(0.3)
	ok(Ads.status("revive") == "unavailable" and not Ads.show_rewarded("revive", "run-E"), "no network: the video is unavailable and cannot be started")
	fake.network_ok = true
	# interstitial limits
	G.ads = {"finished_total": 0, "since_runs": 0, "since_secs": 0.0, "shown": 0}
	var due: Array = []
	for i in 3:
		G.ads.finished_total += 1
		G.ads.since_runs += 1
		G.ads.since_secs += 400.0
		due.append(Ads.interstitial_due(false))
	ok(due == [false, false, false], "the first three finished runs are free of interstitials")
	G.ads.finished_total += 1
	G.ads.since_runs += 1
	ok(Ads.interstitial_due(false), "the fourth finished run may show one (3 runs and 180 s since the start)")
	ok(not Ads.interstitial_due(true), "not after a run in which a rewarded ad was watched")
	Ads.load_ad("interstitial")
	await wait(0.2)
	var nexted := [false]
	Ads.show_interstitial_then(false, func(): nexted[0] = true)
	await wait(0.3)
	ok(nexted[0] and int(G.ads.shown) == 1 and int(G.ads.since_runs) == 0 and is_zero_approx(float(G.ads.since_secs)), "after the interstitial the next run starts and the counters reset")
	G.ads.finished_total += 2
	G.ads.since_runs = 2
	G.ads.since_secs = 900.0
	ok(not Ads.interstitial_due(false), "two runs later: not yet (needs three)")
	G.ads.since_runs = 3
	G.ads.since_secs = 120.0
	ok(not Ads.interstitial_due(false), "three runs but only 120 s of play: not yet (both conditions)")
	G.ads.since_secs = 181.0
	ok(Ads.interstitial_due(false), "three runs and 181 s: due")
	var nexted2 := [false]
	Ads.show_interstitial_then(false, func(): nexted2[0] = true)   # nothing loaded: start right away
	ok(nexted2[0], "no interstitial ready: the next run starts immediately")
	# Ad-Free: nothing requested, nothing shown
	fresh_profile()
	G.ent.no_ads = true
	var fake2: Node = FakeAds.new()
	Ads.use_backend(fake2)
	Ads.start()
	Ads.load_ad("revive")
	Ads.load_ad("interstitial")
	G.ads = {"finished_total": 50, "since_runs": 10, "since_secs": 9999.0, "shown": 0}
	await wait(0.3)
	ok(fake2.started == 0 and fake2.loads == 0 and Ads.requests == 0 and not Ads.interstitial_due(false) and Ads.status("revive") == "off",
		"Ad-Free: the SDK is never started, no ad request, no interstitial")
	# Ad-Free bought during a session: loaded ads are dropped
	fresh_profile()
	var fake3: Node = FakeAds.new()
	Ads.use_backend(fake3)
	Ads.start()
	await wait(0.2)
	Ads.load_ad("revive")
	await wait(0.2)
	G.ent.no_ads = true
	Ads.disable()
	ok(not Ads.is_ready("revive") and not Ads.show_rewarded("revive", "x") and Ads.status("revive") == "off", "buying Ad-Free stops ads at once")

# ---------------------------------------------------------------- rewards

func reward_tests() -> void:
	fresh_profile()
	G.meta.crystals = 100
	G.result = {"id": "att-1", "gems": 18, "doubled": false}
	ok(G.mark_reward_earned("double", "att-1", 18), "double crystals: reward recorded")
	ok(not G.mark_reward_earned("double", "att-1", 18), "recording it again is refused")
	restart_profile()      # killed between the reward and its payment
	ok(G.reward_state("double", "att-1") == "earned", "after a restart the earned-but-unpaid reward is still there")
	var paid := G.apply_double("att-1")
	var paid2 := G.apply_double("att-1")
	ok(paid == 18 and paid2 == 0 and G.meta.crystals == 118 and G.result.doubled, "it pays 18 more exactly once (100 → 118)", "paid %d then %d" % [paid, paid2])
	restart_profile()
	ok(G.apply_double("att-1") == 0 and G.meta.crystals == 118, "after another restart it is not paid again")
	ok(G.apply_double("att-2") == 0, "an attempt without a recorded reward pays nothing")
