class_name Board
extends Node2D
## Draws the four stacks and the five-slot tray and animates the moves.
## The logical GameState is always updated first and at once; the board only catches up visually.
## So a tap during an animation is applied to the state the player is already looking at
## (the stack's next tile is shown as its top immediately), and two fingers or a fast double tap
## simply make two moves, each through the same rule.

signal column_tapped(index: int)
signal landed(result: Dictionary)

const FLY := 0.22
const VANISH := 0.3
const GAP := 7.0

var gs: GameState
var interactive := true
var stacks_rect := Rect2(20, 140, 680, 760)
var tray_rect := Rect2(20, 980, 680, 150)
var col_rects: Array = []
var tile_size := Vector2(140, 110)
var tile_pitch := 117.0
var tray_tile := Vector2(104, 104)
var shelf_y := 900.0
var stack_nodes: Array = []
var tray_nodes: Array = []
var ghosts: Array = []
var slot_glow: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
var tray_state := 0           # 0 calm, 1 one slot left, 2 full (lost)
var nope_col := -1
var nope_t := 0.0
var _time := 0.0
var _tiles: Node2D
var _fx: Node2D
var _st := {}


func _ready() -> void:
	_tiles = Node2D.new()
	_tiles.name = "Tiles"
	add_child(_tiles)
	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.z_index = 20
	add_child(_fx)
	_make_styles()


func _make_styles() -> void:
	_st["well"] = UiKit.box(Color(UiKit.WELL, 0.62), 26)
	_st["plate"] = UiKit.box(UiKit.WOOD, 8, 0, Color.TRANSPARENT, 4, Vector2(0, 3))
	_st["slot"] = UiKit.box(UiKit.SLOT, 20, 0)
	_st["slot_in"] = UiKit.box(Color(0.55, 0.38, 0.2, 0.12), 20)
	_st["slot_glow"] = UiKit.box(Color("fff2a8"), 20, 4, UiKit.GOLD)
	for k in ["calm", "warn", "lost"]:
		var c: Color = {"calm": UiKit.WOOD, "warn": UiKit.WARN, "lost": UiKit.DANGER}[k]
		_st["tray_" + k] = UiKit.box(UiKit.WOOD_LIGHT, 32, 5, c, 10, Vector2(0, 6))


# ------------------------------------------------------------------ layout

func set_layout(p_stacks: Rect2, p_tray: Rect2) -> void:
	stacks_rect = p_stacks
	tray_rect = p_tray
	_compute()
	if gs != null:
		rebuild()
	queue_redraw()


func _compute() -> void:
	var n := Rules.STACKS
	var col_w := stacks_rect.size.x / n
	var max_h := 3
	if gs != null:
		for s in gs.layout:
			max_h = maxi(max_h, s.size())
	shelf_y = stacks_rect.end.y - 16
	var avail := shelf_y - stacks_rect.position.y - 10
	tile_pitch = clampf(avail / max_h, 46.0, 126.0)
	var tw := minf(col_w - 20, 150.0)
	tile_size = Vector2(tw, tile_pitch - GAP)
	col_rects = []
	for i in n:
		col_rects.append(Rect2(stacks_rect.position.x + i * col_w, stacks_rect.position.y, col_w, stacks_rect.size.y + 6))
	var s := slot_rect(0)
	var t := minf(s.size.x, s.size.y) - 10
	tray_tile = Vector2(t, t)


func slot_rect(s: int) -> Rect2:
	var pad := 16.0
	var gap := 12.0
	var w := (tray_rect.size.x - pad * 2 - gap * 4) / Rules.TRAY_SIZE
	var h := tray_rect.size.y - pad * 2
	return Rect2(tray_rect.position.x + pad + s * (w + gap), tray_rect.position.y + pad, w, h)


func slot_pos(s: int) -> Vector2:
	return slot_rect(s).get_center()


func stack_pos(i: int, j: int) -> Vector2:
	return Vector2(col_rects[i].get_center().x, shelf_y - (j + 0.5) * tile_pitch)


func top_tile_pos(i: int) -> Vector2:
	if gs == null or gs.heights[i] == 0:
		return Vector2(col_rects[i].get_center().x, shelf_y)
	return stack_pos(i, gs.heights[i] - 1) - Vector2(0, tile_size.y / 2)


