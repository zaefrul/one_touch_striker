extends SceneTree

## Prepared for the owner; not executed in the source-only handoff.
## godot --headless --path prototypes/penalty_3d -s res://tests/champion_smoke.gd
const Game = preload("res://scripts/main.gd")
const Aim = preload("res://scripts/manual_aim.gd")
const Replay = preload("res://scripts/shot_replay.gd")
const Shot = preload("res://scripts/shot_math.gd")
const CUP: String = "user://champion_smoke_cup.cfg"
const RUSH: String = "user://champion_smoke_rush.cfg"
const SAVE: String = "user://champion_smoke_progress.cfg"
const BAD: String = "user://champion_smoke_bad.cfg"
var _failed: PackedStringArray = PackedStringArray()

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in [CUP, RUSH, SAVE, BAD]:
		_wipe(path)
	_test_memory()
	_test_save()
	_test_recording()
	await _test_arena()
	for path in [CUP, RUSH, SAVE, BAD]:
		_wipe(path)
	for message in _failed:
		push_error(message)
	print("CHAMPION_SMOKE_OK" if _failed.is_empty() else "CHAMPION_SMOKE_FAIL %d" % _failed.size())
	quit(0 if _failed.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed.append(message)

func _test_memory() -> void:
	var brain: ChampionBrain = ChampionBrain.new()
	brain.set_memory([2.8, 3.1, 2.5])
	_expect(brain.guard_bias() > 0.8, "repeated right shots produce visible right coverage")
	for _i in range(5):
		brain.note_shot(-3.0)
	_expect(brain.guard_bias() < -0.8 and brain.memory().size() == 5, "new left shots replace old habits")
	brain.note_shot(INF)
	_expect(is_finite(brain.guard_bias()) and absf(brain.guard_bias()) <= 1.25, "invalid lanes cannot corrupt bounded positioning")
	var previous: Array[int] = []
	for i in range(24):
		brain.begin_set(500 + i)
		var schedule: Array[int] = []
		for ball in range(5):
			if brain.rushes_on(ball):
				schedule.append(ball)
		_expect(schedule.size() == 2 and schedule[1] - schedule[0] > 1, "each set mixes two separated rushes with three parked saves")
		_expect(schedule != previous, "an immediate rematch changes the rush order")
		previous = schedule

func _test_save() -> void:
	var progress: ChampionProgress = ChampionProgress.new(SAVE)
	progress.load_from_disk()
	_expect(progress.record_set(["GOAL"], [1.0]).is_empty() and not FileAccess.file_exists(SAVE), "incomplete set cannot save")
	progress.record_set(["GOAL", "GOAL", "GOAL", "SAVED", "WIDE"], [2.0, 3.0])
	_expect(progress.wins == 0 and progress.losses == 1, "three goals lose the Champion showdown")
	progress.record_set(["GOAL", "GOAL", "GOAL", "GOAL", "POST"], [-2.0, -3.0])
	_expect(progress.wins == 1 and progress.best_goals == 4, "four goals win")
	progress.record_set(["GOAL", "GOAL", "GOAL", "GOAL", "GOAL"], [2.8, -2.8])
	var reopened: ChampionProgress = ChampionProgress.new(SAVE)
	reopened.load_from_disk()
	_expect(reopened.wins == 2 and reopened.losses == 1 and reopened.best_goals == 5, "perfect best and records round-trip")
	_expect(reopened.recent_lanes == [2.8, -2.8], "observed lanes round-trip separately from cup stars")
	var bad: ConfigFile = ConfigFile.new()
	bad.set_value("champion", "version", 99)
	bad.save(BAD)
	var before: String = _contents(BAD)
	var ignored: ChampionProgress = ChampionProgress.new(BAD)
	ignored.load_from_disk()
	ignored.record_set(["GOAL", "GOAL", "GOAL", "GOAL", "GOAL"], [])
	_expect(_contents(BAD) == before, "unknown saves survive a completed attempt")
	var file: FileAccess = FileAccess.open(BAD, FileAccess.WRITE)
	file.store_string("[champion\nbroken")
	file.close()
	before = _contents(BAD)
	ignored.load_from_disk()
	ignored.save()
	_expect(_contents(BAD) == before, "malformed save is preserved")
	_wipe(SAVE)

func _test_recording() -> void:
	var clip: ArenaShotReplay = Replay.new()
	var pose: Dictionary = {"points": PackedVector3Array([Vector3.ZERO, Vector3.UP]), "pitch": 0.0, "lean": 0.0, "extension": 0.0}
	clip.begin(Vector3(1, 1, 10), Quaternion.IDENTITY, pose)
	clip.capture(0.5, Vector3(2, 2, 5), Quaternion(Vector3.UP, 0.5), pose, 1.2)
	clip.capture(0.5, Vector3(3, 1, -0.2), Quaternion(Vector3.UP, 1.0), pose, 1.1)
	pose["pitch"] = 9.0
	_expect(clip.finish(), "recorded samples make a playable clip")
	var halfway: Dictionary = clip.sample(0.5)
	_expect(halfway["ball"].is_equal_approx(Vector3(2, 2, 5)), "replay follows captured positions")
	_expect(is_equal_approx(halfway["net"], 1.2), "net motion follows captured samples")
	_expect(float(halfway["keeper_a"]["pitch"]) == 0.0, "later pose edits cannot change recorded history")
	_expect(clip.sample(1.0)["ball"].is_equal_approx(Vector3(3, 1, -0.2)), "clip ends at the recorded endpoint")
	clip.clear()
	_expect(clip.sample(0.5).is_empty(), "clearing a clip removes previous shot data")

func _test_arena() -> void:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		return
	var arena: Node = packed.instantiate()
	arena.progress_path = CUP
	arena.rush_progress_path = RUSH
	arena.champion_progress_path = SAVE
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.set_physics_process(false)
	arena.set_process(false)
	arena._show_champion_intro()
	arena._start_practice()
	_expect(arena.screen_name() == "CUP", "fresh saves cannot bypass the cup unlock")
	for profile in RivalProfile.roster():
		arena.progress().record_set(profile.id, 3)
	var cup_before: String = _contents(CUP)
	var rush_before: String = _contents(RUSH)
	arena._start_set(0)
	await process_frame
	_test_manual_input(arena)
	arena._start_champion()
	_expect(arena._hud._goal_count.text == "0 / 4", "Champion objective uses four goals")
	arena._preview(Vector2(2, 1), 1.0, false, 1.0)
	_expect(not arena._art["aim_ring"].visible and arena._art["target_ring"].visible, "master mode hides the endpoint and retains chosen aim")
	for dot in arena._art["dots"]:
		if dot.visible:
			_expect(dot.position.z > 7.0, "master preview shows only the start of the path")
	_complete(arena, ["GOAL", "GOAL", "GOAL", "SAVED", "WIDE"])
	_expect(arena._champion_progress.losses == 1 and arena._champion_progress.wins == 0, "3/5 is a loss in the actual flow")
	arena._start_champion()
	for _i in range(4):
		if _i > 0:
			arena._next_ball()
		arena.smoke_resolve("GOAL", Vector3(2.8, 1.2, -0.14))
	_expect(arena.screen_name() == "PLAY" and arena._champion_progress.wins == 0, "four early goals still leave the fifth ball")
	arena._next_ball()
	arena._physics_process(0.3)
	_expect(arena._keeper.rush_origin().x > 0.0, "repeated right shots visibly move the keeper right")
	arena.smoke_resolve("WIDE")
	_expect(arena._champion_progress.wins == 1, "completed 4/5 counts one win")
	arena._finish_set()
	arena._pause_round()
	arena._resume_round()
	_expect(arena._champion_progress.wins == 1, "result re-entry never records another win")
	var saved: String = _contents(SAVE)
	var memory: Array[float] = arena._champion_brain.memory()
	arena._start_practice()
	_expect(arena._art["aim_ring"].visible and arena._art["dots"].back().visible, "practice shows the full preview")
	_complete(arena, ["GOAL", "GOAL", "GOAL", "GOAL", "GOAL"])
	_expect(_contents(SAVE) == saved and arena._champion_brain.memory() == memory, "practice changes neither saved records nor Champion memory")
	arena._start_champion()
	arena.smoke_resolve("GOAL")
	arena._open_cup()
	_expect(_contents(SAVE) == saved, "abandoning a set does not save a result")
	_expect(_contents(CUP) == cup_before and _contents(RUSH) == rush_before, "Champion and practice leave both existing progress files untouched")
	_test_replay_flow(arena)
	root.remove_child(arena)
	arena.free()

func _test_manual_input(arena: Node) -> void:
	var goal: Vector2 = arena._camera.unproject_position(Vector3(2.0, 1.05, 0.0))
	var shot: Vector2 = arena.get_viewport().get_visible_rect().size * Vector2(0.5, 0.78)
	var projected: Vector2 = Aim.from_screen(arena._camera, goal, Vector2.ZERO)
	_expect(projected.is_equal_approx(Vector2(2.0, 1.05)), "drag projection selects the requested goal-plane point")
	arena._begin_control(4, goal)
	_expect(arena._phase == Game.Phase.READY and arena._aim_owner == 4, "goal touch selects aim without holding a shot")
	var release: InputEventScreenTouch = InputEventScreenTouch.new()
	release.index = 4
	release.position = goal
	release.pressed = false
	arena._input(release)
	_expect(arena._shots == 0 and arena._aim_owner == -1, "releasing aim consumes no ball")
	var chosen: Vector2 = arena._aim
	arena._physics_process(0.25)
	arena._process(0.25)
	_expect(arena._aim == chosen, "waiting never sweeps the selected target")
	arena._begin_control(7, shot)
	arena._drag_pointer(shot + Vector2(75, 0))
	var bend: float = arena._spin
	goal = arena._camera.unproject_position(Vector3(-2.0, 1.2, 0.0))
	arena._begin_control(4, goal)
	_expect(arena._locked_aim.x < 0.0 and arena._spin == bend and bend > 0.0, "a second aim finger preserves the chosen bend")
	release.position = goal
	arena._input(release)
	_expect(arena._phase == Game.Phase.HOLD and arena._shots == 0, "aim-finger release cannot launch the held ball")
	arena._pause_round()
	arena._end_pointer(shot)
	arena._resume_round()
	_expect(arena._phase == Game.Phase.READY and arena._shots == 0 and arena._aim_owner == -1, "pause cancels both touch owners and stale release")
	arena._begin_control(Game.MOUSE, shot)
	arena._end_pointer(shot)
	var locked: Vector2 = arena._locked_aim
	arena._move_aim(Vector2.ZERO)
	_expect(arena._shots == 1 and arena._locked_aim == locked, "mouse release shoots once and in-flight aim cannot redirect it")

func _test_replay_flow(arena: Node) -> void:
	# Use the real flight and recorded keeper poses for an exceptional cup goal.
	arena._start_set(0)
	arena._aim = Vector2(-3.1, 1.95)
	var shot: Vector2 = arena.get_viewport().get_visible_rect().size * Vector2(0.5, 0.78)
	arena._begin_control(8, shot)
	arena._end_pointer(shot)
	for _tick in range(120):
		if arena.screen_name() == "REPLAY":
			break
		arena._physics_process(1.0 / 60.0)
	_expect(arena.screen_name() == "REPLAY" and arena._outcome == "GOAL", "real top-corner goal opens a recorded highlight")
	if arena.screen_name() != "REPLAY":
		return
	var outcomes: Array[String] = arena._outcomes.duplicate()
	var live_ball: Vector3 = arena._ball_position
	arena._advance_replay(0.6)
	_expect(arena._outcomes == outcomes and arena._ball_position == live_ball, "playback changes presentation only")
	arena._pause_round()
	var age: float = arena._replay_age
	arena._physics_process(0.5)
	arena._process(0.5)
	_expect(arena._replay_age == age, "paused replay does not advance")
	arena._resume_round()
	arena._skip_replay()
	_expect(arena.screen_name() == "PLAY" and arena.camera_at_home() and arena._ball.position.is_equal_approx(live_ball), "skip restores the exact result and aiming camera")
	arena._next_ball()
	_expect(arena._phase == Game.Phase.READY and arena._outcomes.size() == 1, "next ball after replay does not rescore")
	# Synthetic final-shot samples isolate the once-only save/lifecycle contract.
	arena._start_champion()
	for result in ["GOAL", "GOAL", "GOAL", "WIDE"]:
		arena.smoke_resolve(result)
		arena._next_ball()
	var wins: int = arena._champion_progress.wins
	var pose: Dictionary = arena._keeper.capture_pose()
	arena._replay.begin(Shot.START, Quaternion.IDENTITY, pose)
	arena._replay.capture(0.7, Vector3(0, 1.1, -0.14), Quaternion.IDENTITY, pose)
	arena._replay_last_clock = arena._clock
	arena.smoke_resolve("GOAL")
	_expect(arena._champion_progress.wins == wins + 1, "fifth-ball win is saved before replay")
	arena._start_replay()
	arena._advance_replay(Replay.DURATION)
	_expect(arena.screen_name() == "RESULT" and arena._champion_progress.wins == wins + 1, "automatic replay completion does not duplicate the saved win")
	arena._pause_round()
	arena._resume_round()
	_expect(arena._champion_progress.wins == wins + 1, "pause after a winning replay remains read-only")
	arena._start_replay()
	# The previous recorder is now empty, so replay cannot resurrect old frames.
	_expect(arena.screen_name() == "RESULT", "empty recording cannot reopen a stale highlight")
	for action in ["rematch", "cup"]:
		arena._start_champion()
		pose = arena._keeper.capture_pose()
		arena._replay.begin(Shot.START, Quaternion.IDENTITY, pose)
		arena._replay.capture(0.7, Vector3(3, 1.9, -0.14), Quaternion.IDENTITY, pose)
		arena._replay_last_clock = arena._clock
		arena.smoke_resolve("GOAL", Vector3(3, 1.9, -0.14))
		arena._start_replay()
		if action == "rematch":
			arena._rematch()
		else:
			arena._open_cup()
		_expect(arena.camera_at_home() and arena._outcomes.is_empty() and arena._replay.frame_count() == 0, "navigation during replay clears the recording and restores the camera")
		_expect(arena._champion_progress.wins == wins + 1, "aborting a partial replay cannot write another win")

func _complete(arena: Node, results: Array[String]) -> void:
	for i in range(results.size()):
		if i > 0:
			arena._next_ball()
		arena.smoke_resolve(results[i])

func _contents(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _wipe(path: String) -> void:
	for file in [path, path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
