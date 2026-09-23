class_name PenaltyKeeper
extends Node3D

signal taunted(line: String, world_point: Vector3)

const Shot = preload("res://scripts/shot_math.gd")

var committed: bool = false
var capsules: Array[Dictionary] = []
var _profile: RivalProfile
var _kit: StandardMaterial3D
var _from_x: float = 0.0
var _target_x: float = 0.0
var _root_x: float = 0.0
var _idle_vx: float = 0.0
var _lean: float = 0.0
var _lift: float = 0.0
var _extension: float = 0.0
var _direction: float = 1.0
var _target_lift: float = 0.0
var _commit_age: float = 0.0
var _recovery: float = 0.0
var _saved: bool = false
var _taunt_sent: bool = false
var _rush_ball: bool = false
var _root_z: float = 0.48
var _forward_pitch: float = 0.0

func rush_armed() -> bool:
	return _rush_ball

func rush_origin() -> Vector3:
	return Vector3(_root_x, 0.025, _root_z)

func prepare_shot(clock: float, will_rush: bool) -> void:
	reset_pose(clock)
	_rush_ball = will_rush
	_forward_pitch = 0.20 if will_rush else 0.0
	_write_pose(clock)
	for part in capsules:
		part["old_a"] = part["a"]
		part["old_b"] = part["b"]
	sync_meshes()
	reset_physics_interpolation()

func _ready() -> void:
	_kit = _material(Color("#5fd4ff"))
	var shorts: StandardMaterial3D = _material(Color("#142c36"))
	var skin: StandardMaterial3D = _material(Color("#d79c75"))
	var glove: StandardMaterial3D = _material(Color("#fff2d5"))
	var boot: StandardMaterial3D = _material(Color("#10212d"))
	# Indices remain fixed. Every visible capsule has a matching contact shape.
	for spec in [
		[0.25, _kit], [0.17, skin],
		[0.115, _kit], [0.10, _kit], [0.15, glove],
		[0.115, _kit], [0.10, _kit], [0.15, glove],
		[0.135, shorts], [0.10, _kit], [0.12, boot],
		[0.135, shorts], [0.10, _kit], [0.12, boot],
	]:
		_add_part(float(spec[0]), spec[1])
	if _profile == null:
		configure(RivalProfile.at(1))
	else:
		_kit.albedo_color = _profile.kit
	reset_pose(0.0)

func configure(profile: RivalProfile) -> void:
	_profile = profile
	if _kit != null:
		_kit.albedo_color = profile.kit

func profile() -> RivalProfile:
	return _profile

func head_point() -> Vector3:
	if capsules.is_empty():
		return Vector3(_root_x, 1.69, 0.48)
	return capsules[1]["a"]

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _add_part(radius: float, material: StandardMaterial3D) -> void:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 10
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.mesh = cylinder
	shaft.material_override = material
	add_child(shaft)
	var end_a: MeshInstance3D = MeshInstance3D.new()
	end_a.mesh = sphere
	end_a.material_override = material
	end_a.scale = Vector3.ONE * radius
	add_child(end_a)
	var end_b: MeshInstance3D = MeshInstance3D.new()
	end_b.mesh = sphere
	end_b.material_override = material
	end_b.scale = Vector3.ONE * radius
	add_child(end_b)
	capsules.append({
		"a": Vector3.ZERO, "b": Vector3.ZERO,
		"old_a": Vector3.ZERO, "old_b": Vector3.ZERO,
		"radius": radius, "shaft": shaft, "end_a": end_a, "end_b": end_b,
	})

func _patrol_x(clock: float) -> float:
	if _profile == null:
		return sin(clock * 1.65) * 1.15
	return _profile.offset(clock * 1.65) * 1.15

func _reaction() -> float:
	return 0.19 if _profile == null else _profile.reaction

func _reach() -> float:
	return 1.55 if _profile == null else _profile.reach

func _dive_time() -> float:
	return 0.34 if _profile == null else _profile.dive_time

func _lift_max() -> float:
	return 0.60 if _profile == null else _profile.lift_max

func reset_pose(clock: float) -> void:
	committed = false
	_rush_ball = false
	_root_z = 0.48
	_forward_pitch = 0.0
	_lean = 0.0
	_lift = 0.0
	_extension = 0.0
	_recovery = 0.0
	_saved = false
	_taunt_sent = false
	_root_x = _patrol_x(clock)
	_idle_vx = 0.0
	_write_pose(clock)
	for part in capsules:
		part["old_a"] = part["a"]
		part["old_b"] = part["b"]
	sync_meshes()
	reset_physics_interpolation()

