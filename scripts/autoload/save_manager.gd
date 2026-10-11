extends Node
## JSON saves through FileAccess into user:// (works in Web and Android exports).

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	EventBus.request_save.connect(func(): save_game(0))
	EventBus.request_load.connect(func(): load_game(0))


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int = 0) -> bool:
	GameState.player_position = GameState.player_position
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Save failed: " + slot_path(slot))
		return false
	var payload := GameState.serialize()
	payload["stamp"] = Time.get_datetime_string_from_system()
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	EventBus.game_saved.emit(slot_path(slot))
	EventBus.say("Game saved (slot %d)." % slot, Color(0.65, 0.85, 1.0))
	return true


func load_game(slot: int = 0) -> bool:
	if not has_save(slot):
		EventBus.say("No save in slot %d." % slot, Color(1.0, 0.7, 0.6))
		return false
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Corrupt save: " + slot_path(slot))
		return false
	GameState.deserialize(parsed)
	GameState.session_started = true
	get_tree().reload_current_scene()
	return true


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


func save_meta(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
