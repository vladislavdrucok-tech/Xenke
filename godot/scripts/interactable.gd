class_name Interactable
extends Area2D
## Something the hero can use. Its CollisionShape2D is the interaction area: the hero must stand inside it.
## The game asks `title()`, `verb()` and `blocked()` every frame, and calls `finish()` once the job is done.

signal used(item: Interactable)

## Shown in the hint strip and above the action button.
@export var title_text := ""
@export var verb_text := "Дія"
## Seconds of work; 0 = instant. Wrench jobs are split into pulses of `pulse` seconds.
@export var work_time := 0.0
@export var pulse := 0.42
## Where the hero stands while working (world x); NAN = wherever he is.
@export var spot_x := NAN
## Golden brackets are drawn around this rectangle (local coordinates).
@export var highlight := Rect2(-16, -40, 32, 40)
## "wrench" (stands, arm pushes), "kneel" or "" (instant).
@export var tool := ""

var highlighted := false:
	set(v):
		if v != highlighted:
			highlighted = v
			queue_redraw()

func title() -> String:
	return title_text

func verb() -> String:
	return verb_text

## Why it cannot be used right now ("" = it can).
func blocked() -> String:
	return ""

## Optional reaction on each push of the wrench (sparks, a turn of a wheel...).
func on_pulse(_n: int) -> void:
	pass

## Progress feedback while the hero works (0..1).
func on_progress(_p: float) -> void:
	pass

func finish() -> void:
	used.emit(self)

func _process(_delta: float) -> void:
	if highlighted:
		queue_redraw()

func _draw() -> void:
	if not highlighted:
		return
	# Gold corner brackets that breathe a little.
	var r := highlight.grow(2.0 + sin(Time.get_ticks_msec() / 160.0))
	var c := Color("#f2c14e")
	var l := 6.0
	for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(p, p + Vector2(d.x * l, 0), c, 1.0)
		draw_line(p, p + Vector2(0, d.y * l), c, 1.0)
