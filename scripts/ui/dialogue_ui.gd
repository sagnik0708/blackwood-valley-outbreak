class_name DialogueUi
extends Control

var npc_id := ""
var tree: DialogueTree
var panel: PanelContainer
var name_label: Label
var text_label: RichTextLabel
var choices_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -320
	panel.offset_bottom = -20
	panel.offset_left = 60
	panel.offset_right = -60
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	name_label = Label.new()
	box.add_child(name_label)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = false
	text_label.fit_content = true
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text_label)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 8)
	box.add_child(choices_box)
	visible = false


func open_for(id: String) -> void:
	npc_id = id
	var npc = DataLibrary.get_npc(id)
	if npc == null:
		close_tree()
		return
	tree = DataLibrary.get_dialogue(String(npc.dialogue_id))
	if tree == null:
		close_tree()
		return
	visible = true
	_show(String(tree.start_node))


func _show(node_id: String) -> void:
	var node := tree.node_by_id(node_id)
	if node.is_empty():
		close_tree()
		return
	var npc = DataLibrary.get_npc(npc_id)
	name_label.text = String(node.get("speaker", npc.display_name if npc != null else ""))
	text_label.text = String(node.get("text", ""))
	for c in choices_box.get_children():
		c.queue_free()
	var choices: Array = node.get("choices", [])
	if bool(node.get("end", false)) or choices.is_empty():
		var b := Button.new()
		b.text = "Leave"
		b.custom_minimum_size = Vector2(220, 60)
		b.pressed.connect(close_tree)
		choices_box.add_child(b)
		return
	for choice in choices:
		if String(choice.get("requires_flag", "")) != "" and not GameState.get_flag(String(choice["requires_flag"])):
			continue
		if String(choice.get("requires_item", "")) != "" and not GameState.has_item(String(choice["requires_item"])):
			continue
		var b := Button.new()
		b.text = String(choice.get("text", "..."))
		b.custom_minimum_size = Vector2(320, 60)
		b.pressed.connect(func(): _pick(choice))
		choices_box.add_child(b)


func _pick(choice: Dictionary) -> void:
	if String(choice.get("set_flag", "")) != "":
		var flag := String(choice["set_flag"])
		GameState.set_flag(flag, true)
		GameState.notify_event("flag", flag, 1)
	if String(choice.get("give", "")) != "":
		GameState.add_item(String(choice["give"]), int(choice.get("give_count", 1)))
	if String(choice.get("take", "")) != "":
		GameState.remove_item(String(choice["take"]), int(choice.get("take_count", 1)))
	if String(choice.get("quest", "")) != "":
		GameState.start_quest(String(choice["quest"]))
	if float(choice.get("rep", 0.0)) != 0.0:
		var npc = DataLibrary.get_npc(npc_id)
		if npc != null:
			GameState.change_rep(String(npc.faction_id), float(choice["rep"]))
	GameState.remember(npc_id, "talked")
	AudioManager.play("ui", -8.0)
	if String(choice.get("next", "")) != "":
		_show(String(choice["next"]))
	else:
		close_tree()


func close_tree() -> void:
	visible = false
	EventBus.dialogue_finished.emit(npc_id)
