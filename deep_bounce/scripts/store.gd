extends Node
## Google Play purchases (autoload "Store").
## Rules (Google Play Billing, one-time products):
##  * an item is granted only for a purchase in state PURCHASED whose signature checks out (when the licence key
##    is configured); PENDING shows "waiting" and is checked again when the app returns to the foreground;
##  * handling is idempotent per purchaseToken: the grant and its ledger entry are written in one save, a repeated
##    callback, a double tap or a restart never grants twice;
##  * permanent items are acknowledged after delivery (retried on every start until Google Play confirms, so the
##    3-day window is never missed), support contributions are consumed after they are recorded;
##  * every start and "Restore purchases" re-reads the owned items from Google Play: permanent items come back
##    after a reinstall, a refund confirmed by Google Play removes the item, a network error changes nothing.
## Prices and availability always come from Google Play ProductDetails; the purchase window is opened only after
## fresh details of that product have arrived.

signal changed                                  # connection, prices or a product state changed
signal purchase_result(pid: String, status: String)   # granted, pending, cancelled, error, unavailable, already_owned
signal restore_result(status: String, count: int)     # ok, none, error

const CATALOG := preload("res://scripts/catalog.gd")
const PlayBackend := preload("res://scripts/billing_play.gd")
const FakeBackend := preload("res://scripts/billing_fake.gd")
const PACKAGE := "com.deepbounce.game"
const PURCHASED := 1
const PENDING := 2
const RC_OK := 0
const RC_USER_CANCELED := 1
const RC_SERVICE_UNAVAILABLE := 2
const RC_BILLING_UNAVAILABLE := 3
const RC_ITEM_UNAVAILABLE := 4
const RC_ITEM_ALREADY_OWNED := 7
const RC_NETWORK_ERROR := 12
const RC_SERVICE_DISCONNECTED := -1
const TIMEOUT_MS := 25000

enum Conn { OFF, CONNECTING, READY, UNAVAILABLE, ERROR }

var backend: Node
var conn := Conn.OFF
var details := {}         # pid -> {"price": formatted, "micros", "currency", "t": msec}
var missing := {}         # pid -> true: Google Play did not return this product
var busy := {}            # pid -> {"stage": "offer"|"flow", "since": msec}
var flow_pid := ""
var license_key := ""
var log_lines: PackedStringArray = []
var _restore_wanted := false
var _restore_before := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	cfg.load("res://config/monetization.cfg")
	license_key = String(cfg.get_value("billing", "license_key", ""))
	if OS.get_name() == "Android" and Engine.has_singleton("GodotGooglePlayBilling"):
		use_backend(PlayBackend.new())
	else:
		use_backend(FakeBackend.new())   # desktop and tests: a simulated Google Play
	if license_key == "":
		_log("no Play licence key configured: purchase signatures are not checked on the device")

func use_backend(b: Node) -> void:
	if backend:
		backend.queue_free()
	backend = b
	add_child(b)
	b.connected.connect(_on_connected)
	b.disconnected.connect(_on_disconnected)
	b.connect_error.connect(_on_connect_error)
	b.details_response.connect(_on_details)
	b.purchases_response.connect(_on_purchases)
	b.purchase_updated.connect(_on_purchase_updated)
	b.ack_response.connect(_on_ack)
	b.consume_response.connect(_on_consume)
	conn = Conn.OFF
	details = {}
	missing = {}
	busy = {}
	flow_pid = ""

func _log(s: String) -> void:
	log_lines.append(s)
	if log_lines.size() > 200:
		log_lines.remove_at(0)
	print("[store] ", s)

# ---------------------------------------------------------------- connection

func start() -> void:
	if conn == Conn.CONNECTING or conn == Conn.READY:
		return
	conn = Conn.CONNECTING
	changed.emit()
	backend.start()

func _on_connected() -> void:
	conn = Conn.READY
	_log("connected")
	backend.query_details(PackedStringArray(CATALOG.product_ids()))
	backend.query_purchases()
	changed.emit()

