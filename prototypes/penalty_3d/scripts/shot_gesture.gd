class_name ArenaShotGesture
extends RefCounted

const Shot = preload("res://scripts/shot_math.gd")
const DEAD_ZONE: float = 14.0
const AXIS_BIAS: float = 1.25
const CHIP_TRAVEL: float = 86.0

enum Mode { STRAIGHT, CURVE, CHIP }

var mode: Mode = Mode.STRAIGHT
var spin: float = 0.0
var loft: float = 0.0
var moved: bool = false

func reset() -> void:
	mode = Mode.STRAIGHT
	spin = 0.0
	loft = 0.0
	moved = false

func committed() -> bool:
	return moved

func update_drag(delta: Vector2, chip_enabled: bool) -> void:
	var sideways: float = absf(delta.x)
	var upward: float = maxf(0.0, -delta.y)
	# Even an ambiguous diagonal cannot turn into an accidental knuckle.
	moved = moved or sideways > DEAD_ZONE or (chip_enabled and delta.length() > DEAD_ZONE)
	if mode == Mode.STRAIGHT:
		if chip_enabled and upward > DEAD_ZONE and upward > sideways * AXIS_BIAS:
			mode = Mode.CHIP
		elif sideways > DEAD_ZONE and (not chip_enabled or sideways > upward * AXIS_BIAS):
			mode = Mode.CURVE
	# A chosen axis stays selected until release/cancel. Returning to the origin
	# straightens the flight without allowing an accidental timed knuckle.
	spin = Shot.spin_for_drag(delta.x) if mode == Mode.CURVE else 0.0
	loft = clampf((upward - DEAD_ZONE) / CHIP_TRAVEL, 0.0, 1.0) if mode == Mode.CHIP else 0.0
