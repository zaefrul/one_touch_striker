class_name ArenaManualAim
extends RefCounted

const Shot = preload("res://scripts/shot_math.gd")
const DEFAULT: Vector2 = Vector2(0.0, 1.05)

static func from_screen(camera: Camera3D, point: Vector2, previous: Vector2) -> Vector2:
	var origin: Vector3 = camera.project_ray_origin(point)
	var direction: Vector3 = camera.project_ray_normal(point)
	if absf(direction.z) < 0.00001:
		return previous
	var distance: float = -origin.z / direction.z
	if distance <= 0.0:
		return previous
	var hit: Vector3 = origin + direction * distance
	return Vector2(clampf(hit.x, -Shot.HALF_GOAL - 0.35, Shot.HALF_GOAL + 0.35), clampf(hit.y, Shot.BALL_RADIUS, Shot.GOAL_HEIGHT + 0.35))

static func screen_region(camera: Camera3D) -> Rect2:
	var a: Vector2 = camera.unproject_position(Vector3(-Shot.HALF_GOAL, 0.0, 0.0))
	var bounds: Rect2 = Rect2(a, Vector2.ZERO)
	for corner in [Vector3(Shot.HALF_GOAL, 0, 0), Vector3(-Shot.HALF_GOAL, Shot.GOAL_HEIGHT, 0), Vector3(Shot.HALF_GOAL, Shot.GOAL_HEIGHT, 0)]:
		bounds = bounds.expand(camera.unproject_position(corner))
	return bounds.grow(24.0)