# ------------------------------------------------------------------ building

func attach(state: GameState) -> void:
	gs = state
	_compute()
	rebuild()


func _new_tile(t: int) -> TileView:
	var v := TileView.new()
	v.type = t
	_tiles.add_child(v)
	return v


## Throws away every running animation and draws the state exactly as it is.
func rebuild() -> void:
	for c in _tiles.get_children():
		c.queue_free()
		_tiles.remove_child(c)
	for c in _fx.get_children():
		c.queue_free()
	stack_nodes = []
	tray_nodes = [null, null, null, null, null]
	ghosts = [null, null, null, null, null]
	for s in Rules.TRAY_SIZE:
		slot_glow[s] = 0.0
	position = Vector2.ZERO
	if gs == null:
		return
	for i in gs.layout.size():
		var col := []
		for j in gs.heights[i]:
			var v := _new_tile(gs.layout[i][j])
			v.size = tile_size
			v.position = stack_pos(i, j)
			col.append(v)
		stack_nodes.append(col)
		_mark_tops(i, false)
	for s in Rules.TRAY_SIZE:
		if gs.tray[s] >= 0:
			var v := _new_tile(gs.tray[s])
			v.size = tray_tile
			v.position = slot_pos(s)
			tray_nodes[s] = v
	_update_tray_state(false)
	queue_redraw()


func _mark_tops(i: int, pop: bool) -> void:
	var col: Array = stack_nodes[i]
	for j in col.size():
		var v: TileView = col[j]
		var is_top := j == col.size() - 1
		v.top = is_top
		v.dim = not is_top
		if not is_top:
			v.glow = 0.0
	if pop and col.size() > 0:
		var v: TileView = col[col.size() - 1]
		v.scale = Vector2.ONE
		var tw := v.create_tween()
		tw.tween_property(v, "scale", Vector2(1.07, 1.07), 0.09).set_delay(0.05)
		tw.tween_property(v, "scale", Vector2.ONE, 0.12)


func _update_tray_state(animate: bool) -> void:
	var n := gs.tray_count() if gs != null else 0
	var st := 0
	if gs != null and gs.lost:
		st = 2
	elif n == Rules.TRAY_SIZE - 1:
		st = 1
	if st == 1 and tray_state != 1 and animate:
		Sfx.play("warn")
	tray_state = st
	for s in Rules.TRAY_SIZE:
		var v = tray_nodes[s]
		if v != null:
			v.danger = 1.0 if st == 2 else 0.0
	queue_redraw()


# ------------------------------------------------------------------ moves

## Animates a move that GameState.take() has already applied.
func play_move(res: Dictionary) -> void:
	var i: int = res["stack"]
	var s: int = res["slot"]
	if stack_nodes[i].is_empty():
		rebuild()
		return
	var v: TileView = stack_nodes[i].pop_back()
	_drop_ghost(s)
	tray_nodes[s] = v
	v.top = false
	v.dim = false
	v.glow = 0.0
	v.z_index = 10
	_mark_tops(i, true)
	Sfx.play("pick", randf_range(0.95, 1.08))
	var from := v.position
	var to := slot_pos(s)
	var ctrl := Vector2(lerpf(from.x, to.x, 0.25), minf(from.y, to.y) - 30.0)
	var tw := v.create_tween()
	tw.set_parallel(true)
	tw.tween_method(_fly.bind(v, from, ctrl, to), 0.0, 1.0, FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "size", tray_tile, FLY)
	tw.chain().tween_callback(_on_landed.bind(v, res))
	var cleared: Array = res["cleared"]
	for c in cleared:
		var g = tray_nodes[c]
		tray_nodes[c] = null
		if g != null:
			ghosts[c] = g
			_vanish(g, c, FLY)
	if not cleared.is_empty():
		var gt := create_tween()
		gt.tween_interval(FLY + VANISH * 0.6)
		gt.tween_method(_set_glow.bind(cleared), 1.0, 0.0, 0.9)
	_update_tray_state(false)
	if res["lost"]:
		for c in Rules.TRAY_SIZE:
			if tray_nodes[c] != null:
				tray_nodes[c].danger = 0.0