func advance(clock: float, flight_age: float, ball: Vector3, velocity: Vector3) -> void:
	if not committed:
		var previous_x: float = _root_x
		_root_x = _patrol_x(clock)
		_idle_vx = _root_x - previous_x
		_lean = sin(clock * 3.3) * 0.055
		_lift = 0.0
		_extension = 0.0
		if flight_age >= _reaction() and velocity.z < -0.01:
			# Read only the ball's observed position and velocity after the delay.
			# Never inspect the player's hidden final target, spin or technique.
			var intercept_z: float = 0.48 + _profile.rush_distance if _rush_ball else 0.0
			var remaining: float = maxf(0.0, (ball.z - intercept_z) / -velocity.z)
			var predicted_x: float = ball.x + velocity.x * remaining
			var predicted_y: float = ball.y + velocity.y * remaining - 6.53 * remaining * remaining
			_from_x = _root_x
			if _profile != null and _profile.commit_to_lean and absf(predicted_x - _root_x) < 0.9:
				if absf(_idle_vx) < 0.001:
					_direction = 1.0
				else:
					_direction = 1.0 if _idle_vx > 0.0 else -1.0
			else:
				_direction = -1.0 if predicted_x < _root_x else 1.0
			var body_offset: float = 0.0 if _rush_ball else _direction * 0.48
			_target_x = clampf(predicted_x - body_offset, _from_x - _reach(), _from_x + _reach())
			_target_x = clampf(_target_x, -3.05, 3.05)
			_target_lift = clampf(predicted_y - 1.20, -0.35, _lift_max())
			_commit_age = flight_age
			committed = true
	if committed:
		var move_time: float = _profile.rush_time if _rush_ball else _dive_time()
		var p: float = clampf((flight_age - _commit_age) / move_time, 0.0, 1.0)
		var ease: float = p * p * (3.0 - 2.0 * p)
		_root_x = lerpf(_from_x, _target_x, ease)
		if _rush_ball:
			_root_z = 0.48 + _profile.rush_distance * ease
			_forward_pitch = lerpf(0.20, 0.34, ease)
			_lean = -_direction * 0.12 * ease
			_lift = 0.0
			_extension = ease * 0.30
		else:
			_lean = -_direction * 0.95 * ease
			_lift = _target_lift * sin(p * PI * 0.5)
			_extension = ease
	_write_pose(clock)

func finish(saved: bool) -> void:
	_saved = saved
	_recovery = 0.0
	_taunt_sent = false

func recover(delta: float, clock: float) -> void:
	_recovery += delta
	var amount: float = 1.0 - exp(-delta * 5.0)
	_lean = lerpf(_lean, 0.0, amount)
	_lift = lerpf(_lift, 0.0, amount)
	_extension = lerpf(_extension, 0.0, amount)
	_forward_pitch = lerpf(_forward_pitch, 0.0, amount)
	_root_z = lerpf(_root_z, 0.48, amount)
	if _saved and not _taunt_sent and _recovery > 0.30:
		_taunt_sent = true
		if _profile != null and not _profile.taunts.is_empty():
			var line: String = _profile.taunts[randi() % _profile.taunts.size()]
			taunted.emit(line, head_point())
	_write_pose(clock)

func _point(local_point: Vector3) -> Vector3:
	var pivot: Vector3 = Vector3(0.0, 0.9, 0.0)
	var p: Vector3 = (local_point - pivot).rotated(Vector3.RIGHT, _forward_pitch)
	p = p.rotated(Vector3.BACK, _lean) + pivot
	p += Vector3(_root_x, _lift, _root_z)
	p.y = maxf(0.11, p.y)
	return p

func _part(index: int, a: Vector3, b: Vector3) -> void:
	var part: Dictionary = capsules[index]
	part["old_a"] = part["a"]
	part["old_b"] = part["b"]
	part["a"] = _point(a)
	part["b"] = _point(b)

