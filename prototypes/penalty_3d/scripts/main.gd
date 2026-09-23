extends Node3D

const Shot = preload("res://scripts/shot_math.gd")
const Arena = preload("res://scripts/arena_art.gd")
const KeeperRig = preload("res://scripts/keeper.gd")
const HudScene = preload("res://scripts/hud.gd")
const UI = preload("res://scripts/ui_theme.gd")
const Gesture = preload("res://scripts/shot_gesture.gd")
const Aim = preload("res://scripts/manual_aim.gd")
const Replay = preload("res://scripts/shot_replay.gd")
const NONE: int = -1
const MOUSE: int = -2
const SUBSTEPS: int = 4
const SOUNDS: Dictionary = {
	"kick": preload("res://audio/kick.wav"),
	"net": preload("res://audio/net.wav"),
	"save": preload("res://audio/save.wav"),
	"post": preload("res://audio/post.wav"),
	"wide": preload("res://audio/wide.wav"),
}

enum Phase { READY, HOLD, FLIGHT, RESULT }
enum Screen { CUP, INTRO, PLAY, RESULT, REPLAY }
enum Mode { CUP, RUSH, LESSON, CHAMPION, PRACTICE }

@export var progress_path: String = "user://rival_cup.cfg"
@export var rush_progress_path: String = "user://rush_showdown.cfg"
@export var champion_progress_path: String = "user://champion_showdown.cfg"

var _champion_progress: ChampionProgress
var _champion_profile: RivalProfile = RivalProfile.champion()
var _champion_brain: ChampionBrain = ChampionBrain.new()
var _practice_brain: ChampionBrain = ChampionBrain.new()
var _aim_owner: int = NONE
var _replay: ArenaShotReplay = Replay.new()
var _replay_pending: bool = false
var _replay_age: float = 0.0
var _replay_last_clock: float = 0.0
var _replay_count: int = 0
var _exceptional_shown: bool = false
var _replay_return: Screen = Screen.PLAY
var _replay_live_pose: Dictionary = {}
var _replay_live_ball: Vector3
var _replay_live_rotation: Quaternion
var _replay_home: Transform3D
var _replay_fov: float = 42.0
var _replay_net_strength: float = 0.15

var _mode: Mode = Mode.CUP
var _gesture: ArenaShotGesture = Gesture.new()
var _loft: float = 0.0
var _flight_duration: float = Shot.DURATION
var _rush_clear: bool = false
var _rush_chips: int = 0
var _lesson_success: bool = false
var _set_recorded: bool = false
var _rush_progress: RushProgress
var _rush_profile: RivalProfile = RivalProfile.rush_showdown()
var _rush_cue: Node3D
var _screen: Screen = Screen.CUP
var _phase: Phase = Phase.READY
var _paused: bool = false
var _clock: float = 0.0
var _owner: int = NONE
var _touch_origin: Vector2 = Vector2.ZERO
var _hold_started: int = 0
var _aim: Vector2 = Aim.DEFAULT
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
var _ball_material: ShaderMaterial
var _banner: Label3D
var _camera: Camera3D
var _keeper: PenaltyKeeper
var _hud: PenaltyHUD
var _audio: Dictionary = {}
var _sound_enabled: bool = true
var _progress: CupProgress
var _fx: ArenaGoalFx
var _rival_index: int = 0
var _last_record: Dictionary = {}
var last_signature: Dictionary = {}

func _ready() -> void:
	_progress = CupProgress.new(progress_path)
	_progress.load_from_disk()
	_rush_progress = RushProgress.new(rush_progress_path)
	_rush_progress.load_from_disk()
	_champion_progress = ChampionProgress.new(champion_progress_path)
	_champion_progress.load_from_disk()
	_champion_brain.set_memory(_champion_progress.recent_lanes)
	_art = Arena.build(self)
	_ball = _art["ball"]
	_ball_material = _art["ball_material"]
	_banner = _art["banner"]
	_camera = _art["camera"]
	_rush_cue = _art["rush_cue"]
	var aim_ring: MeshInstance3D = _art["aim_ring"]
	aim_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_art["target_ring"].physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for dot in _art["dots"]:
		dot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_keeper = KeeperRig.new()
	add_child(_keeper)
	_keeper.taunted.connect(_on_taunt)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_hud = HudScene.new()
	layer.add_child(_hud)
	_hud.pause_requested.connect(_pause_round)
	_hud.help_requested.connect(_show_help)
	_hud.resume_requested.connect(_resume_round)
	_hud.next_requested.connect(_next_ball)
	_hud.restart_requested.connect(_rematch)
	_hud.start_requested.connect(_begin_play)
	_hud.rematch_requested.connect(_rematch)
	_hud.next_rival_requested.connect(_go_next_rival)
	_hud.cup_requested.connect(_open_cup)
	_hud.play_next_requested.connect(_play_next)
	_hud.equip_requested.connect(_equip_cup_ball)
	_hud.rival_chosen.connect(_choose_rival)
	_hud.reward_toggled.connect(_toggle_reward)
	_hud.sound_changed.connect(_set_sound)
	_hud.rush_requested.connect(_show_rush_intro)
	_hud.lesson_requested.connect(_start_lesson)
	_hud.skip_lesson_requested.connect(_skip_lesson)
	_hud.rush_start_requested.connect(_start_rush)
	_hud.badge_toggled.connect(_toggle_badge)
	_hud.champion_requested.connect(_show_champion_intro)
	_hud.champion_start_requested.connect(_start_champion)
	_hud.practice_requested.connect(_start_practice)
	_hud.skip_replay_requested.connect(_skip_replay)
	_fx = ArenaGoalFx.new()
	add_child(_fx)
	_fx.setup(_camera, self)
	_prepare_audio()
	_load_preferences()
	get_viewport().size_changed.connect(_on_viewport_changed)
	_open_cup()

