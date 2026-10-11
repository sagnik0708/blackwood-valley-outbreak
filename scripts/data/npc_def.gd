class_name NpcDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var role: String = ""
@export var faction_id: String = ""
@export var home_zone: String = ""
@export var dialogue_id: String = ""
@export var quest_ids: Array = []
@export var schedule: Array = []
@export var needs: Dictionary = {}
@export var is_companion: bool = false
@export var color: Color = Color(0.4, 0.34, 0.42, 1)
