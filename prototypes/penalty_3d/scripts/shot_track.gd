class_name ArenaShotTrack
extends Control

const UI = preload("res://scripts/ui_theme.gd")
var _outcomes: Array[String] = []

func _init() -> void:
	custom_minimum_size = Vector2(116, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_outcomes(value: Array[String]) -> void:
	_outcomes = value.duplicate()
	queue_redraw()

func _draw() -> void:
	for i in range(5):
		var center: Vector2 = Vector2(10 + i * 24, size.y * 0.5)
		if i >= _outcomes.size():
			draw_circle(center, 8.0, UI.RAISED)
			draw_arc(center, 8.0, 0.0, TAU, 24, UI.LIME if i == _outcomes.size() else UI.OUTLINE, 1.5, true)
		elif _outcomes[i] == "GOAL":
			draw_circle(center, 8.0, UI.LIME)
			draw_line(center + Vector2(-3.5, 0), center + Vector2(-0.5, 3), UI.INK, 1.8, true)
			draw_line(center + Vector2(-0.5, 3), center + Vector2(4, -3), UI.INK, 1.8, true)
		else:
			draw_circle(center, 8.0, UI.CORAL)
			draw_line(center - Vector2(3, 3), center + Vector2(3, 3), UI.INK, 1.8, true)
			draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), UI.INK, 1.8, true)
