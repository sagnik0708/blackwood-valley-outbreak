extends Node
## Global signal hub. Keeps systems decoupled and keeps UI off the simulation.

signal stats_changed
signal inventory_changed
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal flag_changed(flag: String, value: bool)
signal toast(message: String, color: Color)
signal interact_prompt(text: String)
signal dialogue_started(npc_id: String)
signal dialogue_finished(npc_id: String)
signal noise_emitted(position: Vector2, radius: float)
signal player_hurt(amount: float)
signal player_died
signal ending_reached(ending_id: String)
signal game_saved(path: String)
signal game_loaded
signal time_changed(day: int, hour: float)
signal weather_changed(weather: String)
signal zone_changed(zone_id: String)
signal request_save
signal request_load
signal panel_toggled(panel: String)


func say(message: String, color: Color = Color(0.85, 0.88, 0.9)) -> void:
	toast.emit(message, color)
