class_name RushProgress
extends RefCounted

const VERSION: int = 1
const MAX_COUNT: int = 999999

var path: String
var lesson_seen: bool = false
var best_goals: int = 0
var best_chips: int = 0
var wins: int = 0
var losses: int = 0
var badge_earned: bool = false
var badge_equipped: bool = false
var _writable: bool = true
var last_save_error: Error = OK

func _init(save_path: String = "user://rush_showdown.cfg") -> void:
	path = save_path

func load_from_disk() -> void:
	lesson_seen = false
	best_goals = 0
	best_chips = 0
	wins = 0
	losses = 0
	badge_earned = false
	badge_equipped = false
	_writable = true
	last_save_error = OK
	if not FileAccess.file_exists(path):
		return
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(path)
	if error != OK:
		_writable = false
		last_save_error = error
		return
	var version: Variant = config.get_value("rush", "version", 0)
	if typeof(version) != TYPE_INT or int(version) != VERSION:
		_writable = false
		last_save_error = ERR_FILE_UNRECOGNIZED
		return
	lesson_seen = _bool_value(config.get_value("rush", "lesson_seen", false))
	best_goals = _count(config.get_value("rush", "best_goals", 0), 5)
	best_chips = mini(best_goals, _count(config.get_value("rush", "best_chips", 0), 5))
	wins = _count(config.get_value("rush", "wins", 0), MAX_COUNT)
	losses = _count(config.get_value("rush", "losses", 0), MAX_COUNT)
	badge_earned = _bool_value(config.get_value("rush", "badge_earned", false)) and wins > 0 and best_goals >= 3 and best_chips > 0
	badge_equipped = badge_earned and _bool_value(config.get_value("rush", "badge_equipped", false))

func best_stars() -> int:
	return CupProgress.stars_for_goals(best_goals)

func mark_lesson_seen() -> void:
	lesson_seen = true
	save()

func record_set(outcomes: Array[String], rush_chips: int) -> Dictionary:
	# Incomplete practice/abandoned attempts can never award progress.
	if outcomes.size() != 5:
		return {}
	for outcome in outcomes:
		if not ["GOAL", "SAVED", "POST", "WIDE", "OVER"].has(outcome):
			return {}
	var goals: int = outcomes.count("GOAL")
	var chips: int = clampi(rush_chips, 0, goals)
	var won: bool = goals >= 3
	var first_badge: bool = won and chips > 0 and not badge_earned
	best_goals = maxi(best_goals, goals)
	best_chips = maxi(best_chips, chips)
	if won:
		wins = mini(MAX_COUNT, wins + 1)
	else:
		losses = mini(MAX_COUNT, losses + 1)
	if first_badge:
		badge_earned = true
		badge_equipped = true
	save()
	return {"won": won, "goals": goals, "chips": chips, "earned": CupProgress.stars_for_goals(goals), "first_badge": first_badge}

func toggle_badge() -> void:
	if not badge_earned:
		return
	badge_equipped = not badge_equipped
	save()

func next_target(goals: int, chips: int) -> String:
	if goals < 3:
		return "Score 3 to clear the showdown"
	if not badge_earned:
		return "Win with a rush chip to earn Sky Master"
	if goals == 3:
		return "Score 4 for two stars"
	if goals == 4:
		return "Score 5 for three stars"
	return "Five from five · %d rush chips" % chips

func save() -> void:
	# Preserve unknown/corrupt files; keep the current session playable.
	if not _writable:
		push_warning("Rush progress could not be saved; existing file needs review.")
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("rush", "version", VERSION)
	config.set_value("rush", "lesson_seen", lesson_seen)
	config.set_value("rush", "best_goals", best_goals)
	config.set_value("rush", "best_chips", best_chips)
	config.set_value("rush", "wins", wins)
	config.set_value("rush", "losses", losses)
	config.set_value("rush", "badge_earned", badge_earned)
	config.set_value("rush", "badge_equipped", badge_equipped)
	# Write first, then replace the known version. An interrupted write leaves
	# the previous save intact and cannot affect the separate Rival Cup file.
	var temporary: String = path + ".tmp"
	last_save_error = config.save(temporary)
	if last_save_error == OK:
		last_save_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if last_save_error != OK:
		push_warning("Could not save Rush Showdown: %s" % error_string(last_save_error))

static func _count(value: Variant, maximum: int) -> int:
	if typeof(value) == TYPE_INT:
		return clampi(int(value), 0, maximum)
	return 0

static func _bool_value(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and bool(value)
