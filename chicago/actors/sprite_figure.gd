class_name SpriteFigure
extends Figure
## A character drawn with imported sprite frames (ArtRegistry) instead of the TEMPORARY polygons. Same API as Figure
## (facing, walking, hurt flash), so actors do not care which one they have. The frame's pivot (point between the
## feet) sits on the node origin. A soft shadow is drawn under it unless the art has its own.

var char_id := ""
var sprite: AnimatedSprite2D
var _state := ""

static func make(id: String, coat_color: Color) -> Figure:
	if ArtRegistry.character_frames(id) == null:
		var f := Figure.new()
		f.coat = coat_color
		return f
	var s := SpriteFigure.new()
	s.char_id = id
	return s

func _ready() -> void:
	var a := ArtRegistry.entry(char_id)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = ArtRegistry.character_frames(char_id)
	sprite.centered = false
	sprite.offset = -Vector2(float(a.pivot[0]), float(a.pivot[1]))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_update()

func _process(delta: float) -> void:
	if hurt_t > 0.0:
		hurt_t -= delta
	sprite.modulate = Color(1, 0.6, 0.6) if hurt_t > 0.0 else Color.WHITE
	_update()

func set_facing(f: String) -> void:
	facing = f

func _update() -> void:
	if sprite == null:
		return
	var p := ArtRegistry.pick(char_id, "walk" if walking else "idle", facing)
	if p[0] == "":
		return
	sprite.flip_h = p[1]
	if sprite.animation != p[0] or not sprite.is_playing():
		sprite.play(p[0])
	_state = p[0]

func current_animation() -> String:
	return _state

func _draw() -> void:
	# Ground shadow only; the body is the sprite.
	var pts := PackedVector2Array()
	for i in 14:
		var t := TAU * i / 14.0
		pts.append(Vector2(cos(t) * 18.0, sin(t) * 8.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.32))
