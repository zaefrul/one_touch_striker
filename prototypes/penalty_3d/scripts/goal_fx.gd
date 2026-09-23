class_name ArenaGoalFx
extends Node

const Shot = preload("res://scripts/shot_math.gd")
const UI = preload("res://scripts/ui_theme.gd")

var last_placement: String = ""
var last_technique: String = ""
var last_title: String = ""
var last_detail: String = ""
var celebrating: bool = false
var tension_level: int = 0
var net_strength: float = 0.15

var _camera: Camera3D
var _home: Transform3D
var _look: Vector3 = Vector3(0.0, 0.8, 4.0)
var _score_pos: Vector3 = Vector3.ZERO
var _age: float = -1.0
var _paused: bool = false
var _particles: CPUParticles3D
var _cheer: AudioStreamPlayer
var _fire: AudioStreamPlayer
var _victory: AudioStreamPlayer
var _groan: AudioStreamPlayer
var _suspense: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _tension_needed: int = 0
var _tension_left: int = 5

func setup(camera: Camera3D, particles_parent: Node3D) -> void:
	_camera = camera
	_home = camera.global_transform
	_look = Vector3(0.0, 0.8, 4.0)
	_particles = CPUParticles3D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 40
	_particles.lifetime = 0.7
	_particles.explosiveness = 1.0
	_particles.direction = Vector3(0, 1, 0)
	_particles.spread = 80.0
	_particles.initial_velocity_min = 1.4
	_particles.initial_velocity_max = 4.2
	_particles.gravity = Vector3(0, -5.0, 0)
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 0.06
	puff.height = 0.12
	puff.radial_segments = 8
	puff.rings = 4
	_particles.mesh = puff
	var dust: StandardMaterial3D = StandardMaterial3D.new()
	dust.albedo_color = UI.GOLD
	dust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_particles.material_override = dust
	particles_parent.add_child(_particles)
	_cheer = _player(preload("res://audio/cheer.wav"), -14.0)
	_fire = _player(preload("res://audio/fire_goal.wav"), -8.0)
	_victory = _player(preload("res://audio/victory.wav"), -8.0)
	_groan = _player(preload("res://audio/groan.wav"), -18.0)
	_suspense = _player(preload("res://audio/suspense.wav"), -16.0)
	var crowd: AudioStreamWAV = preload("res://audio/stadium.wav").duplicate() as AudioStreamWAV
	crowd.loop_mode = AudioStreamWAV.LOOP_FORWARD
	crowd.loop_begin = 0
	crowd.loop_end = int(crowd.get_length() * crowd.mix_rate)
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = crowd
	_ambience.volume_db = -24.0
	add_child(_ambience)
	_ambience.play()

func camera_home_origin() -> Vector3:
	return _home.origin

func particles_emitting() -> bool:
	return _particles != null and _particles.emitting

func particles_speed_scale() -> float:
	return 1.0 if _particles == null else _particles.speed_scale

func _player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player

func classify(score_pos: Vector3, spin: float, knuckle: bool, loft: float = 0.0, cleared_rush: bool = false) -> Dictionary:
	var placement: String = "centre"
	if absf(score_pos.x) > Shot.HALF_GOAL - 1.1 and score_pos.y > 1.5:
		placement = "corner"
	var technique: String = "straight"
	if loft > 0.0:
		technique = "chip"
	elif knuckle:
		technique = "knuckle"
	elif absf(spin) >= 0.75:
		technique = "banana"
	elif absf(spin) > 0.001:
		technique = "curve"
	var title: String = "Goal!"
	if technique == "chip" and cleared_rush:
		title = "CHIPPED HIM!"
	elif placement == "corner":
		title = "TOP BINS!"
	elif technique == "banana":
		title = "BENT IT IN!"
	elif technique == "knuckle":
		title = "PURE KNUCKLE!"
	elif technique == "chip":
		title = "FLOATED IN!"
	var bits: PackedStringArray = PackedStringArray()
	if placement == "corner":
		bits.append("Top corner")
	else:
		bits.append("Centre")
	bits.append(technique.capitalize())
	if technique == "chip" and cleared_rush:
		bits.append("Beat the rush")
	var detail: String = " · ".join(bits)
	last_placement = placement
	last_technique = technique
	last_title = title
	last_detail = detail
	return {
		"placement": placement,
		"technique": technique,
		"title": title,
		"detail": detail,
	}

