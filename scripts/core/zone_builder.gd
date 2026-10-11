class_name ZoneBuilder
extends RefCounted
## Deterministic district builder: terrain, roads, buildings, props, spawns.
## Zone layout follows the design document's 8-zone district map.

const W := 96
const H := 72
enum T { GRASS, DIRT, ROAD, SNOW, CONCRETE, GRAVEL, WOOD, MUD, WATER, ASPHALT, SPORE }

const ZONE_DEFS := [
	{"id": "ranger_outpost", "name": "Ranger Outpost", "rect": Rect2i(2, 2, 18, 14)},
	{"id": "pine_trail", "name": "Old Pine Trail & Roadblock", "rect": Rect2i(22, 2, 18, 14)},
	{"id": "valley_clinic", "name": "Valley Clinic", "rect": Rect2i(42, 2, 18, 16)},
	{"id": "high_school", "name": "Fortified High School", "rect": Rect2i(62, 2, 32, 22)},
	{"id": "timber_mill", "name": "Timber Mill & Workshop", "rect": Rect2i(2, 18, 22, 22)},
	{"id": "ridge_repair", "name": "Ridge Auto Repair", "rect": Rect2i(26, 18, 16, 14)},
	{"id": "substation_chapel", "name": "Hydro Substation & Chapel", "rect": Rect2i(44, 20, 18, 18)},
	{"id": "relay_peak", "name": "Military Relay Peak", "rect": Rect2i(64, 26, 30, 22)},
	{"id": "spore_hollows", "name": "Deep Timber Reserve", "rect": Rect2i(28, 42, 32, 24)},
]

const BUILDINGS := [
	{"name": "cabin", "rect": Rect2i(6, 5, 8, 6), "floor": T.WOOD, "doors": [Vector2i(9, 11)]},
	{"name": "trail_cabin", "rect": Rect2i(24, 4, 6, 5), "floor": T.WOOD, "doors": [Vector2i(26, 9)]},
	{"name": "clinic", "rect": Rect2i(46, 5, 10, 8), "floor": T.CONCRETE, "doors": [Vector2i(51, 13)]},
	{"name": "school", "rect": Rect2i(66, 6, 16, 10), "floor": T.CONCRETE, "doors": [Vector2i(73, 16), Vector2i(76, 16)]},
	{"name": "mill", "rect": Rect2i(5, 21, 12, 8), "floor": T.WOOD, "doors": [Vector2i(10, 29)]},
	{"name": "workshop", "rect": Rect2i(6, 31, 8, 5), "floor": T.WOOD, "doors": [Vector2i(9, 36)]},
	{"name": "garage", "rect": Rect2i(29, 21, 9, 7), "floor": T.CONCRETE, "doors": [Vector2i(33, 28)]},
	{"name": "substation", "rect": Rect2i(47, 23, 7, 6), "floor": T.CONCRETE, "doors": [Vector2i(50, 29)]},
	{"name": "chapel", "rect": Rect2i(55, 23, 6, 8), "floor": T.WOOD, "doors": [Vector2i(57, 31)]},
	{"name": "relay_base", "rect": Rect2i(70, 30, 8, 7), "floor": T.CONCRETE, "doors": [Vector2i(73, 37)]},
]

var terrain: Dictionary = {}
var blocked: Dictionary = {}
var props: Array = []
var interactables: Array = []
var enemy_spawns: Array = []
var npc_spawns: Array = []
var zones: Array = []
var player_start := Vector2.ZERO
var rng := RandomNumberGenerator.new()


func build(seed_value: int = 20261104) -> void:
	rng.seed = seed_value
	_fill_base()
	_roads()
	_buildings()
	_forest()
	_register_zones()
	_place_props()
	_place_interactables()
	_place_spawns()
	player_start = Iso.cell_to_world(Vector2i(11, 12))


func zone_at(cell: Vector2i) -> String:
	for z in zones:
		if Rect2i(z["rect"]).has_point(cell):
			return String(z["id"])
	return "wilderness"


func _fill_base() -> void:
	for y in range(H):
		for x in range(W):
			terrain[Vector2i(x, y)] = T.GRASS


func _roads() -> void:
	for x in range(2, W - 2):
		for y in range(16, 18):
			terrain[Vector2i(x, y)] = T.ROAD
	for y in range(2, H - 2):
		for x in range(36, 38):
			terrain[Vector2i(x, y)] = T.ROAD
	for y in range(2, 46):
		for x in range(60, 62):
			terrain[Vector2i(x, y)] = T.ROAD
	for x in range(62, 94):
		for y in range(24, 26):
			terrain[Vector2i(x, y)] = T.ASPHALT


