class_name Enemy
extends CharacterBody2D

enum State { PATROL, INVESTIGATE, CHASE, ATTACK, DEAD }

@onready var sprite: Sprite2D = $Sprite
@onready var nav: NavigationAgent2D = $NavigationAgent2D

var def: EnemyDef
var spawn_id := ""
var state: int = State.PATROL
var health := 40.0
var dead := false
var facing := 0.0
var home := Vector2.ZERO
var patrol_target := Vector2.ZERO
var interest := Vector2.ZERO
var attack_timer := 0.0
var lost_timer := 0.0
var growl_timer := 4.0
var blocked_lookup: Dictionary = {}


func setup(enemy_def: EnemyDef, id: String) -> void:
	def = enemy_def
	spawn_id = id
	health = float(def.health)


func _ready() -> void:
	add_to_group("enemies")
	home = global_position
	patrol_target = home
	if def == null:
		def = DataLibrary.get_enemy("shambler")
		health = float(def.health)
	sprite.texture = AssetFactory.texture(String(def.id))
	sprite.scale = Vector2.ONE * float(def.scale_factor)


func configure(blocked: Dictionary) -> void:
	blocked_lookup = blocked


func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	growl_timer -= delta
	if growl_timer <= 0.0:
		growl_timer = randf_range(7.0, 16.0)
		AudioManager.play_at("zombie", global_position, -11.0)
	var target := get_tree().get_first_node_in_group("player")
	match state:
		State.PATROL:
			_do_patrol(delta)
			if _can_see(target):
				_alert()
		State.INVESTIGATE:
			_move_toward(interest, float(def.speed) * 0.75, delta)
			if global_position.distance_to(interest) < 42.0:
				state = State.PATROL
				patrol_target = _random_patrol_point()
			if _can_see(target):
				_alert()
		State.CHASE:
			if target == null:
				state = State.PATROL
				return
			interest = target.global_position
			if _can_see(target):
				lost_timer = 0.0
			else:
				lost_timer += delta
			if lost_timer > 6.0:
				state = State.INVESTIGATE
			_move_toward(target.global_position, float(def.speed), delta)
			if global_position.distance_to(target.global_position) <= float(def.attack_range):
				state = State.ATTACK
		State.ATTACK:
			if target == null:
				state = State.PATROL
				return
			facing = (target.global_position - global_position).angle()
			sprite.flip_h = cos(facing) < 0.0
			if global_position.distance_to(target.global_position) > float(def.attack_range) * 1.35:
				state = State.CHASE
			elif attack_timer <= 0.0:
				attack_timer = float(def.attack_cooldown)
				target.take_damage(float(def.damage), global_position, float(def.infection_on_hit))
				AudioManager.play_at("hit", global_position, -6.0)


func _do_patrol(delta: float) -> void:
	if global_position.distance_to(patrol_target) < 30.0:
		patrol_target = _random_patrol_point()
	_move_toward(patrol_target, float(def.speed) * 0.45, delta)


func _random_patrol_point() -> Vector2:
	return home + Vector2(randf_range(-160, 160), randf_range(-120, 120))


func _move_toward(to: Vector2, speed: float, delta: float) -> void:
	nav.target_position = to
	var next := nav.get_next_path_position()
	if next == Vector2.ZERO:
		next = to
	var dir := (next - global_position).normalized()
	velocity = velocity.move_toward(dir * speed, 900.0 * delta)
	move_and_slide()
	if velocity.length() > 4.0:
		facing = velocity.angle()
		sprite.flip_h = cos(facing) < 0.0


func _alert() -> void:
	state = State.CHASE
	lost_timer = 0.0
	AudioManager.play_at("zombie", global_position, -4.0)


func _can_see(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var to: Vector2 = target.global_position - global_position
	var dist := to.length()
	if dist > float(def.sight_range):
		return dist < float(def.scent_range) and float(GameState.stats["infection"]) > 25.0
	if dist > 60.0:
		var ang := absf(wrapf(to.angle() - facing, -PI, PI))
		if ang > deg_to_rad(float(def.fov_degrees) * 0.5):
			return false
	return _line_clear(global_position, target.global_position)


func _line_clear(from: Vector2, to: Vector2) -> bool:
	var steps := int(from.distance_to(to) / 24.0)
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var c := Iso.world_to_cell(from.lerp(to, t))
		if blocked_lookup.get(c, false):
			return false
	return true


func on_noise(pos: Vector2) -> void:
	if dead:
		return
	if global_position.distance_to(pos) > float(def.hearing_range):
		return
	interest = pos
	if state != State.CHASE and state != State.ATTACK:
		state = State.INVESTIGATE


func take_damage(amount: float, from: Vector2) -> void:
	if dead:
		return
	health -= amount
	AudioManager.play_at("hit", global_position, -6.0)
	velocity += (global_position - from).normalized() * 60.0
	if health <= 0.0:
		_die()
	else:
		interest = from
		if state != State.CHASE and state != State.ATTACK:
			state = State.INVESTIGATE


func _die() -> void:
	dead = true
	state = State.DEAD
	GameState.kills += 1
	GameState.dead_enemies.append(spawn_id)
	GameState.notify_event("kill", String(def.id), 1)
	AudioManager.play_at("zombie", global_position, -8.0)
	var table = DataLibrary.get_loot(String(def.loot_table))
	if table != null:
		for entry in table.entries:
			var id := String(entry.get("item", ""))
			var count := int(entry.get("min", 1))
			if id != "" and count > 0:
				GameState.add_item(id, count)
				EventBus.say("Recovered %s x%d" % [DataLibrary.item_name(id), count],
					Color(0.75, 0.85, 0.7))
	modulate = Color(0.45, 0.45, 0.45, 0.9)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	get_tree().create_timer(25.0).timeout.connect(queue_free)
