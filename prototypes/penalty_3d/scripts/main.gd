extends Node3D

const Shot = preload("res://scripts/shot_math.gd")
const Arena = preload("res://scripts/arena_art.gd")
const KeeperRig = preload("res://scripts/keeper.gd")
const HudScene = preload("res://scripts/hud.gd")
const NONE: int = -1
const MOUSE: int = -2
const SUBSTEPS: int = 4
const SOUNDS: Dictionary = {
	"kick": preload("res://audio/kick.wav"),
	"net": preload("res://audio/net.wav"),
	"save": preload("res://audio/save.wav"),
	"post": preload("res://audio/post.wav"),
	"wide": preload("res://audio/wide.wav"),
	"cheer": preload("res://audio/cheer.wav"),
}

enum Phase { READY, HOLD, FLIGHT, RESULT }

var _phase: Phase = Phase.READY
var _paused: bool = false
var _clock: float = 0.0
var _owner: int = NONE
var _touch_origin: Vector2 = Vector2.ZERO
var _hold_started: int = 0
var _aim: Vector2 = Vector2.ZERO
var _locked_aim: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _curve_committed: bool = false
var _knuckle: bool = false
var _timing: String = ""
var _shot_label: String = ""
var _flight_age: float = 0.0
var _ball_position: Vector3 = Shot.START
var _velocity: Vector3 = Vector3.ZERO
var _shots: int = 0
var _outcomes: Array[String] = []
var _outcome: String = ""
var _result_age: float = 0.0
var _result_velocity: Vector3 = Vector3.ZERO
var _art: Dictionary
var _ball: MeshInstance3D
var _camera: Camera3D
var _keeper: PenaltyKeeper
var _hud: PenaltyHUD
var _audio: Dictionary = {}
var _ambience: AudioStreamPlayer
var _sound_enabled: bool = true

func _ready() -> void:
	_art = Arena.build(self)
	_ball = _art["ball"]
	_camera = _art["camera"]
	var aim_ring: MeshInstance3D = _art["aim_ring"]
	aim_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for dot in _art["dots"]:
		dot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_keeper = KeeperRig.new()
	add_child(_keeper)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_hud = HudScene.new()
	layer.add_child(_hud)
	_hud.pause_requested.connect(_pause_round)
	_hud.help_requested.connect(_show_help)
	_hud.resume_requested.connect(_resume_round)
	_hud.next_requested.connect(_next_ball)
	_hud.restart_requested.connect(_restart_set)
	_hud.sound_changed.connect(_set_sound)
	_prepare_audio()
	_load_preferences()
	_ambience.play()
	get_viewport().size_changed.connect(_on_viewport_changed)
	_restart_set()

func _prepare_audio() -> void:
	for key in SOUNDS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = SOUNDS[key]
		player.volume_db = -14.0 if key == "cheer" else -8.0
		add_child(player)
		_audio[key] = player
	var crowd: AudioStreamWAV = preload("res://audio/stadium.wav").duplicate() as AudioStreamWAV
	crowd.loop_mode = AudioStreamWAV.LOOP_FORWARD
	crowd.loop_begin = 0
	crowd.loop_end = int(crowd.get_length() * crowd.mix_rate)
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = crowd
	_ambience.volume_db = -24.0
	add_child(_ambience)

func _load_preferences() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://arena_settings.cfg") == OK:
		var value: Variant = config.get_value("audio", "enabled", true)
		if value is bool:
			_sound_enabled = value
	AudioServer.set_bus_mute(0, not _sound_enabled)
	_hud.set_sound(_sound_enabled)

func _set_sound(enabled: bool) -> void:
	_sound_enabled = enabled
	AudioServer.set_bus_mute(0, not enabled)
	_hud.set_sound(enabled)
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "enabled", enabled)
	var error: Error = config.save("user://arena_settings.cfg")
	if error != OK:
		push_warning("Could not save arena sound preference: %s" % error_string(error))

func _play(key: String) -> void:
	if _sound_enabled and not _paused:
		var player: AudioStreamPlayer = _audio[key]
		player.play()

func _physics_process(delta: float) -> void:
	if _paused:
		return
	var step: float = delta / SUBSTEPS
	for _i in range(SUBSTEPS):
		_clock += step
		match _phase:
			Phase.READY, Phase.HOLD:
				_keeper.advance(_clock, -1.0, Shot.START, Vector3.ZERO)
			Phase.FLIGHT:
				_step_flight(step)
			Phase.RESULT:
				_step_result(step)
	_keeper.sync_meshes()
	_ball.position = _ball_position
	if _phase == Phase.FLIGHT or _phase == Phase.RESULT:
		var axis: Vector3 = Vector3(1.0, _spin * 0.7, 0.1).normalized()
		_ball.rotate(axis, delta * (2.0 if _knuckle else 18.0))
	var shadow: MeshInstance3D = _art["shadow"]
	shadow.position = Vector3(_ball_position.x, 0.012, _ball_position.z)
	var radius_scale: float = clampf(1.0 - _ball_position.y * 0.18, 0.45, 1.0)
	shadow.scale = Vector3(radius_scale, 1.0, radius_scale)
	var net: Node3D = _art["net"]
	var pulse: float = sin(_result_age * 22.0) * exp(-_result_age * 4.0) * 0.15 if _phase == Phase.RESULT and _outcome == "GOAL" else 0.0
	net.scale.z = 1.0 + pulse

