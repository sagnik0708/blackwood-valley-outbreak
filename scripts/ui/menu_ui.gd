class_name MenuUi
extends Control

var mode := "menu"
var panel: PanelContainer
var box: VBoxContainer
var current_ending := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(660, 560)
	panel.offset_left = -330
	panel.offset_top = -280
	panel.offset_right = 330
	panel.offset_bottom = 280
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	EventBus.ending_reached.connect(func(id): current_ending = id)
	visible = false


func show_mode(m: String) -> void:
	mode = m
	for c in box.get_children():
		c.queue_free()
	match mode:
		"menu": _build_menu()
		"pause": _build_pause()
		"death": _build_death()
		"ending": _build_ending()
		"journal": _build_journal()
		"map": _build_map()
		"finale": _build_finale()
	queue_redraw()


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	box.add_child(l)


func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 62)
	b.pressed.connect(func():
		AudioManager.play("click", -6.0)
		cb.call())
	box.add_child(b)


func _build_menu() -> void:
	_title("BLACKWOOD VALLEY: OUTBREAK\nQuarantine Zone 4 - choose your origin")
	for origin in [["ranger", "Park Ranger"], ["paramedic", "Field Paramedic"], ["carpenter", "Master Carpenter"], ["machinist", "Machinist / Electrician"]]:
		_button("NEW GAME - " + String(origin[1]), func(): _new_game(String(origin[0])))
	if SaveManager.has_save(0):
		_button("CONTINUE (autosave)", func(): _load(0))
	for slot in [1, 2]:
		if SaveManager.has_save(slot):
			_button("LOAD SLOT %d" % slot, func(): _load(slot))
	_button("QUIT", func(): get_tree().quit())


func _build_pause() -> void:
	_title("PAUSED")
	_button("RESUME", func(): get_tree().call_group("ui", "close"))
	_button("SAVE GAME", func(): SaveManager.save_game(1))
	_button("SAVE GAME (slot 2)", func(): SaveManager.save_game(2))
	_button("LOAD AUTOSAVE", func(): _load(0))
	_button("TOGGLE TOUCH UI", func():
		GameState.touch_ui = not GameState.touch_ui
		get_tree().call_group("touch", "set_visible", GameState.touch_ui))
	_button("MAIN MENU", func():
		get_tree().paused = false
		GameState.session_started = false
		get_tree().reload_current_scene())
	_button("QUIT", func(): get_tree().quit())


func _build_death() -> void:
	_title("YOU DIED\nThe valley keeps what it takes.")
	_button("RELOAD AUTOSAVE", func(): _load(0))
	_button("NEW GAME", func(): _new_game(GameState.origin))
	_button("QUIT", func(): get_tree().quit())


func _build_ending() -> void:
	var text := ""
	match current_ending:
		"extraction":
			text = "ENDING A: CORDON EXTRACTION\n\nThe transponder carries the CDC research codes up the valley. Rotors cut the blizzard. The high school soccer field lights up, and you choose who boards the last helicopter out of Blackwood Valley."
		"inoculation":
			text = "ENDING B: THE INOCULATION\n\nThe Primordial Mycelium Core reaches Dr. Chen. The Borealis Antiserum is mass-produced while the clinic holds against the final horde. Blackwood Valley survives - changed, but immune."
		"bastion":
			text = "ENDING C: THE MOUNTAIN BASTION\n\nThe relay goes silent, the bombers turn away, and the rockfall pass seals for good. Vance and Thorne hold the valley together as a self-sufficient mountain redoubt."
		_:
			text = "The valley endures."
	_title(text)
	_button("KEEP PLAYING", func(): get_tree().call_group("ui", "close"))
	_button("NEW GAME", func(): _new_game(GameState.origin))
	_button("QUIT", func(): get_tree().quit())


func _build_journal() -> void:
	_title("QUEST JOURNAL")
	for q in GameState.active_quests:
		var def = DataLibrary.get_quest(String(q["id"]))
		if def == null:
			continue
		_title("- " + String(def.title) + "\n  " + String(def.summary))
	for q in GameState.completed_quests:
		var def = DataLibrary.get_quest(String(q["id"]))
		if def != null:
			_title("[done] " + String(def.title))
	_button("CLOSE", func(): get_tree().call_group("ui", "close"))


func _build_finale() -> void:
	_title("BLACKWOOD PEAK - FINAL CHOICE\nDecide the fate of the valley.")
	if GameState.get_flag("ending_chosen"):
		_title("The valley's fate is already sealed.")
		_button("CLOSE", func(): get_tree().call_group("ui", "close"))
		return
	for opt in [["extraction", "ENDING A - Cordon Extraction"], ["inoculation", "ENDING B - The Inoculation"], ["bastion", "ENDING C - The Mountain Bastion"]]:
		var id := String(opt[0])
		var why := GameState.ending_requirement(id)
		var b := Button.new()
		b.text = String(opt[1]) if why == "" else "%s\n(%s)" % [String(opt[1]), why]
		b.custom_minimum_size = Vector2(520, 70)
		b.disabled = why != ""
		b.pressed.connect(func(): GameState.choose_ending(id))
		box.add_child(b)
	_button("CLOSE", func(): get_tree().call_group("ui", "close"))


func _build_map() -> void:
	_title("BLACKWOOD VALLEY - DISTRICT MAP")
	_button("CLOSE", func(): get_tree().call_group("ui", "close"))


func _draw() -> void:
	if mode != "map" or not visible:
		return
	var f := get_theme_default_font()
	var origin := Vector2(60, 220)
	var scale := 5.4
	for z in ZoneBuilder.ZONE_DEFS:
		var r: Rect2i = z["rect"]
		var pos := origin + Vector2(r.position.x, r.position.y) * scale
		var size := Vector2(r.size.x, r.size.y) * scale
		var here := String(z["id"]) == GameState.zone_id
		draw_rect(Rect2(pos, size), Color(0.25, 0.4, 0.32, 0.95) if here else Color(0.16, 0.22, 0.2, 0.95), true)
		draw_rect(Rect2(pos, size), Color(0.6, 0.8, 0.65, 0.8), false, 2.0)
		draw_string(f, pos + Vector2(6, 20), String(z["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 13, Color(0.9, 0.95, 0.88))


func _new_game(origin: String) -> void:
	get_tree().paused = false
	GameState.reset_run(origin)
	GameState.session_started = true
	GameState.player_position = Vector2.ZERO
	get_tree().reload_current_scene()


func _load(slot: int) -> void:
	get_tree().paused = false
	SaveManager.load_game(slot)
