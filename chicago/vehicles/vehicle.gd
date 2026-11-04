class_name Vehicle
extends CharacterBody2D
## A drivable period car (data/vehicles/vehicles.json). Driving is simulated on the ground plane in grid units
## (heading 0 = +x grid = screen lower-right) and projected to the screen, so the car turns and moves the same in
## every direction. Keyboard: up = throttle, down = brake / reverse, left/right = steer. Touch: the stick points
## where to go (the car steers towards it), its length is the throttle.
## Condition 0..100: hard impacts lower it; under 25 the engine is weak; at 0 it does not start.
## TEMPORARY ART: a projected box with a cabin, wheels and lights.

var instance_id := ""
var def := {}
var heading := 0.0
var speed := 0.0               # tiles/s along the heading (negative = reverse)
var damage := 0                # 0 = new, 100 = wrecked
var fuel := 100
var driver: Node = null
var rain := false
var _shape: ConvexPolygonShape2D
var _shape_heading := 999.0
var _dist_acc := 0.0
signal impact(strength: float)

func setup(id: String, d: Dictionary, state: Dictionary) -> void:
	instance_id = id
	def = d
	name = "Vehicle_" + id
	heading = float(state.get("heading", 0.0))
	damage = clampi(int(state.get("damage", 0)), 0, 100)
	fuel = clampi(int(state.get("fuel", d.get("fuel_max", 100))), 0, int(d.get("fuel_max", 100)))
	var p: Array = state.get("pos", [1.0, 1.0])
	position = Iso.to_screen(Vector2(float(p[0]), float(p[1])))

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("vehicle")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 8
	collision_mask = 1 | 4
	var cs := CollisionShape2D.new()
	_shape = ConvexPolygonShape2D.new()
	cs.shape = _shape
	add_child(cs)
	_update_shape()

func kind() -> String:
	return "vehicle"

func verb() -> String:
	return "HUD_ACT_LEAVE_CAR" if driver else "HUD_ACT_DRIVE"

func condition() -> int:
	return 100 - damage

func grid_pos() -> Vector2:
	return Iso.to_grid(position)

func forward() -> Vector2:
	return Vector2(cos(heading), sin(heading))

## The car's footprint corners in grid space (front-left, front-right, back-right, back-left).
func footprint(at: Vector2 = Vector2.INF, h: float = INF) -> PackedVector2Array:
	var c := grid_pos() if at == Vector2.INF else at
	var hd := heading if h == INF else h
	var f := Vector2(cos(hd), sin(hd)) * float(def.get("length", 1.5)) * 0.5
	var r := Vector2(-sin(hd), cos(hd)) * float(def.get("width", 0.7)) * 0.5
	return PackedVector2Array([c + f - r, c + f + r, c - f + r, c - f - r])

func _update_shape() -> void:
	if absf(heading - _shape_heading) < 0.04:
		return
	_shape_heading = heading
	var pts := PackedVector2Array()
	for p in footprint(Vector2.ZERO, heading):
		pts.append(Iso.to_screen(p))
	_shape.points = pts
	queue_redraw()

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	if driver:
		if InputRouter.is_touch_steering():
			var v := InputRouter.move_vector()
			# Stick direction on screen -> ground direction; steer towards it, throttle by stick length.
			var want := Iso.to_grid(Vector2(v.x, v.y) * 64.0).normalized()
			var diff := wrapf(want.angle() - heading, -PI, PI)
			if absf(diff) > PI * 0.75 and speed < 0.6:
				throttle = -v.length()       # stick pointed behind a slow car: back up
				steer = -signf(diff)
			else:
				throttle = v.length()
				steer = clampf(diff * 2.0, -1.0, 1.0)
		else:
			throttle = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
			steer = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	_drive(throttle, steer, delta)

