extends SceneTree

## Headless Rival Cup checks. Launch with:
## godot --headless --path prototypes/penalty_3d -s res://tests/cup_smoke.gd
## `--quit-after` is iteration-based and does not drive this script.

var _failed: PackedStringArray = PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_rivals()
	_test_progress()
	await _test_arena()
	if _failed.is_empty():
		print("CUP_SMOKE_OK")
		quit(0)
	else:
		for line in _failed:
			push_error(line)
			print("FAIL: %s" % line)
		print("CUP_SMOKE_FAIL %d" % _failed.size())
		quit(1)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failed.append(message)


func _tmp(name: String) -> String:
	return "user://%s.cfg" % name


func _test_rivals() -> void:
	var roster: Array[RivalProfile] = RivalProfile.roster()
	_expect(roster.size() == 3, "roster has three rivals")
	_expect(roster[0].id == "sweeper" and roster[0].title == "The Sweeper", "sweeper identity")
	_expect(roster[1].id == "sentinel" and roster[2].id == "gambler", "sentinel and gambler ids")
	_expect(is_equal_approx(roster[0].offset(0.0), 0.0), "sweeper offset at 0 is 0")
	_expect(is_equal_approx(roster[1].offset(0.0), 1.0), "sentinel starts parked right")
	_expect(is_equal_approx(roster[2].offset(0.0), 1.0), "gambler starts on the right")
	_expect(roster[0].reaction == 0.24 and roster[0].lift_max == 0.25, "sweeper save tuning")
	_expect(roster[2].commit_to_lean and roster[2].rush_every == 0, "gambler lean hook; rush later")


func _test_progress() -> void:
	var fresh_path: String = _tmp("cup_smoke_fresh")
	_wipe(fresh_path)
	var fresh: CupProgress = CupProgress.new(fresh_path)
	fresh.load_from_disk()
	_expect(fresh.is_unlocked(0) and not fresh.is_unlocked(1) and not fresh.is_unlocked(2), "fresh save unlocks only rival 1")
	_expect(fresh.stars_for_goals(2) == 0 and fresh.stars_for_goals(3) == 1, "3 goals -> 1 star")
	_expect(fresh.stars_for_goals(4) == 2 and fresh.stars_for_goals(5) == 3, "4/5 goals -> 2/3 stars")
	_expect(not fresh.cup_won() and fresh.ball == "classic", "fresh cup not won")

	var three: Dictionary = fresh.record_set("sweeper", 3)
	_expect(int(three["stars"]) == 1 and three["won"] and three["new_best"], "3 goals records 1 star and a win")
	_expect(fresh.is_unlocked(1) and not fresh.is_unlocked(2), "sentinel unlocks after sweeper")
	_expect(fresh.wins_of("sweeper") == 1 and fresh.losses_of("sweeper") == 0, "exactly one win for the set")

	var rematch: Dictionary = fresh.record_set("sweeper", 2)
	_expect(int(rematch["stars"]) == 1 and not rematch["new_best"], "best stars are retained")
	_expect(fresh.wins_of("sweeper") == 1 and fresh.losses_of("sweeper") == 1, "loss increments once")
	_expect(fresh.is_unlocked(1), "cleared rival stays unlocked after a rematch loss")

	fresh.record_set("sweeper", 5)
	_expect(fresh.stars_of("sweeper") == 3, "perfect set raises stars to 3")

	fresh.record_set("sentinel", 3)
	_expect(fresh.is_unlocked(2) and not fresh.cup_won(), "gambler unlocks; cup still open")
	var cup: Dictionary = fresh.record_set("gambler", 4)
	_expect(fresh.cup_won() and cup["first_cup_win"], "third clear derives cup_won and first_cup_win")
	var again: Dictionary = fresh.record_set("gambler", 5)
	_expect(not again["first_cup_win"] and fresh.stars_of("gambler") == 3, "later perfect is not first cup win")

	var corrupt_path: String = _tmp("cup_smoke_corrupt")
	_wipe(corrupt_path)
	var bad: ConfigFile = ConfigFile.new()
	bad.set_value("cup", "version", 99)
	bad.set_value("cup", "stars_sweeper", 3)
	bad.save(corrupt_path)
	var ignored: CupProgress = CupProgress.new(corrupt_path)
	ignored.load_from_disk()
	_expect(ignored.stars_of("sweeper") == 0 and not ignored.cup_won(), "unknown version starts fresh in memory")
	var still: ConfigFile = ConfigFile.new()
	still.load(corrupt_path)
	_expect(int(still.get_value("cup", "version", 0)) == 99, "unknown version is not overwritten until a real save")
	ignored.record_set("sweeper", 3)
	still.load(corrupt_path)
	_expect(int(still.get_value("cup", "version", 0)) == 1, "next successful save writes version 1")

	var fallback_path: String = _tmp("cup_smoke_ball")
	_wipe(fallback_path)
	var planted: ConfigFile = ConfigFile.new()
	planted.set_value("cup", "version", 1)
	planted.set_value("cup", "ball", "cup")
	planted.set_value("cup", "stars_sweeper", 0)
	planted.save(fallback_path)
	var fallback: CupProgress = CupProgress.new(fallback_path)
	fallback.load_from_disk()
	_expect(fallback.ball == "classic", "cup ball without unlock falls back to classic")
	var rewritten: ConfigFile = ConfigFile.new()
	rewritten.load(fallback_path)
	_expect(str(rewritten.get_value("cup", "ball", "")) == "classic", "classic fallback is persisted")


