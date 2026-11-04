class_name ShopView
extends Control
## Піксельна сцена крамниці: фон, клієнт, предмет на стійці, неон, дощ за вікном.
## Арт 180×170 масштабується так, щоб заповнити ширину; низ сцени (стійка) завжди видно,
## верх обрізається на низьких екранах.

const ART_W := 180.0
const ART_H := 170.0
const COUNTER_TOP := 110.0   # y стійки в координатах арту (counter.png 60 px заввишки)
const VIEW_BOTTOM := 150.0   # який рядок арту припадає на низ екрана (низ стійки обрізано)
const NEON_POS := Vector2(98, 32)
const WINDOW := Rect2(8, 18, 74, 62)

var bg_tex: Texture2D = preload("res://assets/art/shop_bg.png")
var counter_tex: Texture2D = preload("res://assets/art/counter.png")
var neon_tex: Texture2D = preload("res://assets/art/neon_sign.png")
var open_tex: Texture2D = preload("res://assets/art/open_sign.png")

var customer_tex: Texture2D
var item_tex: Texture2D
var customer_offset := 0.0      # у пікселях арту, для входу/виходу
var customer_alpha := 0.0
var item_alpha := 0.0
var item_lift := 0.0
var item_scale := 1.0
var shop_closed := false

var _t := 0.0
var _neon_on := 1.0
var _rain: Array = []
var _bob := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 26:
		_rain.append(Vector3(rng.randf() * WINDOW.size.x, rng.randf() * WINDOW.size.y, rng.randf_range(40, 70)))


func _process(delta: float) -> void:
	_t += delta
	# неон іноді мерехтить
	var n := 1.0
	var phase := fmod(_t, 7.3)
	if phase > 6.6 and phase < 6.9:
		n = 0.35 if int(_t * 30.0) % 2 == 0 else 1.0
	_neon_on = n
	for i in _rain.size():
		var r: Vector3 = _rain[i]
		r.y += r.z * delta
		if r.y > WINDOW.size.y:
			r.y -= WINDOW.size.y
		_rain[i] = r
	queue_redraw()


func art_scale() -> float:
	return size.x / ART_W


## Перетворення координат арту в координати контрола (низ арту = низ контрола).
func art_to_local(p: Vector2) -> Vector2:
	var s := art_scale()
	return Vector2(p.x * s, size.y - (VIEW_BOTTOM - p.y) * s)


func _draw() -> void:
	var s := art_scale()
	var origin := art_to_local(Vector2.ZERO)
	if origin.y > 0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, origin.y + 1)), Color("#140c22"))
	draw_texture_rect(bg_tex, Rect2(origin, Vector2(ART_W, ART_H) * s), false)
	# дощ у вікні
	for r in _rain:
		var p := art_to_local(WINDOW.position + Vector2(r.x, r.y))
		var e := p + Vector2(-1, 4) * s * 0.6
		if p.y > 0:
			draw_line(p, e, Color(0.6, 0.75, 1.0, 0.35), maxf(1.0, s * 0.35))
	# мерехтливі вогні у вікні
	for i in 6:
		var k := int(_t * 1.7 + i * 3.1) % 9
		var wp := WINDOW.position + Vector2(6 + i * 11 + k, 38 + (i * 7 + k) % 18)
		var a := 0.5 + 0.5 * sin(_t * 2.0 + i)
		draw_rect(Rect2(art_to_local(wp), Vector2(s, s)), Color(1.0, 0.85, 0.4, a * 0.9))
	# неонова вивіска на стіні над полицями
	var neon_size := neon_tex.get_size() * s
	var neon_pos := art_to_local(NEON_POS)
	draw_texture_rect(neon_tex, Rect2(neon_pos, neon_size), false, Color(1, 1, 1, _neon_on))
	var open_size := open_tex.get_size() * s
	draw_texture_rect(open_tex, Rect2(art_to_local(Vector2(52, 57)), open_size),
		false, Color(1, 1, 1, 0.25) if shop_closed else Color(1, 1, 1, 0.65 + 0.35 * _neon_on))
	# клієнт
	if customer_tex and customer_alpha > 0.0:
		var cs := customer_tex.get_size()
		var bob := sin(_t * 2.2) * 0.6
		var cp := Vector2(90 - cs.x / 2.0 + customer_offset, COUNTER_TOP + 18 - cs.y + bob + _bob)
		draw_texture_rect(customer_tex, Rect2(art_to_local(cp), cs * s), false, Color(1, 1, 1, customer_alpha))
	# стійка
	draw_texture_rect(counter_tex, Rect2(art_to_local(Vector2(0, COUNTER_TOP)), Vector2(ART_W, 60) * s), false)
	# предмет на стійці
	if item_tex and item_alpha > 0.0:
		var isz := Vector2(32, 32) * item_scale
		var ip := Vector2(84 - isz.x / 2.0, COUNTER_TOP + 16 - isz.y - item_lift)
		# тінь
		draw_rect(Rect2(art_to_local(Vector2(ip.x + 4, COUNTER_TOP + 14)), Vector2(isz.x - 8, 2) * s), Color(0, 0, 0, 0.35 * item_alpha))
		draw_texture_rect(item_tex, Rect2(art_to_local(ip), isz * s), false, Color(1, 1, 1, item_alpha))
	if shop_closed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.1, 0.35))


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func show_customer(sprite_idx: int, item_id: String, animate: bool = true) -> void:
	customer_tex = load("res://assets/art/customers/customer_%02d.png" % clampi(sprite_idx, 0, CustomerDB.SPRITE_COUNT - 1))
	item_tex = load(ItemDB.icon_path(item_id))
	_kill_tween()
	if not animate:
		customer_offset = 0.0
		customer_alpha = 1.0
		item_alpha = 1.0
		item_lift = 0.0
		item_scale = 1.0
		return
	customer_offset = 70.0
	customer_alpha = 0.0
	item_alpha = 0.0
	item_lift = 14.0
	item_scale = 0.6
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "customer_offset", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "customer_alpha", 1.0, 0.35)
	_tween.tween_method(func(v): _bob = -absf(sin(v * PI * 3.0)) * 3.0, 0.0, 1.0, 0.55)
	_tween.chain().set_parallel(true)
	_tween.tween_property(self, "item_alpha", 1.0, 0.2)
	_tween.tween_property(self, "item_lift", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "item_scale", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Клієнт іде. took_item — чи забрав гравець предмет (тоді предмет «їде» в касу).
func hide_customer(took_item: bool) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	if took_item:
		_tween.tween_property(self, "item_lift", -20.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "item_alpha", 0.0, 0.35)
	else:
		_tween.tween_property(self, "item_alpha", 0.0, 0.25)
	_tween.tween_property(self, "customer_offset", -80.0, 0.6).set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "customer_alpha", 0.0, 0.5).set_delay(0.25)
	_tween.tween_method(func(v): _bob = -absf(sin(v * PI * 4.0)) * 3.0, 0.0, 1.0, 0.6).set_delay(0.15)


func clear_customer() -> void:
	_kill_tween()
	customer_alpha = 0.0
	item_alpha = 0.0


## Злегка «трусить» клієнта (відмова/образа).
func shake() -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "customer_offset", 2.0 if i % 2 == 0 else -2.0, 0.04)
	tw.tween_property(self, "customer_offset", 0.0, 0.04)


## Позиція предмета на стійці в глобальних координатах (для ефектів).
func item_global_pos() -> Vector2:
	return get_global_transform() * art_to_local(Vector2(84, COUNTER_TOP))
