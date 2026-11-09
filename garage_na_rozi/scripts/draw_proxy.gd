extends Node2D
## Draws through a callable, so one script can paint several layers.

var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
