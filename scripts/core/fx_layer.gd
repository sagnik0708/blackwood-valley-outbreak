class_name FxLayer
extends Node2D
## Weather particles, screen flash and vignette - all drawn, no textures.

var weather := "clear"
var particles: Array = []
var flash := 0.0
var flash_color := Color(0.8, 0.2, 0.15)
var rng := RandomNumberGenerator.new()
var _spawn_acc := 0.0


func set_weather(kind: String) -> void:
	weather = kind
	particles.clear()
	queue_redraw()


func flash_screen(color: Color, strength: float = 0.5) -> void:
	flash_color = color
	flash = maxf(flash, strength)


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	var cam := Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		cam = player.global_position
	var rate := 0.0
	match weather:
		"freezing_rain": rate = 220.0
		"blizzard": rate = 320.0
		"spore_fog": rate = 60.0
	_spawn_acc += rate * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		particles.append({
			"pos": cam + Vector2(rng.randf_range(-view.x, view.x) * 0.6, -view.y * 0.6),
			"vel": Vector2(rng.randf_range(-40, 40), rng.randf_range(160, 320)),
			"size": rng.randf_range(1.5, 4.0),
		})
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		var pos: Vector2 = p["pos"] + Vector2(p["vel"]) * delta
		if pos.y > cam.y + view.y * 0.7:
			particles.remove_at(i)
			continue
		p["pos"] = pos
	if flash > 0.0:
		flash = maxf(flash - delta * 1.6, 0.0)
	queue_redraw()


func _draw() -> void:
	if weather == "blizzard":
		draw_rect(Rect2(-2000, -2000, 4000, 4000), Color(0.75, 0.82, 0.88, 0.14))
	if weather == "spore_fog":
		draw_rect(Rect2(-2000, -2000, 4000, 4000), Color(0.55, 0.62, 0.3, 0.12))
	for p in particles:
		var pos: Vector2 = p["pos"]
		var s: float = p["size"]
		if weather == "freezing_rain":
			draw_line(pos, pos + Vector2(-6, 18), Color(0.75, 0.85, 0.95, 0.5), 1.4)
		elif weather == "blizzard":
			draw_line(pos, pos + Vector2(-14, 12), Color(0.92, 0.95, 1.0, 0.65), 1.8)
		else:
			draw_circle(pos, s, Color(0.75, 0.9, 0.55, 0.35))
	if flash > 0.0:
		draw_rect(Rect2(-4000, -4000, 8000, 8000), Color(flash_color, flash * 0.35))