func _prepare_audio() -> void:
	for key in SOUNDS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = SOUNDS[key]
		player.volume_db = -8.0
		add_child(player)
		_audio[key] = player

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

func current_profile() -> RivalProfile:
	if _mode == Mode.CHAMPION or _mode == Mode.PRACTICE:
		return _champion_profile
	return RivalProfile.at(_rival_index) if _mode == Mode.CUP else _rush_profile

func _active_brain() -> ChampionBrain:
	return _practice_brain if _mode == Mode.PRACTICE else _champion_brain

func _required_goals() -> int:
	return ChampionProgress.REQUIRED_GOALS if _mode in [Mode.CHAMPION, Mode.PRACTICE] else 3

func progress() -> CupProgress:
	return _progress

func screen_name() -> String:
	return Screen.keys()[_screen]

func tension_level() -> int:
	return _fx.tension_level

func camera_at_home() -> bool:
	return _fx == null or _camera.global_position.distance_to(_fx.camera_home_origin()) < 0.05

func particles_live() -> bool:
	return _fx != null and _fx.particles_emitting()

func fx_speed_scale() -> float:
	return 1.0 if _fx == null else _fx.particles_speed_scale()

func is_celebrating() -> bool:
	return _fx != null and _fx.celebrating

func _physics_process(delta: float) -> void:
	if _paused:
		return
	if _screen == Screen.REPLAY:
		return
	if _fx != null:
		_fx.advance(delta)
	var step: float = delta / SUBSTEPS
	for _i in range(SUBSTEPS):
		_clock += step
		if _screen == Screen.PLAY:
			match _phase:
				Phase.READY, Phase.HOLD:
					_keeper.advance(_clock, -1.0, Shot.START, Vector3.ZERO)
				Phase.FLIGHT:
					_step_flight(step)
				Phase.RESULT:
					_step_result(step)
		elif _screen == Screen.RESULT:
			_step_result(step)
		elif _screen == Screen.INTRO or _screen == Screen.CUP:
			_keeper.advance(_clock, -1.0, Shot.START, Vector3.ZERO)
	_keeper.sync_meshes()
	_update_rush_cue()
	_ball.position = _ball_position
	if _phase == Phase.FLIGHT or _phase == Phase.RESULT:
		var axis: Vector3 = Vector3.LEFT if _loft > 0.0 else Vector3(1.0, _spin * 0.7, 0.1).normalized()
		_ball.rotate(axis, delta * (2.0 if _knuckle else 18.0))
	elif _screen == Screen.CUP:
		_ball.rotate(Vector3(0.15, 1.0, 0.08).normalized(), delta * 1.05)
	var shadow: MeshInstance3D = _art["shadow"]
	shadow.position = Vector3(_ball_position.x, 0.012, _ball_position.z)
	var radius_scale: float = clampf(1.0 - _ball_position.y * 0.18, 0.45, 1.0)
	shadow.scale = Vector3(radius_scale, 1.0, radius_scale)
	var net: Node3D = _art["net"]
	var pulse: float = 0.0
	if _phase == Phase.RESULT and _outcome == "GOAL":
		pulse = sin(_result_age * 22.0) * exp(-_result_age * 4.0) * _fx.net_strength
	net.scale.z = 1.0 + pulse
	_capture_shot()
	if _replay_pending and _result_age >= 0.26:
		_start_replay()

func _process(delta: float) -> void:
	if not _paused and _screen == Screen.REPLAY:
		# Sample recorded poses at display rate for smooth slow-motion playback.
		_advance_replay(delta)
		return
	if _paused or _screen != Screen.PLAY:
		return
	if _phase == Phase.READY:
		_hud.update_guide(_camera.unproject_position(Shot.START), true)
		_preview(_aim, 0.0, false)
	elif _phase == Phase.HOLD:
		var held: float = _held_seconds()
		var clean: bool = Shot.clean_knuckle(held, _gesture.committed())
		_hud.show_hold(Shot.ring_phase(held), _spin, _gesture.committed(), clean, _camera.unproject_position(Shot.START), _loft, _gesture.mode == Gesture.Mode.CHIP)
		_hud.update_guide(_camera.unproject_position(Shot.START), _gesture.mode != Gesture.Mode.CHIP)
		_preview(_locked_aim, _spin, clean, _loft)

