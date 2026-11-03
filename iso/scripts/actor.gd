class_name Actor
extends Node2D
## A character in the isometric yard. The node's position is the point between the feet: the yard sorts everything
## by that point, so the actor passes in front of a thing whose base is above its feet and behind one below.
## TEMPORARY: one painted 3/4 frame per character (cut from the concept). Walking is shown by a bob and a sway, the
## facing by mirroring left/right; real 4/8-direction walk cycles are on the art list (docs/ISO_ART_LIST_UK.md).

var sprite: Sprite2D
var shadow: Sprite2D
var facing_right := true      # the painted frame faces right (Mira) or left (researcher): see art_faces_right
var art_faces_right := true
var moving := false
var working := 0.0
var phase := 0.0
var speed := 150.0
var dir := Vector2.ZERO        # last move direction (screen space)

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

func setup(tex: Texture2D, faces_right: bool) -> void:
	art_faces_right = faces_right
	facing_right = faces_right
	shadow = Sprite2D.new()
	shadow.texture = shadow_tex()
	shadow.scale = Vector2(0.9, 0.32)
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 3)
	add_child(sprite)

func animate(delta: float) -> void:
	if moving:
		phase += delta * speed / 22.0
	else:
		phase = 0.0
	working = maxf(0.0, working - delta)
	if absf(dir.x) > 0.2:
		facing_right = dir.x > 0.0
	sprite.flip_h = facing_right != art_faces_right
	var t := Time.get_ticks_msec() / 1000.0
	if moving:
		# A step: up on every stride, a little lean into the direction of travel.
		sprite.position = Vector2(0, -absf(sin(phase)) * 5.0)
		sprite.rotation = sin(phase) * 0.06
		sprite.scale = Vector2(1.0, 1.0)
	elif working > 0.0:
		var k := absf(sin(t * 9.0))
		sprite.position = Vector2(0, k * 3.0)
		sprite.rotation = (0.08 if facing_right else -0.08) * k
		sprite.scale = Vector2(1.0 + 0.04 * k, 1.0 - 0.06 * k)
	else:
		sprite.position = Vector2.ZERO
		sprite.rotation = 0.0
		sprite.scale = Vector2(1.0, 1.0 + sin(t * 2.2 + position.x) * 0.012)   # breathing
	shadow.scale = Vector2(0.9 - absf(sprite.position.y) * 0.01, 0.32)

## Rectangle the sprite covers on screen (for fading what stands in front of it).
func rect() -> Rect2:
	var t := sprite.texture
	return Rect2(position + Vector2(-t.get_width() / 2.0, -t.get_height()), Vector2(t.get_width(), t.get_height()))
