class_name PenaltyShotMath
extends RefCounted

# World coordinates: X across goal, Y height, Z towards the player.
const BALL_RADIUS: float = 0.14
const START: Vector3 = Vector3(0.0, BALL_RADIUS, 11.0)
const HALF_GOAL: float = 3.66
const GOAL_HEIGHT: float = 2.44
const POST_RADIUS: float = 0.06
const DURATION: float = 0.70
const MAX_BEND: float = 2.65
const SWEET_START: float = 0.55
const SWEET_END: float = 0.73
const FULL_CROSSING: float = 1.0 + BALL_RADIUS / START.z
const CHIP_LIFT: float = 8.0
const CHIP_DURATION: float = 1.20
const MASTERY_LOFT: float = 0.20

static func duration_for(loft: float = 0.0) -> float:
	return lerpf(DURATION, CHIP_DURATION, clampf(loft, 0.0, 1.0))

static func ring_phase(seconds: float) -> float:
	return fposmod(seconds, 1.0)

static func clean_knuckle(seconds: float, curve_committed: bool) -> bool:
	var phase: float = ring_phase(seconds)
	return not curve_committed and seconds >= 0.20 and phase >= SWEET_START and phase <= SWEET_END

static func spin_for_drag(logical_dx: float) -> float:
	if absf(logical_dx) <= 14.0:
		return 0.0
	return signf(logical_dx) * clampf((absf(logical_dx) - 14.0) / 86.0, 0.0, 1.0)

static func aim_at(seconds: float) -> Vector2:
	# Both coordinates are visible in the moving goal target before touch-down.
	return Vector2(sin(seconds * 1.16) * 3.25, 1.15 + sin(seconds * 0.81) * 0.70)

static func position_at(aim: Vector2, spin: float, knuckle: bool, progress: float, loft: float = 0.0) -> Vector3:
	var p: float = maxf(0.0, progress)
	var chip: float = clampf(loft, 0.0, 1.0)
	if chip > 0.0:
		spin = 0.0
		knuckle = false
	var wobble_x: float = 0.0
	var wobble_y: float = 0.0
	if knuckle and p > 0.45 and p < 1.0:
		var u: float = (p - 0.45) / 0.55
		var envelope: float = sin(PI * u)
		wobble_x = 0.32 * sin(TAU * u) * envelope
		wobble_y = 0.10 * sin(2.0 * TAU * u) * envelope
	return Vector3(
		aim.x * p + MAX_BEND * spin * p * p + wobble_x,
		BALL_RADIUS + (aim.y - BALL_RADIUS) * p + (3.2 + CHIP_LIFT * chip) * p * (1.0 - p) + wobble_y,
		START.z * (1.0 - p)
	)

static func label_for(spin: float, knuckle: bool, loft: float = 0.0) -> String:
	if loft > 0.0:
		return "CHIP"
	if knuckle:
		return "KNUCKLE"
	if absf(spin) < 0.001:
		return "STRAIGHT"
	var prefix: String = "BANANA" if absf(spin) >= 0.75 else "CURVE"
	return prefix + (" LEFT" if spin < 0.0 else " RIGHT")

static func timing_label(seconds: float, curve_committed: bool) -> String:
	if curve_committed:
		return "Curve control"
	if seconds < 0.20:
		return "Quick strike"
	if clean_knuckle(seconds, false):
		return "Clean knuckle"
	return "Released early" if ring_phase(seconds) < SWEET_START else "Released late"

static func inside_goal(point: Vector3) -> bool:
	return absf(point.x) < HALF_GOAL - POST_RADIUS - BALL_RADIUS \
		and point.y >= BALL_RADIUS \
		and point.y < GOAL_HEIGHT - POST_RADIUS - BALL_RADIUS

# First sphere-vs-capsule contact along a ball segment, from 0 to 1.
# Distance to a convex capsule along a line is convex. Find its minimum
# using closest segments, then bisect the entry interval. No endpoint-only
# collision check: even a fast shot that crosses an entire glove is caught.
static func capsule_entry(a: Vector3, b: Vector3, u: Vector3, v: Vector3, radius: float) -> float:
	var radius_sq: float = radius * radius
	var is_sphere: bool = u.distance_squared_to(v) < 0.00000001
	var start_nearest: Vector3 = u if is_sphere else Geometry3D.get_closest_point_to_segment(a, u, v)
	if a.distance_squared_to(start_nearest) <= radius_sq:
		return 0.0
	var motion: Vector3 = b - a
	var length_sq: float = motion.length_squared()
	if length_sq < 0.00000001:
		return INF
	if is_sphere:
		var intersections: PackedVector3Array = Geometry3D.segment_intersects_sphere(a, b, u, radius)
		if intersections.is_empty():
			return INF
		return clampf((intersections[0] - a).dot(motion) / length_sq, 0.0, 1.0)
	var pair: PackedVector3Array = Geometry3D.get_closest_points_between_segments(a, b, u, v)
	if pair[0].distance_squared_to(pair[1]) > radius_sq:
		return INF
	var lo: float = 0.0
	var hi: float = clampf((pair[0] - a).dot(motion) / length_sq, 0.0, 1.0)
	for _iteration in range(14):
		var mid: float = (lo + hi) * 0.5
		var sample: Vector3 = a + motion * mid
		var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(sample, u, v)
		if sample.distance_squared_to(nearest) <= radius_sq:
			hi = mid
		else:
			lo = mid
	return hi

static func frame_entry(a: Vector3, b: Vector3) -> float:
	var r: float = BALL_RADIUS + POST_RADIUS
	var left: float = capsule_entry(a, b, Vector3(-HALF_GOAL, 0, 0), Vector3(-HALF_GOAL, GOAL_HEIGHT, 0), r)
	var right: float = capsule_entry(a, b, Vector3(HALF_GOAL, 0, 0), Vector3(HALF_GOAL, GOAL_HEIGHT, 0), r)
	var bar: float = capsule_entry(a, b, Vector3(-HALF_GOAL, GOAL_HEIGHT, 0), Vector3(HALF_GOAL, GOAL_HEIGHT, 0), r)
	return minf(left, minf(right, bar))