func _buildings() -> void:
	for b in BUILDINGS:
		var r: Rect2i = b["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				terrain[c] = int(b["floor"])
				blocked.erase(c)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
					blocked[c] = true
					props.append({"kind": "wall", "cell": c})
		for door in b["doors"]:
			blocked.erase(door)
			_remove_prop(door)
			interactables.append({
				"kind": "door", "cell": door, "id": String(b["name"]) + "_door",
				"label": "Open / Close", "sets_flag": String(b["name"]) + "_opened",
			})


func _remove_prop(cell: Vector2i) -> void:
	for i in range(props.size() - 1, -1, -1):
		if Vector2i(props[i]["cell"]) == cell:
			props.remove_at(i)


func _forest() -> void:
	for y in range(H):
		for x in range(W):
			var c := Vector2i(x, y)
			if blocked.has(c):
				continue
			var t := int(terrain[c])
			if t == T.ROAD or t == T.ASPHALT or t == T.CONCRETE or t == T.WOOD:
				continue
			var roll := _noise_roll(x, y)
			if roll > 0.86:
				blocked[c] = true
				props.append({"kind": "pine", "cell": c})
			elif roll < 0.06:
				terrain[c] = T.DIRT


func _noise_roll(x: int, y: int) -> float:
	var v := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
	return absf(v - floorf(v))


func _register_zones() -> void:
	for z in ZONE_DEFS:
		zones.append({"id": z["id"], "name": z["name"], "rect": z["rect"]})


func _place_props() -> void:
	# school soccer field + roadblock barricades + spore hollows floor
	for y in range(18, 24):
		for x in range(66, 78):
			terrain[Vector2i(x, y)] = T.CONCRETE
	for i in range(6):
		var c := Vector2i(32 + i, 8)
		if not blocked.has(c):
			blocked[c] = true
			props.append({"kind": "barricade", "cell": c})
	for y in range(42, 66):
		for x in range(28, 60):
			if _noise_roll(x + 3, y + 7) > 0.55:
				terrain[Vector2i(x, y)] = T.SPORE
	for y in range(42, 66):
		for x in range(28, 60):
			if _noise_roll(x, y) > 0.9:
				terrain[Vector2i(x, y)] = T.WATER
				blocked[Vector2i(x, y)] = true


func _place_interactables() -> void:
	interactables.append({"kind": "container", "cell": Vector2i(7, 6), "id": "outpost_cache",
		"label": "Search emergency kit", "loot": "outpost_cabin", "quest_target": "outpost_cache"})
	interactables.append({"kind": "container", "cell": Vector2i(12, 9), "id": "outpost_locker",
		"label": "Search locker", "loot": "outpost_cabin"})
	interactables.append({"kind": "bed", "cell": Vector2i(8, 9), "id": "cabin_bed", "label": "Rest (advance time)"})
	interactables.append({"kind": "campfire", "cell": Vector2i(14, 13), "id": "outpost_fire",
		"label": "Light campfire (warmth / rest)"})
	interactables.append({"kind": "container", "cell": Vector2i(25, 6), "id": "store_shelves",
		"label": "Raid the General Store", "loot": "general_store"})
	interactables.append({"kind": "container", "cell": Vector2i(48, 7), "id": "clinic_supplies",
		"label": "Search medical supplies", "loot": "clinic_supplies", "quest_target": "clinic_supplies"})
	interactables.append({"kind": "workbench", "cell": Vector2i(52, 9), "id": "clinic_bench", "label": "Use workbench"})
	interactables.append({"kind": "purifier", "cell": Vector2i(54, 7), "id": "clinic_purifier",
		"label": "Draw purified water"})
	interactables.append({"kind": "container", "cell": Vector2i(70, 8), "id": "school_armory",
		"label": "Search ration store", "loot": "military_cache"})
	interactables.append({"kind": "container", "cell": Vector2i(7, 23), "id": "mill_scrap",
		"label": "Salvage scrap", "loot": "workshop_scrap"})
	interactables.append({"kind": "workbench", "cell": Vector2i(9, 33), "id": "workshop_bench",
		"label": "Workbench & forge", "station": "forge"})
	interactables.append({"kind": "generator", "cell": Vector2i(49, 25), "id": "substation_generator",
		"label": "Repair backup generator", "quest_target": "generator",
		"requires": {"spark_plug": 1, "fuel_canister": 1}})
	interactables.append({"kind": "campfire", "cell": Vector2i(57, 28), "id": "chapel_fire",
		"label": "Sanctuary fire (morale)"})
	interactables.append({"kind": "container", "cell": Vector2i(31, 23), "id": "garage_tools",
		"label": "Search tool chests", "loot": "workshop_scrap"})
	interactables.append({"kind": "broadcast", "cell": Vector2i(72, 32), "id": "relay_broadcast",
		"label": "Intercept military broadcast", "quest_target": "broadcast"})
	interactables.append({"kind": "relay", "cell": Vector2i(76, 33), "id": "peak_transponder",
		"label": "Use peak transponder (final choice)"})
	interactables.append({"kind": "mycelium", "cell": Vector2i(44, 54), "id": "primordial_core",
		"label": "Harvest Primordial Mycelium Core", "quest_target": "core",
		"loot": "forest_floor"})
	interactables.append({"kind": "container", "cell": Vector2i(34, 48), "id": "forest_cache",
		"label": "Forage the forest floor", "loot": "forest_floor"})


func _place_spawns() -> void:
	var dens := {
		"ranger_outpost": 2, "pine_trail": 4, "valley_clinic": 4, "high_school": 5,
		"timber_mill": 4, "ridge_repair": 3, "substation_chapel": 3,
		"relay_peak": 4, "spore_hollows": 7, "wilderness": 8,
	}
	for z in zones:
		var r: Rect2i = z["rect"]
		for i in range(int(dens.get(String(z["id"]), 2))):
			var c := Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 2),
				rng.randi_range(r.position.y + 1, r.end.y - 2))
			if blocked.has(c):
				continue
			var kind := "shambler"
			if String(z["id"]) == "spore_hollows":
				kind = "sprinter" if i % 2 == 0 else "shambler"
			if String(z["id"]) == "relay_peak" and i == 0:
				kind = "hulk"
			enemy_spawns.append({"kind": kind, "cell": c, "id": "%s_%d" % [z["id"], i]})
	for n in DataLibrary.all_of("npcs"):
		var zid := String(n.home_zone)
		for z in zones:
			if String(z["id"]) == zid:
				var r: Rect2i = z["rect"]
				npc_spawns.append({"id": String(n.id), "cell": r.get_center()})
	# Caleb roams the pine trail at start
	npc_spawns.append({"id": "caleb", "cell": Vector2i(30, 12)})
