class_name RivalProfile
extends RefCounted

## Three keepers ported from lib/game/keeper_style.dart. Values are first-pass
## tuning for the phone playtest, not proven balance.
var id: String
var title: String
var weakness: String
var kit: Color
var reaction: float
var reach: float
var dive_time: float
var lift_max: float
var crouch: float
var arm_spread: float
var bounce: float
var taunts: Array[String] = []
var intro_cue: String
var rush_every: int = 0
var rush_distance: float = 3.0
var rush_time: float = 0.44
var commit_to_lean: bool = false

static var _roster: Array[RivalProfile] = []


static func roster() -> Array[RivalProfile]:
	if _roster.is_empty():
		_roster = [_sweeper(), _sentinel(), _gambler()]
	return _roster


static func at(index: int) -> RivalProfile:
	var all: Array[RivalProfile] = roster()
	return all[clampi(index, 0, all.size() - 1)]


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func offset(angle: float) -> float:
	match id:
		"sentinel":
			var cycle: float = fposmod(angle, TAU) / TAU
			if cycle < 0.125:
				return 1.0
			if cycle < 0.5:
				return 1.0 - 2.0 * _ease((cycle - 0.125) / 0.375)
			if cycle < 0.625:
				return -1.0
			return -1.0 + 2.0 * _ease((cycle - 0.625) / 0.375)
		"gambler", "rush_gambler":
			var visit: float = (1.0 - cos(angle)) * 0.5
			return 1.0 - 2.0 * visit * visit * visit
		_:
			return sin(angle)


static func _sweeper() -> RivalProfile:
	var profile: RivalProfile = RivalProfile.new()
	profile.id = "sweeper"
	profile.title = "The Sweeper"
	profile.weakness = "Sweeps from side to side. Aim into the space he leaves."
	profile.kit = Color("#ffd166")
	profile.reaction = 0.24
	profile.reach = 1.35
	profile.dive_time = 0.40
	profile.lift_max = 0.25
	profile.crouch = 0.04
	profile.arm_spread = 0.02
	profile.bounce = 0.08
	profile.taunts = ["Too slow.", "I'm already there.", "Keep chasing."]
	profile.intro_cue = "HE NEVER STOPS"
	profile.rush_every = 0
	return profile


static func _sentinel() -> RivalProfile:
	var profile: RivalProfile = RivalProfile.new()
	profile.id = "sentinel"
	profile.title = "The Sentinel"
	profile.weakness = "Pauses at each side, then crosses. Read the pause before you shoot."
	profile.kit = Color("#5fd4ff")
	profile.reaction = 0.19
	profile.reach = 1.55
	profile.dive_time = 0.34
	profile.lift_max = 0.60
	profile.crouch = 0.0
	profile.arm_spread = 0.10
	profile.bounce = 0.03
	profile.taunts = ["I was waiting.", "Not that post.", "Hold your nerve."]
	profile.intro_cue = "PLANTS, THEN FLIES"
	profile.rush_every = 0
	return profile


static func _gambler() -> RivalProfile:
	var profile: RivalProfile = RivalProfile.new()
	profile.id = "gambler"
	profile.title = "The Gambler"
	profile.weakness = "Guards the right for longer. Watch his brief trip to the left."
	profile.kit = Color("#ff8fd0")
	profile.reaction = 0.16
	profile.reach = 1.75
	profile.dive_time = 0.30
	profile.lift_max = 0.60
	profile.crouch = 0.02
	profile.arm_spread = 0.06
	profile.bounce = 0.05
	profile.taunts = ["Called it.", "Wrong side.", "Lucky next time."]
	profile.intro_cue = "WATCH THE LEAN"
	profile.rush_every = 0
	profile.commit_to_lean = true
	return profile


static func rush_showdown() -> RivalProfile:
	# A separate profile: never mutate the shared three-rival roster or its saves.
	var profile: RivalProfile = _gambler()
	profile.id = "rush_gambler"
	profile.title = "The Gambler"
	profile.weakness = "Blue arrows: he will rush. Lift it over him."
	profile.intro_cue = "BEAT THE RUSH"
	profile.reaction = 0.22
	profile.reach = 1.55
	profile.dive_time = 0.38
	profile.commit_to_lean = false
	profile.rush_every = 2
	profile.taunts = ["Read the run.", "Too low.", "Watch my feet."]
	return profile


func rushes_on(ball_index: int) -> bool:
	return rush_every > 0 and ball_index >= 0 and ball_index % rush_every == 0
