extends Node
## Central run state: survival stats, inventory, quests, factions, world clock.

const SCHEMA_VERSION := 3
const HOURS_PER_SECOND := 0.02
const AMBIENT_TEMP := {"clear": 4.0, "freezing_rain": -3.0, "blizzard": -14.0, "spore_fog": 1.0}

const START_KIT := {
	"ranger": ["hunting_knife", "flashlight", "bandage", "canned_beans", "clean_water", "herbs"],
	"paramedic": ["hunting_knife", "flashlight", "bandage", "painkillers", "canned_beans", "cloth_scrap"],
	"carpenter": ["claw_hammer", "wood_plank", "nails", "flashlight", "bandage", "canned_beans"],
	"machinist": ["pipe_wrench", "spark_plug", "scrap_metal", "flashlight", "bandage", "canned_beans"],
}
const START_WEAPON := {
	"ranger": "hunting_knife", "paramedic": "hunting_knife",
	"carpenter": "claw_hammer", "machinist": "pipe_wrench",
}

var session_started := false
var origin := "machinist"
var stats: Dictionary = {}
var inventory: Array = []
var equipment: Dictionary = {}
var day := 1
var hour := 7.0
var weather := "clear"
var zone_id := "ranger_outpost"
var flags: Dictionary = {}
var active_quests: Array = []
var completed_quests: Array = []
var quest_progress: Dictionary = {}
var npc_memory: Dictionary = {}
var faction_rep: Dictionary = {}
var opened_containers: Array = []
var activated_objects: Array = []
var dead_enemies: Array = []
var player_position := Vector2.ZERO
var play_time := 0.0
var kills := 0
var is_dead := false
var auto_aim := true
var touch_ui := true


func _ready() -> void:
	reset_run("machinist")


func reset_run(new_origin: String = "machinist") -> void:
	origin = new_origin
	stats = {
		"health": 100.0, "max_health": 100.0, "stamina": 100.0, "max_stamina": 100.0,
		"hunger": 88.0, "thirst": 88.0, "fatigue": 92.0, "body_temp": 37.0,
		"infection": 0.0, "mental": 80.0, "bleeding": 0.0,
	}
	inventory = []
	equipment = {"melee": "", "ranged": "", "armor": "", "bag": "canvas_bag", "light": "flashlight"}
	day = 1
	hour = 7.0
	weather = "clear"
	zone_id = "ranger_outpost"
	flags = {}
	active_quests = []
	completed_quests = []
	quest_progress = {}
	npc_memory = {}
	faction_rep = {"valley_watch": 0.0, "bio_research": 0.0, "ridge_scavengers": 0.0}
	opened_containers = []
	activated_objects = []
	dead_enemies = []
	play_time = 0.0
	kills = 0
	is_dead = false
	player_position = Vector2.ZERO
	for id in START_KIT.get(origin, []):
		add_item(id, 1)
	equipment["melee"] = String(START_WEAPON.get(origin, "pipe_wrench"))
	start_quest("beat_01")


# ---------- clock, weather, survival ----------

func advance_clock(delta: float) -> void:
	hour += delta * HOURS_PER_SECOND
	play_time += delta
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		EventBus.time_changed.emit(day, hour)


