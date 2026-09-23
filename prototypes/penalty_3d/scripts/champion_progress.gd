class_name ChampionProgress
extends RefCounted

const VERSION: int = 1
const REQUIRED_GOALS: int = 4
var path: String
var best_goals: int = 0
var wins: int = 0
var losses: int = 0
var recent_lanes: Array[float] = []
var last_save_error: Error = OK
var _writable: bool = true

func _init(save_path: String = "user://champion_showdown.cfg") -> void:
	path = save_path

func load_from_disk() -> void:
	best_goals = 0
	wins = 0
	losses = 0
	recent_lanes.clear()
	_writable = true
	last_save_error = OK
	if not FileAccess.file_exists(path):
		return
	var config: ConfigFile = ConfigFile.new()
	last_save_error = config.load(path)
	if last_save_error != OK:
		_writable = false
		return
	var version: Variant = config.get_value("champion", "version", 0)
	if typeof(version) != TYPE_INT or int(version) != VERSION:
		_writable = false
		last_save_error = ERR_FILE_UNRECOGNIZED
		return
	best_goals = _count(config.get_value("champion", "best_goals", 0), 5)
	wins = _count(config.get_value("champion", "wins", 0), 999999)
	losses = _count(config.get_value("champion", "losses", 0), 999999)
	var lanes: Variant = config.get_value("champion", "recent_lanes", [])
	if typeof(lanes) == TYPE_ARRAY:
		for value in lanes:
			if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)):
				recent_lanes.append(clampf(float(value), -3.66, 3.66))
				if recent_lanes.size() > ChampionBrain.MEMORY_SIZE:
					recent_lanes.pop_front()

func record_set(outcomes: Array[String], observed_lanes: Array[float]) -> Dictionary:
	if outcomes.size() != 5:
		return {}
	for outcome in outcomes:
		if not ["GOAL", "SAVED", "POST", "WIDE", "OVER"].has(outcome):
			return {}
	var goals: int = outcomes.count("GOAL")
	var won: bool = goals >= REQUIRED_GOALS
	var first_win: bool = won and wins == 0
	best_goals = maxi(best_goals, goals)
	if won:
		wins = mini(999999, wins + 1)
	else:
		losses = mini(999999, losses + 1)
	var memory: ChampionBrain = ChampionBrain.new()
	memory.set_memory(observed_lanes)
	recent_lanes = memory.memory()
	save()
	return {"won": won, "goals": goals, "first_win": first_win, "perfect": goals == 5}

func next_target(goals: int) -> String:
	if goals < REQUIRED_GOALS:
		return "Score 4 to beat The Captain"
	if goals == 4:
		return "Beat him 5/5 for a perfect showdown"
	return "Perfect showdown. He will remember those corners."

func save() -> void:
	if not _writable:
		push_warning("Champion save preserved; progress is available for this session only.")
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("champion", "version", VERSION)
	config.set_value("champion", "best_goals", best_goals)
	config.set_value("champion", "wins", wins)
	config.set_value("champion", "losses", losses)
	config.set_value("champion", "recent_lanes", recent_lanes)
	last_save_error = config.save(path + ".tmp")
	if last_save_error == OK:
		last_save_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if last_save_error != OK:
		push_warning("Could not save Champion progress: %s" % error_string(last_save_error))

static func _count(value: Variant, maximum: int) -> int:
	return clampi(int(value), 0, maximum) if typeof(value) == TYPE_INT else 0