func _on_disconnected() -> void:
	conn = Conn.ERROR
	_log("disconnected")
	_fail_busy("error")
	changed.emit()

func _on_connect_error(code: int, msg: String) -> void:
	conn = Conn.UNAVAILABLE if code == RC_BILLING_UNAVAILABLE else Conn.ERROR
	_log("connect error %d %s" % [code, msg])
	_fail_busy("unavailable" if conn == Conn.UNAVAILABLE else "error")
	if _restore_wanted:
		_restore_wanted = false
		restore_result.emit("error", 0)
	changed.emit()

func is_ready() -> bool:
	return conn == Conn.READY

func price(pid: String) -> String:
	return String(details.get(pid, {}).get("price", ""))

func state(pid: String) -> String:
	## For the UI: "busy", "pending", "missing" or "".
	if busy.has(pid):
		return "busy"
	for tok in G.purchases:
		var e: Dictionary = G.purchases[tok]
		if e.pid == pid and e.state == "pending":
			return "pending"
	if missing.has(pid):
		return "missing"
	return ""

func owned(pid: String) -> bool:
	return G.ent.products.has(pid)

func _process(_dt: float) -> void:
	if busy.is_empty():
		return
	var now := Time.get_ticks_msec()
	for pid in busy.keys():
		if now - int(busy[pid].since) > TIMEOUT_MS:
			_log("timeout waiting for %s" % pid)
			busy.erase(pid)
			if flow_pid == pid:
				flow_pid = ""
			purchase_result.emit(pid, "error")
			changed.emit()

func _fail_busy(status: String) -> void:
	for pid in busy.keys():
		purchase_result.emit(pid, status)
	busy = {}
	flow_pid = ""

func _notification(what: int) -> void:
	# back from the Play window, from another app or from the background: pending purchases may have completed
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if conn == Conn.READY:
			backend.query_purchases()
		elif conn == Conn.ERROR or conn == Conn.OFF:
			start()

# ---------------------------------------------------------------- product details

func refresh_details() -> void:
	if conn == Conn.READY:
		backend.query_details(PackedStringArray(CATALOG.product_ids()))
	else:
		start()

func _on_details(resp: Dictionary) -> void:
	var code := int(resp.get("response_code", -99))
	if code != RC_OK:
		_log("details error %d" % code)
		for pid in busy.keys():
			if busy[pid].stage == "offer":
				busy.erase(pid)
				purchase_result.emit(pid, "error")
		changed.emit()
		return
	var got := {}
	for d in resp.get("product_details", []):
		var pid := String(d.get("product_id", ""))
		var offers = d.get("one_time_purchase_offer_details_list", null)
		var offer: Dictionary = {}
		if offers is Array and not offers.is_empty():
			offer = offers[0]
		elif d.has("one_time_purchase_offer_details") and d.one_time_purchase_offer_details is Dictionary:
			offer = d.one_time_purchase_offer_details
		if offer.is_empty():
			continue
		details[pid] = {"price": String(offer.get("formatted_price", "")), "micros": int(offer.get("price_amount_micros", 0)),
			"currency": String(offer.get("price_currency_code", "")), "t": Time.get_ticks_msec()}
		missing.erase(pid)
		got[pid] = true
	for u in resp.get("unfetched_products", []):
		var pid := String(u.get("product_id", ""))
		missing[pid] = true
		details.erase(pid)
	# a purchase waits for fresh details of its product: open the Google Play window now
	for pid in busy.keys():
		if busy[pid].stage != "offer":
			continue
		if got.has(pid):
			_launch(pid)
		else:
			busy.erase(pid)
			missing[pid] = true
			purchase_result.emit(pid, "unavailable")
	changed.emit()

# ---------------------------------------------------------------- buying

