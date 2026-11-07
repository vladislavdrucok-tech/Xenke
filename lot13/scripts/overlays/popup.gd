extends Control
## Generic modal window: title, text, optional portrait / icon / item picture, and buttons.
## args: title, text, buttons ([text, style, Callable or null]), portrait, icon, item.

const Data = preload("res://scripts/data.gd")

var main
var args: Dictionary = {}
var buttons: Array = []
var panel: PanelContainer
var _closed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UI.full(UI.color_rect(Color(0.04, 0.03, 0.07, 0.72))))
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(c))
	panel = UI.panel("panel", 14)
	panel.custom_minimum_size = Vector2(312, 0)
	c.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	var title := str(args.get("title", ""))
	if args.has("portrait"):
		var row := UI.hbox(10)
		row.add_child(UI.tex_rect(UI.portrait_tex(str(args["portrait"])), 3))
		var tl := UI.shadow(UI.label(title, 18, UI.C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
		UI.fill(tl)
		row.add_child(tl)
		v.add_child(row)
	else:
		if args.has("item"):
			var id := str(args["item"])
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(0, 84)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var r: int = Data.rarity_of(id)
			if r >= 2:
				var rays := UI.tex_rect(UI.art("fx/rays"), 2)
				rays.modulate = Data.RARITY_COLORS[r].lightened(0.35)
				var rc := UI.center(rays)
				holder.add_child(UI.full(rc))
			holder.add_child(UI.full(UI.center(UI.item_icon(id, 4))))
			v.add_child(holder)
		elif args.has("icon"):
			v.add_child(UI.center(UI.icon(str(args["icon"]), 3)))
		if title != "":
			v.add_child(UI.shadow(UI.label(title, 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)))
	var text := str(args.get("text", ""))
	if text != "":
		var tl2 := UI.label(text, 15, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER if not args.has("portrait") else HORIZONTAL_ALIGNMENT_LEFT, true)
		tl2.custom_minimum_size = Vector2(280, 0)
		v.add_child(tl2)
	buttons = args.get("buttons", [])
	if buttons.is_empty():
		buttons = [[L.t("ok"), "gold", null]]
	var box: BoxContainer = UI.hbox(8) if buttons.size() <= 2 else UI.vbox(8)
	for i in range(buttons.size()):
		var bd: Array = buttons[i]
		var b := UI.button(str(bd[0]), str(bd[1]), 16, 52)
		UI.fill(b)
		b.pressed.connect(_press.bind(i))
		box.add_child(b)
	v.add_child(box)
	UI.pop(panel, 0.7, 0.25)


func _press(i: int) -> void:
	if _closed:
		return
	_closed = true
	Sfx.click()
	var bd: Array = buttons[i]
	var cb = bd[2] if bd.size() > 2 else null
	main.close_overlay(self)
	if cb is Callable and cb.is_valid():
		cb.call()


func on_back() -> void:
	_press(buttons.size() - 1)
