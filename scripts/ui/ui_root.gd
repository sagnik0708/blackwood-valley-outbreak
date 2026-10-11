class_name UiRoot
extends CanvasLayer

var root: Control
var hud: Hud
var touch: TouchControls
var inventory: InventoryUi
var dialogue: DialogueUi
var menu: MenuUi
var open_panel := ""


func _ready() -> void:
	add_to_group("ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = AssetFactory.ui_theme()
	add_child(root)
	hud = Hud.new(); hud.name = "Hud"; root.add_child(hud)
	touch = TouchControls.new(); touch.name = "Touch"; root.add_child(touch)
	inventory = InventoryUi.new(); inventory.name = "Inventory"; root.add_child(inventory)
	dialogue = DialogueUi.new(); dialogue.name = "Dialogue"; root.add_child(dialogue)
	menu = MenuUi.new(); menu.name = "Menu"; root.add_child(menu)

	GameState.touch_ui = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	touch.visible = GameState.touch_ui

	EventBus.dialogue_started.connect(func(id): open("dialogue"); dialogue.open_for(id))
	EventBus.dialogue_finished.connect(func(_id): close())
	EventBus.panel_toggled.connect(func(p): open(p))
	EventBus.ending_reached.connect(func(_id): open("ending"))
	EventBus.player_died.connect(func(): open("death"))
	if GameState.session_started:
		close()
	else:
		open("menu")


func open(panel: String) -> void:
	open_panel = panel
	_apply()


func close() -> void:
	if open_panel == "dialogue":
		dialogue.close_tree()
	open_panel = ""
	_apply()


func _apply() -> void:
	inventory.visible = open_panel in ["inventory", "craft"]
	if open_panel == "craft":
		inventory.set_tab("craft")
	elif open_panel == "inventory":
		inventory.set_tab("pack")
	dialogue.visible = open_panel == "dialogue"
	var menu_modes := ["menu", "pause", "death", "ending", "journal", "map", "finale"]
	menu.visible = open_panel in menu_modes
	if menu.visible:
		menu.show_mode(open_panel)
	get_tree().paused = open_panel != ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if open_panel == "":
			open("pause")
		else:
			close()
	elif event.is_action_pressed("inventory"):
		if open_panel == "inventory":
			close()
		else:
			open("inventory")
	elif event.is_action_pressed("crafting"):
		if open_panel == "craft":
			close()
		else:
			open("craft")
	elif event.is_action_pressed("journal"):
		if open_panel == "journal":
			close()
		else:
			open("journal")
	elif event.is_action_pressed("map"):
		if open_panel == "map":
			close()
		else:
			open("map")
	elif event.is_action_pressed("quick_save"):
		SaveManager.save_game(0)
	elif event.is_action_pressed("quick_load"):
		SaveManager.load_game(0)