func tick_survival(delta: float) -> void:
	var strain := 1.4 if stats["stamina"] < 20.0 else 1.0
	stats["hunger"] = clampf(stats["hunger"] - delta * 0.055 * strain, 0.0, 100.0)
	stats["thirst"] = clampf(stats["thirst"] - delta * 0.085 * strain, 0.0, 100.0)
	stats["fatigue"] = clampf(stats["fatigue"] - delta * 0.03, 0.0, 100.0)
	var ambient: float = AMBIENT_TEMP.get(weather, 4.0)
	var warmth: float = _equipped_warmth()
	stats["body_temp"] = clampf(
		stats["body_temp"] + (ambient + warmth - 20.0) * delta * 0.012, 26.0, 40.0)
	if stats["infection"] > 0.0:
		stats["infection"] = clampf(stats["infection"] + delta * 0.012, 0.0, 100.0)
	if stats["bleeding"] > 0.0:
		stats["health"] = clampf(stats["health"] - delta * stats["bleeding"] * 0.35, 0.0, stats["max_health"])
		stats["bleeding"] = clampf(stats["bleeding"] - delta * 0.05, 0.0, 5.0)
	if stats["hunger"] <= 0.0 or stats["thirst"] <= 0.0:
		stats["health"] = clampf(stats["health"] - delta * 1.2, 0.0, stats["max_health"])
	if stats["body_temp"] < 32.0:
		stats["health"] = clampf(stats["health"] - delta * 0.8, 0.0, stats["max_health"])
	if stats["infection"] >= 100.0:
		stats["health"] = clampf(stats["health"] - delta * 2.0, 0.0, stats["max_health"])
	if stats["health"] <= 0.0 and not is_dead:
		is_dead = true
		EventBus.player_died.emit()
	EventBus.stats_changed.emit()


func _equipped_warmth() -> float:
	var total := 0.0
	for slot in ["armor"]:
		var id := String(equipment.get(slot, ""))
		if id == "":
			continue
		var it = DataLibrary.get_item(id)
		if it != null:
			total += float(it.warmth)
	return total


func rest(hours: float) -> void:
	advance_clock(hours * 3600.0 / 50.0)
	stats["fatigue"] = clampf(stats["fatigue"] + hours * 18.0, 0.0, 100.0)
	stats["health"] = clampf(stats["health"] + hours * 3.0, 0.0, stats["max_health"])
	stats["body_temp"] = clampf(stats["body_temp"] + hours * 1.2, 0.0, 40.0)
	EventBus.say("You rest for %d hours." % int(hours), Color(0.7, 0.85, 0.7))
	EventBus.request_save.emit()


# ---------- inventory ----------

func add_item(id: String, count: int = 1) -> bool:
	if id == "" or count <= 0:
		return false
	var def = DataLibrary.get_item(id)
	if def == null:
		push_warning("Unknown item id: " + id)
		return false
	if int(def.stack_size) > 1:
		for entry in inventory:
			if String(entry["id"]) == id and int(entry["count"]) < int(def.stack_size):
				entry["count"] = int(entry["count"]) + count
				EventBus.inventory_changed.emit()
				notify_event("item", id, count)
				return true
	inventory.append({"id": id, "count": count, "durability": 1.0})
	EventBus.inventory_changed.emit()
	notify_event("item", id, count)
	return true


func remove_item(id: String, count: int = 1) -> bool:
	var need := count
	for i in range(inventory.size() - 1, -1, -1):
		var entry: Dictionary = inventory[i]
		if String(entry["id"]) != id:
			continue
		var take: int = min(int(entry["count"]), need)
		entry["count"] = int(entry["count"]) - take
		need -= take
		if int(entry["count"]) <= 0:
			inventory.remove_at(i)
		if need <= 0:
			EventBus.inventory_changed.emit()
			return true
	EventBus.inventory_changed.emit()
	return need <= 0


func count_item(id: String) -> int:
	var total := 0
	for entry in inventory:
		if String(entry["id"]) == id:
			total += int(entry["count"])
	return total


func has_item(id: String) -> bool:
	return count_item(id) > 0