func start_goal(score_pos: Vector3, spin: float, knuckle: bool, loft: float = 0.0, cleared_rush: bool = false) -> Dictionary:
	var signature: Dictionary = classify(score_pos, spin, knuckle, loft, cleared_rush)
	_score_pos = score_pos
	_age = 0.0
	celebrating = true
	net_strength = 0.28 if signature["placement"] == "corner" or signature["technique"] != "straight" else 0.15
	_burst(signature)
	_cheer.pitch_scale = 1.12 if signature["technique"] == "banana" else 1.0
	_cheer.play()
	if signature["placement"] == "corner" or signature["technique"] == "knuckle" or cleared_rush:
		_fire.play()
	return signature

func play_miss() -> void:
	_groan.play()

func play_set_win() -> void:
	_victory.play()

func set_tension(needed: int, balls_left: int) -> void:
	_tension_needed = needed
	_tension_left = balls_left
	if needed == 1 and balls_left == 1:
		tension_level = 2
		_ambience.volume_db = -18.0
		if not _suspense.playing:
			_suspense.play()
	elif needed == 1 and balls_left > 0:
		tension_level = 1
		_ambience.volume_db = -18.0
		_suspense.stop()
	else:
		tension_level = 0
		_ambience.volume_db = -24.0
		_suspense.stop()

func set_paused(value: bool) -> void:
	_paused = value
	if _particles != null:
		_particles.speed_scale = 0.0 if value else 1.0
	for player in [_cheer, _fire, _victory, _groan, _suspense, _ambience]:
		if player != null:
			player.stream_paused = value

func cancel() -> void:
	celebrating = false
	_age = -1.0
	net_strength = 0.15
	if _camera != null:
		_camera.global_transform = _home
	if _particles != null:
		_particles.emitting = false
		_particles.speed_scale = 1.0
		_particles.restart()
		_particles.emitting = false
	for player in [_cheer, _fire, _victory, _groan, _suspense]:
		if player != null:
			player.stop()
	if _ambience != null:
		_ambience.volume_db = -24.0
	tension_level = 0
	_tension_needed = 0
	_suspense_clear()

func _suspense_clear() -> void:
	if _suspense != null:
		_suspense.stop()

func advance(delta: float) -> void:
	if _paused or not celebrating or _camera == null:
		return
	_age += delta
	var weight: float = 0.0
	if _age <= 0.6:
		var t: float = _age / 0.6
		weight = 1.0 - (1.0 - t) * (1.0 - t)
	elif _age <= 1.1:
		var u: float = (_age - 0.6) / 0.5
		weight = 1.0 - u * u
	else:
		_camera.global_transform = _home
		celebrating = false
		return
	var closer: Vector3 = _home.origin.lerp(_score_pos, 0.20)
	_camera.global_position = _home.origin.lerp(closer, weight)
	var look: Vector3 = _look.lerp(_score_pos, weight * 0.45)
	if look.distance_squared_to(_camera.global_position) > 0.01:
		_camera.look_at(look)

func _burst(signature: Dictionary) -> void:
	if _particles == null:
		return
	var color: Color = UI.TEXT
	if signature["placement"] == "corner":
		color = UI.GOLD
	elif signature["technique"] == "knuckle" or signature["technique"] == "chip":
		color = UI.BLUE
	elif signature["technique"] == "banana":
		color = Color("#ffd166")
	var dust: StandardMaterial3D = _particles.material_override as StandardMaterial3D
	if dust != null:
		dust.albedo_color = color
	_particles.position = _score_pos
	_particles.restart()
	_particles.emitting = true