func _drive(throttle: float, steer: float, delta: float) -> void:
	var grip := float(def.get("rain_grip", 0.7)) if rain else 1.0
	var max_v := float(def.get("max_speed", 5.0)) * (0.5 if condition() < 25 else 1.0)
	if condition() <= 0 or fuel <= 0:
		throttle = 0.0
	if throttle > 0.0:
		if speed < 0.0:
			speed = minf(speed + float(def.get("brake", 6.0)) * grip * delta, 0.0)
		else:
			speed = minf(speed + float(def.get("accel", 2.5)) * throttle * delta, max_v)
	elif throttle < 0.0:
		if speed > 0.0:
			speed = maxf(speed - float(def.get("brake", 6.0)) * grip * -throttle * delta, 0.0)
		else:
			speed = maxf(speed - float(def.get("accel", 2.5)) * 0.6 * -throttle * delta, -float(def.get("reverse_speed", 1.5)))
	else:
		speed = move_toward(speed, 0.0, float(def.get("drag", 0.9)) * delta)
	# Steering needs motion; at speed it is a little less sharp, and less again on a wet road.
	var turn := float(def.get("steer_rate", 2.2)) * steer * clampf(absf(speed) / 1.2, 0.0, 1.0) * (1.0 - 0.35 * clampf(absf(speed) / max_v, 0.0, 1.0)) * grip
	heading = wrapf(heading + turn * signf(speed if speed != 0.0 else 1.0) * delta, -PI, PI)
	_update_shape()
	var v_grid := forward() * speed
	velocity = Iso.to_screen(v_grid)
	var before := position
	var before_speed := absf(speed)
	move_and_slide()
	if get_slide_collision_count() > 0:
		# What the wall took out of the motion is the impact.
		var moved := Iso.to_grid(position - before).length() / maxf(delta, 0.0001)
		var lost := before_speed - moved
		if lost > float(def.get("impact_threshold", 1.6)):
			var dmg := int(lost * float(def.get("damage_per_impact", 9.0)) / 2.0)
			damage = clampi(damage + maxi(dmg, 1), 0, 100)
			impact.emit(lost)
		speed = signf(speed) * minf(absf(speed), moved)
	var dist := Iso.to_grid(position - before).length()
	_dist_acc += dist * float(def.get("fuel_per_tile", 0.1))
	if _dist_acc >= 1.0:
		fuel = maxi(fuel - int(_dist_acc), 0)
		_dist_acc -= floorf(_dist_acc)
	if dist > 0.0001:
		queue_redraw()

func repair_cost() -> int:
	return damage * int(def.get("repair_cents_per_point", 15))

func repair() -> void:
	damage = 0
	queue_redraw()

func to_state(district_id: String) -> Dictionary:
	var g := grid_pos()
	return {"def": def.get("_id", ""), "district": district_id, "pos": [snappedf(g.x, 0.001), snappedf(g.y, 0.001)],
		"heading": snappedf(heading, 0.0001), "damage": damage, "fuel": fuel}

func _draw() -> void:
	var col := Color(String(def.get("color", "#3c4a5a")))
	if damage > 50:
		col = col.darkened(0.25)
	var hpx := float(def.get("height_px", 30))
	var fp := footprint(Vector2.ZERO, heading)
	var base := PackedVector2Array()
	var top := PackedVector2Array()
	for p in fp:
		base.append(Iso.to_screen(p) + Vector2(0, -6))
		top.append(Iso.to_screen(p) + Vector2(0, -6 - hpx))
	# Shadow
	var sh := PackedVector2Array()
	for p in fp:
		sh.append(Iso.to_screen(p * 1.08) + Vector2(3, 2))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
	# Wheels at the four corners
	for p in fp:
		var w := Iso.to_screen(p * 0.82)
		draw_rect(Rect2(w + Vector2(-6, -12), Vector2(12, 12)), Color("#15151a"))
	# Side walls that face the camera (those whose outward normal points down the screen)
	for i in 4:
		var a := base[i]
		var b := base[(i + 1) % 4]
		var n := (Iso.to_screen(fp[(i + 1) % 4]) + Iso.to_screen(fp[i])) * 0.5
		if n.y > -2.0:
			draw_colored_polygon(PackedVector2Array([top[i], top[(i + 1) % 4], b, a]), col.darkened(0.3 if n.x > 0 else 0.15))
	draw_colored_polygon(top, col.lightened(0.08))
	# Cabin: a smaller, raised box in the middle-back of the roof
	var cab := PackedVector2Array()
	for p in footprint(Vector2.ZERO - forward() * 0.12, heading):
		cab.append(Iso.to_screen((p + forward() * 0.12) * 0.62 - forward() * 0.12) + Vector2(0, -6 - hpx - 18))
	draw_colored_polygon(cab, col.darkened(0.1))
	draw_polyline(PackedVector2Array([cab[0], cab[1], cab[2], cab[3], cab[0]]), Color("#9fb2c0", 0.8), 1.5)
	# Headlights on the front edge (lit at night or always slightly)
	var fl := Iso.to_screen(fp[0] * 0.92) + Vector2(0, -6 - hpx * 0.4)
	var fr := Iso.to_screen(fp[1] * 0.92) + Vector2(0, -6 - hpx * 0.4)
	draw_circle(fl, 3.5, Color("#ffe9a8"))
	draw_circle(fr, 3.5, Color("#ffe9a8"))
	if damage >= 75:
		draw_circle(Iso.to_screen(forward() * 0.6) + Vector2(0, -hpx - 30), 10.0, Color(0.3, 0.3, 0.3, 0.5))
