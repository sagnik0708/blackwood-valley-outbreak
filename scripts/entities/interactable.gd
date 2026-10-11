class_name Interactable
extends Node2D

@onready var sprite: Sprite2D = $Sprite

var kind := "container"
var id := ""
var label := "Search"
var loot_table := ""
var quest_target := ""
var sets_flag := ""
var requires: Dictionary = {}
var station := "any"


func setup(d: Dictionary) -> void:
	kind = String(d.get("kind", "container"))
	id = String(d.get("id", "object"))
	label = String(d.get("label", "Use"))
	loot_table = String(d.get("loot", ""))
	quest_target = String(d.get("quest_target", ""))
	sets_flag = String(d.get("sets_flag", ""))
	requires = d.get("requires", {})
	station = String(d.get("station", "any"))
	sprite.texture = AssetFactory.texture(_sprite_key())
	position = Iso.cell_to_world(Vector2i(d.get("cell", Vector2i.ZERO))) + Vector2(0, -22)
	if GameState.opened_containers.has(id) and kind == "container":
		sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)


func _sprite_key() -> String:
	match kind:
		"door": return "door"
		"bed": return "crate"
		"campfire": return "campfire"
		"workbench": return "generator"
		"purifier": return "crate"
		"generator": return "generator"
		"broadcast": return "relay"
		"relay": return "relay"
		"mycelium": return "mycelium"
		"barricade": return "barricade"
		_: return "container"


func interact_label() -> String:
	return label


func interact(player: Node) -> void:
	match kind:
		"door":
			var opened := not GameState.get_flag(sets_flag)
			GameState.set_flag(sets_flag, opened)
			sprite.modulate = Color(1, 1, 1, 0.55) if opened else Color(1, 1, 1, 1)
			AudioManager.play_at("door", global_position, -8.0)
		"container":
			if GameState.opened_containers.has(id):
				EventBus.say("Already searched - nothing left.", Color(0.8, 0.75, 0.7))
				return
			GameState.opened_containers.append(id)
			sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
			AudioManager.play("pickup", -6.0)
			if loot_table != "":
				_roll_loot(loot_table)
			if quest_target != "":
				GameState.notify_event("search", quest_target, 1)
		"bed":
			GameState.rest(6.0)
		"campfire":
			GameState.stats["body_temp"] = 38.0
			GameState.stats["mental"] = clampf(float(GameState.stats["mental"]) + 12.0, 0.0, 100.0)
			GameState.rest(2.0)
			AudioManager.play_at("generator", global_position, -14.0)
		"purifier":
			GameState.add_item("clean_water", 1)
			AudioManager.play("pickup", -6.0)
		"workbench":
			EventBus.panel_toggled.emit("craft")
		"generator":
			var ok := true
			for need in requires:
				if GameState.count_item(String(need)) < int(requires[need]):
					ok = false
			if not ok:
				EventBus.say("Needs spark plug and fuel canister.", Color(1.0, 0.8, 0.5))
				return
			for need in requires:
				GameState.remove_item(String(need), int(requires[need]))
			GameState.set_flag("generator_online", true)
			GameState.notify_event("flag", "generator_online", 1)
			GameState.notify_event("flag", sets_flag, 1)
			AudioManager.play_at("generator", global_position, -6.0)
			EventBus.say("Backup generator online. Power restored.", Color(0.7, 0.95, 0.75))
		"broadcast":
			GameState.set_flag("broadcast_heard", true)
			GameState.notify_event("flag", "broadcast_heard", 1)
			AudioManager.play("beacon", -4.0)
			EventBus.say("Cordon command: thermobaric cleansing strike in 24 hours.", Color(1.0, 0.55, 0.4))
		"relay":
			EventBus.panel_toggled.emit("finale")
		"mycelium":
			if GameState.get_flag("core_harvested"):
				EventBus.say("The mycelium has gone dormant.", Color(0.8, 0.85, 0.7))
				return
			GameState.set_flag("core_harvested", true)
			GameState.add_item("mycelium_core", 1)
			GameState.notify_event("flag", "core_harvested", 1)
			AudioManager.play("pickup", -4.0)
			EventBus.say("Primordial Mycelium Core harvested.", Color(0.75, 0.95, 0.6))
		_:
			EventBus.say("Nothing useful here.", Color(0.8, 0.8, 0.8))


func _roll_loot(table_id: String) -> void:
	var table = DataLibrary.get_loot(table_id)
	if table == null:
		return
	for entry in table.entries:
		var item_id := String(entry.get("item", ""))
		var count := int(randi_range(int(entry.get("min", 1)), int(entry.get("max", 1))))
		if item_id != "" and count > 0:
			GameState.add_item(item_id, count)
			EventBus.say("Found %s x%d" % [DataLibrary.item_name(item_id), count], Color(0.85, 0.9, 0.8))