func _process(_delta: float) -> void:
	if _paused:
		return
	if _phase == Phase.READY:
		_aim = Shot.aim_at(_clock + Engine.get_physics_interpolation_fraction() / 60.0)
		_preview(_aim, 0.0, false)
	elif _phase == Phase.HOLD:
		var held: float = _held_seconds()
		var clean: bool = Shot.clean_knuckle(held, _curve_committed)
		_hud.show_hold(Shot.ring_phase(held), _spin, _curve_committed, clean, _camera.unproject_position(Shot.START))
		_preview(_locked_aim, _spin, clean)

func _preview(aim: Vector2, spin: float, knuckle: bool) -> void:
	var dots: Array = _art["dots"]
	for i in range(dots.size()):
		var dot: MeshInstance3D = dots[i]
		dot.visible = true
		dot.position = Shot.position_at(aim, spin, knuckle, (i + 1.0) / (dots.size() + 1.0))
	var marker: MeshInstance3D = _art["aim_ring"]
	marker.visible = true
	var target: Vector3 = Shot.position_at(aim, spin, knuckle, 1.0)
	marker.position = target + Vector3(0, 0, 0.02)
	var material: StandardMaterial3D = marker.material_override as StandardMaterial3D
	material.albedo_color = Color("#d9ff6a") if Shot.inside_goal(target) else Color("#ff8581")

func _hide_preview() -> void:
	var marker: MeshInstance3D = _art["aim_ring"]
	marker.hide()
	for dot in _art["dots"]:
		dot.hide()

func _held_seconds() -> float:
	return maxf(0.0, (Time.get_ticks_usec() - _hold_started) / 1000000.0)

