class_name Backdrop
extends Control
## The post office interior behind the menus: wall, panelling, window with the
## city (its look follows the story), shelves and the decorations you bought.

var kind := "menu"     # "menu" | "shift" | "office"
var floor_y := 0.0     # where the panelling starts (set by the owner)
var _decor_nodes := []


func _init(p_kind: String = "menu") -> void:
	kind = p_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	resized.connect(rebuild)
	Game.profile_changed.connect(rebuild)
	rebuild.call_deferred()


func _tiled(tex_name: String, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UI.tex(tex_name)
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.position = rect.position
	t.size = rect.size / UI.PIX
	t.scale = Vector2.ONE * UI.PIX
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func _sprite(tex_name: String, pos: Vector2, k: float = UI.PIX) -> TextureRect:
	var t := UI.image(tex_name, k)
	t.position = pos
	t.size = t.custom_minimum_size
	add_child(t)
	return t


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var s := size if size.x > 0 else get_viewport_rect().size
	var wall_h := floor_y if floor_y > 0 else s.y * (0.62 if kind == "menu" else 0.7)
	_tiled("wall_tile", Rect2(0, 0, s.x, wall_h))
	_tiled("wainscot_tile", Rect2(0, wall_h, s.x, 160))
	_tiled("floor_tile", Rect2(0, wall_h + 160, s.x, max(64.0, s.y - wall_h - 160)))
	# pipes along the ceiling
	_tiled("pipe_h", Rect2(0, 28, s.x, 40))
	if kind == "shift":
		return
	var cx := s.x / 2
	var mood := Story.city_mood(Game.profile)
	var win_pos := Vector2(cx - 72 * UI.PIX / 2, wall_h * 0.18)
	_sprite("city_" + mood, win_pos + Vector2(4, 6) * UI.PIX)
	_sprite("window", win_pos)
	_sprite("shelf", Vector2(16, wall_h - 60 * UI.PIX + 8))
	_sprite("shelf", Vector2(s.x - 44 * UI.PIX - 16, wall_h - 60 * UI.PIX + 8))
	_sprite("clock", Vector2(cx - 11 * UI.PIX, win_pos.y - 26 * UI.PIX))
	var d: Dictionary = Game.profile.get("upgrades", {})
	if int(d.get("poster", 0)) > 0:
		_sprite("dc_poster", Vector2(44 * UI.PIX + 40, wall_h * 0.12))
	if int(d.get("neon", 0)) > 0:
		_sprite("dc_neon", Vector2(cx - 24 * UI.PIX, wall_h * 0.18 + 56 * UI.PIX))
	if int(d.get("plant", 0)) > 0:
		_sprite("dc_plant", Vector2(24, wall_h + 160 - 28 * UI.PIX))
	if int(d.get("lamp", 0)) > 0:
		_sprite("dc_lamp", Vector2(s.x - 16 * UI.PIX - 30, wall_h + 160 - 24 * UI.PIX))
	if int(d.get("radio", 0)) > 0:
		_sprite("dc_radio", Vector2(s.x - 44 * UI.PIX - 8, wall_h - 60 * UI.PIX - 8))
	if int(d.get("catbed", 0)) > 0:
		_sprite("dc_catbed", Vector2(cx + 60, wall_h + 160 - 10 * UI.PIX))
		var cat := UI.image("cat", UI.PIX)
		cat.texture = UI.frames("cat", 4)[0]
		cat.custom_minimum_size = Vector2(24, 16) * UI.PIX
		cat.size = cat.custom_minimum_size
		cat.position = Vector2(cx + 60 + 2 * UI.PIX, wall_h + 160 - 22 * UI.PIX)
		add_child(cat)
