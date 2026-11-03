class_name Actor
extends Node2D
## A character in the isometric yard. The node's position is the point between the feet: the yard sorts everything
## by that point, so the actor passes in front of a thing whose base is above its feet and behind one below.
##
## TEMPORARY until the walk sheets (docs/ISO_ART_LIST_UK.md, C1-C6) arrive: the one painted 3/4 frame is cut into a
## body and two legs (at the hips, between the legs), and the legs step: one lifts and swings forward while the other
## carries the body, the body rises over the passing leg and leans into the walk, the steps follow the real speed.
## Starting and stopping ease in and out (the yard moves the actor with acceleration). Facing = mirroring.

var rig: Node2D               # mirrored as a whole for facing left/right
var body: Sprite2D
var leg_l: Sprite2D
var leg_r: Sprite2D
var shadow: Sprite2D
var facing_right := true
var art_faces_right := true
var moving := false
var working := 0.0
var phase := 0.0
var vel := Vector2.ZERO        # set by the yard every frame (pixels per second)
var dir := Vector2.ZERO
var tex: Texture2D
var hip := 0.0                 # rows from the top where the legs begin
var split := 0.0               # column between the legs
var _last_step := 0
signal stepped(foot: Vector2)

static var _shadow_tex: Texture2D

static func shadow_tex() -> Texture2D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.5))
		g.set_color(1, Color(0, 0, 0, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_shadow_tex = t
	return _shadow_tex

func _part(region: Rect2, origin: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = region
	# Its own pivot (`origin`, in sheet pixels) sits at the node's position, so it can rotate about the hip.
	s.offset = region.position - origin
	s.position = origin - Vector2(tex.get_width() / 2.0, tex.get_height() - 3)
	rig.add_child(s)
	return s

## Real walking frames (the owner's sheets, S3...): all on one canvas with the feet at the bottom centre.
var walk: Array[Texture2D] = []
var idle_frame := 0
var dist := 0.0
var _frame := -1

func setup_frames(frames: Array, faces_right: bool, idle: int) -> void:
	for f in frames:
		walk.append(f)
	idle_frame = idle
	tex = walk[idle]
	art_faces_right = faces_right
	facing_right = faces_right
	shadow = Sprite2D.new()
	shadow.texture = shadow_tex()
	shadow.scale = Vector2(0.9, 0.32)
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	rig = Node2D.new()
	add_child(rig)
	body = Sprite2D.new()
	body.texture = tex
	body.centered = false
	body.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 2)
	rig.add_child(body)

## hip_y / split_x: where the legs start and where they part, in pixels of the frame.
func setup(t: Texture2D, faces_right: bool, hip_y: float, split_x: float) -> void:
	tex = t
	hip = hip_y
	split = split_x
	art_faces_right = faces_right
	facing_right = faces_right
	shadow = Sprite2D.new()
	shadow.texture = shadow_tex()
	shadow.scale = Vector2(0.9, 0.32)
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	rig = Node2D.new()
	add_child(rig)
	var w := float(t.get_width())
	var h := float(t.get_height())
	var top := hip - 5.0           # legs reach a little under the coat, so a lifted leg tucks under it
	leg_l = _part(Rect2(0, top, split, h - top), Vector2(split * 0.6, hip))
	leg_r = _part(Rect2(split, top, w - split, h - top), Vector2(split + (w - split) * 0.4, hip))
	body = _part(Rect2(0, 0, w, hip + 1.0), Vector2(w / 2.0, hip))

func animate(delta: float) -> void:
	if not walk.is_empty():
		_animate_frames(delta)
		return
	var speed := vel.length()
	moving = speed > 6.0
	working = maxf(0.0, working - delta)
	if absf(vel.x) > 10.0:
		facing_right = vel.x > 0.0
	elif absf(dir.x) > 0.2 and not moving:
		facing_right = dir.x > 0.0
	rig.scale.x = 1.0 if facing_right == art_faces_right else -1.0
	var t := Time.get_ticks_msec() / 1000.0
	var hip_pos := Vector2(0, hip - tex.get_height() + 3)
	if moving:
		# About two steps a second at full speed; the stride follows the real speed, so easing in reads as walking.
		phase += delta * (4.0 + speed * 0.042)
		var s := sin(phase)
		var lift_l := maxf(0.0, s)
		var lift_r := maxf(0.0, -s)
		var amt := clampf(speed / 130.0, 0.35, 1.0)
		leg_l.position = hip_pos + Vector2(-tex.get_width() / 2.0 + split * 0.6 + lift_l * 1.6 * amt, -lift_l * 4.5 * amt)
		leg_r.position = hip_pos + Vector2(-tex.get_width() / 2.0 + split + (tex.get_width() - split) * 0.4 + lift_r * 1.6 * amt, -lift_r * 4.5 * amt)
		leg_l.rotation = -lift_l * 0.18 * amt
		leg_r.rotation = -lift_r * 0.18 * amt
		# The body rides highest over the passing leg, leans a little into the walk, sways side to side.
		body.position = hip_pos + Vector2(cos(phase) * 0.8 * amt, -absf(s) * 2.6 * amt)
		body.rotation = 0.05 * amt + cos(phase) * 0.025 * amt
		body.scale = Vector2.ONE
		var step := floori(phase / PI)
		if step != _last_step:
			_last_step = step
			stepped.emit(global_position + Vector2((-6.0 if step % 2 == 0 else 6.0), 0))
	else:
		phase = 0.0
		leg_l.position = hip_pos + Vector2(-tex.get_width() / 2.0 + split * 0.6, 0)
		leg_r.position = hip_pos + Vector2(-tex.get_width() / 2.0 + split + (tex.get_width() - split) * 0.4, 0)
		leg_l.rotation = 0.0
		leg_r.rotation = 0.0
		if working > 0.0:
			var k := absf(sin(t * 9.0))
			body.position = hip_pos + Vector2(1.5 * k, 1.5 * k)
			body.rotation = 0.12 * k
			body.scale = Vector2(1.0, 1.0 - 0.03 * k)
		else:
			# Breathing: the chest rises and falls a little, the legs stay planted.
			body.position = hip_pos
			body.rotation = 0.0
			body.scale = Vector2(1.0, 1.0 + sin(t * 2.2 + position.x) * 0.015)
	shadow.scale = Vector2(0.9 - (0.06 if moving and absf(sin(phase)) > 0.7 else 0.0), 0.32)

## With real frames: the frame follows the distance walked (one frame per 15 px), so the feet never slide;
## standing, the idle frame breathes; working, it bobs over the job.
func _animate_frames(delta: float) -> void:
	var speed := vel.length()
	moving = speed > 6.0
	working = maxf(0.0, working - delta)
	if absf(vel.x) > 10.0:
		facing_right = vel.x > 0.0
	elif absf(dir.x) > 0.2 and not moving:
		facing_right = dir.x > 0.0
	rig.scale.x = 1.0 if facing_right == art_faces_right else -1.0
	var t := Time.get_ticks_msec() / 1000.0
	var f := idle_frame
	if moving:
		dist += speed * delta
		f = floori(dist / 15.0) % walk.size()
		if f != _frame and f % 2 == 0:
			stepped.emit(global_position + Vector2(-5.0 if f == 0 else 5.0, 0))
		body.position = Vector2(0, -absf(sin(dist / 15.0 * PI)) * 1.0)
		body.rotation = 0.0
		body.scale = Vector2.ONE
	elif working > 0.0:
		var k := absf(sin(t * 9.0))
		body.position = Vector2(1.5 * k, 1.5 * k)
		body.rotation = 0.1 * k
		body.scale = Vector2(1.0, 1.0 - 0.03 * k)
	else:
		dist = 0.0
		body.position = Vector2.ZERO
		body.rotation = 0.0
		body.scale = Vector2(1.0, 1.0 + sin(t * 2.2 + position.x) * 0.015)
	if f != _frame:
		_frame = f
		body.texture = walk[f]
	shadow.scale = Vector2(0.8, 0.3)

## Rectangle the sprite covers on screen (for fading what stands in front of it).
func rect() -> Rect2:
	return Rect2(position + Vector2(-tex.get_width() / 2.0, -tex.get_height()), Vector2(tex.get_width(), tex.get_height()))
