class_name Modal
extends Control
## Модальне вікно поверх гри: затемнення + панель по центру.

signal closed

var panel: PanelContainer
var content: VBoxContainer
var dismiss_on_back := true


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.07, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		center.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		center.add_theme_constant_override("margin_" + side, 40)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(cc)
	panel = UIKit.panel(UIKit.PANEL, UIKit.PINK)
	panel.custom_minimum_size = Vector2(620, 0)
	cc.add_child(panel)
	content = UIKit.vbox(14)
	panel.add_child(content)


func _ready() -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# на вузьких екранах панель не ширша за екран
	var w := get_viewport_rect().size.x - 48
	panel.custom_minimum_size.x = minf(620, w)


func title(text: String, color: Color = UIKit.PINK) -> Label:
	var l := UIKit.pixel_label(text, UIKit.FS_BIG + 4, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(l)
	return l


func text(t: String, color: Color = UIKit.TEXT, size: int = UIKit.FS) -> Label:
	var l := UIKit.label(t, size, color, true)
	content.add_child(l)
	return l


func add_button(t: String, kind: String, cb: Callable) -> Button:
	var b := UIKit.button(t, kind)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	content.add_child(b)
	return b


func close() -> void:
	if is_queued_for_deletion():
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()
	queue_free()
