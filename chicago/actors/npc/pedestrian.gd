class_name Pedestrian
extends Node2D
## A generic passer-by (tier C behaviour on screen): walks along sidewalk tiles in straight grid lines, turns at the
## end, pauses near the player. No physics body and no memory: cheap enough for a crowd on a phone.
## Deterministic: its choices come from its own seeded RNG.

const SPEED := 0.9   # tiles/s

var district: District
var rng := RandomNumberGenerator.new()
var g := Vector2.ZERO          # grid position
var dir := Vector2i(1, 0)
var figure: Figure
var player: Node2D
var scared_t := 0.0

func setup(d: District, seed_v: int, start: Vector2i, coat: Color) -> void:
	district = d
	rng.seed = seed_v
	g = Vector2(start) + Vector2(0.5, 0.5)
	position = Iso.to_screen(g)
	figure = Figure.new()
	figure.coat = coat
	figure.hat = coat.darkened(0.55)
	figure.height = 104.0 + rng.randf_range(-6, 6)
	add_child(figure)
	add_to_group("pedestrian")
	_pick_dir()

func _pick_dir() -> void:
	var opts: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _walkable(Vector2i(floori(g.x), floori(g.y)) + d):
			opts.append(d)
	if opts.is_empty():
		dir = Vector2i.ZERO
		return
	# Prefer to keep going; never turn straight back unless it is a dead end.
	if dir in opts and rng.randf() < 0.75:
		return
	var non_back := opts.filter(func(o): return o != -dir)
	var pool: Array = non_back if not non_back.is_empty() else opts
	dir = pool[rng.randi() % pool.size()]

func _walkable(t: Vector2i) -> bool:
	return district.tile(t) == District.T.SIDEWALK

func _process(delta: float) -> void:
	if scared_t > 0.0:
		# Running away from danger (shots): faster, ignores the player.
		scared_t -= delta
	elif player and Player.ground_dist(player.position, position) < 60.0:
		figure.walking = false
		return
	var sp := SPEED * (2.4 if scared_t > 0.0 else 1.0)
	if dir == Vector2i.ZERO:
		_pick_dir()
		figure.walking = false
		return
	var cell := Vector2i(floori(g.x), floori(g.y))
	var centre := Vector2(cell) + Vector2(0.5, 0.5)
	var next := g + Vector2(dir) * sp * delta
	# At a cell centre, decide whether to continue.
	if (next - centre).dot(Vector2(dir)) > 0.0 and (g - centre).dot(Vector2(dir)) <= 0.0:
		if not _walkable(cell + dir) or rng.randf() < 0.12:
			g = centre
			_pick_dir()
			return
	g = next
	position = Iso.to_screen(g)
	figure.walking = true
	figure.set_facing(Iso.facing(Iso.to_screen(Vector2(dir))))

func scare(seconds: float) -> void:
	scared_t = seconds