func use_item(id: String) -> void:
	var def = DataLibrary.get_item(id)
	if def == null or not has_item(id):
		return
	if float(def.heal_health) != 0.0:
		stats["health"] = clampf(stats["health"] + def.heal_health, 0.0, stats["max_health"])
	if float(def.heal_infection) != 0.0:
		stats["infection"] = clampf(stats["infection"] - def.heal_infection, 0.0, 100.0)
	if float(def.nutrition) != 0.0:
		stats["hunger"] = clampf(stats["hunger"] + def.nutrition, 0.0, 100.0)
	if float(def.hydration) != 0.0:
		stats["thirst"] = clampf(stats["thirst"] + def.hydration, 0.0, 100.0)
	if float(def.warmth) != 0.0:
		stats["body_temp"] = clampf(stats["body_temp"] + def.warmth, 26.0, 40.0)
	if float(def.mental) != 0.0:
		stats["mental"] = clampf(stats["mental"] + def.mental, 0.0, 100.0)
	if float(def.stamina_restore) != 0.0:
		stats["stamina"] = clampf(stats["stamina"] + def.stamina_restore, 0.0, stats["max_stamina"])
	stats["bleeding"] = 0.0 if float(def.stop_bleeding) > 0.0 else stats["bleeding"]
	remove_item(id, 1)
	EventBus.say("Used %s." % DataLibrary.item_name(id))
	AudioManager.play("pickup")
	EventBus.stats_changed.emit()


func get_weapon() -> Variant:
	var ranged := String(equipment.get("ranged", ""))
	if ranged != "" and count_item("ammo_38") > 0:
		return DataLibrary.get_item(ranged)
	return DataLibrary.get_item(String(equipment.get("melee", "")))


# ---------- flags, quests, factions, npc memory ----------

func set_flag(flag: String, value: bool = true) -> void:
	if bool(flags.get(flag, false)) == value:
		return
	flags[flag] = value
	EventBus.flag_changed.emit(flag, value)
	if value:
		notify_event("flag", flag)   # completes any `type: "flag"` objective


func get_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func change_rep(faction: String, delta: float) -> void:
	faction_rep[faction] = clampf(float(faction_rep.get(faction, 0.0)) + delta, -1.0, 1.0)


func remember(npc_id: String, key: String) -> void:
	var mem: Array = npc_memory.get(npc_id, [])
	if not mem.has(key):
		mem.append(key)
	npc_memory[npc_id] = mem


func has_memory(npc_id: String, key: String) -> bool:
	return npc_memory.get(npc_id, []).has(key)


func start_quest(id: String) -> void:
	if String(_quest_state(id)) != "":
		return
	active_quests.append({"id": id})
	EventBus.quest_updated.emit(id)
	EventBus.say("New objective: %s" % String(DataLibrary.get_quest(id).title), Color(0.95, 0.85, 0.5))


func _quest_state(id: String) -> String:
	for e in active_quests:
		if String(e["id"]) == id:
			return "active"
	for e in completed_quests:
		if String(e["id"]) == id:
			return "completed"
	return ""


func notify_event(kind: String, target: String, amount: int = 1) -> void:
	for entry in active_quests.duplicate():
		var qid := String(entry["id"])
		var def = DataLibrary.get_quest(qid)
		if def == null:
			continue
		var touched := false
		for obj in def.objectives:
			if String(obj.get("type", "")) != kind:
				continue
			if String(obj.get("target", "")) != target:
				continue
			var key := qid + ":" + String(obj.get("id", ""))
			var need := int(obj.get("count", 1))
			var cur := int(quest_progress.get(key, 0))
			if cur >= need:
				continue
			quest_progress[key] = cur + amount
			touched = true
		if touched:
			EventBus.quest_updated.emit(qid)
			_check_quest(qid)


func _check_quest(qid: String) -> void:
	var def = DataLibrary.get_quest(qid)
	if def == null:
		return
	for obj in def.objectives:
		if bool(obj.get("optional", false)):
			continue
		var key := qid + ":" + String(obj.get("id", ""))
		if int(quest_progress.get(key, 0)) < int(obj.get("count", 1)):
			return
	complete_quest(qid)