func _preview(aim: Vector2, spin: float, knuckle: bool, loft: float = 0.0) -> void:
	var dots: Array = _art["dots"]
	var master: bool = _mode == Mode.CHAMPION
	for i in range(dots.size()):
		var dot: MeshInstance3D = dots[i]
		dot.visible = not master or i < 4
		dot.position = Shot.position_at(aim, spin, knuckle, (i + 1.0) / (dots.size() + 1.0), loft)
	var marker: MeshInstance3D = _art["aim_ring"]
	marker.visible = not master
	var target: Vector3 = Shot.position_at(aim, spin, knuckle, 1.0, loft)
	marker.position = target + Vector3(0, 0, 0.02)
	var material: StandardMaterial3D = marker.material_override as StandardMaterial3D
	material.albedo_color = UI.GOLD if Shot.inside_goal(target) else UI.CORAL
	# White reticle is chosen aim, never the secret landing point in master mode.
	var selected: MeshInstance3D = _art["target_ring"]
	selected.visible = true
	selected.position = Vector3(aim.x, aim.y, 0.04)

func _hide_preview() -> void:
	var marker: MeshInstance3D = _art["aim_ring"]
	marker.hide()
	_art["target_ring"].hide()
	for dot in _art["dots"]:
		dot.hide()

func _held_seconds() -> float:
	return maxf(0.0, (Time.get_ticks_usec() - _hold_started) / 1000000.0)

