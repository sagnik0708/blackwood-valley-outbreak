class_name NpcAgent
extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite

var def: NpcDef
var home := Vector2.ZERO
var wander_target := Vector2.ZERO
var wait_timer := 2.0
var facing := 0.0


func setup(d: NpcDef) -> void:
	def = d
	if def != null and is_instance_valid(sprite):
		sprite.modulate = def.color


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("interactables")
	home = global_position
	wander_target = home
	sprite.texture = AssetFactory.texture("npc")
	if def != null:
		sprite.modulate = def.color


func _physics_process(delta: float) -> void:
	if def == null:
		return
	wait_timer -= delta
	if global_position.distance_to(wander_target) < 24.0:
		if wait_timer <= 0.0:
			wait_timer = randf_range(2.0, 7.0)
			wander_target = home + Vector2(randf_range(-120, 120), randf_range(-90, 90))
	var dir := (wander_target - global_position).normalized()
	velocity = velocity.move_toward(dir * 42.0, 400.0 * delta)
	move_and_slide()
	if velocity.length() > 4.0:
		facing = velocity.angle()
		sprite.flip_h = cos(facing) < 0.0
	for key in def.needs:
		def.needs[key] = clampf(float(def.needs[key]) - delta * 0.05, 0.0, 100.0)


func interact_label() -> String:
	return "Talk to %s" % String(def.display_name) if def != null else "Talk"


func interact(_player: Node) -> void:
	if def == null:
		return
	GameState.remember(String(def.id), "met")
	GameState.notify_event("talk", String(def.id), 1)
	AudioManager.play("ui", -10.0)
	EventBus.dialogue_started.emit(String(def.id))
