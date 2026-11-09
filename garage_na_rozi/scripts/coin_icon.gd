extends Control
## Small painted coin for the interface.


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.45
	Paint.coin(self, size * 0.5, r)