func complete_quest(qid: String) -> void:
	for i in range(active_quests.size()):
		if String(active_quests[i]["id"]) == qid:
			active_quests.remove_at(i)
			break
	completed_quests.append({"id": qid})
	EventBus.quest_completed.emit(qid)
	var def = DataLibrary.get_quest(qid)
	if def == null:
		return
	EventBus.say("Objective complete: %s" % String(def.title), Color(0.6, 0.9, 0.65))
	if bool(def.is_ending):
		EventBus.ending_reached.emit(String(def.ending_id))
		return
	if String(def.next_quest) != "":
		start_quest(String(def.next_quest))
	EventBus.request_save.emit()


func objective_done(qid: String, obj: Dictionary) -> bool:
	var key := qid + ":" + String(obj.get("id", ""))
	return int(quest_progress.get(key, 0)) >= int(obj.get("count", 1))


func objective_progress(qid: String, obj: Dictionary) -> int:
	return int(quest_progress.get(qid + ":" + String(obj.get("id", "")), 0))


# ---------- endings ----------

func ending_requirement(ending_id: String) -> String:
	## Returns "" when the ending is available, otherwise the reason it is locked.
	match ending_id:
		"extraction":
			if not has_item("military_codes"):
				return "Needs the military encryption codes (ask Jonas Reed)"
		"inoculation":
			if not has_item("mycelium_core"):
				return "Needs the Primordial Mycelium Core"
		"bastion":
			if not (get_flag("trade_deal") and get_flag("trade_deal_mara")):
				return "Needs the Vance-Thorne trade deal (talk to both leaders)"
		_:
			return "Unknown ending"
	return ""


func choose_ending(ending_id: String) -> bool:
	if get_flag("ending_chosen"):
		EventBus.say("The valley's fate is already sealed.")
		return false
	var why := ending_requirement(ending_id)
	if why != "":
		EventBus.say(why, Color(1.0, 0.72, 0.55))
		return false
	set_flag("ending_chosen")
	var qid := "ending_" + ending_id
	start_quest(qid)
	complete_quest(qid)
	return true


# ---------- serialisation ----------

func serialize() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION, "origin": origin, "stats": stats.duplicate(true),
		"inventory": inventory.duplicate(true), "equipment": equipment.duplicate(true),
		"day": day, "hour": hour, "weather": weather, "zone": zone_id,
		"flags": flags.duplicate(true), "active_quests": active_quests.duplicate(true),
		"completed_quests": completed_quests.duplicate(true),
		"quest_progress": quest_progress.duplicate(true),
		"npc_memory": npc_memory.duplicate(true), "faction_rep": faction_rep.duplicate(true),
		"opened": opened_containers.duplicate(), "activated": activated_objects.duplicate(),
		"dead": dead_enemies.duplicate(),
		"position": {"x": player_position.x, "y": player_position.y},
		"play_time": play_time, "kills": kills,
	}


func deserialize(data: Dictionary) -> void:
	if int(data.get("schema", 0)) > SCHEMA_VERSION:
		push_warning("Save schema is newer than this build; loading best effort.")
	origin = String(data.get("origin", "machinist"))
	for k in data.get("stats", {}):
		stats[k] = float(data["stats"][k])
	inventory = data.get("inventory", [])
	equipment = data.get("equipment", equipment)
	day = int(data.get("day", 1))
	hour = float(data.get("hour", 7.0))
	weather = String(data.get("weather", "clear"))
	zone_id = String(data.get("zone", "ranger_outpost"))
	flags = data.get("flags", {})
	active_quests = data.get("active_quests", [])
	completed_quests = data.get("completed_quests", [])
	quest_progress = data.get("quest_progress", {})
	npc_memory = data.get("npc_memory", {})
	faction_rep = data.get("faction_rep", faction_rep)
	opened_containers = data.get("opened", [])
	activated_objects = data.get("activated", [])
	dead_enemies = data.get("dead", [])
	var pos: Dictionary = data.get("position", {"x": 0.0, "y": 0.0})
	player_position = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))
	play_time = float(data.get("play_time", 0.0))
	kills = int(data.get("kills", 0))
	is_dead = false
	EventBus.game_loaded.emit()
