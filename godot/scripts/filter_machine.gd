extends Interactable
## The Station's water filter (art baked from the web version's station-art.mjs).
## Three states drawn from the same canvas so nothing shifts: broken (cracked glass, red alarm),
## unit fitted (amber lamp) and running (water in the glass, green lamp, stream into the bucket).
## Origin = the middle of the machine's base on the ground.

const MS := 1.2            # machine is drawn 1.2x its baked size (taller than the hero)
const P := 3.0             # baked art: 3 px per world unit
var M: Dictionary
var tex := {}
var wheel_turns := 0.0
var _wheel_from := 0.0
var _pulse_t := 0.0
var _drip_t := 0.0

@onready var light: PointLight2D = $Lamp
@onready var stream: CPUParticles2D = $Stream
@onready var sparks: CPUParticles2D = $Sparks

func _ready() -> void:
	M = JSON.parse_string(FileAccess.get_file_as_string("res://data/machine.json"))
	for k in ["machine", "glassBroken", "glassClean", "unit"]:
		tex[k] = load("res://assets/station/%s.png" % k)
	State.changed.connect(queue_redraw)
	light.position = at(M.lamp[0], M.lamp[1])
	stream.position = at(M.spout[0] - 1.5, M.spout[1] + 8)
	_apply_state()

## Machine art coordinates (units of the baked art) -> local position.
func at(mx: float, my: float) -> Vector2:
	return Vector2(-M.w * MS / 2.0 + mx * MS, -(M.h - my) * MS)

func _apply_state() -> void:
	var s := State.filter_state
	stream.emitting = s == 2
	light.color = [Color("#ff4a3a"), Color("#f2c14e"), Color("#6ad04a")][s]
	monitoring = s < 2
	work_time = pulse * (5.0 if s == 0 else 3.0)
	monitorable = s < 2
	if s == 0:
		highlight = Rect2(at(M.unit[0] - 2, M.unit[1] - 2), Vector2(M.unit[2] + 4, M.unit[3] + 4) * MS)
	else:
		highlight = Rect2(at(M.wheel[0] - 6, M.wheel[1] - 6), Vector2(12, 12) * MS)
	queue_redraw()

func title() -> String:
	if State.filter_state == 0:
		return "Зламаний фільтр · встанови вузол" if State.inv.repair > 0 else "Зламаний фільтр · потрібен ремонтний вузол"
	return "Фільтр · кран подачі води"

func verb() -> String:
	return "Полагодити" if State.filter_state == 0 else "Відкрити кран"

func blocked() -> String:
	if State.filter_state == 0 and State.inv.repair == 0:
		return "Бракує ремонтного вузла. Зроби його на верстаку."
	return ""

func on_pulse(n: int) -> void:
	_pulse_t = 0.0
	if State.filter_state == 1:
		_wheel_from = wheel_turns
		wheel_turns += 1.0
	sparks.position = at(M.unit[0] + 5, M.unit[1] + 4) if State.filter_state == 0 else at(M.wheel[0], M.wheel[1])
	sparks.color = Color("#ffe08a") if State.filter_state == 0 else Color("#9fd6e0")
	sparks.restart()

func on_progress(p: float) -> void:
	_progress = p
	queue_redraw()

var _progress := 0.0

func finish() -> void:
	State.filter_state += 1
	State.inv.repair = max(0, State.inv.repair - (1 if State.filter_state == 1 else 0))
	_progress = 0.0
	_apply_state()
	State.changed.emit()
	super.finish()

func _process(delta: float) -> void:
	super._process(delta)
	_pulse_t += delta
	_drip_t += delta
	# The red alarm blinks while the filter is broken.
	if State.filter_state == 0:
		light.energy = 1.1 if fmod(_drip_t, 0.66) < 0.33 else 0.15
	else:
		light.energy = 0.9
	queue_redraw()

func _draw() -> void:
	var k := MS / P
	var s := State.filter_state
	var base := at(0, 0)
	draw_texture_rect(tex.machine, Rect2(base, tex.machine.get_size() * k), false)
	var w: Array = M.window
	var gpos := at(w[0], w[1])
	draw_texture_rect(tex.glassClean if s > 0 else tex.glassBroken, Rect2(gpos, tex.glassClean.get_size() * k), false)
	if s == 2:
		var gw: float = w[2] * MS
		var gh: float = w[3] * MS
		var lvl := gh * (0.55 + 0.08 * sin(Time.get_ticks_msec() / 770.0))
		draw_rect(Rect2(gpos + Vector2(1, gh - lvl), Vector2(gw - 2, lvl - 1)), Color(0.25, 0.66, 0.84, 0.78))
		draw_rect(Rect2(gpos + Vector2(1, gh - lvl), Vector2(gw - 2, 1)), Color("#bfeaf6"))
	# Status lamp and gauge needle.
	var lamp := at(M.lamp[0], M.lamp[1])
	draw_rect(Rect2(lamp - Vector2(2.4, 2.4), Vector2(4.8, 4.8)), light.color if light.energy > 0.5 else Color("#5a2020"))
	var g: Array = M.gauge
	var base_ang: float = [0.86, 1.3, 1.62][s]
	var ang: float = PI * (base_ang + (sin(Time.get_ticks_msec() / 140.0) * 0.03 if s == 2 else 0.0))
	var gc := at(g[0], g[1])
	draw_line(gc, gc + Vector2(cos(ang), sin(ang)) * (g[2] - 1) * MS, Color("#b03a2e"), 1.0)
	# The repair unit slides in with the pushes, then stays.
	if s > 0 or (s == 0 and _progress > 0.0):
		var off := 0.0 if s > 0 else (1.0 - _progress) * 5.0
		draw_texture_rect(tex.unit, Rect2(at(M.unit[0] - off, M.unit[1]), tex.unit.get_size() * k), false)
	# Tap wheel: a quarter turn per push, eased with the arm.
	var f := clampf(_pulse_t / 0.23, 0.0, 1.0)
	var turn := lerpf(_wheel_from, wheel_turns, f * f * (3.0 - 2.0 * f))
	var wc := at(M.wheel[0], M.wheel[1])
	var r: float = M.wheel[2] * MS
	draw_arc(wc, r, 0, TAU, 20, Color("#141414"), 2.6)
	draw_arc(wc, r, 0, TAU, 20, Color("#b03a2e"), 1.4)
	for i in 4:
		var a := turn * PI / 2.0 + i * PI / 2.0
		draw_line(wc, wc + Vector2(cos(a), sin(a)) * r, Color("#8a2a1f"), 1.0)
	draw_rect(Rect2(wc - Vector2(1, 1), Vector2(2, 2)), Color("#d9a441"))
	# Broken: a slow drip from the cracked joint.
	if s == 0:
		var d := at(M.drip[0], M.drip[1])
		for i in 2:
			draw_rect(Rect2(d + Vector2(0, fmod(_drip_t * 22.0 + i * 9.0, 16.0)), Vector2(1, 2)), Color("#7fb8c4"))
	super._draw()
