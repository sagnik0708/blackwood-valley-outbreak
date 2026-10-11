class_name FogOfWar
extends Node2D
## Grid line-of-sight fog: unseen / explored / visible cells.

var visible_cells: Dictionary = {}
var explored_cells: Dictionary = {}
var blocker_lookup: Dictionary = {}
var center := Vector2i.ZERO
var radius := 15
var _window := 26


func configure(blocked: Dictionary) -> void:
	blocker_lookup = blocked


func is_visible(cell: Vector2i) -> bool:
	return visible_cells.has(cell)


func update_visibility(origin: Vector2i) -> void:
	if origin == center and not visible_cells.is_empty():
		return
	center = origin
	visible_cells.clear()
	var r2 := radius * radius
	for y in range(origin.y - radius, origin.y + radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			var dx := x - origin.x
			var dy := y - origin.y
			if dx * dx + dy * dy > r2:
				continue
			var c := Vector2i(x, y)
			if _line_of_sight(origin, c):
				visible_cells[c] = true
				explored_cells[c] = true
	queue_redraw()


func _line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y)))
	if steps <= 1:
		return true
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var c := Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)))
		if c == from or c == to:
			continue
		if blocker_lookup.get(c, false):
			return false
	return true


func _draw() -> void:
	for y in range(center.y - _window, center.y + _window + 1):
		for x in range(center.x - _window, center.x + _window + 1):
			var c := Vector2i(x, y)
			if visible_cells.has(c):
				continue
			var alpha := 0.97 if not explored_cells.has(c) else 0.55
			draw_colored_polygon(Iso.diamond_points(Iso.cell_to_world(c) + Vector2(0, 0.5)),
				Color(0.02, 0.03, 0.035, alpha))
