class_name NoiseSystem
extends Node2D
## Visual noise ripples + enemy alerting (stealth core).

var rings: Array = []


func emit(pos: Vector2, radius: float) -> void:
	rings.append({"pos": pos, "radius": radius, "life": 1.0})
	queue_redraw()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= radius:
			e.on_noise(pos)
	EventBus.noise_emitted.emit(pos, radius)


func _process(delta: float) -> void:
	if rings.is_empty():
		return
	var changed := false
	for i in range(rings.size() - 1, -1, -1):
		rings[i]["life"] = float(rings[i]["life"]) - delta * 1.1
		if float(rings[i]["life"]) <= 0.0:
			rings.remove_at(i)
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	for r in rings:
		var life := float(r["life"])
		var t := 1.0 - life
		draw_arc(Vector2(r["pos"]), float(r["radius"]) * (0.3 + 0.7 * t), 0.0, TAU, 48,
			Color(1.0, 0.86, 0.45, 0.4 * life), 3.0)
