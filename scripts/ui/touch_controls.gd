class_name TouchControls
extends Control

const STICK_RADIUS := 96.0

var stick_origin := Vector2.ZERO
var stick_active := false
var stick_index := -1
var player: Player
var buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size := get_viewport_rect().size
	stick_origin = Vector2(160, size.y - 170)

	var pad := Control.new()
	pad.name = "Pad"
	pad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)

	# right-hand action cluster
	var attack := _btn("ATTACK", Vector2(150, 150), Vector2(-180, -190), func(): _press("attack"))
	var interact := _btn("USE", Vector2(110, 110), Vector2(-330, -150), func(): _press("interact"))
	var sneak := _btn("SNEAK", Vector2(110, 84), Vector2(-180, -320), _toggle_sneak)
	var sprint := _btn("RUN", Vector2(110, 84), Vector2(-330, -290), _toggle_sprint)
	var med := _btn("MED", Vector2(100, 84), Vector2(-470, -190), func(): _press("use_medical"))
	pad.add_child(attack); pad.add_child(interact); pad.add_child(sneak); pad.add_child(sprint); pad.add_child(med)
	buttons["sneak"] = sneak
	buttons["sprint"] = sprint

	# top-right utility cluster
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -640
	top.offset_bottom = 66
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	for spec in [["INV", "inventory"], ["CRAFT", "crafting"], ["LOG", "journal"], ["MAP", "map"], ["AUTO", "auto_aim"], ["MENU", "pause"]]:
		var b := Button.new()
		b.text = String(spec[0])
		b.custom_minimum_size = Vector2(96, 60)
		b.pressed.connect(func(): _press(String(spec[1])))
		top.add_child(b)
		buttons[String(spec[1])] = b


func _btn(text: String, size: Vector2, offset: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = offset - Vector2(size.x, size.y) * 0.0 + Vector2(-size.x, -size.y) + Vector2(size.x, size.y)
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + size.x
	b.offset_bottom = offset.y + size.y
	b.pressed.connect(cb)
	return b


func _press(action: String) -> void:
	AudioManager.play("ui", -8.0)
	match action:
		"attack": Input.action_press("attack"); Input.action_release("attack")
		"interact": Input.action_press("interact"); Input.action_release("interact")
		"use_medical": Input.action_press("use_medical"); Input.action_release("use_medical")
		"auto_aim":
			GameState.auto_aim = not GameState.auto_aim
			EventBus.say("Auto-aim %s" % ("on" if GameState.auto_aim else "off"))
		"inventory": EventBus.panel_toggled.emit("inventory")
		"crafting": EventBus.panel_toggled.emit("craft")
		"journal": EventBus.panel_toggled.emit("journal")
		"map": EventBus.panel_toggled.emit("map")
		"pause": EventBus.panel_toggled.emit("pause")


func _toggle_sneak() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.set_touch_sneak(not player.touch_sneak)
	buttons["sneak"].modulate = Color(0.6, 1.0, 0.7) if player.touch_sneak else Color(1, 1, 1)


func _toggle_sprint() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.set_touch_sprint(not player.touch_sprint)
	buttons["sprint"].modulate = Color(1.0, 0.9, 0.5) if player.touch_sprint else Color(1, 1, 1)


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed and event.position.distance_to(stick_origin) < STICK_RADIUS * 1.4:
			stick_active = true
			stick_index = event.index
		elif not event.pressed and event.index == stick_index:
			stick_active = false
			stick_index = -1
			player.set_touch_dir(Vector2.ZERO)
	elif event is InputEventScreenDrag and stick_active and event.index == stick_index:
		player.set_touch_dir((event.position - stick_origin) / STICK_RADIUS)


func _process(_delta: float) -> void:
	if not visible:
		return
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_circle(stick_origin, STICK_RADIUS, Color(0.1, 0.13, 0.14, 0.45))
	draw_arc(stick_origin, STICK_RADIUS, 0.0, TAU, 48, Color(0.7, 0.85, 0.8, 0.5), 3.0)
	var knob := stick_origin
	if stick_active and player != null:
		knob += player.touch_dir * STICK_RADIUS
	draw_circle(knob, 42.0, Color(0.55, 0.75, 0.68, 0.75))
