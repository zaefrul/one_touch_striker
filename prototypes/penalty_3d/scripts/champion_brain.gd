class_name ChampionBrain
extends RefCounted

const MEMORY_SIZE: int = 5
# Two separated rushes; a four-goal win always needs at least two other goals.
const PATTERNS: Array = [[0, 2], [0, 3], [0, 4], [1, 3], [1, 4], [2, 4]]
var _recent: Array[float] = []
var _pattern: int = -1
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_random.randomize()

func set_memory(values: Array[float]) -> void:
	_recent.clear()
	for value in values:
		note_shot(value)

func memory() -> Array[float]:
	return _recent.duplicate()

func begin_set(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_random.seed = seed_value
	if _pattern < 0:
		_pattern = _random.randi_range(0, PATTERNS.size() - 1)
	else:
		# A rematch cannot repeat the same complete rush schedule.
		_pattern = (_pattern + _random.randi_range(1, PATTERNS.size() - 1)) % PATTERNS.size()

func rushes_on(ball_index: int) -> bool:
	return _pattern >= 0 and ball_index >= 0 and ball_index < 5 and PATTERNS[_pattern].has(ball_index)

func note_shot(observed_x: float) -> void:
	if not is_finite(observed_x):
		return
	_recent.append(clampf(observed_x, -3.66, 3.66))
	if _recent.size() > MEMORY_SIZE:
		_recent.pop_front()

func guard_bias() -> float:
	var weighted: float = 0.0
	var weights: float = 0.0
	for i in range(_recent.size()):
		var weight: float = float(i + 1)
		weighted += clampf(_recent[i] / 2.8, -1.0, 1.0) * weight
		weights += weight
	return 0.0 if weights == 0.0 else clampf(weighted / weights * 1.25, -1.25, 1.25)
