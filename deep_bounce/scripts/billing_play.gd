extends Node
## Store backend on Android: the official GodotGooglePlayBilling plugin 3.3.0 (Google Play Billing Library 9.1).
## Only translates calls and signals; all purchase rules live in store.gd.

signal connected
signal disconnected
signal connect_error(code: int, msg: String)
signal details_response(resp: Dictionary)
signal purchases_response(resp: Dictionary)
signal purchase_updated(resp: Dictionary)
signal ack_response(resp: Dictionary)
signal consume_response(resp: Dictionary)

const BillingClientScript := preload("res://addons/GodotGooglePlayBilling/BillingClient.gd")
var client: Node

func _ready() -> void:
	client = BillingClientScript.new()
	add_child(client)
	client.connected.connect(func(): connected.emit())
	client.disconnected.connect(func(): disconnected.emit())
	client.connect_error.connect(func(code, msg): connect_error.emit(int(code), String(msg)))
	client.query_product_details_response.connect(func(r): details_response.emit(r))
	client.query_purchases_response.connect(func(r): purchases_response.emit(r))
	client.on_purchase_updated.connect(func(r): purchase_updated.emit(r))
	client.acknowledge_purchase_response.connect(func(r): ack_response.emit(r))
	client.consume_purchase_response.connect(func(r): consume_response.emit(r))

func start() -> void:
	client.start_connection()

func query_details(ids: PackedStringArray) -> void:
	client.query_product_details(ids, 0)   # ProductType.INAPP

func query_purchases() -> void:
	client.query_purchases(0)

func launch(pid: String) -> Dictionary:
	return client.purchase(pid)

func acknowledge(token: String) -> void:
	client.acknowledge_purchase(token)

func consume(token: String) -> void:
	client.consume_purchase(token)
