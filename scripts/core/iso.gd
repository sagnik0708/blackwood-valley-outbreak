class_name Iso
extends RefCounted
## Isometric coordinate helpers (tile size 64x32, diamond-down layout).

const TILE_W := 64.0
const TILE_H := 32.0


static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2((c.x - c.y) * TILE_W * 0.5, (c.x + c.y) * TILE_H * 0.5)


static func world_to_cell(p: Vector2) -> Vector2i:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2i(roundi((a + b) * 0.5), roundi((b - a) * 0.5))


## Screen-space input -> isometric world direction (keeps movement screen aligned).
static func input_to_world(dir: Vector2) -> Vector2:
	var w := Vector2(dir.x + dir.y, dir.y - dir.x)
	return w.normalized() if w.length() > 0.0 else Vector2.ZERO


static func diamond_points(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -TILE_H * 0.5), center + Vector2(TILE_W * 0.5, 0),
		center + Vector2(0, TILE_H * 0.5), center + Vector2(-TILE_W * 0.5, 0),
	])