func _write_pose(clock: float) -> void:
	var bounce: float = 0.06 if _profile == null else _profile.bounce
	var crouch: float = 0.0 if _profile == null else _profile.crouch
	var spread: float = 0.0 if _profile == null else _profile.arm_spread
	var step: float = sin(clock * 8.0) * bounce * (1.0 - _extension)
	var taunt: float = 0.0
	if _saved and _recovery > 0.30:
		taunt = sin(clampf((_recovery - 0.30) / 0.75, 0.0, 1.0) * PI) * 0.25
	_part(0, Vector3(0, 0.91 - crouch, 0), Vector3(0, 1.28 - crouch, 0))
	_part(1, Vector3(0, 1.69 - crouch, 0), Vector3(0, 1.69 - crouch, 0))
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var arm_index: int = 2 + side_index * 3
		var shoulder: Vector3 = Vector3(side * (0.24 + spread), 1.34 - crouch, 0)
		var elbow: Vector3 = Vector3(side * (0.43 + spread + _extension * 0.08), 1.05 + _extension * 0.36 + taunt - crouch * 0.2, 0.10)
		var hand: Vector3 = Vector3(side * (0.48 + spread + _extension * 0.28), 0.91 + _extension * 0.63 + taunt - crouch * 0.15, 0.24)
		_part(arm_index, shoulder, elbow)
		_part(arm_index + 1, elbow, hand)
		_part(arm_index + 2, hand, hand)
		var leg_index: int = 8 + side_index * 3
		var hip: Vector3 = Vector3(side * 0.16, 0.82 - crouch, 0)
		var knee: Vector3 = Vector3(side * 0.23, 0.46 + side * step - crouch * 0.5, 0.12)
		var ankle: Vector3 = Vector3(side * 0.30, 0.13, -side * step)
		_part(leg_index, hip, knee)
		_part(leg_index + 1, knee, ankle)
		_part(leg_index + 2, ankle, ankle + Vector3(0, 0, 0.18))

func sync_meshes() -> void:
	for part in capsules:
		var a: Vector3 = part["a"]
		var b: Vector3 = part["b"]
		var radius: float = part["radius"]
		var shaft: MeshInstance3D = part["shaft"]
		var end_a: MeshInstance3D = part["end_a"]
		var end_b: MeshInstance3D = part["end_b"]
		var axis: Vector3 = b - a
		shaft.visible = axis.length_squared() > 0.000001
		if shaft.visible:
			shaft.quaternion = Quaternion(Vector3.UP, axis.normalized())
			shaft.scale = Vector3(radius, axis.length(), radius)
			shaft.position = (a + b) * 0.5
		end_a.position = a
		end_b.position = b
		end_b.visible = shaft.visible

func contact_fraction(a: Vector3, b: Vector3) -> float:
	var first: float = INF
	for part in capsules:
		var old_a: Vector3 = part["old_a"]
		var old_b: Vector3 = part["old_b"]
		var new_a: Vector3 = part["a"]
		var new_b: Vector3 = part["b"]
		var shift: Vector3 = (new_a + new_b - old_a - old_b) * 0.5
		# Moving-frame sweep is exact for translation. Limb rotation is sampled
		# at the substep midpoint (240 samples/s at the default physics rate).
		var hit: float = Shot.capsule_entry(
			a + shift * 0.5, b - shift * 0.5,
			(old_a + new_a) * 0.5, (old_b + new_b) * 0.5,
			float(part["radius"]) + Shot.BALL_RADIUS
		)
		first = minf(first, hit)
	return first

func clears_rush(a: Vector3, b: Vector3) -> bool:
	# A mastery chip must pass ABOVE the visible keeper, within his width.
	# Merely shooting around him, or chipping against a parked keeper, does not count.
	if not _rush_ball or not committed or capsules.is_empty():
		return false
	var torso: Dictionary = capsules[0]
	var old_mid: Vector3 = (torso["old_a"] + torso["old_b"]) * 0.5
	var new_mid: Vector3 = (torso["a"] + torso["b"]) * 0.5
	var before: float = a.z + Shot.BALL_RADIUS - old_mid.z
	var after: float = b.z + Shot.BALL_RADIUS - new_mid.z
	if before <= 0.0 or after > 0.0:
		return false
	var fraction: float = clampf(before / (before - after), 0.0, 1.0)
	var crossing: Vector3 = a.lerp(b, fraction)
	var top: float = -INF
	var left: float = INF
	var right: float = -INF
	for part in capsules:
		var radius: float = part["radius"]
		var old_a: Vector3 = part["old_a"]
		var old_b: Vector3 = part["old_b"]
		var points: Array[Vector3] = [old_a.lerp(part["a"], fraction), old_b.lerp(part["b"], fraction)]
		for point in points:
			top = maxf(top, point.y + radius)
			left = minf(left, point.x - radius)
			right = maxf(right, point.x + radius)
	return crossing.y - Shot.BALL_RADIUS > top + 0.02 and crossing.x >= left and crossing.x <= right
