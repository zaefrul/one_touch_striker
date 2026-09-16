class_name CupProgress
extends RefCounted

const VERSION: int = 1
const MAX_COUNT: int = 999999
const IDS: Array[String] = ["sweeper", "sentinel", "gambler"]

var path: String
var stars: Dictionary = {}
var wins: Dictionary = {}
var losses: Dictionary = {}
var ball: String = "classic"
var _allow_save: bool = true


func _init(save_path: String = "user://rival_cup.cfg") -> void:
	path = save_path
	_reset_memory()


func _reset_memory() -> void:
	stars.clear()
	wins.clear()
	losses.clear()
	for id in IDS:
		stars[id] = 0
		wins[id] = 0
		losses[id] = 0
	ball = "classic"


static func stars_for_goals(goals: int) -> int:
	if goals >= 5:
		return 3
	if goals == 4:
		return 2
	if goals == 3:
		return 1
	return 0


func cup_won() -> bool:
	for id in IDS:
		if int(stars[id]) < 1:
			return false
	return true


func stars_of(id: String) -> int:
	return int(stars.get(id, 0))


func wins_of(id: String) -> int:
	return int(wins.get(id, 0))


func losses_of(id: String) -> int:
	return int(losses.get(id, 0))


func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	if index >= IDS.size():
		return false
	return stars_of(IDS[index - 1]) >= 1


func next_play_index() -> int:
	for i in IDS.size():
		if is_unlocked(i) and stars_of(IDS[i]) < 1:
			return i
	for i in IDS.size():
		if is_unlocked(i) and stars_of(IDS[i]) < 3:
			return i
	return 0


func next_target_line(goals: int, rival_index: int) -> String:
	var current: RivalProfile = RivalProfile.at(rival_index)
	if goals < 3:
		return "Score 3 to beat %s" % current.title
	if goals == 3:
		return "Score 4 for two stars"
	if goals == 4:
		return "Score 5 for three stars"
	if rival_index + 1 < IDS.size():
		return "Perfect. Next: %s" % RivalProfile.at(rival_index + 1).title
	return "Cup complete"


func record_set(rival_id: String, goals: int) -> Dictionary:
	if not IDS.has(rival_id):
		return {"stars": 0, "earned": 0, "new_best": false, "first_cup_win": false, "won": false}
	var had_cup: bool = cup_won()
	var earned: int = stars_for_goals(goals)
	var previous: int = stars_of(rival_id)
	var new_best: bool = earned > previous
	if new_best:
		stars[rival_id] = earned
	var won: bool = goals >= 3
	if won:
		wins[rival_id] = mini(MAX_COUNT, wins_of(rival_id) + 1)
	else:
		losses[rival_id] = mini(MAX_COUNT, losses_of(rival_id) + 1)
	var first_cup_win: bool = won and not had_cup and cup_won()
	_allow_save = true
	save()
	return {
		"stars": stars_of(rival_id),
		"earned": earned,
		"new_best": new_best,
		"first_cup_win": first_cup_win,
		"won": won,
	}


func equip_ball(id: String) -> void:
	if id == "cup" and not cup_won():
		id = "classic"
	if id != "classic" and id != "cup":
		id = "classic"
	ball = id
	_allow_save = true
	save()


func load_from_disk() -> void:
	_reset_memory()
	if not FileAccess.file_exists(path):
		_allow_save = true
		return
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		_allow_save = false
		return
	var version: Variant = config.get_value("cup", "version", 0)
	if typeof(version) != TYPE_INT or int(version) != VERSION:
		_allow_save = false
		return
	for id in IDS:
		stars[id] = _clamp_stars(config.get_value("cup", "stars_%s" % id, 0))
		wins[id] = _clamp_count(config.get_value("cup", "wins_%s" % id, 0))
		losses[id] = _clamp_count(config.get_value("cup", "losses_%s" % id, 0))
	var saved_ball: Variant = config.get_value("cup", "ball", "classic")
	ball = str(saved_ball) if saved_ball is String else "classic"
	if ball != "classic" and ball != "cup":
		ball = "classic"
	_allow_save = true
	if ball == "cup" and not cup_won():
		ball = "classic"
		save()


func save() -> void:
	if not _allow_save:
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("cup", "version", VERSION)
	for id in IDS:
		config.set_value("cup", "stars_%s" % id, stars_of(id))
		config.set_value("cup", "wins_%s" % id, wins_of(id))
		config.set_value("cup", "losses_%s" % id, losses_of(id))
	config.set_value("cup", "ball", ball)
	var error: Error = config.save(path)
	if error != OK:
		push_warning("Could not save Rival Cup progress: %s" % error_string(error))


static func _clamp_stars(value: Variant) -> int:
	if value is int or value is float:
		return clampi(int(value), 0, 3)
	return 0


static func _clamp_count(value: Variant) -> int:
	if value is int or value is float:
		return clampi(int(value), 0, MAX_COUNT)
	return 0
