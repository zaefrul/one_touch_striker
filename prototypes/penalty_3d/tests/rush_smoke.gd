extends SceneTree

## Prepared for local execution; not run as part of the source-only handoff.
## godot --headless --path prototypes/penalty_3d -s res://tests/rush_smoke.gd
const Shot = preload("res://scripts/shot_math.gd")
const Gesture = preload("res://scripts/shot_gesture.gd")
const Game = preload("res://scripts/main.gd")
const CUP_PATH: String = "user://rush_smoke_cup.cfg"
const RUSH_PATH: String = "user://rush_smoke_progress.cfg"
const CHAMPION_PATH: String = "user://rush_smoke_champion_unused.cfg"
const BAD_PATH: String = "user://rush_smoke_bad.cfg"
var _failed: PackedStringArray = PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in [CUP_PATH, RUSH_PATH, CHAMPION_PATH, BAD_PATH]:
		_wipe(path)
	_test_gestures()
	_test_progress()
	await _test_arena()
	for path in [CUP_PATH, RUSH_PATH, CHAMPION_PATH, BAD_PATH]:
		_wipe(path)
	if _failed.is_empty():
		print("RUSH_SMOKE_OK")
		quit(0)
	else:
		for message in _failed:
			push_error(message)
		print("RUSH_SMOKE_FAIL %d" % _failed.size())
		quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failed.append(message)

func _test_gestures() -> void:
	var gesture: ArenaShotGesture = Gesture.new()
	gesture.update_drag(Vector2(6, -6), true)
	_expect(not gesture.committed(), "small finger drift remains neutral")
	gesture.update_drag(Vector2(12, -100), true)
	_expect(gesture.loft == 1.0 and gesture.spin == 0.0, "upward drag selects chip")
	gesture.update_drag(Vector2(100, -60), true)
	_expect(gesture.mode == Gesture.Mode.CHIP and gesture.spin == 0.0, "chip cannot switch to curve mid-hold")
	gesture.update_drag(Vector2.ZERO, true)
	_expect(gesture.loft == 0.0 and not Shot.clean_knuckle(2.6, gesture.committed()), "return to origin removes loft without an accidental knuckle")
	gesture.reset()
	gesture.update_drag(Vector2(-100, -6), true)
	gesture.update_drag(Vector2(-100, -100), true)
	_expect(gesture.spin == -1.0 and gesture.loft == 0.0, "curve remains curve when the finger later moves up")
	gesture.reset()
	gesture.update_drag(Vector2(60, -60), true)
	_expect(gesture.mode == Gesture.Mode.STRAIGHT and gesture.committed(), "ambiguous diagonal waits for an axis but suppresses knuckle")
	gesture.reset()
	gesture.update_drag(Vector2(0, -100), false)
	_expect(gesture.loft == 0.0, "chip stays locked until cup completion")
	_expect(Shot.clean_knuckle(9.6, false) and is_equal_approx(Shot.ring_phase(9.6), 0.6), "holding continues across revolutions")
	var aim: Vector2 = Vector2(0, 1.05)
	_expect(Shot.position_at(aim, 0.0, false, 0.0, 1.0) == Shot.START, "chip begins at the ball")
	_expect(Shot.position_at(aim, 0.0, false, 0.5, 1.0).y > Shot.position_at(aim, 0.0, false, 0.5).y + 1.5, "chip has real mid-flight clearance")
	_expect(Shot.position_at(aim, 0.0, false, 1.0, 1.0).is_equal_approx(Vector3(aim.x, aim.y, 0)), "loft returns to the locked goal-plane aim")
	_expect(Shot.duration_for(1.0) > Shot.duration_for() and Shot.duration_for() == 0.70, "chip travels slower; ordinary duration retained")

func _test_progress() -> void:
	var progress: RushProgress = RushProgress.new(RUSH_PATH)
	progress.load_from_disk()
	_expect(progress.record_set(["GOAL"], 1).is_empty(), "incomplete set cannot save")
	progress.record_set(["GOAL", "GOAL", "GOAL", "WIDE", "WIDE"], 0)
	_expect(progress.wins == 1 and not progress.badge_earned, "ordinary win earns stars but not mastery")
	progress.record_set(["GOAL", "GOAL", "GOAL", "WIDE", "WIDE"], 1)
	_expect(progress.badge_earned and progress.badge_equipped and progress.last_save_error == OK, "winning rush chip earns and saves badge")
	progress.toggle_badge()
	var reloaded: RushProgress = RushProgress.new(RUSH_PATH)
	reloaded.load_from_disk()
	_expect(reloaded.wins == 2 and reloaded.best_stars() == 1 and reloaded.badge_earned and not reloaded.badge_equipped, "records and equipment survive reopening")
	reloaded.record_set(["GOAL", "GOAL", "WIDE", "WIDE", "WIDE"], 1)
	_expect(reloaded.best_goals == 3 and reloaded.losses == 1, "defeat preserves best and badge")
	var bad: ConfigFile = ConfigFile.new()
	bad.set_value("rush", "version", 99)
	bad.save(BAD_PATH)
	var previous: String = FileAccess.get_file_as_string(BAD_PATH)
	var ignored: RushProgress = RushProgress.new(BAD_PATH)
	ignored.load_from_disk()
	ignored.mark_lesson_seen()
	_expect(FileAccess.get_file_as_string(BAD_PATH) == previous, "unknown version is preserved after attempted save")
	var malformed: FileAccess = FileAccess.open(BAD_PATH, FileAccess.WRITE)
	malformed.store_string("[rush\nbroken")
	malformed.close()
	previous = FileAccess.get_file_as_string(BAD_PATH)
	ignored.load_from_disk()
	ignored.save()
	_expect(FileAccess.get_file_as_string(BAD_PATH) == previous, "malformed file is preserved")
	_wipe(RUSH_PATH)