func buy(pid: String) -> bool:
	## Starts a purchase for a product the player tapped. Returns false when it cannot start right now.
	if CATALOG.product(pid).is_empty() or busy.has(pid) or flow_pid != "":
		return false
	if CATALOG.product(pid).type == "permanent" and owned(pid):
		purchase_result.emit(pid, "already_owned")
		return false
	busy[pid] = {"stage": "offer", "since": Time.get_ticks_msec()}
	changed.emit()
	if conn == Conn.READY:
		backend.query_details(PackedStringArray([pid]))   # fresh offer data right before the window
	else:
		start()   # the details query after connecting opens the window for this product
	return true

func _launch(pid: String) -> void:
	busy[pid] = {"stage": "flow", "since": Time.get_ticks_msec()}
	flow_pid = pid
	var r: Dictionary = backend.launch(pid)
	var code := int(r.get("response_code", RC_OK))
	_log("launch %s -> %d" % [pid, code])
	if code == RC_OK:
		return
	busy.erase(pid)
	flow_pid = ""
	if code == RC_ITEM_ALREADY_OWNED:
		purchase_result.emit(pid, "already_owned")
		backend.query_purchases()
	elif code == RC_USER_CANCELED:
		purchase_result.emit(pid, "cancelled")
	elif code == RC_ITEM_UNAVAILABLE:
		missing[pid] = true
		purchase_result.emit(pid, "unavailable")
	else:
		purchase_result.emit(pid, "error")
	changed.emit()

func _on_purchase_updated(resp: Dictionary) -> void:
	var code := int(resp.get("response_code", -99))
	var pid := flow_pid
	flow_pid = ""
	if pid != "":
		busy.erase(pid)
	if code == RC_OK:
		for p in resp.get("purchases", []):
			_handle(p, true)
	elif code == RC_USER_CANCELED:
		if pid != "":
			purchase_result.emit(pid, "cancelled")
	elif code == RC_ITEM_ALREADY_OWNED:
		if pid != "":
			purchase_result.emit(pid, "already_owned")
		backend.query_purchases()
	else:
		_log("purchase update error %d" % code)
		if pid != "":
			purchase_result.emit(pid, "error")
	changed.emit()

# ---------------------------------------------------------------- the ledger

static func verify_signature(original_json: String, signature_b64: String, key_b64: String) -> bool:
	## Google Play signs originalJson with the app's licence key (RSA, SHA-256).
	if key_b64 == "" or signature_b64 == "":
		return false
	var body := ""
	var k := key_b64.strip_edges().replace("\n", "")
	for i in range(0, k.length(), 64):
		body += k.substr(i, 64) + "\n"
	var pem := "-----BEGIN PUBLIC KEY-----\n" + body + "-----END PUBLIC KEY-----\n"
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return false
	var sig := Marshalls.base64_to_raw(signature_b64)
	if sig.is_empty():
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, original_json.sha256_buffer(), sig, key)

func _handle(p: Dictionary, interactive: bool) -> void:
	var token := String(p.get("purchase_token", ""))
	if token == "":
		return
	var pkg := String(p.get("package_name", PACKAGE))
	if pkg != PACKAGE:
		_log("ignored purchase for another package %s" % pkg)
		return
	if license_key != "" and not verify_signature(String(p.get("original_json", "")), String(p.get("signature", "")), license_key):
		_log("signature check FAILED for %s, nothing granted" % token.left(12))
		for pid in p.get("product_ids", []):
			purchase_result.emit(String(pid), "error")
		return
	var st := int(p.get("purchase_state", 0))
	for pid_v in p.get("product_ids", []):
		var pid := String(pid_v)
		var prod: Dictionary = CATALOG.product(pid)
		if prod.is_empty():
			continue
		var entry: Dictionary = G.purchases.get(token, {})
		if st == PENDING:
			if entry.get("state", "") != "granted" and entry.get("state", "") != "pending":
				G.purchases[token] = {"pid": pid, "state": "pending", "acked": false, "consumed": false,
					"t": int(Time.get_unix_time_from_system()), "order": String(p.get("order_id", ""))}
				G.save_game()
			if interactive or entry.get("state", "") != "pending":
				purchase_result.emit(pid, "pending")
			continue
		if st != PURCHASED:
			continue
		if entry.get("state", "") != "granted":
			# grant and ledger entry: one save
			if prod.type == "permanent":
				G.grant_permanent(pid)
			else:
				G.support.count = int(G.support.count) + 1
				G.support.thanks = int(G.support.thanks) + 1
			entry = {"pid": pid, "state": "granted", "acked": bool(p.get("is_acknowledged", false)), "consumed": false,
				"t": int(Time.get_unix_time_from_system()), "order": String(p.get("order_id", ""))}
			G.purchases[token] = entry
			G.save_game()
			G.profile_changed.emit()
			_log("granted %s (%s)" % [pid, token.left(12)])
			purchase_result.emit(pid, "granted")
		# finish the purchase with Google Play
		if prod.type == "permanent":
			if bool(p.get("is_acknowledged", false)):
				if not entry.acked:
					entry.acked = true
					G.save_game()
			elif not entry.acked:
				backend.acknowledge(token)
		elif not entry.consumed:
			backend.consume(token)

