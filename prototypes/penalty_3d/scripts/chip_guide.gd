class_name ArenaChipGuide
extends Control

const UI = preload("res://scripts/ui_theme.gd")
var _age: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(44, 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_age = fmod(_age + delta, 1.7)
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_age / 1.2, 0.0, 1.0)
	var top: Vector2 = Vector2(22, 12)
	var base: Vector2 = Vector2(22, 90)
	draw_line(base, top, UI.OUTLINE, 3.0, true)
	draw_line(top, top + Vector2(-8, 10), UI.BLUE, 3.0, true)
	draw_line(top, top + Vector2(8, 10), UI.BLUE, 3.0, true)
	var point: Vector2 = base.lerp(top, t * t * (3.0 - 2.0 * t))
	draw_circle(point, 8.0, Color(UI.BLUE, 0.25))
	draw_arc(point, 8.0, 0, TAU, 24, UI.BLUE, 2.0, true)
