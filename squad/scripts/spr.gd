class_name Spr
extends Node3D
## A pixel-art sprite from the owner's art pack standing in the 3D world: it always faces the camera (billboard),
## keeps sharp pixels, stands with its feet (or base) on the ground point, and has a soft shadow under it.
## Characters switch frames from their atlas (data/sprites.json: foot anchor and foot line per frame); props switch
## their states (closed/open, broken/working...).

static var _data := {}
static var _tex := {}

var sprite: Sprite3D
var shadow: MeshInstance3D
var frames: Array = []
var names := {}
var sheets: Array = []
var px := 0.01
var frame := -1
var right := true
var states := 0
var state := -1
var prop_name := ""
var base_h := 1.0

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
	return _data

static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]

func _make() -> void:
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.centered = true
	add_child(sprite)

## A character: `height` is how tall its walking frames stand in the world.
static func character(char_name: String, height: float, shadow_w := 0.8) -> Spr:
	var s := Spr.new()
	s._make()
	var d: Dictionary = data().chars[char_name]
	s.frames = d.frames
	s.names = d.names
	for p in d.sheets:
		s.sheets.append(tex(p))
	s.px = height / float(d.unit)
	s.sprite.pixel_size = s.px
	s.sprite.region_enabled = true
	s.shadow = Models.blob(s, shadow_w)
	s.show_frame(4, true)
	return s

func pose(n: String, fallback: int) -> int:
	return int(names.get(n, fallback))

func has_pose(n: String) -> bool:
	return names.has(n)

func show_frame(i: int, face_right: bool) -> void:
	if i == frame and face_right == right:
		return
	frame = i
	right = face_right
	var f: Dictionary = frames[i]
	sprite.texture = sheets[int(f.sheet)]
	sprite.region_rect = Rect2(f.x, f.y, f.w, f.h)
	sprite.flip_h = not face_right
	# Put the point between the boots on the node's origin (centred sprite: offset moves the centre).
	var ox: float = f.w / 2.0 - f.anchor
	sprite.offset = Vector2(ox if face_right else -ox, f.foot - f.h / 2.0)

## A prop with states, `scale_k` times its pack size. Its base sits on the ground point.
static func prop(parent: Node3D, name: String, pos: Vector3, st := 0, scale_k := 1.0, shadow_w := -1.0) -> Spr:
	var s := Spr.new()
	s._make()
	var m: Dictionary = data().props[name]
	s.prop_name = name
	s.states = int(m.states)
	s.base_h = float(m.h) * scale_k
	parent.add_child(s)
	s.position = pos
	s.set_state(st)
	if shadow_w != 0.0:
		var t: Texture2D = s.sprite.texture
		var w: float = t.get_width() * s.px
		s.shadow = Models.blob(s, shadow_w if shadow_w > 0.0 else w * 1.05, (shadow_w if shadow_w > 0.0 else w) * 0.45)
	return s

func set_state(st: int) -> void:
	st = clampi(st, 0, states - 1)
	if st == state:
		return
	state = st
	var t := tex("res://assets/props/%s_%d.png" % [prop_name, st])
	sprite.texture = t
	px = base_h / float(t.get_height())
	sprite.pixel_size = px
	sprite.offset = Vector2(0, t.get_height() / 2.0)

func set_alpha(a: float) -> void:
	sprite.modulate.a = a