func _fly(t: float, v: TileView, a: Vector2, c: Vector2, b: Vector2) -> void:
	var u := 1.0 - t
	v.position = u * u * a + 2.0 * u * t * c + t * t * b


func _on_landed(v: TileView, res: Dictionary) -> void:
	if is_instance_valid(v):
		v.z_index = 0
	if not res["cleared"].is_empty():
		Sfx.play("match", randf_range(0.98, 1.04))
		Sfx.buzz(25)
	elif res["lost"]:
		Sfx.play("lose")
		Sfx.buzz(160)
		_shake()
		for c in Rules.TRAY_SIZE:
			if tray_nodes[c] != null:
				var tw: Tween = tray_nodes[c].create_tween()
				tw.tween_property(tray_nodes[c], "danger", 1.0, 0.25)
	else:
		Sfx.play("land", randf_range(0.95, 1.05))
		if tray_state == 1 and gs.tray_count() == Rules.TRAY_SIZE - 1:
			Sfx.play("warn")
	landed.emit(res)


func _vanish(g: TileView, slot: int, delay: float) -> void:
	var tw := g.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(g, "scale", Vector2(1.16, 1.16), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_burst.bind(slot, g.type))
	tw.set_parallel(true)
	tw.tween_property(g, "scale", Vector2(0.25, 0.25), VANISH - 0.08).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(g, "modulate:a", 0.0, VANISH - 0.08).set_delay(0.08)
	tw.chain().tween_callback(_ghost_done.bind(g, slot))


func _ghost_done(g: TileView, slot: int) -> void:
	if ghosts[slot] == g:
		ghosts[slot] = null
	if is_instance_valid(g):
		g.queue_free()


## A new tile is heading for a slot whose old tile is still fading out: finish that fade now.
func _drop_ghost(slot: int) -> void:
	var g = ghosts[slot]
	if g != null and is_instance_valid(g):
		g.queue_free()
	ghosts[slot] = null


func _set_glow(v: float, slots: Array) -> void:
	for s in slots:
		slot_glow[s] = v
	queue_redraw()


func _burst(slot: int, t: int) -> void:
	var b := Burst.new()
	b.position = slot_pos(slot)
	b.color = UiKit.TYPE_COLORS[t][0]
	b.radius = tray_tile.x * 0.75
	_fx.add_child(b)


func _shake() -> void:
	var tw := create_tween()
	for k in 6:
		tw.tween_property(self, "position:x", 9.0 * (1 if k % 2 == 0 else -1) * (1.0 - k / 6.0), 0.045)
	tw.tween_property(self, "position:x", 0.0, 0.05)


