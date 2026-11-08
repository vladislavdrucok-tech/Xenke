extends Node
## Interactive tutorial on 5 floors. Each step waits for the player to do the thing
## it explains; the guide box and pointer show exactly what to tap.

var game: Game
var step := -1
var box: PanelContainer
var text: Label
var hint: Label
var _wait_tap := false
var _guest := {}
var _done := false
var _delivered := 0
var _skip: Button


func _ready() -> void:
	_build_box()
	_next()


func _build_box() -> void:
	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", Art.style("panel_light", 10))
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	box.add_child(vb)
	text = Art.label("", 16)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(text)
	hint = Art.title_label("", 8, Art.GOLD)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint)
	box.gui_input.connect(_on_box_input)
	game.add_child(box)
	_skip = Art.button("ПРОПУСТИТИ", "btn_grey")
	_skip.custom_minimum_size = Vector2(0, 26)
	_skip.pressed.connect(_finish)
	game.add_child(_skip)
	_layout()
	game.resized.connect(_layout)


func _layout() -> void:
	var w := minf(game.size.x - 16.0, 344.0)
	box.custom_minimum_size = Vector2(w, 0)
	box.size = Vector2(w, 0)
	box.position = Vector2((game.size.x - w) / 2.0, Hud.H + 8)
	_skip.position = Vector2(game.size.x - _skip.size.x - 8, game.size.y - FloorPanel.panel_height() - 34)


func _exit_tree() -> void:
	if is_instance_valid(box):
		box.queue_free()
	if is_instance_valid(_skip):
		_skip.queue_free()
	if game and game.panel:
		game.panel.hint_floor = 0
	if game and game.world:
		game.world.highlight_floor = 0
	if game and game.hud:
		game.hud.highlight = ""


func _say(msg: String, wait_tap := false) -> void:
	text.text = msg
	_wait_tap = wait_tap
	hint.text = "ТОРКНИСЬ, ЩОБ ДАЛІ  ▶" if wait_tap else ""
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	box.size = Vector2(box.custom_minimum_size.x, 0)


func _on_box_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and _wait_tap:
		Sfx.play("click")
		_wait_tap = false
		_next()


func allow_press(f: int) -> bool:
	if step == 1:
		return f == 3
	if step == 2:
		return f == 5
	return not _wait_tap


func _next() -> void:
	step += 1
	var sim := game.sim
	game.panel.hint_floor = 0
	game.world.highlight_floor = 0
	game.hud.highlight = ""
	match step:
		0:
			_say("Ласкаво просимо в готель «13»! Ти — нічний ліфтер. Гості чекають на поверхах, а ти возиш їх ліфтом.", true)
		1:
			_guest = sim.spawn("guest", 3, 5, {"patience_mult": 3.0})
			game.world.highlight_floor = 3
			game.panel.hint_floor = 3
			_say("На 3-му поверсі з'явився турист. Натисни кнопку 3 — ліфт поїде по нього.")
		2:
			game.panel.hint_floor = 5
			_say("Гість у кабіні! Число в його бульбашці — поверх, куди йому треба. Натисни 5.")
		3:
			_say("Чудово! За кожну доставку — монети. Чим швидше довезеш, тим більші чайові.", true)
		4:
			_say("Колір бульбашки — терпіння: зелений, жовтий, червоний. Червоний — гість ось-ось піде.", true)
		5:
			game.hud.highlight = "hearts"
			_say("Хто не дочекався, пише скаргу і забирає серце. Немає сердець — зміну провалено.", true)
		6:
			_delivered = 0
			sim.spawn("business", 2, 4, {"patience_mult": 2.5})
			sim.spawn("granny", 4, 1, {"patience_mult": 2.0})
			_say("Тепер сам! Довези обох. Можна натиснути кілька кнопок одразу: ліфт зупиниться на кожній по дорозі. Повторне натискання скасовує зупинку.")
		7:
			_say("Кружечок на кнопці зліва показує, скільки гостей чекає на поверсі. Блакитний справа — скільки пасажирів їде туди.", true)
		8:
			_say("Ти готовий до першої нічної зміни! Зміна триває до 06:00. Удачі!", true)
		9:
			_finish()


func on_event(e: Dictionary) -> void:
	# a guest who gave up is replaced, so a step can always be finished
	if e.t == "complaint" or e.t == "vanish":
		var p := _find_any(e.pid)
		if not p.is_empty():
			var np := game.sim.spawn(p.type, p.origin, p.dest, {"patience_mult": 3.0})
			if step == 1:
				_guest = np
			game.world.float_text(Vector2(200, game.world.feet_y(p.origin) - 30), "ЩЕ ГІСТЬ", Art.CYAN)
	match step:
		1:
			if e.t == "board" and not _guest.is_empty() and e.pid == _guest.id:
				_next()
		2:
			if e.t == "deliver":
				_next()
		6:
			if e.t == "deliver":
				_delivered += 1
				if _delivered >= 2:
					_next()


func _find_any(pid: int) -> Dictionary:
	for p in game.sim.passengers:
		if p.id == pid:
			return p
	return {}


func _finish() -> void:
	if _done:
		return
	_done = true
	Save.data["tutorial_done"] = true
	Save.flush()
	game.start_shift(Save.shift())
