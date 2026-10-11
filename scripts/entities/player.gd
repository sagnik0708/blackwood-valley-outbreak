class_name Player
extends CharacterBody2D

const BASE_SPEED := 155.0
const SPRINT_SPEED := 245.0
const SNEAK_SPEED := 72.0
const ACCEL := 1400.0

@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera

var facing := -PI * 0.25
var touch_dir := Vector2.ZERO
var touch_sneak := false
var touch_sprint := false
var sneaking := false
var sprinting := false
var attack_timer := 0.0
var step_timer := 0.0
var noise_system: NoiseSystem
var fx: FxLayer
var world: Node = null
var near_interactable: Node = null


func _ready() -> void:
	add_to_group("player")
	sprite.texture = AssetFactory.texture("player_" + GameState.origin)
	camera.limit_left = -400
	camera.limit_top = -400
	camera.limit_right = int(Iso.cell_to_world(Vector2i(ZoneBuilder.W, 0)).x) + 400
	camera.limit_bottom = int(Iso.cell_to_world(Vector2i(0, ZoneBuilder.H)).y) + 400
	if GameState.player_position != Vector2.ZERO:
		global_position = GameState.player_position


func _physics_process(delta: float) -> void:
	if GameState.is_dead:
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_dir.length() > 0.05:
		input = touch_dir
	var moving := input.length() > 0.05
	sneaking = Input.is_action_pressed("sneak") or touch_sneak
	sprinting = (Input.is_action_pressed("sprint") or touch_sprint) \
		and moving and float(GameState.stats["stamina"]) > 5.0

	var speed := BASE_SPEED
	if sneaking:
		speed = SNEAK_SPEED
	elif sprinting:
		speed = SPRINT_SPEED

	var dir := Iso.input_to_world(input)
	velocity = velocity.move_toward(dir * speed, ACCEL * delta)
	move_and_slide()
	GameState.player_position = global_position

	if moving:
		facing = dir.angle()
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.28 if sprinting else 0.42
			var radius := 70.0
			if sneaking:
				radius = 18.0
			elif sprinting:
				radius = 190.0
			if noise_system != null:
				noise_system.emit(global_position, radius)
			AudioManager.play_at("step", global_position, -12.0)
		var drain := 16.0 if sprinting else -12.0
		if sneaking:
			drain = -8.0
		GameState.stats["stamina"] = clampf(
			float(GameState.stats["stamina"]) - delta * drain, 0.0,
			float(GameState.stats["max_stamina"]))
	else:
		GameState.stats["stamina"] = clampf(
			float(GameState.stats["stamina"]) + delta * 15.0, 0.0,
			float(GameState.stats["max_stamina"]))

	GameState.tick_survival(delta)
	GameState.advance_clock(delta)
	_update_interactable()
	sprite.flip_h = cos(facing) < 0.0


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_dead:
		return
	if event.is_action_pressed("attack"):
		_try_attack()
	elif event.is_action_pressed("interact"):
		if near_interactable != null:
			near_interactable.interact(self)
	elif event.is_action_pressed("use_medical"):
		_use_best_medical()


func _update_interactable() -> void:
	var best: Node = null
	var best_d := 78.0
	for n in get_tree().get_nodes_in_group("interactables"):
		if not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	near_interactable = best
	EventBus.interact_prompt.emit(best.interact_label() if best != null else "")


func _try_attack() -> void:
	if attack_timer > 0.0:
		return
	var weapon = GameState.get_weapon()
	var dmg := 12.0
	var reach := 58.0
	var stamina_cost := 9.0
	var noise := 90.0
	var swing := 0.42
	var is_gun := false
	if weapon != null:
		if float(weapon.damage) > 0.0:
			dmg = float(weapon.damage)
		reach = float(weapon.attack_range)
		stamina_cost = float(weapon.swing_stamina)
		swing = float(weapon.swing_time)
		noise = 40.0 + float(weapon.noise) * 300.0
		if String(weapon.id) == "revolver_38" and GameState.count_item("ammo_38") > 0:
			GameState.remove_item("ammo_38", 1)
			is_gun = true
			noise = 900.0
	if float(GameState.stats["stamina"]) < stamina_cost:
		EventBus.say("Too exhausted to fight.", Color(1.0, 0.7, 0.6))
		return
	GameState.stats["stamina"] = clampf(
		float(GameState.stats["stamina"]) - stamina_cost, 0.0,
		float(GameState.stats["max_stamina"]))
	attack_timer = swing
	AudioManager.play_at("gun" if is_gun else "swing", global_position, -6.0)
	if noise_system != null:
		noise_system.emit(global_position, noise)

	var target := _nearest_hostile(reach * 2.2)
	if GameState.auto_aim and target != null:
		facing = (target.global_position - global_position).angle()
	var hit_point := global_position + Vector2(cos(facing), sin(facing)) * reach * 0.6
	var did_hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		if is_gun or e.global_position.distance_to(hit_point) <= reach * 0.85:
			if is_gun and e.global_position.distance_to(global_position) > reach:
				continue
			e.take_damage(dmg, global_position)
			did_hit = true
	if did_hit:
		AudioManager.play_at("hit", global_position, -4.0)
		if fx != null:
			fx.flash_screen(Color(0.95, 0.85, 0.6), 0.12)


func _nearest_hostile(max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _use_best_medical() -> void:
	for id in ["medkit", "bandage", "painkillers", "herbs", "antibiotics"]:
		if GameState.has_item(id):
			GameState.use_item(id)
			return
	EventBus.say("No medical supplies left.", Color(1.0, 0.7, 0.6))


func take_damage(amount: float, from: Vector2, infection: float = 0.0) -> void:
	if GameState.is_dead:
		return
	GameState.stats["health"] = clampf(
		float(GameState.stats["health"]) - amount, 0.0, float(GameState.stats["max_health"]))
	GameState.stats["bleeding"] = clampf(float(GameState.stats["bleeding"]) + amount * 0.02, 0.0, 5.0)
	GameState.stats["infection"] = clampf(float(GameState.stats["infection"]) + infection, 0.0, 100.0)
	EventBus.player_hurt.emit(amount)
	AudioManager.play("hurt", -4.0)
	if fx != null:
		fx.flash_screen(Color(0.85, 0.15, 0.12), 0.35)
	velocity += (global_position - from).normalized() * 90.0
	if float(GameState.stats["health"]) <= 0.0 and not GameState.is_dead:
		GameState.is_dead = true
		EventBus.player_died.emit()


func place_barricade() -> void:
	if world == null:
		return
	var cell := Iso.world_to_cell(global_position + Vector2(cos(facing), sin(facing)) * 52.0)
	world.block_cell(cell, "barricade")
	AudioManager.play_at("craft", global_position, -6.0)
	EventBus.say("Barricade raised.", Color(0.8, 0.9, 0.7))


func set_touch_dir(dir: Vector2) -> void:
	touch_dir = dir.limit_length(1.0)


func set_touch_sneak(on: bool) -> void:
	touch_sneak = on


func set_touch_sprint(on: bool) -> void:
	touch_sprint = on
