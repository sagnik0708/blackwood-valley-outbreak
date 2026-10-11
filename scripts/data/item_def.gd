class_name ItemDef
extends Resource

enum ItemType { WEAPON_MELEE, WEAPON_RANGED, AMMO, MEDICAL, FOOD, DRINK, TOOL, MATERIAL, CLOTHING, LIGHT, QUEST }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var type: ItemType = ItemType.MATERIAL
@export var stack_size: int = 10
@export var weight: float = 1.0
@export var icon_color: Color = Color(0.7, 0.7, 0.7, 1)
@export var damage: float = 0.0
@export var attack_range: float = 56.0
@export var swing_stamina: float = 8.0
@export var swing_time: float = 0.45
@export var durability_max: float = 0.0
@export var noise: float = 0.2
@export var heal_health: float = 0.0
@export var heal_infection: float = 0.0
@export var stop_bleeding: float = 0.0
@export var nutrition: float = 0.0
@export var hydration: float = 0.0
@export var warmth: float = 0.0
@export var mental: float = 0.0
@export var stamina_restore: float = 0.0
