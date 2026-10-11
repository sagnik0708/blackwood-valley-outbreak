extends Node
## Registers the complete input map at boot so nothing depends on hand-typed
## InputEvent serialisation. Keyboard, mouse and (for UI) touch all covered.

func _enter_tree() -> void:
	_bind_keys("move_left", PackedInt32Array([KEY_A, KEY_LEFT]))
	_bind_keys("move_right", PackedInt32Array([KEY_D, KEY_RIGHT]))
	_bind_keys("move_up", PackedInt32Array([KEY_W, KEY_UP]))
	_bind_keys("move_down", PackedInt32Array([KEY_S, KEY_DOWN]))
	_bind_keys("attack", PackedInt32Array([KEY_SPACE, KEY_J]))
	_bind_keys("interact", PackedInt32Array([KEY_E, KEY_F]))
	_bind_keys("sneak", PackedInt32Array([KEY_C]))
	_bind_keys("sprint", PackedInt32Array([KEY_SHIFT]))
	_bind_keys("inventory", PackedInt32Array([KEY_I]))
	_bind_keys("crafting", PackedInt32Array([KEY_TAB]))
	_bind_keys("journal", PackedInt32Array([KEY_L]))
	_bind_keys("map", PackedInt32Array([KEY_M]))
	_bind_keys("pause", PackedInt32Array([KEY_ESCAPE]))
	_bind_keys("auto_aim", PackedInt32Array([KEY_Q]))
	_bind_keys("use_medical", PackedInt32Array([KEY_R]))
	_bind_keys("quick_save", PackedInt32Array([KEY_F5]))
	_bind_keys("quick_load", PackedInt32Array([KEY_F9]))
	_bind_mouse("attack", MOUSE_BUTTON_LEFT)
	_bind_mouse("interact", MOUSE_BUTTON_RIGHT)


func _bind_keys(action: String, keys: PackedInt32Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = int(k)
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
