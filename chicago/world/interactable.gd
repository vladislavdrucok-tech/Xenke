class_name Interactable
extends Node2D
## A point in the world the player can act on: door, workbench, bed, counter, repair bay... The world decides what
## the action does (world/world.gd _interact); this node only says what it is and where.
## TEMPORARY ART: a small marker so placeholders are discoverable.

var id := ""
var kind := ""
var verb_key := "HUD_ACT_USE"
var def := {}
var enabled := true

func _ready() -> void:
	add_to_group("interactable")
	# Markers lie on the ground: drawn under everything standing (still above the ground layer at -10).
	z_index = -5

func verb() -> String:
	return verb_key

func _draw() -> void:
	if kind == "door":
		var c := Iso.rect_corners(Rect2(Iso.to_grid(position) - Vector2(0.5, 0.5), Vector2.ONE)) as PackedVector2Array
		for i in c.size():
			c[i] -= position
		draw_polyline(PackedVector2Array([c[0], c[1], c[2], c[3], c[0]]), Color(0.95, 0.8, 0.45, 0.45), 2.0)
	else:
		draw_circle(Vector2(0, -4), 5.0, Color(0.95, 0.8, 0.45, 0.7))
