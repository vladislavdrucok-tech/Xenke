class_name Hud
extends Control
## Top bar: complaints left (hearts), night clock, coins, streak, pause; event banner.

signal pause_pressed

const H := 36

var sim: ShiftSim
var coins_shown := 0.0
var coin_pulse := 0.0
var heart_shake := 0.0
var t := 0.0
var show_pause := true
var highlight := ""
var task := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if show_pause and Rect2(size.x - 40, 0, 40, H).has_point(e.position):
			pause_pressed.emit()
			accept_event()


func bump_coins() -> void:
	coin_pulse = 0.35


func break_heart() -> void:
	heart_shake = 0.6


func _process(delta: float) -> void:
	t += delta
	var target := float(Save.coins())
	coins_shown = move_toward(coins_shown, target, maxf(1.0, absf(target - coins_shown) * 6.0) * delta)
	coin_pulse = maxf(0.0, coin_pulse - delta)
	heart_shake = maxf(0.0, heart_shake - delta)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	draw_style_box(Art.style("panel"), Rect2(-4, -6, size.x + 8, H + 6))
	var font := Art.title()
	# hearts
	var left := sim.hearts - sim.complaints
	for i in sim.hearts:
		var name := "heart" if i < left else "heart_empty"
		var p := Vector2(6 + i * 15, 10)
		if i == left and heart_shake > 0.0:
			p += Vector2(randf_range(-2, 2), randf_range(-2, 2))
			name = "heart_broken"
		Art.draw_icon(self, name, p)
	if highlight == "hearts":
		draw_rect(Rect2(3, 7, sim.hearts * 15 + 4, 22), Color(1, 0.9, 0.3, 0.5 + 0.4 * sin(t * 8.0)), false, 2.0)
	# clock
	var cx := roundf(size.x / 2.0)
	var frac := clampf(sim.time / maxf(sim.duration, 1.0), 0.0, 1.0)
	var clock := Defs.clock_text(frac) if not sim.tutorial else "22:00"
	var cw := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	Art.draw_icon(self, "clock", Vector2(cx - cw / 2.0 - 20, 6))
	var ccol := Art.WHITE
	if not sim.tutorial and sim.duration - sim.time < 10.0 and int(t * 4.0) % 2 == 0:
		ccol = Art.GOLD_L
	draw_string(font, Vector2(cx - cw / 2.0, 18), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ccol)
	var bw := 76.0
	draw_rect(Rect2(cx - bw / 2.0 - 1, 24, bw + 2, 5), Art.INK)
	draw_rect(Rect2(cx - bw / 2.0, 25, bw, 3), Color("3a2e58"))
	draw_rect(Rect2(cx - bw / 2.0, 25, roundf(bw * frac), 3), Color("ffb36a").lerp(Color("ff7a5a"), frac))
	var label := "ЗМІНА %d" % sim.shift if not sim.tutorial else "НАВЧАННЯ"
	var lw := Art.body().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	if size.x >= 380:
		draw_string(Art.body(), Vector2(cx + bw / 2.0 + 8, 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.DIM)
	# coins
	var right := size.x - (44 if show_pause else 8)
	var ctext := str(int(round(coins_shown)))
	var tw := font.get_string_size(ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var s := 1.0 + coin_pulse
	var cp := Vector2(right - tw, 18)
	draw_string(font, cp, ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Art.GOLD_L if coin_pulse > 0.0 else Art.WHITE)
	Art.draw_icon(self, "coin", Vector2(right - tw - 19, 6 - coin_pulse * 4.0))
	if sim.streak >= 2:
		var st := "x%.2f" % (1.0 + float(mini(sim.streak, 10)) * 0.05)
		var sw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(font, Vector2(right - sw, 30), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ff9a3a"))
	if show_pause:
		Art.draw_icon(self, "pause", Vector2(size.x - 30, 10))
	_draw_task()
	_draw_banner()
	lw = lw


func _task_h() -> float:
	return 0.0 if task.is_empty() else 21.0


func _draw_task() -> void:
	if task.is_empty():
		return
	var font := Art.body()
	var prog := "" if task.kind == "clean" else "  %d/%d" % [mini(task.progress, task.goal), task.goal]
	var text: String = String(task.text) + prog
	if task.done:
		text = "Виконано: " + String(task.text)
	var w := minf(ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 24.0, size.x - 8.0)
	var r := Rect2(4, H + 1, w, 19)
	draw_rect(r, Color(0.06, 0.04, 0.12, 0.9))
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Art.GREEN if task.done else Color("3a2e58"))
	Art.draw_icon(self, "check", r.position + Vector2(3, 1), Color.WHITE if task.done else Color(1, 1, 1, 0.6), 16)
	draw_string(font, r.position + Vector2(21, 14), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 16, Art.GREEN if task.done else Color("d8d0f0"))


func _draw_banner() -> void:
	if sim.ev_id == "":
		return
	var e: Dictionary = Defs.EVENTS[sim.ev_id]
	var good: bool = e["good"]
	var r := Rect2(6, H + 4 + _task_h(), size.x - 12, 36)
	var appear := clampf(sim.ev_t / 0.3, 0.0, 1.0)
	r.position.y -= (1.0 - appear) * 20.0
	draw_style_box(Art.style("banner_good" if good else "banner"), r)
	Art.draw_icon(self, Art.EVENT_ICONS.get(sim.ev_id, "star"), r.position + Vector2(8, 10))
	var font := Art.title()
	draw_string(font, r.position + Vector2(30, 13), String(e["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 8,
		Color("6af0a0") if good else Art.PINK)
	draw_string(Art.body(), r.position + Vector2(30, 28), sim.event_text(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 16, Art.WHITE)
	var left := 1.0 - clampf(sim.ev_t / maxf(sim.ev_dur, 0.1), 0.0, 1.0)
	draw_rect(Rect2(r.position.x + 4, r.end.y - 4, (r.size.x - 8) * left, 2), Color("6af0a0") if good else Art.PINK)