## Undo: show the restored state at once, then fly the returned tile back from the tray to its stack.
func play_undo(undone: Dictionary) -> void:
	rebuild()
	var i: int = undone.get("stack", -1)
	if i < 0 or stack_nodes[i].is_empty():
		return
	var v: TileView = stack_nodes[i][stack_nodes[i].size() - 1]
	var to := v.position
	v.position = slot_pos(undone.get("slot", 0))
	v.size = tray_tile
	v.z_index = 10
	var tw := v.create_tween()
	tw.set_parallel(true)
	tw.tween_property(v, "position", to, FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "size", tile_size, FLY)
	tw.chain().tween_callback(func(): v.z_index = 0)
	for c in undone.get("cleared", []):
		var r = tray_nodes[c]
		if r != null:
			r.scale = Vector2(0.4, 0.4)
			r.create_tween().tween_property(r, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Jumps every running animation to its end (used when the app is sent to the background).
func finish_animations() -> void:
	rebuild()


func nope(i: int) -> void:
	nope_col = i
	nope_t = 1.0
	Sfx.play("nope")


func celebrate() -> void:
	var c := Confetti.new()
	c.area = Rect2(stacks_rect.position, Vector2(stacks_rect.size.x, tray_rect.end.y - stacks_rect.position.y))
	_fx.add_child(c)


# ------------------------------------------------------------------ input and drawing

func _input(event: InputEvent) -> void:
	if not interactive or not is_visible_in_tree():
		return
	# Touch only (desktop mouse arrives as emulated touch). Emulated mouse events from the same
	# finger are ignored here, so one tap can never count twice.
	if event is InputEventScreenTouch and event.pressed:
		var p := to_local(event.position)
		for i in col_rects.size():
			if (col_rects[i] as Rect2).has_point(p):
				get_viewport().set_input_as_handled()
				column_tapped.emit(i)
				return


func _process(delta: float) -> void:
	_time += delta
	var need := false
	if gs != null and not gs.is_over() and interactive:
		var g := 0.55 + 0.45 * sin(_time * 3.2)
		for col in stack_nodes:
			if not col.is_empty():
				var v: TileView = col[col.size() - 1]
				v.glow = g
	if nope_t > 0.0:
		nope_t = maxf(0.0, nope_t - delta * 4.0)
		need = true
	if tray_state > 0:
		need = true
	for s in slot_glow:
		if s > 0.0:
			need = true
	if need:
		queue_redraw()


func _draw() -> void:
	if col_rects.is_empty():
		return
	for i in col_rects.size():
		var r: Rect2 = col_rects[i]
		var off := 0.0
		if i == nope_col and nope_t > 0.0:
			off = sin(nope_t * 30.0) * 6.0 * nope_t
		var well := Rect2(r.position.x + 7 + off, r.position.y, r.size.x - 14, shelf_y - r.position.y + 10)
		draw_style_box(_st["well"], well)
		var pw := tile_size.x + 18
		draw_style_box(_st["plate"], Rect2(r.get_center().x - pw / 2 + off, shelf_y + 1, pw, 13))
	var key := "tray_calm"
	var tray := tray_rect
	if tray_state == 1:
		key = "tray_warn"
		var a := 0.6 + 0.4 * sin(_time * 5.0)
		(_st[key] as StyleBoxFlat).border_color = UiKit.WOOD.lerp(UiKit.WARN, a)
	elif tray_state == 2:
		key = "tray_lost"
	draw_style_box(_st[key], tray)
	for s in Rules.TRAY_SIZE:
		var sr := slot_rect(s)
		draw_style_box(_st["slot"], sr)
		draw_style_box(_st["slot_in"], Rect2(sr.position, Vector2(sr.size.x, 10)))
		if slot_glow[s] > 0.0:
			var g: StyleBoxFlat = _st["slot_glow"]
			g.bg_color = Color("fff2a8", slot_glow[s])
			g.border_color = Color(UiKit.GOLD, slot_glow[s])
			draw_style_box(g, sr.grow(2))


class Burst extends Node2D:
	var color := Color.WHITE
	var radius := 80.0
	var t := 0.0
	const LIFE := 0.45

	func _process(delta: float) -> void:
		t += delta
		if t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / LIFE, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var a := 1.0 - k
		draw_arc(Vector2.ZERO, radius * (0.35 + 0.65 * e), 0, TAU, 40, Color(color, a * 0.8), 6.0 * (1.0 - k) + 1.0, true)
		for n in 8:
			var ang := n * TAU / 8 + 0.3
			var p := Vector2(cos(ang), sin(ang)) * radius * (0.3 + 0.9 * e)
			draw_circle(p, 6.0 * (1.0 - k) + 1.0, Color(color.lightened(0.2), a))


class Confetti extends Node2D:
	var area := Rect2(0, 0, 720, 1000)
	var parts := []
	var t := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for n in 70:
			var c: Color = UiKit.TYPE_COLORS[n % UiKit.TYPE_COLORS.size()][0]
			parts.append({
				"p": Vector2(rng.randf_range(area.position.x, area.end.x), area.position.y + rng.randf_range(-60, 120)),
				"v": Vector2(rng.randf_range(-90, 90), rng.randf_range(-260, 40)),
				"r": rng.randf_range(0, TAU), "w": rng.randf_range(-7, 7),
				"s": rng.randf_range(9, 16), "c": c,
			})

	func _process(delta: float) -> void:
		t += delta
		for q in parts:
			q["v"].y += 520.0 * delta
			q["v"].x *= 0.99
			q["p"] += q["v"] * delta
			q["r"] += q["w"] * delta
		if t > 2.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(2.4 - t, 0.0, 1.0)
		for q in parts:
			draw_set_transform(q["p"], q["r"])
			draw_rect(Rect2(-q["s"] / 2, -q["s"] / 4, q["s"], q["s"] / 2), Color(q["c"], a))
		draw_set_transform(Vector2.ZERO)
