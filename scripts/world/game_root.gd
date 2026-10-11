class_name GameRoot
extends Node2D

const INTERACTABLE_SCENE := preload("res://scenes/interactable.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const NPC_SCENE := preload("res://scenes/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var builder: ZoneBuilder
var tilemap: TileMapLayer
var entity_layer: Node2D
var collision_body: StaticBody2D
var fog: FogOfWar
var noise: NoiseSystem
var fx: FxLayer
var player: Player
var world_modulate: CanvasModulate
var current_zone := ""
var weather_timer := 0.0

@onready var ui: UiRoot = $UI


func _ready() -> void:
	AudioManager.set_context(self)
	builder = ZoneBuilder.new()
	builder.build()
	_build_terrain()
	_build_nav()
	_build_collision()
	_build_entities()
	_build_fx()
	_connect()
	GameState.session_started = true
	AudioManager.start_ambient()
	AudioManager.set_weather_mix(GameState.weather)
	current_zone = builder.zone_at(Iso.world_to_cell(player.global_position))
	GameState.notify_event("visit", builder.zone_at(Iso.world_to_cell(player.position)))
	EventBus.say("Blackwood Valley - Quarantine Zone 4", Color(0.95, 0.85, 0.6))


func _build_terrain() -> void:
	tilemap = TileMapLayer.new()
	tilemap.name = "Terrain"
	tilemap.tile_set = AssetFactory.tileset()
	add_child(tilemap)
	for cell in builder.terrain:
		tilemap.set_cell(cell, 0, Vector2i(int(builder.terrain[cell]), 0))
	world_modulate = CanvasModulate.new()
	world_modulate.name = "DayNight"
	add_child(world_modulate)


func _build_nav() -> void:
	var region := NavigationRegion2D.new()
	region.name = "NavRegion"
	var poly := NavigationPolygon.new()
	poly.add_outline(PackedVector2Array([
		Vector2(-500, -500), Vector2(4200, -500), Vector2(4200, 4200), Vector2(-500, 4200)]))
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	add_child(region)


func _build_collision() -> void:
	collision_body = StaticBody2D.new()
	collision_body.name = "Collision"
	add_child(collision_body)
	for cell in builder.blocked:
		_add_blocker(cell)


func _add_blocker(cell: Vector2i) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(46, 22)
	shape.shape = rect
	shape.position = Iso.cell_to_world(cell) + Vector2(0, 2)
	collision_body.add_child(shape)


func block_cell(cell: Vector2i, kind: String = "barricade") -> void:
	if builder.blocked.has(cell):
		return
	builder.blocked[cell] = true
	_add_blocker(cell)
	var s := Sprite2D.new()
	s.texture = AssetFactory.texture(kind)
	s.position = Iso.cell_to_world(cell) + Vector2(0, -22)
	entity_layer.add_child(s)
	if fog != null:
		fog.blocker_lookup[cell] = true


func _build_entities() -> void:
	entity_layer = Node2D.new()
	entity_layer.name = "Entities"
	entity_layer.y_sort_enabled = true
	add_child(entity_layer)

	for prop in builder.props:
		var s := Sprite2D.new()
		s.texture = AssetFactory.texture(String(prop["kind"]))
		s.position = Iso.cell_to_world(Vector2i(prop["cell"])) + Vector2(0, -22)
		entity_layer.add_child(s)

	for d in builder.interactables:
		var n := INTERACTABLE_SCENE.instantiate()
		entity_layer.add_child(n)
		n.setup(d)

	var spawned: Dictionary = {}
	for d in builder.enemy_spawns:
		if spawned.has(String(d["id"])):
			continue
		spawned[String(d["id"])] = true
		var e := ENEMY_SCENE.instantiate()
		entity_layer.add_child(e)
		e.global_position = Iso.cell_to_world(Vector2i(d["cell"]))
		e.setup(DataLibrary.get_enemy(String(d["kind"])), String(d["id"]))
		if GameState.dead_enemies.has(String(d["id"])):
			e.queue_free()

	spawned.clear()
	for d in builder.npc_spawns:
		if spawned.has(String(d["id"])):
			continue
		spawned[String(d["id"])] = true
		var n := NPC_SCENE.instantiate()
		entity_layer.add_child(n)
		n.global_position = Iso.cell_to_world(Vector2i(d["cell"]))
		n.setup(DataLibrary.get_npc(String(d["id"])))

	player = PLAYER_SCENE.instantiate()
	entity_layer.add_child(player)
	player.global_position = builder.player_start
	player.world = self


func _build_fx() -> void:
	fog = FogOfWar.new()
	fog.name = "FogOfWar"
	fog.configure(builder.blocked)
	add_child(fog)
	noise = NoiseSystem.new()
	noise.name = "Noise"
	add_child(noise)
	fx = FxLayer.new()
	fx.name = "Fx"
	fx.z_index = 60
	add_child(fx)
	player.noise_system = noise
	player.fx = fx
	fx.set_weather(GameState.weather)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.configure(builder.blocked)


func _connect() -> void:
	EventBus.quest_updated.connect(func(_id): SaveManager.save_game(0))
	EventBus.player_died.connect(func(): AudioManager.play("hurt", -2.0))
	EventBus.weather_changed.connect(func(w): fx.set_weather(w))


func _process(delta: float) -> void:
	if player == null:
		return
	weather_timer += delta
	if weather_timer > 170.0:
		weather_timer = 0.0
		_change_weather()
	var cell := Iso.world_to_cell(player.global_position)
	fog.update_visibility(cell)
	var zid := builder.zone_at(cell)
	if zid != current_zone:
		current_zone = zid
		GameState.zone_id = zid
		EventBus.zone_changed.emit(zid)
		GameState.notify_event("visit", zid)
		EventBus.say("Entering %s" % _zone_name(zid), Color(0.8, 0.9, 1.0))
		SaveManager.save_game(0)
	_update_day_night()


func _zone_name(zid: String) -> String:
	for z in builder.zones:
		if String(z["id"]) == zid:
			return String(z["name"])
	return "The Wilderness"


func _change_weather() -> void:
	var kinds := ["clear", "freezing_rain", "blizzard", "spore_fog"]
	var w := kinds[randi_range(0, kinds.size() - 1)]
	GameState.weather = w
	EventBus.weather_changed.emit(w)
	EventBus.say("Weather turning: %s" % w.replace("_", " "), Color(0.75, 0.85, 1.0))


func _update_day_night() -> void:
	var h := float(GameState.hour)
	var light := 1.0
	if h < 6.0 or h > 20.0:
		light = 0.42
	elif h < 8.0:
		light = lerpf(0.42, 1.0, (h - 6.0) / 2.0)
	elif h > 18.0:
		light = lerpf(1.0, 0.42, (h - 18.0) / 2.0)
	world_modulate.color = Color(light, light * 0.98, light * 0.95, 1.0)
