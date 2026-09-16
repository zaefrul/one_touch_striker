class_name ArenaShotTrack
extends Control

const UI = preload("res://scripts/ui_theme.gd")
var _outcomes: Array[String] = []
var _pulse_rate: float = 0.0
var _pulse_phase: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(116, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func set_outcomes(value: Array[String]) -> void:
	_outcomes = value.duplicate()
	queue_redraw()

func set_pulse(rate: float) -> void:
	_pulse_rate = rate
	set_process(rate > 0.0)
	if rate <= 0.0:
		_pulse_phase = 0.0
		queue_redraw()

func _process(delta: float) -> void:
	_pulse_phase += delta * _pulse_rate
	queue_redraw()

func _draw() -> void:
	for i in range(5):
		var center: Vector2 = Vector2(10 + i * 24, size.y * 0.5)
		if i >= _outcomes.size():
			var active: bool = i == _outcomes.size()
			var pulse: float = 1.0 + 0.28 * sin(_pulse_phase * TAU) if active and _pulse_rate > 0.0 else 1.0
			draw_circle(center, 8.0, UI.RAISED)
			draw_arc(center, 8.0 * pulse, 0.0, TAU, 24, UI.GOLD if active else UI.OUTLINE, 1.5 * pulse, true)
		elif _outcomes[i] == "GOAL":
			draw_circle(center, 8.0, UI.GOLD)
			draw_line(center + Vector2(-3.5, 0), center + Vector2(-0.5, 3), UI.INK, 1.8, true)
			draw_line(center + Vector2(-0.5, 3), center + Vector2(4, -3), UI.INK, 1.8, true)
		else:
			draw_circle(center, 8.0, UI.CORAL)
			draw_line(center - Vector2(3, 3), center + Vector2(3, 3), UI.INK, 1.8, true)
			draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), UI.INK, 1.8, true)
