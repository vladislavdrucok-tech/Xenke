extends Interactable
## A ladder between two floors. Its area covers the whole height; Use climbs to the other end on its own.

@export var top := 230.0
@export var bottom := 320.0
var hero: Node2D
## Optional check: returns why the ladder cannot be used now ("" = it can).
var gate: Callable
var _tex: Texture2D

func _ready() -> void:
	_tex = load("res://assets/rest/ladder_0.png")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(26, bottom - top + 40)
	cs.shape = r
	cs.position = Vector2(0, (top + bottom) / 2.0 - global_position.y)
	add_child(cs)
	highlight = Rect2(-13, top - global_position.y - 4, 26, bottom - top + 4)

func _going_up() -> bool:
	return hero == null or hero.global_position.y > (top + bottom) / 2.0

func title() -> String:
	return "Драбина · нагору" if _going_up() else "Драбина · вниз"

func blocked() -> String:
	return gate.call() if gate.is_valid() else ""

func verb() -> String:
	return "Лізти"

func finish() -> void:
	hero.start_climb(global_position.x, top if _going_up() else bottom)
	super.finish()

func _draw() -> void:
	if _tex:
		var h := bottom - top + 8
		var w := _tex.get_width() * (h / _tex.get_height())
		draw_texture_rect(_tex, Rect2(-w / 2.0, top - 8 - global_position.y, w, h), false)
	super._draw()