func _on_ack(resp: Dictionary) -> void:
	var token := String(resp.get("token", ""))
	if int(resp.get("response_code", -99)) == RC_OK and G.purchases.has(token):
		G.purchases[token].acked = true
		G.save_game()
		_log("acknowledged %s" % token.left(12))
	else:
		_log("acknowledge failed (%d), retried on the next start" % int(resp.get("response_code", -99)))

func _on_consume(resp: Dictionary) -> void:
	var token := String(resp.get("token", ""))
	if int(resp.get("response_code", -99)) == RC_OK and G.purchases.has(token):
		G.purchases[token].consumed = true
		G.save_game()
		_log("consumed %s" % token.left(12))
	else:
		_log("consume failed (%d), retried on the next start" % int(resp.get("response_code", -99)))

# ---------------------------------------------------------------- owned items, restore, refunds

func restore() -> void:
	_restore_wanted = true
	_restore_before = G.ent.products.size()
	if conn == Conn.READY:
		backend.query_purchases()
	else:
		start()   # owned items are read right after connecting

func _on_purchases(resp: Dictionary) -> void:
	var code := int(resp.get("response_code", -99))
	if code != RC_OK:
		# a connection problem is not a confirmed absence: entitlements stay as they are
		_log("query purchases error %d" % code)
		if _restore_wanted:
			_restore_wanted = false
			restore_result.emit("error", 0)
		changed.emit()
		return
	var owned_now := {}
	for p in resp.get("purchases", []):
		if int(p.get("purchase_state", 0)) == PURCHASED:
			for pid in p.get("product_ids", []):
				owned_now[String(pid)] = true
		_handle(p, false)
	# Google Play answered: a permanent item it no longer lists was refunded or revoked
	var revoked := false
	for pid in G.ent.products.duplicate():
		if CATALOG.product(pid).get("type", "") == "permanent" and not owned_now.has(pid):
			G.revoke_permanent(pid)
			for tok in G.purchases:
				if G.purchases[tok].pid == pid and G.purchases[tok].state == "granted":
					G.purchases[tok].state = "revoked"
			_log("revoked %s (no longer owned on Google Play)" % pid)
			revoked = true
	# pending entries Google Play no longer reports were cancelled
	var listed := {}
	for p in resp.get("purchases", []):
		listed[String(p.get("purchase_token", ""))] = true
	for tok in G.purchases.keys():
		if G.purchases[tok].state == "pending" and not listed.has(tok):
			G.purchases[tok].state = "cancelled"
			revoked = true
	if revoked:
		G.save_game()
		G.profile_changed.emit()
	if _restore_wanted:
		_restore_wanted = false
		var n := 0
		for pid in owned_now:
			if CATALOG.product(pid).get("type", "") == "permanent":
				n += 1
		restore_result.emit("ok" if n > 0 else "none", n)
	changed.emit()