func _input(event: InputEvent) -> void:
	# An aim finger and a shot finger have separate ownership. Releasing the
	# reticle never shoots; crossing the goal with a shot drag never changes mode.
	if _aim_owner != NONE:
		if event is InputEventScreenTouch and event.index == _aim_owner:
			if event.canceled or not event.pressed:
				if not event.canceled:
					_move_aim(event.position)
				_aim_owner = NONE
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventScreenDrag and event.index == _aim_owner:
			_move_aim(event.position)
			get_viewport().set_input_as_handled()
			return
		elif _aim_owner == MOUSE and event is InputEventMouseMotion:
			_move_aim(event.position)
			get_viewport().set_input_as_handled()
			return
		elif _aim_owner == MOUSE and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_move_aim(event.position)
			_aim_owner = NONE
			get_viewport().set_input_as_handled()
			return
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
			if _screen == Screen.CUP or _screen == Screen.INTRO:
				return
			if _paused:
				_resume_round()
			elif _screen == Screen.REPLAY:
				_skip_replay()
			else:
				_pause_round()
		elif event.keycode == KEY_R:
			if _screen in [Screen.PLAY, Screen.RESULT, Screen.REPLAY]:
				_rematch()
		elif event.keycode == KEY_SPACE and not _paused:
			if _screen == Screen.REPLAY:
				_skip_replay()
			elif _screen == Screen.PLAY and _phase == Phase.RESULT:
				_next_ball()
			elif _screen == Screen.INTRO:
				_begin_play()
			elif _screen == Screen.CUP:
				_play_next()
			elif _screen == Screen.RESULT:
				_hud._primary_pressed()
		return
	if _paused or _screen != Screen.PLAY or _phase not in [Phase.READY, Phase.HOLD]:
		return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		_begin_control(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_control(MOUSE, event.position)

func _begin_control(pointer: int, point: Vector2) -> void:
	if _paused or _screen != Screen.PLAY or _phase not in [Phase.READY, Phase.HOLD]:
		return
	if not _hud.in_play_area(point):
		return
	if Aim.screen_region(_camera).has_point(point):
		if _aim_owner == NONE and pointer != _owner:
			_aim_owner = pointer
			_move_aim(point)
			get_viewport().set_input_as_handled()
	elif _owner == NONE and pointer != _aim_owner and _phase == Phase.READY:
		_begin_pointer(pointer, point)

func _move_aim(point: Vector2) -> void:
	if _paused or _screen != Screen.PLAY or _phase not in [Phase.READY, Phase.HOLD]:
		return
	_aim = Aim.from_screen(_camera, point, _aim)
	if _phase == Phase.HOLD:
		_locked_aim = _aim

func _begin_pointer(pointer: int, point: Vector2) -> void:
	if _paused or _screen != Screen.PLAY or _phase != Phase.READY or _owner != NONE:
		return
	if not _hud.in_play_area(point):
		return
	_owner = pointer
	_touch_origin = point
	_hold_started = Time.get_ticks_usec()
	_locked_aim = _aim
	_gesture.reset()
	_spin = 0.0
	_loft = 0.0
	_curve_committed = false
	_phase = Phase.HOLD
	get_viewport().set_input_as_handled()

func _drag_pointer(point: Vector2) -> void:
	if _phase != Phase.HOLD or _paused:
		return
	var logical_drag: Vector2 = (point - _touch_origin) * 400.0 / maxf(1.0, get_viewport().get_visible_rect().size.x)
	_gesture.update_drag(logical_drag, _progress.cup_won())
	_spin = _gesture.spin
	_loft = _gesture.loft
	_curve_committed = _gesture.mode == Gesture.Mode.CURVE

func _end_pointer(point: Vector2) -> void:
	if _paused or _phase != Phase.HOLD or not _hud.in_play_area(point):
		_cancel_hold()
		return
	_drag_pointer(point)
	var seconds: float = _held_seconds()
	_knuckle = Shot.clean_knuckle(seconds, _gesture.committed())
	_timing = Shot.timing_label(seconds, _gesture.committed())
	_shot_label = Shot.label_for(_spin, _knuckle, _loft)
	_owner = NONE
	_aim_owner = NONE
	_flight_age = 0.0
	_ball_position = Shot.START
	_flight_duration = Shot.duration_for(_loft)
	_velocity = (Shot.position_at(_locked_aim, _spin, _knuckle, 0.001, _loft) - Shot.START) / (0.001 * _flight_duration)
	_shots += 1
	_phase = Phase.FLIGHT
	_replay.begin(_ball_position, _ball.quaternion, _keeper.capture_pose())
	_replay_last_clock = _clock
	_rush_cue.hide()
	_hide_preview()
	_hud.show_flight()
	_play("kick")

func _cancel_hold() -> void:
	_owner = NONE
	_aim_owner = NONE
	if _phase == Phase.HOLD:
		_phase = Phase.READY
		_gesture.reset()
		_spin = 0.0
		_loft = 0.0
		_curve_committed = false
		_hud.show_ready()

func _step_flight(delta: float) -> void:
	var previous: Vector3 = _ball_position
	var next_age: float = minf(_flight_age + delta, _flight_duration * Shot.FULL_CROSSING)
	var next: Vector3 = Shot.position_at(_locked_aim, _spin, _knuckle, next_age / _flight_duration, _loft)
	_keeper.advance(_clock, _flight_age, previous, _velocity)
	var save_contact: float = _keeper.contact_fraction(previous, next)
	var frame_contact: float = Shot.frame_entry(previous, next)
	if minf(save_contact, frame_contact) < INF:
		var fraction: float = minf(save_contact, frame_contact)
		_ball_position = previous.lerp(next, fraction)
		_resolve("POST" if frame_contact <= save_contact else "SAVED")
		return
	if _loft >= Shot.MASTERY_LOFT and _keeper.clears_rush(previous, next):
		_rush_clear = true
	var actual_step: float = next_age - _flight_age
	if actual_step > 0.000001:
		_velocity = (next - previous) / actual_step
	_flight_age = next_age
	_ball_position = next
	if _flight_age >= _flight_duration * Shot.FULL_CROSSING:
		if Shot.inside_goal(_ball_position):
			_resolve("GOAL")
		elif _ball_position.y >= Shot.GOAL_HEIGHT - Shot.BALL_RADIUS:
			_resolve("OVER")
		else:
			_resolve("WIDE")

func _resolve(outcome: String) -> void:
	if _phase != Phase.FLIGHT:
		return
	_capture_shot()
	_phase = Phase.RESULT
	_outcome = outcome
	var score_pos: Vector3 = _ball_position
	_outcomes.append(outcome)
	if _mode in [Mode.CHAMPION, Mode.PRACTICE]:
		_active_brain().note_shot(score_pos.x)
	_result_age = 0.0
	_keeper.finish(outcome == "SAVED")
	match outcome:
		"GOAL":
			_result_velocity = Vector3(_velocity.x * 0.14, 0.7, -5.0)
			_play("net")
			if _rush_clear and _loft >= Shot.MASTERY_LOFT:
				_rush_chips += 1
			last_signature = _fx.start_goal(score_pos, _spin, _knuckle, _loft, _rush_clear)
		"SAVED":
			_result_velocity = Vector3(_velocity.x * -0.15, 1.5, 4.0)
			_play("save")
			_fx.play_miss()
			last_signature = {}
		"POST":
			_result_velocity = Vector3(-signf(_ball_position.x) * 2.0, 1.2, 4.0)
			_play("post")
			_fx.play_miss()
			last_signature = {}
		_:
			_result_velocity = _velocity * 0.35
			_play("wide")
			_fx.play_miss()
			last_signature = {}
	if _mode == Mode.LESSON:
		_lesson_success = outcome == "GOAL" and _rush_chips > 0
		if _lesson_success:
			_rush_progress.mark_lesson_seen()
	var clincher: bool = outcome == "GOAL" and _outcomes.count("GOAL") == _required_goals()
	var exceptional: bool = outcome == "GOAL" and (last_signature.get("placement", "") == "corner" or last_signature.get("technique", "") in ["banana", "knuckle"] or _rush_clear)
	_replay_pending = _mode != Mode.LESSON and _replay.recording and _replay_count < 2 and (clincher or (exceptional and not _exceptional_shown))
	if _replay_pending and exceptional:
		_exceptional_shown = true
	if not _replay_pending:
		_replay.finish()
	_hud.set_score(_outcomes)
	_refresh_tension()
	_show_result()

func _show_result() -> void:
	if _mode == Mode.LESSON:
		_hud.show_lesson_result(_lesson_success, _outcome, _loft, _rush_clear)
		return
	if _outcomes.size() >= 5:
		_finish_set()
		return
	if _replay_pending:
		_hud.show_flight()
		return
	var technique: String = last_signature.get("detail", "") if _outcome == "GOAL" and not last_signature.is_empty() else (_shot_label.capitalize() if _gesture.committed() or _curve_committed else _timing)
	var title: String = last_signature.get("title", "") if _outcome == "GOAL" else ""
	_hud.show_result(_outcome, technique, title)

func _finish_set() -> void:
	if _outcomes.size() != 5 or _mode == Mode.LESSON:
		return
	_fx.set_tension(0, 0)
	_hud.set_tension(0)
	var goals: int = _outcomes.count("GOAL")
	# Rendering/resuming results never records the same completed set again.
	if not _set_recorded:
		_set_recorded = true
		if _mode == Mode.CHAMPION:
			_last_record = _champion_progress.record_set(_outcomes, _champion_brain.memory())
		elif _mode == Mode.PRACTICE:
			_last_record = {"won": goals >= _required_goals()}
		elif _mode == Mode.RUSH:
			_last_record = _rush_progress.record_set(_outcomes, _rush_chips)
			_hud.set_badge(_rush_progress.badge_equipped)
		else:
			_last_record = _progress.record_set(current_profile().id, goals)
		if bool(_last_record.get("won", false)):
			_fx.play_set_win()
	_screen = Screen.RESULT
	if _replay_pending:
		_hud.show_flight()
	else:
		_render_completed_result()

func _render_completed_result() -> void:
	var goals: int = _outcomes.count("GOAL")
	if _mode in [Mode.CHAMPION, Mode.PRACTICE]:
		_hud.show_champion_result(goals, _champion_progress, _mode == Mode.PRACTICE)
		return
	if _mode == Mode.RUSH:
		_hud.show_rush_result(goals, _rush_chips, _rush_progress.next_target(goals, _rush_chips), bool(_last_record.get("first_badge", false)))
		return
	_hud.show_set_result(
		goals, CupProgress.stars_for_goals(goals),
		_progress.next_target_line(goals, _rival_index), goals >= 3,
		bool(_last_record.get("first_cup_win", false)),
		_rival_index + 1 < RivalProfile.roster().size()
	)

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
	if _paused:
		return
	if _screen == Screen.REPLAY:
		_skip_replay()
		return
	_fx.cancel()
	if _screen == Screen.RESULT:
		_open_cup()
		return
	if _phase != Phase.RESULT:
		return
	if _mode == Mode.LESSON:
		if _lesson_success:
			_start_rush()
		else:
			_start_lesson()
		return
	_ready_ball()

func _ready_ball() -> void:
	_cancel_replay()
	_fx.cancel()
	_phase = Phase.READY
	_owner = NONE
	_aim_owner = NONE
	_gesture.reset()
	_loft = 0.0
	_rush_clear = false
	_flight_duration = Shot.DURATION
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
	var will_rush: bool = _mode == Mode.LESSON or current_profile().rushes_on(_outcomes.size())
	if _mode in [Mode.CHAMPION, Mode.PRACTICE]:
		_keeper.set_guard_bias(_active_brain().guard_bias())
		will_rush = _active_brain().rushes_on(_outcomes.size())
	_keeper.prepare_shot(_clock, will_rush)
	_update_rush_cue()
	var net: Node3D = _art["net"]
	net.scale = Vector3.ONE
	_hud.hide_taunt()
	_hud.show_ready()
	_hud.set_score(_outcomes)
	_refresh_tension()
	_preview(_aim, 0.0, false)
	reset_physics_interpolation()

func _start_set(rival_index: int) -> void:
	if not _progress.is_unlocked(rival_index):
		return
	_rival_index = rival_index
	_start_attempt(Mode.CUP)

func _start_attempt(mode: Mode) -> void:
	_cancel_replay()
	_cancel_hold()
	_fx.cancel()
	_paused = false
	_pause_audio(false)
	_mode = mode
	_replay_count = 0
	_exceptional_shown = false
	if mode in [Mode.CHAMPION, Mode.PRACTICE]:
		if mode == Mode.PRACTICE:
			_practice_brain.set_memory([])
		_active_brain().begin_set()
	_screen = Screen.PLAY
	_clock = 0.0
	_shots = 0
	_rush_chips = 0
	_lesson_success = false
	_set_recorded = false
	_outcomes.clear()
	_last_record = {}
	last_signature = {}
	for player in _audio.values():
		player.stop()
	_keeper.configure(current_profile())
	if mode in [Mode.CHAMPION, Mode.PRACTICE]:
		_keeper.set_guard_bias(_active_brain().guard_bias(), true)
	_apply_equipped_ball()
	var title: String = current_profile().title if mode == Mode.CUP else "Beat the Rush"
	if mode in [Mode.CHAMPION, Mode.PRACTICE]:
		title = "Captain Practice" if mode == Mode.PRACTICE else "The Captain"
	_set_banner(title.to_upper())
	_hud.set_lesson(mode == Mode.LESSON)
	_hud.set_goal_target(_required_goals())
	_hud.set_chip_unlocked(_progress.cup_won())
	_hud.set_badge(_rush_progress.badge_equipped)
	_hud.set_play_hud(true)
	_hud.set_rival(title)
	_ready_ball()

func _update_rush_cue() -> void:
	_rush_cue.visible = not _paused and _screen == Screen.PLAY and (_phase == Phase.READY or _phase == Phase.HOLD) and _keeper.rush_armed()
	if _rush_cue.visible:
		_rush_cue.position = _keeper.rush_origin()
		var pulse: float = 1.0 + sin(_clock * 5.0) * 0.08
		_rush_cue.scale = Vector3(pulse, 1.0, pulse)

func _show_intro(index: int) -> void:
	if not _progress.is_unlocked(index):
		return
	_cancel_replay()
	_cancel_hold()
	_fx.cancel()
	_paused = false
	_pause_audio(false)
	_mode = Mode.CUP
	_rush_cue.hide()
	_hud.set_lesson(false)
	_screen = Screen.INTRO
	_rival_index = index
	_phase = Phase.READY
	_outcomes.clear()
	_ball_position = Shot.START
	_ball.position = Shot.START
	_apply_equipped_ball()
	_keeper.configure(current_profile())
	_keeper.reset_pose(_clock)
	_set_banner(current_profile().title.to_upper())
	_hide_preview()
	_hud.hide_taunt()
	_hud.set_score(_outcomes)
	_hud.show_intro(current_profile())

func _open_cup() -> void:
	_cancel_replay()
	_cancel_hold()
	_fx.cancel()
	_mode = Mode.CUP
	_rush_cue.hide()
	_hud.set_lesson(false)
	_hud.set_chip_unlocked(_progress.cup_won())
	_paused = false
	_pause_audio(false)
	_screen = Screen.CUP
	_phase = Phase.READY
	_owner = NONE
	_outcomes.clear()
	_rival_index = _progress.next_play_index()
	_keeper.configure(current_profile())
	_keeper.reset_pose(_clock)
	_ball_position = Shot.START
	_ball.position = Shot.START
	Arena.apply_ball(_ball_material, "cup")
	_set_banner("RIVAL CUP")
	_hide_preview()
	_hud.hide_taunt()
	_hud.set_score(_outcomes)
	_hud.set_tension(0)
	_hud.show_cup(_progress, _rush_progress, _champion_progress)

func _begin_play() -> void:
	if _mode == Mode.CHAMPION:
		_start_champion()
	elif _mode == Mode.PRACTICE:
		_start_practice()
	elif _mode == Mode.LESSON:
		_start_lesson()
	elif _mode == Mode.RUSH:
		_start_rush()
	else:
		_start_set(_rival_index)

func _show_rush_intro() -> void:
	if not _progress.cup_won():
		return
	_cancel_replay()
	_cancel_hold()
	_fx.cancel()
	_paused = false
	_pause_audio(false)
	_mode = Mode.RUSH if _rush_progress.lesson_seen else Mode.LESSON
	_screen = Screen.INTRO
	_phase = Phase.READY
	_outcomes.clear()
	_rush_cue.hide()
	_hud.set_lesson(false)
	_hud.set_chip_unlocked(true)
	_keeper.configure(_rush_profile)
	_keeper.prepare_shot(_clock, true)
	_ball_position = Shot.START
	_ball.position = Shot.START
	_apply_equipped_ball()
	_set_banner("BEAT THE RUSH")
	_hide_preview()
	_hud.hide_taunt()
	_hud.show_rush_intro(_mode == Mode.LESSON, _rush_progress)

func _start_rush() -> void:
	if not _progress.cup_won():
		return
	_start_attempt(Mode.RUSH)

func _start_lesson() -> void:
	if not _progress.cup_won():
		return
	_aim = Aim.DEFAULT
	_start_attempt(Mode.LESSON)

func _skip_lesson() -> void:
	if not _progress.cup_won():
		return
	_rush_progress.mark_lesson_seen()
	_start_rush()

func _toggle_badge() -> void:
	_rush_progress.toggle_badge()
	_hud.set_badge(_rush_progress.badge_equipped)
	_hud.show_cup(_progress, _rush_progress, _champion_progress)

func _play_next() -> void:
	if _progress.cup_won():
		_show_champion_intro()
	else:
		_show_intro(_progress.next_play_index())

func _choose_rival(index: int) -> void:
	_show_intro(index)

func _rematch() -> void:
	if _screen == Screen.CUP:
		return
	_begin_play()

func _go_next_rival() -> void:
	var next_index: int = _rival_index + 1
	if next_index >= RivalProfile.roster().size() or not _progress.is_unlocked(next_index):
		_open_cup()
		return
	_show_intro(next_index)

func _equip_cup_ball() -> void:
	_progress.equip_ball("cup")
	_open_cup()

func _toggle_reward() -> void:
	if not _progress.cup_won():
		return
	_progress.equip_ball("classic" if _progress.ball == "cup" else "cup")
	_hud.show_cup(_progress, _rush_progress, _champion_progress)

func _apply_equipped_ball() -> void:
	Arena.apply_ball(_ball_material, _progress.ball)

func _set_banner(text: String) -> void:
	_banner.text = text

func _refresh_tension() -> void:
	if _mode == Mode.LESSON:
		_fx.set_tension(0, 0)
		_hud.set_tension(0)
		return
	var goals: int = _outcomes.count("GOAL")
	var balls_left: int = 5 - _outcomes.size()
	var needed: int = _required_goals() - goals
	_fx.set_tension(needed, balls_left)
	_hud.set_tension(_fx.tension_level)

func _on_taunt(line: String, world_point: Vector3) -> void:
	if _camera == null:
		return
	_hud.show_taunt(line, _camera.unproject_position(world_point))

func smoke_resolve(outcome: String, at: Vector3 = Vector3.ZERO, spin: float = 0.0, knuckle: bool = false) -> void:
	if at == Vector3.ZERO:
		at = Vector3(0.0, 1.2, -Shot.BALL_RADIUS)
	_spin = spin
	_loft = 0.0
	_rush_clear = false
	_gesture.reset()
	_knuckle = knuckle
	_curve_committed = absf(spin) > 0.001
	_shot_label = Shot.label_for(spin, knuckle)
	_timing = "Quick strike"
	_ball_position = at
	_velocity = Vector3(0, 0, -8)
	_phase = Phase.FLIGHT
	_resolve(outcome)

func _pause_round() -> void:
	if _screen == Screen.CUP or _screen == Screen.INTRO:
		return
	_cancel_hold()
	_paused = true
	_rush_cue.hide()
	_pause_audio(true)
	_hud.show_menu(false)

func _show_help() -> void:
	if _screen in [Screen.PLAY, Screen.RESULT, Screen.REPLAY]:
		_pause_round()
	_hud.show_menu(true)

func _resume_round() -> void:
	if _screen == Screen.CUP:
		_hud.show_cup(_progress, _rush_progress, _champion_progress)
		return
	if _screen == Screen.INTRO:
		if _mode == Mode.CUP:
			_hud.show_intro(current_profile())
		elif _mode == Mode.CHAMPION:
			_hud.show_champion_intro(_champion_progress)
		else:
			_hud.show_rush_intro(_mode == Mode.LESSON, _rush_progress)
		return
	_paused = false
	_pause_audio(false)
	if _screen == Screen.REPLAY:
		_hud.show_replay(last_signature.get("title", "Goal!"))
	elif _screen == Screen.RESULT:
		if _replay_pending:
			_hud.show_flight()
		else:
			_render_completed_result()
	elif _phase == Phase.RESULT:
		_show_result()
	elif _phase == Phase.READY:
		_hud.show_ready()
	else:
		_hud.show_flight()
	reset_physics_interpolation()

func _pause_audio(value: bool) -> void:
	for player in _audio.values():
		player.stream_paused = value
	if _fx != null:
		_fx.set_paused(value)

func _on_viewport_changed() -> void:
	_cancel_hold()
	if _paused:
		_hud.show_menu(false)

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause_round()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _screen == Screen.CUP:
			return
		if _paused:
			_resume_round()
		elif _screen == Screen.REPLAY:
			_skip_replay()
		elif _screen == Screen.INTRO or _screen == Screen.RESULT:
			_open_cup()
		else:
			_pause_round()

func _show_champion_intro() -> void:
	if not _progress.cup_won():
		return
	_cancel_replay()
	_cancel_hold()
	_fx.cancel()
	_paused = false
	_pause_audio(false)
	_mode = Mode.CHAMPION
	_screen = Screen.INTRO
	_phase = Phase.READY
	_outcomes.clear()
	_rush_cue.hide()
	_hud.set_lesson(false)
	_hud.set_goal_target(4)
	_hud.set_chip_unlocked(true)
	_keeper.configure(_champion_profile)
	_keeper.set_guard_bias(_champion_brain.guard_bias(), true)
	_keeper.reset_pose(_clock)
	_ball_position = Shot.START
	_ball.position = Shot.START
	_apply_equipped_ball()
	_set_banner("THE CAPTAIN")
	_hide_preview()
	_hud.hide_taunt()
	_hud.show_champion_intro(_champion_progress)

func _start_champion() -> void:
	if _progress.cup_won():
		_start_attempt(Mode.CHAMPION)

func _start_practice() -> void:
	if _progress.cup_won():
		_start_attempt(Mode.PRACTICE)

func _capture_shot() -> void:
	if _replay.recording and _clock > _replay_last_clock:
		_replay.capture(_clock - _replay_last_clock, _ball_position, _ball.quaternion, _keeper.capture_pose(), _art["net"].scale.z)
		_replay_last_clock = _clock

func _start_replay() -> void:
	_replay_pending = false
	if not _replay.finish():
		if _screen == Screen.RESULT:
			_render_completed_result()
		else:
			_show_result()
		return
	_replay_return = _screen
	_replay_live_ball = _ball_position
	_replay_live_rotation = _ball.quaternion
	_replay_live_pose = _keeper.capture_pose()
	_replay_net_strength = _fx.net_strength
	_fx.cancel()
	_replay_home = _camera.global_transform
	_replay_fov = _camera.fov
	_replay_age = 0.0
	_replay_count += 1
	_screen = Screen.REPLAY
	_aim_owner = NONE
	_owner = NONE
	_hide_preview()
	_rush_cue.hide()
	_hud.hide_taunt()
	_hud.show_replay(last_signature.get("title", "Goal!"))
	var side: float = -1.0 if _locked_aim.x < 0.0 else 1.0
	_camera.position = Vector3(side * 5.2, 2.4, 1.4)
	_camera.fov = 58.0
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ball.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_keeper.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_fx.play_highlight()
	_advance_replay(0.0)
	reset_physics_interpolation()

func _advance_replay(delta: float) -> void:
	_replay_age += delta
	var frame: Dictionary = _replay.sample(_replay_age / Replay.DURATION)
	if not frame.is_empty():
		_ball.position = frame["ball"]
		_ball.quaternion = frame["rotation"]
		_keeper.apply_recorded_pose(frame["keeper_a"], frame["keeper_b"], frame["weight"])
		_art["net"].scale.z = frame["net"]
		_camera.look_at(_ball.position.lerp(Vector3(0.0, 1.0, 0.0), 0.12))
		var shadow: MeshInstance3D = _art["shadow"]
		shadow.position = Vector3(_ball.position.x, 0.012, _ball.position.z)
		var scale_factor: float = clampf(1.0 - _ball.position.y * 0.18, 0.45, 1.0)
		shadow.scale = Vector3(scale_factor, 1.0, scale_factor)
	if _replay_age >= Replay.DURATION:
		_skip_replay()

func _restore_replay_view() -> void:
	_camera.global_transform = _replay_home
	_camera.fov = _replay_fov
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	_ball.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	_keeper.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	_ball_position = _replay_live_ball
	_ball.position = _replay_live_ball
	_ball.quaternion = _replay_live_rotation
	_keeper.apply_recorded_pose(_replay_live_pose, _replay_live_pose, 0.0)
	_fx.net_strength = _replay_net_strength
	_art["net"].scale.z = 1.0 + sin(_result_age * 22.0) * exp(-_result_age * 4.0) * _fx.net_strength
	var shadow: MeshInstance3D = _art["shadow"]
	shadow.position = Vector3(_ball_position.x, 0.012, _ball_position.z)
	var scale_factor: float = clampf(1.0 - _ball_position.y * 0.18, 0.45, 1.0)
	shadow.scale = Vector3(scale_factor, 1.0, scale_factor)
	_hud.set_play_hud(true)
	reset_physics_interpolation()

func _skip_replay() -> void:
	if _screen != Screen.REPLAY or _paused:
		return
	_restore_replay_view()
	_screen = _replay_return
	_replay.clear()
	_refresh_tension()
	if _screen == Screen.RESULT:
		_fx.set_tension(0, 0)
		_hud.set_tension(0)
		_render_completed_result()
	else:
		_show_result()

func _cancel_replay() -> void:
	_replay_pending = false
	if _screen == Screen.REPLAY:
		_restore_replay_view()
		_screen = _replay_return
	_replay.clear()
