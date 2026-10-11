extends Node
## Loads the .tres data packs and indexes every entry by `id`.

const PACK_PATHS := {
	"items": "res://data/items.tres",
	"recipes": "res://data/recipes.tres",
	"loot": "res://data/loot_tables.tres",
	"enemies": "res://data/enemies.tres",
	"npcs": "res://data/npcs.tres",
	"factions": "res://data/factions.tres",
	"quests": "res://data/quests.tres",
	"dialogue": "res://data/dialogue.tres",
}

var index: Dictionary = {}


func _ready() -> void:
	for kind in PACK_PATHS:
		var table: Dictionary = {}
		var pack: Variant = load(PACK_PATHS[kind])
		if pack == null:
			push_warning("DataLibrary: missing pack '%s'" % kind)
		else:
			for entry in pack.entries:
				table[String(entry.id)] = entry
		index[kind] = table


func get_entry(kind: String, id: String) -> Variant:
	return index.get(kind, {}).get(id, null)


func get_item(id: String) -> Variant: return get_entry("items", id)
func get_recipe(id: String) -> Variant: return get_entry("recipes", id)
func get_loot(id: String) -> Variant: return get_entry("loot", id)
func get_enemy(id: String) -> Variant: return get_entry("enemies", id)
func get_npc(id: String) -> Variant: return get_entry("npcs", id)
func get_faction(id: String) -> Variant: return get_entry("factions", id)
func get_quest(id: String) -> Variant: return get_entry("quests", id)
func get_dialogue(id: String) -> Variant: return get_entry("dialogue", id)


func all_of(kind: String) -> Array:
	return index.get(kind, {}).values()


func item_name(id: String) -> String:
	var it = get_item(id)
	return String(it.display_name) if it != null else id