# Capture the owner's release before GUI handling, even after dragging onto UI.
# Only a fresh press that survives GUI handling can begin another shot.
func _input(event: InputEvent) -> void:
	if _owner == NONE:
		return
	if event is InputEventScreenTouch and event.index == _owner:
		if event.canceled:
			_cancel_hold()
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			_end_pointer(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _owner:
		_drag_pointer(event.position)
		get_viewport().set_input_as_handled()
	elif _owner == MOUSE and event is InputEventMouseMotion:
		_drag_pointer(event.position)
		get_viewport().set_input_as_handled()
	elif _owner == MOUSE and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_pointer(event.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _paused:
				_resume_round()
			else:
				_pause_round()
		elif event.keycode == KEY_R:
			_restart_set()
		elif event.keycode == KEY_SPACE and _phase == Phase.RESULT and not _paused:
			_next_ball()
		return
	if _paused or _phase != Phase.READY or _owner != NONE:
		return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		_begin_pointer(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_pointer(MOUSE, event.position)

func _begin_pointer(pointer: int, point: Vector2) -> void:
	if not _hud.in_play_area(point):
		return
	_owner = pointer
	_touch_origin = point
	_hold_started = Time.get_ticks_usec()
	_locked_aim = _aim
	_spin = 0.0
	_curve_committed = false
	_phase = Phase.HOLD
	get_viewport().set_input_as_handled()

func _drag_pointer(point: Vector2) -> void:
	if _phase != Phase.HOLD or _paused:
		return
	var logical_dx: float = (point.x - _touch_origin.x) * 400.0 / get_viewport().get_visible_rect().size.x
	_spin = Shot.spin_for_drag(logical_dx)
	if absf(logical_dx) > 14.0:
		_curve_committed = true

func _end_pointer(point: Vector2) -> void:
	if _paused or _phase != Phase.HOLD or not _hud.in_play_area(point):
		_cancel_hold()
		return
	_drag_pointer(point)
	var seconds: float = _held_seconds()
	_knuckle = Shot.clean_knuckle(seconds, _curve_committed)
	_timing = Shot.timing_label(seconds, _curve_committed)
	_shot_label = Shot.label_for(_spin, _knuckle)
	_owner = NONE
	_flight_age = 0.0
	_ball_position = Shot.START
	_velocity = (Shot.position_at(_locked_aim, _spin, _knuckle, 0.001) - Shot.START) / (0.001 * Shot.DURATION)
	_shots += 1
	_phase = Phase.FLIGHT
	_hide_preview()
	_hud.show_flight()
	_play("kick")

func _cancel_hold() -> void:
	_owner = NONE
	if _phase == Phase.HOLD:
		_phase = Phase.READY
		_spin = 0.0
		_curve_committed = false
		_hud.show_ready()

func _step_flight(delta: float) -> void:
	var previous: Vector3 = _ball_position
	var next_age: float = minf(_flight_age + delta, Shot.DURATION * Shot.FULL_CROSSING)
	var next: Vector3 = Shot.position_at(_locked_aim, _spin, _knuckle, next_age / Shot.DURATION)
	_keeper.advance(_clock, _flight_age, previous, _velocity)
	var save_contact: float = _keeper.contact_fraction(previous, next)
	var frame_contact: float = Shot.frame_entry(previous, next)
	if minf(save_contact, frame_contact) < INF:
		var fraction: float = minf(save_contact, frame_contact)
		_ball_position = previous.lerp(next, fraction)
		_resolve("POST" if frame_contact <= save_contact else "SAVED")
		return
	var actual_step: float = next_age - _flight_age
	if actual_step > 0.000001:
		_velocity = (next - previous) / actual_step
	_flight_age = next_age
	_ball_position = next
	# Score only once the whole ball passes behind the goal line.
	if _flight_age >= Shot.DURATION * Shot.FULL_CROSSING:
		if Shot.inside_goal(_ball_position):
			_resolve("GOAL")
		elif _ball_position.y >= Shot.GOAL_HEIGHT - Shot.BALL_RADIUS:
			_resolve("OVER")
		else:
			_resolve("WIDE")

func _resolve(outcome: String) -> void:
	if _phase != Phase.FLIGHT:
		return
	_phase = Phase.RESULT
	_outcome = outcome
	_outcomes.append(outcome)
	_result_age = 0.0
	_keeper.finish(outcome == "SAVED")
	match outcome:
		"GOAL":
			_result_velocity = Vector3(_velocity.x * 0.14, 0.7, -5.0)
			_play("net")
			_play("cheer")
		"SAVED":
			_result_velocity = Vector3(_velocity.x * -0.15, 1.5, 4.0)
			_play("save")
		"POST":
			_result_velocity = Vector3(-signf(_ball_position.x) * 2.0, 1.2, 4.0)
			_play("post")
		_:
			_result_velocity = _velocity * 0.35
			_play("wide")
	_hud.set_score(_outcomes)
	_show_result()

func _show_result() -> void:
	var technique: String = _shot_label.capitalize() if _curve_committed else _timing
	_hud.show_result(_outcome, technique, _shots >= 5)

func _step_result(delta: float) -> void:
	_result_age += delta
	_keeper.recover(delta, _clock)
	if _result_age < 0.9:
		_result_velocity.y -= 9.8 * delta
		_ball_position += _result_velocity * delta
		if _ball_position.y < Shot.BALL_RADIUS:
			_ball_position.y = Shot.BALL_RADIUS
			_result_velocity.y = absf(_result_velocity.y) * 0.20
			_result_velocity.x *= 0.93
			_result_velocity.z *= 0.93
		if _outcome == "GOAL" and _ball_position.z < -1.6 + Shot.BALL_RADIUS:
			_ball_position.z = -1.6 + Shot.BALL_RADIUS
			_result_velocity.z = absf(_result_velocity.z) * 0.12

func _next_ball() -> void:
	if _phase != Phase.RESULT or _paused:
		return
	if _shots >= 5:
		_restart_set()
	else:
		_ready_ball()

func _ready_ball() -> void:
	_phase = Phase.READY
	_owner = NONE
	_spin = 0.0
	_curve_committed = false
	_knuckle = false
	_flight_age = 0.0
	_result_age = 0.0
	_outcome = ""
	_ball_position = Shot.START
	_velocity = Vector3.ZERO
	_ball.position = Shot.START
	_ball.rotation = Vector3.ZERO
	var shadow: MeshInstance3D = _art["shadow"]
	shadow.position = Vector3(Shot.START.x, 0.012, Shot.START.z)
	shadow.scale = Vector3.ONE
	_keeper.reset_pose(_clock)
	var net: Node3D = _art["net"]
	net.scale = Vector3.ONE
	_hud.show_ready()
	_hud.set_score(_outcomes)
	_aim = Shot.aim_at(_clock)
	_preview(_aim, 0.0, false)
	reset_physics_interpolation()

func _restart_set() -> void:
	_paused = false
	_clock = 0.0
	_shots = 0
	_outcomes.clear()
	for player in _audio.values():
		player.stop()
	_pause_audio(false)
	_ready_ball()

func _pause_round() -> void:
	_cancel_hold()
	_paused = true
	_pause_audio(true)
	_hud.show_menu(false)

func _show_help() -> void:
	_pause_round()
	_hud.show_menu(true)

func _resume_round() -> void:
	if not _paused:
		return
	_paused = false
	_pause_audio(false)
	if _phase == Phase.RESULT:
		_show_result()
	elif _phase == Phase.READY:
		_hud.show_ready()
	else:
		_hud.show_flight()
	reset_physics_interpolation()

func _pause_audio(value: bool) -> void:
	for player in _audio.values():
		player.stream_paused = value
	_ambience.stream_paused = value

func _on_viewport_changed() -> void:
	# A resize invalidates the drag origin and target projection.
	_cancel_hold()
	if _paused:
		_hud.show_menu(false)

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause_round()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _paused:
			_resume_round()
		else:
			_pause_round()
