extends Node
## A simulated Google Play for desktop runs and tests. Answers asynchronously like the real library and can be
## told how to behave: billing unavailable, network errors, cancel, pending → approved, failed acknowledge or
## consume, refunds, a "reinstall" (the owned items stay with the fake account).

signal connected
signal disconnected
signal connect_error(code: int, msg: String)
signal details_response(resp: Dictionary)
signal purchases_response(resp: Dictionary)
signal purchase_updated(resp: Dictionary)
signal ack_response(resp: Dictionary)
signal consume_response(resp: Dictionary)

const CATALOG := preload("res://scripts/catalog.gd")

var available := true              # false: BILLING_UNAVAILABLE (3) on connect
var network_ok := true             # false: queries answer SERVICE_UNAVAILABLE (2)
var currency_format := "US$%s"     # how prices are formatted (tests use several locales)
var unlisted := {}                 # product ids Google Play does not return
var next := {}                     # pid -> "approve" | "pending" | "cancel" | "error"
var fail_ack_once := false
var fail_consume_once := false
var account := {}                  # token -> purchase (lives in the "Google account", survives reinstall)
var calls := {"details": 0, "purchases": 0, "launch": 0, "ack": 0, "consume": 0}
var _seq := 0

func _later(f: Callable) -> void:
	get_tree().create_timer(0.05).timeout.connect(f)

func start() -> void:
	_later(func():
		if not available:
			connect_error.emit(3, "Billing unavailable")
		elif not network_ok:
			connect_error.emit(2, "Service unavailable")
		else:
			connected.emit())

func query_details(ids: PackedStringArray) -> void:
	calls.details += 1
	_later(func():
		if not network_ok:
			details_response.emit({"response_code": 2, "debug_message": "offline"})
			return
		var list: Array = []
		var unf: Array = []
		for pid in ids:
			var p: Dictionary = CATALOG.product(pid)
			if p.is_empty() or unlisted.has(pid):
				unf.append({"product_id": pid, "product_type": "inapp", "status_code": 3})
				continue
			list.append({"product_id": pid, "title": pid, "name": pid, "description": "", "product_type": "inapp",
				"one_time_purchase_offer_details_list": [{"formatted_price": currency_format % p.usd,
					"price_amount_micros": int(float(p.usd) * 1000000), "price_currency_code": "USD", "offer_token": "t_" + pid}]})
		details_response.emit({"response_code": 0, "debug_message": "", "product_details": list, "unfetched_products": unf}))

func query_purchases() -> void:
	calls.purchases += 1
	_later(func():
		if not network_ok:
			purchases_response.emit({"response_code": 2, "debug_message": "offline"})
			return
		purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": account.values().duplicate(true)}))

func _make(pid: String, state: int) -> Dictionary:
	_seq += 1
	var token := "tok_%s_%d_%d" % [pid, _seq, randi() % 100000]
	return {"order_id": "GPA.%04d" % _seq, "purchase_token": token, "package_name": "com.deepbounce.game",
		"purchase_state": state, "purchase_time": int(Time.get_unix_time_from_system() * 1000),
		"original_json": JSON.stringify({"productId": pid, "purchaseToken": token}), "is_acknowledged": false,
		"is_auto_renewing": false, "is_suspended": false, "quantity": 1, "signature": "", "product_ids": [pid]}

func launch(pid: String) -> Dictionary:
	calls.launch += 1
	var p: Dictionary = CATALOG.product(pid)
	if p.type == "permanent":
		for t in account:
			if account[t].product_ids.has(pid) and int(account[t].purchase_state) == 1:
				return {"response_code": 7, "debug_message": "already owned"}
	var what: String = next.get(pid, "approve")
	next.erase(pid)
	_later(func(): _deliver(pid, what))
	return {"response_code": 0, "debug_message": ""}

func _deliver(pid: String, what: String) -> void:
	if what == "cancel":
		purchase_updated.emit({"response_code": 1, "debug_message": "user canceled"})
	elif what == "error":
		purchase_updated.emit({"response_code": 6, "debug_message": "error"})
	else:
		var pu := _make(pid, 2 if what == "pending" else 1)
		account[pu.purchase_token] = pu
		purchase_updated.emit({"response_code": 0, "debug_message": "", "purchases": [pu.duplicate(true)]})

func approve_pending() -> void:
	## The payment of a pending purchase went through (e.g. cash at a store).
	for t in account:
		if int(account[t].purchase_state) == 2:
			account[t].purchase_state = 1

func cancel_pending() -> void:
	for t in account.keys():
		if int(account[t].purchase_state) == 2:
			account.erase(t)

func refund(pid: String) -> void:
	for t in account.keys():
		if account[t].product_ids.has(pid):
			account.erase(t)

func acknowledge(token: String) -> void:
	calls.ack += 1
	_later(func():
		if fail_ack_once or not network_ok:
			fail_ack_once = false
			ack_response.emit({"response_code": 6, "debug_message": "fail", "token": token})
			return
		if account.has(token):
			account[token].is_acknowledged = true
		ack_response.emit({"response_code": 0, "debug_message": "", "token": token}))

func consume(token: String) -> void:
	calls.consume += 1
	_later(func():
		if fail_consume_once or not network_ok:
			fail_consume_once = false
			consume_response.emit({"response_code": 6, "debug_message": "fail", "token": token})
			return
		account.erase(token)
		consume_response.emit({"response_code": 0, "debug_message": "", "token": token}))
