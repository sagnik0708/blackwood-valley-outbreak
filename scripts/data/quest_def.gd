class_name QuestDef
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var summary: String = ""
@export var act: int = 1
@export var beat: int = 1
@export var objectives: Array = []
@export var next_quest: String = ""
@export var is_ending: bool = false
@export var ending_id: String = ""