func _test_arena() -> void:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		return
	var arena: Node = packed.instantiate()
	arena.progress_path = CUP_PATH
	arena.rush_progress_path = RUSH_PATH
	arena.champion_progress_path = CHAMPION_PATH
	root.add_child(arena)
	await process_frame
	await process_frame
	# Deterministic stepping below uses the production flight and collision code.
	arena.set_physics_process(false)
	arena.set_process(false)
	arena._show_rush_intro()
	_expect(arena.screen_name() == "CUP", "fresh cup cannot enter showdown")
	for profile in RivalProfile.roster():
		arena.progress().record_set(profile.id, 3)
	var cup_before: String = FileAccess.get_file_as_string(CUP_PATH)
	arena._show_rush_intro()
	_expect(arena._mode == Game.Mode.LESSON, "first unlocked visit offers the lesson")
	arena._start_lesson()
	_fly(arena, 0.0)
	_expect(not arena._lesson_success and arena._rush_progress.wins == 0, "unchipped lesson does not award progress")
	arena._start_lesson()
	_fly(arena, 1.0)
	_expect(arena._outcome == "GOAL" and arena._rush_clear and arena._lesson_success, "actual chip clears the moving keeper and scores")
	_expect(arena._rush_progress.lesson_seen and arena._rush_progress.wins == 0 and not arena._rush_progress.badge_earned, "lesson success only completes onboarding")
	arena._start_rush()
	_expect(arena._keeper.rush_armed(), "ball one signals a rush")
	_fly(arena, 1.0)
	_expect(arena._rush_chips == 1 and arena.last_signature.get("title", "") == "CHIPPED HIM!", "only a confirmed over-keeper goal counts")
	arena._next_ball()
	_expect(not arena._keeper.rush_armed(), "ball two stays back")
	arena.smoke_resolve("GOAL")
	arena._next_ball()
	_expect(arena._keeper.rush_armed(), "ball three rushes again")
	arena.smoke_resolve("GOAL")
	_expect(arena.screen_name() == "PLAY" and arena._rush_progress.wins == 0, "early clear still leaves two balls to earn stars")
	for _i in range(2):
		arena._next_ball()
		arena.smoke_resolve("WIDE")
	_expect(arena.screen_name() == "RESULT" and arena._rush_progress.wins == 1 and arena._rush_progress.badge_earned, "five completed balls record one win and mastery")
	arena._finish_set()
	arena._pause_round()
	arena._resume_round()
	_expect(arena._rush_progress.wins == 1, "re-render and pause cannot count the win again")
	arena._rematch()
	arena.smoke_resolve("WIDE")
	arena._open_cup()
	_expect(arena._rush_progress.losses == 0, "abandoning a rematch does not record a defeat")
	_expect(FileAccess.get_file_as_string(CUP_PATH) == cup_before, "showdown never writes cup stars or records")
	arena._show_rush_intro()
	_expect(arena._mode == Game.Mode.RUSH, "return visit goes directly to showdown briefing")
	arena._start_rush()
	await process_frame
	var point: Vector2 = arena.get_viewport().get_visible_rect().size * Vector2(0.5, 0.78)
	arena._begin_pointer(7, point)
	arena._drag_pointer(point + Vector2(0, -100))
	arena._pause_round()
	arena._end_pointer(point)
	arena._resume_round()
	_expect(arena._shots == 0 and arena._loft == 0.0 and arena._owner == -1, "pause cancels a held chip and stale release")
	_expect(RivalProfile.at(2).rush_every == 0 and RivalProfile.at(2).commit_to_lean, "showdown never mutates the cup roster")
	_test_touch_button(arena)
	root.remove_child(arena)
	arena.free()

func _fly(arena: Node, loft: float) -> void:
	arena._locked_aim = Vector2(0.0, 1.05)
	arena._loft = loft
	arena._spin = 0.0
	arena._knuckle = false
	arena._flight_duration = Shot.duration_for(loft)
	arena._flight_age = 0.0
	arena._ball_position = Shot.START
	arena._velocity = (Shot.position_at(arena._locked_aim, 0.0, false, 0.001, loft) - Shot.START) / (0.001 * arena._flight_duration)
	arena._shots += 1
	arena._phase = Game.Phase.FLIGHT
	for _step in range(480):
		if arena._phase != Game.Phase.FLIGHT:
			break
		arena._clock += 1.0 / 240.0
		arena._step_flight(1.0 / 240.0)
	_expect(arena._phase == Game.Phase.RESULT, "flight resolves within its bounded duration")

func _test_touch_button(arena: Node) -> void:
	# A separate button exercises the shared touch binding without writing settings.
	var button: Button = arena._hud._button(arena._hud, "Touch")
	button.toggle_mode = true
	button.size = Vector2(80, 48)
	var original: bool = button.button_pressed
	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.index = 4
	down.pressed = true
	down.position = button.size * 0.5
	button.gui_input.emit(down)
	var up: InputEventScreenTouch = down.duplicate() as InputEventScreenTouch
	up.pressed = false
	button.gui_input.emit(up)
	_expect(button.button_pressed != original, "raw touch toggles a button without mouse emulation")
	button.gui_input.emit(up)
	_expect(button.button_pressed != original, "repeated release cannot toggle twice")
	var before_swipe: bool = button.button_pressed
	button.gui_input.emit(down)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 4
	drag.position = down.position + Vector2(0, 30)
	button.gui_input.emit(drag)
	button.gui_input.emit(up)
	_expect(button.button_pressed == before_swipe, "a scroll gesture cannot activate the button on release")
	button.free()

func _wipe(path: String) -> void:
	for file in [path, path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
