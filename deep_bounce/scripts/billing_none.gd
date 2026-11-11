extends Node
## Store backend for an Android build in which the Google Play Billing plugin is missing: every connection
## attempt answers BILLING_UNAVAILABLE, so the shop shows "Unavailable" and nothing can ever be granted.
## (The simulated Google Play in billing_fake.gd is for desktop runs and tests only, never for Android.)

signal connected
signal disconnected
signal connect_error(code: int, msg: String)
signal details_response(resp: Dictionary)
signal purchases_response(resp: Dictionary)
signal purchase_updated(resp: Dictionary)
signal ack_response(resp: Dictionary)
signal consume_response(resp: Dictionary)

func start() -> void:
	(func(): connect_error.emit(3, "Google Play Billing plugin missing")).call_deferred()

func query_details(_ids: PackedStringArray) -> void:
	(func(): details_response.emit({"response_code": 3, "debug_message": "no billing"})).call_deferred()

func query_purchases() -> void:
	(func(): purchases_response.emit({"response_code": 3, "debug_message": "no billing"})).call_deferred()

func launch(_pid: String) -> Dictionary:
	return {"response_code": 3, "debug_message": "no billing"}

func acknowledge(token: String) -> void:
	(func(): ack_response.emit({"response_code": 3, "debug_message": "no billing", "token": token})).call_deferred()

func consume(token: String) -> void:
	(func(): consume_response.emit({"response_code": 3, "debug_message": "no billing", "token": token})).call_deferred()
