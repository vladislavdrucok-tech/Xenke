class_name DialogueBox
extends PanelContainer
## Shows a dialogue from data/dialogue/<id>.json: speaker, line, choices. All text is localization keys.
## Effects run through GameState.apply_effects with a key per node / choice, so talking again never pays twice or
## moves a quest twice. When a dialogue ends it emits the game events "dialogue_done" and "talked_to".

signal finished(dialogue_id: String)

var dlg := {}
var node_id := ""
var speaker_label: Label
var text_label: Label
var choices_box: VBoxContainer
var hint: Label
var dialogue_id := ""
var npc_id := ""

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.06, 0.93)
	sb.border_color = Color("#b8893f")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	speaker_label = Label.new()
	speaker_label.add_theme_color_override("font_color", Color("#e7c27a"))
	speaker_label.add_theme_font_size_override("font_size", 20)
	v.add_child(speaker_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.custom_minimum_size = Vector2(300, 0)
	v.add_child(text_label)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 6)
	v.add_child(choices_box)
	hint = Label.new()
	hint.text = "UI_CONTINUE_HINT"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)

func is_open() -> bool:
	return visible

func open(id: String, with_npc: String = "") -> bool:
	dlg = DataRegistry.dialogue(id)
	if dlg.is_empty():
		push_error("DialogueBox: no dialogue " + id)
		return false
	dialogue_id = id
	npc_id = with_npc
	visible = true
	EventBus.dialogue_requested.emit(id, with_npc)
	_show(String(dlg.start))
	return true

func _show(nid: String) -> void:
	node_id = nid
	var n: Dictionary = dlg.nodes.get(nid, {})
	if n.is_empty():
		close()
		return
	GameState.apply_effects(n.get("effects", []), "dlg:%s:%s" % [dialogue_id, nid])
	var spk := String(n.get("speaker", ""))
	var spk_def := DataRegistry.table("npcs").get(spk, {}) as Dictionary
	speaker_label.text = tr(String(spk_def.get("name", spk)))
	text_label.text = tr(String(n.text))
	for c in choices_box.get_children():
		c.queue_free()
	var shown := 0
	var i := 0
	for ch in n.get("choices", []):
		i += 1
		if not Conditions.check(ch.get("if", {}), GameState):
			continue
		var b := Button.new()
		b.text = tr(String(ch.text))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(choose.bind(i - 1))
		choices_box.add_child(b)
		shown += 1
	hint.visible = shown == 0

## Visible choices in order (tests and bots use these indices into the node's full choice list).
func visible_choices() -> Array[int]:
	var out: Array[int] = []
	var n: Dictionary = dlg.get("nodes", {}).get(node_id, {})
	var i := 0
	for ch in n.get("choices", []):
		if Conditions.check(ch.get("if", {}), GameState):
			out.append(i)
		i += 1
	return out

func choose(index: int) -> void:
	var n: Dictionary = dlg.nodes.get(node_id, {})
	var chs: Array = n.get("choices", [])
	if index < 0 or index >= chs.size():
		return
	var ch: Dictionary = chs[index]
	if not Conditions.check(ch.get("if", {}), GameState):
		return
	GameState.apply_effects(ch.get("effects", []), "dlg:%s:%s:c%d" % [dialogue_id, node_id, index])
	_goto(ch.get("next", ""))

## Continue past a line without choices.
func advance() -> void:
	if not visible:
		return
	var n: Dictionary = dlg.nodes.get(node_id, {})
	if not n.get("choices", []).is_empty() and not visible_choices().is_empty():
		return
	if n.get("end", false):
		close()
	else:
		_goto(n.get("next", ""))

func _goto(nid: Variant) -> void:
	if nid == null or String(nid).is_empty():
		close()
	else:
		_show(String(nid))

func close() -> void:
	if not visible:
		return
	visible = false
	var id := dialogue_id
	EventBus.emit_event("dialogue_done", {"dialogue": id, "npc": npc_id})
	if npc_id != "":
		EventBus.emit_event("talked_to", {"npc": npc_id})
	EventBus.dialogue_finished.emit(id)
	finished.emit(id)

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		advance()
		accept_event()
