class_name InventoryUi
extends Control

var tab := "pack"
var panel: PanelContainer
var list_box: VBoxContainer
var title_label: Label
var weight_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 520)
	panel.offset_left = -360
	panel.offset_top = -260
	panel.offset_right = 360
	panel.offset_bottom = 260
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	title_label = Label.new()
	box.add_child(title_label)
	weight_label = Label.new()
	box.add_child(weight_label)
	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	var b1 := Button.new(); b1.text = "PACK"; b1.custom_minimum_size = Vector2(140, 60)
	b1.pressed.connect(func(): set_tab("pack"))
	var b2 := Button.new(); b2.text = "CRAFTING"; b2.custom_minimum_size = Vector2(180, 60)
	b2.pressed.connect(func(): set_tab("craft"))
	var b3 := Button.new(); b3.text = "CLOSE"; b3.custom_minimum_size = Vector2(140, 60)
	b3.pressed.connect(func(): EventBus.panel_toggled.emit("pause"))
	tabs.add_child(b1); tabs.add_child(b2); tabs.add_child(b3)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	EventBus.inventory_changed.connect(func(): _refresh())
	visible = false


func set_tab(t: String) -> void:
	tab = t
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	for c in list_box.get_children():
		c.queue_free()
	title_label.text = "SURVIVOR PACK" if tab == "pack" else "CRAFTING WORKBENCH"
	var weight := 0.0
	for entry in GameState.inventory:
		var def = DataLibrary.get_item(String(entry["id"]))
		if def != null:
			weight += float(def.weight) * int(entry["count"])
	weight_label.text = "Carry weight: %.1f kg   |   Melee: %s" % [weight, GameState.equipment["melee"]]
	if tab == "pack":
		_build_pack()
	else:
		_build_craft()


func _build_pack() -> void:
	for entry in GameState.inventory:
		var id := String(entry["id"])
		var def = DataLibrary.get_item(id)
		if def == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = AssetFactory.item_icon(def)
		icon.custom_minimum_size = Vector2(38, 38)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var lab := Label.new()
		lab.text = "%s x%d" % [String(def.display_name), int(entry["count"])]
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var use := Button.new()
		use.text = "USE"
		use.custom_minimum_size = Vector2(96, 52)
		use.pressed.connect(func():
			if int(def.type) in [0, 1]:
				GameState.equipment["melee" if int(def.type) == 0 else "ranged"] = id
				EventBus.say("Equipped %s." % String(def.display_name))
			elif id == "barricade_kit":
				GameState.remove_item(id, 1)
				var p = get_tree().get_first_node_in_group("player")
				if p != null:
					p.place_barricade()
			else:
				GameState.use_item(id))
		row.add_child(use)
		list_box.add_child(row)
	if GameState.inventory.is_empty():
		var empty := Label.new()
		empty.text = "Your pack is empty. Search the valley."
		list_box.add_child(empty)


func _build_craft() -> void:
	for recipe in DataLibrary.all_of("recipes"):
		var row := VBoxContainer.new()
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var lab := Label.new()
		lab.text = String(recipe.display_name)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(lab)
		var craft := Button.new()
		craft.text = "CRAFT"
		craft.custom_minimum_size = Vector2(120, 52)
		craft.pressed.connect(func(): _craft(String(recipe.id)))
		line.add_child(craft)
		row.add_child(line)
		var need := Label.new()
		var parts: Array = []
		for ing in recipe.ingredients:
			parts.append("%s x%d" % [DataLibrary.item_name(String(ing.get("item", ""))), int(ing.get("count", 1))])
		need.text = "  needs: " + ", ".join(parts) + ("  (station: %s)" % String(recipe.station) if String(recipe.station) != "any" else "")
		row.add_child(need)
		list_box.add_child(row)


func _craft(recipe_id: String) -> void:
	var recipe = DataLibrary.get_recipe(recipe_id)
	if recipe == null:
		return
	for ing in recipe.ingredients:
		if GameState.count_item(String(ing.get("item", ""))) < int(ing.get("count", 1)):
			EventBus.say("Missing ingredients.", Color(1.0, 0.7, 0.6))
			return
	for ing in recipe.ingredients:
		GameState.remove_item(String(ing.get("item", "")), int(ing.get("count", 1)))
	for res in recipe.results:
		GameState.add_item(String(res.get("item", "")), int(res.get("count", 1)))
	GameState.notify_event("craft", recipe_id, 1)
	AudioManager.play("craft", -4.0)
	EventBus.say("Crafted %s." % String(recipe.display_name), Color(0.75, 0.95, 0.75))
	_refresh()
