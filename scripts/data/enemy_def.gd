class_name EnemyDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var health: float = 40.0
@export var speed: float = 95.0
@export var damage: float = 9.0
@export var attack_range: float = 44.0
@export var attack_cooldown: float = 1.4
@export var sight_range: float = 330.0
@export var hearing_range: float = 260.0
@export var scent_range: float = 150.0
@export var fov_degrees: float = 110.0
@export var infection_on_hit: float = 3.0
@export var loot_table: String = "zombie_remains"
@export var body_color: Color = Color(0.35, 0.42, 0.3, 1)
@export var eye_color: Color = Color(0.9, 0.35, 0.25, 1)
@export var scale_factor: float = 1.0
