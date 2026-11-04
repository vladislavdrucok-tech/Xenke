extends Node2D
## TEMPORARY ART: a shop sign drawn as a plaque with the name (period English signage, data key SIGN_*).

var text_key := ""
var lift := 80.0

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var text := tr(text_key)
	var fs := 13
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
	var r := Rect2(Vector2(-w / 2.0, -lift - 12.0), Vector2(w, 22.0))
	draw_rect(r, Color("#2a1d16"))
	draw_rect(r.grow(-2.0), Color("#c9a35a"), false, 1.0)
	draw_string(font, Vector2(-w / 2.0 + 8.0, -lift + 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#f1dfae"))