func _test_arena() -> void:
	var path: String = _tmp("cup_smoke_arena")
	_wipe(path)
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_expect(packed != null, "main.tscn loads")
	if packed == null:
		return
	var arena: Node = packed.instantiate()
	arena.progress_path = path
	arena.rush_progress_path = _tmp("cup_smoke_rush_unused")
	arena.champion_progress_path = _tmp("cup_smoke_champion_unused")
	root.add_child(arena)
	await process_frame
	await process_frame
	_expect(arena.screen_name() == "CUP", "boot opens the cup map")
	_expect(arena.progress().is_unlocked(0) and not arena.progress().is_unlocked(1), "arena fresh unlocks only sweeper")

	arena._show_intro(0)
	await process_frame
	_expect(arena.screen_name() == "INTRO", "play next opens the rival intro")
	_expect(arena.current_profile().id == "sweeper", "intro is the sweeper")

	arena._start_set(0)
	await process_frame
	_expect(arena.screen_name() == "PLAY", "start enters play")
	arena.smoke_resolve("GOAL")
	arena.smoke_resolve("WIDE")
	_expect(arena.progress().wins_of("sweeper") == 0, "abandon mid-set records nothing")
	arena._open_cup()
	await process_frame
	_expect(arena.progress().stars_of("sweeper") == 0, "cup from mid-set does not write stars")

	arena._start_set(0)
	for _i in range(3):
		arena.smoke_resolve("GOAL")
	arena.smoke_resolve("WIDE")
	arena.smoke_resolve("WIDE")
	await process_frame
	_expect(arena.screen_name() == "RESULT", "fifth ball opens the set result")
	_expect(arena.progress().stars_of("sweeper") == 1, "three goals save one star")
	_expect(arena.progress().wins_of("sweeper") == 1, "one win recorded for the completed set")
	_expect(arena.progress().is_unlocked(1), "sentinel unlocks after the first clear")

	arena._start_set(0)
	for _i in range(5):
		arena.smoke_resolve("GOAL")
	_expect(arena.progress().stars_of("sweeper") == 3, "perfect rematch raises stars to three")
	_expect(arena.progress().wins_of("sweeper") == 2, "rematch of a cleared rival records another win")
	_expect(arena.progress().is_unlocked(1), "unlock remains after rematch")

	arena._start_set(1)
	arena.smoke_resolve("WIDE")
	arena.smoke_resolve("WIDE")
	arena.smoke_resolve("WIDE")
	arena.smoke_resolve("WIDE")
	arena.smoke_resolve("WIDE")
	_expect(arena.progress().losses_of("sentinel") == 1, "a finished defeat records one loss")
	_expect(arena.progress().stars_of("sentinel") == 0, "zero goals stay at zero stars")
	_expect(not arena.progress().is_unlocked(2), "gambler stays locked")

	arena._start_set(1)
	for _i in range(4):
		arena.smoke_resolve("GOAL")
	arena.smoke_resolve("WIDE")
	_expect(arena.progress().stars_of("sentinel") == 2, "four goals save two stars")

	arena._start_set(2)
	arena.smoke_resolve("GOAL", Vector3(2.8, 1.85, -0.14), 0.9, false)
	_expect(arena.last_signature.get("placement", "") == "corner", "corner uses the crossing position")
	_expect(arena.last_signature.get("technique", "") == "banana", "banana is kept as a separate fact")
	_expect(arena.last_signature.get("title", "") == "TOP BINS!", "title picks the rarer corner line")
	arena._ball_position = Vector3(0.0, 0.14, 2.0)
	_expect(arena.last_signature.get("placement", "") == "corner", "rebound does not change classification")

	arena.smoke_resolve("GOAL", Vector3(0.2, 1.1, -0.14), 0.0, true)
	_expect(arena.last_signature.get("technique", "") == "knuckle", "knuckle technique is classified")
	_expect(arena.last_signature.get("title", "") == "PURE KNUCKLE!", "knuckle title")

	arena.smoke_resolve("GOAL")
	_expect(arena.tension_level() == 0, "already-cleared set does not sit on peak tension")
	arena.smoke_resolve("WIDE")
	arena.smoke_resolve("WIDE")
	_expect(arena.progress().cup_won(), "clearing the third rival derives cup_won")

	_wipe(_tmp("cup_smoke_tension"))
	var tense_path: String = _tmp("cup_smoke_tension")
	arena.progress().path = tense_path
	arena._start_set(0)
	arena.smoke_resolve("GOAL")
	arena.smoke_resolve("GOAL")
	arena.smoke_resolve("WIDE")
	arena.smoke_resolve("WIDE")
	_expect(arena.tension_level() == 2, "needed 1 and one ball left is peak tension")
	arena.smoke_resolve("GOAL")
	_expect(arena.tension_level() == 0, "fifth resolution clears tension")

	arena._start_set(0)
	arena.smoke_resolve("GOAL")
	_expect(arena.is_celebrating() or arena.particles_live(), "goal starts a celebration")
	arena._next_ball()
	_expect(arena.camera_at_home(), "Next ball during the camera push restores home")
	_expect(not arena.particles_live(), "Next ball clears live particles")

	arena.smoke_resolve("GOAL")
	arena._pause_round()
	_expect(arena.fx_speed_scale() == 0.0, "pause freezes celebration particles")
	arena._resume_round()
	_expect(arena.fx_speed_scale() == 1.0, "resume restores the fx timeline")

	arena._open_cup()
	await process_frame
	_expect(arena.camera_at_home() and not arena.particles_live(), "Cup navigation cancels celebration")

	root.remove_child(arena)
	arena.free()


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
